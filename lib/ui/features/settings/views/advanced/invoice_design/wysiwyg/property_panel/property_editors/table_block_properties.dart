import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/cell_typography_editor.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/expandable_property_row.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_inputs.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/table_header_label.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_view_model.dart';

/// Property editor for `table` (products) and `tasks-table`. Phase 7c
/// adds per-column inline expansion (header / field / width / align +
/// label/value style sub-cards).
class TableBlockProperties extends StatefulWidget {
  const TableBlockProperties({
    super.key,
    required this.vm,
    required this.block,
  });

  final WysiwygDesignViewModel vm;
  final DesignBlock block;

  @override
  State<TableBlockProperties> createState() => _TableBlockPropertiesState();
}

class _TableBlockPropertiesState extends State<TableBlockProperties> {
  int? _expandedIndex;

  List<Map<String, dynamic>> _columns() {
    final raw = widget.block.properties['columns'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return [
      for (final c in raw)
        if (c is Map<String, dynamic>) Map<String, dynamic>.from(c),
    ];
  }

  void _writeColumns(List<Map<String, dynamic>> next) {
    final props = Map<String, dynamic>.from(widget.block.properties);
    props['columns'] = next;
    widget.vm.updateBlock(widget.block.copyWith(properties: props));
  }

  void _writeProperty(String key, Object? value) {
    widget.vm.updateBlock(
      widget.block.copyWith(
        properties: mergePropertyOrOmit(widget.block.properties, key, value),
      ),
    );
  }

  void _updateColumn(int index, String key, Object? value) {
    final cols = _columns();
    final merged = Map<String, dynamic>.from(cols[index]);
    if (value == null || (value is String && value.isEmpty)) {
      merged.remove(key);
    } else {
      merged[key] = value;
    }
    cols[index] = merged;
    _writeColumns(cols);
  }

  void _toggleExpanded(int index) {
    setState(() {
      _expandedIndex = _expandedIndex == index ? null : index;
    });
  }

  void _reorder(int oldIndex, int newIndex) {
    final cols = _columns();
    // onReorderItem already maps newIndex to the post-removal destination.
    final adjusted = newIndex;
    if (adjusted == oldIndex) return;
    final item = cols.removeAt(oldIndex);
    cols.insert(adjusted, item);
    setState(() {
      if (_expandedIndex == oldIndex) {
        _expandedIndex = adjusted;
      } else if (_expandedIndex != null) {
        final ei = _expandedIndex!;
        if (oldIndex < ei && adjusted >= ei) _expandedIndex = ei - 1;
        if (oldIndex > ei && adjusted <= ei) _expandedIndex = ei + 1;
      }
    });
    _writeColumns(cols);
  }

  void _delete(int index) {
    final cols = _columns()..removeAt(index);
    setState(() {
      if (_expandedIndex == index) {
        _expandedIndex = null;
      } else if (_expandedIndex != null && _expandedIndex! > index) {
        _expandedIndex = _expandedIndex! - 1;
      }
    });
    _writeColumns(cols);
  }

  /// Phase 4b: catalog of table columns the user can add. Mirrors the
  /// React block-library defaults plus the most common extras (net cost,
  /// gross line total, discount, tax, custom values).
  static const List<Map<String, dynamic>> _kAvailableColumns = [
    {
      'id': 'product_key',
      'header': 'item',
      'field': 'item.product_key',
      'width': '25%',
      'align': 'left',
    },
    {
      'id': 'notes',
      'header': 'description',
      'field': 'item.notes',
      'width': '30%',
      'align': 'left',
    },
    {
      'id': 'quantity',
      'header': 'qty',
      'field': 'item.quantity',
      'width': '10%',
      'align': 'center',
    },
    {
      'id': 'cost',
      'header': 'unit_cost',
      'field': 'item.cost',
      'width': '15%',
      'align': 'right',
    },
    {
      'id': 'line_total',
      'header': 'line_total',
      'field': 'item.line_total',
      'width': '15%',
      'align': 'right',
    },
    {
      'id': 'net_cost',
      'header': 'net_cost',
      'field': 'item.net_cost',
      'width': '15%',
      'align': 'right',
    },
    {
      'id': 'gross_line_total',
      'header': 'gross_line_total',
      'field': 'item.gross_line_total',
      'width': '15%',
      'align': 'right',
    },
    {
      'id': 'discount',
      'header': 'discount',
      'field': 'item.discount',
      'width': '10%',
      'align': 'right',
    },
    {
      'id': 'tax_rate1',
      'header': 'tax',
      'field': 'item.tax_rate1',
      'width': '10%',
      'align': 'right',
    },
    {
      'id': 'custom_value1',
      'header': 'custom1',
      'field': 'item.custom_value1',
      'width': '15%',
      'align': 'left',
    },
    {
      'id': 'custom_value2',
      'header': 'custom2',
      'field': 'item.custom_value2',
      'width': '15%',
      'align': 'left',
    },
  ];

  Future<void> _addColumn() async {
    final existing = _columns().map((c) => c['id']).toSet();
    final available = _kAvailableColumns
        .where((c) => !existing.contains(c['id']))
        .toList();
    if (available.isEmpty) return;
    final picked = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(ctx.tr('add_column')),
        children: [
          for (final col in available)
            ListTile(
              dense: true,
              title: Text(ctx.tr(col['header'] as String)),
              subtitle: Text(
                col['field'] as String,
                style: TextStyle(
                  fontFamily: kMonoFontFamily,
                  fontSize: 11,
                  color: ctx.inTheme.ink3,
                ),
              ),
              onTap: () => Navigator.of(ctx).pop(col),
            ),
        ],
      ),
    );
    if (picked == null) return;
    _writeColumns([..._columns(), Map<String, dynamic>.from(picked)]);
  }

  @override
  Widget build(BuildContext context) {
    final props = widget.block.properties;
    final cols = _columns();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.tr('columns'),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: Text(context.tr('add_column')),
              onPressed: _addColumn,
            ),
          ],
        ),
        SizedBox(height: InSpacing.sm),
        if (cols.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: InSpacing.md(context)),
            child: Text(
              context.tr('no_records_found'),
              style: TextStyle(color: context.inTheme.ink3),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: cols.length,
            onReorderItem: _reorder,
            itemBuilder: (context, index) => _ColumnRow(
              key: ValueKey('${cols[index]['id']}-$index'),
              index: index,
              column: cols[index],
              expanded: _expandedIndex == index,
              onToggleExpanded: () => _toggleExpanded(index),
              onDelete: () => _delete(index),
              onColumnChanged: (k, v) => _updateColumn(index, k, v),
            ),
          ),
        SizedBox(height: InSpacing.lg(context)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('alternate_row_colors')),
          value: (props['alternateRows'] as bool?) ?? true,
          onChanged: (v) => _writeProperty('alternateRows', v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('show_borders')),
          value: (props['showBorders'] as bool?) ?? true,
          onChanged: (v) => _writeProperty('showBorders', v),
        ),
        SizedBox(height: InSpacing.md(context)),
        _ColorField(
          labelKey: 'header_background',
          value: props['headerBg'] as String?,
          onChanged: (v) => _writeProperty('headerBg', v),
        ),
        SizedBox(height: InSpacing.md(context)),
        _ColorField(
          labelKey: 'row_background',
          value: props['rowBg'] as String?,
          onChanged: (v) => _writeProperty('rowBg', v),
        ),
        SizedBox(height: InSpacing.md(context)),
        _ColorField(
          labelKey: 'alternate_row_background',
          value: props['alternateRowBg'] as String?,
          onChanged: (v) => _writeProperty('alternateRowBg', v),
        ),
        // Phase 7e: header / row typography knobs.
        const SectionDivider(labelKey: 'typography'),
        ColorInput(
          labelKey: 'header_color',
          value: props['headerColor'] as String?,
          onChanged: (v) => _writeProperty('headerColor', v),
        ),
        SizedBox(height: InSpacing.md(context)),
        FontStyleInput(
          fontWeight: props['headerFontWeight'] as String?,
          fontStyle: null,
          onFontWeightChanged: (v) => _writeProperty('headerFontWeight', v),
          onFontStyleChanged: (_) {},
        ),
        SizedBox(height: InSpacing.md(context)),
        ColorInput(
          labelKey: 'row_color',
          value: props['rowColor'] as String?,
          onChanged: (v) => _writeProperty('rowColor', v),
        ),
        const SectionDivider(labelKey: 'spacing'),
        PxInput(
          labelKey: 'padding',
          value: props['padding'],
          resettable: true,
          onChanged: (v) => _writeProperty('padding', v),
        ),
        // Phase 7e: per-region border editor. Reads/writes the
        // `{color, width, sides: {top,right,bottom,left}}` sub-map shape
        // that React's `mergeTableRegion` constructs.
        const SectionDivider(labelKey: 'header_borders'),
        _TableRegionBordersEditor(
          value: props['headerBorders'] as Map<String, dynamic>?,
          onChanged: (v) => _writeProperty('headerBorders', v),
        ),
        const SectionDivider(labelKey: 'row_borders'),
        _TableRegionBordersEditor(
          value: props['rowBorders'] as Map<String, dynamic>?,
          onChanged: (v) => _writeProperty('rowBorders', v),
        ),
      ],
    );
  }
}

