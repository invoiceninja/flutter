import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_header_host.dart';
import 'package:admin/ui/core/widgets/entity_tags_view.dart';
import 'package:admin/ui/features/expenses/widgets/detail/expense_header_segments.dart';
import 'package:admin/ui/features/expenses/widgets/detail/expense_linked_names.dart';
import 'package:admin/utils/formatting.dart';

/// Per-entity wrapper over [EntityDetailHeaderHost].
///
/// **The name is the number**, as it is in the list this record was opened
/// from, in the confirmation prompts and in a logged call's subject. An
/// expense that has not been numbered yet (one created offline) is "Expense"
/// rather than "(no name)" — it has no name to be missing.
///
/// **The line under it says who, for whom, what kind and when**: vendor,
/// client, category, date — each name a link to its record. This used to
/// print the vendor's *id* after a `#`, and the rest sat in six single-row
/// cards under a tab. An expense with none of the four has no line at all,
/// rather than the created / updated dates other headers fall back to: those
/// are the last two rows of the Details card a few lines down, and the same
/// two dates twice on one screen is noise.
///
/// **Tags sit under that.** They are the user's own classification of the
/// expense, and a label worth applying is worth seeing without opening
/// anything.
class ExpenseDetailHeader extends StatelessWidget {
  const ExpenseDetailHeader({
    super.key,
    required this.expense,
    this.names = ExpenseLinkedNames.none,
    this.formatter,
    this.showStatePills = true,
  });

  final Expense expense;

  /// Resolved above the header — see `ExpenseLinkedNamesBuilder`.
  final ExpenseLinkedNames names;
  final Formatter? formatter;

  /// False when the screen is already saying Deleted / Archived in a banner.
  final bool showStatePills;

  @override
  Widget build(BuildContext context) {
    return EntityDetailHeaderHost<Expense>(
      entity: expense,
      entityType: EntityType.expense,
      recordId: expense.id,
      formatter: formatter,
      project: (context, e) {
        final date = e.date;
        final f = formatter;
        final segments = <Widget>[
          ...expensePartySegments(
            context,
            names: names,
            vendorId: e.vendorId,
            clientId: e.clientId,
            categoryId: e.categoryId,
          ),
          // Never the raw ISO date: it waits for the company's format.
          if (date != null && f != null)
            ExpenseHeaderSegment(
              icon: Icons.event_outlined,
              label: f.date(date.toIso()),
              tooltip: context.tr('date'),
            ),
        ];
        return EntityHeaderFields(
          seedForAvatar: e.id,
          displayName: e.number.isEmpty
              ? context.tr('expense')
              : '#${e.number}',
          createdAt: e.createdAt,
          updatedAt: e.updatedAt,
          isDeleted: e.isDeleted,
          isArchived: e.archivedAt != null,
          isDirty: e.isDirty,
          showStatePills: showStatePills,
          // Builds nothing when there are no entries — see the class doc.
          subtitle: ExpenseHeaderSubtitle(segments: segments),
          tags: e.tagIds.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: EntityTagsView(
                    entityType: 'expense',
                    tagIds: e.tagIds,
                  ),
                ),
        );
      },
    );
  }
}
