import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/standard_entity_action_items.dart';
import 'package:admin/ui/core/detail/standard_entity_actions.dart';
import 'package:admin/ui/core/sync/require_synced.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/billing_shared/add_unbilled/unbilled_line_items.dart';
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
  runTemplate,
  clone,
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

  static List<EntityActionItem<ProjectAction>> itemsFor(
    BuildContext context,
    Project project,
    void Function(ProjectAction) onTap,
  ) {
    final canArchive = project.archivedAt == null && !project.isDeleted;
    final canRestore = project.archivedAt != null || project.isDeleted;
    final me = context.read<Services>().auth.session.value?.currentCompany;

    return [
      editActionItem(
        context: context,
        kind: ProjectAction.edit,
        onTap: () => onTap(ProjectAction.edit),
      ),
      // Wired in Phase 3.5 via the Tasks card "Add task" affordance, but
      // also surfaced here so the action menu mirrors React/admin-portal.
      // The four "New X" items collapse into one fly-out submenu (like
      // Client) so they stop burying the rest of the actions menu.
      if ((me?.moduleEnabled(EntityType.task) ?? false) ||
          (me?.moduleEnabled(EntityType.invoice) ?? false) ||
          (me?.moduleEnabled(EntityType.quote) ?? false) ||
          (me?.moduleEnabled(EntityType.expense) ?? false))
        newGroupActionItem(
          context: context,
          kind: ProjectAction.newGroup,
          children: [
            if (me?.moduleEnabled(EntityType.task) ?? false)
              EntityActionItem(
                kind: ProjectAction.newTask,
                icon: Icons.task_outlined,
                label: context.tr('new_task'),
                enabled: true,
                onTap: () => onTap(ProjectAction.newTask),
              ),
            if (me?.moduleEnabled(EntityType.invoice) ?? false)
              EntityActionItem(
                kind: ProjectAction.newInvoice,
                icon: Icons.receipt_long_outlined,
                label: context.tr('new_invoice'),
                enabled: !project.id.startsWith('tmp_'),
                onTap: () => onTap(ProjectAction.newInvoice),
              ),
            if (me?.moduleEnabled(EntityType.quote) ?? false)
              EntityActionItem(
                kind: ProjectAction.newQuote,
                icon: Icons.request_quote_outlined,
                label: context.tr('new_quote'),
                enabled: !project.id.startsWith('tmp_'),
                onTap: () => onTap(ProjectAction.newQuote),
              ),
            if (me?.moduleEnabled(EntityType.expense) ?? false)
              EntityActionItem(
                kind: ProjectAction.newExpense,
                icon: Icons.account_balance_wallet_outlined,
                label: context.tr('new_expense'),
                enabled: !project.id.startsWith('tmp_'),
                onTap: () => onTap(ProjectAction.newExpense),
              ),
          ],
        ),
      if (me?.moduleEnabled(EntityType.invoice) ?? false)
        EntityActionItem(
          kind: ProjectAction.invoiceProject,
          icon: Icons.outbox_outlined,
          label: context.tr('invoice_project'),
          enabled: !project.id.startsWith('tmp_'),
          onTap: () => onTap(ProjectAction.invoiceProject),
        ),
      EntityActionItem(
        kind: ProjectAction.runTemplate,
        icon: Icons.auto_awesome_outlined,
        label: context.tr('run_template'),
        enabled: !project.id.startsWith('tmp_'),
        onTap: () => onTap(ProjectAction.runTemplate),
      ),
      EntityActionItem(
        kind: ProjectAction.clone,
        icon: Icons.copy_outlined,
        label: context.tr('clone_project'),
        enabled: true,
        onTap: () => onTap(ProjectAction.clone),
      ),
      ?archiveActionItem(
        context: context,
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
        kind: ProjectAction.delete,
        canDelete: !project.isDeleted,
        onTap: () => onTap(ProjectAction.delete),
      ),
    ];
  }

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
        // first, then stopped + uninvoiced tasks with logged time. The pure
        // builder reuses the shared "Invoice Expense" / "Add unbilled"
        // converters; `watchForProject` already excludes archived/deleted rows.
        final tasks = await services.tasks
            .watchForProject(companyId: companyId, projectId: project.id)
            .first;
        final expenses = await services.expenses
            .watchForProject(companyId: companyId, projectId: project.id)
            .first;
        // Load the company and client so a task at rate 0 inherits the full
        // cascade: project.taskRate → client.settings.default_task_rate →
        // company.settings.default_task_rate instead of invoicing at $0.
        final company = await services.company.get(companyId);
        final client = project.clientId.isEmpty
            ? null
            : await services.clients
                  .watchByRealId(companyId: companyId, id: project.clientId)
                  .first;
        final group = (client == null || client.groupSettingsId.isEmpty)
            ? null
            : await services.groupSettings
                  .watchByRealId(
                    companyId: companyId,
                    id: client.groupSettingsId,
                  )
                  .first;
        final lineItems = projectInvoiceLineItems(
          tasks: tasks,
          expenses: expenses,
          // Matches the seeded draft below: `emptyInvoice()` is
          // exclusive-tax, so expense costs are billed net (tax added on
          // top by the calculator) — the line total still lands on each
          // expense's gross.
          invoiceInclusive: false,
          project: project,
          client: client,
          group: group,
          company: company,
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
            lineItems: lineItems,
          ),
        );
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

  /// Bulk "Invoice Project(s)": aggregate every selected project's billable
  /// tasks + pending expenses into ONE pre-filled invoice. Mirrors
  /// admin-portal — all selected projects must share a single client, else it
  /// errors. Reuses [projectInvoiceLineItems]; navigates to the invoice create
  /// screen with the line items seeded.
  static Future<void> invoiceProjects(
    BuildContext context,
    Services services,
    String companyId,
    List<Project> projects,
  ) async {
    final usable = projects
        .where((p) => !p.id.startsWith('tmp_') && !p.isDeleted)
        .toList();
    if (usable.isEmpty) {
      Notify.info(context, context.tr('no_billable_tasks'));
      return;
    }
    // Single-client constraint (matches admin-portal's multi-select invoice).
    final clientIds = usable
        .map((p) => p.clientId)
        .where((c) => c.isNotEmpty)
        .toSet();
    if (clientIds.length > 1) {
      Notify.error(context, context.tr('multiple_client_error'));
      return;
    }
    // Load the company and the (single) client once so a task at rate 0
    // inherits the full cascade: project.taskRate →
    // client.settings.default_task_rate → company.settings.default_task_rate
    // instead of invoicing at $0 — the same cascade the single-project
    // `invoiceProject` path applies. The single-client constraint above means
    // one client load covers every selected project.
    final company = await services.company.get(companyId);
    final clientId = clientIds.isEmpty ? '' : clientIds.first;
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
    final lineItems = [
      for (final p in usable)
        ...projectInvoiceLineItems(
          tasks: await services.tasks
              .watchForProject(companyId: companyId, projectId: p.id)
              .first,
          expenses: await services.expenses
              .watchForProject(companyId: companyId, projectId: p.id)
              .first,
          // Matches the seeded draft below (`emptyInvoice()` = exclusive).
          invoiceInclusive: false,
          project: p,
          client: client,
          group: group,
          company: company,
        ),
    ];
    if (!context.mounted) return;
    if (lineItems.isEmpty) {
      Notify.info(context, context.tr('no_billable_tasks'));
      return;
    }
    goEntityCreateFullWidth(
      context,
      '/invoices',
      extra: emptyInvoice().copyWith(
        clientId: clientIds.isEmpty ? '' : clientIds.first,
        // Carry the project link only when invoicing a single project.
        projectId: usable.length == 1 ? usable.first.id : '',
        lineItems: lineItems,
      ),
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
