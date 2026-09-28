import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/domain/date_placeholders.dart';
import 'package:admin/data/models/value/datetime_format.dart';
import 'package:admin/utils/formatting.dart';

/// `[MONTHYEAR|MONTHYEAR+12]` on a product description is what the reporter
/// saw in a list — the server expands it when the invoice renders, so until
/// then it reads as noise (invoiceninja/flutter#93).
void main() {
  // The app gets its intl date symbols from `GlobalMaterialLocalizations` at
  // boot; a plain Dart test has no such boot, so load them here.
  setUpAll(initializeDateFormatting);

  // Mid-month, mid-day: nothing here depends on a calendar boundary, but a
  // fixture on the 1st invites a future change to accidentally depend on one.
  final at = DateTime(2026, 8, 15, 12);

  Formatter formatter({String locale = 'en', String dateFormatId = '5'}) =>
      Formatter(
        settings: CompanyFormatSettings(
          currencyId: '1',
          countryId: '840',
          dateFormatId: dateFormatId,
          useCommaAsDecimalPlace: false,
          showCurrencyCode: false,
          enableMilitaryTime: false,
          locale: locale,
        ),
        currencies: const {},
        countries: const {},
        dateFormats: const {
          '5': DatetimeFormat(id: '5', format: 'MMM d, yyyy'),
          '1': DatetimeFormat(id: '1', format: 'd/MMM/yyyy'),
        },
      );

  String expand(String text, {DateTime? now, Formatter? fmt}) =>
      expandDatePlaceholders(
        text,
        formatter: fmt ?? formatter(),
        now: now ?? at,
      );

  group('ranges', () {
    test('expands the reported token', () {
      expect(
        expand('Hosting [MONTHYEAR|MONTHYEAR+12]'),
        'Hosting August 2026 - August 2027',
      );
    });

    test('no arithmetic → the same month on both sides', () {
      expect(expand('[MONTHYEAR|MONTHYEAR]'), 'August 2026 - August 2026');
    });

    test('an offset crossing a year boundary rolls the year', () {
      expect(
        expand('[MONTHYEAR|MONTHYEAR+5]', now: DateTime(2026, 11, 3)),
        'November 2026 - April 2027',
      );
    });

    test('several ranges in one description each expand', () {
      expect(
        expand('[MONTHYEAR|MONTHYEAR+1] and [MONTHYEAR|MONTHYEAR+2]'),
        'August 2026 - September 2026 and August 2026 - October 2026',
      );
    });

    test('day-1 math, so month-end cannot overflow a month', () {
      // Upstream anchors to `startOfMonth()` since fd8cd8ad6c (it used to keep
      // *today's* day, so Jan 31 + 1 month overflowed to March) — pinned by
      // its testMonthYearRangeDoesNotOverflowAtTheEndOfAMonth.
      expect(
        expand('[MONTHYEAR|MONTHYEAR+1]', now: DateTime(2026, 1, 31)),
        'January 2026 - February 2026',
      );
    });

    test('the separator matches the server, an untranslated "-"', () {
      // `Helpers.php` `$rangeSeparator = '-'` since fd8cd8ad6c — used by the
      // ranges and the literal windows alike, never `ctrans('texts.to')`.
      expect(expand('[MONTHYEAR|MONTHYEAR+1]'), contains(' - '));
      expect(expand(':WEEK'), contains(' - '));
    });

    test('a subtracted offset — upstream\'s own expectation', () {
      // tests/Unit/HelpersTest.php testMonthYearRangeSupportsSubtractingMonths.
      expect(expand('[MONTHYEAR|MONTHYEAR-2]'), 'August 2026 - June 2026');
      expect(
        expand('[MONTHYEAR|MONTHYEAR-3]', now: DateTime(2026, 2, 10)),
        'February 2026 - November 2025',
      );
    });
  });

  group('bare literals', () {
    test(':MONTHYEAR wins over :MONTH — it is the longer key', () {
      // Replacing `:MONTH` first would leave a dangling "YEAR".
      expect(expand('Retainer :MONTHYEAR'), 'Retainer August 2026');
    });

    test(':MONTH / :YEAR / :QUARTER', () {
      expect(expand(':MONTH'), 'August');
      expect(expand(':YEAR'), '2026');
      expect(expand(':QUARTER'), 'Q3');
    });

    test('quarter boundaries', () {
      expect(expand(':QUARTER', now: DateTime(2026, 1, 1)), 'Q1');
      expect(expand(':QUARTER', now: DateTime(2026, 3, 31)), 'Q1');
      expect(expand(':QUARTER', now: DateTime(2026, 4, 1)), 'Q2');
      expect(expand(':QUARTER', now: DateTime(2026, 12, 31)), 'Q4');
    });
  });

  group('fixed-window literals', () {
    test(':WEEK is today through today+6', () {
      expect(expand(':WEEK'), 'Aug 15, 2026 - Aug 21, 2026');
    });

    test(':WEEK_BEFORE / :WEEK_AHEAD', () {
      expect(expand(':WEEK_BEFORE'), 'Aug 8, 2026 - Aug 14, 2026');
      expect(expand(':WEEK_AHEAD'), 'Aug 22, 2026 - Aug 28, 2026');
    });

    test(':MONTH_BEFORE / :MONTH_AFTER', () {
      expect(expand(':MONTH_BEFORE'), 'Jul 15, 2026 - Aug 14, 2026');
      expect(expand(':MONTH_AFTER'), 'Aug 15, 2026 - Sep 14, 2026');
    });

    test(':YEAR_BEFORE / :YEAR_AFTER', () {
      expect(expand(':YEAR_BEFORE'), 'Aug 15, 2025 - Aug 14, 2026');
      expect(expand(':YEAR_AFTER'), 'Aug 15, 2026 - Aug 14, 2027');
    });

    test('windows cross a year boundary intact', () {
      expect(
        expand(':WEEK', now: DateTime(2026, 12, 29)),
        'Dec 29, 2026 - Jan 4, 2027',
      );
      expect(
        expand(':MONTH_AFTER', now: DateTime(2026, 12, 10)),
        'Dec 10, 2026 - Jan 9, 2027',
      );
    });

    test('rendered through the company date format, not ISO', () {
      expect(
        expand(':WEEK', fmt: formatter(dateFormatId: '1')),
        '15/Aug/2026 - 21/Aug/2026',
      );
    });

    test('a longer key beats the prefix it extends', () {
      // `:MONTH` leading the alternation would leave a dangling "_BEFORE".
      expect(expand(':MONTH_BEFORE'), isNot(contains('_BEFORE')));
      expect(expand(':WEEK_AHEAD'), isNot(contains('_AHEAD')));
      expect(expand(':YEAR_AFTER'), isNot(contains('_AFTER')));
    });
  });

  group('arithmetic', () {
    test('upstream\'s own expectation, minus the key it still gets wrong', () {
      // tests/Unit/HelpersTest.php testReservedKeywordMathUsesMatchedOperation
      // expects 'February 2023 Q2 March 2024'; `:QUARTER*2` stays raw here.
      expect(
        expand(
          ':MONTH+1 :YEAR-1 :QUARTER*2 :MONTHYEAR+2',
          now: DateTime(2024, 1, 15, 12),
        ),
        'February 2023 :QUARTER*2 March 2024',
      );
    });

    test(':QUARTER±n is a Q-prefixed quarter that wraps the year', () {
      expect(expand('Retainer for :QUARTER+1'), 'Retainer for Q4');
      expect(expand(':QUARTER+2'), 'Q1');
      expect(expand(':QUARTER-3'), 'Q4');
    });

    test(':QUARTER±n keeps Carbon\'s month overflow on the 31st', () {
      // `addQuarters(1)` on Mar 31 is "Jun 31" → Jul 1, so Q3 upstream.
      expect(expand(':QUARTER+1', now: DateTime(2026, 3, 31, 12)), 'Q3');
      // `subQuarters(1)` on Dec 31 is "Sep 31" → Oct 1, so Q4.
      expect(expand(':QUARTER-1', now: DateTime(2026, 12, 31, 12)), 'Q4');
      expect(expand(':QUARTER+1', now: DateTime(2026, 3, 15, 12)), 'Q2');
    });

    test(':MONTH±n is a month name that wraps without overflowing', () {
      expect(expand(':MONTH+3', now: DateTime(2026, 11, 30, 12)), 'February');
      expect(expand(':MONTH-9', now: DateTime(2026, 2, 10, 12)), 'May');
      expect(expand(':MONTH+1', now: DateTime(2026, 1, 31, 12)), 'February');
    });

    test(':MONTHYEAR±n is anchored to the 1st', () {
      expect(
        expand(':MONTHYEAR+1', now: DateTime(2026, 1, 31, 12)),
        'February 2026',
      );
      expect(expand(':MONTHYEAR-8'), 'December 2025');
    });

    test(':YEAR±n', () {
      expect(expand(':YEAR+1'), '2027');
      expect(expand(':YEAR-10'), '2016');
    });

    test('an offset and a bare literal in one description', () {
      expect(expand(':MONTH - :MONTH+2'), 'August - October');
    });
  });

  group('left alone', () {
    test('text with no keyword is returned unchanged', () {
      expect(expand('Annual hosting plan'), 'Annual hosting plan');
      expect(expand(''), '');
    });

    test('arithmetic upstream still gets wrong stays raw', () {
      // `:YEAR/4` renders `506.5`, `:WEEK+2` renders `2` and `:MONTH_BEFORE-1`
      // a bare month number; `*` / `/` compute a number, not an offset. A
      // token reads as a token.
      expect(expand(':YEAR/4'), ':YEAR/4');
      expect(expand(':WEEK+2'), ':WEEK+2');
      expect(expand(':MONTH_BEFORE-1'), ':MONTH_BEFORE-1');
      expect(expand(':YEAR_AFTER+1'), ':YEAR_AFTER+1');
      expect(expand(':QUARTER*2'), ':QUARTER*2');
      expect(expand(':MONTH*2'), ':MONTH*2');
    });

    test('an offset glued to more text stays raw', () {
      expect(expand(':MONTH+2x'), ':MONTH+2x');
    });

    test('a keyword that is only a prefix of a real word', () {
      expect(expand(':MONTHLY special'), ':MONTHLY special');
    });

    test('a range the server itself skips is untouched', () {
      // `ranges` upstream holds MONTHYEAR only.
      expect(expand('[MONTH|MONTH+2]'), '[MONTH|MONTH+2]');
    });

    test('range forms upstream skips stay raw', () {
      // Upstream accepts only `MONTHYEAR` or `MONTHYEAR[+-]n` on the right and
      // leaves anything else as written.
      expect(expand('[MONTHYEAR|MONTHYEAR/2]'), '[MONTHYEAR|MONTHYEAR/2]');
      expect(expand('[MONTHYEAR|MONTHYEAR*2]'), '[MONTHYEAR|MONTHYEAR*2]');
    });
  });

  group('formatter handling', () {
    test('an empty locale expands instead of throwing', () {
      // `CompanyFormatSettings.locale` is a non-nullable String that is `''`
      // both in `.fallback` and for any unrecognised `language_id`.
      // `DateFormat('')` throws `Invalid locale ""` rather than falling back,
      // and it would throw on exactly the rows this feature exists for.
      expect(
        () => expand('[MONTHYEAR|MONTHYEAR+12]', fmt: formatter(locale: '')),
        returnsNormally,
      );
      expect(
        () => expand(':MONTH', fmt: formatter(locale: '')),
        returnsNormally,
      );
      expect(
        () => expand(':WEEK', fmt: formatter(locale: '')),
        returnsNormally,
      );
    });

    test('the fallback settings are the reachable empty-locale case', () {
      final fallback = Formatter(
        settings: CompanyFormatSettings.fallback,
        currencies: const {},
        countries: const {},
        dateFormats: const {},
      );
      expect(fallback.settings.locale, '');
      expect(
        expandDatePlaceholders(
          'Hosting [MONTHYEAR|MONTHYEAR+12]',
          formatter: fallback,
          now: at,
        ),
        'Hosting August 2026 - August 2027',
      );
    });

    test('no formatter at all falls back to ISO dates', () {
      expect(
        expandDatePlaceholders(':WEEK', now: at),
        '2026-08-15 - 2026-08-21',
      );
      expect(
        expandDatePlaceholders('[MONTHYEAR|MONTHYEAR+1]', now: at),
        'August 2026 - September 2026',
      );
    });

    test('now defaults to the wall clock', () {
      // The `now: null` branch is otherwise never taken by these tests.
      final today = DateTime.now();
      expect(
        expandDatePlaceholders(':YEAR', formatter: formatter()),
        '${today.year}',
      );
    });

    test('a caller can override the separator', () {
      expect(
        expandDatePlaceholders(
          '[MONTHYEAR|MONTHYEAR+1]',
          formatter: formatter(),
          now: at,
          separator: 'bis',
        ),
        'August 2026 bis September 2026',
      );
    });
  });
}
