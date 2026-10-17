import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/confirm_actions_controller.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/tls/certificate_facts.dart';
import 'package:admin/data/services/tls/certificate_trust_store.dart';
import 'package:admin/ui/features/settings/widgets/trusted_certificates_section.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../_localization_helper.dart';

CertificateFacts _facts(String byte, {DateTime? notAfter}) => CertificateFacts(
  sha256: byte * 32,
  subject: '/CN=ninja.lan',
  issuer: '/CN=ninja.lan',
  notBefore: DateTime.utc(2025, 1, 1, 12),
  notAfter: notAfter ?? DateTime.utc(2099, 1, 1, 12),
  subjectAltNames: const ['ninja.lan'],
);

class _FakeAuth implements AuthRepository {
  @override
  final ValueNotifier<AuthSession?> session = ValueNotifier(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeServices implements Services {
  _FakeServices(this.confirmActions);

  @override
  final AuthRepository auth = _FakeAuth();
  @override
  final ConfirmActionsController confirmActions;
  @override
  Formatter? formatterIfReady(String companyId) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late DevicePrefsStore prefs;
  late CertificateTrustStore trust;

  setUp(() {
    prefs = DevicePrefsStore(null);
    trust = CertificateTrustStore(prefs: prefs);
  });

  Future<void> pump(WidgetTester tester, {bool confirm = false}) async {
    final confirmActions = ConfirmActionsController(prefs: prefs);
    await confirmActions.set(confirm);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<Services>.value(value: _FakeServices(confirmActions)),
          ChangeNotifierProvider<CertificateTrustStore>.value(value: trust),
        ],
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(child: TrustedCertificatesSection()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('absent while nothing is trusted', (tester) async {
    await pump(tester);
    expect(find.text('Trusted certificates'), findsNothing);
  });

  testWidgets('lists each trust, and says when one has expired', (
    tester,
  ) async {
    await trust.trust('ninja.lan', 443, _facts('aa'));
    await trust.trust(
      'old.lan',
      8443,
      _facts('bb', notAfter: DateTime.utc(2020, 1, 1, 12)),
    );
    await pump(tester);

    expect(find.text('Trusted certificates'), findsOneWidget);
    expect(find.text('ninja.lan'), findsOneWidget);
    expect(find.text('old.lan:8443'), findsOneWidget);
    expect(find.textContaining('Expired'), findsOneWidget);
    expect(find.textContaining('AA:AA:AA:AA:AA:AA:AA:AA…'), findsOneWidget);
  });

  testWidgets('Stop trusting removes it — and the card with the last one', (
    tester,
  ) async {
    await trust.trust('ninja.lan', 443, _facts('aa'));
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('stop_trusting_ninja.lan:443')));
    await tester.pumpAndSettle();
    expect(trust.pins, isEmpty);
    expect(find.text('Trusted certificates'), findsNothing);
  });

  testWidgets('asks first when Confirm actions is on', (tester) async {
    await trust.trust('ninja.lan', 443, _facts('aa'));
    await pump(tester, confirm: true);
    await tester.tap(find.byKey(const ValueKey('stop_trusting_ninja.lan:443')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(trust.pins, hasLength(1));
  });
}
