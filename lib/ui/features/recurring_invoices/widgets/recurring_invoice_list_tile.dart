import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/recurring_invoice.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/ui/core/list/embedded_list_scope.dart';
import 'package:admin/ui/core/list/entity_actions_popup_button.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/core/list/selectable_list_row.dart';
import 'package:admin/ui/core/widgets/cell_copy_hover.dart';
import 'package:admin/ui/core/widgets/leading_select_slot.dart';
import 'package:admin/ui/core/widgets/client_name_label.dart';
import 'package:admin/ui/core/widgets/formatter_scope.dart';
import 'package:admin/ui/core/widgets/party_money_cell.dart';
import 'package:admin/ui/features/recurring_invoices/widgets/recurring_invoice_actions.dart';
import 'package:admin/ui/features/recurring_invoices/widgets/recurring_invoice_status_pill.dart';

/// Cached locale-only fallback for the narrow-tile amount when no
/// `FormatterScope` is in the tree (never allocate `NumberFormat` per build).
final NumberFormat _recurringInvoiceAmountFallback =
    NumberFormat.decimalPattern()
      ..minimumFractionDigits = 2
      ..maximumFractionDigits = 2;

class RecurringInvoiceListTile extends StatefulWidget {
  const RecurringInvoiceListTile({
    super.key,
    required this.recurringInvoice,
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

  final RecurringInvoice recurringInvoice;
  final List<ColumnDefinition<RecurringInvoice>> columns;
  final VoidCallback onTap;
  final bool wide;

  /// False when the row is archived/soft-deleted; greys the wide-table
  /// standalone edit pencil. Sourced from `EntityListTileOptions.editable`.
  final bool editable;
  final ValueChanged<RecurringInvoiceAction>? onAction;
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
  State<RecurringInvoiceListTile> createState() =>
      _RecurringInvoiceListTileState();
}

class _RecurringInvoiceListTileState extends State<RecurringInvoiceListTile> {
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
              : EntityActionsPopupButton<RecurringInvoiceAction>(
                  splitEditAction: true,
                  editEnabled: w.editable,
                  items: RecurringInvoiceActions.itemsFor(
                    context,
                    w.recurringInvoice,
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
            recurringInvoice: w.recurringInvoice,
            child: col.cellBuilder(w.recurringInvoice, context),
          ),
          const SizedBox(width: kColCellGap),
        ],
        const SizedBox(width: kColWPillSlot),
      ],
    );
  }

  Widget _narrow(BuildContext context, InTheme tokens) {
    final w = widget;
    final amount = w.recurringInvoice.amount;
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
              clientId: w.recurringInvoice.clientId,
              builder: (context, currencyId) {
                final formatter = FormatterScope.maybeOf(context);
                final formatted = formatter?.money(
                  amount,
                  clientCurrencyId: currencyId,
                );
                final amountText = (formatted != null && formatted.isNotEmpty)
                    ? formatted
                    : _recurringInvoiceAmountFallback.format(amount.toDouble());
                return Text(
                  amountText,
                  style: moneyTextStyle(color: tokens.ink),
                );
              },
            ),
            const SizedBox(height: 4),
            RecurringInvoiceStatusPill(
              statusId: w.recurringInvoice.calculatedStatusId,
              hasBounce: w.recurringInvoice.hasBouncedInvitation,
            ),
          ],
        ),
        if (w.onAction != null && !w.selecting) ...[
          const SizedBox(width: 4),
          EntityActionsPopupButton<RecurringInvoiceAction>(
            items: RecurringInvoiceActions.itemsFor(
              context,
              w.recurringInvoice,
              w.onAction!,
            ),
          ),
        ],
      ],
    );
  }

  Widget _identity(BuildContext context, InTheme tokens) {
    final r = widget.recurringInvoice;
    final ident = r.number.isEmpty ? '—' : '#${r.number}';
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
        if (r.clientId.isNotEmpty) ...[
          const SizedBox(height: 2),
          ClientNameLabel(
            clientId: r.clientId,
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
    required this.recurringInvoice,
    required this.child,
  });
  final ColumnDefinition<RecurringInvoice> column;
  final RecurringInvoice recurringInvoice;
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
      value: column.valueBuilder?.call(recurringInvoice),
      align: column.align,
      child: aligned,
    );
    if (column.isFlex) return Expanded(child: cell);
    return SizedBox(width: column.width, child: cell);
  }
}
