// Deterministic inputs shared by the two benchmark harnesses: the web one
// (`benchmark/web_bench_main.dart`, docs/web-benchmarks.md) and the CI one
// (`benchmark/perf/`, docs/performance-tracking.md).
//
// Every generator is seeded and pure, so a run on any machine, under either
// compiler, builds the same input. Changing what one builds changes the work
// every benchmark that uses it measures — so do it only together with a note
// in the perf history (docs/performance-tracking.md § Changing a benchmark).

import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/billing/line_item_type.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/billing/totals_calculator.dart';
import 'package:admin/domain/reports/report_column_types.dart';

/// A tiny deterministic generator, so both compilers get the same inputs.
/// Park–Miller, whose products stay far below 2^53: dart2js integers are JS
/// doubles, and a generator that overflows them yields a different sequence
/// there than under dart2wasm's 64-bit ints.
class Lcg {
  Lcg(this._state);
  int _state;

  int next(int bound) {
    _state = (_state * 48271) % 2147483647;
    return _state % bound;
  }
}

Decimal _cents(int value) => Decimal.fromInt(value).shift(-2);

/// 5 invoices of 50 lines each, with item discounts, three tax slots and
/// surcharges, half of them tax-inclusive.
List<BillingTotalsInput> totalsInputs() {
  final rng = Lcg(20261008);
  return [
    for (var invoice = 0; invoice < 5; invoice++)
      BillingTotalsInput(
        lineItems: [
          for (var line = 0; line < 50; line++)
            LineItem(
              productKey: 'P$line',
              notes: '',
              cost: _cents(100 + rng.next(250000)),
              productCost: Decimal.zero,
              quantity: _cents(25 + rng.next(2000)),
              taxName1: 'VAT',
              taxName2: line.isEven ? 'City' : '',
              taxName3: '',
              taxRate1: _cents(500 + rng.next(2000)),
              taxRate2: line.isEven ? _cents(rng.next(900)) : Decimal.zero,
              taxRate3: Decimal.zero,
              typeId: LineItemType.standard,
              customValue1: '',
              customValue2: '',
              customValue3: '',
              customValue4: '',
              discount: _cents(rng.next(1500)),
              taxCategoryId: '',
            ),
        ],
        discount: _cents(rng.next(1000)),
        isAmountDiscount: invoice % 3 == 0,
        usesInclusiveTaxes: invoice.isOdd,
        taxName1: 'State',
        taxRate1: _cents(rng.next(800)),
        customSurcharge1: _cents(rng.next(5000)),
        customTaxes1: invoice % 4 == 0,
      ),
  ];
}

/// 5,000 invoice rows across 60 clients: grouped by client, sorted by amount.
ReportPreview reportPreview() {
  final rng = Lcg(77);
  const columns = [
    ReportColumn(
      identifier: 'client.name',
      displayLabel: 'Client',
      type: ReportColumnType.string,
    ),
    ReportColumn(
      identifier: 'invoice.number',
      displayLabel: 'Number',
      type: ReportColumnType.string,
    ),
    ReportColumn(
      identifier: 'invoice.amount',
      displayLabel: 'Amount',
      type: ReportColumnType.money,
    ),
    ReportColumn(
      identifier: 'invoice.balance',
      displayLabel: 'Balance',
      type: ReportColumnType.money,
    ),
    ReportColumn(
      identifier: 'invoice.date',
      displayLabel: 'Date',
      type: ReportColumnType.date,
    ),
    ReportColumn(
      identifier: 'invoice.status',
      displayLabel: 'Status',
      type: ReportColumnType.string,
    ),
  ];
  const statuses = ['Draft', 'Sent', 'Partial', 'Paid', 'Overdue'];
  return ReportPreview(
    columns: columns,
    rows: [
      for (var i = 0; i < 5000; i++)
        ReportRow(
          cells: [
            ReportStringCell(value: 'Client ${rng.next(60)}'),
            ReportStringCell(value: 'INV-${10000 + i}'),
            ReportNumberCell(
              value: Decimal.fromInt(rng.next(900000)).shift(-2),
              isMoney: true,
              currencyId: '1',
            ),
            ReportNumberCell(
              value: Decimal.fromInt(rng.next(90000)).shift(-2),
              isMoney: true,
              currencyId: '1',
            ),
            ReportDateCell(
              value: Date(
                2024 + rng.next(3),
                1 + rng.next(12),
                1 + rng.next(28),
              ),
            ),
            ReportStringCell(value: statuses[rng.next(statuses.length)]),
          ],
        ),
    ],
  );
}

