import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/domain/reports/report_registry.dart';
import 'package:admin/domain/reports/report_related_columns.dart';
import 'package:admin/domain/reports/report_row_currency.dart';

ReportColumn _col(String id) =>
    ReportColumn(identifier: id, displayLabel: id, type: inferColumnType(id));

void main() {
  group('the catalog', () {
    test('names only server reports that exist', () {
      for (final report in kReportRelatedColumns.keys) {
        final definition = kReportDefinitions
            .where((d) => d.identifier == report)
            .firstOrNull;
        expect(definition, isNotNull, reason: report);
        // A report built on the device has no server to ask for a column.
        expect(definition!.isLocal, isFalse, reason: report);
        expect(definition.readsAsDocument, isFalse, reason: report);
      }
    });

    test('every label is a bundled translation', () {
      final en =
          jsonDecode(File('assets/i18n/en.json').readAsStringSync())
              as Map<String, dynamic>;
      for (final groups in kReportRelatedColumns.values) {
        for (final group in groups) {
          expect(en[group.labelKey], isNotNull, reason: group.labelKey);
          for (final column in group.columns) {
            expect(en[column.labelKey], isNotNull, reason: column.id);
          }
        }
      }
    });

    test('no column is offered twice on one report', () {
      for (final entry in kReportRelatedColumns.entries) {
        final ids = [
          for (final group in entry.value)
            for (final column in group.columns) column.id,
        ];
        expect(ids.toSet().length, ids.length, reason: entry.key);
      }
    });

    // `ClientDecorator::assigned_user` prints the client's creator.
    test('leaves out the client field the server gets wrong', () {
      expect(
        reportRelatedColumnIds('payment'),
        isNot(contains('client.assigned_user')),
      );
    });

    // `invoice.number` makes `PaymentExport` write a row per applied
    // invoice, so the payment's own amount would repeat on each.
    test('offers nothing that changes what a row is', () {
      for (final report in kReportRelatedColumns.keys) {
        for (final id in reportRelatedColumnIds(report)) {
          expect(
            id.startsWith('invoice.') || id.startsWith('credit.'),
            isFalse,
            reason: '$report: $id',
          );
        }
      }
    });

    // `VendorContactDecorator` reads only `$entity->contacts`, which neither
    // an expense nor a purchase order has: every row would be blank.
    test('no report offers the vendor contact', () {
      for (final report in kReportRelatedColumns.keys) {
        expect(
          reportRelatedColumnIds(
            report,
          ).where((id) => id.startsWith('vendor_contact.')),
          isEmpty,
          reason: report,
        );
      }
    });

    // A cell shows in its row's currency; a client's figures are in the
    // client's, which is the row's only on a billing document or a payment.
    test(
      'a client\'s money is offered only where the row is in its currency',
      () {
        expect(reportRelatedColumnIds('payment'), contains('client.balance'));
        expect(
          reportRelatedColumnIds('invoice_item'),
          contains('client.balance'),
        );
        for (final report in ['task', 'expense']) {
          final money = reportRelatedColumnIds(
            report,
          ).where((id) => inferColumnType(id) == ReportColumnType.money);
          expect(money, isEmpty, reason: report);
          expect(reportRelatedColumnIds(report), contains('client.city'));
        }
      },
    );

    // `ContactDecorator` falls through to the vendor's contact on an expense
    // with no client.
    test('the expense report offers no client contact', () {
      final ids = reportRelatedColumnIds('expense');
      expect(ids, contains('client.city'));
      expect(ids.where((id) => id.startsWith('contact.')), isEmpty);
    });
  });

  group('withRelatedColumnsUntotalled', () {
    final preview = ReportPreview(
      columns: [
        _col('payment.amount'),
        _col('client.balance'),
        _col('client.city'),
      ],
      rows: [
        ReportRow(
          cells: [
            ReportNumberCell(value: Decimal.fromInt(10), isMoney: true),
            ReportNumberCell(value: Decimal.fromInt(500), isMoney: true),
            const ReportStringCell(value: 'Paris'),
          ],
        ),
      ],
    );

    test('a client figure is shown per row and never added up', () {
      final out = withRelatedColumnsUntotalled(
        preview,
        reportRelatedColumnIds('payment'),
      );
      expect(out.columns[1].effectiveAggregation, ReportAggregation.none);
      // The row's own amount is still totalled.
      expect(out.columns[0].effectiveAggregation, ReportAggregation.sum);
      expect(out.columns[2], preview.columns[2]);
    });

    test('a report with nothing to add is passed through', () {
      expect(
        identical(withRelatedColumnsUntotalled(preview, {}), preview),
        isTrue,
      );
    });
  });

  group('the row currency', () {
    // An exact `currency_id` tail outranks `payment.currency`, so an added
    // client currency would take over the payment report's amounts.
    test('an added related currency does not name the row currency', () {
      final columns = [_col('payment.currency'), _col('client.currency_id')];
      expect(reportCurrencyColumnIndex(columns), 1);
      expect(
        reportCurrencyColumnIndex(columns, ignoring: {'client.currency_id'}),
        0,
      );
    });
  });
}
