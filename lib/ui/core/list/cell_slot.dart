import 'package:flutter/material.dart';

import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/ui/core/widgets/cell_copy_hover.dart';

/// One cell of a wide-table row: aligns the cell, wraps it in the hover-copy
/// affordance, and gives it the column's width — `Expanded` for a flex column,
/// a fixed `SizedBox` otherwise.
///
/// The row-side twin of `_HeaderCell` in `entity_list_column_headers.dart`,
/// which has always been generic and resolves the same width branch. Every
/// entity tile carried a private copy of this class; fifteen of the seventeen
/// were byte-identical and the other two differed only in brace style.
///
/// [entity] is used solely to resolve `column.valueBuilder` for the copy value,
/// so nothing here is entity-specific.
class CellSlot<T> extends StatelessWidget {
  const CellSlot({
    required this.column,
    required this.entity,
    required this.child,
    super.key,
  });

  final ColumnDefinition<T> column;
  final T entity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final aligned = Align(
      alignment: column.align == ColumnAlign.end
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: child,
    );
    final cell = CellCopyHover(
      value: column.valueBuilder?.call(entity),
      align: column.align,
      child: aligned,
    );
    if (column.isFlex) return Expanded(child: cell);
    return SizedBox(width: column.width, child: cell);
  }
}
