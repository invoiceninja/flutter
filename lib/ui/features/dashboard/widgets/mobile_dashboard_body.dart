import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_activity.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_card_config.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_list_rows.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/ui/features/dashboard/helpers/totals_math.dart';
import 'package:admin/ui/features/dashboard/view_models/async_section.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/activity_card.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/dashboard/widgets/chart_card.dart';
import 'package:admin/ui/features/dashboard/widgets/configured_cards_grid.dart';
import 'package:admin/ui/features/dashboard/widgets/delta_chip.dart';
import 'package:admin/ui/features/dashboard/widgets/freshness_label.dart';
import 'package:admin/ui/features/dashboard/widgets/manage_dashboard_cards_sheet.dart';
import 'package:admin/ui/features/dashboard/widgets/mobile/dashboard_mobile_rows.dart';
import 'package:admin/ui/features/dashboard/widgets/section_listenable.dart';

/// Mobile (<600 px) dashboard body. The header follows `patterns.jsx:375-441`
/// — eyebrow → dark hero KPI → 4 quick-action tiles → compact past-due table
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
    required this.companyName,
    required this.onOpenCard,
    required this.onPastDueInvoiceTap,
    required this.onAllInvoices,
    required this.onAllUpcomingInvoices,
    required this.onNewInvoice,
    required this.onAddClient,
    required this.onLogExpense,
    required this.onReports,
    required this.onOutstandingTap,
    required this.onOverdueTap,
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
  });

  final DashboardViewModel vm;
  final Formatter formatter;
  final String companyName;

  /// Open the entity list relevant to a tapped configured card.
  final void Function(DashboardCardConfig) onOpenCard;
  final void Function(DashboardInvoiceRow) onPastDueInvoiceTap;

  /// "View all" on the past-due / "Needs your attention" section.
  final VoidCallback onAllInvoices;

  /// "View all" on the Upcoming Invoices card — distinct from
  /// [onAllInvoices] so each lands on its own filtered list.
  final VoidCallback onAllUpcomingInvoices;
  final VoidCallback onNewInvoice;
  final VoidCallback onAddClient;
  final VoidCallback onLogExpense;
  final VoidCallback onReports;
  final VoidCallback onOutstandingTap;
  final VoidCallback onOverdueTap;
  final VoidCallback onPaidTap;
  final void Function(DashboardActivity) onActivityTap;

  /// Null hides the activity feed's "View all" link — there is no
  /// activities screen to route to (see [ActivityCard.onViewAll]).
  final VoidCallback? onAllActivities;
  final void Function(DashboardInvoiceRow) onUpcomingInvoiceTap;
  final void Function(DashboardPaymentRow) onPaymentTap;
  final VoidCallback onAllPayments;
  final void Function(DashboardQuoteRow) onQuoteTap;
  final VoidCallback onAllQuotes;
  final void Function(DashboardRecurringInvoiceRow) onRecurringTap;
  final VoidCallback onAllRecurring;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    // Module gating, mirroring desktop (`_bottomGrid`) — mobile previously
    // rendered these list cards unconditionally.
    final me = context.read<Services>().auth.session.value?.currentCompany;
    bool moduleOn(EntityType t) => me?.moduleEnabled(t) ?? false;
    final invoicesOn = moduleOn(EntityType.invoice);
    final trailingEnabled = <String>{
      if (invoicesOn) DashboardKind.upcomingInvoices,
      if (moduleOn(EntityType.payment)) DashboardKind.recentPayments,
      if (moduleOn(EntityType.quote)) DashboardKind.upcomingQuotes,
      if (moduleOn(EntityType.quote)) DashboardKind.expiredQuotes,
      if (moduleOn(EntityType.recurringInvoice))
        DashboardKind.upcomingRecurring,
    };
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
                      onManage: () => openManageDashboardCards(context, vm: vm),
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
        // ignored); shown only when visible + invoices enabled. Card + spacer
        // gate together so hiding it leaves no orphan gap before the chart.
        if (invoicesOn && _panelVisible(DashboardKind.pastDue)) ...[
          sectionListenable(
            vm.listenableFor(DashboardKind.pastDue),
            () => _needsAttentionCard(context, tokens),
          ),
          SizedBox(height: InSpacing.lg(context)),
        ],
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
        // + a trailing spacer, so hiding one never orphans a gap.
        ..._trailingPanels(context, tokens, trailingEnabled),
        Align(
          alignment: Alignment.centerRight,
          child: FreshnessLabel(
            lastRefreshed: vm.lastRefreshed,
            isRefreshing: vm.isAnyRefreshing,
            onRefresh: vm.refresh,
          ),
        ),
        SizedBox(height: InSpacing.lg(context)),
      ],
    );
  }

  /// The trailing list panels (everything except the pinned past-due card) in
  /// the user's saved order. Each visible, module-enabled panel emits its card
  /// (keyed by kind for stable element identity across reorders) followed by a
  /// spacer, so hiding one never leaves a doubled gap.
  List<Widget> _trailingPanels(
    BuildContext context,
    InTheme tokens,
    Set<String> enabled,
  ) {
    final builders = <String, Widget Function()>{
      DashboardKind.upcomingInvoices: () =>
          _upcomingInvoicesCard(context, tokens),
      DashboardKind.recentPayments: () => _recentPaymentsCard(context, tokens),
      DashboardKind.upcomingQuotes: () => _upcomingQuotesCard(context, tokens),
      DashboardKind.expiredQuotes: () => _expiredQuotesCard(context, tokens),
      DashboardKind.upcomingRecurring: () =>
          _upcomingRecurringCard(context, tokens),
    };
    final out = <Widget>[];
    for (final p in vm.panelPrefs) {
      final build = builders[p.kind];
      if (build == null) continue; // past-due / unknown → not a trailing panel
      if (!p.visible || !enabled.contains(p.kind)) continue;
      out.add(
        KeyedSubtree(
          key: ValueKey(p.kind),
          child: sectionListenable(vm.listenableFor(p.kind), build),
        ),
      );
      out.add(SizedBox(height: InSpacing.lg(context)));
    }
    return out;
  }

  bool _panelVisible(String kind) =>
      vm.panelPrefs.any((p) => p.kind == kind && p.visible);

  // ---------------------------------------------------------------------------
  // Eyebrow

  Widget _eyebrow(BuildContext context, InTheme tokens) {
    return Text(
      '${companyName.toUpperCase()} · ${context.tr('dashboard').toUpperCase()}',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: tokens.ink3,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero KPI — dark surface, Outstanding number + sparkline, 2 sub-KPIs.

  Widget _heroKpi(BuildContext context, InTheme tokens) {
    final isAll = vm.filter.currencyId == kDashboardCurrencyAll;
    final currencyKey = isAll ? null : vm.filter.currencyId.toString();
    final baseCode =
        formatter.currencies[formatter.settings.currencyId]?.code ?? '';
    final convertedHint = isAll && baseCode.isNotEmpty
        ? context.tr('converted_to_currency', {'currency': baseCode})
        : null;
    final current = selectCurrencyTotals(vm.totals.data, currencyKey);
    final previous = selectCurrencyTotals(vm.totalsPrevious.data, currencyKey);

    final outstanding = current?.outstandingAmount ?? Decimal.zero;
    final outstandingText = formatter.money(outstanding);
    final outstandingDelta = percentDelta(
      current?.outstandingAmount,
      previous?.outstandingAmount,
    );

    final overdueCount = current?.outstandingCount ?? 0;

    final paidText = formatter.money(
      current?.revenuePaidToDate ?? Decimal.zero,
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
                      label: context.tr('overdue'),
                      // Count only — matches the desktop "Overdue" KPI. The
                      // totals endpoint exposes no separate overdue amount, so
                      // showing the outstanding $ here just duplicated the hero.
                      value: '$overdueCount',
                      bg: tokens.surfaceAlt,
                      labelColor: tokens.ink3,
                      valueColor: tokens.ink,
                      onTap: onOverdueTap,
                    ),
                  ),
                  SizedBox(width: InSpacing.sm),
                  Expanded(
                    child: _subKpi(
                      context: context,
                      label: context.tr('paid_this_month'),
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
  // Quick-actions grid — 4 tiles in a row.

  Widget _quickActions(BuildContext context, InTheme tokens) {
    final me = context.read<Services>().auth.session.value?.currentCompany;
    final actions = [
      if (me?.moduleEnabled(EntityType.invoice) ?? false)
        _QuickAction(
          label: context.tr('new_invoice'),
          icon: Icons.add,
          iconColor: tokens.accent,
          onTap: onNewInvoice,
        ),
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
    final section = vm.pastDue;
    final hasRows = section.hasData && (section.data?.isNotEmpty ?? false);
    final rows = hasRows
        ? section.data!.take(3).toList(growable: false)
        : const <DashboardInvoiceRow>[];
    final today = Date.today();
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
                    context.tr('needs_your_attention'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tokens.ink,
                    ),
                  ),
                ),
                if (hasRows)
                  GestureDetector(
                    onTap: onAllInvoices,
                    child: Text(
                      context.tr('all_invoices'),
                      style: TextStyle(fontSize: 11.5, color: tokens.ink3),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: tokens.border),
          if (hasRows)
            for (var i = 0; i < rows.length; i++) ...[
              MobileInvoiceRow(
                row: rows[i],
                formatter: formatter,
                today: today,
                onTap: () => onPastDueInvoiceTap(rows[i]),
                alwaysOverdue: true,
              ),
              if (i < rows.length - 1)
                Divider(height: 1, thickness: 1, color: tokens.border),
            ]
          else
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: InSpacing.lg(context),
                vertical: InSpacing.xl,
              ),
              child: Text(
                context.tr('all_caught_up'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: tokens.ink3),
              ),
            ),
        ],
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
      emptyMessage: context.tr('no_upcoming_recurring_invoices'),
      rowBuilder: (row) => MobileRecurringInvoiceRow(
        row: row,
        formatter: formatter,
        onTap: () => onRecurringTap(row),
      ),
    );
  }

  // Shared shell for the stacked list cards: header (title + optional "view
  // all" link) → divider → up to [max] rows separated by dividers, or a
  // centered empty message. Matches the pattern of `_needsAttentionCard`.
  Widget _mobileListCard<T>({
    required BuildContext context,
    required InTheme tokens,
    required String title,
    required String allLabel,
    required VoidCallback onAllTap,
    required AsyncSection<List<T>> section,
    required String emptyMessage,
    required Widget Function(T) rowBuilder,
    int max = 5,
  }) {
    final hasRows = section.hasData && (section.data?.isNotEmpty ?? false);
    final List<T> rows = hasRows
        ? section.data!.take(max).toList(growable: false)
        : <T>[];
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
          if (hasRows)
            for (var i = 0; i < rows.length; i++) ...[
              rowBuilder(rows[i]),
              if (i < rows.length - 1)
                Divider(height: 1, thickness: 1, color: tokens.border),
            ]
          else
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: InSpacing.lg(context),
                vertical: InSpacing.xl,
              ),
              child: Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: tokens.ink3),
              ),
            ),
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
