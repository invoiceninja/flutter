// Two things that ride on what a server row stores as its Drift payload
// (`jsonEncode(QuoteApi.toJson())`), so both are tested through a real fetch
// into a real database rather than a parse:
//
// - the line fields the app does not model survive into storage and back out
//   to the wire — the first cut kept them through a parse but `toJson`, which
//   is what gets stored, dropped them, so the next edit still wiped them;
// - whether the server models optional lines (`is_optional`), which is read
//   from those stored payloads: its line cleaner writes `false` on every line
//   once the field exists, and nothing else ever writes a `false`.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/line_item_api_model.dart';
import 'package:admin/data/models/api/quote_api_model.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/repositories/quote_repository.dart';
import 'package:admin/data/services/quotes_api.dart';

class _FakeQuotesApi implements QuotesApi {
  _FakeQuotesApi(this.rows);
  final List<QuoteApi> rows;

  @override
  Future<({QuoteListApi data, int? cursorUpdatedAt, String? cursorId})> list({
    required int page,
    int perPage = 50,
    String? search,
    int? sinceUpdatedAt,
    String? sinceId,
    Map<String, String> filters = const {},
  }) async => (
    data: QuoteListApi(data: page == 1 ? rows : const []),
    cursorUpdatedAt: null,
    cursorId: null,
  );

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

QuoteApi _quote(String id, Map<String, dynamic> line) => QuoteApi.fromJson({
  'id': id,
  'number': id,
  'updated_at': 1000,
  'line_items': [
    {
      'product_key': 'SVC',
      'notes': 'Service',
      'cost': 100,
      'quantity': 1,
      'type_id': '1',
      ...line,
    },
  ],
});

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<QuoteRepository> loaded(List<QuoteApi> rows) async {
    final repo = QuoteRepository(db: db, api: _FakeQuotesApi(rows));
    await repo.ensurePageLoaded(companyId: 'co', page: 1);
    return repo;
  }

  test('unmodelled line fields survive storage and reach the wire', () async {
    final repo = await loaded([
      _quote('q1', {
        'unit_code': 'HUR',
        'income_account_id': 'qb-41',
        'tags': 'urgent',
        'line_total': 100, // server-computed: not carried
      }),
    ]);
    final quote = await repo.watch(companyId: 'co', id: 'q1').first;
    final line = quote!.lineItems.single;

    expect(line.extra, {
      'unit_code': 'HUR',
      'income_account_id': 'qb-41',
      'tags': 'urgent',
    });
    final wire = line.toApiJson();
    expect(wire['unit_code'], 'HUR');
    expect(wire['income_account_id'], 'qb-41');
    // The storage key is local: never sent, never nested.
    expect(wire.containsKey(kLineItemExtraKey), isFalse);
    expect(wire.containsKey('line_total'), isFalse);
  });

  group('serverModelsOptionalLines', () {
    test('a line the server wrote with is_optional: false proves it', () async {
      final repo = await loaded([
        _quote('q1', {'is_optional': false}),
      ]);
      expect(await repo.serverModelsOptionalLines(companyId: 'co'), isTrue);
      // …and the scope is the company's.
      expect(await repo.serverModelsOptionalLines(companyId: 'other'), isFalse);
    });

    test('no key at all — today\'s server — is not support', () async {
      final repo = await loaded([_quote('q1', {})]);
      expect(await repo.serverModelsOptionalLines(companyId: 'co'), isFalse);
    });

    test(
      'a `true` is not proof: an older server keeps whatever it is sent',
      () async {
        final repo = await loaded([
          _quote('q1', {'is_optional': true}),
        ]);
        expect(await repo.serverModelsOptionalLines(companyId: 'co'), isFalse);
        final quote = await repo.watch(companyId: 'co', id: 'q1').first;
        expect(quote!.lineItems.single.isOptional, isTrue);
      },
    );

    test('the app\'s own payload never carries a false', () {
      // What a local edit stores (`_domainToCompanion` → `toApiJson`).
      final json = emptyLineItem().copyWith(isOptional: false).toApiJson();
      expect(json.containsKey('is_optional'), isFalse);
    });
  });

  // Review finding: `payload LIKE '%…%'` can use no index, and a server
  // without the field never matches, so the probe reads only the newest rows —
  // where a record written after the server upgrade always is.
  test('the probe reads only the most recently updated rows', () async {
    await loaded([
      _quote('old', {'is_optional': false}).copyWith(updatedAt: 1),
      _quote('new', {}).copyWith(updatedAt: 2),
    ]);
    Future<bool> probe(int recent) => db.quoteDao.anyPayloadContains(
      companyId: 'co',
      fragment: kServerOptionalLineMarker,
      recent: recent,
    );
    expect(await probe(1), isFalse);
    expect(await probe(2), isTrue);
  });
}
