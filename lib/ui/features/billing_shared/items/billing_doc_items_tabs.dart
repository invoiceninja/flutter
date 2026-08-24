import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_column_config.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_editor.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_table_desktop.dart';
import 'package:admin/ui/features/billing_shared/view_models/billing_doc_edit_view_model.dart';

/// Items-section wrapper that conditionally surfaces a TabBar over the
/// `LineItemEditor` when the draft has task or expense lines. The user
/// requested this on `invoice/quote/credit/recurring` edit screens so a
/// mixed-type line-item list (some products, some tasks) can be browsed
/// per type rather than as one long interleaved list.
///
/// Modes:
///   * **No tasks AND no expenses present** → pass-through to a single
///     `LineItemEditor` over the full list. Today's UX, unchanged.
///   * **Any task OR expense present** → renders a `TabBar` above an
///     `IndexedStack` of three `LineItemEditor` instances (one per type).
///     Each editor sees the filtered subset for its type. Edits are
///     merged back into the full list (via [mergeBackByType]) preserving
///     the relative position of rows in the other types — see the
///     merge-back doctests below.
///
/// All three editor instances are mounted (offstage when their tab isn't
/// active) so cell focus / cursor position / drag state survive tab
/// switching. Each editor's desktop `LineItemTableDesktopController` is
/// registered with `vm.addBeforeSaveHook(...)` so a Save click flushes
/// every editor's debounced text-field edits regardless of which tab is
/// active. The wrapper registers `vm.stripEmptyLineItems` exactly once.
///
/// Row-error highlighting (`rowErrors`) is keyed by *full-list* index in
/// the VM but the filtered editor renders with local subset indices, so
/// the highlight wouldn't align. The wrapper passes `null` for
/// `rowErrors` to the per-tab editors — the existing field-error UI on
/// the validation banner still surfaces the cross-client error from the
/// VM. (Server-side `cost` / `quantity` row errors are rare enough that
/// dropping the inline tint in tabbed mode is an acceptable trade.)
class BillingDocItemsTabs extends StatefulWidget {
  const BillingDocItemsTabs({
    super.key,
    required this.vm,
    required this.companyId,
    required this.lineItems,
    required this.onChanged,
    required this.newItemFactory,
    required this.rowErrors,
    required this.onPickItems,
    this.showStockQuantity = false,
  });

  /// For `addBeforeSaveHook` + `stripEmptyLineItems`. Type-erased to keep
  /// this widget reusable across invoice/quote/credit/recurring layouts.
  final GenericBillingDocEditViewModel<dynamic> vm;
  final String companyId;
  final List<LineItem> lineItems;
  final ValueChanged<List<LineItem>> onChanged;
  final LineItem Function() newItemFactory;
  final Map<int, Map<String, String>>? rowErrors;
  final VoidCallback onPickItems;

  /// Invoice host only — show the bracketed in-stock count in the products
  /// tab's product typeahead. Forwarded to the products `LineItemEditor`.
  final bool showStockQuantity;

  @override
  State<BillingDocItemsTabs> createState() => _BillingDocItemsTabsState();
}

enum _LineKind { products, tasks, expenses }

bool _isProductLine(LineItem li) =>
    (li.taskId ?? '').isEmpty && (li.expenseId ?? '').isEmpty;
bool _isTaskLine(LineItem li) => (li.taskId ?? '').isNotEmpty;
bool _isExpenseLine(LineItem li) => (li.expenseId ?? '').isNotEmpty;

bool _predicate(_LineKind kind, LineItem li) {
  switch (kind) {
    case _LineKind.products:
      return _isProductLine(li);
    case _LineKind.tasks:
      return _isTaskLine(li);
    case _LineKind.expenses:
      return _isExpenseLine(li);
  }
}

