import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_activity.dart';
import 'package:admin/domain/activity/activity_timeline.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/utils/calendar_week_start.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/ui/core/widgets/filter_icon_button.dart';
import 'package:admin/ui/features/reports/helpers/report_access.dart';
import 'package:admin/ui/features/activity/activity_deep_link.dart';
import 'package:admin/ui/features/activity/view_models/activity_view_model.dart';
import 'package:admin/ui/features/activity/widgets/activity_feed_row.dart';
import 'package:admin/ui/features/activity/widgets/activity_filter_sheet.dart';
import 'package:admin/ui/features/activity/widgets/activity_period_labels.dart';
import 'package:admin/ui/features/activity/widgets/activity_timeline_chart.dart';
import 'package:admin/ui/features/dashboard/helpers/activity_formatter.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/dashboard/widgets/freshness.dart';
import 'package:admin/ui/features/shell/widgets/app_drawer.dart';
import 'package:admin/utils/formatting.dart';

/// Pane width at which the filters leave their sheet for a side rail.
const double kActivityRailMinWidth = 1000;

/// Width of that rail.
const double kActivityRailWidth = 300;

/// Content cap on a wide pane: past it the feed's chevron drifts so far from
/// its sentence that the eye can't join them.
const double kActivityBodyMaxWidth = 1200;

/// Below this body height the timeline strip is dropped: a landscape phone
/// already spends half its height on the app bar, search and chips.
const double kActivityTimelineMinBodyHeight = 420;

