import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_gateway.dart';
import 'package:admin/data/models/domain/tax_rate.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/domain/gateway_constants.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/gateways/view_models/company_gateway_edit_view_model.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

/// Limits & Fees tab — per-payment-type editor. The user picks the active
/// payment type from a chip selector and the per-type form sits below.
class GatewayLimitsFeesTab extends StatefulWidget {
  const GatewayLimitsFeesTab({super.key, required this.vm});

  final CompanyGatewayEditViewModel vm;

  @override
  State<GatewayLimitsFeesTab> createState() => _GatewayLimitsFeesTabState();
}

class _GatewayLimitsFeesTabState extends State<GatewayLimitsFeesTab> {
  String? _activeTypeId;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final statics = services.statics;
    final draft = widget.vm.draft;
    final enabledTypeIds = draft.feesAndLimits.entries
        .where((e) => e.value.isEnabled)
        .map((e) => e.key)
        .toList();

    if (enabledTypeIds.isEmpty) {
      return SettingsFormShell(
        child: Center(
          child: Text(
            context.tr('no_payment_types_enabled'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final active =
        _activeTypeId != null && enabledTypeIds.contains(_activeTypeId)
        ? _activeTypeId!
        : enabledTypeIds.first;
    final fees = draft.feesAndLimits[active] ?? const FeesAndLimits();

    // The active company drives (a) how many fee-tax slots to show
    // (`enabled_item_tax_rates`, exactly like the line-item editor + Tax
    // Settings) and (b) the decimal separator for parsing typed input.
    return StreamBuilder<Company?>(
      stream: services.company.watchCompany(widget.vm.companyId),
      builder: (context, snap) {
        final company = snap.data;
        final taxRateSlots = company?.enabledItemTaxRates ?? 0;
        final useComma = company?.useCommaAsDecimalPlace ?? false;
        final formatter = services.formatterIfReady(widget.vm.companyId);
        return SettingsFormShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: InSpacing.sm,
                runSpacing: InSpacing.sm,
                children: [
                  for (final id in enabledTypeIds)
                    ChoiceChip(
                      label: Text(_typeLabel(context, statics, id)),
                      selected: id == active,
                      onSelected: (_) => setState(() => _activeTypeId = id),
                    ),
                ],
              ),
              SizedBox(height: InSpacing.lg(context)),
              // Key on the active type id: the text fields seed from
              // `initialValue` (applied once in initState), so switching the
              // payment-type chip must recreate them — otherwise they'd keep
              // showing the previous type's amounts.
              _LimitsAndFeesEditor(
                key: ValueKey(active),
                vm: widget.vm,
                typeId: active,
                fees: fees,
                taxRateSlots: taxRateSlots,
                useComma: useComma,
                formatter: formatter,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Localized name for a gateway type id. See the matching helper on
  /// `GatewaySettingsTab` — same fallback chain.
  String _typeLabel(
    BuildContext context,
    StaticsRepository statics,
    String typeId,
  ) {
    final type = statics.gatewayType(typeId);
    if (type == null) return 'type $typeId';
    return context.tr(type.name);
  }
}

class _LimitsAndFeesEditor extends StatelessWidget {
  const _LimitsAndFeesEditor({
    super.key,
    required this.vm,
    required this.typeId,
    required this.fees,
    required this.taxRateSlots,
    required this.useComma,
    required this.formatter,
  });

  final CompanyGatewayEditViewModel vm;
  final String typeId;
  final FeesAndLimits fees;

  /// Number of fee-tax slots to show (company `enabled_item_tax_rates`, 0-3).
  final int taxRateSlots;

  /// Active company decimal-comma flag — drives input parsing.
  final bool useComma;

  /// Company `Formatter` if already resolved; seeds inputs empty-for-zero.
  final Formatter? formatter;

  /// Seed a numeric field: empty for zero (per CLAUDE.md § Forms), otherwise
  /// the locale-aware rendering. Falls back to a locale-correct `toString()`
  /// only when the formatter hasn't resolved yet (cold deep-link) — still
  /// honoring the decimal-comma so the seed matches what the parser expects.
  String _seed(double value) {
    if (formatter != null) return formatter!.inputAmount(value);
    if (value == 0) return '';
    final s = value.toString();
    return useComma ? s.replaceFirst('.', ',') : s;
  }

  double _parse(String v) =>
      parseDouble(v, useCommaAsDecimalPlace: useComma) ?? 0;

  @override
  Widget build(BuildContext context) {
    final minEnabled = fees.minLimit != kGatewayLimitDisabled;
    final maxEnabled = fees.maxLimit != kGatewayLimitDisabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormSection(
          title: context.tr('limits'),
          children: [
            SwitchListTile(
              title: Text(context.tr('enable_min')),
              value: minEnabled,
              onChanged: (v) => vm.updateFees(
                typeId,
                fees.copyWith(minLimit: v ? 0 : kGatewayLimitDisabled),
              ),
              contentPadding: EdgeInsets.zero,
            ),
            if (minEnabled)
              TextFormField(
                initialValue: _seed(fees.minLimit),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                // `min_amount` / `max_amount`, not `min_limit` / `max_limit` —
                // the latter are the display forms "Min: :min" / "Max: :max".
                decoration: InputDecoration(
                  labelText: context.tr('min_amount'),
                ),
                onChanged: (v) =>
                    vm.updateFees(typeId, fees.copyWith(minLimit: _parse(v))),
              ),
            SwitchListTile(
              title: Text(context.tr('enable_max')),
              value: maxEnabled,
              onChanged: (v) => vm.updateFees(
                typeId,
                fees.copyWith(maxLimit: v ? 0 : kGatewayLimitDisabled),
              ),
              contentPadding: EdgeInsets.zero,
            ),
            if (maxEnabled)
              TextFormField(
                initialValue: _seed(fees.maxLimit),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: context.tr('max_amount'),
                ),
                onChanged: (v) =>
                    vm.updateFees(typeId, fees.copyWith(maxLimit: _parse(v))),
              ),
          ],
        ),
        FormSection(
          title: context.tr('fees'),
          children: [
            TextFormField(
              initialValue: _seed(fees.feeAmount),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: context.tr('fee_amount')),
              onChanged: (v) =>
                  vm.updateFees(typeId, fees.copyWith(feeAmount: _parse(v))),
            ),
            TextFormField(
              initialValue: _seed(fees.feePercent),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: context.tr('fee_percent')),
              onChanged: (v) =>
                  vm.updateFees(typeId, fees.copyWith(feePercent: _parse(v))),
            ),
            // Fee-tax slots — one per company item-tax-rate (0-3). Each picks
            // a bundled tax rate and writes the `fee_tax_name<N>` /
            // `fee_tax_rate<N>` pair together, mirroring React + admin-portal.
            for (var slot = 1; slot <= taxRateSlots && slot <= 3; slot++)
              _FeeTaxPicker(
                vm: vm,
                typeId: typeId,
                fees: fees,
                slot: slot,
                singleSlot: taxRateSlots == 1,
              ),
            TextFormField(
              initialValue: _seed(fees.feeCap),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: context.tr('fee_cap')),
              onChanged: (v) =>
                  vm.updateFees(typeId, fees.copyWith(feeCap: _parse(v))),
            ),
            SwitchListTile(
              title: Text(context.tr('adjust_fee_percent')),
              value: fees.adjustFeePercent,
              onChanged: (v) =>
                  vm.updateFees(typeId, fees.copyWith(adjustFeePercent: v)),
              contentPadding: EdgeInsets.zero,
            ),
            _FeePreview(fees: fees, companyId: vm.companyId),
          ],
        ),
      ],
    );
  }
}

/// One fee-tax-rate row. Mirrors `TaxRatePicker` (Tax Settings): strict-pick
/// from the bundled tax rates, writing the name + rate pair together. Unlike
/// `TaxRatePicker` this binds to the gateway draft's `FeesAndLimits`, not the
/// company settings cascade, so it's a purpose-built (small) variant.
class _FeeTaxPicker extends StatelessWidget {
  const _FeeTaxPicker({
    required this.vm,
    required this.typeId,
    required this.fees,
    required this.slot,
    required this.singleSlot,
  });

