// Regression: the project-scoped embedded lists, on both halves of the fix.
//
// A project's detail tabs (Invoices / Expenses / Tasks / Quotes) build their
// list VM with `projectId:`. That scope used to reach ONLY `watchPage`'s
// pre-LIMIT `WHERE project_id` and never the fetch — so the tab pulled the
// newest page COMPANY-wide, filtered it locally to nothing, and rendered a
// permanent "No records found" on a project that has records. An embedded list
// has no pull-to-refresh to escape with.
//
// Three of the four have a server filter and now send it — under three
// DIFFERENT names, each taken from that entity's own `*Filters.php`, which is
// exactly the kind of thing that goes wrong silently (a wrong key is simply
// ignored by the server and the page comes back unnarrowed):
//
//     invoices  → project_id      (InvoiceFilters::project_id)
//     expenses  → project_ids     (ExpenseFilters::project_ids)
//     tasks     → project_tasks   (TaskFilters::project_tasks)
//
// Quotes has none — `QuoteFilters.php` has no project method — so it stays
// local-only and must instead arm the auto-chain via `localOnlyFilterActive`,
// or a short locally-gutted page has no scroll extent and dead-ends the same
// way. That getter is a one-line override, the shape most likely to be tidied
// away by someone who cannot see what it is load-bearing for.

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/bank_transaction_api_model.dart';
import 'package:admin/data/models/api/expense_api_model.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/api/quote_api_model.dart';
import 'package:admin/data/models/api/task_api_model.dart';
import 'package:admin/data/repositories/bank_transaction_repository.dart';
import 'package:admin/data/repositories/expense_repository.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/repositories/quote_repository.dart';
import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/data/services/bank_transactions_api.dart';
import 'package:admin/data/services/expenses_api.dart';
import 'package:admin/data/services/invoices_api.dart';
import 'package:admin/data/services/quotes_api.dart';
import 'package:admin/data/services/tasks_api.dart';
import 'package:admin/ui/features/expenses/view_models/expense_list_view_model.dart';
import 'package:admin/ui/features/invoices/view_models/invoice_list_view_model.dart';
import 'package:admin/ui/features/quotes/view_models/quote_list_view_model.dart';
import 'package:admin/ui/features/tasks/view_models/task_list_view_model.dart';
import 'package:admin/ui/features/transactions/view_models/transaction_list_view_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the wire `filters` map of every list request.
class _Calls {
  final List<Map<String, String>> filters = [];
}

