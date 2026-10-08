import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/app/search_focus_registry.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/report_payload.dart';
import 'package:admin/data/models/domain/schedule.dart';
import 'package:admin/data/models/domain/schedule_constants.dart';
import 'package:admin/domain/reports/report_csv.dart';
import 'package:admin/domain/reports/report_engine.dart';
import 'package:admin/domain/reports/report_group_label.dart';
import 'package:admin/domain/reports/report_measures.dart';
import 'package:admin/domain/reports/report_registry.dart';
import 'package:admin/domain/reports/report_schedule.dart';
import 'package:admin/domain/reports/report_table_model.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/utils/text_input_focus.dart';
import 'package:admin/ui/core/widgets/back_dismissible_menu_anchor.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/focus_owner_keeper.dart';
import 'package:admin/ui/core/widgets/formatter_scope.dart';
import 'package:admin/ui/features/dashboard/widgets/freshness.dart';
import 'package:admin/ui/features/reports/view_models/reports_view_model.dart';
import 'package:admin/ui/features/reports/views/reports_gallery_screen.dart';
import 'package:admin/ui/features/reports/widgets/report_column_tools.dart';
import 'package:admin/ui/features/reports/widgets/report_control_bar.dart';
import 'package:admin/ui/features/reports/widgets/report_document_view.dart';
import 'package:admin/ui/features/reports/widgets/report_export.dart';
import 'package:admin/ui/features/reports/widgets/report_states.dart';
import 'package:admin/ui/features/reports/widgets/report_summary_card.dart';
import 'package:admin/ui/features/reports/widgets/report_table.dart';
import 'package:admin/ui/features/reports/widgets/report_table_layout.dart';
import 'package:admin/ui/features/reports/widgets/report_views.dart';
import 'package:admin/ui/features/settings/widgets/plan_gate_banner.dart';
import 'package:admin/utils/formatting.dart';

/// Pane width from which the controls sit in a row above the results and the
/// figures stand four abreast. Below it the controls go behind the app bar's
/// filter button and the figures stack two by two.
const double kReportWidePane = 720;

/// `/reports/:report` — one report: what it covers, what it adds up to, the
/// shape of it, and its rows.
///
/// The view model lives above this route (`ReportsHost`), so the screen owns
/// nothing but the act of asking for its report: it calls
/// [ReportsViewModel.open] when the route names one, and draws whatever state
/// that leaves.
class ReportScreen extends StatefulWidget {
  const ReportScreen({
    super.key,
    required this.reportId,
    this.starterIndex,
    this.viewId,
  });

  /// The report the route names — already checked to be one this company
  /// may open.
  final String reportId;

  /// One of the report's starter views to apply on arrival, by position.
  final int? starterIndex;

