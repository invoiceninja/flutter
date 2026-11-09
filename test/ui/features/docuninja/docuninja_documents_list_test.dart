import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/data/services/docuninja/docuninja_api.dart';
import 'package:admin/data/services/docuninja/docuninja_client.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/ui/core/widgets/file_drop_zone.dart';
import 'package:admin/ui/core/widgets/selection_checkbox.dart';
import 'package:admin/ui/features/docuninja/view_models/docuninja_documents_view_model.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_create_dialog.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_documents_list.dart';

import '../shell/_shell_test_helpers.dart';

class _Api implements DocuNinjaApi {
  _Api({this.fail = false, this.rows = 0});

  /// The documents call fails (not offline).
  final bool fail;
  final int rows;

  final created = <({String description, List<DnUploadPart> files})>[];

  @override
  Future<DnDocument> createDocument({
    required String description,
    required List<DnUploadPart> files,
  }) async {
    created.add((description: description, files: files));
    return DnDocument.fromJson({'id': 'new1', 'status_id': 1});
  }

  @override
  Future<DnPage<DnDocument>> documents({
    int page = 1,
    int perPage = 20,
    String search = '',
    String status = '',
    String sort = 'id|desc',
  }) async {
    if (fail) throw StateError('boom');
    return DnPage(
      items: [
        for (var i = 0; i < rows; i++)
          DnDocument.fromJson({'id': 'd$i', 'status_id': 1}),
      ],
      currentPage: 1,
      lastPage: 1,
      total: rows,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

UploadSource _file(String name) =>
    BytesUploadSource(Uint8List.fromList('not a pdf'.codeUnits), name);

Future<void> _drop(WidgetTester tester, List<UploadSource> files) async {
  final zone = tester.widget<FileDropZone>(find.byType(FileDropZone));
  await zone.onFiles(files);
  await tester.pump();
}

void main() {
  testWidgets('dropped files become a document named after the first', (
    tester,
  ) async {
    final fixture = await buildFixture(
      companies: [FakeCompany(id: 'co1', name: 'Acme')],
    );
    addTearDown(fixture.dispose);
    final api = _Api();
    final opened = <String>[];
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Scaffold(
          body: DocuNinjaDropZone(api: api, onCreated: (d) => opened.add(d.id)),
        ),
      ),
    );

    await _drop(tester, [_file('Sales_contract.docx'), _file('terms.png')]);

    expect(api.created, hasLength(1));
    expect(api.created.single.description, 'Sales Contract');
    expect(api.created.single.files.map((f) => f.source.fileName), [
      'Sales_contract.docx',
      'terms.png',
    ]);
    expect(opened, ['new1']);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('an unsupported file is refused, never uploaded', (tester) async {
    final fixture = await buildFixture(
      companies: [FakeCompany(id: 'co1', name: 'Acme')],
    );
    addTearDown(fixture.dispose);
    final api = _Api();
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Scaffold(
          body: DocuNinjaDropZone(api: api, onCreated: (_) {}),
        ),
      ),
    );

    await _drop(tester, [_file('archive.zip')]);

    expect(api.created, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the list shows its header above an empty list', (tester) async {
    final fixture = await buildFixture(
      companies: [FakeCompany(id: 'co1', name: 'Acme')],
    );
    addTearDown(fixture.dispose);
    final vm = DocuNinjaDocumentsViewModel(api: _Api());
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        DocuNinjaDocumentsList(
          vm: vm,
          onOpen: (_) {},
          header: const Text('drop-here'),
        ),
      ),
    );
    await vm.refresh();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('drop-here'), findsOneWidget);
    expect(find.text('No records found'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a failed first page answers in place, under the header', (
    tester,
  ) async {
    final fixture = await buildFixture(
      companies: [FakeCompany(id: 'co1', name: 'Acme')],
    );
    addTearDown(fixture.dispose);
    final vm = DocuNinjaDocumentsViewModel(api: _Api(fail: true));
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        DocuNinjaDocumentsList(
          vm: vm,
          onOpen: (_) {},
          header: const Text('drop-here'),
        ),
      ),
    );
    await vm.refresh();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('drop-here'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a filtered empty list offers Clear filters; an unfiltered '
      'one does not', (tester) async {
    final fixture = await buildFixture(
      companies: [FakeCompany(id: 'co1', name: 'Acme')],
    );
    addTearDown(fixture.dispose);
    final vm = DocuNinjaDocumentsViewModel(api: _Api());
    addTearDown(vm.dispose);
    var cleared = 0;
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        DocuNinjaDocumentsList(
          vm: vm,
          onOpen: (_) {},
          onClearFilters: () => cleared++,
        ),
      ),
    );
    await vm.refresh();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('No records found'), findsOneWidget);
    expect(find.text('Clear Filters'), findsNothing);

    vm.setFilters(statuses: {'sent'}, states: {'active'});
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Clear Filters'));
    expect(cleared, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the table header ticks every row, then clears them', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fixture = await buildFixture(
      companies: [FakeCompany(id: 'co1', name: 'Acme')],
    );
    addTearDown(fixture.dispose);
    final vm = DocuNinjaDocumentsViewModel(api: _Api(rows: 3));
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        DocuNinjaDocumentsList(vm: vm, onOpen: (_) {}, selectable: true),
      ),
    );
    await vm.refresh();
    await tester.pump(const Duration(milliseconds: 50));
    vm.toggleSelected(vm.items.first);
    await tester.pump();

    // Selecting shows every checkbox; the header's is the first.
    await tester.tap(find.byType(SelectionCheckbox).first);
    await tester.pump();
    expect(vm.countSelected, 3);
    await tester.tap(find.byType(SelectionCheckbox).first);
    await tester.pump();
    expect(vm.isSelecting, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
