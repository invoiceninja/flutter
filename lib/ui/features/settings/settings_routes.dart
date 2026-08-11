import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/views/basic/account_management/account_management_shell.dart';
import 'package:admin/ui/features/settings/views/basic/account_management/quickbooks_screen.dart';
import 'package:admin/ui/features/settings/views/basic/backup_restore/backup_restore_shell.dart';
import 'package:admin/ui/features/settings/views/basic/company_details/company_details_shell.dart';
import 'package:admin/ui/features/settings/views/basic/expense_settings_screen.dart';
import 'package:admin/ui/features/settings/views/basic/device_settings_screen.dart';
import 'package:admin/ui/features/settings/views/basic/keyboard_shortcuts_screen.dart';
import 'package:admin/ui/features/settings/views/basic/import_export_screen.dart';
import 'package:admin/ui/features/settings/views/basic/localization/localization_shell.dart';
import 'package:admin/data/models/domain/payment_link.dart';
import 'package:admin/data/models/domain/report_schedule_seed.dart';
import 'package:admin/ui/features/gateways/views/company_gateway_detail_screen.dart';
import 'package:admin/ui/features/gateways/views/company_gateway_edit_screen.dart';
import 'package:admin/ui/features/gateways/views/company_gateway_list_screen.dart';
import 'package:admin/ui/features/payment_links/views/payment_link_detail_screen.dart';
import 'package:admin/ui/features/payment_links/views/payment_link_edit_screen.dart';
import 'package:admin/ui/features/payment_links/views/payment_link_list_screen.dart';
import 'package:admin/ui/features/settings/views/basic/online_payments_screen.dart';
import 'package:admin/ui/features/settings/views/basic/product_settings_screen.dart';
import 'package:admin/ui/features/settings/views/basic/task_settings_screen.dart';
import 'package:admin/ui/features/settings/views/basic/tax_settings_screen.dart';
import 'package:admin/ui/features/settings/views/basic/user_details/user_details_shell.dart';
import 'package:admin/ui/features/settings/views/basic/workflow_settings/workflow_settings_shell.dart';
import 'package:admin/ui/features/bank_accounts/views/bank_account_detail_screen.dart';
import 'package:admin/ui/features/bank_accounts/views/bank_account_edit_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/bank_accounts/bank_accounts_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/bank_accounts/transaction_rules_screen.dart';
import 'package:admin/ui/features/transaction_rules/views/transaction_rule_edit_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/client_portal/client_portal_shell.dart';
import 'package:admin/ui/features/settings/views/advanced/custom_fields/custom_fields_shell.dart';
import 'package:admin/ui/features/settings/views/advanced/e_invoice/e_invoice_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/email_settings_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/generated_numbers/generated_numbers_shell.dart';
import 'package:admin/ui/features/settings/views/advanced/group_settings_edit_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/group_settings_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/payment_terms_edit_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/payment_terms_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/tags_edit_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/tags_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/task_statuses_edit_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/task_statuses_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/tax_rates_edit_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/tax_rates_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/integrations/analytics_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/integrations/api_tokens_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/integrations/api_webhooks_screen.dart';
import 'package:admin/ui/features/tokens/views/token_edit_screen.dart';
import 'package:admin/ui/features/webhooks/views/webhook_edit_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/invoice_design_shell.dart';
import 'package:admin/ui/features/settings/views/advanced/schedules_edit_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/schedules_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/system_logs_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/templates_reminders_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/user_management/views/user_detail_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/user_management/views/user_edit_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/user_management_screen.dart';

