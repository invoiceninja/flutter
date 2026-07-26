// Smoke test for `GenericListViewModel<T>`. Confirms the foundation holds:
// a brand-new entity (Invoice here is a fake stand-in) can plug into the
// generic stack with only an entity-specific subclass — no changes to the
// base, the column system, or the filter/sort/multiselect machinery. If
// adding entity #2 requires touching the base, this test fails.
//
// Total entity-specific code measured by line count below; if it grows
// past ~200, the generics aren't pulling their weight.

import 'dart:async';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeInvoice {
  const FakeInvoice({
    required this.id,
    required this.number,
    required this.amount,
    this.archived = false,
    this.deleted = false,
  });

  final String id;
  final String number;
  final double amount;
  final bool archived;
  final bool deleted;
}

final _kAllColumns = <ColumnDefinition<FakeInvoice>>[
  ColumnDefinition(
    id: 'number',
    labelKey: 'number',
    cellBuilder: (i, _) => Text(i.number),
  ),
  ColumnDefinition(
    id: 'amount',
    labelKey: 'amount',
    cellBuilder: (i, _) => Text(i.amount.toString()),
  ),
  // Display-only: renders from the payload, has no column to ORDER BY.
  ColumnDefinition(
    id: 'tags',
    labelKey: 'tags',
    sortable: false,
    cellBuilder: (i, _) => const Text(''),
  ),
];

class FakeInvoiceListViewModel extends GenericListViewModel<FakeInvoice> {
  FakeInvoiceListViewModel({
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
    super.searchDebounce,
    super.persistDebounce,
  });

  final List<FakeInvoice> _stub = const [
    FakeInvoice(id: 'inv_1', number: 'INV-001', amount: 100),
    FakeInvoice(id: 'inv_2', number: 'INV-002', amount: 200, archived: true),
  ];

  int archiveCalls = 0;
  int fetchPageCalls = 0;

  @override
  EntityType get entityType => EntityType.invoice;

  @override
  List<ColumnDefinition<FakeInvoice>> get allColumns => _kAllColumns;

  @override
  List<String> get defaultColumnIds => const ['number', 'amount'];

  @override
  String get defaultSortField => 'number';

  @override
  bool isValidColumnId(String field) =>
      _kAllColumns.any((c) => c.id == field && c.sortable);

  @override
  String idOf(FakeInvoice item) => item.id;

  @override
  bool isArchived(FakeInvoice item) => item.archived;

  @override
  bool isDeleted(FakeInvoice item) => item.deleted;

  @override
  Stream<List<FakeInvoice>> watchPage() => Stream.value(_stub);

  @override
  Future<bool> fetchPage({
    required int page,
    required String? search,
    required Set<EntityState> states,
    required Map<String, Set<String>> extraFilters,
    required bool ignoreCursor,
  }) async {
    fetchPageCalls++;
    return false;
  }

  @override
  Future<void> refreshAll() async {}

  @override
  Stream<List<String>> watchDistinctCustomValues(int columnIndex) =>
      const Stream.empty();

  @override
  Iterable<BulkAction<FakeInvoice>> get bulkActions => [
    BulkAction<FakeInvoice>(
      id: 'archive',
      labelKey: 'archive',
      eligible: (i) => !i.archived && !i.deleted,
      apply: (id) async => archiveCalls++,
    ),
  ];
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test(
    'generic stack carries a brand-new entity without touching the base',
    () async {
      final vm = FakeInvoiceListViewModel(
        companyId: 'co',
        navStateDao: db.navStateDao,
        userSettings: UserSettingsRepository(db: db),
        searchDebounce: const Duration(milliseconds: 1),
        persistDebounce: const Duration(milliseconds: 1),
      );
      await settle();

      // Drift watch streamed the stub through the generic _onItems handler.
      expect(vm.items.map((i) => i.id), ['inv_1', 'inv_2']);
      expect(vm.columns.map((c) => c.id), ['number', 'amount']);
      expect(vm.sortField, 'number');
      expect(vm.states, {EntityState.active});

      // Filter mutations work through the base unchanged.
      await vm.setSort(field: 'amount', ascending: false);
      expect(vm.sortField, 'amount');
      expect(vm.sortAscending, isFalse);
      expect(
        vm.hasActiveFilters,
        isFalse,
        reason: 'sort is not a filter — a sort-only change must not count',
      );

      // Bulk action declared in the registry is callable through the base.
      vm.toggleSelected('inv_1');
      vm.toggleSelected('inv_2');
      final result = await vm.applyBulkAction(vm.bulkActionById('archive')!);
      expect(result.ok, 1, reason: 'inv_1 is eligible, inv_2 already archived');
      expect(result.skipped, 1);
      expect(vm.archiveCalls, 1);
      expect(vm.isInMultiselect, isFalse, reason: 'selection cleared on exit');

      vm.dispose();
    },
  );

