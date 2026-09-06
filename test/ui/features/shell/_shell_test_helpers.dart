// Helpers shared by the sidebar / company-picker widget tests. Seeds a
// real in-memory `AppDatabase` and `Services` so we exercise the full
// `ValueListenable<AuthSession?>` plumbing instead of stubbing it out.

import 'dart:convert';
import 'dart:io';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/services/biometric_service.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/services/device_contacts_service.dart';
import 'package:admin/data/services/connectivity_watcher.dart';
import 'package:admin/data/services/token_storage.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/l10n/supported_locales.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/widgets/toast_host.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

/// Every request fails immediately. A deterministic stand-in for the
/// unreachable test server: without it `buildFixture` falls back to a real
/// `http.Client` against `https://example.com`, which on a networked machine
/// (dev box / CI) actually *responds* — so the sidebar prefetch fired by
/// `auth.switchCompany` (`onActiveCompanyChanged` → `_prefetchSidebarOnCompanyChange`)
/// and the company-picker precheck flush leave real `ApiClient` `.timeout()`
/// Timers pending past the test body, tripping "A Timer is still pending even
/// after the widget tree was disposed". Failing fast completes those futures
/// synchronously (no pending Timer) and hands the precheck flush the
/// `NetworkException` it expects (`ApiClient` maps any client error to it).
http.Client _failFastClient() => MockClient(
  (_) async => throw http.ClientException('offline (test fixture)'),
);

/// Depth-first walk over an action list, descending into group items
/// (`pdfGroup` / `cloneGroup`) so a nested action is findable by kind.
///
/// Every `*_actions_test.dart` looks actions up this way. Shared rather than
/// re-declared per file because a non-flattening lookup silently reports
/// `false` for any action that later moves into a group — a false pass, not a
/// failure.
Iterable<EntityActionItem<A>> flattenActionItems<A>(
  List<EntityActionItem<A>> items,
) sync* {
  for (final item in items) {
    yield item;
    yield* flattenActionItems(item.children ?? const []);
  }
}

class FakeCompany {
  const FakeCompany({
    required this.id,
    required this.name,
    this.token = 'tok',
    this.logoUrl,
    this.isOwner = true,
    this.isAdmin = true,
    this.enabledModules = 32767,
    this.permissions = '',
    this.settings = const <String, dynamic>{},
  });
  final String id;
  final String name;
  final String token;

  /// When set, seeded into the company's settings JSON under `company_logo`
  /// so `AuthRepository.restore()` surfaces it on `AuthCompany.logoUrl`.
  final String? logoUrl;

  /// Defaults to true so widget tests exercising the picker land on the
  /// happy "owner can add a new company" path. Set to false when testing
  /// the disabled-by-guard branches.
  final bool isOwner;

  final bool isAdmin;

  /// Company `enabled_modules` bitmask. Defaults to all standard modules on
  /// (32767) to mirror the real `/login` mask — production never sends 0, and
  /// the module-gated actions (e.g. the client "New" menu) need a non-zero
  /// mask. Set to 0 to exercise the all-modules-off branch.
  final int enabledModules;

  /// Comma-separated permission tokens (`'edit_invoice,create_invoice'`), as
  /// the server sends them. `AuthCompany.can()` short-circuits to true for an
  /// admin or owner, so this only bites once BOTH [isAdmin] and [isOwner] are
  /// false — which is exactly how the entity-action tests reach the
  /// per-permission gating (`can('edit_quote')` granted while
  /// `can('create_quote')` is not). Defaults to `''` (the previous hardcoded
  /// value), so existing callers are unaffected.
  final String permissions;

  /// Extra entries merged into the company's serialized `settings` blob —
  /// e.g. `{'translations': {'unit_cost': 'Unit Price'}}` for the Custom
  /// Labels path. [logoUrl] still wins on `company_logo`.
  final Map<String, dynamic> settings;
}

class ShellFixture {
  ShellFixture({required this.db, required this.services});
  final AppDatabase db;
  final Services services;

  Future<void> dispose() async {
    // `services.auth.restore()` in buildFixture starts the Services-owned
    // RefreshScheduler's periodic timer; stop it or the test binding trips
    // "A Timer is still pending even after the widget tree was disposed".
    services.refreshScheduler.dispose();
    await services.auth.dispose();
    await db.close();
  }
}

