import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/view_models/task_settings_view_model.dart';
import 'package:admin/ui/features/settings/widgets/cascade_settings_scaffold.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/overridable_dropdown_field.dart';
import 'package:admin/ui/features/settings/widgets/overridable_field.dart';
import 'package:admin/ui/features/settings/widgets/overridable_number_field.dart';
import 'package:admin/ui/features/settings/widgets/overridable_switch_field.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';
import 'package:admin/ui/features/settings/widgets/settings_switch_tile.dart';

/// Searchable label keys rendered by this screen. Aggregated into
/// `kSettingsSearchCatalog['task_settings']` so the in-app search surfaces
/// these fields. `search_catalog_consistency_test` verifies every key here
/// appears as a `context.tr('…')` reference in this file.
const kTaskSettingsSearchKeys = <String>[
  'default_task_rate',
  'auto_start_tasks',
  'show_task_end_date',
  'show_task_item_description',
  'show_task_billable',
  'configure_statuses',
  'round_tasks',
  'direction',
  'task_round_to_nearest',
  'round_to_seconds',
  'show_tasks_table',
  'invoice_task_datelog',
  'invoice_task_timelog',
  'invoice_task_hours',
  'invoice_task_item_description',
  'invoice_task_project',
  'project_location',
  'lock_invoiced_tasks',
  'add_documents_to_invoice',
  'show_tasks_in_client_portal',
  'tasks_shown_in_portal',
];

/// Preset values (seconds) the granularity dropdown offers besides the
/// `Custom` sentinel (`0`). Mirrors admin-portal `kTaskRoundingOptions`.
const Set<int> _kPresetSeconds = {60, 300, 900, 1800, 3600, 86400};

/// Settings → Task Settings. Mixes top-level `company.*` toggles (auto
/// start, invoice task options, lock, documents) with cascade
/// `company.settings.*` fields (default rate, rounding, client portal).
///
/// Style: `CascadeSettingsScaffold` (like Localization / Tax Settings) so
/// the cascade fields write to the right entity at every scope — the
/// company's own settings at company scope, the client/group override blob
/// otherwise. The top-level `company.*` toggles are company-level only:
/// they render only inside `if (isCompanyScope)` and read/write via
/// `host.draft` / `host.updateCompany`, which resolve to the company VM at
/// company scope (where alone they appear). `Overridable*` widgets render
/// plain at company scope and show the override checkbox at client/group
/// scope.
class TaskSettingsScreen extends StatelessWidget {
  const TaskSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CascadeSettingsScaffold(
      titleKey: 'task_settings',
      companyVmFactory: ({required repo, required companyId}) =>
          TaskSettingsViewModel(repo: repo, companyId: companyId),
      body: const _TaskSettingsBody(),
    );
  }
}

class _TaskSettingsBody extends StatelessWidget {
  const _TaskSettingsBody();

