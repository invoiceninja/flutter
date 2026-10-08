import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/design.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_inputs.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_view_model.dart';

/// Phase 7a: spacer block property editor — just a height field. The
/// canvas takes its visible space from the block's grid `h`; this knob
/// drives the server PDF's actual pixel height.
class SpacerBlockProperties extends StatelessWidget {
  const SpacerBlockProperties({
    super.key,
    required this.vm,
    required this.block,
  });

  final WysiwygDesignViewModel vm;
  final DesignBlock block;

  @override
  Widget build(BuildContext context) {
    return PxInput(
      labelKey: 'height',
      value: block.properties['height'],
      hintText: '40',
      // Not clearable: the server reads the height unguarded.
      minPx: 1,
      maxPx: 400,
      onChanged: (v) => vm.updateBlock(
        block.copyWith(
          properties: mergePropertyOrOmit(block.properties, 'height', v),
        ),
      ),
    );
  }
}
