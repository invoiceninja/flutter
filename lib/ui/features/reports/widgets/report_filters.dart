import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/report_definition.dart';
import 'package:admin/data/models/domain/report_payload.dart';
import 'package:admin/data/static/activity_types_catalog.dart';
import 'package:admin/domain/reports/report_filter_options.dart';
import 'package:admin/domain/reports/report_registry.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/reports/view_models/reports_view_model.dart';

/// One choice a filter offers.
typedef ReportFilterChoice = ({String id, String name});

/// The filters that are a set of values to pick from — as opposed to the
/// date range (its own control), the on/off ones, and the three that are
/// not filters at all but choices about a file being sent.
bool isReportValueFilter(ReportFilterField field) => switch (field) {
  ReportFilterField.status ||
  ReportFilterField.clientsMulti ||
  ReportFilterField.clientSingle ||
  ReportFilterField.clientIdsMulti ||
  ReportFilterField.vendorsMulti ||
  ReportFilterField.projectsMulti ||
  ReportFilterField.tagsMulti ||
  ReportFilterField.categoriesMulti ||
  ReportFilterField.activityType ||
  ReportFilterField.productKey => true,
  ReportFilterField.dateRange ||
  ReportFilterField.template ||
  ReportFilterField.documentEmailAttachment ||
  ReportFilterField.pdfEmailAttachment ||
  ReportFilterField.includeDeleted ||
  ReportFilterField.isIncomeBilled => false,
};

/// The report's filters the reader can add from the bar: the value filters,
/// and Include Deleted. Accrual-versus-cash is drawn as its own two-way
/// switch, and the range as its own button.
List<ReportFilterField> reportBarFilters(ReportDefinition definition) => [
  for (final field in definition.filterFields)
    if (isReportValueFilter(field) || field == ReportFilterField.includeDeleted)
      field,
];

/// Only one value may be chosen.
bool isReportSingleFilter(ReportFilterField field) =>
    field == ReportFilterField.clientSingle ||
    field == ReportFilterField.activityType;

String reportFilterLabel(BuildContext context, ReportFilterField field) {
  final tr = context.tr;
  return switch (field) {
    ReportFilterField.status => tr('status'),
    ReportFilterField.clientsMulti ||
    ReportFilterField.clientIdsMulti => tr('clients'),
    ReportFilterField.clientSingle => tr('client'),
    ReportFilterField.vendorsMulti => tr('vendors'),
    ReportFilterField.projectsMulti => tr('projects'),
    ReportFilterField.tagsMulti => tr('tags'),
    ReportFilterField.categoriesMulti => tr('expense_categories'),
    ReportFilterField.activityType => tr('activity'),
    ReportFilterField.productKey => tr('products'),
    ReportFilterField.includeDeleted => tr('include_deleted'),
    ReportFilterField.isIncomeBilled => tr('cash_vs_accrual'),
    ReportFilterField.template => tr('template'),
    ReportFilterField.documentEmailAttachment => tr('attach_documents'),
    ReportFilterField.pdfEmailAttachment => tr('attach_pdf'),
    ReportFilterField.dateRange => tr('date_range'),
  };
}

/// The value of a value filter, as the comma-joined ids it travels as.
String? reportFilterValue(ReportPayload p, ReportFilterField field) =>
    switch (field) {
      ReportFilterField.status => p.status,
      ReportFilterField.clientsMulti => p.clients,
      ReportFilterField.clientSingle ||
      ReportFilterField.clientIdsMulti => p.clientId,
      ReportFilterField.vendorsMulti => p.vendors,
      ReportFilterField.projectsMulti => p.projects,
      ReportFilterField.tagsMulti => p.tags,
      ReportFilterField.categoriesMulti => p.categories,
      ReportFilterField.activityType => p.activityTypeId,
      ReportFilterField.productKey => p.productKey,
      _ => null,
    };

