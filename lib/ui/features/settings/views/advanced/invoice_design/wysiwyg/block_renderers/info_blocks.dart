import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/design.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_renderers/_shared.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/sample/sample_data.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/table_header_label.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/variables/variable_replacer.dart';

/// Renders `client-info`, `company-info`, `client-shipping-info`. Iterates
/// the `fieldConfigs` list, substituting each `variable` against the
/// sample data, and emits one row per field (label + prefix + value +
/// suffix). Honors `hideIfEmpty` so empty fields don't waste space.
///
/// An optional title row leads the block when `showTitle` is `true`.
class InfoBlock extends StatelessWidget {
  const InfoBlock({super.key, required this.block, required this.sample});

  final DesignBlock block;
  final DesignerSampleData sample;

  @override
  Widget build(BuildContext context) {
    final props = block.properties;
    final fields = propMapList(props, 'fieldConfigs');
    final color = parseCssColor(props['color'] as String?);
    final fontSize = parsePx(props['fontSize']) ?? inheritedFontSize(context);
    final align = parseTextAlign(props['align'] as String?);
    final lineHeight =
        parsePx(props['lineHeight']) ??
        double.tryParse((props['lineHeight'] as String?) ?? '') ??
        1.3;
    // The company block has no title on the server; only the client and
    // ship-to blocks print one.
    final showTitle =
        block.type != 'company-info' && (props['showTitle'] as bool? ?? false);

    final children = <Widget>[
      if (showTitle) _titleRow(context, props, align),
      for (final field in fields)
        _FieldRow(
          field: field,
          sample: sample,
          color: color,
          fontSize: fontSize,
          textAlign: align,
          lineHeight: lineHeight,
        ),
    ];

    return Column(
      crossAxisAlignment: _crossFor(align),
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _titleRow(
    BuildContext context,
    Map<String, dynamic> props,
    TextAlign align,
  ) {
    final prefix = (props['titlePrefix'] as String?) ?? '';
    final suffix = (props['titleSuffix'] as String?) ?? '';
    final resolved = resolveBlockTitle(context, props['title'] as String?);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$prefix$resolved$suffix',
        textAlign: align,
        style: TextStyle(
          fontSize:
              parsePx(props['titleFontSize']) ?? inheritedFontSize(context),
          fontWeight: parseFontWeight(props['titleFontWeight'] as String?),
          fontStyle: parseFontStyle(props['titleFontStyle'] as String?),
          color: parseCssColor(
            props['titleColor'] as String?,
            fallback: parseCssColor(props['color'] as String?),
          ),
        ),
      ),
    );
  }

  CrossAxisAlignment _crossFor(TextAlign a) => switch (a) {
    TextAlign.center => CrossAxisAlignment.center,
    TextAlign.right => CrossAxisAlignment.end,
    _ => CrossAxisAlignment.start,
  };
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.field,
    required this.sample,
    required this.color,
    required this.fontSize,
    required this.textAlign,
    required this.lineHeight,
  });

  final Map<String, dynamic> field;
  final DesignerSampleData sample;
  final Color color;
  final double fontSize;
  final TextAlign textAlign;
  final double lineHeight;

  @override
  Widget build(BuildContext context) {
    final variable = (field['variable'] as String?) ?? '';
    final value = replaceVariables(
      variable,
      data: sample,
      formatter: DesignerRenderScope.formatterOf(context),
    );
    // Absent is on, as on the server.
    final hideIfEmpty = field['hideIfEmpty'] as bool? ?? true;
    if (hideIfEmpty && resolvesEmpty(value)) return const SizedBox.shrink();
    // Trimmed, because that is how they are stored: the server trims every
    // string of a saved design, so a prefix typed as "Tel: " prints "Tel:".
    final prefix = ((field['prefix'] as String?) ?? '').trim();
    final suffix = ((field['suffix'] as String?) ?? '').trim();
    // Info-block rows are a single line — `valueStyle` is the natural
    // override since the label is concatenated as prefix text. We fall
    // back to `labelStyle` when only the label side has overrides so
    // editing either cell visibly affects the row.
    final cell = resolveCellTypography(
      subMap:
          cellStyleMap(field, 'valueStyle') ??
          cellStyleMap(field, 'labelStyle'),
      field: field,
      blockFontSize: fontSize,
      blockFontWeight: FontWeight.normal,
      blockFontStyle: FontStyle.normal,
      blockColor: color,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Text(
        '$prefix$value$suffix',
        textAlign: textAlign,
        style: cell.toTextStyle(height: lineHeight),
      ),
    );
  }
}