  test('enterSelectionMode latches multiselect with nothing selected; '
      'clearSelection exits', () async {
    final vm = FakeInvoiceListViewModel(
      companyId: 'co',
      navStateDao: db.navStateDao,
      userSettings: UserSettingsRepository(db: db),
      searchDebounce: const Duration(milliseconds: 1),
      persistDebounce: const Duration(milliseconds: 1),
    );
    await settle();

    // The mobile "Select" button entry point: selection mode is on even
    // though no row is selected yet. (Previously impossible —
    // isInMultiselect was purely _selectedIds-derived, so the checkboxes
    // only appeared after a long-press had already selected something.)
    expect(vm.isInMultiselect, isFalse);
    vm.enterSelectionMode();
    expect(vm.isInMultiselect, isTrue);
    expect(vm.countSelected, 0);

    // Picking rows works on top of the latch.
    vm.toggleSelected('inv_1');
    expect(vm.countSelected, 1);

    // The X / Cancel exits even though the latch is set.
    vm.clearSelection();
    expect(vm.isInMultiselect, isFalse);
    expect(vm.countSelected, 0);

    vm.dispose();
  });

  test('a filter reload exits an empty (latched) selection mode', () async {
    final vm = FakeInvoiceListViewModel(
      companyId: 'co',
      navStateDao: db.navStateDao,
      userSettings: UserSettingsRepository(db: db),
      searchDebounce: const Duration(milliseconds: 1),
      persistDebounce: const Duration(milliseconds: 1),
    );
    await settle();
    vm.enterSelectionMode();
    expect(vm.isInMultiselect, isTrue);

    // Changing a filter reloads the list (_resetAndReload); the latch must
    // not survive it, or the user lands back on the list still "selecting"
    // with the FAB hidden and the selection AppBar stuck up.
    await vm.setStates({EntityState.archived});
    await settle();
    expect(vm.isInMultiselect, isFalse);

    vm.dispose();
  });

  test(
    'countEligibleSelected counts only selected, loaded, eligible rows',
    () async {
      final vm = FakeInvoiceListViewModel(
        companyId: 'co',
        navStateDao: db.navStateDao,
        userSettings: UserSettingsRepository(db: db),
        searchDebounce: const Duration(milliseconds: 1),
        persistDebounce: const Duration(milliseconds: 1),
      );
      await settle();
      final archive = vm.bulkActionById('archive')!;

      // Nothing selected → 0 (the scaffold short-circuits the prep dialog).
      expect(vm.countEligibleSelected(archive), 0);

      // inv_2 is already archived → ineligible for 'archive'.
      vm.toggleSelected('inv_2');
      expect(vm.countEligibleSelected(archive), 0);

      // inv_1 is active → the only eligible one in the selection.
      vm.toggleSelected('inv_1');
      expect(vm.countEligibleSelected(archive), 1);

      // An id outside the loaded window isn't counted.
      vm.toggleSelected('inv_999');
      expect(vm.countEligibleSelected(archive), 1);

      vm.dispose();
    },
  );

  // Every column header is a sort control, and a DAO throws `ArgumentError`
  // on a sort field it has no expression for — which cancels the watch
  // subscription and leaves the list frozen (search and filters silently stop
  // working). `isValidColumnId` is the shared gate for all three ways a sort
  // field is set, so a display-only column must be rejected by every one.
  test('a display-only column can never become the sort field', () async {
    final vm = FakeInvoiceListViewModel(
      companyId: 'co',
      navStateDao: db.navStateDao,
      userSettings: UserSettingsRepository(db: db),
      searchDebounce: const Duration(milliseconds: 1),
      persistDebounce: const Duration(milliseconds: 1),
    );
    await settle();
    final original = vm.sortField;

    await vm.setSort(field: 'tags', ascending: true);
    expect(
      vm.sortField,
      original,
      reason: 'setSort must reject a non-sortable column',
    );

    // A sortable column still works, so the gate isn't just refusing everything.
    await vm.setSort(field: 'amount', ascending: true);
    expect(vm.sortField, 'amount');
    vm.dispose();
  });

  test('a persisted display-only sort field is not restored', () async {
    // A blob written before the column was marked display-only (or by a build
    // that let the header set it) must not come back and re-break the list.
    await db.navStateDao.saveFilters(
      filtersJson:
          '{"co":{"invoice":{"search":"","states":["active"],'
          '"sortField":"tags","sortAscending":true,"customFilters":{}}}}',
      now: DateTime.now().millisecondsSinceEpoch,
    );
    final vm = FakeInvoiceListViewModel(
      companyId: 'co',
      navStateDao: db.navStateDao,
      userSettings: UserSettingsRepository(db: db),
      searchDebounce: const Duration(milliseconds: 1),
      persistDebounce: const Duration(milliseconds: 1),
    );
    await settle();
    expect(vm.sortField, isNot('tags'));
    vm.dispose();
  });

