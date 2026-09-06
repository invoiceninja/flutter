import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/task_status.dart';
import 'package:admin/data/models/domain/user.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_custom_fields_section.dart';
import 'package:admin/ui/core/utils/task_status_colors.dart';
import 'package:admin/ui/core/widgets/entity_tags_field.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/tasks/view_models/task_edit_view_model.dart';
import 'package:admin/ui/features/tasks/widgets/edit/task_edit_times_section.dart';
import 'package:admin/utils/formatting.dart';

/// Form body for the Task edit / create screen. Composes the identity
/// fields, the time-log section (`TaskEditTimesSection`), and the custom
/// fields panel. Renders the invoiced-lockout banner at the top when
/// `vm.draft.isInvoiced`.
///
/// Layout:
/// - **≥1100 px**: two columns. Left (`Expanded`) carries the lockout
///   banner + the time-log section — the time log is the dominant content
///   and earns the wider column. Right (`_sidebarWidth` 360 px) holds the
///   identity fields. Mirror of the task detail layout split.
/// - **<1100 px**: single 800 px-capped centered column, today's shape.
///   Don't widen — the time-entry table's columns are fixed and would look
///   hollow in a wider container.
class TaskEditLayout extends StatelessWidget {
  const TaskEditLayout({super.key, required this.vm, this.formatter});

  final TaskEditViewModel vm;

  /// Threaded down to `TaskEditTimesSection` → `TimeEntryRow` /
  /// `TimeEntryEditorSheet` so the date portions of time-log entries
  /// honor `company.settings.date_format_id`. Null in tests; widgets
  /// fall back to ISO `YYYY-MM-DD`.
  final Formatter? formatter;

  static const double _twoColumnBreakpoint = 1100;
  static const double _sidebarWidth = 360;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final locked = vm.draft.isInvoiced;
        return LayoutBuilder(
          builder: (context, constraints) {
            final twoCol = constraints.maxWidth >= _twoColumnBreakpoint;
            return SingleChildScrollView(
              padding: EdgeInsets.all(InSpacing.lg(context)),
              child: twoCol ? _wide(context, locked) : _narrow(context, locked),
            );
          },
        );
      },
    );
  }

  Widget _wide(BuildContext context, bool locked) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (locked) ...[
                _LockoutBanner(),
                SizedBox(height: InSpacing.lg(context)),
              ],
              TaskEditTimesSection(
                vm: vm,
                locked: locked,
                formatter: formatter,
              ),
            ],
          ),
        ),
        SizedBox(width: InSpacing.md(context)),
        SizedBox(
          width: _sidebarWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _IdentitySection(vm: vm, locked: locked, formatter: formatter),
              SizedBox(height: InSpacing.lg(context)),
              _CustomFieldsSection(
                vm: vm,
                formatter: formatter,
                locked: locked,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _narrow(BuildContext context, bool locked) {
    return Center(
      child: ConstrainedBox(
        // 820 (not 800) so the time-log table — which renders at ≥800px and
        // needs ~792 — has margin instead of butting against the cap.
        constraints: const BoxConstraints(maxWidth: 820),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (locked) ...[
              _LockoutBanner(),
              SizedBox(height: InSpacing.lg(context)),
            ],
            _IdentitySection(vm: vm, locked: locked, formatter: formatter),
            SizedBox(height: InSpacing.lg(context)),
            _CustomFieldsSection(vm: vm, formatter: formatter, locked: locked),
            SizedBox(height: InSpacing.lg(context)),
            TaskEditTimesSection(vm: vm, locked: locked, formatter: formatter),
          ],
        ),
      ),
    );
  }
}

/// Task custom fields (`task1..4`) — type-aware, gated by the company's
/// configured labels (self-collapses when none). Disabled when the task is
/// invoice-locked, matching the rest of the form.
class _CustomFieldsSection extends StatelessWidget {
  const _CustomFieldsSection({
    required this.vm,
    required this.formatter,
    required this.locked,
  });

  final TaskEditViewModel vm;
  final Formatter? formatter;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final section = EntityCustomFieldsSection(
      keyPrefix: 'task',
      companyStream: context.read<Services>().company.watchCompany(
        vm.companyId,
      ),
      formatter: formatter,
      cardTitle: context.tr('custom_fields'),
      values: [
        vm.draft.customValue1,
        vm.draft.customValue2,
        vm.draft.customValue3,
        vm.draft.customValue4,
      ],
      onChanged: [
        vm.setCustomValue1,
        vm.setCustomValue2,
        vm.setCustomValue3,
        vm.setCustomValue4,
      ],
    );
    return _Lockable(locked: locked, child: section);
  }
}

