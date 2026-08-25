import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/payment_link.dart';
import 'package:admin/domain/columns/column_cells.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/recurring_frequency.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_actions_popup_button.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/core/list/selectable_list_row.dart';
import 'package:admin/ui/core/widgets/cell_copy_hover.dart';
import 'package:admin/ui/core/widgets/leading_select_slot.dart';
import 'package:admin/ui/features/payment_links/widgets/payment_link_actions.dart';

/// One row in the Payment Links list. Wide-mode renders the configured
/// columns side-by-side; narrow mode collapses to the identity (name over
/// billing frequency) plus a trailing price. Same column-slot math as
/// [ExpenseCategoryListTile] so wide mode stays consistent across settings
/// entities.
class PaymentLinkListTile extends StatelessWidget {
  const PaymentLinkListTile({
    super.key,
    required this.paymentLink,
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

  final PaymentLink paymentLink;
  final List<ColumnDefinition<PaymentLink>> columns;
  final VoidCallback onTap;
  final bool wide;

  /// False when the row is archived/soft-deleted; greys the wide-table
  /// standalone edit pencil. Sourced from `EntityListTileOptions.editable`.
  final bool editable;
  final ValueChanged<PaymentLinkAction>? onAction;
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
        SizedBox(
          width: colWMoreMenu(),
          child: (onAction == null || selecting)
              ? const SizedBox.shrink()
              : EntityActionsPopupButton<PaymentLinkAction>(
                  splitEditAction: true,
                  editEnabled: editable,
                  icon: Icons.more_horiz,
                  items: PaymentLinkActions.itemsFor(
                    context,
                    paymentLink,
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
            paymentLink: paymentLink,
            child: col.cellBuilder(paymentLink, context),
          ),
          const SizedBox(width: kColCellGap),
        ],
        const SizedBox(width: kColWPillSlot),
      ],
    );
  }

  /// Name over billing frequency, with the price trailing — the same anatomy
  /// as the Products tile. A phone row had nothing but the name in it, so
  /// quoting a client on a call meant opening every link in turn
  /// (invoiceninja/flutter#72, #73). `cellMoney` rather than a local format
  /// call so the figure matches the wide table's Price column exactly, dash-
  /// for-zero included.
  Widget _narrow(BuildContext context, InTheme tokens) {
    final freqKey = kRecurringFrequencyLabelKey[paymentLink.frequencyId];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _leading(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                paymentLink.name.isEmpty ? '—' : paymentLink.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              // A one-off link carries no frequency id, and the map returns
              // null for it — same guard the detail screen's overview uses.
              if (freqKey != null) ...[
                const SizedBox(height: 2),
                Text(
                  context.tr(freqKey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tokens.ink3, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        cellMoney(paymentLink.price, context),
        if (onAction != null && !selecting) ...[
          const SizedBox(width: 4),
          EntityActionsPopupButton<PaymentLinkAction>(
            icon: Icons.more_horiz,
            items: PaymentLinkActions.itemsFor(context, paymentLink, onAction!),
          ),
        ],
      ],
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
    required this.paymentLink,
    required this.child,
  });
  final ColumnDefinition<PaymentLink> column;
  final PaymentLink paymentLink;
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
      value: column.valueBuilder?.call(paymentLink),
      align: column.align,
      child: aligned,
    );
    if (column.isFlex) return Expanded(child: cell);
    return SizedBox(width: column.width, child: cell);
  }
}
