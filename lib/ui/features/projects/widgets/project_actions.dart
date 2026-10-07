import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/quick_create.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/copy_entity_link.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/standard_entity_action_items.dart';
import 'package:admin/ui/core/detail/standard_entity_actions.dart';
import 'package:admin/ui/core/sync/require_synced.dart';
import 'package:admin/ui/core/widgets/add_to_invoice_dialog.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/billing_shared/add_unbilled/invoice_append_context.dart';
import 'package:admin/ui/features/billing_shared/add_unbilled/unbilled_line_items.dart';
import 'package:admin/ui/features/billing_shared/seed_billing_create_defaults.dart';
import 'package:admin/ui/features/expenses/view_models/expense_edit_view_model.dart';
import 'package:admin/ui/features/invoices/view_models/invoice_edit_view_model.dart';
import 'package:admin/ui/features/invoices/widgets/detail/run_template_dialog.dart';
import 'package:admin/ui/features/quotes/view_models/quote_edit_view_model.dart';
import 'package:admin/ui/features/tasks/view_models/task_edit_view_model.dart';

/// Action set surfaced for a project. Mirrors `ProductAction` — all
/// branches are wired.
enum ProjectAction {
  edit,
  newGroup,
  newTask,
  newInvoice,
  newQuote,
  newExpense,
  invoiceProject,
  addToInvoice,
  runTemplate,
  clone,
  copyLink,
  archive,
  restore,
  delete,
}

class ProjectActions {
  ProjectActions._();

  /// Actions the old admin-portal hid on a brand-new (unsaved) record.
  /// Fed to `filterForEditScreen` so the create screen drops clone /
  /// archive / restore / delete.
  static bool isLifecycle(ProjectAction action) {
    switch (action) {
      case ProjectAction.clone:
      case ProjectAction.archive:
      case ProjectAction.restore:
      case ProjectAction.delete:
        return true;
      default:
        return false;
    }
  }

  /// After-save actions whose [dispatch] navigates unconditionally; the
  /// create-mode edit scaffold uses this to keep that navigation instead of
  /// redirecting to the detail screen. See `InvoiceActions.navigatesOnCreate`.
  /// `invoiceProject` is excluded — it no-ops when there are no billable tasks.
  static bool navigatesOnCreate(ProjectAction action) {
    switch (action) {
      case ProjectAction.newTask:
      case ProjectAction.newInvoice:
      case ProjectAction.newQuote:
      case ProjectAction.newExpense:
        return true;
      default:
        return false;
    }
  }

  /// Display label for the "Are you sure?" prompt, so a confirm fired
  /// from a long list says which record it's about. Blank is fine — the
  /// dialog just omits the line.
  static String _confirmSubject(Project project) => project.name;

