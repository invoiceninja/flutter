import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_settings.dart';
import 'package:admin/data/models/domain/user.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/user_repository.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/views/advanced/email_settings/email_settings_body.dart';
import 'package:admin/ui/features/settings/views/advanced/email_settings/widgets/smtp_mail_driver_card.dart';

import '../../../../../_localization_helper.dart';

/// Company-scope host backing both the SMTP card (reads [draft]) and the
/// Email Settings body (reads [settings]). At company level
/// `OverridableField.bind` renders children unwrapped, so the override
/// surface ([isOverridden] / [setOverride]) is never reached.
class _FakeHost extends SettingsDraftHost {
  _FakeHost({CompanySettings? settings, Company? company})
    : _settings = settings ?? const CompanySettings(),
      _company = company;

  CompanySettings _settings;
  Company? _company;

  @override
  CompanySettings get settings => _settings;
  @override
  CompanySettings get draftSettings => _settings;
  @override
  CompanySettings get initialSettings => _settings;
  @override
  Company? get draft => _company;
  @override
  Map<String, List<String>> get fieldErrors => const {};

  @override
  void updateSettings(CompanySettings Function(CompanySettings) edit) {
    _settings = edit(_settings);
    notifyListeners();
  }

  @override
  void updateCompany(Company Function(Company) edit) {
    final c = _company;
    if (c != null) _company = edit(c);
    notifyListeners();
  }

  @override
  bool get isLoaded => true;
  @override
  bool get isDirty => false;
  @override
  bool get isSaving => false;
  @override
  String? get loadError => null;
  @override
  String? get submitError => null;
  @override
  void reset() {}
  @override
  Future<Object?> save() async => null;
  @override
  Future<void> load() async {}
}

