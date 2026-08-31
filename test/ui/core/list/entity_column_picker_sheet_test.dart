import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/columns/custom_field_columns.dart';
import 'package:admin/ui/core/list/entity_column_picker_sheet.dart';

import '../../../_localization_helper.dart';

/// The Columns picker is the surface invoiceninja/flutter#106 was filed
/// against ("I cannot select all project fields"), so it gets the first widget
/// test it has ever had.
///
/// A synthetic four-column registry rather than a real entity's: the picker's
/// contract is about labels and id round-tripping, and a 25-column registry
/// would just push the rows under test off the bottom of the sheet.
class _Row {
  const _Row();
}

List<ColumnDefinition<_Row>> _registry(Map<String, String> customFields) =>
    decorateCustomFieldColumns(<ColumnDefinition<_Row>>[
      ColumnDefinition<_Row>(
        id: 'name',
        labelKey: 'name',
        cellBuilder: (_, _) => const Text('name'),
      ),
      ColumnDefinition<_Row>(
        id: 'number',
        labelKey: 'number',
        cellBuilder: (_, _) => const Text('number'),
      ),
      ...customFieldColumns<_Row>(
        prefix: 'project',
        ids: const ['custom1', 'custom2', 'custom3', 'custom4'],
        values: [(_) => '', (_) => '', (_) => '', (_) => ''],
      ),
    ], Company(customFields: customFields));

Future<List<String>?> _pump(
  WidgetTester tester, {
  required List<String> initial,
  Map<String, String> customFields = const {},
}) async {
  List<String>? applied;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: EntityColumnPickerSheet<_Row>(
          initial: initial,
          allColumns: _registry(customFields),
          onApply: (ids) => applied = ids,
          onReset: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return applied;
}

void main() {
  testWidgets("a configured slot is offered under the company's own label", (
    tester,
  ) async {
    await _pump(
      tester,
      initial: const ['name'],
      customFields: const {'project1': 'Region', 'project2': 'Phase|date'},
    );
    expect(find.text('Region'), findsOneWidget);
    expect(find.text('Phase'), findsOneWidget);
    // Never the wire id, nor its generic translation.
    expect(find.text('custom1'), findsNothing);
    expect(find.text('First Custom'), findsNothing);
  });

  testWidgets('an unconfigured slot is not offered at all', (tester) async {
    await _pump(
      tester,
      initial: const ['name'],
      customFields: const {'project1': 'Region'},
    );
    expect(find.text('Region'), findsOneWidget);
    // Slots 2-4 have no label, so there is nothing honest to call them.
    expect(find.text('Second Custom'), findsNothing);
    expect(find.text('custom2'), findsNothing);
  });

  testWidgets('a selected slot shows its company label in Selected too', (
    tester,
  ) async {
    await _pump(
      tester,
      initial: const ['name', 'custom1'],
      customFields: const {'project1': 'Region'},
    );
    // Selected rows carry the drag handle; Available rows don't.
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));
    expect(find.text('Region'), findsOneWidget);
  });

  testWidgets('Done round-trips an id this build cannot render', (
    tester,
  ) async {
    // The regression this guards: hiding an un-configured slot made pressing
    // Done erase the id from `user_settings` for good, so an admin blanking a
    // custom-field label cost every user that column permanently.
    List<String>? applied;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: EntityColumnPickerSheet<_Row>(
            // `custom1` sits between two renderable ids and the company has
            // configured nothing, so the picker can't show it.
            initial: const ['name', 'custom1', 'number'],
            allColumns: _registry(const {}),
            onApply: (ids) => applied = ids,
            onReset: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('custom1'), findsNothing);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(applied, [
      'name',
      'custom1',
      'number',
    ], reason: 'the hidden id comes back at its original index');
  });
}
