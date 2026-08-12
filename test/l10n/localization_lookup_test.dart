import 'package:flutter_test/flutter_test.dart';

import 'package:admin/l10n/localization.dart';

void main() {
  group('Localization.lookup', () {
    test('prefers the active locale, then English, then app-pending', () {
      final loc = Localization.forTesting(
        strings: const {'save': 'Speichern'},
        fallback: const {'save': 'Save', 'cancel': 'Cancel'},
        pending: const {'sync_now': 'Sync now'},
      );

      expect(loc.lookup('save'), 'Speichern');
      expect(loc.lookup('cancel'), 'Cancel');
      expect(loc.lookup('sync_now'), 'Sync now');
    });

    test('a missing key renders as the raw key', () {
      final loc = Localization.forTesting(strings: const {});
      expect(loc.lookup('no_such_key'), 'no_such_key');
    });

    // Transifex ships unfinished entries as `""`, and three such keys are in
    // every bundled locale file today. A plain `??` chain returns that empty
    // string instead of falling through — which for a toast means a blank card
    // (invoiceninja/flutter#30).
    test('an empty bundled value falls through to English', () {
      final loc = Localization.forTesting(
        strings: const {'save': ''},
        fallback: const {'save': 'Save'},
      );
      expect(loc.lookup('save'), 'Save');
    });

    test('a whitespace-only value falls through too', () {
      final loc = Localization.forTesting(
        strings: const {'save': '   '},
        fallback: const {'save': 'Save'},
      );
      expect(loc.lookup('save'), 'Save');
    });

    test('an empty value everywhere renders the key, never blank', () {
      final loc = Localization.forTesting(
        strings: const {'save': ''},
        fallback: const {'save': ''},
        pending: const {'save': ''},
      );
      expect(loc.lookup('save'), 'save');
    });

    test('placeholders still interpolate after the fall-through', () {
      final loc = Localization.forTesting(
        strings: const {'greeting': ''},
        fallback: const {'greeting': 'Hello :name'},
      );
      expect(loc.lookup('greeting', {'name': 'Ada'}), 'Hello Ada');
    });
  });
}
