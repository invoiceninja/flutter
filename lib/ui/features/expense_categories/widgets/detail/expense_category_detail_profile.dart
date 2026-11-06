import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/expense_category.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/record_timestamps.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/detail_info_row.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/expense_categories/widgets/detail/expense_category_color.dart';
import 'package:admin/utils/formatting.dart';

/// "Details" on the expense-category record: its colour and when it was made
/// and last changed. The name is the screen's title and is not repeated.
///
/// A category has nothing else — no figures, no related list the server can
/// scope — so this card is the whole profile, and the screen has no standing
/// card and no quick-action tiles.
class ExpenseCategoryDetailProfile extends StatelessWidget {
  const ExpenseCategoryDetailProfile({
    super.key,
    required this.category,
    this.formatter,
  });

  final ExpenseCategory category;

  /// For the created / updated dates. Null (still loading) leaves them out.
  final Formatter? formatter;

  /// Derived from [rowsFor], the list [build] renders, so the two cannot
  /// drift.
  static bool hasContent(
    BuildContext context,
    ExpenseCategory category, {
    Formatter? formatter,
  }) => rowsFor(context, category, formatter: formatter).isNotEmpty;

  static List<Widget> rowsFor(
    BuildContext context,
    ExpenseCategory category, {
    Formatter? formatter,
  }) {
    final swatch = expenseCategoryColor(category.color);
    return [
      if (category.color.trim().isNotEmpty)
        DetailInfoRow(
          label: context.tr('color'),
          value: '',
          copyable: false,
          child: CopyableValue(
            value: category.color,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (swatch != null) ...[
                  ExpenseCategorySwatch(color: swatch),
                  const SizedBox(width: InSpacing.sm),
                ],
                Flexible(
                  child: Text(
                    category.color.toUpperCase(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.inTheme.ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ...recordTimestampRows(
        context,
        createdAt: category.createdAt,
        updatedAt: category.updatedAt,
        formatter: formatter,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final rows = rowsFor(context, category, formatter: formatter);
    if (rows.isEmpty) return const SizedBox.shrink();
    return DashboardCardShell(
      title: context.tr('details'),
      child: DetailRowStack(children: rows),
    );
  }
}
