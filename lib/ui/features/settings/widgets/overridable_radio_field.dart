import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/widgets/overridable_field.dart';

/// Radio-group counterpart to [OverridableDropdownField]. Use for any
/// two-choice (occasionally up to ~4) settings field bound to a single key —
/// a radio group keeps both options visible instead of hiding one behind a
/// dropdown tap. Reading + writing stays on the caller via [value] /
/// [onChanged], same shape as [OverridableDropdownField], so freezed
/// `copyWith` calls keep their types.
///
/// `RadioGroup` is safe here: the field renders inside the scrollable
/// `SettingsFormShell`, not a `showModalBottomSheet`. The mid-frame-mutation
/// crash that makes `entity_sort_filter_sheet.dart` /
/// `tax_category_dialog.dart` hand-roll a plain selectable list only bites
/// inside modal sheets whose size-listening layout re-enters.
class OverridableRadioField<T> extends StatelessWidget {
  const OverridableRadioField({
    super.key,
    required this.label,
    required this.apiKey,
    required this.value,
    required this.options,
    required this.onChanged,
    this.subtitleOf,
  });

  final String label;
  final String apiKey;
  final T? value;
  final List<({T value, String label})> options;

  /// `null` disables the group (mirrors the `OverridableDropdownField`
  /// contract — greys out the field and ignores taps).
  final ValueChanged<T?>? onChanged;

  /// Optional secondary content rendered under an option's label (e.g. a
  /// two-line summary). When this returns non-null for an option, that tile
  /// switches to `isThreeLine` + non-dense to fit; otherwise the tile stays
  /// dense and single-line, so existing callers are unaffected.
  final Widget? Function(T value)? subtitleOf;

  Widget _buildOption(({T value, String label}) option) {
    final subtitle = subtitleOf?.call(option.value);
    return RadioListTile<T>(
      value: option.value,
      title: Text(option.label),
      subtitle: subtitle,
      // Two-line summaries need the taller three-line tile + a top-aligned
      // radio; the plain single-line case stays dense.
      isThreeLine: subtitle != null,
      contentPadding: EdgeInsets.zero,
      dense: subtitle == null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final host = context.watch<SettingsDraftHost>();
    final errors = host.fieldErrors[apiKey];
    final errorText = (errors != null && errors.isNotEmpty)
        ? errors.first
        : null;

    final field = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        IgnorePointer(
          // `RadioGroup.onChanged` is non-nullable; mirror the
          // `OverridableDropdownField` "null disables" contract by ignoring
          // taps and dimming instead.
          ignoring: onChanged == null,
          child: Opacity(
            opacity: onChanged == null ? 0.5 : 1.0,
            child: RadioGroup<T>(
              groupValue: value,
              onChanged: onChanged ?? (_) {},
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final o in options) _buildOption(o)],
              ),
            ),
          ),
        ),
        if (errorText != null)
          // Standalone error rendering: `RadioListTile` carries no
          // `InputDecoration` slot. Styling matches the Material default
          // `InputDecoration.errorText` (12pt, colorScheme.error), same as
          // `OverridableSwitchField`.
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: InSpacing.md(context),
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
      // Seed the override with the currently displayed value so the radio
      // stays on the same option when the user toggles the checkbox on.
      cascadedValueOnEnable: () => value?.toString(),
      child: field,
    );
  }
}
