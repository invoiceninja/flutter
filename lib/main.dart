import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:admin/app/app_deep_links.dart';
import 'package:admin/app/debug_capture_store.dart';
import 'package:admin/app/app_reload.dart';
import 'package:admin/app/boot_log.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:timezone/data/latest_10y.dart' as tz;
import 'package:admin/app/diagnostics_log.dart';
import 'package:admin/app/env.dart';
import 'package:admin/app/idle_timeout_controller.dart';
import 'package:admin/app/logging.dart';
import 'package:admin/app/native_splash.dart';
import 'package:admin/app/native_window.dart';
import 'package:admin/app/native_window_theme.dart';
import 'package:admin/app/nav_history_controller.dart';
import 'package:admin/app/nav_state_persister.dart';
import 'package:admin/app/router.dart';
import 'package:admin/app/sentry_gate.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/text_scale_controller.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/app/version.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/database_opener.dart';
import 'package:admin/data/db/db_open_exception.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/sync_lifecycle_observer.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/l10n/supported_locales.dart';
import 'package:admin/ui/features/shell/widgets/window_frame.dart';
import 'package:admin/ui/core/widgets/call_log_prompter.dart';
import 'package:admin/ui/core/widgets/shortcut_hint_overlay.dart';
import 'package:admin/ui/core/widgets/toast_host.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';

/// Bootstrap entry point.
///
/// Order:
///   1. ensureInitialized + logging
///   2. Open Drift (with `.broken.<ts>` recovery)
///   3. Build Services (DI graph) and restore any persisted session
///   4. Read persisted nav state so the app reopens where it left off
///   5. Run the app — the router watches `AuthRepository.credentials` and
///      flips between `/login` and the authenticated shell on its own.
Future<void> main() async {
  // Wrap everything past `ensureInitialized` in `runZonedGuarded` so async
  // errors that escape the Flutter tree (timers, untracked Futures) hit our
  // diagnostics log AND the in-memory debug-capture ring. The diagnostics log
  // is debug-only; the capture store lives in release too so the hidden Debug
  // Panel can show what went wrong in prod when capture is enabled.
  // Sentry only in release builds with a configured DSN (mirrors v1's
  // `kReleaseMode` gate; debug/test/CI and self-hosted-without-DSN take the
  // unchanged direct path → zero behavior change there). When enabled it
  // *wraps* the existing zoned bootstrap — it doesn't replace it: the
  // diagnostics / debug-capture handler chain still composes on top, so
  // errors reach our recorders AND Sentry. Per-account opt-in is enforced
  // in `beforeSend` via `sentryShouldSend`.
  // Web is excluded for the first milestone: `sentry_flutter` on web needs
  // its own JS-SDK wiring in `web/index.html`; deferred (see plan). Web
  // takes the unchanged direct `runZonedGuarded` path → zero web behavior
  // change. Native behavior is byte-identical (the added `!kIsWeb` is a
  // const true on every native target).
  if (!kIsWeb && !kDebugMode && Env.sentryDsn.isNotEmpty) {
    await SentryFlutter.init((o) {
      o.dsn = Env.sentryDsn;
      o.release = AppVersion.kClientVersion;
      o.dist = AppVersion.kClientVersion;
      o.beforeSend = (event, hint) =>
          sentryShouldSend(
            reportErrors: _authForSentry?.session.value?.reportErrors ?? false,
          )
          ? event
          : null;
    }, appRunner: () => runZonedGuarded(_bootstrap, _zoneOnError));
  } else {
    await runZonedGuarded(_bootstrap, _zoneOnError);
  }
}

/// Shared `runZonedGuarded` error sink for both bootstrap branches (Sentry-
/// wrapped and direct). Routes escaped async errors to the diagnostics log
/// + debug-capture ring exactly as before.
void _zoneOnError(Object error, StackTrace stack) {
  // Print first, unconditionally — both sinks below are null exactly when this
  // matters most. A throw inside [_bootstrap] happens before `runApp`, so the
  // user is left on the HTML boot loader (`web/index.html`) with no Flutter
  // tree to show it; and on web `_diagnosticsLogRef` is *never* non-null
  // (`_initDiagnostics` returns null there). Without this line a fatal boot
  // error is completely invisible and an endless spinner is the only symptom —
  // which is how the demo's returning-visitor wedge went undiagnosed.
  bootLog('Uncaught zone error: $error\n$stack');
  _diagnosticsLogRef?.recordError(error, stack, context: 'runZonedGuarded');
  _debugCaptureStoreRef?.recordError(error, stack, context: 'runZonedGuarded');
}

