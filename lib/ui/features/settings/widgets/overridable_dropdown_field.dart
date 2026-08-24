import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/widgets/overridable_field.dart';

/// Dropdown counterpart to `OverridableTextField`. Renders a
/// [DropdownButtonFormField] bound to a single settings key and wraps it
/// in [OverridableField] at group/client level so the user can opt in to
/// overriding the cascaded value.
///
/// Use this on any settings page that exposes a dropdown bound to a
/// `String?` (or other `T?`) settings field — currency, language,
/// country, date format, etc. Reading + writing the field stays on the
/// caller via [value] / [onChanged] (the same shape settings dropdowns
/// already use), so freezed `copyWith` calls keep their types.
class OverridableDropdownField<T> extends StatelessWidget {
  const OverridableDropdownField({
    super.key,
    required this.label,
    required this.apiKey,
    required this.value,
    required this.items,
    required this.onChanged,
    this.helperText,
  });

  final String label;
  final String apiKey;
  final T? value;
  final List<DropdownMenuItem<T>> items;

  /// `null` disables the dropdown (matches Material's `DropdownButtonFormField`
  /// contract — a null `onChanged` greys out the field and ignores taps). Use
  /// when a server-side constraint locks the value (e.g. VeriFactu forcing
  /// `lock_invoices` to `when_sent`).
  final ValueChanged<T?>? onChanged;

  /// Optional explainer rendered beneath the field, matching the `subtitle`
  /// the switch rows on the same page carry. Material hides it while
  /// [errorText] is showing — the validation message is the more urgent
  /// thing to read.
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final host = context.watch<SettingsDraftHost>();
    // Guard against value-not-in-items: DropdownButtonFormField throws if
    // `value` isn't one of the item values. This happens transiently
    // before statics finish loading; show null until items are ready.
    final effective = items.any((i) => i.value == value) ? value : null;
    final errors = host.fieldErrors[apiKey];
    final errorText = (errors != null && errors.isNotEmpty)
        ? errors.first
        : null;
    final field = DropdownButtonFormField<T>(
      initialValue: effective,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        helperText: helperText,
        // Translations run longer than English; one line silently truncates.
        helperMaxLines: 3,
      ),
      items: items,
      onChanged: onChanged,
    );
    return OverridableField.bind(
      apiKey: apiKey,
      label: label,
      // Seed the override with the currently displayed value (the cascaded
      // company default) so the dropdown stays on the same option when the
      // user toggles the checkbox on.
      cascadedValueOnEnable: () => seedOnEnable<T>(value, items),
      child: field,
    );
  }

  /// The value to seed a newly-enabled override with. Prefers the cascaded
  /// [value]; when nothing is inherited (`value == null` — e.g. the company
  /// sits at the server default) it falls back to the first real option.
  ///
  /// Without the fallback a null seed collapses straight back to "not
  /// overridden" — the settings bindings omit null keys and `isOverridden`
  /// requires a non-null value — so the override checkbox becomes a dead
  /// control that can never be enabled at client/group scope (finding #12).
  @visibleForTesting
  static String? seedOnEnable<T>(T? value, List<DropdownMenuItem<T>> items) {
    if (value != null) return value.toString();
    for (final item in items) {
      final v = item.value;
      if (v != null) return v.toString();
    }
    return null;
  }
}
