import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/enabled_modules.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/data/models/domain/expense_category.dart';
import 'package:admin/data/models/domain/group_setting.dart';
import 'package:admin/data/models/domain/product.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/domain/date_placeholders.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/billing_shared/add_unbilled/unbilled_line_items.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/product_stock_label.dart';
import 'package:admin/ui/features/billing_shared/line_item_picker/line_item_picker_result.dart';
import 'package:admin/utils/formatting.dart';

/// Tabbed multi-select picker body for the billing-doc edit screens.
///
/// Three tabs — Products / Tasks / Expenses — surface as available based on
/// `showTasksAndExpenses`, the company's `enabled_modules` mask, and whether
/// a client is selected on the draft. Returns the chosen [LineItem]s plus an
/// optional `projectIdHint` so the caller can inherit a picked task's project
/// when the draft has none.
///
/// Hosted by `line_item_picker_sheet.dart`'s responsive chrome
/// (showDialog ≥720 px, showModalBottomSheet below) — this widget is the
/// inner body and is chrome-agnostic.
class LineItemPickerBody extends StatefulWidget {
  const LineItemPickerBody({
    super.key,
    required this.companyId,
    required this.clientId,
    required this.showTasksAndExpenses,
    required this.invoiceInclusive,
    required this.excludedTaskIds,
    required this.excludedExpenseIds,
    required this.formatter,
    this.headedProjectIds = const {},
    this.showStockQuantity = false,
    this.maxHeight,
  });

  final String companyId;
  final String clientId;
  final bool showTasksAndExpenses;

  /// Projects the target doc already shows a task line for — they don't get a
  /// second project header. See `InvoiceAppendContext`.
  final Set<String> headedProjectIds;

  /// The target doc's `usesInclusiveTaxes` — governs whether a picked
  /// expense bills its gross (inclusive doc extracts the tax) or net
  /// (exclusive doc adds it on top). See `expenseInvoiceLineItem`.
  final bool invoiceInclusive;
  final Set<String> excludedTaskIds;
  final Set<String> excludedExpenseIds;
  final Formatter? formatter;

  /// `docTypeIsInvoice` — gates the bracketed in-stock count (`[N]`) on each
  /// product row. ANDed with the live company's `trackInventory` below.
  final bool showStockQuantity;

  /// Caps the body's overall height — non-null inside a bottom sheet so the
  /// modal honors the standard 0.85·screen cap; null inside a Dialog whose
  /// outer SizedBox already enforces a height.
  final double? maxHeight;

  @override
  State<LineItemPickerBody> createState() => _LineItemPickerBodyState();
}

