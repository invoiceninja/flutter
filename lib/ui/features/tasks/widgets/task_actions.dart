import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/group_setting.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/standard_entity_action_items.dart';
import 'package:admin/ui/core/detail/standard_entity_actions.dart';
import 'package:admin/ui/core/sync/require_synced.dart';
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
  /// `viewClient` (empty-client early return) and `addToInvoice` (dismissable
  /// picker dialog) are excluded — they don't always navigate.
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
    final wasRunning = task.isRunning;
    if (wasRunning) {
      await services.tasks.stopRunningTimer(
        companyId: companyId,
        taskId: task.id,
      );
    } else {
      await services.tasks.startTimer(companyId: companyId, taskId: task.id);
    }
    if (!context.mounted) return;
    Notify.success(
      context,
      context.tr(wasRunning ? 'stopped_task' : 'started_task'),
    );
  }

  static List<EntityActionItem<TaskAction>> itemsFor(
    BuildContext context,
    Task task,
    void Function(TaskAction) onTap,
  ) {
    final canArchive = task.archivedAt == null && !task.isDeleted;
    final canRestore = task.archivedAt != null || task.isDeleted;
    final me = context.read<Services>().auth.session.value?.currentCompany;

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
      } else if (task.timeLog.isNotEmpty) {
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
          icon: Icons.play_arrow_outlined,
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
          label: addToInvoiceLabel(context),
          // Mirrors admin-portal: only an un-invoiced, non-running task
          // tied to a client can be appended to an existing invoice.
          enabled:
              !task.id.startsWith('tmp_') &&
              task.clientId.isNotEmpty &&
              !task.isInvoiced &&
              !task.isRunning,
          onTap: () => onTap(TaskAction.addToInvoice),
        ),
      if (task.clientId.isNotEmpty)
        EntityActionItem(
          kind: TaskAction.viewClient,
          icon: Icons.person_outline,
          label: context.tr('view_client'),
          enabled: true,
          onTap: () => onTap(TaskAction.viewClient),
        ),
      EntityActionItem(
        kind: TaskAction.clone,
        icon: Icons.copy_outlined,
        label: context.tr('clone_task'),
        enabled: true,
        onTap: () => onTap(TaskAction.clone),
      ),
      ?archiveActionItem(
        context: context,
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
        await _startTimer(context, services, companyId, task);
      case TaskAction.stop:
        if (!requireSynced(context, task.id)) return;
        await _stopTimer(context, services, companyId, task);
      case TaskAction.resume:
        if (!requireSynced(context, task.id)) return;
        await _resumeTimer(context, services, companyId, task);
      case TaskAction.viewClient:
        if (task.clientId.isEmpty) return;
        goEntityFullDetail(context, '/clients', task.clientId);
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

  /// Start a fresh timer on [task]. Atomically stops any currently-
  /// running entry first (the running case is reachable via Stop, not
  /// Start, but the guard is cheap and defensive).
  static Future<void> _startTimer(
    BuildContext context,
    Services services,
    String companyId,
    Task task,
  ) async {
    final now = DateTime.now();
    final entries = <TimeEntry>[...task.timeLog];
    if (entries.isNotEmpty && entries.last.isRunning) {
      entries[entries.length - 1] = entries.last.copyWith(stop: now);
    }
    entries.add(TimeEntry(start: now, stop: null));
    final next = task.copyWith(timeLog: entries);
    await services.tasks.save(companyId: companyId, task: next);
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

  /// Append a new running entry seeded from the previous entry's
  /// description + billable. Matches admin-portal's "Resume" semantics.
  static Future<void> _resumeTimer(
    BuildContext context,
    Services services,
    String companyId,
    Task task,
  ) async {
    if (task.timeLog.isEmpty) {
      await _startTimer(context, services, companyId, task);
      return;
    }
    final last = task.timeLog.last;
    final now = DateTime.now();
    final entries = <TimeEntry>[
      ...task.timeLog,
      TimeEntry(
        start: now,
        stop: null,
        description: last.description,
        billable: last.billable,
      ),
    ];
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
