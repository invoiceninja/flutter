import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/bank_account.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
import 'package:admin/ui/features/bank_accounts/view_models/bank_account_edit_view_model.dart';
import 'package:admin/ui/features/bank_accounts/widgets/reconnect_banner.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_entity_edit_scaffold.dart';
import 'package:admin/ui/features/settings/widgets/settings_text_field.dart';

/// `/settings/bank_accounts/new` and `/settings/bank_accounts/:id/edit`.
///
/// Edit-or-create form for a single BankAccount. The OAuth Connect flow
/// (Yodlee/Nordigen) lives separately; this form is for manual entries
/// and for editing the local mutable fields (name, sync_from, auto_sync)
/// of an existing connection.
class BankAccountEditScreen extends StatelessWidget {
  const BankAccountEditScreen({this.existingId, super.key});

  final String? existingId;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final repo = services.bankAccounts;

    return SettingsEntityEditScaffold<BankAccount, BankAccountEditViewModel>(
      existingId: existingId,
      backRoute: '/settings/bank_accounts',
      createTitleKey: 'new_bank_account',
      editTitleKey: 'edit_bank_account',
      wireName: 'bank_account',
      watchById: (id) => repo.watch(companyId: companyId, id: id),
      refreshAll: () => repo.refreshAll(companyId: companyId),
      onArchive: (id) => repo.archive(companyId: companyId, id: id),
      onRestore: (id) => repo.restore(companyId: companyId, id: id),
      onDelete: (id) => repo.delete(companyId: companyId, id: id),
      vmFactory: ({existing}) => BankAccountEditViewModel(
        repo: repo,
        companyId: companyId,
        existing: existing,
        sync: services.sync,
        connectivity: services.connectivity,
      ),
      isArchivedOf: (a) => a.archivedAt != null,
      isDeletedOf: (a) => a.isDeleted,
      // Server (Store/UpdateBankIntegrationRequest) requires bank_account_name
      // to be min:3 — enforce client-side so a 1-2 char name doesn't round-trip
      // to a 422.
      canSave: (vm) =>
          !vm.isSaving && vm.isDirty && vm.draft.name.trim().length >= 3,
      bodyBuilder: (context, vm) => [
        if (vm.draft.needsReconnect) ReconnectBanner(account: vm.draft),
        FormSection(
          title: context.tr('bank_account'),
          children: [
            SettingsTextField(
              initialValue: vm.draft.name,
              labelKey: 'name',
              onChanged: vm.setName,
              errorText: vm.fieldErrorFor('bank_account_name'),
              textInputAction: TextInputAction.next,
              externalSyncKey: vm.original?.id,
            ),
            InDateField(
              value: vm.draft.fromDate?.toDateTime(),
              labelText: context.tr('sync_from'),
              formatter: services.formatterIfReady(companyId),
              clearable: true,
              onChanged: (dt) => vm.setFromDate(
                dt == null ? null : Date(dt.year, dt.month, dt.day),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('auto_sync')),
              value: vm.draft.autoSync,
              onChanged: vm.setAutoSync,
            ),
          ],
        ),
      ],
    );
  }
}
