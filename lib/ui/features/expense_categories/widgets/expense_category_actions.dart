import 'package:flutter/material.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/expense_category.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/detail/copy_entity_link.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/standard_entity_action_items.dart';
import 'package:admin/ui/core/detail/standard_entity_actions.dart';
import 'package:admin/ui/core/sync/require_synced.dart';

/// Action set surfaced for an expense category. Mirrors the standard
/// minimum surface — edit / archive / restore / delete — since
/// categories are too small to support clone or cross-entity navigation.
enum ExpenseCategoryAction { edit, copyLink, archive, restore, delete }

/// Single source of truth for what ExpenseCategory actions exist and what
/// they do. The list-row popup, detail header, and edit screen overflow
/// menu all consume this — mirrors `ProductActions` / `CompanyGatewayActions`.
class ExpenseCategoryActions {
  ExpenseCategoryActions._();

  /// Actions the old admin-portal hid on a brand-new (unsaved) record.
  /// Fed to `filterForEditScreen` so the create screen drops archive /
  /// restore / delete. (No clone for this entity.)
  static bool isLifecycle(ExpenseCategoryAction action) {
    switch (action) {
      case ExpenseCategoryAction.archive:
      case ExpenseCategoryAction.restore:
      case ExpenseCategoryAction.delete:
        return true;
      default:
        return false;
    }
  }

  /// Display label for the "Are you sure?" prompt, so a confirm fired
  /// from a long list says which record it's about. Blank is fine — the
  /// dialog just omits the line.
  static String _confirmSubject(ExpenseCategory category) => category.name;

  static List<EntityActionItem<ExpenseCategoryAction>> itemsFor(
    BuildContext context,
    ExpenseCategory category,
    void Function(ExpenseCategoryAction) onTap,
  ) {
    final canArchive = category.archivedAt == null && !category.isDeleted;
    final canRestore = category.archivedAt != null || category.isDeleted;
    // Purge is admin/owner-only — mirrors the Product/Gateway gate so the
    // action only renders when the user could plausibly run it.

    return [
      editActionItem(
        context: context,
        kind: ExpenseCategoryAction.edit,
        onTap: () => onTap(ExpenseCategoryAction.edit),
      ),
      ?copyLinkActionItem(
        context: context,
        kind: ExpenseCategoryAction.copyLink,
        entityId: category.id,
        onTap: () => onTap(ExpenseCategoryAction.copyLink),
      ),
      ?archiveActionItem(
        context: context,
        subject: _confirmSubject(category),
        kind: ExpenseCategoryAction.archive,
        canArchive: canArchive,
        onTap: () => onTap(ExpenseCategoryAction.archive),
      ),
      ?restoreActionItem(
        context: context,
        kind: ExpenseCategoryAction.restore,
        canRestore: canRestore,
        onTap: () => onTap(ExpenseCategoryAction.restore),
      ),
      ?deleteActionItem(
        context: context,
        subject: _confirmSubject(category),
        kind: ExpenseCategoryAction.delete,
        canDelete: !category.isDeleted,
        onTap: () => onTap(ExpenseCategoryAction.delete),
      ),
    ];
  }

  static Future<void> dispatch(
    BuildContext context,
    Services services,
    String companyId,
    ExpenseCategory category,
    ExpenseCategoryAction action,
  ) async {
    switch (action) {
      case ExpenseCategoryAction.edit:
        goEntityEdit(context, '/settings/expense_categories', category.id);
      case ExpenseCategoryAction.copyLink:
        await copyEntityLink(context, EntityType.expenseCategory, category.id);
      case ExpenseCategoryAction.archive:
        await StandardEntityActions.archive(
          context: context,
          wireName: 'expense_category',
          op: () => services.expenseCategories.archive(
            companyId: companyId,
            id: category.id,
          ),
          undoOp: () => services.expenseCategories.restore(
            companyId: companyId,
            id: category.id,
          ),
        );
      case ExpenseCategoryAction.restore:
        await StandardEntityActions.restore(
          context: context,
          wireName: 'expense_category',
          op: () => services.expenseCategories.restore(
            companyId: companyId,
            id: category.id,
          ),
        );
      case ExpenseCategoryAction.delete:
        if (!requireSynced(context, category.id)) return;
        await StandardEntityActions.delete(
          context: context,
          wireName: 'expense_category',
          op: () => services.expenseCategories.delete(
            companyId: companyId,
            id: category.id,
          ),
          undoOp: () => services.expenseCategories.restore(
            companyId: companyId,
            id: category.id,
          ),
        );
    }
  }
}
