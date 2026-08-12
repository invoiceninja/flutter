import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    'success branch off mobile-native renders the body via HtmlWidget, never '
    'a WebView',
    (tester) async {
      // macOS stands in for every non-mobile-native target. The web path
      // (kIsWeb true) routes here too, but kIsWeb is a compile-time const we
      // can't flip in a VM test — it's exercised by the Chrome integration
      // suite. The guarantee under test: the success branch must NOT
      // instantiate a WebView unless it's truly mobile-native. (The default
      // test platform is android, which WOULD take the WebView path — hence
      // the override is required, reset in a finally so the foundation-var
      // invariant check at the end of the body passes.)
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
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
}
