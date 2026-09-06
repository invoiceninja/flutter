import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_column_config.dart';
import 'package:admin/utils/formatting.dart';

/// Modal editor for a single line item. The mobile card list opens this
/// for every tap; the desktop table can also open it when the user wants
/// the full field set. Returns the edited [LineItem] or null on cancel.
///
/// All fields surface conditionally based on [config] — minimal config
/// shows only product key / notes / cost / quantity. The full surface
/// (3 taxes × name+rate + 4 customs + discount) appears when the company
/// settings enable them.
Future<LineItem?> showLineItemEditDialog(
  BuildContext context, {
  required LineItem initial,
  required LineItemColumnConfig config,
  bool useComma = false,
}) {
  return showDialog<LineItem>(
    context: context,
    builder: (_) => _LineItemEditDialog(
      initial: initial,
      config: config,
      useComma: useComma,
    ),
  );
}

class _LineItemEditDialog extends StatefulWidget {
  const _LineItemEditDialog({
    required this.initial,
    required this.config,
    required this.useComma,
  });

  final LineItem initial;
  final LineItemColumnConfig config;
  final bool useComma;

  @override
  State<_LineItemEditDialog> createState() => _LineItemEditDialogState();
}

class _LineItemEditDialogState extends State<_LineItemEditDialog> {
  late LineItem _draft;
  late final TextEditingController _productKey;
  late final TextEditingController _notes;
  late final TextEditingController _cost;
  late final TextEditingController _quantity;
  late final TextEditingController _discount;
  late final TextEditingController _custom1;
  late final TextEditingController _custom2;
  late final TextEditingController _custom3;
  late final TextEditingController _custom4;
  late final TextEditingController _taxName1;
  late final TextEditingController _taxRate1;
  late final TextEditingController _taxName2;
  late final TextEditingController _taxRate2;
  late final TextEditingController _taxName3;
  late final TextEditingController _taxRate3;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
    _productKey = TextEditingController(text: _draft.productKey);
    _notes = TextEditingController(text: _draft.notes);
    _cost = TextEditingController(text: _decimalText(_draft.cost));
    _quantity = TextEditingController(text: _decimalText(_draft.quantity));
    _discount = TextEditingController(text: _decimalText(_draft.discount));
    _custom1 = TextEditingController(text: _draft.customValue1);
    _custom2 = TextEditingController(text: _draft.customValue2);
    _custom3 = TextEditingController(text: _draft.customValue3);
    _custom4 = TextEditingController(text: _draft.customValue4);
    _taxName1 = TextEditingController(text: _draft.taxName1);
    _taxRate1 = TextEditingController(text: _decimalText(_draft.taxRate1));
    _taxName2 = TextEditingController(text: _draft.taxName2);
    _taxRate2 = TextEditingController(text: _decimalText(_draft.taxRate2));
    _taxName3 = TextEditingController(text: _draft.taxName3);
    _taxRate3 = TextEditingController(text: _decimalText(_draft.taxRate3));
  }

  @override
  void dispose() {
    _productKey.dispose();
    _notes.dispose();
    _cost.dispose();
    _quantity.dispose();
    _discount.dispose();
    _custom1.dispose();
    _custom2.dispose();
    _custom3.dispose();
    _custom4.dispose();
    _taxName1.dispose();
    _taxRate1.dispose();
    _taxName2.dispose();
    _taxRate2.dispose();
    _taxName3.dispose();
    _taxRate3.dispose();
    super.dispose();
  }

  String _decimalText(Decimal v) => v == Decimal.zero ? '' : v.toString();

  Decimal _parseOrZero(TextEditingController c) =>
      parseDecimal(c.text, useCommaAsDecimalPlace: widget.useComma) ??
      Decimal.zero;

  LineItem _build() => _draft.copyWith(
    productKey: _productKey.text.trim(),
    notes: _notes.text,
    cost: _parseOrZero(_cost),
    quantity:
        parseDecimal(_quantity.text, useCommaAsDecimalPlace: widget.useComma) ??
        Decimal.one,
    discount: _parseOrZero(_discount),
    customValue1: _custom1.text,
    customValue2: _custom2.text,
    customValue3: _custom3.text,
    customValue4: _custom4.text,
    taxName1: _taxName1.text,
    taxRate1: _parseOrZero(_taxRate1),
    taxName2: _taxName2.text,
    taxRate2: _parseOrZero(_taxRate2),
    taxName3: _taxName3.text,
    taxRate3: _parseOrZero(_taxRate3),
  );

  void _save() => Navigator.of(context).pop(_build());

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    // Field labels resolve the company's Custom Labels before the bundled
    // string, matching the desktop table header.
    String label(String key) => config.labels.resolve(context, key);
    return AlertDialog(
      title: Text(context.tr('line_item')),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _productKey,
                decoration: InputDecoration(labelText: label('product')),
                textInputAction: TextInputAction.next,
                autofocus: true,
              ),
              SizedBox(height: InSpacing.md(context)),
              TextField(
                controller: _notes,
                decoration: InputDecoration(labelText: label('description')),
                maxLines: 3,
                minLines: 2,
              ),
              SizedBox(height: InSpacing.md(context)),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cost,
                      decoration: InputDecoration(
                        labelText: label('unit_cost'),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),
                  SizedBox(width: InSpacing.md(context)),
                  Expanded(
                    child: TextField(
                      controller: _quantity,
                      decoration: InputDecoration(labelText: label('quantity')),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),
                ],
              ),
              if (config.showDiscount) ...[
                SizedBox(height: InSpacing.md(context)),
                TextField(
                  controller: _discount,
                  decoration: InputDecoration(labelText: label('discount')),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                ),
              ],
              if (config.taxColumnCount >= 1) ...[
                SizedBox(height: InSpacing.md(context)),
                _TaxRow(name: _taxName1, rate: _taxRate1, index: 1),
              ],
              if (config.taxColumnCount >= 2) ...[
                SizedBox(height: InSpacing.md(context)),
                _TaxRow(name: _taxName2, rate: _taxRate2, index: 2),
              ],
              if (config.taxColumnCount >= 3) ...[
                SizedBox(height: InSpacing.md(context)),
                _TaxRow(name: _taxName3, rate: _taxRate3, index: 3),
              ],
              if (config.showCustom1) ...[
                SizedBox(height: InSpacing.md(context)),
                TextField(
                  controller: _custom1,
                  decoration: InputDecoration(
                    labelText: context.tr('custom_value1'),
                  ),
                ),
              ],
              if (config.showCustom2) ...[
                SizedBox(height: InSpacing.md(context)),
                TextField(
                  controller: _custom2,
                  decoration: InputDecoration(
                    labelText: context.tr('custom_value2'),
                  ),
                ),
              ],
              if (config.showCustom3) ...[
                SizedBox(height: InSpacing.md(context)),
                TextField(
                  controller: _custom3,
                  decoration: InputDecoration(
                    labelText: context.tr('custom_value3'),
                  ),
                ),
              ],
              if (config.showCustom4) ...[
                SizedBox(height: InSpacing.md(context)),
                TextField(
                  controller: _custom4,
                  decoration: InputDecoration(
                    labelText: context.tr('custom_value4'),
                  ),
                ),
              ],
            ],
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
              label: context.tr('save'),
              onPressed: _save,
              // Multi-field editor: Enter advances fields, it doesn't submit —
              // so no Enter hint.
              autofocus: false,
              showEnterHint: false,
            ),
          ],
        ),
      ],
    );
  }
}

class _TaxRow extends StatelessWidget {
  const _TaxRow({required this.name, required this.rate, required this.index});

  final TextEditingController name;
  final TextEditingController rate;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: name,
            decoration: InputDecoration(
              labelText: '${context.tr('tax_name')} $index',
            ),
          ),
        ),
        SizedBox(width: InSpacing.md(context)),
        Expanded(
          flex: 2,
          child: TextField(
            controller: rate,
            decoration: InputDecoration(
              labelText: '${context.tr('tax_rate')} $index',
              suffixText: '%',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
      ],
    );
  }
}
