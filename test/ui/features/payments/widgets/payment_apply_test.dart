import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/data/services/invoices_api.dart';
import 'package:admin/ui/features/payments/widgets/payment_apply.dart';

/// A small invoices server: answers `list` the way the real one does for the
/// two filters the pick sends (`client_status=unpaid`, `sort=date|asc`; newest
/// first otherwise), one page at a time, and `getWithSchedule` with what it
/// holds now. Records both, so a refresh that never reached it can't pass for
/// one that did — `refreshByIds` swallows errors, `noSuchMethod` included.
class _FakeInvoicesApi implements InvoicesApi {
  _FakeInvoicesApi(Iterable<InvoiceApi> invoices)
    : server = {for (final i in invoices) i.id: i};

  /// What the server holds now, by id.
  final Map<String, InvoiceApi> server;

  final List<Map<String, String>> listFilters = [];
  final List<String> fetched = [];

  /// Runs once a `list` answer has been built — a change made here reaches
  /// `getWithSchedule` but not the page the pick already has.
  void Function()? afterList;

  @override
  Future<({InvoiceListApi data, int? cursorUpdatedAt, String? cursorId})> list({
    required int page,
    int perPage = 50,
    String? search,
    int? sinceUpdatedAt,
    String? sinceId,
    Map<String, String> filters = const {},
  }) async {
    listFilters.add(filters);
    final clientId = filters['client_id'];
    var rows = server.values
        .where((i) => clientId == null || i.clientId == clientId)
        .toList();
    if (filters['client_status'] == 'unpaid') {
      // Sent / Partial.
      rows = rows.where((i) => i.statusId == '2' || i.statusId == '3').toList();
    }
    final ascending = filters['sort'] == 'date|asc';
    rows.sort(
      (a, b) => ascending ? a.date.compareTo(b.date) : b.date.compareTo(a.date),
    );
    final data = InvoiceListApi(
      data: rows.skip((page - 1) * perPage).take(perPage).toList(),
    );
    afterList?.call();
    return (data: data, cursorUpdatedAt: null, cursorId: null);
  }

  @override
  Future<InvoiceItemApi> getWithSchedule(String id) async {
    fetched.add(id);
    final invoice = server[id];
    if (invoice == null) throw StateError('no invoice $id');
    return InvoiceItemApi(data: invoice);
  }

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected API call: ${invocation.memberName}');
}

InvoiceApi _invoice(
  String id,
  String date, {
  String statusId = '2', // sent
  String balance = '100',
  int archivedAt = 0,
}) => InvoiceApi(
  id: id,
  number: id,
  date: date,
  statusId: statusId,
  balance: balance,
  amount: '100',
  clientId: 'c1',
  archivedAt: archivedAt,
  updatedAt: 1700000000,
);

/// Paid since it was cached.
InvoiceApi _paid(InvoiceApi i) =>
    i.copyWith(statusId: '4', balance: '0', paidToDate: '100');

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  InvoiceRepository repoFor(_FakeInvoicesApi api) => InvoiceRepository(
    db: db,
    api: api,
    settings: SettingsRepository(db: db),
  );

  Future<String?> pick(InvoiceRepository repo) async =>
      (await oldestUnpaidInvoice(repo, companyId: 'co', clientId: 'c1'))?.id;

  test('asks the server for the unpaid invoices, oldest first', () async {
    final api = _FakeInvoicesApi([_invoice('inv', '2024-01-01')]);
    await pick(repoFor(api));
    expect(api.listFilters.single, containsPair('client_id', 'c1'));
    expect(api.listFilters.single, containsPair('client_status', 'unpaid'));
    expect(api.listFilters.single, containsPair('sort', 'date|asc'));
  });

  test('a 2020 invoice beats newer ones, past a page of paid ones', () async {
    // The client's newest page, of any status, used to be all that was
    // fetched: fifty paid invoices left the 2020 one uncached, and the
    // "oldest unpaid" was the 2024 one.
    final api = _FakeInvoicesApi([
      _invoice('inv2024', '2024-06-01'),
      for (var i = 0; i < 50; i++)
        _paid(
          _invoice(
            'paid$i',
            '2023-01-${(i % 28 + 1).toString().padLeft(2, '0')}',
          ),
        ),
      _invoice('inv2020', '2020-03-01'),
      _invoice('inv2022', '2022-03-01', statusId: '3', balance: '40'),
    ]);
    expect(await pick(repoFor(api)), 'inv2020');
  });

  test('a draft or an archived invoice is never chosen', () async {
    final api = _FakeInvoicesApi([
      _invoice('archived', '2018-01-01', archivedAt: 1600000000),
      _invoice('draft', '2019-01-01', statusId: '1'),
      _invoice('sent', '2022-01-01'),
    ]);
    final repo = repoFor(api);
    // Everything cached, as the invoices list would leave it.
    await repo.ensurePageLoaded(companyId: 'co', page: 1);
    expect(await pick(repo), 'sent');
  });

  test(
    'a cached invoice the server now has as paid yields to the next',
    () async {
      final api = _FakeInvoicesApi([
        _invoice('stale', '2019-01-01'),
        _invoice('next', '2021-01-01'),
      ]);
      final repo = repoFor(api);
      await repo.ensurePageLoaded(companyId: 'co', page: 1);
      // Since cached: `stale` was paid. `next` is part-paid only after the
      // pick's own page came back, so 40 can only come from the re-read.
      api.server['stale'] = _paid(api.server['stale']!);
      api.afterList = () => api.server['next'] = api.server['next']!.copyWith(
        statusId: '3',
        balance: '40',
        updatedAt: 1700000100,
      );

      final target = await oldestUnpaidInvoice(
        repo,
        companyId: 'co',
        clientId: 'c1',
      );
      expect(api.fetched, ['stale', 'next']);
      expect(target?.id, 'next');
      // The amount is worked out from the re-read row, not the cached 100.
      expect(target?.balance, Decimal.fromInt(40));
    },
  );

  test('three stale winners with more left → "try again", and a retry gets '
      'past them', () async {
    final api = _FakeInvoicesApi([
      for (var i = 1; i <= 3; i++) _invoice('stale$i', '201$i-01-01'),
      _invoice('good', '2020-01-01'),
    ]);
    final repo = repoFor(api);
    await repo.ensurePageLoaded(companyId: 'co', page: 1);
    for (var i = 1; i <= 3; i++) {
      api.server['stale$i'] = _paid(api.server['stale$i']!);
    }

    // Not "none" — `good` was never checked.
    await expectLater(pick(repo), throwsA(isA<StaleApplyTargetsException>()));
    expect(api.fetched, ['stale1', 'stale2', 'stale3']);

    // Each re-fetch corrected the cache, so the next tap starts past them.
    expect(await pick(repo), 'good');
  });

  test('every candidate stale and none left → none', () async {
    final api = _FakeInvoicesApi([
      for (var i = 1; i <= 3; i++) _invoice('stale$i', '201$i-01-01'),
    ]);
    final repo = repoFor(api);
    await repo.ensurePageLoaded(companyId: 'co', page: 1);
    for (var i = 1; i <= 3; i++) {
      api.server['stale$i'] = _paid(api.server['stale$i']!);
    }

    expect(await pick(repo), isNull);
    expect(api.fetched, ['stale1', 'stale2', 'stale3']);
  });
}
