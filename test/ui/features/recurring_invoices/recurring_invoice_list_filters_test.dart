import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/recurring_invoice_api_model.dart';
import 'package:admin/data/repositories/recurring_invoice_repository.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/data/services/recurring_invoices_api.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/ui/features/recurring_invoices/view_models/recurring_invoice_list_view_model.dart';

/// Captures the query `filters` the repository hands the list endpoint, so the
/// real VM → repo → api path pins the exact server param names.
class _FakeRecurringInvoicesApi implements RecurringInvoicesApi {
  final List<Map<String, String>> listFilters = [];

  @override
  Future<
    ({RecurringInvoiceListApi data, int? cursorUpdatedAt, String? cursorId})
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
      data: const RecurringInvoiceListApi(data: []),
      cursorUpdatedAt: null,
      cursorId: null,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  // `status_id` is an `InvoiceFilters`-only method; `RecurringInvoiceFilters`
  // narrows by status through `client_status` keywords instead.
  group('RecurringInvoiceListViewModel — status chip → client_status', () {
    late AppDatabase db;
    late _FakeRecurringInvoicesApi api;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      api = _FakeRecurringInvoicesApi();
    });
    tearDown(() async {
      await db.close();
    });

    Future<Map<String, String>> sentFor(
      Map<String, Set<String>> extraFilters,
    ) async {
      final vm = RecurringInvoiceListViewModel(
        repo: RecurringInvoiceRepository(db: db, api: api),
        companyId: 'co',
        navStateDao: db.navStateDao,
        userSettings: UserSettingsRepository(db: db),
        searchDebounce: const Duration(milliseconds: 1),
        persistDebounce: const Duration(milliseconds: 1),
      );
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

    test('status ids go out as client_status keywords', () async {
      final sent = await sentFor({
        'status_id': {'2', '3'},
      });
      expect((sent['client_status'] ?? '').split(','), {'active', 'paused'});
      expect(sent.containsKey('status_id'), isFalse);
    });

    test("a status tab's exact keyword wins the wire", () async {
      final sent = await sentFor({
        'status_id': {'1'},
        'client_status': {'active'},
      });
      expect(sent['client_status'], 'active');
      expect(sent.containsKey('status_id'), isFalse);
    });

    test('an unknown id sends no status rather than a narrower one', () async {
      final sent = await sentFor({
        'status_id': {'2', '-1'},
      });
      expect(sent.containsKey('client_status'), isFalse);
      expect(sent.containsKey('status_id'), isFalse);
    });

    test('no chip → no client_status', () async {
      final sent = await sentFor(const {});
      expect(sent.containsKey('client_status'), isFalse);
    });
  });
}
