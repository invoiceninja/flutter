import 'dart:convert';
import 'dart:io';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/quote_api_model.dart';
import 'package:admin/data/models/domain/quote.dart';
import 'package:admin/data/repositories/quote_repository.dart';
import 'package:admin/data/services/quotes_api.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '_base_entity_repository_contract.dart';

/// Closes a standing coverage gap (there was no quote repository test, and
/// quotes weren't in the shared contract). Beyond the universal contract,
/// the entity-specific groups feed a **recorded live demo `/api/v1/quotes`
/// page** (25 rows, `test/fixtures/quotes_demo_page1.json`) through the real
/// `QuoteListApi.fromJson` → `Quote.fromApi` → Drift → `watchPage` path so a
/// parse-throw or filter-drop that only the live data shape triggers fails
/// here, deterministically and offline — instead of silently surfacing as an
/// empty `/quotes` list in the demo integration suite.

class _FakeQuotesApi implements QuotesApi {
  _FakeQuotesApi(this._pages);

  final Map<int, List<QuoteApi>> _pages;

  @override
  Future<({QuoteListApi data, int? cursorUpdatedAt, String? cursorId})> list({
    required int page,
    int perPage = 50,
    String? search,
    int? sinceUpdatedAt,
    String? sinceId,
    Map<String, String> filters = const {},
  }) async {
    final rows = _pages[page] ?? <QuoteApi>[];
    return (
      data: QuoteListApi(data: rows),
      cursorUpdatedAt: rows.isNotEmpty ? rows.last.updatedAt : null,
      cursorId: rows.isNotEmpty ? rows.last.id : null,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Records the cursor params each `list` call received and lets a test set the
/// rows the next call returns — so a test can assert whether a fetch read /
/// advanced the keyset cursor.
class _CapturingQuotesApi implements QuotesApi {
  List<QuoteApi> next = const [];
  int? lastSinceUpdatedAt;
  String? lastSinceId;
  String? lastSearch;

  @override
  Future<({QuoteListApi data, int? cursorUpdatedAt, String? cursorId})> list({
    required int page,
    int perPage = 50,
    String? search,
    int? sinceUpdatedAt,
    String? sinceId,
    Map<String, String> filters = const {},
  }) async {
    lastSinceUpdatedAt = sinceUpdatedAt;
    lastSinceId = sinceId;
    lastSearch = search;
    final rows = next;
    return (
      data: QuoteListApi(data: rows),
      cursorUpdatedAt: rows.isNotEmpty ? rows.last.updatedAt : null,
      cursorId: rows.isNotEmpty ? rows.last.id : null,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

List<QuoteApi> _recordedDemoQuotes() {
  final raw = File('test/fixtures/quotes_demo_page1.json').readAsStringSync();
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return QuoteListApi.fromJson(json).data;
}

void main() {
  runEntityRepositoryContract(
    EntityRepositoryContractFixture<Quote, QuoteApi>.build(
      entityType: 'quote',
      updatedAtOf: (item) => item.updatedAt,
      buildRepo: (db) => QuoteRepository(db: db, api: _FakeQuotesApi(const {})),
      buildApiModel: ({required id, displayValue, updatedAt = 1700000000}) =>
          QuoteApi(id: id, number: displayValue ?? id, updatedAt: updatedAt),
      fromApi: Quote.fromApi,
      editCopy: (item, {required displayValue}) =>
          item.copyWith(number: displayValue),
      idOf: (q) => q.id,
      isDirtyOf: (q) => q.isDirty,
      create: (repo, {required companyId, required draft}) =>
          (repo as QuoteRepository).create(companyId: companyId, draft: draft),
      save: (repo, {required companyId, required entity}) =>
          (repo as QuoteRepository).save(companyId: companyId, quote: entity),
      delete: (repo, {required companyId, required id}) =>
          (repo as QuoteRepository).delete(companyId: companyId, id: id),
    ),
  );

  group('QuoteRepository — recorded live demo payload', () {
    test('every recorded demo quote row maps through Quote.fromApi without '
        'throwing (a parse-throw here = silent empty /quotes list)', () {
      final rows = _recordedDemoQuotes();
      expect(rows, hasLength(25), reason: 'fixture should hold the live page');
      for (final a in rows) {
        expect(
          () => Quote.fromApi(a),
          returnsNormally,
          reason:
              'Quote.fromApi threw on demo quote id=${a.id} '
              'status_id=${a.statusId}',
        );
      }
    });

    test('ensurePageLoaded → watchPage surfaces all 25 rows under the '
        'default {EntityState.active} filter', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = QuoteRepository(
        db: db,
        api: _FakeQuotesApi({1: _recordedDemoQuotes()}),
      );

      await repo.ensurePageLoaded(companyId: 'co', page: 1);

      final rows = await repo
          .watchPage(
            companyId: 'co',
            loadedPages: 1,
            states: const {EntityState.active},
          )
          .first;

      expect(
        rows,
        hasLength(25),
        reason:
            'all active demo quotes must survive upsert + watchPage; '
            'a shortfall is the demo-suite "0 QuoteListTile" bug reproduced',
      );
    });
  });

  group('QuoteRepository — search bypasses the keyset cursor (H1)', () {
    test('a normal page-1 fetch advances the cursor; a search fetch neither '
        'reads nor advances it', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = _CapturingQuotesApi();
      final repo = QuoteRepository(db: db, api: api);

      // 1) Normal page-1 fetch: no prior cursor to read, but it ADVANCES the
      //    cursor to data.last.
      api.next = [QuoteApi(id: 'q-normal', number: 'Q-N', updatedAt: 1000)];
      await repo.ensurePageLoaded(companyId: 'co', page: 1);
      expect(api.lastSinceUpdatedAt, isNull);
      final afterNormal = await db.syncStateDao.read(
        companyId: 'co',
        entityType: 'quote',
      );
      expect(afterNormal.updatedAt, 1000, reason: 'normal fetch advances');
      expect(afterNormal.id, 'q-normal');

      // 2) Search fetch (page 1, ignoreCursor:true — what the VM now passes for
      //    a non-empty search). It must NOT send the since-cursor set in step 1
      //    (search looks across full history), and must NOT advance the global
      //    cursor to its search-scoped watermark (5000).
      api.next = [QuoteApi(id: 'q-search', number: 'Q-S', updatedAt: 5000)];
      await repo.ensurePageLoaded(
        companyId: 'co',
        page: 1,
        search: 'acme',
        ignoreCursor: true,
      );
      expect(api.lastSearch, 'acme');
      expect(
        api.lastSinceUpdatedAt,
        isNull,
        reason: 'search must look across full history, not the delta window',
      );
      final afterSearch = await db.syncStateDao.read(
        companyId: 'co',
        entityType: 'quote',
      );
      expect(
        afterSearch.updatedAt,
        1000,
        reason: 'a search-scoped data.last must not corrupt the global cursor',
      );
      expect(afterSearch.id, 'q-normal');
    });
  });
}
