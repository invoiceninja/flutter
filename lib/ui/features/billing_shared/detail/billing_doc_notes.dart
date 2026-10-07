import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/billing/billing_doc_fields.dart';
import 'package:admin/domain/date_placeholders.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/clamped_text.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/utils/notes_html.dart';

/// The note a document's owner left for themselves and their team — the one
/// text field on a billing document that never prints. In the profile, above
/// the tabs: it is written for whoever opens this screen.
///
/// Clamped, with an in-place More, so a long one does not decide where the
/// tabs start.
class BillingDocPrivateNotesCard extends StatelessWidget {
  const BillingDocPrivateNotesCard({super.key, required this.doc});

  final BillingDocFields doc;

  /// Whether this card would render anything. The field is HTML on the wire,
  /// so the question is whether it holds any *words* — markup that renders as
  /// nothing (`<p></p>`) must not open a card.
  static bool hasContent(BillingDocFields doc) =>
      plainTextFromHtml(doc.privateNotes).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final text = plainTextFromHtml(doc.privateNotes);
    if (text.isEmpty) return const SizedBox.shrink();
    return DashboardCardShell(
      title: context.tr('private_notes'),
      child: ClampedText(
        text: text,
        maxLines: 4,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.inTheme.ink),
      ),
    );
  }
}

/// The text that prints on the document — public notes, terms, footer — in
/// the order the page prints it, at the foot of the Overview tab under the
/// totals.
///
/// The footer was never shown read-only before; the screen stopped at terms.
///
/// Each is clamped: terms are routinely a page of boilerplate, and the same
/// page on every invoice.
class BillingDocPrintedNotesCard extends StatelessWidget {
  const BillingDocPrintedNotesCard({
    super.key,
    required this.doc,
    this.formatter,
  });

  final BillingDocFields doc;
  final Formatter? formatter;

  static List<(String, String)> _fields(BillingDocFields doc) => [
    ('public_notes', doc.publicNotes),
    ('terms', doc.terms),
    ('footer', doc.footer),
  ];

  /// Whether this card would render anything — see
  /// [BillingDocPrivateNotesCard.hasContent].
  static bool hasContent(BillingDocFields doc) =>
      _fields(doc).any((f) => plainTextFromHtml(f.$2).isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final blocks = <Widget>[
      for (final (labelKey, stored) in _fields(doc))
        if (plainTextFromHtml(stored) case final text when text.isNotEmpty)
          _NotesBlock(
            label: context.tr(labelKey),
            // These keep their raw date keywords until the PDF renders
            // (`:MONTH`, `[MONTH+1]`…) — the server never persists the
            // expansion — so show what they will say
            // (invoiceninja/flutter#93). On a recurring invoice that previews
            // the next run.
            body: expandDatePlaceholders(text, formatter: formatter),
          ),
    ];
    if (blocks.isEmpty) return const SizedBox.shrink();
    return DashboardCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < blocks.length; i++) ...[
            if (i > 0) ...[
              SizedBox(height: InSpacing.md(context)),
              Divider(height: 1, thickness: 1, color: tokens.border),
              SizedBox(height: InSpacing.md(context)),
            ],
            blocks[i],
          ],
        ],
      ),
    );
  }
}

class _NotesBlock extends StatelessWidget {
  const _NotesBlock({required this.label, required this.body});

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: tokens.ink2,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: InSpacing.xs),
        ClampedText(
          text: body,
          maxLines: 6,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: tokens.ink),
        ),
      ],
    );
  }
}
