import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/design.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_renderers/_shared.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/sample/sample_data.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/table_header_label.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/variables/variable_replacer.dart';

/// Renders `table` (products) and `tasks-table`. Both use the same shape
/// — a header row + body rows from `sample.lineItems`. Each column's
/// `field` references an `item.*` path resolved through
/// [resolveItemVariable]. Visuals mirror React: `headerBg` / `headerColor`
/// / `headerBorders` for the header; `rowBg` / `alternateRowBg` /
/// `rowBorders` for the body. Money columns format via the sample data's
/// `Decimal` values (en-US fallback through [resolveItemVariable]).
class TableBlock extends StatelessWidget {
  const TableBlock({super.key, required this.block, required this.sample});

  final DesignBlock block;
  final DesignerSampleData sample;

  @override
  Widget build(BuildContext context) {
    final props = block.properties;
    final columns = propMapList(props, 'columns');
    if (columns.isEmpty) return const SizedBox.shrink();

    final headerBg = parseCssColor(
      props['headerBg'] as String?,
      fallback: const Color(0xFFF3F4F6),
    );
    final headerColor = parseCssColor(props['headerColor'] as String?);
    final headerFontWeight = parseFontWeight(
      props['headerFontWeight'] as String? ?? 'bold',
    );
    final rowBg = parseCssColor(
      props['rowBg'] as String?,
      fallback: const Color(0xFFFFFFFF),
    );
    final altRowBg = parseCssColor(
      props['alternateRowBg'] as String?,
      fallback: rowBg,
    );
    final rowColor = parseCssColor(props['rowColor'] as String?);
    final alternateRows = props['alternateRows'] as bool? ?? true;
    final padding = parsePx(props['padding']) ?? 8;
    final fontSize = parsePx(props['fontSize']) ?? 12;
    final headerBorder = parseTableRegionBorders(
      propMap(props, 'headerBorders'),
    );
    final rowBorder = parseTableRegionBorders(propMap(props, 'rowBorders'));

    final widths = <int, TableColumnWidth>{
      for (var i = 0; i < columns.length; i++)
        i: _columnWidth(columns[i]['width']),
    };

    return Table(
      columnWidths: widths,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder(
        // Apply the outer-edge sides of the row border globally; per-cell
        // top/bottom come from the cell decoration below.
        horizontalInside: rowBorder?.top.color != null
            ? BorderSide(
                color: rowBorder!.top.color,
                width: rowBorder.top.width,
              )
            : BorderSide.none,
      ),
      children: [
        TableRow(
          decoration: BoxDecoration(color: headerBg, border: headerBorder),
          children: [
            for (final col in columns)
              _cell(
                text: resolveTableHeaderLabel(
                  context,
                  col['header'] as String?,
                ),
                align: parseTextAlign(col['align'] as String?),
                // Header cell uses the column's `labelStyle` cascade —
                // the header IS the label for a table column.
                style: resolveCellTypography(
                  subMap: cellStyleMap(col, 'labelStyle'),
                  field: col,
                  blockFontSize: fontSize,
                  blockFontWeight: headerFontWeight,
                  blockFontStyle: FontStyle.normal,
                  blockColor: headerColor,
                ).toTextStyle(),
                padding: padding,
              ),
          ],
        ),
        for (var i = 0; i < sample.lineItems.length; i++)
          TableRow(
            decoration: BoxDecoration(
              color: (alternateRows && i.isOdd) ? altRowBg : rowBg,
              border: rowBorder,
            ),
            children: [
              for (final col in columns)
                _cell(
                  text: resolveItemVariable(
                    (col['field'] as String?) ?? '',
                    sample.lineItems[i],
                    data: sample,
                  ),
                  align: parseTextAlign(col['align'] as String?),
                  // Body cell uses the column's `valueStyle` cascade.
                  style: resolveCellTypography(
                    subMap: cellStyleMap(col, 'valueStyle'),
                    field: col,
                    blockFontSize: fontSize,
                    blockFontWeight: FontWeight.normal,
                    blockFontStyle: FontStyle.normal,
                    blockColor: rowColor,
                  ).toTextStyle(),
                  padding: padding,
                ),
            ],
          ),
      ],
    );
  }

  TableColumnWidth _columnWidth(Object? raw) {
    if (raw is String && raw.endsWith('%')) {
      final pct = double.tryParse(raw.substring(0, raw.length - 1));
      if (pct != null) return FractionColumnWidth(pct / 100);
    }
    return const FlexColumnWidth();
  }

  Widget _cell({
    required String text,
    required TextAlign align,
    required TextStyle style,
    required double padding,
  }) {
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Text(text, textAlign: align, style: style),
    );
  }
}
