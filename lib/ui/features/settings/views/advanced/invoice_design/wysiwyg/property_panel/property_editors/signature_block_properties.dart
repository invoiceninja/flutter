import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/design.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_inputs.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_view_model.dart';

/// Phase 7a: signature block property editor. Exposes the label text +
/// line/date toggles + alignment + color + font size.
class SignatureBlockProperties extends StatefulWidget {
  const SignatureBlockProperties({
    super.key,
    required this.vm,
    required this.block,
  });

  final WysiwygDesignViewModel vm;
  final DesignBlock block;

  @override
  State<SignatureBlockProperties> createState() =>
      _SignatureBlockPropertiesState();
}

class _SignatureBlockPropertiesState extends State<SignatureBlockProperties> {
  late final TextEditingController _label = TextEditingController(
    text: _labelText(),
  );
  String _lastBlockId = '';

  String _labelText() => (widget.block.properties['label'] as String?) ?? '';

  @override
  void initState() {
    super.initState();
    _lastBlockId = widget.block.id;
  }

  @override
  void didUpdateWidget(covariant SignatureBlockProperties old) {
    super.didUpdateWidget(old);
    if (_lastBlockId != widget.block.id) {
      _lastBlockId = widget.block.id;
      _label.text = _labelText();
    }
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _write(String key, Object? value) {
    widget.vm.updateBlock(
      widget.block.copyWith(
        properties: mergePropertyOrOmit(widget.block.properties, key, value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final props = widget.block.properties;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _label,
          decoration: InputDecoration(
            labelText: context.tr('label'),
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => _write('label', v),
        ),
        PropertySwitch(
          labelKey: 'show_line',
          value: (props['showLine'] as bool?) ?? true,
          onChanged: (v) => _write('showLine', v),
        ),
        PropertySwitch(
          labelKey: 'show_date',
          value: (props['showDate'] as bool?) ?? false,
          onChanged: (v) => _write('showDate', v),
        ),
        AlignmentInput(
          labelKey: 'alignment',
          value: props['align'] as String?,
          onChanged: (v) => _write('align', v),
        ),
        ColorInput(
          labelKey: 'color',
          value: props['color'] as String?,
          onChanged: (v) => _write('color', v),
          defaultValue: '#6B7280',
        ),
        PxInput(
          labelKey: 'font_size',
          value: props['fontSize'],
          hintText: '12',
          resettable: true,
          onChanged: (v) => _write('fontSize', v),
        ),
      ],
    );
  }
}
