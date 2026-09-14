import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/group_setting.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/task_status.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/tasks/task_day.dart';
import 'package:admin/domain/tasks/task_schedule.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/dialogs/confirm_start_scheduled_dialog.dart';
import 'package:admin/ui/core/detail/copy_entity_link.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/standard_entity_action_items.dart';
import 'package:admin/ui/core/detail/standard_entity_actions.dart';
import 'package:admin/ui/core/sync/require_synced.dart';
import 'package:admin/ui/core/utils/task_status_colors.dart';
import 'package:admin/ui/core/widgets/add_to_invoice_dialog.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/billing_shared/add_unbilled/invoice_append_context.dart';
import 'package:admin/ui/features/billing_shared/add_unbilled/unbilled_line_items.dart';
import 'package:admin/ui/features/invoices/view_models/invoice_edit_view_model.dart';
import 'package:admin/utils/formatting.dart';

/// Action set surfaced for a task. Mirrors `ProductAction` — only the
/// edit / archive / restore / delete / purge branches are wired through
/// the standard infrastructure; start/stop/resume mutate `time_log` on a
/// fresh edit-screen open, viewClient navigates, and the invoice-related
/// actions render disabled with a coming-soon tooltip (the entities
/// haven't been wired yet).
enum TaskAction {
  edit,
  start,
  stop,
  resume,
  newInvoice,
  addToInvoice,
  viewClient,
  clone,
  copyLink,
  archive,
  restore,
  delete,
}

class TaskActions {
  TaskActions._();

  /// Actions the old admin-portal hid on a brand-new (unsaved) record.
  /// Fed to `filterForEditScreen` so the create screen drops clone /
  /// archive / restore / delete.
  static bool isLifecycle(TaskAction action) {
    switch (action) {
      case TaskAction.clone:
      case TaskAction.archive:
      case TaskAction.restore:
      case TaskAction.delete:
        return true;
      default:
        return false;
    }
  }

  /// After-save actions whose [dispatch] navigates unconditionally; the
  /// create-mode edit scaffold uses this to keep that navigation instead of
  /// redirecting to the detail screen. See `InvoiceActions.navigatesOnCreate`.
  /// `addToInvoice` (dismissable picker dialog) is excluded — it doesn't
  /// always navigate. `viewClient` never reaches an edit screen at all now
  /// (`isNavigationOnly`), so it can't be an after-save action either.
  static bool navigatesOnCreate(TaskAction action) {
    switch (action) {
      case TaskAction.newInvoice:
        return true;
      default:
        return false;
    }
  }

  /// Whether an inline one-tap timer toggle should render for [task]:
  /// not invoiced (server-immutable), not soft-deleted, and already synced
  /// (a `tmp_` row has no server id the time-log PUT can target). Callers
  /// that lay out around the button read this; the shared
  /// `InlineTimerToggleButton` self-gates on it too.
  static bool canToggleTimer(Task task) =>
      !task.isInvoiced && !task.isDeleted && !task.id.startsWith('tmp_');

  /// One-tap start/stop of [task]'s timer through the outbox (repo
  /// primitives), guarded against unsynced `tmp_` rows, with a success
  /// toast. The single code path shared by every inline surface — the
  /// daily row, the list rows, the kanban card, and the detail KPI strip.
  /// "Not running" always starts (the repo seeds description/billable from
  /// the last entry); the explicit ⋮ Start/Stop/Resume menu is separate.
  static Future<void> toggleTimer(
    BuildContext context,
    Services services,
    String companyId,
    Task task,
  ) async {
    // No affordance exists for invoiced/deleted tasks (every visual button
    // self-gates via canToggleTimer). Guard here too so the keyboard path
    // can't mutate one or fire a lying toast. A `tmp_` task still falls
    // through to requireSynced below, keeping its "not synced yet" toast.
    if (task.isInvoiced || task.isDeleted) return;
    if (!requireSynced(context, task.id)) return;
    if (!task.isRunning) {
      // Starting is never a bare `save` from here: it may need to claim a
      // booking, prompt, or refuse outright. [_beginTimer] owns the toast too,
      // because three of the five outcomes write nothing.
      await _beginTimer(context, services, companyId, task);
      return;
    }
    await services.tasks.stopRunningTimer(
      companyId: companyId,
      taskId: task.id,
    );
    if (!context.mounted) return;
    Notify.success(context, context.tr('stopped_task'));
  }

