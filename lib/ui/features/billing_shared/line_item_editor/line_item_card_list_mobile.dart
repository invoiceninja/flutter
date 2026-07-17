import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_column_config.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_edit_dialog.dart';
import 'package:admin/utils/formatting.dart';

/// Mobile-friendly line-item list. Each row is a tap-to-edit card showing
/// the identity (product key / first line of notes), qty × cost, and the
/// computed gross. Drag-handle on the right enables reorder.
///
/// The caller manages the [LineItem] list and supplies a fresh-row factory
/// for the "Add item" button. Edits open the shared [showLineItemEditDialog].
class LineItemCardListMobile extends StatelessWidget {
  const LineItemCardListMobile({
    super.key,
    required this.companyId,
    required this.items,
    required this.onChanged,
    required this.newItemFactory,
    required this.config,
    this.currencyId,
    this.onPickItems,
  });

  /// Company scope used to look up the active [Formatter] so cost /
  /// total render through the company's currency + decimal-separator
  /// settings. CLAUDE.md mandates `Formatter.money` for displayed
  /// money values.
  final String companyId;

  final List<LineItem> items;
  final ValueChanged<List<LineItem>> onChanged;

  /// Factory for a fresh row when the user taps "Add item". Typically
  /// returns [emptyLineItem]; an entity-specific factory can seed defaults
  /// (e.g. the company's default tax rate names).
  final LineItem Function() newItemFactory;

  final LineItemColumnConfig config;

  /// Resolved display currency for line-item money (vendor currency for POs,
  /// client currency for client-billed docs). Null → company default.
  final String? currencyId;

  /// Opens the bulk products/tasks/expenses picker. When non-null, the
  /// empty-state "Add item" button on a zero-row draft routes through the
  /// picker (matches the items-section FAB). When null, the button still
  /// appears but appends a blank row — only used in test contexts that
  /// don't wire the picker.
  final VoidCallback? onPickItems;

  Future<void> _openEditor(BuildContext context, int index) async {
    final fmt = context.read<Services>().formatterIfReady(companyId);
    final useComma = fmt?.settings.useCommaAsDecimalPlace ?? false;
    final result = await showLineItemEditDialog(
      context,
      initial: items[index],
      config: config,
      useComma: useComma,
    );
    if (result == null) return;
    final next = List<LineItem>.from(items)..[index] = result;
    onChanged(next);
  }

  void _remove(int index) {
    final next = List<LineItem>.from(items)..removeAt(index);
    onChanged(next);
  }

  void _add() {
    final next = List<LineItem>.from(items)..add(newItemFactory());
    onChanged(next);
  }

  void _onReorder(int oldIndex, int newIndex) {
    final next = List<LineItem>.from(items);
    final row = next.removeAt(oldIndex);
    next.insert(newIndex, row);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    if (items.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: InSpacing.lg(context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, color: tokens.ink3, size: 28),
            const SizedBox(height: 8),
            Text(
              context.tr('no_line_items'),
              style: TextStyle(color: tokens.ink3),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
              icon: const Icon(Icons.add),
              label: Text(context.tr('add_item')),
              onPressed: onPickItems ?? _add,
            ),
          ],
        ),
      );
    }
    // The trailing "+ Add item" button below the cards was removed — it
    // duplicated the items-section FAB. Reordering and per-card editing
    // remain the same; bulk adds funnel through the picker.
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: items.length,
      onReorderItem: _onReorder,
      itemBuilder: (context, index) {
        final item = items[index];
        return _ItemCard(
          key: ValueKey('line_item_$index'),
          item: item,
          index: index,
          companyId: companyId,
          currencyId: currencyId,
          onTap: () => _openEditor(context, index),
          onRemove: () => _remove(index),
        );
      },
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    super.key,
    required this.item,
    required this.index,
    required this.companyId,
    required this.currencyId,
    required this.onTap,
    required this.onRemove,
  });

  final LineItem item;
  final int index;
  final String companyId;
  final String? currencyId;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    // Pull the company-scoped Formatter so cost/total render with the
    // right currency + decimal separator. Falls back to a raw decimal
    // string before the formatter resolves on first paint.
    final formatter = context.read<Services>().formatterIfReady(companyId);
    String fmt(Decimal d) =>
        formatter?.money(d, zeroIsNull: false, currencyId: currencyId) ??
        d.toString();
    final gross = item.gross;
    final identity = item.productKey.isEmpty
        ? (item.notes.isEmpty
              ? context.tr('untitled')
              : item.notes.split('\n').first)
        : item.productKey;
    final detail = '${fmt(item.cost)} × ${item.quantity}';
    return Container(
      margin: EdgeInsets.only(bottom: InSpacing.md(context)),
      decoration: BoxDecoration(
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(InRadii.r2),
        color: tokens.surface,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(InRadii.r2),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: InSpacing.md(context),
            vertical: 10,
          ),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Icon(Icons.drag_indicator, color: tokens.ink3, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      identity,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: tokens.ink3, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(fmt(gross), style: moneyTextStyle(color: tokens.ink)),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: tokens.ink3,
                onPressed: onRemove,
                tooltip: context.tr('remove'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
