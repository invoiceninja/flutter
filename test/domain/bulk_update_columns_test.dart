import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/bulk_update_columns.dart';

void main() {
  group('availableBulkUpdateColumns', () {
    test("offers the server's whitelist, in its order", () {
      expect(
        availableBulkUpdateColumns(
          kBulkUpdateTask,
          serverColumns: ['status_id', 'client_id', 'project_id'],
          enabledTaxRates: 0,
          customFieldLabels: const {},
        ),
        ['status_id', 'client_id', 'project_id'],
      );
    });

    test('drops a column this build cannot render', () {
      expect(
        availableBulkUpdateColumns(
          kBulkUpdateTask,
          serverColumns: ['status_id', 'brand_new_column'],
          enabledTaxRates: 0,
          customFieldLabels: const {},
        ),
        ['status_id'],
      );
    });

    // Picking Auto Bill sends both; offering the flag alone would let a user
    // set it against the mode.
    test('never offers auto_bill_enabled on its own', () {
      expect(
        availableBulkUpdateColumns(
          kBulkUpdateRecurringInvoice,
          serverColumns: ['auto_bill', 'auto_bill_enabled'],
          enabledTaxRates: 0,
          customFieldLabels: const {},
        ),
        ['auto_bill'],
      );
    });

    test('offers only the tax slots the company has turned on', () {
      expect(
        availableBulkUpdateColumns(
          kBulkUpdateExpense,
          serverColumns: ['tax1', 'tax2', 'tax3'],
          enabledTaxRates: 2,
          customFieldLabels: const {},
        ),
        ['tax1', 'tax2'],
      );
    });

    test('offers a custom slot only once it has a label', () {
      expect(
        availableBulkUpdateColumns(
          kBulkUpdateExpense,
          serverColumns: ['custom_value1', 'custom_value2'],
          enabledTaxRates: 0,
          customFieldLabels: const {'expense1': '', 'expense2': 'Cost centre'},
        ),
        ['custom_value2'],
      );
    });

    test("a recurring invoice's custom slots are the invoice's", () {
      expect(
        availableBulkUpdateColumns(
          kBulkUpdateRecurringInvoice,
          serverColumns: ['custom_value1'],
          enabledTaxRates: 0,
          customFieldLabels: const {'invoice1': 'PO ref'},
        ),
        ['custom_value1'],
      );
    });

    test('with no server catalog: the legacy client list, nothing else', () {
      expect(
        availableBulkUpdateColumns(
          kBulkUpdateClient,
          serverColumns: null,
          enabledTaxRates: 0,
          customFieldLabels: const {},
        ),
        ['public_notes', 'industry_id', 'size_id', 'country_id'],
      );
      expect(
        availableBulkUpdateColumns(
          kBulkUpdateTask,
          serverColumns: null,
          enabledTaxRates: 0,
          customFieldLabels: const {},
        ),
        isEmpty,
      );
    });
  });

  test('expense notes are plain text; the others are rich text', () {
    expect(
      bulkUpdateValueKind(kBulkUpdateExpense, 'public_notes'),
      BulkUpdateValueKind.text,
    );
    expect(
      bulkUpdateValueKind(kBulkUpdateRecurringInvoice, 'public_notes'),
      BulkUpdateValueKind.html,
    );
    expect(
      bulkUpdateValueKind(kBulkUpdateClient, 'public_notes'),
      BulkUpdateValueKind.html,
    );
  });

  test('a tax value round-trips through name||rate', () {
    final value = bulkUpdateTaxValue('VAT', 17.5);
    expect(value, 'VAT||17.5');
    expect(parseBulkUpdateTaxValue(value), (name: 'VAT', rate: '17.5'));
    expect(parseBulkUpdateTaxValue('no separator'), isNull);
  });

  // Every column the server whitelists (v5-develop, 2026-10) that this app
  // renders must be labelled by a real string, never its raw slug.
  test('every offered column has a translated label', () {
    Map<String, dynamic> read(String path) =>
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final en = read('assets/i18n/en.json');
    final pending = read('assets/i18n/_app_pending.json');
    const whitelists = {
      kBulkUpdateClient: kLegacyClientBulkUpdateColumns,
      kBulkUpdateTask: [
        'status_id',
        'client_id',
        'project_id',
        'assigned_user_id',
      ],
      kBulkUpdateExpense: [
        'tax1', 'tax2', 'tax3', 'uses_inclusive_taxes', 'private_notes', //
        'public_notes', 'should_be_invoiced', 'project_id', 'client_id',
      ],
      kBulkUpdateRecurringInvoice: [
        'tax1', 'tax2', 'tax3', 'uses_inclusive_taxes', 'private_notes', //
        'public_notes', 'terms', 'footer', 'remaining_cycles', 'auto_bill',
      ],
    };
    for (final MapEntry(key: entity, value: columns) in whitelists.entries) {
      for (final column in columns) {
        if (column.startsWith('custom_value')) continue;
        expect(bulkUpdateValueKind(entity, column), isNotNull, reason: column);
        final key = bulkUpdateLabelKey(column);
        final translated = [
          en[key],
          pending[key],
        ].whereType<String>().any((v) => v.trim().isNotEmpty);
        expect(translated, isTrue, reason: '$entity.$column → $key');
      }
    }
  });
}
