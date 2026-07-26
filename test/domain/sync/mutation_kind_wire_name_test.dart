import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/sync/mutation.dart';

/// Generalizes `mutation_kind_add_to_inventory_test.dart` from one kind to all
/// of them.
///
/// `wireName` and `tryParse` are two independent hand-written switches over the
/// same enum, and `wireName` ends in `_ => name`. Add a kind, forget the
/// `wireName` arm, and it silently serializes as the camelCase enum name
/// (`markViewed`) while `tryParse` only knows the snake_case spelling. The
/// mismatch is invisible at enqueue time — the outbox row is written happily —
/// and only surfaces on drain, where the row can never be parsed back. That's a
/// permanently stranded user mutation, not a crash, so nothing else catches it.
///
/// The `_ => name` fallback is legitimate for the nine single-word kinds
/// (`create`, `update`, `delete`, `archive`, `restore`, `purge`, `reorder`,
/// `start`, `stop`) whose enum name already *is* the wire spelling. The
/// snake_case check below passes those and rejects camelCase, which is exactly
/// the fallthrough we care about.
void main() {
  group('MutationKind wire format', () {
    test('every kind round-trips through wireName → tryParse', () {
      final broken = <String>[
        for (final kind in MutationKind.values)
          if (MutationKind.tryParse(kind.wireName) != kind)
            '${kind.name}: wireName "${kind.wireName}" parsed back as '
                '${MutationKind.tryParse(kind.wireName)?.name ?? 'null'}',
      ];

      expect(
        broken,
        isEmpty,
        reason:
            'These kinds cannot be read back out of a persisted outbox row. '
            'Add the missing arm to MutationKind.tryParse (or fix wireName):\n'
            '${broken.join('\n')}',
      );
    });

    test('no two kinds share a wire name', () {
      final byWireName = <String, List<String>>{};
      for (final kind in MutationKind.values) {
        byWireName.putIfAbsent(kind.wireName, () => []).add(kind.name);
      }
      final collisions = byWireName.entries.where((e) => e.value.length > 1);

      expect(
        collisions.map((e) => '"${e.key}" ← ${e.value.join(', ')}'),
        isEmpty,
        reason:
            'A shared wire name makes tryParse resolve every colliding kind to '
            'whichever arm the switch hits first, so the other rows drain as '
            'the wrong mutation.',
      );
    });

    test('every wire name is snake_case (catches the _ => name fallthrough)', () {
      final pattern = RegExp(r'^[a-z][a-z0-9]*(_[a-z0-9]+)*$');
      final offenders = <String>[
        for (final kind in MutationKind.values)
          if (!pattern.hasMatch(kind.wireName))
            '${kind.name} → "${kind.wireName}"',
      ];

      expect(
        offenders,
        isEmpty,
        reason:
            'wireName fell through to the camelCase enum name — add an explicit '
            'arm to the wireName switch:\n${offenders.join('\n')}',
      );
    });

    test('tryParse returns null for an unknown wire name', () {
      expect(MutationKind.tryParse('not_a_real_mutation'), isNull);
      expect(MutationKind.tryParse(''), isNull);
    });
  });
}
