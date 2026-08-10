import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CI lint: the dashboard's "Converted to :currency" caption has exactly one
/// home, `lib/ui/features/dashboard/helpers/converted_hint.dart`.
///
/// This guard exists because the caption's guard clause was copy-pasted into
/// four widgets (KPI row, chart hero, mobile hero, configured metric cards)
/// and every copy asked only "is the currency filter on All?" — so a
/// single-currency company was permanently told its untouched totals had been
/// "Converted to GBP" (flutter#22). A fifth inlined copy would silently
/// reintroduce it, so the key itself is the thing we pin down.
const _allowedFile = 'lib/ui/features/dashboard/helpers/converted_hint.dart';

void main() {
  test('only converted_hint.dart references the converted_to_currency key', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'lib/ should exist');

    final offenders = <String>[];
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart')) continue;
      if (entity.path.endsWith('.freezed.dart')) continue;
      // Normalize separators — `listSync` yields `lib\ui\...` on Windows, and a
      // raw equality would flag the helper file itself as an offender there.
      if (entity.path.replaceAll(r'\', '/') == _allowedFile) continue;

      if (entity.readAsStringSync().contains('converted_to_currency')) {
        offenders.add(entity.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Build the caption with convertedToBaseCaption() from '
          '$_allowedFile — it also checks that the company actually trades in '
          'more than one currency. Found:\n  ${offenders.join('\n  ')}',
    );
  });
}
