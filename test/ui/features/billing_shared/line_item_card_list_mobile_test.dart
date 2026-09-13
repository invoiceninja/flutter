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
                    config: const LineItemColumnConfig(),
                    currencyId: '1',
                    onPickItems: withPicker ? () => pickerTaps++ : null,
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

    testWidgets('both are outlined in both states', (tester) async {
      // The populated footer used to be a borderless TextButton, which read as
      // a tertiary link beside the empty state's outlined pair.
      await pump(tester);
      expect(find.byType(OutlinedButton), findsNWidgets(2));

      items = [emptyLineItem().copyWith(notes: 'existing')];
      await pump(tester);
      expect(find.byType(OutlinedButton), findsNWidgets(2));
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
}
