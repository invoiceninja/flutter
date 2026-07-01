import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/reports/report_column_types.dart';

void main() {
  group('inferColumnType', () {
    test('inventory count columns are numeric (sortable + totalled)', () {
      // `in_stock_quantity` / `max_quantity` previously fell through to string,
      // which broke the Product report's on-hand-stock total and the synthetic
      // stock_value (which reads the in_stock_quantity ReportNumberCell).
      for (final id in const [
        'in_stock_quantity',
        'product.in_stock_quantity',
        'max_quantity',
      ]) {
        expect(
          inferColumnType(id),
          ReportColumnType.number,
          reason: '$id should be number',
        );
        expect(isAggregatable(inferColumnType(id)), isTrue);
      }
    });

    test('custom surcharge columns are money (regression for totals)', () {
      // `*.custom_surcharge1..4` must sum in totals + right-align + numeric
      // filter. Previously fell through to string. Parity with admin-portal.
      for (final id in const [
        'invoice.custom_surcharge1',
        'invoice.custom_surcharge2',
        'quote.custom_surcharge3',
        'recurring_invoice.custom_surcharge4',
      ]) {
        expect(
          inferColumnType(id),
          ReportColumnType.money,
          reason: '$id should be money',
        );
        expect(isAggregatable(inferColumnType(id)), isTrue);
      }
    });

    test('custom_surcharge_taxes columns are NOT money', () {
      // `custom_surcharge_taxes1..4` are booleans, not amounts — they must not
      // be summed/right-aligned as money. Guards against a broad surcharge
      // substring match.
      for (final id in const [
        'invoice.custom_surcharge_taxes1',
        'invoice.custom_surcharge_taxes2',
      ]) {
        expect(
          inferColumnType(id),
          isNot(ReportColumnType.money),
          reason: '$id must not be money',
        );
        expect(isAggregatable(inferColumnType(id)), isFalse);
      }
    });

    test('money columns', () {
      for (final id in const [
        'invoice.amount',
        'client.balance',
        'invoice.paid_to_date',
        'payment.refunded',
        'invoice.tax_total',
      ]) {
        expect(inferColumnType(id), ReportColumnType.money, reason: id);
      }
    });

    test('date vs dateTime', () {
      expect(inferColumnType('client.created_at'), ReportColumnType.dateTime);
      expect(inferColumnType('invoice.date'), ReportColumnType.date);
      expect(inferColumnType('invoice.due_date'), ReportColumnType.date);
    });

    test('age / duration', () {
      expect(inferColumnType('invoice.age'), ReportColumnType.age);
      expect(inferColumnType('task.duration'), ReportColumnType.duration);
      // Age is intentionally NOT aggregatable — a "sum of ages" is meaningless.
      // Duration still sums (e.g. total time logged).
      expect(isAggregatable(ReportColumnType.age), isFalse);
      expect(isAggregatable(ReportColumnType.duration), isTrue);
    });

    test('identifier-style numerics stay string (lexicographic)', () {
      expect(inferColumnType('invoice.number'), ReportColumnType.string);
      expect(inferColumnType('client.vat_number'), ReportColumnType.string);
    });

    test('plain numerics and booleans', () {
      expect(inferColumnType('task.hours'), ReportColumnType.number);
      expect(inferColumnType('product.quantity'), ReportColumnType.number);
      expect(inferColumnType('client.is_active'), ReportColumnType.boolean);
    });
  });
}