/// [p] with a value filter set to [csv]; null or empty clears it.
ReportPayload reportPayloadWithFilter(
  ReportPayload p,
  ReportFilterField field,
  String? csv,
) {
  final value = (csv == null || csv.isEmpty) ? null : csv;
  String? Function() set() =>
      () => value;
  return switch (field) {
    ReportFilterField.status => p.copyWith(status: set()),
    ReportFilterField.clientsMulti => p.copyWith(clients: set()),
    ReportFilterField.clientSingle ||
    ReportFilterField.clientIdsMulti => p.copyWith(clientId: set()),
    ReportFilterField.vendorsMulti => p.copyWith(vendors: set()),
    ReportFilterField.projectsMulti => p.copyWith(projects: set()),
    ReportFilterField.tagsMulti => p.copyWith(tags: set()),
    ReportFilterField.categoriesMulti => p.copyWith(categories: set()),
    ReportFilterField.activityType => p.copyWith(activityTypeId: set()),
    ReportFilterField.productKey => p.copyWith(productKey: set()),
    ReportFilterField.includeDeleted => p.copyWith(
      includeDeleted: value != null,
    ),
    _ => p,
  };
}

/// Whether [field] is narrowing the report right now.
bool isReportFilterActive(ReportPayload p, ReportFilterField field) {
  if (field == ReportFilterField.includeDeleted) return p.includeDeleted;
  final value = reportFilterValue(p, field);
  return value != null && value.isNotEmpty;
}

Set<String> _ids(String? csv) => {
  for (final id in (csv ?? '').split(','))
    if (id.isNotEmpty) id,
};

/// What a value filter can be set to. Live from the local database for the
/// entity filters, fixed for a status or an activity type.
Stream<List<ReportFilterChoice>> reportFilterChoices(
  BuildContext context,
  ReportsViewModel vm,
  ReportFilterField field,
) {
  final services = context.read<Services>();
  final companyId = services.auth.session.value?.currentCompanyId ?? '';
  final tr = context.tr;
  switch (field) {
    case ReportFilterField.clientsMulti:
    case ReportFilterField.clientSingle:
    case ReportFilterField.clientIdsMulti:
      return services.clients.watchActiveNames(companyId: companyId);
    case ReportFilterField.vendorsMulti:
      return services.vendors.watchActiveNames(companyId: companyId);
    case ReportFilterField.projectsMulti:
      return services.projects.watchActiveNames(companyId: companyId);
    case ReportFilterField.productKey:
      return services.products.watchActiveProductKeys(companyId: companyId);
    case ReportFilterField.tagsMulti:
      // Scoped to the type the report's rows carry — a line-item report takes
      // its document's tags.
      final type = kReportTagEntityTypes[vm.reportIdentifier] ?? 'invoice';
      return services.tags
          .watchAll(companyId: companyId, entityType: type)
          .map((list) => [for (final t in list) (id: t.id, name: t.name)]);
    case ReportFilterField.categoriesMulti:
      return services.expenseCategories
          .watchActive(companyId: companyId)
          .map((list) => [for (final e in list) (id: e.id, name: e.name)]);
    case ReportFilterField.status:
      return Stream.value([
        for (final o
            in reportStatusOptions(vm.reportIdentifier) ??
                const <ReportFilterOption>[])
          (id: o.id, name: tr(o.labelKey)),
      ]);
    case ReportFilterField.activityType:
      final choices = [
        for (final e in kActivityTypeLabelKeys.entries)
          (id: '${e.key}', name: tr(e.value)),
      ]..sort((a, b) => a.name.compareTo(b.name));
      return Stream.value(choices);
    case ReportFilterField.dateRange:
    case ReportFilterField.template:
    case ReportFilterField.documentEmailAttachment:
    case ReportFilterField.pdfEmailAttachment:
    case ReportFilterField.includeDeleted:
    case ReportFilterField.isIncomeBilled:
      return const Stream.empty();
  }
}

/// Edit one value filter: a searchable list to tick from, applied on Save.
///
/// **On Save, not as each box is ticked.** Each change to a filter re-runs
/// the report, and picking three clients must be one run, not three — the
/// server finishes a job the app has stopped waiting for, and the routes are
/// throttled. A dialog where there is room for one; on a narrow pane a sheet
/// that keeps clear of the keyboard.
Future<void> editReportFilter(
  BuildContext context,
  ReportsViewModel vm,
  ReportFilterField field,
) async {
  final label = reportFilterLabel(context, field);
  final choices = reportFilterChoices(context, vm, field);
  final initial = _ids(reportFilterValue(vm.payload, field));
  final single = isReportSingleFilter(field);
  final wide = MediaQuery.sizeOf(context).width >= Breakpoints.wide;
  final Set<String>? picked;
  if (wide) {
    picked = await showDialog<Set<String>>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
          child: _ChoicePicker(
            title: label,
            choices: choices,
            initial: initial,
            single: single,
          ),
        ),
      ),
    );
  } else {
    picked = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        // The sheet's own body sees no keyboard inset — it has to make room.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: FractionallySizedBox(
          heightFactor: 0.8,
          child: _ChoicePicker(
            title: label,
            choices: choices,
            initial: initial,
            single: single,
          ),
        ),
      ),
    );
  }
  if (picked == null) return;
  vm.setPayload(reportPayloadWithFilter(vm.payload, field, picked.join(',')));
}