  test('persisted filter blob is keyed by entity type', () async {
    final vm = FakeInvoiceListViewModel(
      companyId: 'co',
      navStateDao: db.navStateDao,
      userSettings: UserSettingsRepository(db: db),
      searchDebounce: const Duration(milliseconds: 1),
      persistDebounce: const Duration(milliseconds: 1),
    );
    await settle();
    await vm.setStates({EntityState.archived});
    // Past the persist debounce.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await settle();
    vm.dispose();

    final row = await db.navStateDao.current();
    expect(row?.filtersJson, isNotNull);
    expect(
      row!.filtersJson!.contains('"invoice"'),
      isTrue,
      reason: 'persisted under EntityType.invoice.name, not "client"',
    );
    expect(
      row.filtersJson!.contains('"client"'),
      isFalse,
      reason: 'invoice and client occupy separate sub-keys',
    );
  });

  test(
    'extraFilters flow through hasActiveFilters and clearAllFilters',
    () async {
      final vm = FakeInvoiceListViewModel(
        companyId: 'co',
        navStateDao: db.navStateDao,
        userSettings: UserSettingsRepository(db: db),
        searchDebounce: const Duration(milliseconds: 1),
        persistDebounce: const Duration(milliseconds: 1),
      );
      await settle();
      expect(vm.hasActiveFilters, isFalse);

      await vm.setExtraFilter(serverKey: 'country_id', values: {'840'});
      expect(vm.hasActiveFilters, isTrue);
      expect(vm.extraFilters['country_id'], {'840'});

      // Empty set removes the entry entirely so the API call drops the key.
      await vm.setExtraFilter(serverKey: 'country_id', values: const {});
      expect(vm.extraFilters.containsKey('country_id'), isFalse);

      await vm.setExtraFilter(serverKey: 'country_id', values: {'840'});
      await vm.setStates({EntityState.archived});
      await vm.clearAllFilters();
      expect(vm.extraFilters, isEmpty);
      // Clear resets state to the default `{active}` (not `{}`). The lone
      // `State: Active` chip is expected; `hasActiveFilters` still reports
      // false for `{active}` so the clear button hides itself.
      expect(vm.states, {EntityState.active});
      expect(vm.hasActiveFilters, isFalse);

      // Clearing from a non-default state still reloads and lands on the
      // `{active}` default. The `changed` gate compares against that
      // target, so `archived → {active}` is a real change (not the old
      // `if (!hasActiveFilters) return;` silent no-op).
      await vm.setStates({EntityState.archived});
      expect(vm.states, {EntityState.archived});
      await vm.clearAllFilters();
      expect(vm.states, {EntityState.active});

      vm.dispose();
    },
  );

  test('swapExtraFilter moves the key in one reload', () async {
    final vm = FakeInvoiceListViewModel(
      companyId: 'co',
      navStateDao: db.navStateDao,
      userSettings: UserSettingsRepository(db: db),
      searchDebounce: const Duration(milliseconds: 1),
      persistDebounce: const Duration(milliseconds: 1),
    );
    await settle();
    await vm.setExtraFilter(
      serverKey: 'created_at',
      values: {'gte:2026-01-01'},
    );
    // Seed a stale window on the target so alsoClearServerKey is exercised.
    await vm.setExtraFilter(
      serverKey: 'due_date_range',
      values: {'due_date,2025-01-01,2025-12-31'},
    );
    await settle();
    final before = vm.fetchPageCalls;

    await vm.swapExtraFilter(
      fromServerKey: 'created_at',
      toServerKey: 'due_date',
      wireValue: 'gte:2026-01-01',
      alsoClearServerKey: 'due_date_range',
    );
    await settle();

    expect(vm.extraFilters.containsKey('created_at'), isFalse);
    expect(vm.extraFilters.containsKey('due_date_range'), isFalse);
    expect(vm.extraFilters['due_date'], {'gte:2026-01-01'});
    // Exactly one fetch — not the two a removeValue + addValue would cost.
    expect(vm.fetchPageCalls, before + 1);
    vm.dispose();
  });

  test('extraFilters persist + rehydrate across VM lifecycles', () async {
    final settings = UserSettingsRepository(db: db);
    final vm1 = FakeInvoiceListViewModel(
      companyId: 'co',
      navStateDao: db.navStateDao,
      userSettings: settings,
      searchDebounce: const Duration(milliseconds: 1),
      persistDebounce: const Duration(milliseconds: 1),
    );
    await settle();
    await vm1.setExtraFilter(serverKey: 'country_id', values: {'840', '124'});
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await settle();
    vm1.dispose();

    final vm2 = FakeInvoiceListViewModel(
      companyId: 'co',
      navStateDao: db.navStateDao,
      userSettings: settings,
      searchDebounce: const Duration(milliseconds: 1),
      persistDebounce: const Duration(milliseconds: 1),
    );
    await settle();
    expect(vm2.extraFilters['country_id'], {'840', '124'});
    vm2.dispose();
  });

