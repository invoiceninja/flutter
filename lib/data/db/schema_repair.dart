import 'package:drift/drift.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/table_retention.dart';

final _log = Logger('SchemaRepair');

/// What [repairSchema] changed.
class SchemaRepairReport {
  const SchemaRepairReport({
    this.createdTables = const [],
    this.addedColumns = const [],
    this.rebuiltTables = const [],
  });

  final List<String> createdTables;

  /// `table.column` entries added in place, rows kept.
  final List<String> addedColumns;

  /// Cache tables dropped and recreated empty — their rows re-download.
  final List<String> rebuiltTables;

  bool get changed =>
      createdTables.isNotEmpty ||
      addedColumns.isNotEmpty ||
      rebuiltTables.isNotEmpty;

  @override
  String toString() =>
      'created $createdTables, added $addedColumns, rebuilt $rebuiltTables';
}

/// Thrown by [repairSchema] when a table that holds the user's data
/// ([TableRetention.durable] / [TableRetention.anchor]) is missing a column
/// that can't be added in place (NOT NULL with no SQL default). Dropping it
/// would destroy that data, so the caller escalates instead.
class SchemaUnrepairableException implements Exception {
  const SchemaUnrepairableException(this.table, this.missingColumns);

  final String table;
  final List<String> missingColumns;

  @override
  String toString() =>
      'SchemaUnrepairableException: $table is missing $missingColumns';
}

/// Bring [db]'s tables to the shape the code declares, destroying only what
/// can be re-downloaded.
///
/// For every declared table: create it if it is missing; add missing columns
/// in place when each is nullable or has a SQL default (rows kept); otherwise
/// drop and recreate it — but only a [TableRetention.cache] table. A durable
/// or anchor table in that state throws [SchemaUnrepairableException].
///
/// When any cache table changed, the sync cursors, `companies.last_sync_at`
/// and the dashboard cache are reset so its rows download again — rows kept
/// through an added column hold that column's default, not the server's
/// value. [forceCursorReset] does the same unconditionally, for an upgrade
/// whose own steps failed and were rolled back.
///
/// This replaced resetting the whole database whenever a column was missing
/// — which took the outbox with it. Runs in one transaction.
Future<SchemaRepairReport> repairSchema(
  AppDatabase db, {
  bool forceCursorReset = false,
}) async {
  final created = <String>[];
  final added = <String>[];
  final rebuilt = <String>[];
  await db.transaction(() async {
    final m = Migrator(db);
    final existing = {
      for (final row
          in await db
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type = 'table'",
              )
              .get())
        row.read<String>('name'),
    };
    for (final table in db.allTables) {
      final name = table.actualTableName;
      if (!existing.contains(name)) {
        await m.createTable(table);
        created.add(name);
        continue;
      }
      final present = {
        for (final row
            in await db.customSelect('PRAGMA table_info($name)').get())
          row.read<String>('name'),
      };
      final missing = [
        for (final column in table.$columns)
          if (!present.contains(column.name)) column,
      ];
      if (missing.isEmpty) continue;
      final addable = missing.every(
        (c) => c.$nullable || c.defaultValue != null,
      );
      if (addable) {
        for (final column in missing) {
          await m.addColumn(table, column);
          added.add('$name.${column.name}');
        }
        continue;
      }
      if (retentionOf(name) != TableRetention.cache) {
        throw SchemaUnrepairableException(name, [
          for (final c in missing) c.name,
        ]);
      }
      await m.deleteTable(name);
      await m.createTable(table);
      rebuilt.add(name);
    }
    await createPerformanceIndexes(db);
    await createClientFilterIndexes(db);

    final cacheChanged = [
      ...created,
      ...rebuilt,
      for (final column in added) column.split('.').first,
    ].any((t) => retentionOf(t) == TableRetention.cache);
    if (cacheChanged || forceCursorReset) {
      await db.delete(db.syncStateRows).go();
      await db.delete(db.dashboardCache).go();
      await db
          .update(db.companies)
          .write(const CompaniesCompanion(lastSyncAt: Value(0)));
    }
  });
  final report = SchemaRepairReport(
    createdTables: created,
    addedColumns: added,
    rebuiltTables: rebuilt,
  );
  if (report.changed) _log.warning('Repaired the local schema: $report');
  return report;
}
