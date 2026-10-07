import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/clamped_text.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';

/// The task's description in full, when the header cannot show all of it.
///
/// A task's description is its name, so the header prints it — but as a
/// heading, held to two lines. A description that is a paragraph, or a list
/// typed one item to a line, is cut off there with no way to read the rest
/// short of opening the task for editing.
class TaskDetailDescriptionCard extends StatelessWidget {
  const TaskDetailDescriptionCard({super.key, required this.task});

  final Task task;

  /// How many lines of the description the header shows
  /// (`TaskDetailHeader` → `nameMaxLines`).
  static const int headerLines = 2;

  /// Whether the card is worth drawing: only for a description the header
  /// truncates. A short description repeated under itself is the same words
  /// twice.
  ///
  /// **Measured, not guessed from a character count** — what fits two heading
  /// lines is some fifty characters on a phone and well over a hundred beside
  /// the standing card on a wide window. [nameWidth] is the width the header
  /// gives the name: its column, less the avatar and the gap beside it.
  static bool truncatedInHeader(
    BuildContext context,
    Task task, {
    required double nameWidth,
  }) {
    final description = task.description.trim();
    if (description.isEmpty) return false;
    final theme = Theme.of(context);
    final painter = TextPainter(
      text: TextSpan(
        text: description,
        // The header's own style for the name (`EntityDetailHeader`).
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      maxLines: headerLines,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: nameWidth <= 0 ? 0 : nameWidth);
    final truncated = painter.didExceedMaxLines;
    painter.dispose();
    return truncated;
  }

  @override
  Widget build(BuildContext context) {
    return DashboardCardShell(
      title: context.tr('description'),
      // A description has no length limit; unclamped, a long one decides
      // where everything below this card starts.
      child: ClampedText(
        text: task.description.trim(),
        maxLines: 8,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.inTheme.ink),
      ),
    );
  }
}
