import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/billing/line_item_type.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_column_config.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_editor.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_table_desktop.dart';
import 'package:admin/ui/features/billing_shared/view_models/billing_doc_edit_view_model.dart';

/// Items-section wrapper that surfaces a Products / Tasks / Expenses TabBar
/// over the `LineItemEditor` on `invoice/quote/credit/recurring` edit screens,
/// so a mixed-type line-item list can be browsed per type rather than as one
/// long interleaved list — and so an hourly line can be typed at all.
///
/// Modes:
///   * **Only products, and no Tasks tab on offer** → one `LineItemEditor`
///     over the full list, no tab chrome.
///   * **Any task or expense line present, or the company's "Show Tasks
///     Table" setting on a document that [offerTasksTab]s** → a `TabBar`
///     above one `LineItemEditor` per type. Each editor sees the filtered
///     subset for its type. Edits are merged back into the full list (via
///     [mergeBackByType]) preserving the relative position of rows in the
///     other types — see the merge-back doctests below.
///
/// A Tasks-tab row is **hourly**: its new rows are `type_id` 2, which is what
/// puts it in the PDF's task table, and its columns read Service / Rate /
/// Hours. Before `show_tasks_table` was read here the tab only appeared once
/// a task had been picked, so a user who bills by the hour without the Tasks
/// module had no way to write one — and flipping the setting did nothing.
///
/// Every visible tab's editor is mounted (offstage when its tab isn't active)
/// so cell focus / cursor position / drag state survive tab switching. Each
/// editor's desktop `LineItemTableDesktopController` is registered with
/// `vm.addFlushHook(...)` so a Save click — or opening the line-item picker —
/// flushes every editor's debounced text-field edits regardless of which tab
/// is active. The wrapper registers `vm.stripEmptyLineItems` exactly once, as
/// a save-only before-save hook.
///
/// **Invariant: [onChanged] must write through to [vm]'s draft.** The merge-back
/// reads `vm.lineItemsOf(vm.draft)` rather than [lineItems] so that a Save —
/// which flushes all three editors in one synchronous pass — doesn't have each
/// flush rebuild from a list that predates the previous one. Every call site
/// pairs `lineItems: vm.draft.lineItems` with `onChanged: vm.replaceLineItems`,
/// which is what makes the two the same list.
///
/// Row errors (`rowErrors`) are keyed by *full-list* index in the VM; each
/// per-tab editor gets them re-keyed to its own subset through
/// [subsetRowErrors].
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
    this.offerTasksTab = false,
    this.onCreateTaskFromLineItem,
  });

  /// For `addFlushHook` + `stripEmptyLineItems`. Type-erased to keep
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

  /// This document keeps a Tasks tab when the company's "Show Tasks Table"
  /// (`show_tasks_table`) is on, even with no hourly line yet —
  /// `BillingDocType.offersTasksTable`. A document that already has one shows
  /// the tab whatever this says.
  final bool offerTasksTab;

  /// Invoice / quote hosts only — schedule a line's work as a dated task
  /// (invoiceninja/flutter#88). Forwarded to ALL THREE tabs: an expense line is
  /// still schedulable, and the "already a task" gate lives at the row, so one
  /// rule holds for the tabbed and untabbed cases alike.
  final ValueChanged<LineItem>? onCreateTaskFromLineItem;

  @override
  State<BillingDocItemsTabs> createState() => _BillingDocItemsTabsState();
}

enum _LineKind { products, tasks, expenses }

// A strict partition — every line is exactly one kind, which `mergeBackByType`
// relies on. Keyed on the TYPE as well as the link: a free-form hourly line
// (`type_id` 2, no `task_id`) is a Tasks line — the server prints it in the
// PDF's task table. Expense lines are `standard` + `expense_id`; the only
// type-6 line this app makes is the desktop row-menu clone of one, which drops
// the link and is stamped type 6 so it stays in the Expenses tab.
bool _isExpenseLine(LineItem li) =>
    (li.expenseId ?? '').isNotEmpty || li.typeId == LineItemType.expense;
bool _isTaskLine(LineItem li) =>
    !_isExpenseLine(li) &&
    ((li.taskId ?? '').isNotEmpty || li.typeId == LineItemType.task);
bool _isProductLine(LineItem li) => !_isExpenseLine(li) && !_isTaskLine(li);

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

/// Non-blank lines per kind. Blank rows are the desktop table's placeholder
/// and a just-added row nobody has typed into — neither is "a line was added".
Map<_LineKind, int> _countByKind(List<LineItem> items) => {
  for (final kind in _LineKind.values)
    kind: items.where((li) => !li.isBlank && _predicate(kind, li)).length,
};

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

