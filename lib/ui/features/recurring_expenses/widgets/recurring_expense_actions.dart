import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/recurring_expense.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/expense_recurring_conversion.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/standard_entity_action_items.dart';
import 'package:admin/ui/core/detail/standard_entity_actions.dart';
import 'package:admin/ui/core/sync/require_synced.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

/// Action set surfaced for a recurring expense.
///
/// Differs from `ExpenseAction` in two ways:
///   * `start` / `stop` replace `invoiceExpense` / `addToInvoice` —
///     visibility is gated on `canBeStarted` / `canBeStopped`.
///   * `cloneToExpense` replaces `cloneToRecurring` — the inverse direction.
///
/// `runTemplate` is dropped — the server doesn't expose template-runner on
/// recurring rows.
enum RecurringExpenseAction {
  edit,
  start,
  stop,
  clone,
  cloneToExpense,
  addComment,
  archive,
  restore,
  delete,
}

class RecurringExpenseActions {
  RecurringExpenseActions._();

  /// Actions the old admin-portal hid on a brand-new (unsaved) record.
  /// Fed to `filterForEditScreen` so the create screen drops clone /
  /// cloneToExpense / archive / restore / delete.
  static bool isLifecycle(RecurringExpenseAction action) {
    switch (action) {
      case RecurringExpenseAction.clone:
      case RecurringExpenseAction.cloneToExpense:
      case RecurringExpenseAction.archive:
      case RecurringExpenseAction.restore:
      case RecurringExpenseAction.delete:
        return true;
      default:
        return false;
    }
  }

  static List<EntityActionItem<RecurringExpenseAction>> itemsFor(
    BuildContext context,
    RecurringExpense recurringExpense,
    void Function(RecurringExpenseAction) onTap,
  ) {
    final canArchive =
        recurringExpense.archivedAt == null && !recurringExpense.isDeleted;
    final canRestore =
        recurringExpense.archivedAt != null || recurringExpense.isDeleted;
    final me = context.read<Services>().auth.session.value?.currentCompany;

    return [
      editActionItem(
        context: context,
        kind: RecurringExpenseAction.edit,
        onTap: () => onTap(RecurringExpenseAction.edit),
      ),
      if (recurringExpense.canBeStarted)
        EntityActionItem(
          kind: RecurringExpenseAction.start,
          icon: Icons.play_arrow_outlined,
          label: context.tr('start'),
          enabled: true,
          onTap: () => onTap(RecurringExpenseAction.start),
        ),
      if (recurringExpense.canBeStopped)
        EntityActionItem(
          kind: RecurringExpenseAction.stop,
          icon: Icons.stop_outlined,
          label: context.tr('stop'),
          enabled: true,
          onTap: () => onTap(RecurringExpenseAction.stop),
        ),
      EntityActionItem(
        kind: RecurringExpenseAction.clone,
        icon: Icons.copy_outlined,
        label: context.tr('clone_recurring'),
        enabled: true,
        onTap: () => onTap(RecurringExpenseAction.clone),
      ),
      if (me?.moduleEnabled(EntityType.expense) ?? false)
        EntityActionItem(
          kind: RecurringExpenseAction.cloneToExpense,
          icon: Icons.account_balance_wallet_outlined,
          label: context.tr('clone_to_expense'),
          enabled: true,
          onTap: () => onTap(RecurringExpenseAction.cloneToExpense),
        ),
      EntityActionItem(
        kind: RecurringExpenseAction.addComment,
        icon: Icons.chat_bubble_outline,
        label: context.tr('add_comment'),
        enabled: true,
        onTap: () => onTap(RecurringExpenseAction.addComment),
      ),
      ?archiveActionItem(
        context: context,
        kind: RecurringExpenseAction.archive,
        canArchive: canArchive,
        onTap: () => onTap(RecurringExpenseAction.archive),
      ),
      ?restoreActionItem(
        context: context,
        kind: RecurringExpenseAction.restore,
        canRestore: canRestore,
        onTap: () => onTap(RecurringExpenseAction.restore),
      ),
      ?deleteActionItem(
        context: context,
        kind: RecurringExpenseAction.delete,
        canDelete: !recurringExpense.isDeleted,
        onTap: () => onTap(RecurringExpenseAction.delete),
      ),
    ];
  }

