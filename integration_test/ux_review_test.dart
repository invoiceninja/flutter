/// UX review sweep — drives the real app across a scripted tour and captures
/// one PNG per stop, at a viewport / platform / theme / text-scale / locale
/// combination supplied by `--dart-define`.
///
/// Run via `tools/capture_ux_review.sh` only. Self-skips without
/// `IN_DEMO_API_TOKEN`, so it never perturbs `flutter test`,
/// `tools/run_integration_local.sh`, or CI.
///
/// Three things about this file are load-bearing; changing them silently
/// destroys the results rather than failing loudly.
///
/// **1. `debugDefaultTargetPlatformOverride` is how touch gets exercised.**
/// `Env.isTouchPrimary` — which gates every `InSizes.touchTarget` in the app —
/// reads `defaultTargetPlatform`, and on web that derives from the *browser's
/// OS*. Headless Chrome on a Mac reports `macOS`, so a 390 px capture would
/// render the narrow *layout* with *desktop* hit targets, and the whole class
/// of "touch target too small" bug (invoiceninja/flutter#11) would be
/// invisible. The override is checked on every call and is unconditional on
/// web (`_platform_web.dart` reads it straight off the getter, no `assert`
/// wrapper), so it works here. `Env.isMobile` / `Env.isDesktop` short-circuit
/// on `kIsWeb`, so native-only paths stay correctly off.
///
/// **2. Sizes must be measured in Dart, never off the PNG.** `setSurfaceSize`
/// makes the binding letterbox-and-scale the logical surface into the physical
/// window, and `takeScreenshot` on web is a *browser viewport* capture. So the
/// image is scaled by `window / surface` — a 32 px control in a 1600x1000
/// window at a 360-wide surface measures 40 px in the file and reads as "fine".
/// Every metric assertion here goes through `tester.getSize`.
///
/// **3. Nothing here throws.** The point of the sweep is to find layout bugs,
/// and in a debug build a `RenderFlex overflowed` becomes a test failure — so
/// the first bug found would abort the run and cost every later capture. Each
/// stop drains `tester.takeException()` into [_findings] and continues; the
/// report is printed at the end.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import 'package:admin/app/env.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/services/connectivity_watcher.dart';
import 'package:admin/data/services/token_storage.dart';
import 'package:admin/main.dart';

import 'support/in_memory_executor.dart';

// --- Sweep parameters -------------------------------------------------------

/// `WIDTHxHEIGHT` in logical pixels. Keep equal to the runner's
/// `--browser-dimension` so the capture isn't scaled (see the class doc).
const String kViewport = String.fromEnvironment(
  'UX_VIEWPORT',
  defaultValue: '1440x900',
);

/// `''` (real desktop pointer), `android`, or `ios`.
const String kPlatform = String.fromEnvironment('UX_PLATFORM');

/// `light` or `dark`.
const String kTheme = String.fromEnvironment('UX_THEME', defaultValue: 'light');

/// Text scale x100 — `int.fromEnvironment` can't carry a double. `140` is the
/// app's own maximum (`kTextScaleExtraLarge`), and `composeTextScaler`
/// multiplies it by the OS scaler, so real users exceed it.
const int kTextScaleX100 = int.fromEnvironment(
  'UX_TEXT_SCALE_X100',
  defaultValue: 100,
);

const String kLocale = String.fromEnvironment('UX_LOCALE', defaultValue: 'en');

/// Prefix for every PNG in this run, so passes don't overwrite each other.
String get _tag {
  final platform = kPlatform.isEmpty ? 'pointer' : kPlatform;
  return '${kViewport}_${platform}_${kTheme}_${kTextScaleX100}_$kLocale';
}

Size get _surface {
  final parts = kViewport.split('x');
  return Size(double.parse(parts[0]), double.parse(parts[1]));
}

bool get _isTouchPass => kPlatform.isNotEmpty;

// --- Findings ---------------------------------------------------------------

final List<String> _findings = <String>[];

void _note(String stop, String message) {
  _findings.add('[$stop] $message');
  // ignore: avoid_print
  print('  !! [$stop] $message');
}

// --- Helpers ----------------------------------------------------------------

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
}

