// Startup — what a cold start awaits before `runApp` once the database is
// open: building the `Services` graph, restoring the session and the device
// preferences, warming the statics from their stored row, and reading the
// saved route. Mirrors `main()`'s order (lib/main.dart); the database open
// itself is left out, because a test's in-memory store is nothing like the
// encrypted file a device opens.
//
// docs/performance-tracking.md. Run through `dart tools/perf/main.dart run`.

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/services/connectivity_watcher.dart';
import 'package:admin/data/services/token_storage.dart';

import '../workloads.dart';
import '_perf.dart';

/// Every request fails at once: the session restore kicks off a `/refresh`
/// and a prefetch it does not await, and neither may reach a network.
http.Client _offline() =>
    MockClient((_) async => throw http.ClientException('offline (benchmark)'));

const _companies = ['co1', 'co2', 'co3'];

void main() {
  perfCalibration();

  late AppDatabase db;
  late InMemoryTokenStorage storage;
  Services? booted;

  Services build() => Services.build(
    db: db,
    tokenStorage: storage,
    connectivityWatcher: ConnectivityWatcher.fixed(online: false),
    httpClient: _offline(),
  );

  benchmark(
    'startup.restore_session',
    title:
        'Cold start — build the services, restore the session and '
        'preferences, warm the statics, read the saved route',
    setUp: () async {
      db = AppDatabase(NativeDatabase.memory());
      storage = await _seed(db);
      // The statics row a previous launch stored, written the way a refresh
      // writes it; and a few hundred invoices, so the store is not empty.
      final seeding = build();
      await seeding.statics.applyStatic(staticsJson());
      for (var i = 0; i < 300; i++) {
        await seeding.invoices.applyUpdateResponse(
          companyId: _companies.first,
          serverResponse: InvoiceApi.fromJson(invoiceJson(i)),
        );
      }
      await _dispose(seeding);
      final check = build();
      await check.auth.restore();
      expect(check.auth.isAuthenticated, isTrue, reason: 'nothing restored');
      await check.statics.ensureLoaded();
      expect(check.statics.currencies, hasLength(160));
      await _dispose(check);
    },
    run: () async {
      final services = booted = build();
      await Future.wait([
        services.auth.restore(),
        services.devicePrefs.load(),
        services.recentlyViewed.restore(),
      ]);
      await services.statics.ensureLoaded();
      return db.navStateDao.current();
    },
    reset: () async {
      final services = booted;
      booted = null;
      // A restore that restored nothing would time the signed-out path.
      expect(services?.auth.isAuthenticated, isTrue, reason: 'not restored');
      if (services != null) await _dispose(services);
    },
    tearDown: () => db.close(),
    samples: 15,
  );
}

/// Lets the work `restore()` starts without awaiting — the `/refresh`, the
/// prefetch, both failing at once offline — finish, then stops what it left
/// running.
Future<void> _dispose(Services services) async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
  services.refreshScheduler.dispose();
  await services.auth.dispose();
}

/// An account, three companies, and the stored tokens a signed-in device
/// has — the shape `test/ui/features/shell/_shell_test_helpers.dart` seeds.
Future<InMemoryTokenStorage> _seed(AppDatabase db) async {
  await db.companiesDao.upsertAccount(
    AccountsCompanion.insert(
      id: 'acct1',
      email: 'pat@example.com',
      plan: 'pro',
      numTrialDays: 0,
      featuresJson: Value(jsonEncode({'hosted_company_count': 10})),
      updatedAt: 0,
    ),
  );
  await db.companiesDao.upsertAll([
    for (final id in _companies)
      CompaniesCompanion.insert(
        id: id,
        name: 'Company $id',
        displayName: Value('Company $id'),
        settings: jsonEncode({'currency_id': '1', 'name': 'Company $id'}),
        permissions: '',
        accountId: 'acct1',
        token: 'tok_$id',
        isOwner: const Value(true),
        isAdmin: const Value(true),
        enabledModules: const Value(32767),
        updatedAt: 0,
      ),
  ]);
  final storage = InMemoryTokenStorage();
  await storage.write(
    'invoiceninja.tokens.v1',
    jsonEncode({for (final id in _companies) id: 'tok_$id'}),
  );
  await storage.write('invoiceninja.base_url.v1', 'https://example.com');
  await storage.write('invoiceninja.is_hosted.v1', 'true');
  await storage.write('invoiceninja.current_company.v1', _companies.first);
  return storage;
}
