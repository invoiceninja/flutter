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
