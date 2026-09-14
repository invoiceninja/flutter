import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source guards for how a task timer starts (invoiceninja/flutter#149).
///
/// Scanned rather than exercised because **every failure here is silent**. A
/// start path that skips `planTaskStart` compiles, runs, and writes a
/// `time_log` the server rejects with a 422 that surfaces minutes later as a
/// dead outbox row — or, when the booking has already passed, one it *accepts*,
/// silently billing hours nobody worked. Nothing throws and no widget looks
/// wrong. Same reasoning as `tasks_view_wiring_test.dart`.
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

  test('every path that opens a time entry goes through planTaskStart', () {
    // Four, not two: the repository primitive behind the inline toggles and
    // the bulk toolbar, the ⋮ menu's Start and Resume (which share
    // `_beginTimer`), and the edit screen's own draft-level button, which
    // never touches the repository at all.
    for (final path in const [
      'lib/data/repositories/task_repository.dart',
      'lib/ui/features/tasks/view_models/task_edit_view_model.dart',
    ]) {
      expect(
        codeOf(path),
        contains('planTaskStart('),
        reason: '$path opens a time entry without consulting the planner',
      );
    }
    // The menu must not hand-roll one either — it delegates to the repository.
    final actions = codeOf('lib/ui/features/tasks/widgets/task_actions.dart');
    expect(actions, contains('services.tasks.startTimer('));
    // A pattern, not one exact literal: `TimeEntry(start: DateTime.now(),
    // stop: null)`, a renamed local, or a trailing comma all sail past a
    // string compare of the spelling that happened to be there.
    expect(
      RegExp(r'TimeEntry\(\s*start:[^)]*stop:\s*null').hasMatch(actions),
      isFalse,
      reason:
          'task_actions must not open a running entry by hand — that is '
          'exactly the append planTaskStart exists to replace',
    );
  });

  test('one Start glyph across every task surface (flutter#153)', () {
    // The reporter's "one uses a circle around the play symbol, the other
    // doesn't". `stop_circle_outlined` has no un-circled Material sibling, so
    // the pair is settled in the circled direction and the bare arrow is out.
    final dir = Directory('lib/ui/features/tasks');
    final offenders = <String>[];
    for (final file in dir.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final code = file
          .readAsLinesSync()
          .map((line) {
            final i = line.indexOf('//');
            return i < 0 ? line : line.substring(0, i);
          })
          .join('\n');
      if (code.contains('play_arrow')) offenders.add(file.path);
    }
    expect(offenders, isEmpty, reason: 'use Icons.play_circle_outlined');
  });

  test('the booked-time slot replaces the duration, never joins it', () {
    // A window chip beside the duration costs 80–110 px of a 187 px identity
    // column on a 411 px phone — #125/#131 re-created. `taskScheduleSlot`
    // returns null when nothing is booked precisely so the caller can fall
    // back to `formatDuration` in the SAME slot.
    for (final path in const [
      'lib/ui/features/tasks/widgets/task_list_tile.dart',
      'lib/ui/features/tasks/widgets/kanban/kanban_card.dart',
    ]) {
      final code = codeOf(path);
      expect(code, contains('taskScheduleSlot('));
      expect(
        code,
        contains('slot?.text ??'),
        reason: '$path must fall back into the same slot, not add a second',
      );
    }
  });
}
