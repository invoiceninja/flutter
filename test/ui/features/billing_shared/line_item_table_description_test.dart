import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_column_config.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_table_desktop.dart';

import '../shell/_shell_test_helpers.dart';

/// Beta feedback: "Item description fields have no way of adding line breaks."
///
/// The wide table's Description cell was a `maxLines: 1` field, which does two
/// things: Return means "done", so a break can't be typed; and `EditableText`
/// prepends `singleLineFormatter`, which filters the WHOLE value on every edit
/// — so a multi-line description seeded from a product, the phone dialog,
/// admin-portal or React lost every break at the first keystroke.
LineItem _line(String notes) => emptyLineItem().copyWith(
  productKey: 'Widget',
  notes: notes,
  cost: Decimal.fromInt(10),
);

/// Feeds the emitted list back, as the real edit layouts do — the table's
/// `widget.items` advances one frame after `onChanged`.
class _Host extends StatefulWidget {
  const _Host({required this.initial, required this.onChanged});

  final List<LineItem> initial;
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
    config: const LineItemColumnConfig(taxColumnCount: 0),
  );
}

void main() {
  late List<List<LineItem>> emitted;
  late ShellFixture fixture;

  Future<void> pump(
    WidgetTester tester,
    List<LineItem> items, {
    TextDirection? textDirection,
  }) async {
    emitted = <List<LineItem>>[];
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    fixture = await buildFixture(
      companies: [const FakeCompany(id: 'co1', name: 'Co')],
    );
    addTearDown(fixture.dispose);
    final Widget host = _Host(initial: items, onChanged: emitted.add);
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        textDirection == null
            ? host
            : Directionality(textDirection: textDirection, child: host),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Finder notesField(String text) => find.byWidgetPredicate(
    (w) => w is TextField && w.controller?.text == text,
  );

  testWidgets('a typed line break is kept', (tester) async {
    await pump(tester, [_line('Line 1')]);

    await tester.enterText(notesField('Line 1'), 'Line 1\nLine 2');
    await tester.pump(const Duration(milliseconds: 300));

    expect(emitted.last.single.notes, 'Line 1\nLine 2');
    await teardown(tester);
  });

  testWidgets('a seeded multi-line description survives an edit', (
    tester,
  ) async {
    await pump(tester, [_line('A\nB')]);

    await tester.enterText(notesField('A\nB'), 'A\nB!');
    await tester.pump(const Duration(milliseconds: 300));

    expect(emitted.last.single.notes, 'A\nB!');
    await teardown(tester);
  });

  testWidgets('the cell is multi-line, so Return inserts a break', (
    tester,
  ) async {
    // A soft keyboard never renders under `flutter test`; the derived
    // keyboard type is what tells the platform Return means newline.
    await pump(tester, [_line('Line 1')]);

    final editable = tester.widget<EditableText>(
      find.descendant(
        of: notesField('Line 1'),
        matching: find.byType(EditableText),
      ),
    );
    expect(editable.keyboardType, TextInputType.multiline);
    expect(editable.maxLines, 6);
    expect(editable.minLines, 1);
    await teardown(tester);
  });

  testWidgets('the cell grows with the description', (tester) async {
    await pump(tester, [_line('One'), _line('One\nTwo\nThree')]);

    final single = tester.getSize(notesField('One')).height;
    final multi = tester.getSize(notesField('One\nTwo\nThree')).height;
    expect(multi, greaterThan(single));
    await teardown(tester);
  });

  testWidgets('Enter alone on the empty row adds no line', (tester) async {
    // Enter there used to unfocus; now it types a newline. A ghost holding
    // only whitespace must not promote, or a stray Enter saves an empty line
    // that prints as a blank row on the PDF.
    await pump(tester, const []);
    final ghostNotes = find.byWidgetPredicate(
      (w) => w is TextField && w.maxLines == 6,
    );
    expect(ghostNotes, findsOneWidget);

    await tester.enterText(ghostNotes, '\n');
    await tester.pump(const Duration(milliseconds: 300));
    expect(emitted.every((items) => items.isEmpty), isTrue);

    await tester.enterText(ghostNotes, 'Hello\n');
    await tester.pump(const Duration(milliseconds: 300));
    expect(emitted.last.single.notes, 'Hello\n');
    await teardown(tester);
  });

  testWidgets('right-to-left: an amount cell reads LTR, flush to the left', (
    tester,
  ) async {
    // Not a description case, but the same harness. An amount is LTR in every
    // language (`-12.5`, never `12.5-`), while the column's end — where the
    // figures line up — is the LEFT edge in RTL. Before the conversion the
    // cell was `textAlign: right` with the ambient (RTL) direction: digits
    // pinned to the wrong edge, and a typed minus could render at the end.
    await pump(tester, [_line('Line 1')], textDirection: TextDirection.rtl);

    final amounts = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.keyboardType ==
              const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
    );
    expect(amounts, findsWidgets);
    for (final field in tester.widgetList<TextField>(amounts)) {
      expect(field.textDirection, TextDirection.ltr);
      expect(field.textAlign, TextAlign.left);
    }
    await teardown(tester);
  });
}
