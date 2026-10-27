import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/document_version.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/document_versions_api.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/history/versioned_pdf_pane.dart';

import '../../../_localization_helper.dart';

/// Counts version renders; never answers with a version list, so the banner
/// stays on its placeholder label.
class _FakeVersionsApi extends DocumentVersionsApi {
  _FakeVersionsApi()
    : super(
        ApiClient(
          credentials: ValueNotifier<ApiCredentials?>(
            const ApiCredentials(baseUrl: 'https://test', token: 't'),
          ),
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          httpClient: MockClient(
            (_) async => http.Response('{}', 200, headers: const {}),
          ),
        ),
      );

  int downloads = 0;

  @override
  Future<DocumentVersionPage> fetchForEntity({
    required String basePath,
    required String id,
  }) async => const DocumentVersionPage.empty();

  @override
  Future<Uint8List> downloadVersionPdf(String activityId) {
    downloads++;
    return Future<Uint8List>.error(StateError('no server in test'));
  }
}

void main() {
  // Failing fetches keep `PdfPreview` (which needs the engine rasterizer)
  // out of the tree; only which fetch runs, and when, is asserted.
  late int live;
  Future<Uint8List> liveFetcher({
    String? designId,
    required bool deliveryNote,
  }) {
    live++;
    return Future<Uint8List>.error(StateError('no server in test'));
  }

  late _FakeVersionsApi api;
  late ValueNotifier<String?> selection;

  setUp(() {
    live = 0;
    api = _FakeVersionsApi();
    selection = ValueNotifier<String?>(null);
  });

  Future<void> pump(WidgetTester tester, Object record) => tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: VersionedPdfPane(
          entity: BillingDocType.invoice,
          entityNumber: '0042',
          selection: selection,
          api: api,
          basePath: '/api/v1/invoices',
          entityId: 'd1',
          liveFetcher: liveFetcher,
          liveRevision: record,
          hasUnsyncedChanges: false,
        ),
      ),
    ),
  );

  testWidgets('a change to the record re-renders the live document', (
    tester,
  ) async {
    await pump(tester, ('0042', 100));
    await tester.pumpAndSettle();
    expect(live, 1);

    // The same record re-emitted: nothing to re-render.
    await pump(tester, ('0042', 100));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(live, 1);

    // A saved edit, while the pane stayed mounted.
    await pump(tester, ('0042', 250));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(live, 2);
  });

  testWidgets('a selected version does not follow the record', (tester) async {
    await pump(tester, ('0042', 100));
    await tester.pumpAndSettle();

    selection.value = 'activity-7';
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(api.downloads, 1);

    // A frozen render does not change when the record does.
    await pump(tester, ('0042', 250));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(api.downloads, 1);
    expect(live, 1);

    // Back to the live document: it is fetched once, at its new content.
    selection.value = null;
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(live, 2);
  });
}
