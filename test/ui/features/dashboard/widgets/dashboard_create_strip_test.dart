import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/quick_create.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_create_fab.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_create_strip.dart';

import '../../../../_localization_helper.dart';

/// The wide dashboard's create buttons. The strip takes plain options, so it
/// is pumped here without `Services`; `dashboard_screen_test.dart` covers which
/// options the screen passes and where a pick navigates.
void main() {
  // Real glyph widths — how many buttons fit is the thing under test.
  setUpAll(_loadInterTight);

  final allOptions = [
    for (final type in kQuickCreateEntities)
      QuickCreateOption(type: type, icon: Icons.circle_outlined),
  ];

  Future<void> pumpStrip(
    WidgetTester tester, {
    List<QuickCreateOption>? options,
    ValueChanged<EntityType>? onCreate,
    double width = 600,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            // Loose, as the top bar hands it: the strip may be narrower than
            // its slot, never wider.
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width),
              child: DashboardCreateStrip(
                options: options ?? allOptions,
                onCreate: onCreate ?? (_) {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The create buttons drawn inline, in order — everything but More.
  List<String> inlineLabels(WidgetTester tester) => [
    for (final e in find.byType(FilledButton).evaluate()) _labelOf(tester, e),
    for (final e in find.byType(OutlinedButton).evaluate())
      if (_labelOf(tester, e) != 'More') _labelOf(tester, e),
  ];

  testWidgets('leads with the first option as the primary, in gate order', (
    tester,
  ) async {
    await pumpStrip(tester);
    final labels = inlineLabels(tester);
    // `kQuickCreateEntities` order, as bare nouns beside the `+`.
    expect(labels.take(3), ['Invoice', 'Quote', 'Payment']);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.text('Invoice'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('what does not fit goes under More, and nothing is lost', (
    tester,
  ) async {
    await pumpStrip(tester, width: 420);
    final inline = inlineLabels(tester);
    expect(inline, isNotEmpty);
    expect(inline.length, lessThan(allOptions.length));
    expect(find.text('More'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    // Menu entries use the full phrase; inline + menu = every option.
    final inMenu = find.byType(MenuItemButton).evaluate().length;
    expect(inline.length + inMenu, allOptions.length);
    // The first hidden one is the next in order.
    expect(find.text('Enter Expense'), findsOneWidget);
  });

  testWidgets('a narrower slot shows fewer buttons, never an overflow', (
    tester,
  ) async {
    await pumpStrip(tester, width: 600);
    final wide = inlineLabels(tester).length;
    await pumpStrip(tester, width: 300);
    final narrow = inlineLabels(tester).length;
    expect(narrow, lessThan(wide));
    expect(tester.takeException(), isNull);
  });

  testWidgets('larger text moves the cut instead of clipping a label', (
    tester,
  ) async {
    await pumpStrip(tester, width: 600);
    final normal = inlineLabels(tester).length;
    // The app's largest in-app setting: never more buttons, never an overflow.
    await pumpStrip(tester, width: 600, textScale: 1.4);
    expect(inlineLabels(tester).length, lessThanOrEqualTo(normal));
    expect(tester.takeException(), isNull);
    // An OS scale on top of it: the cut has to move.
    await pumpStrip(tester, width: 600, textScale: 2);
    expect(inlineLabels(tester).length, lessThan(normal));
    expect(tester.takeException(), isNull);
  });

  testWidgets('never grows past its cap, however wide the bar', (tester) async {
    await pumpStrip(tester, width: 1400);
    expect(
      tester.getSize(find.byType(DashboardCreateStrip)).width,
      lessThanOrEqualTo(kDashboardCreateStripMaxWidth),
    );
    // So the tail stays under More even on an ultrawide window.
    expect(find.text('More'), findsOneWidget);
    expect(inlineLabels(tester).length, lessThan(allOptions.length));
  });

  testWidgets('every button is one height', (tester) async {
    await pumpStrip(tester, width: 600);
    final heights = {
      for (final e in find.byType(FilledButton).evaluate())
        tester.getSize(find.byWidget(e.widget)).height,
      for (final e in find.byType(OutlinedButton).evaluate())
        tester.getSize(find.byWidget(e.widget)).height,
    };
    expect(heights, hasLength(1), reason: 'heights: $heights');
  });

  testWidgets('a tap on a button creates that entity', (tester) async {
    final created = <EntityType>[];
    await pumpStrip(tester, onCreate: created.add);
    await tester.tap(find.text('Quote'));
    expect(created, [EntityType.quote]);
  });

  testWidgets('a pick from More creates that entity', (tester) async {
    final created = <EntityType>[];
    await pumpStrip(tester, width: 420, onCreate: created.add);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MenuItemButton).last);
    await tester.pumpAndSettle();
    expect(created, [kQuickCreateEntities.last]);
  });

  testWidgets('with everything fitting there is no More', (tester) async {
    await pumpStrip(tester, options: allOptions.take(2).toList(), width: 600);
    expect(inlineLabels(tester), ['Invoice', 'Quote']);
    expect(find.text('More'), findsNothing);
  });

  testWidgets('a user who may create nothing gets no strip', (tester) async {
    await pumpStrip(tester, options: const []);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(tester.getSize(find.byType(DashboardCreateStrip)), Size.zero);
  });

  testWidgets('a screen reader hears the full phrase, and can activate it', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final created = <EntityType>[];
    await pumpStrip(tester, onCreate: created.add);
    // "Enter Payment", not the bare noun on the button.
    final payment = find.bySemanticsLabel('Enter Payment');
    expect(payment, findsOneWidget);
    expect(
      tester.getSemantics(payment),
      matchesSemantics(
        label: 'Enter Payment',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });
}

String _labelOf(WidgetTester tester, Element button) {
  final text = find.descendant(
    of: find.byWidget(button.widget),
    matching: find.byType(Text),
  );
  return tester.widget<Text>(text.first).data ?? '';
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
