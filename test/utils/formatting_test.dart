import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/country.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/datetime_format.dart';
import 'package:admin/utils/formatting.dart';

// Minimal subset of the statics bundle used across the tests. Field values
// mirror what `/api/v1/statics` returns from a production Invoice Ninja
// install for these specific IDs.
Currency _currency({
  String id = '1',
  String code = 'USD',
  String symbol = r'$',
  int precision = 2,
  String thousand = ',',
  String decimal = '.',
  bool swap = false,
}) => Currency(
  id: id,
  name: code,
  code: code,
  symbol: symbol,
  precision: precision,
  thousandSeparator: thousand,
  decimalSeparator: decimal,
  swapCurrencySymbol: swap,
  exchangeRate: Decimal.one,
);

Country _country({
  String id = '840',
  String name = 'United States',
  String iso2 = 'US',
  bool swap = false,
  String thousand = '',
  String decimal = '',
}) => Country(
  id: id,
  name: name,
  iso2: iso2,
  iso3: 'USA',
  swapCurrencySymbol: swap,
  thousandSeparator: thousand,
  decimalSeparator: decimal,
  swapPostalCode: false,
);

Formatter _make({
  CompanyFormatSettings? settings,
  Map<String, Currency>? currencies,
  Map<String, Country>? countries,
  Map<String, DatetimeFormat>? dateFormats,
}) => Formatter(
  settings: settings ?? CompanyFormatSettings.fallback,
  currencies:
      currencies ??
      {'1': _currency(), '3': _currency(id: '3', code: 'EUR', symbol: '€')},
  countries:
      countries ??
      {
        '840': _country(),
        '276': _country(
          id: '276',
          name: 'Germany',
          iso2: 'DE',
          swap: true,
          thousand: '.',
          decimal: ',',
        ),
      },
  dateFormats:
      dateFormats ??
      {
        '5': const DatetimeFormat(id: '5', format: 'MMM d, yyyy'),
        '1': const DatetimeFormat(id: '1', format: 'd/MMM/yyyy'),
      },
);