/// Late-bound auth ref so Sentry's `beforeSend` (a closure created before
/// the DI graph exists) can read the active account's `report_errors`
/// opt-in at error time. Mirrors the [_diagnosticsLogRef] pattern; set in
/// [_bootstrap] once `Services` is built.
AuthRepository? _authForSentry;

/// Module-private reference so the `runZonedGuarded` error handler can reach
/// the [DiagnosticsLog] without smuggling it through a closure. Set during
/// [_bootstrap] before `runApp`; remains `null` in release builds.
DiagnosticsLog? _diagnosticsLogRef;

/// Mirror of [_diagnosticsLogRef] for the always-on debug-capture store.
/// Set during [_bootstrap]; null until then.
DebugCaptureStore? _debugCaptureStoreRef;

/// Bounds on the two boot phases that read the local database without a
/// network call of their own. Neither used to be bounded, and both sit before
/// `runApp` — so a store that stalls instead of failing took the whole app
/// down to a blank boot loader. Generous on purpose: these must only ever fire
/// on a genuinely wedged store, never on a cold, slow disk.
const _kRestoreBudget = Duration(seconds: 20);
const _kNavStateBudget = Duration(seconds: 10);

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  initLogging();
  // IANA tzdb, for the callee's real local time beside a phone number and for
  // the outside-business-hours warning (`docs/tap-to-call.md`). Synchronous and
  // web-safe — the data is compiled-in Dart, not an asset fetch — so it costs a
  // few ms here rather than a null check at every call site. Must run before
  // any `tz.getLocation`; `contactClock` degrades to the server's fixed
  // standard-time offset if it somehow hasn't.
  //
  // `latest_10y`, not `latest_all`: 86 KB of transition data instead of 444 KB,
  // across six platforms. The only question this app asks the tzdb is "what is
  // the offset *now*", and the 10-year window is regenerated on every package
  // release, so each app release refreshes it. Switch to `latest_all` if
  // something ever needs a historical or far-future date.
  tz.initializeTimeZones();
  // Dart hot-restart preserves static fields, so without this reset the iOS
  // SplashOverlay would see `dismissed` already true on the second run and
  // skip its entry. Stripped from release builds via `assert`.
  assert(() {
    NativeSplash.dismissed.value = false;
    return true;
  }());

  // Cold-start instrumentation. Each stage logs its own duration and the
  // cumulative time-to-here so a regression in any one boot phase
  // (secure-storage key fetch, DB open, session restore, statics warm) is
  // attributable from the console without a profiler.
  //
  // Debug everywhere, and **also release on web**: a boot that never reaches
  // `runApp` leaves the user on the HTML loader with no Flutter tree and — on
  // web — no diagnostics log either, so the last stage printed is the only
  // thing that names the await which never returned. Half a dozen log lines
  // per boot is a cheap price for the one platform that can't be attached to
  // a debugger after the fact. Still compiled out of native release builds.
  final bootSw = Stopwatch()..start();
  var lastMs = 0;
  void mark(String stage) {
    if (!kDebugMode && !kIsWeb) return;
    final now = bootSw.elapsedMilliseconds;
    Logger('main.boot').info('$stage: ${now - lastMs}ms (t+${now}ms)');
    lastMs = now;
  }

  final diag = await _initDiagnostics();
  _diagnosticsLogRef = diag;
  mark('diagnostics');

  final OpenedDatabase opened;
  try {
    opened = await openAppDatabase();
  } on KeyringUnavailableException catch (e, st) {
    // The OS secret store (keychain / keyring) is unreachable, so the
    // encrypted DB can't be opened — e.g. a Linux snap whose
    // `password-manager-service` plug isn't connected. Render an actionable
    // screen instead of leaving a blank window that re-loops every launch.
    diag?.recordError(e, st, context: 'openAppDatabase: keyring unavailable');
    runApp(const _SecureStorageUnavailableApp());
    return;
  } on DatabaseUnavailableException catch (e, st) {
    // The store could not be opened for a reason a reset would not fix (on
    // web, usually the app being open in another tab). It was left untouched,
    // so the user's unsynced work is still there for the next attempt.
    diag?.recordError(e, st, context: 'openAppDatabase: ${e.kind.name}');
    runApp(_LocalDataUnavailableApp(detail: '${e.cause}', kind: e.kind));
    return;
  } catch (e, st) {
    // `openAppDatabase` recovers from a bad store by destroying and reopening
    // it, but that recovery can itself throw — on web a second
    // `WasmDatabase.open` timing out because a stale browser context still
    // holds the IndexedDB/OPFS lock (the forced reload Flutter's service
    // worker performs after a redeploy leaves exactly that). This branch used
    // not to exist, so the `TimeoutException` escaped `_bootstrap`, `runApp`
    // was never called, and the user sat on the HTML boot loader forever with
    // no route out but clearing site data. Boot must always paint.
    diag?.recordError(e, st, context: 'openAppDatabase');
    runApp(_LocalDataUnavailableApp(detail: '$e'));
    return;
  }
  mark('db-open (incl. secure-storage key)');
  if (opened.recovery case final recovery?) {
    // Not yet surfaced in the UI — the diagnostics log is where a reset's
    // outcome (what was carried over, or where the old store was kept) lands.
    // `wasReset` is false when an earlier launch's salvage finished here.
    Logger('main.boot').warning(
      'Local data recovery (reset this launch: ${opened.wasReset}): $recovery',
    );
  }
  final services = Services.build(db: opened.db, diagnosticsLog: diag);
  // Subscribe to the desktop runner's window pushes (fullscreen enter/exit) and
  // seed the current state. No-op off desktop; nothing downstream awaits it, so
  // it never gates the first frame.
  unawaited(NativeWindow.instance.listenForNativeEvents());
  _debugCaptureStoreRef = services.debugCaptureStore;
  _authForSentry = services.auth;
  _installCaptureHandlers(services.debugCaptureStore);
  // Bounded and guarded: all sixteen reads hit the same single `nav_state`
  // row over one database connection, so a wedged store stalls the lot — and
  // an unbounded, uncaught `Future.wait` here meant `runApp` was never
  // reached. Every one of these controllers has a working default, so a
  // failure or timeout costs the user their *preferences* for this launch,
  // never the app itself.
  try {
    await Future.wait([
      services.auth.restore(),
      services.theme.restore(),
      services.locale.restore(),
      services.textScale.restore(),
      services.keyboardShortcuts.restore(),
      services.sidebar.restore(),
      services.confirmActions.restore(),
      services.statusTabs.restore(),
      services.hideUnverifiedUsers.restore(),
      services.tasksView.restore(),
      services.hideEmptyPanels.restore(),
      services.phoneActions.restore(),
      services.sidebarBadgeModes.restore(),
      services.sidebarMenu.restore(),
      services.recentlyViewed.restore(),
      services.contactsSync.restore(),
    ]).timeout(_kRestoreBudget);
  } catch (e, st) {
    diag?.recordError(e, st, context: 'boot restore');
    Logger('main').warning('Session/preference restore failed at boot', e, st);
  }
  mark('restore (auth/theme/locale/sidebar)');

  // Demo build: if no session was restored, bootstrap one from a baked-in API
  // token so the app lands on the dashboard instead of /login. Inert in normal
  // builds — `Env.demoApiToken` is empty unless set via --dart-define.
  if (!services.auth.isAuthenticated && Env.demoApiToken.isNotEmpty) {
    try {
      // Time-bounded so a stalled network call can't trap boot on the loader;
      // a throw or timeout just leaves the user unauthenticated → /login.
      await services.auth
          .loginWithToken(
            baseUrl: Env.demoApiUrl,
            isHosted: false,
            token: Env.demoApiToken,
          )
          .timeout(const Duration(seconds: 15));
    } catch (e, st) {
      Logger('main').warning('Demo token bootstrap failed', e, st);
    }
    mark('demo token bootstrap');
  }

  // Warm the statics cache before any screen mounts so dropdowns reading
  // `Services.statics` (Company Details size/industry, Localization currency/
  // language/country, …) render populated on first frame instead of flashing
  // "loading". Reads from the Drift cache when fresh (≤ TTL); only the rare
  // stale/empty case pays a network round-trip.
  if (services.auth.isAuthenticated) {
    // Time-bounded + guarded: warming statics is a nice-to-have, never a
    // reason to block the first frame. A slow/failed fetch just means the
    // first screen reads statics from cache (or lazily warms later).
    try {
      await services.statics.ensureLoaded().timeout(
        const Duration(seconds: 10),
      );
    } catch (e, st) {
      Logger('main').warning('Statics warm failed at boot', e, st);
    }
    mark('statics warm');
  }

  // Resume where you left off: pick the persisted route if we have one and
  // the user is still authenticated. Unauthenticated → /login regardless.
  // When biometric is enabled, the router's redirect routes the deep link
  // through `/lock?from=<encoded>` and back out on unlock — we just feed it
  // the user's last route here.
  // Bounded and guarded for the same reason as the restore block above: this
  // is the last await before `runApp`, so a stalled read here is invisible —
  // it looks exactly like a hung app. Falling back to `null` just means the
  // user lands on the default route instead of their last one.
  NavStateData? navState;
  try {
    navState = await opened.db.navStateDao.current().timeout(_kNavStateBudget);
  } catch (e, st) {
    diag?.recordError(e, st, context: 'boot nav-state');
    Logger('main').warning('Restoring the last route failed at boot', e, st);
  }
  // Strip any entity-row segment from the restored URL so cold-start
  // lands on the bare entity list rather than the last-viewed row
  // (`/clients/c_42` → `/clients`; `/settings/...` passes through — see
  // `companySafeLocation`).
  //
  // ALSO strip a trailing `/new` create segment: resuming into a transient
  // create form pre-mounts the create screen, which go_router then reuses
  // (without re-running its bootstrap) on the next "New X" navigation — so a
  // staged client seed / `extra` is never consumed and the form opens blank.
  // Verified via diagnostics: the create `buildVm` ran once at startup (from
  // the restored `/invoices/new`) and never again on the click. Land on the
  // base list instead (`/invoices/new` → `/invoices`).
  final restoredRawRow = navState?.currentRoute;
  // Defensive: a persisted `/calendar_connection/complete` (from a build
  // before it joined the persister skip-list) carries a consumed one-time
  // handoff token; restoring it would re-POST it → a spurious "connect
  // failed". Drop it so we fall back to the default route.
  final restoredRaw =
      (restoredRawRow != null &&
          (restoredRawRow == '/calendar_connection/complete' ||
              restoredRawRow.startsWith('/calendar_connection/complete?')))
      ? null
      : restoredRawRow;
  final restoredUri = restoredRaw == null ? null : Uri.tryParse(restoredRaw);
  final restored =
      (restoredUri != null &&
          restoredUri.pathSegments.isNotEmpty &&
          restoredUri.pathSegments.last == 'new')
      ? (restoredUri.pathSegments.length == 1
            ? null // bare `/new` (no base) → fall back to the default route
            : '/${restoredUri.pathSegments.sublist(0, restoredUri.pathSegments.length - 1).join('/')}')
      : restoredRaw;
  final initialLocation = services.auth.isAuthenticated
      ? (restored == null
            ? defaultPostLoginRoute(services.auth.session.value)
            : companySafeLocation(
                restored,
                services.entityRegistry.uiRoutePaths,
              ))
      : '/login';

  mark('nav-state + route resolve');
  // Web URL strategy is left at Flutter's default (hash — `/#/clients`).
  // This is intentional: hash routing needs no server rewrite-to-index
  // config, so the build deploys to any static host. Do NOT add
  // `setUrlStrategy(PathUrlStrategy())` — it would break deep links on
  // hosts without an index fallback. (Locked decision — see plan.)
  runApp(
    InvoiceNinjaApp(
      services: services,
      dbWasReset: opened.wasReset,
      initialLocation: initialLocation,
    ),
  );
}

