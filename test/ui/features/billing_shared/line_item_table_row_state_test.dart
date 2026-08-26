// `widget.onChanged` does not update `widget.items` within the frame — the
// parent rebuilds on the next one. Anything that mutates the list right after
// flushing must therefore build from the FLUSHED list, not from the props.
// `_addBlankRow` did the latter: tab out of the last cell inside the 250 ms
// cell debounce and the row you had just typed was committed by the flush and
// then immediately discarded, replaced by a blank one.
//
// The same file also keeps a parallel `_RowState` list that `_commitPending`
// pairs POSITIONALLY with `widget.items`, and `_remove` / `_clone` /
// `_insertBelow` used to shift one without the other (`_move` documents that
// they must move together). That inconsistency is now fixed, but note it was
// NOT reachable as data corruption: every trigger for those three is a popup
// menu, and a menu's open-then-select cycle always outlasts the 250 ms
// debounce, so the pending text is already committed by the time the row set
// changes. It is pinned here as an invariant, not as a repro.

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_column_config.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_table_desktop.dart';

import '../shell/_shell_test_helpers.dart';

/// Stateful host: the real edit layouts own the list and re-render the table
/// with it, so the table's `widget.items` advances one frame after `onChanged`.
/// Without that feedback the table would keep reconciling against the original
/// list and the test would prove nothing.
class _Host extends StatefulWidget {
  const _Host({
    required this.initial,
    required this.onChanged,
    required this.controller,
  });

  final List<LineItem> initial;
  final ValueChanged<List<LineItem>> onChanged;
  final LineItemTableDesktopController controller;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late List<LineItem> _items = widget.initial;

  @override
  Widget build(BuildContext context) => LineItemTableDesktop(
    companyId: 'co1',
    items: _items,
    onChanged: (next) {
      widget.onChanged(next);
      setState(() => _items = next);
    },
    newItemFactory: emptyLineItem,
    config: const LineItemColumnConfig(),
    controller: widget.controller,
  );
}

LineItem _line(String key, String notes) => emptyLineItem().copyWith(
  productKey: key,
  notes: notes,
  cost: Decimal.fromInt(10),
  quantity: Decimal.one,
);

