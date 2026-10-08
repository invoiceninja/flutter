import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_inputs.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_view_model.dart';

/// Phase 7a: property editor for the `qrcode` block. Mirrors React's
/// `QRCodeBlockProperties.tsx` 1:1 — a 2-column button grid of the five
/// preset QR types (each writes both `qrType` AND `data` to the matching
/// template variable), plus `size` (PxInput) and `align`
/// (`AlignmentInput`).
class QrcodeBlockProperties extends StatelessWidget {
  const QrcodeBlockProperties({
    super.key,
    required this.vm,
    required this.block,
  });

  final WysiwygDesignViewModel vm;
  final DesignBlock block;

  // QR preset types — the five React supports. Each entry maps the
  // user-facing label key to the template variable that ultimately
  // resolves into the QR's `data` payload.
  static const List<({String type, String label, String variable})> _kPresets =
      [
        (
          type: 'payment_link',
          label: 'payment_link',
          variable: r'$payment_qrcode',
        ),
        (type: 'sepa', label: 'sepa_qr_code', variable: r'$sepa_qr_code'),
        (type: 'swiss', label: 'swiss_qr_bill', variable: r'$swiss_qr'),
        (type: 'spc', label: 'spc_qr_code', variable: r'$spc_qr_code'),
        (
          type: 'verifactu',
          label: 'verifactu_qr_code',
          variable: r'$verifactu_qr_code',
        ),
      ];

  void _setPreset(({String type, String label, String variable}) preset) {
    final next = Map<String, dynamic>.from(block.properties);
    next['qrType'] = preset.type;
    next['data'] = preset.variable;
    vm.updateBlock(block.copyWith(properties: next));
  }

  void _writeProperty(String key, Object? value) {
    vm.updateBlock(
      block.copyWith(
        properties: mergePropertyOrOmit(block.properties, key, value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentType =
        (block.properties['qrType'] as String?) ?? 'payment_link';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 2-column button grid of preset types. Active preset shows in
        // the accent color.
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: InSpacing.sm,
          crossAxisSpacing: InSpacing.sm,
          childAspectRatio: 3.5,
          children: [
            for (final p in _kPresets)
              _PresetButton(
                labelKey: p.label,
                selected: currentType == p.type,
                onPressed: () => _setPreset(p),
              ),
          ],
        ),
        // No size control: the server draws the code at 150px whatever the
        // block says (`docs/invoice-designer.md`).
        const SectionDivider(labelKey: 'layout'),
        AlignmentInput(
          labelKey: 'alignment',
          value: block.properties['align'] as String?,
          onChanged: (v) => _writeProperty('align', v),
        ),
      ],
    );
  }
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({
    required this.labelKey,
    required this.selected,
    required this.onPressed,
  });

  final String labelKey;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return FilledButton.tonal(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 40),
        backgroundColor: selected ? tokens.accent : tokens.surfaceAlt,
        foregroundColor: selected ? Colors.white : tokens.ink,
      ),
      onPressed: onPressed,
      child: Text(
        context.tr(labelKey),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
