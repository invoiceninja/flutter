import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/expense_category.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/session_permissions.dart';
import 'package:admin/ui/core/widgets/entity_picker_field.dart';
import 'package:admin/ui/features/expense_categories/widgets/expense_category_inline_create.dart';

/// The expense-category picker every form shares: active categories, resolved
/// by id, "No records found" for a company with none, and inline create —
/// gated on the server's `create_expense_categories` — through
/// [createExpenseCategoryInline].
///
/// One widget so the create wiring and its archived-name rule live in one
/// place rather than in every form that picks a category.
class ExpenseCategoryPickerField extends StatelessWidget {
  const ExpenseCategoryPickerField({
    super.key,
    required this.companyId,
    required this.selectedId,
    required this.onChanged,
    this.errorText,
    this.footerBuilder,
  });

  final String companyId;
  final String selectedId;
  final ValueChanged<ExpenseCategory?> onChanged;
  final String? errorText;

  /// Pinned under the options, below the create row — the expense form's
  /// "Manage categories" link.
  final WidgetBuilder? footerBuilder;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return EntityPickerField<ExpenseCategory>(
      label: context.tr('category'),
      cacheKey: companyId,
      selectedId: selectedId,
      itemsStream: () =>
          services.expenseCategories.watchActive(companyId: companyId),
      watchById: (id) =>
          services.expenseCategories.watch(companyId: companyId, id: id),
      displayString: (c) => c.name.isEmpty ? c.id : c.name,
      idOf: (c) => c.id,
      emptyHintKey: 'no_records_found',
      createLabelKey: 'new_expense_category',
      onCreateRequested: sessionCan(context, 'create_expense_categories')
          ? (ctx, query) => createExpenseCategoryInline(
              ctx,
              companyId: companyId,
              query: query,
            )
          : null,
      onChanged: onChanged,
      errorText: errorText,
      footerBuilder: footerBuilder,
    );
  }
}
