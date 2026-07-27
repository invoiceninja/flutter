import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/expense_invoice_line_item.dart';
import 'package:admin/domain/expense_recurring_conversion.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/billing_shared/actions/add_comment_prompt.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/standard_entity_action_items.dart';
import 'package:admin/ui/core/detail/standard_entity_actions.dart';
import 'package:admin/ui/core/sync/require_synced.dart';
import 'package:admin/ui/core/widgets/add_to_invoice_dialog.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/invoices/view_models/invoice_edit_view_model.dart';
import 'package:admin/ui/features/invoices/widgets/detail/run_template_dialog.dart';

/// Action set surfaced for an expense. Mirrors `ProjectAction` — all
/// branches do work.
enum ExpenseAction {
  edit,
  clone,
  cloneToRecurring,
  invoiceExpense,
  addToInvoice,
  runTemplate,
  addComment,
  archive,
  restore,
  delete,
}

class ExpenseActions {
  ExpenseActions._();

  /// Actions the old admin-portal hid on a brand-new (unsaved) record.
  /// Fed to `filterForEditScreen` so the create screen drops clone /
  /// clone-to-recurring / archive / restore / delete.
  static bool isLifecycle(ExpenseAction action) {
    switch (action) {
      case ExpenseAction.clone:
      case ExpenseAction.cloneToRecurring:
      case ExpenseAction.archive:
      case ExpenseAction.restore:
      case ExpenseAction.delete:
        return true;
      default:
        return false;
    }
  }

  static List<EntityActionItem<ExpenseAction>> itemsFor(
    BuildContext context,
    Expense expense,
    void Function(ExpenseAction) onTap,
  ) {
    final canArchive = expense.archivedAt == null && !expense.isDeleted;
    final canRestore = expense.archivedAt != null || expense.isDeleted;
    final me = context.read<Services>().auth.session.value?.currentCompany;

    return [
      editActionItem(
        context: context,
        kind: ExpenseAction.edit,
        onTap: () => onTap(ExpenseAction.edit),
      ),
      EntityActionItem(
        kind: ExpenseAction.clone,
        icon: Icons.copy_outlined,
        label: context.tr('clone_expense'),
        enabled: true,
        onTap: () => onTap(ExpenseAction.clone),
      ),
      EntityActionItem(
        kind: ExpenseAction.cloneToRecurring,
        icon: Icons.event_repeat_outlined,
        label: context.tr('clone_to_recurring'),
        enabled: true,
        onTap: () => onTap(ExpenseAction.cloneToRecurring),
      ),
      if (me?.moduleEnabled(EntityType.invoice) ?? false)
        EntityActionItem(
          kind: ExpenseAction.invoiceExpense,
          icon: Icons.outbox_outlined,
          label: context.tr('invoice_expense'),
          enabled: !expense.id.startsWith('tmp_') && expense.invoiceId.isEmpty,
          onTap: () => onTap(ExpenseAction.invoiceExpense),
        ),
      if (me?.moduleEnabled(EntityType.invoice) ?? false)
        EntityActionItem(
          kind: ExpenseAction.addToInvoice,
          icon: Icons.playlist_add_outlined,
          label: context.tr('add_to_invoice'),
          // Mirrors admin-portal: an un-invoiced expense tied to a client
          // can be appended to one of that client's existing invoices.
          enabled:
              !expense.id.startsWith('tmp_') &&
              expense.invoiceId.isEmpty &&
              expense.clientId.isNotEmpty,
          onTap: () => onTap(ExpenseAction.addToInvoice),
        ),
      EntityActionItem(
        kind: ExpenseAction.runTemplate,
        icon: Icons.auto_awesome_outlined,
        label: context.tr('run_template'),
        enabled: !expense.id.startsWith('tmp_'),
        onTap: () => onTap(ExpenseAction.runTemplate),
      ),
      EntityActionItem(
        kind: ExpenseAction.addComment,
        icon: Icons.chat_bubble_outline,
        label: context.tr('add_comment'),
        enabled: true,
        onTap: () => onTap(ExpenseAction.addComment),
      ),
      ?archiveActionItem(
        context: context,
        kind: ExpenseAction.archive,
        canArchive: canArchive,
        onTap: () => onTap(ExpenseAction.archive),
      ),
      ?restoreActionItem(
        context: context,
        kind: ExpenseAction.restore,
        canRestore: canRestore,
        onTap: () => onTap(ExpenseAction.restore),
      ),
      ?deleteActionItem(
        context: context,
        kind: ExpenseAction.delete,
        canDelete: !expense.isDeleted,
        onTap: () => onTap(ExpenseAction.delete),
      ),
    ];
  }

