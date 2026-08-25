import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/color_hex.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/locale_controller.dart';
import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/l10n/supported_locales.dart';
import 'package:admin/ui/features/settings/view_models/user_details_view_model.dart';
import 'package:admin/ui/features/settings/widgets/accent_swatch_grid.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

const kUserDetailsPreferencesSearchKeys = <String>[
  'preferences',
  'app_language',
  'accent_color',
];

/// Settings > User Details > Preferences tab body. Holds the two per-user
/// controls: app language (device-local) and accent colour. Accent writes
/// through to `company_user.settings.accent_color` via the shared
/// [UserDetailsViewModel], so it contributes to the User Details **save bar**
/// (it's server-synced, per-(company,user)). Theme mode, the palette preset
/// and the colour overrides are device-local with no save — they live on
/// Settings → Device Settings instead.
class UserDetailsPreferencesScreen extends StatelessWidget {
  const UserDetailsPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final vm = context.watch<UserDetailsViewModel>();
    final accentReady = vm.isLoaded && vm.draftReady;
    final accentHex = vm.user?.companyUserSettings.accentColor ?? '';

    return SettingsFormShell(
      sections: [
        FormSection(
          title: context.tr('preferences'),
          spacing: 0,
          children: [_LocaleTile(controller: services.locale)],
        ),
        FormSection(
          title: context.tr('accent_color'),
          children: [
            if (!accentReady)
              const Center(child: CircularProgressIndicator())
            else ...[
              AccentSwatchGrid(
                selected: accentHex,
                allowCustom: true,
                onSelected: (hex) {
                  vm.updateCompanyUserSettings(
                    (s) => s.copyWith(accentColor: hex),
                  );
                  // Flip the theme immediately so the rest of the app
                  // reflects the choice before Save round-trips. The
                  // controller drops the preview once the persisted row
                  // catches up (or the user switches company / signs out).
                  services.accentColor.setPreview(parseHexColor(hex));
                },
              ),
              SizedBox(height: InSpacing.md(context)),
              if (accentHex.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: Text(context.tr('reset')),
                    onPressed: () {
                      vm.updateCompanyUserSettings(
                        (s) => s.copyWith(accentColor: ''),
                      );
                      services.accentColor.setPreview(null);
                    },
                  ),
                ),
            ],
          ],
        ),
      ],
    );
  }
}

class _LocaleTile extends StatelessWidget {
  const _LocaleTile({required this.controller});
  final LocaleController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final current = controller.value;
        return ListTile(
          leading: const Icon(Icons.translate_outlined),
          title: Text(context.tr('app_language')),
          subtitle: Text(
            current == null ? context.tr('match_system') : _label(current),
          ),
          // Keyed on `localeKey`, not on `Locale` — and never on a nullable
          // value. `PopupMenuButton<T>` cannot tell a null-valued selection
          // from a dismissal: `_showButtonMenu` awaits `showMenu<T?>` and does
          // `if (newValue == null) { onCanceled?.call(); return; }` *before*
          // reaching `onSelected` (`material/popup_menu.dart`). Typed
          // `Locale?` with a `value: null` row, "Match system" was a dead menu
          // item — picking it left the previous language in place. Same fix as
          // `ProductGroupByButton._kNoGrouping`.
          trailing: PopupMenuButton<String>(
            tooltip: context.tr('choose_language'),
            initialValue: current == null ? _kMatchSystem : localeKey(current),
            onSelected: (key) =>
                controller.set(key == _kMatchSystem ? null : _localeFor(key)),
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: _kMatchSystem,
                child: Text(context.tr('match_system')),
              ),
              const PopupMenuDivider(),
              for (final l in kSupportedLocales)
                PopupMenuItem<String>(
                  value: localeKey(l),
                  child: Text(_label(l)),
                ),
            ],
            child: const Icon(Icons.arrow_drop_down),
          ),
        );
      },
    );
  }

  /// Sentinel for "follow the device language" so the menu never carries a
  /// `null` **value** — see the note on the button above. No `localeKey`
  /// returns an empty string, so this can't collide with a real locale.
  static const String _kMatchSystem = '';

  /// `localeKey` in reverse. Falls back to the first supported locale rather
  /// than throwing: the only keys in the menu come from [kSupportedLocales]
  /// itself, so this is unreachable in practice.
  static Locale _localeFor(String key) => kSupportedLocales.firstWhere(
    (l) => localeKey(l) == key,
    orElse: () => kSupportedLocales.first,
  );

  static String _label(Locale locale) {
    const labels = {
      'en': 'English',
      'en_AU': 'English (Australia)',
      'en_GB': 'English (UK)',
      'es': 'Español',
      'fr': 'Français',
      'de': 'Deutsch',
      'it': 'Italiano',
      'nl': 'Nederlands',
      'pt_BR': 'Português (Brasil)',
      'ja': '日本語',
      'zh_CN': '中文 (简体)',
    };
    return labels[localeKey(locale)] ?? localeKey(locale);
  }
}