  /// Display label for the "Are you sure?" prompt, so a confirm fired
  /// from a long list says which record it's about. Blank is fine — the
  /// dialog just omits the line.
  static String _confirmSubject(Task task) => task.description.trim().isNotEmpty
      ? task.description.trim()
      : (task.number.isEmpty ? '' : '#${task.number}');

  static List<EntityActionItem<TaskAction>> itemsFor(
    BuildContext context,
    Task task,
    void Function(TaskAction) onTap,
  ) {
    final canArchive = task.archivedAt == null && !task.isDeleted;
    final canRestore = task.archivedAt != null || task.isDeleted;
    final me = context.read<Services>().auth.session.value?.currentCompany;
    // Permission gate, matching `EntityLinkCard`'s `permissionKey:` on the
    // detail grids. Read lazily here (itemsFor runs per build) so it
    // re-resolves on a company switch.
    final canViewClient = me?.can('view_client') ?? false;

    // Start/Stop/Resume — only one renders at a time, gated by task state.
    EntityActionItem<TaskAction>? timerItem;
    if (!task.isInvoiced && !task.isDeleted) {
      if (task.isRunning) {
        timerItem = EntityActionItem(
          kind: TaskAction.stop,
          icon: Icons.stop_circle_outlined,
          label: context.tr('stop'),
          enabled: true,
          onTap: () => onTap(TaskAction.stop),
        );
      } else if (task.timeLog.isNotEmpty &&
          task.workedTime() > Duration.zero &&
          task.scheduleStateAt(DateTime.now()) != TaskScheduleState.late) {
        // "Resume" claims previously-worked time, so it may only appear when
        // there IS some. A task whose log is a booking has never been worked
        // — offering to resume it was invoiceninja/flutter#149's opening
        // complaint, and the word is the part that misleads.
        timerItem = EntityActionItem(
          kind: TaskAction.resume,
          icon: Icons.play_circle_outlined,
          label: context.tr('resume'),
          enabled: true,
          onTap: () => onTap(TaskAction.resume),
        );
      } else {
        timerItem = EntityActionItem(
          kind: TaskAction.start,
          icon: Icons.play_circle_outlined,
          label: context.tr('start'),
          enabled: true,
          onTap: () => onTap(TaskAction.start),
        );
      }
    }

    return [
      editActionItem(
        context: context,
        kind: TaskAction.edit,
        onTap: () => onTap(TaskAction.edit),
      ),
      ?timerItem,
      if (me?.moduleEnabled(EntityType.invoice) ?? false)
        EntityActionItem(
          kind: TaskAction.newInvoice,
          icon: Icons.receipt_long_outlined,
          label: context.tr('new_invoice'),
          // Mirrors admin-portal/React: a running task would bill a live-timer
          // snapshot, and an invoiced task would double-bill + lock; gate both.
          // (No clientId requirement — the client is chosen on the new invoice.)
          enabled:
              !task.id.startsWith('tmp_') &&
              !task.isInvoiced &&
              !task.isRunning,
          onTap: () => onTap(TaskAction.newInvoice),
        ),
      if (me?.moduleEnabled(EntityType.invoice) ?? false)
        EntityActionItem(
          kind: TaskAction.addToInvoice,
          icon: Icons.playlist_add,
          // `action_add_to_invoice`, not `add_to_invoice` — the latter is
          // "Add to invoice :invoice" (invoiceninja/flutter#35).
          label: context.tr('action_add_to_invoice'),
          // Mirrors admin-portal: only an un-invoiced, non-running task
          // tied to a client can be appended to an existing invoice.
          enabled:
              !task.id.startsWith('tmp_') &&
              task.clientId.isNotEmpty &&
              !task.isInvoiced &&
              !task.isRunning,
          onTap: () => onTap(TaskAction.addToInvoice),
        ),
      if (task.clientId.isNotEmpty && canViewClient)
        EntityActionItem(
          kind: TaskAction.viewClient,
          icon: Icons.person_outline,
          label: context.tr('view_client'),
          enabled: true,
          // Navigation only — must not reach the edit screen, where
          // `EntityEditScaffold._onAction` would save the dirty form (or
          // create the record) before dispatching it.
          isNavigationOnly: true,
          onTap: () => onTap(TaskAction.viewClient),
        ),
      EntityActionItem(
        kind: TaskAction.clone,
        icon: Icons.copy_outlined,
        label: context.tr('clone_task'),
        enabled: true,
        onTap: () => onTap(TaskAction.clone),
      ),
      ?copyLinkActionItem(
        context: context,
        kind: TaskAction.copyLink,
        entityId: task.id,
        onTap: () => onTap(TaskAction.copyLink),
      ),
      ?archiveActionItem(
        context: context,
        subject: _confirmSubject(task),
        kind: TaskAction.archive,
        canArchive: canArchive,
        onTap: () => onTap(TaskAction.archive),
      ),
      ?restoreActionItem(
        context: context,
        kind: TaskAction.restore,
        canRestore: canRestore,
        onTap: () => onTap(TaskAction.restore),
      ),
      ?deleteActionItem(
        context: context,
        subject: _confirmSubject(task),
        kind: TaskAction.delete,
        canDelete: !task.isDeleted,
        onTap: () => onTap(TaskAction.delete),
      ),
    ];
  }

