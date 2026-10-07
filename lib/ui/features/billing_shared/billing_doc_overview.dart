import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/billing/billing_doc_fields.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/domain/billing/billing_doc_totals.dart';
import 'package:admin/domain/billing/totals_calculator.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/utils/company_labels.dart';
import 'package:admin/ui/core/widgets/centered_form_column.dart';
import 'package:admin/ui/core/widgets/party_money_cell.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_notes.dart';
import 'package:admin/ui/features/billing_shared/line_items_readonly_table.dart';
import 'package:admin/ui/features/billing_shared/totals_widget.dart';
import 'package:admin/utils/formatting.dart';

/// Shared read-only Overview body for all five billing-doc detail screens:
/// the line-items table and a totals breakdown card — the document's content.
/// Invoice-only extras (reminders, applied payments) are appended via
/// [trailing].
///
/// The caller passes a [BillingTotalsInput] (the same value type the edit
/// ViewModels build) — it already carries the line items, discount, and
/// surcharge amounts, so totals are computed here.
///
/// Tags used to be drawn here too; they are under the document's number now.
/// The printed text — public notes, terms, footer — is appended by
/// [BillingDocOverviewOf] as a card of its own. The recurring invoice and the
/// purchase order, whose Overview tab held *only* tags and notes and never
/// showed a line item, use this like the other three.
class BillingDocOverview extends StatefulWidget {
  const BillingDocOverview({
    super.key,
    required this.totalsInput,
    required this.precision,
    this.paidToDate,
    this.balance,
    this.surchargeAmounts = const <Decimal>[],
    this.formatter,
    this.currencyId,
    this.trailing = const <Widget>[],
  });

  final BillingTotalsInput totalsInput;
  final int precision;
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

  @override
  State<BillingDocOverview> createState() => _BillingDocOverviewState();
}

class _BillingDocOverviewState extends State<BillingDocOverview> {
  /// Hoisted (not built in `build`) so the read-only tab doesn't resubscribe
  /// on every parent rebuild — the stable-stream rule. Feeds the surcharge
  /// labels and the line-item header's Custom Labels.
  ///
  /// Watched unconditionally. It used to be lazy — created only for a doc
  /// carrying a surcharge — but the header's Custom Labels
  /// (`settings.translations`) need the company on every doc
  /// (invoiceninja/flutter#84), and a single-row Drift watch is cheap enough
  /// that gating it isn't worth the divergence. The edit screen's
  /// `LineItemEditor` already watches the company unconditionally.
  Stream<Company?>? _company;
  Company? _seed;

  void _ensureCompanyStream() {
    if (_company != null) return;
    final services = context.read<Services>();
    final companyId = services.auth.currentCompanyId ?? '';
    // First-frame seed: without it the surcharge rows appear late and the
    // line-item column labels change under the user on every row click, since
    // the detail pane re-mounts this per `:id`.
    _seed = services.company.peek(companyId: companyId, id: companyId);
    _company = services.company.watchCompany(companyId);
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
    if (stream == null) return _body(context, null);
    return StreamBuilder<Company?>(
      initialData: _seed,
      stream: stream,
      builder: (context, snap) => _body(context, snap.data),
    );
  }

  Widget _body(BuildContext context, Company? company) {
    final surchargeRows = buildSurchargeRows(
      customFields: company?.customFields,
      amounts: widget.surchargeAmounts,
    );
    final totalsInput = widget.totalsInput;
    final precision = widget.precision;
    final formatter = widget.formatter;
    final currencyId = widget.currencyId;
    final paidToDate = widget.paidToDate;
    final balance = widget.balance;
    final trailing = widget.trailing;
    final totals = computeTotals(totalsInput, precision);
    final gap = InSpacing.lg(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LineItemsReadonlyTable(
          items: totalsInput.lineItems,
          formatter: formatter,
          currencyId: currencyId,
          discountIsAmount: totalsInput.isAmountDiscount,
          labels: CompanyLabels.fromCompany(company),
        ),
        SizedBox(height: gap),
        LayoutBuilder(
          builder: (context, constraints) {
            final totalsCard = TotalsWidget(
              totals: totals,
              discount: totalsInput.discount,
              discountIsAmount: totalsInput.isAmountDiscount,
              surcharges: surchargeRows,
              paidToDate: paidToDate,
              balance: balance,
              formatter: formatter,
              currencyId: currencyId,
            );
            // Right-aligned at its own width where there is room to see that
            // it is — and full width where there is not. Capped a few pixels
            // short of the table above it (a 390 px phone leaves six), it
            // read as a card that had slipped.
            if (constraints.maxWidth < _kTotalsWidth + _kTotalsMinMargin) {
              return totalsCard;
            }
            return Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kTotalsWidth),
                child: totalsCard,
              ),
            );
          },
        ),
        for (final w in trailing) ...[SizedBox(height: gap), w],
      ],
    );
  }
}