Future<ShellFixture> buildFixture({
  required List<FakeCompany> companies,
  String? currentCompanyId,
  int trialDays = 0,
  String plan = 'pro',
  int hostedCompanyCount = 10,
  bool online = false,
  // Override the HTTP client to program specific responses (e.g. a 412 on a
  // destructive mutation). Defaults to the fail-fast offline client so the
  // bulk of widget tests never touch the network.
  http.Client? httpClient,
  // Inject a fake address book. Left null, `Services.build` picks the real
  // platform impl — and because `flutter test` reports TargetPlatform.android,
  // that one reports `canSync == true` and then talks to a method channel that
  // isn't there. Contacts-sync tests must pass a fake.
  DeviceContactsService? deviceContactsService,
  // Same trap as the address book: left null, `Services.build` picks the
  // real `local_auth` impl, whose `authenticate()` never completes under
  // `flutter test` (no plugin on the other end of the channel). Anything
  // that pumps the lock screen hangs on `busy` forever unless it passes a
  // fake.
  BiometricService? biometricService,
}) async {
  final db = AppDatabase(NativeDatabase.memory());

  await db.companiesDao.upsertAccount(
    AccountsCompanion.insert(
      id: 'acct1',
      email: 'user@example.com',
      plan: plan,
      numTrialDays: trialDays,
      // `hosted_company_count` lives inside the serialized features blob —
      // `AuthRepository.restore()` decodes it from there. Without this,
      // the default `0` would trip the hosted-plan guard for every test
      // that exercises the "New Company" action.
      featuresJson: Value(
        jsonEncode({'hosted_company_count': hostedCompanyCount}),
      ),
      updatedAt: 0,
    ),
  );
  await db.companiesDao.upsertAll([
    for (final c in companies)
      CompaniesCompanion.insert(
        id: c.id,
        name: c.name,
        displayName: Value(c.name),
        settings: jsonEncode({
          ...c.settings,
          if (c.logoUrl != null) 'company_logo': c.logoUrl,
        }),
        permissions: c.permissions,
        accountId: 'acct1',
        token: c.token,
        isOwner: Value(c.isOwner),
        isAdmin: Value(c.isAdmin),
        enabledModules: Value(c.enabledModules),
        updatedAt: 0,
      ),
  ]);

  final storage = InMemoryTokenStorage();
  await storage.write(
    'invoiceninja.tokens.v1',
    jsonEncode({for (final c in companies) c.id: c.token}),
  );
  await storage.write('invoiceninja.base_url.v1', 'https://example.com');
  await storage.write('invoiceninja.is_hosted.v1', 'true');
  await storage.write(
    'invoiceninja.current_company.v1',
    currentCompanyId ?? companies.first.id,
  );

  final services = Services.build(
    db: db,
    tokenStorage: storage,
    connectivityWatcher: ConnectivityWatcher.fixed(online: online),
    httpClient: httpClient ?? _failFastClient(),
    deviceContactsService: deviceContactsService,
    biometricService: biometricService,
  );
  await services.auth.restore();
  // `restore()` starts the Services-owned RefreshScheduler's periodic 5-min
  // timer. flutter_test checks `!timersPending` at the END of the test body —
  // before `addTearDown` runs — so stopping it in ShellFixture.dispose is too
  // late ("A Timer is still pending even after the widget tree was
  // disposed"). None of the shell widget tests exercise periodic refresh, so
  // stop it here, same rationale as the GoogleFonts timer avoidance below.
  services.refreshScheduler.stop();
  return ShellFixture(db: db, services: services);
}

/// Wraps [child] in the DI + theme surface the real shell uses. The theme
/// deliberately skips the `GoogleFonts` runtime fetch from `buildInTheme`
/// (which spins up an HttpClient and leaves a pending timer in headless
/// tests) — colour tokens are what the sidebar actually reads.
///
/// `Provider<Services>` sits **above** `MaterialApp`, mirroring `main.dart`
/// (where it wraps `MaterialApp.router`). That placement is load-bearing for
/// anything shown on the root navigator: `showDialog` / `Navigator.push`
/// default to `useRootNavigator: true`, so a routed widget mounts under
/// `MaterialApp`'s Navigator — above `home:`. Provided only inside `home:`,
/// every such route threw `ProviderNotFoundException`, and a caller that owns
/// its own route (`showCommandPalette` takes only a `BuildContext`) had no way
/// to re-provide it.
Widget wrapWithShell(Services services, Widget child) {
  final theme = ThemeData.light().copyWith(
    extensions: <ThemeExtension<dynamic>>[InTheme.light],
    dividerColor: InTheme.light.border,
    scaffoldBackgroundColor: InTheme.light.bg,
  );
  return Provider<Services>.value(
    value: services,
    child: MaterialApp(
      theme: theme,
      locale: const Locale('en'),
      supportedLocales: kSupportedLocales,
      localizationsDelegates: [
        _SyncLocalizationDelegate(_enStrings(), _pendingStrings()),
      ],
      // Mirror the real app: the global toast host sits above the content as
      // a later Stack sibling, so any widget that fires a `Notify.*` renders
      // its toast here too.
      home: Stack(
        children: [
          Scaffold(body: child),
          Positioned.fill(child: ToastHost(controller: services.toasts)),
        ],
      ),
    ),
  );
}

/// Synchronous in-process delegate for widget tests. The production
/// `Localization.delegate` loads from `rootBundle` asynchronously, which
/// keeps `MaterialApp`'s child tree hidden until the future resolves —
/// `pumpAndSettle` doesn't always reliably await that load, so tests would
/// run against a still-unloaded `Localizations` ancestor. Reading `en.json`
/// directly off disk and returning a `SynchronousFuture` sidesteps the
/// problem and matches what production renders for English users.
class _SyncLocalizationDelegate extends LocalizationsDelegate<Localization> {
  _SyncLocalizationDelegate(this._strings, this._pending);
  final Map<String, String> _strings;
  final Map<String, String> _pending;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<Localization> load(Locale locale) => SynchronousFuture(
    Localization.forTesting(strings: _strings, pending: _pending),
  );

  @override
  bool shouldReload(LocalizationsDelegate<Localization> old) => false;
}

Map<String, String>? _enStringsCache;
Map<String, String> _enStrings() {
  final cached = _enStringsCache;
  if (cached != null) return cached;
  final raw = File('assets/i18n/en.json').readAsStringSync();
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final map = decoded.map((k, v) => MapEntry(k, v.toString()));
  _enStringsCache = map;
  return map;
}

Map<String, String>? _pendingStringsCache;
Map<String, String> _pendingStrings() {
  final cached = _pendingStringsCache;
  if (cached != null) return cached;
  final raw = File('assets/i18n/_app_pending.json').readAsStringSync();
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final map = decoded.map((k, v) => MapEntry(k, v.toString()));
  _pendingStringsCache = map;
  return map;
}
