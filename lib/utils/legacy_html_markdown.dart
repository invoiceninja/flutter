/// Folds the HTML that reaches note fields from the other Invoice Ninja
/// clients into equivalent markdown.
///
/// The React client edits `public_notes` / `private_notes` / `terms` /
/// `footer` with TinyMCE and the pre-v5 apps used Quill, so **HTML is a
/// permanent inbound shape** for these fields even though this app serializes
/// markdown (which the server renders when `company.markdown_enabled` is on).
///
/// Handing that HTML straight to super_editor's markdown deserializer is
/// destructive, in two different ways:
///
/// * A **block-level** tag makes `markdown`'s `HtmlBlockSyntax` treat the line
///   as a raw HTML block running to the next blank line, and super_editor's
///   block visitor drops raw text nodes — so a `<ul>` took the whole list, and
///   everything after it, out of the document (invoiceninja/flutter#107).
/// * An **inline** tag survives as literal text. `InlineHtmlSyntax` is not in
///   `markdown`'s default inline syntaxes, and super_editor's
///   `defaultInlineHtmlSyntaxes` run only on `md.Element`s (which come from
///   `**bold**` / `[link](url)`, never from literal HTML), so `<strong>` is
///   painted to the user verbatim.
///
/// Either way the loss is **persisted**: `MarkdownTextField._seedDocument`
/// baselines against the round-tripped value, so the first keystroke writes
/// the mangled document back over the user's data.
///
/// So every tag is mapped onto its markdown equivalent, or — where there
/// isn't one — onto a newline that at least keeps the text.
///
/// Known lossy edges, each preferred over deleting the text: table cells
/// flatten to paragraphs (super_editor supports GFM tables, so this could
/// improve later), `<blockquote>` loses its marker, and HTML inside a fenced
/// code block is rewritten like any other (there is no fence tracking).
///
/// HTML **entities** are deliberately not touched: `markdown` resolves them
/// downstream via `DecodeHtmlSyntax`, which is in its default inline syntax
/// set and backed by the full WHATWG table. Decoding them here would only
/// double up.
///
/// The output is **idempotent** — running it over its own result is a no-op —
/// which matters because that result is what super_editor serializes back and
/// what the next edit persists.
library;

/// The attribute list of an HTML tag — `\s+name="value"`, repeated.
///
/// Requiring `=` **and** a value is what keeps this from matching prose.
/// A permissive tail (`[^<>]*`) turns any `<` followed by a block-tag word
/// into a tag: `'qty < table rate > 10'` and `'mail <form@x.com> now'` both
/// lose everything between the brackets, silently and permanently. Valueless
/// attributes (`<td nowrap>`) are legal but neither TinyMCE nor Quill emits
/// them, so the trade is worth it. Quoted values may contain `<` and `>`.
const _kAttrs = r'''(?:\s+[^\s>/=<]+\s*=\s*(?:"[^"]*"|'[^']*'|[^\s><]+))*''';

/// One HTML tag: `<p>`, `</p>`, `<p/>`, `<br />`, `<li dir="ltr">`, …
///
/// Note there is no `\s*` after `<` — no HTML producer emits `< p>`, and
/// requiring the name to abut the bracket is half of what makes prose safe.
final _kHtmlTagPattern = RegExp(
  '<(/?)([a-zA-Z][a-zA-Z0-9]*)$_kAttrs'
  r'\s*/?>',
);

/// `<a href="…">text</a>`, non-greedy (anchors can't nest) and `dotAll` so a
/// link label may wrap across lines.
final _kAnchorPattern = RegExp(
  '<a\\b($_kAttrs)\\s*>(.*?)</a\\s*>',
  caseSensitive: false,
  dotAll: true,
);

/// The `href` of an anchor's attribute list, quoted or bare.
final _kHrefPattern = RegExp(
  '''\\bhref\\s*=\\s*(?:"([^"]*)"|'([^']*)'|([^\\s><]+))''',
  caseSensitive: false,
);

/// Inline tags that map onto a symmetric markdown fence.
const _kInlineFences = <String, String>{
  'strong': '**',
  'b': '**',
  'em': '*',
  'i': '*',
  // super_editor's own `UnderlineSyntax` — markdown has no underline.
  'u': '¬',
  's': '~~',
  'strike': '~~',
  'del': '~~',
  'code': '`',
};

