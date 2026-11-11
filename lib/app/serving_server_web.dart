import 'package:web/web.dart' as web;

import 'package:admin/app/serving_server_parse.dart';

/// Web half of the [serving_server] seam: the boot page's `<html data-*>`
/// attributes and the page's own location. Read once at boot; a failure to
/// read means "not served", which leaves the login screen exactly as it is on
/// the demo.
ServingServer? readServingServer() {
  try {
    final root = web.document.documentElement;
    if (root == null) return null;
    final location = web.window.location;
    return parseServingServer(
      attribute: root.getAttribute,
      origin: location.origin,
      pathname: location.pathname,
    );
  } catch (_) {
    return null;
  }
}
