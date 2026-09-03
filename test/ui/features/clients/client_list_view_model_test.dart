import 'dart:convert';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/data/services/clients_api.dart';
import 'package:admin/data/services/invoices_api.dart';
import 'package:admin/domain/columns/client_columns.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/ui/features/clients/view_models/client_list_view_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// These tests target the ClientListViewModel's contract — what the UI
/// depends on. They DON'T re-test the repository, Drift, or ChangeNotifier
/// itself; we use a fake ClientsApi + a real in-memory ClientRepository so
/// the dataflow we actually wire in production is exercised.

class _FakeClientsApi implements ClientsApi {
  _FakeClientsApi();
  final Map<int, List<ClientApi>> pages = {};
  final List<
    ({
      int page,
      String? search,
      Map<String, String> filters,
      int? sinceUpdatedAt,
    })
  >
  calls = [];
  Object? nextError;

  @override
  Future<({ClientListApi data, int? cursorUpdatedAt, String? cursorId})> list({
    required int page,
    int perPage = 50,
    String? search,
    int? sinceUpdatedAt,
    String? sinceId,
    Map<String, String> filters = const {},
  }) async {
    calls.add((
      page: page,
      search: search,
      filters: Map<String, String>.from(filters),
      sinceUpdatedAt: sinceUpdatedAt,
    ));
    if (nextError != null) {
      final err = nextError;
      nextError = null;
      throw err!;
    }
    final rows = pages[page] ?? const <ClientApi>[];
    return (
      data: ClientListApi(data: rows),
      cursorUpdatedAt: rows.isNotEmpty ? rows.last.updatedAt : null,
      cursorId: rows.isNotEmpty ? rows.last.id : null,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Feeds the `overdue` status tab's cross-entity hydration (#119). Records the
/// query params so the wire shape — and the cursor gate — can be asserted
/// rather than assumed.
class _FakeInvoicesApi implements InvoicesApi {
  final Map<int, List<InvoiceApi>> pages = {};
  final List<({int page, Map<String, String> filters, int? since})> calls = [];
  Object? nextError;

  @override
  Future<({InvoiceListApi data, int? cursorUpdatedAt, String? cursorId})> list({
    required int page,
    int perPage = 50,
    String? search,
    int? sinceUpdatedAt,
    String? sinceId,
    Map<String, String> filters = const {},
  }) async {
    calls.add((
      page: page,
      filters: Map<String, String>.from(filters),
      since: sinceUpdatedAt,
    ));
    if (nextError != null) {
      final err = nextError;
      nextError = null;
      throw err!;
    }
    final rows = pages[page] ?? const <InvoiceApi>[];
    return (
      data: InvoiceListApi(data: rows),
      cursorUpdatedAt: rows.isNotEmpty ? rows.last.updatedAt : null,
      cursorId: rows.isNotEmpty ? rows.last.id : null,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

ClientApi _row(String id, {String name = ''}) =>
    ClientApi(id: id, name: name.isEmpty ? id : name, updatedAt: 100);

/// A sent, part-paid invoice whose due date is in the past — i.e. one that
/// `invoiceOverdueFilter` counts.
InvoiceApi _overdueInvoice(String id, {required String clientId}) => InvoiceApi(
  id: id,
  number: id,
  updatedAt: 100,
  clientId: clientId,
  statusId: '2',
  balance: '10',
  dueDate: Date.today().addDays(-2).toIso(),
);

void main() {
  late AppDatabase db;
  late _FakeClientsApi api;
  late ClientRepository repo;
  late _FakeInvoicesApi invoiceApi;
  late InvoiceRepository invoiceRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = _FakeClientsApi();
    repo = ClientRepository(db: db, api: api);
    invoiceApi = _FakeInvoicesApi();
    invoiceRepo = InvoiceRepository(
      db: db,
      api: invoiceApi,
      settings: SettingsRepository(db: db),
    );
  });
  tearDown(() async {
    await db.close();
  });

  ClientListViewModel vmFor(String companyId) => ClientListViewModel(
    repo: repo,
    invoices: invoiceRepo,
    navStateDao: db.navStateDao,
    userSettings: UserSettingsRepository(db: db),
    companyId: companyId,
    // Keep the debounce tiny so tests don't sleep needlessly.
    searchDebounce: const Duration(milliseconds: 1),
    persistDebounce: const Duration(milliseconds: 1),
  );

  /// Pump the event loop a few times — enough for the constructor's
  /// `unawaited(_loadInitialPage())` and any chained `notifyListeners()`
  /// to settle.
  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('initial load', () {
    test('triggers an ensurePageLoaded(1) on construction', () async {
      api.pages[1] = [_row('c1'), _row('c2')];
      final vm = vmFor('co');
      await settle();

      expect(api.calls, hasLength(1));
      expect(api.calls.single.page, 1);
      expect(api.calls.single.search, isNull);
      expect(vm.items.map((c) => c.id), ['c1', 'c2']);
      vm.dispose();
    });

    test('captures error so the screen can render ErrorView', () async {
      api.nextError = Exception('boom');
      final vm = vmFor('co');
      await settle();

      expect(vm.initialError, isNotNull);
      expect(vm.items, isEmpty);

      // retryInitial flows through the same path and clears the error
      // on success.
      api.pages[1] = [_row('c1')];
      await vm.retryInitial();
      await settle();

      expect(vm.initialError, isNull);
      expect(vm.items.map((c) => c.id), ['c1']);
      vm.dispose();
    });
  });

  group('loadMore', () {
    test('only widens loadedPages on a successful fetch', () async {
      api.pages[1] = [for (var i = 0; i < 50; i++) _row('c$i')]; // full page
      api.pages[2] = [_row('c50')]; // partial → hasMore=false
      final vm = vmFor('co');
      await settle();
      expect(vm.loadedPages, 1);
      expect(vm.hasMore, isTrue);

      await vm.loadMore();
      await settle();
      expect(vm.loadedPages, 2);
      expect(vm.hasMore, isFalse);

      // Calling again after hasMore=false is a no-op (no API call).
      final callsBefore = api.calls.length;
      await vm.loadMore();
      expect(api.calls.length, callsBefore);
      vm.dispose();
    });

    test('errors on subsequent pages do not bump loadedPages', () async {
      api.pages[1] = [for (var i = 0; i < 50; i++) _row('c$i')];
      final vm = vmFor('co');
      await settle();

      api.nextError = Exception('flake');
      await vm.loadMore();
      await settle();
      expect(vm.loadedPages, 1, reason: 'window must not widen on error');
      vm.dispose();
    });

    // flutter#32, end to end. Once the server latched `hasMore = false` the
    // Drift window (`LIMIT pageSize * loadedPages`) was frozen forever: a Sync
    // could land thousands of rows the list would never show, and only clearing
    // the filter — which resets loadedPages/hasMore — brought them back.
    test('rows that land in Drift behind an exhausted list are still reachable '
        '— widening the window needs no server round-trip', () async {
      String id(int i) => 'c${i.toString().padLeft(3, '0')}';
      api.pages[1] = [for (var i = 0; i < 50; i++) _row(id(i))];
      api.pages[2] = [_row(id(50))];
      final vm = vmFor('co');
      await settle();
      await vm.loadMore();
      await settle();
      expect(vm.hasMore, isFalse, reason: 'server exhausted');
      expect(vm.items, hasLength(51));

      // A Sync: `refreshAll` pages the whole entity into Drift, touching no
      // list VM at all — the rows reach the UI only via the live Drift watch,
      // bounded by the window the VM is still holding.
      api.pages[2] = [for (var i = 50; i < 100; i++) _row(id(i))];
      api.pages[3] = [for (var i = 100; i < 150; i++) _row(id(i))];
      await repo.refreshAll(companyId: 'co');
      await settle();

      expect(
        vm.items,
        hasLength(100),
        reason: 'still clamped to LIMIT pageSize * loadedPages',
      );
      expect(
        vm.canWidenLocally,
        isTrue,
        reason: 'the window is saturated, so Drift may hold more',
      );

      final callsBefore = api.calls.length;
      await vm.loadMore();
      await settle();

      expect(vm.loadedPages, 3);
      expect(vm.items, hasLength(150));
      expect(
        api.calls.length,
        callsBefore,
        reason: 'the rows were already local — no request to make',
      );
      vm.dispose();
    });
  });

  group('state filter', () {
    test(
      'setStates resets pagination and passes the lifecycle `status` param',
      () async {
        api.pages[1] = [_row('c1')];
        final vm = vmFor('co');
        await settle();
        api.calls.clear();

        await vm.setStates({EntityState.active, EntityState.archived});
        await settle();

        expect(vm.loadedPages, 1);
        expect(api.calls.single.page, 1);
        expect(api.calls.single.filters['status'], 'active,archived');
        expect(api.calls.single.filters.containsKey('client_status'), isFalse);
      },
    );

    test('widening states fetches with ignoreCursor so previously-uncovered '
        'rows can be pulled', () async {
      api.pages[1] = [_row('c1')];
      final vm = vmFor('co');
      await settle();
      // After initial load the cursor is advanced; the next call would
      // normally include sinceUpdatedAt. Widening the state set must
      // clear the cursor for that request.
      api.calls.clear();

      await vm.setStates({EntityState.active, EntityState.archived});
      await settle();

      expect(api.calls.single.sinceUpdatedAt, isNull);
    });

    // flutter#32. The cursor READ gate used to ignore `extraFilters` and a
    // narrowed `states` set even though the ADVANCE gate honoured both, so a
    // filter chip went out as `filter AND updated_at >= W`. The server then
    // returned only slice rows changed since the last sync — and after a Sync
    // (W ≈ now) essentially nothing, which a short list has no scroll extent to
    // page out of.
    test('a filter chip fetches WITHOUT the warm cursor, so matches older than '
        'the last sync are still pulled', () async {
      api.pages[1] = [_row('c1')];
      final vm = vmFor('co');
      await settle();
      api.calls.clear();

      await vm.setExtraFilter(serverKey: 'country_id', values: {'840'});
      await settle();

      expect(api.calls.single.sinceUpdatedAt, isNull);
      expect(api.calls.single.filters['country_id'], '840');
    });

    test('NARROWING the state set also drops the warm cursor — an `{archived}` '
        'slice is a view like any other', () async {
      api.pages[1] = [_row('c1')];
      final vm = vmFor('co');
      await settle();
      api.calls.clear();

      await vm.setStates({EntityState.archived});
      await settle();

      expect(api.calls.single.sinceUpdatedAt, isNull);
    });

    test(
      'empty set is allowed and omits the lifecycle `status` param ("All")',
      () async {
        api.pages[1] = [_row('c1')];
        final vm = vmFor('co');
        await settle();

        await vm.setStates(<EntityState>{});
        await settle();

        expect(vm.states, isEmpty);
        expect(api.calls.last.filters.containsKey('status'), isFalse);
        // No transient notice on the new "All" path.
        expect(vm.consumeTransientNotice(), isNull);
      },
    );

    test('toggleState mirrors setStates with one entity flipped', () async {
      api.pages[1] = [_row('c1')];
      final vm = vmFor('co');
      await settle();

      vm.toggleState(EntityState.archived);
      await settle();

      expect(vm.states, {EntityState.active, EntityState.archived});
    });
  });

  group('sort', () {
    test('setSort resets pagination and notifies', () async {
      api.pages[1] = [_row('c1')];
      final vm = vmFor('co');
      await settle();

      var notifications = 0;
      vm.addListener(() => notifications++);

      await vm.setSort(field: ClientFieldIds.balance, ascending: false);
      await settle();

      expect(vm.sortField, ClientFieldIds.balance);
      expect(vm.sortAscending, isFalse);
      expect(notifications, greaterThan(0));
      expect(vm.loadedPages, 1);
    });

    test('setSort with same field+direction is a no-op', () async {
      api.pages[1] = [_row('c1')];
      final vm = vmFor('co');
      await settle();
      api.calls.clear();

      await vm.setSort(field: ClientFieldIds.name, ascending: true);
      await settle();

      expect(api.calls, isEmpty);
    });
  });

  group('custom filters', () {
    test('setCustomFilter records selection and resets pagination', () async {
      api.pages[1] = [_row('c1')];
      final vm = vmFor('co');
      await settle();

      await vm.setCustomFilter(columnIndex: 2, values: {'VIP'});
      await settle();

      expect(vm.customFilters[2], {'VIP'});
      expect(vm.loadedPages, 1);
    });

    test('setCustomFilter with empty set removes that column', () async {
      api.pages[1] = [_row('c1')];
      final vm = vmFor('co');
      await settle();
      await vm.setCustomFilter(columnIndex: 1, values: {'A'});
      await settle();
      expect(vm.customFilters.containsKey(1), isTrue);

      await vm.setCustomFilter(columnIndex: 1, values: const {});
      await settle();
      expect(vm.customFilters.containsKey(1), isFalse);
    });
  });

  group('clearAllFilters', () {
    test('returns the VM to defaults and re-fetches', () async {
      api.pages[1] = [_row('c1')];
      final vm = vmFor('co');
      await settle();
      await vm.setStates({EntityState.archived});
      await vm.setSort(field: ClientFieldIds.balance, ascending: false);
      await vm.setCustomFilter(columnIndex: 3, values: {'X'});
      await settle();
      api.calls.clear();

      await vm.clearAllFilters();
      await settle();

      // clearAllFilters resets state to the default `{active}` (not `{}`):
      // "clear filters" means "show me the normal list", which for state is
      // active-only. The lone removable "State: Active" chip is expected; the
      // clear button hides itself in that case so it doesn't read as a filter.
      expect(vm.states, {EntityState.active});
      expect(vm.sortField, ClientFieldIds.name);
      expect(vm.sortAscending, isTrue);
      expect(vm.customFilters, isEmpty);
      expect(api.calls, isNotEmpty);
    });

    test('is a no-op when everything is already cleared', () async {
      api.pages[1] = [_row('c1')];
      final vm = vmFor('co');
      await settle();

      // Move off the cleared target so the first clear is a real change
      // (archived → the default {active}) and reloads. The *second* clear
      // is the genuine no-op: nothing differs from its cleared target —
      // {active}, default sort, no custom/extra filters — so no API call.
      await vm.setStates({EntityState.archived});
      await settle();
      api.calls.clear();

      await vm.clearAllFilters();
      await settle();
      expect(vm.states, {EntityState.active});
      expect(api.calls, isNotEmpty);
      api.calls.clear();

      await vm.clearAllFilters();
      await settle();

      expect(api.calls, isEmpty);
    });
  });

  group('hasActiveFilters', () {
    test('false at defaults, true after any change', () async {
      api.pages[1] = [_row('c1')];
      final vm = vmFor('co');
      await settle();
      expect(vm.hasActiveFilters, isFalse);

      await vm.setStates({EntityState.archived});
      await settle();
      expect(vm.hasActiveFilters, isTrue);

      await vm.clearAllFilters();
      await settle();
      expect(vm.hasActiveFilters, isFalse);
    });
  });

  group('persistence', () {
    test(
      'company-scoped filters round-trip through nav_state.filters_json',
      () async {
        api.pages[1] = [_row('c1')];
        final vm = vmFor('co-A');
        await settle();
        await vm.setStates({EntityState.archived});
        await vm.setSort(field: ClientFieldIds.balance, ascending: false);
        // Wait past the 1 ms persist debounce.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await settle();
        vm.dispose();

        // A second VM for the SAME company should rehydrate the filters.
        api.pages[1] = [_row('c1')];
        final vm2 = vmFor('co-A');
        await settle();
        expect(vm2.states, {EntityState.archived});
        expect(vm2.sortField, ClientFieldIds.balance);
        expect(vm2.sortAscending, isFalse);
        vm2.dispose();
      },
    );

    test('company switch surfaces a different filter blob', () async {
      // Seed a stored blob for company B; company A has none yet.
      await db.navStateDao.saveFilters(
        filtersJson: jsonEncode({
          'co-B': {
            // Singular `client` matches `EntityType.client.name` — the
            // generic list VM persists under the entity-type token.
            'client': {
              'states': ['deleted'],
              'sortField': 'updated_at',
              'sortAscending': false,
              'customFilters': <String, dynamic>{},
              'search': '',
            },
          },
        }),
        now: 0,
      );

      api.pages[1] = [_row('c1')];
      final vmA = vmFor('co-A');
      await settle();
      expect(vmA.states, {EntityState.active}, reason: 'co-A defaults');
      vmA.dispose();

      api.pages[1] = [_row('c1')];
      final vmB = vmFor('co-B');
      await settle();
      expect(vmB.states, {EntityState.deleted});
      expect(vmB.sortField, ClientFieldIds.updatedAt);
      expect(vmB.sortAscending, isFalse);
      vmB.dispose();
    });

    test(
      'corrupt filters_json is treated as no saved state — VM uses defaults',
      () async {
        await db.navStateDao.saveFilters(
          filtersJson: 'not even close to JSON {',
          now: 0,
        );
        api.pages[1] = [_row('c1')];
        final vm = vmFor('co');
        await settle();
        expect(vm.states, {EntityState.active});
        expect(vm.sortField, ClientFieldIds.name);
        vm.dispose();
      },
    );
  });

  group('search', () {
    test(
      'setSearch resets loadedPages and routes the term to the API',
      () async {
        api.pages[1] = [for (var i = 0; i < 50; i++) _row('c$i')];
        api.pages[2] = [_row('c50')];
        final vm = vmFor('co');
        await settle();
        await vm.loadMore();
        await settle();
        expect(vm.loadedPages, 2);

        // Now searching — the next API call should carry the term and
        // loadedPages should reset to 1.
        api.calls.clear();
        api.pages[1] = [_row('c_match', name: 'Acme')];
        vm.setSearch('acme');
        await settle();
        // Give the 1 ms debounce time to fire.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await settle();

        expect(vm.loadedPages, 1);
        expect(api.calls, hasLength(1));
        expect(api.calls.single.search, 'acme');
        vm.dispose();
      },
    );
  });

  group('selectedItems (selection-level bulk actions)', () {
    test('returns selected items in list order, ignoring stale ids', () async {
      api.pages[1] = [_row('c1'), _row('c2'), _row('c3')];
      final vm = vmFor('co');
      await settle();

      // Select out of order; a stale id (not in the list) is ignored.
      vm.toggleSelected('c3');
      vm.toggleSelected('c1');
      vm.toggleSelected('ghost');

      expect(vm.selectedItems.map((c) => c.id), ['c1', 'c3']);
      vm.dispose();
    });

    test('is empty when nothing is selected', () async {
      api.pages[1] = [_row('c1')];
      final vm = vmFor('co');
      await settle();
      expect(vm.selectedItems, isEmpty);
      vm.dispose();
    });
  });

  // invoiceninja/flutter#119. The `overdue` tab's Drift predicate is a subquery
  // over the LOCAL invoices table, and login prefetches page 1 only — so the
  // tab read 0 over a false "No records found" on any account whose overdue
  // invoices weren't among the 50 newest, while the auto-chain paged through
  // clients for matches that could not appear. The VM pulls that slice itself.
  group('overdue tab hydration (#119)', () {
    test(
      'pulls the overdue slice with the filter the Invoices tab sends',
      () async {
        api.pages[1] = [_row('c1')];
        final vm = vmFor('co');
        await settle();
        expect(invoiceApi.calls, isEmpty, reason: 'All tab hydrates nothing');

        await vm.setBadgeMode('overdue');
        await settle();

        expect(invoiceApi.calls, hasLength(1));
        expect(invoiceApi.calls.single.filters['overdue'], 'true');
        expect(
          invoiceApi.calls.single.filters['status'],
          'active',
          reason: 'the client subquery only counts active invoices',
        );
        vm.dispose();
      },
    );

    test('never reads or advances the shared invoice delta cursor', () async {
      // A narrowed fetch that moved the watermark would walk it past every
      // invoice the filter excluded — flutter#32's failure, one entity over.
      api.pages[1] = [_row('c1')];
      final vm = vmFor('co');
      await settle();
      await vm.setBadgeMode('overdue');
      await settle();

      expect(invoiceApi.calls.single.since, isNull);
      final cursor = await db.syncStateDao.read(
        companyId: 'co',
        entityType: 'invoice',
      );
      expect(cursor.isEmpty, isTrue);
      vm.dispose();
    });

    test(
      'surfaces the client whose invoice the hydration just pulled in',
      () async {
        // The regression guard for the whole issue: nothing re-subscribes the
        // clients watch, so this only passes because drift puts the subquery's
        // table in the outer query's readsFrom set.
        api.pages[1] = [_row('c1'), _row('c2')];
        invoiceApi.pages[1] = [_overdueInvoice('i1', clientId: 'c1')];
        final vm = vmFor('co');
        await settle();
        expect(vm.items.map((c) => c.id), ['c1', 'c2']);

        await vm.setBadgeMode('overdue');
        await settle();

        expect(vm.items.map((c) => c.id), ['c1']);
        vm.dispose();
      },
    );

    test('is bounded — a server with endless overdue invoices does not page '
        'forever', () async {
      api.pages[1] = [_row('c1')];
      for (var page = 1; page <= 8; page++) {
        invoiceApi.pages[page] = [
          for (var i = 0; i < 50; i++)
            _overdueInvoice('p$page-i$i', clientId: 'c1'),
        ];
      }
      final vm = vmFor('co');
      await settle();
      await vm.setBadgeMode('overdue');
      await settle();

      expect(invoiceApi.calls, hasLength(5));
      vm.dispose();
    });

    test(
      'runs once — a later reset on the same tab does not re-fetch',
      () async {
        api.pages[1] = [_row('c1')];
        final vm = vmFor('co');
        await settle();
        await vm.setBadgeMode('overdue');
        await settle();
        expect(invoiceApi.calls, hasLength(1));

        final clientCallsBefore = api.calls.length;

        vm.setSearch('acme');
        await settle();
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await settle();

        // Prove the reset actually happened before reading anything into the
        // invoice count — otherwise a debounce that didn't fire would make
        // this test pass while exercising nothing.
        expect(api.calls.length, greaterThan(clientCallsBefore));
        expect(api.calls.last.search, 'acme');
        expect(invoiceApi.calls, hasLength(1));
        vm.dispose();
      },
    );

    test(
      'a failing hydration degrades the tab instead of failing the list',
      () async {
        api.pages[1] = [_row('c1')];
        invoiceApi.nextError = Exception('boom');
        final vm = vmFor('co');
        await settle();
        await vm.setBadgeMode('overdue');
        await settle();

        expect(vm.initialError, isNull);
        expect(api.calls, isNotEmpty, reason: 'the clients fetch still ran');
        expect(
          invoiceApi.calls,
          hasLength(1),
          reason: 'the walk stops at the throw rather than trying page 2',
        );
        vm.dispose();
      },
    );

    test('a failed attempt is retried on the next reset', () async {
      // The latch is a concurrency guard, not a circuit breaker: the auto-chain
      // can't reach the hydration (it only ever fetches page >= 2), so there is
      // no storm to protect against and an offline blip should heal on the
      // user's next interaction rather than needing a pull-to-refresh.
      api.pages[1] = [_row('c1')];
      invoiceApi.nextError = Exception('offline');
      final vm = vmFor('co');
      await settle();
      await vm.setBadgeMode('overdue');
      await settle();
      expect(invoiceApi.calls, hasLength(1));

      vm.setSearch('acme');
      await settle();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await settle();

      expect(api.calls.last.search, 'acme', reason: 'the reset really ran');
      expect(invoiceApi.calls, hasLength(2));
      vm.dispose();
    });

    test('does not fire for the Outstanding tab', () async {
      api.pages[1] = [_row('c1')];
      final vm = vmFor('co');
      await settle();
      await vm.setBadgeMode('outstanding');
      await settle();

      expect(invoiceApi.calls, isEmpty);
      vm.dispose();
    });

    test('pull-to-refresh re-arms it', () async {
      // Refreshing Clients refreshes clients, so an invoice settled elsewhere
      // would otherwise leave its client stuck under Overdue.
      api.pages[1] = [_row('c1')];
      final vm = vmFor('co');
      await settle();
      await vm.setBadgeMode('overdue');
      await settle();
      expect(invoiceApi.calls, hasLength(1));

      await vm.refresh();
      await settle();

      expect(invoiceApi.calls, hasLength(2));
      vm.dispose();
    });
  });

  group('clients-in-group scope (embedded tab)', () {
    ClientListViewModel scopedVm(String companyId, String groupId) =>
        ClientListViewModel(
          repo: repo,
          invoices: invoiceRepo,
          navStateDao: db.navStateDao,
          userSettings: UserSettingsRepository(db: db),
          companyId: companyId,
          groupSettingsId: groupId,
          searchDebounce: const Duration(milliseconds: 1),
          persistDebounce: const Duration(milliseconds: 1),
        );

    test('skips the network fetch so the shared client cursor is not '
        'advanced', () async {
      api.pages[1] = [_row('c1')];
      final vm = scopedVm('co', 'g1');
      await settle();
      // The embedded group tab serves from the already-synced local cache —
      // no ensurePageLoaded call that would corrupt the main list's delta
      // cursor with a `group=` filter.
      expect(api.calls, isEmpty);
      // Nor may the #119 overdue hydration run here — it sits BELOW the
      // early return, and moving it above would put a network fetch behind
      // every client detail page's Clients-in-group tab.
      expect(invoiceApi.calls, isEmpty);
      vm.dispose();
    });

    test(
      'exposes a locked "group" filter so the scope cannot be cleared',
      () async {
        final vm = scopedVm('co', 'g1');
        await settle();
        expect(vm.lockedFilterKeyIds, contains('group'));
        vm.dispose();
      },
    );
  });
}
