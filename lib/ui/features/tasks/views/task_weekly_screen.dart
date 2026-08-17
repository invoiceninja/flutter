import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/utils/calendar_week_start.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/features/shell/widgets/app_drawer.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/tasks/view_models/task_weekly_view_model.dart';
import 'package:admin/ui/features/tasks/views/task_list_screen.dart';
import 'package:admin/ui/features/tasks/widgets/daily/task_daily_actions.dart';
import 'package:admin/ui/features/tasks/widgets/task_filter_bar.dart';
import 'package:admin/ui/features/tasks/widgets/tasks_view_toggle.dart';
import 'package:admin/ui/features/tasks/widgets/weekly/weekly_grid.dart';
import 'package:admin/utils/formatting.dart';

/// Weekly timesheet view: a task × 7-day grid of editable duration cells.
/// Mirrors the kanban-screen shape; additionally listens to the VM's error
/// nonce to surface validation toasts (the VM holds no `BuildContext`).
class TaskWeeklyScreen extends StatefulWidget {
  const TaskWeeklyScreen({super.key, this.focusDate});

  /// Seeds the focused week (from `?date=`); null defaults to today's week.
  final Date? focusDate;

  @override
  State<TaskWeeklyScreen> createState() => _TaskWeeklyScreenState();
}

class _TaskWeeklyScreenState extends State<TaskWeeklyScreen> {
  late final Services _services;
  late String _companyId;
  late TaskWeeklyViewModel _vm;
  Formatter? _formatter;
  int _lastErrorNonce = 0;

  /// Whether the locale-aware week start has been applied once — see
  /// [_applyCalendarWeekStart] for why only the first application is
  /// synchronous.
  bool _weekStartApplied = false;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _formatter = _services.formatterIfReady(_companyId);
    _vm = _buildVm();
    _vm.addListener(_onVmChanged);
    _services.auth.session.addListener(_onSessionChanged);
    _resolveFormatter();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The rendered week start needs `MaterialLocalizations`, which isn't
    // reachable from `initState` — so the VM is seeded with the company value
    // there and corrected here (and again on any locale change).
    _applyCalendarWeekStart();
  }

  /// Align the week strip's start day with every other rendered calendar in the
  /// app.
  ///
  /// The FIRST call runs synchronously: `didChangeDependencies` precedes this
  /// widget's first `build`, so the provider hasn't subscribed to the VM yet and
  /// there is nothing to notify — and applying it now means frame 1 already
  /// paints the right week instead of flashing the wrong one and correcting.
  ///
  /// Every later call defers a frame, because by then the body watches this VM
  /// and `setFirstDayOfWeek` notifies — doing that from inside the build phase
  /// would be a setState-during-build on a mounted descendant. The VM's own
  /// no-change guard means the steady state schedules nothing.
  void _applyCalendarWeekStart() {
    final value = calendarFirstDayOfWeek(context, _formatter);
    if (value == _vm.firstDayOfWeek) return;
    if (!_weekStartApplied) {
      _weekStartApplied = true;
      _vm.setFirstDayOfWeek(value);
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _vm.setFirstDayOfWeek(value);
    });
  }

  TaskWeeklyViewModel _buildVm() => TaskWeeklyViewModel(
    repo: _services.tasks,
    companyId: _companyId,
    firstDayOfWeek: _formatter?.settings.firstDayOfWeek ?? 0,
    focus: widget.focusDate,
  );

  Future<void> _resolveFormatter() async {
    final forCompany = _companyId;
    final f = await _services.formatterFor(forCompany);
    // Bail if the company switched while we were resolving — otherwise the old
    // company's first-day-of-week lands on the new company's VM.
    if (!mounted || forCompany != _companyId) return;
    setState(() => _formatter = f);
    _applyCalendarWeekStart();
  }

  void _onVmChanged() {
    if (_vm.errorNonce == _lastErrorNonce) return;
    _lastErrorNonce = _vm.errorNonce;
    // Blank guard as well as null: `tr('')` returns `''`, which would toast an
    // empty card rather than an error.
    final key = _vm.lastError?.trim();
    if (key != null && key.isNotEmpty && mounted) {
      Notify.error(context, context.tr(key));
    }
  }

  void _onSessionChanged() {
    final s = _services.auth.session.value;
    if (s == null || s.currentCompanyId == _companyId) return;
    final old = _vm;
    _companyId = s.currentCompanyId;
    _formatter = _services.formatterIfReady(_companyId);
    setState(() {
      _vm = _buildVm();
      _lastErrorNonce = 0;
    });
    _vm.addListener(_onVmChanged);
    old.removeListener(_onVmChanged);
    old.dispose();
    _resolveFormatter();
  }

  @override
  void dispose() {
    _services.auth.session.removeListener(_onSessionChanged);
    _vm.removeListener(_onVmChanged);
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildTasksViewAppBar(context, TasksViewMode.weekly),
      // The drawer itself — the AppBar's hamburger needs something to
      // open. Mirrors `EntityListScreenScaffold`, which attaches it the
      // same way for the list view.
      drawer: Breakpoints.isGlobalNavVisible(context)
          ? null
          : const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        tooltip: context.tr('new_task'),
        onPressed: () => goToCreateRoute(context, '/tasks/new'),
        child: const Icon(Icons.add),
      ),
      body: ChangeNotifierProvider<TaskWeeklyViewModel>.value(
        value: _vm,
        child: Column(
          children: [
            TaskFilterBar(filters: _vm, companyId: _companyId),
            _WeeklyHeader(formatter: _formatter),
            Expanded(child: WeeklyGrid(formatter: _formatter)),
          ],
        ),
      ),
    );
  }
}

