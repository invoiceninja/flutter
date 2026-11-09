import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart';

import 'package:admin/ui/core/widgets/windows_web_view.dart';
import 'package:admin/utils/html_preview.dart';

/// A finished HTML document (an email as it will arrive) shown in a native
/// web view, so its `<style>` blocks, tables and images render as a mail
/// client renders them: iOS, Android, macOS (`webview_flutter`) and Windows
/// (WebView2, `windows_web_view.dart`). Everywhere else (the web, Linux),
/// and on a Windows whose WebView2 runtime is missing, [fallback] is shown
/// instead.
///
/// It is a picture, not a page: no script runs ([htmlWithoutScripts]) and a
/// tapped link leaves the document where it is. docs/windows-web-view.md.
class HtmlWebView extends StatefulWidget {
  const HtmlWebView({
    super.key,
    required this.html,
    required this.fallback,
    this.background = const Color(0x00000000),
  });

  final String html;

  /// What shows where there is no web view.
  final WidgetBuilder fallback;

  /// Behind the document (transparent: the email's own background shows).
  final Color background;

  /// Whether this platform has a web view to show it in.
  static bool get supported {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS ||
      TargetPlatform.android ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      _ => false,
    };
  }

  @override
  State<HtmlWebView> createState() => _HtmlWebViewState();
}

class _HtmlWebViewState extends State<HtmlWebView> {
  WebViewController? _flutter;
  WebviewController? _windows;
  StreamSubscription<String>? _windowsUrl;

  /// WebView2 could not start: the fallback shows.
  bool _failed = false;

  String get _document => htmlWithoutScripts(widget.html);

  @override
  void initState() {
    super.initState();
    if (!HtmlWebView.supported) return;
    if (isWindowsWebView) {
      unawaited(_startWindows());
      return;
    }
    _flutter = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setBackgroundColor(widget.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          // Only the document itself loads (`about:blank` or a `data:` URL,
          // by platform); a tapped link goes nowhere.
          onNavigationRequest: (request) =>
              request.url.startsWith('about:') ||
                  request.url.startsWith('data:')
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
        ),
      )
      ..loadHtmlString(_document);
  }

  Future<void> _startWindows() async {
    final controller = await startWindowsWebView();
    if (!mounted) {
      unawaited(controller?.dispose());
      return;
    }
    if (controller == null) {
      setState(() => _failed = true);
      return;
    }
    // WebView2 cannot refuse a navigation from here, so one that leaves the
    // document (a tapped link) is put back.
    _windowsUrl = controller.url.listen((url) {
      if (url.startsWith('http:') || url.startsWith('https:')) {
        unawaited(controller.loadStringContent(_document));
      }
    });
    await controller.setBackgroundColor(widget.background);
    await controller.loadStringContent(_document);
    if (mounted) setState(() => _windows = controller);
  }

  @override
  void didUpdateWidget(covariant HtmlWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html == widget.html) return;
    unawaited(_flutter?.loadHtmlString(_document));
    unawaited(_windows?.loadStringContent(_document));
  }

  @override
  void dispose() {
    unawaited(_windowsUrl?.cancel());
    unawaited(_windows?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flutter = _flutter;
    if (flutter != null) return WebViewWidget(controller: flutter);
    final windows = _windows;
    if (windows != null) return Webview(windows);
    if (_failed || !HtmlWebView.supported) return widget.fallback(context);
    // WebView2 is starting.
    return const SizedBox.expand();
  }
}
