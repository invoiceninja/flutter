import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:admin/data/models/domain/company.dart';
import 'package:admin/ui/features/settings/views/advanced/generated_numbers/generated_number_preview.dart';

void main() {
  // Fixed clock so date/year tokens are deterministic.
  final now = DateTime(2026, 6, 3, 14, 5, 9);
  const company = Company();
  const companyWithLabels = Company(
    customFields: {'client1': 'Region', 'vendor1': 'Dept', 'user1': 'Badge'},
  );

  String preview(
    String pattern, {
    int counter = 5,
    int padding = 4,
    bool showClient = false,
    bool showVendor = false,
    bool showVendorIdNumber = false,
    Company company = const Company(),
  }) {
    return buildNumberPreview(
      pattern: pattern,
      counter: counter,
      padding: padding,
      now: now,
      showClient: showClient,
      showVendor: showVendor,
      showVendorIdNumber: showVendorIdNumber,
      company: company,
    );
  }

  group('buildNumberPreview', () {
    test('substitutes year + padded counter (canonical example)', () {
      expect(preview(r'{$year}-{$counter}'), '2026-0005');
    });

    test('empty pattern → bare padded counter', () {
      expect(preview(''), '0005');
    });

    test('whitespace-only pattern → bare padded counter', () {
      expect(preview('   '), '0005');
    });

    test('a counter-less pattern gets {\$counter} appended (server parity — '
        'confirmed on demo: `{\$year}` → `20260028`)', () {
      expect(preview(r'INV-{$year}'), 'INV-20260005');
    });

    test('padding 0 → counter unpadded', () {
      expect(preview(r'{$counter}', padding: 0), '5');
    });

    test('counter wider than padding is not truncated', () {
      expect(preview(r'{$counter}', counter: 12345), '12345');
    });

    test('counter / client_counter / group_counter all render the same', () {
      expect(
        preview(
          r'{$counter}-{$client_counter}-{$group_counter}',
          showClient: true,
        ),
        '0005-0005-0005',
      );
    });

    test('user_id is rendered as 00', () {
      expect(preview(r'{$user_id}'), '000005');
    });

    test('literals around tokens are preserved', () {
      expect(preview(r'PRE-{$counter}-{$year}-SUF'), 'PRE-0005-2026-SUF');
    });

    test('{\$date:Y-m-d} formats the current date', () {
      expect(preview(r'{$date:Y-m-d}'), '2026-06-030005');
    });

    test('{\$date:d/m/Y} respects the order', () {
      expect(preview(r'{$date:d/m/Y}'), '03/06/20260005');
    });

    test('{\$date:F j, Y} renders month name', () {
      expect(preview(r'{$date:F j, Y}'), 'June 3, 20260005');
    });

    test('empty date format falls back to ISO', () {
      expect(preview(r'{$date:}'), '2026-06-030005');
    });

    test('unknown date format letters are printed literally', () {
      expect(preview(r'{$date:zzz}'), 'zzz0005');
    });

    test('{\$date:jS} renders the ordinal day suffix', () {
      // Fixed clock is the 3rd → "3rd".
      expect(preview(r'{$date:jS}'), '3rd0005');
    });

    test('client tokens are literal when the client group is hidden', () {
      expect(preview(r'{$client_number}'), r'{$client_number}0005');
    });

    test('client tokens get sample values when the group is shown', () {
      expect(preview(r'{$client_number}', showClient: true), '00010005');
      expect(preview(r'{$client_id_number}', showClient: true), 'ID-00010005');
    });

    test('vendor tokens are gated on showVendor', () {
      expect(preview(r'{$vendor_number}'), r'{$vendor_number}0005');
      expect(preview(r'{$vendor_number}', showVendor: true), '00010005');
    });

    test('{\$vendor_id_number} renders alone for the Vendors tab', () {
      // The Vendors tab passes showVendorIdNumber (not showVendor): the backend
      // substitutes {$vendor_id_number} for a Vendor entity but not the other
      // vendor tokens, so those stay literal.
      expect(
        preview(r'{$vendor_id_number}', showVendorIdNumber: true),
        'ID-00010005',
      );
      expect(
        preview(r'{$vendor_number}', showVendorIdNumber: true),
        r'{$vendor_number}0005',
      );
    });

    test('custom-field token → the configured label when set', () {
      expect(
        preview(
          r'{$client_custom1}',
          showClient: true,
          company: companyWithLabels,
        ),
        'Region0005',
      );
      expect(
        preview(r'{$user_custom1}', company: companyWithLabels),
        'Badge0005',
      );
    });

    test('custom-field token left literal when the slot has no label', () {
      expect(
        preview(r'{$client_custom1}', showClient: true, company: company),
        r'{$client_custom1}0005',
      );
    });
  });

  group('phpDateFormatToIntl', () {
    // Assert by formatting (robust to whichever literal-quoting style is used).
    // No locale → en_US default, matching buildNumberPreview + the PHP server.
    String fmt(String php) => DateFormat(phpDateFormatToIntl(php)).format(now);

    test('common formats', () {
      expect(fmt('Y-m-d'), '2026-06-03');
      expect(fmt('d/m/Y'), '03/06/2026');
      expect(fmt('F j, Y'), 'June 3, 2026');
    });

    test('individual letters', () {
      expect(fmt('Y'), '2026');
      expect(fmt('y'), '26');
      expect(fmt('m'), '06');
      expect(fmt('n'), '6');
      expect(fmt('M'), 'Jun');
      expect(fmt('d'), '03');
      expect(fmt('j'), '3');
      expect(fmt('H'), '14');
      expect(fmt('G'), '14');
      expect(fmt('h'), '02');
      expect(fmt('g'), '2');
      expect(fmt('i'), '05');
      expect(fmt('s'), '09');
    });

    test('empty string → empty pattern', () {
      expect(phpDateFormatToIntl(''), '');
    });

    test('unknown letters pass through as literals', () {
      expect(fmt('q'), 'q');
      expect(fmt('Y q'), '2026 q');
    });

    test('ordinal S expands when now is supplied', () {
      String ord(int day) => DateFormat(
        phpDateFormatToIntl('jS', now: DateTime(2026, 6, day)),
      ).format(DateTime(2026, 6, day));
      expect(ord(1), '1st');
      expect(ord(2), '2nd');
      expect(ord(3), '3rd');
      expect(ord(4), '4th');
      expect(ord(11), '11th');
      expect(ord(12), '12th');
      expect(ord(13), '13th');
      expect(ord(21), '21st');
      expect(ord(23), '23rd');
    });

    test('S stays literal without now (fmt passes no clock)', () {
      // j → day "3", S → bare letter (no `now`) → "3S".
      expect(fmt('jS'), '3S');
    });
  });
}
