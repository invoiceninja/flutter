import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/custom_field_types.dart';

void main() {
  group('parseCustomField', () {
    test('null / empty → single-line text, empty label', () {
      for (final raw in [null, '']) {
        final p = parseCustomField(raw);
        expect(p.label, '');
        expect(p.type, kFieldTypeSingleLineText);
        expect(p.options, isEmpty);
      }
    });

    test('no pipe, non-empty → legacy multi-line text', () {
      final p = parseCustomField('Notes');
      expect(p.label, 'Notes');
      expect(p.type, kFieldTypeMultiLineText);
      expect(p.options, isEmpty);
    });

    test('explicit single_line_text keyword', () {
      final p = parseCustomField('Region|single_line_text');
      expect(p.label, 'Region');
      expect(p.type, kFieldTypeSingleLineText);
      expect(p.options, isEmpty);
    });

    test('multi_line_text is a reserved keyword (NOT a dropdown option)', () {
      // The single most important correctness guard: the settings editor
      // writes the explicit `multi_line_text` keyword, so it must round-trip
      // as multi-line — not as a one-option dropdown.
      expect(kReservedCustomFieldTypes, contains(kFieldTypeMultiLineText));
      final p = parseCustomField('Notes|multi_line_text');
      expect(p.label, 'Notes');
      expect(p.type, kFieldTypeMultiLineText);
      expect(p.options, isEmpty);
    });

    test('switch keyword', () {
      final p = parseCustomField('Active|switch');
      expect(p.label, 'Active');
      expect(p.type, kFieldTypeSwitch);
      expect(p.options, isEmpty);
    });

    test('date keyword', () {
      final p = parseCustomField('Due|date');
      expect(p.label, 'Due');
      expect(p.type, kFieldTypeDate);
      expect(p.options, isEmpty);
    });

    test('non-reserved suffix → dropdown with comma-split options', () {
      final p = parseCustomField('Region|North,South,East');
      expect(p.label, 'Region');
      expect(p.type, kFieldTypeDropdown);
      expect(p.options, ['North', 'South', 'East']);
    });

    test('empty suffix ("Label|") → dropdown with no options yet', () {
      final p = parseCustomField('Status|');
      expect(p.label, 'Status');
      expect(p.type, kFieldTypeDropdown);
      expect(p.options, isEmpty);
    });

    test('label may contain spaces; only the first pipe splits', () {
      final p = parseCustomField('Order Ref|Open,Closed');
      expect(p.label, 'Order Ref');
      expect(p.type, kFieldTypeDropdown);
      expect(p.options, ['Open', 'Closed']);
    });

    test('switch canonical stored values', () {
      expect(kSwitchValueYes, 'yes');
      expect(kSwitchValueNo, 'no');
    });
  });

  group('isSwitchTruthy', () {
    test('canonical and legacy truthy values', () {
      expect(isSwitchTruthy('yes'), isTrue);
      expect(isSwitchTruthy('true'), isTrue);
      expect(isSwitchTruthy('1'), isTrue);
    });

    test('falsy values', () {
      expect(isSwitchTruthy('no'), isFalse);
      expect(isSwitchTruthy(''), isFalse);
      expect(isSwitchTruthy('false'), isFalse);
      expect(isSwitchTruthy('0'), isFalse);
    });
  });

  group('surchargeLabel', () {
    test('a bare label is the label — never a multi-line field', () {
      expect(surchargeLabel('Shipping'), 'Shipping');
    });

    test("admin-portal's type suffix is dropped", () {
      expect(surchargeLabel('Shipping|single_line_text'), 'Shipping');
      expect(surchargeLabel('Shipping|'), 'Shipping');
    });

    test('null / empty → empty', () {
      expect(surchargeLabel(null), '');
      expect(surchargeLabel(''), '');
    });
  });
}
