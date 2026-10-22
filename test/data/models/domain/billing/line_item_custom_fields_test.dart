import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/billing/line_item_custom_fields.dart';
import 'package:admin/data/models/domain/billing/line_item_type.dart';
import 'package:admin/data/models/domain/custom_field_types.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/datetime_format.dart';
import 'package:admin/utils/formatting.dart';

/// A line item's four custom values carry no definitions of their own: they
/// are labelled from the company's `product1..4`, or `task1..4` on an hourly
/// line. Nothing in the app read either set for line items, so a product's
/// custom values — copied onto the line by the picker — were never shown.
final _formatter = Formatter(
  settings: const CompanyFormatSettings(
    currencyId: '1',
    countryId: '840',
    dateFormatId: 'X',
    useCommaAsDecimalPlace: false,
    showCurrencyCode: false,
    enableMilitaryTime: false,
    locale: '',
  ),
  currencies: const {},
  countries: const {},
  dateFormats: const {'X': DatetimeFormat(id: 'X', format: 'd/MMM/yyyy')},
);

const _customFields = {
  'product1': 'Color|Red,Blue',
  'product2': 'Warranty|switch',
  // product3 unconfigured
  'product4': 'Shipped|date',
  'task1': 'Phase|single_line_text',
};

void main() {
  group('lineItemCustomFields', () {
    test('a product table reads product1..4 and skips unconfigured slots', () {
      final fields = lineItemCustomFields(_customFields, task: false);
      expect(fields.map((f) => f.slot), [1, 2, 4]);
      expect(fields.map((f) => f.field.label), [
        'Color',
        'Warranty',
        'Shipped',
      ]);
      expect(fields[0].field.type, kFieldTypeDropdown);
      expect(fields[0].field.options, ['Red', 'Blue']);
      expect(fields[1].field.type, kFieldTypeSwitch);
    });

    test('a task table reads task1..4 instead', () {
      final fields = lineItemCustomFields(_customFields, task: true);
      expect(fields.map((f) => f.slot), [1]);
      expect(fields.single.field.label, 'Phase');
    });

    test('no company definitions → none', () {
      expect(lineItemCustomFields(null, task: false), isEmpty);
      expect(lineItemCustomFields(const {}, task: false), isEmpty);
    });
  });

  test('only an hourly line takes the task labels', () {
    // The server's PDF builder decides by type alone: type 2 prints in the
    // task table, an expense line (6) in the product table.
    LineItem typed(LineItemType t) => emptyLineItem().copyWith(typeId: t);
    expect(lineItemUsesTaskFields(typed(LineItemType.task)), isTrue);
    expect(lineItemUsesTaskFields(typed(LineItemType.standard)), isFalse);
    expect(lineItemUsesTaskFields(typed(LineItemType.expense)), isFalse);
  });

  test('slot accessors read and write the matching custom value', () {
    var item = emptyLineItem();
    for (var slot = 1; slot <= 4; slot++) {
      item = withLineItemCustomValue(item, slot, 'v$slot');
    }
    expect(item.customValue1, 'v1');
    expect(item.customValue4, 'v4');
    expect(
      [for (var s = 1; s <= 4; s++) lineItemCustomValue(item, s)],
      ['v1', 'v2', 'v3', 'v4'],
    );
  });

  group('lineItemCustomValueRows', () {
    final fields = lineItemCustomFields(_customFields, task: false);

    List<({String label, String value})> rows(LineItem item) =>
        lineItemCustomValueRows(
          item,
          fields,
          yes: 'Yes',
          no: 'No',
          formatter: _formatter,
        );

    test('formats by type and skips empty values', () {
      final item = emptyLineItem().copyWith(
        customValue1: 'Red',
        customValue2: 'yes',
        customValue4: '2026-03-05',
      );
      expect(rows(item), [
        (label: 'Color', value: 'Red'),
        (label: 'Warranty', value: 'Yes'),
        (label: 'Shipped', value: '5/Mar/2026'),
      ]);
      expect(rows(emptyLineItem()), isEmpty);
    });

    test('a value in an unconfigured slot is not shown', () {
      expect(rows(emptyLineItem().copyWith(customValue3: 'orphan')), isEmpty);
    });

    test('a date that does not parse is dropped, not shown as "Label:"', () {
      expect(rows(emptyLineItem().copyWith(customValue4: 'soon')), isEmpty);
    });

    test('…even before the formatter has loaded', () {
      // Without one, `displayCustomFieldValue` passes the raw value through —
      // which painted "Shipped: soon" on a phone card's first frame.
      final out = lineItemCustomValueRows(
        emptyLineItem().copyWith(customValue4: 'soon'),
        fields,
        yes: 'Yes',
        no: 'No',
      );
      expect(out, isEmpty);
    });

    test('a multi-line value collapses onto one line', () {
      // The rows are joined into one summary line; a newline would push every
      // field after it out of a one- or two-line Text.
      final multi = lineItemCustomFields(const {
        'product1': 'Spec',
      }, task: false);
      final out = lineItemCustomValueRows(
        emptyLineItem().copyWith(customValue1: 'Steel\n  10 mm \nBlack'),
        multi,
        yes: 'Yes',
        no: 'No',
      );
      expect(out.single.value, 'Steel 10 mm Black');
    });

    test('reserved date keywords expand only when asked (read-only)', () {
      final keywordFields = lineItemCustomFields(const {
        'product1': 'Period|single_line_text',
        'product2': 'Plan|:MONTH,other',
      }, task: false);
      final item = emptyLineItem().copyWith(
        customValue1: '[MONTHYEAR|MONTHYEAR+1]',
        customValue2: ':MONTH',
      );
      List<String> values({required bool expand}) => lineItemCustomValueRows(
        item,
        keywordFields,
        yes: 'Yes',
        no: 'No',
        expandDateKeywords: expand,
        now: DateTime(2026, 8, 15, 12),
      ).map((r) => r.value).toList();

      // The printed line: the server expands every product1..4 text value.
      expect(values(expand: true), ['August 2026 - September 2026', 'August']);
      // The editor's summary keeps the token it will save.
      expect(values(expand: false), ['[MONTHYEAR|MONTHYEAR+1]', ':MONTH']);
    });
  });
}
