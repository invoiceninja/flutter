import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart';

import 'package:admin/domain/docuninja/docuninja_create.dart';
import 'package:admin/domain/docuninja/docuninja_embed.dart';
import 'package:admin/ui/core/widgets/windows_web_view.dart';

final _log = Logger('DocuNinjaEmbedSurface');

/// What the embedded builder's page tells the screen.
class DnEmbedEvents {
  const DnEmbedEvents({
    required this.onMessage,
    required this.onPageStarted,
    required this.onLoadFailed,
    required this.openExternal,
  });

  /// One message on the `InvoiceNinjaApp` channel, as the page sent it.
  final void Function(String raw) onMessage;

  /// The main frame started loading a page (a boot, or a reload).
  final VoidCallback onPageStarted;

  /// The main frame failed to load, or no web view could start.
  final VoidCallback onLoadFailed;

  /// A link off the web app: the browser, not this web view.
  final void Function(Uri uri) openExternal;
}

/// The web view the embedded builder runs in (docs/docuninja.md § The field
/// builder runs embedded where a web view can): `webview_flutter` on iOS,
/// Android and macOS, WebView2 on Windows (docs/windows-web-view.md). Both
/// keep the same rules: only the web app loads in the main frame, the page
/// talks over `InvoiceNinjaApp`, and nothing it stored outlives the screen.
abstract class DnEmbedSurface {
  /// The surface for this platform.
  factory DnEmbedSurface(DnEmbedEvents events) =>
      isWindowsWebView ? _WindowsSurface(events) : _FlutterSurface(events);

  /// Clears anything an earlier visit left, then loads [uri].
  Future<void> open(Uri uri);

  /// Loads [uri] in place (a page of the web app, keeping its sign-in).
  Future<void> load(Uri uri);

  Future<void> runJavaScript(String script);

  Future<String?> currentUrl();

  Widget build(BuildContext context);

  /// Clears what the page stored and lets the web view go.
  void dispose();
}

/// Clears what the embedded builder stored, at sign-out (a builder that
/// closed normally cleared after itself; this is for one the app was killed
/// with open). A no-op where the builder is never embedded.
Future<void> clearDocuNinjaWebStorage() async {
  try {
    // On Windows the folder also holds the email previews' cache, so it goes
    // whether or not the builder is embedded.
    if (isWindowsWebView) {
      // With no web view open, WebView2 has let its data folder go: remove
      // it whole. One still open (a 401 sign-out over the builder or a
      // preview) holds it, so leave it: the builder clears the web app's
      // storage as it closes and before its next boot anyway. Best effort:
      // a browser process that lingers can hold a file for a moment.
      if (windowsWebViewsAlive) return;
      final data = Directory(await windowsWebViewDataPath());
      if (await data.exists()) await data.delete(recursive: true);
      return;
    }
    if (kDnEmbeddedBuilder && _flutterEmbedPlatform) {
      await WebViewController().clearLocalStorage();
    }
  } on Object catch (e) {
    // No web view (a test), or a file WebView2 still held.
    _log.fine('Clearing the builder storage: $e');
  }
}

bool get _flutterEmbedPlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.macOS);

