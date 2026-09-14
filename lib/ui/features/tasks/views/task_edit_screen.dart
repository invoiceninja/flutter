import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/edit/after_save_create_action.dart';
import 'package:admin/ui/core/edit/edit_action_filter.dart';
import 'package:admin/ui/core/edit/entity_edit_screen_scaffold.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/features/tasks/view_models/task_edit_view_model.dart';
import 'package:admin/ui/features/tasks/widgets/edit/task_edit_layout.dart';
import 'package:admin/ui/features/tasks/widgets/task_actions.dart';

/// Edit + Create form for a Task. Standard scaffold wiring; the body is
/// in `TaskEditLayout`, which composes the identity / times / custom-fields
/// sections.
///
/// Stateful so we can hold a [Formatter] resolved via
/// [FormatterHostMixin] — the time-log rows render their date portion
/// through this formatter so the date layout honors the company setting.
class TaskEditScreen extends StatefulWidget {
  const TaskEditScreen({this.existingId, this.cloneFrom, super.key});

  final String? existingId;

  /// Edit-mode override draft (parallels InvoiceEditScreen). Null for a normal
  /// edit and for create (which reads the staged draft via
  /// `Services.takeCreateDraft`).
  final Task? cloneFrom;

  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen>
    with FormatterHostMixin {
  late final Services _services;
  late String _companyId;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    loadFormatter(_services, _companyId);
    _services.auth.session.addListener(_onSessionChanged);
  }

  void _onSessionChanged() {
    final s = _services.auth.session.value;
    if (s == null || s.currentCompanyId == _companyId) return;
    _companyId = s.currentCompanyId;
    clearFormatter();
    loadFormatter(_services, _companyId);
  }

