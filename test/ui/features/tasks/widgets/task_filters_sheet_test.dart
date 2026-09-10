import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/features/tasks/view_models/task_filters_mixin.dart';
import 'package:admin/ui/features/tasks/widgets/task_filters_sheet.dart';

import '../../../../_localization_helper.dart';
import '../../../../_responsive_helper.dart';
import '_task_filter_doubles.dart';

void main() {
  const screenHeight = 900.0;

  Future<void> open(
    WidgetTester tester, {
    required double width,
    required TaskFiltersMixin filters,
    double textScale = 1.0,
  }) async {
    // `tester.view`, not `pumpAt`'s `setSurfaceSize`: the dialog-vs-sheet fork
    // and every `InSpacing.*` read `MediaQuery.sizeOf`, which
    // `setSurfaceSize` does not move — a test that only resizes the surface
    // exercises a combination that cannot exist in production.
    tester.view.physicalSize = Size(width, screenHeight);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      Provider<Services>.value(
        value: FakeServices(),
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    openTaskFilters(context, filters: filters, companyId: 'co'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a phone gets a bottom sheet sized to its content', (
    tester,
  ) async {
    final filters = TaskFiltersDouble();
    addTearDown(filters.dispose);
    await open(tester, width: 390, filters: filters);

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Filters'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
    // A cap, not a fraction. Activity's 0.92 sheet needs its height for a big
    // multi-select; three fields under one would cover the board and hide the
    // live, Apply-less filtering this surface performs.
    expect(
      tester.getSize(find.byType(BottomSheet)).height,
      lessThan(screenHeight * 0.85),
    );
    expectNoOverflow(tester);
  });

  testWidgets('a wide window gets the dialog', (tester) async {
    final filters = TaskFiltersDouble();
    addTearDown(filters.dispose);
    await open(tester, width: 900, filters: filters);

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(TextField), findsNWidgets(3));
  });

  testWidgets('a 320 px sheet survives the largest text scale', (tester) async {
    final filters = TaskFiltersDouble();
    addTearDown(filters.dispose);
    await open(tester, width: 320, filters: filters, textScale: kTextScaleMax);
    expectNoOverflow(tester);
    expect(find.text('Filters'), findsOneWidget);
  });

  testWidgets('Clear filters is inert until something is applied', (
    tester,
  ) async {
    final filters = TaskFiltersDouble();
    addTearDown(filters.dispose);
    await open(tester, width: 390, filters: filters);

    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Clear Filters'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('Clear filters empties the fields, not just the view model', (
    tester,
  ) async {
    // The regression the body's `ListenableBuilder` exists for:
    // `EntityPickerField.selectedId` is a constructor argument and the field
    // re-seeds its controller only from `didUpdateWidget`, so without a rebuild
    // the board behind the sheet clears while all three fields keep showing
    // their old values — the sheet contradicting its own primary action.
    final filters = TaskFiltersDouble()
      ..setProjectFilter('p1')
      ..setClientFilter('c1')
      ..setAssigneeFilter('u1');
    addTearDown(filters.dispose);
    await open(tester, width: 390, filters: filters);

    expect(find.text(kFakeClient.name), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Clear Filters'));
    await tester.pumpAndSettle();

    expect(filters.filtersActive, isFalse);
    // Against the fixtures, never their literals: `find.text` is an exact
    // match, so when the shared double's project became "Website redesign" a
    // hardcoded `find.text('Website')` stopped being able to fail — in the one
    // test that exists to catch the `ListenableBuilder` regression.
    expect(find.text(kFakeClient.name), findsNothing);
    expect(find.text(kFakeProject.name), findsNothing);
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.controller?.text ?? '', isEmpty);
    }
  });

  testWidgets('the close button dismisses it', (tester) async {
    final filters = TaskFiltersDouble();
    addTearDown(filters.dispose);
    await open(tester, width: 390, filters: filters);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('a sheet that outlived its view model is inert, not a crash', (
    tester,
  ) async {
    // Reachable without a company switch: the sheet is pushed on the branch
    // navigator, and `RunningTimerPill` paints above the shell — over this
    // sheet — with a tap that opens a task pane, which locks `TaskListScreen`
    // to the plain list and disposes the four custom views' view models.
    // A filter has to be applied first, or `clearFilters` early-returns and
    // `Clear Filters` is disabled — the tap would prove nothing.
    final filters = TaskFiltersDouble()..setClientFilter('c1');
    await open(tester, width: 390, filters: filters);
    filters.dispose();

    await tester.tap(find.widgetWithText(TextButton, 'Clear Filters'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