class _FlutterSurface implements DnEmbedSurface {
  _FlutterSurface(this.events) {
    _web
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'InvoiceNinjaApp',
        onMessageReceived: (m) => events.onMessage(m.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri != null && dnEmbedAllowed(uri)) {
              return NavigationDecision.navigate;
            }
            // The page's own frames (a file preview, an embedded viewer)
            // load where it put them; they never receive the token, which
            // goes only to the main frame on the web app's origin.
            if (!request.isMainFrame) return NavigationDecision.navigate;
            // Anything else (a help page, a payment page) opens in the
            // browser; the web view only ever shows the web app.
            if (uri != null &&
                (uri.scheme == 'https' || uri.scheme == 'http')) {
              events.openExternal(uri);
            }
            return NavigationDecision.prevent;
          },
          onPageStarted: (_) => events.onPageStarted(),
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? false) events.onLoadFailed();
          },
        ),
      );
    _enableFileInputs();
  }

  final DnEmbedEvents events;
  final _web = WebViewController();

  /// A file input in the builder (a document's files, an upload). iOS
  /// answers one itself; Android's web view needs the host to pick the
  /// files, of the types the input accepts. macOS's web view plugin has no
  /// open-panel support, so a file input there does nothing
  /// (docs/docuninja.md).
  void _enableFileInputs() {
    final platform = _web.platform;
    if (platform is! AndroidWebViewController) return;
    platform.setOnShowFileSelector((params) async {
      final extensions = dnAcceptedExtensions(params.acceptTypes);
      final type = extensions == null ? FileType.any : FileType.custom;
      final List<PlatformFile> files;
      if (params.mode == FileSelectorMode.openMultiple) {
        files = await FilePicker.pickFiles(
          type: type,
          allowedExtensions: extensions,
        );
      } else {
        final one = await FilePicker.pickFile(
          type: type,
          allowedExtensions: extensions,
        );
        files = [?one];
      }
      return [
        for (final f in files)
          if (f.path != null) Uri.file(f.path!).toString(),
      ];
    });
  }

  @override
  Future<void> open(Uri uri) async {
    // A fresh page every time: no token or company left over from an
    // earlier visit (React keeps the DocuNinja token in localStorage).
    try {
      await _web.clearLocalStorage();
    } on Object catch (e) {
      _log.fine('Clearing before the builder: $e');
    }
    // Closed meanwhile (a quick Back): nothing to load the page into.
    if (_disposed) return;
    await _web.loadRequest(uri);
  }

  @override
  Future<void> load(Uri uri) => _web.loadRequest(uri);

  @override
  Future<void> runJavaScript(String script) => _web.runJavaScript(script);

  @override
  Future<String?> currentUrl() => _web.currentUrl();

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _web);

  @override
  void dispose() {
    _disposed = true;
    unawaited(_web.clearLocalStorage());
  }

  bool _disposed = false;
}

/// WebView2 on Windows. It cannot refuse a navigation or name a channel the
/// way `webview_flutter` does, so the same rules are kept differently:
///
/// - **The channel** is a script WebView2 runs before the page's own, in the
///   main frame on the web app's origin only, that forwards
///   `InvoiceNinjaApp.postMessage` to `chrome.webview.postMessage`.
/// - **Only the web app shows**: a main-frame address off it is opened in
///   the browser and the web view goes back. It never had the token, which
///   lives in the web app's own session storage and is handed over only on
///   its origin ([dnEmbedInitScript]).
/// - **Storage**: the same script clears the web app's local storage on the
///   first page of each screen, and the screen clears it again as it
///   closes; at sign-out the whole data folder goes
///   ([clearDocuNinjaWebStorage]).
/// - **File inputs** are WebView2's own open dialog.
class _WindowsSurface implements DnEmbedSurface {
  _WindowsSurface(this.events);

  final DnEmbedEvents events;

  /// WebView2's controller from the moment it exists, so a dispose during
  /// its start-up lets it go.
  WebviewController? _started;
  final _controller = ValueNotifier<WebviewController?>(null);
  final _subscriptions = <StreamSubscription<Object?>>[];
  String? _url;
  bool _disposed = false;

  /// The script WebView2 runs before every document's own.
  static String get _bridge {
    final origin = jsonEncode(Uri.parse(kDnHostedWebAppUrl).origin);
    return '(function () {'
        'if (window.top !== window || window.location.origin !== $origin) '
        'return;'
        // First page of this screen (a reload keeps session storage): no
        // earlier visit's DocuNinja token.
        "if (!sessionStorage.getItem('X-IN-EMBED-FRESH')) {"
        'try { localStorage.clear(); } catch (e) {}'
        "sessionStorage.setItem('X-IN-EMBED-FRESH', '1');"
        '}'
        'window.InvoiceNinjaApp = { postMessage: function (m) {'
        'window.chrome.webview.postMessage(String(m)); } };'
        '})();';
  }