class _ChoicePicker extends StatefulWidget {
  const _ChoicePicker({
    required this.title,
    required this.choices,
    required this.initial,
    required this.single,
  });

  final String title;
  final Stream<List<ReportFilterChoice>> choices;
  final Set<String> initial;
  final bool single;

  @override
  State<_ChoicePicker> createState() => _ChoicePickerState();
}

class _ChoicePickerState extends State<_ChoicePicker> {
  late final Set<String> _picked = {...widget.initial};
  String _query = '';

  void _toggle(String id) {
    setState(() {
      if (widget.single) {
        final was = _picked.contains(id);
        _picked.clear();
        if (!was) _picked.add(id);
      } else if (!_picked.remove(id)) {
        _picked.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final tr = context.tr;
    final pad = InSpacing.lg(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad, pad, pad, InSpacing.sm),
          child: Text(
            widget.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: tokens.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: TextField(
            autofocus: MediaQuery.sizeOf(context).width >= Breakpoints.wide,
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              hintText: tr('search'),
              prefixIcon: const Icon(Icons.search, size: 18),
            ),
          ),
        ),
        const SizedBox(height: InSpacing.sm),
        Expanded(
          child: StreamBuilder<List<ReportFilterChoice>>(
            stream: widget.choices,
            builder: (context, snapshot) {
              final all = snapshot.data;
              if (all == null) {
                return const Center(child: CircularProgressIndicator());
              }
              final needle = _query.trim().toLowerCase();
              final shown = needle.isEmpty
                  ? all
                  : [
                      for (final c in all)
                        if (c.name.toLowerCase().contains(needle)) c,
                    ];
              if (shown.isEmpty) {
                return Center(
                  child: Text(
                    tr('no_results'),
                    style: TextStyle(color: tokens.ink2),
                  ),
                );
              }
              return ListView.builder(
                itemCount: shown.length,
                itemBuilder: (context, i) {
                  final c = shown[i];
                  return CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _picked.contains(c.id),
                    onChanged: (_) => _toggle(c.id),
                    title: Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              );
            },
          ),
        ),
        Divider(height: 1, thickness: 1, color: tokens.border),
        Padding(
          padding: EdgeInsets.all(pad),
          child: Row(
            children: [
              if (_picked.isNotEmpty)
                TextButton(
                  onPressed: () => setState(_picked.clear),
                  child: Text(tr('clear')),
                ),
              const Spacer(),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 40),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(tr('cancel')),
              ),
              SizedBox(width: InSpacing.md(context)),
              // Not autofocused: the search field has the focus, and Enter
              // there should not close the list out from under a half-typed
              // name.
              PrimaryDialogAction(
                label: tr('apply'),
                autofocus: false,
                showEnterHint: false,
                onPressed: () => Navigator.of(context).pop(_picked),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A filter's value as a chip says it: the names when there are one or two,
/// a count beyond that.
class ReportFilterSummary extends StatelessWidget {
  const ReportFilterSummary({
    super.key,
    required this.vm,
    required this.field,
    required this.builder,
  });

  final ReportsViewModel vm;
  final ReportFilterField field;
  final Widget Function(BuildContext context, String summary) builder;

  @override
  Widget build(BuildContext context) {
    final ids = _ids(reportFilterValue(vm.payload, field));
    return StreamBuilder<List<ReportFilterChoice>>(
      stream: reportFilterChoices(context, vm, field),
      builder: (context, snapshot) {
        final names = <String>[
          for (final c in snapshot.data ?? const <ReportFilterChoice>[])
            if (ids.contains(c.id)) c.name,
        ];
        final String summary;
        if (ids.length > 2 || names.length != ids.length) {
          // More than fit — or names not loaded yet: say how many.
          summary = '${ids.length}';
        } else {
          summary = names.join(', ');
        }
        return builder(context, summary);
      },
    );
  }
}
