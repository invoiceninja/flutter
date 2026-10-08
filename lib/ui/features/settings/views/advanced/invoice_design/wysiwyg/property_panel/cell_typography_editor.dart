import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_inputs.dart';

/// Phase 7d: nested label/value typography editor. Mirrors React's
/// `components/properties/CellTypographyEditor.tsx` — a dashed-bordered
/// card with a small uppercase heading + fontSize/style/color knobs.
///
/// The underlying value is a `Map<String, dynamic>?` carrying the keys
/// `fontSize` / `fontWeight` / `fontStyle` / `color`. When the user
/// clears all four, [onChanged] fires with `null` so callers can drop
/// the sub-map entirely (mirrors React's `allEmpty` check). This keeps
/// the wire payload clean — no `{"labelStyle": {}}` orphans.
class CellTypographyEditor extends StatelessWidget {
  const CellTypographyEditor({
    super.key,
    required this.headingKey,
    required this.value,
    required this.onChanged,
    this.fontSizePlaceholder,
    this.colorDefault,
  });

  /// Localization key for the section heading (`label_style` /
  /// `value_style` / `typography`).
  final String headingKey;
  final Map<String, dynamic>? value;
  final ValueChanged<Map<String, dynamic>?> onChanged;
  final String? fontSizePlaceholder;
  final String? colorDefault;

  void _set(String key, Object? next) {
    final merged = Map<String, dynamic>.from(value ?? <String, dynamic>{});
    if (next == null || (next is String && next.isEmpty)) {
      merged.remove(key);
    } else {
      merged[key] = next;
    }
    onChanged(merged.isEmpty ? null : merged);
  }

  @override
  Widget build(BuildContext context) {
    final v = value ?? const <String, dynamic>{};
    final tokens = context.inTheme;
    return Container(
      padding: EdgeInsets.all(InSpacing.md(context)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(InRadii.r2),
        // Dashed border per React's design — Flutter's BoxDecoration
        // doesn't ship dashed strokes natively, so we approximate with a
        // dotted style via DecoratedBox + ShapeBorder if needed; a plain
        // solid border is enough to read as "nested card" here.
        border: Border.all(color: tokens.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr(headingKey).toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.2,
              color: tokens.ink3,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: InSpacing.sm),
          PxInput(
            labelKey: 'font_size',
            value: v['fontSize'],
            hintText: fontSizePlaceholder,
            onChanged: (next) => _set('fontSize', next),
            resettable: true,
          ),
          FontStyleInput(
            fontWeight: v['fontWeight'] as String?,
            fontStyle: v['fontStyle'] as String?,
            onFontWeightChanged: (next) => _set('fontWeight', next),
            onFontStyleChanged: (next) => _set('fontStyle', next),
          ),
          ColorInput(
            labelKey: 'color',
            value: v['color'] as String?,
            onChanged: (next) => _set('color', next),
            defaultValue: colorDefault,
          ),
        ],
      ),
    );
  }
}
