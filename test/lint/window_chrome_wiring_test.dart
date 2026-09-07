import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source scans for the frameless Windows / Linux title bar.
///
/// Everything here shares one property: **it cannot fail on this machine any
/// other way.** Neither runner can be built on the macOS dev box, `InSidebar`
/// cannot be widget-tested at all (pumping it deadlocks on the saved-views
/// Drift watch, which `AppDatabase.close()` then waits on forever — see
/// `sidebar_search_box_test.dart`), and the tooltip crash only fires on hover,
/// in release, on two platforms. `window_frame_test.dart` and
/// `window_controls_test.dart` cover everything that *is* observable from a
/// widget test; what is left is only what those cannot see from outside.
void main() {
  final sidebar = File(
    'lib/ui/features/shell/widgets/in_sidebar.dart',
  ).readAsStringSync();
  final frame = File(
    'lib/ui/features/shell/widgets/window_frame.dart',
  ).readAsStringSync();
  final strip = File(
    'lib/ui/features/shell/widgets/window_caption_strip.dart',
  ).readAsStringSync();
  final main = File('lib/main.dart').readAsStringSync();

  test('the sidebar abstains from the arrows via the SHARED predicate', () {
    // Both sides must ask the same question, or the arrows render twice (in
    // the bar and in the rail) or nowhere at all. Neither shows up in any
    // widget test: `InSidebar` cannot be pumped, and `WindowFrame` is pumped
    // without it.
    expect(
      sidebar,
      contains('windowChromeHostsNavArrows()'),
      reason:
          'in_sidebar.dart must gate its own arrow row on the shared '
          'predicate, or the pair renders twice on Windows/Linux.',
    );
    expect(
      frame.contains('paintsAppTitleBar()') ||
          frame.contains('windowChromeHostsNavArrows()'),
      isTrue,
      reason:
          'window_frame.dart must resolve its platform gate from the '
          'shared predicates in native_window.dart.',
    );
  });

  test('only macOS is ever handed the caption strip trailingBuilder', () {
    // `WindowCaptionStrip` asserts `trailingBuilder == null` off macOS. Widen
    // the gate to the shared predicate WITHOUT keeping this second condition
    // and the assert fires on every sidebar build in debug — and in release the
    // arrows disappear from both places at once.
    final idx = sidebar.indexOf('trailingBuilder:');
    expect(idx, greaterThan(-1), reason: 'the strip lost its trailingBuilder');
    final gate = sidebar.substring(idx, idx + 200);
    expect(
      gate,
      contains('captionHostsArrows'),
      reason:
          'the trailingBuilder must be gated on the macOS-only boolean, not '
          'the shared one.',
    );
    expect(
      sidebar,
      contains('WindowCaptionStrip.hostsCaptionRow()'),
      reason:
          'captionHostsArrows must still narrow to macOS — see the assert in '
          'window_caption_strip.dart.',
    );
  });

  test('the caption strip keeps its off-macOS early return', () {
    // `docs/desktop-window-state.md` used to instruct the opposite ("drop the
    // SizedBox.shrink early-return for those platforms"). Doing that now puts a
    // second bar inside the first, because the narrow layout mounts this strip
    // as well.
    expect(
      strip,
      contains('hostsMacCaptionRow()'),
      reason:
          'WindowCaptionStrip must stay macOS-only; Windows/Linux get '
          'WindowFrame above the router instead.',
    );
  });

  test('the title bar never builds a Tooltip', () {
    // There is no `Overlay` above the root Navigator, so a Tooltip here
    // asserts in debug and THROWS ON HOVER in release. Only reachable with a
    // mouse, on two platforms that cannot be built here.
    expect(
      frame,
      contains('tooltips: false'),
      reason:
          'NavHistoryButtons in the title bar must pass tooltips: false — '
          'there is no Overlay ancestor above the router.',
    );
    expect(
      frame.contains('Tooltip('),
      isFalse,
      reason:
          'window_frame.dart must not build a Tooltip: no Overlay ancestor.',
    );
  });

  test('the frame is mounted inside the screenshot RepaintBoundary', () {
    // Outside it, every store capture is short by the band and
    // `ScreenshotResizeResult.matched` is false on every preset — which reads
    // as "the resize clamped", not as "the boundary is in the wrong place".
    final keyIdx = main.indexOf('screenshotWindow.boundaryKey');
    expect(keyIdx, greaterThan(-1), reason: 'the screenshot boundary moved');
    final frameIdx = main.indexOf('WindowFrame(', keyIdx);
    // The next `Positioned.fill` is ToastHost — the RepaintBoundary's sibling
    // in the root Stack. Bounding by that rather than by a character count
    // keeps this from breaking the day someone adds a comment line.
    final nextSibling = main.indexOf('Positioned.fill(', keyIdx);
    expect(
      frameIdx,
      greaterThan(-1),
      reason: 'main.dart must mount WindowFrame.',
    );
    expect(
      nextSibling,
      greaterThan(-1),
      reason: 'the root Stack lost its ToastHost sibling',
    );
    expect(
      frameIdx,
      lessThan(nextSibling),
      reason:
          'WindowFrame must be the RepaintBoundary\'s child, not a later '
          'sibling of it, so screenshots match what ships.',
    );
  });
}
