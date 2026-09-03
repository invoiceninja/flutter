import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_activity.dart';
import 'package:admin/data/services/dashboard_api.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/ui/features/activity/activity_deep_link.dart';
import 'package:admin/ui/features/activity/view_models/activity_view_model.dart';
import 'package:admin/ui/features/activity/widgets/activity_feed_row.dart';
import 'package:admin/ui/features/activity/widgets/activity_filter_sheet.dart';
import 'package:admin/ui/features/dashboard/helpers/activity_formatter.dart';
import 'package:admin/ui/features/dashboard/widgets/freshness.dart';
import 'package:admin/ui/features/shell/widgets/app_drawer.dart';
import 'package:admin/utils/formatting.dart';

/// The company-wide activity feed at `/activity` (invoiceninja/flutter#53).
///
/// Reads the same Drift cache row as the dashboard's Activity card, so it
/// paints from cache immediately and refreshing either surface updates both.
/// Unlike the card it renders every row in the window, day-grouped, and
/// narrowable by user / type / text / comments-only.
///
/// Owns the [Formatter] and the [ActivityViewModel] — both rebuilt on
/// company-switch via the auth session listener (not via `build`, which would
/// dispose a notifier mid-rebuild). Mirrors `ReportsScreen`.
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
  }

  void _loadFormatter() {
    final loadingFor = _companyId;
    _services.formatterFor(loadingFor).then((f) {
      if (!mounted || loadingFor != _companyId) return;
      setState(() => _formatter = f);
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
          ListenableBuilder(
            listenable: _vm,
            builder: (context, _) => _FilterButton(
              activeCount: _vm.filters.activeCount,
              onPressed: () =>
                  openActivityFilters(context, vm: _vm, companyId: _companyId),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
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
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) => _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
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

    return Column(
      children: [
        _HeaderStrip(vm: _vm),
        Divider(height: 1, color: tokens.border),
        Expanded(
          child: Env.isMobile ? scrollable : SelectionArea(child: scrollable),
        ),
      ],
    );
  }

  Widget _list(BuildContext context) {
    final entries = _vm.entries;
    // Only when the server actually capped us. Below the cap nothing is hidden,
    // so the footer would assert a truncation that isn't happening — and on a
    // filtered list it reads as "there should be more rows here".
    final showFooter = _vm.windowCount >= kActivityFeedRows;
    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: InSpacing.sm,
      ),
      // +1 for the window footer, but only when there is one to show.
      itemCount: entries.length + (showFooter ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == entries.length) return _WindowFooter(count: _vm.windowCount);
        final entry = entries[i];
        return switch (entry) {
          ActivityDayHeader() => _DayHeader(
            day: entry.day,
            formatter: _formatter,
          ),
          ActivityFeedItem() => _row(context, entry.activity),
        };
      },
    );
  }

  Widget _row(BuildContext context, DashboardActivity a) {
    final render = ActivityFormatter(context).format(a);
    return ActivityFeedRow(
      render: render,
      meta: activityAuditMeta(a, render: render, formatter: _formatter),
      onTap: activityDeepLinkTarget(a) == null ? null : () => _onRowTap(a),
    );
  }
}

/// Filter affordance with a dot when any filter is on, so the narrowed state is
/// visible without opening the sheet.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.activeCount, required this.onPressed});

  final int activeCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return IconButton(
      tooltip: context.tr('filters'),
      onPressed: onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.filter_alt_outlined),
          if (activeCount > 0)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: tokens.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Freshness stamp plus, when narrowed, the surviving-row count and removable
/// filter chips. Renders no chips at all in the default (unfiltered) view so
/// the screen carries no extra chrome for the common case.
class _HeaderStrip extends StatelessWidget {
  const _HeaderStrip({required this.vm});

  final ActivityViewModel vm;

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
    // the app (`multi_entity_picker`, `multi_product_picker`, `reports_body`)
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

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.formatter});

  final DateTime day;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Padding(
      padding: EdgeInsets.only(top: InSpacing.md(context), bottom: 2),
      child: Text(
        dayHeaderLabel(context, day, formatter),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: tokens.ink3,
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

/// Explains the feed's ceiling at the end of the list — shown only once the
/// server has actually capped us at [kActivityFeedRows] (`?reactv2` is
/// unpaginated, so that is a hard boundary, not a page).
///
/// Phrased as a statement about the feed's *scope* rather than a row count, so
/// it stays true — and doesn't read as "rows are missing" — while a filter is
/// narrowing the list beneath it. The match count lives in the header strip.
class _WindowFooter extends StatelessWidget {
  const _WindowFooter({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: InSpacing.lg(context)),
      child: Center(
        child: Text(
          context.tr('activity_feed_window', {'count': '$count'}),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: tokens.ink3),
        ),
      ),
    );
  }
}
