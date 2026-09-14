import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level guards for the shell's focus-recovery wiring.
///
/// The app's entire keyboard layer — the global `Shortcuts` map, the `G` leader
/// `Focus`, and every list / pane / edit `Shortcuts` below them — lives inside
/// `ScaffoldWithNav`, and Flutter dispatches a key event only from
/// `FocusManager.primaryFocus` *upward*. So the moment primary focus lands at or
/// above the shell, all of it is skipped at once: shortcuts stop working and, on
/// macOS, every keystroke falls through to AppKit and beeps. `FocusOwnerKeeper`
/// is what puts focus back; its own behaviour is pumped in
/// `test/ui/core/widgets/focus_owner_keeper_test.dart`.
///
/// Scanned rather than pumped because `ScaffoldWithNav` needs `Services`, a
/// `GoRouter` and a `StatefulNavigationShell` — and because losing this wiring
/// is completely silent: the tree still builds, nothing throws, and every other
/// test in the suite stays green while the app answers no keystroke at all.
///
/// Matching is by bare identifier only. `dart format` re-wraps by line width, so
/// anything longer goes red on reflows that change no behaviour — the trap
/// `sidebar_search_box_test.dart` already sprang once.
void main() {
  /// Comments are stripped before scanning. Two of the `isFalse` checks below
  /// are for spellings whose *absence* is the point, and the code that avoids
  /// them says so in a comment naming them — so an unstripped scan fails on the
  /// very sentence that explains it.
  String read(String path) => File(path)
      .readAsLinesSync()
      .map((line) {
        final i = line.indexOf('//');
        return i == -1 ? line : line.substring(0, i);
      })
      .join('\n');

  final shell = read('lib/ui/features/shell/scaffold_with_nav.dart');
  final keeper = read('lib/ui/core/widgets/focus_owner_keeper.dart');
  final list = read('lib/ui/core/list/entity_list_screen_scaffold.dart');
  final searchField = read('lib/ui/core/list/search/token_search_field.dart');

  group('ScaffoldWithNav keeps a recoverable focus owner', () {
    test('the leader Focus is built with the retained node, not an '
        'anonymous one', () {
      expect(
        shell.contains('final FocusNode _shellFocus = FocusNode('),
        isTrue,
        reason:
            'an anonymous node cannot be re-focused, so `autofocus: true` '
            '— which fires exactly once — would be the only thing keeping the '
            'whole keyboard layer alive',
      );
      expect(shell.contains('focusNode: _shellFocus'), isTrue);
      expect(shell.contains('onKeyEvent: _handleLeaderKey'), isTrue);
      expect(
        shell.contains('_shellFocus.dispose()'),
        isTrue,
        reason: '`Focus` disposes only the node it created itself',
      );
    });

    test('Focus.withExternalFocusNode is not used', () {
      expect(
        shell.contains('withExternalFocusNode'),
        isFalse,
        reason:
            'that constructor stops applying `onKeyEvent` to the node, so '
            'the leader would silently never fire',
      );
    });

    test(
      'the shell is wrapped in a FocusOwnerKeeper holding the same node',
      () {
        expect(shell.contains('FocusOwnerKeeper('), isTrue);
        expect(shell.contains('node: _shellFocus'), isTrue);
        expect(
          shell.contains('focusIsStale: _focusInHiddenBranch'),
          isTrue,
          reason:
              'without the hidden-branch test, focus left behind in the '
              'branch the user just left keeps serving that branch\'s bare-key '
              'shortcuts',
        );
      },
    );
  });

  group('FocusOwnerKeeper contract', () {
    test('the escape test is ancestry, never equality with the root scope', () {
      expect(
        keeper.contains('ancestors.contains(widget.node)'),
        isTrue,
        reason:
            'a `primaryFocus == rootScope` check looks right and misses '
            'the commonest case — a popped root-navigator route hands focus to '
            'the shell page\'s own FocusScopeNode, which is not the root scope '
            'but is still an ancestor of everything that handles keys',
      );
    });

    test('the suspend and modal guards are still there', () {
      expect(
        keeper.contains('lifecycleState'),
        isTrue,
        reason:
            'while suspended the framework parks focus on the root scope '
            'on purpose and restores it on resume; reclaiming there blurs the '
            'field the user was typing in when they switched away',
      );
      expect(
        keeper.contains('_routeIsCurrent'),
        isTrue,
        reason:
            'a dialog / command palette / company picker above the shell '
            'legitimately owns focus',
      );
    });
  });

  group('the entity list owns focus for its own shortcuts', () {
    test('the list keeps a retained node behind a keeper, not an autofocus', () {
      expect(list.contains('FocusOwnerKeeper('), isTrue);
      expect(list.contains('node: _bodyFocus'), isTrue);
      expect(list.contains('focusNode: _bodyFocus'), isTrue);
      expect(list.contains('_bodyFocus.dispose()'), isTrue);
      expect(
        list.contains('autofocus:'),
        isFalse,
        reason:
            'autofocus is applied once, and only while the enclosing scope has '
            'no focused child — so it is silently dropped on a hot reload, on a '
            'list rebuilt under a route that already existed, and after a pane '
            'closes, which is exactly when N stops working',
      );
    });

    test('all three gates that keep two keepers off one focus are present', () {
      expect(list.contains('widget.embedded'), isTrue);
      expect(
        list.contains('TickerMode.valuesOf(context).enabled'),
        isTrue,
        reason:
            'go_router keeps every visited branch mounted, so without this the '
            "hidden branch's list and the visible one both claim, forever",
      );
      expect(
        list.contains('paneIsOpenForList(context)'),
        isTrue,
        reason:
            'the pane is a sibling of this node, not a descendant, so an open '
            'pane reads as escaped focus and the list would steal its Esc/J/K',
      );
    });
  });

  group('the / search slot follows the visible branch', () {
    test('TokenSearchField claims the slot under a TickerMode gate', () {
      expect(
        searchField.contains('TickerMode.valuesOf(context).enabled'),
        isTrue,
        reason:
            'StatefulShellRoute.indexedStack keeps every visited branch '
            'mounted, so a mount-time claim leaves the one-slot registry '
            'pointing at whichever field mounted last — `/` then focuses an '
            'offstage box, which also latches isTextInputFocused() on for the '
            'whole app',
      );
      expect(
        searchField.contains('_searchFocus?.current = _controller.focus'),
        isTrue,
      );
    });
  });
}
