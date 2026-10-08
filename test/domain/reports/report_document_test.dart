import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/value/money.dart';
import 'package:admin/domain/reports/report_document.dart';

/// The files under `fixtures/` are what the demo server answered for each
/// file-only report (trimmed where long). They are the contract: the parser
/// is tested against what the server writes, not against a guess at it.
String _fixture(String name) =>
    File('test/domain/reports/fixtures/$name.csv').readAsStringSync();

final _dot = FormattedNumberStyle(
  thousandSeparator: ',',
  decimalSeparator: '.',
  precision: 2,
);
final _comma = FormattedNumberStyle(
  thousandSeparator: '.',
  decimalSeparator: ',',
  precision: 2,
);

FormattedNumberStyle? _styles(String code) => code == 'EUR' ? _comma : _dot;

ReportDocument _parse(String name) => parseReportDocument(
  _fixture(name),
  numberStyleFor: _styles,
  defaultStyle: _dot,
)!;

Decimal _d(String v) => Decimal.parse(v);

void main() {
  group('parseCsvRecords', () {
    test('quoted cells keep their commas, quotes and line breaks', () {
      expect(parseCsvRecords('a,"b, c","say ""hi""","two\nlines"\nx,y'), [
        ['a', 'b, c', 'say "hi"', 'two\nlines'],
        ['x', 'y'],
      ]);
    });

    test('a blank line is a record, because here it separates things', () {
      expect(parseCsvRecords('a\n\nb'), [
        ['a'],
        [''],
        ['b'],
      ]);
    });

    test('CRLF and a byte-order mark are not content', () {
      expect(parseCsvRecords('﻿a,b\r\nc,d\r\n'), [
        ['a', 'b'],
        ['c', 'd'],
      ]);
    });
  });

  group('aged receivables, summary', () {
    final doc = _parse('ar_summary');

    test('the title and the date it was made are about the file', () {
      expect(doc.title, 'Aged Receivable Summary Report');
      expect(doc.meta.single.label, 'Created On');
      expect(doc.meta.single.value, '08/Oct/2026');
    });

    test('one table per currency, captioned with it', () {
      final tables = doc.tables.toList();
      expect([for (final t in tables) t.currencyCode], ['GBP', 'EUR']);
      expect(tables.first.header.first, 'Client Name');
      expect(tables.first.rows.length, 3);
    });

    test('a client number is an identifier, not a number', () {
      final t = doc.tables.first;
      // `0004`: all digits, and neither right-aligned nor summed.
      expect(t.kinds[1], ReportDocColumnKind.text);
      expect(t.kinds[0], ReportDocColumnKind.text);
      expect(t.kinds[3], ReportDocColumnKind.money);
      expect(t.kinds.last, ReportDocColumnKind.money);
    });

    test('amounts are read in their own currency\'s notation', () {
      final gbp = doc.tables.first;
      final eur = doc.tables.last;
      expect(gbp.total(gbp.header.length - 1), _d('17358.00'));
      // `€1.717,00` is one thousand seven hundred and seventeen.
      expect(eur.values.first[3], _d('1717.00'));
      expect(eur.total(eur.header.length - 1), _d('4926.00'));
    });

    test('a column of text has no total', () {
      expect(doc.tables.first.total(0), isNull);
      expect(doc.tables.first.total(1), isNull);
    });
  });

  test('aged receivables, detail: dates and blanks are text, age is a '
      'number that is not totalled', () {
    final t = _parse('ar_detail').tables.first;
    expect(t.header, contains('Age'));
    final age = t.header.indexOf('Age');
    expect(t.kinds[0], ReportDocColumnKind.text, reason: 'a date');
    expect(t.kinds[1], ReportDocColumnKind.text, reason: 'an empty column');
    expect(t.kinds[2], ReportDocColumnKind.text, reason: 'invoice 0011');
    expect(t.kinds[age], ReportDocColumnKind.number);
    expect(t.total(age), isNull);
    expect(t.total(t.header.length - 1), _d('17358.00'));
  });

  test('client balance and client sales read the same way', () {
    final balance = _parse('client_balance').tables.first;
    expect(balance.currencyCode, 'GBP');
    expect(balance.kinds[3], ReportDocColumnKind.number, reason: 'a count');
    expect(balance.total(4), _d('17358.00'));

    final sales = _parse('client_sales');
    expect(sales.tables.first.total(4), _d('29707.00'));
  });

  group('client sales, the whole file', () {
    final doc = _parse('client_sales');

    test('a month is a column header, not a negative number', () {
      // "July-2026" read as "-2026 in the currency July" made the header of
      // each month table a line of figures, and the table under it nine
      // loose facts. Three of the nine tables were lost that way.
      final tables = doc.tables.toList();
      expect(tables, hasLength(9));
      expect(
        [for (final t in tables) t.currencyCode],
        [
          'GBP', 'EUR', 'USD', // by client
          'EUR', 'GBP', 'USD', // invoices by month
          'EUR', 'GBP', 'USD', // payments by month
        ],
      );
      expect(tables[3].header, [
        'Client Name',
        'July-2026',
        'August-2026',
        'September-2026',
        'October-2026',
        'November-2026',
        'December-2026',
      ]);
      expect(doc.blocks.whereType<ReportDocFacts>(), isEmpty);
    });

    test('its two breakdowns are headed', () {
      expect(
        [for (final b in doc.blocks.whereType<ReportDocHeading>()) b.text],
        ['Invoices by month', 'Payments by month'],
      );
    });

    test('a month a client was not billed in is blank, and the column is '
        'still amounts', () {
      final byMonth = doc.tables.toList()[3];
      // Sparse: most cells empty.
      expect(byMonth.rows.any((r) => r[1].isEmpty), isTrue);
      expect(byMonth.kinds[1], ReportDocColumnKind.money);
      expect(byMonth.total(1), _d('345.00'));
    });
  });

  test('what looks like an amount and is not', () {
    ReportDocTable table(String cell) =>
        parseReportDocument('A,B,C\nx,$cell,y\n')!.tables.single;
    for (final cell in [
      'July-2026', // a month
      'May 2026', // a month, spaced
      'INV-0042', // an invoice number
      '0004', // a client number
      'Invoice 0007', // a sentence
      '2026-01-01', // a date
      '0 - 30', // a range
    ]) {
      expect(table(cell).kinds[1], ReportDocColumnKind.text, reason: cell);
    }
    for (final cell in [r'$1,250.00', '€1.250,00', 'USD 1250', 'kr 1 250,00']) {
      expect(table(cell).kinds[1], ReportDocColumnKind.money, reason: cell);
    }
    expect(table('1250').kinds[1], ReportDocColumnKind.number);
  });

  group('profit and loss', () {
    final doc = _parse('profit_and_loss');

    test('who and when are about the file; the figures are the report', () {
      expect(doc.title, 'Profit and Loss');
      expect(
        [for (final f in doc.meta) f.label],
        ['Company Name', 'Date Range'],
      );
      expect(doc.meta.last.values, ['01/Jan/2026', '31/Dec/2026']);
    });

    test('each ruled-off part is its own block, in order', () {
      final facts = doc.blocks.whereType<ReportDocFacts>().toList();
      expect(facts.first.entries.first.label, 'Total Revenue[Tax Exclusive]');
      expect(facts.first.entries.first.value, r'$70,114.00');
      expect(
        facts.any((f) => f.entries.any((e) => e.label == 'Total Profit')),
        isTrue,
      );
      final headings = [
        for (final b in doc.blocks.whereType<ReportDocHeading>()) b.text,
      ];
      expect(headings, ['Revenue', 'Expenses']);
    });

    test('the revenue-by-currency lines are a table', () {
      final table = doc.tables.single;
      expect(table.header, ['Currency', 'Amount', 'Total Taxes']);
      expect(table.rows.length, 3);
      expect(table.values.first[1], _d('19848'));
      // Bare numbers: figures, but nothing says they are one currency.
      expect(table.kinds[1], ReportDocColumnKind.number);
    });
  });

  group('tax summary', () {
    final doc = _parse('tax_summary');

    test('a range written across padded cells is one fact', () {
      final range = doc.meta.firstWhere((f) => f.label == 'Date Range');
      expect(range.values, ['01/Jan/2026', '31/Dec/2026']);
    });

    test('a header with no rows under it is not shown as a fact', () {
      for (final facts in doc.blocks.whereType<ReportDocFacts>()) {
        for (final e in facts.entries) {
          expect(e.label, isNot('Tax Name'));
        }
      }
    });

    test('the two accounting bases are headed and their lines kept', () {
      final headings = [
        for (final b in doc.blocks.whereType<ReportDocHeading>()) b.text,
      ];
      expect(headings, containsAll(['Accrual accounting', 'Cash accounting']));
      final first = doc.blocks.whereType<ReportDocFacts>().first;
      expect(first.entries.first.label, 'Gross');
      // The amount is written twice; the formatted one is what is shown.
      expect(first.entries.first.value, r'$70,114.00');
    });

    test('"Invoice 0007" is a name, not seven', () {
      final detail = doc.tables.first;
      expect(detail.kinds.first, ReportDocColumnKind.text);
      expect(detail.rows.first.first, startsWith('Invoice '));
    });
  });

  test('user sales: a title straight over a table', () {
    final doc = _parse('user_sales');
    expect(doc.title, startsWith('User sales report'));
    final t = doc.tables.single;
    expect(t.header, ['Name', 'Invoices', 'Invoice Amount', 'Total Taxes']);
    expect(t.kinds, [
      ReportDocColumnKind.text,
      ReportDocColumnKind.number,
      ReportDocColumnKind.money,
      ReportDocColumnKind.money,
    ]);
    expect(t.total(2), _d('70114.00'));
  });

  test('product sales: the lines, then the per-product summary', () {
    final doc = _parse('product_sales');
    final tables = doc.tables.toList();
    expect(tables.length, 3);
    expect(tables.first.header.first, 'Date');
    expect(tables.first.header.length, 30);
    // Every row exactly as wide as its header, whatever the file padded.
    for (final t in tables) {
      for (final row in t.rows) {
        expect(row.length, t.header.length);
      }
    }
    expect(tables.last.header.first, 'Product');
  });

  group('what is not a report', () {
    test('nothing', () {
      expect(parseReportDocument(''), isNull);
      expect(parseReportDocument('\n\n\n'), isNull);
    });

    test('a title and nothing under it', () {
      expect(parseReportDocument('"Aged Receivable Summary Report"\n'), isNull);
    });

    test('an error page is not a table', () {
      // What a proxy answers when the job failed: no cells, no figures.
      expect(
        parseReportDocument('<html><body>Server Error</body></html>'),
        isNull,
      );
    });
  });
}
