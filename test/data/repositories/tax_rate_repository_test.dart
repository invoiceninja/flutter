import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/tax_rate_api_model.dart';
import 'package:admin/data/models/domain/tax_rate.dart';
import 'package:admin/data/repositories/tax_rate_repository.dart';
import 'package:admin/data/services/tax_rates_api.dart';
import 'package:admin/domain/sync/mutation.dart';

import '_base_entity_repository_contract.dart';

/// First coverage for the tax-rate vertical — repository, DAO, API and both
/// models were entirely untested (`TaxRateRepository` was never named anywhere
/// under `test/`), despite feeding the default-tax pickers on
/// Settings → Tax Settings and, through them, invoice tax math.
///
/// Registers the shared contract (the repository is a standard
/// `BaseEntityRepository`) and adds the bundled-entity behaviour the contract
/// doesn't reach: tax rates arrive on `/refresh?first_load=true`, so
/// `applyBundle` must be upsert-only and never clobber a row with a pending
/// offline edit.
class _FakeTaxRatesApi implements TaxRatesApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  runEntityRepositoryContract(
    EntityRepositoryContractFixture<TaxRate, TaxRateApi>.build(
      entityType: 'tax_rate',
      buildRepo: (db) => TaxRateRepository(db: db, api: _FakeTaxRatesApi()),
      buildApiModel: ({required id, displayValue, updatedAt = 1700000000}) =>
          TaxRateApi(id: id, name: displayValue ?? id, updatedAt: updatedAt),
      fromApi: TaxRate.fromApi,
      editCopy: (item, {required displayValue}) =>
          item.copyWith(name: displayValue),
      idOf: (t) => t.id,
      isDirtyOf: (t) => t.isDirty,
      create: (repo, {required companyId, required draft}) =>
          (repo as TaxRateRepository).create(
            companyId: companyId,
            draft: draft,
          ),
      save: (repo, {required companyId, required entity}) =>
          (repo as TaxRateRepository).save(companyId: companyId, rate: entity),
      delete: (repo, {required companyId, required id}) =>
          repo.delete(companyId: companyId, id: id),
    ),
  );

  group('TaxRateRepository specifics', () {
    late AppDatabase db;
    late TaxRateRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = TaxRateRepository(db: db, api: _FakeTaxRatesApi());
    });
    tearDown(() async => db.close());

    test('delete and purge are password-gated, ordinary edits are not', () {
      // Server policy: destructive tax-rate ops sit behind
      // X-API-PASSWORD-BASE64, so ConfirmPasswordSheet must fire for them.
      expect(repo.requiresPasswordFor(MutationKind.delete), isTrue);
      expect(repo.requiresPasswordFor(MutationKind.purge), isTrue);
      expect(repo.requiresPasswordFor(MutationKind.create), isFalse);
      expect(repo.requiresPasswordFor(MutationKind.update), isFalse);
    });

    group('applyBundle (arrives on /refresh?first_load=true)', () {
      test('upserts every bundled row', () async {
        await repo.applyBundle(
          companyId: 'co',
          bundle: const [
            TaxRateApi(id: 't1', name: 'GST', rate: 10, updatedAt: 100),
            TaxRateApi(id: 't2', name: 'PST', rate: 7, updatedAt: 100),
          ],
        );

        expect(
          (await repo.watch(companyId: 'co', id: 't1').first)?.name,
          'GST',
        );
        expect((await repo.watch(companyId: 'co', id: 't2').first)?.rate, 7);
      });

      test('a later bundle updates an existing row in place', () async {
        await repo.applyBundle(
          companyId: 'co',
          bundle: const [
            TaxRateApi(id: 't1', name: 'GST', rate: 10, updatedAt: 100),
          ],
        );
        await repo.applyBundle(
          companyId: 'co',
          bundle: const [
            TaxRateApi(id: 't1', name: 'GST', rate: 15, updatedAt: 200),
          ],
        );

        expect((await repo.watch(companyId: 'co', id: 't1').first)?.rate, 15);
      });

      test(
        'is upsert-only — a row absent from the bundle is NOT deleted',
        () async {
          await repo.applyBundle(
            companyId: 'co',
            bundle: const [
              TaxRateApi(id: 't1', name: 'GST', updatedAt: 100),
              TaxRateApi(id: 't2', name: 'PST', updatedAt: 100),
            ],
          );

          await repo.applyBundle(
            companyId: 'co',
            bundle: const [TaxRateApi(id: 't1', name: 'GST', updatedAt: 200)],
          );

          expect(
            await repo.watch(companyId: 'co', id: 't2').first,
            isNotNull,
            reason:
                'applyBundle must never delete — a dropped row would take any '
                'pending outbox edit with it',
          );
        },
      );

      test('a locally created (dirty) row survives a bundle apply', () async {
        final created = await repo.create(
          companyId: 'co',
          draft: TaxRate.fromApi(const TaxRateApi(name: 'Local', rate: 5)),
        );

        await repo.applyBundle(
          companyId: 'co',
          bundle: const [
            TaxRateApi(id: 't1', name: 'GST', rate: 10, updatedAt: 100),
          ],
        );

        final local = await repo
            .watch(companyId: 'co', id: created.entity.id)
            .first;
        expect(local, isNotNull);
        expect(local!.name, 'Local');
        expect(
          local.isDirty,
          isTrue,
          reason: 'the pending offline create must stay unsynced',
        );
      });

      test('rows are scoped to their company', () async {
        await repo.applyBundle(
          companyId: 'co',
          bundle: const [TaxRateApi(id: 't1', name: 'GST', updatedAt: 100)],
        );

        expect(await repo.watch(companyId: 'other', id: 't1').first, isNull);
      });
    });
  });
}
