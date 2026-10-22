import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:admin/ui/core/utils/field_text_direction.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/widgets/overridable_field.dart';
import 'package:admin/ui/features/settings/widgets/settings_field_bindings.dart';
import 'package:admin/utils/formatting.dart';

/// Numeric counterpart of [OverridableTextField]. The settings cascade
/// stores everything as `String?`, so this widget round-trips
/// `parseDecimal` (per CLAUDE.md § Forms — "money is Decimal, never
/// double") and renders empty for zero (no leading `"0"` placeholder).
///
/// `integerOnly: true` switches the parser to `int.tryParse` and clamps
/// the keyboard to digits.
class OverridableNumberField extends StatefulWidget {
  const OverridableNumberField({
    super.key,
    required this.label,
    required this.apiKey,
    this.read,
    this.write,
    this.enabled = true,
    this.integerOnly = false,
  });

  final String label;
  final String apiKey;
  final SettingsRead? read;
  final SettingsWrite? write;
  final bool enabled;
  final bool integerOnly;

  @override
  State<OverridableNumberField> createState() => _OverridableNumberFieldState();
}

class _OverridableNumberFieldState extends State<OverridableNumberField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final SettingsRead _read;
  late final SettingsWrite _write;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    final binding = settingsBindingOf(widget.apiKey);
    _read = widget.read ?? binding.read;
    _write = widget.write ?? binding.write;
    final host = context.read<SettingsDraftHost>();
    _controller = TextEditingController(
      text: _displayFor(_read(host.settings), useComma: _useComma(host)),
    );
    // Owned FocusNode + listener so the displayed text isn't reformatted
    // mid-keystroke. Without it, every keystroke notifies the host → rebuild →
    // the controller is overwritten with the canonical value, which swallows a
    // just-typed decimal separator (`parseDecimal('75.')` canonicalises to
    // `75`, so typing `75.5` would land as `755`). Mirrors
    // OverridableCurrencyField; the integer path was unaffected but is included
    // for one consistent code path.
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    final focused = _focusNode.hasFocus;
    if (focused == _hasFocus) return;
    setState(() => _hasFocus = focused);
  }

  /// The company-global decimal-separator choice. `use_comma_as_decimal_place`
  /// is a TOP-LEVEL company field (not a cascade setting). Read it via
  /// `companyContext`, not `draft`: at company scope `companyContext == draft`
  /// (base getter), but at client/group scope `draft` is null while
  /// `companyContext` carries the loaded company's flag. Reading `draft` here
  /// forced `false` (dot) at client/group scope, corrupting comma-locale money
  /// input via `parseDecimal` (`10,50` → `1050`). Mirrors `TaxRatePicker`.
  bool _useComma(SettingsDraftHost host) =>
      host.companyContext?.useCommaAsDecimalPlace ?? false;

  /// Empty-for-zero, no scientific notation. Mirrors `Formatter.inputAmount`
  /// without taking a dependency on the currency map.
  String _displayFor(String? raw, {required bool useComma}) {
    if (raw == null || raw.isEmpty) return '';
    // While focused, show the raw editable string so reformatting doesn't fight
    // the caret or swallow a just-typed separator. Blurred, fall through to the
    // canonical display.
    if (_hasFocus) return raw;
    if (widget.integerOnly) {
      final n = int.tryParse(raw.trim());
      return n == null || n == 0 ? '' : n.toString();
    }
    final d = parseDecimal(raw, useCommaAsDecimalPlace: useComma);
    if (d == null || d == Decimal.zero) return '';
    // Render the company's decimal separator so comma-locale users see
    // `75,5` not `75.5`. `parseDecimal` already accepts both on input and
    // `onChanged` re-canonicalises to a dot for the wire, so this is
    // display-only. `Decimal.toString()` emits at most one `.` (no grouping).
    return useComma ? d.toString().replaceAll('.', ',') : d.toString();
  }

  @override
  Widget build(BuildContext context) {
    final host = context.watch<SettingsDraftHost>();
    final useComma = _useComma(host);
    final hostValue = _displayFor(_read(host.settings), useComma: useComma);
    if (!_hasFocus && _controller.text != hostValue) {
      _controller.value = TextEditingValue(
        text: hostValue,
        selection: TextSelection.collapsed(offset: hostValue.length),
      );
    }

    final scope = FormSaveScope.maybeOf(context);
    final errors = host.fieldErrors[widget.apiKey];
    final errorText = (errors != null && errors.isNotEmpty)
        ? errors.first
        : null;
    final field = TextField(
      controller: _controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      textDirection: TextDirection.ltr,
      textAlign: ltrValueAlign(context, ltr: true),
      keyboardType: widget.integerOnly
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: widget.integerOnly
          ? <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly]
          : null,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: errorText,
      ),
      onChanged: (v) {
        // integerOnly: empty/unparseable input clears the field (the int
        // binding's `int.tryParse('')` → null on save). Decimal: `parseDecimal`
        // returns `Decimal.zero` for empty input, so it persists as "0" — these
        // numeric settings treat 0 and absent alike. Decimal input is
        // canonicalized so the wire stays locale-agnostic (the server expects
        // `1.5`, never `1,5`).
        if (widget.integerOnly) {
          host.updateSettings((s) => _write(s, v));
        } else {
          final parsed = parseDecimal(v, useCommaAsDecimalPlace: useComma);
          host.updateSettings((s) => _write(s, parsed?.toString() ?? ''));
        }
      },
      onSubmitted: scope == null ? null : (_) => scope.trySubmit(),
    );
    return OverridableField.bind(
      apiKey: widget.apiKey,
      label: widget.label,
      // Seed the override from the RAW cascaded value, not the zero-blanked
      // display: a 0 company-default must seed "0"/"0.0" (→ parses back to 0,
      // which latches the override) rather than "" (→ null, leaving the
      // checkbox unable to latch — isOverridden is `containsKey && != null`).
      // The displayed text still blanks zero via _displayFor in build().
      cascadedValueOnEnable: () => _read(host.settings),
      child: field,
    );
  }
}
