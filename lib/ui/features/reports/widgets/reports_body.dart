import 'dart:async';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/enabled_modules.dart';
import 'package:admin/data/models/domain/report_definition.dart';
import 'package:admin/data/models/domain/report_payload.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/domain/report_schedule_seed.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/reports_repository.dart';
import 'package:admin/data/services/reports_api.dart';
import 'package:admin/data/static/activity_types_catalog.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/domain/reports/report_engine.dart';
import 'package:admin/domain/reports/report_filter_options.dart';
import 'package:admin/domain/reports/report_registry.dart';
import 'package:admin/domain/reports/report_schedule.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/dashboard/widgets/filters/date_range_picker_button.dart';
import 'package:admin/ui/features/reports/view_models/reports_view_model.dart';
import 'package:admin/ui/features/reports/widgets/reports_chart_card.dart';
import 'package:admin/ui/features/settings/widgets/plan_gate_banner.dart';
import 'package:admin/utils/formatting.dart';

/// Sits inside the [ReportsScreen]'s Scaffold body. A persistent **Report
/// Settings panel** beside the live table on wide/medium viewports, or a
/// collapsible inline panel above the table on narrow ones. The panel hosts
/// every control (report / date / group / filters / columns) and the
/// Run · Export · Email footer; the table area owns state branching. Mirrors
/// the React + legacy-Flutter reports UX (a settings panel + a live
/// re-aggregating table), not a button toolbar.
class ReportsBody extends StatelessWidget {
  const ReportsBody({required this.formatter, super.key});

  final Formatter? formatter;

  static const double _panelWidth = 320;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tier = Breakpoints.reportTier(constraints.maxWidth);
        if (tier == ReportLayoutTier.narrow) {
          return _NarrowLayout(formatter: formatter);
        }
        final vm = context.watch<ReportsViewModel>();
        final tokens = context.inTheme;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (vm.panelCollapsed)
              _CollapsedRail(onExpand: () => vm.setPanelCollapsed(false))
            else
              SizedBox(
                width: _panelWidth,
                child: _ReportSettingsPanel(formatter: formatter),
              ),
            VerticalDivider(width: 1, color: tokens.border),
            Expanded(child: _ReportsContent(formatter: formatter)),
          ],
        );
      },
    );
  }
}

/// Thin rail shown when the panel is collapsed on wide/medium — a single
/// always-present affordance to bring the panel back (collapsing must never
/// hide Run/Export, so the rail is the recovery path).
class _CollapsedRail extends StatelessWidget {
  const _CollapsedRail({required this.onExpand});

  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Container(
      width: 44,
      color: tokens.surface,
      child: Column(
        children: [
          SizedBox(height: InSpacing.sm),
          IconButton(
            tooltip: context.tr('report_settings'),
            icon: const Icon(Icons.chevron_right),
            onPressed: onExpand,
          ),
          const Icon(Icons.tune, size: 18),
        ],
      ),
    );
  }
}

/// Narrow tier: a non-modal collapsible panel above the table. Deliberately
/// **not** a `showModalBottomSheet` — that dismisses on Run / tap-out and
/// would hide progress and Cancel.
class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({required this.formatter});

  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReportsViewModel>();
    final tokens = context.inTheme;
    return Column(
      children: [
        Material(
          color: tokens.surface,
          child: ListTile(
            leading: const Icon(Icons.tune, size: 20),
            title: Text(context.tr('report_settings')),
            trailing: Icon(
              vm.panelCollapsed ? Icons.expand_more : Icons.expand_less,
            ),
            onTap: () => vm.setPanelCollapsed(!vm.panelCollapsed),
          ),
        ),
        if (!vm.panelCollapsed)
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.55,
            ),
            child: _ReportSettingsPanel(formatter: formatter),
          ),
        const Divider(height: 1),
        Expanded(child: _ReportsContent(formatter: formatter)),
      ],
    );
  }
}

// ─── Report Settings panel ────────────────────────────────────────────────

class _ReportSettingsPanel extends StatelessWidget {
  const _ReportSettingsPanel({required this.formatter});

  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReportsViewModel>();
    final tokens = context.inTheme;
    final hasPreview = vm.run.preview != null;
    return Container(
      color: tokens.surface,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                InSpacing.lg(context),
                InSpacing.md(context),
                InSpacing.sm,
                InSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('report_settings'),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('hide'),
                    icon: const Icon(Icons.chevron_left, size: 20),
                    onPressed: () => vm.setPanelCollapsed(true),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: InSpacing.lg(context),
                  vertical: InSpacing.md(context),
                ),
                children: [
                  _PanelLabel(text: context.tr('report')),
                  _ReportPickerField(vm: vm),
                  SizedBox(height: InSpacing.lg(context)),
                  _PanelLabel(text: context.tr('date_range')),
                  _DateRangeField(vm: vm, formatter: formatter),
                  // Grouping, charting, columns and column-filters are
                  // preview-only. The ~11 reports that don't support preview
                  // can only be exported/emailed, so hide these controls for
                  // them entirely rather than showing them permanently
                  // disabled (matches React).
                  if (vm.definition.supportsPreview) ...[
                    SizedBox(height: InSpacing.lg(context)),
                    _PanelLabel(text: context.tr('group_by')),
                    _GroupByField(vm: vm, enabled: hasPreview),
                    if (hasPreview && vm.group != null)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: vm.chartVisible,
                        onChanged: vm.setChartVisible,
                        title: Text(context.tr('show_chart')),
                      ),
                    SizedBox(height: InSpacing.lg(context)),
                    _ColumnsField(vm: vm, enabled: hasPreview),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: vm.columnFiltersVisible,
                      onChanged: hasPreview
                          ? (_) => vm.toggleColumnFiltersVisible()
                          : null,
                      title: Text(context.tr('filter')),
                    ),
                    if (!hasPreview)
                      Padding(
                        padding: EdgeInsets.only(top: InSpacing.sm),
                        child: Text(
                          context.tr('run_report_to_configure'),
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: context.inTheme.ink3),
                        ),
                      ),
                  ],
                  SizedBox(height: InSpacing.lg(context)),
                  _FiltersSection(vm: vm),
                  if (vm.run.error != null &&
                      vm.run.error!.kind == ReportErrorKind.timeout)
                    Padding(
                      padding: EdgeInsets.only(top: InSpacing.md(context)),
                      child: _InlinePanelNotice(
                        message: context.tr('report_timed_out'),
                        actionLabel: context.tr('keep_waiting'),
                        onAction: vm.keepWaiting,
                      ),
                    ),
                  if (vm.run.status == ReportRunStatus.error &&
                      vm.run.error != null &&
                      vm.run.error!.kind != ReportErrorKind.timeout &&
                      vm.run.preview != null)
                    Padding(
                      padding: EdgeInsets.only(top: InSpacing.md(context)),
                      child: _InlinePanelNotice(
                        message: _errorMessage(context, vm.run.error!),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.all(InSpacing.lg(context)),
              child: _PanelFooterActions(vm: vm, formatter: formatter),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelLabel extends StatelessWidget {
  const _PanelLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: context.inTheme.ink3),
      ),
    );
  }
}

class _ReportPickerField extends StatelessWidget {
  const _ReportPickerField({required this.vm});

  final ReportsViewModel vm;

