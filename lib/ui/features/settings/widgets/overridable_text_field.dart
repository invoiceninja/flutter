import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/widgets/overridable_field.dart';
import 'package:admin/ui/features/settings/widgets/settings_field_bindings.dart';

/// Standard "labeled text field bound to one settings key" used across the
/// Company Details tabs. Handles the [OverridableField] wrapper at
/// group/client level transparently.
///
/// `apiKey` is the snake_case server field name. By default the field looks
/// up its `read`/`write` projection from [settingsBindingOf]; pass explicit
/// closures only when binding to something outside `vm.settings` that still
/// has the same `String?` shape (rare — most non-settings fields are wired
/// directly on the views).
class OverridableTextField extends StatefulWidget {
  const OverridableTextField({
    super.key,
    required this.label,
    required this.apiKey,
    this.read,
    this.write,
    this.enabled = true,
    this.maxLines = 1,
    this.keyboardType,
    this.style,
    this.hintText,
    this.helperText,
    this.obscureToggle = false,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.autocorrect = true,
  });

  final String label;
  final String apiKey;
  final SettingsRead? read;
  final SettingsWrite? write;
  final bool enabled;
  final int maxLines;
  final TextInputType? keyboardType;

  /// Optional TextField.style override. Used by Client Portal → Customize to
  /// render Header / Footer / Custom CSS / Custom JS in a monospace face so
  /// HTML / CSS / JavaScript content is visually distinguishable from prose.
  final TextStyle? style;

  /// Optional placeholder when the field is empty — used to signal expected
  /// content shape (e.g. `<!-- HTML allowed -->`, `/* CSS */`).
  final String? hintText;

  /// Optional helper text shown beneath the field. Email Settings uses this
  /// for the comma-separated-list / region / endpoint hints.
  final String? helperText;

  /// When true, the field is initially obscured and a trailing eye icon
  /// toggles visibility. Used by SMTP password, postmark/mailgun/brevo/SES
  /// secret fields on Email Settings.
  final bool obscureToggle;

  /// Soft-keyboard auto-capitalization. `words` for proper nouns (names,
  /// cities, streets), `characters` for postal codes. Defaults to Flutter's
  /// own `none`, so passing nothing changes nothing.
  final TextCapitalization textCapitalization;

  /// OS autofill hints. **Only ever set these on a field describing the
  /// signed-in user or their own company** — never on a client / vendor /
  /// contact record, where the platform would offer the *admin's* own name,
  /// phone and address. Flutter gates on null vs non-null, so an empty list
  /// does NOT opt out (see `auth_fields.dart`).
  final Iterable<String>? autofillHints;

  /// Set false on identifier-shaped values iOS would happily "correct" —
  /// VAT / registration numbers, hostnames, API keys. Also drives
  /// `enableSuggestions`, which travels with it.
  final bool autocorrect;

  @override
  State<OverridableTextField> createState() => _OverridableTextFieldState();
}

class _OverridableTextFieldState extends State<OverridableTextField> {
  late final TextEditingController _controller;
  late final SettingsRead _read;
  late final SettingsWrite _write;
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    final binding = settingsBindingOf(widget.apiKey);
    _read = widget.read ?? binding.read;
    _write = widget.write ?? binding.write;
    _obscured = widget.obscureToggle;
    final host = context.read<SettingsDraftHost>();
    _controller = TextEditingController(text: _read(host.settings) ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // `watch` so this widget rebuilds when the host mutates the field
    // externally (override-checkbox toggle, programmatic resets). Without it
    // the disabled state and inherited-placeholder text never update.
    final host = context.watch<SettingsDraftHost>();

    // Keep the controller in sync with host-side mutations. If the controller
    // text already matches the host (user just typed), this is a no-op; if
    // the host was updated by something else (override toggle), this pulls
    // the new value in and parks the cursor at the end.
    final hostValue = _read(host.settings) ?? '';
    if (_controller.text != hostValue) {
      _controller.value = TextEditingValue(
        text: hostValue,
        selection: TextSelection.collapsed(offset: hostValue.length),
      );
    }

    // Enter on a single-line field submits the surrounding form via
    // FormSaveScope. Multi-line fields keep Enter for newlines.
    final isSingleLine = widget.maxLines == 1;
    final scope = isSingleLine ? FormSaveScope.maybeOf(context) : null;
    final errors = host.fieldErrors[widget.apiKey];
    final errorText = (errors != null && errors.isNotEmpty)
        ? errors.first
        : null;
    final field = TextField(
      controller: _controller,
      enabled: widget.enabled,
      maxLines: _obscured ? 1 : widget.maxLines,
      obscureText: _obscured,
      keyboardType: widget.keyboardType,
      textCapitalization: widget.textCapitalization,
      autofillHints: widget.autofillHints,
      // One knob, not two — the pairing `AuthField` already uses. A field
      // declared obscurable never wants either, revealed or not: the four
      // Email Settings service secrets declare `obscureToggle` and a
      // visiblePassword keyboard but no `autocorrect: false`, so keying this
      // on `_obscured` handed the IME a revealed API credential.
      autocorrect: widget.autocorrect && !widget.obscureToggle,
      enableSuggestions: widget.autocorrect && !widget.obscureToggle,
      style: widget.style,
      textInputAction: isSingleLine
          ? TextInputAction.done
          : TextInputAction.newline,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hintText,
        helperText: widget.helperText,
        errorText: errorText,
        suffixIcon: widget.obscureToggle
            ? IconButton(
                icon: Icon(
                  _obscured
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscured = !_obscured),
                tooltip: context.tr(_obscured ? 'show' : 'hide'),
              )
            : null,
      ),
      onChanged: (v) {
        // At group/client (cascade) scope, clearing the text removes the
        // override (write null) rather than persisting '' — the server treats a
        // zero-length override as inherit, so '' would render the company
        // default while the app still showed it as overridden-to-empty (L12).
        // At company scope '' stays the correct clear sentinel.
        final value = host.isCascadeScope && v.isEmpty ? null : v;
        host.updateSettings((s) => _write(s, value));
      },
      onSubmitted: scope == null ? null : (_) => scope.trySubmit(),
    );
    return OverridableField.bind(
      apiKey: widget.apiKey,
      label: widget.label,
      cascadedValueOnEnable: () => _read(host.settings) ?? '',
      child: field,
    );
  }
}
