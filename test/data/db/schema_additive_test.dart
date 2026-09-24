import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every schema version only ever adds: each table and column of vN is still
/// in vN+1. That is what lets a build rolled back past an upgrade still open
/// the store (drift runs no downgrade step, and `isSchemaIntact` checks only
/// that the declared columns exist), and what lets a salvage import rows read
/// out of an older store. A step that drops or renames something must be
/// designed for both — this test makes that a decision rather than an
/// accident.
void main() {
  Map<String, Set<String>> tablesOf(int version) {
    final dump =
        jsonDecode(
              File(
                'drift_schemas/drift_schema_v$version.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    return {
      for (final entity in dump['entities'] as List)
        if ((entity as Map)['type'] == 'table')
          (entity['data'] as Map)['name'] as String: {
            for (final column in (entity['data'] as Map)['columns'] as List)
              (column as Map)['name'] as String,
          },
    };
  }

  final versions =
      Directory('drift_schemas')
          .listSync()
          .map((f) => RegExp(r'drift_schema_v(\d+)\.json$').firstMatch(f.path))
          .whereType<RegExpMatch>()
          .map((m) => int.parse(m.group(1)!))
          .toList()
        ..sort();

  test(
    'each schema version keeps every table and column of the one before',
    () {
      expect(versions, isNotEmpty);
      for (var i = 1; i < versions.length; i++) {
        final before = tablesOf(versions[i - 1]);
        final after = tablesOf(versions[i]);
        for (final MapEntry(key: table, value: columns) in before.entries) {
          expect(
            after.keys,
            contains(table),
            reason: 'v${versions[i]} dropped the table $table',
          );
          expect(
            after[table],
            containsAll(columns),
            reason: 'v${versions[i]} dropped a column of $table',
          );
        }
      }
    },
  );
}