/// Wraps a settings route's child in a [KeyedSubtree] whose key encodes the
/// current `(level, targetId)` from [SettingsLevelController]. When the
/// scope flips (e.g. the scope banner's close button calls
/// `controller.reset()`), the key changes and the inner screen remounts
/// — its `initState` then rebuilds the view-model against the new level.
///
/// Without this, screens that capture the scope once in `initState`
/// (every settings screen today) would keep saving to the previous scope
/// after the level changed. With this wrapper, the route stays at the
/// same URL while the content swaps, so closing the banner keeps the
/// user on the same sub-page.
class _SettingsLevelKeyed extends StatelessWidget {
  const _SettingsLevelKeyed({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SettingsLevelController>();
    return KeyedSubtree(
      key: ValueKey('${ctrl.level.name}:${ctrl.targetId ?? ''}'),
      child: child,
    );
  }
}

/// Drop-in replacement for `GoRoute(builder: ...)` that swaps the default
/// `MaterialPage` slide for a viewport-aware transition:
///   * **wide** (≥ `Breakpoints.wide`): no transition — the persistent left
///     sidebar makes navigation feel like content replacement, not a push.
///   * **narrow**: standard right-to-left slide so the stack-style narrow nav
///     still feels right.
/// `MediaQuery` can't be read in `pageBuilder` (no `BuildContext` is mounted
/// yet), so the size check happens inside `transitionsBuilder`.
GoRoute _settingsRoute({
  required String path,
  required Widget Function(BuildContext, GoRouterState) builder,
  List<RouteBase> routes = const [],
}) {
  return GoRoute(
    path: path,
    pageBuilder: (context, state) => CustomTransitionPage<void>(
      key: state.pageKey,
      child: _SettingsLevelKeyed(child: builder(context, state)),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final wide = MediaQuery.sizeOf(context).width >= Breakpoints.wide;
        if (wide) return child;
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOut)).animate(animation),
          child: child,
        );
      },
    ),
    routes: routes,
  );
}

/// One-line shorthand for the dominant pattern: a leaf settings route with no
/// children. Equivalent to `_settingsRoute(path: path, builder: (_, _) =>
/// child())` — the closure is required so the widget can stay `const` at the
/// call site without forcing every entry to spell out the typed lambda.
GoRoute _leaf(String path, Widget Function() child) =>
    _settingsRoute(path: path, builder: (_, _) => child());

/// Redirect child mapping `<root>/:id/edit` back onto `<root>/:id`. Attach it
/// to the `:id` route of every settings entity block that has no detail screen.
///
/// Those blocks invert the entity-branch shape: there, `:id` is the detail
/// screen and `:id/edit` the form; here `:id` IS the form and nothing lives at
/// `:id/edit`. But `entityRecordPath` (`router.dart`), the outbox row "Open"
/// action (`outbox_screen.dart`), and the sync listener's validation / conflict
/// actions (`sync_event_listener.dart`) all append `/edit` for a detail-less
/// entity — so that URL has to resolve or the user lands on the route-error
/// view. Registering it as a redirect (rather than a second route onto the same
/// screen) keeps one canonical URL, and contributes no page of its own.
GoRoute _editAlias() =>
    GoRoute(path: 'edit', redirect: (_, state) => stripEditSuffix(state.uri));

/// [uri] with a trailing `/edit` segment removed, query string preserved.
/// Returns the location unchanged when there is no such segment. Lives here
/// rather than beside `legacyIntegrationsRedirect` in `router.dart` because
/// `router.dart` already imports this library — the reverse import would be a
/// cycle. Backs [_editAlias].
String stripEditSuffix(Uri uri) {
  const suffix = '/edit';
  if (!uri.path.endsWith(suffix)) return uri.toString();
  return uri
      .replace(path: uri.path.substring(0, uri.path.length - suffix.length))
      .toString();
}

