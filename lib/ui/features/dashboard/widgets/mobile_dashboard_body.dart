import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_activity.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_card_config.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_list_rows.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/ui/features/dashboard/helpers/enabled_panel_kinds.dart';
import 'package:admin/ui/features/dashboard/helpers/needs_attention.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/activity_card.dart';
import 'package:admin/ui/features/dashboard/widgets/billing_pipeline_card.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/dashboard/widgets/chart_card.dart';
import 'package:admin/ui/features/dashboard/widgets/configured_cards_grid.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_attention_slot.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_period_bar.dart';
import 'package:admin/ui/features/dashboard/widgets/hidden_empty_panels_builder.dart';
import 'package:admin/ui/features/dashboard/widgets/kpi_row.dart';
import 'package:admin/ui/features/dashboard/widgets/manage_dashboard_cards_sheet.dart';
import 'package:admin/ui/features/dashboard/widgets/needs_attention_band.dart';
import 'package:admin/ui/features/dashboard/widgets/recent_payments_card.dart';
import 'package:admin/ui/features/dashboard/widgets/section_listenable.dart';
import 'package:admin/ui/features/dashboard/widgets/task_calendar_card.dart';
import 'package:admin/ui/features/dashboard/widgets/upcoming_invoices_card.dart';
import 'package:admin/ui/features/dashboard/widgets/upcoming_quotes_card.dart';
import 'package:admin/ui/features/dashboard/widgets/upcoming_recurring_invoices_card.dart';

/// Narrow dashboard body — a phone in either orientation, or a pane under
/// 600 px.
///
/// Top to bottom: **what needs attention**, then **what is outstanding** and
/// how the selected period went, the user's own metric cards, the chart, the
/// list panels in their saved order, and the activity feed.
///
/// The band leads. It used to sit third, under the user's metric cards — one
/// to a row at 140 px each, so three cards put the overdue invoices about
/// 690 px down, off the first screen of the device most likely to be glanced
/// at between jobs.
///
/// **The period controls are in the page**, between Outstanding and the
/// figures they change (`DashboardPeriodBar`). They were a funnel and a cog in
/// the app bar, and the range was shown as an untappable line of small
/// capitals at the top of this list.
///
/// **There are no quick-action tiles** (invoiceninja/flutter#164): creating is
/// the screen's `+` sheet (`DashboardCreateFab`), which stays on screen while
/// the page scrolls.
/// Rows a list panel shows on the narrow layout.
const int _kNarrowPanelRows = 3;

class MobileDashboardBody extends StatelessWidget {
  const MobileDashboardBody({
    super.key,
    required this.vm,
    required this.formatter,
    this.fabClearance = 0,
    this.showFigures = true,
    this.attentionActions = AttentionActions.none,
    this.failedSaves,
    this.onReviewFailedSaves,
    required this.onAttentionViewAll,
    required this.onOpenCard,
    required this.onInvoiceTap,
    required this.onAllUpcomingInvoices,
    required this.onOutstandingTap,
    required this.onInvoicesTap,
    required this.onPaidTap,
    required this.onActivityTap,
    this.onAllActivities,
    required this.onPaymentTap,
    required this.onAllPayments,
    required this.onQuoteTap,
    required this.onAllUpcomingQuotes,
    required this.onAllExpiredQuotes,
    required this.onRecurringTap,
    required this.onAllRecurring,
    required this.onShowPanels,
  });

  final DashboardViewModel vm;
  final Formatter formatter;

  /// Extra bottom padding, so the last panel can scroll clear of the screen's
  /// `+` button. The screen passes `kFabClearance` when it shows the
  /// button and 0 when it doesn't.
  final double fabClearance;

  /// Whether the period figures, the metric cards and the chart are drawn —
  /// false for a user without `view_dashboard`, whom the server refuses those
  /// endpoints. The band and the list panels are unaffected.
  final bool showFigures;

  /// What the band's rows may do — see `AttentionActions`.
  final AttentionActions attentionActions;

  /// Changes that failed to save, as a count; null draws no alert line. Must
  /// be a stream built once by the host.
  final Stream<int>? failedSaves;
  final VoidCallback? onReviewFailedSaves;

  /// The band's "View all" for the selected tab.
  final void Function(AttentionTab tab) onAttentionViewAll;

  /// Open the entity list relevant to a tapped configured card.
  final void Function(DashboardCardConfig) onOpenCard;

