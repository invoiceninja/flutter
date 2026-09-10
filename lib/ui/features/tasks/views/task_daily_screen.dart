import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/features/shell/widgets/app_drawer.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/features/tasks/view_models/task_daily_view_model.dart';
import 'package:admin/ui/features/tasks/views/task_list_screen.dart';
import 'package:admin/ui/features/tasks/widgets/daily/task_daily_actions.dart';
import 'package:admin/ui/features/tasks/widgets/daily/task_daily_entry_row.dart';
import 'package:admin/ui/features/tasks/widgets/daily/task_daily_header.dart';
import 'package:admin/ui/features/tasks/widgets/task_filter_bar.dart';
import 'package:admin/ui/features/tasks/widgets/task_filters_sheet.dart';
import 'package:admin/ui/features/tasks/widgets/tasks_view_toggle.dart';
import 'package:admin/utils/formatting.dart';

/// Daily timeline view: a single day's time entries across all tasks, with
/// start/stop, log-time, and duplicate-yesterday. Mirrors the kanban-screen
/// shape (own VM, company-switch rebuild, shared AppBar toggle).
class TaskDailyScreen extends StatefulWidget {
  const TaskDailyScreen({super.key, this.focusDate});

  /// Seeds the focused day (from `?date=`); null defaults to today.
  final Date? focusDate;

  @override
  State<TaskDailyScreen> createState() => _TaskDailyScreenState();
}

class _TaskDailyScreenState extends State<TaskDailyScreen> {
  late final Services _services;
  late String _companyId;
  late TaskDailyViewModel _vm;
  Formatter? _formatter;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _formatter = _services.formatterIfReady(_companyId);
    _vm = TaskDailyViewModel(
      repo: _services.tasks,
      companyId: _companyId,
      focusDay: widget.focusDate,
    );
    _services.auth.session.addListener(_onSessionChanged);
    _resolveFormatter();
  }

  Future<void> _resolveFormatter() async {
    final forCompany = _companyId;
    final f = await _services.formatterFor(forCompany);
    if (!mounted || forCompany != _companyId) return;
    setState(() => _formatter = f);
  }

  void _onSessionChanged() {
    final s = _services.auth.session.value;
    if (s == null || s.currentCompanyId == _companyId) return;
    final old = _vm;
    _companyId = s.currentCompanyId;
    _formatter = _services.formatterIfReady(_companyId);
    setState(() {
      _vm = TaskDailyViewModel(repo: _services.tasks, companyId: _companyId);
    });
    old.dispose();
    _resolveFormatter();
  }

  @override
  void dispose() {
    _services.auth.session.removeListener(_onSessionChanged);
    _vm.dispose();
    super.dispose();
  }

  /// The single call site per screen: the AppBar's filter action and the chip
  /// strip's chips both route here, so the sheet's arguments cannot drift
  /// between them.
  void _openFilters() =>
      openTaskFilters(context, filters: _vm, companyId: _companyId);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // One gate, all of this screen's consumers of it — the AppBar's
        // flavour, its filter action, the bar's own layout and, on the three
        // time-oriented views, the view header. `Scaffold.appBar` is built
        // outside the body so the bar can never inform it, and two gates
        // disagree in the 600-832 px band; see `taskFiltersInline`. Same shape
        // as `EntityListScreenScaffold`, which reads `wide` here too.
        final wide = Breakpoints.isWide(constraints);
        final inline = taskFiltersInline(
          paneWidth: constraints.maxWidth,
          isPhone: Breakpoints.isPhone(context),
        );
        return Scaffold(
          appBar: buildTasksViewAppBar(
            context,
            TasksViewMode.daily,
            wide: wide,
            // Both null while the pickers render inline — a second entry point
            // there would be redundant chrome over the row itself.
            filters: inline ? null : _vm,
            onEditFilters: _openFilters,
          ),
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
          body: ChangeNotifierProvider<TaskDailyViewModel>.value(
            value: _vm,
            child: Column(
              children: [
                TaskFilterBar(
                  filters: _vm,
                  companyId: _companyId,
                  inline: inline,
                  onEditFilters: _openFilters,
                ),
                TaskDailyHeader(formatter: _formatter, wide: wide),
                Expanded(
                  child: _DailyList(
                    formatter: _formatter,
                    companyId: _companyId,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DailyList extends StatelessWidget {
  const _DailyList({required this.companyId, this.formatter});

  final String companyId;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TaskDailyViewModel>();
    final rows = vm.rows;
    if (rows.isEmpty) {
      // A filtered day that yields nothing is not an empty day, and the generic
      // copy plus a `Log time` button is a dead end twice over: nothing says a
      // filter is responsible, and the entry that button creates may be hidden
      // by that same filter the moment it is saved. Same escape hatch
      // `EntityListScreenScaffold._emptyState` gives every entity list, and the
      // same two existing Transifex keys — but *not* by inheriting it: these
      // four custom views never go through that scaffold at all, and the
      // entities its comment lists as having fallen through are entity lists,
      // the Tasks *list* among them. This is a fourth hand-rolled copy of that
      // decision, which is why the predicate below can be the honest one.
      // It matters more now that the pickers collapse: they used to be the
      // explanation, sitting directly above the emptiness.
      //
      // Gated on `hasFilteredOutRows`, never on `filtersActive`: a day with
      // nothing logged is equally empty either way, and that user would be sent
      // to clear a filter that reveals nothing while losing the `Log time`
      // action they actually came for.
      if (vm.hasFilteredOutRows) {
        return EmptyState(
          icon: Icons.filter_alt_off_outlined,
          title: context.tr('no_records_found'),
          action: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: vm.clearFilters,
            icon: const Icon(Icons.close),
            label: Text(context.tr('clear_filters')),
          ),
        );
      }
      return EmptyState(
        icon: Icons.schedule_outlined,
        title: context.tr('no_records_found'),
        action: FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
          onPressed: () => TaskDailyActions.logTime(context, vm.day),
          icon: const Icon(Icons.add, size: 18),
          label: Text(context.tr('log_time')),
        ),
      );
    }
    final tokens = context.inTheme;
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: tokens.border),
      itemBuilder: (context, i) {
        final row = rows[i];
        return TaskDailyEntryRow(
          task: row.task,
          entry: row.entry,
          companyId: companyId,
          formatter: formatter,
        );
      },
    );
  }
}
