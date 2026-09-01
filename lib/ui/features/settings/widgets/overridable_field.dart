import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/widgets/settings_field_bindings.dart';

/// Generic wrapper that renders a form field with a "use override" checkbox
/// at group/client level. At company level the checkbox is hidden and the
/// child renders unwrapped — there's no "inheritance" concept when editing
/// the company's own defaults.
///
/// Behavior at group/client level:
///   * `isOverridden = false` → checkbox unchecked, child wrapped in
///     `IgnorePointer + Opacity` so the placeholder (inherited value) is
///     visible but the user can't edit until they opt in.
///   * `isOverridden = true` → checkbox checked, child fully interactive.
///   * Tapping the checkbox flips state via [onOverrideToggle]; the caller
///     is responsible for nulling the field on toggle-off and seeding it
///     with the cascaded value on toggle-on.
///
/// Layout: checkbox on the left, field expanded to fill the rest of the
/// row. The field's own `InputDecoration.labelText` carries the field's
/// label visually; [label] is reused as a tooltip on the checkbox for
/// accessibility.
///
/// Most callers should reach for [OverridableField.bind] rather than this
/// constructor — `bind` reads the ambient host + level itself so the
/// per-variant `Overridable*` field widgets don't repeat the same
/// `isOverridden` / `setOverride` plumbing.
///
/// For fields whose read/write isn't (or can't be) registered in the static
/// `settings_field_bindings.dart` map — most importantly user-supplied
/// `translations.<key>` rows on the Custom Labels tab — use
/// [OverridableField.bindInline] to pass the projections directly.
///
/// Mirrors React's `PropertyCheckbox`
/// (`react/src/components/PropertyCheckbox.tsx`).
class OverridableField extends StatelessWidget {
  const OverridableField({
    super.key,
    required this.label,
    required this.isOverridden,
    required this.onOverrideToggle,
    required this.child,
    this.blockPointerWhenInactive = true,
  });

  /// Cascade-aware wrapper for the `Overridable*` field widgets. Reads the
  /// ambient [SettingsDraftHost] and [SettingsLevelController] from context;
  /// at `SettingsLevel.company` returns [child] unwrapped, otherwise wraps
  /// in an [OverridableField] with `isOverridden` / `onOverrideToggle`
  /// already wired against [apiKey].
  ///
  /// [cascadedValueOnEnable] is invoked when the user opts into overriding
  /// — return the currently displayed value (stringified) to seed
  /// [SettingsDraftHost.setOverride]. The typical body is `() => value`
  /// (for text / id strings) or `() => value?.toString()` (for enums).
  /// Invoked lazily so callsites can read live host state without an extra
  /// closure-over-stale-value bug.
  static Widget bind({
    Key? key,
    required String apiKey,
    required String label,
    required String? Function() cascadedValueOnEnable,
    required Widget child,
    bool blockPointerWhenInactive = true,
  }) {
    return _OverridableBoundField(
      key: key,
      apiKey: apiKey,
      label: label,
      cascadedValueOnEnable: cascadedValueOnEnable,
      blockPointerWhenInactive: blockPointerWhenInactive,
      child: child,
    );
  }

  /// Variant of [bind] for fields whose read/write isn't (or can't be)
  /// registered in `settings_field_bindings.dart`'s static map — most
  /// importantly per-key entries on `settings.translations` (Custom Labels),
  /// where the suffix is user-supplied and unknown at compile time.
  ///
  /// Caller passes the projection closures directly. The widget reports
  /// "overridden" when `binding.read(settings) != null` and applies the
  /// override via `host.updateSettings((s) => binding.write(s, value))`.
  /// [apiKey] is still required — it identifies the field for 422 error
  /// display and accessibility tooltips.
  static Widget bindInline({
    Key? key,
    required String apiKey,
    required String label,
    required SettingsBinding binding,
    required String? Function() cascadedValueOnEnable,
    required Widget child,
  }) {
    return _OverridableBoundField(
      key: key,
      apiKey: apiKey,
      label: label,
      cascadedValueOnEnable: cascadedValueOnEnable,
      binding: binding,
      child: child,
    );
  }

  final String label;
  final bool isOverridden;

  /// Whether an un-overridden field is made inert to pointers as well as
  /// dimmed. True for every variant whose child has nothing to interact with
  /// when read-only — a `TextField`, a dropdown, a switch.
  ///
  /// `OverridableMarkdownField` passes false: its editor owns an internal
  /// scroll view, and blocking pointers around it means an inherited value
  /// taller than the box can't be read at all — the invoiceninja/flutter#107
  /// failure, reappearing in the settings cascade. It renders itself
  /// non-editable via `MarkdownTextField.readOnly` instead; the dimming here
  /// still applies, so the two don't compound.
  final bool blockPointerWhenInactive;
  final ValueChanged<bool> onOverrideToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final level = context.watch<SettingsLevelController>().level;
    if (level == SettingsLevel.company) {
      return child;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Tooltip(
          message: label,
          child: SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: isOverridden,
              onChanged: (v) => onOverrideToggle(v ?? false),
            ),
          ),
        ),
        SizedBox(width: InSpacing.md(context)),
        Expanded(
          child: IgnorePointer(
            ignoring: !isOverridden && blockPointerWhenInactive,
            // 0.65 keeps the disabled state readable on light + dark themes
            // (WCAG AA-clearing on most ink tokens) while still reading as
            // "inactive" at a glance.
            child: Opacity(opacity: isOverridden ? 1.0 : 0.65, child: child),
          ),
        ),
      ],
    );
  }
}

class _OverridableBoundField extends StatelessWidget {
  const _OverridableBoundField({
    super.key,
    required this.apiKey,
    required this.label,
    required this.cascadedValueOnEnable,
    required this.child,
    this.blockPointerWhenInactive = true,
    this.binding,
  });

  final String apiKey;
  final String label;
  final String? Function() cascadedValueOnEnable;
  final Widget child;

  /// See [OverridableField.blockPointerWhenInactive].
  final bool blockPointerWhenInactive;

  /// When non-null, the read/write goes through these inline closures
  /// instead of [SettingsDraftHost.isOverridden] / [SettingsDraftHost.setOverride]
  /// (which lookup [apiKey] in the static bindings map). See
  /// [OverridableField.bindInline] for the rationale.
  final SettingsBinding? binding;

  @override
  Widget build(BuildContext context) {
    final level = context.watch<SettingsLevelController>().level;
    if (level == SettingsLevel.company) return child;
    final host = context.watch<SettingsDraftHost>();
    final inline = binding;
    final bool isOverridden;
    final ValueChanged<bool> onToggle;
    if (inline != null) {
      // Read from `draftSettings` (the entity's own override blob), not
      // `settings` (which is the merged view at client scope). Reading the
      // merged view here would render the override checkbox as checked for
      // any key the company has set, even when the client has no override.
      isOverridden = inline.read(host.draftSettings) != null;
      onToggle = (on) {
        final value = on ? cascadedValueOnEnable() : null;
        host.updateSettings((s) => inline.write(s, value));
      };
    } else {
      isOverridden = host.isOverridden(apiKey);
      onToggle = (on) => host.setOverride(
        apiKey: apiKey,
        enabled: on,
        cascadedValue: on ? cascadedValueOnEnable() : null,
      );
    }
    return OverridableField(
      label: label,
      isOverridden: isOverridden,
      onOverrideToggle: onToggle,
      blockPointerWhenInactive: blockPointerWhenInactive,
      child: child,
    );
  }
}
