import 'dart:math';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/custom_field_types.dart';
import 'package:admin/data/models/domain/tax_rate.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/features/billing_shared/edit/tax_rate_tier_picker.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/utils/formatting.dart';

/// One document-level tax tier (name + rate) and its setters.
typedef TaxRowSpec = ({
  String name,
  Decimal rate,
  ValueChanged<String> onName,
  ValueChanged<String> onRate,
});

/// One custom surcharge slot (amount + setter). The label and whether the
/// slot is shown come from the company's `customFields['surcharge{n}']`.
typedef SurchargeSpec = ({Decimal amount, ValueChanged<String> onAmount});

/// Document-level **tax** + **custom surcharge** + **inclusive-tax** editor,
/// shared by every billing-doc edit screen (Invoice / Quote / Credit / PO /
/// RecurringInvoice). These inputs previously had no UI at all — the setters
/// and serialization existed but nothing called them, so a user could not
/// apply a document tax rate, set a surcharge, or toggle inclusive taxes
/// (React exposes all of these in `InvoiceTotals`).
///
/// Tax tiers track the company's `enabled_tax_rates` setting (0–3), like the
/// expense editor; an "Add tax" button overflows into higher tiers when a
/// single document needs more. Each tier picks from the company's configured
/// tax rates (picking one fills both name and rate), as the expense and
/// product forms, admin-portal and React all do — it was a bare name + rate
/// pair, so a company's saved "NYS Sales Tax 8.75%" was nowhere to be picked
/// (beta feedback). A company with no rates keeps the freeform pair.
///
/// Surcharge slots render only when the company has given them a label
/// (`customFields['surcharge1'..'surcharge4']`).
/// Per-surcharge taxability is a company-level setting, so it is not edited
/// here (matching React) — only the amounts.
class BillingTaxSurchargeSection extends StatefulWidget {
  const BillingTaxSurchargeSection({
    required this.companyId,
    this.useCommaAsDecimalPlace = false,
    required this.taxRows,
    required this.usesInclusiveTaxes,
    required this.onInclusiveChanged,
    required this.surcharges,
    super.key,
  });

  final String companyId;

  /// The company's decimal separator, threaded to the numeric fields below.
  /// Without it a comma-locale user typing `12,5` is fought by the re-seed:
  /// `parseDecimal('12,5', useComma: false)` strips the comma and yields 125,
  /// which never equals the parent's canonical `12.5`, so the controller is
  /// rewritten and the caret jumps — the exact bug `numeric` exists to stop.
  final bool useCommaAsDecimalPlace;

  /// Exactly three tiers (taxName/taxRate 1–3); the widget shows as many as
  /// the company enables (plus any already populated, plus "Add tax").
  final List<TaxRowSpec> taxRows;

  final bool usesInclusiveTaxes;
  final ValueChanged<bool> onInclusiveChanged;

  /// Exactly four surcharge slots (customSurcharge 1–4), shown only when the
  /// matching company custom-field label is set.
  final List<SurchargeSpec> surcharges;

  @override
  State<BillingTaxSurchargeSection> createState() =>
      _BillingTaxSurchargeSectionState();
}

