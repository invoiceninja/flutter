import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/list_status_tabs.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';

/// The ViewModel half of the status-tab strip (invoiceninja/flutter#98).
///
/// The tab is stored as a single `extraFilters['badge_mode']` entry so it rides
/// nav_state and saved views for free — but that key is app-private and must
/// never reach the API. What's pinned here is the translation that happens on
/// the way out, and the two things that go wrong silently if it doesn't: a
/// `badge_mode` sent to a server that ignores it (which would still switch off
/// the delta cursor), and a local-only tab that forgets to arm the auto-chain.
class _FakeVm extends GenericListViewModel<dynamic> {
  _FakeVm({
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
    required this.type,
    super.searchDebounce,
    super.persistDebounce,
  });

  final EntityType type;

  int fetchCount = 0;
  Map<String, Set<String>> lastFetchExtraFilters = const {};

  @override
  EntityType get entityType => type;

  @override
  List<ColumnDefinition<dynamic>> get allColumns => const [];

  @override
  List<String> get defaultColumnIds => const [];

  @override
  String get defaultSortField => 'number';

  @override
  bool isValidColumnId(String field) => true;

  @override
  String idOf(dynamic item) => '';

  @override
  bool isArchived(dynamic item) => false;

  @override
  bool isDeleted(dynamic item) => false;

  @override
  Stream<List<dynamic>> watchPage() => const Stream.empty();

  @override
  Future<bool> fetchPage({
    required int page,
    required String? search,
    required Set<EntityState> states,
    required Map<String, Set<String>> extraFilters,
    required bool ignoreCursor,
  }) async {
    fetchCount++;
    lastFetchExtraFilters = extraFilters;
    return false;
  }

  @override
  Future<void> refreshAll() async {}

  @override
  Iterable<BulkAction<dynamic>> get bulkActions => const [];

  bool get localOnlyForTest => localOnlyFilterActive;
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<_FakeVm> makeVm(EntityType type) async {
    final vm = _FakeVm(
      companyId: 'co',
      navStateDao: db.navStateDao,
      userSettings: UserSettingsRepository(db: db),
      type: type,
      searchDebounce: const Duration(milliseconds: 1),
      persistDebounce: const Duration(milliseconds: 1),
    );
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return vm;
  }

  test('a mapped tab sends the entity server filter, never badge_mode', () async {
    final vm = await makeVm(EntityType.invoice);
    await vm.setBadgeMode('draft');

    expect(vm.activeBadgeModeId, 'draft');
    expect(
      vm.lastFetchExtraFilters.containsKey(kBadgeModeFilterKey),
      isFalse,
      reason:
          'badge_mode is a SidebarBadgeMode id, not a query param — sending it '
          'would also flip isNarrowedFetch and kill the delta cursor for a '
          'filter the server ignores',
    );
    expect(vm.lastFetchExtraFilters['status_id'], {'1'});
    vm.dispose();
  });

  test('a local-only tab sends nothing and arms the auto-chain', () async {
    final vm = await makeVm(EntityType.project);
    await vm.setBadgeMode('over_budget');

    expect(vm.lastFetchExtraFilters, isEmpty);
    expect(
      vm.localOnlyForTest,
      isTrue,
      reason:
          'without this a tab whose matches sit past page 1 renders a false '
          '"No records found" with no scroll extent to page out of',
    );
    vm.dispose();
  });

  test('an EXACT mapping does not arm the auto-chain — the fetch returns '
      'precisely the tab\'s rows, so paging is the server\'s job', () async {
    final vm = await makeVm(EntityType.invoice);
    await vm.setBadgeMode('draft');
    expect(vm.localOnlyForTest, isFalse);
    vm.dispose();
  });

