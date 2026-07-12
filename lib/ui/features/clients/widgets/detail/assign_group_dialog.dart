import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/group_setting.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';

/// Outcome of [showAssignGroupDialog].
class AssignGroupResult {
  const AssignGroupResult({required this.changed, required this.groupId});

  /// True when the user picked a different group than what the client
  /// already has (including switching to "(none)"). False if they
  /// cancelled or picked the existing value.
  final bool changed;

  /// New group id (empty string for "(none)"). Null when [changed] is
  /// false.
  final String? groupId;
}

/// Open the Assign Group picker. Returns a result describing whether the
/// user changed the assignment and to what — caller is responsible for
/// the actual save (so a failure can surface against the client detail
/// screen, not the dialog).
Future<AssignGroupResult> showAssignGroupDialog(
  BuildContext context, {
  required Client client,
  required Services services,
  required String companyId,
}) async {
  final result = await showDialog<AssignGroupResult>(
    context: context,
    builder: (_) => _AssignGroupDialog(
      client: client,
      services: services,
      companyId: companyId,
    ),
  );
  return result ?? const AssignGroupResult(changed: false, groupId: null);
}

class _AssignGroupDialog extends StatefulWidget {
  const _AssignGroupDialog({
    required this.client,
    required this.services,
    required this.companyId,
  });

  final Client client;
  final Services services;
  final String companyId;

  @override
  State<_AssignGroupDialog> createState() => _AssignGroupDialogState();
}

class _AssignGroupDialogState extends State<_AssignGroupDialog> {
  late String _selectedId = widget.client.groupSettingsId;

  bool get _canAssign => _selectedId != widget.client.groupSettingsId;

  void _onAssign() {
    if (!_canAssign) return;
    Navigator.of(
      context,
    ).pop(AssignGroupResult(changed: true, groupId: _selectedId));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('assign_group')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: StreamBuilder<List<GroupSetting>>(
          stream: widget.services.groupSettings.watchAll(
            companyId: widget.companyId,
          ),
          builder: (context, snapshot) {
            final groups = snapshot.data ?? const <GroupSetting>[];
            final currentName = _resolveName(
              groups,
              widget.client.groupSettingsId,
            );

            return FormSaveScope(
              onSubmit: _onAssign,
              enabled: _canAssign,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header line — what's currently assigned. Renders even
                  // when groups are loading so the dialog is never empty
                  // on first frame.
                  Text(
                    '${context.tr('current_group')}: $currentName',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.inTheme.ink3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (groups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(context.tr('no_groups_yet')),
                    )
                  else
                    _GroupPicker(
                      groups: groups,
                      selectedId: _selectedId,
                      onChanged: (id) => setState(() => _selectedId = id),
                    ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(context.tr('new_group')),
                      onPressed: () {
                        // Capture the router before pop — the dialog's
                        // BuildContext is unmounted once Navigator.pop runs,
                        // so calling context.go(...) after pop throws in
                        // debug ("deactivated widget's ancestor").
                        final router = GoRouter.of(context);
                        Navigator.of(context).pop(
                          const AssignGroupResult(
                            changed: false,
                            groupId: null,
                          ),
                        );
                        router.go('/settings/group_settings/new');
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
          onPressed: () => Navigator.of(
            context,
          ).pop(const AssignGroupResult(changed: false, groupId: null)),
          child: Text(context.tr('cancel')),
        ),
        PrimaryDialogAction(
          label: context.tr('assign'),
          enabled: _canAssign,
          // Dropdown picker: Enter selects an option, it doesn't submit —
          // so no Enter hint.
          autofocus: false,
          showEnterHint: false,
          onPressed: _onAssign,
        ),
      ],
    );
  }

  String _resolveName(List<GroupSetting> groups, String id) {
    if (id.isEmpty) return context.tr('unassigned');
    for (final g in groups) {
      if (g.id == id) return g.name.isEmpty ? context.tr('untitled') : g.name;
    }
    return context.tr('unassigned');
  }
}

/// Sentinel wrapper used so "(none)" can sit alongside real groups in the
/// dropdown without forcing the field to be nullable everywhere.
class _GroupOption {
  const _GroupOption(this.group);
  final GroupSetting? group;

  String get id => group?.id ?? '';
  String displayString(BuildContext context) =>
      group?.name ?? context.tr('none');
}

class _GroupPicker extends StatelessWidget {
  const _GroupPicker({
    required this.groups,
    required this.selectedId,
    required this.onChanged,
  });

  final List<GroupSetting> groups;
  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = <_GroupOption>[
      const _GroupOption(null),
      for (final g in groups) _GroupOption(g),
    ];
    final current = items.firstWhere(
      (o) => o.id == selectedId,
      orElse: () => const _GroupOption(null),
    );
    return SearchableDropdownField<_GroupOption>(
      label: context.tr('group'),
      items: items,
      initialValue: current,
      displayString: (o) => o.displayString(context),
      idOf: (o) => o.id,
      onChanged: (o) => onChanged(o?.id ?? ''),
    );
  }
}
