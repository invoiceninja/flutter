import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/payments/view_models/payment_edit_view_model.dart';
import 'package:admin/utils/formatting.dart';

/// Running-totals row under the allocations editor.
///
/// Three cells, left-aligned (consistent with the rest of the form):
///   * **Total** — net of invoice and credit allocations (`invoice - credit`).
///     Flips to the error color + adds an `Icons.error_outline` when credits
///     exceed invoices (server rejects that case).
///   * **Credit** — credit-side sum. Always rendered when a credit is in play
///     OR when the section has any allocations at all so the column doesn't
///     flicker in/out mid-edit.
///   * **Remaining** — `draft.amount - net`. Negative means the user has
///     over-allocated relative to the payment amount they typed.
class PaymentAllocationsFooter extends StatelessWidget {
  const PaymentAllocationsFooter({
    super.key,
    required this.vm,
    this.formatter,
    this.currencyId,
  });

  final PaymentEditViewModel vm;
  final Formatter? formatter;

  /// Effective payment currency, resolved by the layout (client → group →
  /// company). Falls back to `draft.currencyId` when not supplied.
  final String? currencyId;

  // `clientCurrencyId` matters: the Formatter handed down here is
  // company-scoped, so without it a JPY/EUR client's totals rendered with the
  // company's symbol, separators AND precision.
  String _fmt(Decimal value) => formatter == null
      ? value.toString()
      : formatter!.money(
          value,
          clientCurrencyId: currencyId?.isNotEmpty == true
              ? currencyId
              : vm.draft.currencyId,
        );

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final invoiceTotal = vm.invoiceAllocatedTotal;
    final creditTotal = vm.creditAllocatedTotal;
    final net = invoiceTotal - creditTotal;
    final remaining = vm.draft.amount - net;
    final overCredited = net < Decimal.zero;
    final hasAnyAllocation = vm.draft.paymentables.isNotEmpty;

    // Don't render an orphaned `Total $0` footer when there are no
    // allocations AND no payment amount typed — keeps the form quiet
    // before the user has done anything.
    if (!hasAnyAllocation && vm.draft.amount == Decimal.zero) {
      return const SizedBox.shrink();
    }

    final errorColor = theme.colorScheme.error;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          _Cell(
            label: context.tr('total'),
            value: _fmt(net),
            valueColor: overCredited ? errorColor : tokens.ink,
            leading: overCredited
                ? Icon(Icons.error_outline, color: errorColor, size: 16)
                : null,
            tooltip: overCredited ? context.tr('credit_payment_error') : null,
          ),
          if (hasAnyAllocation)
            _Cell(
              label: context.tr('credit'),
              value: _fmt(creditTotal),
              valueColor: creditTotal > Decimal.zero ? tokens.ink : tokens.ink3,
            ),
          if (vm.draft.amount > Decimal.zero)
            _Cell(
              label: context.tr('remaining'),
              value: _fmt(remaining),
              valueColor: remaining < Decimal.zero ? errorColor : tokens.ink,
              leading: remaining < Decimal.zero
                  ? Icon(Icons.error_outline, color: errorColor, size: 16)
                  : null,
            ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.label,
    required this.value,
    required this.valueColor,
    this.leading,
    this.tooltip,
  });

  final String label;
  final String value;
  final Color valueColor;
  final Widget? leading;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 4)],
        Text('$label ', style: TextStyle(color: tokens.ink3, fontSize: 12)),
        Text(
          value,
          style: moneyTextStyle(color: valueColor, fontWeight: FontWeight.w600),
        ),
      ],
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: row);
    }
    return row;
  }
}
