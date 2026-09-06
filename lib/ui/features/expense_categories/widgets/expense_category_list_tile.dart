import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/expense_category.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/ui/core/list/entity_actions_popup_button.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/core/list/selectable_list_row.dart';
import 'package:admin/ui/core/widgets/cell_copy_hover.dart';
import 'package:admin/ui/core/widgets/leading_select_slot.dart';
import 'package:admin/ui/features/expense_categories/widgets/expense_category_actions.dart';

/// One row in the expense-categories list.
///
/// Wide-mode layout: leading `…` actions slot + selection slot + column
/// cells + reserved pill slot — same anatomy as `ProductListTile`. Narrow
/// mode stacks a color swatch + name on one line.
class ExpenseCategoryListTile extends StatelessWidget {
  const ExpenseCategoryListTile({
    super.key,
    required this.category,
    required this.columns,
    required this.onTap,
    this.wide = true,
    this.editable = true,
    this.onAction,
    this.onSelectTap,
    this.onLongPress,
    this.selected = false,
    this.urlSelected = false,
    this.selecting = false,
    this.hideBottomDivider = false,
  });

  final ExpenseCategory category;

  /// Columns to render in wide mode. Ignored when [wide] is false.
  final List<ColumnDefinition<ExpenseCategory>> columns;
  final VoidCallback onTap;
  final bool wide;

  /// False when the row is archived/soft-deleted; greys the wide-table
  /// standalone edit pencil. Sourced from `EntityListTileOptions.editable`.
  final bool editable;
  final ValueChanged<ExpenseCategoryAction>? onAction;
  final VoidCallback? onSelectTap;
  final VoidCallback? onLongPress;
  final bool selected;

  /// True when this row matches the URL's `:id` (active in master-detail
  /// split view). Distinct from [selected] (multi-select) so the tile
  /// can render an unmistakable accent stripe on the left edge for
  /// URL-active rows without conflating with the bulk-select chip.
  final bool urlSelected;
  final bool selecting;

  /// Suppresses the bottom hairline (last row, the selected row, or the row
  /// directly above the selected one). Computed by the list scaffold and
  /// passed straight to [SelectableListRow.hideBottomDivider].
  final bool hideBottomDivider;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return SelectableListRow(
      selected: selected,
      urlSelected: urlSelected,
      hideBottomDivider: hideBottomDivider,
      onTap: () => (selecting ? onSelectTap : onTap)?.call(),
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 10),
        child: wide ? _wide(context, tokens) : _narrow(context, tokens),
      ),
    );
  }

  Widget _wide(BuildContext context, InTheme tokens) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Leading `…` actions slot. Hidden in selection mode.
        SizedBox(
          width: colWMoreMenu(),
          child: (onAction == null || selecting)
              ? const SizedBox.shrink()
              : EntityActionsPopupButton<ExpenseCategoryAction>(
                  splitEditAction: true,
                  editEnabled: editable,
                  items: ExpenseCategoryActions.itemsFor(
                    context,
                    category,
                    onAction!,
                  ),
                ),
        ),
        const SizedBox(width: kColActionsLeadingGap),
        _leading(),
        const SizedBox(width: kColCellGap),
        for (final col in columns) ...[
          _CellSlot(
            column: col,
            category: category,
            child: col.cellBuilder(category, context),
          ),
          const SizedBox(width: kColCellGap),
        ],
        // Reserved pill slot so the row's right edge matches the header's.
        const SizedBox(width: kColWPillSlot),
      ],
    );
  }

  Widget _narrow(BuildContext context, InTheme tokens) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _leading(),
        const SizedBox(width: 12),
        _ColorSwatch(color: category.color, tokens: tokens),
        const SizedBox(width: 10),
        Expanded(child: _identity(context, tokens)),
        if (onAction != null && !selecting) ...[
          const SizedBox(width: 4),
          EntityActionsPopupButton<ExpenseCategoryAction>(
            items: ExpenseCategoryActions.itemsFor(
              context,
              category,
              onAction!,
            ),
          ),
        ],
      ],
    );
  }

  Widget _identity(BuildContext context, InTheme tokens) {
    return Text(
      category.name.isEmpty ? '—' : category.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w600),
    );
  }

  Widget _leading() {
    return LeadingSelectSlot(
      selecting: selecting,
      selected: selected,
      onSelectTap: onSelectTap,
      defaultChild: const SizedBox.shrink(),
    );
  }
}

class _CellSlot extends StatelessWidget {
  const _CellSlot({
    required this.column,
    required this.category,
    required this.child,
  });
  final ColumnDefinition<ExpenseCategory> column;
  final ExpenseCategory category;
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
      value: column.valueBuilder?.call(category),
      align: column.align,
      child: aligned,
    );
    if (column.isFlex) return Expanded(child: cell);
    return SizedBox(width: column.width, child: cell);
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.color, required this.tokens});

  final String color;
  final InTheme tokens;

  @override
  Widget build(BuildContext context) {
    final raw = color.trim().replaceFirst('#', '');
    Color resolved = tokens.ink3;
    if (raw.length == 6) {
      final v = int.tryParse(raw, radix: 16);
      if (v != null) resolved = Color(0xFF000000 | v);
    }
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(color: resolved, shape: BoxShape.circle),
    );
  }
}
