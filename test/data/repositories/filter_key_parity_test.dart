import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/expense_api_model.dart';
import 'package:admin/data/models/api/payment_api_model.dart';
import 'package:admin/data/models/api/purchase_order_api_model.dart';
import 'package:admin/data/models/api/vendor_api_model.dart';
import 'package:admin/data/repositories/expense_repository.dart';
import 'package:admin/data/repositories/payment_repository.dart';
import 'package:admin/data/repositories/purchase_order_repository.dart';
import 'package:admin/data/repositories/vendor_repository.dart';
import 'package:admin/data/services/expenses_api.dart';
import 'package:admin/data/services/payments_api.dart';
import 'package:admin/data/services/purchase_orders_api.dart';
import 'package:admin/data/services/vendors_api.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// The filters the purchase order, vendor and expense lists gained: each one
/// has to narrow the server fetch AND the rows already cached, or the chip
/// looks like it did nothing (the server page is upserted into a cache the
/// local watch reads whole).
///
/// Each fake API hands back a fixed page — which lands in Drift — and
/// records the filters it was asked for.
final _now = DateTime.utc(2026, 10, 16, 12);

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('purchase orders', () {
    late _Pos api;
    late PurchaseOrderRepository repo;

    setUp(() async {
      api = _Pos([
        const PurchaseOrderApi(
          id: 'p1',
          number: 'P1',
          statusId: '1',
          clientId: 'c1',
          vendorId: 'v1',
          date: '2026-10-02',
          dueDate: '2026-11-01',
          updatedAt: 1,
        ),
        const PurchaseOrderApi(
          id: 'p2',
          number: 'P2',
          statusId: '2',
          clientId: 'c2',
          vendorId: 'v2',
          date: '2026-09-15',
          dueDate: '2026-10-20',
          updatedAt: 2,
        ),
        const PurchaseOrderApi(
          id: 'p3',
          number: 'P3',
          statusId: '5',
          clientId: 'c1',
          vendorId: 'v1',
          date: '2026-08-01',
          dueDate: '2026-08-31',
          updatedAt: 3,
        ),
      ]);
      repo = PurchaseOrderRepository(db: db, api: api, now: () => _now);
      await repo.ensurePageLoaded(companyId: 'co', page: 1);
      api.calls.clear();
    });

    Future<List<String>> local(Map<String, Set<String>> extra) async {
      final rows = await repo
          .watchPage(companyId: 'co', extraFilters: extra)
          .first;
      return [for (final r in rows) r.id]..sort();
    }

    test('status', () async {
      expect(
        await local(const {
          'client_status': {'draft', 'cancelled'},
        }),
        ['p1', 'p3'],
      );
    });

    test('client and vendor', () async {
      expect(
        await local(const {
          'client_id': {'c1'},
        }),
        ['p1', 'p3'],
      );
      expect(
        await local(const {
          'vendor_id': {'v2'},
        }),
        ['p2'],
      );
    });

    test('a rolling date window', () async {
      expect(
        await local(const {
          'date_range': {'date,rel:m0s,rel:m0e'},
        }),
        ['p1'],
      );
      expect(
        await local(const {
          'due_date_range': {'due_date,rel:m0s,rel:m0e'},
        }),
        ['p2'],
      );
    });

    test('a single-date comparator goes to the server as a window', () async {
      expect(
        await local(const {
          'date': {'gte:2026-09-01'},
        }),
        ['p1', 'p2'],
      );
      await repo.ensurePageLoaded(
        companyId: 'co',
        page: 1,
        extraFilters: const {
          'date': {'gte:2026-09-01'},
          'due_date': {'lt:2026-10-01'},
        },
      );
      final filters = api.calls.single;
      // `PurchaseOrderFilters` has no `date()` comparison: sent as is it was
      // skipped, and the page came back unfiltered.
      expect(filters.containsKey('date'), isFalse);
      expect(filters.containsKey('due_date'), isFalse);
      expect(filters['date_range'], 'date,2026-09-01,9999-12-31');
      expect(filters['due_date_range'], 'due_date,1000-01-01,2026-09-30');
    });
  });

  group('vendors', () {
    late _Vendors api;
    late VendorRepository repo;

    int epoch(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

    setUp(() async {
      api = _Vendors([
        VendorApi(
          id: 'v1',
          name: 'Alpha',
          number: '0001',
          createdAt: epoch(DateTime.utc(2026, 10, 16, 11, 30)),
          updatedAt: epoch(DateTime.utc(2026, 10, 16, 11, 30)),
        ),
        VendorApi(
          id: 'v2',
          name: 'Beta',
          number: '0002',
          createdAt: epoch(DateTime.utc(2026, 9, 1, 12)),
          updatedAt: epoch(DateTime.utc(2026, 9, 1, 12)),
        ),
      ]);
      repo = VendorRepository(db: db, api: api, now: () => _now);
      await repo.ensurePageLoaded(companyId: 'co', page: 1);
      api.calls.clear();
    });

    Future<List<String>> local(Map<String, Set<String>> extra) async {
      final rows = await repo
          .watchPage(companyId: 'co', extraFilters: extra)
          .first;
      return [for (final r in rows) r.id]..sort();
    }

    test('number is an exact match', () async {
      expect(
        await local(const {
          'number': {'0002'},
        }),
        ['v2'],
      );
      expect(
        await local(const {
          'number': {'000'},
        }),
        isEmpty,
      );
    });

    test('created and updated', () async {
      expect(
        await local(const {
          'created_at': {'gte:rel:h1'},
        }),
        ['v1'],
      );
      expect(
        await local(const {
          'updated_at_range': {'updated_at,2026-09-01,2026-09-30'},
        }),
        ['v2'],
      );
    });

    test(
      'a window travels as created_between, its last day included',
      () async {
        await repo.ensurePageLoaded(
          companyId: 'co',
          page: 1,
          extraFilters: const {
            'created_at_range': {'created_at,2026-09-01,2026-09-30'},
          },
        );
        expect(
          api.calls.single['created_between'],
          '2026-09-01,2026-09-30 23:59:59',
        );
      },
    );
  });

  group('expenses', () {
    late _Expenses api;
    late ExpenseRepository repo;

    setUp(() async {
      api = _Expenses([
        const ExpenseApi(
          id: 'e1',
          date: '2026-10-05',
          customValue1: 'North',
          updatedAt: 1,
        ),
        const ExpenseApi(
          id: 'e2',
          date: '2026-07-05',
          customValue1: 'South',
          updatedAt: 2,
        ),
      ]);
      repo = ExpenseRepository(db: db, api: api, now: () => _now);
      await repo.ensurePageLoaded(companyId: 'co', page: 1);
      api.calls.clear();
    });

    Future<List<String>> local({
      Map<String, Set<String>> extra = const {},
      Map<int, Set<String>> custom = const {},
    }) async {
      final rows = await repo
          .watchPage(
            companyId: 'co',
            extraFilters: extra,
            customFilters: custom,
          )
          .first;
      return [for (final r in rows) r.id]..sort();
    }

    test('a custom field', () async {
      expect(
        await local(
          custom: const {
            1: {'South'},
          },
        ),
        ['e2'],
      );
    });

    test('the date, as a comparator and as a window', () async {
      expect(
        await local(
          extra: const {
            'date': {'lt:2026-08-01'},
          },
        ),
        ['e2'],
      );
      expect(
        await local(
          extra: const {
            'date_range': {'date,rel:q0s,rel:q0e'},
          },
        ),
        ['e1'],
      );
      await repo.ensurePageLoaded(
        companyId: 'co',
        page: 1,
        extraFilters: const {
          'date': {'eq:2026-10-05'},
        },
      );
      expect(api.calls.single['date_range'], 'date,2026-10-05,2026-10-05');
    });
  });

  group('payments', () {
    late _Payments api;
    late PaymentRepository repo;

    setUp(() async {
      api = _Payments([
        const PaymentApi(id: 'm1', date: '2026-10-05', updatedAt: 1),
        const PaymentApi(id: 'm2', date: '2026-07-05', updatedAt: 2),
      ]);
      repo = PaymentRepository(db: db, api: api, now: () => _now);
      await repo.ensurePageLoaded(companyId: 'co', page: 1);
      api.calls.clear();
    });

    Future<List<String>> local(Map<String, Set<String>> extra) async {
      final rows = await repo
          .watchPage(companyId: 'co', extraFilters: extra)
          .first;
      return [for (final r in rows) r.id]..sort();
    }

    test('a single-date comparator goes to the server as a window', () async {
      // `PaymentFilters` has no `date()` comparison: sent as is it was
      // skipped, so the list stripped it and filtered locally only.
      expect(
        await local(const {
          'date': {'gte:2026-09-01'},
        }),
        ['m1'],
      );
      await repo.ensurePageLoaded(
        companyId: 'co',
        page: 1,
        extraFilters: const {
          'date': {'gte:2026-09-01'},
        },
      );
      final filters = api.calls.single;
      expect(filters.containsKey('date'), isFalse);
      expect(filters['date_range'], 'date,2026-09-01,9999-12-31');
    });

    test('a rolling window resolves on the wire', () async {
      await repo.ensurePageLoaded(
        companyId: 'co',
        page: 1,
        extraFilters: const {
          'date_range': {'date,rel:m0s,rel:m0e'},
        },
      );
      expect(api.calls.single['date_range'], 'date,2026-10-01,2026-10-31');
    });
  });
}

