import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/shortcuts/key_binding.dart';
import 'package:admin/app/shortcuts/keyboard_shortcuts_controller.dart';
import 'package:admin/app/shortcuts/shortcut_catalog.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/platform_modifier.dart';
import 'package:admin/ui/core/widgets/key_cap.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/keyboard_shortcut_recorder.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';
import 'package:admin/ui/features/settings/widgets/settings_screen_scaffold.dart';

/// Search keys for the settings sidebar search. Colocated with the screen so
/// adding / renaming a field updates both ends in one place (see
/// `search_catalog_consistency_test`).
const kKeyboardShortcutsSearchKeys = <String>[
  'keyboard_shortcuts',
  'shortcuts_general',
  'shortcuts_create_new',
  'switch_company',
  'search_everything',
  'toggle_sidebar',
  'settings',
  'focus_search',
  'reset_all_shortcuts',
];

/// `/settings/keyboard_shortcuts` — device-local keyboard-shortcut
/// customization. Rebind or clear the general shortcuts and assign the
/// otherwise-unbound "create X" actions. No save bar — every change writes
/// straight to [KeyboardShortcutsController] (persisted to `nav_state`), same
/// device-local pattern as Device Settings.
class KeyboardShortcutsScreen extends StatelessWidget {
  const KeyboardShortcutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<Services>().keyboardShortcuts;
    return SettingsScreenScaffold(
      titleKey: 'keyboard_shortcuts',
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final conflicts = controller.conflictingIds();
          final general = kShortcutCatalog
              .where((d) => d.group == ShortcutGroup.general)
              .toList(growable: false);
          final create = kShortcutCatalog
              .where((d) => d.group == ShortcutGroup.create)
              .toList(growable: false);
          return SettingsFormShell(
            sections: [
              _HintCard(),
              FormSection(
                title: context.tr('shortcuts_general'),
                spacing: 0,
                trailing: _ResetAllButton(controller: controller),
                children: [
                  for (final def in general)
                    _ShortcutRow(
                      def: def,
                      controller: controller,
                      conflict: conflicts.contains(def.id),
                    ),
                ],
              ),
              FormSection(
                title: context.tr('shortcuts_create_new'),
                spacing: 0,
                children: [
                  for (final def in create)
                    _ShortcutRow(
                      def: def,
                      controller: controller,
                      conflict: conflicts.contains(def.id),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: InSpacing.lg(context)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: tokens.ink3),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.tr('customize_shortcuts_hint'),
              style: TextStyle(color: tokens.ink3, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResetAllButton extends StatelessWidget {
  const _ResetAllButton({required this.controller});

  final KeyboardShortcutsController controller;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: controller.resetAll,
      child: Text(context.tr('reset_all_shortcuts')),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.def,
    required this.controller,
    required this.conflict,
  });

  final ShortcutDef def;
  final KeyboardShortcutsController controller;
  final bool conflict;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final mod = platformModifierLabel();
    final binding = controller.resolvedBinding(def.id);

    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: InSpacing.lg(context)),
      title: Text(context.tr(def.labelKey)),
      subtitle: conflict
          ? Text(
              context.tr('shortcut_conflict'),
              style: TextStyle(color: tokens.warning, fontSize: 12),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _bindingDisplay(context, binding, mod, conflict),
          SizedBox(width: InSpacing.md(context)),
          IconButton(
            tooltip: context.tr('record_shortcut'),
            icon: const Icon(Icons.keyboard_outlined, size: 20),
            onPressed: () async {
              final recorded = await showShortcutRecorderDialog(
                context,
                label: context.tr(def.labelKey),
              );
              if (recorded != null) controller.setBinding(def.id, recorded);
            },
          ),
          // Clear — only when there's something to clear.
          if (binding != null)
            IconButton(
              tooltip: context.tr('clear'),
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => controller.clearBinding(def.id),
            ),
          // Reset to default — only when overridden (custom or cleared).
          if (controller.isOverridden(def.id))
            IconButton(
              tooltip: context.tr('reset_shortcut'),
              icon: const Icon(Icons.settings_backup_restore, size: 20),
              onPressed: () => controller.resetBinding(def.id),
            ),
        ],
      ),
    );
  }

  Widget _bindingDisplay(
    BuildContext context,
    KeyBinding? binding,
    String mod,
    bool conflict,
  ) {
    final tokens = context.inTheme;
    if (binding == null) {
      return Text(
        context.tr('shortcut_unassigned'),
        style: TextStyle(color: tokens.ink3, fontSize: 12),
      );
    }
    // `KeyCapRow`, not a hand-rolled `Wrap`: one chord is one row, at the
    // app's single inter-cap gap. This rendered the same `displayGlyphs` list
    // as the hint bar and the `?` dialog at a different spacing.
    return KeyCapRow(
      keys: binding.displayGlyphs(mod),
      keyColor: conflict ? tokens.warning : null,
    );
  }
}