/// The company-wide activity feed at `/activity` (invoiceninja/flutter#53).
///
/// Reads the same Drift cache row as the dashboard's Activity card, so it
/// paints from cache immediately and refreshing either surface updates both.
/// Unlike the card it renders every row in the window, day-grouped on a
/// vertical timeline, under a bar chart of the window that doubles as the
/// date filter, and narrowable by date / category / user / type / text /
/// comments-only. A wide pane shows the filters as a rail instead of a sheet.
///
/// Owns the [Formatter] and the [ActivityViewModel] — both rebuilt on
/// company-switch via the auth session listener (not via `build`, which would
/// dispose a notifier mid-rebuild). Mirrors `ReportsHost`.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  late Services _services;
  late ActivityViewModel _vm;
  late String _companyId;
  Formatter? _formatter;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value?.currentCompanyId ?? '';
    _vm = _buildVm();
    _services.auth.session.addListener(_onSessionChanged);
    if (_companyId.isNotEmpty) _loadFormatter();
  }

  ActivityViewModel _buildVm() {
    final vm = ActivityViewModel(
      repo: _services.dashboard,
      companyId: _companyId,
      navStateDao: _services.db.navStateDao,
    );
    vm.addListener(_syncSearchField);
    return vm;
  }

  /// Keeps the search box showing whatever the VM is actually filtering by.
  ///
  /// The two drift apart in three ways otherwise, all of them leaving a
  /// filtered list above an empty-looking box: filters are **restored
  /// asynchronously** on launch, "Clear filters" in the sheet resets them from
  /// outside this widget, and a company switch rehydrates a different set.
  /// Guarded on inequality, so this never fights the user mid-keystroke (they
  /// are equal while typing) or moves the caret.
  void _syncSearchField() {
    final wanted = _vm.filters.search;
    if (_searchController.text == wanted) return;
    _searchController.text = wanted;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Assigned here, not in `build`: `ActivityFormatter` reads `Localization`,
    // so this is the hook that re-fires when the locale changes.
    //
    // It also fires for every *other* dependency this State's `build` reads —
    // `Theme.of`, `MediaQuery.sizeOf` — i.e. on a theme toggle, a rotation and
    // every frame of a desktop window drag. `setTitleResolver` is written to be
    // cheap and phase-safe for exactly that reason; don't move work in here.
    _attachTitleResolver();
  }

  /// Wires the sentence renderer the VM's text filter matches against. Called
  /// on every dependency change **and** after a company switch swaps the VM —
  /// `didChangeDependencies` does not re-fire for that, and a VM without a
  /// resolver silently stops matching rendered text.
  void _attachTitleResolver() {
    final formatter = ActivityFormatter(context);
    _vm.setTitleResolver((a) => formatter.format(a).title);
    _attachWeekStart();
  }

  /// Week-wide timeline bars start on the company's first day of week, else
  /// the locale's. `calendarFirstDayOfWeek` counts from Sunday = 0; the
  /// bucketing uses `DateTime.weekday` (Monday = 1 … Sunday = 7).
  void _attachWeekStart() {
    final sundayZero = calendarFirstDayOfWeek(context, _formatter);
    _vm.setFirstDayOfWeek(sundayZero == 0 ? DateTime.sunday : sundayZero);
  }

  void _loadFormatter() {
    final loadingFor = _companyId;
    _services.formatterFor(loadingFor).then((f) {
      if (!mounted || loadingFor != _companyId) return;
      setState(() => _formatter = f);
      _attachWeekStart();
    });
  }

  void _onSessionChanged() {
    final nextId = _services.auth.session.value?.currentCompanyId ?? '';
    if (nextId == _companyId) return;
    final oldVm = _vm;
    setState(() {
      _companyId = nextId;
      _formatter = null;
      _vm = _buildVm();
    });
    oldVm
      ..removeListener(_syncSearchField)
      ..dispose();
    _attachTitleResolver();
    _syncSearchField();
    if (_companyId.isNotEmpty) _loadFormatter();
  }

  @override
  void dispose() {
    _services.auth.session.removeListener(_onSessionChanged);
    // Listener first: `_syncSearchField` writes to the controller below.
    _vm
      ..removeListener(_syncSearchField)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onRowTap(DashboardActivity a) {
    final target = activityDeepLinkTarget(a);
    if (target == null) return;
    context.go(target);
  }

  @override
  Widget build(BuildContext context) {
    // The pane, not the window: the sidebar takes part of a desktop window,
    // and the app bar's filter button has to agree with the body's rail.
    return LayoutBuilder(
      builder: (context, c) =>
          _scaffold(context, rail: c.maxWidth >= kActivityRailMinWidth),
    );
  }

  Widget _scaffold(BuildContext context, {required bool rail}) {
    final globalNav = Breakpoints.isGlobalNavVisible(context);
    return Scaffold(
      drawer: globalNav ? null : const AppDrawer(),
      appBar: AppBar(
        title: Text(context.tr('activity')),
        leading: globalNav ? null : const DrawerHamburger(),
        automaticallyImplyLeading: !globalNav,
        actions: [
          ListenableBuilder(
            listenable: _vm,
            builder: (context, _) => IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: context.tr('refresh'),
              onPressed: _vm.isRefreshing ? null : _vm.refresh,
            ),
          ),
          // The rail *is* the filter surface on a wide pane — a button opening
          // a second copy of it would be two controls for one state.
          if (!rail)
            ListenableBuilder(
              listenable: _vm,
              builder: (context, _) => FilterIconButton(
                activeCount: _vm.filters.activeCount,
                onPressed: () => openActivityFilters(
                  context,
                  vm: _vm,
                  companyId: _companyId,
                  formatter: _formatter,
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _capped(
              TextField(
                controller: _searchController,
                // Search queries are names and numbers, not prose — iOS
                // autocorrecting "Acme" to "Acne" mid-search is the failure.
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  hintText: context.tr('search'),
                  suffixIcon: ListenableBuilder(
                    listenable: _searchController,
                    builder: (context, _) => _searchController.text.isEmpty
                        ? const SizedBox.shrink()
                        : IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: context.tr('clear'),
                            onPressed: () => _vm.setSearch(''),
                          ),
                  ),
                ),
                onChanged: _vm.setSearch,
              ),
            ),
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) => _body(context, rail: rail),
      ),
    );
  }

  /// At most [kActivityBodyMaxWidth] wide, centred — the same shape as the
  /// settings and record screens' capped columns under a start-aligned title.
  static Widget _capped(Widget child) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: kActivityBodyMaxWidth),
      child: child,
    ),
  );

  Widget _body(BuildContext context, {required bool rail}) {
    final tokens = context.inTheme;
    final section = _vm.section;

    Widget content;
    if (section.hasError && !section.hasData) {
      content = ErrorView(
        message: context.tr('couldnt_load_tap_to_retry', {
          'section': context.tr('activity').toLowerCase(),
        }),
        onRetry: _vm.refresh,
      );
    } else if (section.data == null) {
      content = ListView(
        padding: EdgeInsets.all(InSpacing.lg(context)),
        children: const [
          ActivityFeedSkeleton(count: 8, density: ActivityRowDensity.page),
        ],
      );
    } else if (_vm.entries.isEmpty) {
      // Over-filtering a *bounded* window is easy, so the filtered flavour of
      // this state has to offer a way back out rather than dead-end.
      content = _vm.filters.isActive
          ? EmptyState(
              icon: Icons.filter_alt_off_outlined,
              title: context.tr('no_records_found'),
              action: TextButton.icon(
                onPressed: _vm.clearFilters,
                icon: const Icon(Icons.restart_alt, size: 16),
                label: Text(context.tr('clear_filters')),
              ),
            )
          : EmptyState(
              icon: Icons.notifications_none_outlined,
              title: context.tr('no_activity_yet'),
            );
    } else {
      content = _list(context);
    }

    final scrollable = RefreshIndicator(
      onRefresh: _vm.refresh,
      child: content is ListView
          ? content
          : ListView(
              // Wrapped so `RefreshIndicator` has a Scrollable to attach to
              // at all — `EmptyState` is a plain Column and would leave the
              // pull gesture inert. The physics need no help: `ScrollView`
              // already gives a controller-less vertical list
              // `AlwaysScrollableScrollPhysics` on every platform, so short
              // content stays draggable here and in the feed below.
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.5,
                  child: content,
                ),
              ],
            ),
    );

    // Outside the `SelectionArea` on purpose: a mouse drag across the bars is
    // a range pick, and inside the region it would race text selection.
    final feed = Env.isMobile ? scrollable : SelectionArea(child: scrollable);
    final hasTimeline = _vm.timeline.buckets.isNotEmpty;

    if (rail) {
      return Column(
        children: [
          _capped(_HeaderStrip(vm: _vm, formatter: _formatter)),
          Divider(height: 1, color: tokens.border),
          Expanded(
            child: _capped(
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        if (hasTimeline)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              InSpacing.lg(context),
                              InSpacing.lg(context),
                              InSpacing.lg(context),
                              0,
                            ),
                            child: DashboardCardShell(
                              child: _timeline(compact: false),
                            ),
                          ),
                        Expanded(child: feed),
                      ],
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: BorderDirectional(
                        start: BorderSide(color: tokens.border),
                      ),
                    ),
                    child: SizedBox(
                      width: kActivityRailWidth,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ActivityFilterPanel(
                          vm: _vm,
                          companyId: _companyId,
                          formatter: _formatter,
                          inline: true,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _HeaderStrip(vm: _vm, formatter: _formatter),
        Divider(height: 1, color: tokens.border),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) => Column(
              children: [
                if (hasTimeline &&
                    c.maxHeight >= kActivityTimelineMinBodyHeight) ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      InSpacing.lg(context),
                      0,
                      InSpacing.lg(context),
                      InSpacing.sm,
                    ),
                    child: _timeline(compact: true),
                  ),
                  Divider(height: 1, color: tokens.border),
                ],
                Expanded(child: feed),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _timeline({required bool compact}) => ActivityTimelineChart(
    timeline: _vm.timeline,
    onLoadMore: _vm.canLoadMore ? _vm.loadMore : null,
    loadingMore: _vm.isLoadingMore,
    from: _vm.filters.from,
    until: _vm.filters.until,
    oldestAt: _vm.oldestAt,
    selectionCount: _vm.matchCount,
    formatter: _formatter,
    compact: compact,
    onSelect: _vm.setRange,
    onClear: () => _vm.setRange(null, null),
  );

  Widget _list(BuildContext context) {
    final entries = _vm.entries;
    // Only when the server actually capped us. Below the cap nothing is hidden,
    // so the footer would assert a truncation that isn't happening — and on a
    // filtered list it reads as "there should be more rows here". A fetch that
    // came back short (`canLoadMore` false, under the max) is the same case.
    final showFooter = _vm.canLoadMore || _vm.atWindowMax;
    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: InSpacing.sm,
      ),
      // +1 for the window footer, but only when there is one to show.
      itemCount: entries.length + (showFooter ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == entries.length) {
          return _WindowFooter(
            vm: _vm,
            canOpenReport:
                openableReport(
                  'activity',
                  _services.auth.session.value?.currentCompany,
                ) !=
                null,
          );
        }
        final entry = entries[i];
        // The spine starts on the first day's node and ends on the last
        // entry, so it never pokes out above or below the feed.
        final spine = i == 0
            ? ActivityFeedSpine.start
            : (i == entries.length - 1
                  ? ActivityFeedSpine.end
                  : ActivityFeedSpine.through);
        return switch (entry) {
          ActivityDayHeader() => _DayHeader(
            day: entry.day,
            count: entry.count,
            formatter: _formatter,
            spine: spine,
          ),
          ActivityFeedItem() => _row(context, entry.activity, spine),
          ActivityRunToggle() => _RunToggle(
            entry: entry,
            spine: spine,
            onPressed: () => _vm.toggleRun(entry.runId),
          ),
        };
      },
    );
  }

  Widget _row(
    BuildContext context,
    DashboardActivity a,
    ActivityFeedSpine spine,
  ) {
    final render = ActivityFormatter(context).format(a);
    return ActivityFeedRow(
      render: render,
      // The day header above already names the date.
      meta: activityAuditMeta(
        a,
        render: render,
        formatter: _formatter,
        showDate: false,
      ),
      spine: spine,
      onTap: activityDeepLinkTarget(a) == null ? null : () => _onRowTap(a),
    );
  }
}

