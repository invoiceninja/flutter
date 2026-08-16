import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/calendar_week_start.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/features/tasks/view_models/calendar_connection_view_model.dart';
import 'package:admin/ui/features/tasks/view_models/task_calendar_view_model.dart';
import 'package:admin/ui/features/tasks/views/task_list_screen.dart';
import 'package:admin/ui/features/tasks/widgets/calendar/calendar_connect_menu.dart';
import 'package:admin/ui/features/tasks/widgets/calendar/task_calendar_grid.dart';
import 'package:admin/ui/features/tasks/widgets/calendar/task_calendar_header.dart';
import 'package:admin/ui/features/tasks/widgets/task_filter_bar.dart';
import 'package:admin/ui/features/tasks/widgets/tasks_view_toggle.dart';
import 'package:admin/utils/formatting.dart';

/// Monthly calendar view for tasks. Mirrors the kanban-screen shape: owns its
/// own [TaskCalendarViewModel], rebuilds it on company switch, and carries the
/// shared [TasksViewToggle] in the AppBar. The `Formatter` is resolved once and
/// passed down for the month label + weekday headers.
///
/// Also hosts the calendar-connection surface (a [CalendarConnectionViewModel]):
/// the connect menu + live Google/Microsoft event chips overlaid on the grid.
/// That VM is user-scoped (not company-scoped) so it survives a company switch;
/// events reload whenever the visible month window or connection status changes.
class TaskCalendarScreen extends StatefulWidget {
  const TaskCalendarScreen({super.key, this.focusDate});

  /// Seeds the focused month (from `?date=`); null defaults to the current
  /// month.
  final Date? focusDate;

  @override
  State<TaskCalendarScreen> createState() => _TaskCalendarScreenState();
}

class _TaskCalendarScreenState extends State<TaskCalendarScreen> {
  late final Services _services;
  late String _companyId;
  late TaskCalendarViewModel _vm;
  late final CalendarConnectionViewModel _calVm;
  Formatter? _formatter;

  // Guards against redundant event loads: the last window we fetched, and
  // whether we've seen a connected state (to force a reload on the connect
  // transition).
  String? _loadedWindowKey;
  bool _wasConnected = false;

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
    _vm = TaskCalendarViewModel(
      repo: _services.tasks,
      companyId: _companyId,
      firstDayOfWeek: _formatter?.settings.firstDayOfWeek ?? 0,
      focusMonth: widget.focusDate,
    );
    _calVm = CalendarConnectionViewModel(repo: _services.calendarConnection);
    _vm.addListener(_onTaskVmChanged);
    _calVm.addListener(_onCalVmChanged);
    _services.auth.session.addListener(_onSessionChanged);
    _resolveFormatter();
    _initCalendar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The rendered week start needs `MaterialLocalizations`, which isn't
    // reachable from `initState` — so the VM is seeded with the company value
    // there and corrected here (and again on any locale change).
    _applyCalendarWeekStart();
  }

  /// Align the grid's week start with every other rendered calendar in the app.
  ///
  /// The FIRST call runs synchronously: `didChangeDependencies` precedes this
  /// widget's first `build`, so the provider hasn't subscribed to the VM yet and
  /// there is nothing to notify — and applying it now means frame 1 already
  /// paints the right week start instead of flashing Sunday and correcting.
  ///
  /// Every later call defers a frame, because by then `TaskCalendarGrid` watches
  /// this VM and `setFirstDayOfWeek` notifies — doing that from inside the build
  /// phase would be a setState-during-build on a mounted descendant. The VM's
  /// own no-change guard means the steady state schedules nothing at all.
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

  bool get _calendarAvailable => CalendarConnectMenu.isAvailable(_services);

  Future<void> _initCalendar() async {
    if (!_calendarAvailable) return;
    await _calVm.loadStatus();
    if (!mounted) return;
    _maybeLoadEvents();
  }

  // Reload events when the visible window changes (month / first-day-of-week).
  void _onTaskVmChanged() => _maybeLoadEvents();

  // Force a reload the moment we transition to connected (e.g. the native
  // deep-link complete flow finished while this screen stayed mounted).
  void _onCalVmChanged() {
    if (_calVm.isConnected && !_wasConnected) {
      _wasConnected = true;
      _loadedWindowKey = null;
      _maybeLoadEvents();
    } else if (!_calVm.isConnected) {
      _wasConnected = false;
    }
  }

  void _maybeLoadEvents() {
    if (!_calendarAvailable || !_calVm.isConnected) return;
    final days = _vm.gridDays;
    final key = '${days.first.toIso()}_${days.last.toIso()}';
    if (key == _loadedWindowKey) return;
    _loadedWindowKey = key;
    _calVm.loadEvents(
      from: days.first.toDateTime(),
      to: days.last.toDateTime().add(const Duration(days: 1)),
    );
  }

  Future<void> _resolveFormatter() async {
    final forCompany = _companyId;
    final f = await _services.formatterFor(forCompany);
    // Bail if the company switched while we were resolving — otherwise the old
    // company's first-day-of-week lands on the new company's VM.
    if (!mounted || forCompany != _companyId) return;
    setState(() => _formatter = f);
    _applyCalendarWeekStart();
  }

  void _onSessionChanged() {
    final s = _services.auth.session.value;
    if (s == null || s.currentCompanyId == _companyId) return;
    final old = _vm;
    _companyId = s.currentCompanyId;
    _formatter = _services.formatterIfReady(_companyId);
    setState(() {
      _vm = TaskCalendarViewModel(
        repo: _services.tasks,
        companyId: _companyId,
        firstDayOfWeek: _formatter?.settings.firstDayOfWeek ?? 0,
      );
    });
    old.removeListener(_onTaskVmChanged);
    old.dispose();
    _vm.addListener(_onTaskVmChanged);
    // The connection is user-scoped, so it's unchanged — just reload events for
    // the new VM's window.
    _loadedWindowKey = null;
    _maybeLoadEvents();
    _resolveFormatter();
  }

  @override
  void dispose() {
    _services.auth.session.removeListener(_onSessionChanged);
    _vm.removeListener(_onTaskVmChanged);
    _calVm.removeListener(_onCalVmChanged);
    _vm.dispose();
    _calVm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildTasksViewAppBar(context, TasksViewMode.calendar),
      floatingActionButton: FloatingActionButton(
        tooltip: context.tr('new_task'),
        onPressed: () => goToCreateRoute(context, '/tasks/new'),
        child: const Icon(Icons.add),
      ),
      body: MultiProvider(
        providers: [
          ChangeNotifierProvider<TaskCalendarViewModel>.value(value: _vm),
          ChangeNotifierProvider<CalendarConnectionViewModel>.value(
            value: _calVm,
          ),
        ],
        child: Column(
          children: [
            TaskFilterBar(filters: _vm, companyId: _companyId),
            TaskCalendarHeader(formatter: _formatter),
            Expanded(child: TaskCalendarGrid(formatter: _formatter)),
          ],
        ),
      ),
    );
  }
}