class _LockoutBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Container(
      padding: EdgeInsets.all(InSpacing.md(context)),
      decoration: BoxDecoration(
        color: tokens.accentSoft,
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(InRadii.r2),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 18, color: tokens.ink),
          const SizedBox(width: InSpacing.sm),
          Expanded(
            child: Text(
              context.tr('task_invoiced_locked'),
              style: TextStyle(color: tokens.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentitySection extends StatelessWidget {
  const _IdentitySection({
    required this.vm,
    required this.locked,
    this.formatter,
  });
  final TaskEditViewModel vm;
  final bool locked;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    // EntityEditScaffold wraps the body in a FormSaveScope already; we
    // pull it off the inherited widget and have each single-line field
    // submit through it on Enter. Multi-line fields (description) leave
    // Enter alone so it inserts a newline.
    final scope = FormSaveScope.maybeOf(context);
    void submit(String _) => scope?.trySubmit();
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(InRadii.r3),
      ),
      padding: EdgeInsets.all(InSpacing.lg(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            initialValue: vm.draft.description,
            enabled: !locked,
            maxLines: 3,
            minLines: 1,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(labelText: context.tr('description')),
            onChanged: vm.setDescription,
          ),
          SizedBox(height: InSpacing.md(context)),
          TextFormField(
            // Server auto-assigns when left blank on create; editable to
            // match admin-portal / React.
            initialValue: vm.draft.number,
            enabled: !locked,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(labelText: context.tr('number')),
            onChanged: vm.setNumber,
            onFieldSubmitted: submit,
            autocorrect: false,
          ),
          SizedBox(height: InSpacing.md(context)),
          _ClientPicker(vm: vm, locked: locked),
          SizedBox(height: InSpacing.md(context)),
          _ProjectPicker(vm: vm, locked: locked),
          SizedBox(height: InSpacing.md(context)),
          _StatusPicker(vm: vm, locked: locked),
          SizedBox(height: InSpacing.md(context)),
          _AssignedUserPicker(vm: vm, locked: locked),
          SizedBox(height: InSpacing.md(context)),
          StreamBuilder<Company?>(
            stream: context.read<Services>().company.watchCompany(vm.companyId),
            builder: (context, snap) {
              final defaultRate = snap.data?.settings.defaultTaskRate ?? 0.0;
              final showHint = vm.draft.rate == Decimal.zero && defaultRate > 0;
              return TextFormField(
                initialValue: decimalInputText(vm.draft.rate),
                enabled: !locked,
                textInputAction: TextInputAction.done,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: context.tr('rate'),
                  // Surface the inherited company default so leaving rate
                  // blank is clearly "bill at the default" — the cascade
                  // (resolveTaskRate) applies it on invoice.
                  helperText: showHint
                      ? '${context.tr('default_task_rate')}: '
                            '${formatter?.money(Decimal.parse(defaultRate.toString())) ?? defaultRate}'
                      : null,
                ),
                onChanged: vm.setRate,
                onFieldSubmitted: submit,
              );
            },
          ),
          SizedBox(height: InSpacing.md(context)),
          EntityTagsField(
            entityType: 'task',
            selectedIds: vm.draft.tagIds,
            onChanged: vm.setTagIds,
            enabled: !locked,
          ),
        ],
      ),
    );
  }
}

/// Searchable client picker. Pulls the first 5000 active clients from
/// Drift; type to filter. Mirrors the React app's "Client" combobox on
/// Task edit.
///
/// Two locked-out states:
///   * [locked] true (invoiced task) — the whole form is read-only; keep
///     the dropdown but disable it via IgnorePointer + Opacity.
///   * Project selected (`vm.draft.projectId.isNotEmpty`) — picking a
///     project derives the client; render a clearly-locked read-only
///     row with a lock icon + helper text instead of a dropdown so the
///     user understands WHY they can't edit the client.
class _ClientPicker extends StatelessWidget {
  const _ClientPicker({required this.vm, required this.locked});

  final TaskEditViewModel vm;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final tokens = context.inTheme;
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final lockedByProject = vm.draft.projectId.isNotEmpty;

    if (lockedByProject) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: context.tr('client'),
          helperText: context.tr('project_drives_client'),
          suffixIcon: Icon(Icons.lock_outline, size: 18, color: tokens.ink3),
        ),
        child: StreamBuilder<Client?>(
          stream: services.clients.watch(
            companyId: companyId,
            id: vm.draft.clientId,
          ),
          builder: (context, snap) {
            final c = snap.data;
            final name = c == null
                ? vm.draft.clientId
                : (c.displayName.isNotEmpty
                      ? c.displayName
                      : (c.name.isEmpty ? vm.draft.clientId : c.name));
            return Text(name, style: TextStyle(color: tokens.ink));
          },
        ),
      );
    }

    return StreamBuilder<List<Client>>(
      stream: services.clients.watchPage(
        companyId: companyId,
        loadedPages: 100, // ≈5000 clients — sufficient for the v1 picker.
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
        return _Lockable(
          locked: locked,
          child: SearchableDropdownField<Client>(
            label: context.tr('client'),
            items: clients,
            initialValue: selected,
            displayString: (c) => c.displayName.isEmpty
                ? (c.name.isEmpty ? c.id : c.name)
                : c.displayName,
            idOf: (c) => c.id,
            onChanged: (c) => vm.setClientId(c?.id ?? ''),
          ),
        );
      },
    );
  }
}

