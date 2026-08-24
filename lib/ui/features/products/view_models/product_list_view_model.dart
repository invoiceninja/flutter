import 'dart:async';

import 'package:admin/data/db/dao/product_dao.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_custom_fields.dart';
import 'package:admin/data/models/domain/product.dart';
import 'package:admin/data/models/domain/tag.dart';
import 'package:admin/data/repositories/product_repository.dart';
import 'package:admin/data/repositories/tag_denormalization.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/columns/product_columns.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/combine_latest.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/standard_crud_bulk_actions.dart';
import 'package:admin/ui/features/products/stock_filter_key.dart';

/// Grouping id for "group by tag". The other ids are the custom-value column
/// ids ([ProductFieldIds.custom1] … `custom4`), which the DAO can group in
/// SQL; tags live in the payload blob and are grouped in Dart below.
const String kProductGroupTags = 'tags';

/// List ViewModel for the Products screen. Plugs the [GenericListViewModel]
/// base into [ProductRepository] + the product column registry.
class ProductListViewModel extends GenericListViewModel<Product> {
  ProductListViewModel({
    required this.repo,
    required Stream<Company?> companyStream,
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
    this.tagStream,
    super.savedViews,
    super.searchDebounce,
    super.persistDebounce,
    super.now,
  }) {
    _companySub = companyStream.listen(_onCompany);
  }

  final ProductRepository repo;

  /// Builds a fresh stream of the company's product tags, used to name tag
  /// groups. A **factory**, not a stream: [watchPage] folds it into the page
  /// stream and is re-invoked on every re-subscribe, and a Drift
  /// `.watch().map(...)` that has already been listened to can't be relied on
  /// to re-emit for a second listener. Null = the tags dimension isn't offered.
  final Stream<List<Tag>> Function()? tagStream;

  late final StreamSubscription<Company?> _companySub;
  Company? _company;
  bool _trackInventory = false;
  int _companyThreshold = 0;

  /// Tag id → name, for the group label. Archived tags included so a row
  /// carrying one still lands in a named group rather than Uncategorized.
  Map<String, String> _tagNames = const {};

  /// Group label per row index, parallel to [items]. Empty when the list
  /// isn't grouped. Recomputed in [watchPage]'s map, i.e. in the same
  /// synchronous step that produces the list the base then assigns, so the
  /// two can never disagree.
  List<String> _rowGroupLabels = const [];

  /// Loaded-row count per group label. Under-reports until paging catches
  /// up — same caveat as the sidebar count badges.
  Map<String, int> _groupCounts = const {};

  /// Whether the active company tracks inventory (live, from the company
  /// stream). Drives the per-row low/out highlight via `InventoryScope` and
  /// gates the on-hand-stock cell styling.
  bool get trackInventory => _trackInventory;

  /// Company-level low-stock threshold fallback (live). Used by the low-stock
  /// filter's cascade when a product carries no threshold of its own.
  int get inventoryThreshold => _companyThreshold;

  /// Everything about the company that the grouping UI reads: the four slot
  /// labels (menu entries + the desktop button's caption) and whether the
  /// active choice still resolves. Compared in [_onCompany] so renaming or
  /// un-configuring a slot repaints.
  String get _groupingSignature {
    final company = _company;
    return [
      effectiveGroupField ?? '',
      for (var i = 1; i <= 4; i++) company?.customFieldLabel('product$i') ?? '',
    ].join('\u0000');
  }

  void _onCompany(Company? company) {
    final before = _groupingSignature;
    _company = company;
    // The custom-field config drives which dimensions are offered, what they
    // are called, and whether the persisted choice is still effective — none
    // of which the inventory early-return below would repaint.
    if (_groupingSignature != before) notifyListeners();
    final track = company?.trackInventory ?? false;
    final threshold = company?.inventoryNotificationThreshold ?? 0;
    if (track == _trackInventory && threshold == _companyThreshold) return;
    _trackInventory = track;
    _companyThreshold = threshold;
    // Re-render so the highlight (InventoryScope reads [trackInventory] /
    // [inventoryThreshold]) updates. The filtered SET re-applies the new
    // threshold on the next Drift emit (e.g. the initial page fetch's upsert,
    // which lands after this stream has resolved).
    notifyListeners();
  }

  @override
  EntityType get entityType => EntityType.product;

  @override
  List<ColumnDefinition<Product>> get allColumns => kAllProductColumns;

  @override
  List<String> get defaultColumnIds => kDefaultProductColumns;