  test(
    'v1 filter blob (no extraFilters field) hydrates without errors',
    () async {
      // Simulate a saved blob from before `extraFilters` existed: only
      // states + sortField. The base VM must read it as-is, defaulting
      // `_extraFilters` to {} so existing users don't lose their filters.
      final priorBlob =
          '{"co":{"invoice":{"search":"acme","states":["archived"],'
          '"sortField":"number","sortAscending":false,'
          '"customFilters":{}}}}';
      await db.navStateDao.saveFilters(
        filtersJson: priorBlob,
        now: DateTime.now().millisecondsSinceEpoch,
      );

      final vm = FakeInvoiceListViewModel(
        companyId: 'co',
        navStateDao: db.navStateDao,
        userSettings: UserSettingsRepository(db: db),
        searchDebounce: const Duration(milliseconds: 1),
        persistDebounce: const Duration(milliseconds: 1),
      );
      await settle();
      expect(vm.search, 'acme');
      expect(vm.states, {EntityState.archived});
      expect(vm.sortField, 'number');
      expect(vm.sortAscending, isFalse);
      expect(vm.extraFilters, isEmpty);
      vm.dispose();
    },
  );

  test('legacy updated_between filter migrates to updated_at_range on '
      'hydrate', () async {
    // A blob persisted by an older app version that exposed a standalone
    // "Updated between" filter (2-part start,end wire under updated_between).
    // It must rehydrate as the `updated` DateColumnFilterKey window so it
    // renders a chip and narrows the watch — not a stuck, chip-less filter.
    await db.navStateDao.saveFilters(
      filtersJson:
          '{"co":{"invoice":{"search":"","states":["active"],'
          '"sortField":"number","sortAscending":true,"customFilters":{},'
          '"extraFilters":{"updated_between":["2026-01-01,2026-03-31"]}}}}',
      now: 0,
    );
    final vm = FakeInvoiceListViewModel(
      companyId: 'co',
      navStateDao: db.navStateDao,
      userSettings: UserSettingsRepository(db: db),
      searchDebounce: const Duration(milliseconds: 1),
      persistDebounce: const Duration(milliseconds: 1),
    );
    await settle();
    expect(vm.extraFilters.containsKey('updated_between'), isFalse);
    expect(vm.extraFilters['updated_at_range'], {
      'updated_at,2026-01-01,2026-03-31',
    });
    vm.dispose();
  });

  test('updated_between migration defers to an existing updated_at_range '
      'window (no clobber)', () async {
    await db.navStateDao.saveFilters(
      filtersJson:
          '{"co":{"invoice":{"search":"","states":["active"],'
          '"sortField":"number","sortAscending":true,"customFilters":{},'
          '"extraFilters":{"updated_between":["2020-01-01,2020-12-31"],'
          '"updated_at_range":["updated_at,2026-05-01,2026-05-31"]}}}}',
      now: 0,
    );
    final vm = FakeInvoiceListViewModel(
      companyId: 'co',
      navStateDao: db.navStateDao,
      userSettings: UserSettingsRepository(db: db),
      searchDebounce: const Duration(milliseconds: 1),
      persistDebounce: const Duration(milliseconds: 1),
    );
    await settle();
    expect(vm.extraFilters.containsKey('updated_between'), isFalse);
    expect(vm.extraFilters['updated_at_range'], {
      'updated_at,2026-05-01,2026-05-31',
    });
    vm.dispose();
  });

  test('savedViewSnapshot omits columnIds on default, includes them once '
      'the user customizes', () async {
    final vm = FakeInvoiceListViewModel(
      companyId: 'co',
      navStateDao: db.navStateDao,
      userSettings: UserSettingsRepository(db: db),
      searchDebounce: const Duration(milliseconds: 1),
      persistDebounce: const Duration(milliseconds: 1),
    );
    await settle();
    // On the registry default (no stored preference) the view carries no
    // column override — otherwise applying it would force the default into
    // user_settings and queue a no-op PUT (the reported outbox bug).
    expect(
      vm.savedViewSnapshot().containsKey('columnIds'),
      isFalse,
      reason: 'no column override while on the default layout',
    );
    // Seed the user_settings row so setColumns isn't a silent no-op.
    await db.userSettingsDao.upsert(
      UserSettingsCompanion(
        companyId: const Value('co'),
        userId: const Value('user1'),
        tableColumnsJson: const Value('{}'),
        extraJson: const Value('{}'),
        updatedAt: const Value(0),
      ),
    );
    await vm.setColumns(['amount']);
    await settle();
    expect(
      vm.savedViewSnapshot()['columnIds'],
      equals(['amount']),
      reason: "reflects the user's explicit column-picker choice",
    );
    // currentSnapshot() must NOT carry columnIds — nav_state stays compact.
    expect(vm.currentSnapshot().containsKey('columnIds'), isFalse);

    // Reset back to the default → the override drops out again.
    await vm.resetColumns();
    await settle();
    expect(
      vm.savedViewSnapshot().containsKey('columnIds'),
      isFalse,
      reason: 'resetColumns clears the customization flag',
    );
    vm.dispose();
  });

