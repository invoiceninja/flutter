import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/detail_row_columns.dart';
import 'package:admin/ui/features/tasks/widgets/detail/task_detail_description_card.dart';
import 'package:admin/ui/features/tasks/widgets/detail/task_detail_details_card.dart';
import 'package:admin/utils/formatting.dart';

/// A task's reference fields — the details, and the description when it is
/// longer than the header can show. Always shown, between the comments card
/// and the tabs.
///
/// A task has little to put here, by design: who it is for is the header's
/// subtitle, how it stands is the standing card, and what was done is the
/// Time Log tab. What is left is one card of rows.
///
/// **Every entry is gated on its card's `hasContent`**, in both layouts: the
/// gap between cards is paid per entry, so a card that returned
/// `SizedBox.shrink()` from its own `build` would leave a doubled gap.
///
/// * **≥ [Breakpoints.entityFormMultiColumn]**: Details has its row to
///   itself, so its rows run in two columns (`DetailRowColumnsScope`) rather
///   than one against a window of blank card. The description is prose, so
///   it takes the full width beneath.
/// * **below**: one stack, already capped by the record column.
class TaskDetailProfile extends StatelessWidget {
  const TaskDetailProfile({
    super.key,
    required this.task,
    required this.company,
    this.formatter,
  });

  final Task task;

  /// For the custom-field labels in Details — see `TaskDetailDetailsCard`.
  final Company? company;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final hasDetails = TaskDetailDetailsCard.hasContent(
      context,
      task,
      company,
      formatter: formatter,
    );
    final gap = SizedBox(height: InSpacing.md(context));
    final details = TaskDetailDetailsCard(
      task: task,
      company: company,
      formatter: formatter,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final wide = width >= Breakpoints.entityFormMultiColumn;
        // The header shares this column below the breakpoint, and takes the
        // lead side of the band (11 of 20, across one large gap) above it.
        final band = InSpacing.lg(context);
        final headerWidth = wide ? (width - band) * 11 / 20 : width;
        final hasDescription = TaskDetailDescriptionCard.truncatedInHeader(
          context,
          task,
          nameWidth: headerWidth - _kHeaderAvatar - band,
        );
        final rows = <Widget>[
          if (hasDetails)
            // Alone in its row on a wide window — see `DetailRowColumnsScope`.
            wide ? DetailRowColumnsScope(columns: 2, child: details) : details,
          if (hasDescription) TaskDetailDescriptionCard(task: task),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < rows.length; i++) ...[if (i > 0) gap, rows[i]],
          ],
        );
      },
    );
  }
}

/// The header's avatar (`EntityDetailHeader`), which the name sits beside.
const double _kHeaderAvatar = 56;
