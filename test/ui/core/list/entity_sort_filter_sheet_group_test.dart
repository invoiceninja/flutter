// The "Group by" section added to the mobile sort sheet (issue #56).
//
// Phones pick the grouping here rather than behind a third AppBar glyph, so
// two things matter: the section is invisible for every list that doesn't
// group (which is all of them but Products), and it applies on Done together
// with the sort — never on tap.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/list/entity_sort_filter_sheet.dart';

import '../../../_localization_helper.dart';

const _sortOptions = [
  SortOption(id: 'product_key', label: 'Product'),
  SortOption(id: 'price', label: 'Price'),
];

Future<String?> _pump(
  WidgetTester tester, {
  List<GroupOption> groupOptions = const [],
  String? initialGroup,
  void Function(String?)? onApplyGroup,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: EntitySortFilterSheet(
          initialField: 'product_key',
          initialAscending: true,
          options: _sortOptions,
          onApply: ({required field, required ascending}) {},
          groupOptions: groupOptions,
          initialGroup: initialGroup,
          onApplyGroup: onApplyGroup,
        ),
      ),
    ),
  );
  return null;
}

void main() {
  testWidgets('no group options means the sheet is unchanged', (tester) async {
    await _pump(tester);
    expect(find.text('Group by'), findsNothing);
    expect(find.text('No grouping'), findsNothing);
    expect(find.text('Product'), findsOneWidget);
  });

  testWidgets('group options render below the sort list', (tester) async {
    await _pump(
      tester,
      groupOptions: const [
        GroupOption(id: 'custom1', label: 'Category'),
        GroupOption(id: 'tags', label: 'Tags'),
      ],
    );
    expect(find.text('Group by'), findsOneWidget);
    expect(find.text('No grouping'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Tags'), findsOneWidget);
  });

  testWidgets('the choice applies on Done, not on tap', (tester) async {
    String? applied;
    var calls = 0;
    await _pump(
      tester,
      groupOptions: const [GroupOption(id: 'custom1', label: 'Category')],
      onApplyGroup: (g) {
        applied = g;
        calls++;
      },
    );

    await tester.tap(find.text('Category'));
    await tester.pump();
    expect(calls, 0, reason: 'closing without Done must discard');

    await tester.tap(find.text('Done'));
    await tester.pump();
    expect(calls, 1);
    expect(applied, 'custom1');
  });

  testWidgets('a grouping not on offer displays as No grouping but is NOT '
      'written back', (tester) async {
    var calls = 0;
    await _pump(
      tester,
      // The dimension this id names isn't currently offered (its rows filtered
      // out of the loaded window, or the slot was un-configured), so the radio
      // must not show a dead value...
      groupOptions: const [GroupOption(id: 'custom1', label: 'Category')],
      initialGroup: 'custom3',
      onApplyGroup: (_) => calls++,
    );
    expect(find.text('No grouping'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pump();
    // ...but Done must not persist that normalization. A user who opened the
    // sheet to change the SORT would otherwise silently erase a grouping they
    // never touched.
    expect(calls, 0);
  });

  testWidgets('Done does not re-apply an unchanged grouping', (tester) async {
    var calls = 0;
    await _pump(
      tester,
      groupOptions: const [GroupOption(id: 'custom1', label: 'Category')],
      initialGroup: 'custom1',
      onApplyGroup: (_) => calls++,
    );
    await tester.tap(find.text('Done'));
    await tester.pump();
    expect(calls, 0);
  });

  testWidgets('the selected group is ticked', (tester) async {
    await _pump(
      tester,
      groupOptions: const [GroupOption(id: 'custom1', label: 'Category')],
      initialGroup: 'custom1',
    );
    final selected = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .where((t) => t.selected && t.trailing != null)
        .map((t) => (t.title! as Text).data);
    expect(selected, contains('Category'));
  });
}