class _FakeAuth implements AuthRepository {
  _FakeAuth(this._session);
  final ValueNotifier<AuthSession?> _session;
  @override
  ValueListenable<AuthSession?> get session => _session;
  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeServices implements Services {
  _FakeServices({required this.auth, UserRepository? user})
    : user = user ?? _FakeUserRepo();
  @override
  final AuthRepository auth;
  @override
  final UserRepository user;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Minimal [UserRepository] stub so the Gmail/Microsoft [OauthUserPicker]'s
/// StreamBuilder builds without the real DB. Returns no eligible users, so the
/// picker shows its harmless "connect via the web app" empty state.
class _FakeUserRepo implements UserRepository {
  @override
  Stream<List<User>> watchEmailSendingUsers({
    required String companyId,
    required String provider,
  }) => Stream<List<User>>.value(const <User>[]);

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

AuthSession _session({required bool isHosted, String plan = ''}) => AuthSession(
  baseUrl: 'https://example.test',
  isHosted: isHosted,
  accountId: 'acct',
  companies: const [],
  currentCompanyId: 'co-A',
  plan: plan,
);

void main() {
  // ── SMTP encryption dropdown (Fix 1: lowercase tls/ssl + crash-proof) ──────
  group('SmtpMailDriverCard encryption dropdown', () {
    Future<void> pumpCard(WidgetTester tester, String encryption) async {
      final host = _FakeHost(
        company: Company(id: 'co-A', smtpEncryption: encryption),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider<SettingsLevelController>.value(
                  value: SettingsLevelController(),
                ),
                ChangeNotifierProvider<SettingsDraftHost>.value(value: host),
              ],
              child: const SingleChildScrollView(child: SmtpMailDriverCard()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // Every value the server / React / legacy admin-portal can store must map
    // onto an item — otherwise the raw DropdownButtonFormField asserts
    // "value not in items". '' / tls / TLS / starttls collapse to STARTTLS;
    // ssl shows SSL/TLS.
    for (final entry in const {
      '': 'STARTTLS',
      'tls': 'STARTTLS',
      'TLS': 'STARTTLS',
      'STARTTLS': 'STARTTLS',
      'ssl': 'SSL/TLS',
    }.entries) {
      testWidgets('renders ${entry.value} for stored "${entry.key}" '
          'without asserting', (tester) async {
        await pumpCard(tester, entry.key);
        expect(tester.takeException(), isNull);
        expect(find.text(entry.value), findsOneWidget);
      });
    }
  });

  // ── Provider dropdown (Fix 2: self-hosted default; Fix 7: free-tier lock) ──
  group('EmailSettingsBody provider dropdown', () {
    Future<_FakeHost> pumpBody(
      WidgetTester tester, {
      required AuthSession session,
      String method = 'default',
      Company company = const Company(id: 'co-A'),
      Size viewport = const Size(900, 2600),
    }) async {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final host = _FakeHost(
        settings: CompanySettings(emailSendingMethod: method),
        company: company,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            body: MultiProvider(
              providers: [
                Provider<Services>.value(
                  value: _FakeServices(auth: _FakeAuth(ValueNotifier(session))),
                ),
                ChangeNotifierProvider<SettingsLevelController>.value(
                  value: SettingsLevelController(),
                ),
                ChangeNotifierProvider<SettingsDraftHost>.value(value: host),
              ],
              child: const EmailSettingsBody(),
            ),
          ),
        ),
      );
      // Avoid pumpAndSettle: the signature MarkdownField (super_editor) never
      // settles. Two frames are enough to build the provider section.
      await tester.pump();
      await tester.pump();
      return host;
    }

    // The provider dropdown is the first String-typed dropdown in the tree
    // (Section 1). send_time is DropdownButton<int>, so it isn't matched.
    DropdownButton<String> providerDropdown(WidgetTester tester) =>
        tester.widget<DropdownButton<String>>(
          find.byType(DropdownButton<String>).first,
        );

    testWidgets('self-hosted exposes the Default option (not a blank field)', (
      tester,
    ) async {
      await pumpBody(tester, session: _session(isHosted: false));
      expect(tester.takeException(), isNull);
      // Selected provider renders its label — proves `default` is in the
      // self-hosted item set (before the fix the dropdown was blank).
      expect(find.text('Default'), findsOneWidget);
      expect(providerDropdown(tester).onChanged, isNotNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('free/trial hosted locks the provider dropdown', (
      tester,
    ) async {
      await pumpBody(tester, session: _session(isHosted: true));
      expect(tester.takeException(), isNull);
      // null onChanged => greyed/disabled (React parity).
      expect(providerDropdown(tester).onChanged, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('pro hosted keeps the provider dropdown editable', (
      tester,
    ) async {
      await pumpBody(tester, session: _session(isHosted: true, plan: 'pro'));
      expect(tester.takeException(), isNull);
      expect(providerDropdown(tester).onChanged, isNotNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    // A legacy company stored as 'microsoft' (server alias of 'office365') must
    // still select the Microsoft item. The dropdown only offers 'office365', so
    // without the coalesce the value-not-in-items guard would blank the field.
    testWidgets('legacy "microsoft" method selects Microsoft (not blank)', (
      tester,
    ) async {
      await pumpBody(
        tester,
        session: _session(isHosted: true, plan: 'pro'),
        method: 'microsoft',
      );
      expect(tester.takeException(), isNull);
      expect(providerDropdown(tester).value, 'office365');
      expect(find.text('Microsoft'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    // Issue #28: the leading coloured dot read as a connection-status light
    // (the grey SMTP/Default fallback looked like "offline", right above the
    // Send Test Email button). Every branded option must stay a bare Text;
    // SMTP is the one Row, because it carries the Pro chip.
    testWidgets('provider options carry no decorative colour swatch', (
      tester,
    ) async {
      await pumpBody(tester, session: _session(isHosted: true, plan: 'pro'));
      final items = providerDropdown(tester).items!;
      expect(items, isNotEmpty);
      for (final item in items.where((i) => i.value != 'smtp')) {
        expect(item.child, isA<Text>(), reason: 'provider ${item.value}');
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    // Issue #29: switching the provider away and back must not blank the SMTP
    // card. The card unmounts while another provider is selected and re-seeds
    // its controllers from `host.draft` on remount, so nothing in this flow may
    // drop the seven top-level Company.smtp* fields. (The real data loss was a
    // layer down — a full sync used to re-seed the companies row from an
    // envelope that didn't carry them — but this guards the UI half.)
    testWidgets('SMTP fields survive a provider round-trip', (tester) async {
      const configured = Company(
        id: 'co-A',
        smtpHost: 'smtp.example.com',
        smtpPort: 587,
        smtpUsername: 'postmaster@example.com',
        smtpLocalDomain: 'mail.example.com',
      );
      final host = await pumpBody(
        tester,
        session: _session(isHosted: true, plan: 'pro'),
        method: 'smtp',
        company: configured,
        viewport: const Size(900, 4200),
      );
      expect(find.text('smtp.example.com'), findsOneWidget);
      expect(find.text('postmaster@example.com'), findsOneWidget);

      // Away…
      host.updateSettings(
        (s) => s.copyWith(emailSendingMethod: 'client_postmark'),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(SmtpMailDriverCard), findsNothing);

      // …and back.
      host.updateSettings((s) => s.copyWith(emailSendingMethod: 'smtp'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(SmtpMailDriverCard), findsOneWidget);
      expect(find.text('smtp.example.com'), findsOneWidget);
      expect(find.text('postmaster@example.com'), findsOneWidget);
      expect(find.text('mail.example.com'), findsOneWidget);
      expect(find.text('587'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
