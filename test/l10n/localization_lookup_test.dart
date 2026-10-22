import 'package:flutter_test/flutter_test.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/utils/bidi.dart';

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

    group('a locale\'s translation of an app-local string', () {
      final loc = Localization.forTesting(
        strings: const {
          'save': 'Speichern',
          // Transifex exports an untranslated key as its English source.
          'outbox_label': 'Outbox',
          'blank_label': '  ',
        },
        localePending: const {
          'save': 'Sichern',
          'sync_now': 'Jetzt synchronisieren',
          'outbox_label': 'Postausgang',
          'blank_label': 'Leer',
        },
        fallback: const {
          'save': 'Save',
          'outbox_label': 'Outbox',
          'blank_label': 'Blank',
        },
        pending: const {'sync_now': 'Sync now'},
      );

      test('loses to a real Transifex translation', () {
        expect(loc.lookup('save'), 'Speichern');
      });

      test('beats the English it translates', () {
        expect(loc.lookup('sync_now'), 'Jetzt synchronisieren');
        expect(loc.englishOf('sync_now'), 'Sync now');
      });

      test('beats the English copy Transifex ships before translating', () {
        expect(loc.lookup('outbox_label'), 'Postausgang');
        expect(loc.lookup('blank_label'), 'Leer');
      });

      test('survives a Custom Labels overlay', () {
        final withLabels = loc.withOverrides(const {'quote': 'Angebot'});
        expect(withLabels.lookup('sync_now'), 'Jetzt synchronisieren');
      });
    });

    group('in a right-to-left locale', () {
      final loc = Localization.forTesting(
        strings: const {'paid': 'دفع :amount', 'save': 'حفظ'},
        fallback: const {'saved': 'Saved.', 'paid': 'Paid :amount'},
        pending: const {'sync_now': 'Sync now'},
        rtl: true,
      );

      test('isolates each param so an amount keeps its sign in place', () {
        expect(
          loc.lookup('paid', {'amount': r'-$5.00'}),
          'دفع ${firstStrongIsolate(r'-$5.00')}',
        );
      });

      test('isolates an English fallback as a whole', () {
        expect(loc.lookup('saved'), ltrIsolate('Saved.'));
        expect(loc.lookup('sync_now'), ltrIsolate('Sync now'));
      });

      test('leaves a translated string, a missing key and English alone', () {
        expect(loc.lookup('save'), 'حفظ');
        expect(loc.lookup('no_such_key'), 'no_such_key');
        expect(loc.englishOf('saved'), 'Saved.');
        expect(loc.lookupBundled('saved'), 'Saved.');
      });

      test('a left-to-right locale is never isolated', () {
        final ltr = Localization.forTesting(
          strings: const {'paid': 'Paid :amount'},
        );
        expect(ltr.lookup('paid', {'amount': r'-$5.00'}), r'Paid -$5.00');
      });
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

    group('a placeholder name that prefixes another', () {
      // `:time` is a prefix of `:timezone`, so substituting in map order
      // rewrites the second token to "<value>zone" and it never matches —
      // rendered garbage rather than a missing string, which no `tr()` lint
      // catches. Bundled keys with this shape: `activity_10` / `_39` / `_40` /
      // `_41` (`:payment` + `:payment_amount`) and
      // `entity_number_placeholder` (`:entity` + `:entity_number`).
      final loc = Localization.forTesting(
        strings: const {'when': ':time in :timezone'},
      );

      test('resolves both, with the short name given first', () {
        expect(
          loc.lookup('when', {'time': '11:47 PM', 'timezone': 'Europe/Berlin'}),
          '11:47 PM in Europe/Berlin',
        );
      });

      test('resolves both, with the long name given first', () {
        // The result must not depend on the caller's literal map order.
        expect(
          loc.lookup('when', {'timezone': 'Europe/Berlin', 'time': '11:47 PM'}),
          '11:47 PM in Europe/Berlin',
        );
      });

      test('substitution is sequential, so a value CAN be rescanned', () {
        // Documented, not relied on: passes run longest-name-first over the
        // accumulating output, so a `:time` that the `:timezone` value itself
        // introduced is rewritten by the later, shorter pass. Making this
        // exact needs a single-pass tokenizer; a parameter value containing a
        // literal `:word` is pathological, and the sequential form keeps the
        // hot single-param path allocation-free.
        expect(
          loc.lookup('when', {'time': 'noon', 'timezone': 'UTC :time'}),
          'noon in UTC noon',
        );
      });
    });
  });
}