class _Payments implements PaymentsApi {
  _Payments(this.rows);
  final List<PaymentApi> rows;
  final List<Map<String, String>> calls = [];

  @override
  Future<({PaymentListApi data, int? cursorUpdatedAt, String? cursorId})> list({
    required int page,
    int perPage = 50,
    String? search,
    int? sinceUpdatedAt,
    String? sinceId,
    Map<String, String> filters = const {},
  }) async {
    calls.add(filters);
    return (
      data: PaymentListApi(data: page == 1 ? rows : const []),
      cursorUpdatedAt: null,
      cursorId: null,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Pos implements PurchaseOrdersApi {
  _Pos(this.rows);
  final List<PurchaseOrderApi> rows;
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
      data: PurchaseOrderListApi(data: page == 1 ? rows : const []),
      cursorUpdatedAt: null,
      cursorId: null,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Vendors implements VendorsApi {
  _Vendors(this.rows);
  final List<VendorApi> rows;
  final List<Map<String, String>> calls = [];

  @override
  Future<({VendorListApi data, int? cursorUpdatedAt, String? cursorId})> list({
    required int page,
    int perPage = 50,
    String? search,
    int? sinceUpdatedAt,
    String? sinceId,
    Map<String, String> filters = const {},
  }) async {
    calls.add(filters);
    return (
      data: VendorListApi(data: page == 1 ? rows : const []),
      cursorUpdatedAt: null,
      cursorId: null,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Expenses implements ExpensesApi {
  _Expenses(this.rows);
  final List<ExpenseApi> rows;
  final List<Map<String, String>> calls = [];

  @override
  Future<({ExpenseListApi data, int? cursorUpdatedAt, String? cursorId})> list({
    required int page,
    int perPage = 50,
    String? search,
    int? sinceUpdatedAt,
    String? sinceId,
    Map<String, String> filters = const {},
  }) async {
    calls.add(filters);
    return (
      data: ExpenseListApi(data: page == 1 ? rows : const []),
      cursorUpdatedAt: null,
      cursorId: null,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
