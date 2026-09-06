import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/purchase_order.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/ui/core/list/embedded_list_scope.dart';
import 'package:admin/ui/core/list/entity_actions_popup_button.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/core/list/selectable_list_row.dart';
import 'package:admin/ui/core/widgets/cell_copy_hover.dart';
import 'package:admin/ui/core/widgets/formatter_scope.dart';
import 'package:admin/ui/core/widgets/leading_select_slot.dart';
import 'package:admin/ui/core/widgets/party_money_cell.dart';
import 'package:admin/ui/core/widgets/vendor_name_label.dart';
import 'package:admin/ui/features/purchase_orders/widgets/purchase_order_actions.dart';
import 'package:admin/ui/features/purchase_orders/widgets/purchase_order_status_pill.dart';

/// Locale-only fallback when no [FormatterScope] is in the tree (mirrors the
/// invoice/quote tiles — never allocate `NumberFormat` per build).
final NumberFormat _poAmountFallback = NumberFormat.decimalPattern()
  ..minimumFractionDigits = 2
  ..maximumFractionDigits = 2;

class PurchaseOrderListTile extends StatefulWidget {
  const PurchaseOrderListTile({
    super.key,
    required this.purchaseOrder,
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

  final PurchaseOrder purchaseOrder;
  final List<ColumnDefinition<PurchaseOrder>> columns;
  final VoidCallback onTap;
  final bool wide;

  /// False when the row is archived/soft-deleted; greys the wide-table
  /// standalone edit pencil. Sourced from `EntityListTileOptions.editable`.
  final bool editable;
  final ValueChanged<PurchaseOrderAction>? onAction;
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
  State<PurchaseOrderListTile> createState() => _PurchaseOrderListTileState();
}

class _PurchaseOrderListTileState extends State<PurchaseOrderListTile> {
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
        padding: EmbeddedListScope.of(context)
            ? const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14)
            : const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 10),
        child: w.wide ? _wide(context, tokens) : _narrow(context, tokens),
      ),
    );
  }

  Widget _wide(BuildContext context, InTheme tokens) {
    final w = widget;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: colWMoreMenu(),
          child: (w.onAction == null || w.selecting)
              ? const SizedBox.shrink()
              : EntityActionsPopupButton<PurchaseOrderAction>(
                  splitEditAction: true,
                  editEnabled: w.editable,
                  items: PurchaseOrderActions.itemsFor(
                    context,
                    w.purchaseOrder,
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
            purchaseOrder: w.purchaseOrder,
            child: col.cellBuilder(w.purchaseOrder, context),
          ),
          const SizedBox(width: kColCellGap),
        ],
        const SizedBox(width: kColWPillSlot),
      ],
    );
  }

  Widget _narrow(BuildContext context, InTheme tokens) {
    final w = widget;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _leading(),
        const SizedBox(width: 12),
        Expanded(child: _identity(context, tokens)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            PartyCurrencyBuilder(
              vendorId: w.purchaseOrder.vendorId,
              builder: (context, currencyId) {
                final formatter = FormatterScope.maybeOf(context);
                final amount = w.purchaseOrder.amount;
                final formatted = formatter?.money(
                  amount,
                  vendorCurrencyId: currencyId,
                );
                final amountText = (formatted != null && formatted.isNotEmpty)
                    ? formatted
                    : _poAmountFallback.format(amount.toDouble());
                return Text(
                  amountText,
                  style: moneyTextStyle(color: tokens.ink),
                );
              },
            ),
            const SizedBox(height: 4),
            PurchaseOrderStatusPill(
              statusId: w.purchaseOrder.calculatedStatusId,
              hasBounce: w.purchaseOrder.hasBouncedInvitation,
            ),
          ],
        ),
        if (w.onAction != null && !w.selecting) ...[
          const SizedBox(width: 4),
          EntityActionsPopupButton<PurchaseOrderAction>(
            items: PurchaseOrderActions.itemsFor(
              context,
              w.purchaseOrder,
              w.onAction!,
            ),
          ),
        ],
      ],
    );
  }

  Widget _identity(BuildContext context, InTheme tokens) {
    final p = widget.purchaseOrder;
    final ident = p.number.isEmpty ? '—' : '#${p.number}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          ident,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (p.vendorId.isNotEmpty) ...[
          const SizedBox(height: 2),
          VendorNameLabel(
            vendorId: p.vendorId,
            style: TextStyle(color: tokens.ink3, fontSize: 12),
            link: true,
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
    required this.purchaseOrder,
    required this.child,
  });
  final ColumnDefinition<PurchaseOrder> column;
  final PurchaseOrder purchaseOrder;
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
      value: column.valueBuilder?.call(purchaseOrder),
      align: column.align,
      child: aligned,
    );
    if (column.isFlex) return Expanded(child: cell);
    return SizedBox(width: column.width, child: cell);
  }
}
