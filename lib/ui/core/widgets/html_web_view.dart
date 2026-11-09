import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart';

import 'package:admin/ui/core/widgets/windows_web_view.dart';
import 'package:admin/utils/html_preview.dart';

/// The largest document WebView2 loads from a string (`NavigateToString`
/// takes 2 MB); a larger one (an email with big inline images) shows the
/// fallback rather than a blank page.
const _kWindowsMaxDocumentBytes = 1900 * 1024;

/// A finished HTML document (an email as it will arrive) shown in a native
/// web view, so its `<style>` blocks, tables and images render as a mail
/// client renders them: iOS, Android, macOS (`webview_flutter`) and Windows
/// (WebView2, `windows_web_view.dart`). Everywhere else (the web, Linux),
/// and on a Windows whose WebView2 runtime is missing, [fallback] is shown
/// instead.
///
/// It is a picture, not a page ([previewHtml]): no script runs, a tapped
/// link or form leaves the document where it is, and it reads light. docs/windows-web-view.md.
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
  /// Not applied on macOS, whose web view cannot take one and is
  /// transparent already.
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

  /// WebView2's controller from the moment it exists, so a dispose during
  /// its start-up lets it go.
  WebviewController? _starting;
  WebviewController? _windows;
  StreamSubscription<String>? _windowsUrl;

  /// WebView2 could not start (no runtime): the fallback shows, for good.
  bool _failed = false;

  /// The document is too large for WebView2: the fallback shows until a
  /// smaller one comes.
  bool _tooLarge = false;

  String get _document => previewHtml(widget.html);

  @override
  void initState() {
    super.initState();
    if (!HtmlWebView.supported) return;
    if (isWindowsWebView) {
      // Too large for WebView2: the fallback, from the first frame.
      if (!_fitsWindows(_document)) {
        _tooLarge = true;
      } else {
        unawaited(_startWindows());
      }
      return;
    }
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
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
      );
    // macOS's WKWebView cannot take a background colour (the plugin throws
    // making it non-opaque); it draws the page's own, white for a preview
    // ([previewHtml] sets the light colour scheme).
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      controller.setBackgroundColor(widget.background);
    }
    _flutter = controller..loadHtmlString(_document);
  }

  bool _fitsWindows(String document) =>
      utf8.encode(document).length <= _kWindowsMaxDocumentBytes;

  Future<void> _startWindows() async {
    final controller = await startWindowsWebView();
    if (controller == null) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    _starting = controller;
    if (!mounted) return _release();
    // WebView2 cannot refuse a navigation from here, so one that leaves the
    // document (a tapped link) is put back. A document loaded from a string
    // reports `about:blank`, so this never loops on itself.
    _windowsUrl = controller.url.listen((url) {
      if (url.startsWith('http:') || url.startsWith('https:')) {
        unawaited(controller.loadStringContent(_document));
      }
    });
    await controller.setBackgroundColor(widget.background);
    if (!mounted) return _release();
    // The document as it is now: an edit while WebView2 was starting must
    // not leave the one from before showing.
    final document = _document;
    if (!_fitsWindows(document)) {
      _release();
      setState(() => _tooLarge = true);
      return;
    }
    await controller.loadStringContent(document);
    if (!mounted) return _release();
    setState(() => _windows = controller);
    // Changed during that last load: the newest one.
    final now = _document;
    if (now != document && _fitsWindows(now)) {
      unawaited(controller.loadStringContent(now));
    }
  }

  /// Lets WebView2 go (the widget left, or never needed it).
  void _release() {
    unawaited(_windowsUrl?.cancel());
    _windowsUrl = null;
    final controller = _starting;
    _starting = null;
    _windows = null;
    if (controller != null) unawaited(disposeWindowsWebView(controller));
  }

  @override
  void didUpdateWidget(covariant HtmlWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html == widget.html) return;
    final document = _document;
    unawaited(_flutter?.loadHtmlString(document));
    if (!isWindowsWebView || _failed) return;
    final fits = _fitsWindows(document);
    final windows = _windows;
    if (windows != null) {
      if (fits) {
        unawaited(windows.loadStringContent(document));
      } else {
        _release();
        _tooLarge = true;
      }
    } else if (_tooLarge && fits) {
      // A smaller document after one too large: WebView2 again.
      _tooLarge = false;
      unawaited(_startWindows());
    }
    // A WebView2 still starting loads the new document when it is up.
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flutter = _flutter;
    if (flutter != null) return WebViewWidget(controller: flutter);
    final windows = _windows;
    if (windows != null) return Webview(windows);
    if (_failed || _tooLarge || !HtmlWebView.supported) {
      return widget.fallback(context);
    }
    // WebView2 is starting.
    return const SizedBox.expand();
  }
}