/// The totals card's width when it sits at the end of its row, and how much
/// room has to be left beside it for that to read as deliberate.
const double _kTotalsWidth = 360;
const double _kTotalsMinMargin = 64;

/// [BillingDocOverview] for a document in hand — the Overview tab of every
/// billing document's record screen.
///
/// It does the two things each screen used to do for itself, three of them
/// each with their own watch on the client: map the document's fields to the
/// totals input, and resolve the currency the document is in — the client's
/// (through its group, then the company) or, on a purchase order, the
/// vendor's. That currency also sets the precision the totals round to (JPY
/// 0 dp, BHD / KWD 3 dp), so it cannot be a detail left to the caller.
class BillingDocOverviewOf extends StatelessWidget {
  const BillingDocOverviewOf({
    super.key,
    required this.type,
    required this.doc,
    this.formatter,
    this.paidToDate,
    this.showBalance = false,
    this.trailing,
  });

  final BillingDocType type;
  final BillingDocFields doc;
  final Formatter? formatter;

  /// Adds a Paid to Date row to the totals — invoice and credit.
  final Decimal? paidToDate;

  /// Adds the Balance row under it.
  final bool showBalance;

  /// Sections after the totals, handed the resolved currency: the invoice's
  /// applied payments and its reminders.
  final List<Widget> Function(BuildContext context, String? currencyId)?
  trailing;

  @override
  Widget build(BuildContext context) {
    final vendorParty = type.party == BillingDocParty.vendor;
    // A gap under the tab strip and nothing at the sides: the record page
    // already insets a tab's body to the edge the cards above it share. The
    // old screens padded the tab on all four sides inside a padded scroll
    // view, so the line items sat one inset further in than everything else.
    final overview = Padding(
      padding: EdgeInsets.only(top: InSpacing.lg(context)),
      child: PartyCurrencyBuilder(
        clientId: vendorParty ? null : doc.clientId,
        vendorId: vendorParty ? doc.vendorId : null,
        builder: (context, currencyId) => BillingDocOverview(
          totalsInput: doc.totalsInput,
          surchargeAmounts: [
            doc.customSurcharge1,
            doc.customSurcharge2,
            doc.customSurcharge3,
            doc.customSurcharge4,
          ],
          precision: formatter?.precisionFor(clientCurrencyId: currencyId) ?? 2,
          paidToDate: paidToDate,
          balance: showBalance ? doc.balance : null,
          formatter: formatter,
          currencyId: currencyId,
          trailing: [
            // Straight under the totals, as on the page. And ahead of the
            // host's sections, not after: those hide themselves when they
            // have nothing to show but are still paid a gap each, which at
            // the foot of the tab is invisible and above this card was not.
            if (BillingDocPrintedNotesCard.hasContent(doc))
              BillingDocPrintedNotesCard(doc: doc, formatter: formatter),
            ...?trailing?.call(context, currencyId),
          ],
        ),
      ),
    );
    // On the same edge as the cards above the strip, which the record column
    // caps and centres below its two-column width. Uncapped, the line-items
    // table ran a few pixels wider than everything over it in the band where
    // the column is wider than the cap but has no PDF pane beside it yet.
    return LayoutBuilder(
      builder: (context, constraints) =>
          constraints.maxWidth >= Breakpoints.entityFormMultiColumn
          ? overview
          : CenteredFormColumn(child: overview),
    );
  }
}
