/// The two halves of `MarkdownTextField`'s **HTML source mode**
/// (invoiceninja/flutter#174): deciding that a stored value contains a table,
/// and turning what the user typed in the source box into the string that goes
/// on the wire.
///
/// **Why there is a source mode at all.** The rich editor thinks in markdown,
/// and `markdownFromLegacyHtml` has no rule for a table — it cannot have one
/// that is faithful, because a markdown table carries no cell widths, no
/// alignment, no `colspan` and no block content inside a cell. So a three
/// column footer authored in the web app came back as three stacked
/// paragraphs, as one code block, or — when a tag was hand-written in a shape
/// the fold's strict pattern refuses — as nothing at all, and the first
/// keystroke stored that over the original. A value like that is shown as its
/// own HTML instead, verbatim, which is what React's source-code view and the
/// old Flutter app's plain text boxes both did.
///
/// Also here: the placeholders the box shows in place of embedded image data
/// ([elideDataPayloads]), which is display only and never reaches the wire.
///
/// The remaining question — "would the rich editor silently delete text from
/// this?" — is `richEditorCannotHold` in `editor_html.dart`, because answering
/// it needs the deserializer.
library;

import 'package:admin/utils/legacy_html_markdown.dart' show isHtmlBlockTag;

/// A table, in any part: `<table>`, a row, a cell, a column group.
///
/// **Deliberately permissive**, where `kHtmlTagPattern` is deliberately
/// strict, because the two errors cost opposite things. That pattern
/// *rewrites*, so matching prose (`qty < table rate > 10`) eats the user's
/// words; this one only *routes* — a false positive opens the field as source,
/// with the value exactly as stored, while a false negative hands a table to
/// an editor that flattens it. It therefore matches on the name alone and
/// never looks at the attributes, so `<td nowrap>` and a smart-quoted
/// `style=“width: 33%”` are caught here even though the fold refuses both.
/// (`<` still has to abut the name, so the prose example is not a match.)
final _kTableMarkup = RegExp(
  r'</?(?:table|thead|tbody|tfoot|tr|td|th|colgroup|col|caption)\b',
  caseSensitive: false,
);

/// Whether [source] contains table markup.
bool hasTableMarkup(String source) =>
    source.contains('<') && _kTableMarkup.hasMatch(source);

/// One tag in user-typed source: `<td>`, `</p>`, `<!-- note -->`.
///
/// Permissive for the same reason [_kTableMarkup] is — this only decides where
/// a line break sits, it never removes anything — but **quote-aware**, so a
/// `>` inside `title="a > b"` does not end the tag early and leave the rest of
/// the attribute to be read as text.
final _kSourceTag = RegExp(r'''<[!/?A-Za-z](?:"[^"]*"|'[^']*'|[^<>"'])*>''');

final _kSourceTagName = RegExp('^</?([A-Za-z][A-Za-z0-9]*)');

/// A run of whitespace that contains at least one line break.
final _kBreakRun = RegExp(r'[ \t]*\n\s*');

/// One line break and the indentation either side of it.
final _kOneBreak = RegExp(r'[ \t]*\n[ \t]*');

final _kLeadingSpace = RegExp(r'^\s+');
final _kTrailingSpace = RegExp(r'\s+$');

