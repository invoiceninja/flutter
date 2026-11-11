import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/show_seconds_controller.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/ui/features/tasks/widgets/running_duration_label.dart';

/// `_pulse` is built in `initState`, so a `showDot` change on a reused State
/// used to be ignored entirely: false→true left the dot permanently missing,
/// and true→false left an `AnimationController.repeat()` scheduling frames for
/// a dot that is never painted.
void main() {
  Widget wrap({required bool showDot}) => MaterialApp(
    theme: ThemeData.light().copyWith(
      extensions: <ThemeExtension<dynamic>>[InTheme.light],
    ),
    home: Scaffold(
      body: RunningDurationLabel(
        // A stable key so the same State is reused across the flip.
        key: const ValueKey('label'),
        start: DateTime.utc(2026, 1, 1),
        showDot: showDot,
      ),
    ),
  );

  /// The pulsing dot: the only circular `Container` this widget builds.
  final dot = find.byWidgetPredicate(
    (w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration! as BoxDecoration).shape == BoxShape.circle,
  );

  testWidgets('flipping showDot on a mounted label adds the dot', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(showDot: false));
    expect(dot, findsNothing);

    await tester.pumpWidget(wrap(showDot: true));
    await tester.pump();
    expect(dot, findsOneWidget);
  });

  testWidgets('flipping it back removes the dot', (tester) async {
    await tester.pumpWidget(wrap(showDot: true));
    await tester.pump();
    expect(dot, findsOneWidget);

    await tester.pumpWidget(wrap(showDot: false));
    await tester.pump();
    expect(dot, findsNothing);
  });

  // invoiceninja/flutter#189: the pulse repeats forever, so it is the one
  // thing in the app that draws sixty frames a second for as long as a timer
  // runs. A Wayland compositor never reports a minimized or covered window as
  // hidden, so the framework's own "no frames while hidden" never applied.
  group('the pulse runs only while the app is resumed', () {
    void setLifecycle(WidgetTester tester, AppLifecycleState state) =>
        tester.binding.handleAppLifecycleStateChanged(state);

    double dotOpacity(WidgetTester tester) => tester
        .widget<Opacity>(find.ancestor(of: dot, matching: find.byType(Opacity)))
        .opacity;

    testWidgets('losing focus parks the dot, solid, with no frame pending', (
      tester,
    ) async {
      addTearDown(() => setLifecycle(tester, AppLifecycleState.resumed));
      await tester.pumpWidget(wrap(showDot: true));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.hasScheduledFrame, isTrue);

      setLifecycle(tester, AppLifecycleState.inactive);
      await tester.pump();
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(dotOpacity(tester), 1.0);

      setLifecycle(tester, AppLifecycleState.resumed);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('a label mounted while unfocused does not start it', (
      tester,
    ) async {
      addTearDown(() => setLifecycle(tester, AppLifecycleState.resumed));
      setLifecycle(tester, AppLifecycleState.inactive);
      await tester.pumpWidget(wrap(showDot: true));
      await tester.pump();
      expect(dot, findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('reduced motion holds the dot still', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: wrap(showDot: true),
        ),
      );
      await tester.pump();
      expect(dot, findsOneWidget);
      expect(dotOpacity(tester), 1.0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('Show Seconds preference', () {
    late AppDatabase db;
    late ShowSecondsController controller;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      final prefs = DevicePrefsStore(db);
      await prefs.load();
      controller = ShowSecondsController(prefs: prefs);
    });
    tearDown(() => db.close());

    // 1d 03:12:05 ago, so both the minute-precision and the day forms show.
    Widget kanbanLabel({bool secondsPastDay = true}) =>
        ChangeNotifierProvider<ShowSecondsController>.value(
          value: controller,
          child: MaterialApp(
            theme: ThemeData.light().copyWith(
              extensions: <ThemeExtension<dynamic>>[InTheme.light],
            ),
            home: Scaffold(
              body: RunningDurationLabel(
                start: DateTime.now().subtract(
                  const Duration(days: 1, hours: 3, minutes: 12, seconds: 5),
                ),
                precision: const Duration(minutes: 1),
                secondsPastDay: secondsPastDay,
                showDot: false,
              ),
            ),
          ),
        );

    final withSeconds = find.textContaining(RegExp(r'^1d 03h 12m \d\ds$'));

    testWidgets('off: a minute-precision label past a day has no seconds', (
      tester,
    ) async {
      await tester.pumpWidget(kanbanLabel());
      expect(find.text('1d 03h 12m'), findsOneWidget);
    });

    testWidgets('flipping it on adds seconds, and off takes them away', (
      tester,
    ) async {
      await tester.pumpWidget(kanbanLabel());
      await tester.runAsync(() => controller.set(true));
      await tester.pump();
      expect(withSeconds, findsOneWidget);

      await tester.runAsync(() => controller.set(false));
      await tester.pump();
      expect(find.text('1d 03h 12m'), findsOneWidget);
    });

    // The narrow list row, the wide table's 120 px column and the shell pill
    // have no room for the longer day form.
    testWidgets('a caller that does not opt in keeps the day form short', (
      tester,
    ) async {
      await tester.pumpWidget(kanbanLabel(secondsPastDay: false));
      await tester.runAsync(() => controller.set(true));
      await tester.pump();
      expect(find.text('1d 03h 12m'), findsOneWidget);
    });

    // invoiceninja/flutter#183: the task list's format — the task's total as
    // hours past 24, seconds only with the preference, and still ticking
    // every second so the minute rolls over on time.
    group('hoursOnly', () {
      Widget listLabel() => ChangeNotifierProvider<ShowSecondsController>.value(
        value: controller,
        child: MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: <ThemeExtension<dynamic>>[InTheme.light],
          ),
          home: Scaffold(
            body: RunningDurationLabel(
              // 36:00 already logged, plus a run of 0:30:05.
              start: DateTime.now().subtract(
                const Duration(minutes: 30, seconds: 5),
              ),
              base: const Duration(hours: 36),
              hoursOnly: true,
              showDot: false,
            ),
          ),
        ),
      );

      testWidgets('the total, in hours past a day, without seconds', (
        tester,
      ) async {
        await tester.pumpWidget(listLabel());
        expect(find.text('36:30'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('seconds once the preference is on', (tester) async {
        await tester.pumpWidget(listLabel());
        await tester.runAsync(() => controller.set(true));
        await tester.pump();
        expect(find.textContaining(RegExp(r'^36:30:\d\d$')), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    });
  });
}
