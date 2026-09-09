import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Opt-out marker — see the doc below.
const String _kAllowMarker = 'lint: allow-bare-menu-anchor';

/// The one file allowed to build a bare `MenuAnchor`: the wrapper itself.
const String _kWrapper =
    'lib/ui/core/widgets/back_dismissible_menu_anchor.dart';

/// A `MenuAnchor` menu must be closable with Android's back gesture, which
/// means going through `BackDismissibleMenuAnchor`.
///
/// `MenuAnchor` binds Escape and closes on an outside tap, so on a desktop —
/// where this code is reviewed — it looks complete. It is **not a route**
/// though, and neither `menu_anchor.dart` nor `raw_menu_anchor.dart` contains a
/// `PopScope`, a `BackButtonListener` or a `NavigatorPopHandler`. The
/// `PopupMenuButton` these menus replaced is a `_PopupMenuRoute extends
/// PopupRoute`, which back closes for free — so the swap kept its outside-tap
/// semantics (`consumeOutsideTap: true`, which one call site's comment says out
/// loud) and silently dropped its back semantics. The result was that pressing
/// back with an entity list row's `⋮` open navigated off the list instead of
/// closing the menu, on the app's single most-used control.
///
/// Structural, and it has to be: the failure needs a real `Router`, an Android
/// back event and an open menu to observe, so nothing about a new call site
/// looks wrong at the call site. `BackDismissibleMenuAnchor`'s own behaviour is
/// covered by `test/ui/core/widgets/back_dismissible_menu_anchor_test.dart`;
/// this only makes sure new menus route through it.
void main() {
  test('no bare MenuAnchor outside the back-dismissible wrapper', () {
    // Word-boundary guard, or every `BackDismissibleMenuAnchor(` matches.
    final bare = RegExp(r'(?<![A-Za-z0-9_])MenuAnchor\(');
    final offenders = <String>[];

    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      if (file.path == _kWrapper) continue;
      final raw = file.readAsStringSync();
      if (raw.contains(_kAllowMarker)) continue;
      // Strip `//` tails: the prose explaining this rule names the token.
      final src = raw
          .split('\n')
          .map((l) {
            final i = l.indexOf('//');
            return i == -1 ? l : l.substring(0, i);
          })
          .join('\n');
      if (bare.hasMatch(src)) offenders.add(file.path);
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Use `BackDismissibleMenuAnchor` instead of a bare `MenuAnchor`. A '
          'MenuAnchor is not a route and has no back handling at all, so on '
          'Android the back gesture navigates away from the screen rather '
          'than closing the open menu. Add `// $_kAllowMarker <reason>` only if the '
          'menu genuinely owns its own back handling.',
    );
  });

  test('the wrapper still registers a back-button dispatcher', () {
    // The rule above only proves call sites route through the wrapper. This is
    // the wrapper's contract — without it every call site stays green while
    // every menu goes back to navigating away.
    final src = File(_kWrapper).readAsStringSync().replaceAll('\n', ' ');
    expect(
      src.contains('createChildBackButtonDispatcher()'),
      isTrue,
      reason:
          'BackDismissibleMenuAnchor must register a ChildBackButtonDispatcher '
          'while its menu is open — that is the only layer that runs BEFORE '
          'the Router pops a route. A PopScope cannot work here: '
          'ModalRoute.onPopInvokedWithResult notifies every registered entry, '
          "so SystemBackGate's would still navigate.",
    );
  });
}
