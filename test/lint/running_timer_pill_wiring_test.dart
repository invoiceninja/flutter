import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The shell pins `RunningTimerPill` above every screen, in both of its layout
/// branches. Where it pins the pill decides whether the pill covers a screen's
/// create FAB. invoiceninja/flutter#164 gave the dashboard a FAB on a phone in
/// landscape, where the shell is in its railed branch and used to put the pill
/// in exactly that corner.
///
/// `runningTimerPillBottom` holds the rule and has its own unit test.
/// `ScaffoldWithNav` cannot be pumped (`InSidebar` deadlocks on its
/// saved-views Drift watch, see `sidebar_footer_wiring_test.dart`), so this
/// source scan is what keeps both branches on that rule.
void main() {
  String code(String path) {
    final f = File(path);
    expect(f.existsSync(), isTrue, reason: '$path is missing');
    // Strip `//` tails so a comment that names the helper can't satisfy the
    // scan.
    return f
        .readAsLinesSync()
        .map((l) {
          final i = l.indexOf('//');
          return i == -1 ? l : l.substring(0, i);
        })
        .join('\n');
  }

  test('both shell branches place the pill through the shared rule', () {
    final lines = code(
      'lib/ui/features/shell/scaffold_with_nav.dart',
    ).split('\n');
    final pills = [
      for (var i = 0; i < lines.length; i++)
        if (lines[i].contains('RunningTimerPill(')) i,
    ];
    expect(pills, hasLength(2), reason: 'one pill per layout branch');

    for (final at in pills) {
      // The `Positioned` that places the pill, whichever side of the pill it
      // is written on. The wide branch builds the pill first and positions it
      // in a builder below; the narrow branch wraps it directly.
      final around = lines
          .sublist((at - 12).clamp(0, lines.length), at)
          .followedBy(lines.sublist(at, (at + 13).clamp(0, lines.length)))
          .join('\n');
      expect(
        around,
        contains('bottom: runningTimerPillBottom('),
        reason: 'the pill at line ${at + 1} must take its offset from the rule',
      );
      expect(
        RegExp(r'bottom:\s*\d').hasMatch(around),
        isFalse,
        reason:
            'a literal offset beside the pill at line ${at + 1} is the '
            'regression this guards',
      );
    }
  });

  test('the railed branch measures the pane, not the window', () {
    // The pane is the window less the rail, and the rail's width follows the
    // collapse toggle. Measuring the window would keep the pill in the corner
    // for the whole 600–832 px band, where every list screen shows its FAB.
    final src = code('lib/ui/features/shell/scaffold_with_nav.dart');
    expect(
      RegExp(
        r'paneWidth:\s*constraints\.maxWidth\s*-\s*\(\s*collapsed',
      ).hasMatch(src),
      isTrue,
    );
  });
}
