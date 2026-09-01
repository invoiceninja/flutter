import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/settings_repository.dart';

/// First direct coverage of `SettingsRepository.resolved()` — the app's single
/// settings-cascade walker. Twelve test files construct a `SettingsRepository`
/// for DI, but until now none called `resolved`, so the precedence rule itself
/// was unverified.
///
/// Its one production consumer is `resolveInvoiceLocked`
/// (`lib/domain/billing/invoice_lock.dart:122`), which reads `lock_invoices`
/// and `e_invoice_type` off the resolved map — so a precedence regression
/// silently applies the wrong invoice-locking policy rather than failing loudly.
///
/// TODO(group-cascade): the walker is documented as
/// `client.settings → group.settings → company.settings` but the group layer is
/// still the `// Groups go here in M2.` placeholder in `resolved()`, even though
/// group settings now exist (`group_setting_repository.dart`,
/// `GroupSettingsDraftViewModel`, `group_settings_table.dart`). A client whose
/// group overrides `lock_invoices` currently resolves to the *company* value.
/// These tests deliberately pin only the client-over-company precedence that
/// works today; when the group layer lands, add its cases here rather than
/// treating the omission as intended.
void main() {
  late AppDatabase db;
  late SettingsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = SettingsRepository(db: db);
  });
  tearDown(() async => db.close());

  Future<void> seedCompany(String settings, {String id = 'co'}) =>
      db.companiesDao.upsertAll([
        CompaniesCompanion.insert(
          id: id,
          name: 'Acme',
          settings: settings,
          permissions: '',
          accountId: 'acct',
          token: 'tok',
          updatedAt: 1700000000,
        ),
      ]);

  Future<void> seedClient(
    Map<String, dynamic> payload, {
    String id = 'cl1',
    String companyId = 'co',
  }) => db.clientDao.upsert(
    ClientsCompanion.insert(
      id: id,
      companyId: companyId,
      name: 'Client',
      number: '',
      email: '',
      displayName: 'Client',
      balance: '0',
      updatedAt: 1,
      payload: jsonEncode(payload),
    ),
  );

  group('company layer', () {
    test('returns the company settings when no client is given', () async {
      await seedCompany(jsonEncode({'lock_invoices': 'when_sent'}));

      expect(await repo.resolved(companyId: 'co'), {
        'lock_invoices': 'when_sent',
      });
    });

    test('an unknown company resolves to an empty map, not a throw', () async {
      expect(await repo.resolved(companyId: 'nope'), isEmpty);
    });

    test('an empty settings column resolves to an empty map', () async {
      await seedCompany('');

      expect(await repo.resolved(companyId: 'co'), isEmpty);
    });

    test('a non-object settings blob resolves to an empty map', () async {
      // `_decodeOrEmpty` guards with `decoded is Map` — a JSON array must not
      // blow up the cascade.
      await seedCompany('[]');

      expect(await repo.resolved(companyId: 'co'), isEmpty);
    });
  });

  group('client layer takes precedence over company', () {
    test('a client override wins for the same key', () async {
      await seedCompany(jsonEncode({'lock_invoices': 'when_sent'}));
      await seedClient({
        'settings': {'lock_invoices': 'off'},
      });

      final resolved = await repo.resolved(companyId: 'co', clientId: 'cl1');

      expect(resolved['lock_invoices'], 'off');
    });

    test('company keys the client does not override survive', () async {
      await seedCompany(
        jsonEncode({'lock_invoices': 'when_sent', 'currency_id': '1'}),
      );
      await seedClient({
        'settings': {'lock_invoices': 'off'},
      });

      final resolved = await repo.resolved(companyId: 'co', clientId: 'cl1');

      expect(resolved, {'lock_invoices': 'off', 'currency_id': '1'});
    });

    test('client-only keys are merged in', () async {
      await seedCompany(jsonEncode({'lock_invoices': 'when_sent'}));
      await seedClient({
        'settings': {'language_id': '3'},
      });

      final resolved = await repo.resolved(companyId: 'co', clientId: 'cl1');

      expect(resolved, {'lock_invoices': 'when_sent', 'language_id': '3'});
    });
  });

  group('client layer edge cases fall back to company', () {
    test('a client id that does not exist', () async {
      await seedCompany(jsonEncode({'lock_invoices': 'when_sent'}));

      expect(await repo.resolved(companyId: 'co', clientId: 'ghost'), {
        'lock_invoices': 'when_sent',
      });
    });

    test('a client payload with no settings block', () async {
      await seedCompany(jsonEncode({'lock_invoices': 'when_sent'}));
      await seedClient({'name': 'Client'});

      expect(await repo.resolved(companyId: 'co', clientId: 'cl1'), {
        'lock_invoices': 'when_sent',
      });
    });

    test('a client whose settings block is not an object', () async {
      await seedCompany(jsonEncode({'lock_invoices': 'when_sent'}));
      await seedClient({'settings': 'nonsense'});

      expect(await repo.resolved(companyId: 'co', clientId: 'cl1'), {
        'lock_invoices': 'when_sent',
      });
    });

    test(
      'a client belonging to a different company is not consulted',
      () async {
        await seedCompany(jsonEncode({'lock_invoices': 'when_sent'}));
        await seedClient({
          'settings': {'lock_invoices': 'off'},
        }, companyId: 'other');

        expect(await repo.resolved(companyId: 'co', clientId: 'cl1'), {
          'lock_invoices': 'when_sent',
        });
      },
    );
  });

  group('the first-frame seed mirror', () {
    // ─── The first-frame seed mirror ────────────────────────────────────
    //
    // `resolvedIfReady` exists so the invoice lock banner can decide on frame 1
    // whether ~44px of chrome exists, instead of resolving two Drift reads
    // after mount and pushing the whole detail header down. It is allowed to be
    // stale; `resolved()` must not be.

    test('resolvedIfReady is null before anything has resolved', () async {
      await seedCompany(jsonEncode({'lock_invoices': 'when_sent'}));

      expect(repo.resolvedIfReady(companyId: 'co'), isNull);
    });

    test('resolvedIfReady mirrors what resolved returned', () async {
      await seedCompany(jsonEncode({'lock_invoices': 'when_sent'}));
      final async = await repo.resolved(companyId: 'co');

      expect(repo.resolvedIfReady(companyId: 'co'), async);
    });

    test('a company-only warm seeds every client — the layered property that '
        'makes ONE warm cover the whole list', () async {
      // If the mirror keyed merged (company, client) tuples instead of layers,
      // the seed would be cold on the first click of each client, which is most
      // clicks — the bug would look fixed and mostly not be.
      await seedCompany(jsonEncode({'lock_invoices': 'end_of_month'}));
      await repo.resolved(companyId: 'co');

      expect(repo.resolvedIfReady(companyId: 'co', clientId: 'never-seen'), {
        'lock_invoices': 'end_of_month',
      });
    });

    test(
      'a client override composes with the same precedence as resolved',
      () async {
        await seedCompany(jsonEncode({'lock_invoices': 'when_sent'}));
        await seedClient({
          'settings': {'lock_invoices': 'off'},
        });
        await repo.resolved(companyId: 'co', clientId: 'cl1');

        expect(repo.resolvedIfReady(companyId: 'co', clientId: 'cl1'), {
          'lock_invoices': 'off',
        });
      },
    );

    test('one company never leaks into another', () async {
      await seedCompany(jsonEncode({'lock_invoices': 'when_sent'}));
      await repo.resolved(companyId: 'co');

      expect(repo.resolvedIfReady(companyId: 'other'), isNull);
    });

    test('clearResolvedCache empties both layers (the logout path)', () async {
      await seedCompany(jsonEncode({'lock_invoices': 'when_sent'}));
      await seedClient({
        'settings': {'lock_invoices': 'off'},
      });
      await repo.resolved(companyId: 'co', clientId: 'cl1');

      repo.clearResolvedCache();

      expect(repo.resolvedIfReady(companyId: 'co'), isNull);
      expect(repo.resolvedIfReady(companyId: 'co', clientId: 'cl1'), isNull);
    });

    test('the client layer evicts past seedCacheLimit', () async {
      await seedCompany(jsonEncode({'lock_invoices': 'when_sent'}));
      const limit = SettingsRepository.seedCacheLimit;
      for (var i = 0; i <= limit; i++) {
        await seedClient({
          'settings': {'lock_invoices': 'off'},
        }, id: 'cl$i');
        await repo.resolved(companyId: 'co', clientId: 'cl$i');
      }

      // Evicted entries fall back to the company layer, not to null — the
      // company layer is what makes the seed useful at all.
      expect(repo.resolvedIfReady(companyId: 'co', clientId: 'cl0'), {
        'lock_invoices': 'when_sent',
      });
      expect(repo.resolvedIfReady(companyId: 'co', clientId: 'cl$limit'), {
        'lock_invoices': 'off',
      });
    });

    test('resolved() itself is NEVER cached', () async {
      // The single most important test here. Every gate that ACTS on the lock
      // — InvoiceActions.dispatch, the edit guard, InvoiceRepository.save's
      // backstop — awaits `resolved`. Memoizing it would make those read stale
      // policy, which is a correctness bug rather than a rendering one.
      await seedCompany(jsonEncode({'lock_invoices': 'when_sent'}));
      expect(await repo.resolved(companyId: 'co'), {
        'lock_invoices': 'when_sent',
      });

      await seedCompany(jsonEncode({'lock_invoices': 'off'}));

      expect(await repo.resolved(companyId: 'co'), {'lock_invoices': 'off'});
    });

    test(
      'a caller mutating a resolved map cannot corrupt the mirror',
      () async {
        await seedCompany(jsonEncode({'lock_invoices': 'when_sent'}));
        final result = await repo.resolved(companyId: 'co');
        result['lock_invoices'] = 'tampered';

        expect(repo.resolvedIfReady(companyId: 'co'), {
          'lock_invoices': 'when_sent',
        });
      },
    );
  });
}
