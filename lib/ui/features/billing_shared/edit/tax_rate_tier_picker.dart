import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/tax_rate.dart';
import 'package:admin/data/models/value/parsing.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/utils/formatting.dart';

/// One tax tier (a name + rate pair) picked from the company's configured
/// [rates] — a billing document's tier on its Taxes card, and a line's tier in
/// the phone line-item editor. Picking a rate reports both halves of the pair;
/// clearing it reports no tax (`''`, zero).
///
/// [rates] is `TaxRateRepository.watchAll`'s answer, already ordered by
/// `name.lower()` — it is not re-sorted here, which would be case-sensitive
/// and put "county tax" after "Zone Tax". Pass an empty list while that answer
/// is still out: the field then shows its "Loading" placeholder, which is how
/// a host avoids flashing a freeform pair on every open. A host whose company
/// has no rates at all renders its own freeform pair instead.
///
/// A stored pair that is not in the list — typed by hand, or a rate since
/// renamed or deleted — still shows, as a stand-in entry, so opening a
/// document never hides its tax. That includes a rate with no name: the server
/// taxes nothing for a tier named under two characters, but an inclusive
/// document still backs EVERY rate out of its prices (`totals_calculator.dart`,
/// `InclusiveTax::backout`), so a hidden nameless rate would move the total
/// with nothing on screen to explain it, or to clear.
class TaxRateTierPicker extends StatelessWidget {
  const TaxRateTierPicker({
    super.key,
    required this.label,
    required this.name,
    required this.rate,
    required this.rates,
    required this.onChanged,
    this.useCommaAsDecimalPlace = false,
  });

  final String label;

  /// The tier's stored pair.
  final String name;
  final Decimal rate;

  final List<TaxRate> rates;

  /// The picked pair, or `('', 0)` when cleared.
  final void Function(String name, Decimal rate) onChanged;

  /// Renders the percentage in the company's decimal separator.
  final bool useCommaAsDecimalPlace;

  String _label(TaxRate r) {
    final pct = rateInputText(
      r.rate,
      useCommaAsDecimalPlace: useCommaAsDecimalPlace,
      blankZero: false,
    );
    return r.name.isEmpty ? '$pct%' : '${r.name} ($pct%)';
  }

  @override
  Widget build(BuildContext context) {
    TaxRate? selected;
    for (final r in rates) {
      if (r.name == name && numToDecimal(r.rate) == rate) {
        selected = r;
        break;
      }
    }
    if (selected == null && (name.isNotEmpty || rate != Decimal.zero)) {
      selected = TaxRate(
        id: '__current__',
        name: name,
        rate: rate.toDouble(),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        archivedAt: null,
        isDeleted: false,
      );
    }
    return SearchableDropdownField<TaxRate>(
      label: label,
      items: rates,
      initialValue: selected,
      displayString: _label,
      idOf: (r) => '${r.name}|${r.rate}',
      onChanged: (r) => onChanged(
        r?.name ?? '',
        r == null ? Decimal.zero : numToDecimal(r.rate),
      ),
    );
  }
}
