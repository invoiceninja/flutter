import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/tax_rate.dart';
import 'package:admin/data/models/value/parsing.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/utils/formatting.dart';

/// Per-slot string setter — `slot` is 1..3.
typedef TaxSlotSetter = void Function(int slot, String value);

/// Amount + tax entry card, shared by the Expense and Recurring Expense edit
/// screens (both feed it from their own ViewModel — no VM type leaks in).
///
/// Tax entry mirrors React (`expenses/create/components/{Details,Taxes}.tsx`)
/// and admin-portal `TaxRateDropdown`:
///   * a **By rate / By amount** selector (`calculate_tax_by_amount`),
///   * **By rate**: each tier is a searchable picker over the company's
///     configured `tax_rates` (selecting one fills both `tax_name` and
///     `tax_rate`); falls back to a freeform name/rate pair when the company
///     has no rates defined,
///   * **By amount**: each tier is a freeform name + amount pair,
///   * switching modes resets the opposite-mode values + names (React
///     `handleResetTaxValues`).
///
/// The number of tiers tracks `company.settings.enabled_expense_tax_rates`
/// (with an "Add tax" overflow up to 3); when it's 0 a hint links to Tax
/// Settings instead of showing tax inputs (React parity).
class ExpenseTaxSection extends StatefulWidget {
  const ExpenseTaxSection({
    super.key,
    required this.companyId,
    required this.amount,
    required this.amountError,
    required this.taxNames,
    required this.taxRates,
    required this.taxAmounts,
    required this.usesInclusiveTaxes,
    required this.calculateTaxByAmount,
    required this.onAmountChanged,
    required this.onTaxNameChanged,
    required this.onTaxRateChanged,
    required this.onTaxAmountChanged,
    required this.onUsesInclusiveTaxesChanged,
    required this.onCalculateByAmountChanged,
  });

  final String companyId;
  final Decimal amount;
  final String? amountError;

  /// Current tier values, length 3 (index 0 → slot 1).
  final List<String> taxNames;
  final List<Decimal> taxRates;
  final List<Decimal> taxAmounts;

  final bool usesInclusiveTaxes;
  final bool calculateTaxByAmount;

  final ValueChanged<String> onAmountChanged;
  final TaxSlotSetter onTaxNameChanged;
  final TaxSlotSetter onTaxRateChanged;
  final TaxSlotSetter onTaxAmountChanged;
  final ValueChanged<bool> onUsesInclusiveTaxesChanged;
  final ValueChanged<bool> onCalculateByAmountChanged;

  @override
  State<ExpenseTaxSection> createState() => _ExpenseTaxSectionState();
}

class _ExpenseTaxSectionState extends State<ExpenseTaxSection> {
  /// `null` until the first frame after the company stream emits — we adopt
  /// the larger of the company's enabled count and the draft's populated
  /// rows. After that the user can add more via the "Add tax" button.
  int? _visibleTaxRows;

  int get _draftPopulated {
    for (var slot = 3; slot >= 1; slot--) {
      final i = slot - 1;
      if (widget.taxNames[i].isNotEmpty ||
          widget.taxRates[i] != Decimal.zero ||
          widget.taxAmounts[i] != Decimal.zero) {
        return slot;
      }
    }
    return 0;
  }

  /// Reveal one more tax tier (up to 3) via the "Add tax" button.
  void _addTaxRow() {
    setState(() {
      final v = _visibleTaxRows ?? 0;
      if (v < 3) _visibleTaxRows = v + 1;
    });
  }