  @override
  Widget build(BuildContext context) {
    final session = context.read<Services>().auth.session.value;
    final canList = kReportDefinitions.where((def) {
      final company = session?.currentCompany;
      if (company == null) return true;
      if (!company.can(def.requiredPermission)) return false;
      // Per-entity reports (e.g. Invoice / Quote / Task report) drop out when
      // their module is disabled. General financial reports carry the
      // `view_reports` permission — those stay regardless of `icon` (the icon
      // is a glyph hint, not a capability: profit/loss uses an invoice icon
      // but isn't an invoices-module feature).
      if (def.requiredPermission == 'view_reports') return true;
      return isEntityModuleEnabledForCompany(def.icon, company.enabledModules);
    }).toList();

    // The selected report may have just been filtered out (module disabled
    // mid-session / company switch). Leaving a value with no matching item
    // renders a blank, broken dropdown — recover to the first available report
    // after this frame so the screen stays usable.
    final selectionValid = canList.any(
      (d) => d.identifier == vm.reportIdentifier,
    );
    if (!selectionValid && canList.isNotEmpty) {
      final fallback = canList.first.identifier;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) vm.setReport(fallback);
      });
    }

    return DropdownButtonFormField<String>(
      initialValue: selectionValid ? vm.reportIdentifier : null,
      isExpanded: true,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (v) {
        if (v == null) return;
        vm.setReport(v);
      },
      items: [
        for (final def in canList)
          DropdownMenuItem<String>(
            value: def.identifier,
            child: Text(context.tr(def.labelKey)),
          ),
      ],
    );
  }
}

/// Date range — report presets (incl. `last_90`) plus a "Custom range…"
/// entry that opens the shared two-month picker
/// ([openDateRangePicker]). A `DashboardCustomRange` result maps to
/// `payload.copyWith(datePreset: custom, startDate, endDate)`; a preset
/// from the picker rail maps best-effort onto [ReportDatePreset].
class _DateRangeField extends StatelessWidget {
  const _DateRangeField({required this.vm, required this.formatter});

  final ReportsViewModel vm;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final p = vm.payload;
    final String label;
    if (p.datePreset == ReportDatePreset.custom &&
        p.startDate != null &&
        p.endDate != null) {
      final s = formatter?.date(p.startDate!.toIso()) ?? p.startDate!.toIso();
      final e = formatter?.date(p.endDate!.toIso()) ?? p.endDate!.toIso();
      label = '$s → $e';
    } else {
      label = context.tr(_reportPresetKey(p.datePreset));
    }
    return MenuAnchor(
      builder: (context, controller, _) => OutlinedButton.icon(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 44),
          alignment: Alignment.centerLeft,
        ),
        icon: const Icon(Icons.calendar_today_outlined, size: 16),
        label: Text(label, overflow: TextOverflow.ellipsis),
      ),
      menuChildren: [
        for (final preset in ReportDatePreset.values)
          if (preset != ReportDatePreset.custom)
            MenuItemButton(
              onPressed: () => vm.setPayload(
                vm.payload.copyWith(
                  datePreset: preset,
                  startDate: () => null,
                  endDate: () => null,
                ),
              ),
              child: Text(context.tr(_reportPresetKey(preset))),
            ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.date_range, size: 16),
          onPressed: () => _openCustom(context),
          child: Text(context.tr('custom_range')),
        ),
      ],
    );
  }

  void _openCustom(BuildContext context) {
    final p = vm.payload;
    final DashboardDateRange current =
        (p.datePreset == ReportDatePreset.custom &&
            p.startDate != null &&
            p.endDate != null)
        ? DashboardCustomRange(start: p.startDate!, end: p.endDate!)
        : const DashboardPresetRange(DashboardDatePreset.thisYear);
    openDateRangePicker(
      context,
      current: current,
      formatter: formatter,
      onChange: (r) {
        if (r is DashboardCustomRange) {
          vm.setPayload(
            vm.payload.copyWith(
              datePreset: ReportDatePreset.custom,
              startDate: () => r.start,
              endDate: () => r.end,
            ),
          );
        } else if (r is DashboardPresetRange) {
          vm.setPayload(
            vm.payload.copyWith(
              datePreset: _mapDashboardPreset(r.preset),
              startDate: () => null,
              endDate: () => null,
            ),
          );
        }
      },
    );
  }
}

ReportDatePreset _mapDashboardPreset(DashboardDatePreset p) {
  switch (p) {
    case DashboardDatePreset.last7:
      return ReportDatePreset.last7;
    case DashboardDatePreset.last30:
      return ReportDatePreset.last30;
    case DashboardDatePreset.last365:
      return ReportDatePreset.last365;
    case DashboardDatePreset.thisMonth:
      return ReportDatePreset.thisMonth;
    case DashboardDatePreset.lastMonth:
      return ReportDatePreset.lastMonth;
    case DashboardDatePreset.thisQuarter:
      return ReportDatePreset.thisQuarter;
    case DashboardDatePreset.lastQuarter:
      return ReportDatePreset.lastQuarter;
    case DashboardDatePreset.thisYear:
      return ReportDatePreset.thisYear;
    case DashboardDatePreset.lastYear:
      return ReportDatePreset.lastYear;
    case DashboardDatePreset.allTime:
      return ReportDatePreset.allTime;
  }
}

String _reportPresetKey(ReportDatePreset p) {
  switch (p) {
    case ReportDatePreset.allTime:
      return 'all_time';
    case ReportDatePreset.last7:
      return 'last_7_days';
    case ReportDatePreset.last30:
      return 'last_30_days';
    case ReportDatePreset.last365:
      return 'last_365_days';
    case ReportDatePreset.thisMonth:
      return 'this_month';
    case ReportDatePreset.lastMonth:
      return 'last_month';
    case ReportDatePreset.thisQuarter:
      return 'this_quarter';
    case ReportDatePreset.lastQuarter:
      return 'last_quarter';
    case ReportDatePreset.thisYear:
      return 'this_year';
    case ReportDatePreset.lastYear:
      return 'last_year';
    case ReportDatePreset.custom:
      return 'custom';
  }
}

class _GroupByField extends StatelessWidget {
  const _GroupByField({required this.vm, this.enabled = true});

  final ReportsViewModel vm;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final columns = vm.run.preview?.columns ?? const <ReportColumn>[];
    // Only feed `vm.group` as the value when it's actually one of the items
    // (a preview is loaded and still carries that column). Otherwise '' —
    // covers the disabled-before-Run case and the hydrated-group/no-preview
    // restart path, where a stale id would trip DropdownButtonFormField's
    // "exactly one matching item" assertion.
    final groupValid =
        vm.group != null &&
        vm.group!.isNotEmpty &&
        columns.any((c) => c.identifier == vm.group);
    return DropdownButtonFormField<String>(
      initialValue: groupValid ? vm.group : '',
      isExpanded: true,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: !enabled
          ? null
          : (id) {
              if (id == null || id.isEmpty) {
                vm.setGroup(null);
                return;
              }
              final col = columns.where((c) => c.identifier == id).firstOrNull;
              final isDate =
                  col != null &&
                  (col.type == ReportColumnType.date ||
                      col.type == ReportColumnType.dateTime);
              vm.setGroup(id, subgroup: isDate ? ReportSubgroup.month : null);
            },
      items: [
        DropdownMenuItem(value: '', child: Text(context.tr('no_grouping'))),
        for (final col in columns)
          DropdownMenuItem(
            value: col.identifier,
            child: Text(col.displayLabel),
          ),
      ],
    );
  }
}

class _ColumnsField extends StatelessWidget {
  const _ColumnsField({required this.vm, this.enabled = true});

  final ReportsViewModel vm;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 44),
        alignment: Alignment.centerLeft,
      ),
      icon: const Icon(Icons.view_column_outlined, size: 16),
      label: Text(context.tr('columns')),
      onPressed: enabled ? () => _openColumnPicker(context, vm) : null,
    );
  }
}