class _WeeklyHeader extends StatelessWidget {
  const _WeeklyHeader({this.formatter});

  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TaskWeeklyViewModel>();
    final tokens = context.inTheme;
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.wide;
    final rangeLabel =
        formatter?.dateRange(vm.weekStart.toIso(), vm.weekEnd.toIso()) ??
        '${vm.weekStart.toIso()} – ${vm.weekEnd.toIso()}';
    final grandTotal = vm.rows.fold<int>(
      0,
      (sum, t) => sum + vm.weekTotalFor(t.id),
    );
    final hoursLabel = weeklyHoursText(grandTotal, formatter);

    // Seed "log time" on today when it falls in the visible week, else the
    // week's first day.
    final today = Date.today();
    final inWeek =
        today.compareTo(vm.weekStart) >= 0 && today.compareTo(vm.weekEnd) <= 0;
    final logDay = inWeek ? today : vm.weekStart;

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: InSpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: context.tr('previous'),
            icon: const Icon(Icons.chevron_left),
            onPressed: vm.prevWeek,
          ),
          IconButton(
            tooltip: context.tr('next'),
            icon: const Icon(Icons.chevron_right),
            onPressed: vm.nextWeek,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  rangeLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (hoursLabel.isNotEmpty)
                  Text(
                    '$hoursLabel ${context.tr('hours')}',
                    style: TextStyle(fontSize: 12, color: tokens.ink3),
                  ),
              ],
            ),
          ),
          if (wide)
            TextButton(
              onPressed: vm.goToToday,
              child: Text(context.tr('today')),
            )
          else
            IconButton(
              tooltip: context.tr('today'),
              icon: const Icon(Icons.today_outlined),
              onPressed: vm.goToToday,
            ),
          const SizedBox(width: 8),
          if (wide)
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: () => TaskDailyActions.logTime(context, logDay),
              icon: const Icon(Icons.add, size: 18),
              label: Text(context.tr('log_time')),
            )
          else
            IconButton.filledTonal(
              tooltip: context.tr('log_time'),
              onPressed: () => TaskDailyActions.logTime(context, logDay),
              icon: const Icon(Icons.add),
            ),
        ],
      ),
    );
  }
}
