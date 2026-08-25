// Regression for invoiceninja/flutter#84. Settings → Localization → Custom
// Labels writes `company.settings.translations`, and the server applies that
// map to everything it renders (PDFs, emails, the client portal); React pushes
// it into i18next at app start and admin-portal reads it inline at the
// line-item table. This app *stored* the map and never read it back, so a
// company that renamed "Unit Cost" saw the rename everywhere except here.
//
// These tests drive the real editor against a seeded company so they cover the
// whole path: the Drift company watch → `LineItemColumnConfig.forCompany` →
// the desktop header.

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_editor.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_table_desktop.dart';

import '../shell/_shell_test_helpers.dart';

LineItem _widgetLine() => emptyLineItem().copyWith(
  productKey: 'Widget',
  cost: Decimal.fromInt(10),
  quantity: Decimal.one,
);

void main() {
  // The header renders from the company watch, which emits asynchronously.
  // Pump bounded frames rather than `pumpAndSettle` — the fixture leaves
  // pending Services timers that would hang it.
  Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 15 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> teardownSubtree(WidgetTester tester) async {
    // Drift schedules a zero-duration close timer on unsubscribe; unmount +
    // elapse the clock so it fires before the "Timer still pending" invariant.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> pumpEditor(
    WidgetTester tester, {
    required Map<String, dynamic> settings,
  }) async {
    // Wide enough for the desktop table branch (the header only exists there).
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fixture = await buildFixture(
      companies: [FakeCompany(id: 'co1', name: 'Co', settings: settings)],
    );
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        LineItemEditor(
          companyId: 'co1',
          items: [_widgetLine()],
          onChanged: (_) {},
          newItemFactory: emptyLineItem,
        ),
      ),
    );
    await pumpUntil(tester, find.byType(LineItemTableDesktop));
  }

  testWidgets('the header shows the shipped label when nothing is overridden', (
    tester,
  ) async {
    await pumpEditor(tester, settings: const {});
    await pumpUntil(tester, find.text('UNIT COST'));

    // The header uppercases its labels.
    expect(find.text('UNIT COST'), findsOneWidget);
    await teardownSubtree(tester);
  });

  testWidgets('the header shows the company Custom Label instead', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      settings: const {
        'translations': {'unit_cost': 'Unit Price'},
      },
    );
    await pumpUntil(tester, find.text('UNIT PRICE'));

    expect(find.text('UNIT PRICE'), findsOneWidget);
    expect(find.text('UNIT COST'), findsNothing);
    await teardownSubtree(tester);
  });

  testWidgets('a blank Custom Label falls back to the shipped one', (
    tester,
  ) async {
    // Adding a Custom Labels row without typing in it stores '' — that must
    // not blank the column header.
    await pumpEditor(
      tester,
      settings: const {
        'translations': {'unit_cost': ''},
      },
    );
    await pumpUntil(tester, find.text('UNIT COST'));

    expect(find.text('UNIT COST'), findsOneWidget);
    await teardownSubtree(tester);
  });
}
