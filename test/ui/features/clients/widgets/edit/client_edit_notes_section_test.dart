import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/services/clients_api.dart';
import 'package:admin/ui/features/clients/view_models/client_edit_view_model.dart';
import 'package:admin/ui/features/clients/widgets/edit/client_edit_notes_section.dart';

import '../../../../../_localization_helper.dart';

/// Client notes are HTML on the wire, exactly like a billing document's, so
/// they use the same editor rather than a plain text field — which is what
/// dropped every line break the moment the record was opened on the web
/// (invoiceninja/flutter#159).

class _NoopApi implements ClientsApi {
  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected API call: ${invocation.memberName}');
}

void main() {
  late AppDatabase db;
  late ClientRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ClientRepository(db: db, api: _NoopApi());
  });
  tearDown(() async {
    await db.close();
  });

  ClientEditViewModel vmFor({String publicNotes = ''}) => ClientEditViewModel(
    repo: repo,
    companyId: 'co',
    existing: Client.fromApi(
      ClientApi.fromJson({
        'id': 'c1',
        'name': 'Acme',
        'balance': '0',
        'public_notes': publicNotes,
      }),
    ),
  );

  Future<void> pump(
    WidgetTester tester,
    ClientEditViewModel vm,
    double width,
  ) => tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: width,
            child: ClientEditNotesSection(vm: vm),
          ),
        ),
      ),
    ),
  );

  testWidgets('both notes fields are the shared editor', (tester) async {
    final vm = vmFor();
    addTearDown(vm.dispose);
    await pump(tester, vm, 480);

    expect(find.byType(SuperReader), findsNWidgets(2));
  });

  testWidgets('shows the words of a stored HTML note, not its tags', (
    tester,
  ) async {
    final vm = vmFor(publicNotes: '<p>Hi Bob</p><p>Thanks.</p>');
    addTearDown(vm.dispose);
    await pump(tester, vm, 480);

    expect(find.textContaining('<p>', findRichText: true), findsNothing);
    expect(find.textContaining('Hi Bob', findRichText: true), findsOneWidget);
  });

  testWidgets('fits the 360 px edit sidebar without overflowing', (
    tester,
  ) async {
    // The wide client layout puts this card in a narrow right-hand column, so
    // two editors stacked in it is the tight case.
    final vm = vmFor();
    addTearDown(vm.dispose);
    await pump(tester, vm, 360);

    expect(tester.takeException(), isNull);
  });
}
