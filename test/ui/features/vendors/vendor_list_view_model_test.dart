import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/vendor_api_model.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/data/repositories/vendor_repository.dart';
import 'package:admin/data/services/vendors_api.dart';
import 'package:admin/domain/columns/vendor_columns.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/ui/features/vendors/view_models/vendor_list_view_model.dart';

/// First coverage for `VendorListViewModel`. Mirrors
/// `client_list_view_model_test.dart` — fake API + real in-memory repository,
/// so the production dataflow is exercised rather than mocked away.
///
/// The invariant worth pinning above the rest is
/// **`isValidColumnId(defaultSortField)`**: `isValidColumnId` is the sort gate,
/// so a default sort field that isn't a sortable column makes the list load
/// nothing at all, silently.
class _FakeVendorsApi implements VendorsApi {
  final Map<int, List<VendorApi>> pages = {};
  final List<({int page, String? search, Map<String, String> filters})> calls =
      [];
  Object? nextError;

  @override
  Future<({VendorListApi data, int? cursorUpdatedAt, String? cursorId})> list({
    required int page,
    int perPage = 50,
    String? search,
    int? sinceUpdatedAt,
    String? sinceId,
    Map<String, String> filters = const {},
  }) async {
    calls.add((
      page: page,
      search: search,
      filters: Map<String, String>.from(filters),
    ));
    if (nextError != null) {
      final err = nextError;
      nextError = null;
      throw err!;
    }
    final rows = pages[page] ?? const <VendorApi>[];
    return (
      data: VendorListApi(data: rows),
      cursorUpdatedAt: rows.isNotEmpty ? rows.last.updatedAt : null,
      cursorId: rows.isNotEmpty ? rows.last.id : null,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

VendorApi _row(String id, {String? name}) =>
    VendorApi(id: id, name: name ?? id, updatedAt: 100);

void main() {
  late AppDatabase db;
  late _FakeVendorsApi api;
  late VendorRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = _FakeVendorsApi();
    repo = VendorRepository(db: db, api: api);
  });
  tearDown(() async => db.close());

  VendorListViewModel vmFor() {
    final vm = VendorListViewModel(
      repo: repo,
      navStateDao: db.navStateDao,
      userSettings: UserSettingsRepository(db: db),
      companyId: 'co',
      searchDebounce: const Duration(milliseconds: 1),
      persistDebounce: const Duration(milliseconds: 1),
    );
    addTearDown(vm.dispose);
    return vm;
  }

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('initial load', () {
    test('fetches page 1 on construction and exposes the rows', () async {
      api.pages[1] = [_row('v1'), _row('v2')];

      final vm = vmFor();
      await settle();

      expect(api.calls, hasLength(1));
      expect(api.calls.single.page, 1);
      expect(vm.items.map((v) => v.id), ['v1', 'v2']);
    });

    test('captures a fetch error so the screen can render ErrorView, and '
        'retryInitial clears it', () async {
      api.nextError = Exception('boom');

      final vm = vmFor();
      await settle();
      expect(vm.initialError, isNotNull);
      expect(vm.items, isEmpty);

      api.pages[1] = [_row('v1')];
      await vm.retryInitial();
      await settle();

      expect(vm.initialError, isNull);
      expect(vm.items.map((v) => v.id), ['v1']);
    });
  });

  group('sort contract', () {
    test('the default sort field is a sortable column', () async {
      final vm = vmFor();
      // Settle even though the assertions are synchronous: the constructor
      // kicks off an unawaited initial load, and tearDown would otherwise
      // close the DB out from under it.
      await settle();

      expect(
        vm.isValidColumnId(vm.defaultSortField),
        isTrue,
        reason:
            'isValidColumnId gates sorting — a default that fails it makes '
            'the list silently load nothing',
      );
      expect(vm.sortField, VendorFieldIds.name);
    });

    test('setSort switches field and direction', () async {
      final vm = vmFor();
      await settle();

      await vm.setSort(field: VendorFieldIds.number, ascending: false);

      expect(vm.sortField, VendorFieldIds.number);
      expect(vm.sortAscending, isFalse);
    });

    test('every default column is a real column id', () async {
      final vm = vmFor();
      await settle();
      final known = vm.allColumns.map((c) => c.id).toSet();

      expect(known, containsAll(vm.defaultColumnIds));
    });
  });

  group('lifecycle state filter', () {
    test(
      'setStates sends the lifecycle `status` param, not client_status',
      () async {
        api.pages[1] = [_row('v1')];
        final vm = vmFor();
        await settle();
        api.calls.clear();

        await vm.setStates({EntityState.active, EntityState.archived});
        await settle();

        expect(vm.states, {EntityState.active, EntityState.archived});
        expect(api.calls, isNotEmpty);
        expect(
          api.calls.last.filters['status'],
          contains('archived'),
          reason:
              'lifecycle rides the shared `status` param; client_status is the '
              'per-entity business status and would silently no-op here',
        );
      },
    );
  });
}
