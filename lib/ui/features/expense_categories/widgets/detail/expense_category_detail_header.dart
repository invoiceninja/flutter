import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/expense_category.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_header.dart';
import 'package:admin/ui/features/expense_categories/widgets/detail/expense_category_color.dart';
import 'package:admin/utils/formatting.dart';

/// Per-entity header for the ExpenseCategory record screen. Maps the
/// category's domain fields into the shared [EntityDetailHeader] slots.
///
/// **The subtitle is the category's own colour** — the one thing besides its
/// name that tells two categories apart, and what the user will recognise
/// from the expense list. A category with no colour falls back to the
/// created / updated dates the header shows for every other entity, so the
/// line is never blank.
class ExpenseCategoryDetailHeader extends StatelessWidget {
  const ExpenseCategoryDetailHeader({
    super.key,
    required this.category,
    this.formatter,
    this.showStatePills = true,
  });

  final ExpenseCategory category;
  final Formatter? formatter;

  /// False when the screen is already saying Deleted / Archived in a banner.
  final bool showStatePills;

  @override
  Widget build(BuildContext context) {
    final swatch = expenseCategoryColor(category.color);
    return EntityDetailHeader(
      // The id, never the name: a rename must not reshuffle the tint.
      seedForAvatar: category.id,
      displayName: category.name.isEmpty
          ? context.tr('no_name_fallback')
          : category.name,
      createdAt: category.createdAt,
      updatedAt: category.updatedAt,
      isDeleted: category.isDeleted,
      isArchived: category.archivedAt != null,
      isDirty: category.isDirty,
      formatter: formatter,
      nameMaxLines: 2,
      showStatePills: showStatePills,
      subtitle: swatch == null
          ? DetailHeaderTimestamps(
              createdAt: category.createdAt,
              updatedAt: category.updatedAt,
              formatter: formatter,
            )
          : DetailSubtitle(
              segments: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExpenseCategorySwatch(color: swatch, size: 10),
                    const SizedBox(width: InSpacing.xs),
                    Text(category.color.toUpperCase()),
                  ],
                ),
              ],
            ),
    );
  }
}