/// About 40 KB of the tag soup a legacy notes field carries.
String legacyHtml() {
  final buffer = StringBuffer();
  for (var i = 0; i < 120; i++) {
    buffer
      ..write('<p>Thank you for your <b>business</b>, invoice <i>#$i</i> is ')
      ..write('due on receipt.<br>Pay at <a href="https://example.com/pay/$i">')
      ..write('example.com/pay/$i</a> &amp; quote ref&nbsp;<u>R-$i</u>.</p>')
      ..write('<ul><li>Net 30 &ndash; late fee 1.5%</li><li><strong>Wire')
      ..write('</strong> or <em>card</em></li><li>Questions&#39; welcome</li>')
      ..write('</ul><div>Terms &amp; conditions apply.<br/><br/>Regards</div>');
  }
  return buffer.toString();
}

/// One invoice as `GET /invoices` returns it: [lines] line items, notes,
/// taxes, a client, dates spread over three years, and every status.
///
/// The ids are stable (`inv_<n>`, `cl_<n % clients>`), so a benchmark can seed
/// a table and later address a row by id.
Map<String, dynamic> invoiceJson(
  int n, {
  int lines = 8,
  int clients = 200,
  Lcg? rng,
}) {
  final r = rng ?? Lcg(1000 + n);
  // All in the past, so "overdue" — a comparison with today — is the same
  // set of rows every time the suite runs.
  final year = 2021 + r.next(3);
  final month = 1 + r.next(12);
  final day = 1 + r.next(28);
  String two(int v) => v.toString().padLeft(2, '0');
  final date = '$year-${two(month)}-${two(day)}';
  final due = '$year-${two(month)}-${two(day < 20 ? day + 8 : day)}';
  final amount = (100 + r.next(900000)) / 100;
  final status = 1 + r.next(4);
  return {
    'id': 'inv_$n',
    'number': '${10000 + n}',
    'po_number': n.isEven ? 'PO-${n * 3}' : '',
    'client_id': 'cl_${n % clients}',
    'status_id': '$status',
    'date': date,
    'due_date': due,
    'amount': amount,
    'balance': status == 4 ? 0 : amount,
    'paid_to_date': status == 4 ? amount : 0,
    'discount': r.next(10),
    'tax_name1': 'VAT',
    'tax_rate1': 20,
    'uses_inclusive_taxes': n % 5 == 0,
    'public_notes':
        '<p>Thank you for your business. Invoice ${10000 + n} covers '
        'the work agreed for <b>$date</b>.</p>',
    'private_notes': n % 3 == 0 ? 'Chase after ${two(day)}/${two(month)}' : '',
    'terms': 'Net 30',
    'footer': '',
    'custom_value1': n % 4 == 0 ? 'Region ${n % 7}' : '',
    'line_items': [
      for (var l = 0; l < lines; l++)
        {
          'product_key': 'SKU-${r.next(400)}',
          'notes': 'Consulting — phase ${l + 1}, ${r.next(40)} hours on site',
          'cost': (100 + r.next(50000)) / 100,
          'quantity': 1 + r.next(20),
          'tax_name1': 'VAT',
          'tax_rate1': 20,
          'discount': 0,
          'type_id': '1',
        },
    ],
    'invitations': [
      {
        'id': 'invt_$n',
        'key': 'k${n}abcdef0123456789',
        'link': 'https://example.com/client/invoice/k${n}abcdef0123456789',
        'client_contact_id': 'ct_${n % clients}',
        'sent_date': date,
        'viewed_date': status > 2 ? due : '',
        'opened_date': '',
        'email_status': 'delivered',
      },
    ],
    'is_deleted': false,
    'created_at': 1700000000 + n * 60,
    'updated_at': 1710000000 + n * 60,
    'archived_at': 0,
  };
}

