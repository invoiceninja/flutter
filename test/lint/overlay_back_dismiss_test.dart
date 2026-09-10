import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Opt-out marker. Each occurrence exempts exactly ONE host in its file.
const String _kAllowMarker = 'lint: allow-no-overlay-back-dismiss';

/// A hand-rolled `OverlayPortal` is not a route, so Android's back has to be
/// wired by hand — through `BackDismissibleOverlay`
/// (`lib/ui/core/widgets/picker_dismissal.dart`).
///
/// Flutter gives a non-route overlay no back handling at all. Unhandled, the
/// press reaches `SystemBackGate`, which runs `NavHistoryController.back()` and
/// leaves the screen — or calls `SystemNavigator.pop()` and **exits the app**,
/// on the ordinary case of a session restored straight onto that screen. A
/// `PopScope` cannot substitute: `ModalRoute` notifies every registered
/// `PopEntry`, so `SystemBackGate`'s would still navigate.
///
/// The two hosts this exists for are `token_search_field.dart`'s suggestion and
/// segment menus, and the reason it is a lint rather than a widget test is that
/// the failure needs a real `Router` plus an Android back event to observe —
/// nothing about a new `OverlayPortal` looks wrong at the call site. It is also
/// invisible on a desktop review, which has Escape.
///
/// **This is not a desktop-only surface.** The wide search field is gated on
/// `searchWide = wide || globalNav` (`entity_list_screen_scaffold.dart`) where
/// `Breakpoints.isGlobalNavVisible` is a raw `MediaQuery.width >= 600` with no
/// platform test anywhere in the chain — so every tablet, every unfolded
/// foldable and **every phone in landscape** (~890 dp) reaches it.
///
/// Know the limits. Like its siblings (`picker_popover_wiring_test.dart`,
/// `menu_anchor_back_dismiss_test.dart`) this is an existence/count check: it
/// proves the wrapper is *present* in a file that builds an `OverlayPortal`, not
/// that it wraps the overlay child rather than the anchor — "mounted means open"
/// is the whole mechanism and only a reader can see that it still holds — and
/// not that `onBack` actually dismisses anything. That last one matters: an
/// `onBack` that dismisses nothing still returns `true`, which produces "back is
/// dead", strictly worse than the bug. It says nothing about routes
/// (`showMenu`, `PopupMenuButton`, `DropdownButton`, dialogs), which back
/// already closes for free, nor about `Tooltip`'s internal `OverlayPortal`,
/// which no user dismisses.
void main() {
  test('every hand-rolled OverlayPortal closes on Android back', () {
    final offenders = <String>[];

    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final raw = file.readAsStringSync();
      // Strip `//` tails: the prose explaining this rule names every token it
      // matches, so an un-stripped scan fails on its own documentation.
      final src = raw
          .split('\n')
          .map((l) {
            final i = l.indexOf('//');
            return i == -1 ? l : l.substring(0, i);
          })
          .join('\n');

      // All three constructors, not just the unnamed one. The SDK's own
      // preferred form for an anchored overlay is
      // `OverlayPortal.overlayChildLayoutBuilder(` — which `autocomplete.dart`
      // itself uses — and it contains no `OverlayPortal(` substring, so
      // counting only that would score a file with one as ZERO hosts and pass
      // it with no wrapper at all. `targetsRootOverlay(` has the same hole.
      // The sibling lint takes the same care over `RawAutocomplete<` vs the
      // type-inferred `RawAutocomplete(`.
      final hosts = RegExp(
        r'OverlayPortal(\.(overlayChildLayoutBuilder|targetsRootOverlay))?\(',
      ).allMatches(src).length;
      if (hosts == 0) continue;
      final covered =
          'BackDismissibleOverlay('.allMatches(src).length +
          _kAllowMarker.allMatches(raw).length;
      if (covered < hosts) {
        offenders.add('${file.path} ($hosts host(s), $covered covered)');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Every hand-rolled `OverlayPortal` must wrap its overlay child in '
          '`BackDismissibleOverlay(onBack: …)`. Without it Android back '
          'navigates off the screen — or exits the app — instead of closing '
          'the overlay, because a non-route overlay gets no back handling from '
          'Flutter. Add the wrapper, or one `// $_kAllowMarker <reason>` per '
          'exempt host.',
    );
  });
}