void main() {
  group('round() — admin-portal formatting.dart:22-38', () {
    test('rounds to precision', () {
      expect(round(1.234, 2), 1.23);
      expect(round(1.235, 2), 1.24);
    });

    test('floating-point workaround for the .999999 accumulation case', () {
      // 35 * 1.107 = 38.74500000000001 — the old code's exact bug repro.
      expect(round(35 * 1.107, 2), 38.75);
    });

    test('null and NaN coerce to 0', () {
      expect(round(null, 2), 0);
      expect(round(double.nan, 2), 0);
    });

    test('negative values round half away from zero (Dart `.round()`)', () {
      // Dart's `.round()` rounds halves away from zero, so -123.5 → -124.
      // Pick an unambiguous non-half input to assert the precision contract.
      expect(round(-1.234, 2), -1.23);
    });
  });

  group('parseInt', () {
    test('strips non-digits before parsing', () {
      expect(parseInt(r'$1,234'), 1234);
      expect(parseInt('  42 '), 42);
    });

    test('returns 0 for empty / null / non-numeric', () {
      expect(parseInt(''), 0);
      expect(parseInt(null), 0);
      expect(parseInt('abc'), 0);
    });

    test('zeroIsNull returns null for zero input', () {
      expect(parseInt('0', zeroIsNull: true), isNull);
      expect(parseInt('', zeroIsNull: true), isNull);
    });
  });

  group('parseDecimal', () {
    test('parses a plain number', () {
      expect(parseDecimal('1234.56'), Decimal.parse('1234.56'));
    });

    test('strips currency symbols and grouping commas', () {
      expect(parseDecimal(r'$1,234.56'), Decimal.parse('1234.56'));
    });

    test('useCommaAsDecimalPlace flips separator semantics', () {
      // "1.234,56" → 1234.56 when commas are decimals.
      expect(
        parseDecimal('1.234,56', useCommaAsDecimalPlace: true),
        Decimal.parse('1234.56'),
      );
    });

    test('zeroIsNull behaviour', () {
      expect(parseDecimal('0', zeroIsNull: true), isNull);
      expect(parseDecimal('', zeroIsNull: true), isNull);
    });

    test('negative values', () {
      expect(parseDecimal('-12.5'), Decimal.parse('-12.5'));
    });
  });

  group('parseDouble — tax-rate input (comma-locale safe)', () {
    test('parses a plain dot decimal', () {
      expect(parseDouble('19.5'), 19.5);
    });

    test('comma decimal parses correctly when the company uses commas', () {
      // The bug this guards: a German user typing "19,5" must yield 19.5,
      // not 195. See Settings → Tax Settings (CRUD + subregion dialog).
      expect(parseDouble('19,5', useCommaAsDecimalPlace: true), 19.5);
      expect(parseDouble('1.234,56', useCommaAsDecimalPlace: true), 1234.56);
    });

    test('empty / unparseable input is zero (or null with zeroIsNull)', () {
      expect(parseDouble(''), 0.0);
      expect(parseDouble(null, zeroIsNull: true), isNull);
      expect(parseDouble('0', zeroIsNull: true), isNull);
    });
  });

  group('rateInputText — tax-rate display', () {
    test('drops trailing .0 (19.0 → "19")', () {
      expect(rateInputText(19), '19');
      expect(rateInputText(19.5), '19.5');
    });

    test('uses the comma separator when the company does', () {
      expect(rateInputText(19.5, useCommaAsDecimalPlace: true), '19,5');
    });

    test('blankZero: empty for zero when seeding a field, "0" for display', () {
      expect(rateInputText(0), '');
      expect(rateInputText(0, blankZero: false), '0');
    });
  });

  group('Formatter.money — USD defaults', () {
    final f = _make();

    test('formats with `\$` prefix and 2 decimals', () {
      expect(
        f.money(Decimal.parse('1234.56'), clientCurrencyId: '1'),
        r'$1,234.56',
      );
    });

    test('zero renders as `\$0.00`', () {
      expect(f.money(Decimal.zero, clientCurrencyId: '1'), r'$0.00');
    });

    test('zeroIsNull returns empty string for zero', () {
      expect(
        f.money(Decimal.zero, clientCurrencyId: '1', zeroIsNull: true),
        '',
      );
    });

    test('null amount returns empty string', () {
      expect(f.money(null), '');
    });

    test('negative values get a single sign in front of the symbol prefix', () {
      expect(
        f.money(Decimal.parse('-1234.56'), clientCurrencyId: '1'),
        r'-$1,234.56',
      );
    });

    test('rounding 38.745 yields 38.75 (admin-portal bug parity)', () {
      expect(
        f.money(Decimal.parse('38.745'), clientCurrencyId: '1'),
        r'$38.75',
      );
    });

    test('negative-zero workaround: `-0.001` rounds to `\$0.00`', () {
      // admin-portal formatting.dart:237-241.
      expect(f.money(Decimal.parse('-0.001'), clientCurrencyId: '1'), r'$0.00');
    });

    test('explicit currencyId overrides client currency', () {
      expect(
        f.money(Decimal.parse('10'), currencyId: '3', clientCurrencyId: '1'),
        '€10.00',
      );
    });

    test('showCurrencyCode swaps symbol for code', () {
      expect(
        f.money(
          Decimal.parse('10'),
          clientCurrencyId: '1',
          showCurrencyCode: true,
        ),
        '10.00 USD',
      );
    });
  });

  group(
    'Formatter.money — Euro country override (formatting.dart:160-169)',
    () {
      test('EUR in Germany uses German separators and suffix-symbol', () {
        final f = _make(
          settings: CompanyFormatSettings.fallback.copyWith(countryId: '276'),
          currencies: {
            // EUR with US-style separators baked in — country must override.
            '3': _currency(
              id: '3',
              code: 'EUR',
              symbol: '€',
              thousand: ',',
              decimal: '.',
              swap: false,
            ),
          },
        );
        expect(
          f.money(Decimal.parse('1234.56'), currencyId: '3'),
          '1.234,56 €',
        );
      });
    },
  );

  group('Formatter.percent / integer / decimal', () {
    final f = _make();

    test('percent renders trailing %', () {
      expect(f.percent(15.5), '15.5%');
    });

    test('integer groups thousands, no decimals', () {
      expect(f.integer(1234567), '1,234,567');
    });

    test('decimal preserves up to 5 fractional digits', () {
      expect(f.decimal(1234.5), '1,234.5');
      expect(f.decimal(1234.12345), '1,234.12345');
    });

    test('decimal honors fixed min/max precision — money-style symbol-less '
        'rendering (product detail): 10.00 must not collapse to "10"', () {
      expect(f.decimal(10, minDecimals: 2, maxDecimals: 2), '10.00');
      expect(f.decimal(10.5, minDecimals: 2, maxDecimals: 2), '10.50');
      expect(f.decimal(1234.567, minDecimals: 2, maxDecimals: 2), '1,234.57');
    });

    test('negative-zero suppressed for percent', () {
      // -0.000001 rounds to '0.00000' at maxDecimals=5; the negative sign
      // is then suppressed because the rendered body is all zeros.
      expect(f.percent(-0.000001), '0%');
    });
  });

  group('Formatter.inputMoney / inputAmount', () {
    test('no thousand separator, period decimal by default', () {
      final f = _make();
      expect(f.inputMoney(Decimal.parse('1234.5'), currencyId: '1'), '1234.50');
    });

    test('use_comma_as_decimal_place flips to comma', () {
      final f = _make(
        settings: CompanyFormatSettings.fallback.copyWith(
          useCommaAsDecimalPlace: true,
        ),
      );
      expect(f.inputMoney(Decimal.parse('1234.5'), currencyId: '1'), '1234,50');
    });

    test('inputAmount has no fixed precision', () {
      final f = _make();
      expect(f.inputAmount(1234.5), '1234.5');
      expect(f.inputAmount(0), '');
    });
  });

  group('Formatter.date', () {
    test('formats an ISO date with the company date pattern', () {
      final f = _make();
      expect(f.date('2024-05-11'), 'May 11, 2024');
    });

    test('returns empty for null/empty', () {
      final f = _make();
      expect(f.date(null), '');
      expect(f.date(''), '');
    });

    test('time-only suppresses date', () {
      final f = _make();
      final result = f.date(
        '2024-05-11T15:42:00Z',
        showDate: false,
        showTime: true,
        showSeconds: false,
      );
      expect(result, isNotEmpty);
      // Default settings use 12-hour clock.
      expect(result.contains(':'), isTrue);
    });
  });

  group(
    'Formatter date helpers — regression coverage for the locale guards',
    () {
      // These exist to catch a class of bug where `DateFormat(pattern, '')`
      // throws `LocaleDataException`. All three previously read
      // `settings.locale` directly; only `date` had the `isEmpty ? null : ...`
      // guard. Tests run with the fallback (empty) locale.

      test('dateRange formats both ends, year suppressed for current year', () {
        final f = _make();
        final year = DateTime.now().year;
        final result = f.dateRange('$year-05-11', '$year-05-15');
        expect(result, contains('May 11'));
        expect(result, contains('May 15'));
        expect(result, isNot(contains('$year'))); // year suppressed
      });

      test('dateRange returns empty for bad input', () {
        final f = _make();
        expect(f.dateRange('not-a-date', '2024-05-15'), '');
      });

      test('parseDate round-trips through the company date pattern', () {
        final f = _make(); // format='MMM d, yyyy'
        expect(f.parseDate('May 11, 2024'), '2024-05-11');
        expect(f.parseDate(''), '');
        expect(f.parseDate('garbage'), '');
      });

      test('parseTime returns a DateTime for a 12-hour clock string', () {
        final f = _make(); // enableMilitaryTime: false
        final dt = f.parseTime('3:42 PM');
        expect(dt, isNotNull);
        expect(dt!.hour, 15);
        expect(dt.minute, 42);
      });

      test('parseTime returns null for empty / unparseable input', () {
        final f = _make();
        expect(f.parseTime(''), isNull);
        expect(f.parseTime('not a time'), isNull);
      });
    },
  );

  group('Formatter.customValue', () {
    final f = _make();

    test('switch maps yes/no to localised strings', () {
      expect(
        f.customValue(value: 'yes', fieldType: 'switch', yes: 'Yes', no: 'No'),
        'Yes',
      );
      expect(
        f.customValue(value: 'no', fieldType: 'switch', yes: 'Yes', no: 'No'),
        'No',
      );
    });

    test('date routes through Formatter.date', () {
      expect(
        f.customValue(
          value: '2024-05-11',
          fieldType: 'date',
          yes: 'Y',
          no: 'N',
        ),
        'May 11, 2024',
      );
    });

    test('unknown field type returns the raw value', () {
      expect(
        f.customValue(value: 'arbitrary', fieldType: 'text', yes: 'Y', no: 'N'),
        'arbitrary',
      );
    });
  });

  group('swap_currency_symbol — sourced from companyCurrency', () {
    // admin-portal/lib/utils/formatting.dart:158 reads the swap flag from
    // the company's default currency, not the display currency. A US-based
    // company displaying a foreign-currency balance inherits the company's
    // symbol-placement convention.

    test('display currency without swap inherits company swap=true', () {
      final f = _make(
        settings: CompanyFormatSettings.fallback.copyWith(currencyId: '1'),
        currencies: {
          // Company currency (USD) with swap=true.
          '1': _currency(swap: true),
          // Foreign currency (GBP, not EUR-id-3, so the country-override
          // branch doesn't fire) with swap=false.
          '2': _currency(id: '2', code: 'GBP', symbol: '£', swap: false),
        },
      );
      // Without the fix, GBP would render as '£100.00' (prefix). With the
      // fix it renders as '100.00 £' (swap inherited from company USD).
      expect(f.money(Decimal.parse('100'), currencyId: '2'), '100.00 £');
    });
  });

  group('convertSqlDateToDateTime / convertDateTimeToSqlDate', () {
    test('round-trip preserves the calendar date', () {
      final dt = DateTime.utc(2024, 5, 11);
      expect(convertSqlDateToDateTime(convertDateTimeToSqlDate(dt)), dt);
    });

    test('tolerates non-digit suffix in the day component', () {
      // admin-portal parity: parseInt strips non-digits, so a trailing
      // `T15:42:00Z` doesn't throw. The day field still over-counts (Dart
      // DateTime normalises out-of-range days), so the result is some date
      // — we only assert that no exception escapes.
      expect(
        () => convertSqlDateToDateTime('2024-05-11T15:42:00Z'),
        returnsNormally,
      );
    });
  });

  group('Formatter.address', () {
    final f = _make();

    test('omits country when it matches company default', () {
      final out = f.address(
        const Address(
          address1: '1 Market St',
          city: 'SF',
          state: 'CA',
          postalCode: '94105',
          countryId: '840', // matches fallback companyCountry
        ),
      );
      expect(out, contains('1 Market St'));
      expect(out, isNot(contains('United States')));
    });

    test('includes country when different from company default', () {
      final out = f.address(
        const Address(
          address1: '10 Downing St',
          city: 'London',
          countryId: '276',
        ),
      );
      expect(out, contains('Germany'));
    });

    test('empty address renders empty', () {
      expect(f.address(const Address()), '');
    });
  });

  group('formatDuration', () {
    test('shows H:MM:SS by default', () {
      expect(
        formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });

    test('strips seconds when asked', () {
      expect(
        formatDuration(
          const Duration(hours: 1, minutes: 2, seconds: 3),
          showSeconds: false,
        ),
        '1:02',
      );
    });
  });

  group('parseDurationInput', () {
    test('bare number is hours — integer', () {
      expect(parseDurationInput('1'), const Duration(hours: 1));
      expect(parseDurationInput('2'), const Duration(hours: 2));
      expect(parseDurationInput('8'), const Duration(hours: 8));
    });

    test('bare number is hours — decimal', () {
      expect(parseDurationInput('1.5'), const Duration(minutes: 90));
      expect(parseDurationInput('0.5'), const Duration(minutes: 30));
      expect(parseDurationInput('0.25'), const Duration(minutes: 15));
    });

    test('comma decimal separator', () {
      expect(parseDurationInput('1,5'), const Duration(minutes: 90));
    });

    test('unit-suffix form unchanged', () {
      expect(parseDurationInput('1h 30m'), const Duration(minutes: 90));
      expect(parseDurationInput('90m'), const Duration(minutes: 90));
      expect(parseDurationInput('45s'), const Duration(seconds: 45));
      expect(parseDurationInput('2d'), const Duration(days: 2));
    });

    test('colon form unchanged', () {
      expect(parseDurationInput('1:30'), const Duration(minutes: 90));
      expect(parseDurationInput('1:30:00'), const Duration(minutes: 90));
      expect(parseDurationInput('0:30'), const Duration(minutes: 30));
      expect(parseDurationInput('0:01:30'), const Duration(seconds: 90));
    });

    test('empty / unparseable input returns null', () {
      expect(parseDurationInput(''), isNull);
      expect(parseDurationInput('   '), isNull);
      expect(parseDurationInput('abc'), isNull);
    });
  });

  group('parseDateInput', () {
    test('ISO date wins (locale-independent)', () {
      expect(parseDateInput('2026-05-14'), DateTime(2026, 5, 14));
    });

    test('strict ISO rejects out-of-range months/days', () {
      expect(parseDateInput('2026-13-40'), isNull);
    });

    test('active pattern parses ambiguous M/d/yyyy', () {
      // US default: 7/24/2026 = July 24.
      expect(
        parseDateInput('7/24/2026', activePattern: 'M/d/yyyy'),
        DateTime(2026, 7, 24),
      );
    });

    test('active pattern parses ambiguous d/M/yyyy', () {
      // UK default: 24/7/2026 = July 24.
      expect(
        parseDateInput('24/7/2026', activePattern: 'd/M/yyyy'),
        DateTime(2026, 7, 24),
      );
    });

    test('falls back to MMM d, yyyy long form', () {
      expect(parseDateInput('Jul 24, 2026'), DateTime(2026, 7, 24));
    });

    test('empty and unparseable input return null', () {
      expect(parseDateInput(''), isNull);
      expect(parseDateInput('   '), isNull);
      expect(parseDateInput('not a date'), isNull);
      expect(parseDateInput('???'), isNull);
    });

    test('strips leading/trailing whitespace', () {
      expect(parseDateInput('  2026-05-14  '), DateTime(2026, 5, 14));
    });

    group('shortcuts (admin-portal parity)', () {
      // Pin `now` so the relative shortcuts are deterministic.
      final now = DateTime(2026, 5, 14);

      test('today / tomorrow / yesterday / now', () {
        expect(parseDateInput('today', now: now), DateTime(2026, 5, 14));
        expect(parseDateInput('TODAY', now: now), DateTime(2026, 5, 14));
        expect(parseDateInput('tomorrow', now: now), DateTime(2026, 5, 15));
        expect(parseDateInput('yesterday', now: now), DateTime(2026, 5, 13));
        expect(parseDateInput('now', now: now), DateTime(2026, 5, 14));
      });

      test('signed integer offset', () {
        expect(parseDateInput('+1', now: now), DateTime(2026, 5, 15));
        expect(parseDateInput('-7', now: now), DateTime(2026, 5, 7));
        expect(parseDateInput('+0', now: now), DateTime(2026, 5, 14));
        expect(parseDateInput('+9999', now: now), isNotNull);
        // Over the cap or non-numeric → null.
        expect(parseDateInput('+99999', now: now), isNull);
        expect(parseDateInput('+abc', now: now), isNull);
      });

      test('bare day-only digit string', () {
        // 1-2 digits = day of current month.
        expect(parseDateInput('14', now: now), DateTime(2026, 5, 14));
        expect(parseDateInput('1', now: now), DateTime(2026, 5, 1));
        expect(parseDateInput('31', now: now), DateTime(2026, 5, 31));
        // Out-of-range → null.
        expect(parseDateInput('32', now: now), isNull);
        expect(parseDateInput('0', now: now), isNull);
      });

      test('short slash form respects activePattern', () {
        // US default — month first.
        expect(
          parseDateInput('5/14', activePattern: 'M/d/yyyy', now: now),
          DateTime(2026, 5, 14),
        );
        // EU default — day first.
        expect(
          parseDateInput('14/5', activePattern: 'd/M/yyyy', now: now),
          DateTime(2026, 5, 14),
        );
      });

      test('compact 6-digit MMDDYY with 2-digit year heuristic', () {
        // < 30 → 2000+yy.
        expect(
          parseDateInput('051426', activePattern: 'M/d/yyyy', now: now),
          DateTime(2026, 5, 14),
        );
        // >= 30 → 1900+yy.
        expect(
          parseDateInput('051485', activePattern: 'M/d/yyyy', now: now),
          DateTime(1985, 5, 14),
        );
        // EU order.
        expect(
          parseDateInput('140526', activePattern: 'd/M/yyyy', now: now),
          DateTime(2026, 5, 14),
        );
      });

      test('compact 8-digit MMDDYYYY', () {
        expect(
          parseDateInput('05142026', activePattern: 'M/d/yyyy', now: now),
          DateTime(2026, 5, 14),
        );
      });

      test('invalid compact strings return null', () {
        // Month 99 / day 99.
        expect(
          parseDateInput('999926', activePattern: 'M/d/yyyy', now: now),
          isNull,
        );
      });
    });
  });

  group('parseTimeInput', () {
    test('24-hour with leading zero', () {
      expect(parseTimeInput('09:00'), const TimeOfDay(hour: 9, minute: 0));
      expect(parseTimeInput('14:30'), const TimeOfDay(hour: 14, minute: 30));
    });

    test('24-hour without leading zero', () {
      expect(parseTimeInput('9:00'), const TimeOfDay(hour: 9, minute: 0));
    });

    test('12-hour with AM/PM', () {
      expect(parseTimeInput('9:00 AM'), const TimeOfDay(hour: 9, minute: 0));
      expect(parseTimeInput('9:00 PM'), const TimeOfDay(hour: 21, minute: 0));
    });

    test('12-hour with lowercase am/pm', () {
      expect(parseTimeInput('9:00 am'), const TimeOfDay(hour: 9, minute: 0));
      expect(parseTimeInput('9:00 pm'), const TimeOfDay(hour: 21, minute: 0));
    });

    test('12-hour with no space before AM/PM', () {
      expect(parseTimeInput('9:00AM'), const TimeOfDay(hour: 9, minute: 0));
    });

    test('out-of-range and unparseable input return null', () {
      expect(parseTimeInput('25:00'), isNull);
      expect(parseTimeInput('9:99'), isNull);
      expect(parseTimeInput(''), isNull);
      expect(parseTimeInput('   '), isNull);
      expect(parseTimeInput('noon'), isNull);
    });

    group('shortcuts (admin-portal parity)', () {
      test('bare 1-2 digit hour', () {
        expect(parseTimeInput('9'), const TimeOfDay(hour: 9, minute: 0));
        expect(parseTimeInput('12'), const TimeOfDay(hour: 12, minute: 0));
        expect(parseTimeInput('0'), const TimeOfDay(hour: 0, minute: 0));
        expect(parseTimeInput('23'), const TimeOfDay(hour: 23, minute: 0));
      });

      test('3-digit compact', () {
        expect(parseTimeInput('930'), const TimeOfDay(hour: 9, minute: 30));
        expect(parseTimeInput('945'), const TimeOfDay(hour: 9, minute: 45));
      });

      test('4-digit compact', () {
        expect(parseTimeInput('0930'), const TimeOfDay(hour: 9, minute: 30));
        expect(parseTimeInput('1430'), const TimeOfDay(hour: 14, minute: 30));
      });

      test('AM/PM suffix shortcuts', () {
        expect(parseTimeInput('9p'), const TimeOfDay(hour: 21, minute: 0));
        expect(parseTimeInput('9pm'), const TimeOfDay(hour: 21, minute: 0));
        expect(parseTimeInput('9P'), const TimeOfDay(hour: 21, minute: 0));
        expect(parseTimeInput('9a'), const TimeOfDay(hour: 9, minute: 0));
        expect(parseTimeInput('9am'), const TimeOfDay(hour: 9, minute: 0));
        // `9 a.m.` — dots / spaces stripped.
        expect(parseTimeInput('9 a.m.'), const TimeOfDay(hour: 9, minute: 0));
        // 12 AM → midnight.
        expect(parseTimeInput('12a'), const TimeOfDay(hour: 0, minute: 0));
        // 12 PM → noon (12 stays 12, doesn't add 12).
        expect(parseTimeInput('12p'), const TimeOfDay(hour: 12, minute: 0));
      });

      test('compact digits with AM/PM', () {
        expect(parseTimeInput('930a'), const TimeOfDay(hour: 9, minute: 30));
        expect(parseTimeInput('930p'), const TimeOfDay(hour: 21, minute: 30));
      });

      test('invalid compact strings return null', () {
        // 5 digits doesn't map to anything sensible.
        expect(parseTimeInput('12345'), isNull);
        // Garbage characters after stripping.
        expect(parseTimeInput('foo'), isNull);
      });
    });
  });

  group('formatSize / cleanPhoneNumber', () {
    test('formatSize KB vs MB boundary', () {
      // KB path rounds to int; MB path keeps one decimal then int-truncates.
      expect(formatSize(500), '1 KB');
      expect(formatSize(3_400_000), '3 MB');
    });

    test('cleanPhoneNumber keeps the leading + and drops punctuation', () {
      // The `+` is the whole difference between an international dial and a
      // wrong national one, so it survives where every other symbol doesn't.
      expect(cleanPhoneNumber('+1 (415) 555-2671'), '+14155552671');
      expect(cleanPhoneNumber('(415) 555-2671'), '4155552671');
      expect(cleanPhoneNumber('  +44 20 7946 0018  '), '+442079460018');
      expect(cleanPhoneNumber('415.555.2671'), '4155552671');
    });

    test('cleanPhoneNumber finds a + that is not the first character', () {
      // Both are ordinary stored formats. Testing `startsWith('+')` drops the
      // marker from each and dials an international number nationally.
      expect(cleanPhoneNumber('(+1) 415-555-2671'), '+14155552671');
      expect(cleanPhoneNumber('Mobile: +44 20 7946 0018'), '+442079460018');
      expect(cleanPhoneNumber('  +1-415-555-2671'), '+14155552671');
      // A `+` *after* the digits start is punctuation, not a country marker.
      expect(cleanPhoneNumber('415 555 2671+'), '4155552671');
    });

    test(
      'cleanPhoneNumber rejects free text that leaves a few stray digits',
      () {
        // These used to render as inert text; a link that hands the dialer
        // `tel:1800` is worse than no link at all.
        expect(cleanPhoneNumber('1-800-FLOWERS'), '');
        expect(cleanPhoneNumber('Reception, dial 9 first'), '');
        expect(cleanPhoneNumber('ext 4521'), '');
        // …but a real number keeps working.
        expect(cleanPhoneNumber('555-1234'), '5551234');
      },
    );

    test('cleanPhoneNumber cuts an extension instead of inlining it', () {
      // Inlining would dial 555123422 — a different number entirely.
      expect(cleanPhoneNumber('555-1234 x22'), '5551234');
      expect(cleanPhoneNumber('555-1234 ext 22'), '5551234');
      expect(cleanPhoneNumber('555-1234 ext. 22'), '5551234');
      expect(cleanPhoneNumber('+1 415 555 2671 X9'), '+14155552671');
      expect(cleanPhoneNumber('555-1234#22'), '5551234');
      // A trailing `#` with no digits after it is not an extension marker, so
      // it isn't a cut point — but `*123#` is a 3-digit USSD code, which the
      // minimum-digit floor discards anyway (Android blocks USSD from an
      // ACTION_VIEW `tel:` regardless).
      expect(cleanPhoneNumber('*123#'), '');
    });

    test('cleanPhoneNumber drops a bracketed trunk prefix after a +cc', () {
      // `+44 (0)20 …` means "020… domestically"; keeping the 0 yields
      // +44020…, which is not a dialable number.
      expect(cleanPhoneNumber('+44 (0)20 7946 0018'), '+442079460018');
      expect(cleanPhoneNumber('+44(0)2079460018'), '+442079460018');
      // Only after a country code — a bare (0) elsewhere is just punctuation
      // and its digit is part of the number.
      expect(cleanPhoneNumber('(0)20 7946 0018'), '02079460018');
    });

    test('cleanPhoneNumber returns empty when there is nothing to dial', () {
      // Callers use the empty string to render plain text rather than offer a
      // link that can only fail.
      expect(cleanPhoneNumber(''), '');
      expect(cleanPhoneNumber('   '), '');
      expect(cleanPhoneNumber('call the office'), '');
      expect(cleanPhoneNumber('+'), '');
      expect(cleanPhoneNumber('9'), '');
    });

    test('formatApiUrl / cleanApiUrl strip trailing /api/v1 + slash', () {
      expect(
        formatApiUrl('https://example.com/'),
        'https://example.com/api/v1',
      );
      expect(
        formatApiUrl('https://example.com/api/v1'),
        'https://example.com/api/v1',
      );
      expect(
        cleanApiUrl(' https://example.com/api/v1/ '),
        'https://example.com',
      );
    });
  });

  group('formatTimeOfDay', () {
    test('24-hour (military) pads the hour', () {
      expect(formatTimeOfDay(9, 5, military: true), '09:05');
      expect(formatTimeOfDay(0, 0, military: true), '00:00');
      expect(formatTimeOfDay(23, 30, military: true), '23:30');
    });

    test('12-hour adds AM/PM and a 1..12 hour', () {
      expect(formatTimeOfDay(9, 5, military: false), '9:05 AM');
      expect(formatTimeOfDay(0, 0, military: false), '12:00 AM');
      expect(formatTimeOfDay(12, 0, military: false), '12:00 PM');
      expect(formatTimeOfDay(13, 30, military: false), '1:30 PM');
      expect(formatTimeOfDay(23, 59, military: false), '11:59 PM');
    });
  });
}
