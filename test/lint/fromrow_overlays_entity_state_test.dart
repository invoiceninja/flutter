import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CI lint: every repository `_fromRow` that overlays the local-only
/// `is_dirty` column MUST also overlay `is_deleted` and `archived_at` from the
/// Drift row.
///
/// Why: an optimistic delete/archive flips only the DB COLUMN
/// (`markDeletedDirty` / `setArchived` in `base_entity_dao.dart`), never the
/// payload JSON. `_fromRow` rebuilds the domain from the payload, so without a
/// column overlay `entity.isDeleted` / `entity.archivedAt` stay stale — the
/// row renders as active with Delete offered / Restore hidden, the edit pencil
/// enabled, and (for delete) never converges online because the drain's
/// `applyDeleteResponse` discards the server body. Task/Tag/User already do
/// this; this lint forces every other repo to match instead of the class bug
/// recurring one entity at a time.
///
/// A repo that overlays `is_dirty` is by definition a mutable, optimistically-
/// flipped entity, so it needs all three. The behavioural proof lives in
/// `credit_repository_test.dart` ("offline delete/archive optimistically flips
/// the local row").
void main() {
  // Domains that genuinely have no `archivedAt` field (so their `_fromRow`
  // cannot and must not overlay it). Keep this list tiny and explicit.
  const noArchivedAt = {'company_gateway'};

  test('every _fromRow overlaying is_dirty also overlays is_deleted and '
      'archived_at', () {
    final dir = Directory('lib/data/repositories');
    expect(dir.existsSync(), isTrue, reason: 'repositories dir should exist');

    final offenders = <String>[];
    final fromRowRe = RegExp(r'\w+ _fromRow\(');

    for (final entity in dir.listSync()) {
      if (entity is! File || !entity.path.endsWith('_repository.dart')) {
        continue;
      }
      final name = entity.uri.pathSegments.last.replaceFirst(
        '_repository.dart',
        '',
      );
      final content = entity.readAsStringSync();
      final m = fromRowRe.firstMatch(content);
      if (m == null) continue;

      // Extract the _fromRow body via brace matching.
      var i = content.indexOf('{', m.end - 1);
      if (i < 0) continue;
      var depth = 0;
      final start = i;
      for (; i < content.length; i++) {
        if (content[i] == '{') depth++;
        if (content[i] == '}') {
          depth--;
          if (depth == 0) break;
        }
      }
      final body = content.substring(start, i + 1);
      if (!body.contains('row.isDirty')) continue; // not an overlay _fromRow

      if (!body.contains('row.isDeleted')) {
        offenders.add('$name: _fromRow overlays is_dirty but not is_deleted');
      }
      if (!noArchivedAt.contains(name) && !body.contains('row.archivedAt')) {
        offenders.add('$name: _fromRow overlays is_dirty but not archived_at');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These repository _fromRow projections drop an optimistic '
          'delete/archive column flip, so deleted/archived rows render as '
          'active. Overlay `isDeleted: row.isDeleted` and '
          '`archivedAt: epochSecondsToUtcOrNull(row.archivedAt ?? 0)` onto the '
          'API-derived domain (see task_repository.dart). Offenders:\n  '
          '${offenders.join('\n  ')}',
    );
  });
}
