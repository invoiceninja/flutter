/// HTML the app shows in a web view as a picture of a document (an email
/// preview), never as a page: [html] with a Content-Security-Policy that
/// allows no script, so a template carrying one (a custom template is
/// user-written HTML) runs nothing, on every platform alike. Windows' web
/// view has no switch to turn JavaScript off, and this needs none.
///
/// The policy goes first in `<head>` (or first in the document when there
/// is none): a policy is enforced only from where it is parsed, so a script
/// above it would still run.
String htmlWithoutScripts(String html) {
  const policy =
      '<meta http-equiv="Content-Security-Policy" '
      "content=\"script-src 'none'; object-src 'none'; base-uri 'none'\">";
  final head = RegExp(r'<head(\s[^>]*)?>', caseSensitive: false);
  final match = head.firstMatch(html);
  if (match != null) {
    return html.replaceRange(match.end, match.end, policy);
  }
  final root = RegExp(r'<html(\s[^>]*)?>', caseSensitive: false);
  final open = root.firstMatch(html);
  if (open != null) {
    return html.replaceRange(open.end, open.end, '<head>$policy</head>');
  }
  return '$policy$html';
}