  static Future<void> dispatch(
    BuildContext context,
    Services services,
    String companyId,
    Task task,
    TaskAction action,
  ) async {
    switch (action) {
      case TaskAction.edit:
        goEntityEdit(context, '/tasks', task.id);
      case TaskAction.start:
        // tmp ids haven't synced yet — server can't accept a time-log
        // change for an entity it doesn't know exists.
        if (!requireSynced(context, task.id)) return;
        await _beginTimer(context, services, companyId, task);
      case TaskAction.stop:
        if (!requireSynced(context, task.id)) return;
        await _stopTimer(context, services, companyId, task);
      case TaskAction.resume:
        if (!requireSynced(context, task.id)) return;
        await _beginTimer(context, services, companyId, task);
      case TaskAction.viewClient:
        if (task.clientId.isEmpty) return;
        goEntityFullDetail(context, '/clients', task.clientId);
      case TaskAction.copyLink:
        await copyEntityLink(context, EntityType.task, task.id);
      case TaskAction.archive:
        await StandardEntityActions.archive(
          context: context,
          wireName: 'task',
          op: () => services.tasks.archive(companyId: companyId, id: task.id),
          undoOp: () =>
              services.tasks.restore(companyId: companyId, id: task.id),
        );
      case TaskAction.restore:
        await StandardEntityActions.restore(
          context: context,
          wireName: 'task',
          op: () => services.tasks.restore(companyId: companyId, id: task.id),
        );
      case TaskAction.clone:
        final draft = task.copyWith(
          id: '',
          archivedAt: null,
          isDeleted: false,
          isDirty: false,
          invoiceId: '',
          // A clone is a new task, not the same calendar event — drop the
          // calendar link so the server's dedupe guard doesn't 422 a save the
          // edit form has no field to fix.
          meta: null,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        );
        goEntityCreateFullWidth(context, '/tasks', extra: draft);
      case TaskAction.delete:
        if (!requireSynced(context, task.id)) return;
        await StandardEntityActions.delete(
          context: context,
          wireName: 'task',
          op: () => services.tasks.delete(companyId: companyId, id: task.id),
          undoOp: () =>
              services.tasks.restore(companyId: companyId, id: task.id),
        );
      case TaskAction.newInvoice:
        if (!requireSynced(context, task.id)) return;
        await invoiceTasks(context, services, companyId, [task]);
      case TaskAction.addToInvoice:
        if (!requireSynced(context, task.id)) return;
        await addTasksToInvoice(context, services, companyId, [task]);
    }
  }

