import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/datetime_format.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
import 'package:admin/utils/formatting.dart';

import '../../../_localization_helper.dart';

const _settings = CompanyFormatSettings(
  currencyId: '1',
  countryId: '840',
  dateFormatId: 'X',
  useCommaAsDecimalPlace: false,
  showCurrencyCode: false,
  enableMilitaryTime: false,
  locale: '',
);

final _formatter = Formatter(
  settings: _settings,
  currencies: const {},
  countries: const {},
  dateFormats: const {'X': DatetimeFormat(id: 'X', format: 'd/MMM/yyyy')},
);

/// Every `format_dart` the server seeds (`DateFormatsSeeder.php`), so the
/// placeholder is exercised against the real catalog rather than one sample.
/// Id 1 — the server's *default*, and the one invoiceninja/flutter#127 was
/// filed against — is `dd/MMM/yyyy`.
const _serverDateFormats = <String, String>{
  '1': 'dd/MMM/yyyy',
  '2': 'dd-MMM-yyyy',
  '3': 'dd/MMMM/yyyy',
  '4': 'dd-MMMM-yyyy',
  '5': 'MMM d, yyyy',
  '6': 'MMMM d, yyyy',
  '7': 'EEE MMM d, yyyy',
  '8': 'yyyy-MM-dd',
  '9': 'dd-MM-yyyy',
  '10': 'MM/dd/yyyy',
  '11': 'dd.MM.yyyy',
  '12': 'd. MMM. yyyy',
  '13': 'd. MMMM yyyy',
  '14': 'dd/MM/yyyy',
};

Formatter _formatterFor(String id, String pattern) => Formatter(
  settings: CompanyFormatSettings(
    currencyId: '1',
    countryId: '840',
    dateFormatId: id,
    useCommaAsDecimalPlace: false,
    showCurrencyCode: false,
    enableMilitaryTime: false,
    // Pinned: id 12 (`d. MMM. yyyy`) renders `31. janv.. 2000` in French,
    // which `Formatter.date`'s `'..'` fixup collapses to `31. janv. 2000` —
    // correct to read, but no longer strictly re-parsable by its own pattern.
    locale: '',
  ),
  currencies: const {},
  countries: const {},
  dateFormats: {id: DatetimeFormat(id: id, format: pattern)},
);

Future<void> _pump(
  WidgetTester tester, {
  Formatter? formatter,
  required DateTime? value,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 360,
          child: InDateField(
            value: value,
            formatter: formatter,
            onChanged: (_) {},
            labelText: 'Date',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _value = DateTime(2026, 5, 14);

/// Read the placeholder off the widget rather than with `find.text`:
/// `InputDecoration.maintainHintSize` defaults to true, so the hint `Text` is
/// mounted at opacity 0 even when the field holds a value — a finder would
/// pass whether or not the hint is the string under test.
String? _hintOf(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).decoration!.hintText;

void main() {
  testWidgets('renders the company-formatted date when a Formatter is passed', (
    tester,
  ) async {
    await _pump(tester, formatter: _formatter, value: _value);
    expect(find.text('14/May/2026'), findsOneWidget);
    expect(find.text('2026-05-14'), findsNothing);
  });

  testWidgets('falls back to ISO when no Formatter is passed', (tester) async {
    await _pump(tester, value: _value);
    expect(find.text('2026-05-14'), findsOneWidget);
  });

  group('placeholder', () {
    testWidgets('is a worked example date, never the intl pattern', (
      tester,
    ) async {
      await _pump(tester, formatter: _formatter, value: null);
      expect(_hintOf(tester), '31/Jan/2000');
      // The bug: `MMM` is an abbreviated month NAME, so showing the pattern
      // reads as a typo ("one too many M"). invoiceninja/flutter#127.
      expect(_hintOf(tester), isNot('d/MMM/yyyy'));
    });

    testWidgets('falls back to the ISO sample when no Formatter is passed', (
      tester,
    ) async {
      await _pump(tester, value: null);
      expect(_hintOf(tester), kDateFormatSampleIso);
      expect(_hintOf(tester), isNot('YYYY-MM-DD'));
    });

    testWidgets('is the ISO sample when the format id resolves to nothing', (
      tester,
    ) async {
      // Statics not loaded yet: `dateFormats` is empty. Before the fix this
      // branch yielded a null hint — no placeholder at all.
      final cold = Formatter(
        settings: _settings,
        currencies: const {},
        countries: const {},
        dateFormats: const {},
      );
      await _pump(tester, formatter: cold, value: null);
      expect(_hintOf(tester), kDateFormatSampleIso);
    });

    testWidgets('an explicit hintText still wins', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            body: InDateField(
              value: null,
              formatter: _formatter,
              hintText: 'Anytime',
              onChanged: (_) {},
              labelText: 'Date',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_hintOf(tester), 'Anytime');
    });

    // The invariant, not the string: whatever the placeholder shows must be a
    // date this very field would accept. That fails for a raw pattern AND for
    // a "humanized" one (`dd/mm/yyyy`), which an equality assertion against a
    // hardcoded example would not catch.
    for (final entry in _serverDateFormats.entries) {
      testWidgets('round-trips for server date format ${entry.key} '
          '(${entry.value})', (tester) async {
        await _pump(
          tester,
          formatter: _formatterFor(entry.key, entry.value),
          value: null,
        );
        final hint = _hintOf(tester);
        expect(hint, isNotNull);
        expect(hint, isNot(entry.value), reason: 'rendered the raw pattern');
        expect(
          parseDateInput(hint!, activePattern: entry.value),
          DateTime.parse(kDateFormatSampleIso),
        );
      });
    }
  });
}
