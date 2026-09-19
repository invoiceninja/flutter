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

    // **Derived, not listed.** This test used to name three controllers, and the
    // day a fourth (`hideUnverifiedUsers`, invoiceninja/flutter#150) shipped in
    // the same release as two of them it slipped straight past — the guard built
    // for the bug could not see the newest instance of it. Any controller that
    // declares `resetInMemory` is now required to be wired, so a fifth is covered
    // the day it is written.
    //
    // Three things about *how* it derives, each a hole the first version had:
    //
    //  * **recursive** — `lib/app/shortcuts/keyboard_shortcuts_controller.dart`
    //    is a `Services` field that touches `nav_state` and sits in a
    //    subdirectory, so a flat `listSync()` could never see it;
    //  * the `Services` field name is **looked up**, not guessed from the file
    //    name: two getters are plural where their file is singular
    //    (`sidebar_badge_mode_controller.dart` → `sidebarBadgeModes`,
    //    `shortcut_hint_controller.dart` → `shortcutHints`), so camelCasing the
    //    file name would demand a getter that does not exist;
    //  * the probe runs on **comment-stripped** source, so a doc comment quoting
    //    the signature cannot enlist a controller.
    final classToField = <String, String>{
      // `final FooController foo;` and `late final FooController foo = …` alike.
      for (final m in RegExp(
        r'\b(\w+Controller)\s+(\w+)\s*[;=]',
      ).allMatches(services))
        m.group(1)!: m.group(2)!,
    };

    final declared = <String>[];
    for (final f in Directory('lib/app').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('_controller.dart')) continue;
      final src = read(f.path);
      if (!src.contains('void resetInMemory(')) continue;
      final cls = RegExp(r'\bclass\s+(\w+Controller)\b').firstMatch(src);
      expect(
        cls,
        isNotNull,
        reason: '${f.path} declares resetInMemory but no *Controller class',
      );
      final field = classToField[cls!.group(1)!];
      expect(
        field,
        isNotNull,
        reason:
            '${cls.group(1)} declares resetInMemory but Services exposes no '
            'field of that type — either wire it or say here why it is exempt',
      );
      declared.add(field!);
    }
    declared.sort();

    expect(
      declared,
      containsAll(<String>[
        'hideEmptyPanels',
        'hideUnverifiedUsers',
        'sidebarMenu',
        'tasksView',
      ]),
      reason:
          'the scan lost a controller it used to find — if one was renamed, '
          'update this floor; if one dropped resetInMemory, say why here',
    );

    for (final call in declared.map((n) => '$n.resetInMemory()')) {
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
