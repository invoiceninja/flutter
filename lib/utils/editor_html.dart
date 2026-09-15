/// Serializes a super_editor [Document] to the HTML these note fields carry on
/// the wire. The inverse of `markdownFromLegacyHtml`
/// (`legacy_html_markdown.dart`), which is what brings HTML back *in*.
///
/// **Why HTML and not the markdown the editor speaks internally.**
/// `public_notes` / `private_notes` / `terms` / `footer` are HTML to every
/// other participant: React saves `editor.getHTML()`, its read-only views and
/// the client portal inject the string as markup, and the server runs it
/// through `Purify::clean` on write. Markdown is honoured only when a company
/// sets `markdown_enabled`, which defaults to **false**
/// (`CompanyFactory.php:50`) — so what this app used to send rendered as run
/// together text with literal `**asterisks**` (invoiceninja/flutter#159).
/// `notes_html.dart` carries the rest of that evidence.
///
/// **Why a document walker and not `serializeDocumentToMarkdown` +
/// `markdownToHtml`.** super_editor's markdown serializer escapes nothing, so
/// a paragraph whose plain text is `5 * 3 * 2`, `# 1 priority`, `- see below`
/// or `a_b_c` serializes verbatim — and re-parsing that as markdown would turn
/// the user's own words into emphasis, a heading or a list, and then *persist*
/// the result. Reading the document's own node types and attributions instead
/// means nothing in the text can ever be promoted to markup. It also keeps the
/// output free of super_editor's private markdown dialect (`¬underline¬`,
/// `~strike~`, `:---:` alignment rows, `![a](u =100x50)` size notation), none
/// of which any other client understands.
///
/// **The output never contains a newline.** `HtmlEngine.php` runs `nl2br()`
/// over these fields on the PDF path, so a `\n` between two block tags renders
/// as an extra blank line on the invoice. The server strips every `\n` from a
/// React payload for exactly this reason (`StoreInvoiceRequest.php:160`); we
/// don't send the `X-REACT` header that triggers it, so the guarantee has to
/// hold here. `editor_html_test.dart` asserts it over every construct.
///
/// Byte-stability across a server round trip is not a goal and is not
/// achievable — `Purify::clean` reparses with `DOMDocument` and re-serializes,
/// so `<br>` and attribute order are its call. The invariant that matters is
/// that `htmlFromEditorDocument(deserialize(markdownFromLegacyHtml(v)))` is a
/// fixed point, so opening and saving a record doesn't churn it.
library;

import 'package:super_editor/super_editor.dart';

import 'package:admin/utils/legacy_html_markdown.dart';
import 'package:admin/utils/notes_html.dart';

/// Canonical HTML for a value held by a field that has **no editor behind it**
/// but *is* seeded from a stored one — the ad-hoc Send Email body, a Custom
/// gateway's `text` config.
///
/// Those fields show `markdownFromLegacyHtml`'s output so the user reads words
/// rather than tags, which means whatever comes back is markdown; this is its
/// inverse, so a template that is customised and sent untouched arrives exactly
/// as it was stored. Escaping it as plain text instead is not the inverse and
/// silently destroyed the formatting: `<strong>` came back as `**Bob**`, a
/// `<ul>` as `- One<br>- Two`, and an `<a href>` as a literal
/// `[label](url)` — a dead link.
///
/// The fold runs **first**, not just the parse: the user can paste HTML into a
/// plain field, and handing raw HTML to the deserializer is the #107 failure —
/// a block tag takes its whole block out of the document. Folding first makes
/// this total, and idempotent, for markdown, HTML and plain text alike.
///
/// A field that is *always* typed from scratch — the Send Email sheet, the
/// client bulk-update note — uses `htmlFromPlainText` instead, which never
/// re-reads the user's own words as markdown.
String htmlFromEditableValue(String value) => htmlFromEditorDocument(
  deserializeMarkdownToDocument(markdownFromLegacyHtml(value)),
);

