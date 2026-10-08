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
      'header': r'$product.item_label',
      'field': 'item.product_key',
      'width': '25%',
      'align': 'left',
    },
    {
      'id': 'notes',
      'header': r'$product.description_label',
      'field': 'item.notes',
      'width': '30%',
      'align': 'left',
    },
    {
      'id': 'quantity',
      'header': r'$product.quantity_label',
      'field': 'item.quantity',
      'width': '10%',
      'align': 'center',
    },
    {
      'id': 'cost',
      'header': r'$product.unit_cost_label',
      'field': 'item.cost',
      'width': '15%',
      'align': 'right',
    },
    {
      'id': 'line_total',
      'header': r'$product.line_total_label',
      'field': 'item.line_total',
      'width': '15%',
      'align': 'right',
    },
    {
      'id': 'net_cost',
      'header': r'$product.net_cost_label',
      'field': 'item.net_cost',
      'width': '15%',
      'align': 'right',
    },
    {
      'id': 'gross_line_total',
      'header': r'$product.gross_line_total_label',
      'field': 'item.gross_line_total',
      'width': '15%',
      'align': 'right',
    },
    {
      'id': 'discount',
      'header': r'$product.discount_label',
      'field': 'item.discount',
      'width': '10%',
      'align': 'right',
    },
    {
      'id': 'tax_rate1',
      'header': r'$product.tax_label',
      'field': 'item.tax_rate1',
      'width': '10%',
      'align': 'right',
    },
    {
      'id': 'custom_value1',
      'header': r'$product.product1_label',
      'field': 'item.custom_value1',
      'width': '15%',
      'align': 'left',
    },
    {
      'id': 'custom_value2',
      'header': r'$product.product2_label',
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
              title: Text(
                resolveTableHeaderLabel(ctx, col['header'] as String),
              ),
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
              othersWidth: [
                for (var i = 0; i < cols.length; i++)
                  if (i != index) _percentOf(cols[i]['width']),
              ].fold<double>(0, (a, b) => a + b),
            ),
          ),
        SizedBox(height: InSpacing.lg(context)),
        PropertySwitch(
          labelKey: 'alternate_row_colors',
          value: (props['alternateRows'] as bool?) ?? true,
          onChanged: (v) => _writeProperty('alternateRows', v),
        ),
        ColorInput(
          labelKey: 'header_background',
          defaultValue: '#F3F4F6',
          value: props['headerBg'] as String?,
          onChanged: (v) => _writeProperty('headerBg', v),
        ),
        ColorInput(
          labelKey: 'row_background',
          defaultValue: '#FFFFFF',
          value: props['rowBg'] as String?,
          onChanged: (v) => _writeProperty('rowBg', v),
        ),
        ColorInput(
          labelKey: 'alternate_row_background',
          defaultValue: '#F9FAFB',
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
        FontStyleInput(
          fontWeight: props['headerFontWeight'] as String?,
          fontStyle: null,
          showItalic: false,
          onFontWeightChanged: (v) => _writeProperty('headerFontWeight', v),
          onFontStyleChanged: (_) {},
        ),
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
        // Per-region borders: the `{color, width, sides}` sub-maps React's
        // `mergeTableRegion` builds. Rarely touched, so they start closed.
        PropertyDisclosure(
          titleKey: 'borders',
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: InSpacing.sm),
              child: Text(
                context.tr('header'),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            _TableRegionBordersEditor(
              value: props['headerBorders'] as Map<String, dynamic>?,
              onChanged: (v) => _writeProperty('headerBorders', v),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: InSpacing.sm),
              child: Text(
                context.tr('rows'),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            _TableRegionBordersEditor(
              value: props['rowBorders'] as Map<String, dynamic>?,
              onChanged: (v) => _writeProperty('rowBorders', v),
            ),
          ],
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

  /// A side is stored `true` or `false`, never left out: the server draws a
  /// side unless it is *strictly* false, so removing the key to turn one off
  /// — which is what this did — turned it off on the page and nowhere else.
  void _setSide(String side, bool on) {
    final merged = _read();
    merged['sides'] = _sides(merged)..[side] = on;
    onChanged(merged);
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
                  // Missing is on, as on the server.
                  selected: sides[side] != false,
                  onSelected: (on) => _setSide(side, on),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A column's stored `width` as a percentage; 0 for one that has none (the
/// server shares what is left between those).
double _percentOf(Object? width) =>
    width is String && width.trim().endsWith('%')
    ? double.tryParse(width.trim().replaceAll('%', '')) ?? 0
    : 0;

class _ColumnRow extends StatelessWidget {
  const _ColumnRow({
    super.key,
    required this.index,
    required this.column,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onDelete,
    required this.onColumnChanged,
    required this.othersWidth,
  });

  final int index;
  final double othersWidth;
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
      // What the user set — its share of the table and its alignment — in
      // words. The field path (`item.product_key`) is the server's name for
      // the column, not the user's.
      subtitle: Text(
        [if (width.isNotEmpty) width, context.tr(align)].join('  ·  '),
        style: TextStyle(fontSize: 11.5, color: tokens.ink3),
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
        othersWidth: othersWidth,
      ),
    );
  }
}

class _ExpandedColumnEditor extends StatelessWidget {
  const _ExpandedColumnEditor({
    required this.column,
    required this.onColumnChanged,
    required this.othersWidth,
  });

  final double othersWidth;
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
          _ColumnFieldPicker(
            value: (column['field'] as String?) ?? '',
            onChanged: (v) => onColumnChanged('field', v),
          ),
          _ColumnWidthSlider(
            value: (column['width'] as String?) ?? '',
            othersTotal: othersWidth,
            onChanged: (v) => onColumnChanged('width', v),
          ),
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

/// The line-item value a column shows: one of the fields the server knows,
/// by name — it used to be `item.product_key` typed into a text field.
class _ColumnFieldPicker extends StatelessWidget {
  const _ColumnFieldPicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final known = [
      for (final c in _TableBlockPropertiesState._kAvailableColumns)
        (
          field: c['field'] as String,
          label: resolveTableHeaderLabel(context, c['header'] as String),
        ),
    ];
    final current = known.any((k) => k.field == value) ? value : null;
    return PropertyRow(
      label: context.tr('field'),
      child: DropdownButtonHideUnderline(
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: tokens.border),
            borderRadius: BorderRadius.circular(InRadii.r1),
          ),
          child: DropdownButton<String>(
            value: current,
            isDense: true,
            isExpanded: true,
            // A field this list does not know — another client's, or a
            // newer server's — is shown as it is stored, never replaced.
            hint: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: tokens.ink3),
            ),
            style: DefaultTextStyle.of(
              context,
            ).style.copyWith(fontSize: 13, color: tokens.ink),
            items: [
              for (final k in known)
                DropdownMenuItem(
                  value: k.field,
                  child: Text(k.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    );
  }
}

/// A column's width as a share of the table, in steps of 5%. The server
/// gives whatever the columns leave over to the description column.
class _ColumnWidthSlider extends StatelessWidget {
  const _ColumnWidthSlider({
    required this.value,
    required this.othersTotal,
    required this.onChanged,
  });

  final String value;

  /// What the table's other columns add up to, in percent. This one stops
  /// at what they leave: columns that total more than the table are squeezed
  /// by the browser in an order nobody chose.
  final double othersTotal;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final room = (100 - othersTotal).clamp(5.0, 80.0);
    final percent = (double.tryParse(value.replaceAll('%', '').trim()) ?? 15)
        .clamp(5.0, 80.0);
    return PropertyRow(
      label: context.tr('width'),
      child: Row(
        children: [
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: percent,
                min: 5,
                max: 80,
                divisions: 15,
                label: '${percent.round()}%',
                onChanged: (v) {
                  // Never past what is left — unless it is already past it,
                  // when narrowing must still be possible.
                  final capped = v > room && v > percent ? room : v;
                  onChanged('${(capped / 5).round() * 5}%');
                },
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '${percent.round()}%',
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 12.5, color: context.inTheme.ink2),
            ),
          ),
        ],
      ),
    );
  }
}