Future<void> _openColumnPicker(
  BuildContext context,
  ReportsViewModel vm,
) async {
  final cols = vm.run.preview?.columns ?? const <ReportColumn>[];
  if (cols.isEmpty) return;
  final byId = {for (final c in cols) c.identifier: c};
  final selected = <String>{
    ...vm.visibleColumnIds.isEmpty
        ? cols.map((c) => c.identifier)
        : vm.visibleColumnIds,
  };
  // Seed the working order from the saved order, dropping unknown ids and
  // appending any columns the saved order doesn't mention (server order).
  final order = <String>[
    ...vm.columnOrder.where(byId.containsKey),
    for (final c in cols)
      if (!vm.columnOrder.contains(c.identifier)) c.identifier,
  ];

  final result = await showDialog<({Set<String> selected, List<String> order})>(
    context: context,
    builder: (context) {
      final local = Set<String>.from(selected);
      final localOrder = List<String>.from(order);
      var query = '';
      return StatefulBuilder(
        builder: (context, setState) {
          final searching = query.trim().isNotEmpty;
          final shown = searching
              ? localOrder
                    .where(
                      (id) => (byId[id]?.displayLabel ?? '')
                          .toLowerCase()
                          .contains(query.toLowerCase()),
                    )
                    .toList()
              : localOrder;
          Widget tile(String id, {Key? key}) {
            final c = byId[id]!;
            return CheckboxListTile(
              key: key,
              dense: true,
              value: local.contains(id),
              title: Text(c.displayLabel),
              // Drag handle only when not filtering (reordering a filtered
              // subset is ambiguous — disable it while searching).
              secondary: searching
                  ? null
                  : ReorderableDragStartListener(
                      index: localOrder.indexOf(id),
                      child: const Icon(Icons.drag_handle, size: 20),
                    ),
              onChanged: (v) => setState(() {
                if (v ?? false) {
                  local.add(id);
                } else {
                  local.remove(id);
                }
              }),
            );
          }

          return AlertDialog(
            title: Text(context.tr('columns')),
            content: SizedBox(
              width: 360,
              height: 460,
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 18),
                      hintText: context.tr('search'),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => query = v),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => setState(
                          () => local.addAll(cols.map((c) => c.identifier)),
                        ),
                        child: Text(context.tr('select_all')),
                      ),
                      TextButton(
                        onPressed: () => setState(local.clear),
                        child: Text(context.tr('clear')),
                      ),
                    ],
                  ),
                  Expanded(
                    child: searching
                        ? ListView(children: [for (final id in shown) tile(id)])
                        : ReorderableListView(
                            buildDefaultDragHandles: false,
                            onReorderItem: (oldIndex, newIndex) => setState(() {
                              final id = localOrder.removeAt(oldIndex);
                              localOrder.insert(newIndex, id);
                            }),
                            children: [
                              for (final id in localOrder)
                                tile(id, key: ValueKey(id)),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(64, 40),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.tr('cancel')),
                  ),
                  SizedBox(width: InSpacing.md(context)),
                  PrimaryDialogAction(
                    label: context.tr('save'),
                    onPressed: () => Navigator.of(
                      context,
                    ).pop((selected: local, order: localOrder)),
                    // Has a search field the user types in — don't steal its
                    // focus or show a hint that goes stale once they type.
                    autofocus: false,
                    showEnterHint: false,
                  ),
                ],
              ),
            ],
          );
        },
      );
    },
  );
  if (result != null) {
    vm.setVisibleColumns(result.selected, order: result.order);
  }
}

/// Server-side filters rendered per `definition.filterFields`. Mutates the
/// payload (which flips `isParamDirty` so the existing Run button signals a
/// refetch). `dateRange`/`dateColumn` are handled by the date field above.
class _FiltersSection extends StatelessWidget {
  const _FiltersSection({required this.vm});

  final ReportsViewModel vm;

  @override
  Widget build(BuildContext context) {
    final fields = vm.definition.filterFields
        .where(
          (f) =>
              f != ReportFilterField.dateRange &&
              f != ReportFilterField.dateColumn,
        )
        .toList();
    if (fields.isEmpty) return const SizedBox.shrink();
    final count = vm.activeFilterCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _PanelLabel(text: context.tr('filters'))),
            if (count > 0)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _Badge(count: count),
              ),
            InkWell(
              onTap: vm.resetFilters,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  context.tr('clear'),
                  style: TextStyle(fontSize: 12, color: context.inTheme.accent),
                ),
              ),
            ),
          ],
        ),
        for (final f in fields) ...[
          SizedBox(height: InSpacing.sm),
          _FilterControl(vm: vm, field: f),
        ],
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: tokens.accentSoft,
        borderRadius: BorderRadius.circular(InRadii.r2),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          color: tokens.accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FilterControl extends StatelessWidget {
  const _FilterControl({required this.vm, required this.field});

  final ReportsViewModel vm;
  final ReportFilterField field;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final p = vm.payload;
    switch (field) {
      case ReportFilterField.clientsMulti:
        return _MultiEntityField(
          label: context.tr('clients'),
          csv: p.clients,
          stream: services.clients.watchActiveNames(companyId: companyId),
          onChanged: (csv) => vm.setPayload(p.copyWith(clients: () => csv)),
        );
      case ReportFilterField.clientSingle:
        return _MultiEntityField(
          label: context.tr('client'),
          csv: p.clientId,
          single: true,
          stream: services.clients.watchActiveNames(companyId: companyId),
          onChanged: (csv) => vm.setPayload(p.copyWith(clientId: () => csv)),
        );
      case ReportFilterField.vendorsMulti:
        return _MultiEntityField(
          label: context.tr('vendors'),
          csv: p.vendors,
          stream: services.vendors.watchActiveNames(companyId: companyId),
          onChanged: (csv) => vm.setPayload(p.copyWith(vendors: () => csv)),
        );
      case ReportFilterField.projectsMulti:
        return _MultiEntityField(
          label: context.tr('projects'),
          csv: p.projects,
          stream: services.projects.watchActiveNames(companyId: companyId),
          onChanged: (csv) => vm.setPayload(p.copyWith(projects: () => csv)),
        );
      case ReportFilterField.tagsMulti:
        // Only the task + project reports expose this field; scope the tag
        // pool to the matching entity type.
        final tagEntityType = vm.reportIdentifier == 'task'
            ? 'task'
            : 'project';
        return _MultiEntityField(
          label: context.tr('tags'),
          csv: p.tags,
          stream: services.tags
              .watchAll(companyId: companyId, entityType: tagEntityType)
              .map((list) => [for (final t in list) (id: t.id, name: t.name)]),
          onChanged: (csv) => vm.setPayload(p.copyWith(tags: () => csv)),
        );
      case ReportFilterField.categoriesMulti:
        return _MultiEntityField(
          label: context.tr('expense_categories'),
          csv: p.categories,
          stream: services.expenseCategories
              .watchActive(companyId: companyId)
              .map((list) => [for (final e in list) (id: e.id, name: e.name)]),
          onChanged: (csv) => vm.setPayload(p.copyWith(categories: () => csv)),
        );
      case ReportFilterField.status:
        final statusOpts = reportStatusOptions(vm.reportIdentifier);
        if (statusOpts == null) {
          return _TextFilterField(
            label: context.tr('status'),
            value: p.status,
            onChanged: (v) => vm.setPayload(p.copyWith(status: () => v)),
          );
        }
        return _MultiEntityField(
          label: context.tr('status'),
          csv: p.status,
          staticOptions: [
            for (final o in statusOpts)
              (id: o.id, name: context.tr(o.labelKey)),
          ],
          onChanged: (csv) => vm.setPayload(p.copyWith(status: () => csv)),
        );
      case ReportFilterField.productKey:
        return _MultiEntityField(
          label: context.tr('product'),
          csv: p.productKey,
          stream: services.products.watchActiveProductKeys(
            companyId: companyId,
          ),
          onChanged: (csv) => vm.setPayload(p.copyWith(productKey: () => csv)),
        );
      case ReportFilterField.template:
        return _TextFilterField(
          label: context.tr('template'),
          value: p.templateId,
          onChanged: (v) => vm.setPayload(p.copyWith(templateId: () => v)),
        );
      case ReportFilterField.activityType:
        final activityOpts = [
          for (final e in kActivityTypeLabelKeys.entries)
            (id: '${e.key}', name: context.tr(e.value)),
        ]..sort((a, b) => a.name.compareTo(b.name));
        return _MultiEntityField(
          label: context.tr('activity'),
          csv: p.activityTypeId,
          staticOptions: activityOpts,
          onChanged: (csv) =>
              vm.setPayload(p.copyWith(activityTypeId: () => csv)),
        );
      case ReportFilterField.includeDeleted:
        return _BoolFilterTile(
          label: context.tr('include_deleted'),
          value: p.includeDeleted,
          onChanged: (v) => vm.setPayload(p.copyWith(includeDeleted: v)),
        );
      case ReportFilterField.includeTax:
        return _BoolFilterTile(
          label: context.tr('include_tax'),
          value: p.includeTax,
          onChanged: (v) => vm.setPayload(p.copyWith(includeTax: v)),
        );
      case ReportFilterField.isExpenseBilled:
        return _BoolFilterTile(
          label: context.tr('expense_paid_report'),
          value: p.isExpenseBilled,
          onChanged: (v) => vm.setPayload(p.copyWith(isExpenseBilled: v)),
        );
      case ReportFilterField.isIncomeBilled:
        return _BoolFilterTile(
          label: context.tr('cash_vs_accrual'),
          value: p.isIncomeBilled,
          onChanged: (v) => vm.setPayload(p.copyWith(isIncomeBilled: v)),
        );
      case ReportFilterField.documentEmailAttachment:
        return _BoolFilterTile(
          label: context.tr('document_email_attachment'),
          value: p.documentEmailAttachment,
          onChanged: (v) =>
              vm.setPayload(p.copyWith(documentEmailAttachment: v)),
        );
      case ReportFilterField.pdfEmailAttachment:
        return _BoolFilterTile(
          label: context.tr('pdf_email_attachment'),
          value: p.pdfEmailAttachment,
          onChanged: (v) => vm.setPayload(p.copyWith(pdfEmailAttachment: v)),
        );
      case ReportFilterField.dateRange:
      case ReportFilterField.dateColumn:
        return const SizedBox.shrink();
    }
  }
}