void main() {
  late List<List<LineItem>> emitted;
  late LineItemTableDesktopController controller;

  Future<void> teardownSubtree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// Pump the table directly (no stateful host) with an explicit column config.
  Future<void> pumpWithConfig(
    WidgetTester tester,
    LineItemColumnConfig config,
  ) async {
    emitted = <List<LineItem>>[];
    controller = LineItemTableDesktopController();
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fixture = await buildFixture(
      companies: [const FakeCompany(id: 'co1', name: 'Co')],
    );
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        LineItemTableDesktop(
          companyId: 'co1',
          items: [_line('A', 'Alpha')],
          onChanged: emitted.add,
          newItemFactory: emptyLineItem,
          config: config,
          controller: controller,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> pumpTable(WidgetTester tester, List<LineItem> items) async {
    emitted = <List<LineItem>>[];
    controller = LineItemTableDesktopController();
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fixture = await buildFixture(
      companies: [const FakeCompany(id: 'co1', name: 'Co')],
    );
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        _Host(initial: items, onChanged: emitted.add, controller: controller),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Opens the row menu WITHOUT letting the 250 ms cell debounce fire — the
  /// whole point is that the caret's text is still pending when the row set
  /// changes underneath it. (A helper that pumps 300 ms commits the text first
  /// and the test then proves nothing.)
  Future<void> openRowMenu(WidgetTester tester, int index) async {
    await tester.tap(find.byIcon(Icons.more_vert).at(index));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('a row mutation carries the focused cell with its line item', () {
    testWidgets(
      'tabbing out of the ghost row keeps the line the user just typed',
      (tester) async {
        await pumpTable(tester, [_line('A', 'Alpha')]);

        // Type a unit cost into the trailing ghost row and tab straight on —
        // the 250 ms debounce has not fired, so `_addBlankRow` has to take the
        // flushed list rather than the props.
        // Cells per row with the default config (no discount column):
        // product, notes, cost, quantity, tax. The ghost row is the last one,
        // and `onTabForward` sits on its quantity cell — the last typing cell
        // when the discount column is hidden.
        final fields = find.byType(TextField);
        final n = fields.evaluate().length;
        await tester.enterText(fields.at(n - 3), '42'); // ghost cost
        await tester.pump(Duration.zero);
        await tester.tap(fields.at(n - 2)); // focus ghost quantity
        await tester.pump(Duration.zero);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        for (var i = 0; i < 8; i++) {
          await tester.pump(Duration.zero);
        }

        // Assert on what the tab itself emitted — before any later flush can
        // launder the value back in through a different route.
        final last = emitted.last;
        expect(
          last,
          hasLength(3),
          reason: 'A, the promoted row, and a fresh ghost',
        );
        expect(
          last[1].cost,
          Decimal.fromInt(42),
          reason: 'the row typed into the ghost slot survived the tab',
        );
        await teardownSubtree(tester);
      },
    );

    testWidgets('inserting a row above the caret does not overwrite its item', (
      tester,
    ) async {
      await pumpTable(tester, [
        _line('A', 'Alpha'),
        _line('B', 'Beta'),
        _line('C', 'Gamma'),
      ]);

      await tester.enterText(
        find.widgetWithText(TextField, 'Gamma'),
        'Gamma edited',
      );
      await tester.pump(const Duration(milliseconds: 50));

      await openRowMenu(tester, 0);
      await tester.tap(find.text('Insert Below'));
      await tester.pump(const Duration(milliseconds: 300));

      controller.flushPending();
      await tester.pump(const Duration(milliseconds: 300));

      final last = emitted.last;
      expect(last, hasLength(4), reason: 'A, new blank, B, C');
      expect(last[0].productKey, 'A');
      expect(last[2].productKey, 'B');
      expect(last[2].notes, 'Beta', reason: 'B keeps its own text');
      expect(last[3].productKey, 'C');
      expect(last[3].notes, 'Gamma edited');

      await teardownSubtree(tester);
    });
  });

  // `_emit` reconciles `_rows` (which drives the ListView's `itemCount`)
  // against the list it just emitted, while the parent's rebuild lands a frame
  // later. Everything that renders a row therefore has to read the same list —
  // reading `widget.items` left the two disagreeing, and a just-promoted row
  // rendered as the GHOST: no row menu, `current` from `newItemFactory()`,
  // suppressed row errors, off-by-one `lastRealIndex`.
  //
  // Pumped against a host that does NOT feed the list back, so the divergence
  // is permanent and deterministic rather than a one-frame flicker.
  group('a promoted row renders as a real row, not the ghost', () {
    testWidgets('the ghost row gains a row menu once it is promoted', (
      tester,
    ) async {
      await pumpWithConfig(tester, const LineItemColumnConfig());

      // One real row (A) + the trailing ghost. Only real rows carry a menu.
      expect(find.byIcon(Icons.more_vert), findsOneWidget);

      final fields = find.byType(TextField);
      final n = fields.evaluate().length;
      await tester.enterText(fields.at(n - 3), '42'); // ghost cost
      await tester.pump(const Duration(milliseconds: 300)); // debounce fires

      expect(
        find.byIcon(Icons.more_vert),
        findsNWidgets(2),
        reason: 'A plus the promoted row; the new trailing ghost has no menu',
      );
      await teardownSubtree(tester);
    });
  });

  // The mobile edit dialog has always honoured all three item tax slots
  // (`>= 1` / `>= 2` / `>= 3`); the desktop table rendered only the first. A
  // company on 2 or 3 item tax rates could therefore enter a second tax on a
  // phone and not on a desktop — the same invoice totalling differently by
  // viewport, with no desktop escape hatch (`showLineItemEditDialog` is
  // reachable only from the mobile card list).
  group('every enabled item tax slot gets a column', () {
    testWidgets('three slots render three numbered headers', (tester) async {
      await pumpWithConfig(
        tester,
        const LineItemColumnConfig(taxColumnCount: 3),
      );
      // The header renders labels upper-cased.
      expect(find.text('TAX 1'), findsOneWidget);
      expect(find.text('TAX 2'), findsOneWidget);
      expect(find.text('TAX 3'), findsOneWidget);
      await teardownSubtree(tester);
    });

    testWidgets('a single slot keeps the unnumbered label', (tester) async {
      await pumpWithConfig(tester, const LineItemColumnConfig());
      expect(find.text('TAX'), findsOneWidget);
      expect(find.text('TAX 1'), findsNothing);
      await teardownSubtree(tester);
    });

    testWidgets('each slot is an editable cell of its own', (tester) async {
      // One row + the ghost row. Cells per row with no discount column:
      // product, notes, cost, quantity, then one per tax slot.
      await pumpWithConfig(
        tester,
        const LineItemColumnConfig(taxColumnCount: 3),
      );
      final three = find.byType(TextField).evaluate().length;

      await teardownSubtree(tester);

      await pumpWithConfig(tester, const LineItemColumnConfig());
      final one = find.byType(TextField).evaluate().length;

      // Two rows × two extra tax cells each.
      expect(three - one, 4);
      await teardownSubtree(tester);
    });
  });
}
