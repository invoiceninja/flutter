import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_renderers/_shared.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/cell_typography_editor.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/expandable_property_row.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_inputs.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/variables/variable_replacer.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_view_model.dart';

/// Property editor for the `total` block. Reorderable items + per-row
/// expansion (Phase 7c) for label / fontSize / fontWeight / color /
/// isTotal / isBalance / balanceColor; plus block-level layout knobs
/// (Phase 7e).
class TotalBlockProperties extends StatefulWidget {
  const TotalBlockProperties({
    super.key,
    required this.vm,
    required this.block,
  });

  final WysiwygDesignViewModel vm;
  final DesignBlock block;

  @override
  State<TotalBlockProperties> createState() => _TotalBlockPropertiesState();
}

class _TotalBlockPropertiesState extends State<TotalBlockProperties> {
  int? _expandedIndex;

  List<Map<String, dynamic>> _items() {
    final raw = widget.block.properties['items'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return [
      for (final it in raw)
        if (it is Map<String, dynamic>) Map<String, dynamic>.from(it),
    ];
  }

  void _writeItems(List<Map<String, dynamic>> next) {
    final props = Map<String, dynamic>.from(widget.block.properties);
    props['items'] = next;
    widget.vm.updateBlock(widget.block.copyWith(properties: props));
  }

  void _writeProperty(String key, Object? value) {
    widget.vm.updateBlock(
      widget.block.copyWith(
        properties: mergePropertyOrOmit(widget.block.properties, key, value),
      ),
    );
  }

  void _updateItem(int index, String key, Object? value) {
    _patchItem(index, {key: value});
  }

  /// Apply multiple key updates to one item atomically. Critical when a
  /// single editor (e.g. [CellTypographyEditor]) emits writes for
  /// several keys at once — sequential `_updateItem` calls within one
  /// frame read stale `widget.block` and clobber each other.
  void _patchItem(int index, Map<String, Object?> patch) {
    final items = _items();
    final merged = Map<String, dynamic>.from(items[index]);
    patch.forEach((k, v) {
      if (v == null || (v is String && v.isEmpty)) {
        merged.remove(k);
      } else {
        merged[k] = v;
      }
    });
    items[index] = merged;
    _writeItems(items);
  }

  void _reorder(int oldIndex, int newIndex) {
    final items = _items();
    // onReorderItem already maps newIndex to the post-removal destination.
    final adjusted = newIndex;
    if (adjusted == oldIndex) return;
    final moved = items.removeAt(oldIndex);
    items.insert(adjusted, moved);
    setState(() {
      if (_expandedIndex == oldIndex) {
        _expandedIndex = adjusted;
      } else if (_expandedIndex != null) {
        final ei = _expandedIndex!;
        if (oldIndex < ei && adjusted >= ei) _expandedIndex = ei - 1;
        if (oldIndex > ei && adjusted <= ei) _expandedIndex = ei + 1;
      }
    });
    _writeItems(items);
  }

  void _toggleShow(int index, bool value) {
    final items = _items();
    items[index] = {...items[index], 'show': value};
    _writeItems(items);
  }

  void _toggleExpanded(int index) {
    setState(() {
      _expandedIndex = _expandedIndex == index ? null : index;
    });
  }

  /// The rows a totals block can carry: `(label token, value token)`. The
  /// block used to be fixed at the six it was created with, with no way to
  /// show a surcharge or a deposit.
  static const List<(String, String)> _kRows = [
    (r'$subtotal_label', r'$subtotal'),
    (r'$discount_label', r'$discount'),
    (r'$taxes_label', r'$taxes'),
    (r'$custom_surcharge1_label', r'$custom_surcharge1'),
    (r'$custom_surcharge2_label', r'$custom_surcharge2'),
    (r'$custom_surcharge3_label', r'$custom_surcharge3'),
    (r'$custom_surcharge4_label', r'$custom_surcharge4'),
    (r'$total_label', r'$total'),
    (r'$paid_to_date_label', r'$paid_to_date'),
    (r'$partial_label', r'$partial'),
    (r'$balance_due_label', r'$balance_due'),
  ];

  List<(String, String)> _missingRows(List<Map<String, dynamic>> items) {
    final present = {for (final it in items) it['field']};
    return [
      for (final row in _kRows)
        if (!present.contains(row.$2)) row,
    ];
  }

  Future<void> _addRow(List<Map<String, dynamic>> items) async {
    final picked = await showDialog<(String, String)>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(ctx.tr('add_row')),
        children: [
          for (final row in _missingRows(items))
            ListTile(
              dense: true,
              title: Text(replaceLabelVariables(row.$1, ctx.tr)),
              onTap: () => Navigator.of(ctx).pop(row),
            ),
        ],
      ),
    );
    if (picked == null) return;
    _writeItems([
      ..._items(),
      {'label': picked.$1, 'field': picked.$2, 'show': true},
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final props = widget.block.properties;
    final items = _items();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PropertySwitch(
          labelKey: 'show_labels',
          value: (props['showLabels'] as bool?) ?? true,
          onChanged: (v) => _writeProperty('showLabels', v),
        ),
        SizedBox(height: InSpacing.md(context)),
        Row(
          children: [
            Expanded(
              child: Text(
                context.tr('totals'),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            if (_missingRows(items).isNotEmpty)
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: Text(context.tr('add_row')),
                onPressed: () => _addRow(items),
              ),
          ],
        ),
        SizedBox(height: InSpacing.sm),
        if (items.isEmpty)
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
            itemCount: items.length,
            onReorderItem: _reorder,
            itemBuilder: (context, index) => _TotalItemRow(
              key: ValueKey('total-item-$index-${items[index]['field']}'),
              index: index,
              item: items[index],
              expanded: _expandedIndex == index,
              onToggleShow: (v) => _toggleShow(index, v),
              onToggleExpanded: () => _toggleExpanded(index),
              onItemChanged: (k, v) => _updateItem(index, k, v),
              onItemPatch: (patch) => _patchItem(index, patch),
            ),
          ),
        const SectionDivider(labelKey: 'layout'),
        // Phase 9a: block-level alignment positions the totals table
        // left/center/right within its grid cell. Mirrors React
        // TotalBlock.tsx margin-based positioning.
        AlignmentInput(
          labelKey: 'alignment',
          value: props['align'] as String?,
          onChanged: (v) => _writeProperty('align', v),
        ),
        AlignmentInput(
          labelKey: 'label_align',
          value: props['labelAlign'] as String?,
          onChanged: (v) => _writeProperty('labelAlign', v),
        ),
        AlignmentInput(
          labelKey: 'value_align',
          value: props['valueAlign'] as String?,
          onChanged: (v) => _writeProperty('valueAlign', v),
        ),
        const SectionDivider(labelKey: 'typography'),
        // Phase 9b: block-level fontSize defaults every item's size
        // unless overridden per-item. Renderer already reads
        // props['fontSize'] — this exposes the editor control.
        FontSizeInput(
          labelKey: 'font_size',
          value: props['fontSize'] as String?,
          onChanged: (v) => _writeProperty('fontSize', v),
        ),
        FontStyleInput(
          fontWeight: props['totalFontWeight'] as String?,
          fontStyle: null,
          showItalic: false,
          onFontWeightChanged: (v) => _writeProperty('totalFontWeight', v),
          onFontStyleChanged: (_) {},
        ),
        ColorInput(
          labelKey: 'label_color',
          value: props['labelColor'] as String?,
          onChanged: (v) => _writeProperty('labelColor', v),
          defaultValue: '#6B7280',
        ),
        ColorInput(
          labelKey: 'amount_color',
          value: props['amountColor'] as String?,
          onChanged: (v) => _writeProperty('amountColor', v),
        ),
        ColorInput(
          labelKey: 'total_color',
          value: props['totalColor'] as String?,
          onChanged: (v) => _writeProperty('totalColor', v),
        ),
        ColorInput(
          labelKey: 'balance_color',
          value: props['balanceColor'] as String?,
          onChanged: (v) => _writeProperty('balanceColor', v),
        ),
        // Cell padding, gaps and the page-break rule: rarely touched.
        PropertyDisclosure(
          children: [
            PxInput(
              labelKey: 'spacing',
              value: props['spacing'],
              resettable: true,
              onChanged: (v) => _writeProperty('spacing', v),
            ),
            PxInput(
              labelKey: 'label_padding',
              value: props['labelPadding'],
              resettable: true,
              onChanged: (v) => _writeProperty('labelPadding', v),
            ),
            PxInput(
              labelKey: 'value_padding',
              value: props['valuePadding'],
              resettable: true,
              onChanged: (v) => _writeProperty('valuePadding', v),
            ),
            PxInput(
              labelKey: 'label_value_gap',
              value: props['labelValueGap'],
              resettable: true,
              onChanged: (v) => _writeProperty('labelValueGap', v),
            ),
            PxInput(
              labelKey: 'value_min_width',
              value: props['valueMinWidth'],
              resettable: true,
              onChanged: (v) => _writeProperty('valueMinWidth', v),
            ),
            // Page-break control. Server-only — Flutter's canvas
            // preview doesn't paginate, but the wire payload round-trips
            // the boolean and the server's PDF generator honors it.
            // Mirrors React TotalBlockProperties.tsx lines 474-482.
            PropertySwitch(
              labelKey: 'keep_together',
              hintKey: 'keep_together_hint',
              value: (props['keepTogether'] as bool?) ?? false,
              onChanged: (v) => _writeProperty('keepTogether', v),
            ),
          ],
        ),
      ],
    );
  }
}