  test('applySnapshot resets all six fields before applying', () async {
    final vm = FakeInvoiceListViewModel(
      companyId: 'co',
      navStateDao: db.navStateDao,
      userSettings: UserSettingsRepository(db: db),
      searchDebounce: const Duration(milliseconds: 1),
      persistDebounce: const Duration(milliseconds: 1),
    );
    await settle();
    // Pre-load the VM with non-empty extraFilters + non-default sort —
    // these must be cleared by applySnapshot, not merged.
    await vm.setExtraFilter(serverKey: 'country_id', values: {'US'});
    await vm.setSort(field: 'amount', ascending: false);
    expect(vm.extraFilters['country_id'], {'US'});
    expect(vm.sortField, 'amount');

    // Apply a snapshot that omits extraFilters and reverts sort.
    await vm.applySnapshot({
      'search': 'acme',
      'states': ['archived'],
      'sortField': 'number',
      'sortAscending': true,
    });
    expect(vm.search, 'acme');
    expect(vm.states, {EntityState.archived});
    expect(vm.sortField, 'number');
    expect(vm.sortAscending, isTrue);
    // Critical: extraFilters from before is wiped, not retained.
    expect(vm.extraFilters, isEmpty);
    vm.dispose();
  });

  test(
    'rehydrate from disk + own-write persist cycle stabilizes within one '
    'fetch (locks down snapshot equality against future key reordering)',
    () async {
      await db.navStateDao.saveFilters(
        filtersJson:
            '{"co":{"invoice":{"search":"acme","states":["archived"],'
            '"sortField":"number","sortAscending":false,'
            '"customFilters":{},"extraFilters":{"country_id":["US"]}}}}',
        now: 0,
      );
      final vm = FakeInvoiceListViewModel(
        companyId: 'co',
        navStateDao: db.navStateDao,
        userSettings: UserSettingsRepository(db: db),
        searchDebounce: const Duration(milliseconds: 1),
        persistDebounce: const Duration(milliseconds: 1),
      );
      await settle();
      // Wait past the persist debounce; a spurious watchCurrent re-apply
      // (key-order regression) would echo back as another fetchPage.
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await settle();
      expect(
        vm.fetchPageCalls,
        1,
        reason:
            'exactly one initial fetch — if currentSnapshot() ever reorders '
            'keys vs the persisted slot, DeepCollectionEquality would '
            'diverge and the listener would re-apply, bumping this counter',
      );
      vm.dispose();
    },
  );

  test('user filter change made during the hydrate→first-emission window '
      'survives the listener', () async {
    // Pre-seed nav_state so hydrate has content to read; the slot's
    // extraFilters omit country_id.
    await db.navStateDao.saveFilters(
      filtersJson:
          '{"co":{"invoice":{"search":"","states":["active"],'
          '"sortField":"number","sortAscending":true,'
          '"customFilters":{},"extraFilters":{}}}}',
      now: 0,
    );
    final vm = FakeInvoiceListViewModel(
      companyId: 'co',
      navStateDao: db.navStateDao,
      userSettings: UserSettingsRepository(db: db),
      searchDebounce: const Duration(milliseconds: 1),
      persistDebounce: const Duration(milliseconds: 1),
    );
    // Race the listener: mutate before settle. This synchronously kicks
    // off _resetAndReload + a debounced persist; the first watchCurrent
    // emission is still in flight and would otherwise overwrite us.
    // Yield once so _hydrate completes (it's awaited inside _init).
    await Future<void>.delayed(Duration.zero);
    unawaited(vm.setExtraFilter(serverKey: 'country_id', values: {'US', 'CA'}));
    // Now let everything settle past the persist debounce.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await settle();
    expect(
      vm.extraFilters['country_id'],
      {'US', 'CA'},
      reason:
          "user's mid-init mutation must not be overwritten by the first "
          'watchCurrent emission echoing the pre-edit slot back at us',
    );
    vm.dispose();
  });

