import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/edit/custom_field_input.dart';

void main() {
  group('customFieldDate', () {
    test('reads a bare date as that local calendar day', () {
      final d = customFieldDate('2026-05-14')!;
      expect([d.year, d.month, d.day, d.isUtc], [2026, 5, 14, false]);
    });

    test('a stored time and zone do not move the day', () {
      // Parsed whole, this is a UTC instant `InDateField` shows through
      // `toLocal()` — May 13 west of UTC, while the card and detail view
      // (`Formatter.date`) show the 14th.
      final d = customFieldDate('2026-05-14T00:00:00Z')!;
      expect([d.year, d.month, d.day, d.isUtc], [2026, 5, 14, false]);
    });

    test('no date → null', () {
      expect(customFieldDate(''), isNull);
      expect(customFieldDate('soon'), isNull);
      expect(customFieldDate('not a date at all'), isNull);
    });
  });
}
