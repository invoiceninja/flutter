import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/ui/core/utils/field_text_direction.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/widgets/overridable_field.dart';
import 'package:admin/ui/features/settings/widgets/settings_field_bindings.dart';
import 'package:admin/utils/formatting.dart';

/// Money-input counterpart of [OverridableNumberField]. Same wire shape
/// (string-encoded `Decimal`), but the input parses through
/// [parseDecimal] honoring the user's `useCommaAsDecimalPlace`
/// preference, and the display goes through [Formatter.inputMoney] so the
/// caller's [currencyId] determines the precision and the empty-for-zero
/// rule (CLAUDE.md § Forms — money never renders as `"0"`).
class OverridableCurrencyField extends StatefulWidget {
  const OverridableCurrencyField({
    super.key,
    required this.label,
    required this.apiKey,
    required this.formatter,
    required this.currencyId,
    this.read,
    this.write,
    this.enabled = true,
  });

  final String label;
  final String apiKey;

  /// User's company-scoped [Formatter]. Pass `services.formatterFor(companyId)`.
  final Formatter formatter;

  /// Currency to format under. Falls back to the company currency when
  /// empty.
  final String currencyId;
  final SettingsRead? read;
  final SettingsWrite? write;
  final bool enabled;

  @override
  State<OverridableCurrencyField> createState() =>
      _OverridableCurrencyFieldState();
}

class _OverridableCurrencyFieldState extends State<OverridableCurrencyField> {
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
      text: _formattedFor(_read(host.settings)),
    );
    // Owned FocusNode + listener pattern (mirrors login_screen's
    // `_PasswordField`). Avoids the `Focus(onFocusChange: setState)`
    // wrapper that can fire mid-build during programmatic focus moves.
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

  /// While focused, show the raw editable string (so the caret + commas
  /// don't fight the user); blurred, fall back to the formatted display.
  String _formattedFor(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    if (_hasFocus) return raw;
    final parsed = parseDecimal(raw);
    if (parsed == null) return raw;
    return widget.formatter.inputMoney(parsed, currencyId: widget.currencyId);
  }

  @override
  Widget build(BuildContext context) {
    final host = context.watch<SettingsDraftHost>();
    final hostValue = _formattedFor(_read(host.settings));
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
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textDirection: TextDirection.ltr,
      textAlign: ltrValueAlign(context, ltr: true),
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: errorText,
      ),
      onChanged: (v) {
        // Store the parsed canonical Decimal string so the wire stays
        // locale-agnostic. parseDecimal returning null becomes empty.
        final parsed = parseDecimal(
          v,
          useCommaAsDecimalPlace:
              widget.formatter.settings.useCommaAsDecimalPlace,
        );
        host.updateSettings((s) => _write(s, parsed?.toString() ?? ''));
      },
      onSubmitted: scope == null ? null : (_) => scope.trySubmit(),
    );
    return OverridableField.bind(
      apiKey: widget.apiKey,
      label: widget.label,
      // Raw wire value — `setOverride` expects the canonical Decimal
      // string, not the locale-formatted display. Routing through the
      // formatter here would re-parse the formatted result on the next
      // save and risk locale drift.
      cascadedValueOnEnable: () => _read(host.settings) ?? '',
      child: field,
    );
  }
}
