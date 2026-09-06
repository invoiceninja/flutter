import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
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
/// single document needs more. Surcharge slots render only when the company
/// has given them a label (`customFields['surcharge1'..'surcharge4']`).
/// Per-surcharge taxability is a company-level setting, so it is not edited
/// here (matching React) — only the amounts.
class BillingTaxSurchargeSection extends StatefulWidget {
  const BillingTaxSurchargeSection({
    required this.companyId,
    required this.taxRows,
    required this.usesInclusiveTaxes,
    required this.onInclusiveChanged,
    required this.surcharges,
    super.key,
  });

  final String companyId;

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
  int? _visibleTaxRows;

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
    _company = context.read<Services>().company.watchCompany(widget.companyId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Company?>(
      stream: _company,
      builder: (context, snapshot) {
        final company = snapshot.data;
        final companyEnabled = (company?.enabledTaxRates ?? 0).clamp(0, 3);
        final populated = _draftPopulated();
        _visibleTaxRows ??= companyEnabled > populated
            ? companyEnabled
            : populated;
        final visible = _visibleTaxRows!;

        final surchargeLabels = <int, String>{};
        for (var i = 0; i < 4; i++) {
          final label = company?.customFields['surcharge${i + 1}'] ?? '';
          if (label.isNotEmpty) surchargeLabels[i] = label;
        }

        final children = <Widget>[];
        for (var i = 0; i < visible && i < 3; i++) {
          children.add(_TaxRow(index: i + 1, spec: widget.taxRows[i]));
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
        // labels) → collapse entirely rather than render a lone toggle.
        if (visible == 0 && surchargeLabels.isEmpty && populated == 0) {
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

class _TaxRow extends StatelessWidget {
  const _TaxRow({required this.index, required this.spec});
  final int index;
  final TaxRowSpec spec;

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