/// One client as `GET /clients` returns it, with two contacts and an address.
Map<String, dynamic> clientJson(int n) {
  final r = Lcg(5000 + n);
  const cities = ['Berlin', 'Austin', 'Leeds', 'Lyon', 'Osaka', 'Toronto'];
  final name = 'Customer ${n.toString().padLeft(4, '0')} ${_surname(r)}';
  return {
    'id': 'cl_$n',
    'name': name,
    'display_name': name,
    'number': '${1000 + n}',
    'balance': (r.next(1000000) / 100).toString(),
    'paid_to_date': (r.next(9000000) / 100).toString(),
    'credit_balance': '0',
    'address1': '${1 + r.next(400)} Market Street',
    'city': cities[r.next(cities.length)],
    'postal_code': '${10000 + r.next(89999)}',
    'country_id': '840',
    'phone': '+1 555 ${100 + r.next(899)} ${1000 + r.next(8999)}',
    'website': n.isEven ? 'https://customer$n.example.com' : '',
    'vat_number': n % 3 == 0 ? 'DE${100000000 + n}' : '',
    'private_notes': n % 4 == 0 ? 'Prefers email; key account.' : '',
    'contacts': [
      for (var c = 0; c < 2; c++)
        {
          'id': 'ct_${n}_$c',
          'first_name': c == 0 ? 'Jane' : 'Sam',
          'last_name': _surname(r),
          'email': 'contact$c.$n@customer.example.com',
          'phone': '+1 555 ${100 + r.next(899)} ${1000 + r.next(8999)}',
          'is_primary': c == 0,
        },
    ],
    'settings': {'currency_id': '1'},
    'is_deleted': false,
    'created_at': 1700000000 + n * 60,
    'updated_at': 1710000000 + n * 60,
    'archived_at': 0,
  };
}

String _surname(Lcg r) {
  const names = [
    'Okafor',
    'Lindqvist',
    'Moreau',
    'Tanaka',
    'García',
    'Novak',
    'Byrne',
    'Shah',
  ];
  return names[r.next(names.length)];
}

/// The `static` catalog a `/refresh` carries — about the size of the real
/// one: 160 currencies, 250 countries, 140 timezones, 60 gateways with their
/// field definitions, and the short lists.
Map<String, dynamic> staticsJson() {
  final r = Lcg(31337);
  String word(int n) =>
      String.fromCharCodes([for (var i = 0; i < n; i++) 97 + r.next(26)]);
  return {
    'currencies': [
      for (var i = 1; i <= 160; i++)
        {
          'id': '$i',
          'name': 'Currency ${word(8)}',
          'code': word(3).toUpperCase(),
          'symbol': r'$',
          'precision': 2,
          'thousand_separator': ',',
          'decimal_separator': '.',
          'swap_currency_symbol': i.isEven,
          'exchange_rate': 1 + r.next(10000) / 100,
        },
    ],
    'countries': [
      for (var i = 1; i <= 250; i++)
        {
          'id': '$i',
          'name': 'Country ${word(10)}',
          'iso_3166_2': word(2).toUpperCase(),
          'iso_3166_3': word(3).toUpperCase(),
          'swap_postal_code': i % 5 == 0,
          'swap_currency_symbol': i % 3 == 0,
          'thousand_separator': i.isEven ? '.' : ',',
          'decimal_separator': i.isEven ? ',' : '.',
        },
    ],
    'languages': [
      for (var i = 1; i <= 45; i++)
        {'id': '$i', 'name': 'Language ${word(7)}', 'locale': word(2)},
    ],
    'timezones': [
      for (var i = 1; i <= 140; i++)
        {
          'id': '$i',
          'name': 'Region/${word(9)}',
          'location':
              '(GMT${i.isEven ? '+' : '-'}0${r.next(9)}:00) '
              '${word(8)}',
          'utc_offset': (r.next(25) - 12) * 3600,
        },
    ],
    'industries': [
      for (var i = 1; i <= 30; i++) {'id': '$i', 'name': 'Industry ${word(9)}'},
    ],
    'sizes': [
      for (var i = 1; i <= 6; i++)
        {'id': '$i', 'name': '${i * 10} - ${i * 50}'},
    ],
    'payment_types': [
      for (var i = 1; i <= 35; i++) {'id': '$i', 'name': 'Payment ${word(8)}'},
    ],
    'date_formats': [
      for (var i = 1; i <= 14; i++) {'id': '$i', 'format_dart': 'dd/MMM/yyyy'},
    ],
    'gateways': [
      for (var i = 1; i <= 60; i++)
        {
          'id': '$i',
          'key': word(32),
          'name': 'Gateway ${word(10)}',
          'site_url': 'https://${word(8)}.example.com',
          'sort_order': i,
          'is_offsite': i % 4 == 0,
          'visible': true,
          'default_gateway_type_id': '1',
          'fields': '{"apiKey":"","secretKey":"","testMode":false}',
          'options': {
            '1': {
              'refund': i.isEven,
              'token_billing': true,
              'webhooks': <String>[],
            },
          },
        },
    ],
  };
}

