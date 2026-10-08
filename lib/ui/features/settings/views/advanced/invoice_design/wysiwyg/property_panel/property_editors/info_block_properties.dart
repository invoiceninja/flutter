import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_renderers/_shared.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/cell_typography_editor.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/expandable_property_row.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_inputs.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/variable_picker.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/variables/variable_replacer.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_view_model.dart';

/// Shared property editor for `client-info`, `company-info`,
/// `client-shipping-info`, plus the fieldConfigs section of
/// `invoice-details`. Phase 7c added per-row inline expansion with
/// label / prefix / suffix / hideIfEmpty + label/value style sub-cards.
class InfoBlockProperties extends StatefulWidget {
  const InfoBlockProperties({super.key, required this.vm, required this.block});

  final WysiwygDesignViewModel vm;
  final DesignBlock block;

  @override
  State<InfoBlockProperties> createState() => _InfoBlockPropertiesState();
}

class _InfoBlockPropertiesState extends State<InfoBlockProperties> {
  int? _expandedIndex;

  List<Map<String, dynamic>> _fields() {
    final raw = widget.block.properties['fieldConfigs'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return [
      for (final item in raw)
        if (item is Map<String, dynamic>) Map<String, dynamic>.from(item),
    ];
  }

  void _updateProperty(String key, Object? value) {
    widget.vm.updateBlock(
      widget.block.copyWith(
        properties: mergePropertyOrOmit(widget.block.properties, key, value),
      ),
    );
  }

  void _replaceFields(List<Map<String, dynamic>> next) {
    final props = Map<String, dynamic>.from(widget.block.properties);
    props['fieldConfigs'] = next;
    widget.vm.updateBlock(widget.block.copyWith(properties: props));
  }

  void _updateField(int index, String key, Object? value) {
    final fields = _fields();
    final merged = Map<String, dynamic>.from(fields[index]);
    if (value == null || (value is String && value.isEmpty)) {
      merged.remove(key);
    } else {
      merged[key] = value;
    }
    fields[index] = merged;
    _replaceFields(fields);
  }

  void _onReorder(int oldIndex, int newIndex) {
    final fields = _fields();
    // onReorderItem already maps newIndex to the post-removal destination.
    final adjusted = newIndex;
    if (adjusted == oldIndex) return;
    final item = fields.removeAt(oldIndex);
    fields.insert(adjusted, item);
    setState(() {
      // Track the moved row's expansion across reorder.
      if (_expandedIndex == oldIndex) {
        _expandedIndex = adjusted;
      } else if (_expandedIndex != null) {
        final ei = _expandedIndex!;
        if (oldIndex < ei && adjusted >= ei) _expandedIndex = ei - 1;
        if (oldIndex > ei && adjusted <= ei) _expandedIndex = ei + 1;
      }
    });
    _replaceFields(fields);
  }

  void _delete(int index) {
    final fields = _fields()..removeAt(index);
    setState(() {
      if (_expandedIndex == index) {
        _expandedIndex = null;
      } else if (_expandedIndex != null && _expandedIndex! > index) {
        _expandedIndex = _expandedIndex! - 1;
      }
    });
    _replaceFields(fields);
  }

  void _toggleExpanded(int index) {
    setState(() {
      _expandedIndex = _expandedIndex == index ? null : index;
    });
  }

  Future<void> _addField() async {
    final isDetails = widget.block.type == 'invoice-details';
    final categories = switch (widget.block.type) {
      'client-shipping-info' => {
        VariableCategory.shipping,
        VariableCategory.client,
      },
      'company-info' => {VariableCategory.company},
      // The document's own fields — it used to offer the client's.
      'invoice-details' => {VariableCategory.invoice},
      _ => {VariableCategory.client, VariableCategory.contact},
    };
    final pick = await showVariablePicker(
      context,
      categories: categories,
      customFieldLabels: widget.vm.customFieldLabels,
    );
    if (pick == null) return;
    final fields = _fields();
    final token = pick.token;
    final id = token.replaceAll(RegExp(r'[\$.]'), '_');
    if (!isDetails) {
      // An info block prints the value alone; the label is only this row's
      // name in the panel.
      fields.add({
        'id': id,
        'label': pick.labelKey,
        'variable': token,
        'hideIfEmpty': true,
      });
    } else {
      // The details block prints "Label  value", and prints the label as it
      // is stored — so it must be a token the server translates, never this
      // app's translation key (which printed `custom1` and `public_notes`
      // verbatim). The flat form where the page knows it (`$number_label`,
      // as the block's defaults are); otherwise the token's own label,
      // which the server makes for every value it knows.
      final flat = '\$${token.substring(1).split('.').last}';
      final flatLabel = '${flat}_label';
      final known = kLabelTranslationMap.containsKey(flatLabel);
      fields.add({
        'id': id,
        'label': known ? flatLabel : '${token}_label',
        'variable': known ? flat : token,
        'hideIfEmpty': true,
      });
    }
    _replaceFields(fields);
  }

  @override
  Widget build(BuildContext context) {
    final props = widget.block.properties;
    final type = widget.block.type;
    // What the server prints differs by block, and a control for something
    // it ignores is a control that lies (probed on the demo server,
    // `docs/invoice-designer.md`): a title prints for the client and ship-to
    // blocks only — never for the company block or the details block — and
    // a field's prefix / suffix for the company and client blocks, never for
    // the details block.
    final printsTitle = type == 'client-info' || type == 'client-shipping-info';
    final printsAffixes = type != 'invoice-details';
    final showTitle = printsTitle && ((props['showTitle'] as bool?) ?? false);
    final title = (props['title'] as String?) ?? '';
    final fields = _fields();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (printsTitle)
          PropertySwitch(
            labelKey: 'show_title',
            value: showTitle,
            onChanged: (v) => _updateProperty('showTitle', v),
          ),
        if (showTitle)
          Padding(
            padding: EdgeInsets.only(bottom: InSpacing.md(context)),
            child: TextFormField(
              initialValue: title,
              decoration: InputDecoration(
                labelText: context.tr('title'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => _updateProperty('title', v),
            ),
          ),
        SizedBox(height: InSpacing.md(context)),
        Row(
          children: [
            Expanded(
              child: Text(
                context.tr('field'),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: Text(context.tr('add_field')),
              onPressed: _addField,
            ),
          ],
        ),
        SizedBox(height: InSpacing.sm),
        if (fields.isEmpty)
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
            itemCount: fields.length,
            onReorderItem: _onReorder,
            itemBuilder: (context, index) => _FieldRow(
              key: ValueKey('${fields[index]['id']}-$index'),
              index: index,
              field: fields[index],
              expanded: _expandedIndex == index,
              onToggleExpanded: () => _toggleExpanded(index),
              onDelete: () => _delete(index),
              onFieldChanged: (k, v) => _updateField(index, k, v),
              printsAffixes: printsAffixes,
            ),
          ),
        const SectionDivider(labelKey: 'typography'),
        FontSizeInput(
          labelKey: 'font_size',
          value: props['fontSize'] as String?,
          onChanged: (v) => _updateProperty('fontSize', v),
        ),
        LineHeightInput(
          labelKey: 'line_height',
          value: props['lineHeight'] as String?,
          onChanged: (v) => _updateProperty('lineHeight', v),
        ),
        ColorInput(
          labelKey: 'color',
          value: props['color'] as String?,
          onChanged: (v) => _updateProperty('color', v),
        ),
        const SectionDivider(labelKey: 'layout'),
        AlignmentInput(
          labelKey: 'alignment',
          value: props['align'] as String?,
          onChanged: (v) => _updateProperty('align', v),
        ),
        PxInput(
          labelKey: 'padding',
          value: props['padding'],
          resettable: true,
          onChanged: (v) => _updateProperty('padding', v),
        ),
        if (showTitle) ...[
          const SectionDivider(labelKey: 'title'),
          PxInput(
            labelKey: 'font_size',
            value: props['titleFontSize'],
            resettable: true,
            onChanged: (v) => _updateProperty('titleFontSize', v),
          ),
          FontStyleInput(
            fontWeight: props['titleFontWeight'] as String?,
            fontStyle: props['titleFontStyle'] as String?,
            onFontWeightChanged: (v) => _updateProperty('titleFontWeight', v),
            onFontStyleChanged: (v) => _updateProperty('titleFontStyle', v),
          ),
          ColorInput(
            labelKey: 'color',
            value: props['titleColor'] as String?,
            onChanged: (v) => _updateProperty('titleColor', v),
          ),
          AlignmentInput(
            labelKey: 'alignment',
            value: props['titleAlign'] as String?,
            onChanged: (v) => _updateProperty('titleAlign', v),
          ),
        ],
      ],
    );
  }
}

/// Reorderable row inside the fieldConfigs list. Collapsed: handle +
/// label + variable + expand-chevron + delete. Expanded: inline
/// `label` / `prefix` / `suffix` / `hideIfEmpty` controls + nested
/// CellTypographyEditor for `labelStyle` and `valueStyle`. The
/// surrounding chrome lives in [ExpandablePropertyRow] (Phase 15b).
class _FieldRow extends StatelessWidget {
  const _FieldRow({
    super.key,
    required this.index,
    required this.field,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onDelete,
    required this.onFieldChanged,
    required this.printsAffixes,
  });