/// Minimal full-screen error shown when the OS secret store (keychain /
/// keyring) is unreachable and the encrypted DB can't be opened. `Services`
/// and localization aren't available this early, so the copy is plain English.
/// The actionable hint targets the common cause: a Linux snap whose
/// `password-manager-service` plug hasn't been connected.
class _SecureStorageUnavailableApp extends StatelessWidget {
  const _SecureStorageUnavailableApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.lock_outline, size: 48),
                  SizedBox(height: 16),
                  Text(
                    'Secure storage unavailable',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Invoice Ninja stores its data encrypted and could not reach '
                    'your system keychain to unlock it.\n\n'
                    'On Linux (snap), connect the keyring permission and '
                    'relaunch:',
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12),
                  SelectableText(
                    'snap connect invoiceninja:password-manager-service',
                    style: TextStyle(fontFamily: kMonoFontFamily),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Minimal full-screen error shown when the local database could not be
/// opened *and* `openAppDatabase`'s own destroy-and-reopen recovery failed
/// too. `Services` and localization aren't available this early, so the copy
/// is plain English.
///
/// This exists because the alternative is worse than an error screen: before
/// it, that failure escaped `_bootstrap` uncaught, `runApp` was never called,
/// and the user was left on the HTML boot loader (`web/index.html`) — a dead
/// end whose only escape was clearing site data. The overwhelmingly common
/// cause on web is a store still locked by a stale browser context, which
/// clears on its own within seconds, so "Try again" is a real fix and is
/// offered first.
class _LocalDataUnavailableApp extends StatefulWidget {
  const _LocalDataUnavailableApp({required this.detail, this.kind});

  /// The underlying error, shown small — enough for a bug report without
  /// making the screen look like a crash dump.
  final String detail;

  /// Why the open failed, when `openAppDatabase` classified it and left the
  /// store untouched ([DatabaseUnavailableException]); null when recovery
  /// itself failed. Picks the explanation — "close your other tab" is the
  /// right advice for a lock and useless for a full disk.
  final DbOpenFailureKind? kind;

  @override
  State<_LocalDataUnavailableApp> createState() =>
      _LocalDataUnavailableAppState();
}

class _LocalDataUnavailableAppState extends State<_LocalDataUnavailableApp> {
  bool _busy = false;

  Future<void> _resetAndReload() async {
    setState(() => _busy = true);
    try {
      await destroyDatabaseStore();
    } catch (e, st) {
      Logger('main').warning('Resetting local data failed', e, st);
    }
    if (kIsWeb) {
      reloadApp();
    } else if (mounted) {
      setState(() => _busy = false);
    }
  }

  static String _explanation(DbOpenFailureKind? kind) => switch (kind) {
    DbOpenFailureKind.storageFull =>
      kIsWeb
          ? 'Your browser has run out of storage for Invoice Ninja\'s local '
                'data. Free up some space, then try again.'
          : 'Your device has run out of storage for Invoice Ninja\'s local '
                'data. Free up some space, then relaunch the app.',
    DbOpenFailureKind.transient || DbOpenFailureKind.unknown =>
      kIsWeb
          ? 'Invoice Ninja is probably open in another tab, or a tab that '
                'just closed is still holding its local data. Close any other '
                'Invoice Ninja tabs, then try again.'
          : 'The local database is busy or temporarily unavailable. Quit '
                'Invoice Ninja and open it again to retry.',
    // Recovery itself failed, or a reset-worthy failure we could not repair.
    DbOpenFailureKind.corrupt ||
    DbOpenFailureKind.migrationFailed ||
    null => 'Invoice Ninja could not open its local database.',
  };

  @override
  Widget build(BuildContext context) {
    // Nothing here is localized on purpose: this screen renders before
    // `Services` exists, so there is no `Localization` to read from.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storage_outlined, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Could not open local data',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Text(_explanation(widget.kind), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  // Honest about what a reset costs. This used to promise that
                  // "everything is re-downloaded from the server", which is
                  // true of the cache and false of the outbox: changes made on
                  // this device that never reached the server exist nowhere
                  // else. Native keeps the old store and carries those tables
                  // into the new one on relaunch (`readQuarantinedStore`) when
                  // it can still be read; web has no salvage yet.
                  Text(
                    kIsWeb
                        ? 'Resetting deletes this device\'s copy of your data. '
                              'Everything already synced downloads again, but '
                              'changes made on this device that haven\'t '
                              'synced yet are lost.'
                        : 'Resetting starts this device\'s copy of your data '
                              'over, and everything already synced downloads '
                              'again. Changes that haven\'t synced yet are '
                              'carried over if the old copy can still be read, '
                              'and lost if it can\'t.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  // Paired side-by-side, never stacked (§ Design system).
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (kIsWeb) ...[
                        FilledButton(
                          onPressed: _busy ? null : reloadApp,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(64, 44),
                          ),
                          child: const Text('Try again'),
                        ),
                        const SizedBox(width: 12),
                      ],
                      OutlinedButton(
                        onPressed: _busy ? null : _resetAndReload,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(64, 40),
                        ),
                        child: Text(_busy ? 'Resetting…' : 'Reset local data'),
                      ),
                    ],
                  ),
                  if (!kIsWeb) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Then relaunch the app.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 20),
                  SelectableText(
                    widget.detail,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: kMonoFontFamily,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wire up the debug-only Claude-readable diagnostics log. Returns `null`
/// in release builds — no file is created, no handlers are registered.
///
/// The handlers route uncaught Flutter/Dart errors and WARNING+ Logger
/// records into the same on-disk file. The path is surfaced in Settings →
/// Advanced → System Logs so Claude can be pointed at it.
Future<DiagnosticsLog?> _initDiagnostics() async {
  if (kReleaseMode) return null;
  // No on-disk diagnostics log on web: `DiagnosticsLog.open()` resolves a
  // path via `path_provider`, which has no web implementation and throws.
  // The rest of bootstrap already handles `diag == null`. (Web error
  // capture, if wanted later, is a separate JS-SDK concern — see plan.)
  if (kIsWeb) return null;
  try {
    final diag = await DiagnosticsLog.open();
    final priorFlutterOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      // recordFlutterError (not recordError) so the "relevant error-causing
      // widget" hints land in the on-disk log — otherwise it's framework-only
      // and can't name the culprit widget.
      diag.recordFlutterError(details);
      // Known-benign framework/plugin noise (RawAutocomplete focus asserts,
      // printing's transient raster RangeError) is already kept out of the
      // on-disk log by recordFlutterError; swallow it from the debug console
      // too so it can't bury real errors. Debug-only by construction —
      // `_initDiagnostics` installs no handler in release.
      if (isKnownBenignFrameworkNoise(details.exception, details.stack)) {
        return;
      }
      if (priorFlutterOnError != null) {
        priorFlutterOnError(details);
      } else {
        FlutterError.presentError(details);
      }
    };
    final priorPlatformOnError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      diag.recordError(error, stack, context: 'PlatformDispatcher');
      return priorPlatformOnError?.call(error, stack) ?? false;
    };
    Logger.root.onRecord.listen((record) {
      if (record.level < Level.WARNING) return;
      diag.recordLog(record);
    });
    Logger('main').info('Diagnostics log open at ${diag.path}');
    return diag;
  } catch (e, st) {
    Logger('main').warning('Diagnostics log init failed', e, st);
    return null;
  }
}

