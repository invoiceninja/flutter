import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/recurring_expense_api_model.dart';
import 'package:admin/data/repositories/recurring_expense_repository.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/data/services/recurring_expenses_api.dart';
import 'package:admin/data/db/dao/recurring_expense_dao.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/ui/features/recurring_expenses/view_models/recurring_expense_list_view_model.dart';

/// First coverage for `RecurringExpenseListViewModel`, completing the three
/// feature areas that had no `test/ui/features/<name>/` directory. Mirrors
/// `client_list_view_model_test.dart`.
///
/// Its default sort is `next_send_date` rather than a name or date column, so
/// the `isValidColumnId(defaultSortField)` pin matters here too — that gate is
/// what decides whether the list loads at all.
class _FakeRecurringExpensesApi implements RecurringExpensesApi {
  final Map<int, List<RecurringExpenseApi>> pages = {};
  final List<({int page, String? search, Map<String, String> filters})> calls =
      [];
  Object? nextError;

  @override
  Future<
    ({RecurringExpenseListApi data, int? cursorUpdatedAt, String? cursorId})
  >
  list({
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
    final rows = pages[page] ?? const <RecurringExpenseApi>[];
    return (
      data: RecurringExpenseListApi(data: rows),
      cursorUpdatedAt: rows.isNotEmpty ? rows.last.updatedAt : null,
      cursorId: rows.isNotEmpty ? rows.last.id : null,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

RecurringExpenseApi _row(String id) =>
    RecurringExpenseApi(id: id, updatedAt: 100);

void main() {
  late AppDatabase db;
  late _FakeRecurringExpensesApi api;
  late RecurringExpenseRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = _FakeRecurringExpensesApi();
    repo = RecurringExpenseRepository(db: db, api: api);
  });
  tearDown(() async => db.close());

  RecurringExpenseListViewModel vmFor() {
    final vm = RecurringExpenseListViewModel(
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
      api.pages[1] = [_row('r1'), _row('r2')];

      final vm = vmFor();
      await settle();

      expect(api.calls, hasLength(1));
      expect(api.calls.single.page, 1);
      expect(vm.items.map((r) => r.id), ['r1', 'r2']);
    });

    test('captures a fetch error, and retryInitial clears it', () async {
      api.nextError = Exception('boom');

      final vm = vmFor();
      await settle();
      expect(vm.initialError, isNotNull);

      api.pages[1] = [_row('r1')];
      await vm.retryInitial();
      await settle();

      expect(vm.initialError, isNull);
      expect(vm.items.map((r) => r.id), ['r1']);
    });
  });

  group('sort contract', () {
    test('the default sort field is accepted by the sort gate', () async {
      final vm = vmFor();
      await settle();

      expect(vm.sortField, RecurringExpenseFieldIds.nextSendDate);
      expect(
        vm.isValidColumnId(vm.defaultSortField),
        isTrue,
        reason: 'a default the gate rejects makes the list load nothing',
      );
    });

    test(
      'updated_at is accepted even though it is not a visible column',
      () async {
        final vm = vmFor();
        await settle();

        expect(vm.isValidColumnId(RecurringExpenseFieldIds.updatedAt), isTrue);
      },
    );

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
      api.pages[1] = [_row('r1')];
      final vm = vmFor();
      await settle();
      api.calls.clear();

      await vm.setStates({EntityState.active, EntityState.archived});
      await settle();

      expect(vm.states, {EntityState.active, EntityState.archived});
      expect(api.calls, isNotEmpty);
      expect(api.calls.last.filters['status'], contains('archived'));
    });
  });
}
