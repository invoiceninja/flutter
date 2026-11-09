import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// The macOS implementation, to build the web view as macOS does. Both come
// with webview_flutter.
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'package:admin/ui/core/widgets/html_web_view.dart';

void main() {
  testWidgets('macOS shows the web view: no background colour is set on it', (
    tester,
  ) async {
    // macOS's WKWebView cannot be made non-opaque: setting a background
    // colour there throws in the build, and the preview was an error box.
    final previous = WebViewPlatform.instance;
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    WebViewPlatform.instance = WebKitWebViewPlatform();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: HtmlWebView(
            html: '<p>Hello</p>',
            fallback: (_) => const Text('fallback'),
          ),
        ),
      );
      final error = tester.takeException();
      expect(
        error.toString(),
        isNot(contains('opaque')),
        reason: 'the web view must build on macOS',
      );
      expect(find.text('fallback'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      if (previous != null) WebViewPlatform.instance = previous;
    }
  });

  testWidgets('a platform without a web view shows the fallback', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: HtmlWebView(
            html: '<p>Hello</p>',
            fallback: (_) => const Text('fallback'),
          ),
        ),
      );
      expect(find.text('fallback'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
