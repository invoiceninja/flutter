import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/overridable_text_field.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

/// Searchable label keys rendered by the Customize tab. Mirrors the field
/// list below; aggregated into `kSettingsSearchCatalog['client_portal']`.
const kClientPortalCustomizeSearchKeys = <String>[
  'header',
  'footer',
  'custom_css',
  'custom_javascript',
];

const _kMonospace = TextStyle(fontFamily: kMonoFontFamily, fontSize: 13);

/// Customize tab — Header / Footer (HTML), plus Custom CSS / Custom JS
/// (self-hosted only). Only rendered at company scope; per-client custom
/// code is a UX anti-pattern.
class ClientPortalCustomizeScreen extends StatelessWidget {
  const ClientPortalCustomizeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final level = context.watch<SettingsLevelController>().level;
    if (level != SettingsLevel.company) {
      return EmptyState(
        icon: Icons.code,
        title: context.tr('customize'),
        subtitle: context.tr('company_settings_only'),
      );
    }
    final isHosted =
        context.read<Services>().auth.session.value?.isHosted ?? false;
    return SettingsFormShell(
      sections: [
        FormSection(
          title: context.tr('html'),
          children: [
            OverridableTextField(
              label: context.tr('header'),
              apiKey: 'portal_custom_head',
              maxLines: 8,
              style: _kMonospace,
              hintText: '<!-- HTML allowed -->',
            ),
            SizedBox(height: InSpacing.md(context)),
            OverridableTextField(
              label: context.tr('footer'),
              apiKey: 'portal_custom_footer',
              maxLines: 8,
              style: _kMonospace,
              hintText: '<!-- HTML allowed -->',
            ),
          ],
        ),
        if (!isHosted)
          FormSection(
            title: context.tr('customize'),
            children: [
              OverridableTextField(
                label: context.tr('custom_css'),
                apiKey: 'portal_custom_css',
                maxLines: 8,
                style: _kMonospace,
                hintText: '/* CSS */',
              ),
              SizedBox(height: InSpacing.md(context)),
              OverridableTextField(
                label: context.tr('custom_javascript'),
                apiKey: 'portal_custom_js',
                maxLines: 8,
                style: _kMonospace,
                hintText: '// JavaScript',
              ),
            ],
          ),
      ],
    );
  }
}