final _kInlineFencePattern = RegExp(
  '</?(${_kInlineFences.keys.join('|')})$_kAttrs'
  r'\s*/?>',
  caseSensitive: false,
);

/// Block-level tags that `markdown`'s `HtmlBlockSyntax` would treat as the
/// start of a raw HTML block (CommonMark condition 6, mirrored from
/// `markdown/lib/src/patterns.dart`), minus the list tags handled separately
/// below, plus `br` and `pre`.
///
/// `script`, `style` and `textarea` are intentionally absent. They are
/// raw-text elements that end at their own closing tag, so the deserializer
/// drops exactly them and nothing else — and their content is machinery, not
/// prose, so that is the right outcome. `pre` is the same kind of element but
/// holds text the user typed, so it is mapped (losing the monospace block,
/// keeping the words).
const _kBlockTags = <String>{
  'address',
  'article',
  'aside',
  'base',
  'basefont',
  'blockquote',
  'body',
  'br',
  'caption',
  'center',
  'col',
  'colgroup',
  'dd',
  'details',
  'dialog',
  'dir',
  'div',
  'dl',
  'dt',
  'fieldset',
  'figcaption',
  'figure',
  'footer',
  'form',
  'frame',
  'frameset',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'head',
  'header',
  'hr',
  'html',
  'iframe',
  'legend',
  'link',
  'main',
  'menu',
  'menuitem',
  'nav',
  'noframes',
  'optgroup',
  'option',
  'p',
  'param',
  'pre',
  'section',
  'source',
  'summary',
  'table',
  'tbody',
  'td',
  'tfoot',
  'th',
  'thead',
  'title',
  'tr',
  'track',
};

final _kHeadingPattern = RegExp(r'^h([1-6])$');

