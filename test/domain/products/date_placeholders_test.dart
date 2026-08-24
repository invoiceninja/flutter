import 'package:admin/domain/products/date_placeholders.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

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

  String expand(String text, {DateTime? now}) => expandDatePlaceholders(
    text,
    rangeSeparator: 'to',
    now: now ?? at,
    locale: 'en',
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

  group('left alone', () {
    test('text with no keyword is returned unchanged', () {
      expect(expand('Annual hosting plan'), 'Annual hosting plan');
      expect(expand(''), '');
    });

    test('arithmetic literals stay raw rather than risk a wrong date', () {
      // Upstream month math does not wrap the year; a half-right expansion
      // would read as fact where the token reads as a token.
      expect(expand('due :MONTH+2'), 'due :MONTH+2');
      expect(expand(':WEEK'), ':WEEK');
      expect(expand(':MONTH_BEFORE'), ':MONTH_BEFORE');
    });

    test('a range the server itself skips is untouched', () {
      // `ranges` upstream holds MONTHYEAR only.
      expect(expand('[MONTH|MONTH+2]'), '[MONTH|MONTH+2]');
    });

    test('the separator is the caller\'s, so it can be localized', () {
      expect(
        expandDatePlaceholders(
          '[MONTHYEAR|MONTHYEAR+1]',
          rangeSeparator: 'bis',
          now: at,
          locale: 'en',
        ),
        'August 2026 bis September 2026',
      );
    });
  });
}
