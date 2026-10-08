import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/company_settings_api_model.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/repositories/design_repository.dart';
import 'package:admin/data/services/designs_api.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_library.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_view_model.dart';

class _FakeDesignsApi implements DesignsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

BlockSpec _spec(String type) => kBlockLibrary.firstWhere((s) => s.type == type);

/// The builder stays open after Save. The base view model was written for
/// forms that close on it: "unsaved" meant "differs from what was opened",
/// Discard meant "back to what was opened", and a save in create mode was
/// assumed to be the last. Each of those is wrong once the form lives on.
void main() {
  late AppDatabase db;
  late DesignRepository repo;
  const companyId = 'co1';

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DesignRepository(db: db, api: _FakeDesignsApi());
  });

  tearDown(() async => db.close());

  Design existing() => Design(
    id: 'd1',
    name: 'Letterhead',
    isCustom: true,
    isActive: true,
    isTemplate: false,
    isFree: false,
    entities: const ['invoice'],
    template: DesignTemplate(
      blocks: [_spec('logo').newInstance(idPrefix: 'logo', x: 0, y: 0)],
      documentSettings: const DocumentSettings(),
    ),
    updatedAt: DateTime.utc(2026),
    createdAt: DateTime.utc(2026),
    archivedAt: null,
    isDeleted: false,
  );

  WysiwygDesignViewModel editing() => WysiwygDesignViewModel(
    repo: repo,
    companyId: companyId,
    existing: existing(),
  );

  WysiwygDesignViewModel creating() => WysiwygDesignViewModel(
    repo: repo,
    companyId: companyId,
    seed: existing().copyWith(id: '', name: ''),
    defaultName: 'Visual design',
  );

  Future<List<({String kind, String entityId})>> outbox() async => [
    for (final row in await db.select(db.outbox).get())
      (kind: row.mutationKind, entityId: row.entityId),
  ];

  group('unsaved is measured against what was last saved', () {
    test('save, then undo back to what was opened: that is unsaved', () async {
      final vm = editing();
      vm.addBlock(_spec('divider'));
      expect(await vm.save(), isNotNull);
      expect(vm.isDirty, isFalse);
      expect(vm.hasUnsavedWork, isFalse);

      vm.undo(); // the page is as opened — and the server has the divider
      expect(vm.blocks, hasLength(1));
      expect(vm.isDirty, isTrue);
      expect(vm.hasUnsavedWork, isTrue, reason: 'Save must be enabled');

      expect(await vm.save(), isNotNull);
      expect(vm.isDirty, isFalse);
      final row = (await db.select(db.designs).get()).single;
      expect(row.payload.contains('divider'), isFalse);
    });

    test('the same from a starter', () async {
      final vm = creating();
      vm.addBlock(_spec('divider'));
      await vm.save();
      vm.undo();
      expect(vm.hasUnsavedWork, isTrue);
    });

    test('an edit, then undoing it, after a save: nothing to save', () async {
      final vm = editing();
      vm.addBlock(_spec('divider'));
      await vm.save();
      vm.addBlock(_spec('spacer'));
      expect(vm.isDirty, isTrue);
      vm.undo();
      // It used to prompt "Discard changes?" with nothing unsaved.
      expect(vm.isDirty, isFalse);
    });
  });

  group('Discard after a save goes back to the save', () {
    test(
      'an existing design returns to what was saved, not what was opened',
      () async {
        final vm = editing();
        vm.addBlock(_spec('divider'));
        await vm.save();
        vm.addBlock(_spec('spacer'));

        vm.resetToEmpty();
        expect(
          [for (final b in vm.blocks) b.type],
          ['logo', 'divider'],
          reason: 'the divider is on the server; the page must show it',
        );
        expect(vm.isDirty, isFalse);
      },
    );

    test('a new design returns to its save — not to a blank that the next '
        'Save would write over it', () async {
      final vm = creating();
      vm.addBlock(_spec('divider'));
      await vm.save();
      vm.setName('Half-typed');
      vm.addBlock(_spec('spacer'));

      vm.resetToEmpty();
      expect(vm.draft.name, 'Visual design');
      expect([for (final b in vm.blocks) b.type], ['logo', 'divider']);
      expect(vm.isDirty, isFalse);
      expect(vm.hasUnsavedWork, isFalse);
    });

    test('before any save it is still a blank form', () {
      final vm = creating();
      vm.addBlock(_spec('divider'));
      vm.resetToEmpty();
      expect(vm.blocks, isEmpty);
      expect(vm.isDirty, isFalse);
    });
  });

  group('a new design after its first save', () {
    test('once the create has landed, the next save is an update of it — '
        'and the view model knows its real id', () async {
      final vm = creating();
      final first = await vm.save();
      final tmp = first!.id;
      expect(tmp, startsWith('tmp_'));

      // The create lands: the server gave it an id.
      await db.idRemapDao.remember(
        entityType: 'design',
        tempId: tmp,
        realId: 'real1',
        now: 1,
      );
      await db.delete(db.outbox).go();

      vm.setName('Renamed');
      await vm.save();
      expect(await outbox(), [(kind: 'update', entityId: 'real1')]);
      // What company settings hold is the real id; a temp one never matches.
      expect(vm.savedDesignId, 'real1');
    });

    test('while it has not landed, a save re-sends the create — an update '
        'would wait behind a create that may never go', () async {
      final vm = creating();
      final first = await vm.save();
      vm.setName('Renamed');
      final second = await vm.save();
      expect(second!.id, first!.id);

      // One row, and it is the create, carrying the latest draft.
      final rows = await db.select(db.outbox).get();
      expect([for (final r in rows) r.mutationKind], ['create']);
      expect(rows.single.payload.contains('Renamed'), isTrue);
      expect(await db.select(db.designs).get(), hasLength(1));
    });

    test(
      'an unsynced id is not offered as the saved id to compare with',
      () async {
        final vm = creating();
        expect(vm.savedDesignId, isNull);
        await vm.save();
        // Still temp: nothing in company settings can equal it.
        expect(vm.savedDesignId, isNull);
        expect(vm.hasBeenSaved, isTrue);
      },
    );
  });

  group('page settings on a design that has none', () {
    test('fall back to the company\'s, not to built-in defaults', () {
      final vm = WysiwygDesignViewModel(
        repo: repo,
        companyId: companyId,
        existing: existing().copyWith(
          template: existing().template.copyWith(documentSettings: null),
        ),
        companySettings: const CompanySettingsApi(
          primaryFont: 'Lato',
          fontSize: 12,
          pageSize: 'Letter',
        ),
      );
      expect(vm.documentSettings.primaryFont, 'Lato');
      // Flipping the orientation must not also switch the font to Roboto.
      vm.setDocumentSettings(
        vm.documentSettings.copyWith(pageLayout: 'landscape'),
      );
      final saved = vm.draft.template.documentSettings!;
      expect(saved.pageLayout, 'landscape');
      expect(saved.primaryFont, 'Lato');
      expect(saved.globalFontSize, 12);
      expect(saved.pageSize, 'Letter');
    });
  });
}
