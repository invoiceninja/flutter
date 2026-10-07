import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/clamped_text.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/utils/notes_html.dart';

/// Private + public notes card. Renders either or both fields depending on
/// which are populated; hides entirely when both are empty.
class VendorDetailNotesCard extends StatelessWidget {
  const VendorDetailNotesCard({super.key, required this.vendor});

  final Vendor vendor;

  /// Whether this card would render anything.
  ///
  /// Both fields are HTML on the wire, so the question is whether they hold
  /// any *words* — markup that renders as nothing (`<p></p>`) must not reserve
  /// a card, and a card that hides itself still costs the caller a gap.
  static bool hasContent(Vendor vendor) =>
      plainTextFromHtml(vendor.privateNotes).isNotEmpty ||
      plainTextFromHtml(vendor.publicNotes).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final privateNotes = plainTextFromHtml(vendor.privateNotes);
    final publicNotes = plainTextFromHtml(vendor.publicNotes);
    final hasPrivate = privateNotes.isNotEmpty;
    final hasPublic = publicNotes.isNotEmpty;
    if (!hasPrivate && !hasPublic) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final tokens = context.inTheme;
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
              labelColor: tokens.ink2,
              bodyStyle: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.ink,
              ),
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
              labelColor: tokens.ink2,
              bodyStyle: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.ink,
              ),
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
    required this.labelColor,
    required this.bodyStyle,
  });

  final String label;
  final String body;
  final Color labelColor;
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
            color: labelColor,
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
