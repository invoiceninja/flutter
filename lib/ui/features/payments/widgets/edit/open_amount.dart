import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/core/widgets/ltr_value.dart';
import 'package:admin/utils/formatting.dart';

/// An invoice's or credit's open amount, as the trailing value of a payment
/// picker's option row (`SearchableDropdownField.optionTrailingBuilder`).
///
/// Its own widget rather than the tail of the row's label because the label
/// ellipsizes, and the amount is what a user ticking off a client's invoices
/// picks by — beta feedback: an agency billed per end client could not see
/// which invoice was which once the number and client name filled the row.
/// v1 drew it the same way (`overrideSuggestedAmount`).
class OpenAmountText extends StatelessWidget {
  const OpenAmountText({
    super.key,
    required this.amount,
    required this.formatter,
    this.currencyId,
  });

  final Decimal amount;
  final Formatter? formatter;
  final String? currencyId;

  @override
  Widget build(BuildContext context) {
    return LtrText(
      formatOpenAmount(amount, formatter, currencyId),
      maxLines: 1,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: context.inTheme.ink2,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

String formatOpenAmount(
  Decimal amount,
  Formatter? formatter,
  String? currencyId,
) =>
    formatter?.money(amount, clientCurrencyId: currencyId) ?? amount.toString();

/// What a query matches an open amount by (`searchTextOf`): the amount as
/// shown and as typed (`265.50` finds `£265.50`), as v1's `matchesFilter`
/// did — taking the amount out of the label must not stop it being found.
String openAmountSearchText(
  Decimal amount,
  Formatter? formatter,
  String? currencyId,
) {
  final shown = formatOpenAmount(amount, formatter, currencyId);
  final typed = formatter?.inputMoney(amount, currencyId: currencyId) ?? '';
  return '$shown $typed ${amount.toString()}';
}
