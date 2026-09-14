import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/core/widgets/assigned_user_picker_field.dart';
import 'package:admin/ui/core/widgets/entity_tags_field.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
import 'package:admin/ui/core/widgets/locked_entity_field_row.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/projects/view_models/project_edit_view_model.dart';
import 'package:admin/ui/features/projects/widgets/edit/color_field.dart';

/// Identity + client + assignment + due date + color. Always rendered.
class ProjectEditDetailsSection extends StatelessWidget {
  const ProjectEditDetailsSection({super.key, required this.vm});
  final ProjectEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    return DashboardCardShell(
      title: context.tr('details'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          EntityEditField(
            label: context.tr('name'),
            initial: vm.draft.name,
            onChanged: vm.setName,
            autofocus: vm.isCreate,
            errorText: vm.fieldErrorFor('name'),
          ),
          // Number is server-assigned on first save and immutable afterwards
          // (the server owns the sequence; allowing edits can collide).
          // Surfaced read-only on existing projects so users can copy it.
          if (!vm.isCreate)
            EntityEditField(
              label: context.tr('number'),
              initial: vm.draft.number,
              onChanged: (_) {},
              readOnly: true,
            ),
          _ClientPicker(vm: vm),
          AssignedUserPickerField(
            companyId: vm.companyId,
            selectedId: vm.draft.assignedUserId,
            onChanged: vm.setAssignedUserId,
          ),
          _DueDateField(vm: vm),
          ColorField(initial: vm.draft.color, onChanged: vm.setColor),
          EntityTagsField(
            entityType: 'project',
            selectedIds: vm.draft.tagIds,
            onChanged: vm.setTagIds,
          ),
        ],
      ),
    );
  }
}

/// Searchable client picker for new projects; locked tap-to-navigate row
/// once the project exists (matches React's `ClientActionButtons`).
///
/// The server's variant of the freeze is the *silent* one —
/// `UpdateProjectRequest::prepareForValidation` overwrites
/// `$input['client_id'] = $this->project->client_id` with no 422 at all, so a
/// change appears to work and then snaps back on the next sync. The UI lock is
/// the only signal the user ever gets — which is also why the gate is
/// `!vm.isCreate` with no empty-id fall-through: `validate()` here returns
/// `const {}` on an edit, so an empty client would have handed the user a live
/// picker whose every edit the server discards without a word.
class _ClientPicker extends StatelessWidget {
  const _ClientPicker({required this.vm});
  final ProjectEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    if (!vm.isCreate) {
      return LockedClientFieldRow(
        clientId: vm.draft.clientId,
        helperText: context.tr('locked_after_save_clone'),
        errorText: vm.fieldErrorFor('client_id'),
      );
    }
    return StreamBuilder<List<Client>>(
      stream: services.clients.watchPage(
        companyId: companyId,
        loadedPages: 100,
      ),
      builder: (context, snapshot) {
        final clients = snapshot.data ?? const <Client>[];
        Client? selected;
        for (final c in clients) {
          if (c.id == vm.draft.clientId) {
            selected = c;
            break;
          }
        }
        return SearchableDropdownField<Client>(
          label: context.tr('client'),
          items: clients,
          initialValue: selected,
          displayString: (c) => c.displayName.isEmpty
              ? (c.name.isEmpty ? c.id : c.name)
              : c.displayName,
          idOf: (c) => c.id,
          onChanged: (c) {
            vm.setClientId(c?.id ?? '');
            // Apply the client's default task rate when one is set (React's
            // client resolver). Leaves the existing rate untouched otherwise.
            final raw = c?.settings?['default_task_rate'];
            final rate = raw is num ? raw.toDouble() : null;
            if (rate != null && rate > 0) {
              vm.setTaskRate(rate.toString());
            }
          },
          errorText: vm.fieldErrorFor('client_id'),
        );
      },
    );
  }
}

/// Project due-date input — typed shortcuts (`today`, `+7`, `5/14`)
/// plus the calendar picker fallback via the shared [InDateField].
///
/// Stateful so it can resolve a company [Formatter] via
/// [FormatterHostMixin]; the formatter drives the displayed value's
/// date layout (e.g. `May 14, 2026` vs ISO). Without it the field would
/// fall back to `2026-05-14`, which is a regression from the old code's
/// locale-aware rendering.
class _DueDateField extends StatefulWidget {
  const _DueDateField({required this.vm});
  final ProjectEditViewModel vm;

  @override
  State<_DueDateField> createState() => _DueDateFieldState();
}

class _DueDateFieldState extends State<_DueDateField> with FormatterHostMixin {
  late final Services _services;
  late String _companyId;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    loadFormatter(_services, _companyId);
    _services.auth.session.addListener(_onSessionChanged);
  }

  void _onSessionChanged() {
    final s = _services.auth.session.value;
    if (s == null || s.currentCompanyId == _companyId) return;
    _companyId = s.currentCompanyId;
    clearFormatter();
    loadFormatter(_services, _companyId);
  }

  @override
  void dispose() {
    _services.auth.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.vm.draft.dueDate;
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InDateField(
        value: value?.toDateTime(),
        onChanged: (picked) {
          if (picked == null) {
            widget.vm.setDueDate(null);
          } else {
            widget.vm.setDueDate(Date(picked.year, picked.month, picked.day));
          }
        },
        formatter: formatter,
        labelText: context.tr('due_date'),
        firstDate: DateTime(now.year - 5),
        lastDate: DateTime(now.year + 10),
        clearable: true,
      ),
    );
  }
}
