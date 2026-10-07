import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/recurring_expense.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/recurring_frequency.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_header_host.dart';
import 'package:admin/ui/core/widgets/entity_tags_view.dart';
import 'package:admin/ui/features/expenses/widgets/detail/expense_header_segments.dart';
import 'package:admin/ui/features/expenses/widgets/detail/expense_linked_names.dart';
import 'package:admin/utils/formatting.dart';

/// Per-entity wrapper over [EntityDetailHeaderHost] — the recurring twin of
/// `ExpenseDetailHeader`, and built from the same pieces.
///
/// **The name is the number**; one not numbered yet is "Recurring Expense".
///
/// **The line under it says who, for whom, what kind and how often**:
/// vendor, client, category, frequency. Where an expense ends that line with
/// its date, a recurring one ends it with "Monthly" — when it next runs is a
/// figure on the card beside this, not part of what the record *is*.
class RecurringExpenseDetailHeader extends StatelessWidget {
  const RecurringExpenseDetailHeader({
    super.key,
    required this.recurringExpense,
    this.names = ExpenseLinkedNames.none,
    this.formatter,
    this.showStatePills = true,
  });

  final RecurringExpense recurringExpense;

  /// Resolved above the header — see `ExpenseLinkedNamesBuilder`.
  final ExpenseLinkedNames names;
  final Formatter? formatter;

  /// False when the screen is already saying Deleted / Archived in a banner.
  final bool showStatePills;

  @override
  Widget build(BuildContext context) {
    return EntityDetailHeaderHost<RecurringExpense>(
      entity: recurringExpense,
      entityType: EntityType.recurringExpense,
      recordId: recurringExpense.id,
      formatter: formatter,
      project: (context, e) {
        final frequencyKey = kRecurringFrequencyLabelKey[e.frequencyId];
        final segments = <Widget>[
          ...expensePartySegments(
            context,
            names: names,
            vendorId: e.vendorId,
            clientId: e.clientId,
            categoryId: e.categoryId,
          ),
          // An id the catalog does not know is left out rather than printed:
          // a bare "13" under the number says nothing.
          if (frequencyKey != null)
            ExpenseHeaderSegment(
              icon: Icons.event_repeat_outlined,
              label: context.tr(frequencyKey),
              tooltip: context.tr('frequency'),
            ),
        ];
        return EntityHeaderFields(
          seedForAvatar: e.id,
          displayName: e.number.isEmpty
              ? context.tr('recurring_expense')
              : '#${e.number}',
          createdAt: e.createdAt,
          updatedAt: e.updatedAt,
          isDeleted: e.isDeleted,
          isArchived: e.archivedAt != null,
          isDirty: e.isDirty,
          showStatePills: showStatePills,
          // Builds nothing when there are no entries.
          subtitle: ExpenseHeaderSubtitle(segments: segments),
          tags: e.tagIds.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: EntityTagsView(
                    entityType: 'recurring_expense',
                    tagIds: e.tagIds,
                  ),
                ),
        );
      },
    );
  }
}
