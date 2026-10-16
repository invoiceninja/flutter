import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/quote_api_model.dart';
import 'package:admin/data/repositories/quote_repository.dart';
import 'package:admin/data/services/quotes_api.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Several picked clients reach the server as `client_ids`, never as a
/// comma-joined `client_id`.
///
/// `QueryFilters::client_id` decodes ONE hashid, so `client_id=a,b` fails to
/// decode and every list answered it with zero rows — measured on
/// demo.invoiceninja.com (5.13.47) for all nine client-scoped lists, while
/// `client_ids=a,b` returned the sum of the two. The repository is the seam
/// because every list fetch goes through `ensurePageLoadedTemplate`; quotes
/// stand in for the other seven.
class _CapturingQuotesApi implements QuotesApi {
  final List<Map<String, String>> calls = [];

  @override
  Future<({QuoteListApi data, int? cursorUpdatedAt, String? cursorId})> list({
    required int page,
    int perPage = 50,
    String? search,
    int? sinceUpdatedAt,
    String? sinceId,
    Map<String, String> filters = const {},
  }) async {
    calls.add(filters);
    return (
      data: const QuoteListApi(data: []),
      cursorUpdatedAt: null,
      cursorId: null,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  late _CapturingQuotesApi api;
  late QuoteRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = _CapturingQuotesApi();
    repo = QuoteRepository(db: db, api: api);
  });
  tearDown(() => db.close());

  Future<Map<String, String>> fetch(Map<String, Set<String>> extra) async {
    await repo.ensurePageLoaded(companyId: 'co', page: 1, extraFilters: extra);
    return api.calls.single;
  }

  test('two clients go on the wire as client_ids', () async {
    final filters = await fetch(const {
      'client_id': {'b', 'a'},
    });
    expect(filters['client_ids'], 'a,b');
    expect(filters.containsKey('client_id'), isFalse);
  });

  test('one client stays client_id', () async {
    final filters = await fetch(const {
      'client_id': {'a'},
    });
    expect(filters['client_id'], 'a');
    expect(filters.containsKey('client_ids'), isFalse);
  });

  test('several clients merge into an existing client_ids', () async {
    final filters = await fetch(const {
      'client_id': {'a', 'b'},
      'client_ids': {'c'},
    });
    expect(filters['client_ids'], 'a,b,c');
    expect(filters.containsKey('client_id'), isFalse);
  });

  test('a client created offline is left off a scope that has real ones — '
      'its tmp_ id would not decode', () async {
    final filters = await fetch(const {
      'client_id': {'a', 'tmp_1', 'b'},
    });
    expect(filters['client_ids'], 'a,b');
  });

  test('a client scope still keeps the deleted-clients guard off', () async {
    final filters = await fetch(const {
      'client_id': {'a', 'b'},
    });
    expect(filters.containsKey('without_deleted_clients'), isFalse);
  });

  test('no client scope leaves the guard on', () async {
    final filters = await fetch(const {});
    expect(filters['without_deleted_clients'], 'true');
  });
}
