/// Live demo coverage — navigation, lists & detail.
///
/// Real page-by-page list loads, a client detail open, the full primary-
/// entity list tour, and the reports screen — all against
/// `https://demo.invoiceninja.com`. Shared infra is in
/// `../support/demo_harness.dart`.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/ui/features/clients/views/client_detail_screen.dart';
import 'package:admin/ui/features/clients/views/client_list_screen.dart';
import 'package:admin/ui/features/clients/widgets/client_list_tile.dart';
import 'package:admin/ui/features/credits/views/credit_detail_screen.dart';
import 'package:admin/ui/features/credits/views/credit_list_screen.dart';
import 'package:admin/ui/features/credits/widgets/credit_list_tile.dart';
import 'package:admin/ui/features/dashboard/views/dashboard_screen.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_figures.dart';
import 'package:admin/ui/features/expenses/views/expense_detail_screen.dart';
import 'package:admin/ui/features/expenses/views/expense_list_screen.dart';
import 'package:admin/ui/features/expenses/widgets/expense_list_tile.dart';
import 'package:admin/ui/features/invoices/views/invoice_detail_screen.dart';
import 'package:admin/ui/features/invoices/views/invoice_list_screen.dart';
import 'package:admin/ui/features/invoices/widgets/invoice_list_tile.dart';
import 'package:admin/ui/features/payments/views/payment_detail_screen.dart';
import 'package:admin/ui/features/payments/views/payment_list_screen.dart';
import 'package:admin/ui/features/payments/widgets/payment_list_tile.dart';
import 'package:admin/ui/features/products/views/product_detail_screen.dart';
import 'package:admin/ui/features/products/views/product_list_screen.dart';
import 'package:admin/ui/features/products/widgets/product_list_tile.dart';
import 'package:admin/ui/features/projects/views/project_detail_screen.dart';
import 'package:admin/ui/features/projects/views/project_list_screen.dart';
import 'package:admin/ui/features/projects/widgets/project_list_tile.dart';
import 'package:admin/ui/features/purchase_orders/views/purchase_order_detail_screen.dart';
import 'package:admin/ui/features/purchase_orders/views/purchase_order_list_screen.dart';
import 'package:admin/ui/features/purchase_orders/widgets/purchase_order_list_tile.dart';
import 'package:admin/ui/features/quotes/views/quote_detail_screen.dart';
import 'package:admin/ui/features/quotes/views/quote_list_screen.dart';
import 'package:admin/ui/features/quotes/widgets/quote_list_tile.dart';
import 'package:admin/ui/features/recurring_expenses/views/recurring_expense_detail_screen.dart';
import 'package:admin/ui/features/recurring_expenses/views/recurring_expense_list_screen.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/recurring_expense_list_tile.dart';
import 'package:admin/ui/features/recurring_invoices/views/recurring_invoice_detail_screen.dart';
import 'package:admin/ui/features/recurring_invoices/views/recurring_invoice_list_screen.dart';
import 'package:admin/ui/features/recurring_invoices/widgets/recurring_invoice_list_tile.dart';
import 'package:admin/ui/features/reports/views/reports_screen.dart';
import 'package:admin/ui/features/tasks/views/task_detail_screen.dart';
import 'package:admin/ui/features/tasks/views/task_list_screen.dart';
import 'package:admin/ui/features/tasks/widgets/task_list_tile.dart';
import 'package:admin/ui/features/transactions/views/transaction_list_screen.dart';
import 'package:admin/ui/features/vendors/views/vendor_detail_screen.dart';
import 'package:admin/ui/features/vendors/views/vendor_list_screen.dart';
import 'package:admin/ui/features/vendors/widgets/vendor_list_tile.dart';