class _TextFilterField extends StatelessWidget {
  const _TextFilterField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value ?? '',
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (v) => onChanged(v.trim().isEmpty ? null : v.trim()),
    );
  }
}

class _BoolFilterTile extends StatelessWidget {
  const _BoolFilterTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: value,
      onChanged: onChanged,
      title: Text(label),
    );
  }
}

/// Multi-select (or single-select when [single]) over an entity name
/// stream. Value is the CSV id string the payload carries. Shows a
/// loading/empty placeholder until the repo stream emits (repos may be
/// unsynced right after login).
class _MultiEntityField extends StatelessWidget {
  const _MultiEntityField({
    required this.label,
    required this.csv,
    required this.onChanged,
    this.stream,
    this.staticOptions,
    this.single = false,
  }) : assert(
         stream != null || staticOptions != null,
         'provide either a stream or staticOptions',
       );

  final String label;
  final String? csv;

  /// Live entity-name source. Mutually exclusive with [staticOptions].
  final Stream<List<({String id, String name})>>? stream;

  /// Fixed option set (e.g. status values). When set, no [StreamBuilder] —
  /// the dialog opens directly. Mutually exclusive with [stream].
  final List<({String id, String name})>? staticOptions;

  final ValueChanged<String?> onChanged;
  final bool single;

  @override
  Widget build(BuildContext context) {
    final selectedIds = (csv ?? '')
        .split(',')
        .where((s) => s.isNotEmpty)
        .toSet();
    final options = staticOptions;
    if (options != null) {
      return _button(context, options, selectedIds);
    }
    return StreamBuilder<List<({String id, String name})>>(
      stream: stream,
      builder: (context, snap) {
        final items = snap.data ?? const <({String id, String name})>[];
        return _button(context, items, selectedIds);
      },
    );
  }

  Widget _button(
    BuildContext context,
    List<({String id, String name})> items,
    Set<String> selectedIds,
  ) {
    final summary = selectedIds.isEmpty
        ? context.tr('all')
        : items
              .where((e) => selectedIds.contains(e.id))
              .map((e) => e.name)
              .join(', ')
              .ifEmptyThen('${selectedIds.length}');
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 44),
        alignment: Alignment.centerLeft,
      ),
      onPressed: items.isEmpty
          ? null
          : () => _open(context, items, selectedIds),
      child: Text(
        '$label: $summary',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    List<({String id, String name})> items,
    Set<String> selected,
  ) async {
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) {
        final local = Set<String>.from(selected);
        var query = '';
        return StatefulBuilder(
          builder: (context, setState) {
            final filtered = items
                .where(
                  (e) => e.name.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();
            return AlertDialog(
              title: Text(label),
              content: SizedBox(
                width: 360,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, size: 18),
                        hintText: context.tr('search'),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => query = v),
                    ),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final e in filtered)
                            CheckboxListTile(
                              dense: true,
                              value: local.contains(e.id),
                              title: Text(e.name),
                              onChanged: (v) => setState(() {
                                if (single) local.clear();
                                if (v ?? false) {
                                  local.add(e.id);
                                } else {
                                  local.remove(e.id);
                                }
                              }),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(64, 40),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(context.tr('cancel')),
                    ),
                    SizedBox(width: InSpacing.md(context)),
                    PrimaryDialogAction(
                      label: context.tr('save'),
                      onPressed: () => Navigator.of(context).pop(local),
                      // Has a search field the user types in — don't steal its
                      // focus or show a hint that goes stale once they type.
                      autofocus: false,
                      showEnterHint: false,
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
    if (result != null) {
      onChanged(result.isEmpty ? null : result.join(','));
    }
  }
}

extension on String {
  String ifEmptyThen(String fallback) => isEmpty ? fallback : this;
}

class _InlinePanelNotice extends StatelessWidget {
  const _InlinePanelNotice({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Container(
      padding: EdgeInsets.all(InSpacing.md(context)),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(InRadii.r2),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: Theme.of(context).textTheme.bodySmall),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: onAction,
              style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Run · Export · Email. Always visible (export-only reports have no Run but
/// must still surface Export). In-flight buttons disable + spin; no
/// double-submit.
class _PanelFooterActions extends StatelessWidget {
  const _PanelFooterActions({required this.vm, required this.formatter});

  final ReportsViewModel vm;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    // Reports are Pro on hosted (parity with admin-portal & React). Trialing
    // users keep access (PlanGateBanner / hasProAccess are trial-aware). The
    // preview table stays visible (read-value) — only the Run / Export /
    // Email *actions* are disabled, per the read-value enforcement policy.
    // Defensive `Services` lookup — `_PanelFooterActions` is reachable from
    // widget tests that don't mount a `Services` provider; no provider →
    // ungated (matches pre-gate behaviour), same pattern as
    // `entity_documents_tab.dart`.
    Services? services;
    try {
      services = context.watch<Services>();
    } catch (_) {
      services = null;
    }
    final session = services?.auth.session.value;
    final gated = session != null && !session.hasProAccess;
    final actions = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (vm.definition.supportsPreview) _RunButton(vm: vm),
        if (vm.definition.supportsPreview) SizedBox(height: InSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _ExportButton(vm: vm, formatter: formatter),
            ),
            SizedBox(width: InSpacing.md(context)),
            Expanded(child: _EmailButton(vm: vm)),
          ],
        ),
        // Schedule is offered only for reports the server's email_report
        // exporter actually handles; the rest are cancelSchedule()'d on first
        // run (see isReportSchedulable).
        if (isReportSchedulable(vm.reportIdentifier)) ...[
          SizedBox(height: InSpacing.sm),
          _ScheduleButton(vm: vm),
        ],
        if (vm.columnFilters.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              context.tr('column_filters_preview_only'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.inTheme.ink3),
            ),
          ),
      ],
    );
    if (!gated) return actions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PlanGateBanner(style: PlanGateStyle.inset),
        // Disable the actions without threading an `enabled` flag through
        // every button widget. Semantics label tells assistive tech why.
        Semantics(
          enabled: false,
          label: context.tr('upgrade_to_paid_plan'),
          child: ExcludeSemantics(
            child: IgnorePointer(child: Opacity(opacity: 0.5, child: actions)),
          ),
        ),
      ],
    );
  }
}

