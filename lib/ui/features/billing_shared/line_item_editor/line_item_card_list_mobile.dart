import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/domain/tasks/line_item_notes_display.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_column_config.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_edit_dialog.dart';
import 'package:admin/utils/formatting.dart';

/// Mobile-friendly line-item list. Each row is a tap-to-edit card showing
/// the identity (product key / first line of notes), qty × cost, and the
/// computed gross. Drag-handle on the right enables reorder.
///
/// The caller manages the [LineItem] list and supplies a fresh-row factory
/// for the "Add Line" button. Both that button and a card tap open the shared
/// [showLineItemEditDialog].
///
/// Both add affordances render in BOTH states — empty and populated — via
/// [_AddItemActions]. That is not cosmetic: the Items-tab FAB that used to
/// carry the picker is gone on this branch (invoiceninja/flutter#142), so
/// `Add Items` here is the only door to it on a phone, and it used to exist
/// only while the list was empty.
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
    this.onCreateTaskFromLineItem,
  });

  /// Company scope used to look up the active [Formatter] so cost /
  /// total render through the company's currency + decimal-separator
  /// settings. CLAUDE.md mandates `Formatter.money` for displayed
  /// money values.
  final String companyId;

  final List<LineItem> items;
  final ValueChanged<List<LineItem>> onChanged;

  /// Factory for a fresh row when the user taps "Add Line" — it seeds the
  /// draft the editor dialog opens on, not a row in the list. Typically
  /// returns [emptyLineItem]; an entity-specific factory can seed defaults
  /// (e.g. the company's default tax rate names).
  final LineItem Function() newItemFactory;

  final LineItemColumnConfig config;

  /// Resolved display currency for line-item money (vendor currency for POs,
  /// client currency for client-billed docs). Null → company default.
  final String? currencyId;

  /// Opens the bulk products / tasks / expenses picker, behind the
  /// `Add Items` button. Null hides that button outright — only test contexts
  /// that don't wire a picker pass null; every host in `lib/` supplies one.
  final VoidCallback? onPickItems;

  /// When set, each card gets a "Create Task" button — schedule the work the
  /// line describes as a dated task (invoiceninja/flutter#88). The desktop
  /// table's equivalent lives in its per-row menu. Null on credit / recurring
  /// invoice / purchase order, where the button never renders.
  final ValueChanged<LineItem>? onCreateTaskFromLineItem;

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
    // The dialog is a route, so the host can go away under it — a company
    // switch, or the record closing. `onChanged` writes into the edit VM,
    // which asserts once disposed.
    if (!context.mounted) return;
    final next = List<LineItem>.from(items)..[index] = result;
    onChanged(next);
  }

  void _remove(int index) {
    final next = List<LineItem>.from(items)..removeAt(index);
    onChanged(next);
  }

  /// Open the editor on a fresh row and append it only if the user confirms.
  ///
  /// The button used to append a blank row immediately, leaving the user to
  /// find the resulting "Untitled" card and tap it — the modal now comes
  /// first, so values are set up front and Cancel adds nothing at all. The
  /// dialog is told which verb it is serving so its title and primary action
  /// say "Add" rather than "Save" (invoiceninja/flutter#142).
  ///
  /// `newItemFactory()` still seeds it, so a host that pre-fills defaults
  /// (e.g. the company's tax-rate names) keeps them; `emptyLineItem()` carries
  /// `quantity: 1`, which is why Quantity arrives usefully pre-filled while
  /// every zero renders as an empty field.
  Future<void> _add(BuildContext context) async {
    final fmt = context.read<Services>().formatterIfReady(companyId);
    final useComma = fmt?.settings.useCommaAsDecimalPlace ?? false;
    final result = await showLineItemEditDialog(
      context,
      initial: newItemFactory(),
      config: config,
      useComma: useComma,
      titleKey: 'add_line',
      actionKey: 'add',
    );
    if (result == null) return;
    if (!context.mounted) return;
    onChanged(List<LineItem>.from(items)..add(result));
  }

  void _onReorder(int oldIndex, int newIndex) {
    final next = List<LineItem>.from(items);
    final row = next.removeAt(oldIndex);
    next.insert(newIndex, row);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      // Centred rather than top-left (invoiceninja/flutter#141). The
      // horizontal half comes from the host no longer loosening this
      // subtree's constraints; the vertical half from `Center` shrink-wrapping
      // to `max(child, minHeight)` under the `ConstrainedBox` that
      // `BillingDocEditItemsBody` sets to the viewport height — so a short
      // window or a large text scale scrolls instead of overflowing.
      //
      // `EmptyStateBody`, not `EmptyState`: this is already inside a vertical
      // scroll view and a nested viewport throws on the unbounded height.
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: InSpacing.lg(context)),
          child: EmptyStateBody(
            icon: Icons.receipt_long_outlined,
            title: context.tr('no_line_items'),
            action: _AddItemActions(
              alignment: WrapAlignment.center,
              onAdd: () => _add(context),
              onPickItems: onPickItems,
            ),
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCards(context),
        Padding(
          padding: EdgeInsets.only(top: InSpacing.sm),
          child: _AddItemActions(
            alignment: WrapAlignment.start,
            onAdd: () => _add(context),
            onPickItems: onPickItems,
          ),
        ),
      ],
    );
  }

  Widget _buildCards(BuildContext context) {
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
          // A row that already IS a task can't be scheduled again.
          onCreateTask:
              onCreateTaskFromLineItem == null || (item.taskId ?? '').isNotEmpty
              ? null
              : () => onCreateTaskFromLineItem!(item),
        );
      },
    );
  }
}

