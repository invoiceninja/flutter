import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/services/clients_api.dart';
import 'package:admin/ui/features/settings/view_models/client_settings_draft_view_model.dart';

class _FakeClientsApi implements ClientsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Guards the client-scope fix for Settings → Tax Settings: at client scope
/// `draft` is null (the cascade body would early-return blank), so the body
/// reads company-level fields (tax-rate slot counts, decimal separator) via
/// `companyContext`. This pins that the client-scoped host actually surfaces
/// the loaded company's values there.
void main() {
  late AppDatabase db;
  late ClientRepository clientRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clientRepo = ClientRepository(db: db, api: _FakeClientsApi());
  });
  tearDown(() async {
    await db.close();
  });

  test(
    'companyContext surfaces the company tax counts at client scope',
    () async {
      await db.companiesDao.upsertAll([
        CompaniesCompanion.insert(
          id: 'co-A',
          name: 'Acme',
          settings: '{}',
          permissions: '',
          accountId: 'acct',
          token: 'tok',
          updatedAt: 1700000000,
          enabledTaxRates: const Value(2),
          enabledItemTaxRates: const Value(1),
          useCommaAsDecimalPlace: const Value(true),
        ),
      ]);

      final vm = ClientSettingsDraftViewModel(
        repo: clientRepo,
        db: db,
        companyId: 'co-A',
        clientId: 'client-1',
      );

      // draft is null at client scope — the early-return bug this fix removes.
      expect(vm.draft, isNull);

      await vm.load();

      // companyContext carries exactly the company-level fields the Tax Settings
      // body needs to render the default-rate pickers + decimal-aware display.
      expect(vm.companyContext, isNotNull);
      expect(vm.companyContext!.id, 'co-A');
      expect(vm.companyContext!.enabledTaxRates, 2);
      expect(vm.companyContext!.enabledItemTaxRates, 1);
      expect(vm.companyContext!.useCommaAsDecimalPlace, isTrue);

      vm.dispose();
    },
  );

  test('a client-scope currency override survives toApiJson', () async {
    // `Client.toApiJson()` folds the top-level currencyId / languageId /
    // paymentTerms MIRRORS back over the settings blob (empty removes the key,
    // non-empty overwrites it). Saving only the blob therefore had the edit
    // undone by the client's own serializer: with an empty mirror the override
    // never reached the server, and with a stale one it snapped back — so
    // un-ticking the override could never clear it either.
    await db.companiesDao.upsertAll([
      CompaniesCompanion.insert(
        id: 'co-A',
        name: 'Acme',
        settings: '{}',
        permissions: '',
        accountId: 'acct',
        token: 'tok',
        updatedAt: 1700000000,
      ),
    ]);
    await db.clientDao.upsertAll([
      ClientsCompanion.insert(
        id: 'client-1',
        companyId: 'co-A',
        updatedAt: 1700000000,
        payload: '{"id":"client-1","name":"Acme Ltd","settings":{}}',
        name: 'Acme Ltd',
        number: '',
        email: '',
        displayName: 'Acme Ltd',
        balance: '0',
      ),
    ]);

    final vm = ClientSettingsDraftViewModel(
      repo: clientRepo,
      db: db,
      companyId: 'co-A',
      clientId: 'client-1',
    );
    await vm.load();
    // `load()` only arms the watch; the client arrives on a later emission.
    // (`draft` stays null at client scope by design — that is the *company*
    // settings draft — so wait on `isLoaded` instead.)
    for (var i = 0; i < 100 && !vm.isLoaded; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(vm.isLoaded, isTrue, reason: 'the client row must have loaded');

    vm.updateSettings((s) => s.copyWith(currencyId: '3'));
    final saved = await vm.save();

    expect(saved, isNotNull);
    expect(
      saved!.toApiJson()['settings'],
      containsPair('currency_id', '3'),
      reason: 'the mirror must agree with the blob, or the fold reverts it',
    );
  });
}