/// Renders [document] as the HTML to store.
///
/// Returns `''` for an empty document — an untouched field must not become a
/// `<p></p>` that reads downstream as "the user entered something".
String htmlFromEditorDocument(Document document) {
  final nodes = document.toList(growable: false);
  final buffer = StringBuffer();

  // Leading and trailing blank paragraphs are the editor's own padding, not
  // content; only an interior one is a blank line somebody typed.
  var first = 0;
  var last = nodes.length - 1;
  while (first <= last && _isBlankParagraph(nodes[first])) {
    first++;
  }
  while (last >= first && _isBlankParagraph(nodes[last])) {
    last--;
  }

  var i = first;
  while (i <= last) {
    final node = nodes[i];
    if (node is ListItemNode) {
      final run = <ListItemNode>[];
      while (i <= last && nodes[i] is ListItemNode) {
        run.add(nodes[i] as ListItemNode);
        i++;
      }
      var cursor = 0;
      while (cursor < run.length) {
        cursor = _writeList(buffer, run, cursor, run[cursor].indent);
      }
      continue;
    }
    _writeBlock(buffer, node);
    i++;
  }
  return buffer.toString();
}

bool _isBlankParagraph(DocumentNode node) =>
    node is ParagraphNode && node.text.toPlainText().trim().isEmpty;

void _writeBlock(StringBuffer buffer, DocumentNode node) {
  if (node is ParagraphNode) {
    final blockType = node.getMetadataValue('blockType');
    final heading = _kHeadingTags[blockType];
    if (heading != null) {
      buffer.write('<$heading>');
      _writeAttributed(buffer, node.text);
      buffer.write('</$heading>');
      return;
    }
    if (blockType == blockquoteAttribution) {
      buffer.write('<blockquote><p>');
      _writeAttributed(buffer, node.text);
      buffer.write('</p></blockquote>');
      return;
    }
    if (blockType == codeAttribution) {
      // Plain text, and the trailing newline the fence parser leaves behind is
      // dropped: as a `<br>` it would render an empty last line every time the
      // block was re-saved. Code blocks carry no inline marks.
      final code = node.text.toPlainText().replaceAll(RegExp(r'\n+$'), '');
      buffer
        ..write('<pre><code>')
        ..write(escapeHtmlText(code).replaceAll('\n', '<br>'))
        ..write('</code></pre>');
      return;
    }
    buffer.write('<p>');
    _writeAttributed(buffer, node.text);
    buffer.write('</p>');
    return;
  }

  if (node is TaskNode) {
    // Not reachable from this app's toolbar, but `- [ ] x` in pasted markdown
    // deserializes to one. The marker is kept as text so the fold turns it
    // back into a task rather than a plain bullet.
    buffer.write('<ul><li>');
    buffer.write(node.isComplete ? '[x] ' : '[ ] ');
    _writeAttributed(buffer, node.text);
    buffer.write('</li></ul>');
    return;
  }

  if (node is HorizontalRuleNode) {
    buffer.write('<hr>');
    return;
  }

  if (node is ImageNode) {
    buffer
      ..write('<img src="')
      ..write(escapeHtmlAttribute(node.imageUrl))
      ..write('" alt="')
      ..write(escapeHtmlAttribute(node.altText))
      ..write('">');
    return;
  }

  if (node is TableBlockNode) {
    _writeTable(buffer, node);
    return;
  }

  // Anything else contributes no text; dropping it is better than emitting a
  // tag no consumer whitelists.
}

void _writeTable(StringBuffer buffer, TableBlockNode node) {
  if (node.rowCount == 0) return;
  buffer.write('<table>');
  for (var row = 0; row < node.rowCount; row++) {
    if (row == 0) buffer.write('<thead>');
    if (row == 1) buffer.write('<tbody>');
    buffer.write('<tr>');
    final cellTag = row == 0 ? 'th' : 'td';
    for (final cell in node.getRow(row)) {
      buffer.write('<$cellTag>');
      _writeAttributed(buffer, cell.text);
      buffer.write('</$cellTag>');
    }
    buffer.write('</tr>');
    if (row == 0) buffer.write('</thead>');
  }
  if (node.rowCount > 1) buffer.write('</tbody>');
  buffer.write('</table>');
}