/// The two add affordances, rendered identically in the empty state and under
/// a populated list so they cannot drift apart.
///
/// Two doors, because they do different things: the picker only offers rows
/// that already exist as a Product / Task / Expense, so with it as the sole
/// affordance there was no way to type a one-off line item at all on a phone —
/// the desktop table has always allowed it (invoiceninja/flutter#87). The
/// converse is invoiceninja/flutter#142: `Add Items` used to disappear once a
/// row existed, and with the FAB gone from this branch that left the picker
/// unreachable on a phone.
///
/// `Wrap`, not `Row` — two labelled buttons take a second run on a 320 px
/// phone or past ~1.2x text scale, and a `Row` would overflow instead.
/// `minimumSize: Size(64, 40)` on each, or `theme.dart`'s
/// `Size.fromHeight(40)` (= infinite width) stretches them edge to edge.
class _AddItemActions extends StatelessWidget {
  const _AddItemActions({
    required this.alignment,
    required this.onAdd,
    required this.onPickItems,
  });

  /// Centred under the empty state's icon + title; leading under a list, where
  /// the buttons continue the rows above rather than heading the pane.
  final WrapAlignment alignment;

  final VoidCallback onAdd;

  /// Null hides the picker button — see [LineItemCardListMobile.onPickItems].
  final VoidCallback? onPickItems;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: alignment,
      spacing: InSpacing.md(context),
      runSpacing: InSpacing.sm,
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
          icon: const Icon(Icons.add),
          // "Add Line", not "Add Item": the two buttons are now always
          // adjacent, and `Add Item` / `Add Items` differ by one letter while
          // doing different things — which is how #142's reporter came to read
          // the picker FAB as a duplicate of the button beside it.
          label: Text(context.tr('add_line')),
          onPressed: onAdd,
        ),
        if (onPickItems != null)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
            icon: const Icon(Icons.list_alt_outlined),
            label: Text(context.tr('add_items')),
            onPressed: onPickItems,
          ),
      ],
    );
  }
}

/// Pin a trailing icon button to the app's action-button size.
///
/// Left implicit, an `IconButton`'s LAYOUT box floors at
/// `kMinInteractiveDimension` (48) — via `materialTapTargetSize: padded` on
/// iOS/Android, and via the M3 default `minimumSize` on desktop — which is both
/// over the app's own 44 px touch floor and wider than this row can spare. With
/// two buttons in the cluster that is 96 px taken out of a ~320 px row, and the
/// `Expanded` identity column pays for all of it. Same trap, same fix, as
/// invoiceninja/flutter#89: `fixedSize` is *clamped by* min/max, so both must be
/// neutralised for it to take effect, and `shrinkWrap` stops the box being
/// re-inflated afterwards.
///
/// The money `Text` beside them is deliberately left non-flex: making it
/// `Flexible` would put it in a flex split with the identity `Expanded` and
/// hand it half the free space, costing the identity *more* width than the
/// buttons do.
ButtonStyle _trailingButtonStyle() => IconButton.styleFrom(
  fixedSize: Size(actionButtonSize(), actionButtonSize()),
  minimumSize: Size.zero,
  maximumSize: Size.infinite,
  padding: EdgeInsets.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    super.key,
    required this.item,
    required this.index,
    required this.companyId,
    required this.currencyId,
    required this.onTap,
    required this.onRemove,
    required this.onCreateTask,
  });

  final LineItem item;
  final int index;
  final String companyId;
  final String? currencyId;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  /// Null hides the affordance — see [LineItemCardListMobile.onCreateTaskFromLineItem].
  final VoidCallback? onCreateTask;

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
    // Through the display helper, not `notes.split('\n').first`: a
    // task-generated note opens with the PDF's `<div class="project-header">…`
    // wrapper, so the raw first line is a tag and nothing else.
    final summary = lineItemNotesSummary(item.notes);
    final identity = item.productKey.isEmpty
        ? (summary.isEmpty ? context.tr('untitled') : summary)
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
              if (onCreateTask != null)
                IconButton(
                  icon: const Icon(Icons.more_time, size: 20),
                  color: tokens.ink3,
                  style: _trailingButtonStyle(),
                  onPressed: onCreateTask,
                  tooltip: context.tr('create_task'),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: tokens.ink3,
                style: _trailingButtonStyle(),
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
