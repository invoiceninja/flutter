import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/api/line_item_api_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LineItemApi int coercion', () {
    test('coerces int discriminator/id and numeric fields to strings', () {
      // The server emits `line_items` as raw stored JSON with no read-time
      // casting, so an older/imported/API-written invoice can carry ints in
      // string fields. None of these may throw; all must become strings.
      final item = LineItemApi.fromJson(const {
        'product_key': 12345,
        'type_id': 1,
        'tax_id': 2,
        'custom_value1': 7,
        'notes': 99,
        'tax_name1': 5,
      });
      expect(item.productKey, '12345');
      expect(item.typeId, '1');
      expect(item.taxCategoryId, '2');
      expect(item.customValue1, '7');
      expect(item.notes, '99');
      expect(item.taxName1, '5');
    });

    test('preserves freezed defaults when fields are null/absent', () {
      final nulled = LineItemApi.fromJson(const {'type_id': null});
      expect(nulled.typeId, '1'); // @Default('1') still applies through null
      expect(nulled.taxCategoryId, ''); // @Default('')

      final empty = LineItemApi.fromJson(const {});
      expect(empty.typeId, '1');
      expect(empty.taskId, isNull); // nullable, no default
    });

    test('still accepts ordinary string values unchanged', () {
      final item = LineItemApi.fromJson(const {
        'type_id': '2',
        'tax_id': '5',
        'product_key': 'ABC',
      });
      expect(item.typeId, '2');
      expect(item.taxCategoryId, '5');
      expect(item.productKey, 'ABC');
    });
  });

  group('InvoiceListApi resilience', () {
    test('parses an invoice whose line item has an int type_id '
        '(direct repro of the reported crash)', () {
      final list = InvoiceListApi.fromJson(const {
        'data': [
          {
            'id': 'inv_1',
            'line_items': [
              {'product_key': 'Widget', 'type_id': 1, 'tax_id': 2},
            ],
          },
        ],
      });
      expect(list.data, hasLength(1));
      final item = list.data.single.lineItems.single;
      expect(item.typeId, '1');
      expect(item.taxCategoryId, '2');
      expect(item.productKey, 'Widget');
    });

    test('skips a row that fails to parse instead of blanking the page', () {
      final list = InvoiceListApi.fromJson(const {
        'data': [
          {'id': 'good_1', 'line_items': <Object>[]},
          // A mismatch we deliberately do NOT coerce (a string in the int
          // `created_at` field) makes this row throw — the safety net must
          // drop it, not fail the whole list.
          {'id': 'bad_row', 'created_at': 'not-a-number'},
          {'id': 'good_2', 'line_items': <Object>[]},
        ],
      });
      expect(list.data.map((e) => e.id), ['good_1', 'good_2']);
    });
  });
}
