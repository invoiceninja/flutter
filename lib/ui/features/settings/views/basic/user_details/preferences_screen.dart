import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/color_hex.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/locale_controller.dart';
import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/l10n/supported_locales.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
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
                  alignment: AlignmentDirectional.centerStart,
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
    // "Match system", then every shipped language by its own name — 48 rows,
    // so it types to search (CLAUDE.md § Searchable pickers). Keyed on
    // `localeKey`, with '' for "Match system": no key is empty.
    final options = <({String key, String label})>[
      (key: _kMatchSystem, label: context.tr('match_system')),
      ...[
        for (final l in kSupportedLocales)
          (key: localeKey(l), label: _label(l)),
      ]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase())),
    ];
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final current = controller.value;
        final currentKey = current == null ? _kMatchSystem : localeKey(current);
        return Padding(
          padding: EdgeInsets.symmetric(vertical: InSpacing.md(context)),
          child: SearchableDropdownField<({String key, String label})>(
            label: context.tr('app_language'),
            items: options,
            initialValue: options.firstWhere(
              (o) => o.key == currentKey,
              orElse: () => options.first,
            ),
            displayString: (o) => o.label,
            idOf: (o) => o.key,
            onChanged: (o) {
              if (o == null) return;
              controller.set(o.key == _kMatchSystem ? null : _localeFor(o.key));
            },
          ),
        );
      },
    );
  }

  /// Sentinel for "follow the device language". No `localeKey` returns an
  /// empty string, so this can't collide with a real locale.
  static const String _kMatchSystem = '';

  /// `localeKey` in reverse. Falls back to the first supported locale rather
  /// than throwing: the only keys offered come from [kSupportedLocales]
  /// itself, so this is unreachable in practice.
  static Locale _localeFor(String key) => kSupportedLocales.firstWhere(
    (l) => localeKey(l) == key,
    orElse: () => kSupportedLocales.first,
  );

  static String _label(Locale locale) =>
      kLocaleNativeNames[localeKey(locale)] ?? localeKey(locale);
}