/// Pure helper: fold an edited subset back into the full list, dropping
/// removed rows, preserving the rows of other kinds at their original
/// positions, and appending net-new rows at the end. Exported (top-level)
/// so the merge logic can be unit-tested without a full widget pump.
///
/// Behavior cheatsheet:
///   * Original: `[P1, T1, P2, T2, P3]`, updated tasks: `[T2, T1]`
///     → result: `[P1, T2, P2, T1, P3]` (tasks swap; products pinned).
///   * Original: `[P1, T1, P2]`, updated tasks: `[]`
///     → result: `[P1, P2]` (T1 dropped).
///   * Original: `[P1, T1]`, updated tasks: `[T1, T2]`
///     → result: `[P1, T1, T2]` (T2 appended).
List<LineItem> mergeBackByType({
  required List<LineItem> original,
  required List<LineItem> updatedSubset,
  required bool Function(LineItem) inSubset,
}) {
  final result = <LineItem>[];
  var newIdx = 0;
  for (final orig in original) {
    if (inSubset(orig)) {
      // Refill the original slot with the next entry from the updated
      // subset. If the subset is shorter than the original count, the
      // surplus slots collapse — that's a "delete from the subset".
      if (newIdx < updatedSubset.length) {
        result.add(updatedSubset[newIdx]);
        newIdx++;
      }
    } else {
      result.add(orig);
    }
  }
  // Net-new rows beyond the original count append at the end.
  while (newIdx < updatedSubset.length) {
    result.add(updatedSubset[newIdx]);
    newIdx++;
  }
  return result;
}

