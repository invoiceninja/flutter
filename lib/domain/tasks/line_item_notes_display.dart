/// Turn an invoice line item's stored `notes` into something readable on
/// screen.
///
/// A task-generated line carries a little presentational markup that the PDF
/// needs — `<div class="project-header">…</div>`, `<div class="task-time-details">…</div>`
/// and `<br/>` separators (see `task_invoice_notes.dart`; the server's own
/// converters write the same shapes, and admin-portal writes a `## Name`
/// markdown variant). The app renders `notes` as plain `Text`, so without this
/// the user reads the tags: the invoice detail screen shows
/// `<div class="project-header">Acme Redesign</div>Homepage wireframes…` and a
/// mobile card's one-line summary is the opening tag and nothing else.
///
/// **Display only.** The stored value keeps its markup — that's what gets sent
/// and rendered — so never feed this back into an editor controller or a save
/// payload.
///
/// Deliberately a string rewrite, not an HTML parse: the markup is a closed set
/// we generate ourselves, and anything unrecognised is passed through untouched
/// so a hand-typed description is never mangled.
String lineItemNotesPlainText(String notes) {
  if (notes.isEmpty) return notes;
  // Cheap bail-out for the overwhelmingly common case — a plain description
  // with no markup at all.
  if (!notes.contains('<') && !notes.contains('## ')) return notes;

  var text = notes;

  // Unwrap our two wrappers, keeping their contents. The project header keeps
  // a line of its own; the time-details block is already newline-separated
  // inside.
  text = text.replaceAllMapped(
    RegExp(
      r'<div\s+class="(?:project-header|task-time-details)"\s*>(.*?)</div>',
      caseSensitive: false,
      dotAll: true,
    ),
    (m) => '\n${m[1] ?? ''}\n',
  );

  // admin-portal's markdown variant of the same header.
  text = text.replaceAllMapped(
    RegExp(r'^\s*#{1,6}\s+(.*)$', multiLine: true),
    (m) => m[1] ?? '',
  );

  // The line separators inside the details block.
  text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

  // Any other stray tag (a legacy Quill `<p>` / `<div>`, an unclosed wrapper)
  // — drop the tag, keep the words. The name must start with a letter right
  // after the `<`, so prose like "fixed the < and > comparison" keeps its
  // characters instead of losing everything between them.
  text = text.replaceAll(
    RegExp(r'</?[a-zA-Z][a-zA-Z0-9]*(?:\s[^<>]*)?/?>'),
    '',
  );

  // Unwrapping leaves blank lines behind wherever a wrapper sat on its own.
  final lines = [
    for (final line in text.split('\n'))
      if (line.trim().isNotEmpty) line.trim(),
  ];
  return lines.join('\n');
}

/// The first meaningful line of [notes] — a one-line summary for a compact row
/// (the mobile line-item card, a list cell). Empty when the note has nothing
/// but markup.
String lineItemNotesSummary(String notes) {
  final plain = lineItemNotesPlainText(notes);
  if (plain.isEmpty) return '';
  return plain.split('\n').first;
}