  final int index;
  final Map<String, dynamic> field;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onDelete;
  final void Function(String key, Object? value) onFieldChanged;
  final bool printsAffixes;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final labelKey = (field['label'] as String?) ?? '';
    final variable = (field['variable'] as String?) ?? '';
    // A key for an info row, a `$…_label` token for a details row.
    final displayLabel = labelKey.isEmpty
        ? variable
        : labelKey.startsWith(r'$')
        ? replaceLabelVariables(
            labelKey,
            context.tr,
            customFieldLabels: DesignerRenderScope.customFieldLabelsOf(context),
          )
        : context.tr(labelKey);
    return ExpandablePropertyRow(
      index: index,
      title: Text(
        displayLabel,
        style: Theme.of(context).textTheme.bodyMedium,
        overflow: TextOverflow.ellipsis,
      ),
      // An example of what the row prints, where the sample document has
      // one; the bare `$token` only as a last resort.
      subtitle: Text(
        _exampleOf(context, variable),
        style: TextStyle(fontSize: 11.5, color: tokens.ink3),
        overflow: TextOverflow.ellipsis,
      ),
      expanded: expanded,
      onToggleExpanded: onToggleExpanded,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 18),
        onPressed: onDelete,
      ),
      expandedChild: _ExpandedFieldEditor(
        field: field,
        onFieldChanged: onFieldChanged,
        printsAffixes: printsAffixes,
      ),
    );
  }
}

