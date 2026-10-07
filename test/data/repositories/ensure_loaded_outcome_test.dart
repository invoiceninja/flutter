import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/ensure_loaded_outcome.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/clients_api.dart';

/// `ensureLoaded` says what happened, so a detail screen can tell "the server
/// has no such record" from "the server could not be reached".
class _Api implements ClientsApi {
  _Api(this.onGet);

  final Future<ClientItemApi> Function(String id) onGet;
  int gets = 0;

  @override
  Future<ClientItemApi> get(String id) {
    gets++;
    return onGet(id);
  }

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected API call: ${invocation.memberName}');
}

ClientItemApi _item(String id) => ClientItemApi(
  data: ClientApi(id: id, name: 'Acme', updatedAt: 1),
);

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<EnsureLoadedOutcome> load(ClientRepository repo, String id) =>
      repo.ensureLoaded(companyId: 'co', id: id);

  test('fetched, then cached without a second request', () async {
    final api = _Api((id) async => _item(id));
    final repo = ClientRepository(db: db, api: api);
    expect(await load(repo, 'c1'), EnsureLoadedOutcome.fetched);
    expect(await load(repo, 'c1'), EnsureLoadedOutcome.cached);
    expect(api.gets, 1);
  });

  test(
    'a network failure is unreachable, and is tried again next time',
    () async {
      final api = _Api((id) async => throw const NetworkException('offline'));
      final repo = ClientRepository(db: db, api: api);
      expect(await load(repo, 'c1'), EnsureLoadedOutcome.unreachable);
      expect(await load(repo, 'c1'), EnsureLoadedOutcome.unreachable);
      expect(api.gets, 2, reason: 'not negative-cached');
    },
  );

  test('"never sent" is unreachable too', () async {
    final api = _Api(
      (id) async => throw const RequestNotSentException('no route to host'),
    );
    final repo = ClientRepository(db: db, api: api);
    expect(await load(repo, 'c1'), EnsureLoadedOutcome.unreachable);
  });

  test(
    'the server saying "no such record" is missing, and is remembered',
    () async {
      final api = _Api((id) async => throw const NotFoundException());
      final repo = ClientRepository(db: db, api: api);
      expect(await load(repo, 'c1'), EnsureLoadedOutcome.missing);
      expect(await load(repo, 'c1'), EnsureLoadedOutcome.missing);
      expect(api.gets, 1, reason: 'negative-cached for the session');
    },
  );

  test(
    'a record this user may not see is missing too, and is remembered',
    () async {
      // The server's 401 for a policy refusal — including a record that belongs
      // to another company, which is what a screen left mounted across a company
      // switch asks about. To the screen it is simply not there; asking again
      // would get the same answer.
      final api = _Api((id) async => throw const PermissionDeniedException());
      final repo = ClientRepository(db: db, api: api);
      expect(await load(repo, 'c1'), EnsureLoadedOutcome.missing);
      expect(await load(repo, 'c1'), EnsureLoadedOutcome.missing);
      expect(api.gets, 1);
    },
  );

  test('any other answer is a failure, and is tried again next time', () async {
    final api = _Api((id) async => throw const ServerException(503));
    final repo = ClientRepository(db: db, api: api);
    expect(await load(repo, 'c1'), EnsureLoadedOutcome.failed);
    expect(await load(repo, 'c1'), EnsureLoadedOutcome.failed);
    expect(api.gets, 2);
  });

  test('a local-only or empty id is skipped without a request', () async {
    final api = _Api((id) async => _item(id));
    final repo = ClientRepository(db: db, api: api);
    expect(await load(repo, 'tmp_abc'), EnsureLoadedOutcome.skipped);
    expect(await load(repo, ''), EnsureLoadedOutcome.skipped);
    expect(api.gets, 0);
  });

  test('only the retryable outcomes say so', () {
    expect(EnsureLoadedOutcome.unreachable.isRetryable, isTrue);
    expect(EnsureLoadedOutcome.failed.isRetryable, isTrue);
    for (final o in [
      EnsureLoadedOutcome.cached,
      EnsureLoadedOutcome.fetched,
      EnsureLoadedOutcome.missing,
      EnsureLoadedOutcome.skipped,
    ]) {
      expect(o.isRetryable, isFalse, reason: o.name);
    }
  });
}