class _LineItemPickerBodyState extends State<LineItemPickerBody>
    with TickerProviderStateMixin {
  // Tabs we render — derived once from props + the auth-session company.
  late final List<_TabKind> _tabs;
  late final TabController _tabCtl;

  // Shared filter input across tabs (matches admin-portal + the screenshot).
  final TextEditingController _filterCtl = TextEditingController();
  String _filter = '';
  Timer? _productDebounce;
  String _productSearch = '';

  // Data — Tasks/Expenses preload once (one client, small N); Products
  // re-issues `watchPage(search:)` on each filter change.
  bool _loadingTasksExpenses = true;
  bool _failedTasksExpenses = false;
  List<Task> _tasks = const [];
  List<Expense> _expenses = const [];

  bool _loadingProducts = true;
  List<Product> _products = const [];
  StreamSubscription<List<Product>>? _productSub;

  // Selection state — keyed by entity id per tab.
  final Set<String> _selProducts = <String>{};
  final Set<String> _selTasks = <String>{};
  final Set<String> _selExpenses = <String>{};

  /// Resolved [Product]s for the current product selection, keyed by id. The
  /// Products tab uses server-side search, so `_products` is replaced wholesale
  /// on every filter change — a product selected under one search term would
  /// vanish from `_products` (and the picker result + footer count) under the
  /// next. This map retains the selection across filter changes so
  /// [_selectedLineItems] materializes every picked product, not just those in
  /// the current search window. Kept in lockstep with [_selProducts] at every
  /// mutation site (toggle / select-all / clear). Tasks/Expenses don't need
  /// this — they're preloaded once and filtered in-memory.
  final Map<String, Product> _selectedProductsById = <String, Product>{};

  // Lookup name maps populated once at picker open via the lightweight
  // `watchActiveNames` streams (clients/projects/vendors) and the
  // `watchActive` stream (expense categories). Resolve in tens of ms for
  // typical accounts; while still loading, rows render with the
  // enrichment lines blank (no placeholder/crash).
  Map<String, String> _clientNames = const {};
  Map<String, String> _projectNames = const {};
  Map<String, String> _vendorNames = const {};
  Map<String, String> _categoryNames = const {};

  // Loaded for the task→invoice rate cascade — a picked task at rate 0
  // inherits the project / client / company `default_task_rate` instead of $0.
  Company? _company;
  Client? _client;
  GroupSetting? _group;
  Map<String, Project> _projectsById = const {};

  @override
  void initState() {
    super.initState();
    final services = context.read<Services>();
    final session = services.auth.session.value;
    final modules = session?.currentCompany?.enabledModules ?? 0;
    // Tabs are gated by the caller's `showTasksAndExpenses` (PO ⇒ false) and
    // the company's enabled-modules mask. **Not** by `clientId` — a draft
    // with no client picked yet still shows Tasks / Expenses tabs, and the
    // tab content surfaces rows where `client_id` is blank (i.e., not
    // assigned to any client). When a client is set, both client-blank and
    // client-matching rows show. See the local filter in
    // `_loadTasksAndExpenses` below.
    final tasksOn =
        widget.showTasksAndExpenses &&
        isModuleEnabled(modules, EnabledModule.tasks);
    final expensesOn =
        widget.showTasksAndExpenses &&
        isModuleEnabled(modules, EnabledModule.expenses);
    _tabs = [
      _TabKind.products,
      if (tasksOn) _TabKind.tasks,
      if (expensesOn) _TabKind.expenses,
    ];
    _tabCtl = TabController(length: _tabs.length, vsync: this);
    _tabCtl.addListener(() => setState(() {}));
    _filterCtl.addListener(_onFilterChanged);
    _subscribeProducts(initial: true);
    _loadTasksAndExpenses();
    _loadLookupMaps();
    _loadRateContext();
  }

  /// Load the company (and the target client, if any) so the task→invoice
  /// rate cascade can fall back from `task.rate` to the client / company
  /// `default_task_rate` when a picked task's own rate is 0.
  Future<void> _loadRateContext() async {
    final services = context.read<Services>();
    final company = await services.company.get(widget.companyId);
    final client = widget.clientId.isEmpty
        ? null
        : await services.clients
              .watchByRealId(companyId: widget.companyId, id: widget.clientId)
              .first;
    // Client's group tier of the rate cascade (was skipped).
    final group = (client == null || client.groupSettingsId.isEmpty)
        ? null
        : await services.groupSettings
              .watchByRealId(
                companyId: widget.companyId,
                id: client.groupSettingsId,
              )
              .first;
    // Full Project objects (not just names) so a rate-0 task picks up its
    // project's `task_rate` in the cascade.
    final projects = await services.projects
        .watchPage(companyId: widget.companyId, loadedPages: 100)
        .first;
    if (!mounted) return;
    setState(() {
      _company = company;
      _client = client;
      _group = group;
      _projectsById = {for (final p in projects) p.id: p};
    });
  }

  Future<void> _loadLookupMaps() async {
    final services = context.read<Services>();
    try {
      final results = await Future.wait<List<dynamic>>([
        services.clients.watchActiveNames(companyId: widget.companyId).first,
        services.projects.watchActiveNames(companyId: widget.companyId).first,
        services.vendors.watchActiveNames(companyId: widget.companyId).first,
        // ExpenseCategoryRepository exposes `watchActive` (full entities)
        // not `watchActiveNames` — see expense_category_repository.dart:71.
        // Slightly heavier than the id/name tuples, but the list is small
        // (categories are bundled in /refresh) so the cost is negligible.
        services.expenseCategories
            .watchActive(companyId: widget.companyId)
            .first,
      ]);
      if (!mounted) return;
      setState(() {
        _clientNames = {
          for (final r in (results[0] as List<({String id, String name})>))
            r.id: r.name,
        };
        _projectNames = {
          for (final r in (results[1] as List<({String id, String name})>))
            r.id: r.name,
        };
        _vendorNames = {
          for (final r in (results[2] as List<({String id, String name})>))
            r.id: r.name,
        };
        _categoryNames = {
          for (final c in (results[3] as List<ExpenseCategory>)) c.id: c.name,
        };
      });
    } catch (_) {
      // Look-up enrichment is best-effort — silently keep empty maps and
      // let rows render without the extra context. The picker still works.
    }
  }

  @override
  void dispose() {
    _productDebounce?.cancel();
    _productSub?.cancel();
    _filterCtl.removeListener(_onFilterChanged);
    _filterCtl.dispose();
    _tabCtl.dispose();
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────────────

  /// Wrapper around `_loadTasksAndExpenses` that resets the failed/loading
  /// flags first so the user-visible Retry button can re-issue the same
  /// fetch path without a close-and-reopen cycle. Wired into
  /// `_FailedState.onRetry` on the Tasks / Expenses tabs.
  void _retryTasksAndExpenses() {
    if (!mounted) return;
    setState(() {
      _failedTasksExpenses = false;
      _loadingTasksExpenses = true;
    });
    _loadTasksAndExpenses();
  }

  Future<void> _loadTasksAndExpenses() async {
    if (!_tabs.contains(_TabKind.tasks) && !_tabs.contains(_TabKind.expenses)) {
      if (!mounted) return;
      setState(() => _loadingTasksExpenses = false);
      return;
    }
    final services = context.read<Services>();
    // Server pull is intentionally **not** scoped by `client_id` — the
    // picker shows rows that are either unassigned (`client_id == ''`) or
    // assigned to the active draft's client. Narrowing on the server would
    // drop the unassigned half. The local `where(...)` clause below
    // re-applies the "blank-or-match" rule.
    final filters = <String, Set<String>>{
      'client_status': {'uninvoiced'},
    };
    // Page through the filtered result set (capped) with `ignoreCursor:true`
    // so the browsable list's keyset cursor is untouched. Cap protects the
    // picker open from a pathological company with thousands of unbilled
    // rows.
    Future<void> loadAll(
      Future<bool> Function({
        required String companyId,
        required int page,
        Set<EntityState> states,
        Map<String, Set<String>> extraFilters,
        bool ignoreCursor,
      })
      ensurePage,
    ) async {
      const maxPages = 5;
      for (var page = 1; page <= maxPages; page++) {
        final more = await ensurePage(
          companyId: widget.companyId,
          page: page,
          states: const {EntityState.active},
          extraFilters: filters,
          ignoreCursor: true,
        );
        if (!more) break;
      }
    }

    try {
      await Future.wait([
        if (_tabs.contains(_TabKind.tasks))
          loadAll(services.tasks.ensurePageLoaded),
        if (_tabs.contains(_TabKind.expenses))
          loadAll(services.expenses.ensurePageLoaded),
      ]);
      // 5 pages × 50 rows = 250, matching the server-side cap in `loadAll`.
      // Anything beyond that is reachable via the in-picker filter (which
      // hits the server search seam for products; for tasks/expenses the
      // 250-row window is the working set and search is local).
      const watchPages = 5;
      final tasks = _tabs.contains(_TabKind.tasks)
          ? (await services.tasks
                    .watchPage(
                      companyId: widget.companyId,
                      loadedPages: watchPages,
                      states: const {EntityState.active},
                    )
                    .first)
                .where(
                  (t) =>
                      !t.isInvoiced &&
                      // Running tasks would bill a live-timer snapshot; React
                      // (tasks hooks.tsx:651) excludes them from the picker too.
                      !t.isRunning &&
                      !widget.excludedTaskIds.contains(t.id) &&
                      (t.clientId.isEmpty || t.clientId == widget.clientId),
                )
                .toList()
          : const <Task>[];
      final expenses = _tabs.contains(_TabKind.expenses)
          ? (await services.expenses
                    .watchPage(
                      companyId: widget.companyId,
                      loadedPages: watchPages,
                      states: const {EntityState.active},
                    )
                    .first)
                .where(
                  (e) =>
                      !e.isInvoiced &&
                      !e.isDeleted &&
                      !widget.excludedExpenseIds.contains(e.id) &&
                      (e.clientId.isEmpty || e.clientId == widget.clientId),
                )
                .toList()
          : const <Expense>[];
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _expenses = expenses;
        _loadingTasksExpenses = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingTasksExpenses = false;
        _failedTasksExpenses = true;
      });
    }
  }

  void _subscribeProducts({bool initial = false}) {
    final services = context.read<Services>();
    _productSub?.cancel();
    if (initial) {
      _loadingProducts = true;
    }
    // Best-effort server-side fetch — failures don't block; Drift's
    // existing rows (and the watch stream) keep working.
    unawaited(
      services.products
          .ensurePageLoaded(
            companyId: widget.companyId,
            page: 1,
            search: _productSearch.isEmpty ? null : _productSearch,
          )
          .catchError((_) => false),
    );
    _productSub = services.products
        .watchPage(
          companyId: widget.companyId,
          search: _productSearch.isEmpty ? null : _productSearch,
          // 4 pages worth of rows (200) is generous for the picker; the
          // typical pick-from-recent flow finds the product near the top.
          loadedPages: 4,
        )
        .listen((rows) {
          if (!mounted) return;
          setState(() {
            _products = rows;
            _loadingProducts = false;
          });
        });
  }

  void _onFilterChanged() {
    final next = _filterCtl.text;
    if (next == _filter) return;
    setState(() => _filter = next);
    // Products: 250 ms debounce → re-subscribe with server `search=`.
    // Tasks/Expenses: in-memory list filter, no debounce.
    _productDebounce?.cancel();
    _productDebounce = Timer(const Duration(milliseconds: 250), () {
      final q = next.trim();
      if (q == _productSearch) return;
      _productSearch = q;
      _subscribeProducts();
    });
  }

  // ── Filtered views ───────────────────────────────────────────────────

  String _lower(String s) => s.toLowerCase();

  bool _taskMatches(Task t, String f) {
    if (f.isEmpty) return true;
    return _lower(t.description).contains(f) || _lower(t.number).contains(f);
  }

  bool _expenseMatches(Expense e, String f) {
    if (f.isEmpty) return true;
    return _lower(e.publicNotes).contains(f) || _lower(e.number).contains(f);
  }

  List<Task> get _filteredTasks {
    final f = _lower(_filter.trim());
    if (f.isEmpty) return _tasks;
    return _tasks.where((t) => _taskMatches(t, f)).toList(growable: false);
  }

  List<Expense> get _filteredExpenses {
    final f = _lower(_filter.trim());
    if (f.isEmpty) return _expenses;
    return _expenses
        .where((e) => _expenseMatches(e, f))
        .toList(growable: false);
  }

  // ── Selection helpers ────────────────────────────────────────────────

  List<LineItem> _selectedLineItems() {
    final out = <LineItem>[];
    // Mirror React's product fill: sale price (converted to the client's
    // currency when the company opts in and currencies differ), quantity per
    // the `enable_product_quantity` / `default_quantity` toggles. Rate is the
    // same for every product on this doc, so resolve it once.
    final company = _company;
    final clientCurrencyId = _client?.currencyId ?? '';
    final companyCurrencyId = company?.settings.currencyId ?? '';
    final productRate =
        (company?.convertProducts ?? false) &&
            clientCurrencyId.isNotEmpty &&
            companyCurrencyId.isNotEmpty &&
            clientCurrencyId != companyCurrencyId
        ? crossCurrencyRate(
            context.read<Services>().statics.currencies,
            fromExpenseCurrencyId: companyCurrencyId,
            toInvoiceCurrencyId: clientCurrencyId,
          )
        : null;
    // Iterate the retained selection map, NOT `_products` — a product picked
    // under a previous search term is no longer in the current `_products`
    // window but must still be materialized.
    for (final p in _selectedProductsById.values) {
      out.add(
        lineItemFromProduct(
          p,
          enableProductQuantity: company?.enableProductQuantity ?? false,
          defaultQuantity: company?.defaultQuantity ?? false,
          conversionRate: productRate,
        ),
      );
    }
    // Routed through the grouping builder, not per-task: it clusters the
    // picks by project and writes a project header onto the first line of
    // each run, which is the only way a shared invoice can say which project
    // a line belongs to (an invoice has one `project_id`, a line item none).
    out.addAll(
      tasksToLineItems(
        [
          for (final t in _tasks)
            if (_selTasks.contains(t.id)) t,
        ],
        projectsById: _projectsById,
        company: _company,
        formatter: widget.formatter,
        client: _client,
        group: _group,
        alreadyHeadedProjectIds: widget.headedProjectIds,
        hourLabel: context.tr('hour'),
        hoursLabel: context.tr('hours'),
        projectFieldLabel: context.tr('project'),
      ),
    );
    for (final e in _expenses) {
      if (_selExpenses.contains(e.id)) {
        out.add(
          expenseToLineItem(e, invoiceInclusive: widget.invoiceInclusive),
        );
      }
    }
    return out;
  }

  /// The project to adopt onto a project-less draft — only when the picks are
  /// unanimous. An invoice carries one `project_id`, so stamping it with the
  /// first of several picked projects would label the document with one
  /// project while it carries another's lines (the project headers in the
  /// line notes are what identify those). Matches the server, which leaves
  /// `project_id` null for a multi-project invoice.
  String _projectIdHint() {
    final picked = <String>{
      for (final t in _tasks)
        if (_selTasks.contains(t.id)) t.projectId,
    };
    if (picked.length != 1) return '';
    final only = picked.first;
    return only.isEmpty ? '' : only;
  }

  /// The tasks tab's rows, clustered by project so a whole project can be
  /// added in one tap. Ordered the way `tasksToLineItems` sorts (project,
  /// then chronologically), and project-less tasks come last under their own
  /// heading — they're the odd ones out, not the headline.
  List<_TaskGroup> get _taskGroups {
    final byProject = <String, List<Task>>{};
    for (final t in _filteredTasks) {
      byProject.putIfAbsent(t.projectId, () => <Task>[]).add(t);
    }
    final withProject = byProject.keys.where((id) => id.isNotEmpty).toList()
      ..sort((a, b) {
        final an = _projectNames[a] ?? a;
        final bn = _projectNames[b] ?? b;
        return an.toLowerCase().compareTo(bn.toLowerCase());
      });
    return [
      for (final id in withProject)
        _TaskGroup(
          projectId: id,
          // Falls back to the raw id only while the names stream is still
          // loading; rows render rather than disappear.
          name: _projectNames[id] ?? id,
          tasks: byProject[id]!,
        ),
      if (byProject.containsKey(''))
        _TaskGroup(projectId: '', name: '', tasks: byProject['']!),
    ];
  }

  /// Toggle every task in one project — the "add this project's tasks to the
  /// invoice I'm editing" gesture. Selects all when any are unselected,
  /// clears when they're already all selected.
  void _toggleProject(_TaskGroup group) {
    final ids = group.tasks.map((t) => t.id).toList();
    final allSelected = ids.every(_selTasks.contains);
    setState(() {
      if (allSelected) {
        _selTasks.removeAll(ids);
      } else {
        _selTasks.addAll(ids);
      }
    });
  }

  /// First non-empty `clientId` across picked tasks then expenses.
  /// Returned as `clientIdHint` so the invoke helper can auto-set the
  /// draft's `clientId` on a client-less doc — mirrors admin-portal's
  /// `invoice_edit_vm.dart:204-212` cascade.
  String _clientIdHint() {
    for (final t in _tasks) {
      if (_selTasks.contains(t.id) && t.clientId.isNotEmpty) {
        return t.clientId;
      }
    }
    for (final e in _expenses) {
      if (_selExpenses.contains(e.id) && e.clientId.isNotEmpty) {
        return e.clientId;
      }
    }
    return '';
  }

  /// `taskId → clientId` for every picked task whose source row carries
  /// a non-blank `clientId`. Passed back through `LineItemPickerResult`
  /// so the host VM can prime its cross-client validation cache without
  /// re-fetching from Drift.
  Map<String, String> _pickedTaskClientIds() {
    return {
      for (final t in _tasks)
        if (_selTasks.contains(t.id) && t.clientId.isNotEmpty) t.id: t.clientId,
    };
  }

  Map<String, String> _pickedExpenseClientIds() {
    return {
      for (final e in _expenses)
        if (_selExpenses.contains(e.id) && e.clientId.isNotEmpty)
          e.id: e.clientId,
    };
  }

  void _selectAllOnActiveTab() {
    setState(() {
      switch (_tabs[_tabCtl.index]) {
        case _TabKind.products:
          _selProducts.addAll(_products.map((p) => p.id));
          for (final p in _products) {
            _selectedProductsById[p.id] = p;
          }
          break;
        case _TabKind.tasks:
          _selTasks.addAll(_filteredTasks.map((t) => t.id));
          break;
        case _TabKind.expenses:
          _selExpenses.addAll(_filteredExpenses.map((e) => e.id));
          break;
      }
    });
  }

  void _clearActiveTab() {
    setState(() {
      switch (_tabs[_tabCtl.index]) {
        case _TabKind.products:
          _selProducts.clear();
          _selectedProductsById.clear();
          break;
        case _TabKind.tasks:
          _selTasks.clear();
          break;
        case _TabKind.expenses:
          _selExpenses.clear();
          break;
      }
    });
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final selected = _selectedLineItems();
    final count = selected.length;
    final total = selected.fold(Decimal.zero, (sum, li) => sum + li.gross);

    final maxHeight =
        widget.maxHeight ?? MediaQuery.of(context).size.height * 0.85;
    // Chrome envelope: header 56 + filter+padding ~76 + tabBar 48 +
    // dividers 3 + footer 76 ≈ 259. The tab toolbar (Select All / Clear All)
    // sits inside the active tab body and contributes another ~40. The
    // remaining slot is the list's available room — cap the ListView there
    // so it scrolls when content overflows and shrink-wraps when it doesn't.
    const chromeHeight = 300.0;
    final maxListHeight = (maxHeight - chromeHeight).clamp(
      120.0,
      double.infinity,
    );

    final activeTab = _tabs[_tabCtl.index.clamp(0, _tabs.length - 1)];

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(onClose: () => Navigator.of(context).pop(), tokens: tokens),
          Divider(height: 1, color: tokens.border),
          Padding(
            padding: EdgeInsets.fromLTRB(
              InSpacing.lg(context),
              InSpacing.md(context),
              InSpacing.lg(context),
              InSpacing.md(context),
            ),
            child: TextField(
              controller: _filterCtl,
              // Wide-window only: dialog opens with the filter focused so
              // the user can start typing to narrow the list immediately.
              // Skipped on mobile so the on-screen keyboard doesn't pop
              // up uninvited when the sheet slides into view.
              autofocus: MediaQuery.of(context).size.width >= 720,
              // Search queries are names and numbers, not prose — iOS
              // autocorrecting "Acme" to "Acne" mid-search is the failure.
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 20),
                hintText: context.tr('filter'),
                // `isDense: true` (was) → ~40 px tall, below the Material
                // 3 48 px touch-target. Explicit contentPadding gives a
                // ~52 px tap area without bloating the modal chrome.
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                border: const OutlineInputBorder(),
                suffixIcon: _filter.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => _filterCtl.clear(),
                      ),
              ),
            ),
          ),
          if (_tabs.length > 1) ...[
            _TabsBar(
              controller: _tabCtl,
              tabs: _tabs,
              counts: _tabCounts(),
              selectionDot: _tabSelectionDots(),
              tokens: tokens,
            ),
            Divider(height: 1, color: tokens.border),
          ],
          // Manual tab switcher — only the active tab's body is built. We
          // trade the horizontal-swipe gesture and slide animation of
          // `TabBarView` for the ability to shrink-wrap each tab's content
          // (PageView's bounded-axis requirement is incompatible with
          // size-to-content here). The `_tabCtl` listener already fires
          // `setState` on tab-index change, so the swap happens
          // automatically when the user taps a tab label.
          _tabBody(activeTab, maxListHeight),
          Divider(height: 1, color: tokens.border),
          _Footer(
            tokens: tokens,
            count: count,
            total: total,
            formatter: widget.formatter,
            onCancel: () => Navigator.of(context).pop(),
            onAdd: count == 0
                ? null
                : () => Navigator.of(context).pop(
                    LineItemPickerResult(
                      lineItems: selected,
                      projectIdHint: _projectIdHint(),
                      clientIdHint: _clientIdHint(),
                      pickedTaskClientIds: _pickedTaskClientIds(),
                      pickedExpenseClientIds: _pickedExpenseClientIds(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Map<_TabKind, int?> _tabCounts() {
    final f = _lower(_filter.trim());
    return {
      // Server-paged — total unknown without an extra count query.
      _TabKind.products: null,
      _TabKind.tasks: f.isEmpty
          ? _tasks.length
          : _tasks.where((t) => _taskMatches(t, f)).length,
      _TabKind.expenses: f.isEmpty
          ? _expenses.length
          : _expenses.where((e) => _expenseMatches(e, f)).length,
    };
  }

  Map<_TabKind, bool> _tabSelectionDots() => {
    _TabKind.products: _selProducts.isNotEmpty,
    _TabKind.tasks: _selTasks.isNotEmpty,
    _TabKind.expenses: _selExpenses.isNotEmpty,
  };

  Widget _tabBody(_TabKind kind, double maxListHeight) {
    switch (kind) {
      case _TabKind.products:
        return _ProductsTab(
          loading: _loadingProducts,
          products: _products,
          selected: _selProducts,
          filter: _filter,
          formatter: widget.formatter,
          showProductDetails: _company?.showProductDetails ?? false,
          showStock:
              widget.showStockQuantity && (_company?.trackInventory ?? false),
          maxListHeight: maxListHeight,
          onToggle: (id) => setState(() {
            if (_selProducts.add(id)) {
              // Newly selected — retain the resolved Product (it's in the
              // current `_products` window, since the user just tapped it).
              for (final p in _products) {
                if (p.id == id) {
                  _selectedProductsById[id] = p;
                  break;
                }
              }
            } else {
              _selProducts.remove(id);
              _selectedProductsById.remove(id);
            }
          }),
          onSelectAll: _selectAllOnActiveTab,
          onClearAll: _clearActiveTab,
        );
      case _TabKind.tasks:
        return _TasksTab(
          loading: _loadingTasksExpenses,
          failed: _failedTasksExpenses,
          groups: _taskGroups,
          anyTasks: _filteredTasks.isNotEmpty,
          totalUnfilteredEmpty: _tasks.isEmpty,
          selected: _selTasks,
          filter: _filter,
          formatter: widget.formatter,
          maxListHeight: maxListHeight,
          clientNames: _clientNames,
          onToggle: (id) => setState(() {
            if (!_selTasks.add(id)) _selTasks.remove(id);
          }),
          onToggleProject: _toggleProject,
          onSelectAll: _selectAllOnActiveTab,
          onClearAll: _clearActiveTab,
          onRetry: _retryTasksAndExpenses,
        );
      case _TabKind.expenses:
        return _ExpensesTab(
          loading: _loadingTasksExpenses,
          failed: _failedTasksExpenses,
          expenses: _filteredExpenses,
          totalUnfilteredEmpty: _expenses.isEmpty,
          selected: _selExpenses,
          filter: _filter,
          formatter: widget.formatter,
          maxListHeight: maxListHeight,
          vendorNames: _vendorNames,
          categoryNames: _categoryNames,
          onToggle: (id) => setState(() {
            if (!_selExpenses.add(id)) _selExpenses.remove(id);
          }),
          onSelectAll: _selectAllOnActiveTab,
          onClearAll: _clearActiveTab,
          onRetry: _retryTasksAndExpenses,
        );
    }
  }
}

enum _TabKind { products, tasks, expenses }

class _Header extends StatelessWidget {
  const _Header({required this.onClose, required this.tokens});
  final VoidCallback onClose;
  final InTheme tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        InSpacing.lg(context),
        InSpacing.md(context),
        InSpacing.md(context),
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.tr('add_items'),
              style: TextStyle(
                color: tokens.ink,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.close), onPressed: onClose),
        ],
      ),
    );
  }
}

