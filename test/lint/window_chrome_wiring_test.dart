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
  final dashboardHeader = File(
    'lib/ui/features/dashboard/widgets/dashboard_top_bar.dart',
  ).readAsStringSync();
  final listHeader = File(
    'lib/ui/core/list/entity_list_app_bar.dart',
  ).readAsStringSync();
  final tasksHeader = File(
    'lib/ui/features/tasks/widgets/tasks_view_toggle.dart',
  ).readAsStringSync();

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

  test('both headers floor to the SHARED band height', () {
    // The rail's company row and the content pane's header sit side by side and
    // have to line up, but they do not derive their height the same way — 12 +
    // 44 + 12 + 1 against 8 + 46 + 8. Left to their own arithmetic they drifted
    // 7 px apart, which is why the constant exists. Nothing else can catch a
    // regression here: `InSidebar` cannot be widget-tested (pumping it deadlocks
    // on the saved-views Drift watch), and the seam is only visible on a running
    // desktop build.
    expect(
      sidebar,
      contains('InSizes.headerBand'),
      reason:
          'in_sidebar.dart must floor its header row to the shared band '
          'height, or it drifts out of line with the content header.',
    );
    expect(
      dashboardHeader,
      contains('InSizes.headerBand'),
      reason:
          'dashboard_top_bar.dart must floor to the shared band height, or it '
          'drifts out of line with the sidebar header.',
    );
    // The list toolbar is the third: it was the one left on its own 64 after
    // the sidebar had already been matched to the dashboard's 69, so every
    // list screen sat 5 px out of line.
    expect(
      listHeader,
      contains('InSizes.headerBand'),
      reason:
          'entity_list_app_bar.dart must use the shared band height for its '
          'wide toolbar, or every list screen drifts from the sidebar header.',
    );
    // The multi-select bar and the Tasks view toggle are documented to match
    // the list toolbar EXACTLY — the body would otherwise jump 5 px on
    // entering multi-select or flipping Tasks kanban/calendar.
    expect(
      tasksHeader,
      contains('InSizes.headerBand'),
      reason:
          'tasks_view_toggle.dart mirrors the list toolbar and must use the '
          'same constant, or the toggle shifts when the user changes view.',
    );
  });

  test('no header keeps a hardcoded 64 beside the shared constant', () {
    // The trap this exists for: `Scaffold` clamps an app bar to
    // `AppBar.preferredHeightFor(context, appBar.preferredSize)`, which for a
    // custom PreferredSizeWidget is that value verbatim. Raising
    // `toolbarHeight` while leaving `preferredSize` on the old literal renders
    // the OLD height and looks exactly like a change that did nothing — and a
    // "references the constant" check above passes happily, because the file
    // does reference it. Both numbers have to move together.
    for (final entry in {
      'entity_list_app_bar.dart': listHeader,
      'tasks_view_toggle.dart': tasksHeader,
    }.entries) {
      expect(
        entry.value.contains('toolbarHeight: 64') ||
            entry.value.contains('Size.fromHeight(64)'),
        isFalse,
        reason:
            '${entry.key} still hardcodes 64 somewhere. If that is the '
            'preferredSize clamp, the toolbarHeight beside it is inert.',
      );
    }
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
