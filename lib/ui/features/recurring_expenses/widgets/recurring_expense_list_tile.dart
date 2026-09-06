import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/recurring_expense.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/recurring_frequency.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/embedded_list_scope.dart';
import 'package:admin/ui/core/list/entity_actions_popup_button.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/core/list/selectable_list_row.dart';
import 'package:admin/ui/core/widgets/cell_copy_hover.dart';
import 'package:admin/ui/core/widgets/formatter_scope.dart';
import 'package:admin/ui/core/widgets/leading_select_slot.dart';
import 'package:admin/ui/core/widgets/vendor_name_label.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/recurring_expense_status_pill.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/recurring_expense_actions.dart';

/// Cached locale-only fallback for the narrow-tile amount when no
/// `FormatterScope` is in the tree. Mirrors `ExpenseListTile`.
final NumberFormat _recurringExpenseAmountFallback =
    NumberFormat.decimalPattern()
      ..minimumFractionDigits = 2
      ..maximumFractionDigits = 2;

/// One row in the recurring expenses list.
///
/// Per UX spec: the narrow secondary line surfaces
/// `Frequency · Next run May 21` so users can plan without opening detail.
class RecurringExpenseListTile extends StatefulWidget {
  const RecurringExpenseListTile({
    super.key,
    required this.recurringExpense,
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

  final RecurringExpense recurringExpense;
  final List<ColumnDefinition<RecurringExpense>> columns;
  final VoidCallback onTap;
  final bool wide;

  /// False when the row is archived/soft-deleted; greys the wide-table
  /// standalone edit pencil. Sourced from `EntityListTileOptions.editable`.
  final bool editable;
  final ValueChanged<RecurringExpenseAction>? onAction;
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
  State<RecurringExpenseListTile> createState() =>
      _RecurringExpenseListTileState();
}

class _RecurringExpenseListTileState extends State<RecurringExpenseListTile> {
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
              : EntityActionsPopupButton<RecurringExpenseAction>(
                  splitEditAction: true,
                  editEnabled: w.editable,
                  items: RecurringExpenseActions.itemsFor(
                    context,
                    w.recurringExpense,
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
            recurringExpense: w.recurringExpense,
            child: col.cellBuilder(w.recurringExpense, context),
          ),
          const SizedBox(width: kColCellGap),
        ],
        const SizedBox(width: kColWPillSlot),
      ],
    );
  }

  Widget _narrow(BuildContext context, InTheme tokens) {
    final w = widget;
    // RecurringExpense carries its own `currencyId` — format through it so
    // narrow matches the wide table's `cellMoney`. Locale-only fallback when
    // no FormatterScope is in the tree.
    final formatter = FormatterScope.maybeOf(context);
    final formatted = formatter?.money(
      w.recurringExpense.amount,
      currencyId: w.recurringExpense.currencyId,
    );
    final amountText = (formatted != null && formatted.isNotEmpty)
        ? formatted
        : _recurringExpenseAmountFallback.format(
            w.recurringExpense.amount.toDouble(),
          );
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
            Text(amountText, style: moneyTextStyle(color: tokens.ink)),
            const SizedBox(height: 4),
            RecurringExpenseStatusPill(
              statusId: w.recurringExpense.calculatedStatusId,
            ),
          ],
        ),
        if (w.onAction != null && !w.selecting) ...[
          const SizedBox(width: 4),
          EntityActionsPopupButton<RecurringExpenseAction>(
            items: RecurringExpenseActions.itemsFor(
              context,
              w.recurringExpense,
              w.onAction!,
            ),
          ),
        ],
      ],
    );
  }

  Widget _identity(BuildContext context, InTheme tokens) {
    final e = widget.recurringExpense;
    final freqKey = kRecurringFrequencyLabelKey[e.frequencyId];
    final freqLabel = freqKey == null ? e.frequencyId : context.tr(freqKey);
    final formatter = FormatterScope.maybeOf(context);
    final nextRunText = e.nextSendDate == null
        ? null
        : formatter?.date(e.nextSendDate!.toIso()) ?? e.nextSendDate!.toIso();
    final secondary = nextRunText == null
        ? freqLabel
        : '$freqLabel · ${context.tr('next_run')} $nextRunText';
    final identStyle = const TextStyle(fontWeight: FontWeight.w600);
    final Widget identWidget;
    if (e.number.isNotEmpty) {
      identWidget = Text(
        '#${e.number}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: identStyle,
      );
    } else if (e.vendorId.isNotEmpty) {
      identWidget = VendorNameLabel(
        vendorId: e.vendorId,
        style: identStyle,
        link: true,
      );
    } else {
      identWidget = Text(
        '—',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: identStyle,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        identWidget,
        const SizedBox(height: 2),
        Text(
          secondary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: tokens.ink3, fontSize: 12),
        ),
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
    required this.recurringExpense,
    required this.child,
  });
  final ColumnDefinition<RecurringExpense> column;
  final RecurringExpense recurringExpense;
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
      value: column.valueBuilder?.call(recurringExpense),
      align: column.align,
      child: aligned,
    );
    if (column.isFlex) return Expanded(child: cell);
    return SizedBox(width: column.width, child: cell);
  }
}