  static Future<void> dispatch(
    BuildContext context,
    Services services,
    String companyId,
    Expense expense,
    ExpenseAction action,
  ) async {
    switch (action) {
      case ExpenseAction.edit:
        goEntityEdit(context, '/expenses', expense.id);
      case ExpenseAction.clone:
        final draft = expense.copyWith(
          id: '',
          number: '',
          // Mirror admin-portal's clone: drop attachments and reset the date
          // to today so the copy starts fresh.
          documents: const [],
          date: Date.today(),
          archivedAt: null,
          isDeleted: false,
          isDirty: false,
          invoiceId: '',
          paymentDate: null,
          paymentTypeId: '',
          transactionReference: '',
          transactionId: '',
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        );
        goEntityCreateFullWidth(context, '/expenses', extra: draft);
      case ExpenseAction.cloneToRecurring:
        // Convert to a real [RecurringExpense] clone seed (default monthly
        // schedule) before navigating. Expense and RecurringExpense are
        // distinct Freezed types, so the recurring create form's
        // `state.extra is RecurringExpense` guard silently drops an Expense —
        // handing it the converted object preserves the data.
        goEntityCreateFullWidth(
          context,
          '/recurring_expenses',
          extra: expense.toRecurringExpenseClone(),
        );
      case ExpenseAction.addComment:
        await _promptAddComment(context, services, companyId, expense);
      case ExpenseAction.archive:
        await StandardEntityActions.archive(
          context: context,
          wireName: 'expense',
          op: () =>
              services.expenses.archive(companyId: companyId, id: expense.id),
          undoOp: () =>
              services.expenses.restore(companyId: companyId, id: expense.id),
        );
      case ExpenseAction.restore:
        await StandardEntityActions.restore(
          context: context,
          wireName: 'expense',
          op: () =>
              services.expenses.restore(companyId: companyId, id: expense.id),
        );
      case ExpenseAction.delete:
        if (!requireSynced(context, expense.id)) return;
        await StandardEntityActions.delete(
          context: context,
          wireName: 'expense',
          op: () =>
              services.expenses.delete(companyId: companyId, id: expense.id),
          undoOp: () =>
              services.expenses.restore(companyId: companyId, id: expense.id),
        );
      case ExpenseAction.invoiceExpense:
        if (!requireSynced(context, expense.id)) return;
        if (expense.invoiceId.isNotEmpty) {
          Notify.error(context, context.tr('expense_already_invoiced'));
          return;
        }
        // A new invoice adopts the expense's inclusive-tax mode (React parity),
        // so the carried line tax is interpreted the same way it was on the
        // expense.
        final draft = emptyInvoice().copyWith(
          clientId: expense.clientId,
          projectId: expense.projectId,
          vendorId: expense.vendorId,
          usesInclusiveTaxes: expense.usesInclusiveTaxes,
          lineItems: [
            expenseInvoiceLineItem(
              expense,
              invoiceInclusive: expense.usesInclusiveTaxes,
            ),
          ],
        );
        goEntityCreateFullWidth(context, '/invoices', extra: draft);
      case ExpenseAction.runTemplate:
        if (!requireSynced(context, expense.id)) return;
        final templateId = await showRunTemplateDialog(context);
        if (templateId == null || !context.mounted) return;
        await services.expenses.runTemplate(
          companyId: companyId,
          id: expense.id,
          templateId: templateId,
        );
        if (!context.mounted) return;
        Notify.success(context, context.tr('template_queued'));
      case ExpenseAction.addToInvoice:
        if (!requireSynced(context, expense.id)) return;
        if (expense.invoiceId.isNotEmpty) {
          Notify.error(context, context.tr('expense_already_invoiced'));
          return;
        }
        if (expense.clientId.isEmpty) {
          Notify.error(context, context.tr('please_select_a_client'));
          return;
        }
        final formatter = await services.formatterFor(companyId);
        if (!context.mounted) return;
        final target = await showAddToInvoiceDialog(
          context,
          services: services,
          companyId: companyId,
          clientId: expense.clientId,
          formatter: formatter,
        );
        if (target == null || !context.mounted) return;
        // The target invoice's tax mode is fixed — seed the line cost to match
        // it so the line total lands on the expense's gross either way.
        final addItem = expenseInvoiceLineItem(
          expense,
          invoiceInclusive: target.usesInclusiveTaxes,
        );
        context.go(
          '/invoices/${target.id}/edit',
          extra: target.copyWith(lineItems: [...target.lineItems, addItem]),
        );
    }
  }
}

Future<void> _promptAddComment(
  BuildContext context,
  Services services,
  String companyId,
  Expense expense,
) async {
  // Shared dialog — it owns its controller in a State so disposal cannot
  // race the exit transition (see `showAddCommentPrompt`).
  final text = await showAddCommentPrompt(context);
  if (text == null || text.isEmpty) return;
  await services.expenses.addComment(
    companyId: companyId,
    expenseId: expense.id,
    text: text,
  );
}
