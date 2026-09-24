import 'package:drift/drift.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/nav_state_prefs_carry.dart';
import 'package:admin/data/db/table_retention.dart';

final _log = Logger('Salvage');

/// The tables a reset carries from the quarantined store into the fresh one:
/// everything [TableRetention.durable] (the user's own data) and
/// [TableRetention.anchor] (what `restore()` resumes the session from). The
/// cache is left behind — it downloads again.
final List<String> kSalvagedTables = [
  for (final MapEntry(key: name, value: retention) in kTableRetention.entries)
    if (retention != TableRetention.cache) name,
];

/// What was read out of a quarantined store, without running its migrations.
class QuarantinedStore {
  const QuarantinedStore({
    required this.source,
    this.tables = const {},
    this.error,
  });

  /// Where the store now lives (a `.broken.<ts>` / `.unrecovered.<ts>` file
  /// on native), for the log and for support.
  final String source;

  /// Rows by table name, each row a column → value map. Only the tables in
  /// [kSalvagedTables] that could be read.
  final Map<String, List<Map<String, Object?>>> tables;

  /// Set when the store could not be read at all (still encrypted with a key
  /// this install no longer has, or damaged past reading).
  final Object? error;

  bool get readable => error == null;
}

/// What happened to the user's local data when the store had to be reset —
/// for the log now, and for the post-boot notice.
sealed class LocalDataRecovery {
  const LocalDataRecovery();
}

/// The durable and anchor rows were read out of the broken store and are in
/// the fresh one; only the cache has to download again.
final class LocalDataSalvaged extends LocalDataRecovery {
  const LocalDataSalvaged({
    required this.rowsByTable,
    required this.source,
    this.incompleteTables = const [],
  });

  final Map<String, int> rowsByTable;
  final String source;

  /// Tables whose rows did not all make it across ([importSalvaged]). When
  /// any did not, [source] is the `.unrecovered.<ts>` copy kept for support.
  final List<String> incompleteTables;

  int get unsyncedChanges => rowsByTable['outbox'] ?? 0;

  @override
  String toString() => incompleteTables.isEmpty
      ? 'salvaged $rowsByTable from $source'
      : 'salvaged $rowsByTable from $source, left rows behind in '
            '$incompleteTables';
}

/// Nothing could be carried over. The old store is kept (never pruned) at
/// [retainedAt] when it still exists, so support can try by hand.
final class LocalDataUnrecoverable extends LocalDataRecovery {
  const LocalDataUnrecoverable({required this.reason, this.retainedAt});

  final String reason;
  final String? retainedAt;

  @override
  String toString() => 'unrecoverable ($reason), kept at $retainedAt';
}

/// Import [store]'s rows into the freshly created [db], in one transaction.
///
/// Only [kSalvagedTables] are imported, and only the columns both schemas
/// have, so a store written by an older or newer build still imports. A
/// table whose rows lack a column the current schema requires (NOT NULL, no
/// SQL default) is skipped rather than half-imported. Ids are kept — the
/// outbox's order and its idempotency keys are what make the carried-over
/// rows the same mutations — and inserts are `OR IGNORE`, so one row the new
/// constraints refuse does not cost the rest. Every company's `last_sync_at`
/// is reset afterwards: the cache it described is gone.
///
/// Returns the rows now present per imported table, and the tables that came
/// across short — skipped, or with fewer rows than the store held.
Future<({Map<String, int> rowsByTable, List<String> incompleteTables})>
importSalvaged(AppDatabase db, QuarantinedStore store) async {
  final imported = <String, int>{};
  final incomplete = <String>[];
  await db.transaction(() async {
    for (final table in db.allTables) {
      final name = table.actualTableName;
      if (!kSalvagedTables.contains(name)) continue;
      final rows = store.tables[name];
      if (rows == null || rows.isEmpty) continue;
      final declared = {for (final c in table.$columns) c.name};
      final present = {for (final row in rows) ...row.keys};
      final missingRequired = [
        for (final c in table.$columns)
          if (!c.$nullable &&
              c.defaultValue == null &&
              !present.contains(c.name))
            c.name,
      ];
      if (missingRequired.isNotEmpty) {
        _log.severe(
          'Not salvaging $name: its rows lack required $missingRequired',
        );
        incomplete.add(name);
        continue;
      }
      final columns = [
        for (final c in present)
          if (declared.contains(c)) c,
      ];
      final sql =
          'INSERT OR IGNORE INTO "$name" '
          '(${columns.map((c) => '"$c"').join(', ')}) '
          'VALUES (${List.filled(columns.length, '?').join(', ')})';
      for (final row in rows) {
        await db.customStatement(sql, [for (final c in columns) row[c]]);
      }
      final count =
          (await db
                  .customSelect('SELECT COUNT(*) AS n FROM "$name"')
                  .getSingle())
              .read<int>('n');
      imported[name] = count;
      if (count < rows.length) {
        _log.severe(
          'Salvaged $count of ${rows.length} $name rows; the rest were refused',
        );
        incomplete.add(name);
      }
    }
    await db
        .update(db.companies)
        .write(const CompaniesCompanion(lastSyncAt: Value(0)));
    // A store older than v12 kept its preferences in `nav_state` columns,
    // which came across above; copy them into `device_prefs`. Once per store
    // (a v12 store's marker came across with its rows), and best-effort —
    // preferences are not worth failing the import of the outbox.
    try {
      await carryNavStatePrefs(db);
    } catch (e, st) {
      _log.warning('Copying the salvaged nav_state preferences failed', e, st);
    }
  });
  return (rowsByTable: imported, incompleteTables: incomplete);
}