  static Future<void> dispatch(
    BuildContext context,
    Services services,
    String companyId,
    RecurringExpense recurringExpense,
    RecurringExpenseAction action,
  ) async {
    switch (action) {
      case RecurringExpenseAction.edit:
        goEntityEdit(context, '/recurring_expenses', recurringExpense.id);
      case RecurringExpenseAction.start:
        if (!requireSynced(context, recurringExpense.id)) return;
        await services.recurringExpenses.start(
          companyId: companyId,
          id: recurringExpense.id,
        );
        if (context.mounted) {
          Notify.success(context, context.tr('started_recurring_expense'));
        }
      case RecurringExpenseAction.stop:
        if (!requireSynced(context, recurringExpense.id)) return;
        await services.recurringExpenses.stop(
          companyId: companyId,
          id: recurringExpense.id,
        );
        if (context.mounted) {
          Notify.success(context, context.tr('stopped_recurring_expense'));
        }
      case RecurringExpenseAction.clone:
        final draft = recurringExpense.copyWith(
          id: '',
          number: '',
          archivedAt: null,
          isDeleted: false,
          isDirty: false,
          invoiceId: '',
          paymentDate: null,
          paymentTypeId: '',
          transactionReference: '',
          transactionId: '',
          statusId: null,
          lastSentDate: null,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        );
        goEntityCreateFullWidth(context, '/recurring_expenses', extra: draft);
      case RecurringExpenseAction.cloneToExpense:
        // Convert to a real [Expense] clone seed before navigating. Expense and
        // RecurringExpense are distinct Freezed types, so the Expense create
        // form's `state.extra is Expense` guard silently drops a
        // RecurringExpense — handing it the converted object preserves the data.
        goEntityCreateFullWidth(
          context,
          '/expenses',
          extra: recurringExpense.toExpenseClone(),
        );
      case RecurringExpenseAction.addComment:
        await _promptAddComment(context, services, companyId, recurringExpense);
      case RecurringExpenseAction.archive:
        await StandardEntityActions.archive(
          context: context,
          wireName: 'recurring_expense',
          op: () => services.recurringExpenses.archive(
            companyId: companyId,
            id: recurringExpense.id,
          ),
          undoOp: () => services.recurringExpenses.restore(
            companyId: companyId,
            id: recurringExpense.id,
          ),
        );
      case RecurringExpenseAction.restore:
        await StandardEntityActions.restore(
          context: context,
          wireName: 'recurring_expense',
          op: () => services.recurringExpenses.restore(
            companyId: companyId,
            id: recurringExpense.id,
          ),
        );
      case RecurringExpenseAction.delete:
        if (!requireSynced(context, recurringExpense.id)) return;
        await StandardEntityActions.delete(
          context: context,
          wireName: 'recurring_expense',
          op: () => services.recurringExpenses.delete(
            companyId: companyId,
            id: recurringExpense.id,
          ),
          undoOp: () => services.recurringExpenses.restore(
            companyId: companyId,
            id: recurringExpense.id,
          ),
        );
    }
  }
}

Future<void> _promptAddComment(
  BuildContext context,
  Services services,
  String companyId,
  RecurringExpense recurringExpense,
) async {
  final controller = TextEditingController();
  final text = await showDialog<String>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(ctx.tr('add_comment')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(hintText: ctx.tr('notes')),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 40),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(ctx.tr('cancel')),
              ),
              const SizedBox(width: 8),
              PrimaryDialogAction(
                label: ctx.tr('save'),
                onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                autofocus: false,
                showEnterHint: false,
              ),
            ],
          ),
        ],
      );
    },
  );
  if (text == null || text.isEmpty) return;
  await services.recurringExpenses.addComment(
    companyId: companyId,
    recurringExpenseId: recurringExpense.id,
    text: text,
  );
}
