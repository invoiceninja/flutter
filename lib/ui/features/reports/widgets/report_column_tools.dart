import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/domain/reports/report_engine.dart';
import 'package:admin/domain/reports/report_group_label.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/dashboard/widgets/filters/date_range_picker_button.dart';
import 'package:admin/ui/features/reports/view_models/reports_view_model.dart';
import 'package:admin/utils/formatting.dart';

/// The age buckets a column of invoice ages filters by, as the engine names
/// them (`ReportEngine._matchAge`), with what each is called on screen.
const List<(String, String)> _kAgeBuckets = [
  ('paid', 'paid'),
  ('30', '0 – 30'),
  ('60', '31 – 60'),
  ('90', '61 – 90'),
  ('120', '91 – 120'),
  ('120+', '120+'),
];

/// Filter the rows by [column], with the editor its type calls for:
/// * text — the values the column actually holds, with how many rows have
///   each, to tick from. Not a box to type into: picking "Paid" must not
///   also match "Unpaid", and nobody should have to guess a spelling;
/// * a figure — a least and a most;
/// * a date — the same range popover as the report's own range;
/// * yes/no and an age — their handful of choices.
///
/// These narrow the rows on screen and nothing else; the server is not
/// asked again.
Future<void> editReportColumnFilter(
  BuildContext context,
  ReportsViewModel vm,
  ReportColumn column, {
  Formatter? formatter,
}) async {
  final id = column.identifier;
  final current = vm.columnFilters[id] ?? '';
  switch (column.type) {
    case ReportColumnType.date:
    case ReportColumnType.dateTime:
      final parts = current.split('..');
      final start = parts.length == 2 ? Date.tryParse(parts[0]) : null;
      final end = parts.length == 2 ? Date.tryParse(parts[1]) : null;
      await openDateRangePicker(
        context,
        current: start != null && end != null
            ? DashboardCustomRange(start: start, end: end)
            : const DashboardPresetRange(DashboardDatePreset.thisMonth),
        formatter: formatter,
        onChange: (range) {
          final (s, e) = switch (range) {
            DashboardCustomRange() => (range.start, range.end),
            DashboardPresetRange() => DashboardFilter(
              range: range,
            ).resolveDates(),
          };
          vm.setColumnFilter(id, '${s.toIso()}..${e.toIso()}');
        },
      );
    case ReportColumnType.number:
    case ReportColumnType.money:
    case ReportColumnType.duration:
      final result = await showDialog<String>(
        context: context,
        builder: (context) =>
            _RangeDialog(title: column.displayLabel, initial: current),
      );
      if (result != null) vm.setColumnFilter(id, result);
    case ReportColumnType.boolean:
      final tr = context.tr;
      final picked = await _pickOne(
        context,
        title: column.displayLabel,
        choices: [('true', tr('yes')), ('false', tr('no'))],
        current: current,
      );
      if (picked != null) vm.setColumnFilter(id, picked);
    case ReportColumnType.age:
      final tr = context.tr;
      final picked = await _pickOne(
        context,
        title: column.displayLabel,
        choices: [
          for (final (value, label) in _kAgeBuckets)
            (value, value == 'paid' ? tr('paid') : label),
        ],
        current: current,
      );
      if (picked != null) vm.setColumnFilter(id, picked);
    case ReportColumnType.string:
      final picked = await showDialog<Set<String>>(
        context: context,
        builder: (context) => _ValuesDialog(
          title: column.displayLabel,
          values: _distinctValues(vm, column),
          initial: reportOneOfFilterValues(current) ?? const {},
        ),
      );
      if (picked == null) return;
      vm.setColumnFilter(id, picked.isEmpty ? '' : reportOneOfFilter(picked));
  }
}

/// What a column filter says on its chip.
String reportColumnFilterSummary(
  BuildContext context,
  ReportColumn column,
  String value, {
  Formatter? formatter,
}) {
  final tr = context.tr;
  final oneOf = reportOneOfFilterValues(value);
  if (oneOf != null) {
    if (oneOf.length > 2) return '${oneOf.length}';
    return oneOf.map((v) => v.isEmpty ? tr('blank') : v).join(', ');
  }
  switch (column.type) {
    case ReportColumnType.boolean:
      return value == 'true' ? tr('yes') : tr('no');
    case ReportColumnType.age:
      for (final (bucket, label) in _kAgeBuckets) {
        if (bucket == value) return bucket == 'paid' ? tr('paid') : label;
      }
      return value;
    case ReportColumnType.date:
    case ReportColumnType.dateTime:
      final parts = value.split('..');
      if (parts.length == 2 && formatter != null) {
        return formatter.dateRange(parts[0], parts[1]);
      }
      return value.replaceAll('..', ' – ');
    case ReportColumnType.number:
    case ReportColumnType.money:
    case ReportColumnType.duration:
      final at = value.indexOf('..');
      if (at < 0) return '≥ $value';
      final lo = value.substring(0, at);
      final hi = value.substring(at + 2);
      if (hi.isEmpty) return '≥ $lo';
      if (lo.isEmpty) return '≤ $hi';
      return '$lo – $hi';
    case ReportColumnType.string:
      return '“$value”';
  }
}