/// Writes the list starting at [index], consuming every item at [depth] or
/// deeper, and returns the index of the first item it did not consume.
///
/// Markdown lets the serializer punt on nesting — it writes indented markers
/// and lets CommonMark re-derive the tree. HTML has to nest for real, and a
/// deeper run belongs *inside* the `<li>` above it, not beside it.
int _writeList(
  StringBuffer buffer,
  List<ListItemNode> items,
  int index,
  int depth,
) {
  final type = items[index].type;
  final tag = type == ListItemType.ordered ? 'ol' : 'ul';
  buffer.write('<$tag>');
  var i = index;
  while (i < items.length && items[i].indent >= depth) {
    if (items[i].indent > depth) {
      // A deeper item with no shallower item before it — only reachable from
      // malformed input. Nest it rather than dropping it.
      i = _writeList(buffer, items, i, items[i].indent);
      continue;
    }
    if (items[i].type != type) break;
    buffer.write('<li>');
    _writeAttributed(buffer, items[i].text);
    i++;
    while (i < items.length && items[i].indent > depth) {
      i = _writeList(buffer, items, i, items[i].indent);
    }
    buffer.write('</li>');
  }
  buffer.write('</$tag>');
  return i;
}

// Not `const`: `NamedAttribution` overrides `==`, which a const map key
// may not do.
final _kHeadingTags = <Attribution, String>{
  header1Attribution: 'h1',
  header2Attribution: 'h2',
  header3Attribution: 'h3',
  header4Attribution: 'h4',
  header5Attribution: 'h5',
  header6Attribution: 'h6',
};

void _writeAttributed(StringBuffer buffer, AttributedText text) =>
    _InlineHtmlWriter(buffer).write(text);

/// Turns one [AttributedText] into inline HTML.
///
/// Mirrors super_editor's own `AttributedTextMarkdownSerializer` step for step
/// — same visitor, same open/close ordering, link marker outside the style
/// marks — so a span this app can produce is a span this writer can express.
class _InlineHtmlWriter extends AttributionVisitor {
  _InlineHtmlWriter(this._buffer);

  final StringBuffer _buffer;

  /// Tag names currently open, outermost first.
  final _open = <String>[];

  /// The full opening tag for each entry in [_open] — an `<a>` carries its
  /// href, so reopening it after an overlap needs more than the name.
  ///
  /// Keyed by tag, which means two *differently addressed* links overlapping
  /// each other would reopen with the wrong href. super_editor's link tooling
  /// replaces a span rather than overlapping one, so that shape isn't
  /// reachable from this app; anything that starts producing it has to key
  /// this by the markup instead.
  final _openMarkup = <String, String>{};

  late String _fullText;
  var _cursor = 0;

  void write(AttributedText text) {
    _fullText = text.toPlainText();
    _cursor = 0;
    if (_fullText.isEmpty) return;
    // `visitAttributions` calls `onVisitEnd` itself once the last marker is
    // visited (`attributed_text.dart:680`) — including when there are no
    // markers at all, which is how a plain paragraph gets written.
    text.visitAttributions(this);
  }

