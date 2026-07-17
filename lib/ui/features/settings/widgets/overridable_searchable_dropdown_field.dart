import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/widgets/overridable_field.dart';

/// Searchable counterpart to `OverridableDropdownField`. Use this on settings
/// pages whenever the bound list is long enough that scroll-hunting is
/// annoying (countries, currencies, languages, industries — anything past
/// ~20 options).
///
/// Same cascade-override semantics as `OverridableDropdownField`: the field
/// is bound to a single settings key (`apiKey`), surfaces 422 field errors
/// from the host, and at group/client level wraps in [OverridableField] so
/// the user can opt in to overriding the cascaded value.
///
/// Value type is `String?` (the settings-key id). `T` is the rich item
/// shape (Currency, Language, Country, …) — needed for `displayString` /
/// `idOf`. The widget translates between the two.
class OverridableSearchableDropdownField<T extends Object>
    extends StatelessWidget {
  const OverridableSearchableDropdownField({
    super.key,
    required this.label,
    required this.apiKey,
    required this.value,
    required this.items,
    required this.displayString,
    required this.idOf,
    required this.onChanged,
    this.emptyHintKey,
  });

  final String label;
  final String apiKey;

  /// Current selection as the settings-key id (or `null` when unset).
  final String? value;

  /// Pre-sorted list of selectable items.
  final List<T> items;

  /// Visible label for a given item.
  final String Function(T) displayString;

  /// Stable id for a given item (matched against [value]).
  final String Function(T) idOf;

  /// Fires with the new id (or `null` when cleared).
  final ValueChanged<String?> onChanged;

  /// Localization key for the placeholder while [items] is empty (statics
  /// still loading). Forwarded to [SearchableDropdownField.emptyHintKey].
  final String? emptyHintKey;

  @override
  Widget build(BuildContext context) {
    final host = context.watch<SettingsDraftHost>();

    T? selected;
    for (final item in items) {
      if (idOf(item) == value) {
        selected = item;
        break;
      }
    }

    final errors = host.fieldErrors[apiKey];
    final errorText = (errors != null && errors.isNotEmpty)
        ? errors.first
        : null;

    final field = SearchableDropdownField<T>(
      label: label,
      items: items,
      initialValue: selected,
      displayString: displayString,
      idOf: idOf,
      // Scope-aware clear (H4), matching the picker widgets: at company scope
      // write the empty-string sentinel — a typed null is omitted by
      // CompanySettingsApi's includeIfNull:false toJson, so the stale
      // rawSettings value would resurrect on save; '' survives the merge and
      // actually clears the field. At group/client (cascade) scope a null
      // removes the per-record override.
      onChanged: (item) => onChanged(
        item == null ? (host.isCascadeScope ? null : '') : idOf(item),
      ),
      emptyHintKey: emptyHintKey,
      errorText: errorText,
    );

    return OverridableField.bind(
      apiKey: apiKey,
      label: label,
      // Seed the override with the currently displayed value (the cascaded
      // company default) so the picker stays on the same option when the
      // user toggles the checkbox on. When nothing is inherited (`value ==
      // null` — company at the server default) fall back to the first option:
      // a null seed collapses back to "not overridden", leaving the checkbox a
      // dead control at client/group scope (finding #12, same as the plain
      // OverridableDropdownField).
      cascadedValueOnEnable: () =>
          value ?? (items.isEmpty ? null : idOf(items.first)),
      child: field,
    );
  }
}
