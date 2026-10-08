import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/design.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_renderers/_shared.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/sample/sample_data.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/variables/variable_replacer.dart';

/// Renders the `total` block. Vertical list of label / value rows from
/// `items[]` (only those where `show != false`). `isTotal: true` rows are
/// bold; `isBalance: true` rows use `balanceColor`. Money values resolve
/// through [replaceVariables] (en-US fallback formatting from the sample
/// data's `Decimal` totals).
class TotalBlock extends StatelessWidget {
  const TotalBlock({super.key, required this.block, required this.sample});

  final DesignBlock block;
  final DesignerSampleData sample;

  @override
  Widget build(BuildContext context) {
    final props = block.properties;
    final items = propMapList(
      props,
      'items',
    ).where((it) => it['show'] != false).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    final labelAlign = parseTextAlign(props['labelAlign'] as String?);
    final valueAlign = parseTextAlign(
      props['valueAlign'] as String? ?? 'right',
    );
    final labelColor = parseCssColor(
      props['labelColor'] as String?,
      fallback: const Color(0xFF6B7280),
    );
    final amountColor = parseCssColor(props['amountColor'] as String?);
    final totalColor = parseCssColor(
      props['totalColor'] as String?,
      fallback: amountColor,
    );
    final balanceColor = parseCssColor(
      props['balanceColor'] as String?,
      fallback: amountColor,
    );
    final totalFontWeight = parseFontWeight(
      props['totalFontWeight'] as String? ?? 'bold',
    );
    final fontSize = parsePx(props['fontSize']) ?? inheritedFontSize(context);
    final labelPad = parsePx(props['labelPadding']) ?? 0;
    final valuePad = parsePx(props['valuePadding']) ?? 0;
    final spacing = parsePx(props['spacing']) ?? 0;
    // The server's own fallback for a totals block.
    final gap = parsePx(props['labelValueGap']) ?? 20;
    final showLabels = props['showLabels'] as bool? ?? true;
    // Phase 9a: block-level alignment positions the totals table
    // left/center/right within the surrounding grid cell. Mirrors
    // React TotalBlock.tsx margin-auto positioning.
    final blockAlign = parseAlignment(props['align'] as String? ?? 'right');

    return Align(
      alignment: blockAlign,
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i == items.length - 1 ? 0 : spacing,
                ),
                child: _TotalRow(
                  item: items[i],
                  sample: sample,
                  showLabels: showLabels,
                  labelAlign: labelAlign,
                  valueAlign: valueAlign,
                  labelColor: labelColor,
                  amountColor: amountColor,
                  totalColor: totalColor,
                  balanceColor: balanceColor,
                  totalFontWeight: totalFontWeight,
                  fontSize: fontSize,
                  labelPad: labelPad,
                  valuePad: valuePad,
                  gap: gap,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.item,
    required this.sample,
    required this.showLabels,
    required this.labelAlign,
    required this.valueAlign,
    required this.labelColor,
    required this.amountColor,
    required this.totalColor,
    required this.balanceColor,
    required this.totalFontWeight,
    required this.fontSize,
    required this.labelPad,
    required this.valuePad,
    required this.gap,
  });

  final Map<String, dynamic> item;
  final DesignerSampleData sample;
  final bool showLabels;
  final TextAlign labelAlign;
  final TextAlign valueAlign;
  final Color labelColor;
  final Color amountColor;
  final Color totalColor;
  final Color balanceColor;
  final FontWeight totalFontWeight;
  final double fontSize;
  final double labelPad;
  final double valuePad;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final rawLabel = (item['label'] as String?) ?? '';
    final rawField = (item['field'] as String?) ?? '';
    // Total item labels are seeded as `$subtotal_label`, `$total_label`,
    // etc. — translate through [kLabelTranslationMap] so the canvas
    // shows "Subtotal" / "Total" rather than the raw token.
    final label = replaceLabelVariables(
      replaceVariables(rawLabel, data: sample),
      context.tr,
      document: sample,
      customFieldLabels: DesignerRenderScope.customFieldLabelsOf(context),
    );
    final value = replaceVariables(
      rawField,
      data: sample,
      formatter: DesignerRenderScope.formatterOf(context),
    );
    final isTotal = item['isTotal'] as bool? ?? false;
    final isBalance = item['isBalance'] as bool? ?? false;

    final defaultValueColor = isBalance
        ? balanceColor
        : isTotal
        ? totalColor
        : amountColor;
    final defaultWeight = (isTotal || isBalance)
        ? totalFontWeight
        : FontWeight.normal;

    // Per-item cascade: subMap → flat item key → block-level fallback.
    // Mirrors React `BlockRenderer.tsx` total branch (lines 763–788).
    final labelCell = resolveCellTypography(
      subMap: cellStyleMap(item, 'labelStyle'),
      field: item,
      blockFontSize: fontSize,
      blockFontWeight: defaultWeight,
      blockFontStyle: FontStyle.normal,
      blockColor: labelColor,
    );
    final valueCell = resolveCellTypography(
      subMap: cellStyleMap(item, 'valueStyle'),
      field: item,
      blockFontSize: fontSize,
      blockFontWeight: defaultWeight,
      blockFontStyle: FontStyle.normal,
      blockColor: defaultValueColor,
    );

    return Row(
      children: [
        if (showLabels)
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: labelPad),
              child: Text(
                label,
                textAlign: labelAlign,
                style: labelCell.toTextStyle(),
              ),
            ),
          )
        else
          const Spacer(),
        SizedBox(width: gap),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: valuePad),
          child: Text(
            value,
            textAlign: valueAlign,
            style: valueCell.toTextStyle(),
          ),
        ),
      ],
    );
  }
}
