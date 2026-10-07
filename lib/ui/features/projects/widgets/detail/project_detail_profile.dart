import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/detail_row_columns.dart';
import 'package:admin/ui/features/projects/widgets/detail/project_detail_details_card.dart';
import 'package:admin/ui/features/projects/widgets/detail/project_detail_notes_card.dart';
import 'package:admin/ui/features/projects/widgets/detail/project_progress_card.dart';
import 'package:admin/utils/formatting.dart';

/// A project's reference fields — the details, the hours over time, the
/// notes. Always shown, between the comments card and the tabs.
///
/// **Every entry is gated on its card's `hasContent`**, in both layouts: the
/// gap between cards is paid per entry, so a card that returned
/// `SizedBox.shrink()` from its own `build` would leave a doubled gap — and in
/// the wide row an empty `Expanded` would hold half the width for nothing.
///
/// * **≥ [Breakpoints.entityFormMultiColumn]**: Details and the Progress
///   chart side by side as equal cards, ending on one line, with the notes
///   full width beneath. A project with nothing logged has no chart; its
///   Details card then keeps to the column the header and the quick actions
///   sit in above it, rather than running the width of the window with every
///   value a screen away from its label.
/// * **below**: one stack — Details, the chart where the column is wide enough
///   to read one ([kProjectChartMinWidth]), notes. On a pane or a phone the
///   standing card's budget bar is the chart, as it always was.
class ProjectDetailProfile extends StatelessWidget {
  const ProjectDetailProfile({
    super.key,
    required this.project,
    required this.company,
    required this.tasks,
    this.formatter,
  });

  final Project project;

  /// For the custom-field labels in Details — see `ProjectDetailDetailsCard`.
  final Company? company;

  /// The project's active tasks as held locally, or null when this user may
  /// not view tasks — in which case there is no chart to draw.
  final List<Task>? tasks;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final hasDetails = ProjectDetailDetailsCard.hasContent(
      context,
      project,
      company,
      formatter: formatter,
    );
    final hasNotes = ProjectDetailNotesCard.hasContent(project);
    final tasks = this.tasks;
    final hasChart = ProjectProgressCard.hasContent(tasks);
    final gap = SizedBox(height: InSpacing.md(context));

    Widget details() => ProjectDetailDetailsCard(
      project: project,
      company: company,
      formatter: formatter,
    );
    Widget chart(double height) => ProjectProgressCard(
      project: project,
      tasks: tasks!,
      chartHeight: height,
      formatter: formatter,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final wide = width >= Breakpoints.entityFormMultiColumn;
        final showChart = hasChart && width >= kProjectChartMinWidth;
        final rows = <Widget>[
          if (wide && hasDetails && showChart)
            // `IntrinsicHeight` so the two cards end on one line. Legal here
            // because neither holds a `LayoutBuilder` it can reach: the chart
            // is boxed at a fixed height, which answers for it.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: details()),
                  SizedBox(width: InSpacing.md(context)),
                  Expanded(child: chart(kProjectChartRowHeight)),
                ],
              ),
            )
          else if (wide && hasDetails)
            // Alone in its row — see `DetailRowColumnsScope`.
            DetailRowColumnsScope(columns: 2, child: details())
          else ...[
            if (hasDetails) details(),
            if (showChart) chart(ProjectProgressCard.heightFor(width)),
          ],
          if (hasNotes) ProjectDetailNotesCard(project: project),
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

/// The narrowest column a line chart is worth drawing in. Below it the
/// standing card's budget bar says the same thing in one line.
const double kProjectChartMinWidth = 600;

/// The chart's height beside the Details card: about what five or six detail
/// rows come to, so neither card is left with a blank half.
const double kProjectChartRowHeight = 190;
