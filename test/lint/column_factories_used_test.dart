import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The shared metadata columns must be built by `column_factories.dart`, never
/// hand-rolled in a registry.
///
/// This is a lint rather than care because a hand-rolled copy renders fine and
/// diverges silently. Clients, Products and Vendors each hand-rolled their
/// `created` column and so never picked up `colCreatedAt`'s epoch-0 guard: the
/// Drift column is `withDefault(const Constant(0))`, so a row carrying 0
/// painted "1 Jan 1970" on those three lists and an em-dash on the other
/// eleven. Nothing compared the fourteen definitions.
///
/// `labelKey` is the right token to match on. The column *id* is per-entity
/// (`ClientFieldIds.createdAt`), but every copy of a shared column necessarily
/// spells the same user-facing label key, and that is also what
/// `no_unsubstituted_placeholders_test` keys on.
void main() {
  test('shared metadata columns are built by the factories, not by hand', () {
    // Each maps a label key to the factory that owns it.
    const owned = <String, String>{
      'created': 'colCreatedAt',
      'archived': 'colArchivedAt',
      'tags': 'colTags',
    };
    final offenders = <String>[];
    for (final f
        in Directory('lib/domain/columns').listSync().whereType<File>().where(
          (f) => f.path.endsWith('_columns.dart'),
        )) {
      final src = f.readAsStringSync();
      for (final entry in owned.entries) {
        if (src.contains("labelKey: '${entry.key}',")) {
          offenders.add(
            '${f.uri.pathSegments.last} hand-rolls a '
            "'${entry.key}' column — use ${entry.value}()",
          );
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'these bypass column_factories.dart, so they miss whatever guard '
          'the factory carries (that is how the epoch-0 "1 Jan 1970" bug '
          'reached three lists):\n  ${offenders.join('\n  ')}',
    );
  });

  test('the factories that own those label keys still exist', () {
    // Guards the lint itself: renaming a factory without updating the map
    // above would leave it matching nothing and passing vacuously.
    final src = File(
      'lib/domain/columns/column_factories.dart',
    ).readAsStringSync();
    for (final fn in ['colCreatedAt', 'colArchivedAt', 'colTags']) {
      expect(
        src.contains('ColumnDefinition<T> $fn<T>('),
        isTrue,
        reason: '$fn is gone from column_factories.dart — update this lint',
      );
    }
  });
}
