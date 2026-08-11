import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';

/// Targeted tests for the two narrow writes `_persistAndActivate` leans on:
/// [CompaniesDao.pruneExcept] (full-sync reconciliation) and
/// [CompaniesDao.touchSessionColumns] (the partial write a company with a
/// queued mutation gets instead of the full row). Both exist to make a
/// refresh non-destructive, so their failure mode is silent data loss —
/// hence the coverage.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
  });

  Future<void> seed(
    String id, {
    String smtpHost = '',
    String permissions = '',
    bool isOwner = false,
    int enabledModules = 0,
    int lastSyncAt = 0,
  }) async {
    await db.companiesDao.upsertAll([
      CompaniesCompanion.insert(
        id: id,
        name: id,
        settings: '{}',
        smtpHost: Value(smtpHost),
        permissions: permissions,
        accountId: 'acct',
        token: 'tok',
        isOwner: Value(isOwner),
        enabledModules: Value(enabledModules),
        lastSyncAt: Value(lastSyncAt),
        updatedAt: 1700000000,
      ),
    ]);
  }

  Future<Set<String>> ids() async =>
      (await db.companiesDao.all()).map((c) => c.id).toSet();

  group('pruneExcept', () {
    test('drops the companies the response no longer carries', () async {
      await seed('co_a');
      await seed('co_b');

      await db.companiesDao.pruneExcept(
        companyIds: {'co_a'},
        accountId: 'acct',
      );

      expect(await ids(), {'co_a'});
    });

    test('leaves a surviving row\'s columns untouched', () async {
      // The whole point of pruning instead of wiping: a re-inserted row would
      // reset every column the login/refresh envelope doesn't carry (issue
      // #29). Deleting and recreating co_a would blank smtp_host.
      await seed('co_a', smtpHost: 'smtp.example.com');

      await db.companiesDao.pruneExcept(
        companyIds: {'co_a'},
        accountId: 'acct',
      );

      expect(
        (await db.companiesDao.byId('co_a'))!.smtpHost,
        'smtp.example.com',
      );
    });

    test(
      'an empty company set keeps every row instead of deleting them all',
      () async {
        // drift's `isNotInExp` returns Constant(true) for an empty list, so an
        // unguarded `id.isNotIn({})` compiles to `DELETE ... WHERE TRUE` — it
        // would wipe the local cache. No caller can pass an empty set today
        // (a company-less response throws earlier), which is exactly why this
        // needs a test rather than a comment.
        await seed('co_a');
        await seed('co_b');

        await db.companiesDao.pruneExcept(
          companyIds: const <String>{},
          accountId: 'acct',
        );

        expect(await ids(), {'co_a', 'co_b'});
      },
    );

    test('drops a stale account row but keeps the current one', () async {
      await seed('co_a');
      await db.companiesDao.upsertAccount(
        AccountsCompanion.insert(
          id: 'acct_old',
          email: '',
          plan: 'pro',
          numTrialDays: 0,
          updatedAt: 1,
        ),
      );

      await db.companiesDao.pruneExcept(
        companyIds: {'co_a'},
        accountId: 'acct_new',
      );

      expect(await db.companiesDao.account(), isNull);
    });
  });

  group('touchSessionColumns', () {
    test('refreshes the server-owned columns and the watermark', () async {
      await seed('co_a', permissions: 'view_client', isOwner: false);

      await db.companiesDao.touchSessionColumns(
        companyId: 'co_a',
        at: 4242,
        permissions: 'view_client,edit_client',
        accountId: 'acct_2',
        isAdmin: true,
        isOwner: true,
      );

      final row = (await db.companiesDao.byId('co_a'))!;
      expect(row.permissions, 'view_client,edit_client');
      expect(row.accountId, 'acct_2');
      expect(row.isAdmin, isTrue);
      expect(row.isOwner, isTrue);
      expect(row.lastSyncAt, 4242);
    });

    test('leaves every locally-editable column alone', () async {
      // This write is what a company with a queued settings mutation gets
      // instead of the full row, so anything the user can edit must survive.
      await seed('co_a', smtpHost: 'local.edit', enabledModules: 7);

      await db.companiesDao.touchSessionColumns(
        companyId: 'co_a',
        at: 1,
        permissions: 'p',
        accountId: 'acct',
        isAdmin: false,
        isOwner: false,
      );

      final row = (await db.companiesDao.byId('co_a'))!;
      expect(row.smtpHost, 'local.edit');
      expect(row.enabledModules, 7);
      expect(row.settings, '{}');
    });
  });
}
