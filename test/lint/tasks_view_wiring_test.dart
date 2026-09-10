import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level guards for the Tasks layout preference
/// (invoiceninja/flutter#133), for the kanban screen's deliberate lack of a
/// create FAB (invoiceninja/flutter#135), and for the one responsive gate the
/// four custom views feed to both their AppBar and their filter bar
/// (invoiceninja/flutter#136).
///
/// Scanned rather than exercised because reaching any of it for real needs the
/// whole app graph — a router, a live `Services`, and a `KanbanScreen` that
/// builds a ViewModel over Drift — and because **every failure here is silent**:
/// the app compiles, the toggle still switches views, and the only symptom is
/// that a preference stops sticking, or that a board quietly replaces the list
/// behind an open pane. Same reasoning as `status_tab_wiring_test.dart`.
void main() {
  String read(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path has moved');
    return file.readAsStringSync();
  }

  /// [read] with every `//` tail removed, so a rule can't be satisfied — or
  /// broken — by the prose that explains it. The trap
  /// `no_list_tile_name_link_test.dart` already records.
  String codeOf(String path) => read(path)
      .split('\n')
      .map((line) {
        final i = line.indexOf('//');
        return i < 0 ? line : line.substring(0, i);
      })
      .join('\n');

  const views = [
    'lib/ui/features/tasks/views/kanban_screen.dart',
    'lib/ui/features/tasks/views/task_daily_screen.dart',
    'lib/ui/features/tasks/views/task_weekly_screen.dart',
    'lib/ui/features/tasks/views/task_calendar_screen.dart',
  ];

  test('the tasks listBuilder resolves ?view= through the shared parser', () {
    // An inline `switch` here would compile, behave identically for the four
    // named modes, and silently drop the null arm that makes the remembered
    // preference reachable at all — while `tasks_view_mode_test.dart` stayed
    // green, because it tests the parser this file would have stopped calling.
    expect(
      read('lib/app/entity_modules.dart'),
      contains('tasksViewModeFromQuery(state.uri.queryParameters['),
    );
  });

  test('the tasks listBuilder passes the two lock signals', () {
    final source = read('lib/app/entity_modules.dart');
    // Without `hasPane`, a remembered board mounts behind every open task pane.
    // Only `EntityListScreenScaffold` publishes into `MasterDetailNavController`,
    // so J/K row-stepping and `EntityDetailScaffold`'s first-frame seed both go
    // dead, and a remembered calendar fires a connection-status request per
    // record opened. Nothing throws; the pane just opens on a spinner.
    expect(source, contains("hasPane: state.matchedLocation != '/tasks'"));
    // Without `hasListIntent`, a dashboard task card's drill-down lands on the
    // board, which never reads the intent.
    expect(source, contains('hasListIntent: state.extra is ListFilterIntent'));
  });

  test('TaskListScreen locks every branch that can only be the list', () {
    final source = read('lib/ui/features/tasks/views/task_list_screen.dart');
    for (final arm in [
      'embedded ||',
      'hasPane ||',
      'hasListIntent ||',
      'clientId != null ||',
      'projectId != null',
    ]) {
      expect(source, contains(arm), reason: 'lock arm "$arm" is gone');
    }
    // The read must stay live: the toggle sets the preference and navigates to
    // the same bare `/tasks` the board is already on, which
    // `GoRouterDelegate.setNewRoutePath` short-circuits — so this subscription
    // is the entire repaint path for a view switch.
    expect(source, contains('ValueListenableBuilder<TasksViewMode?>'));
    expect(source, contains('context.read<Services>().tasksView'));
    // ...and it must stay UNCONDITIONAL. An `if (widget.locked) return …`
    // before it alternates the widget at the list's slot between
    // `ValueListenableBuilder` and `EntityListScreenScaffold` every time a pane
    // opens or closes, so `Widget.canUpdate` fails and the list is remounted —
    // resetting its scroll, rebuilding its ViewModel back to page 1 and
    // stranding `MasterDetailNavController` without the row the pane just
    // opened. Invisible on narrow (which remounts anyway) and in every test.
    final remembered = source.substring(
      source.indexOf('class _RememberedTasksView'),
    );
    expect(
      RegExp(r'if \(widget\.locked\)[^\n]*return').hasMatch(remembered),
      isFalse,
      reason:
          '_RememberedTasksView returns early on `locked`, so the element at '
          'the list slot changes type on every pane open/close.',
    );
    // `locked` has to reach the resolver instead.
    expect(source, contains('locked: widget.locked'));
  });

  test('the view toggle writes the preference and adds no history step', () {
    final source = read('lib/ui/features/tasks/widgets/tasks_view_toggle.dart');
    // The toggle is the second preference writer (the mirror in
    // `TaskListScreen` is the first, covering the URL-driven paths). Drop this
    // and picking a view stops sticking at all.
    expect(source, contains('tasksView.set(next)'));
    // And it must emit no `?view=`: `isUpNavigation` compares paths only, so
    // `/tasks` and `/tasks?view=kanban` are separate history entries, and
    // Android back onto the bare one would re-render the board from the
    // preference and look like it did nothing.
    expect(source, contains("context.go('/tasks')"));
    expect(
      source.contains(r"'/tasks?view=$"),
      isFalse,
      reason: 'the toggle is emitting ?view= again — that is a history step',
    );
  });

  test('the kanban screen has no create FAB', () {
    // Its three siblings — daily / weekly / calendar — each hardcode an
    // identical `FloatingActionButton`, and they keep it: a FAB may only be
    // dropped where the substitute is the SAME verb. Daily and weekly do have
    // a second create (`TaskDailyActions.logTime`, behind an always-visible
    // `Log time` button), but it pre-fills a time entry and says so, and
    // calendar's is convert-this-event — neither is a plain new task. Kanban's
    // FAB was the one true duplicate: every column already ends in a
    // `+ New Task` that seeds that column's status, where the FAB seeded
    // nothing (so a task saved with the picker left blank landed in no column
    // until the server assigned one) and on a phone sat over a column's own
    // footer. React's kanban has no page-level create control either
    // (invoiceninja/flutter#135).
    //
    // Scanned rather than pumped: `KanbanScreen` builds a `KanbanViewModel`
    // over two live Drift watch streams, and re-adding the FAB "for consistency
    // with the other three" compiles, runs, and looks perfectly ordinary in a
    // desktop review.
    //
    // Comments are stripped first, or this fails on the very comment in
    // `kanban_screen.dart` that explains the absence — the trap
    // `no_list_tile_name_link_test.dart` already records.
    final source = codeOf('lib/ui/features/tasks/views/kanban_screen.dart');
    expect(
      source.contains('loatingActionButton'),
      isFalse,
      reason:
          'KanbanScreen has a FAB again — the per-column "+ New Task" is the '
          'board\'s create affordance (invoiceninja/flutter#135).',
    );
  });

  test('the column\'s create gate is not the reorder gate', () {
    // `KanbanBoard` folds `!filtersActive` into `canEdit` so a reorder can
    // never be computed from a partial set. With the FAB gone the footer is the
    // board's ONLY create path, so passing that same expression as `canCreate`
    // would take it away from anyone who applies a filter — and `create_task`
    // is what the server authorizes a create against, which `can()` never
    // derives from `edit_task`. Both halves are silent: the footer just isn't
    // drawn. `kanban_column_test.dart` pins the widget's side of this.
    final source = read(
      'lib/ui/features/tasks/widgets/kanban/kanban_board.dart',
    );
    expect(source, contains("me?.can('create_task')"));
    expect(source, contains('canCreate: canCreate,'));
    // The argument alone is not enough: the filter reads just as naturally
    // folded into the DECLARATION (`final canCreate = (…) && !vm.filtersActive`
    // ), which leaves `canCreate: canCreate,` intact and both assertions above
    // green. Count the mentions instead — there must be exactly two, and both
    // must be reorder gates. Comments are stripped or the count picks up the
    // one right beside `canCreate:` explaining why it is NOT folded in.
    final gates = source
        .split('\n')
        .map((line) {
          final i = line.indexOf('//');
          return i < 0 ? line : line.substring(0, i);
        })
        .where((line) => line.contains('filtersActive'))
        .map((line) => line.trim())
        .toList();
    expect(
      gates,
      [
        'canEdit: canEdit && !vm.filtersActive,',
        'onAcceptStatus: (canEdit && !vm.filtersActive)',
      ],
      reason:
          'a filter reached the create gate — a filtered board would then have '
          'no way to create a task at all (invoiceninja/flutter#135).',
    );
    expect(
      read('lib/ui/features/tasks/widgets/kanban/kanban_column.dart'),
      contains('if (canCreate) ...['),
    );
  });

  test('the preference is restored at boot', () {
    // Drop this line and the fix silently degrades to session-only: the mode
    // survives a cancel, but a relaunch is back on the plain list.
    expect(read('lib/main.dart'), contains('services.tasksView.restore()'));
  });

  /// Each custom view must derive **one** bool and feed it to both consumers.
  ///
  /// `Scaffold.appBar` is built outside the body, so the filter bar can never
  /// inform the AppBar — the gate has to sit at the screen. Compute it twice
  /// and the two disagree in the 600-832 px window band, where the 232 px rail
  /// leaves a sub-600 pane: either both chromes render, or neither does and the
  /// Tasks filters become unreachable while previously-set chips can be deleted
  /// but never set. Both are silent, and both look right on a desktop — which
  /// is where this gets reviewed.
  test('each task view computes the filter gate once and feeds both halves', () {
    for (final path in views) {
      final dense = codeOf(path).replaceAll(RegExp(r'\s+'), '');
      expect(
        dense,
        contains('finalinline=taskFiltersInline('),
        reason: '$path must derive the gate from the shared predicate',
      );
      expect(
        dense,
        contains('finalwide=Breakpoints.isWide(constraints);'),
        reason:
            '$path must derive the pane width once — the AppBar\'s flavour, its '
            'filter action and (on three of the four) the view header all read '
            'it, and a second read drifts from the first',
      );
      expect(
        dense,
        contains('wide:wide,'),
        reason: '$path must hand that same bool to the AppBar',
      );
      expect(
        dense,
        contains('filters:inline?null:_vm,'),
        reason: '$path must only offer the AppBar action while collapsed',
      );
      expect(
        dense,
        contains('inline:inline,'),
        reason: '$path must pass the same bool to the bar',
      );
      expect(
        dense,
        contains('onEditFilters:_openFilters,'),
        reason:
            '$path must route the AppBar action and the chips to one call site',
      );
    }
  });

  /// The three time-oriented views must hand their header the same bool.
  ///
  /// Each header used to read `MediaQuery.sizeOf(context).width` for itself —
  /// the *window*, while the header lives in the *pane* — so in the 600-832 px
  /// band (rail up, pane under 600) they drew full-label chrome into a narrow
  /// pane. `TaskCalendarHeader` had no width branch at all and clipped outright
  /// (invoiceninja/flutter#136); `task_calendar_header_test.dart` sweeps that.
  test('the three view headers take the screen\'s pane bool', () {
    const headers = {
      'lib/ui/features/tasks/views/task_daily_screen.dart': 'TaskDailyHeader(',
      'lib/ui/features/tasks/views/task_weekly_screen.dart': '_WeeklyHeader(',
      'lib/ui/features/tasks/views/task_calendar_screen.dart':
          'TaskCalendarHeader(',
    };
    headers.forEach((path, ctor) {
      // The *argument list*, not a literal spelling of it: pinning
      // `${ctor}formatter:_formatter,wide:wide)' would also pin the argument
      // order and the absence of a trailing comma, both of which belong to
      // `dart format` — so reordering two named arguments, or adding a third
      // long enough to make the call wrap, turned this red with a message
      // about the pane bool.
      expect(
        _argsOf(codeOf(path), ctor),
        contains('wide:wide'),
        reason: '$path must pass the pane bool to its header',
      );
    });

    for (final path in const [
      'lib/ui/features/tasks/widgets/daily/task_daily_header.dart',
      'lib/ui/features/tasks/views/task_weekly_screen.dart',
      'lib/ui/features/tasks/widgets/calendar/task_calendar_header.dart',
    ]) {
      // Every way of asking, not the one receiver the bug happened to use:
      // `MediaQuery.sizeOf(context).width >=` was the original spelling, so
      // hoisting the read into a local (`final w = MediaQuery.sizeOf(context)
      // .width;` … `w >= Breakpoints.wide`) or reaching for the older
      // `MediaQuery.of(context).size` re-introduced it with the lint green.
      // A pane-shaped surface has no business reading the window's *size* at
      // all; `textScalerOf` is deliberately not on this list — the calendar
      // header scales its own label budget by it, which is a text question,
      // not a width one.
      final code = codeOf(path).replaceAll(RegExp(r'\s+'), '');
      for (final probe in const [
        'MediaQuery.sizeOf(',
        'MediaQuery.maybeSizeOf(',
        'MediaQuery.of(context).size',
      ]) {
        expect(
          code.contains(probe),
          isFalse,
          reason:
              '$path is a pane-width surface, and `$probe` reads the window — '
              'which is what put full-label chrome in a sub-600 pane.',
        );
      }
    }
  });

  /// The wide branch renders through `flexibleSpace`, and `AppBar` builds
  /// `Stack([flexibleSpace, Material(toolbar)])` — so the toolbar paints *over*
  /// it and, hit-testing being reverse paint order, an `actions:` entry there
  /// would sit on top of `TasksViewToggle` and swallow its taps. The filter
  /// action therefore goes into that branch's own `Row`, and only the narrow
  /// branch has an `actions:` list at all.
  test('the tasks AppBar takes its width and keeps one actions slot', () {
    final code = codeOf('lib/ui/features/tasks/widgets/tasks_view_toggle.dart');
    expect(code, contains('required bool wide,'));
    expect(
      code.contains('MediaQuery.sizeOf(context).width >='),
      isFalse,
      reason:
          'the flavour gate must arrive as a parameter — read here it is the '
          'window, while the pickers collapse on the pane.',
    );
    expect(
      'actions:'.allMatches(code).length,
      1,
      reason:
          'only the narrow branch may have an `actions:` list; in the wide one '
          'it paints over the view toggle and steals its taps.',
    );
    // The single construction site is sized from the same bool that picked the
    // branch, so the 45 px `flexibleSpace` row cannot get a 48 px button.
    expect(code, contains('dense: wide'));
  });

  test('the filter icon is the shared widget, not a second copy', () {
    final activity = codeOf(
      'lib/ui/features/activity/views/activity_screen.dart',
    );
    expect(activity, contains('FilterIconButton('));
    expect(
      activity.contains('class _FilterButton'),
      isFalse,
      reason:
          'Activity and Tasks must not drift on the dot; the leaf lives in '
          'lib/ui/core/widgets/filter_icon_button.dart.',
    );
  });
}

/// The paren-balanced argument list of the first `ctor` call in [source],
/// whitespace stripped — so a nested call in a later argument cannot truncate
/// the match the way a `substring` to the first `)` would.
String _argsOf(String source, String ctor) {
  final dense = source.replaceAll(RegExp(r'\s+'), '');
  final start = dense.indexOf(ctor);
  if (start < 0) return '';
  var depth = 0;
  for (var i = start + ctor.length - 1; i < dense.length; i++) {
    if (dense[i] == '(') depth++;
    if (dense[i] == ')') {
      depth--;
      if (depth == 0) return dense.substring(start + ctor.length, i);
    }
  }
  return '';
}
