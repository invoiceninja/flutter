import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Destroying the user's local data has one owner per kind of destruction.
///
/// The store is the only home of unsynced work — the outbox, `id_remap`,
/// dirty and `tmp_` rows — and a call that destroys it compiles, runs and
/// passes every other test; the user just finds their changes gone. That is
/// how the edit screen came to delete a record's newest failed row after any
/// save (a rejected email included), and how the Danger Zone came to wipe a
/// company from UI code. So every such call is pinned to its owner:
///
///   * the whole database or one company — `LocalDataDisposer`, which says
///     why and logs what went;
///   * outbox rows — the sync engine, where each delete is a delivered row, a
///     superseded save, a discard the user asked for, or a pruned one; and a
///     repository's own save superseding its pending row
///     (`dedupPendingMutations`);
///   * the table statements themselves — the outbox DAO.
///
/// Adding an owner is a decision: add it here with the reason.
void main() {
  final rules = <({String what, RegExp pattern, Set<String> owners})>[
    (
      what: 'a whole-database or per-company wipe',
      pattern: RegExp(r'\.wipe(ForCompany)?\s*\('),
      owners: {'lib/data/repositories/local_data_disposer.dart'},
    ),
    (
      what: 'a destructive outbox delete',
      pattern: RegExp(
        r'(outboxDao|_outbox)\s*\.\s*(deleteRow|deleteAllForEntity|'
        r'deletePendingForCompany|deletePendingForEntity|pruneDead|'
        r'deleteOlderDeadSaves)\s*\(',
      ),
      owners: {
        'lib/data/repositories/sync_repository.dart',
        // `dedupPendingMutations`: a save replacing its own pending row.
        'lib/data/repositories/base_entity_repository.dart',
      },
    ),
    (
      what: 'a raw delete on the outbox table',
      pattern: RegExp(
        r'delete\(\s*(\w+\.)?outbox\s*\)|DELETE\s+FROM\s+"?outbox',
      ),
      owners: {'lib/data/db/dao/outbox_dao.dart'},
    ),
  ];

  test('local data is destroyed only by its owners', () {
    final offenders = <String>[];
    var scanned = 0;
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart')) continue;
      scanned++;
      final path = entity.path.replaceAll(r'\', '/');
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        for (final rule in rules) {
          if (rule.pattern.hasMatch(line) && !rule.owners.contains(path)) {
            offenders.add('$path:${i + 1} — ${rule.what}: ${line.trim()}');
          }
        }
      }
    }
    expect(scanned, greaterThan(500), reason: 'the scan must not be blind');
    expect(
      offenders,
      isEmpty,
      reason:
          'Route these through their owner (see this file\'s doc), or — if '
          'the call genuinely needs to live there — add the file to the '
          'owners with the reason:\n  ${offenders.join('\n  ')}',
    );
  });

  test('the rules see what they are meant to see', () {
    // Guard against a pattern that silently stopped matching.
    final samples = {
      'await services.db.wipeForCompany(companyId);': 0,
      'await _db.wipe();': 0,
      'await services.db.outboxDao.deleteRow(priorDeadId);': 1,
      'await _outbox.deletePendingForEntity(': 1,
      'await db.outboxDao.deleteOlderDeadSaves(': 1,
      '(delete(outbox)..where((o) => o.id.equals(id))).go();': 2,
    };
    samples.forEach((line, rule) {
      expect(rules[rule].pattern.hasMatch(line), isTrue, reason: line);
    });
  });
}
