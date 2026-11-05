import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/services/clients_api.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/ui/core/edit/create_form_documents.dart';
import 'package:admin/ui/core/widgets/file_drop_zone.dart';
import 'package:admin/ui/features/clients/view_models/client_edit_view_model.dart';

import '../../../_localization_helper.dart';

/// Files attached on a create form before the record exists, for every
/// document-bearing entity (docs/attaching-documents.md). New Expense's own
/// tests (`expense_edit_view_model_test`) cover the retry and share paths;
/// this pins that the base class gives the same to an entity that is not an
/// expense.

class _FakeClientsApi implements ClientsApi {
  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  late ClientRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ClientRepository(db: db, api: _FakeClientsApi());
  });
  tearDown(() async => db.close());

  Future<List<OutboxRow>> all() =>
      (db.select(db.outbox)..orderBy([(o) => OrderingTerm.asc(o.id)])).get();

  test('a new client queues each attached file behind its create', () async {
    final vm = ClientEditViewModel(repo: repo, companyId: 'co')
      ..setName('Acme');
    addTearDown(vm.dispose);
    expect(vm.offersDocuments, isTrue);
    vm.addDocuments([
      fileUploadSource('/x/a.pdf'),
      BytesUploadSource(Uint8List(3), 'b.png'),
    ]);

    final saved = await vm.save();
    expect(saved!.id, startsWith('tmp_'));

    final queued = await all();
    expect(queued.map((r) => r.mutationKind), [
      MutationKind.create.wireName,
      MutationKind.documentUpload.wireName,
      MutationKind.documentUpload.wireName,
    ]);
    // The outbox holds an upload behind its record's create and rewrites the
    // temp id once the create lands.
    expect(queued.map((r) => r.entityId).toSet(), {saved.id});
    expect(jsonDecode(queued[1].payload)['local_path'], '/x/a.pdf');
    expect(vm.documents, isEmpty, reason: 'handed to the record for good');
  });

  test('once a save hands the files over, the form takes no more — they '
      'would be neither queued nor kept', () async {
    final vm = ClientEditViewModel(repo: repo, companyId: 'co')
      ..setName('Acme');
    addTearDown(vm.dispose);
    vm.addDocuments([fileUploadSource('/x/a.pdf')]);
    expect(await vm.save(), isNotNull);
    expect(vm.acceptsDocuments, isFalse);
    expect(vm.addDocuments([fileUploadSource('/x/late.pdf')]), isFalse);
    expect(vm.isDirty, isFalse, reason: 'no spurious Discard prompt');

    // Discard starts a fresh record, which takes files again.
    vm.reset(emptyDraft: emptyClient());
    expect(vm.acceptsDocuments, isTrue);
  });

  test('files make a new form dirty, even one Discard just cleaned', () {
    final vm = ClientEditViewModel(repo: repo, companyId: 'co');
    addTearDown(vm.dispose);
    expect(vm.isDirty, isFalse);
    vm.reset(emptyDraft: emptyClient());
    vm.addDocuments([fileUploadSource('/x/a.pdf')]);
    expect(vm.isDirty, isTrue);
  });

  test('an existing client takes none — its documents are on its record '
      'screen', () async {
    final vm = ClientEditViewModel(
      repo: repo,
      companyId: 'co',
      existing: Client.fromApi(
        const ClientApi(id: 'c1', name: 'Acme', updatedAt: 1700000000),
      ),
    );
    addTearDown(vm.dispose);
    expect(vm.offersDocuments, isFalse);
    expect(vm.addDocuments([fileUploadSource('/x/a.pdf')]), isFalse);
    expect(vm.documents, isEmpty);
  });

  testWidgets('the card lists the files, each removable, with the upload '
      'hint', (tester) async {
    final vm = ClientEditViewModel(repo: repo, companyId: 'co');
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: CreateFormDocumentsCard(vm: vm)),
        ),
      ),
    );
    expect(find.text('Documents'), findsOneWidget);
    expect(find.byType(FileDropZone), findsOneWidget);
    expect(find.text('These files upload when you save.'), findsNothing);

    vm.addDocuments([BytesUploadSource(Uint8List(3), 'contract.pdf')]);
    await tester.pump();
    expect(find.text('contract.pdf'), findsOneWidget);
    expect(find.text('These files upload when you save.'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove'));
    await tester.pump();
    expect(find.text('contract.pdf'), findsNothing);
    expect(vm.documents, isEmpty);
  });
}