  static List<EntityActionItem<ProjectAction>> itemsFor(
    BuildContext context,
    Project project,
    void Function(ProjectAction) onTap,
  ) {
    final me = context.read<Services>().auth.session.value?.currentCompany;
    // Archive, restore and delete all need `edit_project`: the server
    // authorizes each through `EntityPolicy::edit` (there is no `delete_*`
    // permission). Ungated, a view-only user was offered Restore — one tap
    // from the record's state banner — for a mutation the server refuses.
    // The server's rule, not just the permission: the record's creator or
    // assignee may change it too (`AuthSession.canEditRecord`).
    final canEditProject =
        context.read<Services>().auth.session.value?.canEditRecord(
          'project',
          createdBy: project.userId,
          assignedTo: project.assignedUserId,
          recordId: project.id,
        ) ??
        false;
    final canArchive =
        canEditProject && project.archivedAt == null && !project.isDeleted;
    final canRestore =
        canEditProject && (project.archivedAt != null || project.isDeleted);
    // A create action needs its module AND the `create_<entity>` permission.
    // The module alone used to decide, which offered New Invoice to a user the
    // server would then refuse — and edit rights never imply create.
    bool canCreate(EntityType type) =>
        (me?.moduleEnabled(type) ?? false) &&
        (me?.can(createPermissionFor(type)) ?? false);
    final createChildren = <EntityActionItem<ProjectAction>>[
      if (canCreate(EntityType.task))
        EntityActionItem(
          kind: ProjectAction.newTask,
          icon: Icons.task_outlined,
          label: context.tr('new_task'),
          enabled: true,
          onTap: () => onTap(ProjectAction.newTask),
        ),
      if (canCreate(EntityType.invoice))
        EntityActionItem(
          kind: ProjectAction.newInvoice,
          icon: Icons.receipt_long_outlined,
          label: context.tr('new_invoice'),
          enabled: !project.id.startsWith('tmp_'),
          onTap: () => onTap(ProjectAction.newInvoice),
        ),
      if (canCreate(EntityType.quote))
        EntityActionItem(
          kind: ProjectAction.newQuote,
          icon: Icons.request_quote_outlined,
          label: context.tr('new_quote'),
          enabled: !project.id.startsWith('tmp_'),
          onTap: () => onTap(ProjectAction.newQuote),
        ),
      if (canCreate(EntityType.expense))
        EntityActionItem(
          kind: ProjectAction.newExpense,
          icon: Icons.account_balance_wallet_outlined,
          label: context.tr('new_expense'),
          enabled: !project.id.startsWith('tmp_'),
          onTap: () => onTap(ProjectAction.newExpense),
        ),
    ];

    final edit = editActionItem<ProjectAction>(
      context: context,
      kind: ProjectAction.edit,
      onTap: () => onTap(ProjectAction.edit),
    );
    return [
      // Everything that edits the project, builds on it or bills it is
      // withdrawn on a soft-deleted project, which the server will not edit
      // or attach anything to — only Copy Link and Restore remain, as on a
      // deleted client. The record screen says why in its banner.
      //
      // Edit alone stays in the list, disabled: a disabled item is hidden
      // from every menu and bar, but the wide list row still finds it as its
      // primary and draws the greyed pencil — without it the row's `⋮` would
      // slide into the pencil's place, out of line with the rows around it.
      if (project.isDeleted)
        EntityActionItem(
          kind: edit.kind,
          icon: edit.icon,
          label: edit.label,
          // No handler: a disabled item is never tapped.
          enabled: false,
          isPrimary: true,
        ),
      if (!project.isDeleted) ...[
        edit,
        // The four "New X" items collapse into one fly-out submenu (like
        // Client) so they stop burying the rest of the actions menu.
        if (createChildren.isNotEmpty)
          newGroupActionItem(
            context: context,
            kind: ProjectAction.newGroup,
            children: createChildren,
          ),
        // Builds a new invoice out of the project's unbilled work, so it is a
        // create like the ones above and gated like them.
        if (canCreate(EntityType.invoice))
          EntityActionItem(
            kind: ProjectAction.invoiceProject,
            icon: Icons.outbox_outlined,
            label: context.tr('invoice_project'),
            enabled: !project.id.startsWith('tmp_'),
            onTap: () => onTap(ProjectAction.invoiceProject),
          ),
        // Appends to an invoice that already exists — an edit of that
        // invoice, which the server allows its creator too. Which invoice is
        // not known until it is picked, so anyone who could own one is asked.
        if ((me?.moduleEnabled(EntityType.invoice) ?? false) &&
            ((me?.can('edit_invoice') ?? false) ||
                (me?.can(createPermissionFor(EntityType.invoice)) ?? false)))
          EntityActionItem(
            kind: ProjectAction.addToInvoice,
            icon: Icons.playlist_add,
            // `action_add_to_invoice`, not `add_to_invoice` — the latter is
            // "Add to invoice :invoice" (invoiceninja/flutter#35).
            label: context.tr('action_add_to_invoice'),
            // Same billable set as "Invoice Project", appended to one of the
            // client's existing invoices instead of a new one — so a period's
            // work across several projects can land on a single document.
            // Needs a client to scope the invoice picker.
            enabled:
                !project.id.startsWith('tmp_') && project.clientId.isNotEmpty,
            onTap: () => onTap(ProjectAction.addToInvoice),
          ),
        EntityActionItem(
          kind: ProjectAction.runTemplate,
          icon: Icons.auto_awesome_outlined,
          label: context.tr('run_template'),
          enabled: !project.id.startsWith('tmp_'),
          onTap: () => onTap(ProjectAction.runTemplate),
        ),
        // Cloning opens a new project: a create.
        if (me?.can(createPermissionFor(EntityType.project)) ?? false)
          EntityActionItem(
            kind: ProjectAction.clone,
            icon: Icons.copy_outlined,
            label: context.tr('clone_project'),
            enabled: true,
            onTap: () => onTap(ProjectAction.clone),
          ),
      ],
      ?copyLinkActionItem(
        context: context,
        kind: ProjectAction.copyLink,
        entityId: project.id,
        onTap: () => onTap(ProjectAction.copyLink),
      ),
      ?archiveActionItem(
        context: context,
        subject: _confirmSubject(project),
        kind: ProjectAction.archive,
        canArchive: canArchive,
        onTap: () => onTap(ProjectAction.archive),
      ),
      ?restoreActionItem(
        context: context,
        kind: ProjectAction.restore,
        canRestore: canRestore,
        onTap: () => onTap(ProjectAction.restore),
      ),
      ?deleteActionItem(
        context: context,
        subject: _confirmSubject(project),
        kind: ProjectAction.delete,
        canDelete: canEditProject && !project.isDeleted,
        onTap: () => onTap(ProjectAction.delete),
      ),
    ];
  }