/// Fixed pumps rather than `pumpAndSettle` — the app runs indefinite
/// animations (sync spinners, the running-task ticker) that never settle.
Future<void> _settle(WidgetTester tester, {int frames = 8}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

/// Drain every pending framework exception into [_findings]. Overflow errors
/// arrive here; leaving them undrained would fail the run at the first bug.
void _drain(WidgetTester tester, String stop) {
  for (
    Object? e = tester.takeException();
    e != null;
    e = tester.takeException()
  ) {
    final first = e.toString().split('\n').first;
    _note(stop, 'EXCEPTION: $first');
  }
}

/// Audits hit-target sizes for the touch passes. Only meaningful under
/// [_isTouchPass] — on a pointer pass small controls are correct by design.
void _auditTouchTargets(WidgetTester tester, String stop) {
  if (!_isTouchPass) return;
  final seen = <String>{};
  for (final type in [IconButton, InkWell, GestureDetector]) {
    for (final element in find.byType(type).evaluate()) {
      final ro = element.renderObject;
      if (ro is! RenderBox || !ro.hasSize) continue;
      final size = ro.size;
      // Zero-size boxes are decorative wrappers, not targets.
      if (size.isEmpty) continue;
      if (size.width >= InSizes.touchTarget &&
          size.height >= InSizes.touchTarget) {
        continue;
      }
      final key =
          '$type ${size.width.toStringAsFixed(0)}x'
          '${size.height.toStringAsFixed(0)}';
      if (seen.add(key)) {
        _note(stop, 'touch target $key (floor is ${InSizes.touchTarget})');
      }
    }
  }
}

/// One stop on the tour: navigate, settle, capture, audit.
Future<void> _stop(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  String name, {
  String? route,
  Finder? waitFor,
  Future<void> Function()? action,
}) async {
  // ignore: avoid_print
  print('== $name');
  try {
    if (route != null) _router(tester).go(route);
    if (action != null) await action();
    if (waitFor != null) await _pumpUntil(tester, waitFor);
    await _settle(tester);
    _drain(tester, name);
    _auditTouchTargets(tester, name);
    await binding.takeScreenshot('${_tag}__$name');
  } catch (e) {
    _note(name, 'STOP FAILED: ${e.toString().split('\n').first}');
    _drain(tester, name);
  }
}

// --- The sweep --------------------------------------------------------------

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ux review sweep', (tester) async {
    if (Env.demoApiToken.isEmpty) {
      markTestSkipped('ux review: run tools/capture_ux_review.sh');
      return;
    }

    // Reset inside the body, NOT via `addTearDown`: the binding runs
    // `debugAssertAllFoundationVarsUnset` between the test body and its
    // tear-downs, so a tear-down reset is too late and fails the run after
    // every capture has already succeeded.
    if (_isTouchPass) {
      debugDefaultTargetPlatformOverride = kPlatform == 'ios'
          ? TargetPlatform.iOS
          : TargetPlatform.android;
    }
    try {
      await _sweep(tester, binding);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

Future<void> _sweep(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
) async {
  await tester.binding.setSurfaceSize(_surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final db = AppDatabase(await openInMemoryExecutor());
  addTearDown(db.close);
  final httpClient = http.Client();
  addTearDown(httpClient.close);

  final services = Services.build(
    db: db,
    tokenStorage: InMemoryTokenStorage(),
    httpClient: httpClient,
    connectivityWatcher: ConnectivityWatcher.fixed(online: true),
  );

  await services.auth.loginWithToken(
    baseUrl: Env.demoApiUrl,
    isHosted: false,
    token: Env.demoApiToken,
  );

  // Theme / scale / locale are plain notifiers that `MaterialApp`'s builder
  // binds to, so they take effect without a remount.
  // Always pin the mode. The default is `ThemeMode.system` and headless Chrome
  // reports dark — so an unset "light" pass silently captured the dark theme,
  // making the entire light half of the matrix a duplicate of the dark half.
  await services.theme.setThemeMode(
    kTheme == 'dark' ? ThemeMode.dark : ThemeMode.light,
  );
  if (kTextScaleX100 != 100) {
    await services.textScale.set(kTextScaleX100 / 100);
  }
  if (kLocale != 'en') await services.locale.set(Locale(kLocale));

  await tester.pumpWidget(
    InvoiceNinjaApp(
      services: services,
      dbWasReset: false,
      initialLocation: '/dashboard',
    ),
  );
  await _pumpUntil(tester, find.byType(Navigator));
  await _settle(tester, frames: 12);

  // ignore: avoid_print
  print('=== UX sweep $_tag ===');

  await _stop(tester, binding, 'dashboard');
  await _stop(tester, binding, 'clients-list', route: '/clients');
  await _stop(tester, binding, 'invoices-list', route: '/invoices');
  await _stop(tester, binding, 'invoice-new', route: '/invoices/new');
  await _stop(tester, binding, 'products-list', route: '/products');
  await _stop(tester, binding, 'tasks-list', route: '/tasks');
  await _stop(tester, binding, 'tasks-kanban', route: '/tasks?view=kanban');
  await _stop(tester, binding, 'tasks-calendar', route: '/tasks?view=calendar');
  await _stop(tester, binding, 'tasks-weekly', route: '/tasks?view=weekly');
  await _stop(tester, binding, 'payments-list', route: '/payments');
  await _stop(tester, binding, 'expenses-list', route: '/expenses');
  await _stop(tester, binding, 'projects-list', route: '/projects');
  await _stop(tester, binding, 'reports', route: '/reports');
  await _stop(tester, binding, 'settings', route: '/settings');
  await _stop(
    tester,
    binding,
    'settings-company',
    route: '/settings/company_details',
  );
  await _stop(
    tester,
    binding,
    'settings-device',
    route: '/settings/device_settings',
  );
  await _stop(tester, binding, 'outbox', route: '/sync/outbox');

  // ignore: avoid_print
  print('\n=== findings for $_tag: ${_findings.length} ===');
  for (final f in _findings) {
    // ignore: avoid_print
    print(f);
  }
  // Deliberately no `expect` — a sweep that fails stops capturing.
}
