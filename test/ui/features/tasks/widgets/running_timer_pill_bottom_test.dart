import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/features/tasks/widgets/running_timer_pill.dart';

/// The shell paints `RunningTimerPill` above every screen, so its offset
/// decides whether it covers a screen's bottom-right FAB. A screen shows one
/// whenever its pane is narrow, and since invoiceninja/flutter#164 the
/// dashboard shows one on any phone, including in landscape, where the shell
/// has already switched to its railed layout.
void main() {
  test('a narrow pane lifts the pill clear of its FAB', () {
    // A phone in portrait, and the 600–832 px window band where the rail is up
    // but the pane is still narrow.
    expect(runningTimerPillBottom(paneWidth: 390, isPhone: true), 112);
    expect(runningTimerPillBottom(paneWidth: 468, isPhone: false), 112);
  });

  test('a phone lifts it even when its pane is wide', () {
    // Landscape: an 890 px window less the 232 px rail. The dashboard keeps
    // its narrow layout, and its FAB, here.
    expect(runningTimerPillBottom(paneWidth: 658, isPhone: true), 112);
  });

  test('a wide pane elsewhere leaves it in the corner', () {
    expect(runningTimerPillBottom(paneWidth: 600, isPhone: false), 16);
    expect(runningTimerPillBottom(paneWidth: 1368, isPhone: false), 16);
  });

  test('a screen that shows its FAB regardless of width lifts it too', () {
    // The width rule is right for every screen but three. Tasks daily / weekly /
    // calendar mount their FAB ungated on `wide` on purpose
    // (`tasksViewAlwaysShowsFab`), so on a desktop window this used to return 16
    // with a real 56 px button underneath — and the pill, being the later `Stack`
    // child, took the taps aimed at `+`.
    expect(
      runningTimerPillBottom(
        paneWidth: 1368,
        isPhone: false,
        screenAlwaysHasFab: true,
      ),
      112,
    );
    // Still opt-in: the default is the width rule, which is what the plain Tasks
    // list and every other screen want.
    expect(
      runningTimerPillBottom(
        paneWidth: 1368,
        isPhone: false,
        screenAlwaysHasFab: false,
      ),
      16,
    );
  });

  test('the lifted offset clears a 56 px FAB with a 40 px gap', () {
    expect(
      runningTimerPillBottom(paneWidth: 390, isPhone: true),
      kFloatingActionButtonMargin + 56 + 40,
    );
  });
}
