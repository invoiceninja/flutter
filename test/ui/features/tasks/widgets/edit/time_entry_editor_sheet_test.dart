import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/ui/features/tasks/widgets/edit/time_entry_editor_sheet.dart';

import '../../../../../_responsive_helper.dart';

/// Only Cancel discards the sheet's edit. The barrier covers the task form's
/// Save and Stop buttons, so a tap on either closed the sheet and threw away
/// the description the user had just typed (beta feedback: "lost description
/// when stopping task or saving task").
void main() {
  final start = DateTime.utc(2026, 6, 5, 11);
  final entry = TimeEntry(
    start: start,
    stop: start.add(const Duration(hours: 1)),
  );
  final running = TimeEntry(start: start, stop: null);

  /// Opens the sheet at phone width and returns a getter for what `show`
  /// resolved with (null until it resolves, and when it resolves to null).
  Future<({TimeEntry? Function() result, bool Function() done})> open(
    WidgetTester tester,
    TimeEntry initial, {
    double width = 560,
  }) async {
    TimeEntry? result;
    var done = false;
    await pumpAt(
      tester,
      width,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await TimeEntryEditorSheet.show(context, initial: initial);
            done = true;
          },
          child: const Text('open'),
        ),
      ),
      height: 844,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return (result: () => result, done: () => done);
  }

  Future<void> typeDescription(WidgetTester tester, String text) async {
    final field = find.descendant(
      of: find.byType(TimeEntryEditorSheet),
      matching: find.byWidgetPredicate(
        (w) => w is TextField && w.minLines == 3,
      ),
    );
    await tester.enterText(field, text);
    await tester.pump();
  }

  Future<void> tapBarrier(WidgetTester tester) async {
    await tester.tapAt(const Offset(280, 20));
    await tester.pumpAndSettle();
  }

  testWidgets('a tap outside the sheet keeps the typed description', (
    tester,
  ) async {
    final r = await open(tester, entry);
    await typeDescription(tester, 'Replaced the valve\nTested the line');
    await tapBarrier(tester);

    expect(r.done(), isTrue);
    expect(r.result()?.description, 'Replaced the valve\nTested the line');
    expect(r.result()!.start!.isAtSameMomentAs(entry.start!), isTrue);
    expect(r.result()!.stop!.isAtSameMomentAs(entry.stop!), isTrue);
  });

  testWidgets('a running entry stays running when dismissed with an edit', (
    tester,
  ) async {
    final r = await open(tester, running);
    await typeDescription(tester, 'On site');
    await tapBarrier(tester);

    expect(r.result()?.description, 'On site');
    expect(r.result()!.isRunning, isTrue);
  });

  testWidgets('a swipe-style pop (Navigator.pop) keeps the edit too', (
    tester,
  ) async {
    final r = await open(tester, entry);
    await typeDescription(tester, 'Notes');
    // The drag-to-dismiss path pops with Navigator.pop, past any PopScope.
    Navigator.of(tester.element(find.byType(TimeEntryEditorSheet))).pop();
    await tester.pumpAndSettle();

    expect(r.result()?.description, 'Notes');
  });

  testWidgets('Cancel still discards', (tester) async {
    final r = await open(tester, entry);
    await typeDescription(tester, 'Throw me away');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(r.done(), isTrue);
    expect(r.result(), isNull);
  });

  testWidgets('an untouched sheet dismissed returns nothing', (tester) async {
    final r = await open(tester, entry);
    await tapBarrier(tester);

    expect(r.done(), isTrue);
    expect(r.result(), isNull);
  });

  testWidgets('Escape is Cancel on the dialog variant', (tester) async {
    final r = await open(tester, entry, width: 700);
    expect(find.byType(Dialog), findsOneWidget);
    await typeDescription(tester, 'Throw me away');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(r.done(), isTrue);
    expect(r.result(), isNull);
  });

  testWidgets('the dialog variant keeps the edit on a barrier tap', (
    tester,
  ) async {
    final r = await open(tester, entry, width: 700);
    await typeDescription(tester, 'Kept');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(r.result()?.description, 'Kept');
  });
}
