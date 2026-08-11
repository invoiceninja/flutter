import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/list/deep_link_filter_intent.dart';
import 'package:admin/ui/core/widgets/link_text.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/ui/features/shell/widgets/app_drawer.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/activity_card.dart';
import 'package:admin/ui/features/dashboard/widgets/chart_card.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_top_bar.dart';
import 'package:admin/ui/features/dashboard/widgets/filters/date_range_picker_button.dart';
import 'package:admin/ui/features/dashboard/widgets/filters/settings_popover.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_card_config.dart';
import 'package:admin/ui/features/dashboard/helpers/card_deep_link.dart';
import 'package:admin/ui/features/dashboard/widgets/configured_cards_grid.dart';
import 'package:admin/ui/features/dashboard/widgets/kpi_row.dart';
import 'package:admin/ui/features/dashboard/widgets/manage_dashboard_cards_sheet.dart';
import 'package:admin/ui/features/dashboard/widgets/mobile_dashboard_body.dart';
import 'package:admin/ui/features/dashboard/widgets/needs_your_attention_card.dart';
import 'package:admin/ui/features/dashboard/widgets/recent_payments_card.dart';
import 'package:admin/ui/features/dashboard/widgets/section_listenable.dart';
import 'package:admin/ui/features/dashboard/widgets/upcoming_invoices_card.dart';
import 'package:admin/ui/features/dashboard/widgets/upcoming_quotes_card.dart';
import 'package:admin/ui/features/dashboard/widgets/upcoming_recurring_invoices_card.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_activity.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_list_rows.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/domain/entity_type.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Services _services;
  late DashboardViewModel _vm;
  late String _companyId;
  // Empty when the active company has neither a `displayName` nor a `name`;
  // `_resolveCompanyName(context)` falls back to the localized 'Dashboard'
  // string at render time so the fallback follows the active locale.
  late String _rawCompanyName;
  Formatter? _formatter;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    final session = _services.auth.session.value!;
    _companyId = session.currentCompanyId;
    _rawCompanyName = _rawNameFor(session.currentCompany);
    _vm = _buildVm();
    _services.auth.session.addListener(_onSessionChanged);
    _loadFormatter();
  }

  static String _rawNameFor(dynamic company) {
    if (company == null) return '';
    final display = company.displayName as String? ?? '';
    if (display.isNotEmpty) return display;
    return company.name as String? ?? '';
  }

  String _resolveCompanyName(BuildContext context) =>
      _rawCompanyName.isNotEmpty ? _rawCompanyName : context.tr('dashboard');

  DashboardViewModel _buildVm() => DashboardViewModel(
    repo: _services.dashboard,
    companyId: _companyId,
    navStateDao: _services.db.navStateDao,
    statics: _services.statics,
    // Sync best-effort: if the formatter is already cached (e.g. navigating
    // back to the dashboard) we get the real fiscal year immediately;
    // otherwise _loadFormatter pushes it in once it resolves.
    firstMonthOfYear:
        _services.formatterIfReady(_companyId)?.settings.firstMonthOfYear ?? 1,
  );

  void _loadFormatter() {
    final loadingFor = _companyId;
    _services.formatterFor(loadingFor).then((f) {
      if (!mounted || loadingFor != _companyId) return;
      setState(() => _formatter = f);
      _vm.setFiscalYearStart(f.settings.firstMonthOfYear);
    });
  }

  void _onSessionChanged() {
    final s = _services.auth.session.value;
    if (s == null || s.currentCompanyId == _companyId) return;
    final oldVm = _vm;
    setState(() {
      _companyId = s.currentCompanyId;
      _rawCompanyName = _rawNameFor(s.currentCompany);
      _formatter = null;
      _vm = _buildVm();
    });
    oldVm.dispose();
    _loadFormatter();
  }

  @override
  void dispose() {
    _services.auth.session.removeListener(_onSessionChanged);
    _vm.dispose();
    super.dispose();
  }

  /// Route prefixes that actually resolve in the router today. Entity roots
  /// (`/invoices`, `/clients`, `/payments`, …) come from the registry so the
  /// set stays correct automatically as modules are wired; the fixed branches
  /// are listed explicitly. A target outside this set short-circuits to a
  /// snack instead of stranding the user on the root error page. In normal
  /// use the dashboard hides any affordance whose destination doesn't exist
  /// (e.g. the activity feed's "View all" — there's no activities screen), so
  /// this is a defensive net, not a routine path.
  Set<String> get _knownRoutePrefixes => {
    ..._services.entityRegistry.uiRoutePaths,
    '/dashboard',
    '/settings',
    '/sync/outbox',
    '/reports',
  };

  /// True when [type]'s module is enabled for the active company. Gates the
  /// dashboard's quick-create affordances (new invoice / log expense).
  bool _moduleOn(EntityType type) =>
      context
          .read<Services>()
          .auth
          .session
          .value
          ?.currentCompany
          ?.moduleEnabled(type) ??
      false;

  Future<void> _safeNavigate(String route) async {
    final isKnown = _knownRoutePrefixes.any(
      (p) => route == p || route.startsWith('$p/'),
    );
    if (!isKnown) {
      _showSnack(context.tr('details_in_next_update'));
      return;
    }
    context.go(route);
  }

  /// Navigate to a list route carrying a dashboard deep-link filter so the
  /// destination datatable shows the same records the tapped panel showed.
  /// Same known-prefix guard as [_safeNavigate].
  Future<void> _goWithIntent(String route, ListFilterIntent intent) async {
    final isKnown = _knownRoutePrefixes.any(
      (p) => route == p || route.startsWith('$p/'),
    );
    if (!isKnown) {
      _showSnack(context.tr('details_in_next_update'));
      return;
    }
    context.go(route, extra: intent);
  }

  /// `due_date` column id — invoice & quote list VMs accept it via
  /// `isValidColumnId`; the dashboard sorts past-due / upcoming invoices by
  /// `due_date|asc`, so the deep-linked list mirrors that ordering.
  static const String _dueDateColumnId = 'due_date';

  /// True when the dashboard's active range is the open-ended "all time"
  /// preset — sending a `date >=` lower bound then adds nothing.
  bool get _isAllTimeRange {
    final r = _vm.filter.range;
    return r is DashboardPresetRange && r.preset == DashboardDatePreset.allTime;
  }

  /// "Needs Your Attention" / pastDue → invoices with `overdue=true`,
  /// sorted by due date ascending (exact parity with the panel query).
  ListFilterIntent get _pastDueInvoicesIntent => ListFilterIntent(
    extraFilters: const {
      'overdue': {'true'},
    },
    sortField: _dueDateColumnId,
    sortAscending: true,
  );

  /// Upcoming invoices panel is a plain `GET /invoices` sorted by due date
  /// ascending — match the ordering, no status filter.
  ListFilterIntent get _upcomingInvoicesIntent =>
      ListFilterIntent(sortField: _dueDateColumnId, sortAscending: true);

  /// Expired quotes → `client_status=expired` (server-backed, same param
  /// the panel uses).
  ListFilterIntent get _expiredQuotesIntent => ListFilterIntent(
    extraFilters: const {
      'client_status': {'expired'},
    },
  );

  /// KPI Outstanding / Unpaid → invoices, carrying the dashboard's date window
  /// as a true closed `date_range` (base `QueryFilters::date_range`, 2-part
  /// `start,end` → `whereBetween('date', …)`). Both the Outstanding *amount*
  /// and the Unpaid *count* tiles describe `client_status=unpaid` (sent +
  /// partial), so they share this windowed intent. "All time" omits the window
  /// (open-ended by design).
  ListFilterIntent _invoiceKpiIntent() {
    final (start, end) = _vm.filter.resolveDates();
    return buildInvoiceKpiIntent(
      overdue: false,
      isAllTimeRange: _isAllTimeRange,
      start: start,
      end: end,
    );
  }

  /// KPI "Paid this month" → payments with `client_status=completed` and the
  /// dashboard's date window as the canonical `date,<start>,<end>` (v5
  /// unified `QueryFilters::date_range`).
  ListFilterIntent get _paidPaymentsIntent {
    final (start, end) = _vm.filter.resolveDates();
    return ListFilterIntent(
      extraFilters: {
        'client_status': const {'completed'},
        'date_range': {'date,${start.toIso()},${end.toIso()}'},
      },
    );
  }

  void _showSnack(String msg) {
    Notify.info(context, msg);
  }

  /// User-initiated refresh — the top bar's button and pull-to-refresh.
  ///
  /// `DashboardRepository.refreshAll` swallows each section's exception into a
  /// map instead of throwing, so without this a failed pass looks identical to
  /// a clean one apart from the freshness stamp quietly continuing to age.
  /// Deliberately not used for the VM's boot refresh in `_init()` — a toast on
  /// app start would be noise.
  Future<void> _refreshWithFeedback() async {
    // Capture the VM as well as the toast queue and the string before the
    // await. `_onSessionChanged` swaps `_vm` and disposes the old one, so a
    // company switch landing mid-pass would otherwise read the *new* company's
    // (null) error here. Same reason `entity_list_screen_scaffold` pins its VM
    // before a post-await callback.
    final vm = _vm;
    final toasts = Notify.capture(context);
    final failure = context.tr('refresh_failed');
    if (await vm.refresh()) return;
    final error = vm.globalError;
    toasts?.error(
      failure,
      detail: error == null ? null : formatNotifyError(error),
    );
  }

  /// Tap on a configured dashboard card → open its entity list, best-effort
  /// pre-filtered to match the metric (see `card_deep_link.dart`). Mirrors
  /// the KPI date-window behaviour for `current`-period cards.
  void _openConfiguredCard(DashboardCardConfig c) {
    final t = cardListTarget(c);
    if (!_moduleOn(t.entity)) {
      _showSnack(context.tr('details_in_next_update'));
      return;
    }
    final (start, end) = _vm.filter.resolveDates();
    _goWithIntent(
      t.route,
      ListFilterIntent(
        extraFilters: {
          ...t.extraFilters,
          if (c.period == CardPeriod.current && !_isAllTimeRange)
            'date_range': {'date,${start.toIso()},${end.toIso()}'},
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // No tree-wide ListenableBuilder here: the Scaffold / AppBar / Drawer /
    // LayoutBuilder / SafeArea chrome doesn't depend on dashboard data and
    // must not rebuild on every one of the ~9+ Drift stream emissions.
    // The VM-dependent chrome (the top bar, which carries the freshness stamp
    // and refresh button) and the data body listen via their own
    // narrowly-scoped ListenableBuilders below.
    return ListenableProvider<DashboardViewModel>.value(
      value: _vm,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;
        final globalNav = Breakpoints.isGlobalNavVisible(context);
        final scaffold = Builder(
          builder: (context) {
            final tokens = context.inTheme;
            return Scaffold(
              backgroundColor: tokens.bg,
              // Drawer keyed on *window* width — not [wide] — so the
              // hamburger doesn't appear at medium widths where the
              // global persistent rail is already visible.
              drawer: globalNav ? null : const AppDrawer(),
              // Mobile uses a standard AppBar (hamburger + title + icon
              // actions). Wide layouts keep the bespoke `DashboardTopBar`
              // inside the body so the company name + subtitle + full-label
              // buttons render the way `screens.jsx:196-201` calls for.
              appBar: wide ? null : _buildMobileAppBar(context),
              body: SafeArea(
                child: Column(
                  children: [
                    if (wide)
                      // Top bar reads `vm.filter` — rebuild only on VM
                      // notify, not as part of the static scaffold.
                      ListenableBuilder(
                        listenable: _vm,
                        builder: (context, _) => DashboardTopBar(
                          vm: _vm,
                          companyName: _resolveCompanyName(context),
                          onRefresh: () => unawaited(_refreshWithFeedback()),
                          onNewInvoice: _moduleOn(EntityType.invoice)
                              ? () => _safeNavigate('/invoices/new')
                              : null,
                          formatter: _formatter,
                        ),
                      ),
                    Expanded(
                      child: RefreshIndicator(
                        // Pull-to-refresh is mobile's only refresh affordance,
                        // so it gets the same failure feedback as the button.
                        onRefresh: _refreshWithFeedback,
                        // The data body is the only part that consumes
                        // section state. RepaintBoundary keeps a body
                        // rebuild from repainting the sibling chrome.
                        child: RepaintBoundary(
                          child: ListenableBuilder(
                            listenable: _vm,
                            builder: (context, _) => _formatter == null
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : (wide
                                      ? _buildScroll(context, constraints)
                                      : _buildMobile(context)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
        return scaffold;
      },
    );
  }

  PreferredSizeWidget _buildMobileAppBar(BuildContext context) {
    return AppBar(
      leading: const DrawerHamburger(),
      title: Text(
        _resolveCompanyName(context),
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        Builder(
          builder: (iconContext) => IconButton(
            tooltip: context.tr('date_range'),
            icon: const Icon(Icons.filter_alt_outlined),
            onPressed: () => openDateRangePicker(
              iconContext,
              current: _vm.filter.range,
              onChange: _vm.setDateRange,
              formatter: _formatter,
            ),
          ),
        ),
        Builder(
          builder: (iconContext) => IconButton(
            tooltip: context.tr('settings'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => openDashboardSettingsPopover(iconContext, vm: _vm),
          ),
        ),
        IconButton(
          tooltip: context.tr('customize'),
          icon: const Icon(Icons.dashboard_customize_outlined),
          onPressed: () => openManageDashboardCards(context, vm: _vm),
        ),
        if (_moduleOn(EntityType.invoice))
          IconButton(
            tooltip: context.tr('new_invoice'),
            icon: const Icon(Icons.add),
            onPressed: () => _safeNavigate('/invoices/new'),
          ),
      ],
    );
  }

  Widget _buildMobile(BuildContext context) {
    return MobileDashboardBody(
      vm: _vm,
      formatter: _formatter!,
      companyName: _resolveCompanyName(context),
      onOpenCard: _openConfiguredCard,
      onPastDueInvoiceTap: _navInvoice,
      onAllInvoices: () => _goWithIntent('/invoices', _pastDueInvoicesIntent),
      onAllUpcomingInvoices: () =>
          _goWithIntent('/invoices', _upcomingInvoicesIntent),
      onNewInvoice: () => _safeNavigate('/invoices/new'),
      onAddClient: () => _safeNavigate('/clients/new'),
      onLogExpense: () => _safeNavigate('/expenses/new'),
      onReports: () => _safeNavigate('/reports'),
      onOutstandingTap: () => _goWithIntent('/invoices', _invoiceKpiIntent()),
      onPaidTap: () => _goWithIntent('/payments', _paidPaymentsIntent),
      onActivityTap: _navActivity,
      // No activities list screen exists — hide the "View all" link
      // rather than route to a dead end.
      onAllActivities: null,
      onUpcomingInvoiceTap: _navInvoice,
      onPaymentTap: _navPayment,
      onAllPayments: () => _safeNavigate('/payments'),
      onQuoteTap: _navQuote,
      onAllQuotes: () => _safeNavigate('/quotes'),
      onRecurringTap: _navRecurring,
      onAllRecurring: () => _safeNavigate('/recurring_invoices'),
    );
  }

  // Cell-level navigation helpers shared by every list card. The pair pattern
  // (entity tap vs client tap) lines up 1:1 with the per-cell callback split
  // in `DashboardEntityTableRow.cellTaps`.

  void _navInvoice(DashboardInvoiceRow row) =>
      _safeNavigate('/invoices/${row.id}');
  void _navInvoiceClient(DashboardInvoiceRow row) =>
      _safeNavigate('/clients/${row.clientId}');
  void _navPayment(DashboardPaymentRow row) =>
      _safeNavigate('/payments/${row.id}');
  void _navPaymentClient(DashboardPaymentRow row) =>
      _safeNavigate('/clients/${row.clientId}');
  void _navQuote(DashboardQuoteRow row) => _safeNavigate('/quotes/${row.id}');
  void _navQuoteClient(DashboardQuoteRow row) =>
      _safeNavigate('/clients/${row.clientId}');
  void _navRecurring(DashboardRecurringInvoiceRow row) =>
      _safeNavigate('/recurring_invoices/${row.id}');
  void _navRecurringClient(DashboardRecurringInvoiceRow row) =>
      _safeNavigate('/clients/${row.clientId}');

  /// Resolve an activity row to its most-specific deep-link. Mirrors the
  /// precedence the activity-list page is expected to use when M2 lands.
  /// Rows that reference no entity (e.g. a system-only activity) silently
  /// do nothing — there's no per-activity detail screen.
  void _navActivity(DashboardActivity a) {
    final target = activityDeepLinkTarget(a);
    if (target == null) return;
    _safeNavigate(target);
  }

  Widget _buildScroll(BuildContext context, BoxConstraints outer) {
    final width = outer.maxWidth;
    final formatter = _formatter!;
    final children = <Widget>[
      ConfiguredCardsGrid(
        vm: _vm,
        formatter: formatter,
        onManage: () => openManageDashboardCards(context, vm: _vm),
        onOpenCard: _openConfiguredCard,
      ),
      SizedBox(height: InSpacing.lg(context)),
      sectionListenable(
        _vm.kpiListenable,
        () => KpiRow(
          vm: _vm,
          formatter: formatter,
          onOutstandingTap: () =>
              _goWithIntent('/invoices', _invoiceKpiIntent()),
          onPaidThisMonthTap: () =>
              _goWithIntent('/payments', _paidPaymentsIntent),
        ),
      ),
      SizedBox(height: InSpacing.lg(context)),
      _chartAndActivity(context, width, formatter),
      SizedBox(height: InSpacing.lg(context)),
      _bottomGrid(context, width, formatter),
      // The freshness stamp + Refresh used to live here, at the very bottom of
      // the scroll; both now sit in the always-visible top bar (issue #26).
      const SizedBox(height: InSpacing.xl),
    ];

    return ListView(
      padding: const EdgeInsets.all(InSpacing.xl),
      children: children,
    );
  }

  Widget _chartAndActivity(
    BuildContext context,
    double width,
    Formatter formatter,
  ) {
    final chart = sectionListenable(
      _vm.chartCardListenable,
      () => ChartCard(vm: _vm, formatter: formatter),
    );
    final activity = sectionListenable(
      _vm.listenableFor(DashboardKind.activities),
      () => ActivityCard(
        section: _vm.activities,
        // No activities list screen exists — hide the "View all" link.
        onViewAll: null,
        onRetry: () => _vm.retry(DashboardKind.activities),
        onActivityTap: _navActivity,
      ),
    );
    if (width >= 1024) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 17, child: chart),
            SizedBox(width: InSpacing.lg(context)),
            Expanded(flex: 10, child: activity),
          ],
        ),
      );
    }
    return Column(
      children: [
        chart,
        SizedBox(height: InSpacing.lg(context)),
        activity,
      ],
    );
  }

  Widget _bottomGrid(BuildContext context, double width, Formatter formatter) {
    // Hide list cards whose backing module is disabled for this company.
    final me = context.read<Services>().auth.session.value?.currentCompany;
    final invoicesOn = me?.moduleEnabled(EntityType.invoice) ?? false;
    final paymentsOn = me?.moduleEnabled(EntityType.payment) ?? false;
    final quotesOn = me?.moduleEnabled(EntityType.quote) ?? false;
    final recurringOn = me?.moduleEnabled(EntityType.recurringInvoice) ?? false;

    // One builder per panel whose module is enabled; rendered in the user's
    // saved order (`_vm.panelPrefs`), skipping hidden panels. Each card is
    // `KeyedSubtree`-keyed by kind so reorder/hide moves the element (and its
    // section subscription) as a unit instead of re-pointing it by position.
    final builders = <String, Widget Function()>{
      if (invoicesOn)
        DashboardKind.pastDue: () => sectionListenable(
          _vm.listenableFor(DashboardKind.pastDue),
          () => NeedsYourAttentionCard(
            section: _vm.pastDue,
            formatter: formatter,
            onInvoiceTap: _navInvoice,
            onClientTap: _navInvoiceClient,
            onViewAll: () => _goWithIntent('/invoices', _pastDueInvoicesIntent),
            onRetry: () => _vm.retry(DashboardKind.pastDue),
          ),
        ),
      if (invoicesOn)
        DashboardKind.upcomingInvoices: () => sectionListenable(
          _vm.listenableFor(DashboardKind.upcomingInvoices),
          () => UpcomingInvoicesCard(
            section: _vm.upcomingInvoices,
            formatter: formatter,
            onInvoiceTap: _navInvoice,
            onClientTap: _navInvoiceClient,
            onViewAll: () =>
                _goWithIntent('/invoices', _upcomingInvoicesIntent),
            onRetry: () => _vm.retry(DashboardKind.upcomingInvoices),
          ),
        ),
      if (paymentsOn)
        DashboardKind.recentPayments: () => sectionListenable(
          _vm.listenableFor(DashboardKind.recentPayments),
          () => RecentPaymentsCard(
            section: _vm.recentPayments,
            formatter: formatter,
            onPaymentTap: _navPayment,
            onClientTap: _navPaymentClient,
            onViewAll: () => _safeNavigate('/payments'),
            onRetry: () => _vm.retry(DashboardKind.recentPayments),
          ),
        ),
      if (quotesOn)
        DashboardKind.upcomingQuotes: () => sectionListenable(
          _vm.listenableFor(DashboardKind.upcomingQuotes),
          () => UpcomingQuotesCard(
            section: _vm.upcomingQuotes,
            formatter: formatter,
            onQuoteTap: _navQuote,
            onClientTap: _navQuoteClient,
            onViewAll: () => _safeNavigate('/quotes'),
            onRetry: () => _vm.retry(DashboardKind.upcomingQuotes),
          ),
        ),
      if (quotesOn)
        DashboardKind.expiredQuotes: () => sectionListenable(
          _vm.listenableFor(DashboardKind.expiredQuotes),
          () => ExpiredQuotesCard(
            section: _vm.expiredQuotes,
            formatter: formatter,
            onQuoteTap: _navQuote,
            onClientTap: _navQuoteClient,
            onViewAll: () => _goWithIntent('/quotes', _expiredQuotesIntent),
            onRetry: () => _vm.retry(DashboardKind.expiredQuotes),
          ),
        ),
      if (recurringOn)
        DashboardKind.upcomingRecurring: () => sectionListenable(
          _vm.listenableFor(DashboardKind.upcomingRecurring),
          () => UpcomingRecurringInvoicesCard(
            section: _vm.upcomingRecurring,
            formatter: formatter,
            onRecurringTap: _navRecurring,
            onClientTap: _navRecurringClient,
            onViewAll: () => _safeNavigate('/recurring_invoices'),
            onRetry: () => _vm.retry(DashboardKind.upcomingRecurring),
          ),
        ),
    };

    final cards = <Widget>[
      for (final p in _vm.panelPrefs)
        if (p.visible && builders.containsKey(p.kind))
          KeyedSubtree(key: ValueKey(p.kind), child: builders[p.kind]!()),
    ];

    if (cards.isEmpty) {
      // No backing module enabled → nothing to surface; collapse silently (the
      // chart / activity / KPI rows above still anchor the screen).
      if (builders.isEmpty) return const SizedBox.shrink();
      // Module-enabled panels exist but the user hid them all → offer an inline
      // way back rather than a blank void (mirrors the cards' empty-state link).
      return Align(
        alignment: Alignment.centerLeft,
        child: LinkText(
          label: context.tr('show_panels'),
          onTap: () => openManageDashboardCards(
            context,
            vm: _vm,
            initialTab: ManagePane.panels,
          ),
          style: const TextStyle(fontSize: 12.5),
        ),
      );
    }

    final columns = width >= 1200 ? 2 : 1;
    return _MultiColumnGrid(
      columns: columns,
      gap: InSpacing.lg(context),
      children: cards,
    );
  }
}

/// Simple column-balanced grid that places `children` left-to-right, top-to-
/// bottom into [columns] columns with `gap` between cells and rows. We use
/// this instead of `GridView` so each row can size itself to its tallest
/// card (cards have variable internal height).
class _MultiColumnGrid extends StatelessWidget {
  const _MultiColumnGrid({
    required this.columns,
    required this.gap,
    required this.children,
  });

  final int columns;
  final double gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final rowChildren = <Widget>[];
      for (var j = 0; j < columns; j++) {
        final idx = i + j;
        if (j > 0) rowChildren.add(SizedBox(width: gap));
        rowChildren.add(
          Expanded(
            child: idx < children.length
                ? children[idx]
                : const SizedBox.shrink(),
          ),
        );
      }
      if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rowChildren,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

/// Builds the deep-link [ListFilterIntent] for the Outstanding / Overdue KPI
/// cards. Extracted as a pure function so the period-window rule is unit
/// testable.
///
/// **Overdue** is an as-of-today metric (`due_date < today`), independent of
/// the dashboard's period window — exactly like the Past Due panel
/// (`DashboardApi.fetchPastDueInvoices` / `_pastDueInvoicesIntent`), which
/// sends `overdue=true` with no `date_range`. Carrying the period as a
/// `date_range` on the invoice *issue* date filtered the destination list
/// down to nothing (overdue invoices are old; their issue date rarely falls
/// inside "this month"), so the deep-link showed an empty list while a manual
/// `overdue:true` filter did not. Overdue therefore never carries a window.
///
/// **Outstanding** (`client_status=unpaid`) is period-scoped: it carries the
/// dashboard window as a closed `date,<start>,<end>` range unless the range is
/// the open-ended "all time" preset.
@visibleForTesting
ListFilterIntent buildInvoiceKpiIntent({
  required bool overdue,
  required bool isAllTimeRange,
  required Date start,
  required Date end,
}) {
  if (overdue) {
    return ListFilterIntent(
      extraFilters: const {
        'overdue': {'true'},
      },
      sortField: _DashboardScreenState._dueDateColumnId,
      sortAscending: true,
    );
  }
  return ListFilterIntent(
    extraFilters: {
      'client_status': const {'unpaid'},
      if (!isAllTimeRange)
        'date_range': {'date,${start.toIso()},${end.toIso()}'},
    },
  );
}

/// Most-specific deep-link for an activity row, or null for system-only
/// activities with no entity reference. Top-level (not a screen method) so the
/// route mapping is directly testable. Document refs precede the party
/// (client/vendor) fallbacks — an "invoice created" row should open the
/// invoice, not the client.
String? activityDeepLinkTarget(DashboardActivity a) {
  if (a.invoiceId != null) return '/invoices/${a.invoiceId}';
  if (a.quoteId != null) return '/quotes/${a.quoteId}';
  if (a.creditId != null) return '/credits/${a.creditId}';
  if (a.paymentId != null) return '/payments/${a.paymentId}';
  if (a.recurringInvoiceId != null) {
    return '/recurring_invoices/${a.recurringInvoiceId}';
  }
  if (a.expenseId != null) return '/expenses/${a.expenseId}';
  if (a.recurringExpenseId != null) {
    return '/recurring_expenses/${a.recurringExpenseId}';
  }
  if (a.taskId != null) return '/tasks/${a.taskId}';
  if (a.purchaseOrderId != null) return '/purchase_orders/${a.purchaseOrderId}';
  // Payment links live under settings but have a real detail screen.
  if (a.subscriptionId != null) {
    return '/settings/payment_links/${a.subscriptionId}';
  }
  if (a.vendorId != null) return '/vendors/${a.vendorId}';
  if (a.clientId != null) return '/clients/${a.clientId}';
  return null;
}
