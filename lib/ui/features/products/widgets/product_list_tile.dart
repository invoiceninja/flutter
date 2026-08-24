import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/product.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/products/date_placeholders.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_actions_popup_button.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/core/list/selectable_list_row.dart';
import 'package:admin/ui/core/widgets/cell_copy_hover.dart';
import 'package:admin/ui/core/widgets/formatter_scope.dart';
import 'package:admin/ui/core/widgets/leading_select_slot.dart';
import 'package:admin/ui/features/products/widgets/inventory_scope.dart';
import 'package:admin/ui/features/products/widgets/product_actions.dart';

/// One row in the products list.
///
/// Wide-mode layout: leading `…` actions slot + (avatar/checkbox slot) +
/// column cells + reserved pill slot, all aligned with
/// [EntityListColumnHeaders] via the shared constants in
/// `entity_list_constants.dart`.
///
/// Narrow-mode layout: stacked card with selection checkbox + product key
/// (+ notes subtitle) + price + status pill + actions menu. No column cells
/// — the narrow tile picks the two highest-signal fields directly so it
/// renders cleanly on small screens.
class ProductListTile extends StatefulWidget {
  const ProductListTile({
    super.key,
    required this.product,
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

  final Product product;

  /// Columns to render in wide mode. Ignored when [wide] is false — narrow
  /// mode renders a fixed identity + price pair.
  final List<ColumnDefinition<Product>> columns;
  final VoidCallback onTap;

  /// True for the wide table-style row; false for the narrow stacked tile.
  final bool wide;

  /// False when the row is archived/soft-deleted; greys the wide-table
  /// standalone edit pencil. Sourced from `EntityListTileOptions.editable`.
  final bool editable;

  /// Trailing action menu callback. When null no menu renders (e.g. while
  /// in multiselect mode).
  final ValueChanged<ProductAction>? onAction;

  /// Tap handler for the leading select target. When non-null the row
  /// participates in multi-select; the leading slot reveals a checkbox on
  /// hover and renders as a checkbox while [selecting] is true.
  final VoidCallback? onSelectTap;

  /// Long-press anywhere on the row enters / toggles multi-select. Touch
  /// entry point for tablets; desktop users go through [onSelectTap].
  final VoidCallback? onLongPress;

  /// True when this row is part of the active multi-selection.
  final bool selected;

  /// True when this row matches the URL's `:id` (active in master-detail
  /// split view). Distinct from [selected] (multi-select) so the tile
  /// can render an unmistakable accent stripe on the left edge for
  /// URL-active rows without conflating with the bulk-select chip.
  final bool urlSelected;

  /// True when the screen is in selection mode (any rows selected). All
  /// rows render their leading slot as the selection checkbox during this
  /// state, regardless of [selected].
  final bool selecting;

  /// Suppresses the bottom hairline (last row, the selected row, or the row
  /// directly above the selected one). Computed by the list scaffold and
  /// passed straight to [SelectableListRow.hideBottomDivider].
  final bool hideBottomDivider;

  @override
  State<ProductListTile> createState() => _ProductListTileState();
}

class _ProductListTileState extends State<ProductListTile> {
  @override
  Widget build(BuildContext context) {
    final w = widget;
    final tokens = context.inTheme;
    return SelectableListRow(
      selected: w.selected,
      urlSelected: w.urlSelected,
      hideBottomDivider: w.hideBottomDivider,
      onTap: () => (w.selecting ? w.onSelectTap : w.onTap)?.call(),
      onLongPress: w.onLongPress,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 10),
        child: w.wide ? _wide(context, tokens) : _narrow(context, tokens),
      ),
    );
  }