  /// Switch tax-entry mode, clearing the opposite-mode values and all names —
  /// mirrors React `handleResetTaxValues` so a stale rate doesn't ship with a
  /// by-amount expense (or vice versa).
  void _onModeChanged(bool byAmount) {
    if (byAmount == widget.calculateTaxByAmount) return;
    widget.onCalculateByAmountChanged(byAmount);
    for (var slot = 1; slot <= 3; slot++) {
      widget.onTaxNameChanged(slot, '');
      if (byAmount) {
        widget.onTaxRateChanged(slot, '0');
      } else {
        widget.onTaxAmountChanged(slot, '0');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return StreamBuilder<Company?>(
      stream: services.company.watchCompany(widget.companyId),
      builder: (context, snapshot) {
        final companyEnabled = (snapshot.data?.enabledExpenseTaxRates ?? 0)
            .clamp(0, 3);
        _visibleTaxRows ??= companyEnabled > _draftPopulated
            ? companyEnabled
            : _draftPopulated;
        final visible = _visibleTaxRows!;

        return DashboardCardShell(
          title: context.tr('amount'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              EntityEditField(
                label: context.tr('amount'),
                initial: decimalInputText(widget.amount),
                onChanged: widget.onAmountChanged,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                errorText: widget.amountError,
              ),
              if (visible == 0)
                _TaxDisabledHint()
              else
                _TaxArea(
                  state: this,
                  visible: visible,
                  companyId: widget.companyId,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Hint shown when `enabled_expense_tax_rates == 0` — directs the user to Tax
/// Settings rather than offering tax inputs (React `Taxes.tsx`).
class _TaxDisabledHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Padding(
      padding: EdgeInsets.only(top: InSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.tr('expense_tax_help'),
              style: TextStyle(color: tokens.ink3, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () => context.go('/settings/tax_settings'),
            child: Text(context.tr('settings')),
          ),
        ],
      ),
    );
  }
}

class _TaxArea extends StatelessWidget {
  const _TaxArea({
    required this.state,
    required this.visible,
    required this.companyId,
  });

  final _ExpenseTaxSectionState state;
  final int visible;
  final String companyId;

  @override
  Widget build(BuildContext context) {
    final w = state.widget;
    final byAmount = w.calculateTaxByAmount;
    final canAdd = visible < 3;
    final services = context.read<Services>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(top: InSpacing.sm, bottom: InSpacing.xs),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(context.tr('by_rate'))),
                ButtonSegment(
                  value: true,
                  label: Text(context.tr('by_amount')),
                ),
              ],
              selected: {byAmount},
              onSelectionChanged: (set) =>
                  set.isEmpty ? null : state._onModeChanged(set.first),
            ),
          ),
        ),
        // By-rate tiers pick from the company's bundled tax rates. One stream
        // feeds every visible slot.
        if (!byAmount)
          StreamBuilder<List<TaxRate>>(
            stream: services.taxRates.watchAll(companyId: companyId),
            builder: (context, snap) {
              final rates = snap.data ?? const <TaxRate>[];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var slot = 1; slot <= visible; slot++)
                    _RatePickerSlot(state: state, slot: slot, rates: rates),
                ],
              );
            },
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var slot = 1; slot <= visible; slot++)
                _AmountSlot(state: state, slot: slot),
            ],
          ),
        if (canAdd)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: state._addTaxRow,
              icon: const Icon(Icons.add, size: 16),
              label: Text(context.tr('add_tax')),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(top: InSpacing.sm),
          child: SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('inclusive_taxes')),
            value: w.usesInclusiveTaxes,
            onChanged: w.onUsesInclusiveTaxesChanged,
          ),
        ),
      ],
    );
  }
}

/// One by-rate tier: a searchable picker over the bundled tax rates (picking
/// one writes both name + rate). Falls back to a freeform name/rate pair when
/// the company has no rates configured. Mirrors the products tax slot.
class _RatePickerSlot extends StatelessWidget {
  const _RatePickerSlot({
    required this.state,
    required this.slot,
    required this.rates,
  });

  final _ExpenseTaxSectionState state;
  final int slot;
  final List<TaxRate> rates;

  @override
  Widget build(BuildContext context) {
    final w = state.widget;
    final i = slot - 1;
    final name = w.taxNames[i];
    final rate = w.taxRates[i];

    if (rates.isEmpty) {
      // No bundled rates → keep a freeform pair so a tax can still be entered.
      return Padding(
        padding: EdgeInsets.symmetric(vertical: InSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: EntityEditField(
                label: context.tr('tax_name$slot'),
                initial: name,
                onChanged: (v) => w.onTaxNameChanged(slot, v),
              ),
            ),
            SizedBox(width: InSpacing.md(context)),
            Expanded(
              flex: 2,
              child: EntityEditField(
                label: context.tr('tax_rate$slot'),
                initial: decimalInputText(rate),
                onChanged: (v) => w.onTaxRateChanged(slot, v),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
          ],
        ),
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
    // Stored value not in the bundled list (a legacy hand-entered rate) → show
    // a synthetic entry so the user still sees what's saved.
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
      padding: EdgeInsets.symmetric(vertical: InSpacing.xs),
      child: SearchableDropdownField<TaxRate>(
        label: context.tr('tax_rate$slot'),
        items: sorted,
        initialValue: selected,
        displayString: (r) => '${r.name} (${r.rate}%)',
        idOf: (r) => '${r.name}|${r.rate}',
        onChanged: (r) {
          w.onTaxNameChanged(slot, r?.name ?? '');
          w.onTaxRateChanged(slot, r == null ? '0' : r.rate.toString());
        },
      ),
    );
  }
}

/// One by-amount tier: freeform name + tax-amount pair.
class _AmountSlot extends StatelessWidget {
  const _AmountSlot({required this.state, required this.slot});

  final _ExpenseTaxSectionState state;
  final int slot;

  @override
  Widget build(BuildContext context) {
    final w = state.widget;
    final i = slot - 1;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: InSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: EntityEditField(
              label: context.tr('tax_name$slot'),
              initial: w.taxNames[i],
              onChanged: (v) => w.onTaxNameChanged(slot, v),
            ),
          ),
          SizedBox(width: InSpacing.md(context)),
          Expanded(
            flex: 2,
            child: EntityEditField(
              label: context.tr('tax_amount'),
              initial: decimalInputText(w.taxAmounts[i]),
              onChanged: (v) => w.onTaxAmountChanged(slot, v),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
