import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/user.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/entity_picker_field.dart';
import 'package:admin/ui/features/tasks/widgets/task_filter_bar.dart';

import '../../../../_localization_helper.dart';
import '../../../../_responsive_helper.dart';
import '_task_filter_doubles.dart';

void main() {
  // ── The gate ───────────────────────────────────────────────────────────────
  //
  // A pure function precisely so this table exists: both of its terms fail
  // invisibly on screen, and it is the only place that can see them at once.
  group('taskFiltersInline', () {
    // Pane = window − the rail (232 expanded, 64 collapsed) once it is up.
    bool at(double paneWidth, {bool isPhone = false}) =>
        taskFiltersInline(paneWidth: paneWidth, isPhone: isPhone);

    test('a phone stays collapsed in both orientations', () {
      expect(at(412, isPhone: true), isFalse); // portrait, no rail
      // Landscape: a ~890 px window, so the rail is up and the pane is ~658 —
      // wide by every width test, on a viewport only ~412 px tall (flutter#51).
      expect(at(658, isPhone: true), isFalse);
    });

    test('a tablet in portrait collapses on width alone', () {
      expect(at(744 - 232), isFalse); // iPad mini
      expect(at(768 - 232), isFalse); // iPad 10.2
      expect(at(820 - 232), isFalse); // iPad 10.9
    });

    test('a desktop keeps the pickers inline', () {
      expect(at(1024 - 232), isTrue);
      expect(at(1280 - 232), isTrue);
      expect(at(1440 - 232), isTrue);
      expect(at(1280 - 64), isTrue); // rail collapsed
    });

    test('the threshold counts the bar\'s own gutters', () {
      // The gate this replaced lived inside `Container(padding: horizontal:
      // 24)`, so it really tested `pane - 48 >= 600`. Reading the raw pane
      // would newly put three pickers in a 552 px content box — ~50 px of
      // visible text each once touch spends 96 on the ✕ + ▾ suffix.
      expect(at(600 + 2 * kTaskFilterBarGutter), isTrue);
      expect(at(600 + 2 * kTaskFilterBarGutter - 1), isFalse);
      expect(at(Breakpoints.wide), isFalse);
    });
  });

  // ── The bar ────────────────────────────────────────────────────────────────
  group('TaskFilterBar', () {
    late TaskFiltersDouble filters;
    var edits = 0;

    setUp(() {
      filters = TaskFiltersDouble();
      edits = 0;
    });

    tearDown(() => filters.dispose());

    Widget bar({required bool inline}) => TaskFilterBar(
      filters: filters,
      companyId: 'co',
      inline: inline,
      onEditFilters: () => edits++,
    );

    /// Deliberately NO `Provider<Services>` — see the first test.
    Future<void> pumpBare(
      WidgetTester tester,
      Widget child, {
      double width = 412,
      double textScale = 1.0,
    }) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          builder: (context, inner) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: inner!,
          ),
          home: Scaffold(
            body: SizedBox(width: width, child: child),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('collapsed and unfiltered, it costs nothing and touches no '
        'Services', (tester) async {
      // The headline assertion of invoiceninja/flutter#136: three stacked
      // pickers were ~180 px of a 412x915 phone, ~230 with the Clear row.
      // Pumped with no
      // `Provider<Services>` in the tree at all, so a `ProviderNotFound`
      // failure here means `context.read<Services>()` was hoisted back out of
      // `taskFilterPickers` and onto the free path.
      await pumpBare(tester, bar(inline: false));
      expect(tester.getSize(find.byType(TaskFilterBar)).height, 0);
      expect(find.byType(InputChip), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('collapsed and filtered, one chip per dimension, labelled by '
        'dimension', (tester) async {
      filters
        ..setProjectFilter('p1')
        ..setClientFilter('c1')
        ..setAssigneeFilter('u1');
      await pumpBare(tester, bar(inline: false));

      expect(find.byType(InputChip), findsNWidgets(3));
      // Dimension labels, not resolved record names: a name-bearing chip is
      // ~215 px, so three of them wrap to three runs and save nothing over the
      // pickers they replace — and the `*NameLabel` resolvers would put a raw
      // hashid or a bare em dash in a chip.
      expect(find.text('Project'), findsOneWidget);
      expect(find.text('Client'), findsOneWidget);
      expect(find.text('Assigned User'), findsOneWidget);
    });

    testWidgets('the ✕ drops only its own dimension', (tester) async {
      filters
        ..setProjectFilter('p1')
        ..setClientFilter('c1');
      await pumpBare(tester, bar(inline: false));

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(InputChip, 'Project'),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pumpAndSettle();

      expect(filters.projectId, '');
      expect(filters.clientId, 'c1');
      expect(find.byType(InputChip), findsOneWidget);
      expect(edits, 0, reason: 'the delete icon must not open the sheet');
    });

    testWidgets('the chip body reopens the sheet instead of destroying the '
        'filter', (tester) async {
      filters.setClientFilter('c1');
      await pumpBare(tester, bar(inline: false));

      await tester.tap(find.text('Client'));
      await tester.pumpAndSettle();

      expect(edits, 1);
      expect(
        filters.clientId,
        'c1',
        reason: 'a mis-tap on the body must not clear the filter it names',
      );
    });

    testWidgets('the filtered strip keeps the band recipe', (tester) async {
      // `surface` + a bottom border is what makes this read as one continuous
      // band with the day / week / month header directly below it — and on
      // kanban it is the board's only separator from a zero-elevation AppBar.
      filters.setClientFilter('c1');
      await pumpBare(tester, bar(inline: false));

      final decorated = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(TaskFilterBar),
          matching: find.byType(Container),
        ),
      );
      expect(
        decorated.any(
          (c) =>
              c.decoration is BoxDecoration &&
              (c.decoration! as BoxDecoration).border != null,
        ),
        isTrue,
      );
    });

    testWidgets('the collapsed strip stays inside its height budget', (
      tester,
    ) async {
      // The issue is *about* height and nothing else in the suite measures it.
      // The bounds are deliberately loose because `flutter test` substitutes a
      // square-per-glyph font that over-measures text by roughly half: with the
      // bundled Inter Tight all three chips are a single 65 px run on a 412 px
      // phone, wrapping to two (117) only at the largest text scale or on a
      // 320-360 px one. What must hold either way is the ceiling — the ~180 px
      // of stacked pickers this replaces (~230 with their Clear row).
      filters.setClientFilter('c1');
      await pumpBare(tester, bar(inline: false));
      expect(
        tester.getSize(find.byType(TaskFilterBar)).height,
        lessThanOrEqualTo(72),
        reason: 'one applied filter must be one run',
      );

      filters
        ..setProjectFilter('p1')
        ..setAssigneeFilter('u1');
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(TaskFilterBar)).height,
        lessThanOrEqualTo(120),
      );

      await pumpBare(tester, bar(inline: false), textScale: kTextScaleMax);
      expect(
        tester.getSize(find.byType(TaskFilterBar)).height,
        lessThan(176),
        reason:
            'a third run would put the strip back at the picker stack\'s '
            'height, which is the whole point of collapsing it',
      );
      expectNoOverflow(tester);
    });

    testWidgets('inline renders the three pickers and no chips', (
      tester,
    ) async {
      filters.setClientFilter('c1');
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        Provider<Services>.value(
          value: FakeServices(),
          child: MaterialApp(
            theme: buildInTheme(InTheme.light),
            localizationsDelegates: kTestLocalizationsDelegates,
            supportedLocales: kTestSupportedLocales,
            home: Scaffold(body: bar(inline: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EntityPickerField<User>), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(3));
      expect(find.byType(InputChip), findsNothing);
      // Clear rides in the row rather than the strip.
      expect(find.text('Clear'), findsOneWidget);
      expectNoOverflow(tester);
    });
  });
}
