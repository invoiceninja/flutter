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

import 'package:admin/l10n/transifex_php_parser.dart' show decodeHtmlEntities;

/// The attribute list of an HTML tag — `\s+name="value"`, repeated.
///
/// Requiring `=` **and** a value is what keeps this from matching prose.
/// A permissive tail (`[^<>]*`) turns any `<` followed by a block-tag word
/// into a tag: `'qty < table rate > 10'` and `'mail <form@x.com> now'` both
/// lose everything between the brackets, silently and permanently. Valueless
/// attributes (`<td nowrap>`) are legal but neither TinyMCE nor Quill emits
/// them, so the trade is worth it. Quoted values may contain `<` and `>`.
const kHtmlAttrs = r'''(?:\s+[^\s>/=<]+\s*=\s*(?:"[^"]*"|'[^']*'|[^\s><]+))*''';

/// One HTML tag: `<p>`, `</p>`, `<p/>`, `<br />`, `<li dir="ltr">`, …
///
/// Note there is no `\s*` after `<` — no HTML producer emits `< p>`, and
/// requiring the name to abut the bracket is half of what makes prose safe.
final kHtmlTagPattern = RegExp(
  '<(/?)([a-zA-Z][a-zA-Z0-9]*)$kHtmlAttrs'
  r'\s*/?>',
);

/// `<a href="…">text</a>`, non-greedy (anchors can't nest) and `dotAll` so a
/// link label may wrap across lines.
final _kAnchorPattern = RegExp(
  '<a\\b($kHtmlAttrs)\\s*>(.*?)</a\\s*>',
  caseSensitive: false,
  dotAll: true,
);

