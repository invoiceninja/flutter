/// Marketing screenshot capture for the README.
///
/// Boots the real `InvoiceNinjaApp` **on web** against the demo server using the
/// same baked-token bootstrap the public web demo uses (`AuthRepository`
/// `loginWithToken`, see `main.dart`), then writes one PNG per marketing screen
/// via `binding.takeScreenshot`. The bytes are persisted by the
/// `onScreenshot` handler in `test_driver/screenshots_driver.dart`.
///
/// **Run only via `tools/capture_screenshots.sh`.** That script passes
/// `--dart-define=IN_DEMO_API_TOKEN=…` and the screenshot-writing driver.
/// Without the token define this test self-skips, so it never perturbs
/// `flutter test`, `tools/run_integration_local.sh`, or CI (where
/// `binding.takeScreenshot` would have no driver to receive the bytes).
///
/// Capture runs on web because the `integration_test` plugin only implements
/// `takeScreenshot` for Android/iOS/web — there is no macOS plugin, so
/// `-d macos` would throw `MissingPluginException`.
///
/// Read-only: it navigates and captures. It never writes to the demo account.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import 'package:admin/app/env.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/services/connectivity_watcher.dart';
import 'package:admin/data/services/token_storage.dart';
import 'package:admin/main.dart';
import 'package:admin/ui/features/dashboard/views/dashboard_screen.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_figures.dart';
import 'package:admin/ui/features/invoices/views/invoice_detail_screen.dart';
import 'package:admin/ui/features/invoices/views/invoice_edit_screen.dart';
import 'package:admin/ui/features/invoices/views/invoice_list_screen.dart';
import 'package:admin/ui/features/invoices/widgets/invoice_list_tile.dart';

import 'support/in_memory_executor.dart';

/// Pump in 200 ms bursts until [finder] matches — generous timeout because the
/// tour waits on live demo-server fetches (KPIs, list pages).
Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 40),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
}

/// Let async content (charts, avatars, logos) paint before a capture.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// The running app's go_router, resolved via the always-present `Navigator`.
GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture marketing screenshots', (tester) async {
    if (Env.demoApiToken.isEmpty) {
      markTestSkipped(
        'screenshots: set IN_DEMO_API_TOKEN — run tools/capture_screenshots.sh',
      );
      return;
    }

    // Desktop-wide layout. The captured viewport is sized by the driver's
    // `--browser-dimension`; keep this equal to it so the image isn't clipped.
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
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

    // Same demo-token bootstrap as `main.dart` / the public web demo.
    await services.auth.loginWithToken(
      baseUrl: Env.demoApiUrl,
      isHosted: false,
      token: Env.demoApiToken,
    );

    await tester.pumpWidget(
      InvoiceNinjaApp(
        services: services,
        dbWasReset: false,
        initialLocation: '/dashboard',
      ),
    );

    // 1. Dashboard — wait for a figure the server returned. The Outstanding
    // card is on screen from the first frame (as a placeholder), so it is its
    // loaded state, not its presence, that says the live fetch resolved.
    await _pumpUntilFound(tester, find.byType(DashboardScreen));
    await _pumpUntilFound(
      tester,
      find.byWidgetPredicate(
        (w) => w is OutstandingFigureCard && w.showsLoadedValue,
      ),
    );
    await _settle(tester);
    await binding.takeScreenshot('01-dashboard');

    // 2. Invoice list — wait for a real row from the live page-one fetch.
    _router(tester).go('/invoices');
    await _pumpUntilFound(tester, find.byType(InvoiceListScreen));
    await _pumpUntilFound(tester, find.byType(InvoiceListTile));
    await _settle(tester);
    await binding.takeScreenshot('02-invoice-list');

    // 3. Invoice detail — open the first row.
    await tester.tap(find.byType(InvoiceListTile).first);
    await _pumpUntilFound(tester, find.byType(InvoiceDetailScreen));
    await _settle(tester);
    await binding.takeScreenshot('03-invoice-view');

    // 4. Invoice editor — the `/new` create route is never lock-gated (unlike
    // editing a sent/paid invoice, which can bounce to a "locked" dialog).
    _router(tester).go('/invoices/new');
    await _pumpUntilFound(tester, find.byType(InvoiceEditScreen));
    await _settle(tester);
    await binding.takeScreenshot('04-invoice-edit');
  });
}
