import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/services/statics_service.dart';

/// A statics service that fails loudly — `applyStatic` must never reach the
/// network, so any `fetch()` here would be a bug.
class _ThrowingStaticsService implements StaticsService {
  @override
  Future<Map<String, dynamic>> fetch() async =>
      throw StateError('StaticsService.fetch should not be called');

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  late StaticsRepository statics;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    statics = StaticsRepository(db: db, service: _ThrowingStaticsService());
  });
  tearDown(() async {
    await db.close();
  });

  group('applyStatic', () {
    test('no-ops on null without touching the cache', () async {
      await statics.applyStatic(null);
      expect(await db.staticsDao.read(), isNull);
      expect(statics.currencies, isEmpty);
    });

    test('no-ops on the empty map a delta refresh carries', () async {
      // A delta /refresh (no include_static) returns `static: {}`. Writing
      // that would blank every dropdown — guard must short-circuit.
      await statics.applyStatic(const <String, dynamic>{});
      expect(await db.staticsDao.read(), isNull);
      expect(statics.currencies, isEmpty);
    });

    test('writes a non-empty blob through and warms typed views', () async {
      await statics.applyStatic(const {
        'currencies': [
          {'id': '1', 'name': 'US Dollar', 'code': 'USD'},
        ],
      });

      final cached = await db.staticsDao.read();
      expect(cached, isNotNull);
      expect(cached!.payload, contains('US Dollar'));
      expect(statics.currency('1')?.name, 'US Dollar');
    });

    test(
      'does not blank a populated cache when later given an empty map',
      () async {
        await statics.applyStatic(const {
          'currencies': [
            {'id': '1', 'name': 'US Dollar', 'code': 'USD'},
          ],
        });
        await statics.applyStatic(const <String, dynamic>{});

        expect(statics.currency('1')?.name, 'US Dollar');
        expect((await db.staticsDao.read())!.payload, contains('US Dollar'));
      },
    );
  });

  // `ensureLoaded` is called several times over on a cold start — boot, the
  // locale resolver on every session change, each company's formatter — and it
  // used to read the stored payload, decode it and rebuild every typed view
  // each time. Once the blob is in memory it now checks the row's stamp and
  // returns; the stamp is also how it notices a wipe.
  group('ensureLoaded', () {
    const usd = {
      'currencies': [
        {'id': '1', 'name': 'US Dollar', 'code': 'USD'},
      ],
    };
    const eur = {
      'currencies': [
        {'id': '3', 'name': 'Euro', 'code': 'EUR'},
      ],
    };
    var nowMs = 1700000000000;
    late _CountingStaticsService service;
    late StaticsRepository repo;

    setUp(() {
      nowMs = 1700000000000;
      service = _CountingStaticsService(usd);
      repo = StaticsRepository(
        db: db,
        service: service,
        ttl: const Duration(days: 7),
        now: () => DateTime.fromMillisecondsSinceEpoch(nowMs),
      );
    });

    test('a second call leaves the parsed views alone', () async {
      await repo.ensureLoaded();
      final currencies = repo.currencies;
      expect(currencies['1']?.name, 'US Dollar');

      await repo.ensureLoaded();
      await repo.ensureLoaded();

      expect(
        repo.currencies,
        same(currencies),
        reason: 'nothing was decoded or rebuilt again',
      );
      expect(service.fetches, 1);
    });

    test('a fresh repository still reads what is on disk', () async {
      await repo.ensureLoaded();

      final second = StaticsRepository(
        db: db,
        service: _ThrowingStaticsService(),
        now: () => DateTime.fromMillisecondsSinceEpoch(nowMs),
      );
      await second.ensureLoaded();

      expect(second.currency('1')?.name, 'US Dollar');
    });

    test('a wiped store is noticed, and refetched', () async {
      // Sign out, then sign in as someone else in the same process: the
      // login envelope carries no statics, so this call is what restores
      // them. A fast path that trusted memory alone would leave the next
      // cold start with no cache at all.
      await repo.ensureLoaded();
      await db.wipe();
      service.blob = eur;

      await repo.ensureLoaded();

      expect(service.fetches, 2);
      expect(repo.currency('3')?.name, 'Euro');
      expect(await db.staticsDao.read(), isNotNull);
    });

    test('a row written behind its back is picked up', () async {
      await repo.ensureLoaded();
      await db.staticsDao.write(
        payload: '{"currencies":[{"id":"3","name":"Euro","code":"EUR"}]}',
        fetchedAt: nowMs + 1,
      );

      await repo.ensureLoaded();

      expect(repo.currency('3')?.name, 'Euro');
      expect(service.fetches, 1, reason: 'the stored row is still fresh');
    });

    test('an expired cache is refetched', () async {
      await repo.ensureLoaded();
      nowMs += const Duration(days: 8).inMilliseconds;
      service.blob = eur;

      await repo.ensureLoaded();

      expect(service.fetches, 2);
      expect(repo.currency('3')?.name, 'Euro');
    });

    test('applyStatic keeps the fast path honest', () async {
      await repo.ensureLoaded();
      nowMs += 1000;
      await repo.applyStatic(eur);
      final currencies = repo.currencies;

      await repo.ensureLoaded();

      expect(repo.currencies, same(currencies));
      expect(repo.currency('3')?.name, 'Euro');
      expect(service.fetches, 1);
    });

    test('concurrent callers share one load', () async {
      await Future.wait([
        repo.ensureLoaded(),
        repo.ensureLoaded(),
        repo.ensureLoaded(),
      ]);

      expect(service.fetches, 1);
      expect(repo.currency('1')?.name, 'US Dollar');
    });

    test('force bypasses the fast path', () async {
      await repo.ensureLoaded();
      service.blob = eur;

      await repo.ensureLoaded(force: true);

      expect(service.fetches, 2);
      expect(repo.currency('3')?.name, 'Euro');
    });
  });
}

/// Returns [blob] and counts how often it was asked.
class _CountingStaticsService implements StaticsService {
  _CountingStaticsService(this.blob);

  Map<String, dynamic> blob;
  int fetches = 0;

  @override
  Future<Map<String, dynamic>> fetch() async {
    fetches++;
    return blob;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
