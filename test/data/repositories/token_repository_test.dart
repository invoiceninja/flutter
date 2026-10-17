import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/token_api_model.dart';
import 'package:admin/data/models/domain/token.dart';
import 'package:admin/data/repositories/token_repository.dart';
import 'package:admin/data/services/tokens_api.dart';

import '_base_entity_repository_contract.dart';

void main() {
  runEntityRepositoryContract(
    EntityRepositoryContractFixture<Token, TokenApi>.build(
      entityType: 'token',
      buildRepo: (db) => TokenRepository(db: db, api: _FakeTokensApi()),
      buildApiModel:
          ({
            required String id,
            String? displayValue,
            int updatedAt = 1700000000,
          }) => TokenApi(
            id: id,
            name: displayValue ?? id,
            // List/refresh responses come masked (10 chars + 'xxxxxxxxxxx').
            token: 'cnm1dcvo01xxxxxxxxxxx',
            updatedAt: updatedAt,
          ),
      fromApi: Token.fromApi,
      editCopy: (item, {required String displayValue}) =>
          item.copyWith(name: displayValue),
      idOf: (item) => item.id,
      isDirtyOf: (item) => item.isDirty,
      create: (repo, {required companyId, required draft}) =>
          (repo as TokenRepository).create(companyId: companyId, draft: draft),
      save: (repo, {required companyId, required entity}) =>
          (repo as TokenRepository).save(companyId: companyId, token: entity),
      delete: (repo, {required companyId, required id}) =>
          (repo as TokenRepository).delete(companyId: companyId, id: id),
      // Server applies `password_protected` to token store/update/destroy.
      createRequiresPassword: true,
    ),
  );

  group('TokenRepository — entity-specific', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });
    tearDown(() async {
      await db.close();
    });

    TokenRepository makeRepo() =>
        TokenRepository(db: db, api: _FakeTokensApi());

    test('isMasked detects the server "xxxxxxxxxxx" suffix', () {
      final maskedToken = Token.fromApi(
        const TokenApi(id: 't_1', name: 'N', token: 'abc1234567xxxxxxxxxxx'),
      );
      expect(maskedToken.isMasked, isTrue);
      expect(maskedToken.tokenHint, 'abc1234567…');

      final raw = Token.fromApi(
        const TokenApi(id: 't_1', name: 'N', token: 'raw-bearer-secret-here'),
      );
      expect(raw.isMasked, isFalse);
    });

    test('toApiJson strips the read-only token and user_id fields', () {
      final t = Token.fromApi(
        const TokenApi(
          id: 't_1',
          name: 'My Token',
          token: 'abc1234567xxxxxxxxxxx',
          userId: 'u_1',
        ),
      );
      final json = t.toApiJson(preserveTempId: true);
      expect(json['name'], 'My Token');
      expect(json.containsKey('token'), isFalse);
      expect(json.containsKey('user_id'), isFalse);
    });

    test('toApiJson emits id only for real ids, never for tmp_ ids', () {
      final saved = Token.fromApi(const TokenApi(id: 't_1', name: 'N'));
      final tmp = saved.copyWith(id: 'tmp_abc');
      expect(saved.toApiJson()['id'], 't_1');
      expect(tmp.toApiJson().containsKey('id'), isFalse);
      expect(tmp.toApiJson(preserveTempId: true)['id'], 'tmp_abc');
    });

    test(
      'applyBundle upserts every row and advances the cursor to max updatedAt',
      () async {
        final repo = makeRepo();
        await repo.applyBundle(
          companyId: 'co',
          bundle: const [
            TokenApi(
              id: 't_a',
              name: 'Alpha',
              token: 'abc1234567xxxxxxxxxxx',
              updatedAt: 1700000100,
            ),
            TokenApi(
              id: 't_b',
              name: 'Beta',
              token: 'def4567890xxxxxxxxxxx',
              updatedAt: 1700000200,
            ),
          ],
        );
        final rows = await repo
            .watchPage(companyId: 'co', loadedPages: 4)
            .first;
        expect(rows.map((t) => t.id).toSet(), {'t_a', 't_b'});
        // Every persisted row should be the masked form.
        expect(rows.every((t) => t.isMasked), isTrue);
        final cursor = await db.syncStateDao.read(
          companyId: 'co',
          entityType: 'token',
        );
        expect(cursor.updatedAt, 1700000200);
        expect(cursor.id, 't_b');
      },
    );

    test('applyBundle is a no-op when the bundle is empty', () async {
      final repo = makeRepo();
      await repo.applyBundle(companyId: 'co', bundle: const []);
      final cursor = await db.syncStateDao.read(
        companyId: 'co',
        entityType: 'token',
      );
      expect(cursor.isEmpty, isTrue);
    });

    test('applyBundle preserves the local payload of an is_dirty row '
        'so an offline edit is not clobbered by a re-bundle', () async {
      final repo = makeRepo();
      final draft = Token.fromApi(const TokenApi(name: 'Offline'));
      await repo.create(companyId: 'co', draft: draft);
      final dirtyBefore = (await repo.watchPage(companyId: 'co').first).single;
      expect(dirtyBefore.isDirty, isTrue);

      await repo.applyBundle(
        companyId: 'co',
        bundle: const [
          TokenApi(
            id: 't_server',
            name: 'Server',
            token: 'abc1234567xxxxxxxxxxx',
            updatedAt: 1700000500,
          ),
        ],
      );
      final all = await repo.watchPage(companyId: 'co').first;
      expect(all, hasLength(2));
      expect(all.map((t) => t.name).toSet(), {'Offline', 'Server'});
      final stillDirty = all.firstWhere((t) => t.name == 'Offline');
      expect(stillDirty.isDirty, isTrue);
    });

    test('applyCreateResponse broadcasts the raw secret on newSecrets '
        'AND persists the masked form to Drift', () async {
      final repo = makeRepo();

      final draft = Token.fromApi(const TokenApi(name: 'My Token'));
      final stored = (await repo.create(companyId: 'co', draft: draft)).entity;
      final tempId = stored.id;

      final firstSecret = repo.newSecrets.first;

      await repo.applyCreateResponse(
        companyId: 'co',
        tempId: tempId,
        serverResponse: const TokenApi(
          id: 't_real',
          name: 'My Token',
          token: 'this-is-the-raw-bearer-secret',
          userId: 'u_1',
          updatedAt: 1700000123,
        ),
      );

      final secret = await firstSecret.timeout(const Duration(seconds: 2));
      expect(secret.tempId, tempId);
      expect(secret.secret, 'this-is-the-raw-bearer-secret');

      // The raw secret went out on the broadcast only: the `token` column
      // and the payload both hold the server's masked form, so nothing at
      // rest (unencrypted, on web) carries the credential.
      final row = await db.tokenDao
          .watchById(companyId: 'co', id: 't_real')
          .first;
      expect(row, isNotNull);
      expect(row!.token, 'this-is-thxxxxxxxxxxx');
      expect(row.payload, isNot(contains('this-is-the-raw-bearer-secret')));
      final read = await repo
          .watch(companyId: 'co', id: 't_real')
          .firstWhere((t) => t != null);
      expect(read!.isMasked, isTrue);

      // And what we *send*: `Token.toApiJson` strips `token`, so the outbox
      // never echoes the secret back.
      final domain = Token.fromApi(
        const TokenApi(
          id: 't_real',
          name: 'My Token',
          token: 'this-is-the-raw-bearer-secret',
          userId: 'u_1',
        ),
      );
      final sentJson = domain.toApiJson(preserveTempId: true);
      expect(sentJson.containsKey('token'), isFalse);
      expect(sentJson.containsKey('user_id'), isFalse);
    });

    test('applyCreateResponse does NOT emit on newSecrets when the response '
        'token is already masked (e.g. a refresh-driven re-create)', () async {
      final repo = makeRepo();

      var emitted = 0;
      final sub = repo.newSecrets.listen((_) => emitted++);
      addTearDown(sub.cancel);

      await repo.applyCreateResponse(
        companyId: 'co',
        tempId: 'tmp_abc',
        serverResponse: const TokenApi(
          id: 't_masked',
          name: 'Masked',
          token: 'abc1234567xxxxxxxxxxx',
          updatedAt: 1700000200,
        ),
      );
      // Give the broadcast stream a tick to deliver if it were going to.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emitted, 0);
    });

    test('applyCreateResponse buffers the raw secret for a late subscriber; '
        'takePendingSecrets drains and clears it', () async {
      final repo = makeRepo();

      // No live listener on newSecrets — mimics the create completing while
      // the app-wide shell listener isn't mounted yet (cold start) or is
      // between screens. The broadcast alone would drop it; the buffer keeps it.
      await repo.applyCreateResponse(
        companyId: 'co',
        tempId: 'tmp_late',
        serverResponse: const TokenApi(
          id: 't_late',
          name: 'Late',
          token: 'raw-secret-for-a-late-subscriber',
          userId: 'u_1',
          updatedAt: 1700000300,
        ),
      );

      final pending = repo.takePendingSecrets();
      expect(pending, hasLength(1));
      expect(pending.single.tempId, 'tmp_late');
      expect(pending.single.secret, 'raw-secret-for-a-late-subscriber');

      // Draining clears the buffer so the dialog never re-shows.
      expect(repo.takePendingSecrets(), isEmpty);
    });

    test(
      'takePendingSecrets stays empty for a masked (no-secret) response',
      () async {
        final repo = makeRepo();

        await repo.applyCreateResponse(
          companyId: 'co',
          tempId: 'tmp_masked',
          serverResponse: const TokenApi(
            id: 't_masked2',
            name: 'Masked',
            token: 'abc1234567xxxxxxxxxxx',
            updatedAt: 1700000400,
          ),
        );

        expect(repo.takePendingSecrets(), isEmpty);
      },
    );

    test('maskTokenSecret matches the server hashed transformer', () {
      const raw =
          'Abc123defGhij456klmNop789qrsTuv012wxyZab345cdeFgh678ijkLmn901opq';
      final masked = maskTokenSecret(raw);
      expect(masked, 'Abc123defGxxxxxxxxxxx');
      expect(Token.fromApi(TokenApi(id: 't', token: masked)).isMasked, isTrue);
      // Too short to have a prefix: nothing of it survives.
      expect(maskTokenSecret('short'), 'xxxxxxxxxxx');
    });

    test('obscuredHint is the prefix plus dots, never the secret', () {
      final t = Token.fromApi(
        const TokenApi(id: 't', token: 'abc1234567xxxxxxxxxxx'),
      );
      expect(t.obscuredHint, 'abc1234567••••••••••••');
    });

    group('fetchSecret', () {
      test('returns the raw token from GET /tokens/{id} and writes nothing '
          'to Drift', () async {
        final requested = <String>[];
        final repo = TokenRepository(
          db: db,
          api: _FakeTokensApi(
            onGet: (id) {
              requested.add(id);
              return TokenApi(
                id: id,
                name: 'N',
                token: 'the-full-secret-value',
              );
            },
          ),
        );
        await repo.applyBundle(
          companyId: 'co',
          bundle: const [
            TokenApi(
              id: 't_1',
              name: 'N',
              token: 'the-full-sxxxxxxxxxxx',
              updatedAt: 1700000100,
            ),
          ],
        );
        final before = await db.tokenDao
            .watchById(companyId: 'co', id: 't_1')
            .first;

        final secret = await repo.fetchSecret(companyId: 'co', id: 't_1');

        expect(secret, 'the-full-secret-value');
        expect(requested, ['t_1']);
        final after = await db.tokenDao
            .watchById(companyId: 'co', id: 't_1')
            .first;
        expect(after!.token, before!.token);
        expect(after.payload, before.payload);
      });

      test('returns null when the server answers masked', () async {
        final repo = TokenRepository(
          db: db,
          api: _FakeTokensApi(
            onGet: (id) => TokenApi(id: id, token: 'abc1234567xxxxxxxxxxx'),
          ),
        );
        expect(await repo.fetchSecret(companyId: 'co', id: 't_1'), isNull);
      });

      test('throws TokenNotSyncedException for a create still in the outbox, '
          'without a request', () async {
        var calls = 0;
        final repo = TokenRepository(
          db: db,
          api: _FakeTokensApi(
            onGet: (id) {
              calls++;
              return TokenApi(id: id, token: 'never');
            },
          ),
        );
        final created = await repo.create(
          companyId: 'co',
          draft: Token.fromApi(const TokenApi(name: 'Offline')),
        );

        await expectLater(
          repo.fetchSecret(companyId: 'co', id: created.entity.id),
          throwsA(isA<TokenNotSyncedException>()),
        );
        expect(calls, 0);
      });

      test('resolves a tmp_ id whose create has landed to the real id — the '
          'edit screen keeps the id it opened with', () async {
        final requested = <String>[];
        final repo = TokenRepository(
          db: db,
          api: _FakeTokensApi(
            onGet: (id) {
              requested.add(id);
              return TokenApi(id: id, token: 'the-full-secret-value');
            },
          ),
        );
        final created = await repo.create(
          companyId: 'co',
          draft: Token.fromApi(const TokenApi(name: 'New')),
        );
        final tempId = created.entity.id;
        await repo.applyCreateResponse(
          companyId: 'co',
          tempId: tempId,
          serverResponse: const TokenApi(
            id: 't_real',
            name: 'New',
            token: 'the-full-secret-value',
            updatedAt: 1700000500,
          ),
        );

        final secret = await repo.fetchSecret(companyId: 'co', id: tempId);

        expect(secret, 'the-full-secret-value');
        expect(requested, ['t_real']);
      });
    });

    test(
      '_fromRow overlays is_dirty so an offline create reads as dirty',
      () async {
        final repo = makeRepo();
        final draft = Token.fromApi(const TokenApi(name: 'New'));
        await repo.create(companyId: 'co', draft: draft);
        final rows = await repo.watchPage(companyId: 'co').first;
        expect(rows, hasLength(1));
        expect(rows.first.isDirty, isTrue);
      },
    );
  });
}

class _FakeTokensApi implements TokensApi {
  _FakeTokensApi({this.onGet});

  /// Answers `GET /tokens/{id}`; every other call stays unimplemented.
  final TokenApi Function(String id)? onGet;

  @override
  Future<TokenItemApi> get(String id) async {
    final handler = onGet;
    if (handler == null) throw UnimplementedError();
    return TokenItemApi(data: handler(id));
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