  test(
    'nav_state listener does not feedback-loop on the VM\'s own persist',
    () async {
      final vm = FakeInvoiceListViewModel(
        companyId: 'co',
        navStateDao: db.navStateDao,
        userSettings: UserSettingsRepository(db: db),
        searchDebounce: const Duration(milliseconds: 1),
        persistDebounce: const Duration(milliseconds: 1),
      );
      await settle();
      final initialFetches = vm.fetchPageCalls;
      // Mutate state so the VM persists. The persist will write
      // nav_state.filters_json, which fires the watchCurrent listener — but
      // the slot will match currentSnapshot and the listener must skip.
      await vm.setExtraFilter(serverKey: 'country_id', values: {'US'});
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await settle();
      // Exactly one extra fetch (the setExtraFilter -> _resetAndReload path).
      // No second fetch from the watchCurrent listener echoing our own
      // persist back at us.
      expect(vm.fetchPageCalls, initialFetches + 1);
      vm.dispose();
    },
  );

  test('external slot removal resets the running list to defaults', () async {
    // Models SavedViewsRepository.clearAppliedViewFilters: the entity's
    // slot is removed from filters_json while the VM is live. The VM must
    // fall back to defaults and reload, not keep the stale filters.
    final vm = FakeInvoiceListViewModel(
      companyId: 'co',
      navStateDao: db.navStateDao,
      userSettings: UserSettingsRepository(db: db),
      searchDebounce: const Duration(milliseconds: 1),
      persistDebounce: const Duration(milliseconds: 1),
    );
    await settle();
    await vm.setExtraFilter(serverKey: 'country_id', values: {'US'});
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await settle();
    expect(vm.extraFilters, isNotEmpty);
    final fetches = vm.fetchPageCalls;

    // Remove the slot (no `co.invoice` key) — the listener treats absent
    // as "reset to defaults".
    await db.navStateDao.saveFilters(filtersJson: '{}', now: 1);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await settle();

    expect(vm.extraFilters, isEmpty);
    expect(vm.search, '');
    expect(vm.fetchPageCalls, fetches + 1);
    vm.dispose();
  });

  test('external slot removal is a no-op when already at defaults', () async {
    final vm = FakeInvoiceListViewModel(
      companyId: 'co',
      navStateDao: db.navStateDao,
      userSettings: UserSettingsRepository(db: db),
      searchDebounce: const Duration(milliseconds: 1),
      persistDebounce: const Duration(milliseconds: 1),
    );
    await settle();
    final fetches = vm.fetchPageCalls;

    // Already default → the _defaultSnapshot() stand-in dedupes against
    // currentSnapshot(); no spurious reload.
    await db.navStateDao.saveFilters(filtersJson: '{}', now: 1);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await settle();

    expect(vm.fetchPageCalls, fetches);
    vm.dispose();
  });

  test(
    'transformPage override filters items before they reach the view',
    () async {
      final vm = _UnpaidOnlyInvoiceListViewModel(
        companyId: 'co',
        navStateDao: db.navStateDao,
        userSettings: UserSettingsRepository(db: db),
        searchDebounce: const Duration(milliseconds: 1),
        persistDebounce: const Duration(milliseconds: 1),
      );
      await settle();
      // The fake stub has inv_1 (amount=100) and inv_2 (amount=200, archived).
      // The override drops anything with amount < 150 — exercises the hook
      // wiring without depending on entity-specific semantics.
      expect(
        vm.items.map((i) => i.id),
        ['inv_2'],
        reason: 'transformPage(raw) wrapped watchPage() before _onItems ran',
      );
      vm.dispose();
    },
  );

  test(
    'empty `_states` is treated as "no status filter" in hasActiveFilters',
    () async {
      final vm = FakeInvoiceListViewModel(
        companyId: 'co',
        navStateDao: db.navStateDao,
        userSettings: UserSettingsRepository(db: db),
        searchDebounce: const Duration(milliseconds: 1),
        persistDebounce: const Duration(milliseconds: 1),
      );
      await settle();

      // Default `{active}` reports no active filter.
      expect(vm.hasActiveFilters, isFalse);

      // Clearing to `{}` (user removed the only status chip) is also
      // "no filter" — both states drop the lifecycle `status` query param.
      await vm.setStates(const <EntityState>{});
      expect(
        vm.hasActiveFilters,
        isFalse,
        reason:
            'empty set means "show all"; equivalent to the default `{active}` '
            'from a hasActiveFilters perspective so the empty-state copy '
            'reads "no clients yet", not "no matches".',
      );
      vm.dispose();
    },
  );

