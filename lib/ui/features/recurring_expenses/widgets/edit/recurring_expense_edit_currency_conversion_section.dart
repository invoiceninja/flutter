import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/recurring_expenses/view_models/recurring_expense_edit_view_model.dart';
import 'package:admin/utils/formatting.dart';

/// Currency conversion sub-form — mirrors
/// `ExpenseEditCurrencyConversionSection`. Lives inside a collapsible
/// parent on the edit screen; this widget renders the fields only.
class RecurringExpenseEditCurrencyConversionSection extends StatelessWidget {
  const RecurringExpenseEditCurrencyConversionSection({
    super.key,
    required this.vm,
  });
  final RecurringExpenseEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final currencies = services.statics.currencies.values.toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    Currency? selected;
    for (final c in currencies) {
      if (c.id == vm.draft.invoiceCurrencyId) {
        selected = c;
        break;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SearchableDropdownField<Currency>(
          label: context.tr('invoice_currency'),
          items: currencies,
          initialValue: selected,
          displayString: (c) => '${c.code} · ${c.name}',
          idOf: (c) => c.id,
          onChanged: (c) {
            vm.setInvoiceCurrencyId(c?.id ?? '');
            // Seed the exchange rate from the two currencies' base rates
            // (React parity); the VM recomputes the foreign amount.
            if (c != null) {
              final rate = crossCurrencyRate(
                services.statics.currencies,
                fromExpenseCurrencyId: vm.draft.currencyId,
                toInvoiceCurrencyId: c.id,
              );
              if (rate != null) vm.setExchangeRate(rate.toString());
            }
          },
          errorText: vm.fieldErrorFor('invoice_currency_id'),
        ),
        EntityEditField(
          label: context.tr('exchange_rate'),
          initial: decimalInputText(vm.draft.exchangeRate),
          onChanged: vm.setExchangeRate,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          errorText: vm.fieldErrorFor('exchange_rate'),
        ),
        EntityEditField(
          label: context.tr('foreign_amount'),
          initial: decimalInputText(vm.draft.foreignAmount),
          onChanged: vm.setForeignAmount,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          errorText: vm.fieldErrorFor('foreign_amount'),
        ),
      ],
    );
  }
}
