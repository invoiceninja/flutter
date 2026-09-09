import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `InSidebar` cannot be widget-tested — pumping it deadlocks on the
/// saved-views Drift watch, which `AppDatabase.close()` then waits on forever
/// (see `sidebar_search_box_test.dart` and `sidebar_footer_wiring_test.dart`).
/// So the menu feature's wiring inside that file is pinned by reading the
/// source, the same way the footer's is.
///
/// Everything the grid *renders* is covered properly by
/// `sidebar_nav_grid_test.dart` and `sidebar_nav_item_test.dart`; what's left
/// here is only what those cannot see from outside.
void main() {
  final sidebar = File(
    'lib/ui/features/shell/widgets/in_sidebar.dart',
  ).readAsStringSync();

  test('the nav list is ordered by the user preference, not the registry', () {
    // The registry order is still the *default*, but if this call goes away the
    // sidebar silently ignores everything the Customize sheet writes and the
    // only symptom is "reordering does nothing".
    expect(
      sidebar,
      contains('sidebarMenu.entriesFor('),
      reason:
          'in_sidebar.dart must resolve its nav block through '
          'SidebarMenuController.entriesFor, or the user\'s menu order is '
          'silently ignored.',
    );
  });

  test('the grid layout is actually reachable from the sidebar', () {
    expect(
      sidebar,
      contains('SidebarNavGrid('),
      reason: 'the grid menu layout has no host.',
    );
    expect(
      sidebar,
      contains('SidebarMenuLayout.grid'),
      reason: 'nothing selects the grid layout.',
    );
  });

  test('a menu change repaints a sidebar that is already mounted', () {
    // A detail screen (and the rail behind `/settings/**`) stays mounted while
    // the user flips the layout, so a build-time read with no listener would
    // leave the old menu on screen until some unrelated rebuild came along.
    expect(
      sidebar,
      contains('listenable: services.sidebarMenu'),
      reason:
          'the nav list must listen to SidebarMenuController, not just read '
          'it during build.',
    );
  });

  test('nothing in the griddable block can hide itself asynchronously', () {
    // Every grid cell must render something. Outbox is the one row in the
    // sidebar whose visibility resolves inside a StreamBuilder
    // (`hideWhenZero`), so it stays out of the block — otherwise a cell could
    // collapse to nothing and leave an empty column behind it, the failure
    // invoiceninja/flutter#124 already paid for once.
    final start = sidebar.indexOf('List<_NavEntry> _buildMenuEntries(');
    expect(start, isNonNegative, reason: '_buildMenuEntries went away');
    final end = sidebar.indexOf('Widget _entityNav(', start);
    expect(end, greaterThan(start), reason: '_entityNav went away');

    expect(
      sidebar.substring(start, end),
      isNot(contains('hideWhenZero')),
      reason:
          'a destination that hides itself asynchronously cannot be a grid '
          'cell — keep it out of _buildMenuEntries.',
    );
  });

  test('the badge cache learns which entity rows are still rendered', () {
    // `_noteBadgeMode` only fires for a row that renders, so hiding one would
    // otherwise strand its Drift query live for the rest of the session.
    final start = sidebar.indexOf('List<_NavEntry> _buildMenuEntries(');
    final end = sidebar.indexOf('Widget _entityNav(', start);
    expect(
      sidebar.substring(start, end),
      contains('_noteRenderedEntities('),
      reason:
          'hiding a menu row leaks its badge stream unless _buildMenuEntries '
          'reports the rendered set back to the cache.',
    );
  });

  group('pinned chrome rows (invoiceninja/flutter#131)', () {
    // Settings and Outbox are chrome, not menu destinations: they render below
    // the nav scroller so they cannot scroll away, and in grid mode so the tile
    // block no longer runs straight into a full-width row.
    //
    // All of this is source-scanned for the reason at the top of the file, and
    // one of the three assertions below is the only thing in the suite that can
    // see a half-done job at all: `hideWhenZero` means a developer with an
    // empty outbox never renders that row, so a missing `selection:` on it is
    // invisible on screen.

    test('the chrome rows are out of the scrolling list', () {
      final start = sidebar.indexOf('List<Widget> _buildItems(');
      expect(start, isNonNegative, reason: '_buildItems went away');
      final end = sidebar.indexOf('Widget _pinnedChromeRows(', start);
      expect(
        end,
        greaterThan(start),
        reason:
            '_pinnedChromeRows must be defined right after _buildItems — and '
            'before _buildMenuEntries, or the `hideWhenZero` guard above fails '
            'with a message about grid cells.',
      );
      final body = sidebar.substring(start, end);
      expect(
        body,
        isNot(contains('FixedBranchKind.settings')),
        reason: 'Settings is pinned below the scroller, not built into it.',
      );
      expect(
        body,
        isNot(contains('FixedBranchKind.outbox')),
        reason: 'Outbox is pinned below the scroller, not built into it.',
      );
    });

    test('the block mounts below the nav rule, above the footer actions', () {
      // `indexOf` finds the CALL, which precedes the definition in this file —
      // that is exactly the ordering being asserted.
      final scroller = sidebar.indexOf('SingleChildScrollView(');
      final chrome = sidebar.indexOf('_pinnedChromeRows(');
      final footer = sidebar.indexOf('SidebarFooterActions(');
      expect(scroller, isNonNegative);
      expect(chrome, greaterThan(scroller));
      // Below the RULE, not merely below the scroller. Without this the block
      // could be hoisted between the two and every assertion here would still
      // pass — leaving a half-clipped nav row abutting the Settings row with
      // nothing between them, which is the arrangement the design paragraph
      // rejects. Searched from the scroller so it finds the nav rule rather
      // than the identical one under the header.
      final rule = sidebar.indexOf(
        'Container(height: 1, color: tokens.border)',
        scroller,
      );
      expect(rule, isNonNegative, reason: 'the nav rule went away');
      expect(
        chrome,
        greaterThan(rule),
        reason:
            'the chrome rows belong below the nav rule — the scroll viewport '
            'clips there, so the rule is what gives a partially scrolled row a '
            'crisp edge instead of resting on Settings.',
      );
      expect(
        footer,
        greaterThan(chrome),
        reason:
            'the chrome rows must sit above SidebarFooterActions. Moving them '
            'down among the footer siblings would put a nav row inside the '
            'help/theme group and below the white-label upsell gate — and '
            'every other lint would still pass, since sidebar_footer_wiring '
            'only guards the region below WhiteLabelFooter.',
      );
    });

    test('both chrome rows opt into the neutral selection', () {
      final start = sidebar.indexOf('Widget _pinnedChromeRows(');
      expect(start, isNonNegative, reason: '_pinnedChromeRows went away');
      final end = sidebar.indexOf('List<_NavEntry> _buildMenuEntries(', start);
      expect(end, greaterThan(start), reason: '_buildMenuEntries went away');
      final body = sidebar.substring(start, end);
      expect(body, contains('FixedBranchKind.settings'));
      expect(body, contains('FixedBranchKind.outbox'));
      expect(
        'SidebarNavSelection.neutral'.allMatches(body).length,
        2,
        reason:
            'both pinned rows must pass selection: neutral. The Outbox row is '
            'the one that goes unnoticed — hideWhenZero hides it from anyone '
            'whose outbox is empty, so it would keep the accent fill in '
            'release with a green suite and a clean screenshot.',
      );
    });
  });

  test('the preference is restored at boot', () {
    // Forgetting this line is the classic form of this bug: the choice
    // persists and simply never comes back on the next launch.
    expect(
      File('lib/main.dart').readAsStringSync(),
      contains('services.sidebarMenu.restore()'),
      reason: 'add it to the boot Future.wait beside the other device prefs.',
    );
  });
}
