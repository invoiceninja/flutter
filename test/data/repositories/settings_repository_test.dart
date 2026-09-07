import 'dart:convert';

import 'package:drift/drift.dart' show Value;
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

  group('group layer (company -> group -> client)', () {
    Future<void> seedGroup(
      Map<String, dynamic> settings, {
      String id = 'grp1',
      String companyId = 'co',
    }) => db.groupSettingDao.upsertAll([
      GroupSettingsCompanion.insert(
        id: id,
        companyId: companyId,
        name: 'Retail',
        updatedAt: 1,
        payload: jsonEncode({'id': id, 'name': 'Retail', 'settings': settings}),
      ),
    ]);

    test('a group override beats the company', () async {
      // This resolver backs the gates that ACT on settings —
      // `resolveInvoiceLockReason` / `peekInvoiceLockReason`, the
      // add-to-invoice dialog, tap-to-call's timezone. It walked
      // `{...company, ...client}` long after Groups shipped, so a group-level
      // `lock_invoices` never locked in the app: no banner, and Edit/Delete
      // still enabled on a sent invoice the server considers locked.
      await seedCompany(jsonEncode({'lock_invoices': 'off'}));
      await seedGroup({'lock_invoices': 'when_sent'});
      await db.clientDao.upsert(
        ClientsCompanion.insert(
          id: 'cl1',
          companyId: 'co',
          name: 'Client',
          number: '',
          email: '',
          displayName: 'Client',
          balance: '0',
          updatedAt: 1,
          payload: jsonEncode({'id': 'cl1', 'settings': <String, dynamic>{}}),
          groupSettingsId: const Value('grp1'),
        ),
      );

      expect(await repo.resolved(companyId: 'co', clientId: 'cl1'), {
        'lock_invoices': 'when_sent',
      });
    });

    test('a client override still beats the group', () async {
      await seedCompany(jsonEncode({'lock_invoices': 'off'}));
      await seedGroup({'lock_invoices': 'when_sent'});
      await db.clientDao.upsert(
        ClientsCompanion.insert(
          id: 'cl1',
          companyId: 'co',
          name: 'Client',
          number: '',
          email: '',
          displayName: 'Client',
          balance: '0',
          updatedAt: 1,
          payload: jsonEncode({
            'id': 'cl1',
            'settings': {'lock_invoices': 'end_of_month'},
          }),
          groupSettingsId: const Value('grp1'),
        ),
      );

      expect(await repo.resolved(companyId: 'co', clientId: 'cl1'), {
        'lock_invoices': 'end_of_month',
      });
    });

    test(
      'the seed mirror carries the group tier once the client is known',
      () async {
        await seedCompany(jsonEncode({'lock_invoices': 'off'}));
        await seedGroup({'lock_invoices': 'when_sent'});
        await db.clientDao.upsert(
          ClientsCompanion.insert(
            id: 'cl1',
            companyId: 'co',
            name: 'Client',
            number: '',
            email: '',
            displayName: 'Client',
            balance: '0',
            updatedAt: 1,
            payload: jsonEncode({'id': 'cl1', 'settings': <String, dynamic>{}}),
            groupSettingsId: const Value('grp1'),
          ),
        );
        await repo.resolved(companyId: 'co', clientId: 'cl1');

        expect(repo.resolvedIfReady(companyId: 'co', clientId: 'cl1'), {
          'lock_invoices': 'when_sent',
        });
      },
    );
  });

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

  group('seed-mirror eviction', () {
    Future<void> seedGroup(
      Map<String, dynamic> settings, {
      String id = 'grp1',
      String companyId = 'co',
    }) => db.groupSettingDao.upsertAll([
      GroupSettingsCompanion.insert(
        id: id,
        companyId: companyId,
        name: 'Retail',
        updatedAt: 1,
        payload: jsonEncode({'id': id, 'name': 'Retail', 'settings': settings}),
      ),
    ]);

    /// `group_settings_id` is a real Drift column, not a payload key — the
    /// walker reads `client.groupSettingsId`, so a payload-only seed silently
    /// produces an UNGROUPED client and every group assertion goes vacuous.
    Future<void> seedGroupedClient(
      Map<String, dynamic> settings, {
      String id = 'cl1',
      String? groupId = 'grp1',
    }) => db.clientDao.upsert(
      ClientsCompanion.insert(
        id: id,
        companyId: 'co',
        name: 'Client',
        number: '',
        email: '',
        displayName: 'Client',
        balance: '0',
        updatedAt: 1,
        payload: jsonEncode({'id': id, 'settings': settings}),
        groupSettingsId: Value(groupId),
      ),
    );

    test(
      'evicting a client layer must not leave its group id behind — the seed '
      'would then silently DROP the client tier',
      () async {
        // Three DISTINCT values, so the assertion can tell all three outcomes
        // apart: the correct cold-cache fall-through (company `off`), the bug
        // (group branch minus the client tier → `when_sent`), and a stale hit
        // (`end_of_month`).
        await seedCompany(jsonEncode({'lock_invoices': 'off'}));
        await seedGroup({'lock_invoices': 'when_sent'});
        await seedGroupedClient({'lock_invoices': 'end_of_month'});

        await repo.resolved(companyId: 'co', clientId: 'cl1');
        expect(
          repo.resolvedIfReady(companyId: 'co', clientId: 'cl1'),
          {'lock_invoices': 'end_of_month'},
          reason: 'precondition: all three tiers are warm',
        );

        // Push `cl1`'s client layer out of the bounded mirror. `_clientGroup`
        // used to be a plain map write with no eviction at all, so it kept
        // naming `grp1` after the layer beside it was gone: `resolvedIfReady`
        // then took the group branch, merged `{company + group}` and reported
        // itself READY — seeding the invoice-lock banner as LOCKED on a client
        // that had explicitly unlocked itself.
        for (var i = 0; i < SettingsRepository.seedCacheLimit; i++) {
          await seedGroupedClient({}, id: 'filler$i', groupId: null);
          await repo.resolved(companyId: 'co', clientId: 'filler$i');
        }

        expect(
          repo.resolvedIfReady(companyId: 'co', clientId: 'cl1'),
          {'lock_invoices': 'off'},
          reason:
              'an evicted client is a COLD cache, so it must fall through to '
              'the company layer exactly as an unseen client does — never to '
              'a group-branch answer with the client tier missing',
        );
      },
    );

    test(
      'a still-cached client keeps its group tier under eviction pressure',
      () async {
        await seedCompany(jsonEncode({'lock_invoices': 'off'}));
        await seedGroup({'lock_invoices': 'when_sent'});
        await seedGroupedClient(<String, dynamic>{});

        // Fill to one under the limit, then re-resolve cl1 so it is the most
        // recently used entry and survives.
        for (var i = 0; i < SettingsRepository.seedCacheLimit - 1; i++) {
          await seedGroupedClient({}, id: 'filler$i', groupId: null);
          await repo.resolved(companyId: 'co', clientId: 'filler$i');
        }
        await repo.resolved(companyId: 'co', clientId: 'cl1');

        expect(repo.resolvedIfReady(companyId: 'co', clientId: 'cl1'), {
          'lock_invoices': 'when_sent',
        });
      },
    );
  });
}
