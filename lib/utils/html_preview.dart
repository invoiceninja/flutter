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
/// These go first in the `<head>` that comes before `<body>`. The server's
/// email wrapper has no `<head>` at all (it strips it), and a full HTML
/// email pasted into a template's body brings its own `<head>` *inside*
/// the wrapper's body, where a policy is ignored, so a `<head>` after
/// `<body>`, or inside a comment, is not the head: the tags then go in
/// first, after any doctype, where the parser puts them into the head it
/// makes. A `<meta http-equiv="refresh">` is dropped too: no policy stops
/// it, and it would send the preview off to its address.
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

  final headTag = first(RegExp(r'<head(\s[^>]*)?>', caseSensitive: false));
  final bodyTag = first(RegExp(r'<body[\s>]', caseSensitive: false));
  if (headTag != null && (bodyTag == null || headTag.start < bodyTag.start)) {
    return doc.replaceRange(headTag.end, headTag.end, head);
  }
  final doctype = RegExp(
    r'^\s*<!doctype[^>]*>',
    caseSensitive: false,
  ).firstMatch(doc);
  final at = doctype?.end ?? 0;
  return doc.replaceRange(at, at, head);
}
