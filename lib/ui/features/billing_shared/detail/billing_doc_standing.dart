import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/billing/billing_doc_fields.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/recurring_frequency.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/standing_card.dart';
import 'package:admin/ui/core/widgets/party_money_cell.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_due_note.dart';
import 'package:admin/utils/formatting.dart';

/// Where a billing document stands: the one or two figures that answer the
/// question the document raises, and a line under them that says how its
/// deadline is doing.
///
/// | Document | Figures | Only when non-zero | Line |
/// |---|---|---|---|
/// | Invoice | Amount, Balance Due | Paid to Date, Partial Due | due / past due |
/// | Quote | Amount | Partial Due | expires / expired |
/// | Credit | Amount, Credit Remaining | Applied, Partial Due | — |
/// | Recurring invoice | Amount, Next Send Date | — | frequency, cycles |
/// | Purchase order | Amount | Balance, when it differs | — |
///
/// It replaces `BillingDocKpiStrip`, which dashed every zero — so a draft
/// invoice led with `AMOUNT $500 · BALANCE — · PAID —`, two thirds of the
/// header's loudest row saying nothing — and the recurring invoice's and
/// purchase order's hand-rolled label/value wraps, which printed the raw
/// `Decimal` until the formatter arrived.
///
/// **Zero rules** (`docs/row-actions-and-values.md`). A primary figure always
/// prints, zero included: `$0.00` *is* the answer to "what is still owed". A
/// secondary one is drawn only when it is not zero — `!=`, never `>`, because
/// a negative figure is the unusual one a user most needs to see. Unknown (the
/// formatter still loading) is a blank line of the right height, never a dash.
///
/// **Nothing here is red but the line.** The balance stays plain ink even on
/// an invoice a month late: the status pill above already says Past Due, and
/// the line below says by how much. One loud thing per card.
///
/// Amounts go through `PartyCurrencyBuilder` — client → group → company, or
/// the vendor's own on a purchase order — so a group-inheriting client's
/// invoice is not printed in the company's currency.
class BillingDocStanding extends StatelessWidget {
  const BillingDocStanding({
    super.key,
    required this.type,
    required this.doc,
    required this.formatter,
    this.settled,
    this.dueNote,
    this.nextSendDate,
    this.frequencyId = '',
    this.remainingCycles,
  });

  final BillingDocType type;
  final BillingDocFields doc;

  /// Null while it loads — the figures are blank until it arrives.
  final Formatter? formatter;

  /// What has already been settled against the document — paid on an invoice,
  /// applied on a credit. Not on [BillingDocFields]: only those two carry it.
  final Decimal? settled;

  /// Computed by the host, which knows what "still open" means for its
  /// document — see [billingDocDueNote]. Null draws no line.
  final BillingDocDueNote? dueNote;

  /// Recurring invoice only.
  final Date? nextSendDate;
  final String frequencyId;

  /// Negative means endless; null (every other document) draws nothing.
  final int? remainingCycles;

