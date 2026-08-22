import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/widgets/overridable_field.dart';
import 'package:admin/ui/features/settings/widgets/settings_field_bindings.dart';

/// Boolean counterpart to [OverridableTextField] / [OverridableDropdownField].
/// Renders a [SwitchListTile] bound to a single settings key and wraps it in
/// [OverridableField] at group/client level so the user can opt in to
/// overriding the cascaded value.
///
/// The cascade override system stores values as `String?` (see
/// [SettingsBinding]); each bool binding encodes its value as `'true'` /
/// `'false'` / `null` and this widget translates back to a Dart `bool?` for
/// the switch.
///
/// Use for `company.settings.*` bool fields: `military_time`,
/// `enable_rappen_rounding`, `show_currency_code`, etc. (NOT
/// `use_comma_as_decimal_place` — that's a top-level company field bound
/// directly to the company draft, see the Localization screen.)
class OverridableSwitchField extends StatelessWidget {
  const OverridableSwitchField({
    super.key,
    required this.label,
    required this.apiKey,
    this.subtitle,
    this.enabled = true,
    this.defaultValue = false,
  });

  final String label;
  final String apiKey;

  /// Optional secondary line under the switch label — typically a clarifying
  /// hint (e.g. `use_comma_as_decimal_place` under `decimal_comma`).
  final String? subtitle;

  /// When false the toggle is non-interactive (greyed) — used to plan-gate a
  /// field while keeping it visible (e.g. reminder rules on a free account).
  final bool enabled;

  /// What an unset (`null`) setting renders as. Defaults to `false`, which is
  /// right for the many keys the server also defaults off — every existing
  /// call site is unchanged.
  ///
  /// Pass `true` for a key whose *server-side* default is on
  /// (`documents_public_by_default`). Without it the switch would read OFF on
  /// a company that has never written the key while the server keeps behaving
  /// as if it were ON — a toggle that lies about the current behavior.
  final bool defaultValue;

  @override
  Widget build(BuildContext context) {
    final binding = settingsBindingOf(apiKey);
    final host = context.watch<SettingsDraftHost>();
    final raw = binding.read(host.settings);
    final bool? value = raw == null ? null : raw == 'true';
    final effective = value ?? defaultValue;

    final errors = host.fieldErrors[apiKey];
    final errorText = (errors != null && errors.isNotEmpty)
        ? errors.first
        : null;

    final field = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          title: Text(label),
          subtitle: subtitle == null ? null : Text(subtitle!),
          value: effective,
          // Null onChanged greys out the switch (Material's disabled contract).
          onChanged: enabled
              ? (v) =>
                    host.updateSettings((s) => binding.write(s, v.toString()))
              : null,
          contentPadding: EdgeInsets.zero,
        ),
        if (errorText != null)
          // Standalone error rendering because `SwitchListTile` doesn't carry
          // an `InputDecoration` slot. Styling intentionally matches the
          // Material default `InputDecoration.errorText` (12pt, colorScheme.error)
          // used by `OverridableTextField` — if that default ever changes,
          // update both sites.
          Padding(
            padding: EdgeInsets.only(
              left: InSpacing.md(context),
              top: InSpacing.xs,
            ),
            child: Text(
              errorText,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );

    return OverridableField.bind(
      apiKey: apiKey,
      label: label,
      // Seed the override with the displayed value so the switch stays in
      // place when the user toggles the checkbox on.
      cascadedValueOnEnable: () => effective.toString(),
      child: field,
    );
  }
}