  /// The project screen's quick-action strip, most-used first. The strip
  /// shows the first few that apply (`pickQuickActions`); the rest stay one
  /// tap further away in the `⋮` menu, which still lists everything.
  ///
  /// Every tile is the *same item* [itemsFor] builds, looked up by kind, so
  /// its module and permission gates and its unsynced guard cannot drift from
  /// the menu's.
  ///
  /// `applies` is about relevance, not ability: the two invoicing tiles are
  /// worth a slot only while the project has work to put on an invoice.
  /// [hasBillableWork] is the screen's answer to that, from the tasks it
  /// already holds — see [hasBillableTasks]. Both actions stay in the menu
  /// either way, where a project whose only unbilled work is an expense can
  /// still reach them.
  ///
  /// New Invoice is deliberately not a tile: beside "Invoice" it would be a
  /// second tile with the same word on it, for the rarer of the two.
  static List<EntityQuickAction<ProjectAction>> quickItemsFor(
    BuildContext context,
    Project project,
    void Function(ProjectAction) onTap, {
    required bool hasBillableWork,
  }) {
    // A deleted project is read-only, and an unsynced one would answer most
    // tiles with "sync first" — the banner says that once instead.
    if (project.isDeleted || project.id.startsWith('tmp_')) return const [];
    final items = itemsFor(context, project, onTap);
    EntityQuickAction<ProjectAction>? pick(
      ProjectAction kind,
      String shortLabel, {
      bool applies = true,
    }) {
      final item = findActionItem<ProjectAction>(items, kind);
      if (item == null) return null;
      return EntityQuickAction(
        item: item,
        shortLabel: shortLabel,
        applies: applies,
      );
    }

    // "+ Task", not "New Task": the entity noun is one word in every bundled
    // locale, where the verb phrase is two and will not fit a tile.
    String create(String nounKey) => '+ ${context.tr(nounKey)}';

    return [
      ?pick(ProjectAction.newTask, create('task')),
      ?pick(
        ProjectAction.invoiceProject,
        context.tr('invoice'),
        applies: hasBillableWork,
      ),
      ?pick(ProjectAction.newExpense, create('expense')),
      ?pick(ProjectAction.newQuote, create('quote')),
      ?pick(
        ProjectAction.addToInvoice,
        context.tr('action_add_to_invoice'),
        applies: hasBillableWork,
      ),
      ?pick(ProjectAction.clone, context.tr('clone')),
    ];
  }

