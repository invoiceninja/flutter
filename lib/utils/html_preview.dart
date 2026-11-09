/// HTML the app shows in a web view as a picture of a document (an email
/// preview), never as a page: [html] with a Content-Security-Policy that
/// allows no script, so a template carrying one (a custom template is
/// user-written HTML) runs nothing, on every platform alike. Windows' web
/// view has no switch to turn JavaScript off, and this needs none.
///
/// The policy goes first in `<head>` (or first in the document when there
/// is none): a policy is enforced only from where it is parsed, so a script
/// above it would still run. A `<head>` inside a comment is not the head.
/// A `<meta http-equiv="refresh">` is dropped too: no policy stops it, and
/// it would send the preview off to its address.
String htmlWithoutScripts(String html) {
  const policy =
      '<meta http-equiv="Content-Security-Policy" '
      "content=\"script-src 'none'; object-src 'none'; base-uri 'none'\">";
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

  final head = first(RegExp(r'<head(\s[^>]*)?>', caseSensitive: false));
  if (head != null) return doc.replaceRange(head.end, head.end, policy);
  final root = first(RegExp(r'<html(\s[^>]*)?>', caseSensitive: false));
  if (root != null) {
    return doc.replaceRange(root.end, root.end, '<head>$policy</head>');
  }
  return '$policy$doc';
}
