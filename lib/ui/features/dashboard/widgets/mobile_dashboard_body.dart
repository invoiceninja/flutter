import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_activity.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_card_config.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_list_rows.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/ui/features/dashboard/helpers/converted_hint.dart';
import 'package:admin/ui/features/dashboard/helpers/enabled_panel_kinds.dart';
import 'package:admin/ui/features/dashboard/helpers/range_dates.dart';
import 'package:admin/ui/features/dashboard/helpers/totals_math.dart';
import 'package:admin/ui/features/dashboard/view_models/async_section.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/activity_card.dart';
import 'package:admin/ui/features/dashboard/widgets/billing_pipeline_card.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/dashboard/widgets/chart_card.dart';
import 'package:admin/ui/features/dashboard/widgets/configured_cards_grid.dart';
import 'package:admin/ui/features/dashboard/widgets/delta_chip.dart';
import 'package:admin/ui/features/dashboard/widgets/freshness.dart';
import 'package:admin/ui/features/dashboard/widgets/hidden_empty_panels_builder.dart';
import 'package:admin/ui/features/dashboard/widgets/list_card_skeleton.dart';
import 'package:admin/ui/features/dashboard/widgets/manage_dashboard_cards_sheet.dart';
import 'package:admin/ui/features/dashboard/widgets/mobile/dashboard_mobile_rows.dart';
import 'package:admin/ui/features/dashboard/widgets/section_listenable.dart';
import 'package:admin/ui/features/dashboard/widgets/task_calendar_card.dart';

/// Mobile (<600 px) dashboard body. The header follows `patterns.jsx:375-441`
/// — eyebrow → dark hero KPI → quick-action tiles → compact past-due table
/// — and is then followed by the same sections desktop renders (revenue
/// chart, activity feed, upcoming invoices, recent payments, upcoming /
/// expired quotes, upcoming recurring invoices), each laid out as a single-
/// column stack of mobile-friendly rows rather than the desktop multi-column
/// tables which overflow on phone widths.
class MobileDashboardBody extends StatelessWidget {
  const MobileDashboardBody({
    super.key,
    required this.vm,
    required this.formatter,
    required this.onOpenCard,
    required this.onPastDueInvoiceTap,
    required this.onAllInvoices,
    required this.onAllUpcomingInvoices,
    required this.onAddClient,
    required this.onLogExpense,
    required this.onReports,
    required this.onOutstandingTap,
    required this.onPaidTap,
    required this.onActivityTap,
    this.onAllActivities,
    required this.onUpcomingInvoiceTap,
    required this.onPaymentTap,
    required this.onAllPayments,
    required this.onQuoteTap,
    required this.onAllQuotes,
    required this.onRecurringTap,
    required this.onAllRecurring,
    required this.onShowPanels,
  });

  final DashboardViewModel vm;
  final Formatter formatter;

  /// Open the entity list relevant to a tapped configured card.
  final void Function(DashboardCardConfig) onOpenCard;
  final void Function(DashboardInvoiceRow) onPastDueInvoiceTap;

  /// "View all" on the past-due / "Needs your attention" section.
  final VoidCallback onAllInvoices;

  /// "View all" on the Upcoming Invoices card — distinct from
  /// [onAllInvoices] so each lands on its own filtered list.
  final VoidCallback onAllUpcomingInvoices;
  final VoidCallback onAddClient;
  final VoidCallback onLogExpense;
  final VoidCallback onReports;
  final VoidCallback onOutstandingTap;
  final VoidCallback onPaidTap;
  final void Function(DashboardActivity) onActivityTap;

  /// Opens the full company activity feed at `/activity`. Nullable only so a
  /// test can omit it — null still hides the "View all" link
  /// (see [ActivityCard.onViewAll]).
  final VoidCallback? onAllActivities;
  final void Function(DashboardInvoiceRow) onUpcomingInvoiceTap;
  final void Function(DashboardPaymentRow) onPaymentTap;
  final VoidCallback onAllPayments;
  final void Function(DashboardQuoteRow) onQuoteTap;
  final VoidCallback onAllQuotes;
  final void Function(DashboardRecurringInvoiceRow) onRecurringTap;
  final VoidCallback onAllRecurring;

