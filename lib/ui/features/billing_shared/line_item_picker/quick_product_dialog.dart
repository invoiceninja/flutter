import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/product.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/utils/formatting.dart';

/// The few fields a product needs to be added to a document straight from the
/// Add-items picker (invoiceninja/ui#3384): its key — prefilled with what the
/// user searched for — a price and a description. Anything more belongs on
/// the product screen. Returns the draft to create, or null on cancel.
///
/// A key-only create (what the desktop line-item cell does) would land a $0
/// line on the document and a priceless entry in the catalog, which is why
/// this asks for the price up front.
Future<Product?> showQuickProductDialog(
  BuildContext context, {
  required String initialKey,
  bool useCommaAsDecimalPlace = false,
}) => showDialog<Product>(
  context: context,
  builder: (_) => _QuickProductDialog(
    initialKey: initialKey,
    useCommaAsDecimalPlace: useCommaAsDecimalPlace,
  ),
);

class _QuickProductDialog extends StatefulWidget {
  const _QuickProductDialog({
    required this.initialKey,
    required this.useCommaAsDecimalPlace,
  });

  final String initialKey;
  final bool useCommaAsDecimalPlace;

  @override
  State<_QuickProductDialog> createState() => _QuickProductDialogState();
}

class _QuickProductDialogState extends State<_QuickProductDialog> {
  late final TextEditingController _key = TextEditingController(
    text: widget.initialKey,
  );
  final TextEditingController _price = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  bool get _canSave => _key.text.trim().isNotEmpty;

  @override
  void dispose() {
    _key.dispose();
    _price.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canSave) return;
    final price =
        parseDecimal(
          _price.text,
          useCommaAsDecimalPlace: widget.useCommaAsDecimalPlace,
        ) ??
        emptyProductWithKey('').price;
    Navigator.of(context).pop(
      emptyProductWithKey(
        _key.text.trim(),
      ).copyWith(price: price, notes: _notes.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FormSaveScope(
      onSubmit: _submit,
      enabled: _canSave,
      child: AlertDialog(
        title: Text(context.tr('new_product')),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _key,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: context.tr('item')),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _price,
                // The price field's own focus: the key is usually right
                // already — it is what the user just searched for.
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(labelText: context.tr('price')),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: context.tr('description'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('cancel')),
          ),
          PrimaryDialogAction(
            label: context.tr('save'),
            autofocus: false,
            enabled: _canSave,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
