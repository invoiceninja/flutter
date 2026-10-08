import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/report_preview_api_model.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/value/money.dart';

Decimal d(String v) => Decimal.parse(v);

/// One-row preview of [cells], keyed by column identifier → raw `value`.
ReportPreview _decode(
  Map<String, Object?> cells, {
  FormattedNumberStyle? style,
}) {
  final ids = cells.keys.toList();
  return decodeReportPreview({
    'columns': [
      for (final id in ids) {'identifier': id, 'display_value': id},
    ],
    '0': [
      for (final id in ids)
        {
          'identifier': id,
          'value': cells[id],
          'display_value': cells[id],
          'entity': id.split('.').first,
          'id': id.split('.').last,
          'hashed_id': null,
        },
    ],
  }, numberStyle: style);
}

Decimal? _amount(ReportPreview p, [int i = 0]) =>
    (p.rows.single.cells[i] as ReportNumberCell).value;

void main() {
  final us = FormattedNumberStyle(
    thousandSeparator: ',',
    decimalSeparator: '.',
    precision: 2,
  );
  final eu = FormattedNumberStyle(
    thousandSeparator: '.',
    decimalSeparator: ',',
    precision: 2,
  );
  // A currency with no decimals and a `.` grouping separator — CLP.
  final clp = FormattedNumberStyle(
    thousandSeparator: '.',
    decimalSeparator: ',',
    precision: 0,
  );

  group('numbers are read with the company currency format', () {
    test('a grouped amount', () {
      expect(
        _amount(_decode({'invoice.amount': '2,949.00'}, style: us)),
        d('2949.00'),
      );
      expect(
        _amount(_decode({'invoice.amount': '2.949,00'}, style: eu)),
        d('2949.00'),
      );
    });

    test('a zero-decimal currency does not read its grouping as a decimal', () {
      // `Decimal.tryParse("1.234")` is 1.234 — the bug this style exists for.
      expect(
        _amount(_decode({'invoice.amount': '1.234'}, style: clp)),
        d('1234'),
      );
      expect(
        _amount(_decode({'invoice.amount': '12.345.678'}, style: clp)),
        d('12345678'),
      );
    });

    test('a raw decimal the export did not format is left alone', () {
      // The recurring-invoice report sends its amounts unformatted
      // ("4544.000000", probed live). Under a `.`-grouping style that must
      // not become four and a half billion.
      expect(
        _amount(
          _decode({'recurring_invoice.amount': '4544.000000'}, style: eu),
        ),
        d('4544'),
      );
      expect(
        _amount(
          _decode({'recurring_invoice.amount': '4544.000000'}, style: clp),
        ),
        d('4544'),
      );
      expect(
        _amount(
          _decode({'recurring_invoice.amount': '4544.000000'}, style: us),
        ),
        d('4544'),
      );
    });

    test('a JSON number passes straight through', () {
      // Whole floats arrive as ints (`item.cost`, `task.rate`).
      expect(_amount(_decode({'item.cost': 741}, style: eu)), d('741'));
      expect(_amount(_decode({'item.cost': 12.5}, style: eu)), d('12.5'));
    });

    test('negative amounts', () {
      expect(
        _amount(_decode({'credit.amount': '-1,250.50'}, style: us)),
        d('-1250.50'),
      );
      expect(
        _amount(_decode({'credit.amount': '-1.250,50'}, style: eu)),
        d('-1250.50'),
      );
    });

    test('with no style the format-agnostic parse still applies', () {
      expect(_amount(_decode({'invoice.amount': '3,238.00'})), d('3238.00'));
      expect(_amount(_decode({'invoice.amount': '3.238,00'})), d('3238.00'));
    });
  });

  group('blank is not zero', () {
    test('an empty numeric cell has no value', () {
      // `payment.applied_amount` on a payment applied to nothing.
      final p = _decode({'payment.applied_amount': ''}, style: us);
      expect(_amount(p), isNull);
    });

    test('a word in an amount column has no value, and keeps its text', () {
      // `PaymentDecorator::amount` answers "Unpaid" for an unpaid invoice.
      final p = _decode({'payment.amount': 'Unpaid'}, style: us);
      expect(_amount(p), isNull);
      expect(p.rows.single.cells.single.displayValue, 'Unpaid');
    });

    test('a real zero is still zero', () {
      expect(
        _amount(_decode({'invoice.balance': '0.00'}, style: us)),
        d('0.00'),
      );
      expect(
        _amount(_decode({'expense.foreign_amount': 0}, style: us)),
        d('0'),
      );
    });
  });

  group('record ids', () {
    test('a related cell carries hashed_id; the field name is ignored', () {
      final p = decodeReportPreview({
        'columns': [
          {'identifier': 'client.name', 'display_value': 'Client'},
          {'identifier': 'invoice.number', 'display_value': 'Number'},
        ],
        '0': [
          {
            'value': 'ACME',
            'display_value': 'ACME',
            'entity': 'client',
            'id': 'name',
            'hashed_id': 'mxkazYeJ0P',
          },
          {
            'value': '0001',
            'display_value': '0001',
            'entity': 'invoice',
            'id': 'number',
            'hashed_id': null,
          },
        ],
      });
      final row = p.rows.single;
      expect(row.cells[0].entityId, 'mxkazYeJ0P');
      expect(row.cells[1].entityId, isNull);
      expect(row.recordId, isNull);
      expect(row.recordWire, isNull);
    });

    test('an empty hashed_id is no id', () {
      final p = decodeReportPreview({
        'columns': [
          {'identifier': 'client.name', 'display_value': 'Client'},
        ],
        '0': [
          {'value': 'ACME', 'entity': 'client', 'id': 'name', 'hashed_id': ''},
        ],
      });
      expect(p.rows.single.cells.single.entityId, isNull);
    });
  });
}