/// Re-key [rowErrors] — keyed by index in the FULL line-item list, which is
/// how the server names them (`line_items.3.cost`) — to the index each row has
/// in the subset [inSubset] keeps, in list order (the order the per-tab
/// editors render). Rows outside the subset drop out. Exported (top-level) so
/// the mapping can be unit-tested without a widget pump.
Map<int, Map<String, String>> subsetRowErrors({
  required List<LineItem> lineItems,
  required Map<int, Map<String, String>>? rowErrors,
  required bool Function(LineItem) inSubset,
}) {
  if (rowErrors == null || rowErrors.isEmpty) return const {};
  final out = <int, Map<String, String>>{};
  var subsetIndex = 0;
  for (var i = 0; i < lineItems.length; i++) {
    if (!inSubset(lineItems[i])) continue;
    final errors = rowErrors[i];
    if (errors != null && errors.isNotEmpty) out[subsetIndex] = errors;
    subsetIndex++;
  }
  return out;
}

class _BillingDocItemsTabsState extends State<BillingDocItemsTabs>
    with TickerProviderStateMixin {
  // One controller per type. Each is registered with the VM's
  // `addFlushHook` so Save flushes debounced text-field edits across all
  // three editors regardless of which tab is currently visible.
  final _productsCtl = LineItemTableDesktopController();
  final _tasksCtl = LineItemTableDesktopController();
  final _expensesCtl = LineItemTableDesktopController();

  TabController? _tabCtl;

  /// The kinds [_tabCtl] was built for, in tab order. Compared as a LIST, not
  /// a count: Tasks leaving as Expenses arrives keeps the length and changes
  /// what every index means.
  List<_LineKind> _tabs = const [_LineKind.products];

  /// A remembered tab that isn't on offer yet — Tasks with no hourly line,
  /// before the company's `show_tasks_table` has landed. Consumed by the first
  /// company event, so it can't fire later as a surprise jump.
  _LineKind? _restoreOnCompany;
  VoidCallback? _unregisterProductsFlush;
  VoidCallback? _unregisterTasksFlush;
  VoidCallback? _unregisterExpensesFlush;
  VoidCallback? _unregisterStrip;

  /// The company's `show_tasks_table`. Read from a subscription rather than a
  /// `StreamBuilder` because it changes the TAB SET, and the tab controller
  /// is rebuilt in exactly one place ([_syncTabs]). Seeded from the repo's
  /// first-frame `peek` so the tab bar is there on the first frame instead of
  /// dropping everything below it a frame later; the subscription owns the
  /// value from its first event. When there is no seed the row lands late, so
  /// the widget tree keeps one shape either way (see [build]) — the tab bar
  /// arriving must not remount the products editor under it.
  StreamSubscription<Company?>? _companySub;
  bool _showTasksTable = false;

  /// Set when one of this widget's own editors changed the lines, and consumed
  /// by the next [didUpdateWidget]. Only lines added from OUTSIDE — the picker
  /// writes through `replaceLineItems` directly — move the view; an edit made
  /// in a tab (a clone, a row whose debounce commits after the user already
  /// switched tabs) must not yank them anywhere.
  bool _ownEdit = false;

  // Cached so we can detect when the visible-tab set changes.
  bool _hasTasks = false;
  bool _hasExpenses = false;

  @override
  void initState() {
    super.initState();
    _hasTasks = widget.lineItems.any(_isTaskLine);
    _hasExpenses = widget.lineItems.any(_isExpenseLine);
    _showTasksTable =
        context
            .read<Services>()
            .company
            .peek(companyId: widget.companyId, id: widget.companyId)
            ?.showTasksTable ??
        false;
    _tabs = _visibleTabs();
    _rebuildTabController(jumpTo: _tabs.indexOf(_initialKind()));
    _listenToCompany();
    // Flush hooks, not before-save hooks: the line-item picker commits them
    // too before it reads the list. Stripping blank rows stays save-only.
    _unregisterProductsFlush = widget.vm.addFlushHook(
      _productsCtl.flushPending,
    );
    _unregisterTasksFlush = widget.vm.addFlushHook(_tasksCtl.flushPending);
    _unregisterExpensesFlush = widget.vm.addFlushHook(
      _expensesCtl.flushPending,
    );
    _unregisterStrip = widget.vm.addBeforeSaveHook(
      widget.vm.stripEmptyLineItems,
    );
  }

  /// The tab to open on: the one this document last showed (the narrow
  /// layout's `TabBarView` rebuilds this widget whenever the user comes back
  /// from another tab), else Tasks for a document that bills only hours —
  /// admin-portal's rule — else Products. Mount-time only: deleting the last
  /// product line later must not yank the user across to Tasks.
  _LineKind _initialKind() {
    final remembered = _LineKind.values.asNameMap()[widget.vm.itemsTab];
    if (remembered != null) {
      if (_tabs.contains(remembered)) return remembered;
      _restoreOnCompany = remembered;
    }
    if (_hasTasks && !widget.lineItems.any(_isProductLine)) {
      return _LineKind.tasks;
    }
    return _LineKind.products;
  }

  void _listenToCompany() {
    _companySub?.cancel();
    _companySub = context
        .read<Services>()
        .company
        .watchCompany(widget.companyId)
        .listen((company) {
          if (!mounted) return;
          final restore = _restoreOnCompany;
          _restoreOnCompany = null;
          final show = company?.showTasksTable ?? false;
          if (show == _showTasksTable) return;
          setState(() {
            _showTasksTable = show;
            _syncTabs(follow: restore);
          });
        });
  }

  @override
  void didUpdateWidget(BillingDocItemsTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) _listenToCompany();
    _hasTasks = widget.lineItems.any(_isTaskLine);
    _hasExpenses = widget.lineItems.any(_isExpenseLine);
    final ownEdit = _ownEdit;
    _ownEdit = false;
    _syncTabs(
      follow: ownEdit
          ? null
          : _grownKind(oldWidget.lineItems, widget.lineItems),
    );
  }

  /// The one kind that gained lines between [before] and [after], if exactly
  /// one did. Picking tasks from the Products tab (the FAB, ⌘N, Add Items)
  /// lands them in a tab the user isn't looking at; following them there is
  /// what shows the pick worked. Two kinds growing at once — a document
  /// loading, or a mixed pick — is no signal, and nothing moves.
  _LineKind? _grownKind(List<LineItem> before, List<LineItem> after) {
    if (identical(before, after)) return null;
    final was = _countByKind(before);
    final now = _countByKind(after);
    final grown = [
      for (final kind in _LineKind.values)
        if (now[kind]! > was[kind]!) kind,
    ];
    return grown.length == 1 ? grown.single : null;
  }

  /// Reconcile the tab controller with the visible tab set, and move to
  /// [follow] when it names a tab other than the active one. Every change to
  /// the tab set — a line added or removed, the company's setting landing —
  /// comes through here.
  void _syncTabs({_LineKind? follow}) {
    final prevKind = _activeKind();
    final next = _visibleTabs();
    final target = follow != null && next.contains(follow) ? follow : prevKind;
    if (!listEquals(next, _tabs)) {
      // Tab set changed (e.g. the setting landed, or the last task line was
      // deleted). Remap the controller, staying on the same kind when it's
      // still there.
      _tabs = next;
      final idx = next.indexOf(target);
      _rebuildTabController(jumpTo: idx < 0 ? 0 : idx);
    } else if (target != prevKind) {
      _tabCtl!.animateTo(next.indexOf(target));
    }
  }

  void _rebuildTabController({required int jumpTo}) {
    _tabCtl?.dispose();
    _tabCtl = TabController(length: _tabs.length, vsync: this)
      ..index = jumpTo.clamp(0, _tabs.length - 1);
    _tabCtl!.addListener(_onTabChanged);
    // Not while a remembered tab waits for the company to offer it: recording
    // the Products placeholder would forget it before it could be restored.
    if (_restoreOnCompany == null) widget.vm.itemsTab = _activeKind().name;
  }

  void _onTabChanged() {
    // A tab the user picked wins over one still waiting to be restored.
    _restoreOnCompany = null;
    widget.vm.itemsTab = _activeKind().name;
    setState(() {});
  }

  _LineKind _activeKind() {
    final ctl = _tabCtl;
    if (ctl == null) return _LineKind.products;
    return _tabs[ctl.index.clamp(0, _tabs.length - 1)];
  }

  bool get _showTasks => _hasTasks || (widget.offerTasksTab && _showTasksTable);

  List<_LineKind> _visibleTabs() => <_LineKind>[
    _LineKind.products,
    if (_showTasks) _LineKind.tasks,
    if (_hasExpenses) _LineKind.expenses,
  ];

  @override
  void dispose() {
    _companySub?.cancel();
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
      // The VM's draft, NOT `widget.lineItems`. `onChanged` writes through to
      // `vm.draft` synchronously, but the props only catch up on the next
      // frame — and `save()` runs all four before-save hooks in ONE synchronous
      // loop. Merging into the props therefore had every hook start from the
      // list as it was before Save began: hook 1 (products flush) committed its
      // edit, hook 2 (tasks flush) rebuilt from the pre-Save list and silently
      // dropped it. Same "props don't update within the frame" trap the
      // `_items` seam closes inside `LineItemTableDesktop`, one level down.
      original: widget.vm.lineItemsOf(widget.vm.draft),
      updatedSubset: updatedSubset,
      inSubset: (li) => _predicate(kind, li),
    );
    _ownEdit = true;
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

  /// A new row in the Tasks tab is hourly (`type_id` 2) — otherwise the line
  /// typed there would be a product line and jump straight out of the tab.
  LineItem Function() _factoryFor(_LineKind kind) => kind == _LineKind.tasks
      ? () => widget.newItemFactory().copyWith(typeId: LineItemType.task)
      : widget.newItemFactory;

  Widget _editor(_LineKind kind) {
    return LineItemEditor(
      companyId: widget.companyId,
      clientId: widget.vm.clientIdOf(widget.vm.draft),
      items: _subset(kind),
      onChanged: (next) => _onSubsetChanged(kind, next),
      newItemFactory: _factoryFor(kind),
      // What this host *wants* to show. `LineItemEditor` narrows it to what
      // the company actually enables — it watches the company row for the
      // discount column, so the tax count rides that read rather than opening
      // another subscription per editor (invoiceninja/flutter#85). The tabs'
      // own read above is a different question — which tabs exist — asked once.
      //
      // One tax column, not zero: this is also what renders for the frame
      // before the company arrives, and starting at zero would pop the column
      // in a beat later. Same "keep the host's config until we know better"
      // rule the discount column has always used.
      config: LineItemColumnConfig(
        showDiscount: true,
        taxColumnCount: 1,
        isTaskTable: kind == _LineKind.tasks,
      ),
      controller: _controllerFor(kind),
      // Stock count is a product-selection affordance — only the products
      // tab's typeahead surfaces it (and only on invoices, via the host).
      showStockQuantity: widget.showStockQuantity && kind == _LineKind.products,
      rowErrors: subsetRowErrors(
        lineItems: widget.lineItems,
        rowErrors: widget.rowErrors,
        inSubset: (li) => _predicate(kind, li),
      ),
      onPickItems: widget.onPickItems,
      onCreateTaskFromLineItem: widget.onCreateTaskFromLineItem,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabbed = _tabs.length > 1;
    final activeKind = _activeKind();
    final tokens = context.inTheme;
    final tabBar = TabBar(
      controller: _tabCtl,
      isScrollable: false,
      labelColor: tokens.ink,
      unselectedLabelColor: tokens.ink3,
      tabs: [for (final k in _tabs) Tab(text: _tabLabel(context, k))],
    );
    final gap = InSpacing.md(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // `BillingDocEditItemsBody` sets a viewport-high minHeight on the
        // narrow branch so the phone empty state centres (#141), and 0 on the
        // wide one so the table never stretches. The tab chrome spends part of
        // it; the active editor gets the rest.
        final chrome = tabbed ? tabBar.preferredSize.height + 1 + gap : 0.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (tabbed) ...[
              tabBar,
              Divider(height: 1, color: tokens.border),
              SizedBox(height: gap),
            ],
            // Keyed, and always last, so the tab bar arriving after the first
            // frame (the company row is async) inserts ABOVE the editors
            // rather than remounting them — a remount disposes the desktop
            // rows and drops a cell edit still inside its debounce.
            Column(
              key: const ValueKey('billing-items-editors'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Not an `IndexedStack`: that sizes to its TALLEST child, so a
                // one-row Tasks table sat in a Products-tall box, and it
                // loosens the minHeight the phone empty state centres in.
                // `Visibility.maintainState` keeps a hidden tab's rows, typed
                // text and flush hooks alive at zero height (and out of focus
                // traversal). Only tabs that exist get an editor — each one
                // opens its own company / currency / product watches.
                for (final kind in tabbed ? _tabs : [activeKind])
                  Visibility(
                    key: ValueKey(kind),
                    visible: kind == activeKind,
                    maintainState: true,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: math.max(0, constraints.minHeight - chrome),
                      ),
                      child: _editor(kind),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
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