  @override
  String get defaultSortField => ProductFieldIds.productKey;

  @override
  bool isValidColumnId(String field) =>
      isSortableColumnId(productColumnsById, field);

  @override
  String idOf(Product item) => item.id;

  @override
  bool isArchived(Product item) => item.archivedAt != null;

  @override
  bool isDeleted(Product item) => item.isDeleted;

  @override
  Stream<List<Product>> watchPage() {
    final base = repo.watchPage(
      companyId: companyId,
      loadedPages: loadedPages,
      search: search.isEmpty ? null : search,
      states: states,
      sortField: sortField,
      sortAscending: sortAscending,
      customFilters: customFilters,
      // Custom-value grouping is a SQL ORDER BY prefix so groups stay
      // contiguous across the paged window; `tags` isn't a column, so the
      // DAO ignores it and the regroup happens below.
      groupField: effectiveGroupField,
    );
    final tagsOf = tagStream;
    // Grouping by tag needs tag NAMES, which live in a different table — so a
    // tag write doesn't invalidate the products query and `notifyListeners()`
    // can't re-run this map. Fold the tag stream in instead, the same way
    // `CompanyGatewayListViewModel.watchPage` folds in the company: the first
    // emission then already carries the names (no cold-start window where
    // every row resolves to Uncategorized), and a rename re-emits.
    //
    // Built HERE, per call: this runs again on every re-subscribe, and a Drift
    // `.watch().map(...)` already listened to can't be relied on to re-emit
    // for a second listener. [combineLatest2] waits for both sides, so a
    // silent source would strand the whole list empty.
    if (effectiveGroupField != kProductGroupTags || tagsOf == null) {
      return base.map(_postProcess);
    }
    return combineLatest2<List<Product>, List<Tag>, List<Product>>(
      base,
      tagsOf(),
      (products, tags) {
        _tagNames = {for (final t in tags) t.id: t.name};
        return _postProcess(products);
      },
    );
  }

  List<Product> _postProcess(List<Product> products) {
    var result = products;
    // Both live in the product payload rather than a physical column, so
    // both are post-decode predicates — never SQL WHEREs. The difference:
    // `tag_ids` is ALSO sent to the server (`QueryFilters::tag_ids`), so it
    // narrows the fetch and this predicate only has to keep the local view
    // in step; `in_stock_quantity` has no server dimension at all, so it's
    // bounded by the loaded window and drives the auto-chain (see
    // localOnlyFilterActive).
    final tagIds = extraFilters['tag_ids'] ?? const <String>{};
    if (tagIds.isNotEmpty) {
      result = result
          .where((p) => matchesTagIdFilter(p.tagIds, tagIds))
          .toList(growable: false);
    }
    // Read the stock filter + threshold per-emit so a Drift re-emit
    // re-filters with the current company threshold.
    final filter = _stockFilter;
    if (filter != StockFilter.none) {
      result = result
          .where(
            (p) => stockFilterMatches(
              p,
              filter,
              companyThreshold: _companyThreshold,
            ),
          )
          .toList(growable: false);
    }
    if (effectiveGroupField == kProductGroupTags) {
      result = _regroupByTag(result);
    }
    _recomputeGroups(result);
    return result;
  }

  /// Re-order the loaded window so rows sharing a tag are contiguous,
  /// untagged last. Tags live in the payload blob rather than a column, so
  /// unlike custom-value grouping this can only order what's already loaded —
  /// groups fill in as further pages arrive (same class of local-window
  /// limitation as the `stock:` filter).
  ///
  /// Decorate-sort on `(label, originalIndex)` because `List.sort` is NOT
  /// stable: comparing the original index preserves the DAO's within-group
  /// ordering (the user's chosen sort column).
  List<Product> _regroupByTag(List<Product> rows) {
    final decorated =
        <({int i, String label, Product p})>[
          for (var i = 0; i < rows.length; i++)
            (i: i, label: _tagGroupLabel(rows[i]), p: rows[i]),
        ]..sort((a, b) {
          // Untagged sorts last, matching the SQL grouping's empty-last rule.
          if (a.label.isEmpty != b.label.isEmpty) {
            return a.label.isEmpty ? 1 : -1;
          }
          final byName = a.label.toLowerCase().compareTo(b.label.toLowerCase());
          if (byName != 0) return byName;
          // Exact-label tiebreak BEFORE the index one. Without it "Alpha" vs
          // "alpha" compares equal here while two same-cased rows still compare by
          // index, which is an inconsistent comparator (cmp(A,a)==0, cmp(a,A')==0,
          // cmp(A,A')==-1). `List.sort` is then free to interleave the two
          // spellings into alternating headers.
          final byExact = a.label.compareTo(b.label);
          if (byExact != 0) return byExact;
          return a.i.compareTo(b.i);
        });
    return [for (final d in decorated) d.p];
  }

