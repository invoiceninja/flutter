import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/widgets/toast_controller.dart';

/// Pure-ish controller tests. Run inside `testWidgets` so the binding's fake
/// clock drives the controller's auto-dismiss `Timer`s via `tester.pump(d)` —
/// no `fake_async` dependency needed. Each test disposes the controller in the
/// body (flutter_test checks for pending timers before `addTearDown` runs).
void main() {
  group('ToastController', () {
    testWidgets('show appends oldest-first; distinct messages stack', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox());
      final c = ToastController();

      c.show(variant: NotifyVariant.success, message: 'First');
      c.show(variant: NotifyVariant.info, message: 'Second');

      expect(c.toasts.map((t) => t.message), ['First', 'Second']);
      c.dispose();
    });

    testWidgets('identical newest toast dedups into a ×N bump', (tester) async {
      await tester.pumpWidget(const SizedBox());
      final c = ToastController();

      final id1 = c.show(variant: NotifyVariant.error, message: 'Boom');
      final id2 = c.show(variant: NotifyVariant.error, message: 'Boom');

      expect(id1, id2, reason: 'dedup keeps the same id');
      expect(c.toasts.length, 1);
      expect(c.toasts.single.count, 2);

      // A different message stacks rather than dedups.
      c.show(variant: NotifyVariant.error, message: 'Other');
      expect(c.toasts.length, 2);
      c.dispose();
    });

    testWidgets('cap drops the oldest beyond maxVisible', (tester) async {
      await tester.pumpWidget(const SizedBox());
      final c = ToastController(maxVisible: 3);

      for (var i = 0; i < 5; i++) {
        c.show(variant: NotifyVariant.info, message: 'm$i');
      }
      expect(c.toasts.length, 3);
      // Oldest (m0, m1) dropped; newest survive.
      expect(c.toasts.map((t) => t.message), ['m2', 'm3', 'm4']);
      c.dispose();
    });

    testWidgets('auto-dismiss removes the toast after its duration', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox());
      final c = ToastController();

      c.show(variant: NotifyVariant.success, message: 'Saved'); // 3s
      expect(c.toasts, isNotEmpty);

      await tester.pump(const Duration(seconds: 2));
      expect(c.toasts, isNotEmpty, reason: 'still within the 3s window');

      await tester.pump(const Duration(seconds: 2)); // total 4s
      expect(c.toasts, isEmpty, reason: 'auto-dismissed past 3s');
      c.dispose();
    });

    testWidgets('an actionable toast lingers at least 6s', (tester) async {
      await tester.pumpWidget(const SizedBox());
      final c = ToastController();

      c.show(
        variant: NotifyVariant.success, // base 3s
        message: 'Archived',
        action: NotifyAction('UNDO', () {}),
      );

      await tester.pump(const Duration(seconds: 5));
      expect(c.toasts, isNotEmpty, reason: 'actionable bumps to >= 6s');

      await tester.pump(const Duration(seconds: 2)); // total 7s
      expect(c.toasts, isEmpty);
      c.dispose();
    });

    testWidgets('pause freezes the timer; resume re-arms it', (tester) async {
      await tester.pumpWidget(const SizedBox());
      final c = ToastController();

      final id = c.show(
        variant: NotifyVariant.success,
        message: 'Saved',
      )!; // 3s
      c.pause(id);
      await tester.pump(const Duration(seconds: 5));
      expect(c.toasts, isNotEmpty, reason: 'paused — does not auto-dismiss');

      c.resume(id);
      await tester.pump(const Duration(seconds: 2));
      expect(c.toasts, isNotEmpty, reason: 're-armed for the full 3s');
      await tester.pump(const Duration(seconds: 2)); // total 4s since resume
      expect(c.toasts, isEmpty);
      c.dispose();
    });

    testWidgets('dismiss removes by id and is tolerant of unknown ids', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox());
      final c = ToastController();

      final id = c.show(variant: NotifyVariant.info, message: 'Hi')!;
      c.dismiss(99999); // unknown — no throw, no change
      expect(c.toasts.length, 1);
      c.dismiss(id);
      expect(c.toasts, isEmpty);
      c.dispose();
    });

    testWidgets('clearAll empties the queue and cancels timers', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox());
      final c = ToastController();

      c.show(variant: NotifyVariant.error, message: 'A');
      c.show(variant: NotifyVariant.error, message: 'B');
      c.clearAll();
      expect(c.toasts, isEmpty);
      // No pending timer remains (would trip the binding's check otherwise).
      await tester.pump(const Duration(seconds: 10));
      c.dispose();
    });
  });

  /// invoiceninja/flutter#30 — a toast whose strings were blank or newline-laden
  /// painted a card that was empty but stretched (the card gives the message 2
  /// lines and the detail 3, and blank lines occupy full line boxes).
  group('ToastController — blank / multi-line normalization', () {
    testWidgets('a blank message with no detail queues nothing', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox());
      final c = ToastController();

      expect(c.show(variant: NotifyVariant.success, message: ''), isNull);
      expect(
        c.show(variant: NotifyVariant.error, message: '   \n\n  '),
        isNull,
      );
      expect(
        c.show(variant: NotifyVariant.info, message: '', detail: '\n \n'),
        isNull,
      );
      expect(c.toasts, isEmpty);
      c.dispose();
    });

    testWidgets('a blank message promotes the detail into the title', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox());
      final c = ToastController();

      c.show(variant: NotifyVariant.error, message: '', detail: 'Boom');
      expect(c.toasts.single.message, 'Boom');
      expect(c.toasts.single.detail, isNull);
      c.dispose();
    });

    testWidgets('a message collapses to a single line', (tester) async {
      await tester.pumpWidget(const SizedBox());
      final c = ToastController();

      c.show(
        variant: NotifyVariant.error,
        message: '  Internal Server Error\n\n\n<html>\r\n<body>  ',
      );
      expect(c.toasts.single.message, 'Internal Server Error <html> <body>');
      c.dispose();
    });

    testWidgets('a detail keeps its first non-blank lines, capped at the '
        'card maxLines', (tester) async {
      await tester.pumpWidget(const SizedBox());
      final c = ToastController();

      c.show(
        variant: NotifyVariant.error,
        message: 'Could not save',
        detail: '\n one \n\n  two  \r\nthree\n\nfour\n',
      );
      expect(c.toasts.single.detail, 'one\ntwo\nthree');
      expect(kToastDetailMaxLines, 3);
      c.dispose();
    });

    testWidgets('an action with a blank label is dropped', (tester) async {
      await tester.pumpWidget(const SizedBox());
      final c = ToastController();

      c.show(
        variant: NotifyVariant.info,
        message: 'Hi',
        action: NotifyAction('  ', () {}),
      );
      expect(c.toasts.single.action, isNull);
      c.dispose();
    });

    testWidgets('dedup compares the normalized strings', (tester) async {
      await tester.pumpWidget(const SizedBox());
      final c = ToastController();

      final id1 = c.show(variant: NotifyVariant.error, message: 'Boom');
      final id2 = c.show(variant: NotifyVariant.error, message: '  Boom\n');

      expect(id1, id2);
      expect(c.toasts.single.count, 2);
      c.dispose();
    });
  });
}