  test('a WIDENED mapping narrows the fetch AND arms the auto-chain', () async {
    // The regression this exists for: Quotes → Expired fetches `expired,draft`
    // because the app also counts a past-due draft as expired. On an account
    // with many drafts, page 1 comes back full of them and the local predicate
    // keeps almost none — a short emission with no scroll extent, so without
    // the chain the tab reads "Expired 3" over "No records found". Gating the
    // chain on "has no server mapping" (rather than "still narrows locally")
    // silently lost this for five tabs.
    final vm = await makeVm(EntityType.quote);
    await vm.setBadgeMode('expired');

    expect(vm.lastFetchExtraFilters['client_status'], {'expired', 'draft'});
    expect(
      vm.localOnlyForTest,
      isTrue,
      reason: 'a superset fetch still leaves the local predicate narrowing',
    );
    vm.dispose();
  });

  test(
    'an un-mapped tab on an entity that HAS mappings still arms the chain',
    () async {
      // Payments: pending/failed are exact server filters, but `unapplied` has no
      // usable superset and is local-only. The per-mode lookup has to see that.
      final vm = await makeVm(EntityType.payment);
      await vm.setBadgeMode('unapplied');
      expect(vm.lastFetchExtraFilters, isEmpty);
      expect(vm.localOnlyForTest, isTrue);

      await vm.setBadgeMode('failed');
      expect(vm.lastFetchExtraFilters['client_status'], {'failed'});
      expect(vm.localOnlyForTest, isFalse);
      vm.dispose();
    },
  );

  test('a filter the user set by hand wins the fetch', () async {
    final vm = await makeVm(EntityType.invoice);
    // Hand-picked "Paid" via the search field, then the Draft tab.
    await vm.setExtraFilter(serverKey: 'status_id', values: {'4'});
    await vm.setBadgeMode('draft');

    expect(
      vm.lastFetchExtraFilters['status_id'],
      {'4'},
      reason:
          'the tab must not silently widen the fetch behind a chip the user '
          'can see; its own predicate still ANDs on top locally',
    );
    vm.dispose();
  });

  test('selecting a tab is one reload, and All is one more', () async {
    final vm = await makeVm(EntityType.invoice);
    final before = vm.fetchCount;

    await vm.setBadgeMode('draft');
    expect(vm.fetchCount, before + 1);

    await vm.setBadgeMode(null);
    expect(vm.fetchCount, before + 2);
    expect(vm.activeBadgeModeId, isNull);
    vm.dispose();
  });

  test('clearAllFilters resets the strip to All', () async {
    final vm = await makeVm(EntityType.invoice);
    await vm.setBadgeMode('draft');
    expect(vm.hasActiveFilters, isTrue);

    await vm.clearAllFilters();
    expect(vm.activeBadgeModeId, isNull);
    vm.dispose();
  });

  group('persistence', () {
    Future<void> seedNavState(EntityType type, String modeId) =>
        db.navStateDao.saveFilters(
          filtersJson: jsonEncode({
            'co': {
              type.name: {
                'extraFilters': {
                  kBadgeModeFilterKey: [modeId],
                },
              },
            },
          }),
          now: 1,
        );

    test('a live tab is restored on the next launch', () async {
      await seedNavState(EntityType.invoice, 'draft');
      final vm = await makeVm(EntityType.invoice);
      expect(vm.activeBadgeModeId, 'draft');
      vm.dispose();
    });

    test('a tab this build no longer offers is dropped rather than left as a '
        'stuck, chip-less filter', () async {
      await seedNavState(EntityType.invoice, 'retired_mode');
      final vm = await makeVm(EntityType.invoice);
      expect(vm.activeBadgeModeId, isNull);
      expect(
        vm.hasActiveFilters,
        isFalse,
        reason:
            'a dead key would keep the Clear-filters affordance lit forever '
            'while filtering nothing the user can see',
      );
      vm.dispose();
    });

    test('a mode belonging to a different entity is dropped too', () async {
      // `sent` is a quote / credit / purchase-order bucket, not an invoice one.
      await seedNavState(EntityType.invoice, 'sent');
      final vm = await makeVm(EntityType.invoice);
      expect(vm.activeBadgeModeId, isNull);
      vm.dispose();
    });
  });
}