/// Searchable project picker. Streams projects filtered by the currently
/// selected client; picking a project propagates clientId + auto-fills the
/// rate (when current rate is zero) via [TaskEditViewModel.selectProject].
class _ProjectPicker extends StatelessWidget {
  const _ProjectPicker({required this.vm, required this.locked});

  final TaskEditViewModel vm;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    // Empty client → no projects to choose from; render a disabled picker
    // so the form layout doesn't shift when the user does pick a client.
    return StreamBuilder<List<Project>>(
      stream: vm.draft.clientId.isEmpty
          ? const Stream<List<Project>>.empty()
          : services.projects.watchForClient(
              companyId: companyId,
              clientId: vm.draft.clientId,
            ),
      builder: (context, snapshot) {
        final projects = snapshot.data ?? const <Project>[];
        Project? selected;
        for (final p in projects) {
          if (p.id == vm.draft.projectId) {
            selected = p;
            break;
          }
        }
        final empty = vm.draft.clientId.isEmpty;
        final tokens = context.inTheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Lockable(
              locked: locked || empty,
              child: SearchableDropdownField<Project>(
                label: context.tr('project'),
                items: projects,
                initialValue: selected,
                displayString: (p) => p.name.isEmpty ? p.id : p.name,
                idOf: (p) => p.id,
                onChanged: vm.selectProject,
              ),
            ),
            // Helper line that explains why the picker is greyed out when
            // no client is set. Tucked under the field at the same offset
            // an InputDecoration's `helperText` would use.
            if (empty && !locked)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 0),
                child: Text(
                  context.tr('select_a_client_first'),
                  style: TextStyle(fontSize: 12, color: tokens.ink3),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Searchable status picker. Reads `services.taskStatuses.watchAll`.
class _StatusPicker extends StatelessWidget {
  const _StatusPicker({required this.vm, required this.locked});

  final TaskEditViewModel vm;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    return StreamBuilder<List<TaskStatus>>(
      stream: services.taskStatuses.watchAll(companyId: companyId),
      builder: (context, snapshot) {
        final statuses = snapshot.data ?? const <TaskStatus>[];
        TaskStatus? selected;
        for (final s in statuses) {
          if (s.id == vm.draft.statusId) {
            selected = s;
            break;
          }
        }
        return _Lockable(
          locked: locked,
          child: SearchableDropdownField<TaskStatus>(
            label: context.tr('status'),
            items: statuses,
            initialValue: selected,
            displayString: (s) => s.name.isEmpty ? s.id : s.name,
            idOf: (s) => s.id,
            // Same dot the list pill, kanban header and settings rows use, so
            // the picker reads like the rest of the task UI.
            optionLeadingBuilder: (context, status) => Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: taskStatusColors(
                  context,
                  name: status.name,
                  color: status.color,
                ).fg,
                shape: BoxShape.circle,
              ),
            ),
            onChanged: (s) => vm.setStatusId(s?.id ?? ''),
          ),
        );
      },
    );
  }
}

/// Searchable assigned-user picker. Reads `services.user.watchPage` —
/// mirrors the kanban filter bar's assignee picker.
class _AssignedUserPicker extends StatelessWidget {
  const _AssignedUserPicker({required this.vm, required this.locked});

  final TaskEditViewModel vm;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    return StreamBuilder<List<User>>(
      stream: services.user.watchPage(companyId: companyId, loadedPages: 100),
      builder: (context, snapshot) {
        final users = snapshot.data ?? const <User>[];
        User? selected;
        for (final u in users) {
          if (u.id == vm.draft.assignedUserId) {
            selected = u;
            break;
          }
        }
        return _Lockable(
          locked: locked,
          child: SearchableDropdownField<User>(
            label: context.tr('assigned_user'),
            items: users,
            initialValue: selected,
            displayString: (u) => u.displayName.isEmpty ? u.id : u.displayName,
            idOf: (u) => u.id,
            onChanged: (u) => vm.setAssignedUserId(u?.id ?? ''),
          ),
        );
      },
    );
  }
}

/// Greys out and disables a field on an invoiced (or not-yet-applicable) task.
///
/// `IgnorePointer` alone isn't enough: it only overrides hit testing, so Tab
/// still reaches the widget, and a picker that has focus can be driven entirely
/// from the keyboard — arrow to another option, Enter, and the draft is edited
/// on a record the server will reject.
class _Lockable extends StatelessWidget {
  const _Lockable({required this.locked, required this.child});

  final bool locked;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;
    return ExcludeFocus(
      child: IgnorePointer(child: Opacity(opacity: 0.5, child: child)),
    );
  }
}
