import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/utils/notes_html.dart';

/// Private + public notes card. Renders either or both fields depending on
/// which are populated; hides entirely when both are empty.
class ClientDetailNotesCard extends StatelessWidget {
  const ClientDetailNotesCard({super.key, required this.client});

  final Client client;

  /// Whether this card would render anything.
  ///
  /// Both fields are HTML on the wire, so the question is whether they hold
  /// any *words* — markup that renders as nothing (`<p></p>`) must not reserve
  /// a card, and a card that hides itself still costs the caller a gap.
  static bool hasContent(Client client) =>
      plainTextFromHtml(client.privateNotes).isNotEmpty ||
      plainTextFromHtml(client.publicNotes).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    // Both fields are HTML on the wire — written here, by the React client, or
    // by the pre-v5 apps — so what a reader wants is the words. Gate on the
    // flattened text too: markup that renders as nothing (`<p></p>`) must not
    // open a card with nothing in it.
    final privateNotes = plainTextFromHtml(client.privateNotes);
    final publicNotes = plainTextFromHtml(client.publicNotes);
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
              labelColor: tokens.ink3,
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
              labelColor: tokens.ink3,
              bodyStyle: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.ink,
              ),
            ),
        ],
      ),
    );
  }
}

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
        Text(body, style: bodyStyle),
      ],
    );
  }
}
