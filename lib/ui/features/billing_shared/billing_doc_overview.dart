import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/domain/billing/totals_calculator.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/entity_tags_view.dart';
import 'package:admin/ui/features/billing_shared/line_items_readonly_table.dart';
import 'package:admin/ui/features/billing_shared/totals_widget.dart';
import 'package:admin/utils/formatting.dart';

/// Shared read-only Overview body for billing-doc detail screens (Invoice /
/// Quote / Credit): the line-items table, a totals breakdown card, and the
/// public-notes / terms blocks. Invoice-only extras (reminders, applied
/// payments) are appended via [trailing].
///
/// The caller passes a [BillingTotalsInput] (the same value type the edit
/// ViewModels build) — it already carries the line items, discount, and
/// surcharge amounts, so totals are computed here. Empty notes/terms blocks
/// are hidden rather than rendered as `—`.
class BillingDocOverview extends StatelessWidget {
  const BillingDocOverview({
    super.key,
    required this.totalsInput,
    required this.precision,
    required this.publicNotes,
    required this.terms,
    this.paidToDate,
    this.balance,
    this.surcharges = const <TotalsSurcharge>[],
    this.formatter,
    this.currencyId,
    this.trailing = const <Widget>[],
    this.entityType,
    this.tagIds = const <String>[],
  });

  final BillingTotalsInput totalsInput;
  final int precision;
  final String publicNotes;
  final String terms;
  final Decimal? paidToDate;
  final Decimal? balance;

  /// Itemized custom-surcharge rows (label + amount). Optional — the computed
  /// total already includes surcharge amounts; this only drives the breakdown
  /// rows.
  final List<TotalsSurcharge> surcharges;

  final Formatter? formatter;
  final String? currencyId;

  /// Entity-specific sections appended after the totals (e.g. the invoice's
  /// applied-payments list and reminders summary).
  final List<Widget> trailing;

  /// Wire key for the tag chips shown at the top of the overview (e.g.
  /// `'invoice'`). When null or [tagIds] is empty, no tags block renders.
  final String? entityType;
  final List<String> tagIds;

  @override
  Widget build(BuildContext context) {
    final totals = computeTotals(totalsInput, precision);
    final gap = InSpacing.lg(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (entityType != null && tagIds.isNotEmpty) ...[
          _tags(context),
          SizedBox(height: gap),
        ],
        LineItemsReadonlyTable(
          items: totalsInput.lineItems,
          formatter: formatter,
          currencyId: currencyId,
          discountIsAmount: totalsInput.isAmountDiscount,
        ),
        SizedBox(height: gap),
        Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: TotalsWidget(
              totals: totals,
              discount: totalsInput.discount,
              discountIsAmount: totalsInput.isAmountDiscount,
              surcharges: surcharges,
              paidToDate: paidToDate,
              balance: balance,
              formatter: formatter,
              currencyId: currencyId,
            ),
          ),
        ),
        for (final w in trailing) ...[SizedBox(height: gap), w],
        if (publicNotes.isNotEmpty) ...[
          SizedBox(height: gap),
          _notes(context, 'public_notes', publicNotes),
        ],
        if (terms.isNotEmpty) ...[
          SizedBox(height: gap),
          _notes(context, 'terms', terms),
        ],
      ],
    );
  }

  Widget _tags(BuildContext context) {
    final tokens = context.inTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('tags'),
          style: TextStyle(
            fontSize: 12,
            color: tokens.ink3,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        EntityTagsView(entityType: entityType!, tagIds: tagIds),
      ],
    );
  }

  Widget _notes(BuildContext context, String labelKey, String value) {
    final tokens = context.inTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(labelKey),
          style: TextStyle(
            fontSize: 12,
            color: tokens.ink3,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: tokens.ink)),
      ],
    );
  }
}