/// Rewrites legacy HTML in [input] into markdown super_editor can parse.
///
/// Safe to call on content that is already markdown (or plain text): the
/// user's own blank lines are copied through verbatim. Only the breaks this
/// function *introduces* are merged, and they are merged as they are emitted
/// rather than by a regex sweep at the end — a sweep can't tell a run it
/// created from one the user typed, and super_editor preserves every blank
/// line as an empty paragraph node, so the difference is visible.
String markdownFromLegacyHtml(String input) {
  if (!input.contains('<')) return input.trim();

  var text = input.replaceAllMapped(_kAnchorPattern, (match) {
    final href = _hrefOf(match.group(1) ?? '');
    final label = match.group(2) ?? '';
    return href.isEmpty ? label : '[$label]($href)';
  });
  text = text.replaceAllMapped(
    _kInlineFencePattern,
    (match) => _kInlineFences[match.group(1)!.toLowerCase()]!,
  );

  final out = _MarkdownWriter();
  // One entry per open <ul>/<ol>; true == ordered. Drives the marker an <li>
  // emits and how far it is indented.
  final listStack = <bool>[];
  var cursor = 0;

  for (final match in _kHtmlTagPattern.allMatches(text)) {
    final tag = match.group(2)!.toLowerCase();
    final isList = tag == 'ul' || tag == 'ol';
    if (!isList && tag != 'li' && !_kBlockTags.contains(tag)) {
      // An inline tag with no mapping (`<span>`, `<font>`, …). Leaving it is
      // imperfect — it renders literally — but deleting it could take
      // meaningful text with it, and it can't swallow a block.
      continue;
    }

    // Whitespace between two block tags is HTML source formatting, not
    // content: TinyMCE pretty-prints `</p>\n<p>`, and copying that newline
    // through would add an empty paragraph on top of the break below.
    final between = text.substring(cursor, match.start);
    if (between.trim().isNotEmpty) out.writeText(between);
    cursor = match.end;
    final isClosing = match.group(1) == '/';

    if (isList) {
      final bool topLevel;
      if (isClosing) {
        if (listStack.isNotEmpty) listStack.removeLast();
        topLevel = listStack.isEmpty;
      } else {
        topLevel = listStack.isEmpty;
        listStack.add(tag == 'ol');
      }
      // A top-level list needs a blank line separating it from the surrounding
      // paragraphs. A nested one asks for nothing: the `<li>` that follows
      // brings its own line break, and a blank line here would make the list
      // loose and detach the sub-list from its parent item.
      if (topLevel) out.requestBreak(2);
      continue;
    }

    if (tag == 'li') {
      // `</li>` asks for nothing — the next `<li>` opens its own line.
      if (isClosing) continue;
      final ordered = listStack.isNotEmpty && listStack.last;
      out
        ..requestBreak(1)
        ..writeText(' ' * _ancestorIndent(listStack))
        ..writeText(ordered ? '1. ' : '- ')
        ..holdBreaks();
      continue;
    }

    final heading = _kHeadingPattern.firstMatch(tag);
    if (heading != null) {
      out.requestBreak(2);
      if (!isClosing) {
        out
          ..writeText('${'#' * int.parse(heading.group(1)!)} ')
          ..holdBreaks();
      }
      continue;
    }

    if (tag == 'hr') {
      out
        ..requestBreak(2)
        ..writeText('---')
        ..requestBreak(2);
      continue;
    }

    // `<br>` is a line break inside a paragraph; every other block tag is a
    // paragraph boundary and needs the blank line that separates two markdown
    // paragraphs — except inside a list, where TinyMCE's `<li><p>…</p></li>`
    // would otherwise put a blank line between every item and make the whole
    // list loose. A single break there is a lazy continuation of the item.
    out.requestBreak(tag == 'br' || listStack.isNotEmpty ? 1 : 2);
  }
  final tail = text.substring(cursor);
  if (tail.trim().isNotEmpty) out.writeText(tail);

  return out.toString().trim();
}

/// Accumulates markdown while merging the line breaks the rewriter asks for.
///
/// Breaks are *requested*, not written: the largest request wins, it is
/// resolved against the newlines already at the end of the buffer, and it is
/// flushed only when real text arrives. That is what keeps `</p><p>` from
/// stacking two breaks into an empty paragraph, keeps a leading break from
/// ever being emitted, and lets a marker sit flush against the text that
/// follows it.
class _MarkdownWriter {
  final _buffer = StringBuffer();

  /// Newlines currently at the end of [_buffer].
  int _trailing = 0;

  /// Largest break requested since the last write, in newlines.
  int _pending = 0;

  /// True between a list/heading marker and the text that belongs to it, while
  /// break requests are ignored. TinyMCE writes `<li><p>One</p></li>`, and
  /// honouring that `<p>` would strand the marker on a line of its own — which
  /// CommonMark reads as an empty list item plus an unrelated paragraph.
  bool _holding = false;

  bool _wroteAnything = false;

  void requestBreak(int newlines) {
    if (_holding) return;
    if (newlines > _pending) _pending = newlines;
  }

  /// Suppress break requests until the next text arrives.
  void holdBreaks() => _holding = true;

  void writeText(String text) {
    if (text.isEmpty) return;
    final needed = _pending - _trailing;
    if (_wroteAnything && needed > 0) {
      _buffer.write('\n' * needed);
      _trailing += needed;
    }
    _pending = 0;
    _buffer.write(text);
    _wroteAnything = true;
    if (text.trim().isNotEmpty) _holding = false;

    var run = 0;
    while (run < text.length &&
        text.codeUnitAt(text.length - 1 - run) == 0x0A) {
      run++;
    }
    _trailing = run == text.length ? _trailing + run : run;
  }

  @override
  String toString() => _buffer.toString();
}

/// Total width of the markers of every list enclosing the innermost one, so a
/// nested item lines up with its parent's content column — 2 for `- `, 3 for
/// `1. `. Indent too little and the sub-list flattens into its parent.
int _ancestorIndent(List<bool> listStack) {
  var indent = 0;
  for (var i = 0; i < listStack.length - 1; i++) {
    indent += listStack[i] ? 3 : 2;
  }
  return indent;
}

String _hrefOf(String attributes) {
  final match = _kHrefPattern.firstMatch(attributes);
  if (match == null) return '';
  return match.group(1) ?? match.group(2) ?? match.group(3) ?? '';
}