/// Install error / log handlers that fan out into the [DebugCaptureStore].
/// These run in release builds too — they're the only error sink in prod.
/// Each handler chains to the existing one (which in debug already routes to
/// [DiagnosticsLog] from [_initDiagnostics]), so this never displaces the
/// Claude-readable file logger.
void _installCaptureHandlers(DebugCaptureStore store) {
  final priorFlutterOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    store.recordError(
      details.exception,
      details.stack,
      context: details.context?.toString(),
    );
    if (priorFlutterOnError != null) {
      priorFlutterOnError(details);
    } else {
      FlutterError.presentError(details);
    }
  };
  final priorPlatformOnError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    store.recordError(error, stack, context: 'PlatformDispatcher');
    return priorPlatformOnError?.call(error, stack) ?? false;
  };
  Logger.root.onRecord.listen((record) {
    if (record.level < Level.WARNING) return;
    store.recordLog(record);
  });
}

/// Top-level widget. Built once at boot from a fully-initialised [Services]
/// graph and a resolved [initialLocation].
///
/// Responsibilities:
///   - Build the [GoRouter] from `Services` (auth, client-version, biometric
///     gating; nothing app-wide is built lower in the tree).
///   - Attach a [NavStatePersister] so the user's last route survives restart.
///   - Register two [WidgetsBindingObserver]s — password-cache wipe on
///     background, sync drain on resume.
///   - Render [MaterialApp.router], rebuilt only when the persisted theme or
///     locale changes (see `build` below).
class InvoiceNinjaApp extends StatefulWidget {
  const InvoiceNinjaApp({
    required this.services,
    required this.dbWasReset,
    required this.initialLocation,
    super.key,
  });

