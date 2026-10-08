import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/report_cache_store.dart';

void main() {
  late AppDatabase db;
  var now = 1000;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = 1000;
  });

  tearDown(() async {
    await db.close();
  });

  ReportCacheStore store({int maxEntries = 12, int maxLength = 1 << 20}) =>
      ReportCacheStore(
        db: db,
        now: () => now,
        maxEntries: maxEntries,
        maxPayloadLength: maxLength,
      );

  Map<String, Object?> raw(String marker) => {
    'columns': [
      {'identifier': 'client.name', 'display_value': 'Client'},
    ],
    '0': [
      {'value': marker, 'display_value': marker},
    ],
  };

  test('a result is read back as it was written, with when', () async {
    final s = store();
    final key = ReportCacheStore.keyFor('invoice', {'date_range': 'this_year'});
    await s.write(companyId: 'c1', key: key, raw: raw('a'));

    final hit = await s.read(companyId: 'c1', key: key);
    expect(hit!.raw, raw('a'));
    expect(hit.fetchedAt.millisecondsSinceEpoch, 1000);
  });

  test('a miss is null', () async {
    expect(await store().read(companyId: 'c1', key: 'invoice|{}'), isNull);
  });

  test('the key is the request, whatever order its fields came in', () {
    expect(
      ReportCacheStore.keyFor('invoice', {'b': 1, 'a': 'x'}),
      ReportCacheStore.keyFor('invoice', {'a': 'x', 'b': 1}),
    );
    // A different report, range or filter is a different result.
    final base = ReportCacheStore.keyFor('invoice', {'date_range': 'all'});
    expect(
      ReportCacheStore.keyFor('quote', {'date_range': 'all'}),
      isNot(base),
    );
    expect(
      ReportCacheStore.keyFor('invoice', {'date_range': 'this_year'}),
      isNot(base),
    );
    expect(
      ReportCacheStore.keyFor('invoice', {
        'date_range': 'all',
        'status': 'paid',
      }),
      isNot(base),
    );
  });

  test('one company never reads another', () async {
    final s = store();
    await s.write(companyId: 'c1', key: 'k', raw: raw('a'));
    expect(await s.read(companyId: 'c2', key: 'k'), isNull);
  });

  test('only the most recent results are kept', () async {
    final s = store(maxEntries: 2);
    for (final k in ['k1', 'k2', 'k3']) {
      now += 10;
      await s.write(companyId: 'c1', key: k, raw: raw(k));
    }
    expect(await s.read(companyId: 'c1', key: 'k1'), isNull);
    expect(await s.read(companyId: 'c1', key: 'k2'), isNotNull);
    expect(await s.read(companyId: 'c1', key: 'k3'), isNotNull);
  });

  test('re-running a report keeps it among the recent ones', () async {
    final s = store(maxEntries: 2);
    now = 10;
    await s.write(companyId: 'c1', key: 'k1', raw: raw('old'));
    now = 20;
    await s.write(companyId: 'c1', key: 'k2', raw: raw('b'));
    now = 30;
    await s.write(companyId: 'c1', key: 'k1', raw: raw('new'));
    now = 40;
    await s.write(companyId: 'c1', key: 'k3', raw: raw('c'));

    expect((await s.read(companyId: 'c1', key: 'k1'))!.raw, raw('new'));
    expect(await s.read(companyId: 'c1', key: 'k2'), isNull);
  });

  test(
    'a result too large to keep is not kept, nor is its predecessor',
    () async {
      final s = store(maxLength: 200);
      await s.write(companyId: 'c1', key: 'k', raw: raw('small'));
      expect(await s.read(companyId: 'c1', key: 'k'), isNotNull);

      // Otherwise the next open would show last week's smaller answer to the
      // same request as if it were this one.
      await s.write(companyId: 'c1', key: 'k', raw: raw('x' * 500));
      expect(await s.read(companyId: 'c1', key: 'k'), isNull);
    },
  );

  test('the history of reports does not touch the dashboard rows', () async {
    await db.dashboardCacheDao.upsert(
      companyId: 'c1',
      kind: 'chart',
      filterHash: 'h',
      payload: '{}',
      fetchedAt: 1,
    );
    final s = store(maxEntries: 1);
    await s.write(companyId: 'c1', key: 'k1', raw: raw('a'));
    await s.write(companyId: 'c1', key: 'k2', raw: raw('b'));

    final chart = await db.dashboardCacheDao.read(
      companyId: 'c1',
      kind: 'chart',
      filterHash: 'h',
    );
    expect(chart, isNotNull);
  });
}
