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
        'Hosting August 2026 to August 2027',
      );
    });

    test('no arithmetic → the same month on both sides', () {
      expect(expand('[MONTHYEAR|MONTHYEAR]'), 'August 2026 to August 2026');
    });

    test('an offset crossing a year boundary rolls the year', () {
      expect(
        expand('[MONTHYEAR|MONTHYEAR+5]', now: DateTime(2026, 11, 3)),
        'November 2026 to April 2027',
      );
    });

    test('several ranges in one description each expand', () {
      expect(
        expand('[MONTHYEAR|MONTHYEAR+1] and [MONTHYEAR|MONTHYEAR+2]'),
        'August 2026 to September 2026 and August 2026 to October 2026',
      );
    });

    test('day-1 math, so month-end cannot overflow a month', () {
      // Upstream's `Carbon::createFromDate($y, $m)` keeps *today's* day and
      // then `addMonths(1)` overflows Jan 31 → Mar 3. Ours cannot.
      expect(
        expand('[MONTHYEAR|MONTHYEAR+1]', now: DateTime(2026, 1, 31)),
        'January 2026 to February 2026',
      );
    });

    test(
      'the separator matches the server, which hardcodes lowercase "to"',
      () {
        // `Helpers.php:289` — `sprintf('%s to %s', …)`, never `ctrans`.
        expect(expand('[MONTHYEAR|MONTHYEAR+1]'), contains(' to '));
      },
    );
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
      expect(expand(':WEEK'), 'Aug 15, 2026 to Aug 21, 2026');
    });

    test(':WEEK_BEFORE / :WEEK_AHEAD', () {
      expect(expand(':WEEK_BEFORE'), 'Aug 8, 2026 to Aug 14, 2026');
      expect(expand(':WEEK_AHEAD'), 'Aug 22, 2026 to Aug 28, 2026');
    });

    test(':MONTH_BEFORE / :MONTH_AFTER', () {
      expect(expand(':MONTH_BEFORE'), 'Jul 15, 2026 to Aug 14, 2026');
      expect(expand(':MONTH_AFTER'), 'Aug 15, 2026 to Sep 14, 2026');
    });

    test(':YEAR_BEFORE / :YEAR_AFTER', () {
      expect(expand(':YEAR_BEFORE'), 'Aug 15, 2025 to Aug 14, 2026');
      expect(expand(':YEAR_AFTER'), 'Aug 15, 2026 to Aug 14, 2027');
    });

    test('windows cross a year boundary intact', () {
      expect(
        expand(':WEEK', now: DateTime(2026, 12, 29)),
        'Dec 29, 2026 to Jan 4, 2027',
      );
      expect(
        expand(':MONTH_AFTER', now: DateTime(2026, 12, 10)),
        'Dec 10, 2026 to Jan 9, 2027',
      );
    });

    test('rendered through the company date format, not ISO', () {
      expect(
        expand(':WEEK', fmt: formatter(dateFormatId: '1')),
        '15/Aug/2026 to 21/Aug/2026',
      );
    });

    test('a longer key beats the prefix it extends', () {
      // `:MONTH` leading the alternation would leave a dangling "_BEFORE".
      expect(expand(':MONTH_BEFORE'), isNot(contains('_BEFORE')));
      expect(expand(':WEEK_AHEAD'), isNot(contains('_AHEAD')));
      expect(expand(':YEAR_AFTER'), isNot(contains('_AFTER')));
    });
  });

  group('left alone', () {
    test('text with no keyword is returned unchanged', () {
      expect(expand('Annual hosting plan'), 'Annual hosting plan');
      expect(expand(''), '');
    });

    test('arithmetic literals stay raw rather than ship upstream bugs', () {
      // `:QUARTER+1` renders a bare `4` upstream, `:YEAR/4` renders `506.5`,
      // and `:WEEK+2` renders `2`. A token reads as a token.
      expect(expand('due :MONTH+2'), 'due :MONTH+2');
      expect(expand(':QUARTER+1'), ':QUARTER+1');
      expect(expand(':YEAR/4'), ':YEAR/4');
      expect(expand(':WEEK+2'), ':WEEK+2');
      expect(expand(':MONTH_BEFORE-1'), ':MONTH_BEFORE-1');
    });

    test('a keyword that is only a prefix of a real word', () {
      expect(expand(':MONTHLY special'), ':MONTHLY special');
    });

    test('a range the server itself skips is untouched', () {
      // `ranges` upstream holds MONTHYEAR only.
      expect(expand('[MONTH|MONTH+2]'), '[MONTH|MONTH+2]');
    });

    test('range forms upstream renders wrongly stay raw', () {
      // `-` / `*` leave an empty right side server-side; `/` makes
      // `preg_replace` return null and destroys the whole description.
      expect(expand('[MONTHYEAR|MONTHYEAR-2]'), '[MONTHYEAR|MONTHYEAR-2]');
      expect(expand('[MONTHYEAR|MONTHYEAR/2]'), '[MONTHYEAR|MONTHYEAR/2]');
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
        'Hosting August 2026 to August 2027',
      );
    });

    test('no formatter at all falls back to ISO dates', () {
      expect(
        expandDatePlaceholders(':WEEK', now: at),
        '2026-08-15 to 2026-08-21',
      );
      expect(
        expandDatePlaceholders('[MONTHYEAR|MONTHYEAR+1]', now: at),
        'August 2026 to September 2026',
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
