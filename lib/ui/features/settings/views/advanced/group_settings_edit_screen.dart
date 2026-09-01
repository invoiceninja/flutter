import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/group_setting.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/build_standard_documents_tab.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/features/clients/views/client_list_screen.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/view_models/group_setting_edit_view_model.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_entity_edit_scaffold.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';
import 'package:admin/ui/features/settings/widgets/settings_text_field.dart';

/// `/settings/group_settings/new` and `/settings/group_settings/:id`.
///
/// Create mode shows the Overview form alone. Edit mode wraps it in a
/// three-tab shell (Overview / Clients / Documents) mirroring React's group
/// edit screen. Lifecycle, AppBar, and the archive/restore/delete overflow
/// are owned by [SettingsEntityEditScaffold]; the tabbed body rides
/// `customBodyBuilder`.
///
/// Like React and the legacy app, the only field edited directly on the
/// group is its **name** — every cascade setting (currency, language,
/// country, …) is configured via "Configure Settings", which switches the
/// settings shell into group scope.
class GroupSettingsEditScreen extends StatelessWidget {
  const GroupSettingsEditScreen({this.existingId, super.key});

  final String? existingId;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final repo = services.groupSettings;

    return SettingsEntityEditScaffold<GroupSetting, GroupSettingEditViewModel>(
      existingId: existingId,
      backRoute: '/settings/group_settings',
      createTitleKey: 'new_group',
      editTitleKey: 'edit_group',
      wireName: 'group',
      watchById: (id) => repo.watch(companyId: companyId, id: id),
      refreshAll: () => repo.refreshAll(companyId: companyId),
      onArchive: (id) => repo.archive(companyId: companyId, id: id),
      onRestore: (id) => repo.restore(companyId: companyId, id: id),
      onDelete: (id) => repo.delete(companyId: companyId, id: id),
      vmFactory: ({existing}) => GroupSettingEditViewModel(
        repo: repo,
        companyId: companyId,
        existing: existing,
        sync: services.sync,
        connectivity: services.connectivity,
      ),
      isArchivedOf: (g) => g.archivedAt != null,
      isDeletedOf: (g) => g.isDeleted,
      // Gated on `isSaving` (mutually exclusive submits), `isDirty` (a no-op
      // save would still enqueue an outbox row and bump `updated_at`), and a
      // valid name — the server requires `name` present + unique on create.
      canSave: (vm) => !vm.isSaving && vm.isDirty && vm.nameIsValid,
      // Create mode: the Overview form alone (width-capped). Edit mode: the
      // 3-tab shell, which needs a saved group id (Clients/Documents).
      customBodyBuilder: (context, vm) => vm.isCreate
          ? SettingsFormShell(sections: _overviewSections(context, vm))
          : _GroupEditTabs(
              vm: vm,
              companyId: companyId,
              groupId: vm.original!.id,
            ),
    );
  }
}

/// Edit-mode body: the Overview / Clients / Documents tab shell. A
/// `StatefulWidget` so it can (a) fire a one-time documents refresh on open
/// and (b) feed the Documents tab from a **live** Drift watch rather than the
/// frozen edit-VM `draft` — uploads/deletes must appear immediately.
class _GroupEditTabs extends StatefulWidget {
  const _GroupEditTabs({
    required this.vm,
    required this.companyId,
    required this.groupId,
  });

  final GroupSettingEditViewModel vm;
  final String companyId;
  final String groupId;

  @override
  State<_GroupEditTabs> createState() => _GroupEditTabsState();
}

class _GroupEditTabsState extends State<_GroupEditTabs> {
  @override
  void initState() {
    super.initState();
    // Documents aren't carried by the /login+/refresh bundle, and the list's
    // delta refresh skips already-synced groups — a full refresh
    // (include=documents) is what pulls this group's attachments into Drift.
    // Fire-and-forget; also covers a deep-link / app-restart-restore here.
    unawaited(
      context.read<Services>().groupSettings.refreshAll(
        companyId: widget.companyId,
        full: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final vm = widget.vm;
    final id = widget.groupId;
    return WatchBuilder<GroupSetting?>(
      cacheKey: (widget.companyId, id),
      create: () =>
          services.groupSettings.watch(companyId: widget.companyId, id: id),
      initialData: vm.original,
      builder: (context, snapshot) {
        final documents = (snapshot.data ?? vm.original!).documents;
        return EntityDetailTabs(
          tabs: [
            EntityDetailTab(
              label: context.tr('overview'),
              icon: Icons.tune_outlined,
              bodyBuilder: (_) =>
                  SettingsFormShell(sections: _overviewSections(context, vm)),
            ),
            EntityDetailTab(
              label: context.tr('clients'),
              icon: Icons.people_outline,
              bodyBuilder: (_) =>
                  ClientListScreen(groupSettingsId: id, embedded: true),
            ),
            buildStandardDocumentsTab(
              context: context,
              companyId: widget.companyId,
              entityId: id,
              documents: documents,
              repo: services.groupSettings,
            ),
          ],
        );
      },
    );
  }
}

List<Widget> _overviewSections(
  BuildContext context,
  GroupSettingEditViewModel vm,
) => [
  FormSection(
    title: context.tr('group'),
    children: [
      SettingsTextField(
        initialValue: vm.draft.name,
        labelKey: 'name',
        onChanged: vm.setName,
        // Server 422 on `name` wins; otherwise the client-side duplicate
        // check (create-only) renders inline. A blank name shows no error —
        // the disabled Save button is the cue.
        errorText:
            vm.fieldErrorFor('name') ??
            (vm.nameErrorKey == null ? null : context.tr(vm.nameErrorKey!)),
        externalSyncKey: vm.original?.id,
      ),
    ],
  ),
  // Edit mode only — entering group-scope cascade editing needs a saved
  // group (the cascade VM reads `group.settings` from Drift).
  if (vm.original != null) _ConfigureSettingsSection(vm: vm),
];

/// "Configure Settings" affordance — switches the settings shell into
/// group scope and lands on Localization, mirroring the per-client
/// `ClientAction.settings` flow. Disabled while the Overview form has
/// unsaved edits (they live in a separate draft the cascade VM can't see)
/// or before the group has synced a real id.
class _ConfigureSettingsSection extends StatelessWidget {
  const _ConfigureSettingsSection({required this.vm});
  final GroupSettingEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final group = vm.original!;
    final canConfigure = !vm.isDirty && !group.id.startsWith('tmp_');
    return FormSection(
      title: context.tr('settings'),
      children: [
        ListTile(
          leading: const Icon(Icons.tune),
          title: Text(context.tr('configure_settings')),
          subtitle: vm.isDirty ? Text(context.tr('unsaved_changes')) : null,
          trailing: const Icon(Icons.chevron_right),
          enabled: canConfigure,
          onTap: canConfigure
              ? () {
                  context.read<Services>().settingsLevel.setLevel(
                    SettingsLevel.group,
                    targetId: group.id,
                    targetName: group.name,
                  );
                  context.go('/settings/localization');
                }
              : null,
        ),
      ],
    );
  }
}
