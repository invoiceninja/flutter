import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/billing/line_item_custom_fields.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_column_config.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_table_desktop.dart';

import '../shell/_shell_test_helpers.dart';

/// The desktop / iPad line-item table had no custom-field columns at all, so
/// a product's custom values — copied onto the line by the picker — could be
/// neither seen nor edited there. React and admin-portal both add a column
/// per configured `product1..4`.
const _definitions = {
  'product1': 'Serial|single_line_text',
  'product2': 'Warranty|switch',
  'product3': 'Color|Red,Blue',
  'product4': 'Shipped|date',
};

LineItemColumnConfig _config({
  Map<String, String> definitions = _definitions,
  int taxColumnCount = 1,
}) => LineItemColumnConfig(
  taxColumnCount: taxColumnCount,
  customFields: lineItemCustomFields(definitions, task: false),
);

LineItem _line({String serial = '', String warranty = ''}) =>
    emptyLineItem().copyWith(
      productKey: 'Widget',
      notes: 'A widget',
      cost: Decimal.fromInt(10),
      customValue1: serial,
      customValue2: warranty,
    );

/// Feeds the emitted list back, as the real edit layouts do — the table's
/// `widget.items` advances one frame after `onChanged`.
class _Host extends StatefulWidget {
  const _Host({
    required this.initial,
    required this.config,
    required this.onChanged,
  });

  final List<LineItem> initial;
  final LineItemColumnConfig config;
  final ValueChanged<List<LineItem>> onChanged;

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
    config: widget.config,
  );
}

