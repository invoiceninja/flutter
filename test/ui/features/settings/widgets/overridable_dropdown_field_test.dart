import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/features/settings/views/advanced/templates_reminders/template_options.dart';
import 'package:admin/ui/features/settings/widgets/overridable_dropdown_field.dart';

/// #12: enabling a cascade override at client/group scope must seed a concrete
/// value. The endless-reminder frequency sits at the server default ('0',
/// rendered as a null cascaded value), so the old seed (`value?.toString()`)
/// returned null — the settings binding drops null keys and `isOverridden`
/// requires a non-null value, so the override checkbox could never be enabled.
void main() {
  group('OverridableDropdownField.seedOnEnable (#12)', () {
    final freqItems = [
      for (final e in kEndlessReminderFrequencies)
        DropdownMenuItem<String>(value: e.$1, child: Text(e.$2)),
    ];

    test('null cascaded value seeds the first real option (not null)', () {
      expect(
        OverridableDropdownField.seedOnEnable<String>(null, freqItems),
        '1',
      );
    });

    test('a present cascaded value is kept', () {
      expect(
        OverridableDropdownField.seedOnEnable<String>('5', freqItems),
        '5',
      );
    });

    test('skips a leading null-valued (placeholder) item', () {
      final items = <DropdownMenuItem<String>>[
        const DropdownMenuItem<String>(value: null, child: Text('None')),
        const DropdownMenuItem<String>(value: 'usd', child: Text('USD')),
      ];
      expect(OverridableDropdownField.seedOnEnable<String>(null, items), 'usd');
    });

    test('empty items → null (transient pre-statics-load; no crash)', () {
      expect(
        OverridableDropdownField.seedOnEnable<String>(
          null,
          const <DropdownMenuItem<String>>[],
        ),
        isNull,
      );
    });
  });
}
