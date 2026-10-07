import 'package:drift/drift.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/tables/statics_table.dart';

part 'statics_dao.g.dart';

@DriftAccessor(tables: [Statics])
class StaticsDao extends DatabaseAccessor<AppDatabase> with _$StaticsDaoMixin {
  StaticsDao(super.db);

  Future<({String payload, int fetchedAt})?> read() async {
    final row =
        await (select(statics)
              ..where((s) => s.id.equals(0))
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    return (payload: row.payload, fetchedAt: row.fetchedAt);
  }

  /// The stored row's `fetched_at` alone, or null when there is no row. Enough
  /// to tell whether the cache is present and fresh without reading the whole
  /// payload across the database isolate.
  Future<int?> fetchedAt() async {
    final row =
        await (selectOnly(statics)
              ..addColumns([statics.fetchedAt])
              ..where(statics.id.equals(0))
              ..limit(1))
            .getSingleOrNull();
    return row?.read(statics.fetchedAt);
  }

  Future<void> write({required String payload, required int fetchedAt}) =>
      // Pin the row id to 0. Drift treats an integer primary key with no
      // companion value as a ROWID alias and auto-assigns 1, 2, 3, … on each
      // insert, so `insertOnConflictUpdate` never collides and `read()`
      // (which filters `id == 0`) never finds the row — the single-row cache
      // silently never hits. Setting id explicitly makes the upsert collapse
      // onto one row, which is the whole point of this table.
      into(statics).insertOnConflictUpdate(
        StaticsCompanion.insert(
          id: const Value(0),
          payload: payload,
          fetchedAt: fetchedAt,
        ),
      );
}
