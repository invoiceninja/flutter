import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/purchase_order_api_model.dart';
import 'package:admin/data/repositories/purchase_order_repository.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/data/services/purchase_orders_api.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/ui/features/purchase_orders/view_models/purchase_order_list_view_model.dart';

/// A Status chip that includes Sent goes to the server only when the server
/// answers `client_status=sent` exactly (5.13.44+). Before that, a sent
/// purchase order past its due date fell out of the server's answer — a
/// subset the local predicate cannot put back — so the chip is applied
/// locally only there.
void main() {
  late AppDatabase db;
  late _Pos api;
  final vms = <PurchaseOrderListViewModel>[];

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = _Pos();
  });

  tearDown(() async {
    for (final vm in vms) {
      vm.dispose();
    }
    vms.clear();
    await db.close();
  });

  Future<Map<String, String>> fetchedWith(
    Set<String> statuses, {
    required bool exact,
  }) async {
    final vm = PurchaseOrderListViewModel(
      repo: PurchaseOrderRepository(db: db, api: api),
      companyId: 'co',
      navStateDao: db.navStateDao,
      userSettings: UserSettingsRepository(db: db),
      sentStatusExact: () => exact,
    );
    vms.add(vm);
    await vm.setExtraFilter(serverKey: 'client_status', values: statuses);
    api.calls.clear();
    await vm.fetchPage(
      page: 1,
      search: null,
      states: const {EntityState.active},
      extraFilters: {'client_status': statuses},
      ignoreCursor: true,
    );
    return api.calls.last;
  }

  test('a current server is asked for Sent', () async {
    final f = await fetchedWith({'sent', 'draft'}, exact: true);
    expect(f['client_status'], 'draft,sent');
  });

  test('an older server is not', () async {
    final f = await fetchedWith({'sent', 'draft'}, exact: false);
    expect(f.containsKey('client_status'), isFalse);
  });

  test('statuses without Sent go to any server', () async {
    final f = await fetchedWith({'draft', 'accepted'}, exact: false);
    expect(f['client_status'], 'accepted,draft');
  });
}

class _Pos implements PurchaseOrdersApi {
  final List<Map<String, String>> calls = [];

  @override
  Future<({PurchaseOrderListApi data, int? cursorUpdatedAt, String? cursorId})>
  list({
    required int page,
    int perPage = 50,
    String? search,
    int? sinceUpdatedAt,
    String? sinceId,
    Map<String, String> filters = const {},
  }) async {
    calls.add(filters);
    return (
      data: const PurchaseOrderListApi(),
      cursorUpdatedAt: null,
      cursorId: null,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