class _TotalItemRow extends StatelessWidget {
  const _TotalItemRow({
    super.key,
    required this.index,
    required this.item,
    required this.expanded,
    required this.onToggleShow,
    required this.onToggleExpanded,
    required this.onItemChanged,
    required this.onItemPatch,
  });

  final int index;
  final Map<String, dynamic> item;
  final bool expanded;
  final ValueChanged<bool> onToggleShow;
  final VoidCallback onToggleExpanded;
  final void Function(String key, Object? value) onItemChanged;
  final void Function(Map<String, Object?> patch) onItemPatch;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final labelKey = (item['label'] as String?) ?? '';
    final field = (item['field'] as String?) ?? '';
    final show = (item['show'] as bool?) ?? true;
    final isTotal = (item['isTotal'] as bool?) ?? false;
    final isBalance = (item['isBalance'] as bool?) ?? false;
    return ExpandablePropertyRow(
      index: index,
      title: Text(
        _readableLabel(context, labelKey, field),
        style: Theme.of(context).textTheme.bodyMedium,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Text(
            _exampleOf(context, field),
            style: TextStyle(fontSize: 11.5, color: tokens.ink3),
          ),
          if (isTotal || isBalance) ...[
            SizedBox(width: InSpacing.sm),
            Icon(
              isBalance
                  ? Icons.account_balance_wallet_outlined
                  : Icons.functions,
              size: 12,
              color: tokens.ink3,
            ),
          ],
        ],
      ),
      expanded: expanded,
      onToggleExpanded: onToggleExpanded,
      // Total items are hideable, not deletable — the show switch takes
      // the trailing slot in place of Info/Table's delete icon.
      trailing: Switch.adaptive(value: show, onChanged: onToggleShow),
      expandedChild: _ExpandedTotalEditor(
        item: item,
        onItemChanged: onItemChanged,
        onItemPatch: onItemPatch,
      ),
    );
  }

  String _readableLabel(BuildContext context, String labelKey, String field) {
    if (labelKey.isEmpty) return field;
    var key = labelKey;
    if (key.startsWith(r'$')) key = key.substring(1);
    if (key.endsWith('_label')) key = key.substring(0, key.length - 6);
    final translated = context.tr(key);
    return translated == key ? labelKey : translated;
  }
}

