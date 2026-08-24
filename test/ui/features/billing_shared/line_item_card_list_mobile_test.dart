import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
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
/// (invoiceninja/flutter#87).
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

  Future<void> pump(WidgetTester tester, {bool withPicker = true}) {
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
    );
  }

  testWidgets('the empty state offers a blank row as well as the picker', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Add Item'), findsOneWidget);
    expect(find.text('Add Items'), findsOneWidget);

    // The blank row must not open the picker — that is the whole complaint.
    await tester.tap(find.text('Add Item'));
    await tester.pumpAndSettle();
    expect(pickerTaps, 0);
    expect(items, hasLength(1));
  });

  testWidgets('the picker button still opens the picker', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Add Items'));
    await tester.pumpAndSettle();
    expect(pickerTaps, 1);
    expect(items, isEmpty);
  });

  testWidgets('no picker wired → only the blank-row action', (tester) async {
    await pump(tester, withPicker: false);

    expect(find.text('Add Item'), findsOneWidget);
    expect(find.text('Add Items'), findsNothing);
  });

  testWidgets('a populated list keeps a blank-row action below the cards', (
    tester,
  ) async {
    items = [emptyLineItem().copyWith(notes: 'existing')];
    await pump(tester);

    expect(find.text('Add Item'), findsOneWidget);
    await tester.tap(find.text('Add Item'));
    await tester.pumpAndSettle();
    expect(items, hasLength(2));
    expect(pickerTaps, 0);
  });
}