import '../support/demo_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerDemoReachabilityProbe();

  testWidgets('clients list loads real rows from the demo server', (
    tester,
  ) async {
    if (skipIfUnreachable()) return;

    await bootLoggedIn(tester, initialLocation: '/clients');
    await pumpUntilFound(tester, find.byType(ClientListScreen));
    expect(find.byType(ClientListScreen), findsOneWidget);

    // The demo dataset is always seeded with clients — page one should
    // produce at least one real tile after the live fetch resolves.
    await pumpUntilFound(tester, find.byType(ClientListTile));
    expect(
      find.byType(ClientListTile),
      findsAtLeastNWidgets(1),
      reason: 'demo server should return at least one client',
    );
    expect(find.byType(ErrorView), findsNothing);
  });

  testWidgets('opening a client shows the detail screen with live data', (
    tester,
  ) async {
    if (skipIfUnreachable()) return;

    await bootLoggedIn(tester, initialLocation: '/clients');
    await pumpUntilFound(tester, find.byType(ClientListTile));
    expect(find.byType(ClientListTile), findsAtLeastNWidgets(1));

    await tester.tap(find.byType(ClientListTile).first);
    await pumpUntilFound(tester, find.byType(ClientDetailScreen));
    expect(find.byType(ClientDetailScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ClientDetailScreen),
        matching: find.byType(ErrorView),
      ),
      findsNothing,
    );
  });

  testWidgets('every primary entity list loads from the demo server', (
    tester,
  ) async {
    if (skipIfUnreachable()) return;

    // One login, then tour each list through the real router. Each route
    // triggers a live page-by-page fetch; we assert the screen mounted and
    // no ErrorView surfaced.
    await bootLoggedIn(tester, initialLocation: '/clients');
    await pumpUntilFound(tester, find.byType(ClientListScreen));

    final tour = <({String route, Type screen})>[
      (route: '/products', screen: ProductListScreen),
      (route: '/invoices', screen: InvoiceListScreen),
      (route: '/quotes', screen: QuoteListScreen),
      (route: '/payments', screen: PaymentListScreen),
      (route: '/expenses', screen: ExpenseListScreen),
      (route: '/tasks', screen: TaskListScreen),
      (route: '/projects', screen: ProjectListScreen),
      (route: '/vendors', screen: VendorListScreen),
      (route: '/recurring_invoices', screen: RecurringInvoiceListScreen),
      (route: '/credits', screen: CreditListScreen),
      (route: '/purchase_orders', screen: PurchaseOrderListScreen),
      (route: '/recurring_expenses', screen: RecurringExpenseListScreen),
      (route: '/transactions', screen: TransactionListScreen),
    ];
    for (final stop in tour) {
      await goAndExpect(tester, route: stop.route, screenType: stop.screen);
    }
  });

  testWidgets('reports screen mounts post-login', (tester) async {
    if (skipIfUnreachable()) return;

    await bootLoggedIn(tester, initialLocation: '/reports');
    await pumpUntilFound(tester, find.byType(ReportsScreen));
    expect(find.byType(ReportsScreen), findsOneWidget);
  });

  testWidgets('primary entity detail screens load from the demo server', (
    tester,
  ) async {
    if (skipIfUnreachable()) return;

    // One login, then open the first row of each list and confirm the
    // detail screen renders live data without an ErrorView. Single app
    // launch — no extra macOS relaunch.
    await bootLoggedIn(tester, initialLocation: '/clients');
    await pumpUntilFound(tester, find.byType(ClientListScreen));

    final cases = <({String route, Type tile, Type detail})>[
      (route: '/products', tile: ProductListTile, detail: ProductDetailScreen),
      (route: '/invoices', tile: InvoiceListTile, detail: InvoiceDetailScreen),
      (route: '/quotes', tile: QuoteListTile, detail: QuoteDetailScreen),
      (route: '/payments', tile: PaymentListTile, detail: PaymentDetailScreen),
      (route: '/expenses', tile: ExpenseListTile, detail: ExpenseDetailScreen),
      (route: '/tasks', tile: TaskListTile, detail: TaskDetailScreen),
      (route: '/projects', tile: ProjectListTile, detail: ProjectDetailScreen),
      (route: '/vendors', tile: VendorListTile, detail: VendorDetailScreen),
    ];
    for (final c in cases) {
      await openFirstRowDetail(
        tester,
        listRoute: c.route,
        listTileType: c.tile,
        detailType: c.detail,
      );
    }

    // Secondary entities: the shared demo dataset does NOT reliably seed
    // these the way it does the 8 primary lists (e.g. /recurring_expenses
    // can be empty). So assert the list screen mounts with no ErrorView
    // (the 🟡 coverage), and only drill into detail when a row actually
    // exists — an empty live list is a valid state here, not a failure.
    final secondary = <({String route, Type list, Type tile, Type detail})>[
      (
        route: '/recurring_invoices',
        list: RecurringInvoiceListScreen,
        tile: RecurringInvoiceListTile,
        detail: RecurringInvoiceDetailScreen,
      ),
      (
        route: '/credits',
        list: CreditListScreen,
        tile: CreditListTile,
        detail: CreditDetailScreen,
      ),
      (
        route: '/purchase_orders',
        list: PurchaseOrderListScreen,
        tile: PurchaseOrderListTile,
        detail: PurchaseOrderDetailScreen,
      ),
      (
        route: '/recurring_expenses',
        list: RecurringExpenseListScreen,
        tile: RecurringExpenseListTile,
        detail: RecurringExpenseDetailScreen,
      ),
    ];
    for (final c in secondary) {
      await goAndExpect(tester, route: c.route, screenType: c.list);
      // Bounded wait for a row (15s) — long enough for a live page-one
      // fetch, short enough not to burn 40s × N when the list is empty.
      final tile = find.byType(c.tile);
      await pumpUntilFound(tester, tile, timeout: const Duration(seconds: 15));
      if (tile.evaluate().isEmpty) continue; // empty list — list-only cover
      await tester.tap(tile.first);
      await pumpUntilFound(tester, find.byType(c.detail));
      expect(
        find.byType(c.detail),
        findsOneWidget,
        reason: 'expected ${c.detail} after tapping a row on ${c.route}',
      );
      expect(
        find.descendant(
          of: find.byType(c.detail),
          matching: find.byType(ErrorView),
        ),
        findsNothing,
        reason: '${c.detail} showed an ErrorView with live data',
      );
    }
  });

  testWidgets('clients list search filters rows against live data', (
    tester,
  ) async {
    if (skipIfUnreachable()) return;

    await bootLoggedIn(tester, initialLocation: '/clients');
    await pumpUntilFound(tester, find.byType(ClientListTile));
    final before = find.byType(ClientListTile).evaluate().length;
    expect(before, greaterThan(0));

    // The list scaffold's token search is the only TextField on a plain
    // list screen. Typing a query the dataset is very unlikely to match
    // broadly must narrow (or empty) the list — never grow it — and must
    // not crash the screen.
    final searchField = find
        .descendant(
          of: find.byType(ClientListScreen),
          matching: find.byType(TextField),
        )
        .first;
    await tester.enterText(searchField, 'zqxjv-no-such-client');
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.byType(ClientListScreen), findsOneWidget);
    expect(find.byType(ErrorView), findsNothing);
    expect(
      find.byType(ClientListTile).evaluate().length,
      lessThanOrEqualTo(before),
      reason: 'search must filter (never grow) the live list',
    );
  });

  testWidgets('products list search filters rows against live data', (
    tester,
  ) async {
    if (skipIfUnreachable()) return;

    // Same shape as the clients-search test, on a second entity — broadens
    // the "token search narrows (never grows) the live list" assertion past
    // a single entity stack.
    await bootLoggedIn(tester, initialLocation: '/products');
    await pumpUntilFound(tester, find.byType(ProductListTile));
    final before = find.byType(ProductListTile).evaluate().length;
    expect(before, greaterThan(0));

    final searchField = find
        .descendant(
          of: find.byType(ProductListScreen),
          matching: find.byType(TextField),
        )
        .first;
    await tester.enterText(searchField, 'zqxjv-no-such-product');
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.byType(ProductListScreen), findsOneWidget);
    expect(find.byType(ErrorView), findsNothing);
    expect(
      find.byType(ProductListTile).evaluate().length,
      lessThanOrEqualTo(before),
      reason: 'search must filter (never grow) the live list',
    );
  });

  testWidgets('clients multi-select exposes the bulk-action surface', (
    tester,
  ) async {
    if (skipIfUnreachable()) return;

    // Selection-surface only: long-press a real row to enter multi-select,
    // assert the selection AppBar's bulk Archive action renders against live
    // data with no ErrorView, then clear the selection. Deliberately does
    // NOT fire the bulk mutation here — archiving a shared real demo client
    // is unsafe; the write-bearing bulk archive/restore round-trip runs
    // against a throwaway ZZ-CLAUDE-IT record in crud_test.dart instead.
    await bootLoggedIn(tester, initialLocation: '/clients');
    await pumpUntilFound(tester, find.byType(ClientListTile));
    expect(find.byType(ClientListTile), findsAtLeastNWidgets(1));

    await tester.longPress(find.byType(ClientListTile).first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    // On the wide surface the bulk actions render as labelled OutlinedButtons
    // (entity_list_app_bar.dart → EntityDetailActionsRow). Archive carries
    // Icons.archive_outlined; its presence proves selection mode + the bulk
    // cluster mounted.
    final archive = find.widgetWithIcon(OutlinedButton, Icons.archive_outlined);
    await pumpUntilFound(tester, archive, timeout: const Duration(seconds: 10));
    expect(
      archive,
      findsAtLeastNWidgets(1),
      reason: 'multi-select must expose the bulk Archive action',
    );
    expect(find.byType(ErrorView), findsNothing);

    // Leave selection mode so teardown unmounts cleanly.
    final close = find.widgetWithIcon(IconButton, Icons.close);
    if (close.evaluate().isNotEmpty) {
      await tester.tap(close.first);
      await tester.pump(const Duration(milliseconds: 300));
    }
  });

  testWidgets('dashboard loads with live data', (tester) async {
    if (skipIfUnreachable()) return;

    await bootLoggedIn(tester, initialLocation: '/dashboard');
    await pumpUntilFound(tester, find.byType(DashboardScreen));
    // The Outstanding card is on screen from the first frame — as a
    // placeholder until the live totals fetch resolves, and as a dash if it
    // fails. So it is the card *showing a value the server returned*, plus no
    // ErrorView, that is the stable "dashboard loaded with live data" signal.
    final loadedFigure = find.byWidgetPredicate(
      (w) => w is OutstandingFigureCard && w.showsLoadedValue,
    );
    await pumpUntilFound(tester, loadedFigure);
    expect(loadedFigure, findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DashboardScreen),
        matching: find.byType(ErrorView),
      ),
      findsNothing,
    );
  });

  testWidgets('expenses list fetches a second page on scroll', (tester) async {
    if (skipIfUnreachable()) return;

    final services = await bootLoggedIn(tester, initialLocation: '/expenses');
    await pumpUntilFound(tester, find.byType(ExpenseListTile));
    final companyId = services.auth.session.value!.currentCompanyId;

    // Page-by-page coverage only makes sense if the demo actually has more
    // than one page (50) of expenses. Ask the server for the real total
    // first; skip cleanly if the shared dataset is ≤ one page (vs. failing
    // on demo-data variance).
    final probe = await http
        .get(
          Uri.parse('${apiBase(services)}/api/v1/expenses?per_page=1'),
          headers: apiHeaders(services),
        )
        .timeout(const Duration(seconds: 20));
    final total = probe.statusCode == 200
        ? ((jsonDecode(probe.body) as Map<String, dynamic>)['meta']
                      as Map<String, dynamic>?)?['pagination']?['total']
                  as int? ??
              0
        : 0;
    if (total <= 50) {
      markTestSkipped(
        'demo has $total expenses (≤1 page) — cannot exercise '
        'pagination',
      );
      return;
    }

    // The list's own vertical scrollable (NOT the shell sidebar's). Scroll
    // past the 600px load-more threshold so page 2 is fetched from the live
    // server and persisted to Drift; assert the persisted count > 50 (page
    // size) — built-tile counting is unreliable (lazy ListView.builder).
    final listScroll = find
        .descendant(
          of: find.byType(ExpenseListScreen),
          matching: find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          ),
        )
        .first;
    await scrollToLoadMore(tester, scrollable: listScroll, drags: 16);
    final count = await services.db.expenseDao
        .watchCount(companyId: companyId)
        .first;
    expect(
      count,
      greaterThan(50),
      reason: 'a second page should have been fetched from the live server',
    );
  });

  testWidgets('running the clients report renders results', (tester) async {
    if (skipIfUnreachable()) return;

    await bootLoggedIn(tester, initialLocation: '/reports');
    await pumpUntilFound(tester, find.byType(ReportsScreen));
    // Reports opens on the preselected Clients report ("This year") with an
    // initial EmptyState until a run is triggered.
    await pumpUntilFound(
      tester,
      find.descendant(
        of: find.byType(ReportsScreen),
        matching: find.byType(EmptyState),
      ),
    );

    // The Run action is the FilledButton carrying a play arrow (the
    // in-flight state swaps it for a spinner + Cancel). The wide layout
    // renders it in more than one on-screen slot — all bound to the same
    // `vm.runReport` — so accept ≥1 and tap the first.
    final runBtn = find
        .widgetWithIcon(FilledButton, Icons.play_arrow)
        .hitTestable();
    await pumpUntilFound(tester, runBtn, timeout: const Duration(seconds: 10));
    expect(
      runBtn,
      findsAtLeastNWidgets(1),
      reason: 'reports screen must expose Run',
    );
    await tester.tap(runBtn.first);

    // Queued POST + poll: wait (generously) for the initial EmptyState to
    // give way to results, and assert the run did not error.
    await pumpUntilGone(
      tester,
      find.descendant(
        of: find.byType(ReportsScreen),
        matching: find.byType(EmptyState),
      ),
      timeout: const Duration(seconds: 90),
    );
    expect(
      find.descendant(
        of: find.byType(ReportsScreen),
        matching: find.byType(EmptyState),
      ),
      findsNothing,
      reason: 'the report run should leave the initial empty state',
    );
    expect(
      find.descendant(
        of: find.byType(ReportsScreen),
        matching: find.byType(ErrorView),
      ),
      findsNothing,
      reason: 'the report run should not surface an ErrorView',
    );
  });
}