  /// The row's tag group: its first tag name alphabetically. A product can
  /// carry several tags, but `items` is a flat list the view indexes into
  /// (row keys, multiselect, keyboard stepping), so a row can't be repeated
  /// under each one — first-alphabetically is at least deterministic.
  String _tagGroupLabel(Product p) {
    final names = <String>[
      for (final id in p.tagIds)
        if ((_tagNames[id] ?? '').isNotEmpty) _tagNames[id]!,
    ]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names.isEmpty ? '' : names.first;
  }

  /// The group a row belongs to, or `''` for "no value" — which the view
  /// renders as the localized *Uncategorized*. Deliberately NOT localized
  /// here: `''` is what lands in the persisted collapsed set, so folding a
  /// group survives a language change.
  String _groupLabelOf(Product p) => switch (effectiveGroupField) {
    ProductFieldIds.custom1 => p.customValue1,
    ProductFieldIds.custom2 => p.customValue2,
    ProductFieldIds.custom3 => p.customValue3,
    ProductFieldIds.custom4 => p.customValue4,
    kProductGroupTags => _tagGroupLabel(p),
    _ => '',
  };

  void _recomputeGroups(List<Product> rows) {
    if (effectiveGroupField == null) {
      _rowGroupLabels = const [];
      _groupCounts = const {};
      return;
    }
    final labels = <String>[for (final p in rows) _groupLabelOf(p)];
    final counts = <String, int>{};
    for (final l in labels) {
      counts[l] = (counts[l] ?? 0) + 1;
    }
    _rowGroupLabels = labels;
    _groupCounts = counts;
  }

  /// Stock is filtered post-decode over the loaded window, so a short
  /// filtered result must auto-chain page fetches (see the base class) —
  /// otherwise `stock:low` with no match in the first 50 rows renders a
  /// false "No records found" that can never scroll itself out.
  @override
  bool get localOnlyFilterActive =>
      _stockFilter != StockFilter.none || super.localOnlyFilterActive;

  @override
  int get pageSize => repo.pageSize;

  /// Parse the local `stock` extra-filter slot into a [StockFilter]. `out`
  /// wins over `low` if both are somehow present (out is the stricter set).
  StockFilter get _stockFilter {
    final values = extraFilters[StockFilterKey.serverKey] ?? const <String>{};
    if (values.contains(StockFilterKey.out)) return StockFilter.out;
    if (values.contains(StockFilterKey.low)) return StockFilter.low;
    return StockFilter.none;
  }

  @override
  Future<bool> fetchPage({
    required int page,
    required String? search,
    required Set<EntityState> states,
    required Map<String, Set<String>> extraFilters,
    required bool ignoreCursor,
  }) {
    // `stock` is a LOCAL filter — the server has no such dimension, so it must
    // not reach the fetch; the local watch re-applies it post-decode in
    // [watchPage]. `tag_ids` DOES have a server dimension and is passed through.
    final serverFilters = GenericListViewModel.extraFiltersWithout(
      extraFilters,
      StockFilterKey.serverKey,
    );
    return repo.ensurePageLoaded(
      companyId: companyId,
      page: page,
      search: search,
      states: states,
      extraFilters: serverFilters,
      ignoreCursor: ignoreCursor,
    );
  }

  @override
  Future<void> refreshAll() => repo.refreshAll(companyId: companyId);

  @override
  Iterable<BulkAction<Product>> get bulkActions => standardCrudBulkActions(
    isArchived: isArchived,
    isDeleted: isDeleted,
    archive: (id) => repo.archive(companyId: companyId, id: id),
    restore: (id) => repo.restore(companyId: companyId, id: id),
    delete: (id) => repo.delete(companyId: companyId, id: id),
  );

  @override
  void dispose() {
    _companySub.cancel();
    super.dispose();
  }

  // ── Grouping ────────────────────────────────────────────────────────

  @override
  Future<void> setGroupField(String? field) {
    // Drop the old dimension's labels up front. The base notifies before the
    // re-subscribed stream delivers, so without this the list paints one frame
    // of the previous dimension's headers over the new grouping.
    if (field != groupField) {
      _rowGroupLabels = const [];
      _groupCounts = const {};
    }
    return super.setGroupField(field);
  }

