import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Device preferences mirrored in memory from `nav_state` must be restored at
/// boot and forgotten **only when the row is really wiped**.
///
/// `AuthRepository.onBeforeLogout` runs on every logout, including the idle
/// re-lock / 401 path that *keeps* local data — so a `resetInMemory()` there
/// showed the same user the default main menu after a re-lock, and their next
/// menu edit saved that default over their real order (the Tasks layout and
/// "Hide empty panels" lost their choice the same way). `onBeforeDataWipe`
/// fires exactly when `nav_state` is destroyed: a deliberate sign-out, or a
/// different identity signing in. Nothing a widget test builds reaches
/// `Services.build`'s wiring, so this is a source scan
/// (invoiceninja/flutter#161).
void main() {
  String read(String path) {
    final f = File(path);
    expect(f.existsSync(), isTrue, reason: '$path is missing');
    // Strip `//` tails so a comment explaining the rule can't satisfy it.
    return f
        .readAsLinesSync()
        .map((l) {
          final i = l.indexOf('//');
          return i == -1 ? l : l.substring(0, i);
        })
        .join('\n');
  }

  test('"Hide empty panels" is restored at boot', () {
    // Drop this and an explicit choice silently stops surviving a relaunch.
    expect(
      read('lib/main.dart'),
      contains('services.hideEmptyPanels.restore()'),
    );
  });

  test('in-memory nav_state preferences reset only on a real wipe', () {
    final services = read('lib/app/services.dart');
    final wipe = RegExp(
      r'onBeforeDataWipe\s*=\s*\(\)\s*async\s*\{([^}]*)\}',
    ).firstMatch(services);
    expect(wipe, isNotNull, reason: 'the onBeforeDataWipe closure is missing');
    final body = wipe!.group(1)!;

    for (final call in const [
      'sidebarMenu.resetInMemory()',
      'tasksView.resetInMemory()',
      'hideEmptyPanels.resetInMemory()',
    ]) {
      expect(
        body,
        contains(call),
        reason: '$call must run when nav_state is wiped',
      );
      expect(
        call.allMatches(services).length,
        1,
        reason:
            '$call must run from onBeforeDataWipe only — onBeforeLogout also '
            'runs on the re-lock / 401 path, which keeps nav_state',
      );
    }
  });
}
