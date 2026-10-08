import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_inputs.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_view_model.dart';

/// Phase 7a: property editor for the `divider` block. Exposes thickness,
/// color, line-style (solid / dashed — dashed renders as solid today,
/// but the property round-trips for the server PDF path), and the two
/// vertical margins.
class DividerBlockProperties extends StatelessWidget {
  const DividerBlockProperties({
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
        PxInput(
          labelKey: 'thickness',
          value: props['thickness'],
          hintText: '1',
          resettable: true,
          onChanged: (v) => _write('thickness', v),
        ),
        ColorInput(
          labelKey: 'color',
          value: props['color'] as String?,
          onChanged: (v) => _write('color', v),
          defaultValue: '#E5E7EB',
        ),
        SizedBox(height: InSpacing.md(context)),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(labelText: context.tr('style')),
          initialValue: (props['style'] as String?) ?? 'solid',
          items: [
            DropdownMenuItem(value: 'solid', child: Text(context.tr('solid'))),
            DropdownMenuItem(
              value: 'dashed',
              child: Text(context.tr('dashed')),
            ),
          ],
          onChanged: (v) {
            if (v != null) _write('style', v);
          },
        ),
        const SectionDivider(labelKey: 'spacing'),
        PxInput(
          labelKey: 'margin_top',
          value: props['marginTop'],
          hintText: '10',
          resettable: true,
          onChanged: (v) => _write('marginTop', v),
        ),
        PxInput(
          labelKey: 'margin_bottom',
          value: props['marginBottom'],
          hintText: '10',
          resettable: true,
          onChanged: (v) => _write('marginBottom', v),
        ),
      ],
    );
  }
}