/// What the row prints for the document on the page; a dash when that
/// document has nothing there.
String _exampleOf(BuildContext context, String variable) {
  final example = replaceVariables(
    variable,
    data: DesignerRenderScope.sampleOf(context),
    formatter: DesignerRenderScope.formatterOf(context),
  );
  return example.trim().isEmpty ? '—' : example;
}

class _ExpandedFieldEditor extends StatelessWidget {
  const _ExpandedFieldEditor({
    required this.field,
    required this.onFieldChanged,
    required this.printsAffixes,
  });

  final Map<String, dynamic> field;
  final void Function(String key, Object? value) onFieldChanged;

  /// Whether the server prints a field's prefix and suffix for this block.
  final bool printsAffixes;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    // Absent is on, as on the server (`$config['hideIfEmpty'] ?? true`).
    final hideIfEmpty = (field['hideIfEmpty'] as bool?) ?? true;
    return Container(
      margin: EdgeInsets.only(top: InSpacing.sm, left: 24),
      padding: EdgeInsets.all(InSpacing.md(context)),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(InRadii.r2),
        border: Border.all(color: tokens.border, width: 1),
      ),
      // A transparent Material gives the descendant SwitchListTile a Material
      // ancestor to paint ink on — without it, Flutter 3.44 asserts because
      // this Container's background would hide the ink.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              initialValue: (field['label'] as String?) ?? '',
              decoration: InputDecoration(
                labelText: context.tr('label'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => onFieldChanged('label', v),
            ),
            if (printsAffixes) ...[
              SizedBox(height: InSpacing.md(context)),
              TextFormField(
                initialValue: (field['prefix'] as String?) ?? '',
                decoration: InputDecoration(
                  labelText: context.tr('prefix'),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => onFieldChanged('prefix', v),
                autocorrect: false,
              ),
              SizedBox(height: InSpacing.md(context)),
              TextFormField(
                initialValue: (field['suffix'] as String?) ?? '',
                decoration: InputDecoration(
                  labelText: context.tr('suffix'),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => onFieldChanged('suffix', v),
                autocorrect: false,
              ),
            ],
            PropertySwitch(
              labelKey: 'hide_if_empty',
              value: hideIfEmpty,
              onChanged: (v) => onFieldChanged('hideIfEmpty', v),
            ),
            SizedBox(height: InSpacing.sm),
            CellTypographyEditor(
              headingKey: 'label_style',
              value: field['labelStyle'] as Map<String, dynamic>?,
              onChanged: (v) => onFieldChanged('labelStyle', v),
            ),
            SizedBox(height: InSpacing.md(context)),
            CellTypographyEditor(
              headingKey: 'value_style',
              value: field['valueStyle'] as Map<String, dynamic>?,
              onChanged: (v) => onFieldChanged('valueStyle', v),
            ),
          ],
        ),
      ),
    );
  }
}