/// "Schedule" — opens the recurring-email schedule editor pre-filled as an
/// `email_report` with the current report's filters/columns (mirrors React's
/// `useScheduleReport`). Uses the typed-`extra` prefill precedent
/// (`ReportScheduleSeed` → `SchedulesEditScreen.seed`).
class _ScheduleButton extends StatelessWidget {
  const _ScheduleButton({required this.vm});

  final ReportsViewModel vm;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
      icon: const Icon(Icons.schedule_outlined, size: 18),
      label: Text(context.tr('schedule')),
      onPressed: () {
        final seed = ReportScheduleSeed(
          reportIdentifier: vm.reportIdentifier,
          payload: vm.payload,
          // Ordered visible keys (column order, filtered to visible; empty →
          // the visible set) minus any synthetic client-only column
          // (`stock_value`) the server doesn't know — same stripping export and
          // email use.
          reportKeys: vm.serverReportKeys(ordered: true),
          groupBy: vm.group,
        );
        // Cross-branch (Reports → Settings) drops route `extra:`; stage the
        // seed on `Services` so the schedule create screen reads it.
        context.read<Services>().stageCreateDraft('/settings/schedules', seed);
        context.go('/settings/schedules/new');
      },
    );
  }
}

class _RunButton extends StatelessWidget {
  const _RunButton({required this.vm});

  final ReportsViewModel vm;

  @override
  Widget build(BuildContext context) {
    final isLoading = vm.run.isLoading;
    if (isLoading) {
      return FilledButton.icon(
        onPressed: vm.cancelRun,
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 44),
        ),
        icon: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: Text(context.tr('cancel')),
      );
    }
    final label = vm.isParamDirty
        ? context.tr('run_to_refresh')
        : context.tr('run_report');
    return FilledButton.icon(
      onPressed: vm.runReport,
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 44),
      ),
      icon: const Icon(Icons.play_arrow, size: 16),
      label: Text(label),
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.vm, required this.formatter});

  final ReportsViewModel vm;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    if (vm.isExporting) {
      return OutlinedButton.icon(
        onPressed: vm.cancelExport,
        style: OutlinedButton.styleFrom(minimumSize: const Size(64, 44)),
        icon: const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: Text(context.tr('cancel')),
      );
    }
    return MenuAnchor(
      builder: (context, controller, _) => OutlinedButton.icon(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        style: OutlinedButton.styleFrom(minimumSize: const Size(64, 44)),
        icon: const Icon(Icons.download, size: 16),
        label: Text(context.tr('export')),
      ),
      menuChildren: [
        for (final f in ReportExportFormat.values)
          MenuItemButton(
            onPressed: () => _export(context, f),
            child: Text(f.wire.toUpperCase()),
          ),
      ],
    );
  }

  Future<void> _export(BuildContext context, ReportExportFormat f) async {
    final toasts = Notify.capture(context);
    final tr = context.tr;
    final result = await vm.runExport(f);
    if (result == null) {
      final err = vm.exportError;
      if (err != null && err.kind == ReportErrorKind.timeout) {
        toasts?.warning(
          tr('report_timed_out'),
          action: NotifyAction(tr('keep_waiting'), () async {
            final retry = await vm.keepWaitingExport();
            if (retry != null) {
              await _save(toasts, tr, retry, f);
            }
          }),
        );
      } else if (err != null) {
        // `??` doesn't cover it: the server's message is a plain String that
        // can arrive as `""`, and this goes through the captured controller
        // (no context), which suppresses a blank toast rather than falling
        // back the way `Notify.error` does.
        final reason = err.message?.trim();
        toasts?.error(
          reason == null || reason.isEmpty ? tr('an_error_occurred') : reason,
        );
      }
      return;
    }
    await _save(toasts, tr, result, f);
  }

  Future<void> _save(
    ToastController? toasts,
    String Function(String, [Map<String, String>?]) tr,
    ReportExportResult result,
    ReportExportFormat f,
  ) async {
    final name =
        '${vm.definition.labelKey}_${vm.payload.datePreset.wire}'
        '.${f.defaultExtension}';
    try {
      final path = await FilePicker.saveFile(
        fileName: name,
        bytes: result.bytes,
      );
      if (path != null) {
        // Desktop returns a path without writing; web has no filesystem — the
        // browser already downloaded via `saveFile`, and `File` would throw
        // `UnsupportedError`. Write defensively only on native.
        if (!kIsWeb) {
          final file = File(path);
          if (!await file.exists() || await file.length() == 0) {
            await file.writeAsBytes(result.bytes);
          }
        }
        toasts?.success(tr('exported'));
      }
    } catch (e) {
      toasts?.error(tr('an_error_occurred'));
    }
  }
}

class _EmailButton extends StatelessWidget {
  const _EmailButton({required this.vm});

  final ReportsViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (vm.isEmailing) {
      return OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(minimumSize: const Size(64, 44)),
        child: const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: const Size(64, 44)),
      icon: const Icon(Icons.email_outlined, size: 16),
      label: Text(context.tr('email')),
      onPressed: () async {
        final toasts = Notify.capture(context);
        final tr = context.tr;
        try {
          await vm.sendEmail();
          toasts?.success(tr('email_sent'));
        } catch (e) {
          toasts?.error(tr('an_error_occurred'));
        }
      },
    );
  }
}

/// Flatten a 422's per-field messages into one block, or null when the server
/// sent none / only blanks.
///
/// `join` returns `''` for an empty list, so the `?? l10n(...)` fallbacks below
/// used to be dead code: a non-null but empty `fieldErrors` produced an empty
/// message with no fallback.
String? _flattenFieldErrors(Map<String, List<String>>? fieldErrors) {
  final lines = fieldErrors?.values
      .expand((v) => v)
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  return lines == null || lines.isEmpty ? null : lines.join('\n');
}

/// Same trap as [_flattenFieldErrors] for the server's own message field.
String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _errorMessage(BuildContext context, ReportError error) {
  final l10n = context.tr;
  switch (error.kind) {
    case ReportErrorKind.timeout:
      return l10n('report_timed_out');
    case ReportErrorKind.planRequired:
      return l10n('upgrade_to_view_reports');
    case ReportErrorKind.unauthorized:
      return l10n('access_denied');
    case ReportErrorKind.validation:
      return _flattenFieldErrors(error.fieldErrors) ??
          l10n('an_error_occurred');
    case ReportErrorKind.network:
      return l10n('no_internet_connection');
    case ReportErrorKind.passwordRequired:
      return l10n('password_required');
    case ReportErrorKind.serverError:
    case ReportErrorKind.cancelled:
    case ReportErrorKind.unknown:
      return _blankToNull(error.message) ?? l10n('an_error_occurred');
  }
}

// ─── Body content (state branching) ───────────────────────────────────────

class _ReportsContent extends StatelessWidget {
  const _ReportsContent({required this.formatter});

  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReportsViewModel>();
    final run = vm.run;

