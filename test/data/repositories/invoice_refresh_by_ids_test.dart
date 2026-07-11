import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/domain/invoice_status.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/data/services/invoices_api.dart';

/// Fake that returns a canned invoice per id (or throws), and records which
/// ids were fetched. Everything else is unimplemented.
class _FakeInvoicesApi implements InvoicesApi {
  _FakeInvoicesApi({this.responses = const {}, this.errors = const {}});

  final Map<String, InvoiceApi> responses;
  final Map<String, Object> errors;
  final List<String> fetched = [];

  @override
  Future<InvoiceItemApi> getWithSchedule(String id) async {
    fetched.add(id);
    final err = errors[id];
    if (err != null) throw err;
    final inv = responses[id];
    if (inv == null) throw StateError('unexpected getWithSchedule for $id');
    return InvoiceItemApi(data: inv);
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  InvoiceRepository repo(_FakeInvoicesApi api) => InvoiceRepository(
    db: db,
    api: api,
    settings: SettingsRepository(db: db),
  );

  // `_fromRow` rebuilds the domain from the `payload` JSON column, so the seed
  // writes a full InvoiceApi payload (not just the filter columns).
  Future<void> seedInvoice(
    String id, {
    String statusId = '2', // sent
    String balance = '100',
    String paidToDate = '0',
    String clientId = 'cli_1',
    bool dirty = false,
  }) {
    final api = InvoiceApi(
      id: id,
      statusId: statusId,
      balance: balance,
      paidToDate: paidToDate,
      clientId: clientId,
      updatedAt: 1700000000,
    );
    return db.invoiceDao.upsert(
      InvoicesCompanion.insert(
        id: id,
        companyId: 'co',
        updatedAt: 1700000000,
        statusId: Value(statusId),
        balance: Value(balance),
        paidToDate: Value(paidToDate),
        clientId: Value(clientId),
        isDirty: Value(dirty),
        payload: jsonEncode(api.toJson()),
      ),
    );
  }

  // A now-paid server response for [id].
  InvoiceApi paidResponse(String id, {String clientId = 'cli_1'}) => InvoiceApi(
    id: id,
    statusId: '4', // paid
    balance: '0',
    paidToDate: '100',
    clientId: clientId,
    updatedAt: 1700000100,
  );

  test(
    'force-refetches an already-cached invoice and returns its clientId',
    () async {
      await seedInvoice('inv1'); // sent, balance 100
      final api = _FakeInvoicesApi(responses: {'inv1': paidResponse('inv1')});
      final r = repo(api);

      final clientIds = await r.refreshByIds(
        companyId: 'co',
        ids: const ['inv1'],
      );

      // Unlike ensureLoaded, it does NOT short-circuit on the cached row.
      expect(api.fetched, ['inv1']);
      expect(clientIds, {'cli_1'});

      final inv = await r.watch(companyId: 'co', id: 'inv1').first;
      expect(inv!.statusId, InvoiceStatus.paid);
      expect(inv.balance, Decimal.zero);
      expect(inv.paidToDate, Decimal.parse('100'));
    },
  );

  test('skips tmp_ and empty ids without any network fetch', () async {
    final api = _FakeInvoicesApi();
    final clientIds = await repo(
      api,
    ).refreshByIds(companyId: 'co', ids: const ['tmp_pending', '']);
    expect(clientIds, isEmpty);
    expect(api.fetched, isEmpty);
  });

  test('swallows per-id errors and still applies the rest', () async {
    await seedInvoice('ok', clientId: 'cli_ok');
    final api = _FakeInvoicesApi(
      responses: {'ok': paidResponse('ok', clientId: 'cli_ok')},
      errors: {
        'net': Exception('network down'),
        'gone': StateError('404 not found'),
      },
    );
    final r = repo(api);

    final clientIds = await r.refreshByIds(
      companyId: 'co',
      ids: const ['ok', 'net', 'gone'],
    );

    // Errors are swallowed; the good id is still applied + returned.
    expect(clientIds, {'cli_ok'});
    final inv = await r.watch(companyId: 'co', id: 'ok').first;
    expect(inv!.statusId, InvoiceStatus.paid);
  });

  test('does not clobber a locally-edited (is_dirty) invoice', () async {
    await seedInvoice('inv1', dirty: true); // sent, balance 100, dirty
    final api = _FakeInvoicesApi(responses: {'inv1': paidResponse('inv1')});
    final r = repo(api);

    final clientIds = await r.refreshByIds(
      companyId: 'co',
      ids: const ['inv1'],
    );

    // The fetch happens and the client is still returned, but the dirty row
    // is preserved (the upsert drops it).
    expect(api.fetched, ['inv1']);
    expect(clientIds, {'cli_1'});
    final inv = await r.watch(companyId: 'co', id: 'inv1').first;
    expect(inv!.isDirty, isTrue);
    expect(inv.balance, Decimal.parse('100')); // local value, not clobbered
    expect(inv.statusId, InvoiceStatus.sent);
  });
}
