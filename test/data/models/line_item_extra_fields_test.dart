// The server replaces `line_items` whole on every save, so a line field this
// app does not model is a field an edit from the app wipes. Before these
// fields were carried through, any save reset a line's e-invoice `unit_code`
// to `C62` and cleared its QuickBooks `income_account_id`, its `tags`, `date`
// and `sort_id` — and would have cleared the new `is_optional` flag too.

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/line_item_api_model.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';

Map<String, dynamic> _wire(Map<String, dynamic> extra) => {
  'product_key': 'SVC',
  'notes': 'Service',
  'cost': 100,
  'quantity': 2,
  'type_id': '1',
  ...extra,
};

LineItem _parse(Map<String, dynamic> json) =>
    LineItem.fromApi(LineItemApi.fromJson(json));

void main() {
  test('fields this app does not model survive a round trip', () {
    final out = _parse(
      _wire({
        'unit_code': 'HUR',
        'income_account_id': 'qb-41',
        'tags': 'urgent,onsite',
        'date': '2026-11-01',
        'sort_id': '3',
        'some_future_field': {'nested': true},
      }),
    ).toApiJson();

    expect(out['unit_code'], 'HUR');
    expect(out['income_account_id'], 'qb-41');
    expect(out['tags'], 'urgent,onsite');
    expect(out['date'], '2026-11-01');
    expect(out['sort_id'], '3');
    expect(out['some_future_field'], {'nested': true});
  });

  test('server-computed fields are not echoed back', () {
    final out = _parse(
      _wire({
        'line_total': 200,
        'gross_line_total': 220,
        'tax_amount': 20,
        'net_cost': 100,
        'is_amount_discount': true,
      }),
    ).toApiJson();

    for (final key in kServerComputedLineItemKeys) {
      expect(out.containsKey(key), isFalse, reason: key);
    }
  });

  test('a modelled field is written from the model, never a stale copy', () {
    final item = _parse(_wire({'unit_code': 'HUR'}));
    final out = item.copyWith(notes: 'Edited').toApiJson();
    expect(out['notes'], 'Edited');
    expect(item.extra.containsKey('notes'), isFalse);
  });

  group('is_optional', () {
    test('read in any of the server\'s shapes', () {
      for (final v in [true, 1, '1', 'true']) {
        expect(_parse(_wire({'is_optional': v})).isOptional, isTrue);
      }
      expect(_parse(_wire({})).isOptional, isFalse);
    });

    test('sent only when set — an absent key is already "not optional"', () {
      final optional = _parse(_wire({'is_optional': true}));
      expect(optional.toApiJson()['is_optional'], isTrue);
      expect(optional.extra.containsKey('is_optional'), isFalse);
      expect(
        optional
            .copyWith(isOptional: false)
            .toApiJson()
            .containsKey('is_optional'),
        isFalse,
      );
    });

    test('a clone keeps it only onto a quote', () {
      final item = emptyLineItem().copyWith(
        notes: 'Extended warranty',
        cost: Decimal.fromInt(80),
        isOptional: true,
      );
      expect(clonedLineItems([item]).single.isOptional, isFalse);
      expect(
        clonedLineItems([item], keepOptional: true).single.isOptional,
        isTrue,
      );
    });
  });
}
