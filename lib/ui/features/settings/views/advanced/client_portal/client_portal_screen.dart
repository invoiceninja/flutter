import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/portal_constants.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/enabled_modules.dart';
import 'package:admin/domain/client_portal_urls.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/external_url.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/views/advanced/client_portal/widgets/confirmed_portal_url_display.dart';
import 'package:admin/ui/features/settings/views/advanced/client_portal/widgets/portal_url_display.dart';
import 'package:admin/ui/features/settings/views/advanced/client_portal/widgets/subdomain_field.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/overridable_switch_field.dart';
import 'package:admin/ui/features/settings/widgets/overridable_text_field.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

/// Searchable label keys rendered by the Settings tab. Aggregated into the
/// `'client_portal'` entry of `kSettingsSearchCatalog` so the in-app search
/// surfaces these fields. Keep in sync with the field list below.
const kClientPortalSettingsSearchKeys = <String>[
  'portal_mode',
  'subdomain',
  'domain_url',
  'login_url',
  'view_docs',
  'client_portal',
  'enable_client_portal_dashboard',
  'mobile_version',
  'preference_product_notes_for_html_view',
  'enable_client_profile_update',
  'client_document_upload',
  'vendor_document_upload',
  'accept_purchase_order_number',
  'terms_of_service',
  'privacy_policy',
];

/// Default tab of the Client Portal settings page — Portal configuration,
/// master toggle + features, uploads/approvals, and the long-form legal
/// documents.
///
/// Portal Configuration (top-level Company fields) renders only at company
/// scope. Cascade-aware toggles render at every scope with the standard
/// override checkbox. When the master `enable_client_portal` toggle is off,
/// the dependent sections render dimmed + non-interactive so the user can
/// see they're inactive — but the master toggle itself stays interactive so
/// the user can flip the portal back on.
class ClientPortalScreen extends StatelessWidget {
  const ClientPortalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final host = context.watch<SettingsDraftHost>();
    final level = context.watch<SettingsLevelController>().level;
    final services = context.read<Services>();
    final session = services.auth.session.value;
    final isHosted = session?.isHosted ?? false;
    final isEnterprisePlan = session?.hasEnterpriseAccess ?? false;
    // BUG FIX: the Free plan slug is the empty string, never the literal
    // `'free'`, so the old `== 'free'` check was always false and the
    // subdomain field was never gated. Use the canonical trial-aware
    // predicate (a Free or non-Pro hosted account has no subdomain access;
    // trialing / paid users do).
    final isFreePlan = isHosted && !(session?.hasProAccess ?? false);
    final draft = host.draft;
    // Defaults to true so a never-set settings row doesn't dim the page on
    // first load. The legacy admin-portal does the same.
    final portalEnabled = host.settings.enableClientPortal ?? true;
    final modules = draft?.enabledModules ?? 0;
    final vendorsOn = isModuleEnabled(modules, EnabledModule.vendors);
    final quotesOn = isModuleEnabled(modules, EnabledModule.quotes);
    final purchaseOrdersOn = isModuleEnabled(
      modules,
      EnabledModule.purchaseOrders,
    );
    final pdfHtmlOnMobile = host.settings.showPdfhtmlOnMobile ?? false;
    // Only dim at company scope. At group/client scope the override checkbox
    // is the user's escape hatch — hiding it behind IgnorePointer would
    // strand them with no way to flip the local override.
    final dimDependents = !portalEnabled && level == SettingsLevel.company;

    final masterSection = FormSection(
      title: context.tr('portal_features'),
      children: [
        OverridableSwitchField(
          label: context.tr('client_portal'),
          apiKey: 'enable_client_portal',
          subtitle: context.trIfDefined('enable_client_portal_help'),
        ),
        OverridableSwitchField(
          label: context.tr('dashboard'),
          apiKey: 'enable_client_portal_dashboard',
          subtitle: context.trIfDefined('enable_client_portal_dashboard_help'),
        ),
        OverridableSwitchField(
          label: context.tr('mobile_version'),
          apiKey: 'show_pdfhtml_on_mobile',
          subtitle: context.trIfDefined('show_pdfhtml_on_mobile_help'),
        ),
        if (pdfHtmlOnMobile)
          OverridableSwitchField(
            label: context.tr('preference_product_notes_for_html_view'),
            apiKey: 'preference_product_notes_for_html_view',
            subtitle: context.trIfDefined(
              'preference_product_notes_for_html_view_help',
            ),
          ),
        OverridableSwitchField(
          label: context.tr('enable_client_profile_update'),
          apiKey: 'enable_client_profile_update',
          subtitle: context.trIfDefined('enable_client_profile_update_help'),
        ),
      ],
    );
    final uploadsSection = FormSection(
      title: context.tr('uploads_and_approvals'),
      children: [
        OverridableSwitchField(
          label: context.tr('client_document_upload'),
          apiKey: 'client_portal_enable_uploads',
          subtitle: context.trIfDefined('document_upload_help'),
        ),
        if (vendorsOn)
          OverridableSwitchField(
            label: context.tr('vendor_document_upload'),
            apiKey: 'vendor_portal_enable_uploads',
            subtitle: context.trIfDefined('vendor_document_upload_help'),
          ),
        if (quotesOn && purchaseOrdersOn)
          OverridableSwitchField(
            label: context.tr('accept_purchase_order_number'),
            apiKey: 'accept_client_input_quote_approval',
            subtitle: context.trIfDefined('accept_purchase_order_number_help'),
          ),
      ],
    );
    final legalSection = FormSection(
      title: context.tr('legal'),
      children: [
        OverridableTextField(
          label: context.tr('terms_of_service'),
          apiKey: 'client_portal_terms',
          maxLines: 6,
        ),
        OverridableTextField(
          label: context.tr('privacy_policy'),
          apiKey: 'client_portal_privacy_policy',
          maxLines: 6,
        ),
      ],
    );

