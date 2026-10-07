import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/tasks/view_models/task_edit_view_model.dart'
    show emptyTask;

/// Type a description, press Enter, get a task on this project
/// (invoiceninja/ui#3383). Built for rapid entry: focus stays in the field
/// after each create, Escape clears it, and there is no toast — the new task
/// appearing in the list right under the field is the feedback (an unsynced
/// create sorts first). The list's own New button stays for the full form.
///
/// It heads the project's **Tasks tab**. It used to sit in a Tasks card above
/// the tabs, over a second copy of the list the tab one scroll down already
/// showed.
class ProjectQuickAddTask extends StatefulWidget {
  const ProjectQuickAddTask({
    super.key,
    required this.project,
    required this.companyId,
  });

  final Project project;
  final String companyId;

  /// Whether the field is offered: only where a task could be created at all,
  /// and not on an archived, deleted or not-yet-synced project.
  static bool appliesTo(Project project, {required bool canCreateTask}) =>
      canCreateTask &&
      project.archivedAt == null &&
      !project.isDeleted &&
      !project.id.startsWith('tmp_');

  @override
  State<ProjectQuickAddTask> createState() => _ProjectQuickAddTaskState();
}

class _ProjectQuickAddTaskState extends State<ProjectQuickAddTask> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final description = _controller.text.trim();
    if (description.isEmpty || _busy) return;
    final services = context.read<Services>();
    final p = widget.project;
    setState(() => _busy = true);
    try {
      // The company's first status (board order), never blank: a blank
      // status puts the task in no kanban column until the server assigns
      // one — offline, never (see `create_task_from_line_item_sheet.dart`).
      final statuses = await services.taskStatuses
          .watchAll(companyId: widget.companyId)
          .first;
      await services.tasks.create(
        companyId: widget.companyId,
        draft: emptyTask().copyWith(
          description: description,
          projectId: p.id,
          clientId: p.clientId,
          rate: p.taskRate,
          statusId: statuses.isEmpty ? '' : statuses.first.id,
          // Orders this create among other unsynced ones — see
          // `TaskDao.watchForProject`.
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      if (!mounted) return;
      _controller.clear();
      _focus.requestFocus();
    } catch (e) {
      if (mounted) {
        Notify.error(context, context.tr('could_not_save'), error: e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          _controller.clear();
          _focus.unfocus();
        },
      },
      child: TextField(
        key: const Key('project_quick_add_task'),
        controller: _controller,
        focusNode: _focus,
        textInputAction: TextInputAction.done,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _create(),
        // Keep focus (and the soft keyboard) up between creates.
        onEditingComplete: () {},
        decoration: InputDecoration(
          isDense: true,
          hintText: context.tr('new_task'),
          prefixIcon: Icon(Icons.add, size: 18, color: tokens.ink3),
          // The app's Enter glyph, on a keyboard-first device only — it says
          // "press Enter" to someone who has one.
          suffixIcon: Env.isTouchPrimary
              ? null
              : ExcludeSemantics(
                  child: Center(
                    widthFactor: 1,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Opacity(
                        opacity: 0.5,
                        child: Text('↵', style: TextStyle(color: tokens.ink3)),
                      ),
                    ),
                  ),
                ),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