class _ExpandedTotalEditor extends StatelessWidget {
  const _ExpandedTotalEditor({
    required this.item,
    required this.onItemChanged,
    required this.onItemPatch,
  });

  final Map<String, dynamic> item;
  final void Function(String key, Object? value) onItemChanged;
  final void Function(Map<String, Object?> patch) onItemPatch;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final isTotal = (item['isTotal'] as bool?) ?? false;
    final isBalance = (item['isBalance'] as bool?) ?? false;
    return Container(
      margin: EdgeInsets.only(top: InSpacing.sm, left: 24),
      padding: EdgeInsets.all(InSpacing.md(context)),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(InRadii.r2),
        border: Border.all(color: tokens.border, width: 1),
      ),
      // A transparent Material gives the descendant SwitchListTiles a Material
      // ancestor to paint ink on — without it, Flutter 3.44 asserts because
      // this Container's background would hide the ink.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              initialValue: (item['label'] as String?) ?? '',
              decoration: InputDecoration(
                labelText: context.tr('label'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => onItemChanged('label', v),
            ),
            SizedBox(height: InSpacing.md(context)),
            // Phase 8d: per-item typography editor — matches the
            // Info/Table row expansions and restores the missing fontStyle
            // (italic) toggle. The flat keys stay on the item (data shape
            // unchanged); the editor is a typography sub-card view onto
            // those keys.
            CellTypographyEditor(
              headingKey: 'typography',
              value: _flatStyleView(item),
              onChanged: (next) => onItemPatch({
                'fontSize': next?['fontSize'],
                'fontWeight': next?['fontWeight'],
                'fontStyle': next?['fontStyle'],
                'color': next?['color'],
              }),
            ),
            PropertySwitch(
              labelKey: 'is_total',
              value: isTotal,
              onChanged: (v) => onItemChanged('isTotal', v),
            ),
            PropertySwitch(
              labelKey: 'is_balance',
              value: isBalance,
              onChanged: (v) => onItemChanged('isBalance', v),
            ),
            if (isBalance) ...[
              ColorInput(
                labelKey: 'balance_color',
                value: item['balanceColor'] as String?,
                onChanged: (v) => onItemChanged('balanceColor', v),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Synthesize a `Map` view of the flat typography keys on a total item
  /// so it can be edited via [CellTypographyEditor]. Returns `null` when
  /// all four keys are unset so the sub-card stays empty.
  static Map<String, dynamic>? _flatStyleView(Map<String, dynamic> item) {
    final out = <String, dynamic>{};
    for (final k in const ['fontSize', 'fontWeight', 'fontStyle', 'color']) {
      final v = item[k];
      if (v != null && !(v is String && v.isEmpty)) {
        out[k] = v;
      }
    }
    return out.isEmpty ? null : out;
  }
}

/// What the row prints for the document on the page; a dash when that
/// document has nothing there.
String _exampleOf(BuildContext context, String field) {
  final example = replaceVariables(
    field,
    data: DesignerRenderScope.sampleOf(context),
    formatter: DesignerRenderScope.formatterOf(context),
  );
  return example.trim().isEmpty ? '—' : example;
}
