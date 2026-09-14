import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The `G`-leader table has three consumers — the shell resolves the pressed
/// second key, `in_sidebar` draws each row's `G`-then-x tooltip, and the `?`
/// dialog lists the whole thing. All three used to spell the table out by hand,
/// and every direction of drift was silent: a shortcut with no sidebar hint and
/// no dialog entry is one nobody can discover, and a hint with no shell case is
/// a documented shortcut that does nothing at all.
///
/// They now read `lib/domain/leader_shortcuts.dart`, so adding a destination is
/// one entry. This scan is what stops a hand-rolled switch coming back.
void main() {
  /// Comments stripped: the `isFalse` check below names the spelling it
  /// forbids, and the shell's own comment about the leader would otherwise
  /// trip it.
  String read(String path) => File(path)
      .readAsLinesSync()
      .map((line) {
        final i = line.indexOf('//');
        return i == -1 ? line : line.substring(0, i);
      })
      .join('\n');

  final shell = read('lib/ui/features/shell/scaffold_with_nav.dart');
  final sidebar = read('lib/ui/features/shell/widgets/in_sidebar.dart');
  final dialog = read(
    'lib/ui/features/shell/widgets/keyboard_shortcuts_dialog.dart',
  );

  test('the shell resolves the second key through the table', () {
    expect(shell.contains('leaderTargetForKey('), isTrue);
    expect(
      shell.contains('LogicalKeyboardKey.keyD'),
      isFalse,
      reason:
          'the per-letter switch is what this table replaced; the only '
          'LogicalKeyboardKey the shell still names is keyG, the leader itself',
    );
  });

  test('the sidebar draws its hints from the table', () {
    expect(sidebar.contains('leaderKeyForEntity('), isTrue);
    expect(sidebar.contains('leaderKeyForFixed('), isTrue);
  });

  test('the ? dialog lists the table', () {
    expect(
      dialog.contains('kLeaderTargets'),
      isTrue,
      reason:
          'a hardcoded letter list here silently stops mentioning new '
          'destinations, which is the only place they are documented',
    );
  });
}
