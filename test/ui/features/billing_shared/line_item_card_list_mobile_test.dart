import 'package:decimal/decimal.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_card_list_mobile.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_column_config.dart';
import 'package:admin/app/services.dart';
import 'package:admin/utils/formatting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../_localization_helper.dart';

/// The phone editor only offered the picker, which can add nothing that isn't
/// already a Product / Task / Expense — so a one-off line item, which the
/// desktop table has always allowed, could not be entered at all
/// (invoiceninja/flutter#87). The converse is invoiceninja/flutter#142: the
/// picker button then disappeared the moment a row existed, and the FAB that
/// covered it on this branch is gone.
///
/// `_ItemCard` asks Services for a Formatter and renders unformatted when it
/// isn't ready — which is the only thing these tests need from the DI graph.
class _FakeServices implements Services {
  @override
  Formatter? formatterIfReady(String companyId) => null;

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

void main() {
  late List<LineItem> items;
  late int pickerTaps;

  setUp(() {
    items = <LineItem>[];
    pickerTaps = 0;
  });

  /// [minHeight] stands in for the `ConstrainedBox` that
  /// `BillingDocEditItemsBody` sets to the viewport height — the empty state's
  /// vertical centring is nothing but `Center` under that constraint.
  Future<void> pump(
    WidgetTester tester, {
    bool withPicker = true,
    double minHeight = 0,
    Map<int, Map<String, String>>? rowErrors,
    LineItemColumnConfig config = const LineItemColumnConfig(),
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Provider<Services>.value(
          value: _FakeServices(),
          child: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minHeight),
                  child: LineItemCardListMobile(
                    companyId: 'co',
                    items: items,
                    onChanged: (next) => setState(() => items = next),
                    newItemFactory: emptyLineItem,
                    config: config,
                    currencyId: '1',
                    onPickItems: withPicker ? () => pickerTaps++ : null,
                    rowErrors: rowErrors,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Finder addLine() => find.widgetWithText(OutlinedButton, 'Add Line');
  Finder addItems() => find.widgetWithText(OutlinedButton, 'Add Items');
  Finder addText() => find.widgetWithText(OutlinedButton, 'Add Text');

  group('the two doors', () {
    testWidgets('the empty state offers a blank row as well as the picker', (
      tester,
    ) async {
      await pump(tester);

      expect(addLine(), findsOneWidget);
      expect(addItems(), findsOneWidget);
    });

    testWidgets('a POPULATED list offers both of them too', (tester) async {
      // The picker button used to render only while the list was empty, and
      // the FAB that covered the gap is gone from this branch — so on a phone
      // there was no way to reach the picker at all once a row existed
      // (invoiceninja/flutter#142).
      items = [emptyLineItem().copyWith(notes: 'existing')];
      await pump(tester);

      expect(addLine(), findsOneWidget);
      expect(addItems(), findsOneWidget);

      await tester.tap(addItems());
      await tester.pumpAndSettle();
      expect(pickerTaps, 1);
      expect(items, hasLength(1), reason: 'the picker adds nothing by itself');
    });

    testWidgets('all three are outlined in both states', (tester) async {
      // The populated footer used to be a borderless TextButton, which read as
      // a tertiary link beside the empty state's outlined pair.
      await pump(tester);
      expect(find.byType(OutlinedButton), findsNWidgets(3));

      items = [emptyLineItem().copyWith(notes: 'existing')];
      await pump(tester);
      expect(find.byType(OutlinedButton), findsNWidgets(3));
    });

    testWidgets('the picker button opens the picker', (tester) async {
      await pump(tester);

      await tester.tap(addItems());
      await tester.pumpAndSettle();
      expect(pickerTaps, 1);
      expect(items, isEmpty);
    });

    testWidgets('no picker wired → only the blank-row action', (tester) async {
      await pump(tester, withPicker: false);

      expect(addLine(), findsOneWidget);
      expect(addItems(), findsNothing);
    });
  });

  group('Add Line opens the editor first', () {
    testWidgets('confirming appends the edited row, not a blank one', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(addLine());
      await tester.pumpAndSettle();
      // The dialog names the verb it is serving, so Cancel is unambiguous.
      expect(find.widgetWithText(AlertDialog, 'Add Line'), findsOneWidget);
      expect(pickerTaps, 0, reason: 'the blank row must not open the picker');
      expect(
        items,
        isEmpty,
        reason: 'nothing is added until the user confirms',
      );

      await tester.enterText(find.byType(TextField).first, 'Consulting');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(items, hasLength(1));
      expect(items.single.productKey, 'Consulting');
      expect(pickerTaps, 0);
    });

    testWidgets('cancelling adds nothing at all', (tester) async {
      await pump(tester);

      await tester.tap(addLine());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(items, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('it appends below an existing row', (tester) async {
      items = [emptyLineItem().copyWith(notes: 'existing')];
      await pump(tester);

      await tester.tap(addLine());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'second');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(items, hasLength(2));
      expect(items.last.productKey, 'second');
      expect(pickerTaps, 0);
    });
  });

  group('the empty state is centred (invoiceninja/flutter#141)', () {
    testWidgets('horizontally, within whatever width it is given', (
      tester,
    ) async {
      await pump(tester);

      final host = tester.getRect(find.byType(SingleChildScrollView));
      final body = tester.getRect(find.byType(EmptyStateBody));
      expect(body.center.dx, closeTo(host.center.dx, 0.5));
    });

    testWidgets('vertically, when an ancestor supplies the viewport height', (
      tester,
    ) async {
      await pump(tester, minHeight: 500);

      final body = tester.getRect(find.byType(EmptyStateBody));
      // `Center` shrink-wraps to `max(child, minHeight)` under an infinite
      // maxHeight, so the block lands in the middle of the 500 it was given.
      expect(body.center.dy, closeTo(250, 1));
    });

    testWidgets('and still scrolls when it outgrows the viewport', (
      tester,
    ) async {
      // Nothing may clip: a landscape phone at a large text scale is taller
      // than the tab it sits in.
      tester.view.physicalSize = const Size(360, 220);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pump(tester, minHeight: 220);
      expect(tester.takeException(), isNull);
    });
  });

  // A 422 on `line_items.1.cost` used to highlight nothing on a phone: the
  // cards took no row errors at all.
  testWidgets('a row the server rejected says so, on its own card', (
    tester,
  ) async {
    items = [
      emptyLineItem().copyWith(productKey: 'First'),
      emptyLineItem().copyWith(productKey: 'Second'),
    ];
    await pump(
      tester,
      rowErrors: {
        1: {'cost': 'The cost must be a number.'},
      },
    );
    expect(find.text('The cost must be a number.'), findsOneWidget);
    final card = find.ancestor(
      of: find.text('The cost must be a number.'),
      matching: find.byType(Container),
    );
    expect(
      find.descendant(of: card.first, matching: find.text('Second')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card.first, matching: find.text('First')),
      findsNothing,
    );
  });

  // A customer was adding a blank item, typing into the three-line
  // Description and zeroing its quantity by hand to put a paragraph on the PDF.
  group('Add Text', () {
    testWidgets('appends a line with no product, cost or quantity', (
      tester,
    ) async {
      items = [emptyLineItem().copyWith(productKey: 'SC2')];
      await pump(tester);

      await tester.tap(addText());
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AlertDialog, 'Add Text'), findsOneWidget);
      expect(items, hasLength(1), reason: 'nothing until the user confirms');

      await tester.enterText(find.byType(TextField), 'Diagnosed the fan.');
      await tester.pump(); // Add enables on the rebuild the text triggers.
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(items, hasLength(2));
      final line = items.last;
      expect(line.notes, 'Diagnosed the fan.');
      expect(line.isTextOnly, isTrue);
      expect(
        line.quantity,
        Decimal.zero,
        reason: 'a quantity of 1 prints \$0.00 1 \$0.00 on the PDF',
      );
      expect(pickerTaps, 0);
    });

    testWidgets('can\'t add an empty one', (tester) async {
      await pump(tester);
      await tester.tap(addText());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(items, isEmpty);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('on a phone the box fills the screen', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(tester);

      await tester.tap(addText());
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        tester.getSize(find.byType(TextField)).height,
        greaterThan(500),
        reason: 'the point is to see what you are writing',
      );
    });

    testWidgets('closing with text typed asks before throwing it away', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(addText());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'A paragraph');

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Keep editing'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('A paragraph'), findsOneWidget);
      expect(items, isEmpty);
    });

    testWidgets('the Tasks table offers no text line', (tester) async {
      // Its new rows are hourly (`type_id` 2); a text line is a product row
      // and would jump out of the tab.
      await pump(tester, config: const LineItemColumnConfig(isTaskTable: true));
      expect(addLine(), findsOneWidget);
      expect(addText(), findsNothing);
    });

    testWidgets('a text card shows its text, not \$0.00 × 0', (tester) async {
      items = [textLineItem().copyWith(notes: 'First line\nSecond line')];
      await pump(tester);

      expect(find.text('First line\nSecond line'), findsOneWidget);
      expect(find.textContaining('× 0'), findsNothing);
      expect(find.textContaining('0.00'), findsNothing);
    });

    testWidgets('tapping a text card opens the text editor', (tester) async {
      items = [textLineItem().copyWith(notes: 'Old')];
      await pump(tester);

      await tester.tap(find.text('Old'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'New');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(items.single.notes, 'New');
      expect(items.single.isTextOnly, isTrue);
    });

    testWidgets('More Fields hands the edited text to the full editor', (
      tester,
    ) async {
      items = [textLineItem().copyWith(notes: 'Old')];
      await pump(tester);

      await tester.tap(find.text('Old'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Edited');
      await tester.tap(find.text('More Fields'));
      await tester.pumpAndSettle();

      // The full editor: Product, Description, Cost, Quantity…
      expect(find.byType(TextField), findsAtLeastNWidgets(4));
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Edited'),
        ),
        findsOneWidget,
      );
      // Cancel there keeps the text, which was already committed.
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(items.single.notes, 'Edited');
    });
  });
}