  /// "Invoice Task": one pre-filled invoice from [tasks], which may span
  /// several projects — the tasks are clustered by project and the first line
  /// of each run carries a project header, since an invoice has one
  /// `project_id` and a line item has none.
  static Future<void> invoiceTasks(
    BuildContext context,
    Services services,
    String companyId,
    List<Task> tasks,
  ) async {
    final billable = _billableSelection(context, tasks);
    if (billable == null) return;
    final labels = TaskNoteLabels.of(context);
    // `emptyInvoice()` is exclusive-tax; nothing here depends on that yet
    // (tasks carry no tax of their own) but the context load is shared.
    final ctx = await _TaskInvoiceContext.load(services, companyId, billable);
    if (!context.mounted) return;
    final lineItems = tasksToLineItems(
      billable,
      projectsById: ctx.projectsById,
      company: ctx.company,
      formatter: ctx.formatter,
      client: ctx.client,
      group: ctx.group,
      hourLabel: labels.hour,
      hoursLabel: labels.hours,
      projectFieldLabel: labels.project,
    );
    if (lineItems.isEmpty) {
      Notify.info(context, context.tr('no_billable_tasks'));
      return;
    }
    final projectIds = billable.map((t) => t.projectId).toSet();
    // Before the navigation — see the note in [addTasksToInvoice].
    _reportSkipped(context, billable.length, tasks.length);
    goEntityCreateFullWidth(
      context,
      '/invoices',
      extra: emptyInvoice().copyWith(
        clientId: ctx.clientId,
        // One `project_id` per invoice: link it only when every task agrees,
        // else the document would be labelled with one project while carrying
        // another's lines. Matches the server, which leaves it null for a
        // multi-project bulk invoice (`ProjectRepository::invoice`).
        projectId: projectIds.length == 1 ? projectIds.first : '',
        lineItems: lineItems,
      ),
    );
  }

  /// "Add to invoice": append [tasks] to one of the client's existing
  /// invoices, so a period's work across several projects lands on a single
  /// document (forum #23511).
  static Future<void> addTasksToInvoice(
    BuildContext context,
    Services services,
    String companyId,
    List<Task> tasks,
  ) async {
    final billable = _billableSelection(context, tasks);
    if (billable == null) return;
    final clientId = billable
        .map((t) => t.clientId)
        .firstWhere((c) => c.isNotEmpty, orElse: () => '');
    if (clientId.isEmpty) {
      Notify.error(context, context.tr('please_select_a_client'));
      return;
    }
    final labels = TaskNoteLabels.of(context);
    final formatter = await services.formatterFor(companyId);
    if (!context.mounted) return;
    final target = await showAddToInvoiceDialog(
      context,
      services: services,
      companyId: companyId,
      clientId: clientId,
      formatter: formatter,
    );
    if (target == null || !context.mounted) return;
    final existing = await InvoiceAppendContext.of(services, companyId, target);
    final ctx = await _TaskInvoiceContext.load(services, companyId, billable);
    if (!context.mounted) return;
    final fresh = billable
        .where((t) => !existing.taskIds.contains(t.id))
        .toList();
    final lineItems = tasksToLineItems(
      fresh,
      projectsById: ctx.projectsById,
      company: ctx.company,
      formatter: ctx.formatter,
      client: ctx.client,
      group: ctx.group,
      alreadyHeadedProjectIds: existing.projectIds,
      hourLabel: labels.hour,
      hoursLabel: labels.hours,
      projectFieldLabel: labels.project,
    );
    if (lineItems.isEmpty) {
      Notify.info(context, context.tr('no_billable_tasks'));
      return;
    }
    // Toast BEFORE navigating: `Notify` resolves the toast host through this
    // context, and `go` deactivates the element it belongs to — the lookup
    // then fails and is swallowed, so a toast queued afterwards silently never
    // appears. The host itself is global and outlives the route, so queueing
    // first is both safe and visible on the destination screen.
    //
    // Worth saying at all because the lines land on a *draft*: without it the
    // user arrives at an edit screen with no sign anything happened and no
    // hint that a Save is still required.
    Notify.success(
      context,
      fresh.length == tasks.length
          ? context.tr('added_invoice_items', {'count': '${lineItems.length}'})
          : context.tr('added_invoice_items_partial', {
              'count': '${lineItems.length}',
              'total': '${tasks.length}',
            }),
    );
    goEntityEditWithDraft(
      context,
      '/invoices',
      target.id,
      target.copyWith(lineItems: [...target.lineItems, ...lineItems]),
    );
  }