class _FakeInvoicesApi implements InvoicesApi {
  _FakeInvoicesApi(this.calls);
  final _Calls calls;
  @override
  Future<({InvoiceListApi data, int? cursorUpdatedAt, String? cursorId})> list({
    required int page,
    int perPage = 50,
    String? search,
    int? sinceUpdatedAt,
    String? sinceId,
    Map<String, String> filters = const {},
  }) async {
    calls.filters.add(Map.of(filters));
    return (
      data: const InvoiceListApi(data: []),
      cursorUpdatedAt: null,
      cursorId: null,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeExpensesApi implements ExpensesApi {
  _FakeExpensesApi(this.calls);
  final _Calls calls;
  @override
  Future<({ExpenseListApi data, int? cursorUpdatedAt, String? cursorId})> list({
    required int page,
    int perPage = 50,
    String? search,
    int? sinceUpdatedAt,
    String? sinceId,
    Map<String, String> filters = const {},
  }) async {
    calls.filters.add(Map.of(filters));
    return (
      data: const ExpenseListApi(data: []),
      cursorUpdatedAt: null,
      cursorId: null,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeTasksApi implements TasksApi {
  _FakeTasksApi(this.calls);
  final _Calls calls;
  @override
  Future<({TaskListApi data, int? cursorUpdatedAt, String? cursorId})> list({
    required int page,
    int perPage = 50,
    String? search,
    int? sinceUpdatedAt,
    String? sinceId,
    Map<String, String> filters = const {},
  }) async {
    calls.filters.add(Map.of(filters));
    return (
      data: const TaskListApi(data: []),
      cursorUpdatedAt: null,
      cursorId: null,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeQuotesApi implements QuotesApi {
  _FakeQuotesApi(this.calls);
  final _Calls calls;
  @override
  Future<({QuoteListApi data, int? cursorUpdatedAt, String? cursorId})> list({
    required int page,
    int perPage = 50,
    String? search,
    int? sinceUpdatedAt,
    String? sinceId,
    Map<String, String> filters = const {},
  }) async {
    calls.filters.add(Map.of(filters));
    return (
      data: const QuoteListApi(data: []),
      cursorUpdatedAt: null,
      cursorId: null,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeBankTransactionsApi implements BankTransactionsApi {
  _FakeBankTransactionsApi(this.calls);
  final _Calls calls;
  @override
  Future<
    ({BankTransactionListApi data, int? cursorUpdatedAt, String? cursorId})
  >
  list({
    required int page,
    int perPage = 50,
    String? search,
    int? sinceUpdatedAt,
    String? sinceId,
    Map<String, String> filters = const {},
  }) async {
    calls.filters.add(Map.of(filters));
    return (
      data: const BankTransactionListApi(data: []),
      cursorUpdatedAt: null,
      cursorId: null,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  late _Calls calls;
  late UserSettingsRepository userSettings;
  late SettingsRepository settings;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    calls = _Calls();
    userSettings = UserSettingsRepository(db: db);
    settings = SettingsRepository(db: db);
  });
  tearDown(() async => db.close());

  Future<void> settle() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('project scope reaches the server fetch', () {
    test('invoices send project_id', () async {
      InvoiceListViewModel(
        repo: InvoiceRepository(
          db: db,
          api: _FakeInvoicesApi(calls),
          settings: settings,
        ),
        companyId: 'co',
        navStateDao: db.navStateDao,
        userSettings: userSettings,
        projectId: 'p1',
      );
      await settle();

      expect(calls.filters, isNotEmpty);
      expect(
        calls.filters.first['project_id'],
        'p1',
        reason: 'InvoiceFilters::project_id is the server-side name',
      );
    });

    test(
      'expenses send project_ids (plural — the server spells it so)',
      () async {
        ExpenseListViewModel(
          repo: ExpenseRepository(db: db, api: _FakeExpensesApi(calls)),
          companyId: 'co',
          navStateDao: db.navStateDao,
          userSettings: userSettings,
          projectId: 'p1',
        );
        await settle();

        expect(calls.filters, isNotEmpty);
        expect(calls.filters.first['project_ids'], 'p1');
        expect(
          calls.filters.first.containsKey('project_id'),
          isFalse,
          reason: 'the singular key is silently ignored by ExpenseFilters',
        );
      },
    );

    test('tasks send project_tasks', () async {
      TaskListViewModel(
        repo: TaskRepository(db: db, api: _FakeTasksApi(calls)),
        companyId: 'co',
        navStateDao: db.navStateDao,
        userSettings: userSettings,
        projectId: 'p1',
      );
      await settle();

      expect(calls.filters, isNotEmpty);
      expect(calls.filters.first['project_tasks'], 'p1');
    });

    test('an unscoped list sends no project filter at all', () async {
      InvoiceListViewModel(
        repo: InvoiceRepository(
          db: db,
          api: _FakeInvoicesApi(calls),
          settings: settings,
        ),
        companyId: 'co',
        navStateDao: db.navStateDao,
        userSettings: userSettings,
      );
      await settle();

      expect(calls.filters, isNotEmpty);
      for (final f in calls.filters) {
        expect(f.keys.where((k) => k.startsWith('project')), isEmpty);
      }
    });
  });

  group('localOnlyFilterActive arms the auto-chain', () {
    test('quotes: project scope is local-only, so it must widen', () async {
      final repo = QuoteRepository(db: db, api: _FakeQuotesApi(calls));

      final scoped = QuoteListViewModel(
        repo: repo,
        companyId: 'co',
        navStateDao: db.navStateDao,
        userSettings: userSettings,
        projectId: 'p1',
      );
      final unscoped = QuoteListViewModel(
        repo: repo,
        companyId: 'co',
        navStateDao: db.navStateDao,
        userSettings: userSettings,
      );
      await settle();

      expect(
        scoped.localOnlyFilterActive,
        isTrue,
        reason:
            'QuoteFilters.php has no project method, so the DAO predicate is '
            'the only narrowing — a gutted page needs the auto-chain',
      );
      expect(unscoped.localOnlyFilterActive, isFalse);

      // And the corollary: with no server filter to send, nothing
      // project-shaped may go on the wire.
      for (final f in calls.filters) {
        expect(f.keys.where((k) => k.startsWith('project')), isEmpty);
      }
    });

    test(
      'transactions: a date filter is local-only, so it must widen',
      () async {
        final vm = TransactionListViewModel(
          repo: BankTransactionRepository(
            db: db,
            api: _FakeBankTransactionsApi(calls),
          ),
          companyId: 'co',
          navStateDao: db.navStateDao,
          userSettings: userSettings,
          searchDebounce: const Duration(milliseconds: 1),
          persistDebounce: const Duration(milliseconds: 1),
        );
        await settle();
        expect(vm.localOnlyFilterActive, isFalse);

        await vm.setExtraFilter(
          serverKey: 'date',
          values: {'2026-01-01,2026-01-31'},
        );
        await settle();

        expect(
          vm.localOnlyFilterActive,
          isTrue,
          reason:
              'the request strips `date` (no BankTransactionFilters::date), so '
              'the DAO predicate guts the page and the auto-chain must re-arm',
        );
        // The stripped key must not reach the wire either, or the window
        // freezes after ceil(matches / pageSize) pages.
        for (final f in calls.filters) {
          expect(f.containsKey('date'), isFalse);
        }
      },
    );
  });
}
