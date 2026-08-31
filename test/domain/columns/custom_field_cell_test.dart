import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/dao/project_dao.dart';
import 'package:admin/data/models/api/project_api_model.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/datetime_format.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/project.dart';
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
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            final child = Builder(
              builder: (context) =>
                  column.cellBuilder(_project(value: value), context),
            );
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
}