  final Services services;
  final bool dbWasReset;
  final String initialLocation;

  @override
  State<InvoiceNinjaApp> createState() => _InvoiceNinjaAppState();
}

class _InvoiceNinjaAppState extends State<InvoiceNinjaApp> {
  // Owned for the app's lifetime: router, nav-state persister, and lifecycle
  // observers. All four are `late final` so they're built once on first access
  // and torn down in `dispose`.
  late final GoRouter _router = buildRouter(
    isAuthenticated: () => widget.services.auth.isAuthenticated,
    postLoginRoute: () =>
        defaultPostLoginRoute(widget.services.auth.session.value),
    isClientTooOld: () => widget.services.clientTooOld.value != null,
    isBiometricLockRequired: () =>
        widget.services.auth.requiresBiometricUnlock.value,
    isCompanySetupRequired: () =>
        isCompanySetupRequired(widget.services.auth.session.value),
    refreshListenable: Listenable.merge([
      widget.services.auth.credentials,
      // `session` fires on every Drift `companies`-table change (see the
      // `_companiesSub` watcher in `AuthRepository`), so the optimistic
      // settings.name write from the setup wizard releases the `/setup`
      // gate without waiting for the outbox PUT to round-trip.
      widget.services.auth.session,
      widget.services.auth.requiresBiometricUnlock,
      widget.services.clientTooOld,
    ]),
    registry: widget.services.entityRegistry,
    disabledModuleRoots: () => disabledEntityRoots(
      widget.services.entityRegistry,
      widget.services.auth.session.value?.currentCompany?.enabledModules ?? 0,
    ).toSet(),
    initialLocation: widget.initialLocation,
  );