  test(
    'embedded list neither hydrates from nor persists to the shared '
    'nav_state slot (a detail tab must not corrupt the standalone list)',
    () async {
      // The standalone list has a persisted "resume where you left off" view.
      await db.navStateDao.saveFilters(
        filtersJson:
            '{"co":{"invoice":{"search":"acme","states":["archived"],'
            '"sortField":"number","sortAscending":false,'
            '"customFilters":{},"extraFilters":{"country_id":["US"]}}}}',
        now: 0,
      );

      final vm = _EmbeddedFakeInvoiceListViewModel(
        companyId: 'co',
        navStateDao: db.navStateDao,
        userSettings: UserSettingsRepository(db: db),
        searchDebounce: const Duration(milliseconds: 1),
        persistDebounce: const Duration(milliseconds: 1),
      );
      await settle();

      // 1) It did NOT inherit the standalone list's persisted view — it starts
      //    from its own locked-scope defaults.
      expect(vm.isEmbedded, isTrue);
      expect(
        vm.search,
        '',
        reason: 'embedded must not hydrate the shared slot',
      );
      expect(vm.states, {EntityState.active});
      expect(vm.extraFilters, isEmpty);

      // 2) Interacting with the embedded list must NOT write the shared slot.
      await vm.setExtraFilter(serverKey: 'country_id', values: {'CA'});
      vm.setSearch('zzz'); // debounced, fire-and-forget
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await settle();

      final row = await db.navStateDao.current();
      expect(
        row!.filtersJson!.contains('"acme"'),
        isTrue,
        reason: "standalone list's saved search is preserved",
      );
      expect(
        row.filtersJson!.contains('"zzz"'),
        isFalse,
        reason: 'embedded search must not leak into the shared slot',
      );
      expect(
        row.filtersJson!.contains('"CA"'),
        isFalse,
        reason: 'embedded filter must not leak into the shared slot',
      );
      vm.dispose();
    },
  );

  group('local-only filter auto-chain (M4)', () {
    const short = [FakeInvoice(id: 'inv_9', number: 'INV-009', amount: 1)];

    Future<_LocalFilterFakeVm> makeVm() async {
      final vm = _LocalFilterFakeVm(
        companyId: 'co',
        navStateDao: db.navStateDao,
        userSettings: UserSettingsRepository(db: db),
        searchDebounce: const Duration(milliseconds: 1),
        persistDebounce: const Duration(milliseconds: 1),
      );
      await settle();
      addTearDown(() {
        vm.dispose();
        vm.controller.close();
      });
      return vm;
    }

    test('a short filtered emission chains one loadMore', () async {
      final vm = await makeVm();
      final initial = vm.fetchPageCalls;

      vm.controller.add(short);
      await settle();

      expect(vm.fetchPageCalls, initial + 1);
    });

    test('chain is budget-bounded per filter epoch', () async {
      final vm = await makeVm();
      final initial = vm.fetchPageCalls;

      for (var i = 0; i < 10; i++) {
        vm.controller.add(short);
        await settle();
      }

      // 5-page allowance, no matter how many short emissions arrive.
      expect(vm.fetchPageCalls, initial + 5);
    });

    test('no chain when localOnlyFilterActive is false', () async {
      final vm = await makeVm();
      vm.localFilter = false;
      final initial = vm.fetchPageCalls;

      vm.controller.add(short);
      await settle();

      expect(vm.fetchPageCalls, initial);
    });

    test('a failed chained fetch does not hot-loop', () async {
      final vm = await makeVm();
      vm.fetchThrows = true;
      final initial = vm.fetchPageCalls;

      vm.controller.add(short);
      await settle();
      await settle();

      // One attempt for the one emission — a failure produces no new Drift
      // emission, so nothing re-triggers without external input.
      expect(vm.fetchPageCalls, initial + 1);
    });

    test('consumeTransientError is consume-once and carries the kind + '
        'stripped message (a failed refresh/load-more must reach the toast, '
        'not vanish in a same-tick null-out)', () async {
      final vm = await makeVm();
      vm.fetchThrows = true;

      await vm.refresh();
      final refreshError = vm.consumeTransientError();
      expect(refreshError?.kind, 'refresh');
      expect(refreshError?.message, isNotEmpty);
      expect(vm.consumeTransientError(), isNull, reason: 'consume-once');

      await vm.loadMore();
      final loadMoreError = vm.consumeTransientError();
      expect(loadMoreError?.kind, 'load_more');
      expect(vm.consumeTransientError(), isNull);
    });

    test('budget re-arms after a filter/sort reset', () async {
      final vm = await makeVm();
      for (var i = 0; i < 6; i++) {
        vm.controller.add(short);
        await settle();
      }
      final exhausted = vm.fetchPageCalls;

      // Any epoch bump (_resetAndReload) re-arms the allowance.
      await vm.setSort(field: 'amount', ascending: true);
      await settle();
      final afterReset = vm.fetchPageCalls; // +1 from the reset's own fetch

      vm.controller.add(short);
      await settle();

      expect(afterReset, exhausted + 1);
      expect(vm.fetchPageCalls, afterReset + 1);
    });

    // #25 regression: the chain must fire from the INITIAL load, not only from
    // later emissions. A real Drift watch re-runs its query on every write AND
    // re-emits on re-subscribe; the page-1 upsert emits *mid-load* (while
    // `isLoadingPage` is still true), so `_maybeAutoChain` bails and — without a
    // post-fetch `_resubscribe()` — nothing re-fires it, dead-ending a short
    // `stock:`/`tag:` page on a false "No records found". The broadcast fake in
    // the tests above emits only AFTER settle (post-load), so it can't surface
    // this; this fake's `Stream.value(short)` re-emits on the finally's
    // re-subscribe, exactly like Drift.
    test('a short first page auto-chains from the INITIAL load (not just later '
        'emissions)', () async {
      final vm = _InitialLoadLocalFilterFakeVm(
        companyId: 'co',
        navStateDao: db.navStateDao,
        userSettings: UserSettingsRepository(db: db),
        searchDebounce: const Duration(milliseconds: 1),
        persistDebounce: const Duration(milliseconds: 1),
      );
      addTearDown(vm.dispose);
      await settle();

      // fetchPageCalls == 1 means only the initial load ran and the chain never
      // fired (the bug). The post-fetch re-subscribe re-emits the short page
      // with isLoadingPage cleared, so the chain runs (bounded by the budget).
      expect(
        vm.fetchPageCalls,
        greaterThan(1),
        reason: 'initial short page must chain loadMore, not dead-end',
      );
      expect(
        vm.fetchPageCalls,
        lessThanOrEqualTo(6),
        reason: 'chain stays budget-bounded (1 initial + 5 pages)',
      );
    });
  });
}

