import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/features/shell/widgets/app_drawer.dart';
import 'package:admin/ui/features/tasks/view_models/kanban_view_model.dart';
import 'package:admin/ui/features/tasks/views/task_list_screen.dart';
import 'package:admin/ui/features/tasks/widgets/kanban/kanban_board.dart';
import 'package:admin/ui/features/tasks/widgets/task_filter_bar.dart';
import 'package:admin/ui/features/tasks/widgets/tasks_view_toggle.dart';

/// Top-level kanban screen. Mounts its own [KanbanViewModel] (separate from
/// the list VM) and renders the board. AppBar carries the same toggle the
/// list screen has so the user can flip back.
class KanbanScreen extends StatefulWidget {
  const KanbanScreen({super.key});

  @override
  State<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends State<KanbanScreen> {
  late final Services _services;
  late String _companyId;
  late KanbanViewModel _vm;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = KanbanViewModel(
      repo: _services.tasks,
      statusRepo: _services.taskStatuses,
      companyId: _companyId,
    );
    _services.auth.session.addListener(_onSessionChanged);
  }

  void _onSessionChanged() {
    final s = _services.auth.session.value;
    if (s == null || s.currentCompanyId == _companyId) return;
    final old = _vm;
    setState(() {
      _companyId = s.currentCompanyId;
      _vm = KanbanViewModel(
        repo: _services.tasks,
        statusRepo: _services.taskStatuses,
        companyId: _companyId,
      );
    });
    old.dispose();
  }

  @override
  void dispose() {
    _services.auth.session.removeListener(_onSessionChanged);
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildTasksViewAppBar(context, TasksViewMode.kanban),
      // The drawer itself — the AppBar's hamburger needs something to
      // open. Mirrors `EntityListScreenScaffold`, which attaches it the
      // same way for the list view.
      drawer: Breakpoints.isGlobalNavVisible(context)
          ? null
          : const AppDrawer(),
      // Deliberately no `floatingActionButton` — the one Tasks view that can
      // drop it, because a FAB may only go where the substitute is the SAME
      // verb. Every column ends in its own `+ New Task`, which is a plain
      // new-task create and a better one (it seeds the column's status, so the
      // task lands where the user clicked; this FAB seeded nothing, and on a
      // phone `endFloat` put it over the footer of whichever column was
      // scrolled to the right edge). Daily and weekly are NOT a precedent: they
      // do have a second create, but it is `TaskDailyActions.logTime` behind a
      // `Log time` button — a different verb that pre-fills a time entry — so
      // dropping their FAB would make a plain new task unreachable there;
      // calendar's only other create is convert-this-event. React's kanban has
      // no page-level create control either (invoiceninja/flutter#135).
      // `test/lint/tasks_view_wiring_test.dart` fails the build if one returns.
      body: ChangeNotifierProvider<KanbanViewModel>.value(
        value: _vm,
        child: Column(
          children: [
            TaskFilterBar(filters: _vm, companyId: _vm.companyId),
            const Expanded(child: KanbanBoard()),
          ],
        ),
      ),
    );
  }
}
