import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/data/services/invoices_api.dart';
import 'package:admin/domain/entity_state.dart';

/// The two paging rules every repo shares, and the fact that the repos which
/// hand-roll their own `ensurePageLoaded` body actually apply them.
///
/// Both rules were originally fixed on `ensurePageLoadedTemplate` only — but
/// six repos (invoice, quote, credit, recurring invoice, purchase order, group
/// setting) don't use the template, so the fixes silently missed the busiest
/// lists in the app. Hence the direct rule tests *plus* an invoice-level one.
class _FakeInvoicesApi implements InvoicesApi {
  _FakeInvoicesApi(this._pages);

  final Map<int, List<InvoiceApi>> _pages;
  final List<({int page, int? since})> calls = [];

  @override
  Future<({InvoiceListApi data, int? cursorUpdatedAt, String? cursorId})> list({
    required int page,
    int perPage = 50,
    String? search,
    int? sinceUpdatedAt,
    String? sinceId,
    Map<String, String> filters = const {},
  }) async {
    calls.add((page: page, since: sinceUpdatedAt));
    final rows = _pages[page] ?? <InvoiceApi>[];
    return (
      data: InvoiceListApi(data: rows),
      cursorUpdatedAt: rows.isNotEmpty ? rows.last.updatedAt : null,
      cursorId: rows.isNotEmpty ? rows.last.id : null,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  late InvoiceRepository repo;
  late _FakeInvoicesApi api;

  void build({Map<int, List<InvoiceApi>> pages = const {}}) {
    api = _FakeInvoicesApi(pages);
    repo = InvoiceRepository(
      db: db,
      api: api,
      settings: SettingsRepository(db: db),
    );
  }

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    build();
  });
  tearDown(() async => db.close());

  group('hasMoreAfterPage', () {
    test('a cursor-narrowed page always defers the decision — an empty or '
        'short DELTA is not end-of-list', () {
      expect(
        repo.hasMoreAfterPage(rowCount: 0, cursorApplied: true, pageSize: 50),
        isTrue,
      );
      expect(
        repo.hasMoreAfterPage(rowCount: 3, cursorApplied: true, pageSize: 50),
        isTrue,
      );
    });

    test('a cursorless page concludes from the row count', () {
      expect(
        repo.hasMoreAfterPage(rowCount: 0, cursorApplied: false, pageSize: 50),
        isFalse,
      );
      expect(
        repo.hasMoreAfterPage(rowCount: 49, cursorApplied: false, pageSize: 50),
        isFalse,
      );
      expect(
        repo.hasMoreAfterPage(rowCount: 50, cursorApplied: false, pageSize: 50),
        isTrue,
      );
    });
  });

  group('shouldAdvanceCursor', () {
    bool advance({
      int page = 1,
      bool hasParentScope = false,
      bool isSearchScoped = false,
      Set<EntityState> states = const {EntityState.active},
      Map<String, Set<String>> extraFilters = const {},
    }) => repo.shouldAdvanceCursor(
      page: page,
      hasParentScope: hasParentScope,
      isSearchScoped: isSearchScoped,
      states: states,
      extraFilters: extraFilters,
    );

    test('the plain page-1 list view advances', () {
      expect(advance(), isTrue);
    });

    test('the WIDEST fetch advances — every refreshAll passes all states, and '
        'that is what stamps lastFullSyncAt on a forced full resync', () {
      expect(advance(states: EntityState.values.toSet()), isTrue);
      expect(advance(states: const {}), isTrue);
    });

    test('a narrowed state slice does NOT advance', () {
      expect(advance(states: const {EntityState.archived}), isFalse);
      expect(
        advance(states: const {EntityState.active, EntityState.archived}),
        isFalse,
      );
    });

    test('any user filter blocks the advance — `data.last` from a filtered '
        'page is a high-water mark for that SLICE only', () {
      expect(
        advance(
          extraFilters: {
            'country_id': {'840'},
          },
        ),
        isFalse,
      );
      // An empty value set is not a filter.
      expect(advance(extraFilters: {'country_id': <String>{}}), isTrue);
    });

    test('parent scope, search and page >= 2 all block the advance', () {
      expect(advance(hasParentScope: true), isFalse);
      expect(advance(isSearchScoped: true), isFalse);
      expect(advance(page: 2), isFalse);
    });
  });