  @override
  void dispose() {
    _services.auth.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EntityEditScreenScaffold<Task, TaskEditViewModel>(
      existingId: widget.existingId,
      entityTypeName: 'task',
      fetchExisting: (ctx, services, companyId, id) =>
          services.tasks.watch(companyId: companyId, id: id).first,
      buildVm: (ctx, services, companyId, existing) {
        // Create-mode seed staged on `Services` (route extra:/query is dropped
        // cross-branch + on screen reuse); the keyed `/new` route recreates the
        // screen on each stage so buildVm re-reads it. `cloneFrom` is the
        // edit-mode override.
        final clone =
            widget.cloneFrom ??
            (existing == null
                ? services.takeCreateDraft<Task>('/tasks')
                : null);
        final vm = TaskEditViewModel(
          repo: services.tasks,
          companyId: companyId,
          now: DateTime.now,
          existing: existing,
          cloneFrom: clone,
          useCommaAsDecimalPlace:
              services
                  .formatterIfReady(companyId)
                  ?.settings
                  .useCommaAsDecimalPlace ??
              false,
          sync: services.sync,
          connectivity: services.connectivity,
        );
        // Seed the project picker on first build. Fire-and-forget — the
        // watch resolves the project once Drift has it, then runs the
        // same selectProject side-effects as the dropdown (sets clientId,
        // conditionally fills rate, locks the client picker).
        //
        // `unawaited` so the analyzer accepts the dropped future; the
        // `.catchError` is defensive so a transient stream error (e.g.
        // Drift restarted mid-rebuild) doesn't surface as an uncaught
        // zone exception. If the project isn't cached locally (offline +
        // never synced) the resolved value is null and we no-op — the
        // user can pick the project manually from the dropdown.
        // Wrapped in postFrame so the scaffold's listeners are attached
        // before vm.selectProject's notifyListeners fires. See
        // InvoiceEditScreen for the full trace.
        // Embedded Project → Tasks-tab "New" stages a draft with a projectId
        // but no client; resolve the project so `selectProject` sets clientId +
        // (when rate is zero) the project task_rate. Actions that bake the
        // clientId skip this.
        final seedProjectId =
            (clone != null &&
                clone.projectId.isNotEmpty &&
                clone.clientId.isEmpty)
            ? clone.projectId
            : null;
        if (seedProjectId != null && existing == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(
              services.projects
                  .watch(companyId: companyId, id: seedProjectId)
                  .first
                  .then((project) {
                    if (project != null) vm.selectProject(project);
                  })
                  .catchError((Object _) {}),
            );
          });
        }
        // Auto-start: when `auto_start_tasks` is on, a brand-new task begins
        // with a running timer (admin-portal parity). Clones carry their own
        // entries, so skip them. Fire-and-forget, post-frame so the
        // scaffold's listeners are attached before the seed notifies.
        // Auto-start applies to any new task; `applyAutoStartIfEmpty` no-ops
        // when the staged draft already carries time entries (a clone).
        if (existing == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(
              services.company
                  .get(companyId)
                  .then((company) {
                    if (company?.autoStartTasks ?? false) {
                      vm.applyAutoStartIfEmpty();
                    }
                  })
                  .catchError((Object _) {}),
            );
          });
        }
        return vm;
      },
      titleWhileLoading: (ctx) =>
          widget.existingId == null ? ctx.tr('new_task') : ctx.tr('edit'),
      titleBuilder: (ctx, vm) => vm.isCreate
          ? ctx.tr('new_task')
          : (vm.draft.description.isNotEmpty
                ? '${ctx.tr('edit')} · ${vm.draft.description}'
                : ctx.tr('edit')),
      // Invoiced tasks are server-immutable — hide the Save button so the
      // user can't enqueue a doomed mutation. The lockout banner inside
      // the body explains why the form is read-only.
      // A log the server would reject can't be saved: `checkTimeLog` 422s the
      // whole payload, and the outbox has no way to show that as a field error
      // — the row just dead-letters minutes later. The times section names the
      // problem inline; this stops it being queued at all.
      canSave: (vm) =>
          !vm.isSaving &&
          !vm.draft.isInvoiced &&
          vm.draftTimeLogProblem == null,
      bodyBuilder: (ctx, vm) => TaskEditLayout(vm: vm, formatter: formatter),
      resetToEmpty: (vm) => vm.resetToEmpty(),
      entityIdOf: (t) => t.id,
      actionsBuilder: (ctx, vm, onTap, saveButton) =>
          EntityOverflowActionBar<TaskAction>(
            leading: saveButton,
            items: filterForEditScreen(
              TaskActions.itemsFor(ctx, vm.draft, (a) => onTap(a)),
              isCreate: vm.isCreate,
              isLifecycle: TaskActions.isLifecycle,
            ),
          ),
      onAfterSaveAction: (ctx, saved, a) {
        final services = ctx.read<Services>();
        return TaskActions.dispatch(
          ctx,
          services,
          services.auth.session.value!.currentCompanyId,
          saved,
          a as TaskAction,
        );
      },
      // Create-mode: resolve the tmp id to the real one so New Invoice keeps its
      // navigation instead of the detail redirect.
      onAfterSaveActionOnCreate: (ctx, saved, a) {
        final services = ctx.read<Services>();
        final companyId = services.auth.session.value!.currentCompanyId;
        return dispatchAfterSaveOnCreate<Task, TaskAction>(
          ctx,
          saved: saved,
          idOf: (t) => t.id,
          withId: (t, id) => t.copyWith(id: id),
          resolveId: services.tasks.resolveId,
          action: a as TaskAction,
          navigatesOnCreate: TaskActions.navigatesOnCreate,
          dispatch: (c, resolved, act) =>
              TaskActions.dispatch(c, services, companyId, resolved, act),
        );
      },
      onSaved: (ctx, vm, saved) => goAfterEntitySave(
        ctx,
        isCreate: vm.isCreate,
        basePath: '/tasks',
        savedId: saved.id,
      ),
    );
  }
}
