import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/webhook.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_entity_edit_scaffold.dart';
import 'package:admin/ui/features/settings/widgets/settings_text_field.dart';
import 'package:admin/ui/features/webhooks/view_models/webhook_edit_view_model.dart';
import 'package:admin/ui/features/webhooks/widgets/webhook_headers_editor.dart';

/// `/settings/account_management/integrations/api_webhooks/new` and `/.../:id`.
class WebhookEditScreen extends StatelessWidget {
  const WebhookEditScreen({this.existingId, super.key});

  final String? existingId;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final repo = services.webhooks;

    return SettingsEntityEditScaffold<Webhook, WebhookEditViewModel>(
      existingId: existingId,
      backRoute: '/settings/account_management/integrations/api_webhooks',
      createTitleKey: 'new_webhook',
      editTitleKey: 'edit_webhook',
      wireName: 'webhook',
      watchById: (id) => repo.watch(companyId: companyId, id: id),
      refreshAll: () => repo.refreshAll(companyId: companyId),
      onArchive: (id) => repo.archive(companyId: companyId, id: id),
      onRestore: (id) => repo.restore(companyId: companyId, id: id),
      onDelete: (id) => repo.delete(companyId: companyId, id: id),
      vmFactory: ({existing}) => WebhookEditViewModel(
        repo: repo,
        companyId: companyId,
        existing: existing,
        sync: services.sync,
        connectivity: services.connectivity,
      ),
      isArchivedOf: (w) => w.archivedAt != null,
      isDeletedOf: (w) => w.isDeleted,
      canSave: (vm) =>
          !vm.isSaving &&
          vm.isDirty &&
          vm.draft.targetUrl.trim().isNotEmpty &&
          vm.draft.eventId.isNotEmpty,
      bodyBuilder: (context, vm) => [
        FormSection(
          title: context.tr('webhook'),
          children: [
            SettingsTextField(
              initialValue: vm.draft.targetUrl,
              labelKey: 'target_url',
              onChanged: vm.setTargetUrl,
              errorText: vm.fieldErrorFor('target_url'),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              externalSyncKey: vm.original?.id,
            ),
            const SizedBox(height: 8),
            SearchableDropdownField<String>(
              label: context.tr('event_type'),
              initialValue: vm.draft.eventId.isEmpty ? null : vm.draft.eventId,
              items: kWebhookEventNames.keys.toList(growable: false),
              displayString: (id) => context.tr(kWebhookEventNames[id] ?? id),
              idOf: (id) => id,
              onChanged: (id) => vm.setEventId(id ?? ''),
              errorText: vm.fieldErrorFor('event_id'),
            ),
            const SizedBox(height: 8),
            _RestMethodSelector(vm: vm),
          ],
        ),
        FormSection(
          title: context.tr('headers'),
          children: [WebhookHeadersEditor(vm: vm)],
        ),
      ],
    );
  }
}

class _RestMethodSelector extends StatelessWidget {
  const _RestMethodSelector({required this.vm});
  final WebhookEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '${context.tr('rest_method')}:',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SegmentedButton<String>(
            segments: [
              for (final m in kWebhookRestMethods)
                ButtonSegment(value: m, label: Text(m.toUpperCase())),
            ],
            selected: {vm.draft.restMethod},
            onSelectionChanged: (set) =>
                set.isEmpty ? null : vm.setRestMethod(set.first),
          ),
        ),
      ],
    );
  }
}