/// Route pair for a tabbed settings shell — registers `/settings/<path>` and
/// `/settings/<path>/:tab(<slugs>)` against a single [CustomTransitionPage]
/// builder so both routes resolve to the same Navigator Page. The constant
/// [ValueKey] keyed by [pageKey] is what keeps the shell's Element (its
/// `TabController`, draft VM, in-progress swipe) alive across the two paths;
/// without it, clicking a tab from the bare URL would remount the shell.
///
/// Pairs with [TabbedSettingsShell] in
/// `lib/ui/features/settings/widgets/tabbed_settings_shell.dart` — the shell
/// reads `:tab` off the route, the route trusts the shell to keep
/// [TabController] aligned. Both halves are required.
///
/// [tabSubRoutes] maps a tab slug to routes that live *under* that tab (e.g.
/// Account Management → Integrations → Analytics). Such a slug gets its own
/// explicit `GoRoute` — carrying the same [pageKey], so the shell's Element
/// survives navigating into and back out of a child — and is dropped from the
/// `:tab(…)` pattern so exactly one route matches each URL. `:tab` is null on
/// those routes, hence the fixed slug passed to [shellBuilder]; a shell with
/// sub-routes must ALSO derive its active tab from the path rather than the
/// `:tab` path parameter, which go_router reports as null once a child route is
/// the terminal match (see `accountManagementTabSlug`).
///
/// If [tabSubRoutes] covers every slug the `:tab` route is dropped entirely —
/// go_router's `patternToRegExp` needs at least one character inside the
/// parens, so an empty `:tab()` alternation is not a parse error: `:tab`
/// degrades to a bare parameter and `()` becomes a literal, leaving a route
/// that silently matches nothing.
List<RouteBase> tabbedSettingsRoutePair({
  required String path,
  required String pageKey,
  required List<String> tabSlugs,
  required Widget Function(String? initialTab) shellBuilder,
  Map<String, List<RouteBase>> tabSubRoutes = const {},
}) {
  CustomTransitionPage<void> Function(BuildContext, GoRouterState)
  pageBuilderFor(String? fixedTab) {
    return (context, state) => CustomTransitionPage<void>(
      key: ValueKey(pageKey),
      child: _SettingsLevelKeyed(
        child: shellBuilder(state.pathParameters['tab'] ?? fixedTab),
      ),
      transitionsBuilder: (context, animation, _, child) {
        final wide = MediaQuery.sizeOf(context).width >= Breakpoints.wide;
        if (wide) return child;
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOut)).animate(animation),
          child: child,
        );
      },
    );
  }

  final patternSlugs = tabSlugs
      .where((s) => !tabSubRoutes.containsKey(s))
      .toList();

  return [
    GoRoute(path: path, pageBuilder: pageBuilderFor(null)),
    for (final entry in tabSubRoutes.entries)
      GoRoute(
        path: '$path/${entry.key}',
        pageBuilder: pageBuilderFor(entry.key),
        routes: entry.value,
      ),
    if (patternSlugs.isNotEmpty)
      GoRoute(
        path: '$path/:tab(${patternSlugs.join('|')})',
        pageBuilder: pageBuilderFor(null),
      ),
  ];
}

