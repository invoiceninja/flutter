import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/db/dao/expense_category_dao.dart';
import 'package:admin/data/models/domain/expense_category.dart';
import 'package:admin/domain/columns/column_cells.dart';
import 'package:admin/domain/columns/column_factories.dart';
import 'package:admin/domain/columns/column_definition.dart';

typedef ExpenseCategoryColumn = ColumnDefinition<ExpenseCategory>;

const List<String> kDefaultExpenseCategoryColumns = <String>[
  ExpenseCategoryFieldIds.name,
  _ExpenseCategoryExtraColumns.color,
];

class _ExpenseCategoryExtraColumns {
  static const String color = 'color';
}

final List<ExpenseCategoryColumn> kAllExpenseCategoryColumns =
    <ExpenseCategoryColumn>[
      ExpenseCategoryColumn(
        id: ExpenseCategoryFieldIds.name,
        labelKey: 'name',
        cellBuilder: (c, _) => cellText(c.name, bold: true),
        valueBuilder: (c) => cellNonZeroString(c.name),
      ),
      ExpenseCategoryColumn(
        id: _ExpenseCategoryExtraColumns.color,
        labelKey: 'color',
        width: 80,
        cellBuilder: (c, ctx) => _ColorSwatchCell(color: c.color),
        valueBuilder: (c) => cellNonZeroString(c.color),
      ),
      colUpdatedAt<ExpenseCategory>(
        ExpenseCategoryFieldIds.updatedAt,
        (c) => c.updatedAt,
        width: 110,
      ),
    ];

final Map<String, ExpenseCategoryColumn> expenseCategoryColumnsById = {
  for (final c in kAllExpenseCategoryColumns) c.id: c,
};

/// Small color swatch + hex code used both in the list table column and in
/// the detail card. Falls back to `tokens.ink3` for unparseable hex so the
/// list never renders an empty cell.
class _ColorSwatchCell extends StatelessWidget {
  const _ColorSwatchCell({required this.color});

  final String color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final parsed = _parseHex(color) ?? tokens.ink3;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: parsed, shape: BoxShape.circle),
        ),
      ],
    );
  }

  Color? _parseHex(String raw) {
    final cleaned = raw.trim().replaceFirst('#', '');
    if (cleaned.length != 6) return null;
    final v = int.tryParse(cleaned, radix: 16);
    if (v == null) return null;
    return Color(0xFF000000 | v);
  }
}