String _isoDate(Lcg r) {
  String two(int v) => v.toString().padLeft(2, '0');
  // All in the past, like [invoiceJson]'s, so nothing measured moves with
  // the calendar.
  return '${2021 + r.next(3)}-${two(1 + r.next(12))}-${two(1 + r.next(28))}';
}

/// One expense as `GET /expenses` returns it.
Map<String, dynamic> expenseJson(int n) {
  final r = Lcg(7000 + n);
  return {
    'id': 'exp_$n',
    'number': '${5000 + n}',
    'date': _isoDate(r),
    'amount': (100 + r.next(500000)) / 100,
    'vendor_id': n.isEven ? 'vn_${n % 50}' : '',
    'client_id': n % 3 == 0 ? 'cl_${n % 200}' : '',
    'category_id': 'cat_${n % 12}',
    'currency_id': '1',
    'public_notes': 'Travel and materials for job ${n % 300}',
    'private_notes': n % 4 == 0 ? 'Reimburse via payroll' : '',
    'payment_date': n % 5 == 0 ? _isoDate(r) : '',
    'transaction_reference': n % 7 == 0 ? 'TX-${100000 + n}' : '',
    'tax_name1': 'VAT',
    'tax_rate1': 20,
    'should_be_invoiced': n.isOdd,
    'is_deleted': false,
    'created_at': 1700000000 + n * 60,
    'updated_at': 1710000000 + n * 60,
    'archived_at': 0,
  };
}

/// One payment as `GET /payments` returns it, applied to two invoices.
Map<String, dynamic> paymentJson(int n) {
  final r = Lcg(8000 + n);
  final amount = (100 + r.next(900000)) / 100;
  return {
    'id': 'pay_$n',
    'number': '${3000 + n}',
    'date': _isoDate(r),
    'amount': amount,
    'applied': amount,
    'refunded': 0,
    'status_id': '4',
    'type_id': '${1 + r.next(30)}',
    'client_id': 'cl_${n % 200}',
    'currency_id': '1',
    'transaction_reference': 'ch_${n}abcdef${r.next(99999)}',
    'private_notes': n % 6 == 0 ? 'Paid by phone' : '',
    'paymentables': [
      for (var p = 0; p < 2; p++)
        {
          'id': 'pbl_${n}_$p',
          'invoice_id': 'inv_${(n + p) % 5000}',
          'amount': amount / 2,
          'refunded': 0,
          'created_at': 1700000000 + n * 60,
          'updated_at': 1700000000 + n * 60,
        },
    ],
    'is_deleted': false,
    'created_at': 1700000000 + n * 60,
    'updated_at': 1710000000 + n * 60,
    'archived_at': 0,
  };
}

/// One product as `GET /products` returns it.
Map<String, dynamic> productJson(int n) {
  final r = Lcg(9000 + n);
  return {
    'id': 'prd_$n',
    'product_key': 'SKU-${(n * 7919) % 100000}',
    'notes': 'Consulting service tier ${n % 9}, billed per hour on site',
    'cost': (100 + r.next(20000)) / 100,
    'price': (200 + r.next(40000)) / 100,
    'quantity': 1,
    'tax_name1': 'VAT',
    'tax_rate1': 20,
    'in_stock_quantity': r.next(500),
    'is_deleted': false,
    'created_at': 1700000000 + n * 60,
    'updated_at': 1710000000 + n * 60,
    'archived_at': 0,
  };
}

/// One bank transaction as `GET /bank_transactions` returns it.
Map<String, dynamic> bankTransactionJson(int n) {
  final r = Lcg(11000 + n);
  return {
    'id': 'btx_$n',
    'date': _isoDate(r),
    'amount': (100 + r.next(500000)) / 100,
    'currency_id': '1',
    'description': 'CARD PAYMENT ${r.next(99999)} MERCHANT ${n % 400}',
    'participant_name': 'Merchant ${n % 400}',
    'base_type': n.isEven ? 'DEBIT' : 'CREDIT',
    'category_type': 'Expense',
    'status_id': '${1 + r.next(3)}',
    'bank_integration_id': 'bi_${n % 3}',
    'is_deleted': false,
    'created_at': 1700000000 + n * 60,
    'updated_at': 1710000000 + n * 60,
    'archived_at': 0,
  };
}
