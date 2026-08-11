import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/enabled_modules.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/settings_search_catalog.dart';

void main() {
  group('settings search catalog', () {
    test('every catalog section has a matching SettingsSectionDef', () {
      for (final slug in kSettingsSearchCatalog.keys) {
        expect(
          kSettingsSectionsBySlug.containsKey(slug),
          isTrue,
          reason:
              'Catalog references section "$slug" but no '
              'SettingsSectionDef has that slug. Add the section to '
              'kSettingsSections or remove the orphan catalog entry.',
        );
      }
    });

    test('section routes all start with /settings/<slug>', () {
      for (final section in kSettingsSections) {
        expect(
          section.route,
          startsWith('/settings/'),
          reason:
              'Section "${section.slug}" has unexpected route '
              '${section.route}',
        );
      }
    });

    test('searchSettings returns the full catalog for an empty query', () {
      final l10n = Localization.forTesting(strings: const {});
      final hits = searchSettings('', l10n);
      final totalFields = kSettingsSearchCatalog.values
          .map((v) => v.length)
          .fold<int>(0, (a, b) => a + b);
      expect(hits, hasLength(totalFields));
    });

    test('searchSettings matches case-insensitively on localized label', () {
      // Stub a label so we can search by the rendered string, not the key.
      final l10n = Localization.forTesting(
        strings: const {'vat_number': 'VAT Number'},
      );
      final hits = searchSettings('vat', l10n);
      expect(hits, isNotEmpty);
      expect(
        hits.any(
          (h) =>
              h.fieldKey == 'vat_number' && h.section.slug == 'company_details',
        ),
        isTrue,
      );
    });

    test('searchSettings returns no hits for a no-match query', () {
      final l10n = Localization.forTesting(strings: const {});
      // Missing keys fall through to the raw key, so the query has to miss
      // both the localized label and every field key in the catalog.
      final hits = searchSettings('zzz_definitely_not_a_field', l10n);
      expect(hits, isEmpty);
    });
  });

  group('SettingsSectionDef module gating', () {
    SettingsSectionDef section(String slug) => kSettingsSectionsBySlug[slug]!;

    test('ungated section is always visible', () {
      expect(section('company_details').isVisibleFor(0), isTrue);
      expect(section('localization').enabledBy, isNull);
    });

    test('all-off mask (0) hides gated sections', () {
      // 0 = every module off; module-gated sections are hidden.
      expect(section('task_settings').isVisibleFor(0), isFalse);
      expect(section('expense_settings').isVisibleFor(0), isFalse);
      expect(section('workflow_settings').isVisibleFor(0), isFalse);
    });

    test('task / expense settings track their single module', () {
      // Non-zero mask with the module off ⇒ hidden (credits=2 only).
      const creditsOnly = 2;
      expect(section('task_settings').isVisibleFor(creditsOnly), isFalse);
      expect(
        section('task_settings').isVisibleFor(EnabledModule.tasks.bitmask),
        isTrue,
      );
      expect(section('expense_settings').isVisibleFor(creditsOnly), isFalse);
      expect(
        section(
          'expense_settings',
        ).isVisibleFor(EnabledModule.expenses.bitmask),
        isTrue,
      );
    });

    test('workflow_settings stays while invoices OR quotes is on', () {
      final wf = section('workflow_settings');
      // credits=2 only (non-zero, both invoices+quotes off) ⇒ hidden.
      expect(wf.isVisibleFor(2), isFalse);
      expect(wf.isVisibleFor(EnabledModule.invoices.bitmask), isTrue);
      expect(wf.isVisibleFor(EnabledModule.quotes.bitmask), isTrue);
    });

    test('gated sections remain in the catalog (consistency preserved)', () {
      // Filtering is query-time, never by trimming kSettingsSearchCatalog —
      // search_catalog_consistency_test enforces this; assert it here too.
      for (final slug in ['task_settings', 'expense_settings']) {
        expect(kSettingsSearchCatalog.containsKey(slug), isTrue);
        expect(kSettingsSectionsBySlug.containsKey(slug), isTrue);
      }
    });
  });

  group('hosted-only field gating', () {
    test('every hosted-only field exists in the catalog', () {
      // The filter is a set-membership check against `fieldKey`, so a typo (or
      // a renamed key) makes it a silent no-op — the entry keeps surfacing for
      // self-hosted users and nothing fails.
      final allFields = kSettingsSearchCatalog.values.expand((v) => v).toSet();
      for (final key in kHostedOnlySettingsFields) {
        expect(
          allFields,
          contains(key),
          reason:
              'kHostedOnlySettingsFields lists "$key", which no catalog '
              'section declares — the hosted filter would never match it.',
        );
      }
    });

    test('the referral fields stay in the catalog, gated not deleted', () {
      // Same rule as the module/admin gates: filter at query time, keep the
      // static catalog complete.
      expect(
        kSettingsSearchCatalog['account_management'],
        containsAll(kHostedOnlySettingsFields),
      );
      expect(kHostedOnlySettingsFields, contains('referral_program'));
      expect(kHostedOnlySettingsFields, contains('referral_code'));
    });
  });
}
