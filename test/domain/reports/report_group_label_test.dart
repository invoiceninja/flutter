import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/datetime_format.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/domain/reports/report_engine.dart';
import 'package:admin/domain/reports/report_group_label.dart';
import 'package:admin/utils/formatting.dart';

/// A formatter for [locale] with the server's default date format (id 1,
/// `dd/MMM/yyyy`) so the day/week branch is exercised through the real
/// `Formatter.date` path rather than an ISO fallback.
Formatter _formatter({String locale = 'en'}) => Formatter(
  settings: CompanyFormatSettings(
    currencyId: '1',
    countryId: '840',
    dateFormatId: '1',
    useCommaAsDecimalPlace: false,
    showCurrencyCode: false,
    enableMilitaryTime: false,
    locale: locale,
  ),
  currencies: const {},
  countries: const {},
  dateFormats: const {'1': DatetimeFormat(id: '1', format: 'dd/MMM/yyyy')},
);

void main() {
  // Month / quarter / year go through `DateFormat` skeletons, which need the
  // locale's symbols loaded. In the app that happens via
  // `GlobalMaterialLocalizations`; here there is no widget tree, so load them
  // directly. (Deliberately not a *measurement* test — intl's own data is the
  // full CLDR set, not the subset Flutter bundles, so widths derived from it
  // would not be what ships.)
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('es');
    await initializeDateFormatting('ja');
  });

  group('reportGroupDisplayLabel', () {
    test('passes a non-date column straight through', () {
      expect(
        reportGroupDisplayLabel(
          key: 'ACME',
          columnType: ReportColumnType.string,
          subgroup: ReportSubgroup.month,
          formatter: _formatter(),
        ),
        'ACME',
      );
    });

    test('month renders the month name and year', () {
      expect(
        reportGroupDisplayLabel(
          key: '2026-04-01',
          columnType: ReportColumnType.dateTime,
          subgroup: ReportSubgroup.month,
          formatter: _formatter(),
        ),
        'April 2026',
      );
    });

    test('quarter renders a quarter, not a month', () {
      final label = reportGroupDisplayLabel(
        key: '2026-04-01',
        columnType: ReportColumnType.dateTime,
        subgroup: ReportSubgroup.quarter,
        formatter: _formatter(),
      );
      expect(label, contains('2026'));
      expect(label, contains('2')); // Q2
      expect(label, isNot(contains('April')));
    });

    test('year renders just the year', () {
      expect(
        reportGroupDisplayLabel(
          key: '2026-01-01',
          columnType: ReportColumnType.date,
          subgroup: ReportSubgroup.year,
          formatter: _formatter(),
        ),
        '2026',
      );
    });

    test('day and week honour the company date format', () {
      // id 1 is `dd/MMM/yyyy` — the server's own default, and the reason a
      // raw intl pattern can't be used as a hint anywhere in the app.
      expect(
        reportGroupDisplayLabel(
          key: '2026-04-01',
          columnType: ReportColumnType.dateTime,
          subgroup: ReportSubgroup.day,
          formatter: _formatter(),
        ),
        '01/Apr/2026',
      );
      expect(
        reportGroupDisplayLabel(
          key: '2026-04-01',
          columnType: ReportColumnType.dateTime,
          subgroup: ReportSubgroup.week,
          formatter: _formatter(),
        ),
        '01/Apr/2026',
      );
    });

    // The reason month/quarter/year use a `DateFormat` *skeleton* rather than
    // a literal `'MMMM yyyy'`: a literal pins the field order and drops the
    // locale's own connectives. Spanish needs a "de"; Japanese puts the year
    // first. Both assertions fail against a literal pattern.
    test('uses a locale skeleton, not a literal pattern (es)', () {
      final label = reportGroupDisplayLabel(
        key: '2026-09-01',
        columnType: ReportColumnType.dateTime,
        subgroup: ReportSubgroup.month,
        formatter: _formatter(locale: 'es'),
      );
      expect(label, contains('septiembre'));
      expect(label, contains(' de '));
    });

    test('uses a locale skeleton, not a literal pattern (ja)', () {
      final label = reportGroupDisplayLabel(
        key: '2026-09-01',
        columnType: ReportColumnType.dateTime,
        subgroup: ReportSubgroup.month,
        formatter: _formatter(locale: 'ja'),
      );
      // Year first — a literal `MMMM yyyy` would render "9月 2026".
      expect(label.indexOf('2026'), lessThan(label.indexOf('9')));
    });

    test('falls back to the raw key with no formatter', () {
      expect(
        reportGroupDisplayLabel(
          key: '2026-04-01',
          columnType: ReportColumnType.dateTime,
          subgroup: ReportSubgroup.day,
          formatter: null,
        ),
        '2026-04-01',
      );
    });

    test('an unparsable key survives untouched', () {
      // The engine's own bucket for a null date cell.
      expect(
        reportGroupDisplayLabel(
          key: '',
          columnType: ReportColumnType.dateTime,
          subgroup: ReportSubgroup.month,
          formatter: _formatter(),
        ),
        '',
      );
    });
  });
}
