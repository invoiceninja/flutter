import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/clamped_text.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/utils/notes_html.dart';

/// The project's private and public notes. Renders either or both, and
/// nothing at all when both are empty.
///
/// They used to be two rows of the Details card, each squeezed beside a 160 px
/// label — the one free-text field on the record, in the narrowest slot on the
/// screen.
class ProjectDetailNotesCard extends StatelessWidget {
  const ProjectDetailNotesCard({super.key, required this.project});

  final Project project;

  /// Whether this card would render anything.
  ///
  /// Asked of the *words*: a stored value can be markup that renders as
  /// nothing (`<p></p>`), and that must not reserve a card — a card that hides
  /// itself still costs the caller a gap.
  static bool hasContent(Project project) =>
      plainTextFromHtml(project.privateNotes).isNotEmpty ||
      plainTextFromHtml(project.publicNotes).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final privateNotes = plainTextFromHtml(project.privateNotes);
    final publicNotes = plainTextFromHtml(project.publicNotes);
    final hasPrivate = privateNotes.isNotEmpty;
    final hasPublic = publicNotes.isNotEmpty;
    if (!hasPrivate && !hasPublic) return const SizedBox.shrink();
    final tokens = context.inTheme;
    final bodyStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: tokens.ink);
    return DashboardCardShell(
      title: context.tr('notes'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasPrivate)
            _NotesBlock(
              label: context.tr('private_notes'),
              body: privateNotes,
              bodyStyle: bodyStyle,
            ),
          if (hasPrivate && hasPublic) ...[
            SizedBox(height: InSpacing.md(context)),
            Divider(height: 1, thickness: 1, color: tokens.border),
            SizedBox(height: InSpacing.md(context)),
          ],
          if (hasPublic)
            _NotesBlock(
              label: context.tr('public_notes'),
              body: publicNotes,
              bodyStyle: bodyStyle,
            ),
        ],
      ),
    );
  }
}

/// Enough to read a typical note whole, short enough that an essay does not
/// take the page.
const int _kNoteLines = 6;

class _NotesBlock extends StatelessWidget {
  const _NotesBlock({
    required this.label,
    required this.body,
    required this.bodyStyle,
  });

  final String label;
  final String body;
  final TextStyle? bodyStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.inTheme.ink2,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: InSpacing.xs),
        // A note has no length limit; unclamped, one long one decides where
        // everything below this card starts.
        ClampedText(text: body, maxLines: _kNoteLines, style: bodyStyle),
      ],
    );
  }
}