/// Where the spine crosses a header or toggle: the centre of the 28 px icon
/// column the rows draw it through.
const double _kSpineX = 14;

/// Paints the timeline spine behind [child], through a node at [nodeY].
class _Spine extends StatelessWidget {
  const _Spine({required this.spine, required this.nodeY, required this.child});

  final ActivityFeedSpine spine;
  final double nodeY;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = context.inTheme.border;
    return Stack(
      children: [
        PositionedDirectional(
          start: _kSpineX - 1,
          width: 2,
          top: spine == ActivityFeedSpine.start ? nodeY : 0,
          bottom: spine == ActivityFeedSpine.end ? null : 0,
          height: spine == ActivityFeedSpine.end ? nodeY : null,
          child: ColoredBox(color: color),
        ),
        child,
      ],
    );
  }
}

/// Freshness stamp plus, when narrowed, the surviving-row count and removable
/// filter chips. Renders no chips at all in the default (unfiltered) view so
/// the screen carries no extra chrome for the common case.
class _HeaderStrip extends StatelessWidget {
  const _HeaderStrip({required this.vm, required this.formatter});

  final ActivityViewModel vm;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final f = vm.filters;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        InSpacing.lg(context),
        InSpacing.sm,
        InSpacing.lg(context),
        InSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: FreshnessTicker(
                  builder: (context) => Text(
                    freshnessText(
                      context,
                      lastRefreshed: vm.lastRefreshed,
                      isRefreshing: vm.isRefreshing,
                    ),
                    style: TextStyle(fontSize: 11, color: tokens.ink3),
                  ),
                ),
              ),
              if (f.isActive)
                Text(
                  '${vm.matchCount}',
                  style: TextStyle(fontSize: 11, color: tokens.ink3),
                ),
            ],
          ),
          if (f.isActive) ...[
            SizedBox(height: InSpacing.sm),
            Wrap(
              spacing: InSpacing.sm,
              runSpacing: InSpacing.xs,
              children: [
                if (f.hasRange)
                  _Chip(
                    label: activityRangeLabel(
                      context,
                      from: f.from,
                      until: f.until,
                      formatter: formatter,
                    ),
                    onRemove: () => vm.setRange(null, null),
                  ),
                if (f.categories.isNotEmpty)
                  _Chip(
                    label: _categoriesLabel(context, f.categories),
                    onRemove: vm.clearCategories,
                  ),
                if (f.search.trim().isNotEmpty)
                  _Chip(
                    label: f.search.trim(),
                    onRemove: () => vm.setSearch(''),
                  ),
                if (f.userId != null)
                  _Chip(
                    label: context.tr('user'),
                    onRemove: () => vm.setUser(null),
                  ),
                if (f.lens != ActivityLens.all)
                  _Chip(
                    label: context.tr(
                      f.lens == ActivityLens.calls ? 'calls' : 'comments',
                    ),
                    onRemove: () => vm.setLens(ActivityLens.all),
                  ),
                if (f.lens == ActivityLens.all && f.typeIds.isNotEmpty)
                  _Chip(
                    label: '${context.tr('type')} (${f.typeIds.length})',
                    onRemove: () => vm.setTypeIds(const <int>{}),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// "Sent, Paid" — or "Category (3)" once naming them all would crowd the
/// strip.
String _categoriesLabel(BuildContext context, Set<ActivityCategory> cats) {
  if (cats.length <= 2) {
    // Enum order, not tap order, so the chip doesn't reshuffle as you tick.
    return [
      for (final c in ActivityCategory.values)
        if (cats.contains(c)) activityCategoryLabel(context, c),
    ].join(', ');
  }
  return '${context.tr('category')} (${cats.length})';
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    // Default density on purpose. `shrinkWrap` opts out of the
    // `kMinInteractiveDimension` inflation `padded` gives on iOS/Android, which
    // put the ✕ well under `InSizes.touchTarget` — and this chip is the only
    // way to drop its filter from the header strip. Every other `InputChip` in
    // the app (`multi_entity_picker`, `multi_product_picker`, `report_control_bar`)
    // uses the defaults too.
    //
    // Body *and* ✕ both clear, mirroring the reports drill-down breadcrumb: the
    // whole control is the affordance, so make all of it a target.
    return InputChip(
      label: Text(label),
      onPressed: onRemove,
      onDeleted: onRemove,
      deleteIcon: const Icon(Icons.close, size: 16),
    );
  }
}

/// A day's node on the spine: a ringed dot in the icon column, then the date
/// and how many events it holds, aligned with the row sentences below.
class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.count,
    required this.formatter,
    required this.spine,
  });

  final DateTime day;
  final int count;
  final Formatter? formatter;
  final ActivityFeedSpine spine;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final top = InSpacing.md(context);
    const dot = 12.0;
    return _Spine(
      spine: spine,
      nodeY: top + 8,
      child: Padding(
        padding: EdgeInsets.only(top: top, bottom: 2),
        child: Row(
          children: [
            SizedBox(
              width: _kSpineX * 2,
              child: Center(
                child: Container(
                  width: dot,
                  height: dot,
                  decoration: BoxDecoration(
                    color: tokens.borderStrong,
                    shape: BoxShape.circle,
                    // A ring of page colour, so the dot sits *on* the line
                    // rather than merging into it.
                    border: Border.all(color: tokens.bg, width: 2),
                  ),
                ),
              ),
            ),
            SizedBox(width: InSpacing.md(context)),
            Expanded(
              child: Text(
                '${dayHeaderLabel(context, day, formatter)} · '
                '${activityEventCount(context, count)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: tokens.ink3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "+3 more" under a folded run, "Collapse" under an opened one — aligned
/// with the sentences, on the spine.
class _RunToggle extends StatelessWidget {
  const _RunToggle({
    required this.entry,
    required this.spine,
    required this.onPressed,
  });

  final ActivityRunToggle entry;
  final ActivityFeedSpine spine;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final height = Env.isTouchPrimary ? InSizes.touchTarget : 28.0;
    return _Spine(
      spine: spine,
      nodeY: height / 2,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: _kSpineX * 2 + InSpacing.md(context) - 8,
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              minimumSize: Size(0, height),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: onPressed,
            icon: Icon(
              entry.expanded ? Icons.expand_less : Icons.expand_more,
              size: 16,
            ),
            // Sized on the `Text`, never through `styleFrom(textStyle:)` —
            // that replaces the theme's label style wholesale, font family
            // included.
            label: Text(
              entry.expanded
                  ? context.tr('collapse')
                  : context.tr('plus_n_more', {'count': '${entry.hidden}'}),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
}

/// `Today` / `Yesterday` / the company-formatted date. Compared in *local*
/// calendar days — the same basis `localDayOf` groups on.
String dayHeaderLabel(
  BuildContext context,
  DateTime day,
  Formatter? formatter,
) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final delta = today.difference(day).inDays;
  if (delta == 0) return context.tr('today');
  if (delta == 1) return context.tr('yesterday');
  final iso =
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
  // Date-only, so no timezone conversion is wanted here — `day` is already the
  // local calendar day `localDayOf` grouped on.
  return formatter?.date(iso) ?? iso;
}

/// Explains the feed's ceiling at the end of the list — shown only while the
/// window is full, i.e. older activity may exist (`?reactv2` has no cursor, so
/// the window is a hard boundary, not a page) — and offers the way past it:
/// Load more under the window's cap, the Activity report at it.
///
/// Phrased as a statement about the feed's *scope* rather than a row count, so
/// it stays true — and doesn't read as "rows are missing" — while a filter is
/// narrowing the list beneath it. The match count lives in the header strip.
class _WindowFooter extends StatelessWidget {
  const _WindowFooter({required this.vm, required this.canOpenReport});

  final ActivityViewModel vm;

  /// Whether this company may open the Activity report — the link goes only
  /// where the route's own guard would let it.
  final bool canOpenReport;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: InSpacing.lg(context)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr('activity_feed_window', {'count': '${vm.windowCount}'}),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: tokens.ink3),
          ),
          if (vm.canLoadMore) ...[
            SizedBox(height: InSpacing.md(context)),
            OutlinedButton.icon(
              // A centred single button renders edge to edge without its own
              // minimum (docs/buttons-and-spacing.md § Centered single-action
              // buttons must constrain their own width too).
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: vm.isLoadingMore ? null : vm.loadMore,
              icon: vm.isLoadingMore
                  ? const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.history, size: 16),
              label: Text(context.tr('load_more')),
            ),
            if (vm.loadMoreFailed) ...[
              const SizedBox(height: InSpacing.xs),
              Text(
                context.tr('couldnt_load_tap_to_retry', {
                  'section': context.tr('activity').toLowerCase(),
                }),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: tokens.overdue),
              ),
            ],
          ] else if (vm.atWindowMax && canOpenReport) ...[
            SizedBox(height: InSpacing.sm),
            TextButton.icon(
              onPressed: () => context.go('/reports/activity'),
              icon: const Icon(Icons.assessment_outlined, size: 16),
              label: Text(context.tr('activity_open_report')),
            ),
          ],
        ],
      ),
    );
  }
}