  @override
  Future<void> open(Uri uri) async {
    final controller = await startWindowsWebView();
    if (controller == null) {
      // No WebView2 runtime: the screen offers the browser.
      if (!_disposed) events.onLoadFailed();
      return;
    }
    _started = controller;
    if (_disposed) return _release();
    try {
      await _wire(controller, uri);
    } on Object catch (e, st) {
      // A WebView2 that started but would not take the bridge or the page
      // (its browser process failed): let it go, and offer the browser.
      _log.warning('The builder did not load in WebView2', e, st);
      // Off the screen first, so a later dispose does not let it go twice.
      if (!_disposed) _controller.value = null;
      _release();
      if (!_disposed) events.onLoadFailed();
    }
  }

  Future<void> _wire(WebviewController controller, Uri uri) async {
    _subscriptions
      ..add(
        controller.webMessage.listen(
          (m) => events.onMessage(m is String ? m : jsonEncode(m)),
        ),
      )
      ..add(
        controller.loadingState.listen((state) {
          if (state == LoadingState.loading) events.onPageStarted();
        }),
      )
      ..add(
        controller.onLoadError.listen((status) {
          // Going back from a refused address cancels a load, and an
          // off-site page the guard is leaving (one that failed to load:
          // no network, a bad certificate) fails on its own; neither is the
          // builder failing.
          final at = Uri.tryParse(_url ?? '');
          if (at != null && at.hasScheme && !dnEmbedAllowed(at)) return;
          if (status != WebErrorStatus.operationCanceled) {
            events.onLoadFailed();
          }
        }),
      )
      ..add(controller.url.listen((url) => _onUrl(controller, url)));
    await controller.addScriptToExecuteOnDocumentCreated(_bridge);
    if (_disposed) return _release();
    _controller.value = controller;
    await controller.loadUrl(uri.toString());
  }

  void _onUrl(WebviewController controller, String url) {
    _url = url;
    final uri = Uri.tryParse(url);
    if (uri == null || dnEmbedAllowed(uri)) return;
    // The page loaded from nothing yet: not a navigation away.
    if (uri.scheme == 'about') return;
    // A web page off the web app opens in the browser; anything else in the
    // main frame (`blob:`, `data:`, `file:`), which `webview_flutter`
    // refuses, is just undone.
    if (uri.scheme == 'https' || uri.scheme == 'http') events.openExternal(uri);
    unawaited(controller.goBack());
  }

  @override
  Future<void> load(Uri uri) async =>
      _controller.value?.loadUrl(uri.toString());

  @override
  Future<void> runJavaScript(String script) async {
    await _controller.value?.executeScript(script);
  }

  @override
  Future<String?> currentUrl() async => _url;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<WebviewController?>(
        valueListenable: _controller,
        builder: (context, controller, _) =>
            controller == null ? const SizedBox.expand() : Webview(controller),
      );

  /// Lets WebView2 go, before it showed anything.
  void _release() {
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    _subscriptions.clear();
    final controller = _started;
    _started = null;
    if (controller != null) unawaited(disposeWindowsWebView(controller));
  }

  @override
  void dispose() {
    _disposed = true;
    final controller = _controller.value;
    _controller.dispose();
    // Still starting: [open] lets it go when it resumes.
    if (controller == null) return;
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    _started = null;
    unawaited(() async {
      try {
        if (_url != null && dnEmbedAllowed(Uri.parse(_url!))) {
          await controller.executeScript(
            'try { localStorage.clear(); sessionStorage.clear(); } '
            'catch (e) {}',
          );
        }
      } on Object catch (e) {
        _log.fine('Clearing the builder storage: $e');
      } finally {
        await disposeWindowsWebView(controller);
      }
    }());
  }
}
