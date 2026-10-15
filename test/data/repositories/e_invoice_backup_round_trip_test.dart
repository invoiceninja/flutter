import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/credit_api_model.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/repositories/credit_repository.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/data/services/credits_api.dart';
import 'package:admin/data/services/invoices_api.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// `backup` is read-only — `toApiJson` leaves it off the wire — but the
/// list's PEPPOL mark reads `backup.guid` from the stored row, so a local
/// edit-save must keep it, or a delivered document reads back as undelivered
/// until the server's echo lands (never, offline).
class _FakeInvoicesApi implements InvoicesApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeCreditsApi implements CreditsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  const backup = {'guid': 'peppol-ref-1'};

  test('an invoice keeps backup.guid across a local edit', () async {
    final repo = InvoiceRepository(
      db: db,
      api: _FakeInvoicesApi(),
      settings: SettingsRepository(db: db),
    );
    await repo.applyUpdateResponse(
      companyId: 'co',
      serverResponse: const InvoiceApi(
        id: 'inv1',
        statusId: '2',
        updatedAt: 1700000000,
        backup: backup,
      ),
    );
    final stored = await repo.watch(companyId: 'co', id: 'inv1').first;
    expect(stored!.backup?['guid'], 'peppol-ref-1');

    await repo.save(
      companyId: 'co',
      invoice: stored.copyWith(number: 'INV-RENAMED'),
    );
    final edited = await repo.watch(companyId: 'co', id: 'inv1').first;
    expect(edited!.number, 'INV-RENAMED');
    expect(edited.backup?['guid'], 'peppol-ref-1');
  });

  test('a credit reads backup.guid and keeps it across a local edit', () async {
    final repo = CreditRepository(db: db, api: _FakeCreditsApi());
    await repo.applyUpdateResponse(
      companyId: 'co',
      serverResponse: const CreditApi(
        id: 'cr1',
        statusId: '2',
        updatedAt: 1700000000,
        backup: backup,
      ),
    );
    final stored = await repo.watch(companyId: 'co', id: 'cr1').first;
    expect(stored!.backup?['guid'], 'peppol-ref-1');

    await repo.save(
      companyId: 'co',
      credit: stored.copyWith(number: 'CR-RENAMED'),
    );
    final edited = await repo.watch(companyId: 'co', id: 'cr1').first;
    expect(edited!.number, 'CR-RENAMED');
    expect(edited.backup?['guid'], 'peppol-ref-1');
  });
}
