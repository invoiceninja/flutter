import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/entity_registry.dart' show FixedBranchKind;
import 'package:admin/domain/leader_shortcuts.dart';

/// `kLeaderTargets` is the single copy of the `G`-leader table — the shell
/// resolves a pressed second key through it, the sidebar draws its per-row
/// `G`-then-x hints from it, and the `?` dialog lists it. Everything here is a
/// property of the table itself, so it stays a pure unit test.
void main() {
  test('every key is one uppercase letter', () {
    for (final target in kLeaderTargets) {
      expect(
        target.key,
        matches(RegExp(r'^[A-Z]$')),
        reason:
            'the shell matches against `LogicalKeyboardKey.keyLabel`, which '
            'is a single uppercase character for a letter key',
      );
    }
  });

  test('keys are unique', () {
    final keys = kLeaderTargets.map((t) => t.key).toList();
    expect(keys.toSet().length, keys.length);
  });

  test('G is not itself a target', () {
    expect(
      kLeaderTargets.any((t) => t.key == 'G'),
      isFalse,
      reason:
          'the leader is armed by G, so `G G` must stay a no-op rather '
          'than jumping somewhere the user cannot have meant',
    );
  });

  test('a target names exactly one branch and carries a label key', () {
    for (final target in kLeaderTargets) {
      expect(
        (target.entity == null) != (target.fixed == null),
        isTrue,
        reason: '${target.key} must name exactly one branch kind',
      );
      expect(
        target.labelKey,
        isNotEmpty,
        reason:
            'the ? dialog is the only place a leader jump is documented, and '
            'it renders this key as the destination name',
      );
    }
  });

  test('lookup by key round-trips, and is case-insensitive', () {
    for (final target in kLeaderTargets) {
      expect(identical(leaderTargetForKey(target.key), target), isTrue);
      expect(
        identical(leaderTargetForKey(target.key.toLowerCase()), target),
        isTrue,
      );
    }
    expect(leaderTargetForKey('Z'), isNull);
  });

  test('the reverse lookups the sidebar hints use agree with the table', () {
    for (final target in kLeaderTargets) {
      final entity = target.entity;
      if (entity != null) {
        expect(leaderKeyForEntity(entity), target.key);
      } else {
        expect(leaderKeyForFixed(target.fixed!), target.key);
      }
    }
    // Outbox has no leader jump, and a row with no key must render no hint
    // rather than a hint for somebody else's destination.
    expect(leaderKeyForFixed(FixedBranchKind.outbox), isNull);
  });
}
