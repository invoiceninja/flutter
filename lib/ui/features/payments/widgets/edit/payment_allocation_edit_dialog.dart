import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/payments/widgets/edit/payment_allocations_section.dart';
import 'package:admin/utils/formatting.dart'
    show decimalInputText, Formatter, parseDecimal;

/// Modal editor used by the narrow-mode card list. Picker + amount in one
/// dialog so phone users edit a single allocation without juggling a
/// cramped row.
Future<Paymentable?> showPaymentAllocationEditDialog(
  BuildContext context, {
  required AllocationKind kind,
  required Paymentable? initial,
  required List<AllocationTarget> targets,
  required Set<String> excludeIds,
  required Decimal paymentAmount,
  required Decimal allocatedExcludingThisRow,
  Formatter? formatter,
}) {
  return showDialog<Paymentable>(
    context: context,
    builder: (ctx) => _PaymentAllocationEditDialog(
      kind: kind,
      initial: initial,
      targets: targets
          .where((t) => !excludeIds.contains(t.id))
          .toList(growable: false),
      paymentAmount: paymentAmount,
      allocatedExcludingThisRow: allocatedExcludingThisRow,
      formatter: formatter,
    ),
  );
}

class _PaymentAllocationEditDialog extends StatefulWidget {
  const _PaymentAllocationEditDialog({
    required this.kind,
    required this.initial,
    required this.targets,
    required this.paymentAmount,
    required this.allocatedExcludingThisRow,
    required this.formatter,
  });

  final AllocationKind kind;
  final Paymentable? initial;
  final List<AllocationTarget> targets;
  final Decimal paymentAmount;
  final Decimal allocatedExcludingThisRow;
  final Formatter? formatter;

  @override
  State<_PaymentAllocationEditDialog> createState() =>
      _PaymentAllocationEditDialogState();
}

class _PaymentAllocationEditDialogState
    extends State<_PaymentAllocationEditDialog> {
  AllocationTarget? _selected;
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    final initialId = widget.initial == null
        ? ''
        : (widget.kind == AllocationKind.invoice
              ? widget.initial!.invoiceId
              : widget.initial!.creditId);
    for (final t in widget.targets) {
      if (t.id == initialId) {
        _selected = t;
        break;
      }
    }
    _amountController = TextEditingController(
      text: decimalInputText(widget.initial?.amount ?? Decimal.zero),
    );
    // Drive the Save button's enabled state off the live amount value.
    _amountController.addListener(_onAmountChanged);
  }

  bool get _useComma =>
      widget.formatter?.settings.useCommaAsDecimalPlace ?? false;

  void _onAmountChanged() {
    final parsed =
        parseDecimal(
          _amountController.text,
          useCommaAsDecimalPlace: _useComma,
        ) ??
        Decimal.zero;
    final nextPositive = parsed > Decimal.zero;
    if (nextPositive != _amountPositive) {
      setState(() => _amountPositive = nextPositive);
    }
  }

  late bool _amountPositive =
      (widget.initial?.amount ?? Decimal.zero) > Decimal.zero;

  @override
  void dispose() {
    _amountController
      ..removeListener(_onAmountChanged)
      ..dispose();
    super.dispose();
  }

  void _save() {
    if (_selected == null || !_amountPositive) return;
    final amount =
        parseDecimal(
          _amountController.text,
          useCommaAsDecimalPlace: _useComma,
        ) ??
        Decimal.zero;
    final result = Paymentable(
      invoiceId: widget.kind == AllocationKind.invoice ? _selected!.id : '',
      creditId: widget.kind == AllocationKind.credit ? _selected!.id : '',
      amount: amount,
      refunded: widget.initial?.refunded ?? Decimal.zero,
      id: widget.initial?.id ?? '',
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        context.tr(
          widget.kind == AllocationKind.invoice ? 'invoice' : 'credit',
        ),
      ),
      content: SizedBox(
        // Cap to the viewport (minus AlertDialog insets) so the dialog never
        // overflows a phone screen narrower than 400 px.
        width: math.min(400.0, MediaQuery.sizeOf(context).width - 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SearchableDropdownField<AllocationTarget>(
              label: context.tr(
                widget.kind == AllocationKind.invoice ? 'invoice' : 'credit',
              ),
              items: widget.targets,
              initialValue: _selected,
              displayString: (t) {
                final number = t.number.isEmpty
                    ? context.tr('pending')
                    : '#${t.number}';
                final amount = widget.formatter == null
                    ? t.balance.toString()
                    : widget.formatter!.money(t.balance);
                return '$number · $amount';
              },
              idOf: (t) => t.id,
              onChanged: (target) {
                if (target == null) return;
                setState(() {
                  _selected = target;
                  // Re-seed amount from preferred + cap.
                  final autoFill = computeAutoFillAmount(
                    kind: widget.kind,
                    target: target,
                    paymentAmount: widget.paymentAmount,
                    allocatedExcludingThisRow: widget.allocatedExcludingThisRow,
                  );
                  _amountController.text = decimalInputText(autoFill);
                });
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: context.tr(
                  widget.kind == AllocationKind.invoice ? 'amount' : 'applied',
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: widget.initial != null,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr('cancel')),
            ),
            const SizedBox(width: 8),
            PrimaryDialogAction(
              label: context.tr('save'),
              onPressed: _save,
              enabled: _selected != null && _amountPositive,
              autofocus: false,
            ),
          ],
        ),
      ],
    );
  }
}
