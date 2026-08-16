// The one rule every RENDERED calendar shares. It exists because the three
// calendars in the app (dashboard date-range, Tasks → Calendar, Tasks → Weekly)
// drifted apart once already: `CompanyFormatSettings.firstDayOfWeek` used to be
// a non-nullable int defaulting to 0, so "never configured" and "explicitly
// Sunday" were the same value and every locale-aware fallback was dead code.

import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/ui/core/utils/calendar_week_start.dart';
import 'package:admin/utils/formatting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Formatter _formatter({int? firstDayOfWeek}) => Formatter(
  settings: CompanyFormatSettings(
    currencyId: '1',
    countryId: '840',
    dateFormatId: '5',
    useCommaAsDecimalPlace: false,
    showCurrencyCode: false,
    enableMilitaryTime: false,
    locale: '',
    firstDayOfWeek: firstDayOfWeek,
  ),
  currencies: const {},
  countries: const {},
  dateFormats: const {},
);

void main() {
  /// Resolves the helper under a real `MaterialLocalizations` for [locale].
  Future<int> resolve(
    WidgetTester tester,
    Locale locale,
    Formatter? formatter,
  ) async {
    late int result;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('de')],
        home: Builder(
          builder: (context) {
            result = calendarFirstDayOfWeek(context, formatter);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('an unconfigured company follows the device locale', (
    tester,
  ) async {
    expect(await resolve(tester, const Locale('en'), _formatter()), 0);
    expect(await resolve(tester, const Locale('de'), _formatter()), 1);
  });

  testWidgets('no formatter at all still follows the locale', (tester) async {
    expect(await resolve(tester, const Locale('de'), null), 1);
  });

  testWidgets('a configured company wins over the locale', (tester) async {
    final wednesday = _formatter(firstDayOfWeek: 3);
    expect(await resolve(tester, const Locale('en'), wednesday), 3);
    expect(await resolve(tester, const Locale('de'), wednesday), 3);
  });

  // Sunday is a real, selectable value — it must NOT be re-read as "unset" and
  // replaced by the locale's Monday.
  testWidgets('an explicit Sunday is honoured, not treated as unset', (
    tester,
  ) async {
    expect(
      await resolve(tester, const Locale('de'), _formatter(firstDayOfWeek: 0)),
      0,
    );
  });

  // Same reason `startOfWeek` normalizes: a garbage value must fall back rather
  // than silently rotate the grid (Dart's `%` would happily accept it).
  testWidgets('an out-of-range value falls back instead of rotating', (
    tester,
  ) async {
    expect(
      await resolve(tester, const Locale('de'), _formatter(firstDayOfWeek: 9)),
      0,
    );
    expect(
      await resolve(tester, const Locale('de'), _formatter(firstDayOfWeek: -1)),
      0,
    );
  });
}
