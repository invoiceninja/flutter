import 'package:admin/data/models/domain/dashboard/dashboard_totals.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/ui/features/dashboard/helpers/totals_math.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression coverage for the "All currencies" selection fix: when no explicit
/// currency key is passed, `selectCurrencyTotals` must return the server's
/// exchange-rate-converted `999` bucket (not an arbitrary first currency), and
/// fall back to the sole currency for single-currency companies that omit it.
///
/// Fixture mirrors the probe-confirmed `POST /api/v1/charts/totals_v2` shape:
/// a `currencies` label map plus per-currency-id buckets, including `999`.
DashboardTotals _totals(Map<String, dynamic> extraBuckets) {
  return DashboardTotals.fromJson({
    'currencies': {'1': 'USD', '2': 'GBP', '3': 'EUR'},
    '1': {
      'invoices': {'invoiced_amount': '11705.00', 'code': 'USD'},
      'revenue': {'paid_to_date': '3457.00', 'code': 'USD'},
      'outstanding': {
        'amount': '8248.00',
        'outstanding_count': 4,
        'code': 'USD',
      },
      'expenses': {'amount': '25.00', 'code': 'USD'},
    },
    '2': {
      'invoices': {'invoiced_amount': '186363.00', 'code': 'GBP'},
      'revenue': {'paid_to_date': '176561.00', 'code': 'GBP'},
      'outstanding': {
        'amount': '9802.00',
        'outstanding_count': 4,
        'code': 'GBP',
      },
      'expenses': <String, dynamic>{},
    },
    ...extraBuckets,
  });
}

void main() {
  group('selectCurrencyTotals', () {
    test('null key returns the server-converted 999 bucket', () {
      final totals = _totals({
        '999': {
          'invoices': {'invoiced_amount': '216108.00'},
          'revenue': {'paid_to_date': '180018.00'},
          'outstanding': {'amount': '23992.00', 'outstanding_count': 11},
          'expenses': {'amount': '8.78'},
        },
      });

      final selected = selectCurrencyTotals(totals, null);

      expect(selected, isNotNull);
      expect(selected!.outstandingCount, 11);
      // 999 amounts must win over currency "1" / "2" buckets.
      expect(selected.outstandingAmount.toString(), '23992');
      expect(selected.revenuePaidToDate.toString(), '180018');
    });

    test('null key falls back to the sole currency when 999 is absent', () {
      final totals = DashboardTotals.fromJson({
        'currencies': {'2': 'GBP'},
        '2': {
          'invoices': {'invoiced_amount': '186363.00', 'code': 'GBP'},
          'revenue': {'paid_to_date': '176561.00', 'code': 'GBP'},
          'outstanding': {
            'amount': '9802.00',
            'outstanding_count': 4,
            'code': 'GBP',
          },
          'expenses': <String, dynamic>{},
        },
      });

      final selected = selectCurrencyTotals(totals, null);

      expect(selected, isNotNull);
      expect(selected!.code, 'GBP');
      expect(selected.outstandingCount, 4);
    });

    test('explicit key returns that currency, not 999', () {
      final totals = _totals({
        '999': {
          'outstanding': {'amount': '23992.00', 'outstanding_count': 11},
        },
      });

      final selected = selectCurrencyTotals(totals, '2');

      expect(selected, isNotNull);
      expect(selected!.code, 'GBP');
      expect(selected.outstandingCount, 4);
    });

    test('returns null for null or empty totals', () {
      expect(selectCurrencyTotals(null, null), isNull);
      expect(
        selectCurrencyTotals(
          DashboardTotals.fromJson({'currencies': <String, dynamic>{}}),
          null,
        ),
        isNull,
      );
    });
  });

  group('selectedCurrencyKey', () {
    test('"All currencies" maps to null (the server-converted bucket)', () {
      expect(selectedCurrencyKey(kDashboardCurrencyAll), isNull);
    });

    test('a specific currency maps to its string bucket key', () {
      expect(selectedCurrencyKey(2), '2');
    });
  });

  /// flutter#22: a single-currency company was told its untouched totals were
  /// "Converted to <its own currency>". The server's `currencies` map always
  /// carries the company currency, so one entry means nothing can convert.
  group('hasForeignCurrency', () {
    DashboardTotals currencies(Map<String, String> map) =>
        DashboardTotals.fromJson({'currencies': map});

    test('true when a non-base currency is present', () {
      expect(
        hasForeignCurrency(currencies(const {'2': 'GBP', '3': 'EUR'}), '2'),
        isTrue,
      );
    });

    test('false for a single-currency company — the flutter#22 case', () {
      expect(hasForeignCurrency(currencies(const {'2': 'GBP'}), '2'), isFalse);
    });

    test('false while totals are loading', () {
      expect(hasForeignCurrency(null, '2'), isFalse);
    });

    test('false when the server omits the currencies map', () {
      final totals = DashboardTotals.fromJson({
        '2': {
          'outstanding': {'amount': '9802.00'},
        },
      });
      expect(hasForeignCurrency(totals, '2'), isFalse);
    });

    test('a stray 999 aggregate key does not fake a foreign currency', () {
      expect(
        hasForeignCurrency(currencies(const {'2': 'GBP', '999': 'All'}), '2'),
        isFalse,
      );
    });

    test('true when the only currency is a foreign one', () {
      expect(hasForeignCurrency(currencies(const {'3': 'EUR'}), '2'), isTrue);
    });
  });
}