  final CompanyGatewayEditViewModel vm;
  final String typeId;
  final FeesAndLimits fees;
  final int slot; // 1-3
  final bool singleSlot;

  String get _currentName => switch (slot) {
    1 => fees.feeTaxName1,
    2 => fees.feeTaxName2,
    _ => fees.feeTaxName3,
  };

  double get _currentRate => switch (slot) {
    1 => fees.feeTaxRate1,
    2 => fees.feeTaxRate2,
    _ => fees.feeTaxRate3,
  };

  FeesAndLimits _write({required String name, required double rate}) {
    switch (slot) {
      case 1:
        return fees.copyWith(feeTaxName1: name, feeTaxRate1: rate);
      case 2:
        return fees.copyWith(feeTaxName2: name, feeTaxRate2: rate);
      default:
        return fees.copyWith(feeTaxName3: name, feeTaxRate3: rate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final label = singleSlot ? context.tr('tax') : '${context.tr('tax')} $slot';
    return Padding(
      padding: EdgeInsets.only(top: InSpacing.md(context)),
      child: StreamBuilder<List<TaxRate>>(
        stream: services.taxRates.watchAll(companyId: vm.companyId),
        builder: (context, snap) {
          final rates = snap.data ?? const <TaxRate>[];
          final sorted = [...rates]..sort((a, b) => a.name.compareTo(b.name));

          // Match the stored name+rate against the bundled list; fall back to
          // a synthetic entry so a legacy/hand-entered value still shows.
          TaxRate? selected;
          for (final r in sorted) {
            if (r.name == _currentName &&
                (r.rate - _currentRate).abs() < 0.0001) {
              selected = r;
              break;
            }
          }
          if (selected == null && _currentName.isNotEmpty) {
            selected = TaxRate(
              id: '__current__',
              name: _currentName,
              rate: _currentRate,
              updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
              createdAt: DateTime.fromMillisecondsSinceEpoch(0),
              archivedAt: null,
              isDeleted: false,
            );
          }

          return SearchableDropdownField<TaxRate>(
            label: label,
            items: sorted,
            initialValue: selected,
            displayString: (r) => '${r.name} (${r.rate}%)',
            idOf: (r) => '${r.name}|${r.rate}',
            onChanged: (r) => vm.updateFees(
              typeId,
              _write(name: r?.name ?? '', rate: r?.rate ?? 0),
            ),
          );
        },
      ),
    );
  }
}

/// Live preview: "On a $100 payment: total $X, fee $Y" — rendered through
/// the company `Formatter` so the currency symbol / locale match the rest
/// of the app instead of a hardcoded `$`.
class _FeePreview extends StatelessWidget {
  const _FeePreview({required this.fees, required this.companyId});
  final FeesAndLimits fees;
  final String companyId;

  @override
  Widget build(BuildContext context) {
    const sample = 100.0;
    var fee = _sampleFee(sample);
    final total = sample + fee;
    final tokens = context.inTheme;
    final services = context.read<Services>();
    return FutureBuilder<Formatter>(
      future: services.formatterFor(companyId),
      initialData: services.formatterIfReady(companyId),
      builder: (context, snapshot) {
        final formatter = snapshot.data;
        // Money via the company `Formatter` (no currencyId → company
        // default). Before it resolves (cold deep-link), fall back to a
        // bare `$` so the preview still renders.
        String money(double value, {int fractionDigits = 2}) {
          if (formatter == null) {
            return '\$${value.toStringAsFixed(fractionDigits)}';
          }
          return formatter.money(Decimal.parse(value.toStringAsFixed(2)));
        }

        return Padding(
          padding: EdgeInsets.only(top: InSpacing.md(context)),
          child: Text(
            // `fees_sample_detailed`, not `fees_sample` — the Transifex string
            // is "The fee for a :amount invoice would be :total.", which names
            // the *total* as the fee and drops `fee` entirely.
            context.tr('fees_sample_detailed', {
              'amount': money(sample, fractionDigits: 0),
              'total': money(total),
              'fee': money(fee),
            }),
            style: TextStyle(color: tokens.ink2),
          ),
        );
      },
    );
  }

  /// Sample fee on [baseAmount], honoring `adjust_fee_percent` and `fee_cap` —
  /// mirrors admin-portal's `calculateSampleFee` (the correct branches; the
  /// fee-tax line is omitted, matching the prior preview, since it doesn't
  /// affect the headline fee/total the merchant tunes here).
  double _sampleFee(double baseAmount) {
    double fee;
    if (fees.feePercent == 0) {
      fee = fees.feeAmount;
    } else if (fees.adjustFeePercent && fees.feePercent < 100) {
      // Gross-up: charge enough that the merchant nets `baseAmount` after the
      // percentage fee is taken out.
      fee =
          ((fees.feeAmount + baseAmount) / (1 - fees.feePercent / 100)) -
          baseAmount;
    } else {
      fee = fees.feeAmount + (baseAmount * fees.feePercent / 100);
    }
    if (fees.feeCap > 0 && fee > fees.feeCap) fee = fees.feeCap;
    return fee < 0 ? 0 : fee;
  }
}