  /// Whether any of [tasks] could go on an invoice right now: synced, not
  /// running, not yet invoiced, with billable time actually worked. The same
  /// test `projectInvoiceLineItems` applies, so a tile offered on this answer
  /// is one whose action will find something to bill.
  static bool hasBillableTasks(Iterable<Task> tasks, {DateTime? now}) =>
      tasks.any(
        (t) =>
            !t.id.startsWith('tmp_') &&
            !t.isDeleted &&
            !t.isRunning &&
            !t.isInvoiced &&
            t.billableDuration(now).inSeconds > 0,
      );

  static Future<void> dispatch(
    BuildContext context,
    Services services,
    String companyId,
    Project project,
    ProjectAction action,
  ) async {
    switch (action) {
      case ProjectAction.newGroup:
        break; // Submenu parent — never dispatched; children carry the action.
      case ProjectAction.edit:
        goEntityEdit(context, '/projects', project.id);
      case ProjectAction.newTask:
        goEntityCreateFullWidth(
          context,
          '/tasks',
          extra: emptyTask().copyWith(projectId: project.id),
        );
      case ProjectAction.copyLink:
        await copyEntityLink(context, EntityType.project, project.id);
      case ProjectAction.archive:
        await StandardEntityActions.archive(
          context: context,
          wireName: 'project',
          op: () =>
              services.projects.archive(companyId: companyId, id: project.id),
          undoOp: () =>
              services.projects.restore(companyId: companyId, id: project.id),
        );
      case ProjectAction.restore:
        await StandardEntityActions.restore(
          context: context,
          wireName: 'project',
          op: () =>
              services.projects.restore(companyId: companyId, id: project.id),
        );
      case ProjectAction.clone:
        // Strip identity-bearing fields so the create form opens with a
        // truly new draft seeded from the source project.
        final draft = project.copyWith(
          id: '',
          number: '',
          archivedAt: null,
          isDeleted: false,
          isDirty: false,
          currentHours: 0,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        );
        goEntityCreateFullWidth(context, '/projects', extra: draft);
      case ProjectAction.delete:
        if (!requireSynced(context, project.id)) return;
        await StandardEntityActions.delete(
          context: context,
          wireName: 'project',
          op: () =>
              services.projects.delete(companyId: companyId, id: project.id),
          undoOp: () =>
              services.projects.restore(companyId: companyId, id: project.id),
        );
      case ProjectAction.newInvoice:
        if (!requireSynced(context, project.id)) return;
        goEntityCreateFullWidth(
          context,
          '/invoices',
          extra: emptyInvoice().copyWith(
            clientId: project.clientId,
            projectId: project.id,
          ),
        );
      case ProjectAction.newQuote:
        if (!requireSynced(context, project.id)) return;
        goEntityCreateFullWidth(
          context,
          '/quotes',
          extra: emptyQuote().copyWith(
            clientId: project.clientId,
            projectId: project.id,
          ),
        );
      case ProjectAction.newExpense:
        if (!requireSynced(context, project.id)) return;
        goEntityCreateFullWidth(
          context,
          '/expenses',
          extra: emptyExpense().copyWith(
            clientId: project.clientId,
            projectId: project.id,
          ),
        );
      case ProjectAction.invoiceProject:
        if (!requireSynced(context, project.id)) return;
        // Mirrors admin-portal's "Invoice Project": pending project expenses
        // first, then stopped + uninvoiced tasks with logged time.
        final labels = TaskNoteLabels.of(context);
        // The client's inclusive-tax mode, resolved before the lines: an
        // expense line is billed net on an exclusive invoice (tax added on top
        // by the calculator) and gross on an inclusive one — either way the
        // line total lands on the expense's gross. Staged on the draft, since
        // the edit screen never re-seeds a document that arrives with lines.
        final inclusive = await resolveCreateInclusiveTaxes(
          services.settings,
          companyId: companyId,
          clientId: project.clientId,
        );
        final lineItems = await _projectLineItems(
          services,
          companyId,
          [project],
          invoiceInclusive: inclusive,
          labels: labels,
        );
        if (!context.mounted) return;
        if (lineItems.isEmpty) {
          Notify.info(context, context.tr('no_billable_tasks'));
          return;
        }
        goEntityCreateFullWidth(
          context,
          '/invoices',
          extra: emptyInvoice().copyWith(
            clientId: project.clientId,
            projectId: project.id,
            usesInclusiveTaxes: inclusive,
            lineItems: lineItems,
          ),
        );
      case ProjectAction.addToInvoice:
        if (!requireSynced(context, project.id)) return;
        if (project.clientId.isEmpty) {
          Notify.error(context, context.tr('please_select_a_client'));
          return;
        }
        await addProjectsToInvoice(context, services, companyId, [project]);
      case ProjectAction.runTemplate:
        if (!requireSynced(context, project.id)) return;
        final templateId = await showRunTemplateDialog(context);
        if (templateId == null || !context.mounted) return;
        await services.projects.runTemplate(
          companyId: companyId,
          id: project.id,
          templateId: templateId,
        );
        if (!context.mounted) return;
        Notify.success(context, context.tr('template_queued'));
    }
  }

