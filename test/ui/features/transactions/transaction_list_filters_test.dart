import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/bank_transaction_api_model.dart';
import 'package:admin/data/repositories/bank_transaction_repository.dart';
import 'package:admin/data/repositories/tag_repository.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/data/services/bank_transactions_api.dart';
import 'package:admin/data/services/tags_api.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/ui/core/list/search/date_column_filter_key.dart';
import 'package:admin/ui/features/transactions/view_models/transaction_list_view_model.dart';
import 'package:admin/ui/features/transactions/widgets/transaction_filter_keys.dart';

/// Captures the query `filters` the repository hands the list endpoint so we
/// can pin the exact server param names (the dataflow VM → repo → api is the
/// real production path; only the HTTP edge is faked).
class _FakeBankTransactionsApi implements BankTransactionsApi {
  final List<Map<String, String>> listFilters = [];

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
    listFilters.add(Map<String, String>.from(filters));
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
  group('TransactionListViewModel — bank-account scope (B1)', () {
    late AppDatabase db;
    late _FakeBankTransactionsApi api;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      api = _FakeBankTransactionsApi();
    });
    tearDown(() async {
      await db.close();
    });

    TransactionListViewModel makeVm({String? bankAccountId}) =>
        TransactionListViewModel(
          repo: BankTransactionRepository(db: db, api: api),
          companyId: 'co',
          navStateDao: db.navStateDao,
          userSettings: UserSettingsRepository(db: db),
          searchDebounce: const Duration(milliseconds: 1),
          persistDebounce: const Duration(milliseconds: 1),
          bankAccountId: bankAccountId,
        );

    test('embedded list sends the plural bank_integration_ids param '
        '(the singular form is silently ignored server-side)', () async {
      final vm = makeVm(bankAccountId: 'acct_1');
      addTearDown(vm.dispose);

      await vm.fetchPage(
        page: 1,
        search: null,
        states: const {EntityState.active},
        extraFilters: const {},
        ignoreCursor: false,
      );

      expect(api.listFilters, isNotEmpty);
      final sent = api.listFilters.last;
      expect(sent['bank_integration_ids'], 'acct_1');
      expect(sent.containsKey('bank_integration_id'), isFalse);
    });

    test('unscoped workspace list sends no bank-account filter', () async {
      final vm = makeVm();
      addTearDown(vm.dispose);

      await vm.fetchPage(
        page: 1,
        search: null,
        states: const {EntityState.active},
        extraFilters: const {},
        ignoreCursor: false,
      );

      expect(api.listFilters, isNotEmpty);
      final sent = api.listFilters.last;
      expect(sent.containsKey('bank_integration_ids'), isFalse);
      expect(sent.containsKey('bank_integration_id'), isFalse);
    });

    test(
      'bank-account-scoped list is isEmbedded so it does not read/write the '
      'standalone /transactions nav_state slot (filter-bleed regression)',
      () {
        final embedded = makeVm(bankAccountId: 'acct_1');
        addTearDown(embedded.dispose);
        expect(embedded.isEmbedded, isTrue);
        expect(embedded.lockedFilterKeyIds, isNotEmpty);

        // The standalone workspace list must stay non-embedded so it keeps
        // persisting the user's "resume where you left off" filters.
        final standalone = makeVm();
        addTearDown(standalone.dispose);
        expect(standalone.isEmbedded, isFalse);
        expect(standalone.lockedFilterKeyIds, isEmpty);
      },
    );
  });

  group('buildTransactionFilterKeys — date range (P1)', () {
    test('exposes a transaction-date range filter routing to date_range', () {
      // `TagFilterKey` opens a Drift watch in its constructor, so build the
      // keys against a real in-memory db + tag repo and dispose after.
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final tags = TagRepository(db: db, api: _StubTagsApi());
      final keys = buildTransactionFilterKeys(tags: tags, companyId: 'co_1');
      addTearDown(() {
        for (final k in keys) {
          k.dispose();
        }
      });
      final dateKeys = keys.whereType<DateColumnFilterKey>().toList();
      expect(dateKeys, hasLength(1));
      expect(dateKeys.single.serverKey, 'date');
      expect(dateKeys.single.rangeServerKey, 'date_range');
    });
  });

  group(
    'TransactionListViewModel — status/type → client_status server param',
    () {
      late AppDatabase db;
      late _FakeBankTransactionsApi api;

      setUp(() {
        db = AppDatabase(NativeDatabase.memory());
        api = _FakeBankTransactionsApi();
      });
      tearDown(() async {
        await db.close();
      });

      TransactionListViewModel makeVm() => TransactionListViewModel(
        repo: BankTransactionRepository(db: db, api: api),
        companyId: 'co',
        navStateDao: db.navStateDao,
        userSettings: UserSettingsRepository(db: db),
        searchDebounce: const Duration(milliseconds: 1),
        persistDebounce: const Duration(milliseconds: 1),
      );

      Future<Map<String, String>> sentFor(
        Map<String, Set<String>> extraFilters,
      ) async {
        final vm = makeVm();
        addTearDown(vm.dispose);
        await vm.fetchPage(
          page: 1,
          search: null,
          states: const {EntityState.active},
          extraFilters: extraFilters,
          ignoreCursor: false,
        );
        return api.listFilters.last;
      }

      test('status chip maps to a client_status keyword (no raw status_id) — '
          'BankTransactionFilters has no status_id handler', () async {
        final sent = await sentFor({
          'status_id': {'2'},
        });
        expect(sent['client_status'], 'matched');
        expect(sent.containsKey('status_id'), isFalse);
      });

      test(
        'type chip maps to a client_status keyword (no raw base_type)',
        () async {
          final sent = await sentFor({
            'base_type': {'CREDIT'},
          });
          expect(sent['client_status'], 'deposits');
          expect(sent.containsKey('base_type'), isFalse);
        },
      );

      test('status + type combine into one client_status value', () async {
        final sent = await sentFor({
          'status_id': {'2'},
          'base_type': {'CREDIT'},
        });
        final parts = (sent['client_status'] ?? '').split(',');
        expect(parts, containsAll(<String>['matched', 'deposits']));
        expect(sent.containsKey('status_id'), isFalse);
        expect(sent.containsKey('base_type'), isFalse);
      });

      test('multiple statuses map to multiple keywords', () async {
        final sent = await sentFor({
          'status_id': {'1', '3'},
        });
        final parts = (sent['client_status'] ?? '').split(',');
        expect(parts, containsAll(<String>['unmatched', 'converted']));
      });

      test('no status/type filter → no client_status key', () async {
        final sent = await sentFor(const {});
        expect(sent.containsKey('client_status'), isFalse);
      });

      test('single-date `date` comparator is not sent (no server handler), '
          'but the `date_range` window is forwarded', () async {
        final dateOnly = await sentFor({
          'date': {'gte:2026-01-01'},
        });
        expect(dateOnly.containsKey('date'), isFalse);

        final windowed = await sentFor({
          'date_range': {'date,2026-01-01,2026-03-31'},
        });
        expect(windowed['date_range'], 'date,2026-01-01,2026-03-31');
      });
    },
  );
}

/// The tag filter reads tags from the local DAO (never the API) in this test,
/// so the API is never exercised — throw if anything reaches it.
class _StubTagsApi implements TagsApi {
  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