  @override
  Widget build(BuildContext context) {
    final host = context.watch<SettingsDraftHost>();
    final scope = context.watch<SettingsLevelController>();

    final isCompanyScope = scope.isCompany;
    final settings = host.settings;

    return SettingsFormShell(
      sections: [
        FormSection(
          title: context.tr('tasks'),
          children: [
            // `default_task_rate` is `double?`. We use `OverridableNumberField`
            // (not `OverridableCurrencyField`) because the currency field needs
            // a synchronous `Formatter` (async bootstrap); the number field
            // renders empty-for-zero and strips the trailing `.0` without it.
            // Matches `online_payments_general_body.dart`'s payment minimums.
            OverridableNumberField(
              label: context.tr('default_task_rate'),
              apiKey: 'default_task_rate',
            ),
            if (isCompanyScope) ...[
              SettingsSwitchTile(
                label: context.tr('auto_start_tasks'),
                help: context.tr('auto_start_tasks_help'),
                value: host.draft?.autoStartTasks ?? false,
                onChanged: (v) =>
                    host.updateCompany((c) => c.copyWith(autoStartTasks: v)),
              ),
              SettingsSwitchTile(
                label: context.tr('show_task_end_date'),
                help: context.tr('show_task_end_date_help'),
                value: host.draft?.showTaskEndDate ?? false,
                onChanged: (v) =>
                    host.updateCompany((c) => c.copyWith(showTaskEndDate: v)),
              ),
            ],
            OverridableSwitchField(
              label: context.tr('show_task_item_description'),
              apiKey: 'show_task_item_description',
              subtitle: context.tr('show_task_item_description_help'),
            ),
            OverridableSwitchField(
              label: context.tr('show_task_billable'),
              apiKey: 'allow_billable_task_items',
              subtitle: context.tr('allow_billable_task_items_help'),
            ),
            // Task statuses are a company-level list, so this nav button is
            // company-scope only. It lives here rather than in the Rounding
            // card (where it used to sit) because statuses belong to tasks in
            // general, not to rounding — invoiceninja/flutter#55. Mirrors
            // "Configure payment terms" at the foot of Online Payments →
            // Defaults. Note `/settings/task_statuses` has no settings-sidebar
            // row, so this is the screen's only entry point.
            if (isCompanyScope) ...[
              const Divider(height: 1),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/settings/task_statuses'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 40),
                  ),
                  icon: const Icon(Icons.label_outlined, size: 18),
                  label: Text(context.tr('configure_statuses')),
                ),
              ),
            ],
          ],
        ),
        const _RoundingSection(),
        if (isCompanyScope)
          FormSection(
            title: context.tr('invoicing'),
            children: [
              SettingsSwitchTile(
                label: context.tr('show_tasks_table'),
                help: context.tr('show_tasks_table_help'),
                value: host.draft?.showTasksTable ?? false,
                onChanged: (v) =>
                    host.updateCompany((c) => c.copyWith(showTasksTable: v)),
              ),
              SettingsSwitchTile(
                label: context.tr('invoice_task_datelog'),
                help: context.tr('invoice_task_datelog_help'),
                value: host.draft?.invoiceTaskDatelog ?? false,
                onChanged: (v) => host.updateCompany(
                  (c) => c.copyWith(invoiceTaskDatelog: v),
                ),
              ),
              SettingsSwitchTile(
                label: context.tr('invoice_task_timelog'),
                help: context.tr('invoice_task_timelog_help'),
                value: host.draft?.invoiceTaskTimelog ?? false,
                onChanged: (v) => host.updateCompany(
                  (c) => c.copyWith(invoiceTaskTimelog: v),
                ),
              ),
              SettingsSwitchTile(
                label: context.tr('invoice_task_hours'),
                help: context.tr('invoice_task_hours_help'),
                value: host.draft?.invoiceTaskHours ?? false,
                onChanged: (v) =>
                    host.updateCompany((c) => c.copyWith(invoiceTaskHours: v)),
              ),
              // Render disabled-with-tooltip when the cascade field gating
              // this row isn't enabled — fewer layout jumps than hide/show.
              SettingsSwitchTile(
                label: context.tr('invoice_task_item_description'),
                help: context.tr('invoice_task_item_description_help'),
                value: host.draft?.invoiceTaskItemDescription ?? false,
                enabled: settings.showTaskItemDescription == true,
                disabledTooltip: context.tr('show_task_item_description'),
                onChanged: (v) => host.updateCompany(
                  (c) => c.copyWith(invoiceTaskItemDescription: v),
                ),
              ),
              SettingsSwitchTile(
                label: context.tr('invoice_task_project'),
                help: context.tr('invoice_task_project_help'),
                value: host.draft?.invoiceTaskProject ?? false,
                onChanged: (v) => host.updateCompany(
                  (c) => c.copyWith(invoiceTaskProject: v),
                ),
              ),
              _ProjectLocationDropdown(
                value: host.draft?.invoiceTaskProjectHeader ?? false,
                enabled: host.draft?.invoiceTaskProject ?? false,
                onChanged: (v) => host.updateCompany(
                  (c) => c.copyWith(invoiceTaskProjectHeader: v),
                ),
              ),
              SettingsSwitchTile(
                label: context.tr('lock_invoiced_tasks'),
                help: context.tr('lock_invoiced_tasks_help'),
                value: host.draft?.invoiceTaskLock ?? false,
                onChanged: (v) =>
                    host.updateCompany((c) => c.copyWith(invoiceTaskLock: v)),
              ),
              SettingsSwitchTile(
                label: context.tr('add_documents_to_invoice'),
                help: context.tr('add_documents_to_invoice_help'),
                value: host.draft?.invoiceTaskDocuments ?? false,
                onChanged: (v) => host.updateCompany(
                  (c) => c.copyWith(invoiceTaskDocuments: v),
                ),
              ),
            ],
          ),
        FormSection(
          title: context.tr('client_portal'),
          children: [
            OverridableDropdownField<bool>(
              label: context.tr('show_tasks_in_client_portal'),
              apiKey: 'enable_client_portal_tasks',
              // Coalesce to false so a fresh tenant with `null` still
              // renders a valid dropdown selection (otherwise the value
              // is not in items and the widget renders empty).
              value: settings.enableClientPortalTasks ?? false,
              items: [
                DropdownMenuItem(
                  value: true,
                  child: Text(context.tr('enabled')),
                ),
                DropdownMenuItem(
                  value: false,
                  child: Text(context.tr('disabled')),
                ),
              ],
              onChanged: (v) => host.updateSettings(
                (s) => s.copyWith(enableClientPortalTasks: v),
              ),
            ),
            _PortalTasksDropdown(
              value: settings.showAllTasksClientPortal ?? 'invoiced',
              enabled: settings.enableClientPortalTasks == true,
              onChanged: (v) => host.updateSettings(
                (s) => s.copyWith(showAllTasksClientPortal: v),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Rounding card — gated UX (matches old Flutter).
///
/// **Cascade design**: enable + granularity + custom-seconds are one logical
/// field (`task_round_to_nearest`), so they share a single override checkbox
/// at client/group scope. That checkbox lives on the **enable dropdown**
/// (wrapped in `OverridableField`), which is always visible — so a client can
/// opt into overriding rounding even when the inherited value is "off". The
/// granularity dropdown and custom-seconds field are plain widgets
/// `enabled: isOverridden`; they become editable only once the override is on
/// (and only render when rounding is enabled). `task_round_up` (direction) is
/// a separate field with its own override checkbox.
class _RoundingSection extends StatefulWidget {
  const _RoundingSection();

  @override
  State<_RoundingSection> createState() => _RoundingSectionState();
}

class _RoundingSectionState extends State<_RoundingSection> {
  /// Last user-picked granularity seconds, captured before writing the
  /// "disabled" sentinel `1`. Restored when the user re-enables so they
  /// don't lose their prior choice. Defaults to 900 (15 min).
  int _lastEnabledSeconds = 900;

  @override
  Widget build(BuildContext context) {
    final host = context.watch<SettingsDraftHost>();
    final scope = context.watch<SettingsLevelController>();
    final isCompanyScope = scope.isCompany;
    final raw = host.settings.taskRoundToNearest;
    final asInt = raw?.toInt();
    final enabled = raw != null && asInt != 1;
    if (enabled && asInt != null && asInt != 0) {
      // Track the last non-disabled, non-Custom-sentinel value so we can
      // restore it after a disabled→enabled flip.
      _lastEnabledSeconds = asInt;
    }
    final isPresetValue = asInt != null && _kPresetSeconds.contains(asInt);
    final isCustomValue = enabled && (asInt == 0 || !isPresetValue);

    final isOverridden =
        isCompanyScope || host.isOverridden('task_round_to_nearest');

    // Granularity value shown when rounding is enabled (always one of the
    // dropdown items: a preset, or 0 for "Custom").
    final granularitySeconds = isCustomValue
        ? 0
        : (asInt ?? _lastEnabledSeconds);
    // Server-side validation for the rounding field surfaces under the
    // granularity dropdown (where it did before this field's checkbox moved
    // to the enable dropdown).
    final roundErrors = host.fieldErrors['task_round_to_nearest'];
    final roundErrorText = (roundErrors != null && roundErrors.isNotEmpty)
        ? roundErrors.first
        : null;

    return FormSection(
      title: context.tr('rounding'),
      children: [
        // Enable on/off — carries the canonical `task_round_to_nearest`
        // override checkbox at client/group scope. It's always visible (unlike
        // the granularity dropdown, which only renders when rounding is on), so
        // a client can opt into overriding rounding even when the inherited
        // value is "off". Renders unwrapped (no checkbox) at company scope.
        OverridableField.bind(
          apiKey: 'task_round_to_nearest',
          label: context.tr('round_tasks'),
          // Seed with the inherited seconds; coalesce null → 1 (the "disabled"
          // sentinel) so the override registers even when nothing was set
          // upstream — a null numeric seed parses back to null and wouldn't
          // stick.
          cascadedValueOnEnable: () =>
              (host.settings.taskRoundToNearest?.toInt() ?? 1).toString(),
          child: DropdownButtonFormField<bool>(
            key: ValueKey('round-enable-$enabled'),
            isExpanded: true,
            initialValue: enabled,
            decoration: InputDecoration(
              labelText: context.tr('round_tasks'),
              helperText: context.tr('round_tasks_help'),
            ),
            items: [
              DropdownMenuItem(value: true, child: Text(context.tr('enabled'))),
              DropdownMenuItem(
                value: false,
                child: Text(context.tr('disabled')),
              ),
            ],
            onChanged: (v) {
              if (v == null) return;
              host.updateSettings((s) {
                if (v) {
                  // Re-enable: restore previous granularity, not a hardcoded
                  // default — preserves the user's choice across an off/on flip.
                  return s.copyWith(
                    taskRoundToNearest: _lastEnabledSeconds.toDouble(),
                  );
                }
                return s.copyWith(taskRoundToNearest: 1);
              });
            },
          ),
        ),
        if (enabled) ...[
          OverridableDropdownField<bool>(
            label: context.tr('direction'),
            apiKey: 'task_round_up',
            value: host.settings.taskRoundUp ?? false,
            items: [
              DropdownMenuItem(
                value: false,
                child: Text(context.tr('round_down')),
              ),
              DropdownMenuItem(
                value: true,
                child: Text(context.tr('round_up')),
              ),
            ],
            onChanged: (v) =>
                host.updateSettings((s) => s.copyWith(taskRoundUp: v)),
          ),
          // Granularity — plain dropdown; the enable dropdown above owns the
          // `task_round_to_nearest` override checkbox. Editable only once the
          // override is on (mirrors `_CustomSecondsField` below).
          DropdownButtonFormField<int>(
            key: ValueKey('round-granularity-$granularitySeconds'),
            initialValue:
                (granularitySeconds == 0 ||
                    _kPresetSeconds.contains(granularitySeconds))
                ? granularitySeconds
                : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.tr('task_round_to_nearest'),
              helperText: context.tr('task_round_to_nearest_help'),
              errorText: roundErrorText,
              enabled: isOverridden,
            ),
            items: [
              DropdownMenuItem(value: 60, child: Text(context.tr('1_minute'))),
              DropdownMenuItem(
                value: 300,
                child: Text(context.tr('5_minutes')),
              ),
              DropdownMenuItem(
                value: 900,
                child: Text(context.tr('15_minutes')),
              ),
              DropdownMenuItem(
                value: 1800,
                child: Text(context.tr('30_minutes')),
              ),
              DropdownMenuItem(value: 3600, child: Text(context.tr('1_hour'))),
              DropdownMenuItem(value: 86400, child: Text(context.tr('1_day'))),
              DropdownMenuItem(value: 0, child: Text(context.tr('custom'))),
            ],
            onChanged: isOverridden
                ? (v) {
                    if (v == null) return;
                    // Picking "Custom" (sentinel 0) flips isCustomValue so the
                    // seconds field appears. Mirrors admin-portal behavior.
                    host.updateSettings(
                      (s) => s.copyWith(taskRoundToNearest: v.toDouble()),
                    );
                  }
                : null,
          ),
          if (isCustomValue)
            _CustomSecondsField(
              host: host,
              enabled: isOverridden,
              currentSeconds: asInt ?? 0,
            ),
        ],
      ],
    );
  }
}

/// Plain integer-seconds input for the Custom rounding case. Not wrapped
/// in `OverridableField` to avoid a duplicate checkbox — the enable dropdown
/// above is the canonical override for `task_round_to_nearest`.
class _CustomSecondsField extends StatefulWidget {
  const _CustomSecondsField({
    required this.host,
    required this.enabled,
    required this.currentSeconds,
  });

  final SettingsDraftHost host;
  final bool enabled;
  final int currentSeconds;

  @override
  State<_CustomSecondsField> createState() => _CustomSecondsFieldState();
}

class _CustomSecondsFieldState extends State<_CustomSecondsField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _displayFor(widget.currentSeconds),
    );
  }

  @override
  void didUpdateWidget(_CustomSecondsField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-sync when the host pushes a new value (e.g. Discard guard reset
    // or server-driven refresh). Compare parsed values so an in-progress
    // keystroke doesn't get clobbered while the user is typing.
    final parsed = int.tryParse(_controller.text) ?? 0;
    if (parsed != widget.currentSeconds) {
      _controller.text = _displayFor(widget.currentSeconds);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _displayFor(int n) => n <= 0 ? '' : n.toString();

  @override
  Widget build(BuildContext context) {
    final scope = FormSaveScope.maybeOf(context);
    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(labelText: context.tr('round_to_seconds')),
      onChanged: (v) {
        final parsed = int.tryParse(v.trim());
        widget.host.updateSettings(
          (s) => s.copyWith(taskRoundToNearest: parsed?.toDouble()),
        );
      },
      onSubmitted: scope == null ? null : (_) => scope.trySubmit(),
    );
  }
}

/// Project Location dropdown — `invoice_task_project_header`:
/// false = service, true = description. Disabled-with-tooltip when the
/// parent `invoice_task_project` is off.
class _ProjectLocationDropdown extends StatelessWidget {
  const _ProjectLocationDropdown({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final field = DropdownButtonFormField<bool>(
      key: ValueKey('project-location-$value-$enabled'),
      isExpanded: true,
      initialValue: enabled ? value : null,
      decoration: InputDecoration(
        labelText: context.tr('project_location'),
        enabled: enabled,
      ),
      items: [
        DropdownMenuItem(value: false, child: Text(context.tr('service'))),
        DropdownMenuItem(value: true, child: Text(context.tr('description'))),
      ],
      onChanged: enabled ? (v) => v == null ? null : onChanged(v) : null,
    );
    if (enabled) return field;
    return Tooltip(message: context.tr('invoice_task_project'), child: field);
  }
}

/// Tasks-shown-in-portal dropdown. Disabled when the parent
/// `enable_client_portal_tasks` cascade field is off — leaves the
/// override checkbox (at non-company scope) interactive so the user can
/// still opt into overriding `show_all_tasks_client_portal`.
class _PortalTasksDropdown extends StatelessWidget {
  const _PortalTasksDropdown({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String value;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: enabled ? '' : context.tr('show_tasks_in_client_portal'),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: OverridableDropdownField<String>(
          label: context.tr('tasks_shown_in_portal'),
          apiKey: 'show_all_tasks_client_portal',
          value: value,
          items: [
            DropdownMenuItem(
              value: 'invoiced',
              child: Text(context.tr('invoiced')),
            ),
            DropdownMenuItem(
              value: 'uninvoiced',
              child: Text(context.tr('uninvoiced')),
            ),
            DropdownMenuItem(value: 'all', child: Text(context.tr('all'))),
          ],
          onChanged: enabled ? onChanged : (_) {},
        ),
      ),
    );
  }
}