  /// Tasks that can actually be billed, or null when the selection is
  /// unusable (the caller has already been toasted). Mirrors admin-portal:
  /// multiple clients abort, multiple *projects* are fine — that's the whole
  /// point of the project headers.
  static List<Task>? _billableSelection(
    BuildContext context,
    List<Task> tasks,
  ) {
    final clientIds = tasks
        .map((t) => t.clientId)
        .where((c) => c.isNotEmpty)
        .toSet();
    if (clientIds.length > 1) {
      Notify.error(context, context.tr('multiple_client_error'));
      return null;
    }
    // A running task would bill a live-timer snapshot; an invoiced one would
    // double-bill and is server-immutable; a `tmp_` row has no server id for
    // the line to reference.
    final billable = tasks
        .where(
          (t) =>
              !t.id.startsWith('tmp_') &&
              !t.isDeleted &&
              !t.isRunning &&
              !t.isInvoiced,
        )
        .toList();
    if (billable.isEmpty) {
      Notify.info(context, context.tr('no_billable_tasks'));
      return null;
    }
    return billable;
  }

  /// Silently dropping rows from a bulk selection reads as a bug — say how
  /// many made it when the counts differ.
  static void _reportSkipped(BuildContext context, int used, int selected) {
    if (used >= selected) return;
    Notify.info(
      context,
      context.tr('added_invoice_items_partial', {
        'count': '$used',
        'total': '$selected',
      }),
    );
  }

