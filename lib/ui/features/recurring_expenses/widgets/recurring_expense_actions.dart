import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/recurring_expense.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/expense_recurring_conversion.dart';
import 'package:admin/domain/quick_create.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/activity_note_actions.dart';
import 'package:admin/ui/core/detail/copy_entity_link.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
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
  viewVendor,
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
    final me = context.read<Services>().auth.session.value?.currentCompany;
    // Start, stop, archive, restore and delete all need
    // `edit_recurring_expense`: the server authorizes each through
    // `EntityPolicy::edit` (there is no `delete_*` permission). Ungated, a
    // view-only user was offered Restore — one tap from the record's state
    // banner — for a mutation the server refuses.
    // The server's rule, not just the permission: the record's creator or
    // assignee may change it too (`AuthSession.canEditRecord`).
    final canEdit =
        context.read<Services>().auth.session.value?.canEditRecord(
          'recurring_expense',
          createdBy: recurringExpense.userId,
          assignedTo: recurringExpense.assignedUserId,
          recordId: recurringExpense.id,
        ) ??
        false;
    final canArchive =
        canEdit &&
        recurringExpense.archivedAt == null &&
        !recurringExpense.isDeleted;
    final canRestore =
        canEdit &&
        (recurringExpense.archivedAt != null || recurringExpense.isDeleted);
    // Permission gate for the labelled "go to the vendor" item. Read lazily
    // here (itemsFor runs per build) so it re-resolves on a company switch.
    final canViewVendor = me?.can('view_vendor') ?? false;
    // A clone is a new record and needs `create_<entity>` — edit rights never
    // imply it. Its own module is on, or this record would not be on screen;
    // a one-off expense is another kind and needs its module as well.
    final canClone =
        me?.can(createPermissionFor(EntityType.recurringExpense)) ?? false;
    final canCloneToExpense =
        (me?.moduleEnabled(EntityType.expense) ?? false) &&
        (me?.can(createPermissionFor(EntityType.expense)) ?? false);

    return [
      // Everything that changes the record, runs it or copies it. Hidden
      // entirely on a soft-deleted one — only the link, the vendor and
      // Restore remain, as on a deleted client: the server refuses an edit of
      // a deleted record, and the screen says it is read-only.
      if (!recurringExpense.isDeleted) ...[
        editActionItem(
          context: context,
          kind: RecurringExpenseAction.edit,
          onTap: () => onTap(RecurringExpenseAction.edit),
        ),
        if (canEdit && recurringExpense.canBeStarted)
          EntityActionItem(
            kind: RecurringExpenseAction.start,
            confirm: true,
            confirmSubject: _confirmSubject(recurringExpense),
            icon: Icons.play_arrow_outlined,
            label: context.tr('start'),
            enabled: true,
            onTap: () => onTap(RecurringExpenseAction.start),
          ),
        if (canEdit && recurringExpense.canBeStopped)
          EntityActionItem(
            kind: RecurringExpenseAction.stop,
            confirm: true,
            confirmSubject: _confirmSubject(recurringExpense),
            icon: Icons.stop_outlined,
            label: context.tr('stop'),
            enabled: true,
            onTap: () => onTap(RecurringExpenseAction.stop),
          ),
        if (canClone)
          EntityActionItem(
            kind: RecurringExpenseAction.clone,
            icon: Icons.copy_outlined,
            label: context.tr('clone_recurring'),
            enabled: true,
            onTap: () => onTap(RecurringExpenseAction.clone),
          ),
        if (canCloneToExpense)
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
      ],
      if (recurringExpense.vendorId.isNotEmpty && canViewVendor)
        EntityActionItem(
          kind: RecurringExpenseAction.viewVendor,
          icon: Icons.storefront_outlined,
          label: context.tr('view_vendor'),
          enabled: true,
          // Navigation only — must not reach the edit screen, where
          // `EntityEditScaffold._onAction` would save the dirty form (or
          // create the record) before dispatching it.
          isNavigationOnly: true,
          onTap: () => onTap(RecurringExpenseAction.viewVendor),
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
        canDelete: canEdit && !recurringExpense.isDeleted,
        onTap: () => onTap(RecurringExpenseAction.delete),
      ),
    ];
  }

  /// The recurring-expense screen's quick-action strip, most-used first. The
  /// strip shows the first few that apply (`pickQuickActions`); the rest stay
  /// in the `⋮` menu, which still lists everything.
  ///
  /// Every tile is the *same item* [itemsFor] builds, looked up by kind, so
  /// its permission gates, its confirmation prompt and its unsynced guard
  /// cannot drift from the menu's. Start and Stop are never both there:
  /// [itemsFor] offers whichever one the schedule's state allows, so the
  /// first tile is always the one thing that can be done to the schedule now.
  static List<EntityQuickAction<RecurringExpenseAction>> quickItemsFor(
    BuildContext context,
    RecurringExpense recurringExpense,
    void Function(RecurringExpenseAction) onTap,
  ) {
    // A deleted record is read-only, and an unsynced one would answer Start
    // with "sync first" — the banner says that once instead.
    if (recurringExpense.isDeleted || recurringExpense.id.startsWith('tmp_')) {
      return const [];
    }
    final items = itemsFor(context, recurringExpense, onTap);
    EntityQuickAction<RecurringExpenseAction>? pick(
      RecurringExpenseAction kind,
      String shortLabel,
    ) {
      final item = findActionItem<RecurringExpenseAction>(items, kind);
      if (item == null) return null;
      return EntityQuickAction(item: item, shortLabel: shortLabel);
    }

    return [
      ?pick(RecurringExpenseAction.start, context.tr('start')),
      ?pick(RecurringExpenseAction.stop, context.tr('stop')),
      ?pick(RecurringExpenseAction.clone, context.tr('clone')),
      // "+ Expense": the one-off copy, named like every other create tile.
      ?pick(
        RecurringExpenseAction.cloneToExpense,
        '+ ${context.tr('expense')}',
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
        // A clone copies its source, so the create form skips the company's
        // new-expense defaults for it.
        goEntityCreateFullWidth(
          context,
          '/recurring_expenses',
          extra: draft,
          isClone: true,
        );
      case RecurringExpenseAction.cloneToExpense:
        // Convert to a real [Expense] clone seed before navigating. Expense and
        // RecurringExpense are distinct Freezed types, so the Expense create
        // form's typed `takeCreateSeed<Expense>` would drop a RecurringExpense —
        // handing it the converted object preserves the data.
        goEntityCreateFullWidth(
          context,
          '/expenses',
          extra: recurringExpense.toExpenseClone(),
          isClone: true,
        );
      case RecurringExpenseAction.logCall:
        await promptLogCallFor(
          context,
          companyId: companyId,
          entityId: recurringExpense.id,
          subject: _confirmSubject(recurringExpense),
          vendorId: recurringExpense.vendorId,
          clientId: recurringExpense.clientId,
          submit: (text) => services.recurringExpenses.addComment(
            companyId: companyId,
            entityId: recurringExpense.id,
            text: text,
          ),
        );
      case RecurringExpenseAction.addComment:
        await promptAddCommentFor(
          context,
          entityId: recurringExpense.id,
          submit: (text) => services.recurringExpenses.addComment(
            companyId: companyId,
            entityId: recurringExpense.id,
            text: text,
          ),
        );
      case RecurringExpenseAction.viewVendor:
        if (recurringExpense.vendorId.isEmpty) return;
        goEntityFullDetail(context, '/vendors', recurringExpense.vendorId);
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
