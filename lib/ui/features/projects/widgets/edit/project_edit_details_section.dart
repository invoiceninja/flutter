import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/core/widgets/assigned_user_picker_field.dart';
import 'package:admin/ui/core/widgets/entity_tags_field.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
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
class _ClientPicker extends StatelessWidget {
  const _ClientPicker({required this.vm});
  final ProjectEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    if (!vm.isCreate) {
      return _LockedClientRow(
        clientId: vm.draft.clientId,
        companyId: companyId,
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

/// Renders the client picker as a read-only InputDecorator-wrapped row
/// matching the surrounding [EntityEditField] chrome — outlined border,
/// floating label, lock-icon suffix to signal the field is server-bound.
/// Tap navigates to the linked client.
class _LockedClientRow extends StatelessWidget {
  const _LockedClientRow({required this.clientId, required this.companyId});
  final String clientId;
  final String companyId;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final tokens = context.inTheme;
    final me = services.auth.session.value?.currentCompany;
    final canView = me?.can('view_client') ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: canView && clientId.isNotEmpty
            ? () => goEntityFullDetail(context, '/clients', clientId)
            : null,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: context.tr('client'),
            suffixIcon: Icon(Icons.lock_outline, size: 18, color: tokens.ink3),
          ),
          child: StreamBuilder<Client?>(
            stream: services.clients.watch(companyId: companyId, id: clientId),
            builder: (context, snap) {
              final c = snap.data;
              final name = c == null
                  ? clientId
                  : (c.displayName.isNotEmpty
                        ? c.displayName
                        : (c.name.isEmpty ? clientId : c.name));
              return Text(name, style: TextStyle(color: tokens.ink));
            },
          ),
        ),
      ),
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