void main() {
  late List<List<LineItem>> emitted;
  late ShellFixture fixture;

  Future<void> pump(
    WidgetTester tester, {
    required List<LineItem> items,
    LineItemColumnConfig? config,
    double width = 1600,
  }) async {
    emitted = <List<LineItem>>[];
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    fixture = await buildFixture(
      companies: [const FakeCompany(id: 'co1', name: 'Co')],
    );
    addTearDown(fixture.dispose);
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        _Host(
          initial: items,
          config: config ?? _config(),
          onChanged: emitted.add,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// The custom cell for [slot] on row [row] (0-based; the last is the ghost).
  Finder cell(int slot, int row) =>
      find.byKey(ValueKey('custom_$slot')).at(row + 1); // +1: the header

  testWidgets('each field is a column headed by the company label', (
    tester,
  ) async {
    await pump(tester, items: [_line()]);

    for (final label in ['SERIAL', 'WARRANTY', 'COLOR', 'SHIPPED']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    // One line in a fixed column; the label as typed is the tooltip.
    expect(
      find.byWidgetPredicate((w) => w is Tooltip && w.message == 'Serial'),
      findsWidgets,
    );
    await teardown(tester);
  });

  testWidgets('a text cell shows the value and commits an edit, untrimmed', (
    tester,
  ) async {
    await pump(tester, items: [_line(serial: 'SN-1')]);

    final field = find.descendant(
      of: cell(1, 0),
      matching: find.byType(TextField),
    );
    expect(find.descendant(of: field, matching: find.text('SN-1')), findsOne);

    await tester.enterText(field, 'SN-2 ');
    await tester.pump(const Duration(milliseconds: 300));
    expect(emitted.last.single.customValue1, 'SN-2 ');
    await teardown(tester);
  });

  testWidgets('clearing a cell the user just typed in commits the clear', (
    tester,
  ) async {
    // Only typed text is written back, which a seed that lagged behind the
    // cell's own commit would read as "no edit" and keep the old value.
    await pump(tester, items: [_line()]);
    final field = find.descendant(
      of: cell(1, 0),
      matching: find.byType(TextField),
    );

    await tester.enterText(field, 'SN-9');
    await tester.pump(const Duration(milliseconds: 300));
    expect(emitted.last.single.customValue1, 'SN-9');

    await tester.enterText(field, '');
    await tester.pump(const Duration(milliseconds: 300));
    expect(emitted.last.single.customValue1, '');
    await teardown(tester);
  });

  testWidgets('a switch cell commits yes / no, and is inert on the ghost row', (
    tester,
  ) async {
    await pump(tester, items: [_line(serial: 'SN-1')]);

    final boxes = find.byType(Checkbox);
    expect(boxes, findsNWidgets(2), reason: 'one row + the ghost');
    expect(
      tester.widget<Checkbox>(boxes.last).onChanged,
      isNull,
      reason:
          'a tick on the ghost would promote a line holding only "yes", '
          'which survives the save-time blank strip',
    );

    await tester.tap(boxes.first);
    await tester.pump(const Duration(milliseconds: 50));
    expect(emitted.last.single.customValue2, 'yes');
    await teardown(tester);
  });

  testWidgets('a tick inside the text debounce keeps the text typed', (
    tester,
  ) async {
    // The switch commits at once, on the row rebuilt from its live cells — so
    // text still inside the 250 ms debounce rides along rather than reverting.
    await pump(tester, items: [_line(serial: 'SN-1')]);
    await tester.enterText(
      find.descendant(of: cell(1, 0), matching: find.byType(TextField)),
      'SN-77',
    );
    await tester.pump(Duration.zero);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump(Duration.zero);

    expect(emitted.last.single.customValue1, 'SN-77');
    expect(emitted.last.single.customValue2, 'yes');
    await tester.pump(const Duration(milliseconds: 300));
    await teardown(tester);
  });

  testWidgets('tick then untick on a blank row leaves it blank', (
    tester,
  ) async {
    // `isBlank` counts any custom value as content, so a stored `no` would
    // keep an inserted blank line past the save-time strip.
    await pump(tester, items: [_line(), emptyLineItem()]);
    final box = find.byType(Checkbox).at(1);

    await tester.tap(box);
    await tester.pump(const Duration(milliseconds: 50));
    expect(emitted.last[1].customValue2, 'yes');
    await tester.tap(box);
    await tester.pump(const Duration(milliseconds: 50));
    expect(emitted.last[1].isBlank, isTrue);

    // A row with content still stores the `no` React and v1 store.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump(const Duration(milliseconds: 50));
    expect(emitted.last[0].customValue2, 'no');
    await teardown(tester);
  });

  testWidgets('typing in a custom text cell on the ghost row adds the line', (
    tester,
  ) async {
    await pump(tester, items: [_line()]);
    await tester.enterText(
      find.descendant(of: cell(1, 1), matching: find.byType(TextField)),
      'SN-5',
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(emitted.last, hasLength(2));
    expect(emitted.last[1].customValue1, 'SN-5');
    await teardown(tester);
  });

  testWidgets('a date cell commits typed text, clears, and is inert on the '
      'ghost row', (tester) async {
    await pump(tester, items: [_line()]);
    final field = find.descendant(
      of: cell(4, 0),
      matching: find.byType(TextField),
    );
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: cell(4, 1), matching: find.byType(TextField)),
          )
          .enabled,
      isFalse,
    );

    await tester.enterText(field, '2026-05-14');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 50));
    expect(emitted.last.single.customValue4, '2026-05-14');

    await tester.enterText(field, '');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 50));
    expect(emitted.last.single.customValue4, '');
    await teardown(tester);
  });

  testWidgets('the menu cell paints its ink on a Material of its own', (
    tester,
  ) async {
    // Else its focus / hover / press paint on the Scaffold's Material, under
    // the table's opaque surface — a Tab stop nobody can see. A widget test
    // can't see the paint, so it asserts where the ink lands.
    await pump(tester, items: [_line()]);
    final ink = find.descendant(of: cell(3, 0), matching: find.byType(InkWell));
    final material = tester.widget<Material>(
      find.ancestor(of: ink, matching: find.byType(Material)).first,
    );
    expect(
      find.descendant(of: cell(3, 0), matching: find.byWidget(material)),
      findsOneWidget,
    );
    await teardown(tester);
  });

  group('a dropdown with more options than a menu lists', () {
    final options = [for (var i = 1; i <= 25; i++) 'Option $i'];
    final config = _config(
      definitions: {'product3': 'Size|${options.join(',')}'},
    );
    LineItem sized(String v) => _line().copyWith(customValue3: v);

    testWidgets('Enter on a filled cell keeps the value', (tester) async {
      // `RawAutocomplete` highlights row 0 and Enter picks it; with the blank
      // first, that erased the value.
      await pump(tester, items: [sized('Option 7')], config: config);
      final field = find.descendant(
        of: cell(3, 0),
        matching: find.byType(TextField),
      );
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(
        emitted.where((l) => l.single.customValue3 != 'Option 7'),
        isEmpty,
      );
      await teardown(tester);
    });

    testWidgets('an option typed in full is kept on leaving the cell', (
      tester,
    ) async {
      await pump(tester, items: [sized('Option 7')], config: config);
      final field = find.descendant(
        of: cell(3, 0),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, 'option 12');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(emitted.last.single.customValue3, 'Option 12');
      await teardown(tester);
    });

    testWidgets('text naming no option is put back', (tester) async {
      await pump(tester, items: [sized('Option 7')], config: config);
      final field = find.descendant(
        of: cell(3, 0),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, 'nonsense');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(emitted, isEmpty);
      expect(
        find.descendant(of: field, matching: find.text('Option 7')),
        findsOne,
      );
      await teardown(tester);
    });
  });

  testWidgets('a dropdown cell picks from a menu of the options', (
    tester,
  ) async {
    await pump(tester, items: [_line()]);

    await tester.tap(
      find.descendant(of: cell(3, 0), matching: find.byType(InkWell)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Red'), findsOneWidget);
    await tester.tap(find.text('Blue'));
    await tester.pumpAndSettle();

    expect(emitted.last.single.customValue3, 'Blue');
    expect(
      find.descendant(of: cell(3, 0), matching: find.text('Blue')),
      findsOne,
    );
    await teardown(tester);
  });

  group('a table wider than its pane scrolls sideways', () {
    // The table's own sideways scroll view — every single-line text field
    // is a horizontal `Scrollable` too.
    double maxScroll(WidgetTester tester) => tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byWidgetPredicate(
                  (w) =>
                      w is SingleChildScrollView &&
                      w.scrollDirection == Axis.horizontal,
                ),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .maxScrollExtent;

    testWidgets('narrow pane, custom columns → scrolls', (tester) async {
      await pump(
        tester,
        items: [_line()],
        config: _config(taxColumnCount: 3),
        width: 800,
      );
      expect(maxScroll(tester), greaterThan(0));
      await teardown(tester);
    });

    testWidgets('wide pane → fits, nothing to scroll', (tester) async {
      await pump(tester, items: [_line()], config: _config(taxColumnCount: 3));
      expect(maxScroll(tester), 0);
      await teardown(tester);
    });

    testWidgets('no custom fields → the table never scrolls', (tester) async {
      // A company without custom fields keeps the layout it always had.
      await pump(
        tester,
        items: [_line()],
        config: _config(definitions: const {}, taxColumnCount: 3),
        width: 760,
      );
      expect(maxScroll(tester), 0);
      await teardown(tester);
    });
  });
}
