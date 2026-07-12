import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/api/tax_config_api_model.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/utils/formatting.dart';

/// Edit a single [TaxSubregionApi] entry from Settings → Tax Settings →
/// Calculate Taxes. Mirrors React `EditSubRegionModal.tsx` — four typed
/// inputs (name, rate, reduced rate, VAT number) with Cancel + Save
/// side-by-side per the design system rule for action button pairs.
class SubregionEditDialog extends StatefulWidget {
  const SubregionEditDialog({
    super.key,
    required this.subregionKey,
    required this.initial,
    this.useComma = false,
    this.fieldErrors,
  });

  /// Subregion identifier (state code / country ISO) — shown in the title.
  final String subregionKey;

  /// Current values; closed dialog returns the new subregion via the
  /// `Navigator.pop` result.
  final TaxSubregionApi initial;

  /// The company's `use_comma_as_decimal_place` setting — drives both the
  /// seeded display and the parse of the rate fields so comma-locale users
  /// can type `19,5` without it becoming `195`.
  final bool useComma;

  /// Server validation errors for this subregion, pre-stripped of the
  /// `tax_data.regions.<R>.subregions.<S>.` prefix — keys are bare field
  /// names (`tax_name`, `tax_rate`, `reduced_tax_rate`, `vat_number`).
  /// Surfaced under each matching `TextField`'s `errorText`. Null or empty
  /// when the user has not yet hit a 422.
  final Map<String, List<String>>? fieldErrors;

  /// Open the dialog and return the edited subregion. `null` on cancel.
  static Future<TaxSubregionApi?> show(
    BuildContext context, {
    required String subregionKey,
    required TaxSubregionApi initial,
    bool useComma = false,
    Map<String, List<String>>? fieldErrors,
  }) {
    return showDialog<TaxSubregionApi>(
      context: context,
      builder: (_) => SubregionEditDialog(
        subregionKey: subregionKey,
        initial: initial,
        useComma: useComma,
        fieldErrors: fieldErrors,
      ),
    );
  }

  @override
  State<SubregionEditDialog> createState() => _SubregionEditDialogState();
}

class _SubregionEditDialogState extends State<SubregionEditDialog> {
  late final TextEditingController _name;
  late final TextEditingController _rate;
  late final TextEditingController _reducedRate;
  late final TextEditingController _vatNumber;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial.taxName);
    _rate = TextEditingController(
      text: rateInputText(
        widget.initial.taxRate,
        useCommaAsDecimalPlace: widget.useComma,
      ),
    );
    _reducedRate = TextEditingController(
      text: rateInputText(
        widget.initial.reducedTaxRate,
        useCommaAsDecimalPlace: widget.useComma,
      ),
    );
    _vatNumber = TextEditingController(text: widget.initial.vatNumber);
  }

  @override
  void dispose() {
    _name.dispose();
    _rate.dispose();
    _reducedRate.dispose();
    _vatNumber.dispose();
    super.dispose();
  }

  void _submit() {
    final next = widget.initial.copyWith(
      taxName: _name.text.trim(),
      taxRate:
          parseDouble(_rate.text, useCommaAsDecimalPlace: widget.useComma) ?? 0,
      reducedTaxRate:
          parseDouble(
            _reducedRate.text,
            useCommaAsDecimalPlace: widget.useComma,
          ) ??
          0,
      vatNumber: _vatNumber.text.trim(),
    );
    Navigator.of(context).pop(next);
  }

  String? _errorFor(String key) {
    final entry = widget.fieldErrors?[key];
    if (entry == null || entry.isEmpty) return null;
    return entry.first;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${context.tr('edit')} — ${widget.subregionKey}'),
      // Cap the width so the four fields read as a tidy column on desktop, but
      // never force an intrinsic width that could overflow a narrow phone or
      // jump when a server `errorText` appears. (An earlier `IntrinsicWidth`
      // here sized the dialog to the widest label and grew on validation
      // errors.) Mirrors `add_to_invoice_dialog.dart`.
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: FormSaveScope(
          onSubmit: _submit,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: context.tr('tax_name'),
                  errorText: _errorFor('tax_name'),
                ),
                textInputAction: TextInputAction.next,
              ),
              SizedBox(height: InSpacing.md(context)),
              TextField(
                controller: _rate,
                decoration: InputDecoration(
                  labelText: context.tr('tax_rate'),
                  errorText: _errorFor('tax_rate'),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
              ),
              SizedBox(height: InSpacing.md(context)),
              TextField(
                controller: _reducedRate,
                decoration: InputDecoration(
                  labelText: context.tr('reduced_rate'),
                  errorText: _errorFor('reduced_tax_rate'),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
              ),
              SizedBox(height: InSpacing.md(context)),
              TextField(
                controller: _vatNumber,
                decoration: InputDecoration(
                  labelText: context.tr('vat_number'),
                  errorText: _errorFor('vat_number'),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
      ),
      // Cancel + Save side-by-side per § Design system v2. Per-call
      // minimumSize overrides keep them on one row inside
      // `AlertDialog.actions` (the global FilledButton theme defaults to
      // `Size.fromHeight(44)` — i.e. infinite width — which is right for
      // stacked form buttons but wrong here). Spacing is handled by the
      // `AlertDialog`'s internal `OverflowBar`; a manual `SizedBox`
      // between the children is ignored by `OverflowBar`'s layout.
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('cancel')),
        ),
        PrimaryDialogAction(
          label: context.tr('save'),
          autofocus: false,
          onPressed: _submit,
        ),
      ],
    );
  }
}
