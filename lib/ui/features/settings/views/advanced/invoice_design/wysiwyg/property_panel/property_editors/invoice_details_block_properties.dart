import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/design.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_editors/info_block_properties.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_inputs.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_view_model.dart';

/// Phase 7a: property editor for `invoice-details`. Reuses
/// [InfoBlockProperties] for the reorderable `fieldConfigs` machinery
/// (drag handle + label + hideIfEmpty toggle + delete + add-via-picker)
/// then adds the block-level label/value layout knobs that React's
/// `InvoiceDetailsBlockProperties.tsx` exposes — `showLabels`,
/// `labelAlign`, `valueAlign`, `labelColor`, plus the spacing PxInputs.
class InvoiceDetailsBlockProperties extends StatelessWidget {
  const InvoiceDetailsBlockProperties({
    super.key,
    required this.vm,
    required this.block,
  });

  final WysiwygDesignViewModel vm;
  final DesignBlock block;

  void _write(String key, Object? value) {
    vm.updateBlock(
      block.copyWith(
        properties: mergePropertyOrOmit(block.properties, key, value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final props = block.properties;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Field reorder list shared with the client-info / company-info
        // editors. Same drag handle + hideIfEmpty + delete + add-field
        // contract.
        InfoBlockProperties(vm: vm, block: block),
        const SectionDivider(labelKey: 'labels'),
        PropertySwitch(
          labelKey: 'show_labels',
          value: (props['showLabels'] as bool?) ?? true,
          onChanged: (v) => _write('showLabels', v),
        ),
        AlignmentInput(
          labelKey: 'label_align',
          value: props['labelAlign'] as String?,
          onChanged: (v) => _write('labelAlign', v),
        ),
        AlignmentInput(
          labelKey: 'value_align',
          value: props['valueAlign'] as String?,
          onChanged: (v) => _write('valueAlign', v),
        ),
        ColorInput(
          labelKey: 'label_color',
          value: props['labelColor'] as String?,
          onChanged: (v) => _write('labelColor', v),
          defaultValue: '#6B7280',
        ),
        const SectionDivider(labelKey: 'spacing'),
        PxInput(
          labelKey: 'label_padding',
          value: props['labelPadding'],
          resettable: true,
          onChanged: (v) => _write('labelPadding', v),
        ),
        PxInput(
          labelKey: 'value_padding',
          value: props['valuePadding'],
          resettable: true,
          onChanged: (v) => _write('valuePadding', v),
        ),
        PxInput(
          labelKey: 'label_value_gap',
          value: props['labelValueGap'],
          hintText: '12',
          resettable: true,
          onChanged: (v) => _write('labelValueGap', v),
        ),
        PxInput(
          labelKey: 'row_spacing',
          value: props['rowSpacing'],
          resettable: true,
          onChanged: (v) => _write('rowSpacing', v),
        ),
        PxInput(
          labelKey: 'value_min_width',
          value: props['valueMinWidth'],
          resettable: true,
          onChanged: (v) => _write('valueMinWidth', v),
        ),
      ],
    );
  }
}
