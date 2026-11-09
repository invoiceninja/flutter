/// HTML the app shows in a web view as a picture of a document (an email
/// preview), never as a page:
///
/// - **No script runs**: a Content-Security-Policy allows none, on every
///   platform alike (a custom template is user-written HTML, and the
///   Windows web view the app uses exposes no switch to turn JavaScript
///   off). It also refuses form submissions.
/// - **No link or form leaves**: `<base target="_blank">` sends every link
///   to a new window, which the web views refuse, so a tap never reaches the
///   server (a real portal link would mark the invoice viewed).
/// - **It reads as the email will**: light, on white, whatever the app's
///   theme (`color-scheme: light only`), unless the email sets its own
///   colours.
///
/// These go first in the document, right after its doctype (before any
/// comment or prolog-free markup), where the HTML parser puts them into the
/// head it makes, whatever follows: a document's own `<head>` then merges
/// into that one, and the server's email wrapper, which has no `<head>` (it
/// strips it), works the same. Inserting inside a `<head>` was wrong twice
/// over: markup before that head (`<html><script>…<head>`) ran first, and a
/// full HTML email pasted into a template's body brings a `<head>` *inside*
/// the wrapper's body, where a policy is ignored. A doctype inside a comment
/// is not the doctype. A `<meta http-equiv="refresh">` is dropped too: no
/// policy stops it, and it would send the preview off to its address.
String previewHtml(String html) {
  const head =
      '<meta http-equiv="Content-Security-Policy" '
      "content=\"script-src 'none'; object-src 'none'; base-uri 'none'; "
      "form-action 'none'\">"
      '<base target="_blank">'
      '<style>:root { color-scheme: light only !important; }</style>';
  final doc = html.replaceAll(
    RegExp(
      r'''<meta\b[^>]*http-equiv\s*=\s*["']?refresh["']?[^>]*>''',
      caseSensitive: false,
    ),
    '',
  );
  final comments = [
    for (final m in RegExp(r'<!--[\s\S]*?(-->|$)').allMatches(doc))
      (m.start, m.end),
  ];
  bool commented(int at) => comments.any((c) => at >= c.$1 && at < c.$2);
  RegExpMatch? first(RegExp tag) {
    for (final m in tag.allMatches(doc)) {
      if (!commented(m.start)) return m;
    }
    return null;
  }

  // After the doctype, or quirks mode would follow. Only the document's
  // own doctype counts: one with nothing but comments, white space or an
  // XML prolog before it, not one a pasted email brings into the body.
  final doctype = first(RegExp(r'<!doctype[^>]*>', caseSensitive: false));
  var at = 0;
  if (doctype != null) {
    final before = doc
        .substring(0, doctype.start)
        .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '')
        .replaceAll(RegExp(r'<\?xml[^>]*\?>', caseSensitive: false), '');
    if (before.trim().isEmpty) at = doctype.end;
  }
  return doc.replaceRange(at, at, head);
}