  /// Opens Customize on its Panels tab — from the "N empty panels hidden"
  /// line, the one place a phone says that panels are being left out.
  final VoidCallback onShowPanels;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    // Module + permission gating through the one shared gate the wide body and
    // the manage sheet also read (`enabledPanelKinds`) — mobile previously
    // rendered these list cards unconditionally, and then briefly held a
    // hand-copied second gate.
    final me = context.read<Services>().auth.session.value?.currentCompany;
    final enabled = enabledPanelKinds(
      moduleOn: (t) => me?.moduleEnabled(t) ?? false,
      can: (p) => me?.can(p) ?? false,
    );
    // Named for the panel, not the module: this asks the shared gate the
    // precise question the pinned card needs, and stays correct if past-due
    // ever gains a permission gate of its own.
    final pastDueEnabled = enabled.contains(DashboardKind.pastDue);
    // `hidden` is the set of panels this device is leaving out because they
    // have nothing to show (invoiceninja/flutter#161) — on by default on a
    // phone. The builder is what rebuilds this list when a panel empties: a
    // section emission only reaches its own card.
    return HiddenEmptyPanelsBuilder(
      vm: vm,
      pref: context.read<Services>().hideEmptyPanels,
      builder: (context, hidden) => _list(
        context,
        tokens,
        enabled: enabled,
        pastDueEnabled: pastDueEnabled,
        hidden: hidden,
      ),
    );
  }

  Widget _list(
    BuildContext context,
    InTheme tokens, {
    required Set<String> enabled,
    required bool pastDueEnabled,
    required Set<String> hidden,
  }) {
    return ListView(
      padding: EdgeInsets.all(InSpacing.lg(context)),
      children: [
        _eyebrow(context, tokens),
        // The empty-state "add cards" link is dropped on mobile — the app bar
        // already has a dedicated Cards button. Only render the grid (and its
        // leading gap) once cards exist.
        ListenableBuilder(
          listenable: vm,
          builder: (context, _) => vm.dashboardCards.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: InSpacing.sm),
                    ConfiguredCardsGrid(
                      vm: vm,
                      formatter: formatter,
                      onManage: () => openManageDashboardCards(
                        context,
                        vm: vm,
                        mobileLayout: true,
                      ),
                      onOpenCard: onOpenCard,
                    ),
                  ],
                ),
        ),
        SizedBox(height: InSpacing.lg(context)),
        sectionListenable(vm.kpiListenable, () => _heroKpi(context, tokens)),
        SizedBox(height: InSpacing.lg(context)),
        _quickActions(context, tokens),
        SizedBox(height: InSpacing.lg(context)),
        // Past-due is pinned to the hero zone on mobile (its order slot is
        // ignored); shown only when visible + invoices enabled, and not while
        // it is hidden for having nothing to show. ONE child either way — card
        // and spacer together, or nothing: the list matches unkeyed children
        // by index, so a slot that came and went would shift the chart and the
        // activity card below it, and each shift rebuilds them from scratch.
        (pastDueEnabled &&
                _panelVisible(DashboardKind.pastDue) &&
                !hidden.contains(DashboardKind.pastDue))
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  sectionListenable(
                    vm.listenableFor(DashboardKind.pastDue),
                    () => _needsAttentionCard(context, tokens),
                  ),
                  SizedBox(height: InSpacing.lg(context)),
                ],
              )
            : const SizedBox.shrink(),
        sectionListenable(
          vm.chartCardListenable,
          () => ChartCard(vm: vm, formatter: formatter),
        ),
        SizedBox(height: InSpacing.lg(context)),
        sectionListenable(
          vm.listenableFor(DashboardKind.activities),
          () => ActivityCard(
            section: vm.activities,
            onViewAll: onAllActivities,
            onRetry: () => vm.retry(DashboardKind.activities),
            onActivityTap: onActivityTap,
          ),
        ),
        SizedBox(height: InSpacing.lg(context)),
        // Trailing list panels in the user's saved order (past-due excluded —
        // it's pinned above). Each visible, module-enabled panel emits its card
        // + a trailing spacer, so hiding one never orphans a gap — which is
        // also why nothing replaces the freshness stamp that used to close the
        // page here; it rides the eyebrow at the top now (issue #26), and the
        // ListView's own padding closes the bottom when every panel is hidden.
        ..._trailingPanels(context, tokens, enabled: enabled, hidden: hidden),
        _hiddenPanelsLink(context, enabled: enabled, hidden: hidden),
      ],
    );
  }

  /// "2 empty panels hidden", closing the page — the one hint a phone gives
  /// that "Hide empty panels" is leaving something out (invoiceninja/flutter#161).
  /// The preference is on by default here, so an upgraded user's empty panels
  /// simply vanish; this line is how they find out why, and it opens Customize
  /// on the Panels tab, where each hidden row says so and the switch lives.
  ///
  /// Counts only panels the user has switched on and that this company can
  /// show — a panel they switched off is absent for its own reason. Renders
  /// nothing when nothing is hidden, so it costs no space otherwise.
  Widget _hiddenPanelsLink(
    BuildContext context, {
    required Set<String> enabled,
    required Set<String> hidden,
  }) {
    final count = vm.panelPrefs
        .where(
          (p) =>
              p.visible && enabled.contains(p.kind) && hidden.contains(p.kind),
        )
        .length;
    if (count == 0) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: DashboardCardFooterLink(
        label: context.tr(
          count == 1
              ? 'empty_panels_hidden_count_singular'
              : 'empty_panels_hidden_count_plural',
          {'count': '$count'},
        ),
        onTap: onShowPanels,
        touchFloor: true,
      ),
    );
  }

  /// The trailing list panels (everything except the pinned past-due card) in
  /// the user's saved order. Each visible, module-enabled panel that is not
  /// [hidden] for having nothing to show emits its card (keyed by kind, which
  /// the `ListView` matches across reorders and hides) followed by a spacer,
  /// so hiding one never leaves a doubled gap.
  List<Widget> _trailingPanels(
    BuildContext context,
    InTheme tokens, {
    required Set<String> enabled,
    required Set<String> hidden,
  }) {
    // Each closure returns its widget ALREADY wrapped — the shape `_bottomGrid`
    // uses. Wrapping every panel in `sectionListenable` from the loop instead
    // only works while every panel is cache-backed: `listenableFor` happily
    // mints a notifier for a kind that has no section, so a Drift-backed panel
    // would hang off a `Listenable` that can never fire and read, wrongly, as
    // if it were fed by `dashboard_cache`.
    final builders = <String, Widget Function()>{
      DashboardKind.upcomingInvoices: () => sectionListenable(
        vm.listenableFor(DashboardKind.upcomingInvoices),
        () => _upcomingInvoicesCard(context, tokens),
      ),
      DashboardKind.recentPayments: () => sectionListenable(
        vm.listenableFor(DashboardKind.recentPayments),
        () => _recentPaymentsCard(context, tokens),
      ),
      DashboardKind.upcomingQuotes: () => sectionListenable(
        vm.listenableFor(DashboardKind.upcomingQuotes),
        () => _upcomingQuotesCard(context, tokens),
      ),
      DashboardKind.expiredQuotes: () => sectionListenable(
        vm.listenableFor(DashboardKind.expiredQuotes),
        () => _expiredQuotesCard(context, tokens),
      ),
      DashboardKind.upcomingRecurring: () => sectionListenable(
        vm.listenableFor(DashboardKind.upcomingRecurring),
        () => _upcomingRecurringCard(context, tokens),
      ),
      DashboardKind.invoicesAndQuotes: () {
        final me = context.read<Services>().auth.session.value?.currentCompany;
        final halves = billingPipelineHalves(
          moduleOn: (t) => me?.moduleEnabled(t) ?? false,
          can: (p) => me?.can(p) ?? false,
        );
        return DashboardBillingPipelineCard(
          companyId: vm.companyId,
          formatter: formatter,
          refreshNonce: vm.lastRefreshed,
          narrow: true,
          includeInvoices: halves.invoices,
          includeQuotes: halves.quotes,
          initialTabId: vm.billingTab,
          onTabChanged: vm.setBillingTab,
        );
      },
      DashboardKind.taskCalendar: () => DashboardTaskCalendarCard(
        companyId: vm.companyId,
        formatter: formatter,
        refreshNonce: vm.lastRefreshed,
      ),
    };
    final out = <Widget>[];
    for (final p in vm.panelPrefs) {
      final build = builders[p.kind];
      if (build == null) continue; // past-due / unknown → not a trailing panel
      if (!p.visible || !enabled.contains(p.kind)) continue;
      if (hidden.contains(p.kind)) continue;
      out.add(KeyedSubtree(key: ValueKey(p.kind), child: build()));
      out.add(SizedBox(height: InSpacing.lg(context)));
    }
    return out;
  }

  bool _panelVisible(String kind) =>
      vm.panelPrefs.any((p) => p.kind == kind && p.visible);

  // ---------------------------------------------------------------------------
  // Eyebrow

  /// `APR 1, 2026 — JUN 30, 2026 · UPDATED 12 MIN AGO`.
  ///
  /// The window leads because on a phone it appeared nowhere else — the AppBar
  /// carries a bare filter *icon* — so every figure below was scoped to a range
  /// the user couldn't see (flutter#37). It displaced `ACME CORPORATION ·
  /// DASHBOARD`, which cost nothing: the nav already says which page this is,
  /// and the company is a tap or two away in the drawer — the
  /// `CompanySwitcherButton` header on a multi-company account, and
  /// `SidebarCompanyFooterAction` on a single-company one (issue #104), which
  /// drops the header row for the space and spells the name out in the picker
  /// sheet it opens rather than in the drawer itself.
  /// (This used to point at the AppBar title for the company name; flutter#50
  /// retitled that bar to the page name, so the drawer is the sole surface.)
  ///
  /// One run in one voice, not a two-column row: on a 360 dp phone the content
  /// line is ~336 px and a full range (~186 px) plus the freshness stamp
  /// (~158 px) overruns it, so side-by-side would truncate the window on every
  /// handset at or below 375 dp. As a single string the ellipsis eats the
  /// freshness first, which is the right priority. No tappable Refresh here —
  /// `RefreshIndicator` already wraps the body and the AppBar has no room for a
  /// fifth action.
  Widget _eyebrow(BuildContext context, InTheme tokens) {
    return FreshnessTicker(
      builder: (context) => Text(
        '${dashboardRangeDates(context, vm.filter, formatter: formatter).toUpperCase()} · '
        '${freshnessText(context, lastRefreshed: vm.lastRefreshed, isRefreshing: vm.isAnyRefreshing).toUpperCase()}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: tokens.ink3,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero KPI — dark surface, Outstanding number + sparkline, 2 sub-KPIs.

  Widget _heroKpi(BuildContext context, InTheme tokens) {
    final currencyKey = selectedCurrencyKey(vm.filter.currencyId);
    final convertedHint = convertedToBaseCaption(
      context,
      selectedCurrencyId: vm.filter.currencyId,
      totals: vm.totals.data,
      formatter: formatter,
    );
    final current = selectCurrencyTotals(vm.totals.data, currencyKey);
    final previous = selectCurrencyTotals(vm.totalsPrevious.data, currencyKey);

    final outstanding = current?.outstandingAmount ?? Decimal.zero;
    final outstandingText = formatter.money(
      outstanding,
      currencyId: currencyKey,
    );
    final outstandingDelta = percentDelta(
      current?.outstandingAmount,
      previous?.outstandingAmount,
    );

    final unpaidCount = current?.outstandingCount ?? 0;

    final paidText = formatter.money(
      current?.revenuePaidToDate ?? Decimal.zero,
      currencyId: currencyKey,
    );

    final heroRadius = BorderRadius.circular(InRadii.r3);

    return Material(
      color: tokens.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: tokens.border),
        borderRadius: heroRadius,
      ),
      child: InkWell(
        onTap: onOutstandingTap,
        child: Padding(
          padding: EdgeInsets.all(InSpacing.lg(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.tr('outstanding'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                            color: tokens.ink3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          outstandingText,
                          style: moneyTextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.5,
                            color: tokens.ink,
                          ),
                        ),
                        if (convertedHint != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            convertedHint,
                            style: TextStyle(fontSize: 11, color: tokens.ink3),
                          ),
                        ],
                        if (outstandingDelta != null) ...[
                          const SizedBox(height: 4),
                          // Outstanding is "good when down": a rising balance
                          // renders red, a falling one green — same semantics
                          // as the desktop KPI. Reuse DeltaChip, don't hand-roll
                          // (the old version hardcoded green for both).
                          DeltaChip(
                            percent: outstandingDelta,
                            goodDirection: GoodDirection.down,
                            // Range-agnostic + localized, matching the chart
                            // card. "this month" misled for non-month ranges.
                            suffix: context.tr('vs_prior'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: InSpacing.lg(context)),
              Row(
                children: [
                  Expanded(
                    child: _subKpi(
                      context: context,
                      label: context.tr('unpaid'),
                      // Count of unpaid invoices in the period. The totals
                      // endpoint exposes only `outstanding_count` (no overdue
                      // count), so this is labeled "Unpaid" and drills to the
                      // same windowed-unpaid list as the Outstanding hero — the
                      // mislabeled "Overdue" number/drill-through disagreed (U7).
                      value: '$unpaidCount',
                      bg: tokens.surfaceAlt,
                      labelColor: tokens.ink3,
                      valueColor: tokens.ink,
                      onTap: onOutstandingTap,
                    ),
                  ),
                  SizedBox(width: InSpacing.sm),
                  Expanded(
                    child: _subKpi(
                      context: context,
                      // Range-agnostic, like its "Unpaid" sibling: the figure
                      // tracks the selected window, so a fixed "this month"
                      // heading lied for every other range (flutter#37). The
                      // window is stated once, in the eyebrow above.
                      label: context.tr('paid'),
                      value: paidText,
                      bg: tokens.surfaceAlt,
                      labelColor: tokens.ink3,
                      valueColor: tokens.ink,
                      onTap: onPaidTap,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _subKpi({
    required BuildContext context,
    required String label,
    required String value,
    required Color bg,
    required Color labelColor,
    required Color valueColor,
    VoidCallback? onTap,
  }) {
    final radius = BorderRadius.circular(10);
    final inner = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.md(context),
        vertical: InSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: labelColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: moneyTextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
    return Material(
      color: bg,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? inner
          : InkWell(onTap: onTap, borderRadius: radius, child: inner),
    );
  }

  // ---------------------------------------------------------------------------
  // Quick-actions grid — 2-3 tiles in a row.

  /// **There is deliberately no New Invoice tile** (flutter#52).
  /// `DashboardMobileAppBar` carries a pinned `+` to the same `/invoices/new`,
  /// gated on the same `moduleEnabled(EntityType.invoice)` flag — so the two
  /// always appeared and vanished together, and the bar's copy is the better
  /// one: an `AppBar` action stays reachable at any scroll position, while this
  /// row scrolls away with the page. Don't restore it without removing that
  /// action first.
  ///
  /// The row is variable-length by design — New Client and Reports are always
  /// on, expense is module-gated, so it renders 2 or 3 tiles and the
  /// `Expanded`s rebalance whatever is left.
  Widget _quickActions(BuildContext context, InTheme tokens) {
    final me = context.read<Services>().auth.session.value?.currentCompany;
    final actions = [
      _QuickAction(
        label: context.tr('new_client'),
        icon: Icons.person_add_alt_outlined,
        iconColor: tokens.ink2,
        onTap: onAddClient,
      ),
      if (me?.moduleEnabled(EntityType.expense) ?? false)
        _QuickAction(
          label: context.tr('new_expense'),
          icon: Icons.receipt_long_outlined,
          iconColor: tokens.ink2,
          onTap: onLogExpense,
        ),
      _QuickAction(
        label: context.tr('reports'),
        icon: Icons.insert_chart_outlined,
        iconColor: tokens.ink2,
        onTap: onReports,
      ),
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) SizedBox(width: InSpacing.sm),
            Expanded(child: _quickActionTile(tokens, actions[i])),
          ],
        ],
      ),
    );
  }

  Widget _quickActionTile(InTheme tokens, _QuickAction action) {
    return Tooltip(
      message: action.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(InRadii.r2),
        onTap: action.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: tokens.surface,
            border: Border.all(color: tokens.border),
            borderRadius: BorderRadius.circular(InRadii.r2),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: InSpacing.xs,
            vertical: InSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, size: 15, color: action.iconColor),
              const SizedBox(height: 6),
              Text(
                action.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                  color: tokens.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Needs-attention card — 3 rows max on mobile.

  Widget _needsAttentionCard(BuildContext context, InTheme tokens) {
    final today = Date.today();
    return _mobileListCard<DashboardInvoiceRow>(
      context: context,
      tokens: tokens,
      title: context.tr('needs_your_attention'),
      allLabel: context.tr('all_invoices'),
      onAllTap: onAllInvoices,
      section: vm.pastDue,
      emptyMessage: context.tr('all_caught_up'),
      onRetry: () => vm.retry(DashboardKind.pastDue),
      max: 3,
      rowBuilder: (row) => MobileInvoiceRow(
        row: row,
        formatter: formatter,
        today: today,
        onTap: () => onPastDueInvoiceTap(row),
        alwaysOverdue: true,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // List-card sections — single-column stacked rows that mirror the data each
  // desktop card shows, but in a layout that fits on a phone width.

  Widget _upcomingInvoicesCard(BuildContext context, InTheme tokens) {
    final today = Date.today();
    return _mobileListCard<DashboardInvoiceRow>(
      context: context,
      tokens: tokens,
      title: context.tr('upcoming_invoices'),
      allLabel: context.tr('all_invoices'),
      onAllTap: onAllUpcomingInvoices,
      section: vm.upcomingInvoices,
      onRetry: () => vm.retry(DashboardKind.upcomingInvoices),
      emptyMessage: context.tr('no_invoices_due_soon'),
      rowBuilder: (row) => MobileInvoiceRow(
        row: row,
        formatter: formatter,
        today: today,
        onTap: () => onUpcomingInvoiceTap(row),
      ),
    );
  }

  Widget _recentPaymentsCard(BuildContext context, InTheme tokens) {
    return _mobileListCard<DashboardPaymentRow>(
      context: context,
      tokens: tokens,
      title: context.tr('recent_payments'),
      allLabel: context.tr('all_payments'),
      onAllTap: onAllPayments,
      section: vm.recentPayments,
      onRetry: () => vm.retry(DashboardKind.recentPayments),
      emptyMessage: context.tr('no_payments_yet'),
      rowBuilder: (row) => MobilePaymentRow(
        row: row,
        formatter: formatter,
        onTap: () => onPaymentTap(row),
      ),
    );
  }

  Widget _upcomingQuotesCard(BuildContext context, InTheme tokens) {
    return _mobileListCard<DashboardQuoteRow>(
      context: context,
      tokens: tokens,
      title: context.tr('upcoming_quotes'),
      allLabel: context.tr('all_quotes'),
      onAllTap: onAllQuotes,
      section: vm.upcomingQuotes,
      onRetry: () => vm.retry(DashboardKind.upcomingQuotes),
      emptyMessage: context.tr('no_upcoming_quotes'),
      rowBuilder: (row) => MobileQuoteRow(
        row: row,
        formatter: formatter,
        expired: false,
        onTap: () => onQuoteTap(row),
      ),
    );
  }

  Widget _expiredQuotesCard(BuildContext context, InTheme tokens) {
    return _mobileListCard<DashboardQuoteRow>(
      context: context,
      tokens: tokens,
      title: context.tr('expired_quotes'),
      allLabel: context.tr('all_quotes'),
      onAllTap: onAllQuotes,
      section: vm.expiredQuotes,
      onRetry: () => vm.retry(DashboardKind.expiredQuotes),
      emptyMessage: context.tr('no_expired_quotes'),
      rowBuilder: (row) => MobileQuoteRow(
        row: row,
        formatter: formatter,
        expired: true,
        onTap: () => onQuoteTap(row),
      ),
    );
  }

  Widget _upcomingRecurringCard(BuildContext context, InTheme tokens) {
    return _mobileListCard<DashboardRecurringInvoiceRow>(
      context: context,
      tokens: tokens,
      title: context.tr('upcoming_recurring_invoices'),
      allLabel: context.tr('all_recurring_invoices'),
      onAllTap: onAllRecurring,
      section: vm.upcomingRecurring,
      onRetry: () => vm.retry(DashboardKind.upcomingRecurring),
      emptyMessage: context.tr('no_upcoming_recurring_invoices'),
      rowBuilder: (row) => MobileRecurringInvoiceRow(
        row: row,
        formatter: formatter,
        onTap: () => onRecurringTap(row),
      ),
    );
  }

  // Shared shell for the stacked list cards (past-due included): header
  // (title + optional "view all" link) → divider → a body chosen by
  // `ListSectionState`, the order the wide `DashboardListCard` and the view
  // model's `emptyPanels` share. The empty message renders only once the
  // section has loaded with no rows — it used to render for all three non-row
  // states, so a phone would flash "No upcoming quotes" before hiding the
  // panel, and a failed fetch read as "there are none" (flutter#161).
  //
  // Both non-row placeholders are compact, and deliberately so: this card
  // sits in a phone's single column, where a tall placeholder that collapses
  // on load moves everything below it.
  Widget _mobileListCard<T>({
    required BuildContext context,
    required InTheme tokens,
    required String title,
    required String allLabel,
    required VoidCallback onAllTap,
    required AsyncSection<List<T>> section,
    required String emptyMessage,
    required VoidCallback onRetry,
    required Widget Function(T) rowBuilder,
    int max = 5,
  }) {
    final state = section.listState;
    final hasRows = state == ListSectionState.rows;
    final List<T> rows = hasRows
        ? section.data!.take(max).toList(growable: false)
        : <T>[];
    final messagePadding = EdgeInsets.symmetric(
      horizontal: InSpacing.lg(context),
      vertical: InSpacing.xl,
    );
    final messageStyle = TextStyle(fontSize: 12.5, color: tokens.ink3);
    return DashboardCardShell(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: InSpacing.lg(context),
              vertical: InSpacing.md(context),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tokens.ink,
                    ),
                  ),
                ),
                if (hasRows)
                  GestureDetector(
                    onTap: onAllTap,
                    child: Text(
                      allLabel,
                      style: TextStyle(fontSize: 11.5, color: tokens.ink3),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: tokens.border),
          ...switch (state) {
            ListSectionState.rows => [
              for (var i = 0; i < rows.length; i++) ...[
                rowBuilder(rows[i]),
                if (i < rows.length - 1)
                  Divider(height: 1, thickness: 1, color: tokens.border),
              ],
            ],
            // Inline rather than `ErrorView`: that centres a 56 px icon and a
            // padded button in a scroll view, which needs ~240 px — in a fixed
            // box it clipped Retry out of sight and swallowed pull-to-refresh.
            ListSectionState.failed => [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  InSpacing.lg(context),
                  InSpacing.lg(context),
                  InSpacing.lg(context),
                  InSpacing.sm,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.tr('couldnt_load_tap_to_retry', {
                        'section': title.toLowerCase(),
                      }),
                      textAlign: TextAlign.center,
                      style: messageStyle,
                    ),
                    TextButton(
                      onPressed: onRetry,
                      child: Text(context.tr('retry')),
                    ),
                  ],
                ),
              ),
            ],
            // One row, padded to the empty message's height — the skeleton
            // row is 46 px, and 46 + 2×10 matches `messagePadding`'s 48 plus
            // one 12.5 px line — so a card that loads empty keeps its height,
            // and one hidden for being empty takes a card's worth of space
            // with it rather than a three-row skeleton's.
            ListSectionState.loading => [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: InSpacing.lg(context),
                  vertical: 10,
                ),
                child: const ListCardSkeleton(rowCount: 1),
              ),
            ],
            ListSectionState.empty => [
              Padding(
                padding: messagePadding,
                child: Text(
                  emptyMessage,
                  textAlign: TextAlign.center,
                  style: messageStyle,
                ),
              ),
            ],
          },
        ],
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
}
