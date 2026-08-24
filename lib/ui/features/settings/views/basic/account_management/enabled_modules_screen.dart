import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/enabled_modules.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/settings/views/basic/account_management/company_settings_gate.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

/// Account Management → Enabled Modules. One toggle per
/// [kEnabledModulesOrder] entry — value flows through XOR on
/// `company.enabled_modules`. Each toggle saves immediately (no Save button)
/// to keep the interaction simple; per-toggle in-flight state guards against
/// rapid taps stepping on each other.
class AccountManagementEnabledModulesScreen extends StatefulWidget {
  const AccountManagementEnabledModulesScreen({super.key});

  @override
  State<AccountManagementEnabledModulesScreen> createState() =>
      _AccountManagementEnabledModulesScreenState();
}

class _AccountManagementEnabledModulesScreenState
    extends State<AccountManagementEnabledModulesScreen> {
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // This tab edits the WHOLE company (updateCompany PUTs the entire
    // serialized row), but it binds to the cached Drift row instead of the
    // VM seam. After a full sync the SMTP / expense / task-invoicing /
    // payment-conversion columns hold table defaults (they're absent from the
    // login envelope + _persistAndActivate insert), so a toggle PUT would
    // clobber the user's real server values. Re-hydrate the canonical company
    // on mount, mirroring SettingsDraftViewModel.kickRefresh (repo.refresh =>
    // GET /companies/{id} => applyUpdateResponse). refresh() swallows its own
    // errors, so the screen still renders from cache when offline.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final services = context.read<Services>();
      final companyId = services.auth.session.value?.currentCompanyId;
      if (companyId == null || companyId.isEmpty) return;
      unawaited(services.company.refresh(companyId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId == null || companyId.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return CompanySettingsGate(
      companyId: companyId,
      builder: (context, ready) => StreamBuilder<Company?>(
        stream: services.company.watchCompany(companyId),
        builder: (context, snapshot) {
          final company = snapshot.data;
          if (company == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return SettingsFormShell(
            sections: [
              if (!ready) const CompanySettingsLockedBanner(),
              FormSection(
                // Not `enabled_modules`: the card holds every module with its
                // switch, on or off (invoiceninja/flutter#82).
                title: context.tr('modules'),
                spacing: 0,
                children: [
                  for (final module in kEnabledModulesOrder)
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.tr(module.labelKey)),
                      value: isModuleEnabled(company.enabledModules, module),
                      // Gated on `ready`: the canonical company must be fetched
                      // before a toggle PUTs the whole row (else cached
                      // server-only defaults clobber the server).
                      onChanged: (!ready || _saving)
                          ? null
                          : (_) => _onToggle(company, module),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _onToggle(Company company, EnabledModule module) async {
    final services = context.read<Services>();
    setState(() => _saving = true);
    try {
      await services.company.updateCompany(
        draft: company.copyWith(
          enabledModules: toggleModule(company.enabledModules, module),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Notify.error(context, context.tr('error_refresh_page'), error: e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