class _BillingTaxSurchargeSectionState
    extends State<BillingTaxSurchargeSection> {
  /// Tax tiers on screen. Grow-only — the card has no way to remove a tier —
  /// and recomputed on every build: it used to be latched on the FIRST build,
  /// which on a new document ran before the company row arrived, so a company
  /// with document taxes enabled got zero tiers and (with no surcharges) no
  /// card at all — and with it no inclusive-tax switch.
  int _visibleTaxRows = 0;

  int _draftPopulated() {
    final r = widget.taxRows;
    if (r[2].name.isNotEmpty || r[2].rate != Decimal.zero) return 3;
    if (r[1].name.isNotEmpty || r[1].rate != Decimal.zero) return 2;
    if (r[0].name.isNotEmpty || r[0].rate != Decimal.zero) return 1;
    return 0;
  }

  // Hoist the company watch into state (keyed by companyId) so it is NOT
  // rebuilt on every keystroke — the parent layout rebuilds under
  // AnimatedBuilder(vm), and a fresh `watch()` per build would drop the inner
  // StreamBuilder to a null snapshot and flicker the section.
  Stream<Company?>? _company;
  Stream<List<TaxRate>>? _rates;
  String? _companyId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureStream();
  }

  @override
  void didUpdateWidget(covariant BillingTaxSurchargeSection old) {
    super.didUpdateWidget(old);
    _ensureStream();
  }

  void _ensureStream() {
    if (_companyId == widget.companyId && _company != null) return;
    _companyId = widget.companyId;
    final services = context.read<Services>();
    _company = services.company.watchCompany(widget.companyId);
    _rates = services.taxRates.watchAll(companyId: widget.companyId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Company?>(
      stream: _company,
      // The last company this session saw, so the first frame already knows
      // the enabled tiers instead of drawing none and growing a beat later.
      initialData: context.read<Services>().company.peek(
        companyId: widget.companyId,
        id: widget.companyId,
      ),
      builder: (context, snapshot) {
        final company = snapshot.data;
        final companyEnabled = (company?.enabledTaxRates ?? 0).clamp(0, 3);
        final populated = _draftPopulated();
        _visibleTaxRows = max(_visibleTaxRows, max(companyEnabled, populated));
        final visible = _visibleTaxRows;

        final surchargeLabels = <int, String>{};
        for (var i = 0; i < 4; i++) {
          final label = surchargeLabel(
            company?.customFields['surcharge${i + 1}'],
          );
          if (label.isNotEmpty) surchargeLabels[i] = label;
        }

        final children = <Widget>[];
        if (visible > 0) {
          // One rates stream feeds every visible tier.
          children.add(
            StreamBuilder<List<TaxRate>>(
              stream: _rates,
              builder: (context, rateSnap) {
                final rates = rateSnap.data ?? const <TaxRate>[];
                // Only an ANSWERED empty list means "no rates configured".
                // Before Drift's first emission the picker stands in (its
                // empty-items placeholder reads "Loading"), so a company with
                // rates no longer flashes the freeform pair on every open —
                // and a half-typed name can't be unmounted by the swap.
                final freeform = rateSnap.hasData && rates.isEmpty;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < visible && i < 3; i++)
                      freeform
                          ? _TaxRow(
                              index: i + 1,
                              spec: widget.taxRows[i],
                              useCommaAsDecimalPlace:
                                  widget.useCommaAsDecimalPlace,
                            )
                          : _TaxRatePickerRow(
                              index: i + 1,
                              spec: widget.taxRows[i],
                              rates: rates,
                              useCommaAsDecimalPlace:
                                  widget.useCommaAsDecimalPlace,
                            ),
                  ],
                );
              },
            ),
          );
        }
        if (visible < 3) {
          children.add(
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => setState(() => _visibleTaxRows = visible + 1),
                icon: const Icon(Icons.add, size: 16),
                label: Text(context.tr('add_tax')),
              ),
            ),
          );
        }
        children.add(
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('inclusive_taxes')),
            value: widget.usesInclusiveTaxes,
            onChanged: widget.onInclusiveChanged,
          ),
        );
        for (final entry in surchargeLabels.entries) {
          children.add(
            Padding(
              padding: EdgeInsets.symmetric(vertical: InSpacing.sm),
              child: EntityEditField(
                numeric: true,
                useCommaAsDecimalPlace: widget.useCommaAsDecimalPlace,
                label: entry.value,
                initial: decimalInputText(widget.surcharges[entry.key].amount),
                onChanged: widget.surcharges[entry.key].onAmount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
              ),
            ),
          );
        }

        // Nothing to show (no enabled taxes, none populated, no surcharge
        // labels) → collapse entirely rather than render a lone toggle. Not
        // while the inclusive-tax switch means something: the lines are
        // taxed (`enabled_item_tax_rates`), or the document is inclusive —
        // this card is the only place that switch lives.
        final inclusiveMatters =
            (company?.enabledItemTaxRates ?? 0) > 0 ||
            widget.usesInclusiveTaxes;
        if (visible == 0 &&
            surchargeLabels.isEmpty &&
            populated == 0 &&
            !inclusiveMatters) {
          return const SizedBox.shrink();
        }

        return DashboardCardShell(
          title: context.tr('taxes'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        );
      },
    );
  }
}

/// One tier as a [TaxRateTierPicker] over the company's tax rates.
class _TaxRatePickerRow extends StatelessWidget {
  const _TaxRatePickerRow({
    required this.index,
    required this.spec,
    required this.rates,
    required this.useCommaAsDecimalPlace,
  });
  final int index;
  final TaxRowSpec spec;
  final List<TaxRate> rates;
  final bool useCommaAsDecimalPlace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: InSpacing.xs),
      child: TaxRateTierPicker(
        label: context.tr('tax_rate$index'),
        name: spec.name,
        rate: spec.rate,
        rates: rates,
        useCommaAsDecimalPlace: useCommaAsDecimalPlace,
        onChanged: (name, rate) {
          spec.onName(name);
          // The setter parses with the company's separator, and a plain
          // decimal string has no comma to misread under either setting.
          spec.onRate(rate.toString());
        },
      ),
    );
  }
}

class _TaxRow extends StatelessWidget {
  const _TaxRow({
    required this.index,
    required this.spec,
    required this.useCommaAsDecimalPlace,
  });
  final int index;
  final TaxRowSpec spec;
  final bool useCommaAsDecimalPlace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: InSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: EntityEditField(
              label: context.tr('tax_name$index'),
              initial: spec.name,
              onChanged: spec.onName,
            ),
          ),
          SizedBox(width: InSpacing.md(context)),
          Expanded(
            flex: 2,
            child: EntityEditField(
              numeric: true,
              useCommaAsDecimalPlace: useCommaAsDecimalPlace,
              label: context.tr('tax_rate$index'),
              initial: decimalInputText(spec.rate),
              onChanged: spec.onRate,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