    Widget dim(Widget section) => dimDependents
        ? IgnorePointer(
            ignoring: true,
            child: Opacity(opacity: 0.5, child: section),
          )
        : section;

    return SettingsFormShell(
      sections: [
        if (level == SettingsLevel.company)
          _PortalConfigurationSection(
            draft: draft,
            isHosted: isHosted,
            isEnterprisePlan: isEnterprisePlan,
            isFreePlan: isFreePlan,
            portalEnabled: portalEnabled,
          ),
        // Master section is never dimmed — the user must always be able to
        // flip the portal back on.
        masterSection,
        dim(uploadsSection),
        dim(legalSection),
      ],
    );
  }
}

class _PortalConfigurationSection extends StatefulWidget {
  const _PortalConfigurationSection({
    required this.draft,
    required this.isHosted,
    required this.isEnterprisePlan,
    required this.isFreePlan,
    required this.portalEnabled,
  });

  final Company? draft;
  final bool isHosted;
  final bool isEnterprisePlan;
  final bool isFreePlan;

  /// `enable_client_portal` — off, the URLs below lead to a portal that
  /// shows every page as disabled, so they carry a notice.
  final bool portalEnabled;

  @override
  State<_PortalConfigurationSection> createState() =>
      _PortalConfigurationSectionState();
}

class _PortalConfigurationSectionState
    extends State<_PortalConfigurationSection> {
  late final TextEditingController _domainController;

  @override
  void initState() {
    super.initState();
    _domainController = TextEditingController(
      text: widget.draft?.portalDomain ?? '',
    );
  }

  @override
  void dispose() {
    _domainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final host = context.watch<SettingsDraftHost>();
    final draft = widget.draft;
    final portalMode = draft?.portalMode ?? '';
    final subdomain = draft?.subdomain ?? '';
    final portalDomain = draft?.portalDomain ?? '';
    final companyKey = draft?.companyKey ?? '';
    // Sync the controller with host-driven changes (refresh / reset). Same
    // pattern as OverridableTextField — match on text, preserve cursor.
    if (_domainController.text != portalDomain) {
      _domainController.value = TextEditingValue(
        text: portalDomain,
        selection: TextSelection.collapsed(offset: portalDomain.length),
      );
    }
    final showSubdomain =
        widget.isHosted && portalMode == kClientPortalModeSubdomain;
    final showDomain =
        !widget.isHosted || portalMode == kClientPortalModeDomain;
    final showViewDocs =
        widget.isHosted &&
        portalMode == kClientPortalModeDomain &&
        widget.isEnterprisePlan;
    final loginUrl = clientPortalUrl(
      page: ClientPortalPage.login,
      isHosted: widget.isHosted,
      portalMode: portalMode,
      subdomain: subdomain,
      portalDomain: portalDomain,
      companyKey: companyKey,
    );
    final saved = host.initialCompany;
    final savedLoginUrl = saved == null
        ? ''
        : clientPortalUrl(
            page: ClientPortalPage.login,
            isHosted: widget.isHosted,
            portalMode: saved.portalMode,
            subdomain: saved.subdomain,
            portalDomain: saved.portalDomain,
            companyKey: saved.companyKey,
          );
    final scope = FormSaveScope.maybeOf(context);

    return FormSection(
      title: context.tr('portal_settings'),
      children: [
        if (widget.isHosted) ...[
          DropdownButtonFormField<String>(
            initialValue: portalMode.isEmpty ? null : portalMode,
            decoration: InputDecoration(
              labelText: context.tr('portal_mode'),
              helperText: widget.isEnterprisePlan
                  ? null
                  : context.tr('requires_an_enterprise_plan'),
            ),
            items: [
              DropdownMenuItem(
                value: kClientPortalModeSubdomain,
                child: Text(context.tr(kClientPortalModeSubdomain)),
              ),
              DropdownMenuItem(
                value: kClientPortalModeDomain,
                child: Text(context.tr(kClientPortalModeDomain)),
              ),
            ],
            onChanged: widget.isEnterprisePlan
                ? (v) =>
                      host.updateCompany((c) => c.copyWith(portalMode: v ?? ''))
                : null,
          ),
        ],
        if (showSubdomain) SubdomainField(enabled: !widget.isFreePlan),
        if (showDomain)
          TextField(
            controller: _domainController,
            textInputAction: TextInputAction.done,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: context.tr('domain_url'),
              helperText: context.tr('portal_domain_help'),
              helperMaxLines: 2,
            ),
            onChanged: (v) =>
                host.updateCompany((c) => c.copyWith(portalDomain: v)),
            onSubmitted: scope == null ? null : (_) => scope.trySubmit(),
          ),
        if (showViewDocs)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: Text(context.tr('view_docs')),
              onPressed: () => _openDocs(context),
            ),
          ),
        if (loginUrl.isNotEmpty) ...[
          if (!widget.portalEnabled) const PortalDisabledNotice(),
          ConfirmedPortalUrlDisplay(
            companyId: draft?.id ?? '',
            label: context.tr('login_url'),
            url: loginUrl,
            savedUrl: savedLoginUrl,
          ),
        ],
      ],
    );
  }
}

Future<void> _openDocs(BuildContext context) async {
  /* best-effort link — nothing to say if it doesn't open */
  await launchExternalUri(Uri.parse(kDocsCustomDomainUrl));
}
