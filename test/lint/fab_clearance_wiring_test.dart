import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `Scaffold` never insets its body for a floating action button, so the button
/// covers the bottom 72 px of whatever is under it. Every screen that mounts a
/// create FAB over content therefore has to pay that inset itself, or its last
/// row is unreachable at any scroll offset — which on a list row is exactly
/// where the `⋮` menu lives (invoiceninja/flutter#167, reported on Quotes;
/// #164 was the same bug on the dashboard).
///
/// That one argument is the part of the fix no widget test can reach on most of
/// these screens. The three custom Tasks views have no widget test that pumps
/// them at all (`test/ui/features/tasks/` covers view models, tiles and the
/// kanban), and `dashboard_screen_test.dart` never builds `MobileDashboardBody`
/// — the screen is only pumpable because its formatter future never completes,
/// which leaves the body a spinner. So: a scan, the shape
/// `running_timer_pill_wiring_test.dart` uses for the same reason. Dropping the
/// argument would put the last row back under the button, silently.
///
/// The list scaffold is the one surface with real geometry coverage —
/// `test/ui/core/list/entity_list_fab_clearance_test.dart` scrolls a Quotes
/// list to its end and measures the last row against the button — so it is
/// carried by both.
///
/// This is a TABLE, not a blanket "every file with a `FloatingActionButton`".
/// The billing-doc editors (`billing_doc_edit_fab.dart` and its five layouts)
/// and the WYSIWYG reorder view are deliberately out of scope — the reorder
/// view carries its own literal, and the editors are a known remaining gap —
/// and a blanket rule would need an exemption list per file, which is a special
/// case pretending to be a rule.
void main() {
  /// [path]'s source with `//` tails stripped, so a comment naming the helper
  /// cannot satisfy the scan.
  String code(String path) {
    final f = File(path);
    expect(f.existsSync(), isTrue, reason: '$path is missing');
    return f
        .readAsLinesSync()
        .map((l) {
          final i = l.indexOf('//');
          return i == -1 ? l : l.substring(0, i);
        })
        .join('\n');
  }

  /// Every file that both mounts a create FAB and owns the content under it.
  ///
  /// The dashboard is the odd one out: its body already sits in a `SafeArea`,
  /// so it adds the bare [kFabClearance] to its own gutter rather than calling
  /// `fabScrollClearance`, which would apply the safe inset a second time.
  const surfaces = <({String path, String fab, String clearance})>[
    (
      path: 'lib/ui/core/list/entity_list_screen_scaffold.dart',
      fab: 'FloatingActionButton(',
      clearance: 'fabScrollClearance(',
    ),
    (
      path: 'lib/ui/features/tasks/views/task_daily_screen.dart',
      fab: 'FloatingActionButton(',
      clearance: 'fabScrollClearance(',
    ),
    (
      path: 'lib/ui/features/tasks/views/task_weekly_screen.dart',
      fab: 'FloatingActionButton(',
      clearance: 'fabScrollClearance(',
    ),
    (
      path: 'lib/ui/features/tasks/views/task_calendar_screen.dart',
      fab: 'FloatingActionButton(',
      clearance: 'fabScrollClearance(',
    ),
    (
      path: 'lib/ui/features/dashboard/views/dashboard_screen.dart',
      fab: 'DashboardCreateFab(',
      clearance: 'kFabClearance',
    ),
  ];

  for (final s in surfaces) {
    test('${s.path.split('/').last} clears its FAB', () {
      final src = code(s.path);
      expect(
        src,
        contains(s.fab),
        reason:
            'this table is the set of screens that mount a create FAB — if '
            '${s.path} no longer does, drop its row instead of loosening the '
            'rule',
      );
      expect(
        src,
        contains(s.clearance),
        reason:
            'the content under the FAB in ${s.path} must be inset by '
            '${s.clearance}, or its last row can never scroll clear of the '
            'button',
      );
    });
  }

  test('the clearance has exactly one definition', () {
    final home = code('lib/ui/core/utils/fab_clearance.dart');
    expect(home, contains('const double kFabClearance'));
    expect(home, contains('double fabScrollClearance('));

    // The number itself lives in one place. A second `56 + kFloating…` is how
    // the dashboard's copy and the list's would drift apart again.
    final lib = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    final definers = [
      for (final f in lib)
        if (f.path != 'lib/ui/core/utils/fab_clearance.dart' &&
            code(f.path).contains('56 + kFloatingActionButtonMargin'))
          f.path,
    ];
    expect(
      definers,
      isEmpty,
      reason: 'the FAB geometry belongs to kFabClearance alone',
    );
  });
}