/// `<img src="…" alt="…">`. Self-closed or not, like every other void tag.
final _kImagePattern = RegExp(
  '<img\\b($kHtmlAttrs)\\s*/?>',
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
  '</?(${_kInlineFences.keys.join('|')})$kHtmlAttrs'
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
  // `<img>` has a markdown equivalent, and without this rule it would fall
  // through the tag loop as an unmapped inline tag and be painted to the user
  // as raw markup. Reachable both ways: the editor's own
  // `ImageUrlConversionReaction` creates images, and the other clients store
  // them.
  text = text.replaceAllMapped(_kImagePattern, (match) {
    final attrs = match.group(1) ?? '';
    final src = _attributeOf(attrs, 'src');
    if (src.isEmpty) return '';
    return '![${_attributeOf(attrs, 'alt')}]($src)';
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
  // True between a `<p>` and its `</p>` while no text has been written — the
  // shape a deliberately blank line takes in every HTML editor.
  var openParagraphIsEmpty = false;

  for (final match in kHtmlTagPattern.allMatches(text)) {
    final tag = match.group(2)!.toLowerCase();
    final isList = tag == 'ul' || tag == 'ol';
    final isUnmappedInline =
        !isList && tag != 'li' && !_kBlockTags.contains(tag);

    // Whitespace between two block tags is HTML source formatting, not
    // content: TinyMCE pretty-prints `</p>\n<p>`, and copying that newline
    // through would add an empty paragraph on top of the break below.
    final between = text.substring(cursor, match.start);
    if (between.trim().isNotEmpty) {
      out.writeText(between);
      openParagraphIsEmpty = false;
    }
    cursor = match.end;
    final isClosing = match.group(1) == '/';

    // An inline tag with no markdown equivalent (`<span style=…>`, `<font>`,
    // `<mark>`): drop the tag, keep the text between its ends. It used to be
    // left in place, which round-tripped only by accident — the literal tag
    // went back to the server and the browser re-parsed it — while the user
    // saw raw markup in the editor the whole time. Now that this app writes
    // HTML, leaving it would be worse still: the writer escapes text, so the
    // tag would reach the web app as a visible `&lt;span …&gt;`. The span's
    // own colour or size is the price; the words are what matter, and the
    // pattern above is conservative enough that only a real tag is dropped.
    if (isUnmappedInline) continue;

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
      // `</li>` asks for nothing — the next `<li>` opens its own line. It does
      // have to release the hold, though: an item that closed with no text in it
      // would otherwise go on suppressing breaks for the whole rest of the
      // document. See [_MarkdownWriter.releaseBreaks].
      if (isClosing) {
        out.releaseBreaks();
        continue;
      }
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
      // Release before the request, not after: `requestBreak` is a no-op while
      // held, so an empty `<h2></h2>` would otherwise swallow its own closing
      // break along with every one after it.
      if (isClosing) out.releaseBreaks();
      out.requestBreak(2);
      if (!isClosing) {
        out
          ..writeText('${'#' * int.parse(heading.group(1)!)} ')
          ..holdBreaks();
      }
      continue;
    }

    if (tag == 'blockquote') {
      // Markdown's `>` marker, laid out exactly like a heading's `#`: request
      // the paragraph break first, then hold breaks so the `<p>` TinyMCE nests
      // inside can't strand the marker on a line of its own. Without this the
      // quote silently degraded to a plain paragraph on the next edit.
      //
      // Release before the request for the same reason the heading arm does: an
      // empty `<blockquote></blockquote>` would otherwise hold its own closing
      // break and every one that followed.
      if (isClosing) out.releaseBreaks();
      out.requestBreak(2);
      if (!isClosing) {
        out
          ..writeText('> ')
          ..holdBreaks();
      }
      continue;
    }

    if (tag == 'p' && listStack.isEmpty) {
      if (isClosing) {
        // A `<p></p>` holding nothing is how an HTML editor stores a
        // deliberately blank line, and dropping it would quietly close up a
        // gap the user typed. Four newlines is exactly one empty
        // `ParagraphNode` to super_editor's `_EmptyLinePreservingParagraphSyntax`
        // — two blank lines, not one. A leading or trailing run still emits
        // nothing: the writer suppresses a break before any text, and a
        // pending break with no text after it is never flushed.
        out.requestBreak(openParagraphIsEmpty ? 4 : 2);
        openParagraphIsEmpty = false;
      } else {
        openParagraphIsEmpty = true;
        out.requestBreak(2);
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

    // `<br>` is a line break the author typed inside a paragraph, so it
    // *accumulates* — see [_MarkdownWriter.requestHardBreak], and note that a
    // closing `</br>` is legacy data for the same thing (`one</br>two`).
    //
    // `inList` is not optional: the clamp the block arm below applies inside a
    // list has to apply here too, or a double break inside an item splits the
    // list in half. It is passed rather than inferred because the writer has no
    // idea where in the document it is.
    if (tag == 'br') {
      out.requestHardBreak(inList: listStack.isNotEmpty);
      continue;
    }
    // Every other block tag is a paragraph boundary and needs the blank line
    // that separates two markdown paragraphs — except inside a list, where
    // TinyMCE's `<li><p>…</p></li>` would otherwise put a blank line between
    // every item and make the whole list loose. A single break there is a lazy
    // continuation of the item.
    out.requestBreak(listStack.isNotEmpty ? 1 : 2);
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

  /// Largest **block-boundary** break requested since the last write, in
  /// newlines. Merged rather than summed, because `</p><p>` asks twice for the
  /// one boundary it describes.
  int _pending = 0;

  /// How many consecutive **author-typed** `<br>`s have arrived since the last
  /// write. Counted separately from [_pending] and resolved against it as a max,
  /// so two `<br>`s are two newlines while a `<br>` that merely decorates a
  /// block boundary (`</p><br>`) adds nothing to it.
  int _pendingBreaks = 0;

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

  /// A break the **author typed** (`<br>`), which *adds* to any pending break
  /// instead of being merged into it.
  ///
  /// [requestBreak] takes the larger of the two because `</p><p>` asks twice for
  /// the one paragraph boundary it describes. Consecutive `<br>`s are the
  /// opposite: each one is a separate break the author put there, and taking the
  /// max silently collapsed `a<br><br>b` to `a\nb` — the same markdown
  /// `a<br>b` folds to, so the blank line was gone by the next save.
  ///
  /// That was not an edge case. Every server default email body is
  /// `'<p>$client<br><br>' . <message> . '</p>…'`
  /// (`EmailTemplateDefaults.php`), so editing one word of any template dropped
  /// the blank line after the greeting from every mail that company then sent.
  ///
  /// Counted separately from [requestBreak] and resolved against it as a max, so
  /// a `<br>` that merely decorates a boundary the block tags already asked for
  /// (`</p><br><p>`) does not push it a line wider.
  ///
  /// [inList] clamps the whole run to **one** newline, which is the same lazy
  /// continuation the block arm uses inside a list and is not an approximation:
  /// a blank line closes the item's paragraph, and the text after it is not
  /// indented to the item's content column, so CommonMark ends the list there.
  /// `<ol><li>a<br><br>b</li><li>c</li></ol>` would otherwise re-emit as
  /// `<ol><li>a</li></ol><p>b</p><ol><li>c</li></ol>` — **`c` numbered 1 again**
  /// in the rendered PDF. TinyMCE writes that shape for two Shift+Enters in an
  /// item, and `editor_html.dart` writes it for a `ListItemNode` holding
  /// `a\n\nb`, so the app feeds itself the trigger.
  ///
  /// Outside a list the run resolves to one of the values the encoding actually
  /// defines — 1 (a soft break inside a paragraph), 2 (a paragraph boundary) or
  /// 4 (a paragraph plus one deliberately blank one, see the `</p>` arm). **3 is
  /// skipped deliberately**: super_editor reads two blank lines followed by text
  /// as a single paragraph whose text begins with a newline, which re-emits as
  /// `<p>a</p><p><br>b</p>` and folds back to 2 — so three author breaks would
  /// survive one save and lose one on the next.
  void requestHardBreak({required bool inList}) {
    if (_holding) return;
    final cap = inList ? 1 : 4;
    if (_pendingBreaks >= cap) return;
    _pendingBreaks++;
    if (_pendingBreaks == 3) _pendingBreaks = 4;
  }

  /// Suppress break requests until the next text arrives.
  void holdBreaks() => _holding = true;

  /// Stop suppressing break requests: the construct that called [holdBreaks]
  /// has closed, so what follows is no longer its content.
  ///
  /// [writeText] also clears the flag, which covers every marker construct that
  /// contains text. One that contains **none** had nothing to clear it, and
  /// because [requestBreak] is a no-op while held, the flag then suppressed
  /// every break for the rest of the document: `<ul><li></li></ul><p>Next</p>`
  /// folded to `- Next`, turning the paragraph after the list into a bullet, and
  /// a blank bullet between two items pulled the next one into a nested list.
  /// `<li><p></p></li>` is exactly what TinyMCE writes for an emptied item, and
  /// `editor_html.dart` writes `<li></li>` for one too, so the app fed itself the
  /// trigger.
  void releaseBreaks() => _holding = false;

  void writeText(String text) {
    if (text.isEmpty) return;
    final wanted = _pending > _pendingBreaks ? _pending : _pendingBreaks;
    final needed = wanted - _trailing;
    if (_wroteAnything && needed > 0) {
      _buffer.write('\n' * needed);
      _trailing += needed;
    }
    _pending = 0;
    _pendingBreaks = 0;
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

final _kAttributePatterns = <String, RegExp>{};

String _hrefOf(String attributes) => _attributeOf(attributes, 'href');

/// The value of [name] in an HTML attribute list, quoted or bare; `''` when
/// absent.
///
/// Entities are resolved here even though the rest of this file deliberately
/// leaves them to `markdown`'s `DecodeHtmlSyntax` downstream: a URL is data,
/// not markup, and nothing downstream decodes inside a markdown link
/// destination — so `?a=1&amp;b=2` would otherwise come back with the `&amp;`
/// still in it, one more entity on every round trip.
String _attributeOf(String attributes, String name) {
  final pattern = _kAttributePatterns.putIfAbsent(
    name,
    () => RegExp(
      '''\\b$name\\s*=\\s*(?:"([^"]*)"|'([^']*)'|([^\\s><]+))''',
      caseSensitive: false,
    ),
  );
  final match = pattern.firstMatch(attributes);
  if (match == null) return '';
  final raw = match.group(1) ?? match.group(2) ?? match.group(3) ?? '';
  return decodeHtmlEntities(raw);
}