class _BillingDocItemsTabsState extends State<BillingDocItemsTabs>
    with TickerProviderStateMixin {
  // One controller per type. Each is registered with the VM's
  // `addBeforeSaveHook` so Save flushes debounced text-field edits across
  // all three editors regardless of which tab is currently visible.
  final _productsCtl = LineItemTableDesktopController();
  final _tasksCtl = LineItemTableDesktopController();
  final _expensesCtl = LineItemTableDesktopController();

  TabController? _tabCtl;
  VoidCallback? _unregisterProductsFlush;
  VoidCallback? _unregisterTasksFlush;
  VoidCallback? _unregisterExpensesFlush;
  VoidCallback? _unregisterStrip;

  // Cached so we can detect when the visible-tab set changes.
  bool _hasTasks = false;
  bool _hasExpenses = false;

  @override
  void initState() {
    super.initState();
    _hasTasks = widget.lineItems.any(_isTaskLine);
    _hasExpenses = widget.lineItems.any(_isExpenseLine);
    _rebuildTabController(jumpTo: 0);
    _unregisterProductsFlush = widget.vm.addBeforeSaveHook(
      _productsCtl.flushPending,
    );
    _unregisterTasksFlush = widget.vm.addBeforeSaveHook(_tasksCtl.flushPending);
    _unregisterExpensesFlush = widget.vm.addBeforeSaveHook(
      _expensesCtl.flushPending,
    );
    _unregisterStrip = widget.vm.addBeforeSaveHook(
      widget.vm.stripEmptyLineItems,
    );
  }

  @override
  void didUpdateWidget(BillingDocItemsTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hasTasksNow = widget.lineItems.any(_isTaskLine);
    final hasExpensesNow = widget.lineItems.any(_isExpenseLine);
    if (hasTasksNow != _hasTasks || hasExpensesNow != _hasExpenses) {
      // Tab set changed (e.g. user deleted the last task line). Remap
      // the controller so the count matches and clamp the active index
      // into range.
      final prevKind = _activeKindOrNull();
      _hasTasks = hasTasksNow;
      _hasExpenses = hasExpensesNow;
      final visible = _visibleTabs();
      var nextIdx = 0;
      if (prevKind != null) {
        final newIdx = visible.indexOf(prevKind);
        if (newIdx >= 0) nextIdx = newIdx;
      }
      _rebuildTabController(jumpTo: nextIdx);
    }
  }

  void _rebuildTabController({required int jumpTo}) {
    _tabCtl?.dispose();
    final length = _visibleTabs().length;
    _tabCtl = TabController(length: length, vsync: this)
      ..index = jumpTo.clamp(0, length - 1);
    _tabCtl!.addListener(() => setState(() {}));
  }

  _LineKind? _activeKindOrNull() {
    final visible = _visibleTabs();
    if (_tabCtl == null) return null;
    if (visible.isEmpty) return null;
    return visible[_tabCtl!.index.clamp(0, visible.length - 1)];
  }

  List<_LineKind> _visibleTabs() => <_LineKind>[
    _LineKind.products,
    if (_hasTasks) _LineKind.tasks,
    if (_hasExpenses) _LineKind.expenses,
  ];

  int _stackIndexOf(_LineKind kind) {
    switch (kind) {
      case _LineKind.products:
        return 0;
      case _LineKind.tasks:
        return 1;
      case _LineKind.expenses:
        return 2;
    }
  }

  @override
  void dispose() {
    _unregisterProductsFlush?.call();
    _unregisterTasksFlush?.call();
    _unregisterExpensesFlush?.call();
    _unregisterStrip?.call();
    _tabCtl?.dispose();
    super.dispose();
  }

  List<LineItem> _subset(_LineKind kind) {
    return widget.lineItems.where((li) => _predicate(kind, li)).toList();
  }

  void _onSubsetChanged(_LineKind kind, List<LineItem> updatedSubset) {
    final next = mergeBackByType(
      original: widget.lineItems,
      updatedSubset: updatedSubset,
      inSubset: (li) => _predicate(kind, li),
    );
    widget.onChanged(next);
  }

  LineItemTableDesktopController _controllerFor(_LineKind kind) {
    switch (kind) {
      case _LineKind.products:
        return _productsCtl;
      case _LineKind.tasks:
        return _tasksCtl;
      case _LineKind.expenses:
        return _expensesCtl;
    }
  }

  Widget _editor(_LineKind kind) {
    return LineItemEditor(
      companyId: widget.companyId,
      clientId: widget.vm.clientIdOf(widget.vm.draft),
      items: _subset(kind),
      onChanged: (next) => _onSubsetChanged(kind, next),
      newItemFactory: widget.newItemFactory,
      // What this host *wants* to show. `LineItemEditor` narrows it to what
      // the company actually enables — it already watches the company row for
      // the discount column, so the tax count rides that read rather than
      // opening a second subscription (invoiceninja/flutter#85).
      //
      // One tax column, not zero: this is also what renders for the frame
      // before the company arrives, and starting at zero would pop the column
      // in a beat later. Same "keep the host's config until we know better"
      // rule the discount column has always used.
      config: const LineItemColumnConfig(showDiscount: true, taxColumnCount: 1),
      controller: _controllerFor(kind),
      // Stock count is a product-selection affordance — only the products
      // tab's typeahead surfaces it (and only on invoices, via the host).
      showStockQuantity: widget.showStockQuantity && kind == _LineKind.products,
      // Row-error indices key off the full list; per-tab indices won't
      // line up. The cross-client error still surfaces in the validation
      // banner, so the per-row tint is just a polish loss in tabbed mode.
      rowErrors: null,
      onPickItems: widget.onPickItems,
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleTabs();
    if (visible.length == 1) {
      // No tasks AND no expenses present — pass-through, no tab chrome.
      return _editor(_LineKind.products);
    }

    final tokens = context.inTheme;
    final activeKind = _activeKindOrNull() ?? _LineKind.products;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _tabCtl,
          isScrollable: false,
          labelColor: tokens.ink,
          unselectedLabelColor: tokens.ink3,
          tabs: [for (final k in visible) Tab(text: _tabLabel(context, k))],
        ),
        Divider(height: 1, color: tokens.border),
        SizedBox(height: InSpacing.md(context)),
        IndexedStack(
          index: _stackIndexOf(activeKind),
          children: [
            _editor(_LineKind.products),
            _editor(_LineKind.tasks),
            _editor(_LineKind.expenses),
          ],
        ),
      ],
    );
  }

  String _tabLabel(BuildContext context, _LineKind kind) {
    final count = _subset(kind).where((li) => !li.isBlank).length;
    final base = switch (kind) {
      _LineKind.products => context.tr('products'),
      _LineKind.tasks => context.tr('tasks'),
      _LineKind.expenses => context.tr('expenses'),
    };
    return count == 0 ? base : '$base ($count)';
  }
}