/// Exercises the `transformPage` hook: drops invoices with `amount < 150` so
/// only `inv_2` makes it to the view. Stand-in for a real "unpaid invoices"
/// derived filter that the server doesn't expose as an `extraFilters` key.
class _UnpaidOnlyInvoiceListViewModel extends FakeInvoiceListViewModel {
  _UnpaidOnlyInvoiceListViewModel({
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
    super.searchDebounce,
    super.persistDebounce,
  });

  @override
  Stream<List<FakeInvoice>> transformPage(Stream<List<FakeInvoice>> raw) =>
      raw.map((items) => items.where((i) => i.amount >= 150).toList());
}

/// Fake for the local-only-filter auto-chain (M4): a controllable watch
/// stream plus a fetch that reports more pages, so tests can drive the
/// emission → loadMore chain step by step.
class _LocalFilterFakeVm extends FakeInvoiceListViewModel {
  _LocalFilterFakeVm({
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
    super.searchDebounce,
    super.persistDebounce,
  });

  bool localFilter = true;
  bool fetchThrows = false;
  final StreamController<List<FakeInvoice>> controller =
      StreamController<List<FakeInvoice>>.broadcast();

  @override
  bool get localOnlyFilterActive => localFilter;

  @override
  Stream<List<FakeInvoice>> watchPage() => controller.stream;

  @override
  Future<bool> fetchPage({
    required int page,
    required String? search,
    required Set<EntityState> states,
    required Map<String, Set<String>> extraFilters,
    required bool ignoreCursor,
  }) async {
    fetchPageCalls++;
    if (fetchThrows) throw Exception('offline');
    return true; // hasMore — the chain's precondition.
  }

  @override
  Future<void> refreshAll() async {
    if (fetchThrows) throw Exception('offline');
  }
}

/// #25 fake: `watchPage()` returns a fresh `Stream.value(short)` on EVERY call,
/// so it re-emits the short page on each (re-)subscribe — the behavior of a real
/// Drift watch that the broadcast [_LocalFilterFakeVm] can't reproduce. Used to
/// prove the auto-chain fires from the initial load via the post-fetch
/// `_resubscribe()`, not only from later manual emissions.
class _InitialLoadLocalFilterFakeVm extends FakeInvoiceListViewModel {
  _InitialLoadLocalFilterFakeVm({
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
    super.searchDebounce,
    super.persistDebounce,
  });

  static const _short = [
    FakeInvoice(id: 'inv_9', number: 'INV-009', amount: 1),
  ];

  @override
  bool get localOnlyFilterActive => true;

  @override
  Stream<List<FakeInvoice>> watchPage() => Stream.value(_short);

  @override
  Future<bool> fetchPage({
    required int page,
    required String? search,
    required Set<EntityState> states,
    required Map<String, Set<String>> extraFilters,
    required bool ignoreCursor,
  }) async {
    fetchPageCalls++;
    return true; // hasMore — the chain's precondition.
  }

  @override
  Future<void> refreshAll() async {}
}

/// Stand-in for an embedded list (e.g. a client detail tab). A non-empty
/// [lockedFilterKeyIds] is the signal `GenericListViewModel.isEmbedded` reads
/// to keep its filter state purely in memory — never touching the shared
/// per-entity `nav_state` slot that belongs to the standalone list.
class _EmbeddedFakeInvoiceListViewModel extends FakeInvoiceListViewModel {
  _EmbeddedFakeInvoiceListViewModel({
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
    super.searchDebounce,
    super.persistDebounce,
  });

  @override
  Set<String> get lockedFilterKeyIds => const {'client'};
}