/// The distinct values of [column] across the whole result, most frequent
/// first — at most a few hundred, which is past the point a list to tick
/// from is the right tool anyway.
List<(String, int)> _distinctValues(ReportsViewModel vm, ReportColumn column) {
  final preview = vm.run.preview;
  if (preview == null) return const [];
  final index = preview.columns.indexWhere(
    (c) => c.identifier == column.identifier,
  );
  if (index < 0) return const [];
  final counts = <String, int>{};
  for (final row in preview.rows) {
    if (index >= row.cells.length) continue;
    final cell = row.cells[index];
    final text =
        cell.displayValue ??
        (cell is ReportStringCell ? cell.value : null) ??
        '';
    counts[text] = (counts[text] ?? 0) + 1;
  }
  final entries = counts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });
  return [for (final e in entries.take(300)) (e.key, e.value)];
}

Future<String?> _pickOne(
  BuildContext context, {
  required String title,
  required List<(String, String)> choices,
  required String current,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(title),
      children: [
        RadioGroup<String>(
          groupValue: current,
          onChanged: (v) => Navigator.of(context).pop(v ?? ''),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (value, label) in choices)
                RadioListTile<String>(
                  dense: true,
                  value: value,
                  title: Text(label),
                ),
            ],
          ),
        ),
        if (current.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(''),
                child: Text(context.tr('clear')),
              ),
            ),
          ),
      ],
    ),
  );
}

class _RangeDialog extends StatefulWidget {
  const _RangeDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_RangeDialog> createState() => _RangeDialogState();
}

class _RangeDialogState extends State<_RangeDialog> {
  late final TextEditingController _min;
  late final TextEditingController _max;

  @override
  void initState() {
    super.initState();
    final at = widget.initial.indexOf('..');
    _min = TextEditingController(
      text: at < 0 ? widget.initial : widget.initial.substring(0, at),
    );
    _max = TextEditingController(
      text: at < 0 ? '' : widget.initial.substring(at + 2),
    );
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _apply() {
    final lo = _min.text.trim();
    final hi = _max.text.trim();
    Navigator.of(context).pop(lo.isEmpty && hi.isEmpty ? '' : '$lo..$hi');
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    const keyboard = TextInputType.numberWithOptions(
      signed: true,
      decimal: true,
    );
    return AlertDialog(
      title: Text(widget.title),
      content: FormSaveScope(
        onSubmit: _apply,
        enabled: true,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _min,
                autofocus: true,
                keyboardType: keyboard,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: tr('min')),
              ),
            ),
            SizedBox(width: InSpacing.md(context)),
            Expanded(
              child: TextField(
                controller: _max,
                keyboardType: keyboard,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _apply(),
                decoration: InputDecoration(labelText: tr('max')),
              ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('cancel')),
        ),
        PrimaryDialogAction(
          label: tr('apply'),
          autofocus: false,
          onPressed: _apply,
        ),
      ],
    );
  }
}

class _ValuesDialog extends StatefulWidget {
  const _ValuesDialog({
    required this.title,
    required this.values,
    required this.initial,
  });

  final String title;
  final List<(String, int)> values;
  final Set<String> initial;

  @override
  State<_ValuesDialog> createState() => _ValuesDialogState();
}

class _ValuesDialogState extends State<_ValuesDialog> {
  late final Set<String> _picked = {...widget.initial};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final tr = context.tr;
    final pad = InSpacing.lg(context);
    final needle = _query.trim().toLowerCase();
    final shown = needle.isEmpty
        ? widget.values
        : [
            for (final v in widget.values)
              if (v.$1.toLowerCase().contains(needle)) v,
          ];
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Column(
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
                decoration: InputDecoration(
                  isDense: true,
                  hintText: tr('search'),
                  prefixIcon: const Icon(Icons.search, size: 18),
                ),
              ),
            ),
            const SizedBox(height: InSpacing.sm),
            Expanded(
              child: ListView.builder(
                itemCount: shown.length,
                itemBuilder: (context, i) {
                  final (value, count) = shown[i];
                  return CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _picked.contains(value),
                    onChanged: (_) => setState(() {
                      if (!_picked.remove(value)) _picked.add(value);
                    }),
                    title: Text(
                      value.isEmpty ? tr('blank') : value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    secondary: Text(
                      '$count',
                      style: TextStyle(fontSize: 12, color: tokens.ink3),
                    ),
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
        ),
      ),
    );
  }
}

