import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/models/value/datetime_format.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/ui/features/reports/widgets/report_cell_text.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../_localization_helper.dart';

Currency _currency(
  String id,
  String code,
  String symbol, {
  String thousand = ',',
  String decimal = '.',
}) => Currency.fromMap({
  'id': id,
  'name': code,
  'code': code,
  'symbol': symbol,
  'precision': 2,
  'thousand_separator': thousand,
  'decimal_separator': decimal,
  'swap_currency_symbol': false,
  'exchange_rate': 1,
});

/// A company in USD, with GBP and EUR known.
Formatter _formatter() => Formatter(
  settings: CompanyFormatSettings.fallback,
  currencies: {
    '1': _currency('1', 'USD', r'$'),
    '2': _currency('2', 'GBP', '£'),
    '3': _currency('3', 'EUR', '€', thousand: '.', decimal: ','),
  },
  countries: const {},
  dateFormats: const {'5': DatetimeFormat(id: '5', format: 'MMM d, y')},
);

ReportColumn _col(String id) =>
    ReportColumn(identifier: id, displayLabel: id, type: inferColumnType(id));

Future<String> _text(
  WidgetTester tester,
  ReportCell cell,
  String columnId, {
  Formatter? formatter,
  String? rowCurrencyId,
  ReportColumn? column,
  bool hoursMinutes = false,
}) async {
  late String out;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: ReportHoursFormat(
        hoursMinutes: hoursMinutes,
        child: Builder(
          builder: (context) {
            out = reportCellText(
              context,
              cell,
              column ?? _col(columnId),
              formatter,
              rowCurrencyId: rowCurrencyId,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  return out;
}

void main() {
  final f = _formatter();

  testWidgets('an amount is formatted from its value, not the server string', (
    tester,
  ) async {
    // Probed live on the client report: value "3,125.00", display_value
    // "£3.00" — the server re-formats an already formatted string, and PHP
    // reads "3,125.00" as 3. The cell used to print the display value.
    final cell = ReportNumberCell(
      value: Decimal.parse('3125.00'),
      isMoney: true,
      displayValue: '£3.00',
    );
    final text = await _text(
      tester,
      cell,
      'client.balance',
      formatter: f,
      rowCurrencyId: '2',
    );
    expect(text, '£3,125.00');
  });

  testWidgets('an amount takes the currency of its row', (tester) async {
    // Everywhere else display_value is just the bare number in the company's
    // format ("521.00") — no symbol, and the wrong separators for a euro row.
    final cell = ReportNumberCell(
      value: Decimal.parse('1521.5'),
      isMoney: true,
      displayValue: '1,521.50',
    );
    expect(
      await _text(
        tester,
        cell,
        'invoice.amount',
        formatter: f,
        rowCurrencyId: '3',
      ),
      contains('1.521,50'),
    );
    expect(
      await _text(
        tester,
        cell,
        'invoice.amount',
        formatter: f,
        rowCurrencyId: '1',
      ),
      r'$1,521.50',
    );
  });

  testWidgets('with no row currency an amount is in the company currency', (
    tester,
  ) async {
    final cell = ReportNumberCell(value: Decimal.parse('960'), isMoney: true);
    expect(await _text(tester, cell, 'price', formatter: f), r'$960.00');
  });

  testWidgets('an amount waits for the formatter rather than flash a number', (
    tester,
  ) async {
    final cell = ReportNumberCell(value: Decimal.parse('960'), isMoney: true);
    expect(await _text(tester, cell, 'price'), '—');
  });

  testWidgets('a word in an amount column is shown as the word', (
    tester,
  ) async {
    // `payment.amount` on an invoice nobody has paid.
    const cell = ReportNumberCell(isMoney: true, displayValue: 'Unpaid');
    expect(await _text(tester, cell, 'payment.amount', formatter: f), 'Unpaid');
  });

  testWidgets('a date is in the company format, not ISO', (tester) async {
    final cell = ReportDateCell(
      value: Date(2026, 3, 3),
      displayValue: '2026-03-03',
    );
    final text = await _text(tester, cell, 'invoice.date', formatter: f);
    expect(text, 'Mar 3, 2026');
  });

  testWidgets('a date that could not be parsed keeps the server string', (
    tester,
  ) async {
    // The activity report sends its date already in the company's format.
    const cell = ReportDateCell(displayValue: '08/Oct/2026');
    expect(await _text(tester, cell, 'date', formatter: f), '08/Oct/2026');
  });

  testWidgets('a boolean reads Yes or No, never true or false', (tester) async {
    const yes = ReportBoolCell(value: true, displayValue: 'true');
    const no = ReportBoolCell(value: false, displayValue: 'false');
    expect(await _text(tester, yes, 'invoice.is_amount_discount'), 'Yes');
    expect(await _text(tester, no, 'invoice.is_amount_discount'), 'No');
  });

  testWidgets('a duration reads in hours, as the hours format says', (
    tester,
  ) async {
    // The weekly timesheet's rule: decimal hours by default, `H:MM` when the
    // device says so — never seconds, never a day count.
    const cell = ReportDurationCell(seconds: 5400, displayValue: '5400');
    expect(await _text(tester, cell, 'task.duration', formatter: f), '1.5');
    expect(
      await _text(tester, cell, 'task.duration', hoursMinutes: true),
      '1:30',
    );
    const zero = ReportDurationCell(seconds: 0, displayValue: '0');
    expect(await _text(tester, zero, 'task.duration', formatter: f), '0');
  });

  testWidgets('a time-only column shows the time of day alone', (tester) async {
    final cell = ReportDateTimeCell(
      value: DateTime.utc(2026, 10, 8, 9, 30),
      displayValue: '09:30',
    );
    const column = ReportColumn(
      identifier: 'task.start_time',
      displayLabel: 'Start Time',
      type: ReportColumnType.dateTime,
      timeOnly: true,
    );
    final text = await _text(
      tester,
      cell,
      'task.start_time',
      formatter: f,
      column: column,
    );
    final local = DateTime.utc(2026, 10, 8, 9, 30).toLocal();
    expect(text, contains('${local.minute}'.padLeft(2, '0')));
    // No date, and no seconds.
    expect(text, isNot(contains('2026')));
    expect(RegExp(r'\d+:\d+:\d+').hasMatch(text), isFalse);
  });

  testWidgets('text is the server string', (tester) async {
    const cell = ReportStringCell(value: 'paid', displayValue: 'Paid');
    expect(await _text(tester, cell, 'invoice.status'), 'Paid');
  });

  test('a report rounds hours to two places; the timesheet does not', () {
    // The timesheet's cells are seeded with this text and edited in place:
    // rounded, "0.33" retyped as it reads would save 1188 s, not 1200.
    expect(reportDurationText(1200, f), '0.33');
    expect(weeklyHoursText(1200, f), '0.33333');
  });

  test('a total of durations is hours; a total of quantities a number', () {
    // A week's 37.5 hours used to read "1d 13h 30m".
    expect(
      reportValueText(
        Decimal.fromInt(135000),
        column: _col('task.duration'),
        formatter: f,
      ),
      '37.5',
    );
    expect(
      reportValueText(
        Decimal.fromInt(135000),
        column: _col('task.duration'),
        formatter: f,
        hoursMinutes: true,
      ),
      '37:30',
    );
    expect(
      reportValueText(
        Decimal.parse('12.5'),
        column: _col('item.quantity'),
        formatter: f,
      ),
      '12.5',
    );
  });
}
