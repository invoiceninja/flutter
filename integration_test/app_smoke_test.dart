/// Boot, redirect, and login smoke tests.
///
/// Each scenario exercises the real `InvoiceNinjaApp` with an in-memory
/// database + token storage. A `MockClient` is supplied throughout so the
/// app's background refresh never reaches the real network.
///
/// **Do not run these locally.** They take over the foreground app and
/// interrupt the user's session — see CLAUDE.md "Integration tests". They
/// run in GitHub CI.
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/services/biometric_service.dart';
import 'package:admin/data/services/connectivity_watcher.dart';
import 'package:admin/data/services/token_storage.dart';
import 'package:admin/main.dart';
import 'package:admin/ui/features/auth/views/lock_screen.dart';
import 'package:admin/ui/features/auth/views/login_screen.dart';
import 'package:admin/ui/features/auth/views/setup_wizard_screen.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/features/dashboard/views/dashboard_screen.dart';
import 'package:admin/ui/features/reports/views/reports_screen.dart';

// Entity list screens — exercised by the per-route mount tests below.
import 'package:admin/ui/features/bank_accounts/views/bank_account_list_screen.dart';
import 'package:admin/ui/features/clients/views/client_list_screen.dart';
import 'package:admin/ui/features/credits/views/credit_list_screen.dart';
import 'package:admin/ui/features/expense_categories/views/expense_category_list_screen.dart';
import 'package:admin/ui/features/expenses/views/expense_list_screen.dart';
import 'package:admin/ui/features/gateways/views/company_gateway_list_screen.dart';
import 'package:admin/ui/features/invoices/views/invoice_list_screen.dart';
import 'package:admin/ui/features/payment_links/views/payment_link_list_screen.dart';
import 'package:admin/ui/features/payments/views/payment_list_screen.dart';
import 'package:admin/ui/features/products/views/product_list_screen.dart';
import 'package:admin/ui/features/projects/views/project_list_screen.dart';
import 'package:admin/ui/features/purchase_orders/views/purchase_order_list_screen.dart';
import 'package:admin/ui/features/quotes/views/quote_list_screen.dart';
import 'package:admin/ui/features/recurring_expenses/views/recurring_expense_list_screen.dart';
import 'package:admin/ui/features/recurring_invoices/views/recurring_invoice_list_screen.dart';
import 'package:admin/ui/features/tasks/views/task_list_screen.dart';
import 'package:admin/ui/features/tokens/views/token_list_screen.dart';
import 'package:admin/ui/features/transactions/views/transaction_list_screen.dart';
import 'package:admin/ui/features/transaction_rules/views/transaction_rule_list_screen.dart';
import 'package:admin/ui/features/vendors/views/vendor_list_screen.dart';
import 'package:admin/ui/features/webhooks/views/webhook_list_screen.dart';

// Entity edit (create) screens.
import 'package:admin/ui/features/clients/views/client_edit_screen.dart';
import 'package:admin/ui/features/expenses/views/expense_edit_screen.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/ui/features/invoices/views/invoice_detail_screen.dart';
import 'package:admin/ui/features/invoices/views/invoice_edit_screen.dart';
import 'package:admin/ui/features/products/views/product_edit_screen.dart';
import 'package:admin/ui/features/projects/views/project_edit_screen.dart';
import 'package:admin/ui/features/quotes/views/quote_edit_screen.dart';
import 'package:admin/ui/features/tasks/views/task_edit_screen.dart';
import 'package:admin/ui/features/vendors/views/vendor_edit_screen.dart';

// Settings entry-point screens. Tabbed sub-screens are exercised by
// pumping the parent route — the shell pulls the right tab in.
import 'package:admin/ui/features/settings/views/basic/company_details/company_details_shell.dart';
import 'package:admin/ui/features/settings/views/basic/device_settings_screen.dart';
import 'package:admin/ui/features/settings/views/basic/localization/localization_shell.dart';
import 'package:admin/ui/features/settings/views/basic/online_payments/online_payments_shell.dart';
import 'package:admin/ui/features/settings/views/basic/user_details/user_details_shell.dart';
import 'package:admin/ui/features/settings/views/basic/workflow_settings/workflow_settings_shell.dart';

