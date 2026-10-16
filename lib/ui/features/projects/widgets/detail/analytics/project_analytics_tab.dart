import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/features/projects/view_models/project_analytics_view_model.dart';
import 'package:admin/ui/features/projects/widgets/detail/analytics/analytics_figures.dart';
import 'package:admin/ui/features/projects/widgets/detail/analytics/expenses_section.dart';
import 'package:admin/ui/features/projects/widgets/detail/analytics/forecast_section.dart';
import 'package:admin/ui/features/projects/widgets/detail/analytics/money_section.dart';
import 'package:admin/ui/features/projects/widgets/detail/analytics/project_burnup_chart.dart';
import 'package:admin/ui/features/projects/widgets/detail/analytics/time_section.dart';
import 'package:admin/utils/formatting.dart';

/// Analytics tab on the project detail screen — the server-computed view of a
/// project, from `charts/project_analytics/{id}` + `charts/project_burnup/{id}`.
///
/// **One scrolling tab, in React's order:** Forecast, Burn-up, Money, Time,
/// Expenses. React's develop branch folds its Money / Time / Expenses tabs
/// into one, and nothing on a record screen hides behind a disclosure.
///
/// **Who sees what.** Anyone who can view the project gets the tab (from
/// server 5.13.28 — `project_detail_tabs.dart` keeps the old gate before
/// that). A user who may not see the money gets the server's forecast and the
/// burn-up in hours, both built from their own time, and nothing else — so
/// the Money, Time and Expenses sections are left out, not shown empty.
///
/// The record's figures above the tabs (the standing card, the progress
/// chart) are computed locally and work offline; this tab is server-only, and
/// says so when it cannot reach the server.
class ProjectAnalyticsTab extends StatefulWidget {
  const ProjectAnalyticsTab({
    super.key,
    required this.project,
    this.formatter,
    this.viewModel,
  });

  final Project project;
  final Formatter? formatter;

  /// A view model built by the caller, which then owns it. Only tests pass
  /// one — the tab otherwise builds its own from `Services`, with the Sync,
  /// push and outbox signals wired in.
  @visibleForTesting
  final ProjectAnalyticsViewModel? viewModel;

  @override
  State<ProjectAnalyticsTab> createState() => _ProjectAnalyticsTabState();
}

class _ProjectAnalyticsTabState extends State<ProjectAnalyticsTab> {
  late final ProjectAnalyticsViewModel _vm;

  @override
  void initState() {
    super.initState();
    final injected = widget.viewModel;
    if (injected != null) {
      _vm = injected;
      _vm.load();
      return;
    }
    final services = context.read<Services>();
    final p = widget.project;
    _vm = ProjectAnalyticsViewModel(
      api: services.projectCharts,
      projectId: p.id,
      companyId: services.auth.currentCompanyId ?? '',
      projectStart: _startOf(p),
      projectDue: p.dueDate,
      resyncCompletions: services.resync.lastCompletion,
      realtimeRefreshes: services.realtime.lastRefresh,
      outboxActive: services.auth.currentCompanyId == null
          ? null
          : services.watchOutboxActive(services.auth.currentCompanyId!),
    );
    _vm.load();
  }

  @override
  void didUpdateWidget(ProjectAnalyticsTab old) {
    super.didUpdateWidget(old);
    final p = widget.project;
    _vm.updateProject(start: _startOf(p), due: p.dueDate);
    // The project row changed — a sync, a pushed change, an edit that left
    // the outbox — so the server's figures may have too.
    if (old.project.updatedAt != p.updatedAt) {
      _vm.refreshQuietly();
    }
  }

  /// The local day the project was created — the start of its life.
  static Date _startOf(Project p) {
    final created = p.createdAt.toLocal();
    return Date(created.year, created.month, created.day);
  }

  @override
  void dispose() {
    if (widget.viewModel == null) _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        if (_vm.initialLoading) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final blocking = _vm.blockingFailure;
        if (blocking != null) {
          return _Failure(failure: blocking, vm: _vm);
        }
        return _Sections(
          vm: _vm,
          project: widget.project,
          formatter: widget.formatter,
          // Per build, so a tab left open past midnight fills to the new day.
          today: Date.today(),
        );
      },
    );
  }
}

class _Sections extends StatelessWidget {
  const _Sections({
    required this.vm,
    required this.project,
    required this.formatter,
    required this.today,
  });

  final ProjectAnalyticsViewModel vm;
  final Project project;
  final Formatter? formatter;
  final Date today;

