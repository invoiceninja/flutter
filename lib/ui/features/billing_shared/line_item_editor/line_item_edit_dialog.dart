import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/billing/line_item_custom_fields.dart';
import 'package:admin/data/models/domain/billing/line_item_type.dart';
import 'package:admin/data/models/domain/tax_rate.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/custom_field_input.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/core/widgets/spell_check.dart';
import 'package:admin/ui/features/billing_shared/edit/tax_rate_tier_picker.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_column_config.dart';
import 'package:admin/utils/formatting.dart';

/// Modal editor for a single line item. The mobile card list opens this
/// for every tap AND for `Add Item`; the desktop table can also open it when
/// the user wants the full field set. Returns the edited [LineItem] or null on
/// cancel.
///
/// All fields surface conditionally based on [config] — minimal config
/// shows only product key / notes / cost / quantity. The full surface
/// (3 taxes × name+rate + 4 customs + discount) appears when the company
/// settings enable them.
///
/// The custom fields sit after Cost / Quantity, not after Description where
/// the desktop table puts its columns: a phone with the keyboard up shows
/// roughly 250 px of this dialog, and four custom fields above Quantity — the
/// field people come here to change — would push it out of view. Their values
/// usually arrive from the picked product anyway. Each is rendered by type
/// through the shared [CustomFieldInput]; [formatter] dates a date-typed one.
///
/// [titleKey] / [actionKey] let a caller name the verb it is serving. They
/// default to the edit wording, and the *create* caller passes `add_line` /
/// `add`: since invoiceninja/flutter#142 the phone opens this dialog BEFORE
/// the row exists, so "Save" on a record the user has never seen — and a
/// Cancel that silently adds nothing — would both be lying about what the
/// buttons do.
///
/// [taxRates] is the company's configured tax rates
/// (`TaxRateRepository.watchAll`). With rates, each tax tier is a
/// [TaxRateTierPicker], as the desktop table's tax cells and the document's
/// Taxes card are; without any, or with no stream, it stays a freeform name +
/// rate pair. The phone was the one surface left typing a saved rate by hand
/// (beta feedback: "NYS Sales Tax 8.75%" was nowhere to be picked).
///
/// [autofocusProduct] is for that create caller too: a new line starts at its
/// Product, but tapping an existing card is usually about some other field,
/// and an autofocused Product raises the keyboard over the very fields the
/// user came to change.
Future<LineItem?> showLineItemEditDialog(
  BuildContext context, {
  required LineItem initial,
  required LineItemColumnConfig config,
  bool useComma = false,
  Formatter? formatter,
  String titleKey = 'line_item',
  String actionKey = 'save',
  bool autofocusProduct = false,
  Stream<List<TaxRate>>? taxRates,
}) {
  return showDialog<LineItem>(
    context: context,
    builder: (_) => _LineItemEditDialog(
      initial: initial,
      config: config,
      useComma: useComma,
      formatter: formatter,
      titleKey: titleKey,
      actionKey: actionKey,
      autofocusProduct: autofocusProduct,
      taxRates: taxRates,
    ),
  );
}

class _LineItemEditDialog extends StatefulWidget {
  const _LineItemEditDialog({
    required this.initial,
    required this.config,
    required this.useComma,
    required this.formatter,
    required this.titleKey,
    required this.actionKey,
    required this.autofocusProduct,
    required this.taxRates,
  });

  final LineItem initial;
  final LineItemColumnConfig config;
  final bool useComma;
  final Formatter? formatter;
  final String titleKey;
  final String actionKey;
  final bool autofocusProduct;
  final Stream<List<TaxRate>>? taxRates;

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

  /// [_draft] already carries the custom values — each field writes its slot
  /// straight into it — so they are not rebuilt here, and a slot the company
  /// has no field for keeps whatever value it arrived with.
  LineItem _build() => _draft.copyWith(
    productKey: _productKey.text.trim(),
    notes: _notes.text,
    cost: _parseOrZero(_cost),
    // An hourly line's Hours field also takes a duration (`1:30`, `90m`); a
    // colon it can't read keeps the hours the line already had.
    quantity: _draft.typeId == LineItemType.task
        ? parseHoursInput(
                _quantity.text,
                useCommaAsDecimalPlace: widget.useComma,
              ) ??
              _draft.quantity
        : parseDecimal(
                _quantity.text,
                useCommaAsDecimalPlace: widget.useComma,
              ) ??
              Decimal.one,
    discount: _parseOrZero(_discount),
    taxName1: _taxName1.text,
    taxRate1: _parseOrZero(_taxRate1),
    taxName2: _taxName2.text,
    taxRate2: _parseOrZero(_taxRate2),
    taxName3: _taxName3.text,
    taxRate3: _parseOrZero(_taxRate3),
  );

