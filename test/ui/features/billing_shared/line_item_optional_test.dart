// Optional quote lines: a line the client may choose to include when
// approving. The toggle is offered on quotes only (`allowOptionalLines`), and
// on any line that already carries the flag so it can be cleared; an optional
// line is marked on its row and counts toward no total.

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_card_list_mobile.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_column_config.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_table_desktop.dart';

import '../shell/_shell_test_helpers.dart';

LineItem _line({bool optional = false}) => emptyLineItem().copyWith(
  productKey: 'WARRANTY',
  notes: 'Extended warranty',
  cost: Decimal.fromInt(80),
  quantity: Decimal.one,
  isOptional: optional,
);

void main() {
  late List<List<LineItem>> emitted;

  Future<ShellFixture> fixtureFor() async {
    final fixture = await buildFixture(
      companies: [const FakeCompany(id: 'co1', name: 'Co')],
    );
    addTearDown(fixture.dispose);
    return fixture;
  }

  // Drift schedules a zero-duration close timer on unsubscribe.
  Future<void> teardownSubtree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  group('desktop row menu', () {
    Future<void> pump(
      WidgetTester tester, {
      required bool allow,
      bool optional = false,
    }) async {
      emitted = <List<LineItem>>[];
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final fixture = await fixtureFor();
      await tester.pumpWidget(
        wrapWithShell(
          fixture.services,
          LineItemTableDesktop(
            companyId: 'co1',
            items: [_line(optional: optional)],
            onChanged: emitted.add,
            newItemFactory: emptyLineItem,
            config: const LineItemColumnConfig(),
            allowOptionalLines: allow,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('a quote row toggles Optional', (tester) async {
      await pump(tester, allow: true);
      await openMenu(tester);
      expect(find.text('Optional'), findsOneWidget);
      expect(_menuItemChecked(tester), isFalse);
      await tester.tap(find.text('Optional'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(emitted.last.single.isOptional, isTrue);
      await teardownSubtree(tester);
    });

    testWidgets('no toggle on a document that does not offer it', (
      tester,
    ) async {
      await pump(tester, allow: false);
      await openMenu(tester);
      expect(find.text('Optional'), findsNothing);
      expect(find.text('Clone'), findsOneWidget);
      await teardownSubtree(tester);
    });

    testWidgets('a line already optional is marked, and can be cleared', (
      tester,
    ) async {
      await pump(tester, allow: false, optional: true);
      // The marker under the line total.
      expect(find.text('Optional'), findsOneWidget);

      await openMenu(tester);
      // Menu item + marker.
      expect(find.text('Optional'), findsNWidgets(2));
      expect(_menuItemChecked(tester), isTrue);
      await tester.tap(find.text('Optional').last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(emitted.last.single.isOptional, isFalse);
      await teardownSubtree(tester);
    });
  });

  group('phone', () {
    Future<void> pump(
      WidgetTester tester, {
      required bool allow,
      bool optional = false,
    }) async {
      emitted = <List<LineItem>>[];
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final fixture = await fixtureFor();
      await tester.pumpWidget(
        wrapWithShell(
          fixture.services,
          LineItemCardListMobile(
            companyId: 'co1',
            items: [_line(optional: optional)],
            onChanged: emitted.add,
            newItemFactory: emptyLineItem,
            config: const LineItemColumnConfig(),
            currencyId: '1',
            allowOptionalLines: allow,
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('the edit dialog has an Optional switch on a quote', (
      tester,
    ) async {
      await pump(tester, allow: true);
      await tester.tap(find.text('WARRANTY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final toggle = find.widgetWithText(SwitchListTile, 'Optional');
      expect(toggle, findsOneWidget);
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(emitted.last.single.isOptional, isTrue);
      await teardownSubtree(tester);
    });

    testWidgets('no switch on a document that does not offer it', (
      tester,
    ) async {
      await pump(tester, allow: false);
      await tester.tap(find.text('WARRANTY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.widgetWithText(SwitchListTile, 'Optional'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 300));
      await teardownSubtree(tester);
    });

    testWidgets('an optional line\'s card says so', (tester) async {
      await pump(tester, allow: true, optional: true);
      expect(find.text('Optional'), findsOneWidget);
      await teardownSubtree(tester);
    });
  });
}

/// The row menu's Optional item's tick. Its value type is the table's private
/// action enum, so it is found by shape rather than by type argument.
bool _menuItemChecked(WidgetTester tester) => tester
    .widget<CheckedPopupMenuItem<dynamic>>(
      find.byWidgetPredicate((w) => w is CheckedPopupMenuItem),
    )
    .checked;
