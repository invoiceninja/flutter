import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/expenses/receipt_parser.dart';

/// Receipt OCR's rules, over what an engine really returns. The fixtures in
/// `test/fixtures/receipts/<engine>/` are receipts rendered and read by that
/// engine — Apple Vision on macOS so far — so the label and its amount arrive
/// as separate fragments, as they do on a device, and the rows are rebuilt
/// from the boxes. `docs/receipt-ocr.md`.
void main() {
  const today = Date(2026, 10, 25);

  Currency currency(String code, {int precision = 2, String symbol = ''}) =>
      Currency(
        id: code,
        name: code,
        code: code,
        symbol: symbol,
        precision: precision,
        thousandSeparator: ',',
        decimalSeparator: '.',
        swapCurrencySymbol: false,
        exchangeRate: Decimal.one,
      );

  final currencies = [
    currency('USD', symbol: r'$'),
    currency('EUR', symbol: '€'),
    currency('GBP', symbol: '£'),
    currency('CAD', symbol: r'$'),
    currency('AUD', symbol: r'$'),
    currency('SEK', symbol: 'kr'),
    currency('INR', symbol: '₹'),
    currency('KWD', precision: 3, symbol: 'KD'),
    currency('JPY', precision: 0, symbol: '¥'),
    // Codes that are also ordinary words a till prints — `ALL SALES FINAL`,
    // `LG CUP`, `TOP UP` — from the server's CurrenciesSeeder.
    for (final code in const [
      'ALL',
      'CUP',
      'TOP',
      'PEN',
      'MAD',
      'TRY',
      'SOS',
      'BOB',
      'BAM',
      'GEL',
      'MOP',
      'HUF',
      'RON',
      'AMD',
      'PHP',
    ])
      currency(code),
  ];

  DateOrder order(String s) => switch (s) {
    'dmy' => DateOrder.dmy,
    'ymd' => DateOrder.ymd,
    _ => DateOrder.mdy,
  };

  group('fixtures', () {
    for (final engine in Directory('test/fixtures/receipts').listSync()) {
      if (engine is! Directory) continue;
      final files = engine.listSync().whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      for (final file in files) {
        final name = file.uri.pathSegments.last.replaceAll('.json', '');
        test('${engine.uri.pathSegments.where((s) => s.isNotEmpty).last}/'
            '$name', () {
          final fixture =
              jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
          final ctxJson = fixture['context'] as Map<String, dynamic>;
          final expected = fixture['expected'] as Map<String, dynamic>;
          final fragments = [
            for (final f in fixture['fragments'] as List)
              ?OcrFragment.fromMap(f),
          ];
          final ctx = ReceiptParseContext(
            today: today,
            dateOrder: order(ctxJson['order'] as String),
            currencies: currencies,
            companyCurrency: currencies.firstWhere(
              (c) => c.code == ctxJson['company'],
            ),
          );

          final scan = parseReceiptText(fragments, ctx);

          expect(scan.total?.value.toString(), _decimal(expected['total']));
          expect(scan.total?.confidence.name, expected['totalConf']);
          expect(scan.date?.value.toIso(), expected['date']);
          if (expected.containsKey('dateConf')) {
            expect(scan.date?.confidence.name, expected['dateConf']);
          }
          expect(scan.vendorName, expected['vendor']);
          expect(scan.currencyCode, expected['currency']);
          expect(scan.receiptNumber, expected['number']);
          final taxes = expected['taxes'] as List;
          expect(
            [
              for (final t in scan.taxes)
                [t.rate?.toString(), t.amount?.toString()],
            ],
            [
              for (final t in taxes) [_decimal(t[0]), _decimal(t[1])],
            ],
          );
        });
      }
    }
  });

  group('rebuildRows', () {
    test('a label and an amount on one printed line meet again, whatever '
        'order the engine returned them in', () {
      // ML Kit's shape: every label, then every amount.
      final rows = rebuildRows([
        const OcrFragment('SUBTOTAL', 0.05, 0.50, 0.2, 0.03),
        const OcrFragment('TOTAL', 0.05, 0.55, 0.2, 0.03),
        const OcrFragment('13.67', 0.80, 0.501, 0.1, 0.03),
        const OcrFragment('14.23', 0.80, 0.552, 0.1, 0.03),
      ]);
      expect(rows.map((r) => r.text), ['SUBTOTAL 13.67', 'TOTAL 14.23']);
    });

    test('a slanted line still forms one row', () {
      final rows = rebuildRows([
        const OcrFragment('TOTAL', 0.05, 0.50, 0.2, 0.03),
        const OcrFragment('14.23', 0.80, 0.512, 0.1, 0.03),
        const OcrFragment('VISA', 0.05, 0.56, 0.2, 0.03),
      ]);
      expect(rows.map((r) => r.text), ['TOTAL 14.23', 'VISA']);
    });
  });

  group('amounts', () {
    ReceiptScan parse(String total, {String company = 'USD'}) =>
        parseReceiptRows(
          [
            ReceiptRow([OcrFragment('Total $total', 0, 0, 1, 0.1)]),
          ],
          ReceiptParseContext(
            today: today,
            currencies: currencies,
            companyCurrency: currencies.firstWhere((c) => c.code == company),
          ),
        );

    test('both decimal styles, and every grouping a till prints', () {
      expect(parse('1,234.56').total?.value, Decimal.parse('1234.56'));
      expect(parse('1.234,56').total?.value, Decimal.parse('1234.56'));
      expect(parse('1 234,56').total?.value, Decimal.parse('1234.56'));
      expect(parse("1'234.56").total?.value, Decimal.parse('1234.56'));
      expect(parse('12,50').total?.value, Decimal.parse('12.5'));
      expect(parse('12').total?.value, Decimal.parse('12'));
    });

    test('the currency decides how many decimals there are', () {
      expect(
        parse('1,280', company: 'JPY').total?.value,
        Decimal.parse('1280'),
      );
      expect(
        parse('3.250', company: 'KWD').total?.value,
        Decimal.parse('3.25'),
      );
    });
  });

  group('rows that only look like something', () {
    ReceiptScan rows(List<String> lines, {String company = 'USD'}) =>
        parseReceiptRows(
          [
            for (var i = 0; i < lines.length; i++)
              ReceiptRow([OcrFragment(lines[i], 0, i * 0.1, 1, 0.05)]),
          ],
          ReceiptParseContext(
            today: today,
            currencies: currencies,
            companyCurrency: currencies.firstWhere((c) => c.code == company),
          ),
        );

    test('a quantity column is not a thousands group', () {
      expect(
        rows(['HOTEL', 'ROOM 2 189.00', 'BAR 1 12.00']).total?.value,
        Decimal.parse('189'),
      );
      // A comma decimal still takes a space as grouping.
      expect(
        rows(['Total 1 234,56'], company: 'EUR').total?.value,
        Decimal.parse('1234.56'),
      );
    });

    test('a refund total is left blank, not read as a positive', () {
      expect(rows(['RETURN', 'Total -49.99']).total, isNull);
    });

    test('a dotted phone number is no date', () {
      expect(rows(['Tel 01.02.25.67.89', 'Total 5.00']).date, isNull);
    });

    test('a tax heading or identifier is no tax', () {
      expect(rows(['TAX INVOICE 0042', 'Total 5.00']).taxes, isEmpty);
      expect(rows(['VAT: GB 220 4302 31', 'Total 95.00']).taxes, isEmpty);
    });

    test('the same unrated tax printed twice is one tax', () {
      expect(rows(['Tax 0.56', 'Total 14.23', 'Tax 0.56']).taxes, hasLength(1));
    });

    test('a Turkish %18 is a rate', () {
      expect(
        rows([
          'KDV %18 1,80',
          'Toplam 11,80',
        ], company: 'TRY').taxes.single.rate,
        Decimal.parse('18'),
      );
    });

    test('month abbreviations a till prints', () {
      for (final (line, month) in [
        ('Mar 15, 2026', 3),
        ('15 MAR 2026', 3),
        ('15/Mar/2026', 3),
        ('15MAR26', 3),
        ('3. Mär 2026', 3),
        ('12 janv. 2026', 1),
        ('5 dic 2025', 12),
      ]) {
        expect(rows([line]).date?.value.month, month, reason: line);
      }
    });
  });

  group('cleanVendorName', () {
    test('a till line becomes a name', () {
      expect(cleanVendorName('SQ *BLUE BOTTLE #102'), 'Blue Bottle');
      expect(cleanVendorName('TST* Joe\'s Pizza'), "Joe's Pizza");
      expect(cleanVendorName('WHOLEFDS MKT 10234'), 'Wholefds Mkt');
      expect(cleanVendorName('Café Roma'), 'Café Roma');
      expect(cleanVendorName('#1234'), isNull);
      // `no` / `nr` / `store` are words, not the end of `BRUNO`.
      expect(cleanVendorName('PIZZERIA DA BRUNO 2'), 'Pizzeria Da Bruno 2');
      expect(cleanVendorName('CAFE MILANO 3'), 'Cafe Milano 3');
    });
  });

  test('dateOrderOf reads the company pattern', () {
    expect(dateOrderOf('dd/MM/yyyy'), DateOrder.dmy);
    expect(dateOrderOf('M/d/yyyy'), DateOrder.mdy);
    expect(dateOrderOf('yyyy-MM-dd'), DateOrder.ymd);
    expect(dateOrderOf('d. MMM yyyy'), DateOrder.dmy);
    expect(dateOrderOf('MMM d, yyyy'), DateOrder.mdy);
  });

  test('a page with nothing on it reads as nothing', () {
    final scan = parseReceiptText(
      const [],
      const ReceiptParseContext(today: today),
    );
    expect(scan.isEmpty, isTrue);
  });
}

String? _decimal(Object? v) =>
    v == null ? null : Decimal.parse(v as String).toString();