  late final NavStatePersister _navPersister = NavStatePersister.fromRouter(
    router: _router,
    db: widget.services.db,
  );

  late final NavHistoryController _navHistory = NavHistoryController.fromRouter(
    router: _router,
    session: widget.services.auth.session,
  );

  // Bridges deep links (shared record links + the calendar-OAuth return) into
  // `services.deepLinks`: from the OS natively, and on web from the URL the
  // page was loaded with — there nothing delivers a link, it *is* the address.
  late final AppDeepLinks _appDeepLinks = AppDeepLinks(
    widget.services.deepLinks,
  );

  late final PasswordCacheLifecycleObserver _passwordCacheObserver =
      PasswordCacheLifecycleObserver(widget.services.passwordCache);

  late final SyncLifecycleObserver _syncObserver = SyncLifecycleObserver(
    auth: widget.services.auth,
    sync: widget.services.sync,
    refreshScheduler: widget.services.refreshScheduler,
  );

  late final IdleTimeoutController _idleTimeout = IdleTimeoutController(
    auth: widget.services.auth,
    company: widget.services.company,
    sync: widget.services.sync,
  );

  @override
  void initState() {
    super.initState();
    // Reference `_navPersister` / `_navHistory` so their `late final`
    // initializers run now — each constructor attaches a router listener and
    // we never call methods on `_navPersister` directly.
    _navPersister;
    _navHistory;
    // The deep-link router needs the GoRouter (which only exists now) and a
    // context under the MultiProvider for the company-switch guards' dialogs.
    // The root navigator's context is null until the first frame, so the
    // supplier is a callback rather than a value — a cold-start link retries
    // itself instead of being dropped.
    widget.services.deepLinks.attach(
      go: _router.go,
      contextOf: () => _router.routerDelegate.navigatorKey.currentContext,
    );
    _appDeepLinks;
    WidgetsBinding.instance.addObserver(_passwordCacheObserver);
    WidgetsBinding.instance.addObserver(_syncObserver);
    WidgetsBinding.instance.addObserver(_idleTimeout);
    // Dismiss the splash once Flutter has actually painted — keeps the logo
    // on screen through the router redirect chain instead of a fixed timer.
    // Two-frame deferral: the first post-frame lets GoRouter's synchronous
    // redirect chain resolve and paint; the second gives the auth-restore
    // microtask one more frame to settle before we fade the overlay. Native
    // macOS side has a 6 s safety fallback.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => NativeSplash.dismiss(),
      );
    });
    if (widget.dbWasReset) {
      debugPrint('Drift was reset on open — user should re-login and re-sync.');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_idleTimeout);
    WidgetsBinding.instance.removeObserver(_syncObserver);
    WidgetsBinding.instance.removeObserver(_passwordCacheObserver);
    _idleTimeout.dispose();
    widget.services.refreshScheduler.dispose();
    _navPersister.dispose();
    _navHistory.dispose();
    _appDeepLinks.dispose();
    widget.services.deepLinks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The nested builders rebuild `MaterialApp.router` when the persisted
    // theme or locale changes, so a settings toggle takes effect without a
    // restart. `ListenableBuilder` reacts to `ThemeController` (mode +
    // light/dark variant + custom palette) so picking a sub-palette or
    // editing a custom colour repaints immediately. `lightTokens` /
    // `darkTokens` return memoised instances (the controller caches the
    // resolved custom palette) so unrelated rebuilds don't churn the theme.
    final theme = widget.services.theme;
    return MultiProvider(
      providers: [
        Provider<Services>.value(value: widget.services),
        // Exposed so `ScaffoldWithNav`'s back/forward shortcuts can drive it.
        ChangeNotifierProvider<NavHistoryController>.value(value: _navHistory),
        // Mount the settings-edit scope once at the root so every settings
        // page reads the same instance via `context.watch<…>()` without
        // having to thread it through the route tree. The same controller
        // lives on `Services.settingsLevel` for non-widget callers (e.g.
        // the client detail screen's action handler).
        ChangeNotifierProvider<SettingsLevelController>.value(
          value: widget.services.settingsLevel,
        ),
      ],
      child: ListenableBuilder(
        listenable: Listenable.merge([
          theme,
          widget.services.accentColor,
          widget.services.textScale,
        ]),
        builder: (context, _) => ValueListenableBuilder<Locale?>(
          // Resolved locale: device override → active company's
          // settings.language_id → English (see AppLocaleResolver). The device
          // App Language picker writes `services.locale`, which feeds this.
          valueListenable: widget.services.appLocale,
          builder: (context, locale, _) => MaterialApp.router(
            title: 'Invoice Ninja',
            debugShowCheckedModeBanner: false,
            themeMode: theme.themeMode,
            locale: locale,
            // `lightTokens`/`darkTokens` already layer the user's per-side
            // colour overrides onto the selected preset. Accent stays the
            // single per-user `accentColor` setting (server-synced), applied
            // to both sides. Both `theme:`/`darkTheme:` stay populated so
            // `ThemeMode.system` resolves correctly and the macOS titlebar
            // (builder below, which reads the resolved extension) keeps
            // following OS brightness.
            theme: buildInTheme(
              theme.lightTokens,
              accentOverride: widget.services.accentColor.value,
            ),
            darkTheme: buildInTheme(
              theme.darkTokens,
              accentOverride: widget.services.accentColor.value,
            ),
            supportedLocales: kSupportedLocales,
            localizationsDelegates: const [
              Localization.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: _router,
            // Push the resolved variant's bg/ink to the native macOS
            // titlebar. `Theme.of(context)` here is already resolved (system
            // → light/dark via MediaQuery), so this picks up live OS-Dark
            // flips under `ThemeMode.system` for free. `apply` dedupes, so
            // the per-rebuild cost is negligible.
            builder: (context, child) {
              final tokens = Theme.of(context).extension<InTheme>();
              if (tokens != null) {
                scheduleMicrotask(() {
                  NativeWindowTheme.instance.apply(
                    background: tokens.bg,
                    title: tokens.ink,
                    // The window's outer edge sits against an arbitrary
                    // desktop, so it takes the app's stronger hairline — unlike
                    // the title bar's own internal rule, which matches the
                    // app's ordinary dividers.
                    border: tokens.borderStrong,
                    brightness: tokens.brightness,
                  );
                });
              }
              // Apply the device-local UI text-scale override app-wide
              // (Settings → Device Settings), composed with the OS/accessibility
              // scaler so a larger system font is respected — at the default
              // factor (1.0) this is a pure OS passthrough. `copyWith` keeps the
              // rest of the MediaQuery. The controller is in this builder's
              // merged listenable, so a change rebuilds here.
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(
                  textScaler: composeTextScaler(
                    mq.textScaler,
                    widget.services.textScale.value,
                  ),
                ),
                // Feed user activity to the idle-timeout enforcer. Translucent
                // so it never intercepts gestures; `poke()` is a cheap clock
                // stamp read by the controller's periodic check.
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) => _idleTimeout.poke(),
                  onPointerMove: (_) => _idleTimeout.poke(),
                  onPointerSignal: (_) => _idleTimeout.poke(),
                  onPointerHover: (_) => _idleTimeout.poke(),
                  // iOS: layer an animated splash overlay above all routes so
                  // the storyboard → Flutter handoff has a gentle exit instead
                  // of a hard cut. Passthrough on every other platform.
                  child: NativeSplash.wrap(
                    // Global toast host (top layer) over the app. A later
                    // sibling in this Stack paints ABOVE every route AND modal
                    // dialog/sheet (they live inside `child` on the root
                    // navigator's overlay), so toasts are never hidden behind a
                    // password/conflict sheet. `Positioned.fill` gives the host
                    // tight constraints; it lays out only a small corner column,
                    // so taps outside a toast fall through to the app/barrier.
                    // Excluded from the screenshot RepaintBoundary on purpose —
                    // a transient toast shouldn't bleed into store captures.
                    child: Stack(
                      children: [
                        // Root capture boundary for the Debug Panel's screenshot
                        // button: snapshotting this yields the full window at
                        // exactly `physicalSize`. Inside `NativeSplash.wrap` so
                        // the iOS splash overlay is excluded; below the
                        // textScaler MediaQuery so the shot reflects the user's
                        // text scale.
                        RepaintBoundary(
                          key: widget.services.screenshotWindow.boundaryKey,
                          // Frameless Windows/Linux only: paints the app's own
                          // title bar above every route (a passthrough on macOS,
                          // mobile and web). It must wrap the router rather than
                          // live in the shell — `/login`, `/lock` and the route
                          // error screen have no sidebar, and a frameless window
                          // with no chrome there could not be moved or closed.
                          // Inside the boundary so store captures match the app.
                          child: WindowFrame(
                            screenshotWindow: widget.services.screenshotWindow,
                            railCollapsed: widget.services.sidebar,
                            shellMounted: widget.services.shellMounted,
                            child: child ?? const SizedBox.shrink(),
                          ),
                        ),
                        Positioned.fill(
                          child: ToastHost(controller: widget.services.toasts),
                        ),
                        // Slack-style hint bar: holding ⌘/Ctrl reveals the
                        // modifier shortcuts available in the current context.
                        // A sibling of ToastHost so it too paints above every
                        // route and modal; non-interactive so taps fall
                        // through.
                        Positioned.fill(
                          child: ShortcutHintOverlay(
                            controller: widget.services.shortcutHints,
                          ),
                        ),
                        // Paints nothing — it watches the app lifecycle and
                        // raises the "log this call?" toast when the user comes
                        // back from the dialer (invoiceninja/flutter#120). A
                        // widget rather than a fourth `WidgetsBindingObserver`
                        // above, because the offer opens a form and enqueues
                        // through the repositories, so it needs a context under
                        // the providers.
                        CallLogPrompter(
                          services: widget.services,
                          // A context inside the router's Navigator — this
                          // widget's own sits above it, so a sheet pushed from
                          // there would find no Navigator at all. Same supplier
                          // `deepLinks.attach` takes, for the same reason.
                          contextOf: () => _router
                              .routerDelegate
                              .navigatorKey
                              .currentContext,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