  /// Projects that can be billed, or null when the selection is unusable (the
  /// caller has already been toasted). Mirrors admin-portal's multi-select
  /// invoice: all selected projects must share a single client.
  static List<Project>? _billableSelection(
    BuildContext context,
    List<Project> projects,
  ) {
    final usable = projects
        .where((p) => !p.id.startsWith('tmp_') && !p.isDeleted)
        .toList();
    if (usable.isEmpty) {
      Notify.info(context, context.tr('no_billable_tasks'));
      return null;
    }
    final clientIds = usable
        .map((p) => p.clientId)
        .where((c) => c.isNotEmpty)
        .toSet();
    if (clientIds.length > 1) {
      Notify.error(context, context.tr('multiple_client_error'));
      return null;
    }
    return usable;
  }

  /// Every billable line across [projects] — pending expenses then billable
  /// tasks per project, with the rate cascade resolved and a project header on
  /// the first task of each project (so one invoice can carry several
  /// projects' work and still say whose is whose).
  ///
  /// Pass [existing] when appending to an invoice: rows already on it are
  /// skipped (re-running the action would otherwise bill the same task twice)
  /// and projects it already shows don't get a second header.
  ///
  /// The single-client constraint enforced by [_billableSelection] means one
  /// client / group / company load covers every project here.
  static Future<List<LineItem>> _projectLineItems(
    Services services,
    String companyId,
    List<Project> projects, {
    required bool invoiceInclusive,
    required TaskNoteLabels labels,
    InvoiceAppendContext existing = InvoiceAppendContext.empty,
  }) async {
    final company = await services.company.get(companyId);
    final formatter = await services.formatterFor(companyId);
    final clientId = projects
        .map((p) => p.clientId)
        .firstWhere((c) => c.isNotEmpty, orElse: () => '');
    final client = clientId.isEmpty
        ? null
        : await services.clients
              .watchByRealId(companyId: companyId, id: clientId)
              .first;
    final group = (client == null || client.groupSettingsId.isEmpty)
        ? null
        : await services.groupSettings
              .watchByRealId(companyId: companyId, id: client.groupSettingsId)
              .first;

    final out = <LineItem>[];
    for (final project in projects) {
      final tasks = await services.tasks
          .watchForProject(companyId: companyId, projectId: project.id)
          .first;
      final expenses = await services.expenses
          .watchForProject(companyId: companyId, projectId: project.id)
          .first;
      out.addAll(
        projectInvoiceLineItems(
          tasks: tasks,
          expenses: expenses,
          invoiceInclusive: invoiceInclusive,
          project: project,
          client: client,
          group: group,
          company: company,
          formatter: formatter,
          excludedTaskIds: existing.taskIds,
          excludedExpenseIds: existing.expenseIds,
          alreadyHeadedProjectIds: existing.projectIds,
          hourLabel: labels.hour,
          hoursLabel: labels.hours,
          projectFieldLabel: labels.project,
        ),
      );
    }
    return out;
  }