  // The READ gate used to ignore `extraFilters` and `states` while the ADVANCE
  // gate honoured both. A filter chip therefore fetched page 1 with the
  // `updated_at >= W` watermark ANDed onto the filter, so the server returned
  // only slice rows changed since the last sync — and after a full resync (W ≈
  // now) it returned nothing at all, leaving a false "No records found" a short
  // list has no scroll extent to page out of. flutter#32.
  group('shouldReadCursor', () {
    bool read({
      bool ignoreCursor = false,
      int page = 1,
      bool hasParentScope = false,
      bool isSearchScoped = false,
      Set<EntityState> states = const {EntityState.active},
      Map<String, Set<String>> extraFilters = const {},
    }) => repo.shouldReadCursor(
      ignoreCursor: ignoreCursor,
      page: page,
      hasParentScope: hasParentScope,
      isSearchScoped: isSearchScoped,
      states: states,
      extraFilters: extraFilters,
    );

    test('the plain page-1 list view reads the cursor — the delta fast path '
        'every warm cold-start depends on stays intact', () {
      expect(read(), isTrue);
    });

    test('the WIDEST fetch reads it too — that is refreshAll, which must stay '
        'a delta pull when `full: false`', () {
      expect(read(states: EntityState.values.toSet()), isTrue);
      expect(read(states: const {}), isTrue);
    });

    test('any user filter blocks the read — otherwise the filter and the '
        'watermark are ANDed and older matches are never fetched', () {
      expect(
        read(
          extraFilters: {
            'client_status': {'paid'},
          },
        ),
        isFalse,
      );
      // An empty value set is not a filter.
      expect(read(extraFilters: {'client_status': <String>{}}), isTrue);
    });

    test('a narrowed state slice blocks the read', () {
      expect(read(states: const {EntityState.archived}), isFalse);
      expect(
        read(states: const {EntityState.active, EntityState.archived}),
        isFalse,
      );
    });

    test(
      'ignoreCursor, parent scope, search and page >= 2 all block the read',
      () {
        expect(read(ignoreCursor: true), isFalse);
        expect(read(hasParentScope: true), isFalse);
        expect(read(isSearchScoped: true), isFalse);
        expect(read(page: 2), isFalse);
      },
    );

    // The anti-drift guard: both gates now sit on `isNarrowedFetch`, and this
    // is what keeps them there. `page`/`ignoreCursor` are held at the one
    // combination where the two are supposed to agree.
    test('READ and ADVANCE agree on every narrowing combination — they drifted '
        'apart once and that was the bug', () {
      const stateSets = <Set<EntityState>>[
        {EntityState.active},
        {EntityState.archived},
        {EntityState.active, EntityState.archived},
        {},
      ];
      final filterSets = <Map<String, Set<String>>>[
        const {},
        {
          'client_status': {'paid'},
        },
        {'client_status': <String>{}},
      ];
      for (final parent in [false, true]) {
        for (final search in [false, true]) {
          for (final states in [...stateSets, EntityState.values.toSet()]) {
            for (final filters in filterSets) {
              expect(
                repo.shouldReadCursor(
                  ignoreCursor: false,
                  page: 1,
                  hasParentScope: parent,
                  isSearchScoped: search,
                  states: states,
                  extraFilters: filters,
                ),
                repo.shouldAdvanceCursor(
                  page: 1,
                  hasParentScope: parent,
                  isSearchScoped: search,
                  states: states,
                  extraFilters: filters,
                ),
                reason:
                    'parent=$parent search=$search states=$states '
                    'filters=$filters',
              );
            }
          }
        }
      }
    });
  });

  group('InvoiceRepository applies the shared rules (it hand-rolls its own '
      'ensurePageLoaded body)', () {
    test('an empty warm DELTA page keeps hasMore true, so the list is not '
        'capped at one page of the local cache', () async {
      await db.syncStateDao.writeCursor(
        companyId: 'co',
        entityType: 'invoice',
        updatedAt: 1700000000,
        id: 'i49',
        now: 1700000000,
      );
      build(pages: const {1: <InvoiceApi>[]});

      final hasMore = await repo.ensurePageLoaded(companyId: 'co', page: 1);

      expect(api.calls.single.since, isNotNull, reason: 'cursor was applied');
      expect(hasMore, isTrue);
    });

    test('a cold empty page 1 still concludes end-of-list', () async {
      build(pages: const {1: <InvoiceApi>[]});
      expect(await repo.ensurePageLoaded(companyId: 'co', page: 1), isFalse);
    });

    test('a filtered page-1 fetch does NOT move the shared watermark', () async {
      build(
        pages: {
          1: [InvoiceApi(id: 'i1', number: '1', updatedAt: 1800000000)],
        },
      );

      await repo.ensurePageLoaded(
        companyId: 'co',
        page: 1,
        extraFilters: {
          'client_status': {'paid'},
        },
      );

      final cursor = await db.syncStateDao.read(
        companyId: 'co',
        entityType: 'invoice',
      );
      expect(
        cursor.id,
        isNull,
        reason:
            'advancing from a filtered slice walks the watermark past rows the '
            'filter excluded, and the next unfiltered delta never refetches '
            'them',
      );
    });

    test('an unfiltered page-1 fetch does move the watermark', () async {
      build(
        pages: {
          1: [InvoiceApi(id: 'i1', number: '1', updatedAt: 1800000000)],
        },
      );

      await repo.ensurePageLoaded(companyId: 'co', page: 1);

      final cursor = await db.syncStateDao.read(
        companyId: 'co',
        entityType: 'invoice',
      );
      expect(cursor.id, 'i1');
    });

    // The flutter#32 regression assertions: with a warm watermark, a NARROWED
    // page 1 must go out un-narrowed by the cursor, or the server ANDs the two
    // and older matches never reach the local cache.
    Future<void> seedWarmCursor() => db.syncStateDao.writeCursor(
      companyId: 'co',
      entityType: 'invoice',
      updatedAt: 1700000000,
      id: 'i49',
      now: 1700000000,
    );

    test('a filtered page-1 fetch does NOT send the warm cursor', () async {
      await seedWarmCursor();
      build(pages: const {1: <InvoiceApi>[]});

      await repo.ensurePageLoaded(
        companyId: 'co',
        page: 1,
        extraFilters: {
          'client_status': {'paid'},
        },
      );

      expect(api.calls.single.since, isNull);
    });

    test('a narrowed state slice does NOT send the warm cursor', () async {
      await seedWarmCursor();
      build(pages: const {1: <InvoiceApi>[]});

      await repo.ensurePageLoaded(
        companyId: 'co',
        page: 1,
        states: const {EntityState.archived},
      );

      expect(api.calls.single.since, isNull);
    });

    test('the refreshAll shape (all states, no filters) still sends it — the '
        'delta pull must not become a full scan', () async {
      await seedWarmCursor();
      build(pages: const {1: <InvoiceApi>[]});

      await repo.ensurePageLoaded(
        companyId: 'co',
        page: 1,
        states: EntityState.values.toSet(),
      );

      expect(api.calls.single.since, isNotNull);
    });
  });
}
