import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/bank_transaction.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/ui/core/list/embedded_list_scope.dart';
import 'package:admin/ui/core/list/entity_actions_popup_button.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/core/list/selectable_list_row.dart';
import 'package:admin/ui/core/widgets/cell_copy_hover.dart';
import 'package:admin/ui/core/widgets/formatter_scope.dart';
import 'package:admin/ui/core/widgets/leading_select_slot.dart';
import 'package:admin/ui/features/transactions/widgets/transaction_actions.dart';
import 'package:admin/ui/features/transactions/widgets/transaction_status_pill.dart';

/// Shared 2-digit amount formatter for narrow-mode rows. `NumberFormat`
/// is expensive to construct but stateless to format, so one cached
/// instance replaces the per-tile allocation.
final NumberFormat _txAmountFormat = NumberFormat.decimalPattern()
  ..minimumFractionDigits = 2
  ..maximumFractionDigits = 2;

/// One row in the transactions list. Wide-mode renders the column grid;
/// narrow-mode collapses to identity (participant + description) + amount
/// + status pill on the trailing side, with deposit/withdrawal sign
/// implicit via the `+` / `-` prefix.
class TransactionListTile extends StatefulWidget {
  const TransactionListTile({
    super.key,
    required this.transaction,
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

  final BankTransaction transaction;
  final List<ColumnDefinition<BankTransaction>> columns;
  final VoidCallback onTap;
  final bool wide;

  /// False when the row is archived/soft-deleted; greys the wide-table
  /// standalone edit pencil. Sourced from `EntityListTileOptions.editable`.
  final bool editable;
  final ValueChanged<TransactionAction>? onAction;
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
  State<TransactionListTile> createState() => _TransactionListTileState();
}

class _TransactionListTileState extends State<TransactionListTile> {
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
              : EntityActionsPopupButton<TransactionAction>(
                  splitEditAction: true,
                  editEnabled: w.editable,
                  items: TransactionActions.itemsFor(
                    context,
                    w.transaction,
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
            transaction: w.transaction,
            child: col.cellBuilder(w.transaction, context),
          ),
          const SizedBox(width: kColCellGap),
        ],
        const SizedBox(width: kColWPillSlot),
      ],
    );
  }

  Widget _narrow(BuildContext context, InTheme tokens) {
    final w = widget;
    final tx = w.transaction;
    // Prefix `+` for deposits, `-` for withdrawals so users read the sign
    // even before the column header is rendered.
    final sign = tx.isWithdrawal ? '-' : '+';
    final amountText = '$sign${_txAmountFormat.format(tx.amount.toDouble())}';
    final amountColor = tx.isWithdrawal ? tokens.overdue : tokens.paid;
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
            Text(
              amountText,
              style: moneyTextStyle(
                color: amountColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            TransactionStatusPill(statusId: tx.statusId),
          ],
        ),
        if (w.onAction != null && !w.selecting) ...[
          const SizedBox(width: 4),
          EntityActionsPopupButton<TransactionAction>(
            items: TransactionActions.itemsFor(context, tx, w.onAction!),
          ),
        ],
      ],
    );
  }

  Widget _identity(BuildContext context, InTheme tokens) {
    final tx = widget.transaction;
    final headline = tx.participantName.isNotEmpty
        ? tx.participantName
        : (tx.description.isNotEmpty ? tx.description : '—');
    // Format through the active company's date format (a FormatterScope wraps
    // the list); fall back to ISO only when no scope is present.
    final formatter = FormatterScope.maybeOf(context);
    final dateText = tx.date == null
        ? ''
        : (formatter?.date(tx.date!.toIso()) ?? tx.date!.toIso());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          headline,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (dateText.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            dateText,
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
    required this.transaction,
    required this.child,
  });
  final ColumnDefinition<BankTransaction> column;
  final BankTransaction transaction;
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
      value: column.valueBuilder?.call(transaction),
      align: column.align,
      child: aligned,
    );
    if (column.isFlex) return Expanded(child: cell);
    return SizedBox(width: column.width, child: cell);
  }
}