  @override
  void visitAttributions(
    AttributedText fullText,
    int index,
    Set<Attribution> startingAttributions,
    Set<Attribution> endingAttributions,
  ) {
    _writeText(_fullText.substring(_cursor, index));

    if (startingAttributions.isNotEmpty) {
      // The link wraps the style marks, matching the markdown serializer's
      // `[**bold**](url)`.
      final link = startingAttributions
          .whereType<LinkAttribution>()
          .firstOrNull;
      if (link != null) {
        // Only a scheme the consumers keep: the server's `Purify` allows
        // `http(s)://`, `data:image/` and `$var` hrefs, and React runs
        // DOMPurify. A `javascript:` destination — reachable by pasting
        // markdown — would be stripped downstream anyway, so drop the anchor
        // here rather than store something that renders as a dead tag.
        if (_isSafeHref(link.plainTextUri)) {
          _push('a', '<a href="${escapeHtmlAttribute(link.plainTextUri)}">');
        }
      }
      for (final attribution in _kStyleOrder) {
        if (!startingAttributions.contains(attribution)) continue;
        final tag = _kStyleTags[attribution]!;
        _push(tag, '<$tag>');
      }
    }

    _writeText(_fullText[index]);
    _cursor = index + 1;

    if (endingAttributions.isNotEmpty) {
      for (final attribution in _kStyleOrder.reversed) {
        if (!endingAttributions.contains(attribution)) continue;
        _pop(_kStyleTags[attribution]!);
      }
      if (endingAttributions.whereType<LinkAttribution>().isNotEmpty) {
        // A no-op when the opener was refused above.
        _pop('a');
      }
    }
  }

  @override
  void onVisitEnd() {
    if (_cursor < _fullText.length) {
      _writeText(_fullText.substring(_cursor));
      _cursor = _fullText.length;
    }
    // Defensive: a span whose end marker never arrived would otherwise leave
    // an unclosed tag for the server's DOM parser to guess at.
    while (_open.isNotEmpty) {
      _buffer.write('</${_open.removeLast()}>');
    }
  }

  void _push(String tag, String markup) {
    _open.add(tag);
    _openMarkup[tag] = markup;
    _buffer.write(markup);
  }

  /// Closes [tag], reopening anything that was nested inside it.
  ///
  /// super_editor can hold *partially* overlapping spans — bold over 0-5 and
  /// italics over 3-8 — which markdown tolerates as `**a*b**c*` and HTML does
  /// not. Closing the tags above it and reopening them keeps the output
  /// well-formed; for the strictly nested case (everything the toolbar
  /// produces) this is the naive close.
  void _pop(String tag) {
    final index = _open.lastIndexOf(tag);
    if (index < 0) return;
    final reopen = <String>[];
    while (_open.length - 1 > index) {
      final above = _open.removeLast();
      _buffer.write('</$above>');
      reopen.add(above);
    }
    _open.removeLast();
    _buffer.write('</$tag>');
    for (final above in reopen.reversed) {
      _push(above, _openMarkup[above]!);
    }
  }

  /// A newline inside a node is a soft line break — the shape the markdown
  /// serializer writes as a two-space hard break.
  void _writeText(String text) {
    if (text.isEmpty) return;
    _buffer.write(escapeHtmlText(text).replaceAll('\n', '<br>'));
  }
}

/// Whether [uri] is a destination the downstream sanitizers keep.
///
/// A relative link and a `$template.variable` are both fine — the server's
/// whitelist has a `$*.*` pattern for exactly that.
bool _isSafeHref(String uri) {
  final scheme = Uri.tryParse(uri)?.scheme.toLowerCase() ?? '';
  return scheme.isEmpty ||
      scheme == 'http' ||
      scheme == 'https' ||
      scheme == 'mailto' ||
      scheme == 'tel' ||
      (scheme == 'data' && uri.toLowerCase().startsWith('data:image/'));
}

/// Open order, mirroring `AttributedTextMarkdownSerializer`'s; closing runs in
/// reverse so the marks pair up.
const _kStyleOrder = <Attribution>[
  codeAttribution,
  boldAttribution,
  italicsAttribution,
  strikethroughAttribution,
  underlineAttribution,
];

final _kStyleTags = <Attribution, String>{
  codeAttribution: 'code',
  boldAttribution: 'strong',
  italicsAttribution: 'em',
  strikethroughAttribution: 's',
  underlineAttribution: 'u',
};