  /// Bulk "Invoice Project(s)": aggregate every selected project's billable
  /// tasks + pending expenses into ONE pre-filled invoice. Navigates to the
  /// invoice create screen with the line items seeded.
  static Future<void> invoiceProjects(
    BuildContext context,
    Services services,
    String companyId,
    List<Project> projects,
  ) async {
    final usable = _billableSelection(context, projects);
    if (usable == null) return;
    final clientId = usable
        .map((p) => p.clientId)
        .firstWhere((c) => c.isNotEmpty, orElse: () => '');
    final labels = TaskNoteLabels.of(context);
    // Resolved before the lines — see [ProjectAction.invoiceProject].
    final inclusive = await resolveCreateInclusiveTaxes(
      services.settings,
      companyId: companyId,
      clientId: clientId,
    );
    final lineItems = await _projectLineItems(
      services,
      companyId,
      usable,
      invoiceInclusive: inclusive,
      labels: labels,
    );
    if (!context.mounted) return;
    if (lineItems.isEmpty) {
      Notify.info(context, context.tr('no_billable_tasks'));
      return;
    }
    goEntityCreateFullWidth(
      context,
      '/invoices',
      extra: emptyInvoice().copyWith(
        clientId: clientId,
        usesInclusiveTaxes: inclusive,
        // Carry the project link only when invoicing a single project — an
        // invoice has one `project_id` and stamping it with the first of
        // several would mislabel the others' lines. Matches the server
        // (`ProjectRepository::invoice` leaves it null for multi-project).
        projectId: usable.length == 1 ? usable.first.id : '',
        lineItems: lineItems,
      ),
    );
  }

  /// Bulk "Add to invoice": append every selected project's billable tasks +
  /// pending expenses to ONE of the client's existing invoices. The forum
  /// ask (#23511) — several projects' work on a single periodic invoice —
  /// solved from the project side; the Add-items picker on the invoice solves
  /// it from the other direction.
  static Future<void> addProjectsToInvoice(
    BuildContext context,
    Services services,
    String companyId,
    List<Project> projects,
  ) async {
    final usable = _billableSelection(context, projects);
    if (usable == null) return;
    final clientId = usable
        .map((p) => p.clientId)
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
    final lineItems = await _projectLineItems(
      services,
      companyId,
      usable,
      // Bill against the TARGET's tax mode, not the default — an inclusive
      // invoice extracts tax from the line, an exclusive one adds it on top.
      invoiceInclusive: target.usesInclusiveTaxes,
      labels: labels,
      existing: existing,
    );
    if (!context.mounted) return;
    if (lineItems.isEmpty) {
      Notify.info(context, context.tr('no_billable_tasks'));
      return;
    }
    // Toast before navigating — see `TaskActions.addTasksToInvoice` for why
    // the order matters (the toast host is resolved through this context, and
    // `go` deactivates it). The lines land on a *draft*, so without this the
    // user arrives at an edit screen with no sign anything happened and no
    // hint that a Save is still required.
    Notify.success(
      context,
      context.tr('added_invoice_items', {'count': '${lineItems.length}'}),
    );
    goEntityEditWithDraft(
      context,
      '/invoices',
      target.id,
      target.copyWith(lineItems: [...target.lineItems, ...lineItems]),
    );
  }

  /// Bulk "Download Documents": collect every document id across the selected
  /// projects and fire the server-side export (`POST /documents/bulk
  /// {action:'download'}`) — the server zips and emails them, matching
  /// admin-portal + React. Works identically on web/native (one POST, no
  /// client download). Toasts when the selection has no documents.
  static Future<void> downloadDocuments(
    BuildContext context,
    Services services,
    List<Project> projects,
  ) async {
    final ids = <String>[
      for (final p in projects)
        for (final d in p.documents) d.id,
    ];
    if (ids.isEmpty) {
      Notify.info(context, context.tr('no_documents_to_download'));
      return;
    }
    try {
      await services.documents.bulkDownload(
        ids: ids,
        idempotencyKey: const Uuid().v4(),
      );
      if (!context.mounted) return;
      Notify.success(context, context.tr('exported_data'));
    } catch (e) {
      if (!context.mounted) return;
      Notify.error(context, context.tr('an_error_occurred'), error: e);
    }
  }
}
