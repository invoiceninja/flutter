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

/// Points WebView2 at a data folder of the app's own, once, before the first
/// web view: its default sits beside the executable, which an MSIX (Microsoft
/// Store) install keeps read-only, so the first web view would fail to start.
/// A failure here is logged and the default is tried.
Future<void> ensureWindowsWebViewEnvironment() => _environment ??= () async {
  try {
    final dir = await getApplicationSupportDirectory();
    await WebviewController.initializeEnvironment(
      userDataPath: p.join(dir.path, 'WebView2'),
    );
  } on Object catch (e, st) {
    _log.warning('WebView2 environment', e, st);
  }
}();

/// A WebView2 controller, set up and ready to load, or null when WebView2
/// cannot start (its runtime is missing on an old Windows 10): every caller
/// falls back to what it shows where there is no web view.
Future<WebviewController?> startWindowsWebView() async {
  await ensureWindowsWebViewEnvironment();
  final controller = WebviewController();
  try {
    await controller.initialize();
    // No pop-up windows: a link that asks for one goes through the caller's
    // own handling or nowhere.
    await controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
    return controller;
  } on Object catch (e, st) {
    _log.warning('WebView2 did not start', e, st);
    unawaited(controller.dispose());
    return null;
  }
}