/// Nested editor for a `{color, width, sides:{top,right,bottom,left}}`
/// border sub-map. React's `mergeTableRegion` builds this same shape.
class _TableRegionBordersEditor extends StatelessWidget {
  const _TableRegionBordersEditor({
    required this.value,
    required this.onChanged,
  });

  final Map<String, dynamic>? value;
  final ValueChanged<Map<String, dynamic>?> onChanged;

  Map<String, dynamic> _read() =>
      Map<String, dynamic>.from(value ?? const <String, dynamic>{});

  Map<String, dynamic> _sides(Map<String, dynamic> region) {
    final s = region['sides'];
    if (s is Map<String, dynamic>) {
      return Map<String, dynamic>.from(s);
    }
    return <String, dynamic>{};
  }

  void _set(String key, Object? next) {
    final merged = _read();
    if (next == null || (next is String && next.isEmpty)) {
      merged.remove(key);
    } else {
      merged[key] = next;
    }
    onChanged(merged.isEmpty ? null : merged);
  }

  void _setSide(String side, bool on) {
    final merged = _read();
    final sides = _sides(merged);
    if (on) {
      sides[side] = true;
    } else {
      sides.remove(side);
    }
    if (sides.isEmpty) {
      merged.remove('sides');
    } else {
      merged['sides'] = sides;
    }
    onChanged(merged.isEmpty ? null : merged);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final region = _read();
    final sides = _sides(region);
    return Container(
      padding: EdgeInsets.all(InSpacing.md(context)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(InRadii.r2),
        border: Border.all(color: tokens.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColorInput(
            labelKey: 'color',
            value: region['color'] as String?,
            onChanged: (v) => _set('color', v),
            defaultValue: '#E5E7EB',
          ),
          SizedBox(height: InSpacing.md(context)),
          PxInput(
            labelKey: 'width',
            value: region['width'],
            hintText: '1',
            resettable: true,
            // React clamps to [0, 20] in `coerceBorderWidthPx`.
            minPx: 0,
            maxPx: 20,
            onChanged: (v) => _set('width', v),
          ),
          SizedBox(height: InSpacing.md(context)),
          Text(
            context.tr('sides'),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          SizedBox(height: InSpacing.sm),
          Wrap(
            spacing: 6,
            children: [
              for (final side in const ['top', 'right', 'bottom', 'left'])
                FilterChip(
                  label: Text(context.tr(side)),
                  selected: (sides[side] as bool?) ?? false,
                  onSelected: (on) => _setSide(side, on),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColumnRow extends StatelessWidget {
  const _ColumnRow({
    super.key,
    required this.index,
    required this.column,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onDelete,
    required this.onColumnChanged,
  });

  final int index;
  final Map<String, dynamic> column;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onDelete;
  final void Function(String key, Object? value) onColumnChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final headerKey = (column['header'] as String?) ?? '';
    final field = (column['field'] as String?) ?? '';
    final width = (column['width'] as String?) ?? '';
    final align = (column['align'] as String?) ?? 'left';
    return ExpandablePropertyRow(
      index: index,
      title: Text(
        headerKey.isEmpty ? field : resolveTableHeaderLabel(context, headerKey),
        style: Theme.of(context).textTheme.bodyMedium,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '$field  ·  $width  ·  $align',
        style: TextStyle(
          fontSize: 11,
          fontFamily: kMonoFontFamily,
          color: tokens.ink3,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      expanded: expanded,
      onToggleExpanded: onToggleExpanded,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 18),
        onPressed: onDelete,
      ),
      expandedChild: _ExpandedColumnEditor(
        column: column,
        onColumnChanged: onColumnChanged,
      ),
    );
  }
}

class _ExpandedColumnEditor extends StatelessWidget {
  const _ExpandedColumnEditor({
    required this.column,
    required this.onColumnChanged,
  });

  final Map<String, dynamic> column;
  final void Function(String key, Object? value) onColumnChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Container(
      margin: EdgeInsets.only(top: InSpacing.sm, left: 24),
      padding: EdgeInsets.all(InSpacing.md(context)),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(InRadii.r2),
        border: Border.all(color: tokens.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            initialValue: (column['header'] as String?) ?? '',
            decoration: InputDecoration(
              labelText: context.tr('header'),
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => onColumnChanged('header', v),
          ),
          SizedBox(height: InSpacing.md(context)),
          TextFormField(
            initialValue: (column['field'] as String?) ?? '',
            decoration: InputDecoration(
              labelText: context.tr('field'),
              border: const OutlineInputBorder(),
              hintText: 'item.product_key',
            ),
            onChanged: (v) => onColumnChanged('field', v),
          ),
          SizedBox(height: InSpacing.md(context)),
          TextFormField(
            initialValue: (column['width'] as String?) ?? '',
            decoration: InputDecoration(
              labelText: context.tr('width'),
              border: const OutlineInputBorder(),
              hintText: '25%',
            ),
            onChanged: (v) => onColumnChanged('width', v),
          ),
          SizedBox(height: InSpacing.md(context)),
          AlignmentInput(
            labelKey: 'alignment',
            value: column['align'] as String?,
            onChanged: (v) => onColumnChanged('align', v),
          ),
          SizedBox(height: InSpacing.md(context)),
          CellTypographyEditor(
            headingKey: 'label_style',
            value: column['labelStyle'] as Map<String, dynamic>?,
            onChanged: (v) => onColumnChanged('labelStyle', v),
          ),
          SizedBox(height: InSpacing.md(context)),
          CellTypographyEditor(
            headingKey: 'value_style',
            value: column['valueStyle'] as Map<String, dynamic>?,
            onChanged: (v) => onColumnChanged('valueStyle', v),
          ),
        ],
      ),
    );
  }
}

class _ColorField extends StatelessWidget {
  const _ColorField({
    required this.labelKey,
    required this.value,
    required this.onChanged,
  });

  final String labelKey;
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value ?? '',
      decoration: InputDecoration(
        labelText: context.tr(labelKey),
        hintText: '#FFFFFF',
        border: const OutlineInputBorder(),
      ),
      onChanged: (v) => onChanged(v.trim()),
    );
  }
}
