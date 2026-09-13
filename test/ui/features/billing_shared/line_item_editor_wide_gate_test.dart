// The Items-tab FAB is mounted by `BillingDocEditItemsBody` exactly where
// `LineItemEditor` renders the desktop table, because that table has no inline
// picker affordance of its own (invoiceninja/flutter#142). Two widgets, one
// question — so the predicate is shared, and this is what stops the editor
// drifting away from it. A drift is silent in both directions: a FAB over the
// card list is the duplicate #142 asked to remove, and no FAB over the table
// leaves the picker unreachable on an iPad, which has no ⌘N either.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_card_list_mobile.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_editor.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_table_desktop.dart';

import '../shell/_shell_test_helpers.dart';

void main() {
  test('the gate is a single threshold on CONTENT width', () {
    expect(lineItemEditorShowsWideTable(kLineItemWideTableMinWidth), isTrue);
    expect(
      lineItemEditorShowsWideTable(kLineItemWideTableMinWidth - 1),
      isFalse,
    );
    expect(lineItemEditorShowsWideTable(0), isFalse);
  });

  /// Pump the editor in a box of exactly [width] and report which branch it
  /// chose. The `SizedBox` is the point: the editor's own `LayoutBuilder` must
  /// see the number under test, not the window's.
  Future<bool> rendersWideTable(WidgetTester tester, double width) async {
    final fixture = await buildFixture(
      companies: [const FakeCompany(id: 'co1', name: 'Co')],
    );
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: LineItemEditor(
              companyId: 'co1',
              items: [emptyLineItem().copyWith(productKey: 'Widget')],
              onChanged: (_) {},
              newItemFactory: emptyLineItem,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));

    final wide = find.byType(LineItemTableDesktop).evaluate().isNotEmpty;
    final narrow = find.byType(LineItemCardListMobile).evaluate().isNotEmpty;
    expect(wide != narrow, isTrue, reason: 'exactly one branch renders');

    // Drift schedules a zero-duration close timer on unsubscribe.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    return wide;
  }

  // One fixture per test: `buildFixture` opens its own `AppDatabase`, and two
  // live at once make drift warn about racing executors.
  for (final width in [
    kLineItemWideTableMinWidth,
    kLineItemWideTableMinWidth - 1,
  ]) {
    testWidgets('the editor agrees with the gate at $width px of content', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      expect(
        await rendersWideTable(tester, width),
        lineItemEditorShowsWideTable(width),
      );
    });
  }
}
