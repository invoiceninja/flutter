import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/domain/client_portal_urls.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/views/advanced/client_portal/widgets/portal_url_display.dart';
import 'package:admin/ui/features/settings/views/advanced/client_portal/widgets/registration_fields_configurator.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

/// Searchable label keys rendered by the Registration tab. Mirrors the field
/// list below; aggregated into `kSettingsSearchCatalog['client_portal']`.
const kClientPortalRegistrationSearchKeys = <String>[
  'client_registration',
  'registration_url',
];

/// Registration tab — only rendered at company scope (per-client / per-group
/// scope shows an empty state). Holds the Client Registration toggle, the
/// Registration URL, and the twenty-field hide/optional/require matrix.
class ClientPortalRegistrationScreen extends StatelessWidget {
  const ClientPortalRegistrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final level = context.watch<SettingsLevelController>().level;
    if (level != SettingsLevel.company) {
      return EmptyState(
        icon: Icons.lock_outline,
        title: context.tr('registration'),
        subtitle: context.tr('company_settings_only'),
      );
    }
    final host = context.watch<SettingsDraftHost>();
    final draft = host.draft;
    // `client_can_register` is a top-level company column (the server gates
    // registration on it; the `settings` copy is deprecated). Read + write the
    // company draft directly, not the cascade — this tab is company-scope only.
    final canRegister = draft?.clientCanRegister ?? false;
    final companyKey = draft?.companyKey ?? '';
    final portalDomain = draft?.portalDomain ?? '';
    final subdomain = draft?.subdomain ?? '';
    final registrationHelp = context.trIfDefined('client_registration_help');
    final portalEnabled = host.settings.enableClientPortal ?? true;
    final session = context.read<Services>().auth.session.value;
    final registrationUrl = clientPortalUrl(
      page: ClientPortalPage.register,
      isHosted: session?.isHosted ?? false,
      hasMultipleCompanies: (session?.companies.length ?? 0) > 1,
      portalMode: draft?.portalMode ?? '',
      subdomain: subdomain,
      portalDomain: portalDomain,
      companyKey: companyKey,
    );

    return SettingsFormShell(
      sections: [
        FormSection(
          title: context.tr('registration'),
          children: [
            SwitchListTile(
              title: Text(context.tr('client_registration')),
              subtitle: registrationHelp == null
                  ? null
                  : Text(registrationHelp),
              value: canRegister,
              onChanged: (v) =>
                  host.updateCompany((c) => c.copyWith(clientCanRegister: v)),
              contentPadding: EdgeInsets.zero,
            ),
            if (canRegister && registrationUrl.isNotEmpty) ...[
              if (!portalEnabled) const PortalDisabledNotice(),
              PortalUrlDisplay(
                label: context.tr('registration_url'),
                url: registrationUrl,
                showQrCode: true,
              ),
            ],
          ],
        ),
        FormSection(
          title: context.tr('registration_fields'),
          children: const [RegistrationFieldsConfigurator()],
        ),
      ],
    );
  }
}
