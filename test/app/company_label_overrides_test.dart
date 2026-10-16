import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/company_label_overrides.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_settings.dart';
import 'package:admin/data/models/value/language.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/company_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';

/// The active company's Custom Labels, as the app's own strings read them
/// (invoiceninja/flutter#84): what `CompanyLabelsScope` hands to
/// `Localization.of`.

class _FakeAuth implements AuthRepository {
  final session_ = ValueNotifier<AuthSession?>(null);
  @override
  ValueListenable<AuthSession?> get session => session_;
  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Each company's row is a stream the test can push into — a save, a Sync
/// or a `/refresh` rewriting it.
class _FakeCompanies implements CompanyRepository {
  final rows = <String, StreamController<Company?>>{};
  @override
  Stream<Company?> watchCompany(String companyId) =>
      (rows[companyId] ??= StreamController<Company?>.broadcast()).stream;
  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeStatics implements StaticsRepository {
  /// A Drift failure under `ensureLoaded` — the store being reset, a locked
  /// web IndexedDB.
  Object? loadError;

  @override
  Future<void> ensureLoaded({bool force = false}) async {
    if (loadError != null) throw loadError!;
  }

  @override
  Map<String, Language> get languages => const {
    '1': Language(id: '1', name: 'English', locale: 'en'),
    '3': Language(id: '3', name: 'German', locale: 'de'),
    // A language this app ships no UI strings for: the app shows English.
    '17': Language(id: '17', name: 'Turkish', locale: 'tr_TR'),
  };
  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

AuthSession _session(String companyId) => AuthSession(
  baseUrl: 'https://example.test',
  isHosted: false,
  accountId: 'acct',
  companies: const [],
  currentCompanyId: companyId,
  plan: 'pro',
);

Company _company(
  String id,
  Map<String, dynamic>? translations, {
  String languageId = '1',
}) => Company(
  id: id,
  settings: CompanySettings(translations: translations, languageId: languageId),
);

void main() {
  group('companyLabelOverrides — what counts as a label', () {
    test('an override is kept', () {
      expect(
        companyLabelOverrides(_company('co', const {'quote': 'Estimate'})),
        {'quote': 'Estimate'},
      );
    });

    test('blank and whitespace-only values are dropped', () {
      // The Custom Labels editor seeds a new row with '' and the server
      // coerces nulls to '' — neither may blank a word across the app.
      expect(
        companyLabelOverrides(
          _company('co', const {'unit_cost': '', 'item': '   '}),
        ),
        isEmpty,
      );
    });

    test('a non-string value is dropped rather than stringified', () {
      // Some accounts store a nested object under a lang key.
      expect(
        companyLabelOverrides(
          _company('co', const {
            'unit_cost': {'a': 'b'},
          }),
        ),
        isEmpty,
      );
    });

    test('no company, or no translations, is no labels', () {
      expect(companyLabelOverrides(null), isEmpty);
      expect(companyLabelOverrides(_company('co', null)), isEmpty);
    });
  });

  group('CompanyLabelOverrides', () {
    late _FakeAuth auth;
    late _FakeCompanies companies;
    late _FakeStatics statics;

    /// What `AppLocaleResolver` says the app shows.
    late ValueNotifier<Locale?> shown;
    late CompanyLabelOverrides labels;

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    setUp(() {
      auth = _FakeAuth();
      companies = _FakeCompanies();
      statics = _FakeStatics();
      shown = ValueNotifier(const Locale('en'));
      labels = CompanyLabelOverrides(
        auth: auth,
        company: companies,
        appLocale: shown,
        statics: statics,
      );
    });
    tearDown(() {
      labels.dispose();
      shown.dispose();
    });

    Future<void> push(
      String id,
      Map<String, dynamic>? t, {
      String lang = '1',
    }) async {
      companies.rows[id]!.add(_company(id, t, languageId: lang));
      await settle();
    }

    test('follows the active company row: a save, a Sync, a switch', () async {
      auth.session_.value = _session('co-A');
      await push('co-A', const {'quote': 'Estimate'});
      expect(labels.value, {'quote': 'Estimate'});

      // The row rewritten — by a save here, or a Sync from another device.
      await push('co-A', const {'quote': 'Proposal'});
      expect(labels.value, {'quote': 'Proposal'});

      // Another company: its labels, never the last one's.
      auth.session_.value = _session('co-B');
      expect(
        labels.value,
        isEmpty,
        reason: 'cleared at the switch, not when co-B\'s row arrives',
      );
      await push('co-B', const {'invoice': 'Bill'});
      expect(labels.value, {'invoice': 'Bill'});
    });

    test('signing out empties them', () async {
      auth.session_.value = _session('co-A');
      await push('co-A', const {'quote': 'Estimate'});
      auth.session_.value = null;
      await settle();
      expect(labels.value, isEmpty);
    });

    test(
      'withheld while the app shows another language than the company\'s',
      () async {
        shown.value = const Locale('de');
        auth.session_.value = _session('co-A');
        await push('co-A', const {'quote': 'Angebot'}, lang: '3'); // German
        expect(labels.value, {'quote': 'Angebot'});
        expect(labels.withheldForLanguage, isFalse);

        // The user set the app to English.
        shown.value = const Locale('en');
        await settle();
        expect(labels.value, isEmpty);
        expect(labels.withheldForLanguage, isTrue);

        shown.value = const Locale('de');
        await settle();
        expect(labels.value, {'quote': 'Angebot'});
        expect(labels.withheldForLanguage, isFalse);
      },
    );

    test('a company language with no UI strings is withheld from the English '
        'app it runs in — no device setting involved', () async {
      auth.session_.value = _session('co-A');
      await push('co-A', const {'quote': 'Teklif'}, lang: '17'); // Turkish
      expect(labels.value, isEmpty);
      expect(labels.withheldForLanguage, isTrue);
    });

    test(
      'an English company in the English app, or no language set: applied',
      () async {
        auth.session_.value = _session('co-A');
        await push('co-A', const {'quote': 'Estimate'});
        expect(labels.value, {'quote': 'Estimate'});
        await push('co-A', const {'quote': 'Estimate'}, lang: '');
        expect(labels.value, {'quote': 'Estimate'});
      },
    );

    test('statics that fail to load: applied unchecked, not left stale, and '
        'no unhandled error', () async {
      statics.loadError = StateError('database is locked');
      auth.session_.value = _session('co-A');
      await push('co-A', const {'quote': 'Angebot'}, lang: '3');
      expect(labels.value, {'quote': 'Angebot'});
    });

    test('an unchanged map does not notify', () async {
      auth.session_.value = _session('co-A');
      await push('co-A', const {'quote': 'Estimate'});
      var notified = 0;
      labels.addListener(() => notified++);
      await push('co-A', const {'quote': 'Estimate'});
      expect(notified, 0, reason: 'every widget that read a string rebuilds');
    });
  });
}