class _TabsBar extends StatelessWidget {
  const _TabsBar({
    required this.controller,
    required this.tabs,
    required this.counts,
    required this.selectionDot,
    required this.tokens,
  });

  final TabController controller;
  final List<_TabKind> tabs;
  final Map<_TabKind, int?> counts;
  final Map<_TabKind, bool> selectionDot;
  final InTheme tokens;

  String _label(BuildContext context, _TabKind k) {
    final base = switch (k) {
      _TabKind.products => context.tr('products'),
      _TabKind.tasks => context.tr('tasks'),
      _TabKind.expenses => context.tr('expenses'),
    };
    final n = counts[k];
    return n == null ? base : '$base ($n)';
  }

  @override
  Widget build(BuildContext context) {
    // `isScrollable: false` so the (1, 2, or 3) tabs share the bar width
    // evenly instead of laying out at intrinsic width left-to-right —
    // on a narrow dialog the rightmost tab was previously clipped (no
    // visible scroll affordance). Wrap each label in `Flexible` so long
    // labels (e.g. "Expenses (123)") ellipsize within their slot rather
    // than pushing the trailing selection dot off-screen.
    return TabBar(
      controller: controller,
      isScrollable: false,
      labelColor: tokens.ink,
      unselectedLabelColor: tokens.ink3,
      tabs: [
        for (final k in tabs)
          Tab(
            // `Semantics(selected: …)` tells screen readers that the tab
            // has a pending selection (paired with the visible accent
            // dot for sighted users). The dot itself stays a plain
            // visual Container — no double-announce.
            child: Semantics(
              selected: selectionDot[k] ?? false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _label(context, k),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                  if (selectionDot[k] ?? false) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: tokens.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TabToolbar extends StatelessWidget {
  const _TabToolbar({
    required this.onSelectAll,
    required this.onClearAll,
    required this.canSelectAll,
    required this.canClear,
  });

  final VoidCallback onSelectAll;
  final VoidCallback onClearAll;
  final bool canSelectAll;
  final bool canClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.md(context),
        vertical: 4,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: canSelectAll ? onSelectAll : null,
            child: Text(context.tr('select_all')),
          ),
          TextButton(
            onPressed: canClear ? onClearAll : null,
            child: Text(context.tr('clear_all')),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.tokens,
    required this.count,
    required this.total,
    required this.formatter,
    required this.onCancel,
    required this.onAdd,
  });

  final InTheme tokens;
  final int count;
  final Decimal total;
  final Formatter? formatter;
  final VoidCallback onCancel;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    // Footer always shows a count — even at zero. An empty SizedBox here
    // left the footer visually lopsided before any picks; the muted
    // `0` reads as "intentional zero state, not a loading glitch".
    final String countText;
    if (count == 0) {
      countText = '0';
    } else if (formatter == null) {
      countText = '$count';
    } else {
      countText = '$count · ${formatter!.money(total)}';
    }
    return Padding(
      padding: EdgeInsets.all(InSpacing.lg(context)),
      child: Row(
        children: [
          Expanded(
            child: Text(
              countText,
              style: TextStyle(
                color: count == 0 ? tokens.ink3 : tokens.ink2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: onCancel,
            child: Text(context.tr('cancel')),
          ),
          SizedBox(width: InSpacing.md(context)),
          PrimaryDialogAction(
            label: context.tr('add'),
            onPressed: onAdd,
            // Search + multi-select tabs — no Enter hint.
            autofocus: false,
            showEnterHint: false,
          ),
        ],
      ),
    );
  }
}

// ── Per-tab bodies ─────────────────────────────────────────────────────

class _ProductsTab extends StatelessWidget {
  const _ProductsTab({
    required this.loading,
    required this.products,
    required this.selected,
    required this.filter,
    required this.formatter,
    required this.showProductDetails,
    required this.showStock,
    required this.maxListHeight,
    required this.onToggle,
    required this.onSelectAll,
    required this.onClearAll,
  });

  final bool loading;
  final List<Product> products;
  final Set<String> selected;
  final String filter;
  final Formatter? formatter;

  /// Company `show_product_details` — when false, the product description is
  /// hidden from each row (only the product key + price show).
  final bool showProductDetails;

  /// When true, render the bracketed in-stock count (`[N]`) on each row —
  /// already resolved to `company.trackInventory && docTypeIsInvoice`.
  final bool showStock;
  final double maxListHeight;
  final void Function(String id) onToggle;
  final VoidCallback onSelectAll;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    if (loading) return const _LoadingState();
    if (products.isEmpty) {
      return _EmptyState(filter: filter, unfilteredEmpty: true);
    }
    final f = formatter;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TabToolbar(
          onSelectAll: onSelectAll,
          onClearAll: onClearAll,
          canSelectAll: products.isNotEmpty,
          canClear: selected.isNotEmpty,
        ),
        // ConstrainedBox + shrink-wrap: list takes its intrinsic height up
        // to `maxListHeight`, then scrolls.
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxListHeight),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: products.length,
            itemBuilder: (context, i) {
              final p = products[i];
              // Reserved date keywords read as the dates they become, same as
              // the Products list (invoiceninja/flutter#93).
              final notesLine = p.notes.trim().isNotEmpty
                  ? expandDatePlaceholders(
                      p.notes.trim(),
                      formatter: formatter,
                    ).split('\n').first
                  : '';
              return InkWell(
                onTap: () => onToggle(p.id),
                child: CheckboxListTile(
                  dense: true,
                  value: selected.contains(p.id),
                  onChanged: (_) => onToggle(p.id),
                  title: _RowTitle(
                    left: p.productKey.trim().isNotEmpty
                        ? p.productKey
                        : context.tr('product'),
                    right: f == null ? '' : f.money(p.price),
                    stockQuantity: p.inStockQuantity,
                    showStock: showStock,
                  ),
                  subtitle: (!showProductDetails || notesLine.isEmpty)
                      ? null
                      : Text(
                          notesLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// One project's worth of pickable tasks. `projectId == ''` is the
/// no-project bucket, rendered last under its own heading.
class _TaskGroup {
  const _TaskGroup({
    required this.projectId,
    required this.name,
    required this.tasks,
  });

  final String projectId;
  final String name;
  final List<Task> tasks;
}

class _TasksTab extends StatelessWidget {
  const _TasksTab({
    required this.loading,
    required this.failed,
    required this.groups,
    required this.anyTasks,
    required this.totalUnfilteredEmpty,
    required this.selected,
    required this.filter,
    required this.formatter,
    required this.maxListHeight,
    required this.clientNames,
    required this.onToggle,
    required this.onToggleProject,
    required this.onSelectAll,
    required this.onClearAll,
    required this.onRetry,
  });

  final bool loading;
  final bool failed;

  /// Tasks clustered by project — the unit the user actually thinks in when
  /// billing a period ("add the Redesign work"), and the same clustering the
  /// generated line items use.
  final List<_TaskGroup> groups;
  final bool anyTasks;
  final bool totalUnfilteredEmpty;
  final Set<String> selected;
  final String filter;
  final Formatter? formatter;
  final double maxListHeight;
  final Map<String, String> clientNames;
  final void Function(String id) onToggle;
  final void Function(_TaskGroup group) onToggleProject;
  final VoidCallback onSelectAll;
  final VoidCallback onClearAll;
  final VoidCallback onRetry;

  String _title(BuildContext context, Task t) {
    if (t.description.trim().isNotEmpty) return t.description.trim();
    if (t.number.isNotEmpty) return '#${t.number}';
    return context.tr('task');
  }

  /// Right-column amount: `total` when the task has a rate; bare hours
  /// (e.g., "2.5h") otherwise so the column stays populated for tasks
  /// that aren't billed by rate.
  String _right(Task t) {
    final hours = taskBillableHours(t);
    final f = formatter;
    if (f == null || t.rate == Decimal.zero) return '${hours}h';
    return f.money(hours * t.rate);
  }

  /// One subtitle line: `{client} · {hours} × {rate}`. Each part skipped when
  /// empty / unresolved. The project is no longer repeated here — the section
  /// heading above the row carries it.
  String _subtitle(Task t) {
    final f = formatter;
    final hours = taskBillableHours(t);
    final parts = <String>[
      if (t.clientId.isNotEmpty) clientNames[t.clientId] ?? '',
      if (f != null && t.rate != Decimal.zero) '$hours × ${f.money(t.rate)}',
    ].where((s) => s.isNotEmpty).toList();
    return parts.join(' · ');
  }

  /// Flattened `[heading, …rows]` so one `ListView.builder` covers every
  /// group — nested scrollables inside a bounded modal don't lay out.
  List<Object> get _rows => [
    for (final g in groups) ...[g, ...g.tasks],
  ];

  @override
  Widget build(BuildContext context) {
    if (loading) return const _LoadingState();
    if (failed) return _FailedState(onRetry: onRetry);
    if (!anyTasks) {
      return _EmptyState(filter: filter, unfilteredEmpty: totalUnfilteredEmpty);
    }
    final rows = _rows;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TabToolbar(
          onSelectAll: onSelectAll,
          onClearAll: onClearAll,
          canSelectAll: anyTasks,
          canClear: selected.isNotEmpty,
        ),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxListHeight),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final row = rows[i];
              if (row is _TaskGroup) {
                return _ProjectHeadingRow(
                  group: row,
                  selected: selected,
                  onToggleProject: onToggleProject,
                  // Everything above the first heading is chrome, so it needs
                  // no rule of its own.
                  isFirst: i == 0,
                );
              }
              final t = row as Task;
              final subtitle = _subtitle(t);
              // `InkWell` wrapper gives the whole row a hover/press
              // ripple on desktop and one focusable target for
              // keyboard nav. CheckboxListTile's own `onChanged` still
              // fires so `Space` toggles when the row has focus.
              return InkWell(
                onTap: () => onToggle(t.id),
                child: CheckboxListTile(
                  dense: true,
                  value: selected.contains(t.id),
                  onChanged: (_) => onToggle(t.id),
                  title: _RowTitle(left: _title(context, t), right: _right(t)),
                  subtitle: subtitle.isEmpty
                      ? null
                      : Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Section heading for one project, with a tristate checkbox that adds or
/// clears that project's whole run in a tap — the direct answer to "put this
/// project's tasks on the invoice I'm editing".
class _ProjectHeadingRow extends StatelessWidget {
  const _ProjectHeadingRow({
    required this.group,
    required this.selected,
    required this.onToggleProject,
    required this.isFirst,
  });

  final _TaskGroup group;
  final Set<String> selected;
  final void Function(_TaskGroup group) onToggleProject;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final picked = group.tasks.where((t) => selected.contains(t.id)).length;
    final label = group.projectId.isEmpty
        ? context.tr('no_project')
        : group.name;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // A rule between runs — nothing else separates one project's tasks
        // from the next, and the type alone is too quiet to do it. Same idiom
        // as the line-item table, where dividers carry the rhythm.
        if (!isFirst) Divider(height: 1, color: tokens.border),
        // The same widget as the task rows below, with the same `dense` flag,
        // so the two checkboxes line up down the column by construction
        // instead of by a hand-tuned inset. (The hand-rolled `SizedBox(40)` it
        // replaces also clipped the checkbox on mobile, where
        // `materialTapTargetSize` is `padded` and lays it out at 48.)
        CheckboxListTile(
          dense: true,
          // Tristate reads as "some of this project is on the invoice", which
          // is exactly the state a partial pick leaves.
          tristate: true,
          value: picked == group.tasks.length
              ? true
              : (picked == 0 ? false : null),
          onChanged: (_) => onToggleProject(group),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.ink2,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${group.tasks.length}',
                style: TextStyle(color: tokens.ink3, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExpensesTab extends StatelessWidget {
  const _ExpensesTab({
    required this.loading,
    required this.failed,
    required this.expenses,
    required this.totalUnfilteredEmpty,
    required this.selected,
    required this.filter,
    required this.formatter,
    required this.maxListHeight,
    required this.vendorNames,
    required this.categoryNames,
    required this.onToggle,
    required this.onSelectAll,
    required this.onClearAll,
    required this.onRetry,
  });

  final bool loading;
  final bool failed;
  final List<Expense> expenses;
  final bool totalUnfilteredEmpty;
  final Set<String> selected;
  final String filter;
  final Formatter? formatter;
  final double maxListHeight;
  final Map<String, String> vendorNames;
  final Map<String, String> categoryNames;
  final void Function(String id) onToggle;
  final VoidCallback onSelectAll;
  final VoidCallback onClearAll;
  final VoidCallback onRetry;

  /// Title fallback chain: public notes → vendor name → `#number` →
  /// localized "expense". Adding vendor here is the key change — many
  /// expenses don't carry public notes, and "Office Depot" reads far
  /// better than "#1234" or "expense".
  String _title(BuildContext context, Expense e) {
    if (e.publicNotes.trim().isNotEmpty) return e.publicNotes.trim();
    final vendor = vendorNames[e.vendorId];
    if (vendor != null && vendor.isNotEmpty) return vendor;
    if (e.number.isNotEmpty) return '#${e.number}';
    return context.tr('expense');
  }

  /// One subtitle line: `{date} · {category}`. Both parts skipped when
  /// empty; whole subtitle is null if nothing's available (CheckboxListTile
  /// then collapses to a single-line row).
  String _subtitle(Expense e) {
    final f = formatter;
    final parts = <String>[
      if (e.date != null) f?.date(e.date!.toIso()) ?? '',
      if (e.categoryId.isNotEmpty) categoryNames[e.categoryId] ?? '',
    ].where((s) => s.isNotEmpty).toList();
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const _LoadingState();
    if (failed) return _FailedState(onRetry: onRetry);
    if (expenses.isEmpty) {
      return _EmptyState(filter: filter, unfilteredEmpty: totalUnfilteredEmpty);
    }
    final f = formatter;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TabToolbar(
          onSelectAll: onSelectAll,
          onClearAll: onClearAll,
          canSelectAll: expenses.isNotEmpty,
          canClear: selected.isNotEmpty,
        ),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxListHeight),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: expenses.length,
            itemBuilder: (context, i) {
              final e = expenses[i];
              final subtitle = _subtitle(e);
              return InkWell(
                onTap: () => onToggle(e.id),
                child: CheckboxListTile(
                  dense: true,
                  value: selected.contains(e.id),
                  onChanged: (_) => onToggle(e.id),
                  title: _RowTitle(
                    left: _title(context, e),
                    right: f == null ? '' : f.money(e.amount),
                  ),
                  subtitle: subtitle.isEmpty
                      ? null
                      : Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Row title widget shared across all three tabs: identifier on the left
/// (Expanded so it ellipsizes when narrow), monospaced amount on the
/// right (tabular figures so amounts down the column align by decimal
/// point — same numeric typography as the desktop edit table at
/// `line_item_card_list_mobile.dart:223`).
///
/// Force `TextDirection.ltr` inside the Row so the amount stays on the
/// right edge in RTL locales (Arabic, Hebrew). Tabular numeric columns
/// are read LTR universally even in RTL UIs — matches how iOS / Material
/// money cells behave in their own list patterns.
class _RowTitle extends StatelessWidget {
  const _RowTitle({
    required this.left,
    required this.right,
    this.stockQuantity,
    this.showStock = false,
  });
  final String left;
  final String right;

  /// In-stock count rendered as `[N]` between the title and the trailing
  /// price — products only; null / `showStock: false` on task & expense rows.
  final Decimal? stockQuantity;
  final bool showStock;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    left,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (showStock && stockQuantity != null)
                  ProductStockLabel(quantity: stockQuantity!, show: true),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            right,
            style: moneyTextStyle(
              color: tokens.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 48),
    child: Center(child: CircularProgressIndicator()),
  );
}

class _FailedState extends StatelessWidget {
  const _FailedState({this.onRetry});
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr('an_error_occurred'),
              style: TextStyle(color: tokens.ink3),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 40),
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(context.tr('retry')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter, required this.unfilteredEmpty});

  /// Current shared filter text (possibly empty).
  final String filter;

  /// True when the underlying list itself is empty (vs. filter-excluded).
  final bool unfilteredEmpty;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final trimmed = filter.trim();
    final message = (!unfilteredEmpty && trimmed.isNotEmpty)
        // Param keys carry no leading colon — `lookup` prefixes one itself,
        // so `':filter'` produced `::filter` and never substituted.
        ? context.tr('no_matches_for_filter', {'filter': trimmed})
        : context.tr('no_records_found');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: Text(message, style: TextStyle(color: tokens.ink3)),
      ),
    );
  }
}