    // Loading without prior content → skeleton-ish shell.
    if (run.isLoading && run.preview == null) {
      return const _LoadingShell();
    }
    // Error without prior content → full error view.
    if (run.status == ReportRunStatus.error && run.preview == null) {
      return _ErrorState(error: run.error!, onRetry: vm.runReport);
    }
    // No preview yet → Initial empty state.
    if (run.preview == null) {
      return _InitialState(reportLabel: context.tr(vm.definition.labelKey));
    }
    // Ready (possibly with overlaid error banner).
    return _ReportTableArea(formatter: formatter);
  }
}

class _LoadingShell extends StatelessWidget {
  const _LoadingShell();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _InitialState extends StatelessWidget {
  const _InitialState({required this.reportLabel});

  final String reportLabel;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ReportsViewModel>();
    return EmptyState(
      icon: Icons.bar_chart_outlined,
      title: context.tr('reports'),
      subtitle: context.tr('run_report_to_load_hint', {'report': reportLabel}),
      action: vm.definition.supportsPreview
          ? FilledButton.icon(
              onPressed: vm.runReport,
              style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
              icon: const Icon(Icons.play_arrow, size: 16),
              label: Text(context.tr('run_report')),
            )
          : null,
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final ReportError error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.tr;
    String message;
    switch (error.kind) {
      case ReportErrorKind.timeout:
        message = l10n('report_timed_out');
      case ReportErrorKind.planRequired:
        message = l10n('upgrade_to_view_reports');
      case ReportErrorKind.unauthorized:
        message = l10n('access_denied');
      case ReportErrorKind.validation:
        message =
            _flattenFieldErrors(error.fieldErrors) ?? l10n('an_error_occurred');
      case ReportErrorKind.network:
        message = l10n('no_internet_connection');
      case ReportErrorKind.passwordRequired:
        message = l10n('password_required');
      case ReportErrorKind.serverError:
      case ReportErrorKind.cancelled:
      case ReportErrorKind.unknown:
        message = _blankToNull(error.message) ?? l10n('an_error_occurred');
    }
    return ErrorView(message: message, onRetry: onRetry);
  }
}

// ─── Table area (post-Run) ────────────────────────────────────────────────

class _ReportTableArea extends StatelessWidget {
  const _ReportTableArea({required this.formatter});

  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReportsViewModel>();
    final view = vm.buildView(
      companyCurrencyId: formatter?.settings.currencyId,
      firstMonthOfYear: formatter?.settings.firstMonthOfYear ?? 1,
      firstDayOfWeek: formatter?.settings.firstDayOfWeek ?? 0,
    );
    if (view.rows.isEmpty && view.groups.isEmpty) {
      return Column(
        children: [
          if (vm.selectedGroup != null) _DrillBreadcrumb(vm: vm),
          Expanded(
            child: EmptyState(
              icon: Icons.search_off,
              title: context.tr('no_results'),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        if (vm.selectedGroup != null) _DrillBreadcrumb(vm: vm),
        // Chart card slots between the drill breadcrumb and the totals
        // card. Only renders when there's actually a group bucket set —
        // the engine emits `groups: []` whenever no group is active OR
        // the user has drilled into a single group (in which case the
        // chart's "compare across groups" domain doesn't apply).
        if (vm.chartVisible && view.groups.isNotEmpty)
          ReportsChartCard(view: view, formatter: formatter),
        // Totals card renders whenever there's any row count to summarize —
        // money totals are nice-to-have, the row count is the floor (e.g.
        // Activity / Task reports have no money columns but should still
        // show "47 rows" in the totals card).
        if (view.rowCountByCurrency.isNotEmpty || view.totalRowCount > 0)
          _TotalsCard(view: view, formatter: formatter),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tier = Breakpoints.reportTier(constraints.maxWidth);
              if (tier == ReportLayoutTier.narrow) {
                return _ReportCardList(view: view, formatter: formatter);
              }
              return _ReportDataTable(
                view: view,
                formatter: formatter,
                pinFirstColumn: tier == ReportLayoutTier.medium,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DrillBreadcrumb extends StatelessWidget {
  const _DrillBreadcrumb({required this.vm});

  final ReportsViewModel vm;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Container(
      color: tokens.surface,
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: InSpacing.sm,
      ),
      child: Row(
        children: [
          // Flexible + ellipsis so a long group name can't overflow the row.
          Flexible(
            child: InputChip(
              avatar: const Icon(Icons.filter_alt_outlined, size: 16),
              label: Text(
                vm.selectedGroup ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // Tap anywhere on the chip — body or delete icon — clears the
              // drill. The breadcrumb is the only exit affordance for the
              // drilled view, so make the whole control feel like a button.
              onPressed: () => vm.setSelectedGroup(null),
              onDeleted: () => vm.setSelectedGroup(null),
              deleteIcon: const Icon(Icons.close, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.view, required this.formatter});

  final ReportView view;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    // Aggregatable columns (money / number / duration) the engine summed into
    // `grandTotalsByCurrency` ({columnId: {currencyId: sum}}).
    final totalColumns = view.visibleColumns
        .where((c) => isAggregatable(c.type))
        .where(
          (c) =>
              (view.grandTotalsByCurrency[c.identifier] ?? const {}).isNotEmpty,
        )
        .toList();
    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(InSpacing.lg(context)),
      padding: EdgeInsets.all(InSpacing.lg(context)),
      decoration: BoxDecoration(
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(InRadii.r3),
        color: tokens.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in view.rowCountByCurrency.entries)
            Padding(
              padding: EdgeInsets.symmetric(vertical: InSpacing.sm / 2),
              child: Text(
                _countLine(context, entry.key, entry.value),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          if (totalColumns.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.only(top: InSpacing.sm),
              child: Divider(height: 1, color: tokens.border),
            ),
            SizedBox(height: InSpacing.sm),
            for (final col in totalColumns)
              for (final e
                  in view.grandTotalsByCurrency[col.identifier]!.entries)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: InSpacing.sm / 2),
                  child: Text(
                    _totalLine(context, col, e.key, e.value),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  String _countLine(BuildContext context, String currencyId, int count) {
    final tr = context.tr;
    final label = _currencyLabel(context, currencyId);
    return '$label · $count ${count == 1 ? tr('row') : tr('rows')}';
  }

  String _totalLine(
    BuildContext context,
    ReportColumn column,
    String currencyId,
    Object value,
  ) {
    final String amount;
    if (column.type == ReportColumnType.money) {
      // Money convention: render `—` while the formatter is still loading,
      // never the raw Decimal.toString().
      final f = formatter;
      amount = f == null
          ? '—'
          : f.money(
              value as Decimal,
              currencyId: currencyId.isEmpty ? null : currencyId,
            );
    } else {
      amount = '$value';
    }
    final cur = column.type == ReportColumnType.money && currencyId.isNotEmpty
        ? '${_currencyLabel(context, currencyId)} '
        : '';
    return '${column.displayLabel} · $cur$amount';
  }

  String _currencyLabel(BuildContext context, String currencyId) {
    final tr = context.tr;
    final currency = formatter?.currencies[currencyId];
    return currencyId.isEmpty
        ? tr('total')
        : (currency?.code.isNotEmpty == true ? currency!.code : currencyId);
  }
}

// ─── The table itself ────────────────────────────────────────────────────

class _ReportDataTable extends StatelessWidget {
  const _ReportDataTable({
    required this.view,
    required this.formatter,
    required this.pinFirstColumn,
  });

  final ReportView view;
  final Formatter? formatter;
  final bool pinFirstColumn;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final vm = context.watch<ReportsViewModel>();
    final showFilters = vm.columnFiltersVisible;
    final headerCount = showFilters ? 2 : 1;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: _tableMinWidth(context),
        child: ListView.builder(
          shrinkWrap: false,
          itemCount: _bodyRowCount() + headerCount,
          itemBuilder: (context, index) {
            if (index == 0) return _HeaderRow(view: view);
            if (showFilters && index == 1) {
              return _ColumnFilterRow(view: view, vm: vm, formatter: formatter);
            }
            final i = index - headerCount;
            if (view.groups.isNotEmpty) {
              return _GroupRow(
                view: view,
                group: view.groups[i],
                formatter: formatter,
                background: i.isEven ? tokens.surface : tokens.surfaceAlt,
              );
            }
            return _DataRow(
              view: view,
              row: view.rows[i],
              formatter: formatter,
              background: i.isEven ? tokens.surface : tokens.surfaceAlt,
            );
          },
        ),
      ),
    );
  }

  int _bodyRowCount() =>
      view.groups.isNotEmpty ? view.groups.length : view.rows.length;

  double _tableMinWidth(BuildContext context) {
    // 160 px per column gives a comfortable default; the horizontal scroll
    // view handles overflow on narrower viewports.
    final cols = view.visibleColumns.length;
    return cols * 160.0;
  }
}

/// Per-column filter inputs, rendered directly under the header. Mirrors
/// [_HeaderRow]'s `for (col in visibleColumns) Expanded(...)` structure so it
/// scroll-syncs and stays column-aligned inside the same fixed-width table.
/// Client-side only — drives `vm.setColumnFilter` (the engine applies it);
/// debounced so typing doesn't recompute the view on every keystroke.
class _ColumnFilterRow extends StatelessWidget {
  const _ColumnFilterRow({
    required this.view,
    required this.vm,
    required this.formatter,
  });

  final ReportView view;
  final ReportsViewModel vm;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: InSpacing.sm,
      ),
      child: Row(
        children: [
          for (final col in view.visibleColumns)
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: InSpacing.sm),
                child: _ColumnFilterCell(
                  key: ValueKey('cf_${col.identifier}'),
                  column: col,
                  initial: vm.columnFilters[col.identifier] ?? '',
                  formatter: formatter,
                  onChanged: (v) => vm.setColumnFilter(col.identifier, v),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Per-column header filter, shaped to the column's [ReportColumnType] so the
/// user doesn't have to know the engine's token syntax: age and boolean become
/// dropdowns, date columns get a range picker, numeric columns a `min..max`
/// field, and strings a free-text substring field. The tokens each control
/// emits are exactly what `ReportEngine` matches on. Mirrors admin-portal's
/// type-aware filter row.
class _ColumnFilterCell extends StatefulWidget {
  const _ColumnFilterCell({
    required this.column,
    required this.initial,
    required this.onChanged,
    this.formatter,
    super.key,
  });

  final ReportColumn column;
  final String initial;
  final ValueChanged<String> onChanged;
  final Formatter? formatter;

  @override
  State<_ColumnFilterCell> createState() => _ColumnFilterCellState();
}

class _ColumnFilterCellState extends State<_ColumnFilterCell> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _emitDebounced(String v) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => widget.onChanged(v),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.column.type) {
      case ReportColumnType.age:
        return _dropdown(_ageItems(context));
      case ReportColumnType.boolean:
        return _dropdown(_boolItems(context));
      case ReportColumnType.date:
      case ReportColumnType.dateTime:
        return _DateRangeFilterButton(
          value: widget.initial,
          formatter: widget.formatter,
          onChanged: widget.onChanged,
        );
      case ReportColumnType.number:
      case ReportColumnType.money:
      case ReportColumnType.duration:
        return _textField(hint: context.tr('column_filter_range_hint'));
      case ReportColumnType.string:
        return _textField();
    }
  }

  Widget _textField({String? hint}) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12),
      ),
      style: const TextStyle(fontSize: 12),
      onChanged: _emitDebounced,
    );
  }

  Widget _dropdown(List<DropdownMenuItem<String>> items) {
    final current = items.any((i) => i.value == widget.initial)
        ? widget.initial
        : '';
    return DropdownButtonFormField<String>(
      initialValue: current,
      isDense: true,
      isExpanded: true,
      style: const TextStyle(fontSize: 12),
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      items: items,
      onChanged: (v) => widget.onChanged(v ?? ''),
    );
  }

  List<DropdownMenuItem<String>> _ageItems(BuildContext context) {
    // Tokens are the bucket upper bounds the engine's `_matchAge` accepts.
    return [
      DropdownMenuItem(value: '', child: Text(context.tr('all'))),
      DropdownMenuItem(value: 'paid', child: Text(context.tr('paid'))),
      const DropdownMenuItem(value: '30', child: Text('1 - 30')),
      const DropdownMenuItem(value: '60', child: Text('31 - 60')),
      const DropdownMenuItem(value: '90', child: Text('61 - 90')),
      const DropdownMenuItem(value: '120', child: Text('91 - 120')),
      const DropdownMenuItem(value: '120+', child: Text('120+')),
    ];
  }

  List<DropdownMenuItem<String>> _boolItems(BuildContext context) {
    return [
      DropdownMenuItem(value: '', child: Text(context.tr('all'))),
      DropdownMenuItem(value: 'true', child: Text(context.tr('yes'))),
      DropdownMenuItem(value: 'false', child: Text(context.tr('no'))),
    ];
  }
}

/// Compact date-range filter for a date/dateTime column header. Opens the
/// shared range picker and stores the resolved bounds as `startIso..endIso`
/// (what `ReportEngine._matchDateRange` expects); the trailing × clears it.
class _DateRangeFilterButton extends StatelessWidget {
  const _DateRangeFilterButton({
    required this.value,
    required this.onChanged,
    this.formatter,
  });

  final String value; // 'startIso..endIso' or ''
  final ValueChanged<String> onChanged;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final hasValue = value.contains('..');
    final String label;
    if (hasValue) {
      final parts = value.split('..');
      String fmt(String iso) => iso.trim().isEmpty
          ? '—'
          : (formatter?.date(iso.trim()) ?? iso.trim());
      label = '${fmt(parts[0])} → ${fmt(parts.length > 1 ? parts[1] : '')}';
    } else {
      label = context.tr('date_range');
    }
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.centerLeft,
      ),
      onPressed: () => _open(context),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (hasValue)
            GestureDetector(
              onTap: () => onChanged(''),
              child: Icon(Icons.close, size: 14, color: tokens.ink3),
            )
          else
            Icon(Icons.date_range, size: 14, color: tokens.ink3),
        ],
      ),
    );
  }

