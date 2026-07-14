import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/billing/line_item_type.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/tasks/task_rate.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/standard_entity_action_items.dart';
import 'package:admin/ui/core/detail/standard_entity_actions.dart';
import 'package:admin/ui/core/sync/require_synced.dart';
import 'package:admin/ui/core/widgets/add_to_invoice_dialog.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/billing_shared/add_unbilled/unbilled_line_items.dart';
import 'package:admin/ui/features/invoices/view_models/invoice_edit_view_model.dart';

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
          label: context.tr('add_to_invoice'),
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
        // Same 3-dp conversion as the "Add unbilled items" / "Invoice project"
        // path (taskBillableHours) so a task invoiced via this menu and via the
        // bulk path produce identical quantities; an empty task seeds a 1-hour
        // editable default rather than a $0 ghost line, matching that path.
        final hours = taskBillableHours(task);
        // Apply the task → project → client → company rate cascade so a task
        // left at rate 0 invoices at the inherited rate, not $0.
        final rate = await _resolveRate(services, companyId, task);
        if (!context.mounted) return;
        final lineItem = emptyLineItem().copyWith(
          typeId: LineItemType.task,
          taskId: task.id,
          notes: task.description,
          quantity: hours,
          cost: rate,
        );
        final draft = emptyInvoice().copyWith(
          clientId: task.clientId,
          projectId: task.projectId,
          lineItems: [lineItem],
        );
        goEntityCreateFullWidth(context, '/invoices', extra: draft);
      case TaskAction.addToInvoice:
        if (!requireSynced(context, task.id)) return;
        if (task.clientId.isEmpty) {
          Notify.error(context, context.tr('please_select_a_client'));
          return;
        }
        final formatter = await services.formatterFor(companyId);
        if (!context.mounted) return;
        final target = await showAddToInvoiceDialog(
          context,
          services: services,
          companyId: companyId,
          clientId: task.clientId,
          formatter: formatter,
        );
        if (target == null || !context.mounted) return;
        // Same 3-dp conversion as the "Add unbilled items" / "Invoice project"
        // path (taskBillableHours) so a task invoiced via this menu and via the
        // bulk path produce identical quantities; an empty task seeds a 1-hour
        // editable default rather than a $0 ghost line, matching that path.
        final hours = taskBillableHours(task);
        final rate = await _resolveRate(services, companyId, task);
        if (!context.mounted) return;
        final lineItem = emptyLineItem().copyWith(
          typeId: LineItemType.task,
          taskId: task.id,
          notes: task.description,
          quantity: hours,
          cost: rate,
        );
        context.go(
          '/invoices/${target.id}/edit',
          extra: target.copyWith(lineItems: [...target.lineItems, lineItem]),
        );
    }
  }

  /// Effective hourly rate for a task→invoice line, applying the
  /// task → project → client → company `default_task_rate` cascade. Loads
  /// the related entities lazily — and only when the task's own rate is 0,
  /// the sole case where the fallback matters.
  static Future<Decimal> _resolveRate(
    Services services,
    String companyId,
    Task task,
  ) async {
    if (task.rate > Decimal.zero) return task.rate;
    final company = await services.company.get(companyId);
    final project = task.projectId.isEmpty
        ? null
        : await services.projects
              .watchByRealId(companyId: companyId, id: task.projectId)
              .first;
    final client = task.clientId.isEmpty
        ? null
        : await services.clients
              .watchByRealId(companyId: companyId, id: task.clientId)
              .first;
    return resolveTaskRate(
      task: task,
      project: project,
      client: client,
      company: company,
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
