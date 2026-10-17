import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/token.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_entity_edit_scaffold.dart';
import 'package:admin/ui/features/settings/widgets/settings_text_field.dart';
import 'package:admin/ui/features/tokens/view_models/token_edit_view_model.dart';
import 'package:admin/ui/features/tokens/widgets/token_secret_field.dart';
import 'package:admin/utils/formatting.dart';

/// `/settings/account_management/integrations/api_tokens/new` and `/.../:id`. Edit is
/// name-only — `token`, `is_system`, and `user_id` are server-owned.
///
/// On create, the server mints the raw bearer secret and the shell's
/// `SyncEventListener` surfaces it via `TokenCreatedDialog` when the create
/// syncs; after Save this screen just pops back to the list. A saved token's
/// secret can be shown or copied again here, through [TokenSecretField].
class TokenEditScreen extends StatelessWidget {
  const TokenEditScreen({this.existingId, super.key});

  final String? existingId;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final session = services.auth.session.value;
    final companyId = session?.currentCompanyId ?? '';
    final endpoint = cleanApiUrl(session?.baseUrl);
    final repo = services.tokens;

    return SettingsEntityEditScaffold<Token, TokenEditViewModel>(
      existingId: existingId,
      backRoute: '/settings/account_management/integrations/api_tokens',
      createTitleKey: 'new_token',
      editTitleKey: 'edit_token',
      wireName: 'token',
      watchById: (id) => repo.watch(companyId: companyId, id: id),
      refreshAll: () => repo.refreshAll(companyId: companyId),
      onArchive: (id) => repo.archive(companyId: companyId, id: id),
      onRestore: (id) => repo.restore(companyId: companyId, id: id),
      onDelete: (id) => repo.delete(companyId: companyId, id: id),
      vmFactory: ({existing}) => TokenEditViewModel(
        repo: repo,
        companyId: companyId,
        existing: existing,
        sync: services.sync,
        connectivity: services.connectivity,
      ),
      isArchivedOf: (t) => t.archivedAt != null,
      isDeletedOf: (t) => t.isDeleted,
      canSave: (vm) =>
          !vm.isSaving && vm.isDirty && vm.draft.name.trim().isNotEmpty,
      bodyBuilder: (context, vm) {
        final saved = vm.original;
        return [
          FormSection(
            title: context.tr('token'),
            children: [
              SettingsTextField(
                initialValue: vm.draft.name,
                labelKey: 'name',
                onChanged: vm.setName,
                errorText: vm.fieldErrorFor('name'),
                textInputAction: TextInputAction.done,
                externalSyncKey: saved?.id,
              ),
              // Shown for an unsynced token too: the view model keeps the
              // `tmp_` id it opened with even after the create lands, and
              // `fetchSecret` resolves it at tap time.
              if (saved != null && !saved.isDeleted) ...[
                TokenSecretField(
                  key: ValueKey(saved.id),
                  hint: saved.obscuredHint,
                  fetchSecret: () =>
                      repo.fetchSecret(companyId: companyId, id: saved.id),
                ),
                if (endpoint.isNotEmpty) TokenEndpointField(url: endpoint),
              ],
            ],
          ),
        ];
      },
    );
  }
}
