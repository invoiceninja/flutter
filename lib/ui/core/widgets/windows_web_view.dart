import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart';

final _log = Logger('WindowsWebView');

/// The app's web view on Windows: WebView2, through `webview_flutter_windows`,
/// which draws into Flutter's own surface (so a dialog or a cover paints over
/// it, as on the other platforms) but has its own API rather than
/// `webview_flutter`'s, which has no Windows implementation.
/// docs/windows-web-view.md.
bool get isWindowsWebView =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

Future<void>? _environment;

/// The folder WebView2 keeps the app's web data in (storage, cache):
/// `<application support>/WebView2`.
Future<String> windowsWebViewDataPath() async =>
    p.join((await getApplicationSupportDirectory()).path, 'WebView2');

/// Points WebView2 at a data folder of the app's own, once, before the first
/// web view: the plugin's default is a shared `flutter_webview_windows`
/// folder under the user's local app data, named only by the executable,
/// which the app could not clear at sign-out without guessing at it. A
/// failure here is logged and the default is used.
Future<void> ensureWindowsWebViewEnvironment() => _environment ??= () async {
  try {
    await WebviewController.initializeEnvironment(
      userDataPath: await windowsWebViewDataPath(),
    );
  } on Object catch (e, st) {
    _log.warning('WebView2 environment', e, st);
  }
}();

int _live = 0;
bool _startFailureLogged = false;

/// Whether any web view is open now (its browser process holds the data
/// folder, so nothing may delete it).
bool get windowsWebViewsAlive => _live > 0;

/// A WebView2 controller, set up and ready to load, or null when WebView2
/// cannot start (its runtime is missing on an old Windows 10): every caller
/// falls back to what it shows where there is no web view. Every controller
/// this returns goes back through [disposeWindowsWebView].
Future<WebviewController?> startWindowsWebView() async {
  await ensureWindowsWebViewEnvironment();
  final controller = WebviewController();
  _live++;
  try {
    await controller.initialize();
    // No pop-up windows: a link that asks for one goes through the caller's
    // own handling or nowhere.
    await controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
    return controller;
  } on Object catch (e, st) {
    // Once a run: a missing runtime fails every preview the same way.
    if (!_startFailureLogged) {
      _startFailureLogged = true;
      _log.warning('WebView2 did not start', e, st);
    }
    unawaited(disposeWindowsWebView(controller));
    return null;
  }
}

/// Lets a controller from [startWindowsWebView] go.
Future<void> disposeWindowsWebView(WebviewController controller) async {
  try {
    await controller.dispose();
  } finally {
    _live--;
  }
}