  /// Commits a typed-but-unblurred field before reading the draft, as
  /// `EntityEditScaffold._runSave` does. A date-typed custom field commits
  /// only on blur or Enter, and on iOS / Android a tap on Save never takes
  /// focus from a text field (`_EditableTextTapOutsideAction` unfocuses only
  /// for a mouse, or on the web) — so the date the user just typed was dropped.
  /// Focus changes apply on a microtask, hence the yield.
  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    Navigator.of(context).pop(_build());
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    // After `labelKey`, so an hourly line reads Service / Rate / Hours — and
    // `context.tr` puts a company's Custom Label for that word first.
    String label(String key) => context.tr(config.labelKey(key));
    return AlertDialog(
      title: Text(context.tr(widget.titleKey)),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LineItemSpellCheck(
                builder: (context, config) => TextField(
                  controller: _productKey,
                  decoration: InputDecoration(labelText: label('product')),
                  textInputAction: TextInputAction.next,
                  autofocus: widget.autofocusProduct,
                  spellCheckConfiguration: config,
                  contextMenuBuilder: spellCheckContextMenuBuilder,
                ),
              ),
              SizedBox(height: InSpacing.md(context)),
              LineItemSpellCheck(
                builder: (context, config) => TextField(
                  controller: _notes,
                  decoration: InputDecoration(labelText: label('description')),
                  // Grows with the text up to eight lines, then scrolls — three
                  // left a paragraph mostly out of sight while typing it.
                  maxLines: 8,
                  minLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  spellCheckConfiguration: config,
                  contextMenuBuilder: spellCheckContextMenuBuilder,
                ),
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
              for (final custom in config.customFields) ...[
                SizedBox(height: InSpacing.md(context)),
                CustomFieldInput(
                  key: ValueKey('custom_${custom.slot}'),
                  field: custom.field,
                  value: lineItemCustomValue(_draft, custom.slot),
                  formatter: widget.formatter,
                  onChanged: (v) => setState(
                    () => _draft = withLineItemCustomValue(
                      _draft,
                      custom.slot,
                      v,
                    ),
                  ),
                ),
              ],
              if (config.taxColumnCount >= 1)
                StreamBuilder<List<TaxRate>>(
                  stream: widget.taxRates,
                  builder: (context, snap) {
                    final rates = snap.data ?? const <TaxRate>[];
                    // Freeform only on an ANSWERED empty list (or no stream):
                    // until the rates answer, the picker's placeholder stands
                    // in, so the pair never flashes up and away again.
                    final freeform =
                        widget.taxRates == null ||
                        (snap.hasData && rates.isEmpty);
                    final tiers = [
                      (_taxName1, _taxRate1),
                      (_taxName2, _taxRate2),
                      (_taxName3, _taxRate3),
                    ];
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (
                          var i = 0;
                          i < config.taxColumnCount && i < 3;
                          i++
                        ) ...[
                          SizedBox(height: InSpacing.md(context)),
                          if (freeform)
                            _TaxRow(
                              name: tiers[i].$1,
                              rate: tiers[i].$2,
                              index: i + 1,
                            )
                          else
                            TaxRateTierPicker(
                              label: '${context.tr('tax_rate')} ${i + 1}',
                              name: tiers[i].$1.text,
                              rate: _parseOrZero(tiers[i].$2),
                              rates: rates,
                              useCommaAsDecimalPlace: widget.useComma,
                              // The controllers stay the dialog's one store
                              // for the pair, so `_build` reads a pick the
                              // same way it reads a typed tax.
                              onChanged: (name, rate) => setState(() {
                                tiers[i].$1.text = name;
                                tiers[i].$2.text = _decimalText(rate);
                              }),
                            ),
                        ],
                      ],
                    );
                  },
                ),
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
              label: context.tr(widget.actionKey),
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