  /// Begin work on [task] — the single write shared by the ⋮ menu's Start and
  /// Resume items and by every inline one-tap toggle.
  ///
  /// The decision belongs to `planTaskStart`, which the repository applies;
  /// this owns the three things only a widget can do: ask before overwriting a
  /// booking the user isn't looking at, resolve the In-progress status (the
  /// repository can't — `builtInTaskStatusKey` is a `lib/ui` symbol and
  /// `layering_test` forbids reaching it from `lib/data`), and offer Undo.
  static Future<void> _beginTimer(
    BuildContext context,
    Services services,
    String companyId,
    Task task,
  ) async {
    // Everything the feedback needs is resolved BEFORE the first await.
    //
    // Claiming makes the task running, which removes its row from the Upcoming
    // tab's own query and swaps the shell pill's "Due now" body out — so on
    // both of this feature's surfaces the widget that started the timer is
    // unmounted *by its own write*. Reading `context` afterwards would drop
    // the toast and, with it, the only Undo. `Notify.capture` exists for
    // exactly this: the toast host is global and outlives any context.
    final toasts = Notify.capture(context);
    final startedMsg = context.tr('started_task');
    final claimedDetail = context.tr('booking_moved_to_now');
    final blockedMsg = context.tr('task_time_log_blocks_start');
    final undoLabel = context.tr('undo');
    final formatter = services.formatterIfReady(companyId);

    // Captured before the write so Undo can put the log — and the status —
    // back. Restored through a targeted primitive, not a whole-record save:
    // re-saving this snapshot would also revert any field a sync landed in the
    // meantime.
    final beforeLog = task.timeLog;
    final beforeStatusId = task.statusId;

    // Resolved only when a claim is on the table. The status move is the app's
    // own plan→actual transition, never something a plain Start does, and
    // skipping it keeps the common path free of a Drift query.
    final couldClaim =
        task.scheduleStateAt(DateTime.now()) != TaskScheduleState.none;
    final claimStatusId = couldClaim
        ? await _inProgressStatusId(context, services, companyId, task)
        : null;

    Future<TaskStartResult> start({bool confirmed = false}) =>
        services.tasks.startTimer(
          companyId: companyId,
          taskId: task.id,
          confirmClaim: confirmed,
          claimStatusId: claimStatusId,
        );

    var result = await start();

    if (result == TaskStartResult.needsConfirmation) {
      // The only branch that genuinely needs a live context — a dialog has to
      // be pushed on a navigator. Nothing has been written yet, so bailing
      // here loses nothing.
      if (!context.mounted) return;
      final confirmed = await showConfirmStartScheduledDialog(
        context,
        message: _claimPrompt(context, task, formatter),
        subject: _confirmSubject(task),
      );
      if (!confirmed) return;
      result = await start(confirmed: true);
    }

    switch (result) {
      case TaskStartResult.blocked:
        toasts?.warning(blockedMsg);
      case TaskStartResult.noop:
      case TaskStartResult.needsConfirmation:
        // Nothing was written and nothing changed. `noop` is reachable when
        // this widget's copy is a beat stale (the task is already running, or
        // has just been invoiced), and silence there is the honest answer —
        // the surface it came from is about to rebuild with the truth.
        break;
      case TaskStartResult.started:
        toasts?.success(startedMsg);
      case TaskStartResult.claimed:
        toasts?.success(
          startedMsg,
          detail: claimedDetail,
          action: NotifyAction(
            undoLabel,
            () => unawaited(
              services.tasks.restoreTimeLog(
                companyId: companyId,
                taskId: task.id,
                timeLog: beforeLog,
                statusId: beforeStatusId,
              ),
            ),
          ),
        );
    }
  }

  /// The body of the claim prompt, phrased for whichever case triggered it.
  static String _claimPrompt(
    BuildContext context,
    Task task,
    Formatter? formatter,
  ) {
    final now = DateTime.now();
    final state = task.scheduleStateAt(now);
    final sorted = sortTimeLog(task.timeLog);
    if (state == TaskScheduleState.late && sorted.isNotEmpty) {
      final entry = sorted.first;
      final start = entry.start!.toLocal();
      // Name the duration, not just the time. `late` is *inferred* — one entry,
      // on the task's due date, matching its estimate — and confirming replaces
      // that entry outright. If the inference is wrong the user is about to
      // discard real logged work, so the prompt has to say how much.
      return context.tr('start_booked_late', {
        'time': formatTimeOfDay(
          start.hour,
          start.minute,
          military: formatter?.settings.enableMilitaryTime ?? false,
        ),
        'duration': formatDuration(
          entry.durationUpTo(now),
          compactDays: true,
          showSeconds: false,
        ),
      });
    }
    // `firstWhere`-with-fallback, not `.first`: the repository re-reads the
    // row before deciding, so this widget's copy can be a beat stale — and a
    // throw out of an `onPressed` is the worst possible way to learn that.
    // The generic prompt is honest in that case; only the date is lost.
    Date? day;
    for (final e in sortTimeLog(task.timeLog)) {
      if (!e.isRunning && e.stop!.isAfter(now)) {
        day = timeEntryLocalDate(e);
        break;
      }
    }
    if (day == null) return context.tr('start_booked_time');
    return context.tr('start_booked_other_day', {
      'date': formatter?.date(day.toIso()) ?? day.toIso(),
    });
  }

