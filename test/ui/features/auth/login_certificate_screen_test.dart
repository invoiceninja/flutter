import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/auth_service.dart';
import 'package:admin/data/services/tls/certificate_facts.dart';
import 'package:admin/data/services/tls/certificate_problems.dart';
import 'package:admin/data/services/tls/certificate_trust_store.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';
import 'package:admin/ui/features/auth/views/login_screen.dart';

import '../../../_localization_helper.dart';

/// The login screen's half of a refused certificate: the dialog, the retry
/// after Trust, and the line under Server URL that can take it back.

final _facts = CertificateFacts(
  sha256: 'cd' * 32,
  subject: '/CN=*.registrar-servers.com',
  issuer: '/C=GB/O=Sectigo Limited/CN=Sectigo DV R36',
  notBefore: DateTime.utc(2025, 11, 7, 12),
  notAfter: DateTime.utc(2099, 11, 17, 12),
  subjectAltNames: const ['*.registrar-servers.com'],
);

/// Refuses the first [refusals] prechecks, then answers.
class _FakeAuth implements AuthRepository {
  _FakeAuth({this.refusals = 1});

  int refusals;
  int precheckCalls = 0;

  @override
  Future<LoginPrecheck?> precheckLogin({
    required String baseUrl,
    required bool isHosted,
    required String email,
  }) async {
    precheckCalls++;
    if (refusals > 0) {
      refusals--;
      throw UntrustedCertificateException(
        host: Uri.parse(baseUrl).host,
        port: 443,
        certificate: _facts,
        problems: const [CertificateProblem.nameMismatch],
      );
    }
    return const LoginPrecheck(methods: {'password'}, secretRequired: false);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeServices implements Services {
  _FakeServices(this.auth);
  @override
  final AuthRepository auth;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Finder _key(String key) => find.byKey(ValueKey(key));
Finder _input(String key) =>
    find.descendant(of: _key(key), matching: find.byType(TextField));

void main() {
  late CertificateTrustStore trust;
  late ToastController toasts;

  Future<_FakeAuth> pumpLogin(WidgetTester tester, {int refusals = 1}) async {
    final auth = _FakeAuth(refusals: refusals);
    trust = CertificateTrustStore(prefs: DevicePrefsStore(null));
    toasts = ToastController();
    addTearDown(toasts.clearAll);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<Services>.value(value: _FakeServices(auth)),
          ChangeNotifierProvider<ToastController>.value(value: toasts),
          ChangeNotifierProvider<CertificateTrustStore>.value(value: trust),
        ],
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pump();
    tester.takeException(); // the logo asset
    return auth;
  }

  Future<void> continueSelfHosted(WidgetTester tester) async {
    await tester.tap(find.text('Self-Hosted'));
    await tester.pump();
    await tester.enterText(_input('login_url'), 'https://pay.example.com');
    await tester.enterText(_input('login_email'), 'a@b.co');
    await tester.tap(_key('login_continue'));
    await tester.pumpAndSettle();
  }

  testWidgets('Continue → the dialog → Trust and continue → step 2', (
    tester,
  ) async {
    final auth = await pumpLogin(tester);
    await continueSelfHosted(tester);

    expect(find.text("Can't verify pay.example.com"), findsOneWidget);
    expect(toasts.toasts, isEmpty, reason: 'explained, not toasted');

    await tester.tap(_key('certificate_trust'));
    await tester.pumpAndSettle();

    expect(trust.isTrusted('pay.example.com', 443, _facts.sha256), isTrue);
    expect(auth.precheckCalls, 2);
    expect(_key('login_password'), findsOneWidget);
  });

  testWidgets('Cancel stays on step 1 and trusts nothing', (tester) async {
    final auth = await pumpLogin(tester);
    await continueSelfHosted(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(trust.pins, isEmpty);
    expect(auth.precheckCalls, 1);
    expect(_key('login_password'), findsNothing);
    expect(_key('login_continue'), findsOneWidget);
  });

  testWidgets('the Server URL line shows a trust and Forget takes it back', (
    tester,
  ) async {
    await pumpLogin(tester, refusals: 0);
    await trust.trust('pay.example.com', 443, _facts);
    await tester.tap(find.text('Self-Hosted'));
    await tester.pump();
    expect(_key('login_trusted_certificate'), findsNothing);

    await tester.enterText(_input('login_url'), 'https://pay.example.com');
    await tester.pump();
    expect(_key('login_trusted_certificate'), findsOneWidget);
    expect(
      find.text('Using a certificate you trusted for this server'),
      findsOneWidget,
    );

    await tester.tap(_key('login_forget_certificate'));
    await tester.pumpAndSettle();
    expect(trust.pins, isEmpty);
    expect(_key('login_trusted_certificate'), findsNothing);
  });
}
