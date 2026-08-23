import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CI lint: every surface that renders an [EntityActionItem] must wire
/// `guardedOnTap(context, item)` into its button / menu item, never read
/// `item.onTap` directly.
///
/// `guardedOnTap` is what puts the "Are you sure?" dialog in front of a tagged
/// action (invoiceninja/flutter#49). Reading `onTap` straight off the item
/// still compiles, still runs, and still passes every other test — the action
/// just silently loses its guard. That invisibility is why this needs a
/// build-time check rather than a convention in CLAUDE.md.
///
/// Scope: files under `lib/` that mention `EntityActionItem`, since only those
/// can bypass the guard. Self-referential reads (`this.onTap`, `widget.onTap`,
/// `super.onTap`) are a widget forwarding its *own* callback param, not an
/// action item's, so they're excluded. The two owners are allowlisted:
/// `entity_detail_actions_row.dart` declares the field and
/// `confirm_action_dialog.dart` is the wrapper itself.
void main() {
  test('EntityActionItem.onTap is only read through guardedOnTap', () {
    const owners = {
      'lib/ui/core/detail/entity_detail_actions_row.dart',
      'lib/ui/core/dialogs/confirm_action_dialog.dart',
    };
    // A `.onTap` read whose receiver isn't the widget/class itself.
    final pattern = RegExp(r'(?<!\bthis)(?<!\bwidget)(?<!\bsuper)\.onTap\b');

    final offenders = <String>[];
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'lib/ should exist');

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart')) continue;
      if (entity.path.endsWith('.freezed.dart')) continue;
      if (owners.contains(entity.path)) continue;

      final content = entity.readAsStringSync();
      if (!content.contains('EntityActionItem')) continue;

      for (final match in pattern.allMatches(content)) {
        final lineStart = content.lastIndexOf('\n', match.start) + 1;
        final lineEnd = content.indexOf('\n', match.end);
        final line = content
            .substring(lineStart, lineEnd == -1 ? content.length : lineEnd)
            .trim();
        offenders.add('${entity.path}:  $line');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Wire `guardedOnTap(context, item)` instead of reading `item.onTap` '
          'directly, or the action skips its "Are you sure?" gate. Found:\n  '
          '${offenders.join('\n  ')}',
    );
  });

  test('the allowlisted owners still exist', () {
    // A rename would silently empty the allowlist's purpose; fail loudly.
    for (final path in const [
      'lib/ui/core/detail/entity_detail_actions_row.dart',
      'lib/ui/core/dialogs/confirm_action_dialog.dart',
    ]) {
      expect(File(path).existsSync(), isTrue, reason: '$path moved or renamed');
    }
  });
}