  Widget _wide(BuildContext context, InTheme tokens) {
    final w = widget;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Leading `…` actions slot. Hidden in selection mode.
        SizedBox(
          width: kColWMoreMenu,
          child: (w.onAction == null || w.selecting)
              ? const SizedBox.shrink()
              : EntityActionsPopupButton<ProductAction>(
                  splitEditAction: true,
                  editEnabled: w.editable,
                  icon: Icons.more_horiz,
                  items: ProductActions.itemsFor(
                    context,
                    w.product,
                    w.onAction!,
                  ),
                ),
        ),
        const SizedBox(width: kColActionsLeadingGap),
        _leading(),
        const SizedBox(width: kColCellGap),
        for (final col in w.columns) ...[
          _CellSlot(
            column: col,
            product: w.product,
            child: col.cellBuilder(w.product, context),
          ),
          const SizedBox(width: kColCellGap),
        ],
        // Reserved pill slot so the row's right edge matches the header's.
        // Empty for now — future product status badge slots in here.
        const SizedBox(width: kColWPillSlot),
      ],
    );
  }

  Widget _narrow(BuildContext context, InTheme tokens) {
    final w = widget;
    // Format the price through the active-company Formatter (currency cascade
    // + symbol), matching the wide table's money cells. Falls back to a
    // locale number only during the brief cold-start window before the
    // FormatterScope resolves.
    final formatter = FormatterScope.maybeOf(context);
    final priceText =
        formatter?.money(w.product.price) ??
        (NumberFormat.decimalPattern()
              ..minimumFractionDigits = 2
              ..maximumFractionDigits = 2)
            .format(w.product.price.toDouble());
    // Narrow tiles render no column cells, so surface low/out stock inline:
    // qty + status icon in the matching colour (icon so it isn't colour-only).
    final stockStatus =
        InventoryScope.maybeOf(context)?.statusFor(w.product) ?? StockStatus.ok;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _leading(),
        const SizedBox(width: 12),
        Expanded(child: _identity(context, tokens)),
        const SizedBox(width: 12),
        if (stockStatus != StockStatus.ok) ...[
          Icon(
            stockStatus == StockStatus.out
                ? Icons.error_outline
                : Icons.warning_amber_rounded,
            size: 16,
            color: stockStatus == StockStatus.out
                ? tokens.overdue
                : tokens.warning,
          ),
          const SizedBox(width: 4),
          Text(
            w.product.inStockQuantity.toString(),
            style: moneyTextStyle(
              fontSize: 13,
              color: stockStatus == StockStatus.out
                  ? tokens.overdue
                  : tokens.warning,
            ),
          ),
          const SizedBox(width: 10),
        ],
        Text(priceText, style: moneyTextStyle(color: tokens.ink)),
        if (w.onAction != null && !w.selecting) ...[
          const SizedBox(width: 4),
          EntityActionsPopupButton<ProductAction>(
            icon: Icons.more_horiz,
            items: ProductActions.itemsFor(context, w.product, w.onAction!),
          ),
        ],
      ],
    );
  }

  Widget _identity(BuildContext context, InTheme tokens) {
    final p = widget.product;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          p.productKey.isEmpty ? '—' : p.productKey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (p.notes.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            // Same reasoning as the Description column — a reserved date
            // keyword reads as the date it becomes (invoiceninja/flutter#93).
            expandDatePlaceholders(
              p.notes,
              rangeSeparator: context.tr('to'),
              locale: FormatterScope.maybeOf(context)?.settings.locale,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: tokens.ink3, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _leading() {
    final w = widget;
    return LeadingSelectSlot(
      selecting: w.selecting,
      selected: w.selected,
      onSelectTap: w.onSelectTap,
      defaultChild: const SizedBox.shrink(),
    );
  }
}

class _CellSlot extends StatelessWidget {
  const _CellSlot({
    required this.column,
    required this.product,
    required this.child,
  });
  final ColumnDefinition<Product> column;
  final Product product;
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
      value: column.valueBuilder?.call(product),
      align: column.align,
      child: aligned,
    );
    if (column.isFlex) return Expanded(child: cell);
    return SizedBox(width: column.width, child: cell);
  }
}