/// Choose which columns the table shows, and in what order.
///
/// Fed from the columns the server returned — all of them, not the ones
/// showing — so a column that is hidden is always here to be switched back
/// on. The report's on-demand date column is listed too, marked as one that
/// has to be fetched.
Future<void> openReportColumns(
  BuildContext context,
  ReportsViewModel vm,
) async {
  final preview = vm.run.preview;
  if (preview == null) return;
  final result = await showDialog<(Set<String>, List<String>, bool)>(
    context: context,
    builder: (context) => _ColumnsDialog(vm: vm, preview: preview),
  );
  if (result == null) return;
  final (ids, order, fetchDate) = result;
  if (fetchDate) vm.setIncludeDateColumn(true);
  vm.setVisibleColumns(ids, order: order);
}

class _ColumnsDialog extends StatefulWidget {
  const _ColumnsDialog({required this.vm, required this.preview});

  final ReportsViewModel vm;
  final ReportPreview preview;

  @override
  State<_ColumnsDialog> createState() => _ColumnsDialogState();
}

class _ColumnsDialogState extends State<_ColumnsDialog> {
  late List<ReportColumn> _order;
  late Set<String> _visible;
  bool _fetchDate = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    final vm = widget.vm;
    final byId = {for (final c in widget.preview.columns) c.identifier: c};
    // The reader's own order first, then whatever it does not mention.
    _order = [
      for (final id in vm.columnOrder) ?byId[id],
      for (final c in widget.preview.columns)
        if (!vm.columnOrder.contains(c.identifier)) c,
    ];
    _visible = vm.visibleColumnIds.isEmpty
        ? {for (final c in _order) c.identifier}
        : {...vm.visibleColumnIds};
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final tr = context.tr;
    final vm = widget.vm;
    final pad = InSpacing.lg(context);
    final needle = _query.trim().toLowerCase();
    final searching = needle.isNotEmpty;
    final shown = searching
        ? [
            for (final c in _order)
              if (c.displayLabel.toLowerCase().contains(needle)) c,
          ]
        : _order;
    final offerable = vm.offerableDateColumnId;
    final dateLabelKey = reportDateKeyLabelKey(vm.definition.dateRangeKey);

    Widget tile(ReportColumn c, {int? index}) => CheckboxListTile(
      key: ValueKey(c.identifier),
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      value: _visible.contains(c.identifier),
      onChanged: (_) => setState(() {
        if (!_visible.remove(c.identifier)) _visible.add(c.identifier);
      }),
      title: Text(c.displayLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
      secondary: index == null
          ? null
          : ReorderableDragStartListener(
              index: index,
              child: Icon(Icons.drag_indicator, size: 18, color: tokens.ink3),
            ),
    );

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(pad, pad, pad, InSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tr('columns'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: tokens.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(
                      () => _visible = {for (final c in _order) c.identifier},
                    ),
                    child: Text(tr('select_all')),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _visible = {}),
                    child: Text(tr('clear')),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: tr('search'),
                  prefixIcon: const Icon(Icons.search, size: 18),
                ),
              ),
            ),
            const SizedBox(height: InSpacing.sm),
            Expanded(
              // Dragging reorders the whole list, so it is offered only when
              // the whole list is showing.
              child: searching
                  ? ListView(children: [for (final c in shown) tile(c)])
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      itemCount: shown.length,
                      onReorderItem: (from, to) => setState(() {
                        _order.insert(to, _order.removeAt(from));
                      }),
                      itemBuilder: (context, i) => tile(shown[i], index: i),
                    ),
            ),
            if (offerable != null && dateLabelKey != null)
              CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: _fetchDate,
                onChanged: (v) => setState(() => _fetchDate = v ?? false),
                title: Text(tr(dateLabelKey)),
                // Not in the result yet: ticking it asks the server again.
                secondary: Icon(
                  Icons.cloud_download_outlined,
                  size: 18,
                  color: tokens.ink3,
                ),
              ),
            Divider(height: 1, thickness: 1, color: tokens.border),
            Padding(
              padding: EdgeInsets.all(pad),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(64, 40),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(tr('cancel')),
                  ),
                  SizedBox(width: InSpacing.md(context)),
                  PrimaryDialogAction(
                    label: tr('done'),
                    autofocus: false,
                    showEnterHint: false,
                    // A table with no columns is not a table.
                    enabled: _visible.isNotEmpty || _fetchDate,
                    onPressed: () => Navigator.of(context).pop((
                      _visible,
                      [for (final c in _order) c.identifier],
                      _fetchDate,
                    )),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
