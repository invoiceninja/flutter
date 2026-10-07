import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/invoices_api.dart';

/// The fetch and the local read behind the client screen's past-due line.
class _Api implements InvoicesApi {
  _Api(this.rows, {this.fail = false});

  final List<InvoiceApi> rows;
  final bool fail;
  final List<Map<String, String>> filters = [];
  final List<int?> cursors = [];

  @override
  Future<({InvoiceListApi data, int? cursorUpdatedAt, String? cursorId})> list({
    required int page,
    int perPage = 50,
    String? search,
    int? sinceUpdatedAt,
    String? sinceId,
    Map<String, String> filters = const {},
  }) async {
    this.filters.add(filters);
    cursors.add(sinceUpdatedAt);
    if (fail) throw const NetworkException('offline');
    return (
      data: InvoiceListApi(data: rows),
      cursorUpdatedAt: rows.isEmpty ? null : rows.last.updatedAt,
      cursorId: rows.isEmpty ? null : rows.last.id,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected API call: ${invocation.memberName}');
}

InvoiceApi _inv(
  String id, {
  String status = '2',
  String client = 'c1',
  int archivedAt = 0,
  bool isDeleted = false,
}) => InvoiceApi(
  id: id,
  clientId: client,
  statusId: status,
  amount: '100',
  balance: '100',
  archivedAt: archivedAt,
  isDeleted: isDeleted,
  updatedAt: 1700000000,
);

InvoiceRepository _repo(AppDatabase db, InvoicesApi api) => InvoiceRepository(
  db: db,
  api: api,
  settings: SettingsRepository(db: db),
);

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<UnpaidInvoicesFetch> load(
    InvoiceRepository repo, [
    String client = 'c1',
  ]) => repo.ensureUnpaidForClientLoaded(companyId: 'co', clientId: client);

  test('asks for this client\'s Sent and Partial invoices, archived '
      'included', () async {
    final api = _Api([_inv('a')]);
    final repo = _repo(db, api);
    expect(await load(repo), UnpaidInvoicesFetch.complete);
    final sent = api.filters.single;
    expect(sent['client_id'], 'c1');
    expect(sent['client_status'], 'unpaid');
    // `status` is the lifecycle param; deleted is deliberately not in it.
    expect(sent['status'], 'active,archived');
  });

  test('is a narrowed fetch: reads no cursor and moves none', () async {
    final api = _Api([_inv('a')]);
    final repo = _repo(db, api);
    await load(repo);
    expect(api.cursors.single, isNull);
    // The list's own first page afterwards still starts from nothing — a
    // watermark left by one client's unpaid slice would hide every older
    // invoice from it.
    await repo.ensurePageLoaded(companyId: 'co', page: 1);
    expect(api.cursors.last, isNull);
  });

  test('a full page is not a complete answer', () async {
    final api = _Api([for (var i = 0; i < 50; i++) _inv('i$i')]);
    final repo = _repo(db, api);
    expect(await load(repo), UnpaidInvoicesFetch.incomplete);
  });

  test(
    'a failed request says so — it is worth asking again — and does not throw',
    () async {
      final repo = _repo(db, _Api(const [], fail: true));
      expect(await load(repo), UnpaidInvoicesFetch.failed);
    },
  );

  test('an empty answer is complete', () async {
    final repo = _repo(db, _Api(const []));
    expect(await load(repo), UnpaidInvoicesFetch.complete);
  });

  test('an unsynced client is never asked about', () async {
    final api = _Api(const []);
    final repo = _repo(db, api);
    expect(await load(repo, 'tmp_1'), UnpaidInvoicesFetch.incomplete);
    expect(await load(repo, ''), UnpaidInvoicesFetch.incomplete);
    expect(api.filters, isEmpty);
  });

  test(
    'the local read is Sent and Partial, archived in, deleted out',
    () async {
      final api = _Api([
        _inv('sent'),
        _inv('partial', status: '3'),
        _inv('archived', archivedAt: 1700000000),
        _inv('draft', status: '1'),
        // "Has been sent" is not "is unpaid".
        _inv('paid', status: '4'),
        _inv('deleted', isDeleted: true),
        _inv('other', client: 'c2'),
      ]);
      final repo = _repo(db, api);
      await repo.ensurePageLoaded(
        companyId: 'co',
        page: 1,
        states: const {},
        ignoreCursor: true,
      );
      final rows = await repo
          .watchUnpaidForClient(companyId: 'co', clientId: 'c1')
          .first;
      expect(rows.map((i) => i.id).toSet(), {'sent', 'partial', 'archived'});
    },
  );

  group('a list scoped to a parent the server has not seen', () {
    test('asks the server nothing, and reports no more pages', () async {
      final api = _Api([_inv('a')]);
      final repo = _repo(db, api);
      final hasMore = await repo.ensurePageLoaded(
        companyId: 'co',
        page: 1,
        extraFilters: const {
          'client_id': {'tmp_1'},
        },
      );
      expect(hasMore, isFalse);
      expect(api.filters, isEmpty);
    });

    test('a real parent is fetched as before', () async {
      final api = _Api([_inv('a')]);
      final repo = _repo(db, api);
      await repo.ensurePageLoaded(
        companyId: 'co',
        page: 1,
        extraFilters: const {
          'client_id': {'c1'},
        },
      );
      expect(api.filters.single['client_id'], 'c1');
    });

    test('so is a set that still names a real one', () async {
      final api = _Api([_inv('a')]);
      final repo = _repo(db, api);
      await repo.ensurePageLoaded(
        companyId: 'co',
        page: 1,
        extraFilters: const {
          'client_ids': {'tmp_1', 'c1'},
        },
      );
      expect(api.filters, hasLength(1));
    });
  });
}