  /// A saved view to open the report in, by id.
  final String? viewId;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'report row search');

  /// What holds primary focus while nothing else on the screen does, so the
  /// `Shortcuts` above it are reached at all — see [build].
  final _bodyFocus = FocusNode(debugLabel: 'report screen');
  SearchFocusRegistry? _searchRegistry;
  ReportsViewModel? _vm;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final vm = context.read<ReportsViewModel>();
    if (!identical(vm, _vm)) {
      // First build, or the company changed and the host made a new one.
      _vm = vm;
      _scheduleOpen();
    }
    // `/` focuses whichever search box holds this slot. Claimed only while
    // this route is the one on stage — the gallery beneath it and every
    // other branch stay mounted, and the last to *mount* is not the one the
    // reader is looking at (the `TokenSearchField` gate, for its reason).
    _searchRegistry ??= context.read<Services>().searchFocus;
    if (TickerMode.valuesOf(context).enabled) {
      _searchRegistry?.current = _searchFocus;
    } else {
      _searchRegistry?.release(_searchFocus);
    }
  }

  @override
  void didUpdateWidget(ReportScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reportId != widget.reportId ||
        oldWidget.starterIndex != widget.starterIndex ||
        oldWidget.viewId != widget.viewId) {
      _scheduleOpen();
    }
  }

  /// Both callers above run inside a build, and `open` notifies at once when
  /// the view model's saved state is already loaded — which is every time
  /// but the first. A notification during a build is an assertion in debug
  /// and a dropped rebuild in release, so the open waits for the build to
  /// finish. The frame in between draws the skeleton.
  void _scheduleOpen() {
    scheduleMicrotask(() {
      if (mounted) _open();
    });
  }

  Future<void> _open() async {
    final vm = _vm;
    if (vm == null) return;
    final id = widget.reportId;
    final starter = widget.starterIndex;
    final viewId = widget.viewId;
    final saved = context.read<Services>().savedViews;
    await vm.open(id);
    if (!mounted || vm.reportIdentifier != id) return;
    _search.text = vm.search;
    if (viewId != null) {
      final view = await saved.reportView(viewId);
      if (!mounted || vm.reportIdentifier != id) return;
      // Gone, or another report's: the report opens as it was left.
      if (view != null && view.reportIdentifier == id) {
        vm.applyReportView(view.id, view.state);
        _search.text = vm.search;
      }
    } else if (starter != null) {
      final views = vm.definition.starterViews;
      if (starter >= 0 && starter < views.length) {
        vm.applyStarterView(views[starter]);
      }
    } else {
      return;
    }
    // The view is applied once, on arrival; it is not part of where the
    // reader *is*. Left on the address it would be applied again on every
    // restore, over whatever they have since changed.
    if (mounted) context.go(reportRoutePath(id));
  }

  @override
  void dispose() {
    _searchRegistry?.release(_searchFocus);
    _search.dispose();
    _searchFocus.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  /// `Esc`: step back out of whatever narrowed the rows last — a drill into
  /// one group, else the row search.
  bool get _hasSomethingToClear {
    final vm = _vm;
    if (vm == null) return false;
    return (vm.selectedGroup?.isNotEmpty ?? false) || vm.search.isNotEmpty;
  }

  void _clearInnermost() {
    final vm = _vm;
    if (vm == null) return;
    if (vm.selectedGroup?.isNotEmpty ?? false) {
      vm.setSelectedGroup(null);
    } else if (vm.search.isNotEmpty) {
      _search.clear();
      vm.setSearch('');
    }
  }

  bool get _canRefresh {
    final vm = _vm;
    if (vm == null || vm.reportIdentifier != widget.reportId) return false;
    if (!vm.definition.showsOnScreen || vm.run.isLoading) return false;
    final session = context.read<Services>().auth.session.value;
    return session == null || session.hasProAccess;
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        // Not on key-repeat: holding the key would queue a run per repeat,
        // against a route the server limits to twenty a minute.
        SingleActivator(LogicalKeyboardKey.keyR, includeRepeats: false):
            _RefreshIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _ClearIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _RefreshIntent: _WhenAction<_RefreshIntent>(
            when: () => _canRefresh,
            run: () => _vm?.runReport(),
          ),
          // Disabled — so `Esc` falls through to whoever else wants it —
          // when there is nothing here for it to undo.
          _ClearIntent: _WhenAction<_ClearIntent>(
            when: () => _hasSomethingToClear,
            run: _clearInnermost,
          ),
        },
        // **The map above is never consulted without this.** A key is
        // offered to `primaryFocus` and its ancestors, never to descendants,
        // and a report opens with focus on the route's own scope — above
        // this `Shortcuts`. A retained node behind a keeper, not
        // `autofocus: true`, which fires once (`docs/keyboard.md` § The
        // whole keyboard layer hangs off one focus node). The keeper only
        // takes back focus that went *up*; the search field, a menu or a
        // dialog keeps what it took. Gated on `TickerMode`, so a report
        // left mounted behind another branch does not claim.
        child: FocusOwnerKeeper(
          node: _bodyFocus,
          enabled: TickerMode.valuesOf(context).enabled,
          child: Focus(focusNode: _bodyFocus, child: _buildScreen(context)),
        ),
      ),
    );
  }

  Widget _buildScreen(BuildContext context) {
    final vm = context.watch<ReportsViewModel>();
    final services = context.watch<Services>();
    final formatter = FormatterScope.maybeOf(context);
    final session = services.auth.session.value;
    final gated = session != null && !session.hasProAccess;
    final globalNav = Breakpoints.isGlobalNavVisible(context);
    final tokens = context.inTheme;
    // Until `open` has switched the view model to this route's report, what
    // it holds is another report's state — draw the skeleton, not that.
    final ready = vm.reportIdentifier == widget.reportId;
    final view = !ready || vm.run.preview == null
        ? null
        : vm.buildView(
            companyCurrencyId: formatter?.settings.currencyId,
            firstMonthOfYear: formatter?.settings.firstMonthOfYear ?? 1,
            firstDayOfWeek: formatter?.settings.firstDayOfWeek ?? 0,
          );
    final currencies = view == null ? const <String>[] : reportCurrencies(view);
    // The engine's own answer: it ranked the groups in this currency.
    final currencyId = view?.currencyId ?? '';
    final actions = ReportExportActions(
      vm: vm,
      view: view,
      formatter: formatter,
      currencyId: currencyId,
      enabled: !gated && ready,
    );
    final title = context.tr(reportDefinitionFor(widget.reportId).labelKey);

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: globalNav
          ? null
          : AppBar(
              leading: BackButton(onPressed: () => context.go('/reports')),
              title: Text(title),
              actions: [
                _RefreshButton(vm: vm, enabled: !gated),
                if (ready && vm.definition.supportsPreview)
                  ReportViewsButton(vm: vm),
                BackDismissibleMenuAnchor(
                  menuChildren: [
                    ...actions.menuItems(context),
                    const Divider(height: 1),
                    MenuItemButton(
                      leadingIcon: const Icon(Icons.restart_alt, size: 16),
                      onPressed: vm.resetEverything,
                      child: Text(context.tr('reset_view')),
                    ),
                  ],
                  builder: (context, controller, _) => IconButton(
                    tooltip: context.tr('more_actions'),
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => controller.isOpen
                        ? controller.close()
                        : controller.open(),
                  ),
                ),
              ],
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (globalNav)
            _HeaderBand(vm: vm, title: title, actions: actions, gated: gated),
          if (gated) const PlanGateBanner(style: PlanGateStyle.stripe),
          Expanded(
            // The pane, not the window: the sidebar has a share of the
            // window, and it is the pane the controls have to fit in.
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= kReportWidePane;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (ready)
                      ReportControlBar(
                        vm: vm,
                        formatter: formatter,
                        currencies: currencies,
                        currencyId: currencyId,
                        wide: wide,
                        currencyCounts:
                            view?.rowCountByCurrency ?? const <String, int>{},
                      ),
                    // A hairline of progress while a result is refreshed
                    // behind the one on screen. Always there, so the page
                    // does not shift by two pixels each time.
                    SizedBox(
                      height: 2,
                      child: ready && vm.run.isLoading && vm.hasResult
                          ? const LinearProgressIndicator(minHeight: 2)
                          : null,
                    ),
                    if (ready) ReportNotice(vm: vm),
                    Expanded(
                      child: _Results(
                        vm: vm,
                        view: view,
                        ready: ready,
                        formatter: formatter,
                        currencyId: currencyId,
                        multiCurrency: currencies.length > 1,
                        wide: wide,
                        width: constraints.maxWidth,
                        gated: gated,
                        actions: actions,
                        search: _search,
                        searchFocus: _searchFocus,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The wide layout's header: where this is, how fresh it is, and what can be
/// done with it. Floored to the shared header height so it lines up with the
/// sidebar's company row across the seam.
class _HeaderBand extends StatelessWidget {
  const _HeaderBand({
    required this.vm,
    required this.title,
    required this.actions,
    required this.gated,
  });

  final ReportsViewModel vm;
  final String title;
  final ReportExportActions actions;
  final bool gated;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final tr = context.tr;
    return Container(
      constraints: const BoxConstraints(minHeight: InSizes.headerBand),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.xl,
        vertical: InSpacing.md(context),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: () => context.go('/reports'),
            style: TextButton.styleFrom(
              foregroundColor: tokens.ink2,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(tr('reports')),
          ),
          Icon(Icons.chevron_right, size: 16, color: tokens.ink3),
          const SizedBox(width: 4),
          // Expanded, not Flexible beside a Spacer: the two would split the
          // spare width between them and leave the actions stranded
          // mid-band instead of against its end.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: tokens.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (vm.definition.showsOnScreen)
                  FreshnessTicker(
                    builder: (context) => Text(
                      freshnessText(
                        context,
                        lastRefreshed: vm.run.isLoading
                            ? null
                            : vm.resultFetchedAt,
                        isRefreshing: vm.run.isLoading,
                        cachedAt: vm.resultFetchedAt,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tokens.ink2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: InSpacing.sm),
          _ScheduleLink(
            reportId: vm.reportIdentifier,
            companyId: vm.companyId ?? '',
          ),
          if (vm.definition.showsOnScreen) ...[
            _RefreshButton(vm: vm, enabled: !gated),
            const SizedBox(width: InSpacing.sm),
          ],
          if (vm.definition.supportsPreview) ...[
            ReportViewsButton(vm: vm),
            const SizedBox(width: InSpacing.sm),
          ],
          ReportExportButton(actions: actions),
          BackDismissibleMenuAnchor(
            menuChildren: [
              MenuItemButton(
                leadingIcon: const Icon(Icons.restart_alt, size: 16),
                onPressed: vm.resetEverything,
                child: Text(tr('reset_view')),
              ),
            ],
            builder: (context, controller, _) => IconButton(
              tooltip: tr('more_actions'),
              icon: Icon(Icons.more_vert, size: 20, color: tokens.ink2),
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Scheduled" beside a report that is already being emailed on a schedule,
/// leading to that schedule.
///
/// Scheduling a report used to be write-only from here: the menu offered
/// *Schedule* every time, with nothing to say one already existed, so a
/// monthly report was scheduled twice by anyone who came back to check.
///
/// Read from the schedules the app already holds. It draws nothing while
/// it knows of none — which is not a claim that there are none, only the
/// absence of a claim that there are.
class _ScheduleLink extends StatefulWidget {
  const _ScheduleLink({required this.reportId, required this.companyId});

  final String reportId;

  /// The company the report is being read for — the view model's, which
  /// the host replaces whenever the session's company changes.
  final String companyId;

  @override
  State<_ScheduleLink> createState() => _ScheduleLinkState();
}

class _ScheduleLinkState extends State<_ScheduleLink> {
  Stream<List<Schedule>>? _schedules;

  @override
  void initState() {
    super.initState();
    _watch();
  }

  @override
  void didUpdateWidget(_ScheduleLink oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) _watch();
  }

  /// Made here, not in `build`: a stream made there is a new subscription —
  /// and a replayed first event — on every rebuild of the header.
  void _watch() {
    _schedules = widget.companyId.isEmpty
        ? null
        : context.read<Services>().schedules.watchPage(
            companyId: widget.companyId,
            templates: const {kScheduleTemplateEmailReport},
          );
  }

  @override
  Widget build(BuildContext context) {
    final name = scheduledReportName(widget.reportId);
    final stream = _schedules;
    if (name == null || stream == null) return const SizedBox.shrink();
    final tokens = context.inTheme;
    return StreamBuilder<List<Schedule>>(
      stream: stream,
      builder: (context, snapshot) {
        final mine = [
          for (final s in snapshot.data ?? const <Schedule>[])
            if (s.reportName == name) s,
        ];
        if (mine.isEmpty) return const SizedBox.shrink();
        final tr = context.tr;
        return Padding(
          padding: const EdgeInsetsDirectional.only(end: InSpacing.sm),
          child: TextButton.icon(
            key: const Key('report-scheduled'),
            // One: straight to it. Several: to the list they are in.
            onPressed: () => context.go(
              mine.length == 1
                  ? '/settings/schedules/${mine.single.id}'
                  : '/settings/schedules',
            ),
            style: TextButton.styleFrom(
              foregroundColor: tokens.ink2,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.schedule_outlined, size: 16),
            label: Text(
              mine.length == 1
                  ? tr('report_scheduled')
                  : tr('report_scheduled_count', {'count': '${mine.length}'}),
            ),
          ),
        );
      },
    );
  }
}

/// Run the report again — or, while it is running, stop waiting for it.
class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.vm, required this.enabled});

  final ReportsViewModel vm;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    if (!vm.definition.showsOnScreen) return const SizedBox.shrink();
    if (vm.run.isLoading) {
      return IconButton(
        key: const Key('report-cancel'),
        tooltip: tr('cancel'),
        onPressed: vm.cancelRun,
        icon: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      key: const Key('report-refresh'),
      tooltip: tr('refresh'),
      onPressed: enabled ? vm.runReport : null,
      icon: const Icon(Icons.refresh, size: 20),
    );
  }
}

/// Everything under the controls: the state the report is in, or its result.
class _Results extends StatelessWidget {
  const _Results({
    required this.vm,
    required this.view,
    required this.ready,
    required this.formatter,
    required this.currencyId,
    required this.multiCurrency,
    required this.wide,
    required this.width,
    required this.gated,
    required this.actions,
    required this.search,
    required this.searchFocus,
  });

  final ReportsViewModel vm;
  final ReportView? view;
  final bool ready;
  final Formatter? formatter;
  final String currencyId;
  final bool multiCurrency;
  final bool wide;
  final double width;
  final bool gated;
  final ReportExportActions actions;
  final TextEditingController search;
  final FocusNode searchFocus;

  /// The figure a narrow pane's group lines lead with: the one the chart
  /// above is of.
  ReportTableSummary _summaryMeasure() {
    final id = resolveReportMeasureId(vm);
    return ReportTableSummary(
      measureId: id,
      column: reportMeasureColumns(
        vm.run.preview,
      ).where((c) => c.identifier == id).firstOrNull,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final view = this.view;
    if (!ready) return ReportSkeleton(wide: wide);
    if (!vm.definition.supportsPreview) {
      final document = vm.document;
      if (vm.definition.readsAsDocument && !vm.documentUnreadable) {
        if (document != null) {
          final page = ReportDocumentView(
            document: document,
            reportId: vm.reportIdentifier,
            formatter: formatter,
            wide: wide,
          );
          return AnimatedOpacity(
            opacity: vm.run.isLoading ? 0.55 : 1,
            duration: const Duration(milliseconds: 150),
            child: Env.isTouchPrimary && !gated
                ? RefreshIndicator(onRefresh: vm.runReport, child: page)
                : page,
          );
        }
        if (vm.run.isLoading) return ReportSkeleton(wide: wide);
        // The notice above says what went wrong and offers the retry.
        if (vm.run.error != null || gated) return const SizedBox.shrink();
        if (!vm.isOnline) {
          return ReportMessage(
            icon: Icons.cloud_off_outlined,
            message: tr('report_waiting_online'),
          );
        }
        return ReportSkeleton(wide: wide);
      }
      // A report the server produces only as a file — or one whose file
      // could not be read back, where the download is still the answer.
      return ReportMessage(
        icon: Icons.description_outlined,
        message: tr('report_file_only'),
        actions: [
          BackDismissibleMenuAnchor(
            menuChildren: actions.menuItems(context),
            builder: (context, controller, _) => FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
              icon: const Icon(Icons.download_outlined, size: 18),
              label: Text(tr('export')),
            ),
          ),
        ],
      );
    }
    if (view == null) {
      // No result to show. Why not decides what to say.
      final error = vm.run.error;
      if (vm.run.isLoading) return ReportSkeleton(wide: wide);
      // The notice above already says what went wrong and offers the retry.
      if (error != null || gated) return const SizedBox.shrink();
      if (!vm.isOnline) {
        return ReportMessage(
          icon: Icons.cloud_off_outlined,
          message: tr('report_waiting_online'),
        );
      }
      return ReportSkeleton(wide: wide);
    }

    final gutter = wide ? InSpacing.xl : InSpacing.lg(context);
    final layout = ReportTableLayout.of(
      columns: view.visibleColumns,
      // The card's two hairline borders are not table.
      width: width - gutter * 2 - 2,
      userWidths: vm.columnWidths,
      // On a narrow pane the held column must leave the others room.
      pinnedMaxFraction: wide ? null : 0.42,
    );
    final lines = buildReportTableLines(
      view,
      expanded: vm.expandedGroups,
      splitByPeriod: vm.isSplitByPeriod,
    );
    final totalRows = vm.run.preview?.rows.length ?? 0;
    final currencyCode = !multiCurrency
        ? null
        : (formatter?.currencies[currencyId]?.code ?? currencyId);

    final Widget scroll = CustomScrollView(
      // Always scrollable, so a short result can still be pulled to refresh.
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(gutter, gutter, gutter, 0),
          sliver: SliverToBoxAdapter(
            child: ReportSummaryCard(
              vm: vm,
              view: view,
              formatter: formatter,
              currencyId: currencyId,
              wide: wide,
              previous: vm.buildCompareView(
                companyCurrencyId: formatter?.settings.currencyId,
                firstMonthOfYear: formatter?.settings.firstMonthOfYear ?? 1,
                firstDayOfWeek: formatter?.settings.firstDayOfWeek ?? 0,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            gutter,
            InSpacing.lg(context),
            gutter,
            InSpacing.sm,
          ),
          sliver: SliverToBoxAdapter(
            child: _TableToolbar(
              vm: vm,
              view: view,
              lines: lines,
              totalRows: totalRows,
              formatter: formatter,
              currencyId: currencyId,
              search: search,
              searchFocus: searchFocus,
              wide: wide,
            ),
          ),
        ),
        if (view.totalRowCount == 0)
          SliverFillRemaining(
            hasScrollBody: false,
            child: ReportMessage(
              icon: Icons.inbox_outlined,
              message: totalRows == 0
                  ? tr('report_no_rows')
                  : tr('report_no_matching_rows'),
              actions: [
                if (totalRows > 0)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(64, 40),
                    ),
                    onPressed: () {
                      search.clear();
                      vm.clearLocalFilters();
                    },
                    child: Text(tr('clear_filters')),
                  )
                else if (vm.definition.honoursDateRange &&
                    vm.payload.datePreset != ReportDatePreset.allTime)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(64, 40),
                    ),
                    onPressed: () => vm.setPayload(
                      vm.payload.copyWith(
                        datePreset: ReportDatePreset.allTime,
                        startDate: () => null,
                        endDate: () => null,
                      ),
                    ),
                    child: Text(tr('all_time')),
                  ),
              ],
            ),
          )
        else
          ...buildReportTableSlivers(
            context,
            vm: vm,
            view: view,
            lines: lines,
            formatter: formatter,
            currencyId: currencyId,
            currencyLabel: currencyCode,
            onFilter: (column) => editReportColumnFilter(
              context,
              vm,
              column,
              formatter: formatter,
            ),
            gutter: gutter,
            summary: wide ? null : _summaryMeasure(),
          ),
        SliverToBoxAdapter(child: SizedBox(height: gutter)),
      ],
    );

    return ReportTableHorizontalScroll(
      layout: layout,
      // While a newer result is fetched the one on screen stays, dimmed —
      // no skeleton flash, no jump — and stays usable.
      child: AnimatedOpacity(
        opacity: vm.run.isLoading ? 0.55 : 1,
        duration: const Duration(milliseconds: 150),
        child: Env.isTouchPrimary && !gated
            ? RefreshIndicator(onRefresh: vm.runReport, child: scroll)
            : scroll,
      ),
    );
  }
}

/// The line above the table: how many rows it holds, a search of them, and
/// what the table itself can do.
class _TableToolbar extends StatelessWidget {
  const _TableToolbar({
    required this.vm,
    required this.view,
    required this.lines,
    required this.totalRows,
    required this.formatter,
    required this.currencyId,
    required this.search,
    required this.searchFocus,
    required this.wide,
  });

  final ReportsViewModel vm;
  final ReportView view;
  final List<ReportTableLine> lines;
  final int totalRows;
  final Formatter? formatter;
  final String currencyId;
  final TextEditingController search;
  final FocusNode searchFocus;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final tr = context.tr;
    final shown = view.totalRowCount;
    final unit = tr(shown == 1 && shown == totalRows ? 'row' : 'rows');
    // "12 of 214 rows" once something has narrowed them.
    final count = shown == totalRows
        ? '$shown $unit'
        : '${tr('report_rows_of', {'shown': '$shown', 'total': '$totalRows'})} $unit';
    final groupIds = [
      for (final line in lines)
        if (line is ReportTableGroupLine) line.id,
    ];
    final field = TextField(
      key: const Key('report-row-search'),
      controller: search,
      focusNode: searchFocus,
      onChanged: vm.setSearch,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        hintText: tr('report_search_rows'),
        prefixIcon: const Icon(Icons.search, size: 18),
        suffixIcon: vm.search.isEmpty
            ? null
            : IconButton(
                tooltip: tr('clear'),
                icon: const Icon(Icons.close, size: 16),
                onPressed: () {
                  search.clear();
                  vm.setSearch('');
                },
              ),
      ),
    );
    final tools = [
      ReportBarButton(
        key: const Key('report-columns'),
        icon: Icons.view_column_outlined,
        label: tr('columns'),
        onPressed: () => openReportColumns(context, vm),
      ),
      BackDismissibleMenuAnchor(
        menuChildren: [
          if (view.groups.isNotEmpty) ...[
            MenuItemButton(
              leadingIcon: const Icon(Icons.unfold_more, size: 16),
              onPressed: () => vm.setExpandedGroups({
                ...groupIds,
                // A split grouping's periods open with their group.
                for (final g in view.groups) g.key,
                for (final g in view.groups)
                  reportTableParentId(splitReportGroupKey(g.key).$1),
              }),
              child: Text(tr('expand_all')),
            ),
            MenuItemButton(
              leadingIcon: const Icon(Icons.unfold_less, size: 16),
              onPressed: () => vm.setExpandedGroups(const {}),
              child: Text(tr('collapse_all')),
            ),
          ],
          MenuItemButton(
            leadingIcon: const Icon(Icons.copy_outlined, size: 16),
            onPressed: () => copyToClipboard(context, _asText(context)),
            child: Text(tr('copy_table')),
          ),
        ],
        builder: (context, controller, _) => IconButton(
          tooltip: tr('more_actions'),
          icon: Icon(Icons.more_vert, size: 20, color: tokens.ink2),
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
        ),
      ),
    ];
    final label = Text(
      count,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: tokens.ink,
        fontWeight: FontWeight.w600,
      ),
    );
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: label),
              ...tools,
            ],
          ),
          const SizedBox(height: InSpacing.sm),
          field,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: label),
        SizedBox(width: 260, child: field),
        SizedBox(width: InSpacing.md(context)),
        ...tools,
      ],
    );
  }

  /// The view as tab-separated text, for pasting straight into a
  /// spreadsheet: the same rows and columns the file would hold.
  String _asText(BuildContext context) {
    final groupType = vm.groupColumn?.type;
    return buildReportCsv(
      view: view,
      separator: '\t',
      currencyId: currencyId,
      countLabel: context.tr('count'),
      groupLabel: (key) => reportGroupDisplayLabel(
        key: key,
        columnType: groupType,
        subgroup: vm.subgroup,
        formatter: formatter,
      ),
    );
  }
}

class _RefreshIntent extends Intent {
  const _RefreshIntent();
}

class _ClearIntent extends Intent {
  const _ClearIntent();
}

/// [GuardedShortcutAction]'s rules — stand down while typing or mid leader
/// sequence — plus a condition of its own. Disabled rather than a no-op when
/// it does not hold: only a *disabled* action lets the key fall through to
/// whoever else might want it.
class _WhenAction<T extends Intent> extends GuardedShortcutAction<T> {
  _WhenAction({required this.when, required VoidCallback run})
    : super(
        onInvoke: (_) {
          run();
          return null;
        },
      );

  final bool Function() when;

  @override
  bool isEnabled(T intent) => when() && super.isEnabled(intent);

  @override
  bool consumesKey(T intent) => when() && super.consumesKey(intent);
}
