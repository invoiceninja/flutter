import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_activity.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_card_config.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_list_rows.dart';
import 'package:admin/data/models/domain/invoice_status.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/list_status_tabs.dart' show kBadgeModeFilterKey;
import 'package:admin/domain/quick_create.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart'
    show findActionItem;
import 'package:admin/ui/core/list/deep_link_filter_intent.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/core/utils/fab_clearance.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/party_call_button.dart';
import 'package:admin/ui/features/activity/activity_deep_link.dart';
import 'package:admin/ui/features/dashboard/helpers/attention_record_verdict.dart';
import 'package:admin/ui/features/dashboard/helpers/card_deep_link.dart';
import 'package:admin/ui/features/dashboard/helpers/enabled_panel_kinds.dart';
import 'package:admin/ui/features/dashboard/helpers/needs_attention.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/billing_pipeline_card.dart';
import 'package:admin/ui/features/dashboard/widgets/activity_card.dart';
import 'package:admin/ui/features/dashboard/widgets/chart_card.dart';
import 'package:admin/ui/features/dashboard/widgets/configured_cards_grid.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_attention_slot.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_create_fab.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_mobile_app_bar.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_panel_grid.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_period_bar.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_top_bar.dart';
import 'package:admin/ui/features/dashboard/widgets/hidden_empty_panels_builder.dart';
import 'package:admin/ui/features/dashboard/widgets/kpi_row.dart';
import 'package:admin/ui/features/dashboard/widgets/manage_dashboard_cards_sheet.dart';
import 'package:admin/ui/features/dashboard/widgets/mobile_dashboard_body.dart';
import 'package:admin/ui/features/dashboard/widgets/needs_attention_band.dart';
import 'package:admin/ui/features/dashboard/widgets/recent_payments_card.dart';
import 'package:admin/ui/features/dashboard/widgets/section_listenable.dart';
import 'package:admin/ui/features/dashboard/widgets/task_calendar_card.dart';
import 'package:admin/ui/features/dashboard/widgets/upcoming_invoices_card.dart';
import 'package:admin/ui/features/dashboard/widgets/upcoming_quotes_card.dart';
import 'package:admin/ui/features/dashboard/widgets/upcoming_recurring_invoices_card.dart';
import 'package:admin/ui/features/invoices/widgets/invoice_actions.dart';
import 'package:admin/ui/features/quotes/widgets/quote_actions.dart';
import 'package:admin/ui/features/shell/widgets/app_drawer.dart';
import 'package:admin/utils/formatting.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Services _services;
  late DashboardViewModel _vm;
  late String _companyId;
  // Empty when the active company has neither a `displayName` nor a `name`.
  // Wide-layout only since flutter#50 — the mobile bar titles with the page
  // name now, so this feeds `DashboardTopBar` alone, and since flutter#51 a
  // phone never reaches that bar in either orientation. `_resolveCompanyName`
  // still falls back to the localized 'Dashboard' string at render time, so
  // an unnamed company degrades to a sensible header in the active locale.
  late String _rawCompanyName;
  Formatter? _formatter;

  /// Changes waiting on the user after failing to save — the band's first
  /// line. Built once per company, never in `build`: a stream made there is a
  /// new object each time and would re-subscribe on every rebuild.
  late Stream<int> _failedSaves;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    final session = _services.auth.session.value!;
    _companyId = session.currentCompanyId;
    _rawCompanyName = _rawNameFor(session.currentCompany);
    _failedSaves = _services.watchOutboxAttention(_companyId);
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
    // A completed Sync pass refetches the sections only this view model can
    // key (invoiceninja/flutter#162). Passed here, the single construction
    // site, so the company-switch rebuild in `_onSessionChanged` keeps it.
    resyncCompletions: _services.resync.lastCompletion,
    // A pushed server change refetches the same sections, rate-limited.
    realtimeRefreshes: _services.realtime.lastRefresh,
    // So does a change of the user's own leaving the outbox — a payment
    // entered from a past-due row must take that row off the page.
    outboxActive: _services.watchOutboxActive(_companyId),
    // The needs-attention band is built from three lists and has to leave out
    // the ones this company or user is not offered. Read live, so a module
    // switched on mid-session is seen on the next emission.
    panelEnabled: (kind) => _enabledPanels().contains(kind),
    // Sync best-effort: if the formatter is already cached (e.g. navigating
    // back to the dashboard) we get the real fiscal year immediately;
    // otherwise _loadFormatter pushes it in once it resolves.
    firstMonthOfYear:
        _services.formatterIfReady(_companyId)?.settings.firstMonthOfYear ?? 1,
  );

  /// The panels this company and user are offered — the one gate both bodies
  /// and the Customize sheet read (`enabledPanelKinds`).
  Set<String> _enabledPanels() {
    final me = _services.auth.session.value?.currentCompany;
    return enabledPanelKinds(
      moduleOn: (t) => me?.moduleEnabled(t) ?? false,
      can: (p) => me?.can(p) ?? false,
    );
  }

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
    if (s == null) return;
    if (s.currentCompanyId == _companyId) {
      // Same company, but the session is rebuilt when its modules,
      // permissions or name change. The create affordances and the panel
      // gates read those at build time, and nothing else rebuilds this
      // chrome, so a permission granted mid-session would otherwise leave
      // the `+` stale until the next company switch.
      setState(() => _rawCompanyName = _rawNameFor(s.currentCompany));
      return;
    }
    final oldVm = _vm;
    setState(() {
      _companyId = s.currentCompanyId;
      _rawCompanyName = _rawNameFor(s.currentCompany);
      _formatter = null;
      _failedSaves = _services.watchOutboxAttention(_companyId);
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
    '/activity',
  };

  /// True when [type]'s module is enabled for the active company. Gates a
  /// configured card's tap-through. The create affordances ask
  /// [_creatableEntities] instead, which also checks the create permission.
  bool _moduleOn(EntityType type) =>
      context
          .read<Services>()
          .auth
          .session
          .value
          ?.currentCompany
          ?.moduleEnabled(type) ??
      false;

  /// What the active user may create from the dashboard, in menu order
  /// (invoiceninja/flutter#164). Both layouts read this one gate. The narrow
  /// `+` sheet lists every entry, and the wide bar shows New Invoice only when
  /// invoices are on the list. So the two cannot disagree about who may start
  /// an invoice.
  List<EntityType> _creatableEntities() {
    final me = _services.auth.session.value?.currentCompany;
    final registry = _services.entityRegistry;
    return quickCreateEntities(
      hasCreateRoute: (t) => registry[t]?.newRoute != null,
      moduleOn: (t) => me?.moduleEnabled(t) ?? false,
      can: (p) => me?.can(p) ?? false,
    );
  }

  /// [creatable] as sheet entries, each with the icon its sidebar row wears.
  List<QuickCreateOption> _createOptions(List<EntityType> creatable) => [
    for (final type in creatable)
      QuickCreateOption(
        type: type,
        // Non-null: `_creatableEntities` only returns types that have a
        // registry entry with a create route.
        icon: _services.entityRegistry[type]!.effectiveOutlinedIcon,
      ),
  ];

  /// Opens a blank create screen for [type]. Both the `+` sheet and the wide
  /// bar's New Invoice button end up here.
  ///
  /// Every destination is in another shell branch. So this first runs the
  /// global dirty-form guard, as the sidebar's `+` and the create shortcuts
  /// do. Then it navigates with `goToCreateRoute` rather than a bare `go`. A
  /// bare `go` would reuse a create screen the branch still has mounted, which
  /// could still be seeded with, say, the client that an earlier New Invoice
  /// started from.
  Future<void> _create(EntityType type) async {
    final route = _services.entityRegistry[type]?.newRoute;
    if (route == null) return;
    if (!await _services.unsavedChangesGuard.confirmIfDirty(context)) return;
    if (!mounted) return;
    goToCreateRoute(context, route);
  }

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

  /// Upcoming invoices → unpaid invoices due today or later, soonest first:
  /// what the panel lists (the server's `upcoming`), as filters the invoice
  /// list can apply *and show as chips*. It used to open the whole invoice
  /// list sorted by due date, so "View all" on a panel of unpaid invoices led
  /// with paid and draft ones.
  ListFilterIntent get _upcomingInvoicesIntent => ListFilterIntent(
    extraFilters: {
      'status_id': {InvoiceStatus.sent.wireId, InvoiceStatus.partial.wireId},
      'due_date': {'gte:${_vm.today.toIso()}'},
    },
    sortField: _dueDateColumnId,
    sortAscending: true,
  );

  /// Upcoming quotes → sent quotes still valid today, soonest to lapse first.
  ListFilterIntent get _upcomingQuotesIntent => ListFilterIntent(
    extraFilters: {
      'client_status': const {'sent'},
      'due_date': {'gte:${_vm.today.toIso()}'},
    },
    sortField: _dueDateColumnId,
    sortAscending: true,
  );

  /// Upcoming recurring invoices → the list's own Active tab.
  ListFilterIntent get _activeRecurringIntent => ListFilterIntent(
    extraFilters: const {
      kBadgeModeFilterKey: {'active'},
    },
  );

  /// The band's "View all" for [tab]: the list of exactly what that tab
  /// counts. The two "soon" tabs carry the same seven-day window the band
  /// used (`kAttentionSoonDays`).
  void _viewAllAttention(AttentionTab tab) {
    final today = _vm.today;
    final window =
        'due_date,${today.toIso()},'
        '${today.addDays(kAttentionSoonDays).toIso()}';
    switch (tab) {
      case AttentionTab.pastDue:
        unawaited(_goWithIntent('/invoices', _pastDueInvoicesIntent));
      case AttentionTab.dueSoon:
        unawaited(
          _goWithIntent(
            '/invoices',
            ListFilterIntent(
              extraFilters: {
                'status_id': {
                  InvoiceStatus.sent.wireId,
                  InvoiceStatus.partial.wireId,
                },
                'due_date_range': {window},
              },
              sortField: _dueDateColumnId,
              sortAscending: true,
            ),
          ),
        );
      case AttentionTab.quotesExpiring:
        unawaited(
          _goWithIntent(
            '/quotes',
            ListFilterIntent(
              extraFilters: {
                'client_status': const {'sent'},
                'due_date_range': {window},
              },
              sortField: _dueDateColumnId,
              sortAscending: true,
            ),
          ),
        );
    }
  }

  /// Expired quotes → `client_status=expired` (server-backed, same param
  /// the panel uses).
  ListFilterIntent get _expiredQuotesIntent => ListFilterIntent(
    extraFilters: const {
      'client_status': {'expired'},
    },
  );

  /// Outstanding → every unpaid invoice. No date window: the figure is what
  /// is owed today, whenever it was invoiced, so the list it opens is too.
  ListFilterIntent _outstandingIntent() => buildInvoiceKpiIntent(
    overdue: false,
    isAllTimeRange: true,
    start: _vm.today,
    end: _vm.today,
  );

  /// Invoices → what the period's Invoices figure sums: sent, partial and paid
  /// invoices dated in the window (plus drafts when they are counted). The
  /// statuses are stated because the server leaves cancelled and reversed
  /// invoices out of the figure, and a bare date window would list them.
  ListFilterIntent _invoicedIntent() {
    final (start, end) = _vm.filter.resolveDates();
    return ListFilterIntent(
      extraFilters: {
        'status_id': {
          if (_vm.filter.includeDrafts) InvoiceStatus.draft.wireId,
          InvoiceStatus.sent.wireId,
          InvoiceStatus.partial.wireId,
          InvoiceStatus.paid.wireId,
        },
        if (!_isAllTimeRange)
          'date_range': {'date,${start.toIso()},${end.toIso()}'},
      },
    );
  }

  /// KPI "Paid" → payments with `client_status=completed` and the dashboard's
  /// date window as the canonical `date,<start>,<end>` (v5 unified
  /// `QueryFilters::date_range`).
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
          // Only when the destination has a faithful mapping at all.
          // `cardListTarget` deliberately returns `{}` for task / expense
          // cards ("No faithful expense list filter today → bare list"), and
          // neither list registers a date key or mirrors one locally — so
          // adding the window there produced a phantom filter: an unfiltered
          // list with the "clear filters" icon lit, persisted to `nav_state`,
          // permanently narrowing every later `ensurePageLoaded` (and on tasks
          // flipping `isNarrowedFetch` so the list stopped advancing its
          // cursor).
          if (t.extraFilters.isNotEmpty &&
              c.period == CardPeriod.current &&
              !_isAllTimeRange)
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
        // Pane width alone hands a landscape phone the desktop chrome: the
        // window is ~890 px there, so the persistent rail comes up and its 232
        // still leaves ~660 here — a company name this truncates plus five
        // full-label buttons that wrap onto two runs of a ~412 px-tall viewport
        // (flutter#51). A phone takes the narrow branch in either orientation,
        // so flutter#50's portrait fix applies in landscape too.
        final wide =
            Breakpoints.isWide(constraints) && !Breakpoints.isPhone(context);
        final globalNav = Breakpoints.isGlobalNavVisible(context);
        final creatable = _creatableEntities();
        // One list for both layouts: the narrow `+` opens a sheet of it, the
        // wide top bar shows as much of it as fits and puts the rest under
        // More. Neither can offer something the other does not.
        final createOptions = _createOptions(creatable);
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
              appBar: wide ? null : _buildMobileAppBar(globalNav: globalNav),
              // invoiceninja/flutter#164. This is the narrow dashboard's only
              // create affordance. It is left off when the user may create
              // nothing, rather than opening an empty sheet.
              floatingActionButton: wide || createOptions.isEmpty
                  ? null
                  : DashboardCreateFab(
                      options: createOptions,
                      onCreate: (type) => unawaited(_create(type)),
                    ),
              body: SafeArea(
                child: Column(
                  children: [
                    if (wide)
                      // Rebuilds on the VM's own notify (refresh state) and on
                      // the totals section, which carries how old the cached
                      // figures are — not as part of the static scaffold.
                      // Outside the formatter gate below: nothing in the bar
                      // needs one, and a create button must not wait on it.
                      ListenableBuilder(
                        listenable: Listenable.merge([
                          _vm,
                          _vm.listenableFor(DashboardKind.totalsCurrent),
                        ]),
                        builder: (context, _) => DashboardTopBar(
                          vm: _vm,
                          companyName: _resolveCompanyName(context),
                          onRefresh: () => unawaited(_refreshWithFeedback()),
                          createOptions: createOptions,
                          onCreate: (type) => unawaited(_create(type)),
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
                                      : _buildMobile(
                                          context,
                                          fabClearance: createOptions.isEmpty
                                              ? 0
                                              : kFabClearance,
                                        )),
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

  PreferredSizeWidget _buildMobileAppBar({required bool globalNav}) {
    return DashboardMobileAppBar(
      vm: _vm,
      // Suppressed once the persistent rail is up: the drawer is attached on
      // the same condition (see `drawer:` above), so an unguarded hamburger
      // would open nothing. This bar is picked from the *local* constraints
      // while the drawer follows *window* width, so the two disagree for a
      // window between 600 and ~832 px.
      showHamburger: !globalNav,
    );
  }

  Widget _buildMobile(BuildContext context, {required double fabClearance}) {
    return MobileDashboardBody(
      vm: _vm,
      formatter: _formatter!,
      fabClearance: fabClearance,
      showFigures: _showsFigures,
      attentionActions: _attentionActions(),
      failedSaves: _failedSaves,
      onReviewFailedSaves: () => _safeNavigate('/sync/outbox'),
      onAttentionViewAll: _viewAllAttention,
      onOpenCard: _openConfiguredCard,
      onInvoiceTap: _navInvoice,
      onAllUpcomingInvoices: () =>
          _goWithIntent('/invoices', _upcomingInvoicesIntent),
      onOutstandingTap: () => _goWithIntent('/invoices', _outstandingIntent()),
      onInvoicesTap: () => _goWithIntent('/invoices', _invoicedIntent()),
      onPaidTap: () => _goWithIntent('/payments', _paidPaymentsIntent),
      onActivityTap: _navActivity,
      onAllActivities: () => _safeNavigate('/activity'),
      onPaymentTap: _navPayment,
      onAllPayments: () => _safeNavigate('/payments'),
      onQuoteTap: _navQuote,
      onAllUpcomingQuotes: () =>
          _goWithIntent('/quotes', _upcomingQuotesIntent),
      onAllExpiredQuotes: () => _goWithIntent('/quotes', _expiredQuotesIntent),
      onRecurringTap: _navRecurring,
      onAllRecurring: () =>
          _goWithIntent('/recurring_invoices', _activeRecurringIntent),
      onShowPanels: () => openManageDashboardCards(
        context,
        vm: _vm,
        initialTab: ManagePane.panels,
      ),
    );
  }

  /// Whether the period figures, the metric cards and the chart are drawn.
  /// The server refuses the chart endpoints to a user without
  /// `view_dashboard`, so for them those sections could only ever show a
  /// retry; the band and the list panels are ordinary list requests and stay.
  bool get _showsFigures =>
      _services.auth.session.value?.currentCompany?.can('view_dashboard') ??
      false;

  bool _panelVisible(String kind) =>
      _vm.panelPrefs.any((p) => p.kind == kind && p.visible);

  // ─── Needs-attention band ──────────────────────────────────────────────

  /// What a band row may do for this user. Offered by module and permission
  /// here; the tap checks again against the record as it is by then.
  AttentionActions _attentionActions() {
    final session = _services.auth.session.value;
    final maySend = session?.currentCompany?.maySendEmails ?? false;
    final mayEnterPayment = _creatableEntities().contains(EntityType.payment);
    final quotesOn = _enabledPanels().contains(DashboardKind.upcomingQuotes);
    return AttentionActions(
      remindInvoice: (row) {
        final mayEdit =
            session?.canEditRecord(
              'invoice',
              createdBy: row.userId,
              assignedTo: row.assignedUserId,
              recordId: row.id,
            ) ??
            false;
        if (!maySend || !mayEdit) return null;
        return () => _actOnInvoice(row, InvoiceAction.sendEmail);
      },
      enterPayment: (row) => mayEnterPayment
          ? () => _actOnInvoice(row, InvoiceAction.enterPayment)
          : null,
      remindQuote: (row) {
        final mayEdit =
            session?.canEditRecord(
              'quote',
              createdBy: row.userId,
              assignedTo: row.assignedUserId,
              recordId: row.id,
            ) ??
            false;
        if (!quotesOn || !maySend || !mayEdit) return null;
        return () => _remindQuote(row);
      },
      // A slot is kept for the call button only where calling is switched on;
      // the button itself draws nothing for a client with no number.
      callButton: _services.phoneActions.value.tapToCall
          ? (context, clientId) => PartyCallButton(clientId: clientId)
          : null,
    );
  }

  /// Runs [action] on the invoice [row] names — on the invoice **as it is
  /// now**, not as the dashboard last listed it.
  ///
  /// The row is the server's past-due list, cached, while every action screen
  /// reads the local database — and the app loads invoices a page at a time, so
  /// an old overdue invoice is exactly the one that may never have been
  /// browsed to. Acting on the row meant a Send Email screen reading "No
  /// records found" and a payment form with a blank invoice. And between that
  /// fetch and this tap the invoice may have been paid. So: fetch it, look at
  /// it, then act or say why not.
  Future<void> _actOnInvoice(
    DashboardInvoiceRow row,
    InvoiceAction action,
  ) async {
    if (!await _services.unsavedChangesGuard.confirmIfDirty(context)) return;
    final companyId = _companyId;
    final vm = _vm;
    try {
      // Both swallow a failed fetch and leave whatever is cached, which is
      // what makes the offline case fall through to the verdict below.
      await _services.invoices.refreshByIds(
        companyId: companyId,
        ids: [row.id],
      );
      if (row.clientId.isNotEmpty) {
        await _services.clients.ensureLoaded(
          companyId: companyId,
          id: row.clientId,
        );
      }
    } catch (_) {
      // Decided by what is on the device.
    }
    final invoice = await _services.invoices
        .watch(companyId: companyId, id: row.id)
        .first;
    if (!mounted || companyId != _companyId) return;
    switch (invoiceVerdict(invoice)) {
      case AttentionVerdict.unavailable:
        Notify.warning(context, context.tr('connect_to_load_record'));
        return;
      case AttentionVerdict.resolved:
        Notify.info(context, context.tr('no_longer_owed'));
        unawaited(vm.refresh());
        return;
      case AttentionVerdict.act:
        break;
    }
    final item = findActionItem<InvoiceAction>(
      InvoiceActions.itemsFor(context, invoice!, (_) {}),
      action,
    );
    if (item == null || !item.enabled) {
      Notify.warning(context, context.tr('action_not_available'));
      return;
    }
    if (action == InvoiceAction.sendEmail) {
      // Open on the reminder, not on the "here is your invoice" email the
      // composer otherwise starts with.
      context.go(
        '/invoices/${invoice.id}/email?view=full'
        '&template=${nextInvoiceReminderTemplate(row)}',
      );
      return;
    }
    await InvoiceActions.dispatch(
      context,
      _services,
      companyId,
      invoice,
      action,
    );
  }

  /// A reminder for a quote about to lapse — see [_actOnInvoice].
  Future<void> _remindQuote(DashboardQuoteRow row) async {
    if (!await _services.unsavedChangesGuard.confirmIfDirty(context)) return;
    final companyId = _companyId;
    final vm = _vm;
    try {
      await _services.quotes.refreshByIds(companyId: companyId, ids: [row.id]);
      if (row.clientId.isNotEmpty) {
        await _services.clients.ensureLoaded(
          companyId: companyId,
          id: row.clientId,
        );
      }
    } catch (_) {
      // Decided by what is on the device.
    }
    final quote = await _services.quotes
        .watch(companyId: companyId, id: row.id)
        .first;
    if (!mounted || companyId != _companyId) return;
    switch (quoteVerdict(quote)) {
      case AttentionVerdict.unavailable:
        Notify.warning(context, context.tr('connect_to_load_record'));
        return;
      case AttentionVerdict.resolved:
        Notify.info(context, context.tr('no_longer_open_quote'));
        unawaited(vm.refresh());
        return;
      case AttentionVerdict.act:
        break;
    }
    final item = findActionItem<QuoteAction>(
      QuoteActions.itemsFor(context, quote!, (_) {}),
      QuoteAction.sendEmail,
    );
    if (item == null || !item.enabled) {
      Notify.warning(context, context.tr('action_not_available'));
      return;
    }
    context.go(
      '/quotes/${quote.id}/email?view=full&template=$kQuoteReminderTemplate',
    );
  }

  // Row navigation shared by the band and every list card. A row is one
  // target and opens its record; the client is a tap further on, from there.

  void _navInvoice(DashboardInvoiceRow row) =>
      _safeNavigate('/invoices/${row.id}');
  void _navPayment(DashboardPaymentRow row) =>
      _safeNavigate('/payments/${row.id}');
  void _navQuote(DashboardQuoteRow row) => _safeNavigate('/quotes/${row.id}');
  void _navRecurring(DashboardRecurringInvoiceRow row) =>
      _safeNavigate('/recurring_invoices/${row.id}');

  /// Resolve an activity row to its most-specific deep-link. Mirrors the
  /// precedence the activity-list page is expected to use when M2 lands.
  /// Rows that reference no entity (e.g. a system-only activity) silently
  /// do nothing — there's no per-activity detail screen.
  void _navActivity(DashboardActivity a) {
    final target = activityDeepLinkTarget(a);
    if (target == null) return;
    _safeNavigate(target);
  }

  /// The wide body, top to bottom: what needs attention now, then how the
  /// selected period went, then the panels.
  ///
  /// Two gaps, and they mean something: [InSpacing.lg] between things that
  /// belong together (the period controls and the figures they change), and
  /// [InSpacing.xl] between one zone and the next.
  Widget _buildScroll(BuildContext context, BoxConstraints outer) {
    final width = outer.maxWidth;
    final formatter = _formatter!;
    final enabled = _enabledPanels();
    final showFigures = _showsFigures;
    final expensesOn = _moduleOn(EntityType.expense);
    final zoneGap = const SizedBox(height: InSpacing.xl);
    final children = <Widget>[
      // First, and one child whether or not it draws — see
      // `DashboardAttentionSlot`.
      HiddenEmptyPanelsBuilder(
        vm: _vm,
        pref: _services.hideEmptyPanels,
        builder: (context, hidden) => ListenableBuilder(
          // Tap-to-call decides whether rows carry a call button.
          listenable: _services.phoneActions,
          builder: (context, _) => DashboardAttentionSlot(
            vm: _vm,
            formatter: formatter,
            show:
                enabled.contains(DashboardKind.pastDue) &&
                _panelVisible(DashboardKind.pastDue) &&
                !hidden.contains(DashboardKind.pastDue),
            compact: false,
            rowLimit: kAttentionRows,
            gap: InSpacing.xl,
            actions: _attentionActions(),
            failedSaves: _failedSaves,
            onReviewFailedSaves: () => _safeNavigate('/sync/outbox'),
            onInvoiceTap: _navInvoice,
            onQuoteTap: _navQuote,
            onViewAll: _viewAllAttention,
          ),
        ),
      ),
      if (showFigures) ...[
        // The controls that govern the figures and the chart, directly above
        // them. Reads the totals too (whether a second currency exists).
        sectionListenable(
          _vm.kpiListenable,
          () => DashboardPeriodBar(vm: _vm, formatter: formatter),
        ),
        SizedBox(height: InSpacing.lg(context)),
        sectionListenable(
          Listenable.merge([_vm.kpiListenable, _vm.attentionListenable]),
          () => KpiRow(
            vm: _vm,
            formatter: formatter,
            // The band's own count, so "4 past due" here and the tab above
            // can never disagree.
            pastDueCount:
                enabled.contains(DashboardKind.pastDue) &&
                    _vm.pastDue.data != null
                ? _vm.attention().pastDueCount
                : null,
            showExpenses: expensesOn,
            onOutstandingTap: () =>
                _goWithIntent('/invoices', _outstandingIntent()),
            onInvoicesTap: () => _goWithIntent('/invoices', _invoicedIntent()),
            onPaidTap: () => _goWithIntent('/payments', _paidPaymentsIntent),
          ),
        ),
        // One child either way, like the band: the cards and the gap above
        // them, or nothing.
        _vm.dashboardCards.isEmpty
            ? const SizedBox.shrink()
            : Padding(
                padding: EdgeInsets.only(top: InSpacing.lg(context)),
                child: ConfiguredCardsGrid(
                  vm: _vm,
                  formatter: formatter,
                  onManage: () => openManageDashboardCards(context, vm: _vm),
                  onOpenCard: _openConfiguredCard,
                ),
              ),
        SizedBox(height: InSpacing.lg(context)),
      ],
      _chartAndActivity(context, width, formatter, showChart: showFigures),
      zoneGap,
      _bottomGrid(context, width, formatter),
      // The freshness stamp + Refresh used to live here, at the very bottom of
      // the scroll; both now sit in the always-visible top bar (issue #26).
      zoneGap,
    ];

    return ListView(
      padding: const EdgeInsets.all(InSpacing.xl),
      children: children,
    );
  }

  Widget _chartAndActivity(
    BuildContext context,
    double width,
    Formatter formatter, {
    required bool showChart,
  }) {
    final activity = sectionListenable(
      _vm.listenableFor(DashboardKind.activities),
      () => ActivityCard(
        section: _vm.activities,
        onViewAll: () => _safeNavigate('/activity'),
        onRetry: () => _vm.retry(DashboardKind.activities),
        onActivityTap: _navActivity,
      ),
    );
    if (!showChart) return activity;
    final sideBySide = width >= 1024;
    final chart = sectionListenable(
      _vm.chartCardListenable,
      // Beside Activity the plot takes whatever height that card has, so the
      // two end on one line; stacked, it keeps its own proportions.
      () => ChartCard(vm: _vm, formatter: formatter, fillHeight: sideBySide),
    );
    if (sideBySide) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 17, child: chart),
            SizedBox(width: InSpacing.lg(context)),
            Expanded(
              flex: 10,
              child: DashboardPanelCell(stretched: true, child: activity),
            ),
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
    // Hide panels whose backing module (or permission) is unavailable for this
    // company. One shared gate — see `enabledPanelKinds`; the mobile body and
    // the manage sheet read the same set.
    final me = context.read<Services>().auth.session.value?.currentCompany;
    final enabled = enabledPanelKinds(
      moduleOn: (t) => me?.moduleEnabled(t) ?? false,
      can: (p) => me?.can(p) ?? false,
    );
    bool on(String kind) => enabled.contains(kind);
    final actions = _attentionActions();

    // Past-due is not here: it is the needs-attention band that leads the
    // page (`_buildScroll`), on this layout as on the narrow one.
    //
    // One builder per panel whose module is enabled; `DashboardPanelGrid`
    // renders them in the user's saved order (`_vm.panelPrefs`), skipping the
    // ones the user hid and the ones with nothing to show, and keys each with
    // a `GlobalKey` so a panel that changes row keeps its element — see that
    // widget for why the old per-card `ValueKey` never did.
    final builders = <String, Widget Function()>{
      if (on(DashboardKind.upcomingInvoices))
        DashboardKind.upcomingInvoices: () => sectionListenable(
          _vm.listenableFor(DashboardKind.upcomingInvoices),
          () => UpcomingInvoicesCard(
            section: _vm.upcomingInvoices,
            formatter: formatter,
            today: _vm.today,
            compact: false,
            onInvoiceTap: _navInvoice,
            onViewAll: () =>
                _goWithIntent('/invoices', _upcomingInvoicesIntent),
            onRetry: () => _vm.retry(DashboardKind.upcomingInvoices),
            enterPayment: actions.enterPayment,
          ),
        ),
      if (on(DashboardKind.recentPayments))
        DashboardKind.recentPayments: () => sectionListenable(
          _vm.listenableFor(DashboardKind.recentPayments),
          () => RecentPaymentsCard(
            section: _vm.recentPayments,
            formatter: formatter,
            compact: false,
            onPaymentTap: _navPayment,
            onViewAll: () => _safeNavigate('/payments'),
            onRetry: () => _vm.retry(DashboardKind.recentPayments),
          ),
        ),
      if (on(DashboardKind.upcomingQuotes))
        DashboardKind.upcomingQuotes: () => sectionListenable(
          _vm.listenableFor(DashboardKind.upcomingQuotes),
          () => UpcomingQuotesCard(
            section: _vm.upcomingQuotes,
            formatter: formatter,
            today: _vm.today,
            compact: false,
            onQuoteTap: _navQuote,
            onViewAll: () => _goWithIntent('/quotes', _upcomingQuotesIntent),
            onRetry: () => _vm.retry(DashboardKind.upcomingQuotes),
            remind: actions.remindQuote,
          ),
        ),
      if (on(DashboardKind.expiredQuotes))
        DashboardKind.expiredQuotes: () => sectionListenable(
          _vm.listenableFor(DashboardKind.expiredQuotes),
          () => ExpiredQuotesCard(
            section: _vm.expiredQuotes,
            formatter: formatter,
            compact: false,
            onQuoteTap: _navQuote,
            onViewAll: () => _goWithIntent('/quotes', _expiredQuotesIntent),
            onRetry: () => _vm.retry(DashboardKind.expiredQuotes),
          ),
        ),
      if (on(DashboardKind.upcomingRecurring))
        DashboardKind.upcomingRecurring: () => sectionListenable(
          _vm.listenableFor(DashboardKind.upcomingRecurring),
          () => UpcomingRecurringInvoicesCard(
            section: _vm.upcomingRecurring,
            formatter: formatter,
            compact: false,
            onRecurringTap: _navRecurring,
            onViewAll: () =>
                _goWithIntent('/recurring_invoices', _activeRecurringIntent),
            onRetry: () => _vm.retry(DashboardKind.upcomingRecurring),
          ),
        ),
      // Drift-backed, so no `sectionListenable` wrapper: the card owns its own
      // `ListenableBuilder` over a task view model, and there is no
      // `dashboard_cache` section for this kind to listen to.
      // Drift-backed, so no `sectionListenable` wrapper here either.
      if (on(DashboardKind.invoicesAndQuotes))
        DashboardKind.invoicesAndQuotes: () {
          final halves = billingPipelineHalves(
            moduleOn: (t) => me?.moduleEnabled(t) ?? false,
            can: (p) => me?.can(p) ?? false,
          );
          return DashboardBillingPipelineCard(
            companyId: _companyId,
            formatter: formatter,
            refreshNonce: _vm.panelRefreshNonce,
            narrow: false,
            includeInvoices: halves.invoices,
            includeQuotes: halves.quotes,
            initialTabId: _vm.billingTab,
            onTabChanged: _vm.setBillingTab,
          );
        },
      if (on(DashboardKind.taskCalendar))
        DashboardKind.taskCalendar: () => DashboardTaskCalendarCard(
          companyId: _companyId,
          formatter: formatter,
          refreshNonce: _vm.panelRefreshNonce,
        ),
    };

    // The builder is what rebuilds this grid when a panel empties or fills
    // (invoiceninja/flutter#161): a section emission only reaches its own
    // card, never the view model this method runs under. Wrapped always — even
    // with the preference off — so the grid's element, and the `GlobalKey`s it
    // owns, never change identity with the setting.
    return HiddenEmptyPanelsBuilder(
      vm: _vm,
      pref: _services.hideEmptyPanels,
      builder: (context, hidden) => DashboardPanelGrid(
        panelPrefs: _vm.panelPrefs,
        builders: builders,
        hidden: hidden,
        columns: width >= kDashboardTwoColumnPane ? 2 : 1,
        gap: InSpacing.lg(context),
        onShowPanels: () => openManageDashboardCards(
          context,
          vm: _vm,
          initialTab: ManagePane.panels,
        ),
      ),
    );
  }
}

/// Pane width from which the panels sit two to a row.
///
/// It was 1200 — a 1432 px window once the sidebar is counted — so a 1280 or
/// 1366 px laptop, the commonest desktop there is, stacked every panel full
/// width and the page ran to eight screens. A panel row is
/// `number · client | when | amount | action`; at this width each half-width
/// card has about 470 px, which holds that row at the app's largest text size
/// with the client name still readable.
const double kDashboardTwoColumnPane = 1000;

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
      // `status_id`, NOT `client_status`. The invoices list registers no
      // `client_status` key and `InvoiceRepository.watchPage` has no local
      // mirror for one (quotes / credits / payments / expenses all do), so it
      // narrowed the network fetch while the Drift watch the list actually
      // renders from ignored it: the user landed on an unfiltered list — paid,
      // draft and cancelled invoices included — with no chip explaining
      // anything and a lit "clear filters" icon, and the phantom filter then
      // persisted to `nav_state` and silently windowed every later page fetch.
      //
      // Sent + partial IS "unpaid" — the same definition `InvoiceDao`'s own
      // `unpaid` badge mode uses — and `status_id` renders as a real, removable
      // chip that the DAO mirrors locally.
      'status_id': {InvoiceStatus.sent.wireId, InvoiceStatus.partial.wireId},
      if (!isAllTimeRange)
        'date_range': {'date,${start.toIso()},${end.toIso()}'},
    },
  );
}