/// All sub-routes under `/settings`. Mounted by `router.dart` as the `routes:`
/// list of the `/settings` `GoRoute`. URL slugs are user-facing (e.g.
/// `payment_links`, `users` for User Management).
///
/// **Nesting defines the back stack.** go_router emits one `Page` per matched
/// route in the chain, so a nested route with a `builder`/`pageBuilder` becomes
/// a real page the user lands on when they press back — whether or not they
/// ever visited it. Nest a route only under a parent that is genuinely the
/// screen it was reached from; a URL grouping that nobody navigates through
/// shows up as a phantom page on the way back (issue #8).
final List<RouteBase> settingsRoutes = [
  // ── Basic ─────────────────────────────────────────────────────────────
  // Company Details is one shell with 6 tabs in a TabBarView. The bare URL
  // and the per-tab URL share a page key (see `tabbedSettingsRoutePair`) so
  // they resolve to a single, persistent Navigator Page — clicking a tab
  // from the bare URL doesn't remount the shell.
  ...tabbedSettingsRoutePair(
    path: 'company_details',
    pageKey: 'company_details_shell',
    tabSlugs: const ['address', 'logo', 'defaults', 'documents'],
    shellBuilder: (initialTab) => CompanyDetailsShell(initialTab: initialTab),
  ),
  ...tabbedSettingsRoutePair(
    path: 'user_details',
    pageKey: 'user_details_shell',
    tabSlugs: const [
      'password',
      'connect',
      'enable_two_factor',
      'notifications',
      'preferences',
    ],
    shellBuilder: (initialTab) => UserDetailsShell(initialTab: initialTab),
  ),
  // Localization is one shell with two tabs (Settings, Custom Labels), shared
  // page key so the bare URL and `/custom_labels` resolve to the same
  // Navigator Page — keeps the cascade VM + TabController alive across the
  // two paths.
  ...tabbedSettingsRoutePair(
    path: 'localization',
    pageKey: 'localization_shell',
    tabSlugs: const ['custom_labels'],
    shellBuilder: (initialTab) => LocalizationShell(initialTab: initialTab),
  ),
  // Online Payments is one shell with three tabs (General / Defaults /
  // Emails) on narrow widths, and a single stacked page on wide. The bare URL
  // and `/defaults` + `/emails` share a page key (see `tabbedSettingsRoutePair`)
  // so they resolve to the same Navigator Page — clicking a tab from the bare
  // URL doesn't remount the shell.
  ...tabbedSettingsRoutePair(
    path: 'online_payments',
    pageKey: 'online_payments_shell',
    tabSlugs: const ['defaults', 'emails'],
    shellBuilder: (initialTab) => OnlinePaymentsScreen(initialTab: initialTab),
  ),
  _settingsRoute(
    path: 'company_gateways',
    builder: (_, _) => const CompanyGatewayListScreen(),
    routes: [
      _leaf('new', () => const CompanyGatewayEditScreen()),
      _settingsRoute(
        path: ':id',
        builder: (_, state) =>
            CompanyGatewayDetailScreen(id: state.pathParameters['id']!),
        routes: [
          _settingsRoute(
            path: 'edit',
            builder: (_, state) => CompanyGatewayEditScreen(
              existingId: state.pathParameters['id'],
            ),
          ),
        ],
      ),
    ],
  ),
  _leaf('tax_settings', () => const TaxSettingsScreen()),
  _leaf('product_settings', () => const ProductSettingsScreen()),
  _leaf('task_settings', () => const TaskSettingsScreen()),
  _leaf('expense_settings', () => const ExpenseSettingsScreen()),
  // Workflow Settings is one shell with two tabs (Invoices / Quotes), shared
  // page key so the bare URL and `/quotes` resolve to the same Navigator Page
  // — keeps the cascade VM + TabController alive across the two paths.
  ...tabbedSettingsRoutePair(
    path: 'workflow_settings',
    pageKey: 'workflow_settings_shell',
    tabSlugs: const ['quotes'],
    shellBuilder: (initialTab) => WorkflowSettingsShell(initialTab: initialTab),
  ),
  // Account Management is one shell with seven URL-driven tabs (Plan default,
  // Overview / Enabled Modules / Integrations / Security Settings / Referral
  // Program / Danger Zone). Shared page key keeps the TabController + each
  // tab's local state alive across navigations.
  //
  // `referral_program` stays registered here even though the shell hides that
  // tab on self-hosted sessions (issue #27) — the route table is static and
  // session-independent, and the shell normalizes a hidden tab's URL back to
  // the base path (see `visibleAccountManagementTabSlugs`).
  //
  // The Integrations tab's four in-app destinations are `tabSubRoutes`
  // children (the other two tiles are external links), so
  // the shell page sits under them in the back stack and system back returns
  // to the tab the user tapped from (issue #8). They used to hang off a
  // top-level `/settings/integrations` route whose own page — an orphan left
  // behind when that sidebar section was removed — became a phantom screen on
  // the way back.
  ...tabbedSettingsRoutePair(
    path: 'account_management',
    pageKey: 'account_management_shell',
    tabSlugs: const [
      'overview',
      'enabled_modules',
      'integrations',
      'security_settings',
      'referral_program',
      'danger_zone',
    ],
    shellBuilder: (initialTab) =>
        AccountManagementShell(initialTab: initialTab),
    tabSubRoutes: {
      'integrations': [
        _settingsRoute(
          path: 'api_tokens',
          builder: (_, _) => const IntegrationsApiTokensScreen(),
          routes: [
            _leaf('new', () => const TokenEditScreen()),
            _settingsRoute(
              path: ':id',
              builder: (_, state) =>
                  TokenEditScreen(existingId: state.pathParameters['id']),
              routes: [_editAlias()],
            ),
          ],
        ),
        _settingsRoute(
          path: 'api_webhooks',
          builder: (_, _) => const IntegrationsApiWebhooksScreen(),
          routes: [
            _leaf('new', () => const WebhookEditScreen()),
            _settingsRoute(
              path: ':id',
              builder: (_, state) =>
                  WebhookEditScreen(existingId: state.pathParameters['id']),
              routes: [_editAlias()],
            ),
          ],
        ),
        _leaf('analytics', () => const IntegrationsAnalyticsScreen()),
        _leaf('quickbooks', () => const QuickbooksScreen()),
      ],
    },
  ),
  // `plan` is the shell's empty-slug default tab, so it is deliberately absent
  // from `tabSlugs` and `/settings/account_management/plan` matches no route.
  // Callers still reach for it (and `nav_state_persister` would then save the
  // dead URL, re-opening the route-error view on every launch), so heal it with
  // a redirect. A redirect-only GoRoute contributes no page of its own.
  GoRoute(
    path: 'account_management/plan',
    redirect: (_, _) => '/settings/account_management',
  ),
  // Backup | Restore is a single shell with two URL-driven tabs. Bare URL
  // resolves to the Backup tab; `/restore` to the Restore tab. Shared page
  // key (see `tabbedSettingsRoutePair`) keeps the shell's TabController + the
  // Restore tab's in-progress upload state alive across the two paths.
  ...tabbedSettingsRoutePair(
    path: 'backup_restore',
    pageKey: 'backup_restore_shell',
    tabSlugs: const ['restore'],
    shellBuilder: (initialTab) => BackupRestoreShell(initialTab: initialTab),
  ),
  _leaf('import_export', () => const ImportExportScreen()),
  _leaf('device_settings', () => const DeviceSettingsScreen()),
  _leaf('keyboard_shortcuts', () => const KeyboardShortcutsScreen()),

  // ── Advanced ──────────────────────────────────────────────────────────
  // Invoice Design is one shell with a Custom Designs tab + a tab per
  // PDF-variable section + a General Settings tab. Shared page key so the
  // bare URL and each `/<slug>` resolve to the same Navigator Page — keeps
  // the cascade VM + TabController alive across tab clicks.
  ...tabbedSettingsRoutePair(
    path: 'invoice_design',
    pageKey: 'invoice_design_shell',
    tabSlugs: const [
      'custom_designs',
      'client_details',
      'company_details',
      'company_address',
      'invoice_details',
      'quote_details',
      'credit_details',
      'vendor_details',
      'purchase_order_details',
      'product_columns',
      'product_quote_columns',
      'task_columns',
      'total_columns',
    ],
    shellBuilder: (initialTab) => InvoiceDesignShell(initialTab: initialTab),
  ),
  // Custom Fields is one shell with N module-gated tabs (Company / Clients /
  // Products / Invoices / Payments / Projects / Tasks / Vendors / Expenses /
  // Users). The bare URL and per-tab URL share a page key (see
  // `tabbedSettingsRoutePair`) so flipping tabs doesn't remount the shell —
  // the dynamic-tabs custom shell still derives `:tab` off the route, so the
  // pair helper here just registers both URLs against one Navigator page.
  // Module-disabled slugs (e.g. `tasks` when the Tasks module is off) stay
  // in `tabSlugs` so deep links resolve; the shell falls back to the first
  // visible tab in that case.
  ...tabbedSettingsRoutePair(
    path: 'custom_fields',
    pageKey: 'custom_fields_shell',
    tabSlugs: const [
      'clients',
      'products',
      'invoices',
      'payments',
      'projects',
      'tasks',
      'vendors',
      'expenses',
      'users',
    ],
    shellBuilder: (initialTab) => CustomFieldsShell(initialTab: initialTab),
  ),
  // Generated Numbers is a tabbed cascade shell — the parent and per-tab
  // URLs share a page key (see `tabbedSettingsRoutePair`) so flipping tabs
  // doesn't remount the shell or its draft VM. Module-disabled slugs (e.g.
  // `tasks` when the Tasks module is off) stay in `tabSlugs` so deep links
  // resolve; the shell falls back to the first visible tab.
  ...tabbedSettingsRoutePair(
    path: 'generated_numbers',
    pageKey: 'generated_numbers_shell',
    tabSlugs: const [
      'clients',
      'invoices',
      'recurring_invoices',
      'payments',
      'quotes',
      'credits',
      'projects',
      'tasks',
      'vendors',
      'purchase_orders',
      'expenses',
      'recurring_expenses',
    ],
    shellBuilder: (initialTab) => GeneratedNumbersShell(initialTab: initialTab),
  ),
  ...tabbedSettingsRoutePair(
    path: 'client_portal',
    pageKey: 'client_portal',
    tabSlugs: const ['authorization', 'registration', 'messages', 'customize'],
    shellBuilder: (initialTab) => ClientPortalShell(initialTab: initialTab),
  ),
  _leaf('e_invoice', () => const EInvoiceScreen()),
  _leaf('email_settings', () => const EmailSettingsScreen()),
  _leaf('templates_and_reminders', () => const TemplatesRemindersScreen()),
  _settingsRoute(
    path: 'bank_accounts',
    builder: (_, _) => const BankAccountsScreen(),
    routes: [
      _leaf('new', () => const BankAccountEditScreen()),
      _settingsRoute(
        path: 'transaction_rules',
        builder: (_, _) => const BankAccountsTransactionRulesScreen(),
        routes: [
          _leaf('new', () => const TransactionRuleEditScreen()),
          _settingsRoute(
            path: ':id',
            builder: (_, state) => TransactionRuleEditScreen(
              existingId: state.pathParameters['id'],
            ),
            routes: [_editAlias()],
          ),
        ],
      ),
      _settingsRoute(
        path: ':id',
        builder: (_, state) =>
            BankAccountDetailScreen(id: state.pathParameters['id']!),
        routes: [
          _settingsRoute(
            path: 'edit',
            builder: (_, state) =>
                BankAccountEditScreen(existingId: state.pathParameters['id']),
          ),
        ],
      ),
    ],
  ),
  _settingsRoute(
    path: 'group_settings',
    builder: (_, _) => const GroupSettingsScreen(),
    routes: [
      _leaf('new', () => const GroupSettingsEditScreen()),
      _settingsRoute(
        path: ':id',
        builder: (_, state) =>
            GroupSettingsEditScreen(existingId: state.pathParameters['id']),
        routes: [_editAlias()],
      ),
    ],
  ),
  _settingsRoute(
    path: 'task_statuses',
    builder: (_, _) => const TaskStatusesScreen(),
    routes: [
      _leaf('new', () => const TaskStatusesEditScreen()),
      _settingsRoute(
        path: ':id',
        builder: (_, state) =>
            TaskStatusesEditScreen(existingId: state.pathParameters['id']),
        routes: [_editAlias()],
      ),
    ],
  ),
  _settingsRoute(
    path: 'tags',
    builder: (_, _) => const TagsScreen(),
    routes: [
      // `?entityType=task|project` carries the active toggle into create.
      _settingsRoute(
        path: 'new',
        builder: (_, state) => TagsEditScreen(
          entityType: state.uri.queryParameters['entityType'] ?? 'task',
        ),
      ),
      _settingsRoute(
        path: ':id',
        builder: (_, state) =>
            TagsEditScreen(existingId: state.pathParameters['id']),
        routes: [_editAlias()],
      ),
    ],
  ),
  _settingsRoute(
    path: 'payment_terms',
    builder: (_, _) => const PaymentTermsScreen(),
    routes: [
      _leaf('new', () => const PaymentTermsEditScreen()),
      _settingsRoute(
        path: ':id',
        builder: (_, state) =>
            PaymentTermsEditScreen(existingId: state.pathParameters['id']),
        routes: [_editAlias()],
      ),
    ],
  ),
  _settingsRoute(
    path: 'tax_rates',
    builder: (_, _) => const TaxRatesScreen(),
    routes: [
      _leaf('new', () => const TaxRatesEditScreen()),
      _settingsRoute(
        path: ':id',
        builder: (_, state) =>
            TaxRatesEditScreen(existingId: state.pathParameters['id']),
        routes: [_editAlias()],
      ),
    ],
  ),
  // Payment Links — registered here (not only via the entity branch) so
  // `/settings/payment_links` matches the Settings branch first and renders
  // inside `SettingsShell`, keeping the persistent sidebar. Same pattern as
  // `company_gateways` above; screens are reused from the entity module.
  _settingsRoute(
    path: 'payment_links',
    builder: (_, _) => const PaymentLinkListScreen(),
    routes: [
      _settingsRoute(
        path: 'new',
        builder: (_, state) => PaymentLinkEditScreen(
          cloneFrom: state.extra is PaymentLink
              ? state.extra as PaymentLink
              : null,
        ),
      ),
      _settingsRoute(
        path: ':id',
        builder: (_, state) =>
            PaymentLinkDetailScreen(id: state.pathParameters['id']!),
        routes: [
          _settingsRoute(
            path: 'edit',
            builder: (_, state) =>
                PaymentLinkEditScreen(existingId: state.pathParameters['id']),
          ),
        ],
      ),
    ],
  ),
  _settingsRoute(
    path: 'schedules',
    builder: (_, state) => const SchedulesScreen(),
    routes: [
      _settingsRoute(
        path: 'new',
        builder: (context, state) => SchedulesEditScreen(
          starter: state.uri.queryParameters['starter'],
          // Cross-branch (Reports → Schedule) drops route `extra:`, so the seed
          // rides on `Services`; fall back to `extra:` for same-branch callers.
          seed:
              context.read<Services>().takeCreateDraft<ReportScheduleSeed>(
                '/settings/schedules',
              ) ??
              (state.extra is ReportScheduleSeed
                  ? state.extra as ReportScheduleSeed
                  : null),
        ),
      ),
      _settingsRoute(
        path: ':id',
        builder: (_, state) =>
            SchedulesEditScreen(existingId: state.pathParameters['id']),
        routes: [_editAlias()],
      ),
    ],
  ),
  _settingsRoute(
    path: 'users',
    builder: (_, _) => const UserManagementScreen(),
    routes: [
      _leaf('new', () => const UserEditScreen()),
      _settingsRoute(
        path: ':id',
        builder: (_, state) =>
            UserDetailScreen(id: state.pathParameters['id']!),
        routes: [
          _settingsRoute(
            path: 'edit',
            builder: (_, state) =>
                UserEditScreen(existingId: state.pathParameters['id']),
          ),
        ],
      ),
    ],
  ),
  _leaf('system_logs', () => const SystemLogsScreen()),
];
