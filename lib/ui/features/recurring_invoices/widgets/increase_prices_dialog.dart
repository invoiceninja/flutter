import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/utils/formatting.dart';

/// Prompt for the Increase Prices bulk action: asks for a percentage and
/// returns it (canonical dot-decimal string) to the caller, which enqueues
/// `MutationKind.increasePrices` per selected recurring invoice. Returns null
/// on cancel or invalid input.
///
/// [useCommaAsDecimalPlace] should be the active company's setting (resolved by
/// the caller, which has `Services` in scope) so a comma-locale user typing
/// `5,5` isn't sent as `55` — a 10× increase.
Future<String?> showIncreasePricesDialog(
  BuildContext context, {
  bool useCommaAsDecimalPlace = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) =>
        _IncreasePricesDialog(useCommaAsDecimalPlace: useCommaAsDecimalPlace),
  );
}

class _IncreasePricesDialog extends StatefulWidget {
  const _IncreasePricesDialog({required this.useCommaAsDecimalPlace});

  final bool useCommaAsDecimalPlace;

  @override
  State<_IncreasePricesDialog> createState() => _IncreasePricesDialogState();
}

class _IncreasePricesDialogState extends State<_IncreasePricesDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // A 0 / empty value is a no-op increase, and the input formatter blocks a
  // leading `-`, so a positive number is the only meaningful input. The server
  // caps the percentage at 100 (BulkRecurringInvoiceRequest: `max:100`), so we
  // enforce the same ceiling here — otherwise each selected invoice's mutation
  // 422s and goes dead in the outbox with only a generic "could not save".
  static const _maxPercent = 100;

  double? get _parsed => parseDouble(
    _controller.text.trim(),
    useCommaAsDecimalPlace: widget.useCommaAsDecimalPlace,
    zeroIsNull: true,
  );

  bool get _valid {
    final n = _parsed;
    return n != null && n > 0 && n <= _maxPercent;
  }

  void _submit() {
    final n = _parsed;
    if (n == null || n <= 0 || n > _maxPercent) return;
    // Send a canonical dot-decimal string regardless of locale — the API
    // parses it with `num.tryParse`.
    Navigator.of(context).pop(n.toString());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('increase_prices')),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: _controller,
          autofocus: true,
          // NOT signed: the formatter below blocks `-` and `_valid` requires
          // n > 0 (the server caps at max:100), so a minus key would be
          // swallowed while costing every user the large iOS decimal pad.
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: context.tr('percentage_increase'),
            suffixText: '%',
          ),
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
              label: context.tr('done'),
              onPressed: _submit,
              enabled: _valid,
              autofocus: false,
            ),
          ],
        ),
      ],
    );
  }
}
