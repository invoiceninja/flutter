import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/enabled_modules.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/settings_search_catalog.dart';
import 'package:admin/ui/features/settings/widgets/contacts_sync_section.dart';
import 'package:admin/ui/features/settings/widgets/mobile_app_section.dart';

import '../../../_localization_helper.dart';

/// Every module on — the scope a test uses when it isn't about modules.
final int _allModules = kEnabledModulesOrder.fold<int>(
  0,
  (mask, m) => mask | m.bitmask,
);

SettingsSearchScope _scope({
  int? enabledModules,
  bool isAdminOrOwner = true,
  bool isCascade = false,
  bool isHosted = true,
}) => SettingsSearchScope(
  enabledModules: enabledModules ?? _allModules,
  isAdminOrOwner: isAdminOrOwner,
  isCascade: isCascade,
  isHosted: isHosted,
);

Iterable<String> _allKeys() sync* {
  for (final tabs in kSettingsSearchCatalog.values) {
    for (final tab in tabs) {
      yield* tab.keys;
      if (tab.titleKey != null) yield tab.titleKey!;
    }
  }
}

void main() {
  // A key gate can ask the platform (`platformSupportsSpellCheck` reads the
  // binding's dispatcher), so searchSettings needs a binding.
  TestWidgetsFlutterBinding.ensureInitialized();

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

    test('every section has a catalog entry', () {
      // Tags had none, so nothing on its page could be found.
      for (final section in kSettingsSections) {
        expect(
          kSettingsSearchCatalog[section.slug],
          isNotEmpty,
          reason: '"${section.slug}" has no kSettingsSearchCatalog entry',
        );
      }
    });

    test('tab paths are unique within a section and never slash-wrapped', () {
      for (final entry in kSettingsSearchCatalog.entries) {
        final paths = [for (final tab in entry.value) tab.path];
        expect(
          paths.toSet(),
          hasLength(paths.length),
          reason: '${entry.key} lists a tab twice',
        );
        for (final p in paths) {
          expect(p.startsWith('/') || p.endsWith('/'), isFalse);
        }
      }
    });

    test('no field key resolves to a string with a :placeholder', () {
      // Settings search renders a field key raw (`l10n.lookup(hit.fieldKey)`)
      // — it has nothing to substitute with. A key whose bundled value carries
      // a `:token` therefore shows the token to the user; `days_left`
      // (":days days left") did exactly that until it was swapped for
      // `days_left_label`. The `test/lint/` text scan can't see these because
      // they're bare strings in a list, so assert it here.
      final l10n = bundledLocalization();
      final offenders = <String>[
        for (final key in _allKeys())
          if (kLocalePlaceholderPattern.hasMatch(l10n.lookup(key)))
            '$key -> "${l10n.lookup(key)}"',
      ];
      expect(
        offenders,
        isEmpty,
        reason:
            'Catalog keys must resolve placeholder-free. Point at a clean key '
            '(or add a *_label key to _app_pending.json). Found:\n  '
            '${offenders.join('\n  ')}',
      );
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

    test('every keyword entry names a real section or tab', () {
      // A typo here is silent: the keywords just never match anything.
      for (final key in kSettingsSearchKeywords.keys) {
        final slash = key.indexOf('/');
        final slug = slash < 0 ? key : key.substring(0, slash);
        final path = slash < 0 ? '' : key.substring(slash + 1);
        final tabs = kSettingsSearchCatalog[slug];
        expect(tabs, isNotNull, reason: '"$key" names no section');
        expect(
          tabs!.any((t) => t.path == path),
          isTrue,
          reason: '"$key" names no tab of $slug',
        );
      }
    });
  });

  group('searchSettings', () {
    test('an empty or blank query returns nothing', () {
      // The UI shows the section list until something is typed; the old
      // resting state was every field in the catalog.
      final l10n = bundledLocalization();
      expect(searchSettings('', l10n), isEmpty);
      expect(searchSettings('   ', l10n), isEmpty);
    });

    test('matches case-insensitively on the localized label', () {
      final l10n = Localization.forTesting(
        strings: const {'vat_number': 'VAT Number'},
      );
      final hits = searchSettings('vat', l10n);
      expect(
        hits.any(
          (h) =>
              h.fieldKey == 'vat_number' && h.section.slug == 'company_details',
        ),
        isTrue,
      );
    });

    test('returns no hits for a no-match query', () {
      final l10n = Localization.forTesting(strings: const {});
      // Missing keys fall through to the raw key, so the query has to miss
      // both the localized label and every field key in the catalog.
      expect(searchSettings('zzz_definitely_not_a_field', l10n), isEmpty);
    });

    test('every section is found by its own name, first', () {
      // Nineteen weren't: "Tax Settings" found nothing, and "Company
      // Details" found only an Invoice Design row.
      final l10n = bundledLocalization();
      for (final section in kSettingsSections) {
        final title = l10n.lookup(section.titleKey);
        final hits = searchSettings(title, l10n);
        expect(hits, isNotEmpty, reason: '"$title" found nothing');
        expect(
          hits.first.isSection && hits.first.section.slug == section.slug,
          isTrue,
          reason:
              '"$title" should lead with its own section, got '
              '${hits.first.section.slug}/${hits.first.fieldKey}',
        );
      }
    });

    test('a label is listed once per section', () {
      // The ten Custom Fields tabs each list Label / Field Type / Date / …, so
      // "date" used to return ten identical "Date · Custom Fields" rows.
      final l10n = bundledLocalization();
      for (final q in ['a', 'e', 'date', 'email', 'number', 'label']) {
        final seen = <String>{};
        for (final h in searchSettings(q, l10n)) {
          final id =
              '${h.section.slug}/${l10n.lookup(h.fieldKey).toLowerCase()}';
          expect(seen.add(id), isTrue, reason: '"$q" lists $id twice');
        }
      }
      final dates = searchSettings('date', l10n)
          .where(
            (h) => h.section.slug == 'custom_fields' && h.fieldKey == 'date',
          )
          .toList();
      expect(dates, hasLength(1));
      // On every tab, so the row names no tab — but still opens one that has it.
      expect(dates.single.tabTitleKey, isNull);
      expect(dates.single.route, '/settings/custom_fields');
    });

    test('a field on one tab names that tab and opens it', () {
      final l10n = bundledLocalization();
      final postal = searchSettings(
        'postal',
        l10n,
      ).firstWhere((h) => h.fieldKey == 'postal_code');
      expect(postal.route, '/settings/company_details/address');
      expect(postal.tabTitleKey, 'address');
      expect(postal.revealsField, isTrue);
    });

    test(
      'a label that starts with the query outranks one that contains it',
      () {
        final l10n = bundledLocalization();
        final hits = searchSettings('number', l10n);
        final keys = [for (final h in hits) h.fieldKey];
        expect(keys.indexOf('number_padding'), isNonNegative);
        expect(keys.indexOf('invoice_number'), isNonNegative);
        expect(
          keys.indexOf('number_padding'),
          lessThan(keys.indexOf('invoice_number')),
        );
      },
    );

    test('a multi-word query matches its words in any order', () {
      final l10n = bundledLocalization();
      for (final q in ['invoice number', 'number invoice']) {
        expect(
          searchSettings(q, l10n).any((h) => h.fieldKey == 'invoice_number'),
          isTrue,
          reason: '"$q" should find Invoice Number',
        );
      }
    });

    test('a word may land in the tab title once another is in the label', () {
      // "pattern quotes" → Number Pattern on Generated Numbers › Quotes.
      final l10n = bundledLocalization();
      final hit = searchSettings(
        'pattern quotes',
        l10n,
      ).firstWhere((h) => h.fieldKey == 'number_pattern');
      expect(hit.route, '/settings/generated_numbers/quotes');
    });

    test('the English label matches under another locale', () {
      final l10n = Localization.forTesting(
        strings: const {'postal_code': 'Postleitzahl'},
        fallback: const {'postal_code': 'Postal Code'},
      );
      expect(
        searchSettings('postal', l10n).any((h) => h.fieldKey == 'postal_code'),
        isTrue,
      );
      // …below a match on the label the user can actually read.
      final german = searchSettings('postleit', l10n);
      expect(german.first.fieldKey, 'postal_code');
    });

    test('keywords find the page that never says the word', () {
      final l10n = bundledLocalization();
      expect(
        searchSettings(
          'smtp',
          l10n,
        ).any((h) => h.isSection && h.section.slug == 'email_settings'),
        isTrue,
      );
      final twoFactor = searchSettings('2fa', l10n).where(
        (h) =>
            h.kind == SettingsSearchHitKind.tab &&
            h.route == '/settings/user_details/enable_two_factor',
      );
      expect(twoFactor, hasLength(1));
      expect(twoFactor.single.revealsField, isFalse);
    });

    test('typing a section name does not list its every tab', () {
      // Tabs are matched on their own title and keywords; the section's name
      // alone would otherwise drag in all of them.
      final l10n = bundledLocalization();
      final hits = searchSettings(l10n.lookup('client_portal'), l10n);
      expect(hits.where((h) => h.kind == SettingsSearchHitKind.tab), isEmpty);
    });
  });

  group('SettingsSearchScope', () {
    group('Device Settings cards that render only somewhere', () {
      final l10n = bundledLocalization();
      // Every label of [keys] that reaches Device Settings under [scope].
      Set<String> offered(List<String> keys, SettingsSearchScope scope) => {
        for (final key in keys)
          for (final h in searchSettings(l10n.lookup(key), l10n, scope: scope))
            if (h.section.slug == 'device_settings' && h.fieldKey == key) key,
      };
      tearDown(() => debugDefaultTargetPlatformOverride = null);

      test('Contacts sync only on a phone, where it can write contacts', () {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        expect(
          offered(kContactsSyncSearchKeys, _scope()),
          kContactsSyncSearchKeys.toSet(),
        );
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        expect(offered(kContactsSyncSearchKeys, _scope()), isEmpty);
      });

      test('Mobile App only where the card shows', () {
        expect(
          offered(kMobileAppSearchKeys, _scope()),
          kMobileAppSearchKeys.toSet(),
        );
        expect(
          offered(
            kMobileAppSearchKeys,
            const SettingsSearchScope(
              enabledModules: 0,
              isAdminOrOwner: true,
              isCascade: false,
              isHosted: true,
              showsMobileApp: false,
            ),
          ),
          isEmpty,
        );
      });

      test('Hide Peppol Sent Status only for a company that sends by '
          'PEPPOL', () {
        const keys = ['hide_peppol_sent_status'];
        expect(offered(keys, _scope()), keys.toSet());
        expect(
          offered(
            keys,
            const SettingsSearchScope(
              enabledModules: 0,
              isAdminOrOwner: true,
              isCascade: false,
              isHosted: true,
              sendsPeppol: false,
            ),
          ),
          isEmpty,
        );
      });

      test('with no scope the session- and company-bound gates fail open', () {
        final hits = searchSettings(
          l10n.lookup('hide_peppol_sent_status'),
          l10n,
        );
        expect(
          hits.any((h) => h.fieldKey == 'hide_peppol_sent_status'),
          isTrue,
        );
      });
    });

    test('Spell check is offered only where its section renders', () {
      // `_SpellCheckSection` renders nothing without a platform checker (web,
      // Linux), so a hit there would open Device Settings on nothing.
      final l10n = bundledLocalization();
      bool offersSpellCheck() => searchSettings(
        'spell',
        l10n,
        scope: _scope(),
      ).any((h) => h.fieldKey == 'spell_check');
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(offersSpellCheck(), isTrue);
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(offersSpellCheck(), isFalse);
    });

    test('a self-hosted session never sees the Referral Program tab', () {
      // `AccountManagementShell` hides it there (issue #27).
      final l10n = bundledLocalization();
      bool reachesReferral(List<SettingsSearchHit> hits) =>
          hits.any((h) => h.route.endsWith('/referral_program'));
      expect(
        reachesReferral(
          searchSettings('referral', l10n, scope: _scope(isHosted: true)),
        ),
        isTrue,
      );
      expect(
        reachesReferral(
          searchSettings('referral', l10n, scope: _scope(isHosted: false)),
        ),
        isFalse,
      );
    });

    test('a tab whose module is off is not offered', () {
      final l10n = bundledLocalization();
      final invoicesOnly = _scope(
        enabledModules: EnabledModule.invoices.bitmask,
      );
      final hits = searchSettings('expense', l10n, scope: invoicesOnly);
      expect(
        hits.where((h) => h.route.contains('/expenses')),
        isEmpty,
        reason: 'the Custom Fields and Generated Numbers expense tabs are off',
      );
      expect(hits.where((h) => h.section.slug == 'expense_settings'), isEmpty);
    });

    test('a key on a gated tab is offered only while its tab is', () {
      // The shell falls back to its first tab for a hidden slug, so an ungated
      // hit would open the wrong page rather than fail.
      final l10n = bundledLocalization();
      bool reachesQuotes(SettingsSearchScope scope) => searchSettings(
        'pattern quotes',
        l10n,
        scope: scope,
      ).any((h) => h.route == '/settings/generated_numbers/quotes');
      expect(
        reachesQuotes(_scope(enabledModules: EnabledModule.quotes.bitmask)),
        isTrue,
      );
      expect(
        reachesQuotes(_scope(enabledModules: EnabledModule.credits.bitmask)),
        isFalse,
      );
      // Number Pattern itself stays findable through the always-shown
      // Clients tab.
      final hit = searchSettings(
        'number pattern',
        l10n,
        scope: _scope(enabledModules: 0),
      ).firstWhere((h) => h.fieldKey == 'number_pattern');
      expect(hit.route, '/settings/generated_numbers/clients');
    });

    test('client scope drops company-only sections and tabs', () {
      final l10n = bundledLocalization();
      final hits = [
        for (final q in ['columns', 'details', 'custom labels', 'logo'])
          ...searchSettings(q, l10n, scope: _scope(isCascade: true)),
      ];
      expect(
        hits.where(
          (h) =>
              h.route.startsWith('/settings/invoice_design/') ||
              h.route == '/settings/localization/custom_labels' ||
              h.section.slug == 'company_details',
        ),
        isEmpty,
      );
    });

    test('an admin-only section is hidden from everyone else', () {
      final l10n = bundledLocalization();
      bool findsLogs(SettingsSearchScope scope) => searchSettings(
        l10n.lookup('system_logs'),
        l10n,
        scope: scope,
      ).any((h) => h.section.slug == 'system_logs');
      expect(findsLogs(_scope()), isTrue);
      expect(findsLogs(_scope(isAdminOrOwner: false)), isFalse);
    });

    test('gated sections and tabs stay in the catalog — filtered, not cut', () {
      // Filtering is query-time, never by trimming kSettingsSearchCatalog;
      // the consistency tests read the whole thing.
      for (final slug in ['task_settings', 'expense_settings']) {
        expect(kSettingsSearchCatalog.containsKey(slug), isTrue);
      }
      expect(
        kSettingsSearchCatalog['account_management']!.where(
          (t) => t.hostedOnly,
        ),
        hasLength(1),
      );
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
  });
}