// Shell.
import 'package:admin/ui/features/shell/widgets/in_sidebar.dart';
import 'package:admin/ui/features/shell/widgets/sidebar_nav_item.dart';
import 'package:admin/ui/features/sync/views/outbox_screen.dart';

import 'support/in_memory_executor.dart';

/// Always-cancels biometric stand-in so the integration-test driver never
/// hangs waiting on a real platform prompt. The lock screen kicks off
/// `unlock()` from `addPostFrameCallback`, so we just need the call to
/// resolve quickly with `false`.
class _AlwaysCancelBiometric implements BiometricService {
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> authenticate({required String reason}) async => false;
}

/// Suppresses every outbound request with a 500. Used by scenarios that
/// don't care about the network — `AuthRepository.restore()` fires a
/// best-effort `_refreshSessionQuietly()` after restore, and we don't want
/// it to reach the real internet from CI.
///
/// GET requests get an empty-list JSON body so list screens that fire
/// their initial fetch on mount don't raise an uncaught
/// `ServerException` (which the binding catches as a test failure).
http.Client _silentNetwork() => MockClient((req) async {
  if (req.method == 'GET') {
    return http.Response(
      '{"data": []}',
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
  return http.Response('', 500);
});

/// `pumpAndSettle` can return before [Localizations.load] resolves the
/// async asset bundle — the widget tree then shows the `SizedBox`
/// placeholder rather than the requested screen. Pump in short bursts
/// until [finder] matches at least one widget or [timeout] elapses, which
/// gives the localization Future a chance to complete on the platform
/// thread before assertions run.
Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
}

/// All entity modules switched on — mirrors the real `enabled_modules` mask
/// the server sends (`/login` returns e.g. 32767). Seeded companies must set
/// this: the column defaults to `0` ("every module off"), which makes every
/// module-gated route (invoices, quotes, expenses, …) redirect to `/dashboard`
/// (see `disabledEntityRoots` in router.dart) so its list screen never mounts
/// and the route-mount tests find 0 widgets.
const int _kAllModulesEnabled = 32767;

/// Seed Drift + token storage so `AuthRepository.restore()` finds a complete
/// session. `permissions` is a comma-separated string; with `isAdmin: false`
/// and `isOwner: false` it's the only thing that gates `view_dashboard`.
Future<({AppDatabase db, InMemoryTokenStorage storage})> _seedSession({
  required String permissions,
  bool isAdmin = false,
  bool isOwner = false,
  bool biometricEnabled = false,
  String companyName = 'Acme',
  String companySettingsJson = '{}',
}) async {
  final db = AppDatabase(await openInMemoryExecutor());
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  await db.companiesDao.upsertAccount(
    AccountsCompanion.insert(
      id: 'acct_1',
      email: '',
      plan: 'pro',
      numTrialDays: 14,
      updatedAt: nowMs,
    ),
  );
  await db.companiesDao.upsertAll([
    CompaniesCompanion.insert(
      id: 'co_a',
      name: companyName,
      settings: companySettingsJson,
      permissions: permissions,
      accountId: 'acct_1',
      token: 'tok_a',
      isOwner: Value(isOwner),
      isAdmin: Value(isAdmin),
      enabledModules: const Value(_kAllModulesEnabled),
      updatedAt: nowMs,
    ),
  ]);
  final storage = InMemoryTokenStorage();
  await storage.write('invoiceninja.tokens.v1', '{"co_a":"tok_a"}');
  await storage.write('invoiceninja.base_url.v1', 'https://test');
  await storage.write('invoiceninja.is_hosted.v1', 'false');
  await storage.write('invoiceninja.current_company.v1', 'co_a');
  if (biometricEnabled) {
    await storage.write('invoiceninja.biometric_enabled.v1', 'true');
  }
  return (db: db, storage: storage);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots into the login screen with no persisted creds', (
    tester,
  ) async {
    final db = AppDatabase(await openInMemoryExecutor());
    addTearDown(db.close);

    final services = _buildTestServices(
      db: db,
      tokenStorage: InMemoryTokenStorage(),
      httpClient: _silentNetwork(),
    );
    await services.auth.restore();

    await tester.pumpWidget(
      InvoiceNinjaApp(
        services: services,
        dbWasReset: false,
        initialLocation: '/login',
      ),
    );
    await _pumpUntilFound(tester, find.byType(LoginScreen));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('login_submit')), findsOneWidget);
    // Email + password (and the optional OTP) — at least the first two.
    expect(find.byType(TextField), findsAtLeastNWidgets(2));
  });

  testWidgets(
    'app boots into the lock screen when biometric is enabled with a valid session',
    (tester) async {
      final seed = await _seedSession(
        permissions: '',
        isAdmin: true,
        isOwner: true,
        biometricEnabled: true,
      );
      addTearDown(seed.db.close);

      final services = _buildTestServices(
        db: seed.db,
        tokenStorage: seed.storage,
        biometricService: _AlwaysCancelBiometric(),
        httpClient: _silentNetwork(),
      );
      await services.auth.restore();

      // Bypass `/login` initialLocation special-case: the router redirect
      // will move us to `/lock?from=…` because `requiresBiometricUnlock` is
      // true.
      await tester.pumpWidget(
        InvoiceNinjaApp(
          services: services,
          dbWasReset: false,
          initialLocation: '/dashboard',
        ),
      );
      await _pumpUntilFound(tester, find.byType(LockScreen));

      expect(find.byType(LockScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('lock_unlock')), findsOneWidget);
      expect(find.byKey(const ValueKey('lock_sign_out')), findsOneWidget);
    },
  );

  testWidgets('lock screen Sign Out returns to /login', (tester) async {
    final seed = await _seedSession(
      permissions: '',
      isAdmin: true,
      isOwner: true,
      biometricEnabled: true,
    );
    addTearDown(seed.db.close);

    final services = _buildTestServices(
      db: seed.db,
      tokenStorage: seed.storage,
      biometricService: _AlwaysCancelBiometric(),
      httpClient: _silentNetwork(),
    );
    await services.auth.restore();

    await tester.pumpWidget(
      InvoiceNinjaApp(
        services: services,
        dbWasReset: false,
        initialLocation: '/dashboard',
      ),
    );
    await _pumpUntilFound(tester, find.byType(LockScreen));
    expect(find.byType(LockScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('lock_sign_out')));
    await _pumpUntilFound(tester, find.byType(LoginScreen));

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets(
    'authenticated boot lands on /dashboard when company can view dashboard',
    (tester) async {
      final seed = await _seedSession(
        permissions: '',
        isAdmin: true,
        isOwner: true,
      );
      addTearDown(seed.db.close);

      final services = _buildTestServices(
        db: seed.db,
        tokenStorage: seed.storage,
        httpClient: _silentNetwork(),
      );
      await services.auth.restore();

      await tester.pumpWidget(
        InvoiceNinjaApp(
          services: services,
          dbWasReset: false,
          initialLocation: '/dashboard',
        ),
      );
      await _pumpUntilFound(tester, find.byType(DashboardScreen));

      expect(find.byType(DashboardScreen), findsOneWidget);
    },
  );

  testWidgets(
    '/reports lands on ReportsScreen for a company with view_reports',
    (tester) async {
      final seed = await _seedSession(
        permissions: '',
        isAdmin: true,
        isOwner: true,
      );
      addTearDown(seed.db.close);

      final services = _buildTestServices(
        db: seed.db,
        tokenStorage: seed.storage,
        httpClient: _silentNetwork(),
      );
      await services.auth.restore();

      await tester.pumpWidget(
        InvoiceNinjaApp(
          services: services,
          dbWasReset: false,
          initialLocation: '/reports',
        ),
      );
      await _pumpUntilFound(tester, find.byType(ReportsScreen));

      expect(find.byType(ReportsScreen), findsOneWidget);
      // First-paint state should be the initial EmptyState — confirms the
      // screen mounted with content, not just an empty scaffold.
      expect(find.byType(EmptyState), findsOneWidget);
    },
  );

  testWidgets(
    'authenticated boot lands on /clients when view_dashboard is denied',
    (tester) async {
      // Plain user (not admin, not owner) with permissions that don't
      // include `view_dashboard`. defaultPostLoginRoute() should fall
      // through to /clients.
      final seed = await _seedSession(permissions: 'view_client,edit_client');
      addTearDown(seed.db.close);

      final services = _buildTestServices(
        db: seed.db,
        tokenStorage: seed.storage,
        httpClient: _silentNetwork(),
      );
      await services.auth.restore();

      // Start at `/login`; the router's `loggedIn && atLogin` redirect
      // calls `postLoginRoute()`, which falls through to `/clients`
      // because the company lacks `view_dashboard`.
      await tester.pumpWidget(
        InvoiceNinjaApp(
          services: services,
          dbWasReset: false,
          initialLocation: '/login',
        ),
      );
      await _pumpUntilFound(tester, find.byType(ClientListScreen));

      expect(find.byType(ClientListScreen), findsOneWidget);
      expect(find.byType(DashboardScreen), findsNothing);
    },
  );

  testWidgets('authenticated boot lands on /setup when company name is empty', (
    tester,
  ) async {
    // Server-fresh account seed: empty top-level name AND empty
    // settings.name. companyDisplayName() returns "Untitled" so
    // isCompanySetupRequired() trips and the router gates every route
    // behind the wizard.
    final seed = await _seedSession(
      permissions: '',
      isAdmin: true,
      isOwner: true,
      companyName: '',
      companySettingsJson: '{}',
    );
    addTearDown(seed.db.close);

    final services = _buildTestServices(
      db: seed.db,
      tokenStorage: seed.storage,
      httpClient: _silentNetwork(),
    );
    await services.auth.restore();

    // Target the dashboard on purpose — the router redirect should
    // bounce us to /setup before the dashboard ever renders.
    await tester.pumpWidget(
      InvoiceNinjaApp(
        services: services,
        dbWasReset: false,
        initialLocation: '/dashboard',
      ),
    );
    await _pumpUntilFound(tester, find.byType(SetupWizardScreen));

    expect(find.byType(SetupWizardScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('setup_submit')), findsOneWidget);
    expect(find.byKey(const ValueKey('setup_company_name')), findsOneWidget);
    expect(find.byType(DashboardScreen), findsNothing);
  });

  testWidgets(
    'authenticated boot lands on /setup when settings.name is "Untitled Company"',
    (tester) async {
      // The server seeds new companies with `settings.name = "Untitled
      // Company"`. companyDisplayName prefers settings.name over the
      // top-level fields, so the trigger fires even though `name` is set.
      final seed = await _seedSession(
        permissions: '',
        isAdmin: true,
        isOwner: true,
        companyName: 'Untitled Company',
        companySettingsJson: jsonEncode({'name': 'Untitled Company'}),
      );
      addTearDown(seed.db.close);

      final services = _buildTestServices(
        db: seed.db,
        tokenStorage: seed.storage,
        httpClient: _silentNetwork(),
      );
      await services.auth.restore();

      await tester.pumpWidget(
        InvoiceNinjaApp(
          services: services,
          dbWasReset: false,
          initialLocation: '/dashboard',
        ),
      );
      await _pumpUntilFound(tester, find.byType(SetupWizardScreen));

      expect(find.byType(SetupWizardScreen), findsOneWidget);
    },
  );

  testWidgets('login submit + refresh land on /dashboard', (tester) async {
    final db = AppDatabase(await openInMemoryExecutor());
    addTearDown(db.close);

    // Smallest envelope that satisfies AuthRepository._persistAndActivate.
    // Mirrors the shape used by test/data/repositories/auth_repository_test
    // _envelope() — kept inline here so the wire format is visible at the
    // call site.
    final envelope = jsonEncode({
      'data': [
        {
          'is_admin': true,
          'is_owner': true,
          'permissions': '',
          'permissions_updated_at': 0,
          'company': {
            'id': 'co_a',
            'name': 'Acme',
            // All modules on (matches the live server's default of 32767) so
            // the sidebar nav + route smoke assertions for module-gated
            // entities (Invoices, etc.) pass — a 0 mask now gates them.
            'enabled_modules': 32767,
            'settings': <String, dynamic>{},
          },
          'token': {'token': 'tok_a'},
          'account': {
            'id': 'acct_1',
            'default_company_id': 'co_a',
            'plan': 'pro',
            'num_trial_days': 14,
          },
          'settings': <String, dynamic>{},
          'user': {'id': 'u_1'},
        },
      ],
    });

    final mockClient = MockClient((req) async {
      if (req.url.path == '/api/v1/login') {
        return http.Response(
          envelope,
          200,
          headers: const {'content-type': 'application/json'},
        );
      }
      if (req.url.path == '/api/v1/refresh') {
        return http.Response(
          envelope,
          200,
          headers: const {'content-type': 'application/json'},
        );
      }
      return http.Response('not stubbed: ${req.url}', 500);
    });

    final services = _buildTestServices(
      db: db,
      tokenStorage: InMemoryTokenStorage(),
      httpClient: mockClient,
    );
    await services.auth.restore();

    await tester.pumpWidget(
      InvoiceNinjaApp(
        services: services,
        dbWasReset: false,
        initialLocation: '/login',
      ),
    );
    await _pumpUntilFound(tester, find.byType(LoginScreen));
    expect(find.byType(LoginScreen), findsOneWidget);

    // The login form has email + password + OTP fields in order. Enter
    // creds into the first two; the OTP field is optional and stays blank.
    final fields = find.byType(TextField);
    expect(fields, findsAtLeastNWidgets(2));
    await tester.enterText(fields.at(0), 'me@example.com');
    await tester.enterText(fields.at(1), 'hunter2');
    await tester.tap(find.byKey(const ValueKey('login_submit')));
    await _pumpUntilFound(tester, find.byType(DashboardScreen));

    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  // ─────────────────────────────────────────────────────────────────────
  // Per-route mount tests.
  //
  // Every entity list URL, every settings entry point, and every entity
  // create URL goes through the same `_expectRouteMounts` helper. The
  // helper boots the app at the route under an admin/owner session and
  // waits for the expected screen type to appear in the widget tree.
  // ─────────────────────────────────────────────────────────────────────

  group('Entity list routes mount the right screen', () {
    final cases = <({String route, Type screenType})>[
      (route: '/clients', screenType: ClientListScreen),
      (route: '/products', screenType: ProductListScreen),
      (route: '/invoices', screenType: InvoiceListScreen),
      (route: '/recurring_invoices', screenType: RecurringInvoiceListScreen),
      (route: '/quotes', screenType: QuoteListScreen),
      (route: '/credits', screenType: CreditListScreen),
      (route: '/payments', screenType: PaymentListScreen),
      (route: '/expenses', screenType: ExpenseListScreen),
      (route: '/recurring_expenses', screenType: RecurringExpenseListScreen),
      (route: '/tasks', screenType: TaskListScreen),
      (route: '/projects', screenType: ProjectListScreen),
      (route: '/vendors', screenType: VendorListScreen),
      (route: '/purchase_orders', screenType: PurchaseOrderListScreen),
      (route: '/transactions', screenType: TransactionListScreen),
    ];

    for (final c in cases) {
      testWidgets('${c.route} → ${c.screenType}', (tester) async {
        await _expectRouteMounts(
          tester,
          route: c.route,
          screenType: c.screenType,
        );
      });
    }
  });

  group('Settings entity list routes mount the right screen', () {
    final cases = <({String route, Type screenType})>[
      (route: '/settings/bank_accounts', screenType: BankAccountListScreen),
      (
        route: '/settings/bank_accounts/transaction_rules',
        screenType: TransactionRuleListScreen,
      ),
      (
        route: '/settings/company_gateways',
        screenType: CompanyGatewayListScreen,
      ),
      (
        route: '/settings/expense_categories',
        screenType: ExpenseCategoryListScreen,
      ),
      (route: '/settings/payment_links', screenType: PaymentLinkListScreen),
      (
        route: '/settings/account_management/integrations/api_tokens',
        screenType: TokenListScreen,
      ),
      (
        route: '/settings/account_management/integrations/api_webhooks',
        screenType: WebhookListScreen,
      ),
    ];

    for (final c in cases) {
      testWidgets('${c.route} → ${c.screenType}', (tester) async {
        await _expectRouteMounts(
          tester,
          route: c.route,
          screenType: c.screenType,
        );
      });
    }
  });

  group('Settings sub-routes mount the right screen', () {
    final cases = <({String route, Type screenType})>[
      (route: '/settings/company_details', screenType: CompanyDetailsShell),
      (route: '/settings/user_details', screenType: UserDetailsShell),
      (route: '/settings/localization', screenType: LocalizationShell),
      (route: '/settings/online_payments', screenType: OnlinePaymentsShell),
      (route: '/settings/workflow_settings', screenType: WorkflowSettingsShell),
      (route: '/settings/device_settings', screenType: DeviceSettingsScreen),
    ];

    for (final c in cases) {
      testWidgets('${c.route} → ${c.screenType}', (tester) async {
        await _expectRouteMounts(
          tester,
          route: c.route,
          screenType: c.screenType,
        );
      });
    }
  });

  group('Entity create forms mount edit screens', () {
    final cases = <({String route, Type screenType})>[
      (route: '/clients/new', screenType: ClientEditScreen),
      (route: '/products/new', screenType: ProductEditScreen),
      (route: '/invoices/new', screenType: InvoiceEditScreen),
      (route: '/quotes/new', screenType: QuoteEditScreen),
      (route: '/expenses/new', screenType: ExpenseEditScreen),
      (route: '/tasks/new', screenType: TaskEditScreen),
      (route: '/projects/new', screenType: ProjectEditScreen),
      (route: '/vendors/new', screenType: VendorEditScreen),
    ];

    for (final c in cases) {
      testWidgets('${c.route} → ${c.screenType}', (tester) async {
        await _expectRouteMounts(
          tester,
          route: c.route,
          screenType: c.screenType,
        );
      });
    }
  });

  testWidgets('/sync/outbox mounts OutboxScreen', (tester) async {
    await _expectRouteMounts(
      tester,
      route: '/sync/outbox',
      screenType: OutboxScreen,
    );
  });

  // ─────────────────────────────────────────────────────────────────────
  // Shell + sidebar nav: tap a sidebar nav item, verify the branch
  // switched. Spot-checks the sidebar inventory and the search field on
  // the canonical entity list screen.
  // ─────────────────────────────────────────────────────────────────────

  testWidgets('sidebar Products nav → /products', (tester) async {
    await _bootAdminApp(tester, initialLocation: '/clients');
    await _pumpUntilFound(tester, find.byType(ClientListScreen));

    await _tapSidebarItem(tester, 'Products');
    await _pumpUntilFound(tester, find.byType(ProductListScreen));
    expect(find.byType(ProductListScreen), findsOneWidget);
  });

  testWidgets('sidebar Invoices nav → /invoices', (tester) async {
    await _bootAdminApp(tester, initialLocation: '/clients');
    await _pumpUntilFound(tester, find.byType(ClientListScreen));

    await _tapSidebarItem(tester, 'Invoices');
    await _pumpUntilFound(tester, find.byType(InvoiceListScreen));
    expect(find.byType(InvoiceListScreen), findsOneWidget);
  });

  testWidgets('sidebar Clients nav from Dashboard → /clients', (tester) async {
    await _bootAdminApp(tester, initialLocation: '/dashboard');
    await _pumpUntilFound(tester, find.byType(DashboardScreen));

    await _tapSidebarItem(tester, 'Clients');
    await _pumpUntilFound(tester, find.byType(ClientListScreen));
    expect(find.byType(ClientListScreen), findsOneWidget);
  });

  testWidgets('sidebar Dashboard nav → /dashboard', (tester) async {
    await _bootAdminApp(tester, initialLocation: '/clients');
    await _pumpUntilFound(tester, find.byType(ClientListScreen));

    await _tapSidebarItem(tester, 'Dashboard');
    await _pumpUntilFound(tester, find.byType(DashboardScreen));
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('client list screen surfaces a search field', (tester) async {
    await _bootAdminApp(tester, initialLocation: '/clients');
    await _pumpUntilFound(tester, find.byType(ClientListScreen));

    // The list scaffold mounts a token-search field that is itself a
    // `TextField`. Verifying any text field is present is enough to know
    // search wiring loaded — the typed-field unit tests exercise the
    // token-parse semantics.
    expect(
      find.descendant(
        of: find.byType(ClientListScreen),
        matching: find.byType(TextField),
      ),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('the sidebar lists every primary entity', (tester) async {
    await _bootAdminApp(tester, initialLocation: '/clients');
    await _pumpUntilFound(tester, find.byType(ClientListScreen));

    // Spot-check a handful of well-known sidebar labels. The full set is
    // covered by the per-route mount tests above; this assertion just
    // protects against the sidebar collapsing or losing its primary
    // entries entirely.
    for (final label in const [
      'Clients',
      'Invoices',
      'Products',
      'Tasks',
      'Quotes',
    ]) {
      expect(
        find.descendant(
          of: find.byType(InSidebar),
          matching: find.widgetWithText(SidebarNavItem, label),
        ),
        findsOneWidget,
        reason: 'sidebar must surface "$label"',
      );
    }
  });

  // Deep-link regression for the invoice-lock gate. A cold deep link to
  // `/invoices/:id/edit` never goes through InvoiceActions.dispatch, so the
  // gate lives in InvoiceEditScreen's fetchExisting closure. Booting the
  // real app straight at the edit route for a sent invoice under
  // `lock_invoices=when_sent` must: show the reason-specific dialog, and
  // (no back stack on a cold deep link) land on the detail screen.
  //
  // This lives here, not under `test/`, because it needs the real
  // EntityEditScreenScaffold load (a genuine async Drift read) AND boots a
  // GoogleFonts-using screen — the two are incompatible under plain
  // `flutter test` (google_fonts → path_provider headless limitation, see
  // demo_harness.dart). On a real device both work without runAsync.
  testWidgets('cold deep link to a locked invoice edit → dialog, then detail', (
    tester,
  ) async {
    final db = AppDatabase(await openInMemoryExecutor());
    addTearDown(db.close);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await db.companiesDao.upsertAccount(
      AccountsCompanion.insert(
        id: 'acct_1',
        email: '',
        plan: 'pro',
        numTrialDays: 14,
        updatedAt: nowMs,
      ),
    );
    await db.companiesDao.upsertAll([
      CompaniesCompanion.insert(
        id: 'co_a',
        name: 'Acme',
        settings: '{"lock_invoices": "when_sent"}',
        permissions: '',
        accountId: 'acct_1',
        token: 'tok_a',
        isOwner: const Value(true),
        isAdmin: const Value(true),
        enabledModules: const Value(_kAllModulesEnabled),
        updatedAt: nowMs,
      ),
    ]);
    final storage = InMemoryTokenStorage();
    await storage.write('invoiceninja.tokens.v1', '{"co_a":"tok_a"}');
    await storage.write('invoiceninja.base_url.v1', 'https://test');
    await storage.write('invoiceninja.is_hosted.v1', 'false');
    await storage.write('invoiceninja.current_company.v1', 'co_a');

    final services = _buildTestServices(
      db: db,
      tokenStorage: storage,
      httpClient: _silentNetwork(),
    );
    await services.auth.restore();
    // status_id 2 = sent → locked under when_sent.
    await services.invoices.applyUpdateResponse(
      companyId: 'co_a',
      serverResponse: const InvoiceApi(
        id: 'inv1',
        statusId: '2',
        updatedAt: 1700000000,
      ),
    );

    await tester.pumpWidget(
      InvoiceNinjaApp(
        services: services,
        dbWasReset: false,
        initialLocation: '/invoices/inv1/edit',
      ),
    );
    await _pumpUntilFound(tester, find.byType(AlertDialog));

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Sent invoices are locked'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Close'));
    await _pumpUntilFound(tester, find.byType(InvoiceDetailScreen));

    expect(find.byType(AlertDialog), findsNothing);
    // Gate fired: dialog dismissed and we landed on the detail screen
    // instead of staying in the editor. We deliberately do NOT assert
    // `InvoiceEditScreen` is gone — under the real go_router the redirected
    // edit route can linger in the widget tree through the transition
    // (the unit test's flat two-route stub unmounted it immediately; the
    // real shell/router does not). DetailScreen present + dialog gone is
    // the meaningful, non-brittle proof that the deep-link gate worked.
    expect(find.byType(InvoiceDetailScreen), findsOneWidget);
  });
}

// ───────────────────────────────────────────────────────────────────────
// Helpers shared by the per-route + shell-nav tests. Kept at the bottom
// of the file so the testWidgets blocks read top-to-bottom.
// ───────────────────────────────────────────────────────────────────────

Future<({AppDatabase db, InMemoryTokenStorage storage})>
_seedAdminSession() async {
  final db = AppDatabase(await openInMemoryExecutor());
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  await db.companiesDao.upsertAccount(
    AccountsCompanion.insert(
      id: 'acct_1',
      email: '',
      plan: 'pro',
      numTrialDays: 14,
      updatedAt: nowMs,
    ),
  );
  await db.companiesDao.upsertAll([
    CompaniesCompanion.insert(
      id: 'co_a',
      name: 'Acme',
      settings: '{}',
      permissions: '',
      accountId: 'acct_1',
      token: 'tok_a',
      isOwner: const Value(true),
      isAdmin: const Value(true),
      enabledModules: const Value(_kAllModulesEnabled),
      updatedAt: nowMs,
    ),
  ]);
  final storage = InMemoryTokenStorage();
  await storage.write('invoiceninja.tokens.v1', '{"co_a":"tok_a"}');
  await storage.write('invoiceninja.base_url.v1', 'https://test');
  await storage.write('invoiceninja.is_hosted.v1', 'false');
  await storage.write('invoiceninja.current_company.v1', 'co_a');
  return (db: db, storage: storage);
}

/// Boots `InvoiceNinjaApp` at [route] under an admin/owner session and
/// waits for [screenType]. The screen builder is checked by widget type
/// only — we just want to know the URL resolved and the screen mounted.
Future<void> _expectRouteMounts(
  WidgetTester tester, {
  required String route,
  required Type screenType,
}) async {
  await _bootAdminApp(tester, initialLocation: route);
  await _pumpUntilFound(tester, find.byType(screenType));
  expect(
    find.byType(screenType),
    findsOneWidget,
    reason: 'Expected $screenType at route $route',
  );
}

/// Builds [Services] for these smoke tests with a deterministic connectivity
/// watcher. Without it, [Services.build] falls back to
/// `ConnectivityWatcher.live()`, whose real-network `onOnline` subscription
/// outlives the test — the harness only closes the in-memory DB in
/// `addTearDown`, never disposing `Services` — so a later connectivity event
/// fires `sync.drainOnce` against the closed DB and throws a `StateError` the
/// framework blames on whatever test is running. `.fixed`'s `onOnline` is an
/// empty stream, so nothing leaks. Route every `Services.build` in this file
/// through here so a new call site can't reintroduce the leak.
Services _buildTestServices({
  required AppDatabase db,
  required TokenStorage tokenStorage,
  required http.Client httpClient,
  BiometricService? biometricService,
}) {
  return Services.build(
    db: db,
    tokenStorage: tokenStorage,
    httpClient: httpClient,
    biometricService: biometricService,
    connectivityWatcher: ConnectivityWatcher.fixed(online: true),
  );
}

/// Boots an admin/owner session at [initialLocation]. Returns nothing —
/// `addTearDown(db.close)` handles cleanup.
Future<void> _bootAdminApp(
  WidgetTester tester, {
  required String initialLocation,
}) async {
  final seed = await _seedAdminSession();
  addTearDown(seed.db.close);

  final services = _buildTestServices(
    db: seed.db,
    tokenStorage: seed.storage,
    httpClient: _silentNetwork(),
  );
  await services.auth.restore();

  await tester.pumpWidget(
    InvoiceNinjaApp(
      services: services,
      dbWasReset: false,
      initialLocation: initialLocation,
    ),
  );
}

/// Tap a [SidebarNavItem] by its localized label. The widget tree must
/// already include the shell — the caller is responsible for booting the
/// app and waiting for the active screen first.
Future<void> _tapSidebarItem(WidgetTester tester, String label) async {
  final inSidebar = find.byType(InSidebar);
  expect(inSidebar, findsOneWidget, reason: 'InSidebar must be mounted');
  final item = find.descendant(
    of: inSidebar,
    matching: find.widgetWithText(SidebarNavItem, label),
  );
  expect(item, findsOneWidget, reason: 'sidebar item "$label" missing');
  await tester.tap(item);
}
