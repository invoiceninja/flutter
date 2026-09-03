import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/recurring_expense.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/expense_recurring_conversion.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/activity_note_actions.dart';
import 'package:admin/ui/core/detail/copy_entity_link.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/standard_entity_action_items.dart';
import 'package:admin/ui/core/detail/standard_entity_actions.dart';
import 'package:admin/ui/core/sync/require_synced.dart';
import 'package:admin/ui/core/widgets/notify.dart';

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
  logCall,
  copyLink,
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

  /// Display label for the "Are you sure?" prompt, so a confirm fired
  /// from a long list says which record it's about. Blank is fine — the
  /// dialog just omits the line.
  static String _confirmSubject(RecurringExpense recurringExpense) =>
      recurringExpense.number.isEmpty ? '' : '#${recurringExpense.number}';

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
          confirm: true,
          confirmSubject: _confirmSubject(recurringExpense),
          icon: Icons.play_arrow_outlined,
          label: context.tr('start'),
          enabled: true,
          onTap: () => onTap(RecurringExpenseAction.start),
        ),
      if (recurringExpense.canBeStopped)
        EntityActionItem(
          kind: RecurringExpenseAction.stop,
          confirm: true,
          confirmSubject: _confirmSubject(recurringExpense),
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
      EntityActionItem(
        kind: RecurringExpenseAction.logCall,
        icon: Icons.phone_in_talk_outlined,
        label: context.tr('log_call'),
        enabled: true,
        onTap: () => onTap(RecurringExpenseAction.logCall),
      ),
      ?copyLinkActionItem(
        context: context,
        kind: RecurringExpenseAction.copyLink,
        entityId: recurringExpense.id,
        onTap: () => onTap(RecurringExpenseAction.copyLink),
      ),
      ?archiveActionItem(
        context: context,
        subject: _confirmSubject(recurringExpense),
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
        subject: _confirmSubject(recurringExpense),
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
      case RecurringExpenseAction.logCall:
        await promptLogCallFor(
          context,
          companyId: companyId,
          entityId: recurringExpense.id,
          subject: _confirmSubject(recurringExpense),
          submit: (text) => services.recurringExpenses.addComment(
            companyId: companyId,
            recurringExpenseId: recurringExpense.id,
            text: text,
          ),
        );
      case RecurringExpenseAction.addComment:
        await promptAddCommentFor(
          context,
          entityId: recurringExpense.id,
          submit: (text) => services.recurringExpenses.addComment(
            companyId: companyId,
            recurringExpenseId: recurringExpense.id,
            text: text,
          ),
        );
      case RecurringExpenseAction.copyLink:
        await copyEntityLink(
          context,
          EntityType.recurringExpense,
          recurringExpense.id,
        );
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
