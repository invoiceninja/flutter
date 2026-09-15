/// The HTML that `public_notes` / `private_notes` / `terms` / `footer` carry
/// on the wire, in the two directions that don't involve the editor.
///
/// These fields are **HTML** everywhere in the Invoice Ninja ecosystem: the
/// React client edits them with TipTap and saves `editor.getHTML()`, every one
/// of its read-only views injects the stored string with
/// `dangerouslySetInnerHTML` into a `white-space: normal` container, the client
/// portal renders `{!! html_entity_decode(e($public_notes)) !!}`, and the
/// server sanitizes each of them through `Purify::clean` on write
/// (`app/Http/Requests/Request.php:212`), whose whitelist is an editor-output
/// one. A bare `\n` is insignificant whitespace to all of them — which is why
/// a pasted email lost its paragraphs on the web (invoiceninja/flutter#159).
///
/// The editor's own conversion is `htmlFromEditorDocument` (`editor_html.dart`);
/// this file covers the surfaces that have no editor: a plain text field whose
/// value must still reach the wire as HTML ([htmlFromPlainText]), and every
/// read-only render of a stored value ([plainTextFromHtml]). Inbound *to* the
/// editor is `markdownFromLegacyHtml` (`legacy_html_markdown.dart`).
///
/// **Nothing here ever emits a newline.** `HtmlEngine.php` runs `nl2br()` over
/// these fields on the PDF path, so a `\n` between two block tags would render
/// as an extra blank line in the invoice. The server gives the React client the
/// same guarantee from the other side, by deleting every `\n` from a payload
/// carrying `X-REACT` (`StoreInvoiceRequest.php:160`); we don't send that
/// header, so the guarantee has to hold here.
library;

import 'package:admin/l10n/transifex_php_parser.dart' show decodeHtmlEntities;
import 'package:admin/utils/legacy_html_markdown.dart';

/// Escapes [text] for use in HTML character data.
///
/// `$` is deliberately untouched: these fields carry `$client.name`-style
/// template variables, and the server substitutes them by literal match.
String escapeHtmlText(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

/// Escapes [value] for use inside a double-quoted HTML attribute.
String escapeHtmlAttribute(String value) =>
    escapeHtmlText(value).replaceAll('"', '&quot;');

/// Renders plain [text] as the HTML these fields expect.
///
/// A blank line starts a new `<p>`; a single newline is a `<br>` inside the
/// current one. Markdown is **not** interpreted — this is for fields the user
/// types as plain text from scratch — the Send Email *sheet*, the client
/// bulk-update note — so `5 * 3 * 2` stays `5 * 3 * 2` rather than turning
/// into emphasis.
///
/// A field that is *seeded* from a stored value instead (the Send Email
/// screen's body, a Custom gateway's `text` config) shows the fold's markdown,
/// so its way back out has to be the fold's inverse — `htmlFromEditableValue`
/// in `editor_html.dart`, not this.
///
/// Returns `''` for blank input, so an untouched field never becomes a
/// `<p></p>` that reads downstream as "the user entered something".
String htmlFromPlainText(String text) {
  if (text.trim().isEmpty) return '';
  final paragraphs = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split(RegExp(r'\n[ \t]*\n'));
  final buffer = StringBuffer();
  for (final paragraph in paragraphs) {
    final trimmed = paragraph.trim();
    if (trimmed.isEmpty) continue;
    buffer
      ..write('<p>')
      ..write(escapeHtmlText(trimmed).replaceAll('\n', '<br>'))
      ..write('</p>');
  }
  return buffer.toString();
}

/// The readable text of a stored notes value, for a read-only surface.
///
/// Keeps the line structure a reader needs (`<br>` and every block close
/// become newlines); [singleLine] collapses it for a table cell, which has one
/// line to spend anyway.
///
/// Plain text passes straight through — the same cheap `<`-free guard
/// `markdownFromLegacyHtml` uses, so a legacy value costs nothing and can't be
/// damaged by a pattern that was written for markup.
String plainTextFromHtml(String input, {bool singleLine = false}) {
  var text = input;
  if (text.contains('<')) {
    text = text.replaceAllMapped(kHtmlTagPattern, (match) {
      final tag = match.group(2)!.toLowerCase();
      if (tag == 'br') return '\n';
      return _kTextBlockTags.contains(tag) ? '\n\n' : '';
    });
  }
  text = decodeHtmlEntities(text);
  if (singleLine) return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

/// Tags whose boundary is a paragraph break when markup is flattened to text.
/// `br` is handled separately (one newline, not two).
const _kTextBlockTags = <String>{
  'address',
  'blockquote',
  'dd',
  'div',
  'dt',
  'figcaption',
  'figure',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'hr',
  'li',
  'ol',
  'p',
  'pre',
  'section',
  'table',
  'tr',
  'ul',
};