  @override
  bool isRowHidden(int index) =>
      index >= 0 &&
      index < _rowGroupLabels.length &&
      isGroupCollapsed(_rowGroupLabels[index]);

  @override
  bool get hasHiddenRows =>
      effectiveGroupField != null && collapsedGroups.isNotEmpty;

  /// Whether row [index] is the first of its group, i.e. the row the section
  /// header sits above. O(1) — the labels were resolved once per emission.
  bool isGroupStart(int index) {
    if (index < 0 || index >= _rowGroupLabels.length) return false;
    if (index == 0) return true;
    return _rowGroupLabels[index] != _rowGroupLabels[index - 1];
  }

  /// Raw group label for row [index]; `''` means "no value" and the view
  /// renders it as the localized *Uncategorized*.
  String groupLabelAt(int index) => index >= 0 && index < _rowGroupLabels.length
      ? _rowGroupLabels[index]
      : '';

  /// Loaded-row count for a group label (see [_groupCounts] on accuracy).
  int groupCount(String label) => _groupCounts[label] ?? 0;

  /// The grouping actually in force. [groupField] is what the user picked and
  /// what stays persisted; this is what the list renders by.
  ///
  /// A choice stops resolving when the company un-configures that custom-field
  /// slot, or when a persisted blob names an id this build doesn't know.
  /// Rendering it anyway would collapse the list into one nameless group.
  ///
  /// Deliberately a *derived read* rather than clearing [groupField]: an empty
  /// `custom_fields` map is also what `CompanyRepository.applyUpdateResponse`
  /// writes when a company response merely omits the key, so clearing would
  /// destroy the user's preference on a signal we can't trust. Same
  /// non-destructive shape as `CustomFieldFilterKey.tokensFrom`, which hides an
  /// orphaned chip while retaining its state so it re-paints if the label
  /// comes back.
  String? get effectiveGroupField {
    final id = groupField;
    if (id == null) return null;
    if (id == kProductGroupTags) return tagStream == null ? null : id;
    final slot = _slotOf(id);
    if (slot == null) return null;
    return (_company?.customFieldLabel('product$slot') ?? '').isEmpty
        ? null
        : id;
  }

  /// Grouping dimensions worth offering: a custom-field slot the company has
  /// both configured *and* populated, plus tags once some loaded row carries
  /// one — a dimension with no data renders one nameless group.
  ///
  /// The dimension currently in force is ALWAYS included, even after its data
  /// filters out of the loaded window. Otherwise the control hides itself while
  /// the list is still grouped, leaving no way to switch it off (both surfaces
  /// hide on an empty list). Same "keep the committed value reachable" rule the
  /// searchable pickers follow.
  List<String> get availableGroupFieldIds {
    final company = _company;
    final ids = <String>[
      for (var i = 1; i <= 4; i++)
        if (company != null &&
            company.customFieldLabel('product$i').isNotEmpty &&
            distinctCustomValues(i).isNotEmpty)
          _customGroupId(i),
      if (tagStream != null && items.any((p) => p.tagIds.isNotEmpty))
        kProductGroupTags,
    ];
    final active = effectiveGroupField;
    if (active != null && !ids.contains(active)) ids.add(active);
    return ids;
  }

  /// The company's own label for a custom-slot grouping id (`Category`, …).
  /// Empty for [kProductGroupTags], which the view localizes itself.
  String groupFieldLabel(String id) {
    final slot = _slotOf(id);
    if (slot == null) return '';
    return _company?.customFieldLabel('product$slot') ?? '';
  }

  static String _customGroupId(int slot) => switch (slot) {
    1 => ProductFieldIds.custom1,
    2 => ProductFieldIds.custom2,
    3 => ProductFieldIds.custom3,
    _ => ProductFieldIds.custom4,
  };

  static int? _slotOf(String id) => switch (id) {
    ProductFieldIds.custom1 => 1,
    ProductFieldIds.custom2 => 2,
    ProductFieldIds.custom3 => 3,
    ProductFieldIds.custom4 => 4,
    _ => null,
  };

  /// Distinct populated values per custom column. Feeds both the `custom1:`…
  /// `custom4:` filter tokens' suggestions and [availableGroupFieldIds] — the
  /// base caches this behind the synchronous `distinctCustomValues`.
  @override
  Stream<List<String>> watchDistinctCustomValues(int columnIndex) =>
      repo.watchDistinctCustomValues(
        companyId: companyId,
        columnIndex: columnIndex,
      );
}