  @override
  Widget build(BuildContext context) {
    final a = vm.analytics;
    final burnup = vm.burnup;
    final financial = vm.canViewFinancials;
    final active = a == null || analyticsHasActivity(a);
    final sections = <Widget>[
      _Toolbar(vm: vm, financial: financial),
      // A fetch that failed while older figures are on screen says so above
      // them, rather than replacing them.
      if (vm.analyticsFailure != null || vm.burnupFailure != null)
        _StaleBanner(vm: vm),
      ForecastSection(
        analytics: a,
        projectBudgetedHours: project.budgetedHours,
        projectLoggedHours: project.currentHours,
        projectDueDate: project.dueDate,
        formatter: formatter,
      ),
      if (burnup != null && !burnup.isEmpty)
        ProjectBurnupSection(vm: vm, burnup: burnup, formatter: formatter),
      // Only for a user who may see the money: `analyticsHasActivity` reads
      // the blocks the server sends nobody else, so for them it is always
      // false — and their Forecast already says "Log time…" when it is so.
      if (a != null && financial && !active)
        EmptyState(
          icon: Icons.insights_outlined,
          title: context.tr('no_analytics_data'),
        ),
      if (a != null && active && financial) ...[
        if (MoneySection.hasMoney(a))
          MoneySection(analytics: a, formatter: formatter),
        TimeSection(analytics: a, formatter: formatter, today: today),
        if (ExpensesSection.hasSpend(a))
          ExpensesSection(analytics: a, formatter: formatter, today: today),
      ],
    ];
    final gap = SizedBox(height: InSpacing.lg(context));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) gap,
          sections[i],
        ],
      ],
    );
  }
}

/// Include drafts, and the in-place refresh spinner. Drafts are money: the
/// switch is offered only to a user who may see it, as in React.
class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.vm, required this.financial});

  final ProjectAnalyticsViewModel vm;
  final bool financial;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: InSpacing.md(context),
      runSpacing: InSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (financial)
          FilterChip(
            label: Text(context.tr('include_drafts')),
            selected: vm.includeDrafts,
            onSelected: vm.setIncludeDrafts,
          ),
        if (vm.loading)
          Semantics(
            label: context.tr('loading'),
            child: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }
}

/// The copy for a failure, by what the user can do about it.
String _failureText(
  BuildContext context,
  ProjectAnalyticsFailure f,
) => switch (f) {
  ProjectAnalyticsFailure.offline => context.tr('analytics_needs_connection'),
  ProjectAnalyticsFailure.unavailable => context.tr('analytics_unavailable'),
  ProjectAnalyticsFailure.forbidden => context.tr('not_authorized'),
  ProjectAnalyticsFailure.other => context.tr('analytics_failed'),
};

/// Nothing from before to show, and the fetch failed.
class _Failure extends StatelessWidget {
  const _Failure({required this.failure, required this.vm});

  final ProjectAnalyticsFailure failure;
  final ProjectAnalyticsViewModel vm;

  @override
  Widget build(BuildContext context) {
    // A refused user has nothing to retry; an old server will not grow the
    // endpoint by being asked again.
    final retry =
        failure == ProjectAnalyticsFailure.offline ||
        failure == ProjectAnalyticsFailure.other;
    return EmptyState(
      icon: failure == ProjectAnalyticsFailure.offline
          ? Icons.cloud_off_outlined
          : Icons.insights_outlined,
      title: _failureText(context, failure),
      subtitle: failure == ProjectAnalyticsFailure.other
          ? vm.failureMessage
          : null,
      action: retry
          ? FilledButton(
              // A centred single action constrains its own width, or the
              // Size.fromHeight(44) theme stretches it edge to edge.
              style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
              onPressed: vm.load,
              child: Text(context.tr('retry')),
            )
          : null,
    );
  }
}

/// A refresh failed while older figures are still on screen.
class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.vm});

  final ProjectAnalyticsViewModel vm;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final failure = vm.analyticsFailure ?? vm.burnupFailure!;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.md(context),
        vertical: InSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: tokens.warningSoft,
        borderRadius: BorderRadius.circular(InRadii.r2),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: tokens.ink2),
          SizedBox(width: InSpacing.sm),
          Expanded(
            child: Text(
              _failureText(context, failure),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.ink),
            ),
          ),
          if (failure == ProjectAnalyticsFailure.offline ||
              failure == ProjectAnalyticsFailure.other)
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(64, 36)),
              onPressed: vm.load,
              child: Text(context.tr('retry')),
            ),
        ],
      ),
    );
  }
}
