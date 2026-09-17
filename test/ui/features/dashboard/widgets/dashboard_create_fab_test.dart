import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/quick_create.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_create_fab.dart';

import '../../../../_localization_helper.dart';

/// invoiceninja/flutter#164: the narrow dashboard's `+` is a bottom-right FAB
/// that opens a choice of what to create, where it used to be an app-bar icon
/// that could only start an invoice.
///
/// The button and its sheet take plain options, so they are pumped here without
/// `Services`. `dashboard_screen_test.dart` covers which options the screen
/// passes and where a pick navigates.
void main() {
  // Real glyph widths. Otherwise every glyph is a full em square and the label
  // assertions describe some other font.
  setUpAll(_loadInterTight);

  final allOptions = [
    for (final type in kQuickCreateEntities)
      QuickCreateOption(type: type, icon: Icons.circle_outlined),
  ];

  /// [size] moves the render surface and `MediaQuery` together, since the
  /// sheet reads both. [nested] hosts the button inside a second `Navigator`,
  /// as the shell's branch navigators host the dashboard.
  Future<void> pumpFab(
    WidgetTester tester, {
    List<QuickCreateOption>? options,
    ValueChanged<EntityType>? onCreate,
    Size size = const Size(360, 640),
    double textScale = 1,
    bool nested = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final page = Scaffold(
      body: const SizedBox.expand(),
      floatingActionButton: DashboardCreateFab(
        options: options ?? allOptions,
        onCreate: onCreate ?? (_) {},
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        theme: buildInTheme(InTheme.light),
        builder: (context, inner) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: inner!,
        ),
        home: nested
            ? Navigator(
                onGenerateRoute: (_) =>
                    MaterialPageRoute<void>(builder: (_) => page),
              )
            : page,
      ),
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
  }

  final sheetHeading = find.descendant(
    of: find.byType(BottomSheet),
    matching: find.text('Create New'),
  );

  testWidgets('is a + labelled Create New', (tester) async {
    await pumpFab(tester);

    expect(
      find.descendant(
        of: find.byType(FloatingActionButton),
        matching: find.byIcon(Icons.add),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Create New'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('opens a sheet with one tile per option, in order', (
    tester,
  ) async {
    await pumpFab(tester);
    await openSheet(tester);

    expect(sheetHeading, findsOneWidget);
    // English labels come from the `new_*` keys, so three entries say "Enter".
    const labels = [
      'New Invoice',
      'New Quote',
      'Enter Payment',
      'New Task',
      'Enter Expense',
      'New Client',
      'Enter Credit',
      'New Recurring Invoice',
      'New Project',
      'New Product',
      'New Vendor',
      'New Purchase Order',
      'New Recurring Expense',
      'New Transaction',
    ];
    Offset at(String label) => tester.getCenter(find.text(label));
    for (var i = 0; i < labels.length; i++) {
      expect(find.text(labels[i]), findsOneWidget, reason: labels[i]);
      if (i == 0) continue;
      // Reading order: each label is further down, or on the same run and
      // further right.
      final prev = at(labels[i - 1]);
      final here = at(labels[i]);
      final sameRun = (here.dy - prev.dy).abs() < 1;
      expect(
        sameRun ? here.dx > prev.dx : here.dy > prev.dy,
        isTrue,
        reason: '${labels[i]} should follow ${labels[i - 1]}',
      );
    }
  });

  // The column count is what makes the first two rows the six most-used
  // creates. See `kQuickCreateMinTileWidth`.
  testWidgets('a 360 dp phone gets three columns', (tester) async {
    await pumpFab(tester);
    await openSheet(tester);

    // A 2 px tolerance, not the default 1e-10: these labels each fit on one
    // line today, and a label that wrapped would shift its centre by half a
    // line — which should not read as "the column count changed".
    Offset at(String label) => tester.getCenter(find.text(label));
    final invoice = at('New Invoice');
    expect(at('New Quote').dy, moreOrLessEquals(invoice.dy, epsilon: 2));
    expect(at('Enter Payment').dy, moreOrLessEquals(invoice.dy, epsilon: 2));
    // The fourth wraps onto the second run, under the first.
    expect(at('New Task').dx, moreOrLessEquals(invoice.dx, epsilon: 2));
    expect(at('New Task').dy, greaterThan(invoice.dy));
  });

  testWidgets('a pick closes the sheet and reports the entity', (tester) async {
    final picked = <EntityType>[];
    await pumpFab(tester, onCreate: picked.add);
    await openSheet(tester);

    await tester.tap(find.text('Enter Payment'));
    await tester.pumpAndSettle();

    expect(picked, [EntityType.payment]);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('dismissing the sheet reports nothing', (tester) async {
    final picked = <EntityType>[];
    await pumpFab(tester, onCreate: picked.add);
    await openSheet(tester);

    // The barrier, well above the sheet.
    await tester.tapAt(const Offset(180, 20));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(picked, isEmpty);
  });

  // The sheet is a route, so Android's back closes it without the wiring a
  // `MenuAnchor` needs (`docs/popup-dismissal.md`).
  testWidgets('Android back closes the sheet without a pick', (tester) async {
    final picked = <EntityType>[];
    await pumpFab(tester, onCreate: picked.add);
    await openSheet(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(picked, isEmpty);
  });

  // The shell paints its running-timer pill above the branch navigators. On a
  // branch navigator, the sheet would sit under the pill.
  testWidgets('the sheet opens on the root navigator', (tester) async {
    await pumpFab(tester, nested: true);
    await openSheet(tester);

    expect(sheetHeading, findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(BottomSheet),
        matching: find.byType(Navigator),
      ),
      findsOneWidget,
      reason: 'a sheet inside the nested navigator would have two ancestors',
    );
  });

  testWidgets('only the options given are offered', (tester) async {
    await pumpFab(
      tester,
      options: const [
        QuickCreateOption(type: EntityType.client, icon: Icons.people),
      ],
    );
    await openSheet(tester);

    expect(find.text('New Client'), findsOneWidget);
    expect(find.text('New Invoice'), findsNothing);
  });

  testWidgets('every tile is at least a touch target tall', (tester) async {
    await pumpFab(tester);
    await openSheet(tester);

    final tiles = find.descendant(
      of: find.byType(QuickCreateGrid),
      matching: find.byType(InkWell),
    );
    expect(tiles, findsNWidgets(kQuickCreateEntities.length));
    for (final tile in tiles.evaluate()) {
      expect(
        tester.getSize(find.byWidget(tile.widget)).height,
        greaterThanOrEqualTo(InSizes.touchTarget),
      );
    }
  });

  group('lays out without overflowing', () {
    for (final (size, scale) in const [
      (Size(320, 568), 1.0),
      (Size(360, 640), 1.0),
      (Size(360, 640), 2.0),
      (Size(844, 390), 1.0),
      (Size(844, 390), 1.3),
    ]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()} @ $scale', (
        tester,
      ) async {
        await pumpFab(tester, size: size, textScale: scale);
        await openSheet(tester);

        expect(tester.takeException(), isNull);
        // The sheet scrolls when it is taller than the screen allows, so the
        // last entry can always be reached.
        await tester.scrollUntilVisible(
          find.text('New Transaction'),
          50,
          scrollable: find.descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.tap(find.text('New Transaction'));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
      });
    }
  });

  // The table in `kQuickCreateMinTileWidth`'s doc. "Sheet content" is the
  // sheet's width less its two gutters (12 px each on a phone, 16 once the
  // window is 600 wide). The landscape sheet is capped at Material's 640.
  test('quickCreateColumns matches its documented table', () {
    const table = [
      (296.0, [2, 2, 2]),
      (336.0, [3, 2, 2]),
      (388.0, [3, 2, 2]),
      (608.0, [5, 4, 3]),
    ];
    const scales = [1.0, 1.3, 2.0];
    for (final (width, expected) in table) {
      for (var i = 0; i < scales.length; i++) {
        expect(
          quickCreateColumns(width: width, textScale: scales[i]),
          expected[i],
          reason: '$width px at ${scales[i]}',
        );
      }
    }
  });

  test('quickCreateColumns stays within 2..6', () {
    expect(quickCreateColumns(width: 10, textScale: 1), 2);
    expect(quickCreateColumns(width: 2000, textScale: 1), 6);
    expect(quickCreateColumns(width: 0, textScale: 1), 2);
  });
}

Future<void> _loadInterTight() async {
  final loader = FontLoader(kSansFontFamily)
    ..addFont(
      Future.value(
        File(
          'assets/fonts/InterTight.ttf',
        ).readAsBytesSync().buffer.asByteData(),
      ),
    );
  await loader.load();
}
