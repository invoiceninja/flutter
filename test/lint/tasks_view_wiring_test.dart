import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level guards for the Tasks layout preference
/// (invoiceninja/flutter#133).
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

  test('the preference is restored at boot', () {
    // Drop this line and the fix silently degrades to session-only: the mode
    // survives a cancel, but a relaunch is back on the plain list.
    expect(read('lib/main.dart'), contains('services.tasksView.restore()'));
  });
}
