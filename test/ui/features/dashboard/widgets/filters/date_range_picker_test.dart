import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
import 'package:admin/ui/features/dashboard/widgets/filters/date_range_picker_button.dart';
import 'package:admin/ui/features/shell/widgets/in_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../_localization_helper.dart';

void main() {
  /// Pumps the popover body at an exact width, with no route involved.
  /// [textScale] exercises the scaled cell/label extents.
  Future<void> pumpAtWidth(
    WidgetTester tester,
    double width, {
    DashboardDateRange? current,
    double textScale = 1.0,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          // `copyWith`, not a fresh `MediaQueryData`: constructing one from
          // scratch would blank every other metric — notably `size`, which the
          // popover reads for its fallback width and `InSpacing.md` reads for
          // its narrow/wide branch. Override the scaler and nothing else.
          body: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: SingleChildScrollView(
                child: SizedBox(
                  width: width,
                  child: DashboardDateRangePopover(
                    current:
                        current ??
                        DashboardCustomRange(
                          start: const Date(2026, 3, 1),
                          end: const Date(2026, 3, 20),
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The rendered size of the day cell holding [day]. `_DayCell` fills itself
  /// with an `InkWell`, so that ancestor is the cell box.
  Size dayCellSize(WidgetTester tester, String day) => tester.getSize(
    find.ancestor(of: find.text(day), matching: find.byType(InkWell)).first,
  );

  Future<DashboardDateRange?> pumpAndCapture(
    WidgetTester tester,
    DashboardDateRange current,
    Future<void> Function(WidgetTester tester) interact,
  ) async {
    DashboardDateRange? captured;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  captured = await Navigator.of(context)
                      .push<DashboardDateRange?>(
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            body: Center(
                              child: SizedBox(
                                width: 720,
                                child: DashboardDateRangePopover(
                                  current: current,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await interact(tester);
    await tester.pumpAndSettle();
    return captured;
  }

  testWidgets('tapping a preset chip pops with that preset', (tester) async {
    final result = await pumpAndCapture(
      tester,
      const DashboardPresetRange(DashboardDatePreset.thisMonth),
      (tester) async {
        await tester.tap(find.text('Last 7 Days'));
      },
    );
    expect(result, isA<DashboardPresetRange>());
    expect((result as DashboardPresetRange).preset, DashboardDatePreset.last7);
  });

  testWidgets('tapping two days then Apply pops with a custom range', (
    tester,
  ) async {
    // Anchor the popover on a fixed initial range so we know which dates are
    // visible: pre-seeding with a custom range positions the calendar on the
    // start month.
    final result = await pumpAndCapture(
      tester,
      DashboardCustomRange(
        start: const Date(2026, 3, 1),
        end: const Date(2026, 3, 1),
      ),
      (tester) async {
        // Tap day 5 (start) then day 12 (end) in the left calendar (March).
        // Both months render the digits 5 and 12 so we restrict by the cell
        // height; the start-edge tap is the first '5' encountered.
        await tester.tap(find.text('5').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('12').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apply'));
      },
    );
    expect(result, isA<DashboardCustomRange>());
    final custom = result! as DashboardCustomRange;
    expect(custom.start, const Date(2026, 3, 5));
    expect(custom.end, const Date(2026, 3, 12));
  });

  testWidgets('Cancel returns null', (tester) async {
    final result = await pumpAndCapture(
      tester,
      const DashboardPresetRange(DashboardDatePreset.thisMonth),
      (tester) async {
        await tester.tap(find.text('Cancel'));
      },
    );
    expect(result, isNull);
  });

  testWidgets('popover opens at full width without layout overflow', (
    tester,
  ) async {
    // Reproduces the bug fix: `showMenu` capped the popover at ~280 px,
    // crushing the calendars. With the custom `PopupRoute`, the popover
    // should size to 960 px on a wide viewport with no overflow.
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    DashboardDateRange? captured;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: Center(
            child: DateRangePickerButton(
              current: const DashboardPresetRange(
                DashboardDatePreset.thisMonth,
              ),
              onChange: (r) => captured = r,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(DateRangePickerButton));
    await tester.pumpAndSettle();

    // No RenderFlex / layout overflow exceptions during open.
    expect(tester.takeException(), isNull);

    // Popover is on-screen at the requested wide-breakpoint width.
    final popoverFinder = find.byType(DashboardDateRangePopover);
    expect(popoverFinder, findsOneWidget);
    expect(tester.getSize(popoverFinder).width, 960.0);
    // Popover's left edge sits at or right of the persistent sidebar so the
    // preset rail isn't hidden behind it on wide layouts.
    final topLeft = tester.getTopLeft(popoverFinder);
    expect(topLeft.dx, greaterThanOrEqualTo(kInSidebarWidth + 16));

    // Tap a preset to dismiss cleanly.
    await tester.tap(find.text('Last 7 Days'));
    await tester.pumpAndSettle();
    expect(captured, isA<DashboardPresetRange>());
  });

  testWidgets('popover clamps width to fit a narrow viewport', (tester) async {
    // Below `Breakpoints.wide` (600 px) the shell hosts the sidebar in a
    // modal `AppDrawer` instead of inline, so the popover can use the full
    // viewport minus 16 px margins. At 500 px viewport: 500 - 32 = 468.
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: Center(
            child: DateRangePickerButton(
              current: const DashboardPresetRange(
                DashboardDatePreset.thisMonth,
              ),
              onChange: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(DateRangePickerButton));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final popoverFinder = find.byType(DashboardDateRangePopover);
    expect(popoverFinder, findsOneWidget);
    expect(tester.getSize(popoverFinder).width, 468.0);

    final topRight = tester.getTopRight(popoverFinder);
    expect(topRight.dx, lessThanOrEqualTo(500 - 16));
    final topLeft = tester.getTopLeft(popoverFinder);
    expect(topLeft.dx, 16.0);
  });

  testWidgets('typing shortcuts into from/to pops a custom range', (
    tester,
  ) async {
    final today = Date.today();
    final t2 = today.toDateTime().add(const Duration(days: 2));

    final result = await pumpAndCapture(
      tester,
      DashboardCustomRange(start: today, end: today),
      (tester) async {
        // First TextField = "from", second = "to".
        await tester.enterText(find.byType(TextField).at(0), 'today');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).at(1), '+2');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apply'));
      },
    );

    expect(result, isA<DashboardCustomRange>());
    final custom = result! as DashboardCustomRange;
    expect(custom.start, today);
    expect(custom.end, Date(t2.year, t2.month, t2.day));
  });

  testWidgets('typed date outside the allowed window is ignored', (
    tester,
  ) async {
    final today = Date.today();

    final result = await pumpAndCapture(
      tester,
      DashboardCustomRange(start: today, end: today),
      (tester) async {
        // 1990 is before `_firstAllowed` (2000-01-01): the handler drops it,
        // leaving the seeded `today` start untouched.
        await tester.enterText(find.byType(TextField).at(0), '1990-01-01');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apply'));
      },
    );

    expect(result, isA<DashboardCustomRange>());
    expect((result! as DashboardCustomRange).start, today);
  });

  testWidgets('Apply is disabled until two days are picked', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 720,
              child: DashboardDateRangePopover(
                current: const DashboardPresetRange(
                  DashboardDatePreset.thisMonth,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Pre-seeded range = today's month, both start/end set → Apply enabled.
    final applyFinder = find.widgetWithText(FilledButton, 'Apply');
    final applyInitial = tester.widget<FilledButton>(applyFinder);
    expect(applyInitial.onPressed, isNotNull);

    // Tap a single day to enter "start only" state — Apply disables.
    await tester.tap(find.text('15').first);
    await tester.pumpAndSettle();
    final applyAfter = tester.widget<FilledButton>(applyFinder);
    expect(applyAfter.onPressed, isNull);
  });

  // ---------------------------------------------------------------------
  // Narrow-width layout (invoiceninja/flutter#38). At a phone width the old
  // fixed two-pane / two-month tree gave each of its 14 day columns ~10 px,
  // so two-digit day numbers soft-wrapped mid-number ("20" → "2" / "0"), the
  // month header wrapped, and the From/To values were clipped.
  // ---------------------------------------------------------------------
  group('narrow width', () {
    // 328 px is what a 360 dp Android phone produces (viewport − 2×16 margin).
    const phone = 328.0;

    testWidgets('day cells stay wide enough for a two-digit number', (
      tester,
    ) async {
      await pumpAtWidth(tester, phone);

      // The invariant behind the bug report. Asserting the *cell* rather than
      // the text's line count keeps this meaningful: the day label is now
      // wrapped in a `FittedBox`, which lays out unbounded and so is always
      // one line — a line-count assertion would pass for the wrong reason.
      expect(
        dayCellSize(tester, '20').width,
        greaterThanOrEqualTo(24.0),
        reason:
            'a two-digit day needs ~14 px of glyph; below ~24 px of column '
            'the number wraps or is scaled to illegibility',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders one month, and two when there is room', (
      tester,
    ) async {
      // Seeded on March 2026, so the panes are March (+ April when wide).
      // Both months contain a 15th, which makes the count the month count.
      await pumpAtWidth(tester, phone);
      expect(find.text('15'), findsOneWidget);

      await pumpAtWidth(tester, 720);
      expect(find.text('15'), findsNWidgets(2));
    });

    testWidgets('From/To stack instead of being clipped side by side', (
      tester,
    ) async {
      await pumpAtWidth(tester, phone);
      final from = tester.getRect(find.byType(InDateField).at(0));
      final to = tester.getRect(find.byType(InDateField).at(1));
      expect(to.top, greaterThanOrEqualTo(from.bottom));
      expect(to.left, moreOrLessEquals(from.left));
      // Each field now owns the full column rather than half of it minus a
      // ~28 px calendar suffix, which is what clipped the value.
      expect(from.width, greaterThan(140));

      await pumpAtWidth(tester, 720);
      final wideFrom = tester.getRect(find.byType(InDateField).at(0));
      final wideTo = tester.getRect(find.byType(InDateField).at(1));
      expect(wideTo.left, greaterThan(wideFrom.right - 1));
      expect(wideTo.top, moreOrLessEquals(wideFrom.top));
    });

    testWidgets('compact can page to the last allowed month', (tester) async {
      // `_lastAllowed` is today + 5 years. Anchor one month short of it: with
      // only one month on screen the "next" chevron has to gate on the
      // *visible* month, not on anchor + 1, or that final month is
      // unreachable.
      final now = DateTime.now();
      final oneShort = DateTime(now.year + 5, now.month - 1, 1);
      await pumpAtWidth(
        tester,
        phone,
        current: DashboardCustomRange(
          start: Date(oneShort.year, oneShort.month, 1),
          end: Date(oneShort.year, oneShort.month, 2),
        ),
      );

      final next = find.widgetWithIcon(IconButton, Icons.chevron_right);
      expect(tester.widget<IconButton>(next).onPressed, isNotNull);
    });

    testWidgets('survives a 1.5x text scale without overflowing', (
      tester,
    ) async {
      await pumpAtWidth(tester, phone, textScale: 1.5);
      expect(tester.takeException(), isNull);
      // The cell extent scales with the text, so the glyph keeps its line box
      // instead of being sliced by a fixed 30 px height.
      expect(dayCellSize(tester, '20').height, greaterThan(36.0));
    });

    testWidgets('does not throw on a 320 px viewport', (tester) async {
      // `preferredWidth.clamp(320, media.width - 32)` threw an ArgumentError
      // here: `num.clamp` requires lower <= upper, and 320 > 288.
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            body: Center(
              child: DateRangePickerButton(
                current: const DashboardPresetRange(
                  DashboardDatePreset.thisMonth,
                ),
                onChange: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(DateRangePickerButton));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(DashboardDateRangePopover)).width,
        288.0,
      );
    });

    testWidgets('opens upward when the keyboard covers the space below', (
      tester,
    ) async {
      // The From/To fields exist to be typed into, so the soft keyboard is on
      // the main path — and it used to bury Cancel/Apply under a popover that
      // neither moved nor scrolled.
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            // Anchored low, which is the real case: the narrow Client
            // Statement screen opens this from a button inside a bottom
            // sheet, and the Dashboard's own button sits in a top bar that
            // can wrap to a second run.
            body: Align(
              alignment: Alignment.bottomCenter,
              child: DateRangePickerButton(
                current: const DashboardPresetRange(
                  DashboardDatePreset.thisMonth,
                ),
                onChange: (_) {},
              ),
            ),
          ),
        ),
      );
      final anchor = tester.getRect(find.byType(DateRangePickerButton));
      await tester.tap(find.byType(DateRangePickerButton));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final popover = tester.getRect(find.byType(DashboardDateRangePopover));
      expect(
        popover.bottom,
        lessThanOrEqualTo(anchor.top),
        reason: 'with 300 px of keyboard there is more room above the anchor',
      );
      expect(popover.top, greaterThanOrEqualTo(0));
      // The whole popover clears the keyboard — that is the guarantee that was
      // missing, since the route only ever read `MediaQuery.sizeOf`.
      expect(popover.bottom, lessThanOrEqualTo(800 - 300));

      // Whatever doesn't fit in the remaining space scrolls rather than being
      // clipped by the overlay's `Stack` (which paints no overflow banner, so
      // this used to fail silently). Apply is reachable and lands inside the
      // popover, above the keyboard.
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();
      final apply = tester.getRect(find.widgetWithText(FilledButton, 'Apply'));
      expect(apply.bottom, lessThanOrEqualTo(popover.bottom + 0.5));
      expect(apply.top, greaterThanOrEqualTo(popover.top - 0.5));
    });

    testWidgets('preset rows and chevrons meet the touch target floor', (
      tester,
    ) async {
      // `flutter test` reports TargetPlatform.android, so `Env.isTouchPrimary`
      // is true here and the touch sizing is the path under test. Both of
      // these were silent failures: a chevron declared 28 px rendered ~20
      // because `visualDensity: compact` subtracts 8 from explicit
      // constraints.
      await pumpAtWidth(tester, phone);

      final chevron = tester.getSize(
        find.widgetWithIcon(IconButton, Icons.chevron_right),
      );
      expect(chevron.width, greaterThanOrEqualTo(InSizes.touchTarget));
      expect(chevron.height, greaterThanOrEqualTo(InSizes.touchTarget));

      final preset = tester.getSize(
        find
            .ancestor(
              of: find.text('Last 7 Days'),
              matching: find.byType(InkWell),
            )
            .first,
      );
      expect(preset.height, greaterThanOrEqualTo(InSizes.touchTarget));
    });
  });
}
