import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/dao/project_dao.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/project_api_model.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/datetime_format.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/domain/columns/client_columns.dart';
import 'package:admin/domain/columns/custom_field_columns.dart';
import 'package:admin/domain/columns/project_columns.dart';
import 'package:admin/ui/core/widgets/formatter_scope.dart';
import 'package:admin/utils/formatting.dart';

import '../../_localization_helper.dart';

/// A custom-field cell renders through the slot's *configured type*: a date
/// slot in the company's date format, a switch slot as localized Yes / No,
/// everything else verbatim. Before invoiceninja/flutter#106 every slot
/// rendered the raw stored string, so a date column showed `2026-01-05` and a
/// switch column showed `yes`.
final _formatter = Formatter(
  settings: CompanyFormatSettings.fallback,
  currencies: {
    '1': Currency(
      id: '1',
      name: 'USD',
      code: 'USD',
      symbol: r'$',
      precision: 2,
      thousandSeparator: ',',
      decimalSeparator: '.',
      swapCurrencySymbol: false,
      exchangeRate: Decimal.one,
    ),
  },
  countries: const {},
  dateFormats: const {'5': DatetimeFormat(id: '5', format: 'MMM d, yyyy')},
);

Project _project({String value = ''}) =>
    Project.fromApi(ProjectApi(id: 'p1', name: 'P', customValue1: value));

/// Render slot 1's cell for a company configured with [definition].
Future<String> _cell(
  WidgetTester tester,
  String definition,
  String value, {
  bool withScope = true,
}) async {
  final decorated = decorateCustomFieldColumns(
    kAllProjectColumns,
    Company(customFields: {'project1': definition}),
  );
  final column = decorated.firstWhere((c) => c.id == ProjectFieldIds.custom1);
  return _pumpCell(
    tester,
    (context) => column.cellBuilder(_project(value: value), context),
    withScope: withScope,
  );
}

/// [_cell] for a client's slot 1 — a prefix the server expands reserved date
/// keywords in, where `project` is one it never does.
Future<String> _clientCell(
  WidgetTester tester,
  String definition,
  String value,
) async {
  final decorated = decorateCustomFieldColumns(
    kAllClientColumns,
    Company(customFields: {'client1': definition}),
  );
  final column = decorated.firstWhere((c) => c.id == ClientFieldIds.custom1);
  final client = Client.fromApi(
    ClientApi(id: 'c1', name: 'C', customValue1: value),
  );
  return _pumpCell(tester, (context) => column.cellBuilder(client, context));
}

Future<String> _pumpCell(
  WidgetTester tester,
  Widget Function(BuildContext context) cell, {
  bool withScope = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            final child = Builder(builder: cell);
            return withScope
                ? FormatterScope(formatter: _formatter, child: child)
                : child;
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.widget<Text>(find.byType(Text)).data!;
}

void main() {
  testWidgets('a switch slot renders localized Yes / No', (tester) async {
    expect(await _cell(tester, 'Signed|switch', 'yes'), 'Yes');
    expect(await _cell(tester, 'Signed|switch', 'no'), 'No');
    // `isSwitchTruthy` also accepts the legacy spellings.
    expect(await _cell(tester, 'Signed|switch', 'true'), 'Yes');
    expect(await _cell(tester, 'Signed|switch', '1'), 'Yes');
  });

  testWidgets("a date slot uses the company's date format", (tester) async {
    expect(await _cell(tester, 'Kickoff|date', '2026-01-05'), 'Jan 5, 2026');
  });

  testWidgets('a date slot falls back to the raw ISO with no formatter', (
    tester,
  ) async {
    // The list scaffold only mounts a `FormatterScope` once the formatter
    // future resolves, so this is the one-frame cold-start rendering.
    expect(
      await _cell(tester, 'Kickoff|date', '2026-01-05', withScope: false),
      '2026-01-05',
    );
  });

  testWidgets('an unparseable date renders an em-dash, not a blank cell', (
    tester,
  ) async {
    expect(await _cell(tester, 'Kickoff|date', 'not-a-date'), '—');
  });

  testWidgets('dropdown and text slots render verbatim', (tester) async {
    expect(await _cell(tester, 'Region|North,South', 'North'), 'North');
    expect(
      await _cell(tester, 'Notes|single_line_text', 'anything at all'),
      'anything at all',
    );
    // No pipe at all is the legacy multi-line shape.
    expect(await _cell(tester, 'Region', 'North'), 'North');
  });

  testWidgets('an empty value renders an em-dash whatever the type', (
    tester,
  ) async {
    expect(await _cell(tester, 'Signed|switch', ''), '—');
    expect(await _cell(tester, 'Kickoff|date', ''), '—');
    expect(await _cell(tester, 'Region|North,South', ''), '—');
  });

  testWidgets(
    'a text or dropdown value shows its reserved date keywords as dates where '
    'the server expands them, and stays raw where it does not',
    (tester) async {
      final year = '${DateTime.now().year}';
      expect(
        await _clientCell(tester, 'Term|single_line_text', 'FY :YEAR'),
        'FY $year',
      );
      expect(await _clientCell(tester, 'Term|:YEAR,other', ':YEAR'), year);
      // A switch / date slot is the server's other two branches — never
      // expanded.
      expect(await _clientCell(tester, 'Signed|switch', 'yes'), 'Yes');
      // `project1..4` are never printed through `formatCustomFieldValue`.
      expect(
        await _cell(tester, 'Term|single_line_text', 'FY :YEAR'),
        'FY :YEAR',
      );
    },
  );
}