  @override
  Widget build(BuildContext context) {
    final vendorParty = type.party == BillingDocParty.vendor;
    return PartyCurrencyBuilder(
      clientId: vendorParty ? null : doc.clientId,
      vendorId: vendorParty ? doc.vendorId : null,
      builder: (context, currencyId) {
        String money(Decimal amount) =>
            formatter?.money(amount, clientCurrencyId: currencyId) ?? '';
        StandingFigure figure(String labelKey, Decimal amount) =>
            StandingFigure(label: context.tr(labelKey), value: money(amount));

        final balanceKey = type.balanceLabelKey;
        final settledKey = type.settledLabelKey;
        final settled = this.settled;
        final doc = this.doc;
        final partial = doc is BillingDocPartialFields
            ? doc.partial
            : Decimal.zero;
        final nextSend = nextSendDate;
        final f = formatter;
        return StandingCard(
          primary: [
            figure('amount', doc.amount),
            if (balanceKey != null) figure(balanceKey, doc.balance),
            // A date, in the figure's own typeface: on this card it is the
            // answer to "when does it next go out", and a draft or a finished
            // series simply has no second figure.
            if (nextSend != null && f != null)
              StandingFigure(
                label: context.tr('next_send_date'),
                value: f.date(nextSend.toIso()),
              ),
          ],
          secondary: [
            if (settledKey != null &&
                settled != null &&
                settled != Decimal.zero)
              figure(settledKey, settled),
            if (partial != Decimal.zero) figure('partial_due', partial),
            // A purchase order's balance is its amount until something is
            // recorded against it; printed beside it, the same number twice is
            // noise.
            if (type == BillingDocType.purchaseOrder &&
                doc.balance != Decimal.zero &&
                doc.balance != doc.amount)
              figure('balance', doc.balance),
          ],
          // Not while the formatter is loading: the figures above are blank
          // then, and a line under blank figures reads as the whole answer.
          footnote: f == null ? null : _footnote(context),
        );
      },
    );
  }

  Widget? _footnote(BuildContext context) {
    final note = dueNote;
    final keys = type.dueNoteLabelKeys;
    if (note != null && keys != null) {
      return BillingDocDueLine(note: note, labelKeys: keys);
    }
    final cycles = remainingCycles;
    final frequencyKey = kRecurringFrequencyLabelKey[frequencyId];
    final pairs = <String>[
      if (frequencyKey != null)
        '${context.tr('frequency')}: ${context.tr(frequencyKey)}',
      if (cycles != null)
        '${context.tr('remaining_cycles')}: '
            '${cycles < 0 ? context.tr('endless') : cycles}',
    ];
    if (pairs.isEmpty) return null;
    return _FootnoteText(text: pairs.join(' · '), late: false);
  }
}

/// "Due: 5 Days" · "Due: Today" · "Past Due: 12 Days" — the last in the
/// overdue ink, and nothing else on the card is.
///
/// Label–value pairs rather than a sentence, for the reason
/// [BillingDocType.dueNoteLabelKeys] gives: the bundles have no plural forms.
/// The unit is the bare `day` / `days` noun every bundle has.
class BillingDocDueLine extends StatelessWidget {
  const BillingDocDueLine({
    super.key,
    required this.note,
    required this.labelKeys,
  });

  final BillingDocDueNote note;
  final ({String upcoming, String late}) labelKeys;

  /// The line's text, for a test or a screen reader to read whole.
  static String textFor(
    BuildContext context,
    BillingDocDueNote note,
    ({String upcoming, String late}) labelKeys,
  ) {
    String days(int n) => '$n ${context.tr(n == 1 ? 'day' : 'days')}';
    return switch (note.state) {
      BillingDocDueState.late =>
        '${context.tr(labelKeys.late)}: ${days(note.days)}',
      BillingDocDueState.today =>
        '${context.tr(labelKeys.upcoming)}: ${context.tr('today')}',
      BillingDocDueState.upcoming =>
        '${context.tr(labelKeys.upcoming)}: ${days(note.days)}',
    };
  }

  @override
  Widget build(BuildContext context) =>
      _FootnoteText(text: textFor(context, note, labelKeys), late: note.isLate);
}

class _FootnoteText extends StatelessWidget {
  const _FootnoteText({required this.text, required this.late});

  final String text;
  final bool late;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final color = late ? tokens.overdue : tokens.ink2;
    // The gap above is this line's own — see `StandingCard.footnote`.
    return Padding(
      padding: const EdgeInsets.only(top: kStandingFootnoteGap),
      child: Row(
        children: [
          if (late) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: tokens.overdue,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: InSpacing.sm),
          ],
          Flexible(
            // Scales down like the figures above it rather than losing its
            // tail: a count with its unit cut off is a guess.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                text,
                maxLines: 1,
                softWrap: false,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: late ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