  /// The company's "In progress" status, when moving [task] onto it is the
  /// app's call to make rather than the user's — i.e. the task is still
  /// sitting in a status that means "not started".
  ///
  /// Null (leave the status alone) whenever the current status is anything
  /// else, including any status this app can't recognise: `builtInTaskStatusKey`
  /// matches the server's seeded names against English and the active locale
  /// only, so a company created in a third language falls through here by
  /// design. Null also for the bulk toolbar, which passes no context at all.
  static Future<String?> _inProgressStatusId(
    BuildContext context,
    Services services,
    String companyId,
    Task task,
  ) async {
    final statuses = await services.taskStatuses
        .watchAll(companyId: companyId)
        .first;
    if (!context.mounted) return null;
    String? keyOf(String name) => builtInTaskStatusKey(name, tr: context.tr);

    if (task.statusId.isNotEmpty) {
      TaskStatus? current;
      for (final s in statuses) {
        if (s.id == task.statusId) current = s;
      }
      if (current == null) return null;
      final key = keyOf(current.name);
      if (key != 'backlog' && key != 'ready_to_do') return null;
    }
    for (final s in statuses) {
      if (keyOf(s.name) == 'in_progress') return s.id;
    }
    return null;
  }

  /// Stop the running entry, leaving everything else untouched.
  static Future<void> _stopTimer(
    BuildContext context,
    Services services,
    String companyId,
    Task task,
  ) async {
    if (task.timeLog.isEmpty || !task.timeLog.last.isRunning) return;
    final now = DateTime.now();
    final entries = <TimeEntry>[...task.timeLog];
    entries[entries.length - 1] = entries.last.copyWith(stop: now);
    final next = task.copyWith(timeLog: entries);
    await services.tasks.save(companyId: companyId, task: next);
  }
}

/// The related entities a batch of tasks needs to become invoice lines: the
/// company (Task Settings + the tail of the rate cascade), a [Formatter] for
/// the time-detail block, the single client + its group tier, and the projects
/// the tasks belong to (for the headers and `project.taskRate`).
///
/// Loaded once per action rather than per task — the old per-task
/// `_resolveRate` re-read the company, client and group for every row.
class _TaskInvoiceContext {
  const _TaskInvoiceContext({
    required this.company,
    required this.formatter,
    required this.clientId,
    required this.client,
    required this.group,
    required this.projectsById,
  });

  final Company? company;
  final Formatter formatter;
  final String clientId;
  final Client? client;
  final GroupSetting? group;
  final Map<String, Project> projectsById;

  static Future<_TaskInvoiceContext> load(
    Services services,
    String companyId,
    List<Task> tasks,
  ) async {
    final company = await services.company.get(companyId);
    final formatter = await services.formatterFor(companyId);
    // Callers enforce the single-client rule, so one load covers the batch.
    final clientId = tasks
        .map((t) => t.clientId)
        .firstWhere((c) => c.isNotEmpty, orElse: () => '');
    final client = clientId.isEmpty
        ? null
        : await services.clients
              .watchByRealId(companyId: companyId, id: clientId)
              .first;
    // The rate cascade is task → project → client → GROUP → company.
    final group = (client == null || client.groupSettingsId.isEmpty)
        ? null
        : await services.groupSettings
              .watchByRealId(companyId: companyId, id: client.groupSettingsId)
              .first;
    final projectIds = tasks
        .map((t) => t.projectId)
        .where((id) => id.isNotEmpty)
        .toSet();
    final projectsById = <String, Project>{};
    for (final id in projectIds) {
      final project = await services.projects
          .watchByRealId(companyId: companyId, id: id)
          .first;
      if (project != null) projectsById[id] = project;
    }
    return _TaskInvoiceContext(
      company: company,
      formatter: formatter,
      clientId: clientId,
      client: client,
      group: group,
      projectsById: projectsById,
    );
  }
}