  /// A tap on an invoice row, in the band or the Upcoming Invoices card.
  final void Function(DashboardInvoiceRow) onInvoiceTap;

  /// "View all" on the Upcoming Invoices card.
  final VoidCallback onAllUpcomingInvoices;
  final VoidCallback onOutstandingTap;

  /// A tap on the period's Invoices figure.
  final VoidCallback onInvoicesTap;
  final VoidCallback onPaidTap;
  final void Function(DashboardActivity) onActivityTap;

  /// Opens the full company activity feed at `/activity`. Nullable only so a
  /// test can omit it — null still hides the "View all" link
  /// (see [ActivityCard.onViewAll]).
  final VoidCallback? onAllActivities;
  final void Function(DashboardPaymentRow) onPaymentTap;
  final VoidCallback onAllPayments;
  final void Function(DashboardQuoteRow) onQuoteTap;

  /// "View all" on the Upcoming Quotes and Expired Quotes cards — two lists,
  /// so two destinations.
  final VoidCallback onAllUpcomingQuotes;
  final VoidCallback onAllExpiredQuotes;
  final void Function(DashboardRecurringInvoiceRow) onRecurringTap;
  final VoidCallback onAllRecurring;

  /// Opens Customize on its Panels tab — from the "N empty panels hidden"
  /// line, the one place a phone says that panels are being left out.
  final VoidCallback onShowPanels;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    // Module + permission gating through the one shared gate the wide body and
    // the manage sheet also read (`enabledPanelKinds`).
    final me = context.read<Services>().auth.session.value?.currentCompany;
    final enabled = enabledPanelKinds(
      moduleOn: (t) => me?.moduleEnabled(t) ?? false,
      can: (p) => me?.can(p) ?? false,
    );
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
        hidden: hidden,
        expensesOn: me?.moduleEnabled(EntityType.expense) ?? false,
      ),
    );
  }

  Widget _list(
    BuildContext context,
    InTheme tokens, {
    required Set<String> enabled,
    required Set<String> hidden,
    required bool expensesOn,
  }) {
    final gutter = InSpacing.lg(context);
    final pastDueOn = enabled.contains(DashboardKind.pastDue);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        gutter,
        gutter,
        gutter,
        gutter + fabClearance,
      ),
      children: [
        // The band leads, and it is ONE child either way — band and gap, or a
        // zero-size box: the list matches unkeyed children by index, so a slot
        // that came and went would shift, and rebuild, everything below it.
        // Past-due's order slot is ignored; only its show / hide switch counts.
        DashboardAttentionSlot(
          vm: vm,
          formatter: formatter,
          show:
              pastDueOn &&
              _panelVisible(DashboardKind.pastDue) &&
              !hidden.contains(DashboardKind.pastDue),
          compact: true,
          rowLimit: kAttentionRows,
          gap: InSpacing.lg(context),
          actions: attentionActions,
          failedSaves: failedSaves,
          onReviewFailedSaves: onReviewFailedSaves,
          onInvoiceTap: onInvoiceTap,
          onQuoteTap: onQuoteTap,
          onViewAll: onAttentionViewAll,
        ),
        if (showFigures) ...[
          sectionListenable(
            Listenable.merge([vm.kpiListenable, vm.attentionListenable]),
            () => buildOutstandingCard(
              context,
              vm: vm,
              formatter: formatter,
              pastDueCount: pastDueOn && vm.pastDue.data != null
                  ? vm.attention().pastDueCount
                  : null,
              onTap: onOutstandingTap,
              valueFontSize: 30,
            ),
          ),
          SizedBox(height: InSpacing.lg(context)),
          // The controls for the figures and the chart, directly above them.
          // Rebuilt by the screen's global notify (the filter) and by the
          // totals (whether there is a second currency to offer).
          sectionListenable(
            vm.kpiListenable,
            () =>
                DashboardPeriodBar(vm: vm, formatter: formatter, compact: true),
          ),
          SizedBox(height: InSpacing.md(context)),
          sectionListenable(
            vm.kpiListenable,
            () => buildPeriodCard(
              context,
              vm: vm,
              formatter: formatter,
              showExpenses: expensesOn,
              onInvoicesTap: onInvoicesTap,
              onPaidTap: onPaidTap,
              valueFontSize: 16,
            ),
          ),
          SizedBox(height: InSpacing.lg(context)),
          // The user's own metric cards. One child either way — see the band.
          ListenableBuilder(
            listenable: vm,
            builder: (context, _) => vm.dashboardCards.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: EdgeInsets.only(bottom: InSpacing.lg(context)),
                    child: ConfiguredCardsGrid(
                      vm: vm,
                      formatter: formatter,
                      onManage: () => openManageDashboardCards(context, vm: vm),
                      onOpenCard: onOpenCard,
                    ),
                  ),
          ),
          sectionListenable(
            vm.chartCardListenable,
            () => ChartCard(vm: vm, formatter: formatter),
          ),
          SizedBox(height: InSpacing.lg(context)),
        ],
        // The list panels in the user's saved order (past-due excluded — it is
        // the band above). Each visible, module-enabled panel emits its card +
        // a trailing spacer, so hiding one never orphans a gap.
        ..._trailingPanels(context, tokens, enabled: enabled, hidden: hidden),
        _hiddenPanelsLink(context, enabled: enabled, hidden: hidden),
        // Last: a feed of what already happened is the least urgent thing on
        // the page, and it used to sit above every panel.
        sectionListenable(
          vm.listenableFor(DashboardKind.activities),
          () => ActivityCard(
            section: vm.activities,
            onViewAll: onAllActivities,
            onRetry: () => vm.retry(DashboardKind.activities),
            onActivityTap: onActivityTap,
          ),
        ),
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
    return Padding(
      // It carries its own gap, like a panel: the activity feed follows, and a
      // line that came and went would otherwise leave it hard against it.
      padding: EdgeInsets.only(bottom: InSpacing.lg(context)),
      child: Align(
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
      // The same cards the wide grid uses, in their stacked form: one row
      // grammar and one set of states on both layouts. Three rows rather than
      // five — on a phone each row is two lines, and "View all" is one tap.
      DashboardKind.upcomingInvoices: () => sectionListenable(
        vm.listenableFor(DashboardKind.upcomingInvoices),
        () => UpcomingInvoicesCard(
          section: vm.upcomingInvoices,
          formatter: formatter,
          today: vm.today,
          compact: true,
          preview: _kNarrowPanelRows,
          onInvoiceTap: onInvoiceTap,
          onViewAll: onAllUpcomingInvoices,
          onRetry: () => vm.retry(DashboardKind.upcomingInvoices),
          enterPayment: attentionActions.enterPayment,
        ),
      ),
      DashboardKind.recentPayments: () => sectionListenable(
        vm.listenableFor(DashboardKind.recentPayments),
        () => RecentPaymentsCard(
          section: vm.recentPayments,
          formatter: formatter,
          compact: true,
          preview: _kNarrowPanelRows,
          onPaymentTap: onPaymentTap,
          onViewAll: onAllPayments,
          onRetry: () => vm.retry(DashboardKind.recentPayments),
        ),
      ),
      DashboardKind.upcomingQuotes: () => sectionListenable(
        vm.listenableFor(DashboardKind.upcomingQuotes),
        () => UpcomingQuotesCard(
          section: vm.upcomingQuotes,
          formatter: formatter,
          today: vm.today,
          compact: true,
          preview: _kNarrowPanelRows,
          onQuoteTap: onQuoteTap,
          onViewAll: onAllUpcomingQuotes,
          onRetry: () => vm.retry(DashboardKind.upcomingQuotes),
          remind: attentionActions.remindQuote,
        ),
      ),
      DashboardKind.expiredQuotes: () => sectionListenable(
        vm.listenableFor(DashboardKind.expiredQuotes),
        () => ExpiredQuotesCard(
          section: vm.expiredQuotes,
          formatter: formatter,
          compact: true,
          preview: _kNarrowPanelRows,
          onQuoteTap: onQuoteTap,
          onViewAll: onAllExpiredQuotes,
          onRetry: () => vm.retry(DashboardKind.expiredQuotes),
        ),
      ),
      DashboardKind.upcomingRecurring: () => sectionListenable(
        vm.listenableFor(DashboardKind.upcomingRecurring),
        () => UpcomingRecurringInvoicesCard(
          section: vm.upcomingRecurring,
          formatter: formatter,
          compact: true,
          preview: _kNarrowPanelRows,
          onRecurringTap: onRecurringTap,
          onViewAll: onAllRecurring,
          onRetry: () => vm.retry(DashboardKind.upcomingRecurring),
        ),
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
          refreshNonce: vm.panelRefreshNonce,
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
        refreshNonce: vm.panelRefreshNonce,
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
}
