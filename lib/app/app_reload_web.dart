import 'package:web/web.dart' as web;

/// Reload the page — the web half of the [app_reload] seam.
///
/// The boot-failure screen uses this to retry from scratch. That is the real
/// fix for the common web wedge: the local store was held by a stale browser
/// context (the forced reload Flutter's service worker performs after a
/// redeploy), the lock clears within a second or two, and the next load opens
/// the database normally.
void reloadApp() => web.window.location.reload();