  void _open(BuildContext context) {
    DashboardDateRange current = const DashboardPresetRange(
      DashboardDatePreset.thisYear,
    );
    if (value.contains('..')) {
      final parts = value.split('..');
      final s = Date.tryParse(parts[0].trim());
      final e = parts.length > 1 ? Date.tryParse(parts[1].trim()) : null;
      if (s != null && e != null) {
        current = DashboardCustomRange(start: s, end: e);
      }
    }
    openDateRangePicker(
      context,
      current: current,
      formatter: formatter,
      onChange: (r) {
        final (start, end) = r.resolve();
        onChanged('${start.toIso()}..${end.toIso()}');
      },
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.view});

  final ReportView view;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ReportsViewModel>();
    final tokens = context.inTheme;
    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: InSpacing.sm,
      ),
      child: Row(
        children: [
          for (final col in view.visibleColumns)
            Expanded(
              child: Semantics(
                button: true,
                label: () {
                  if (vm.sortField != col.identifier) {
                    return 'Sort by ${col.displayLabel}';
                  }
                  return 'Sort by ${col.displayLabel}. '
                      'Currently ${vm.sortAscending ? 'ascending' : 'descending'}. '
                      'Double-tap to toggle.';
                }(),
                child: InkWell(
                  onTap: () => vm.toggleSort(col.identifier),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: InSpacing.sm),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            col.displayLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                        if (vm.sortField == col.identifier)
                          Icon(
                            vm.sortAscending
                                ? Icons.arrow_drop_up
                                : Icons.arrow_drop_down,
                            size: 18,
                            color: tokens.ink2,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.view,
    required this.row,
    required this.formatter,
    required this.background,
  });

  final ReportView view;
  final ReportRow row;
  final Formatter? formatter;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final wire = row.entityWire;
    final id = row.entityId;
    final handlers = wire == null
        ? null
        : resolveDrillTarget(services.entityRegistry, wire);
    final canDrill = handlers != null && id != null && id.isNotEmpty;
    return Material(
      color: background,
      child: InkWell(
        onTap: canDrill ? () => context.go('${handlers.routePath}/$id') : null,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: InSpacing.lg(context),
            vertical: InSpacing.sm,
          ),
          child: Row(
            children: [
              for (var i = 0; i < view.visibleColumns.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: InSpacing.sm),
                    child: _CellText(
                      cell: _cellByColumn(view, row, i),
                      column: view.visibleColumns[i],
                      formatter: formatter,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.view,
    required this.group,
    required this.formatter,
    required this.background,
  });

  final ReportView view;
  final GroupTotals group;
  final Formatter? formatter;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ReportsViewModel>();
    final unit = context.tr(group.count == 1 ? 'row' : 'rows');
    return Semantics(
      button: true,
      label:
          'Group ${group.key}, ${group.count} $unit. Double-tap to drill in.',
      child: Material(
        color: background,
        child: InkWell(
          onTap: () => vm.setSelectedGroup(group.key),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: InSpacing.lg(context),
              vertical: InSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: InSpacing.sm),
                    child: Text(
                      '${group.key} (${group.count})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                for (var i = 1; i < view.visibleColumns.length; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: InSpacing.sm),
                      child: _GroupTotalText(
                        column: view.visibleColumns[i],
                        group: group,
                        formatter: formatter,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupTotalText extends StatelessWidget {
  const _GroupTotalText({
    required this.column,
    required this.group,
    required this.formatter,
  });

  final ReportColumn column;
  final GroupTotals group;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    if (!isAggregatable(column.type)) return const Text('');
    final perCurrency = group.numericTotals[column.identifier];
    if (perCurrency == null || perCurrency.isEmpty) return const Text('');
    // Render the dominant currency entry; multi-currency groups show "—"
    // in the cell and rely on the totals card for the full breakdown.
    if (perCurrency.length == 1) {
      final e = perCurrency.entries.first;
      final value = e.value;
      if (column.type == ReportColumnType.money) {
        // Formatter is still loading on first paint — render the
        // placeholder so the column doesn't briefly flash a raw Decimal.
        final f = formatter;
        if (f == null) return const Text('—');
        return Text(
          f.money(value, currencyId: e.key.isEmpty ? null : e.key),
          style: moneyTextStyle(),
        );
      }
      return Text('$value');
    }
    return const Text('—');
  }
}

/// Display string for a report cell: the server's pre-formatted `displayValue`
/// when present, else a typed fallback (money/date through [formatter], a
/// `0:13:42` duration, localized yes/no, …). Shared by the wide-table
/// [_CellText] and the narrow [_ReportCardList] so both format identically —
/// the card list previously read raw `displayValue` and skipped this.
String _reportCellText(
  BuildContext context,
  ReportCell cell,
  ReportColumn column,
  Formatter? formatter,
) {
  final dv = cell.displayValue;
  if (dv != null) return dv;
  // Server values aren't always pre-formatted (typed numbers, some entity
  // references); format through the Formatter and fall back otherwise.
  if (cell is ReportNumberCell) {
    if (cell.value == null) return '';
    if (column.type == ReportColumnType.money) {
      // CLAUDE.md convention: money columns render `—` while the formatter
      // is loading, never the raw Decimal.toString().
      final f = formatter;
      if (f == null) return '—';
      return f.money(
        cell.value!,
        currencyId: cell.currencyId == null || cell.currencyId!.isEmpty
            ? null
            : cell.currencyId,
      );
    }
    return cell.value!.toString();
  }
  if (cell is ReportDateCell) {
    final iso = cell.value?.toIso();
    if (iso == null) return '';
    return formatter?.date(iso) ?? iso;
  }
  if (cell is ReportDateTimeCell) {
    final iso = cell.value?.toIso8601String();
    if (iso == null) return '';
    return formatter?.date(iso, showTime: true) ?? iso;
  }
  if (cell is ReportAgeCell) {
    if (cell.isPaid) return context.tr('paid');
    return '${cell.days ?? ''}';
  }
  if (cell is ReportBoolCell) {
    if (cell.value == null) return '';
    return cell.value! ? context.tr('yes') : context.tr('no');
  }
  if (cell is ReportDurationCell) {
    // `0:13:42`-style, matching the tasks time-log rendering; long spans
    // compact to `Xd HHh MMm`. (Was a non-localized `${seconds}s`.)
    return formatDuration(
      Duration(seconds: cell.seconds ?? 0),
      compactDays: true,
    );
  }
  if (cell is ReportStringCell) {
    return cell.value ?? '';
  }
  return '';
}

class _CellText extends StatelessWidget {
  const _CellText({
    required this.cell,
    required this.column,
    required this.formatter,
  });

  final ReportCell cell;
  final ReportColumn column;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    return Text(
      _reportCellText(context, cell, column, formatter),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: column.type == ReportColumnType.money ? moneyTextStyle() : null,
    );
  }
}

// Rows still carry cells in the original server order — the engine
// reorders `visibleColumns` (group column to index 0 when grouped) but
// not the cells themselves. `cellIndexByColumn` maps the visible column's
// identifier back to its original row-cell index, so drill-down rendering
// (group at index 0 in visibleColumns; original cell elsewhere in
// row.cells) lands on the right cell.
ReportCell _cellByColumn(ReportView view, ReportRow row, int visibleIdx) {
  final colId = view.visibleColumns[visibleIdx].identifier;
  final origIdx = view.cellIndexByColumn[colId];
  if (origIdx == null || origIdx >= row.cells.length) {
    // Defensive: visible column we couldn't map back. Render empty.
    return const ReportStringCell(value: '');
  }
  return row.cells[origIdx];
}

// ─── Narrow-viewport card list ────────────────────────────────────────────

class _ReportCardList extends StatelessWidget {
  const _ReportCardList({required this.view, required this.formatter});

  final ReportView view;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    if (view.groups.isNotEmpty) {
      return ListView.separated(
        itemCount: view.groups.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final g = view.groups[i];
          return ListTile(
            title: Text(g.key),
            subtitle: Text('${g.count} ${context.tr('rows')}'),
            onTap: () =>
                context.read<ReportsViewModel>().setSelectedGroup(g.key),
          );
        },
      );
    }
    return ListView.separated(
      itemCount: view.rows.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final row = view.rows[i];
        final services = context.read<Services>();
        final wire = row.entityWire;
        final id = row.entityId;
        final handlers = wire == null
            ? null
            : resolveDrillTarget(services.entityRegistry, wire);
        final canDrill = handlers != null && id != null && id.isNotEmpty;
        // Map by column identifier (not raw cell position): visibleColumns is
        // filtered/reordered and pins the group column to index 0 on drill, so
        // `row.cells[k]` would pair the wrong value with the label. `_cellByColumn`
        // resolves each visible column back to its original cell, exactly like
        // the wide table.
        return ListTile(
          onTap: canDrill
              ? () => context.go('${handlers.routePath}/$id')
              : null,
          title: Text(
            view.visibleColumns.isEmpty
                ? ''
                : _reportCellText(
                    context,
                    _cellByColumn(view, row, 0),
                    view.visibleColumns.first,
                    formatter,
                  ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var k = 1; k < view.visibleColumns.length && k < 4; k++)
                Text(
                  '${view.visibleColumns[k].displayLabel}: '
                  '${_reportCellText(context, _cellByColumn(view, row, k), view.visibleColumns[k], formatter)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        );
      },
    );
  }
}
