import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/domain/reports/report_engine.dart';
import 'package:admin/domain/reports/report_row_currency.dart';

Decimal d(String s) => Decimal.parse(s);

ReportView _compute(ReportPreview preview, {ReportUiState? ui}) =>
    const ReportEngine().compute(
      preview: preview,
      ui: ui ?? const ReportUiState(),
      exchangeRates: const {},
      companyCurrencyId: '1',
    );

const _client = ReportColumn(
  identifier: 'client.name',
  displayLabel: 'Client',
  type: ReportColumnType.string,
);
const _currency = ReportColumn(
  identifier: 'client.currency_id',
  displayLabel: 'Currency',
  type: ReportColumnType.string,
);
const _amount = ReportColumn(
  identifier: 'invoice.amount',
  displayLabel: 'Amount',
  type: ReportColumnType.money,
);

ReportNumberCell _money(String v) =>
    ReportNumberCell(value: d(v), isMoney: true);

void main() {
  group('the row names the currency', () {
    // The server sends an ISO code in a column of the row and nothing on the
    // cell (probed live: `client.currency_id: "EUR"`).
    final preview = withRowCurrencies(
      ReportPreview(
        columns: const [_client, _currency, _amount],
        rows: [
          ReportRow(
            cells: [
              const ReportStringCell(value: 'Zemlak'),
              const ReportStringCell(value: 'EUR'),
              _money('521.00'),
            ],
          ),
          ReportRow(
            cells: [
              const ReportStringCell(value: 'Oberbrunner'),
              const ReportStringCell(value: 'USD'),
              _money('2949.00'),
            ],
          ),
          ReportRow(
            cells: [
              const ReportStringCell(value: 'Price-Adams'),
              const ReportStringCell(value: 'USD'),
              _money('100.00'),
            ],
          ),
        ],
      ),
      currencyIdByCode: const {'USD': '1', 'EUR': '3'},
      fallbackCurrencyId: '1',
    );

    test('each row is stamped from its own code', () {
      expect(preview.rows.map((r) => r.currencyId), ['3', '1', '1']);
    });

    test('totals are per currency, never across them', () {
      final view = _compute(preview);
      // It used to be one bucket — `''` — holding 3,570.00 of nothing.
      expect(view.grandTotalsByCurrency['invoice.amount'], {
        '3': d('521.00'),
        '1': d('3049.00'),
      });
      expect(view.rowCountByCurrency, {'3': 1, '1': 2});
    });

    test('a group keeps its currencies apart too', () {
      final view = _compute(
        preview,
        ui: const ReportUiState(group: 'client.currency_id'),
      );
      expect(view.groups.map((g) => g.key), ['EUR', 'USD']);
      expect(view.groups.last.numericTotals['invoice.amount'], {
        '1': d('3049.00'),
      });
    });

    test('a code is matched whatever its case or padding', () {
      final p = withRowCurrencies(
        ReportPreview(
          columns: const [_currency, _amount],
          rows: [
            ReportRow(
              cells: [
                const ReportStringCell(value: ' eur '),
                _money('1'),
              ],
            ),
          ],
        ),
        currencyIdByCode: const {'EUR': '3'},
      );
      expect(p.rows.single.currencyId, '3');
    });

    test('an unknown or blank code falls back to the company currency', () {
      final p = withRowCurrencies(
        ReportPreview(
          columns: const [_currency, _amount],
          rows: [
            ReportRow(
              cells: [
                const ReportStringCell(value: 'XXX'),
                _money('1'),
              ],
            ),
            ReportRow(
              cells: [
                const ReportStringCell(value: ''),
                _money('2'),
              ],
            ),
          ],
        ),
        currencyIdByCode: const {'USD': '1'},
        fallbackCurrencyId: '1',
      );
      expect(p.rows.map((r) => r.currencyId), ['1', '1']);
    });

    test('a report with no currency column takes the fallback', () {
      // Tasks and products name no currency at all.
      final p = withRowCurrencies(
        ReportPreview(
          columns: const [_amount],
          rows: [
            ReportRow(cells: [_money('5')]),
          ],
        ),
        currencyIdByCode: const {'USD': '1'},
        fallbackCurrencyId: '1',
      );
      expect(p.rows.single.currencyId, '1');
    });

    test('with nothing to go on the preview is returned untouched', () {
      final p = ReportPreview(
        columns: const [_amount],
        rows: [
          ReportRow(cells: [_money('5')]),
        ],
      );
      expect(
        identical(withRowCurrencies(p, currencyIdByCode: const {}), p),
        isTrue,
      );
    });

    test('quantities and hours bucket with their row, not under ""', () {
      // "USD" has to mean the same rows whichever column is read.
      const qty = ReportColumn(
        identifier: 'item.quantity',
        displayLabel: 'Qty',
        type: ReportColumnType.number,
      );
      final view = _compute(
        ReportPreview(
          columns: const [_amount, qty],
          rows: [
            ReportRow(
              currencyId: '1',
              cells: [
                _money('10'),
                ReportNumberCell(value: d('2')),
              ],
            ),
            ReportRow(
              currencyId: '3',
              cells: [
                _money('20'),
                ReportNumberCell(value: d('5')),
              ],
            ),
          ],
        ),
      );
      expect(view.grandTotalsByCurrency['item.quantity'], {
        '1': d('2'),
        '3': d('5'),
      });
    });
  });

  group('the currency column', () {
    ReportColumn col(String id) => ReportColumn(
      identifier: id,
      displayLabel: id,
      type: ReportColumnType.string,
    );

    test('is the one named currency_id', () {
      expect(
        reportCurrencyColumnIndex([
          col('client.name'),
          col('client.currency_id'),
        ]),
        1,
      );
    });

    test('never the currency an expense was invoiced in', () {
      // `expense.invoice_currency_id` is blank on most rows and is about a
      // different amount.
      expect(
        reportCurrencyColumnIndex([
          col('expense.invoice_currency_id'),
          col('expense.amount'),
          col('expense.currency_id'),
        ]),
        2,
      );
      expect(
        reportCurrencyColumnIndex([col('expense.invoice_currency_id')]),
        -1,
      );
    });

    test('payments and vendors call it currency', () {
      expect(
        reportCurrencyColumnIndex([
          col('payment.amount'),
          col('payment.currency'),
        ]),
        1,
      );
      expect(reportCurrencyColumnIndex([col('vendor.currency')]), 0);
    });

    test('tasks and products have none', () {
      expect(
        reportCurrencyColumnIndex([col('task.duration'), col('task.rate')]),
        -1,
      );
    });
  });

  group('what gets totalled', () {
    ReportColumn num(
      String id, [
      ReportColumnType t = ReportColumnType.number,
    ]) => ReportColumn(identifier: id, displayLabel: id, type: t);

    test('a rate, a unit price and a discount are not', () {
      for (final id in const [
        'invoice.tax_rate1',
        'invoice.exchange_rate',
        'payment.exchange_rate',
        'task.rate',
        'item.cost',
        'item.product_cost',
        'price',
        'cost',
        'invoice.discount',
        'max_quantity',
      ]) {
        final type = inferColumnType(id);
        expect(
          defaultReportAggregation(id, type),
          ReportAggregation.none,
          reason: id,
        );
      }
    });

    test('an amount, a quantity and a duration are', () {
      for (final id in const [
        'invoice.amount',
        'invoice.balance',
        'item.line_total',
        'item.quantity',
        'in_stock_quantity',
        'task.duration',
        'expense.net_amount',
      ]) {
        expect(
          defaultReportAggregation(id, inferColumnType(id)),
          ReportAggregation.sum,
          reason: id,
        );
      }
    });

    test('a text or date column never is', () {
      expect(
        defaultReportAggregation('invoice.number', ReportColumnType.string),
        ReportAggregation.none,
      );
      expect(
        defaultReportAggregation('invoice.date', ReportColumnType.date),
        ReportAggregation.none,
      );
    });

    test('the engine leaves an untotalled column out of the totals', () {
      final rate = num('invoice.tax_rate1');
      final view = _compute(
        ReportPreview(
          columns: [_amount, rate],
          rows: [
            ReportRow(
              cells: [
                _money('100'),
                ReportNumberCell(value: d('7.5')),
              ],
            ),
            ReportRow(
              cells: [
                _money('50'),
                ReportNumberCell(value: d('7.5')),
              ],
            ),
          ],
        ),
      );
      expect(view.grandTotalsByCurrency.keys, ['invoice.amount']);
    });
  });

  group('a parent record repeated on every line', () {
    // `InvoiceItemExport` merges the whole invoice into each of its lines:
    // probed live, invoice 0025 (4,806.00) arrives on ten rows.
    const invoiceAmount = ReportColumn(
      identifier: 'invoice.amount',
      displayLabel: 'Amount',
      type: ReportColumnType.money,
      aggregation: ReportAggregation.oncePerRecord,
    );
    const lineTotal = ReportColumn(
      identifier: 'item.line_total',
      displayLabel: 'Line Total',
      type: ReportColumnType.money,
    );

    ReportRow line(String? invoiceId, String amount, String line) => ReportRow(
      recordWire: 'invoice',
      recordId: invoiceId,
      cells: [_money(amount), _money(line)],
    );

    test('is counted once per record', () {
      final view = _compute(
        ReportPreview(
          columns: const [invoiceAmount, lineTotal],
          rows: [
            line('inv25', '4806', '741'),
            line('inv25', '4806', '521'),
            line('inv25', '4806', '3544'),
            line('inv26', '100', '100'),
          ],
        ),
      );
      // Not 14,518.
      expect(view.grandTotalsByCurrency['invoice.amount'], {'': d('4906')});
      // The line's own figure is still a plain sum.
      expect(view.grandTotalsByCurrency['item.line_total'], {'': d('4906')});
    });

    test('is not totalled at all when the rows carry no record id', () {
      // A total ten times too large is worse than no total.
      final view = _compute(
        ReportPreview(
          columns: const [invoiceAmount, lineTotal],
          rows: [line(null, '4806', '741'), line(null, '4806', '521')],
        ),
      );
      expect(view.grandTotalsByCurrency.containsKey('invoice.amount'), isFalse);
      expect(view.grandTotalsByCurrency['item.line_total'], {'': d('1262')});
    });

    test('a group counts each of its own records once', () {
      const product = ReportColumn(
        identifier: 'item.product_key',
        displayLabel: 'Product',
        type: ReportColumnType.string,
      );
      ReportRow row(String id, String amount, String key) => ReportRow(
        recordWire: 'invoice',
        recordId: id,
        cells: [
          _money(amount),
          ReportStringCell(value: key),
        ],
      );
      final view = _compute(
        ReportPreview(
          columns: const [invoiceAmount, product],
          rows: [
            row('a', '100', 'Widget'),
            row('a', '100', 'Widget'),
            row('b', '40', 'Widget'),
            row('a', '100', 'Gadget'),
          ],
        ),
        ui: const ReportUiState(group: 'item.product_key'),
      );
      final byKey = {for (final g in view.groups) g.key: g};
      expect(byKey['Widget']!.numericTotals['invoice.amount'], {'': d('140')});
      expect(byKey['Gadget']!.numericTotals['invoice.amount'], {'': d('100')});
    });
  });
}
