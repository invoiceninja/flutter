import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin/ui/core/widgets/html_web_view.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/services/templates_api.dart';
import 'package:admin/ui/features/settings/views/advanced/templates_reminders/preview_controller.dart';
import 'package:admin/ui/features/settings/views/advanced/templates_reminders/widgets/template_preview_panel.dart';

import '../../../../../../_localization_helper.dart';

class _FakeTemplatesApi implements TemplatesApi {
  @override
  Future<TemplatePreview> render({
    required String template,
    required String subject,
    required String body,
    String entity = '',
    String entityId = '',
  }) async {
    return TemplatePreview(
      subject: subject,
      body: body,
      wrapper: '<html><body>$body</body></html>',
      rawSubject: subject,
      rawBody: body,
    );
  }
}

/// Answers after a moment, so the loading state shows.
class _SlowTemplatesApi extends _FakeTemplatesApi {
  @override
  Future<TemplatePreview> render({
    required String template,
    required String subject,
    required String body,
    String entity = '',
    String entityId = '',
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return super.render(template: template, subject: subject, body: body);
  }
}

void main() {
  Widget host(PreviewController controller) {
    return MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 500,
          height: 600,
          child: TemplatePreviewPanel(controller: controller),
        ),
      ),
    );
  }

  testWidgets(
    'success branch without a web view renders the body via HtmlWidget, '
    'never a WebView',
    (tester) async {
      // Linux stands in for every target without a web view. The web path
      // (kIsWeb true) routes here too, but kIsWeb is a compile-time const we
      // can't flip in a VM test — it's exercised by the Chrome integration
      // suite. The guarantee under test: the success branch must NOT
      // instantiate a WebView where there is none. (The default test
      // platform is android, which WOULD take the WebView path — hence the
      // override is required, reset in a finally so the foundation-var
      // invariant check at the end of the body passes.)
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        final controller = PreviewController(api: _FakeTemplatesApi());
        addTearDown(controller.dispose);
        controller.schedule(
          template: 'invoice',
          subject: 'Welcome',
          body: '<p>Hello world</p>',
          immediate: true,
        );

        await tester.pumpWidget(host(controller));
        await tester.pumpAndSettle();

        expect(find.byType(HtmlWidget), findsOneWidget);
        expect(find.byType(WebViewWidget), findsNothing);
        // Subject bar reflects the server-substituted subject.
        expect(find.text('Welcome'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'the preview stays up under a progress bar while the next one loads',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        final controller = PreviewController(api: _SlowTemplatesApi());
        addTearDown(controller.dispose);
        controller.schedule(
          template: 'invoice',
          subject: 'One',
          body: '<p>First</p>',
          immediate: true,
        );
        await tester.pumpWidget(host(controller));
        await tester.pumpAndSettle();
        final before = tester.state(find.byType(HtmlWebView));

        controller.schedule(
          template: 'invoice',
          subject: 'Two',
          body: '<p>Second</p>',
        );
        // Past the debounce: loading.
        await tester.pump(const Duration(milliseconds: 450));
        // Loading: the same preview (its web view not torn down), with a bar.
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(tester.state(find.byType(HtmlWebView)), same(before));

        await tester.pumpAndSettle(const Duration(seconds: 2));
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.text('Two'), findsOneWidget);
        expect(tester.state(find.byType(HtmlWebView)), same(before));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  test(
    'the email preview has a web view on iOS, Android, macOS and Windows',
    () {
      try {
        for (final p in TargetPlatform.values) {
          debugDefaultTargetPlatformOverride = p;
          expect(
            HtmlWebView.supported,
            {
              TargetPlatform.iOS,
              TargetPlatform.android,
              TargetPlatform.macOS,
              TargetPlatform.windows,
            }.contains(p),
            reason: '$p',
          );
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
