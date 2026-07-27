import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
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
class BillingDocOverview extends StatefulWidget {
  const BillingDocOverview({
    super.key,
    required this.totalsInput,
    required this.precision,
    required this.publicNotes,
    required this.terms,
    this.paidToDate,
    this.balance,
    this.surchargeAmounts = const <Decimal>[],
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

  /// The four invoice-level custom surcharge amounts, in slot order. Labels
  /// are resolved here from `company.customFields['surcharge1'..'4']`. The
  /// computed total already includes these amounts; the rows are what make the
  /// breakdown add up (previously a doc with a surcharge showed Subtotal and
  /// Total with nothing explaining the difference).
  final List<Decimal> surchargeAmounts;

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
  State<BillingDocOverview> createState() => _BillingDocOverviewState();
}

class _BillingDocOverviewState extends State<BillingDocOverview> {
  /// Hoisted (not built in `build`) so the read-only tab doesn't resubscribe
  /// on every parent rebuild — the stable-stream rule. Only feeds the
  /// surcharge labels.
  Stream<Company?>? _company;

  /// Only docs that actually carry a surcharge need the company (for its
  /// labels). Keeping the lookup lazy avoids a pointless watch on the common
  /// no-surcharge doc, and keeps this widget usable without a `Services`
  /// provider above it.
  bool get _needsCompany =>
      widget.surchargeAmounts.any((a) => a != Decimal.zero);

  void _ensureCompanyStream() {
    if (_company != null || !_needsCompany) return;
    final services = context.read<Services>();
    _company = services.company.watchCompany(
      services.auth.currentCompanyId ?? '',
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureCompanyStream();
  }

  @override
  void didUpdateWidget(covariant BillingDocOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureCompanyStream();
  }

  @override
  Widget build(BuildContext context) {
    final stream = _company;
    if (stream == null) return _body(context, const <TotalsSurcharge>[]);
    return StreamBuilder<Company?>(
      stream: stream,
      builder: (context, snap) => _body(
        context,
        buildSurchargeRows(
          customFields: snap.data?.customFields,
          amounts: widget.surchargeAmounts,
        ),
      ),
    );
  }

  Widget _body(BuildContext context, List<TotalsSurcharge> surchargeRows) {
    final totalsInput = widget.totalsInput;
    final precision = widget.precision;
    final formatter = widget.formatter;
    final currencyId = widget.currencyId;
    final paidToDate = widget.paidToDate;
    final balance = widget.balance;
    final trailing = widget.trailing;
    final entityType = widget.entityType;
    final tagIds = widget.tagIds;
    final publicNotes = widget.publicNotes;
    final terms = widget.terms;
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
              surcharges: surchargeRows,
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
        EntityTagsView(entityType: widget.entityType!, tagIds: widget.tagIds),
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
