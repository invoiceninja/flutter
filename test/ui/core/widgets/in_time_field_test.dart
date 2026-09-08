import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/ui/core/widgets/in_time_field.dart';
import 'package:admin/utils/formatting.dart';

import '../../../_localization_helper.dart';

Formatter _formatter({required bool military}) => Formatter(
  settings: CompanyFormatSettings(
    currencyId: '1',
    countryId: '840',
    dateFormatId: '5',
    useCommaAsDecimalPlace: false,
    showCurrencyCode: false,
    enableMilitaryTime: military,
    locale: '',
  ),
  currencies: const {},
  countries: const {},
  dateFormats: const {},
);

Future<void> _pump(
  WidgetTester tester, {
  Formatter? formatter,
  TimeOfDay? value,
  String? hintText,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 360,
          child: InTimeField(
            value: value,
            formatter: formatter,
            hintText: hintText,
            onChanged: (_) {},
            labelText: 'Time',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// See the note in `in_date_field_test.dart`: `maintainHintSize` keeps the
/// hint mounted at opacity 0, so `find.text` cannot tell a live placeholder
/// from a hidden one.
String? _hintOf(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).decoration!.hintText;

void main() {
  testWidgets('placeholder is a worked example on military time', (
    tester,
  ) async {
    await _pump(tester, formatter: _formatter(military: true));
    expect(_hintOf(tester), '13:45');
    expect(_hintOf(tester), isNot('HH:MM'));
  });

  testWidgets('placeholder is a worked example on 12-hour time', (
    tester,
  ) async {
    await _pump(tester, formatter: _formatter(military: false));
    expect(_hintOf(tester), '1:45 PM');
    expect(_hintOf(tester), isNot('h:mm AM'));
  });

  testWidgets('the two renderings are distinguishable', (tester) async {
    // The sample hour is past noon on purpose — a morning one would render
    // near-identically under both and teach the user nothing.
    expect(
      timeFormatSample(military: true),
      isNot(timeFormatSample(military: false)),
    );
  });

  testWidgets('an explicit hintText still wins', (tester) async {
    // The `tr('running')` label the task time-log cells pass for a running
    // entry, which must survive the default becoming an example.
    await _pump(
      tester,
      formatter: _formatter(military: true),
      hintText: 'Running',
    );
    expect(_hintOf(tester), 'Running');
  });

  testWidgets('defaults to military when no Formatter is passed', (
    tester,
  ) async {
    await _pump(tester);
    expect(_hintOf(tester), '13:45');
  });

  testWidgets('renders a committed value in the same shape as the hint', (
    tester,
  ) async {
    await _pump(
      tester,
      formatter: _formatter(military: false),
      value: const TimeOfDay(hour: 9, minute: 5),
    );
    expect(find.text('9:05 AM'), findsOneWidget);
  });
}
