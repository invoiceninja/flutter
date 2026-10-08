import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/repositories/design_repository.dart';
import 'package:admin/data/services/designs_api.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_library.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/document_source.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_view_model.dart';

import '../../../../../_localization_helper.dart';

class _FakeDesignsApi implements DesignsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// The page used to show a made-up invoice while the preview drew a real
/// one. The workspace now fills the page from the chosen document.
void main() {
  late AppDatabase db;
  late WysiwygDesignViewModel vm;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    vm = WysiwygDesignViewModel(
      repo: DesignRepository(db: db, api: _FakeDesignsApi()),
      companyId: 'co1',
    );
  });

  tearDown(() async {
    vm.dispose();
    await db.close();
  });

  testWidgets('the page shows the chosen invoice, and the sample on request', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final document = DesignerDocumentController(
      loadRecent: () async => [
        Invoice.fromApi(
          InvoiceApi.fromJson({
            'id': 'inv1',
            'client_id': 'c1',
            'number': 'R-0042',
            'amount': '10.00',
            'date': '2026-03-04',
            'updated_at': 1,
            'created_at': 1,
          }),
        ),
      ],
      loadClient: (id) async => Client.fromApi(
        ClientApi(
          id: id,
          name: 'Blue Door Bakery',
          displayName: 'Blue Door Bakery',
          updatedAt: 1,
        ),
      ),
    );
    addTearDown(document.dispose);
    await document.load();

    vm.addBlock(blockSpecFor('invoice-details')!);
    vm.addBlock(blockSpecFor('client-info')!);
    final edits = vm.canUndo;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        locale: const Locale('en'),
        theme: buildInTheme(InTheme.light),
        home: Scaffold(
          body: DesignerWorkspace(vm: vm, isPro: true, document: document),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    expect(find.text('R-0042'), findsOneWidget);
    expect(find.text('INV-0001'), findsNothing);
    expect(find.text('Invoice R-0042'), findsOneWidget, reason: 'the bar');
    // On the page, and as the example under "Client Name" in the panel —
    // the selected block's fields are described by the same document.
    expect(find.text('Blue Door Bakery'), findsNWidgets(2));
    expect(find.text('Acme Corporation'), findsNothing);
    // This client has no address: the panel says so with a dash rather
    // than showing the raw `$client.address1`.
    expect(find.textContaining(r'$client.'), findsNothing);

    await document.showInvoice(null);
    await tester.pump();
    expect(find.text('INV-0001'), findsOneWidget);
    expect(find.text('Acme Corporation'), findsNWidgets(2));
    expect(find.text('R-0042'), findsNothing);
    expect(find.text('Blue Door Bakery'), findsNothing);

    // A way of looking at the design, not part of it.
    expect(vm.canUndo, edits);
  });
}
