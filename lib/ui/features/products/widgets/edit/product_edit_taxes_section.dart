import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/tax_rate.dart';
import 'package:admin/data/models/value/parsing.dart';
import 'package:admin/domain/product_tax_categories.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/products/view_models/product_edit_view_model.dart';
import 'package:admin/utils/formatting.dart';

/// Tax category, product image URL, and the configurable tax-rate slots.
/// `productImage` always renders; `tax_id` (tax category) always renders;
/// the three `tax_name`/`tax_rate` slot pairs are gated on
/// `company.settings.enabled_item_tax_rates` (0=none, 1=one slot, 2=two,
/// 3=three) — matches React `ProductForm.tsx`.
///
/// Each enabled slot is a searchable dropdown over the company's bundled
/// `tax_rates` (picking a rate writes BOTH `tax_name<N>` and `tax_rate<N>`),
/// mirroring the legacy `TaxRateDropdown` and React `<Selector>`. When the
/// company has no tax rates defined, the slot falls back to a freeform
/// name/rate pair so a tax can still be hand-entered.
class ProductEditTaxesSection extends StatelessWidget {
  const ProductEditTaxesSection({super.key, required this.vm});

  final ProductEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return StreamBuilder<Company?>(
      stream: services.company.watchCompany(vm.companyId),
      builder: (context, companySnap) {
        final enabledSlots = companySnap.data?.enabledItemTaxRates ?? 0;
        return DashboardCardShell(
          title: context.tr('taxes'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              EntityEditField(
                label: context.tr('product_image'),
                initial: vm.draft.productImage,
                onChanged: vm.setProductImage,
                keyboardType: TextInputType.url,
                autocorrect: false,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: InSpacing.xs),
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: context.tr('tax_category'),
                  ),
                  initialValue:
                      kProductTaxCategories.containsKey(vm.draft.taxId)
                      ? vm.draft.taxId
                      : null,
                  items: [
                    for (final MapEntry(key: id, value: labelKey)
                        in kProductTaxCategories.entries)
                      DropdownMenuItem(
                        value: id,
                        child: Text(context.tr(labelKey)),
                      ),
                  ],
                  onChanged: (v) => vm.setTaxId(v ?? ''),
                ),
              ),
              // One subscription to the bundled tax rates feeds every enabled
              // slot. Only opened when at least one slot is configured.
              if (enabledSlots >= 1)
                StreamBuilder<List<TaxRate>>(
                  stream: services.taxRates.watchAll(companyId: vm.companyId),
                  builder: (context, rateSnap) {
                    final rates = rateSnap.data ?? const <TaxRate>[];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (enabledSlots >= 1)
                          _TaxSlot(vm: vm, slot: 1, rates: rates),
                        if (enabledSlots >= 2)
                          _TaxSlot(vm: vm, slot: 2, rates: rates),
                        if (enabledSlots >= 3)
                          _TaxSlot(vm: vm, slot: 3, rates: rates),
                      ],
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One tax-rate slot. Renders a searchable dropdown over the bundled
/// `tax_rates`; if the company has none, falls back to the freeform
/// name/rate pair.
class _TaxSlot extends StatelessWidget {
  const _TaxSlot({required this.vm, required this.slot, required this.rates});

  final ProductEditViewModel vm;
  final int slot;
  final List<TaxRate> rates;

  String get _name => switch (slot) {
    1 => vm.draft.taxName1,
    2 => vm.draft.taxName2,
    _ => vm.draft.taxName3,
  };

  Decimal get _rate => switch (slot) {
    1 => vm.draft.taxRate1,
    2 => vm.draft.taxRate2,
    _ => vm.draft.taxRate3,
  };

  ValueChanged<String> get _onNameChanged => switch (slot) {
    1 => vm.setTaxName1,
    2 => vm.setTaxName2,
    _ => vm.setTaxName3,
  };

  ValueChanged<String> get _onRateChanged => switch (slot) {
    1 => vm.setTaxRate1,
    2 => vm.setTaxRate2,
    _ => vm.setTaxRate3,
  };

  @override
  Widget build(BuildContext context) {
    final name = _name;
    final rate = _rate;
    if (rates.isEmpty) {
      // No bundled tax rates → keep the freeform pair so a tax can still
      // be hand-entered. (Typed input correctly routes through the
      // locale-aware String setters.)
      return _TaxRow(
        nameLabel: context.tr('tax_name'),
        rateLabel: context.tr('tax_rate'),
        nameValue: name,
        rateValue: rate,
        onNameChanged: _onNameChanged,
        onRateChanged: _onRateChanged,
      );
    }

    final sorted = [...rates]..sort((a, b) => a.name.compareTo(b.name));

    TaxRate? selected;
    for (final r in sorted) {
      if (r.name == name && numToDecimal(r.rate) == rate) {
        selected = r;
        break;
      }
    }
    // Stored value not in the bundled list (a legacy hand-entered rate) →
    // show a synthetic entry so the user still sees what's saved. It's not
    // added to `items`, so it disappears once a real rate is picked.
    if (selected == null && name.isNotEmpty) {
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: InSpacing.xs),
      child: SearchableDropdownField<TaxRate>(
        label: context.tr('tax_rate'),
        items: sorted,
        initialValue: selected,
        displayString: (r) => '${r.name} (${r.rate}%)',
        idOf: (r) => '${r.name}|${r.rate}',
        onChanged: (r) => vm.setTaxSlot(
          slot,
          name: r?.name ?? '',
          rate: r == null ? Decimal.zero : numToDecimal(r.rate),
        ),
      ),
    );
  }
}

/// Freeform name + rate pair, used only as the fallback when the company has
/// no bundled tax rates to pick from.
class _TaxRow extends StatelessWidget {
  const _TaxRow({
    required this.nameLabel,
    required this.rateLabel,
    required this.nameValue,
    required this.rateValue,
    required this.onNameChanged,
    required this.onRateChanged,
  });

  final String nameLabel;
  final String rateLabel;
  final String nameValue;
  final Decimal rateValue;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onRateChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: EntityEditField(
            label: nameLabel,
            initial: nameValue,
            onChanged: onNameChanged,
          ),
        ),
        SizedBox(width: InSpacing.md(context)),
        Expanded(
          child: EntityEditField(
            label: rateLabel,
            initial: decimalInputText(rateValue),
            onChanged: onRateChanged,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
      ],
    );
  }
}