/// `invoice-details` renderer. Same `fieldConfigs` shape as the info
/// blocks but rendered as a label + value two-column `Table` so labels
/// align across rows. Honors `labelAlign` / `valueAlign` / `labelColor` /
/// `labelPadding` / `valuePadding` / `rowSpacing` / `labelValueGap`.
class InvoiceDetailsBlock extends StatelessWidget {
  const InvoiceDetailsBlock({
    super.key,
    required this.block,
    required this.sample,
  });

  final DesignBlock block;
  final DesignerSampleData sample;

  @override
  Widget build(BuildContext context) {
    final props = block.properties;
    final fields = propMapList(props, 'fieldConfigs');
    if (fields.isEmpty) return const SizedBox.shrink();

    final valueColor = parseCssColor(props['color'] as String?);
    final labelColor = parseCssColor(
      props['labelColor'] as String?,
      fallback: valueColor,
    );
    final fontSize = parsePx(props['fontSize']) ?? inheritedFontSize(context);
    final labelAlign = parseTextAlign(props['labelAlign'] as String?);
    final valueAlign = parseTextAlign(props['valueAlign'] as String?);
    final labelPad = parsePx(props['labelPadding']) ?? 0;
    final valuePad = parsePx(props['valuePadding']) ?? 0;
    final gap = parsePx(props['labelValueGap']) ?? 12;
    final rowSpacing = parsePx(props['rowSpacing']) ?? 0;
    final showLabels = props['showLabels'] as bool? ?? true;
    final lineHeight =
        parsePx(props['lineHeight']) ??
        double.tryParse((props['lineHeight'] as String?) ?? '') ??
        1.3;

    final formatter = DesignerRenderScope.formatterOf(context);
    final rows = <TableRow>[];
    for (var i = 0; i < fields.length; i++) {
      final f = fields[i];
      final variable = (f['variable'] as String?) ?? '';
      final value = replaceVariables(
        variable,
        data: sample,
        formatter: formatter,
      );
      final hideIfEmpty = f['hideIfEmpty'] as bool? ?? true;
      if (hideIfEmpty && resolvesEmpty(value)) continue;

      final rawLabel = (f['label'] as String?) ?? '';
      // Labels are typically `$..._label` tokens — translate through
      // [kLabelTranslationMap]; fall back to the variable substitution
      // path for any non-label text (e.g. literal "Phone:").
      final label = rawLabel.isEmpty
          ? ''
          : replaceLabelVariables(
              replaceVariables(rawLabel, data: sample),
              context.tr,
              document: sample,
              customFieldLabels: DesignerRenderScope.customFieldLabelsOf(
                context,
              ),
            );

      final pad = EdgeInsets.only(
        bottom: i == fields.length - 1 ? 0 : rowSpacing,
      );
      // Per-row cascade — labelStyle on label cell, valueStyle on value
      // cell, with block-level fontSize / color as fallback. Mirrors
      // React's `BlockRenderer.tsx` invoice-details branch.
      final labelCell = resolveCellTypography(
        subMap: cellStyleMap(f, 'labelStyle'),
        field: f,
        blockFontSize: fontSize,
        blockFontWeight: FontWeight.normal,
        blockFontStyle: FontStyle.normal,
        blockColor: labelColor,
      );
      final valueCell = resolveCellTypography(
        subMap: cellStyleMap(f, 'valueStyle'),
        field: f,
        blockFontSize: fontSize,
        blockFontWeight: FontWeight.normal,
        blockFontStyle: FontStyle.normal,
        blockColor: valueColor,
      );
      rows.add(
        TableRow(
          children: [
            if (showLabels)
              Padding(
                // The gap is the label cell's right padding, as on the
                // server (`padding-right: labelValueGap`). It used to be a
                // third column pinned to zero width, so the longest value
                // printed hard against its label.
                padding: pad + EdgeInsets.only(left: labelPad, right: gap),
                child: Text(
                  label,
                  textAlign: labelAlign,
                  style: labelCell.toTextStyle(height: lineHeight),
                ),
              )
            else
              const SizedBox.shrink(),
            Padding(
              padding: pad + EdgeInsets.symmetric(horizontal: valuePad),
              child: Text(
                value,
                textAlign: valueAlign,
                style: valueCell.toTextStyle(height: lineHeight),
              ),
            ),
          ],
        ),
      );
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    // The server's table is `width: fit-content`, placed by the block's
    // `align`. A `Table` under a tight width would stretch to it instead and
    // sit at the left whatever the alignment said.
    return Align(
      alignment: parseAlignment(props['align'] as String?),
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: rows,
      ),
    );
  }
}