/// The string the source box sends, given the [text] the user sees in it.
///
/// **Identical to [text] unless it contains a line break.** The server runs
/// `nl2br()` over these fields on the PDF path (`HtmlEngine.php:823`) and
/// deletes newlines only from a request carrying `X-REACT`
/// (`UpdateInvoiceRequest.php:191`), which this app does not send. So a line
/// break between two tags — the first thing anyone does in a source box, to
/// make a table readable — would print as a blank line on the invoice, and
/// between two table rows as a blank line *above* the table, where a browser
/// hoists the stray `<br>`. Every other writer in this app already guarantees
/// its output has no newline (`notes_html.dart`); this is that guarantee for
/// the one writer whose input the user typed.
///
/// Where the break sits decides what it meant:
///
///  * **inside a tag** (an attribute list wrapped across lines) → one space;
///  * **beside a block-level tag or a `<br>`** — `</td>\n<td>`,
///    `<br>\n  Street` — is source formatting and is dropped, which is what
///    the server does for React and what HTML itself says about it;
///  * **between words, or beside an inline tag** — `Company\nStreet`,
///    `<b>Bob</b>\nThanks` — becomes `<br>`. That is what the PDF already
///    renders for it, and what the rich path writes for the same value, so an
///    edit made here cannot quietly join two lines of an address.
///
/// Inside `<pre>` every break is content; inside `<style>` / `<script>` none
/// is. The ends are trimmed, and the result is a fixed point.
String wireHtmlFromSource(String text) {
  final source = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (!source.contains('\n')) return source.trim();

  final out = StringBuffer();
  var cursor = 0;
  var preDepth = 0;
  var rawDepth = 0;
  // The start of the value is a boundary, like a block tag: a break there is
  // not between two words.
  var afterBoundary = true;

  void writeText(String run, {required bool beforeBoundary}) {
    if (run.isEmpty) return;
    if (!run.contains('\n')) {
      out.write(run);
    } else if (rawDepth > 0) {
      out.write(run.replaceAll(_kBreakRun, ' '));
    } else if (preDepth > 0) {
      out.write(run.replaceAll('\n', '<br>'));
    } else {
      final lead = _kLeadingSpace.stringMatch(run) ?? '';
      if (lead.length == run.length) {
        // Nothing but whitespace between two tags.
        out.write(_edge(run, atBoundary: afterBoundary || beforeBoundary));
      } else {
        final trail = _kTrailingSpace.stringMatch(run) ?? '';
        final core = run.substring(lead.length, run.length - trail.length);
        out
          ..write(_edge(lead, atBoundary: afterBoundary))
          ..write(core.replaceAll(_kOneBreak, '<br>'))
          ..write(_edge(trail, atBoundary: beforeBoundary));
      }
    }
  }

  for (final match in _kSourceTag.allMatches(source)) {
    final tag = match.group(0)!;
    final name = _kSourceTagName.firstMatch(tag)?.group(1)?.toLowerCase();
    // A comment or a doctype is formatting on both sides, like a block tag.
    final isBoundary = name == null || isHtmlBlockTag(name);
    writeText(
      source.substring(cursor, match.start),
      beforeBoundary: isBoundary,
    );
    out.write(tag.replaceAll(_kBreakRun, ' '));
    cursor = match.end;
    afterBoundary = isBoundary;

    final closing = tag.startsWith('</');
    if (name == 'pre') {
      preDepth = closing ? (preDepth > 0 ? preDepth - 1 : 0) : preDepth + 1;
    } else if (name == 'style' || name == 'script') {
      rawDepth = closing ? (rawDepth > 0 ? rawDepth - 1 : 0) : rawDepth + 1;
    }
  }
  writeText(source.substring(cursor), beforeBoundary: true);

  return out.toString().trim();
}

/// The whitespace at one end of a text run: dropped beside a boundary when it
/// holds a line break, one `<br>` per break otherwise, and left exactly as it
/// is when it holds none (a plain space between two inline tags is content).
String _edge(String space, {required bool atBoundary}) {
  if (!space.contains('\n')) return space;
  return atBoundary ? '' : '<br>' * '\n'.allMatches(space).length;
}

/// A base64 `data:` URI long enough to be a picture rather than a pixel: the
/// header, then the payload. 512 characters of payload is ~380 bytes of image —
/// below that the text is cheap to show and not worth a placeholder.
final _kDataPayload = RegExp(
  r'(data:[A-Za-z0-9.+/-]+;base64,)([A-Za-z0-9+/=]{512,})',
);

final _kDataPlaceholder = RegExp(r'\[base64-data-(\d+)-\d+KB\]');

/// [source] with every embedded image's base64 payload swapped for a short
/// placeholder — what the source box *shows* — and the payloads it took out.
///
/// The web app's image button embeds an upload as a `data:` URI (TipTap's
/// `allowBase64`), so a footer with a logo in it is one unbreakable "word"
/// several hundred KB long. A text field lays that out a character at a time
/// across thousands of wrapped lines: measured at **~2 s per keystroke** for
/// 300 KB, with the markup the user came to edit buried under a wall of
/// `AAAA…`. The placeholder (`[base64-data-1-300KB]`) costs nothing to lay out
/// and says what it stands for.
///
/// [restoreDataPayloads] puts them back before anything leaves the box, so the
/// value on the wire is the stored one. Plain ASCII on purpose: it has to
/// render in the bundled mono face, and it must not look like markup, a
/// template `$variable`, or Twig.
({String text, List<String> payloads}) elideDataPayloads(String source) {
  if (!source.contains(';base64,')) {
    return (text: source, payloads: const <String>[]);
  }
  final payloads = <String>[];
  final text = source.replaceAllMapped(_kDataPayload, (match) {
    final payload = match.group(2)!;
    payloads.add(payload);
    final kb = (payload.length * 3 / 4 / 1024).ceil();
    return '${match.group(1)}[base64-data-${payloads.length}-${kb}KB]';
  });
  return (text: text, payloads: payloads);
}

/// The inverse of [elideDataPayloads]: every placeholder in [text] replaced by
/// the payload it was standing for.
///
/// A placeholder the user deleted takes its image with it, which is what
/// deleting it meant; one they copied elsewhere in the box brings the image
/// along. A number with no payload behind it — pasted from another field — is
/// left exactly as typed rather than guessed at.
String restoreDataPayloads(String text, List<String> payloads) {
  if (payloads.isEmpty || !text.contains('[base64-data-')) return text;
  return text.replaceAllMapped(_kDataPlaceholder, (match) {
    final index = int.parse(match.group(1)!) - 1;
    return index >= 0 && index < payloads.length
        ? payloads[index]
        : match.group(0)!;
  });
}
