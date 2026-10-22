import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/expense_category.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/dialogs/entity_name_dialog.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/utils/search_fold.dart';

/// A picker's inline "New Expense Category" / `Create "«query»"`, created from
/// its name alone (old app parity).
///
/// The name is checked against **every** category, archived and deleted
/// included, before creating: the server's `unique:expense_categories,name`
/// rule ignores soft-deletes, so a clash 422s the create — and an expense saved
/// against its `tmp_` id dies in the outbox behind it, offline, where nobody
/// sees it until much later (`TagPickerField` learned this as M1). An active
/// match is selected instead; an archived or deleted one is refused with a
/// toast naming it.
///
/// Categories arrive bundled and complete, so the local table is the whole
/// catalogue and no server search is needed.
///
/// Resolves to the category to select, or null when cancelled or refused.
Future<ExpenseCategory?> createExpenseCategoryInline(
  BuildContext context, {
  required String companyId,
  required String query,
}) async {
  final services = context.read<Services>();
  final name = query.trim().isNotEmpty
      ? query.trim()
      : await showEntityNameDialog(context, titleKey: 'new_expense_category');
  if (name == null || !context.mounted) return null;

  try {
    final rows = await services.expenseCategories
        .watchPage(
          companyId: companyId,
          search: name,
          states: EntityState.values.toSet(),
          // Past the default 50 rows: a common word can match many categories
          // that sort before the exact one.
          loadedPages: 20,
        )
        .first;
    if (!context.mounted) return null;
    final want = foldSearchText(name);
    for (final c in rows) {
      if (foldSearchText(c.name.trim()) != want) continue;
      if (c.archivedAt == null && !c.isDeleted) {
        Notify.info(
          context,
          context.tr('inline_create_used_existing', {'name': c.name}),
        );
        return c;
      }
      Notify.warning(
        context,
        context.tr('inline_create_name_taken', {'name': c.name}),
      );
      return null;
    }
    final created = (await services.expenseCategories.create(
      companyId: companyId,
      draft: emptyExpenseCategory().copyWith(name: name),
    )).entity;
    if (!context.mounted) return created;
    Notify.success(context, context.tr('created_expense_category'));
    return created;
  } catch (e) {
    if (context.mounted) {
      Notify.error(context, context.tr('could_not_save'), error: e);
    }
    return null;
  }
}
