import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/expense_api_model.dart';
import 'package:admin/data/repositories/expense_repository.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/data/services/expenses_api.dart';
import 'package:admin/data/db/dao/expense_dao.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/ui/features/expenses/view_models/expense_list_view_model.dart';

/// First coverage for `ExpenseListViewModel`. Mirrors
/// `client_list_view_model_test.dart` — fake API + real in-memory repository.
///
/// Expenses are one of the VMs that widen `isValidColumnId` beyond the column
/// catalogue (it also accepts `updated_at`), which makes the
/// `isValidColumnId(defaultSortField)` check worth pinning: `isValidColumnId`
/// is the sort gate, and a default that fails it makes the list silently load
/// nothing.
class _FakeExpensesApi implements ExpensesApi {
  final Map<int, List<ExpenseApi>> pages = {};
  final List<({int page, String? search, Map<String, String> filters})> calls =
      [];
  Object? nextError;

  @override
  Future<({ExpenseListApi data, int? cursorUpdatedAt, String? cursorId})> list({
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
    final rows = pages[page] ?? const <ExpenseApi>[];
    return (
      data: ExpenseListApi(data: rows),
      cursorUpdatedAt: rows.isNotEmpty ? rows.last.updatedAt : null,
      cursorId: rows.isNotEmpty ? rows.last.id : null,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

ExpenseApi _row(String id) => ExpenseApi(id: id, updatedAt: 100);

void main() {
  late AppDatabase db;
  late _FakeExpensesApi api;
  late ExpenseRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = _FakeExpensesApi();
    repo = ExpenseRepository(db: db, api: api);
  });
  tearDown(() async => db.close());

  ExpenseListViewModel vmFor() {
    final vm = ExpenseListViewModel(
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

  /// The constructor kicks off an unawaited initial load; every test settles
  /// before asserting so tearDown can't close the DB mid-flight.
  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('initial load', () {
    test('fetches page 1 on construction and exposes the rows', () async {
      api.pages[1] = [_row('e1'), _row('e2')];

      final vm = vmFor();
      await settle();

      expect(api.calls, hasLength(1));
      expect(api.calls.single.page, 1);
      expect(vm.items.map((e) => e.id), ['e1', 'e2']);
    });

    test('captures a fetch error, and retryInitial clears it', () async {
      api.nextError = Exception('boom');

      final vm = vmFor();
      await settle();
      expect(vm.initialError, isNotNull);

      api.pages[1] = [_row('e1')];
      await vm.retryInitial();
      await settle();

      expect(vm.initialError, isNull);
      expect(vm.items.map((e) => e.id), ['e1']);
    });
  });

  group('sort contract', () {
    test('the default sort field is accepted by the sort gate', () async {
      final vm = vmFor();
      await settle();

      expect(vm.sortField, ExpenseFieldIds.date);
      expect(
        vm.isValidColumnId(vm.defaultSortField),
        isTrue,
        reason: 'a default the gate rejects makes the list load nothing',
      );
    });

    test('updated_at is explicitly accepted by the widened gate', () async {
      final vm = vmFor();
      await settle();

      // `ExpenseListViewModel.isValidColumnId` is
      // `isSortableColumnId(...) || field == updatedAt` — the second arm is
      // what keeps a saved "sort by last updated" working.
      expect(vm.isValidColumnId(ExpenseFieldIds.updatedAt), isTrue);
    });

    test('an unknown field is rejected', () async {
      final vm = vmFor();
      await settle();

      expect(vm.isValidColumnId('not_a_field'), isFalse);
    });

    test('every default column is a real column id', () async {
      final vm = vmFor();
      await settle();

      expect(
        vm.allColumns.map((c) => c.id).toSet(),
        containsAll(vm.defaultColumnIds),
      );
    });
  });

  group('lifecycle state filter', () {
    test('setStates sends the lifecycle `status` param', () async {
      api.pages[1] = [_row('e1')];
      final vm = vmFor();
      await settle();
      api.calls.clear();

      await vm.setStates({EntityState.active, EntityState.deleted});
      await settle();

      expect(vm.states, {EntityState.active, EntityState.deleted});
      expect(api.calls, isNotEmpty);
      expect(api.calls.last.filters['status'], contains('deleted'));
    });
  });
}
