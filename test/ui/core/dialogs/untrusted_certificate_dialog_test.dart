import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/services/tls/certificate_facts.dart';
import 'package:admin/data/services/tls/certificate_problems.dart';
import 'package:admin/data/services/tls/certificate_trust_store.dart';
import 'package:admin/ui/core/dialogs/untrusted_certificate_dialog.dart';

import '../../../_localization_helper.dart';

final _registrar = CertificateFacts(
  sha256: 'cd' * 32,
  subject: '/CN=*.registrar-servers.com',
  issuer:
      '/C=GB/O=Sectigo Limited/CN=Sectigo Public Server Authentication CA DV R36',
  notBefore: DateTime.utc(2025, 11, 7, 12),
  notAfter: DateTime.utc(2026, 11, 17, 12),
  subjectAltNames: const ['*.registrar-servers.com', 'registrar-servers.com'],
);

final _selfSigned = CertificateFacts(
  sha256: 'ef' * 32,
  subject: '/CN=invoiceninja',
  issuer: '/CN=invoiceninja',
  notBefore: DateTime.utc(2026, 1, 1, 12),
  notAfter: DateTime.utc(2036, 1, 1, 12),
  subjectAltNames: const ['192.168.0.10'],
);

void main() {
  /// Opens the dialog from a button and returns a getter for its result.
  Future<bool? Function()> open(
    WidgetTester tester, {
    String host = 'pay.example.com',
    CertificateFacts? facts,
    List<CertificateProblem> problems = const [CertificateProblem.nameMismatch],
    bool canTrust = true,
    TrustedCertificate? replacing,
    bool continues = true,
    double textScale = 1,
  }) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async =>
                    result = await showUntrustedCertificateDialog(
                      context,
                      host: host,
                      port: 443,
                      certificate: facts ?? _registrar,
                      problems: problems,
                      canTrust: canTrust,
                      replacing: replacing,
                      continues: continues,
                    ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => result;
  }

  testWidgets(
    'a shared-hosting default: what is wrong, how to fix it, then facts',
    (tester) async {
      await open(tester);
      expect(find.text("Can't verify pay.example.com"), findsOneWidget);
      expect(
        find.textContaining(
          'pay.example.com is sending a certificate for '
          '*.registrar-servers.com, registrar-servers.com',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('issue a certificate for pay.example.com'),
        findsOneWidget,
      );
      // A public server presenting someone else's name: the strong wording.
      expect(find.textContaining('impersonating'), findsOneWidget);
      expect(
        find.text('Sectigo Public Server Authentication CA DV R36'),
        findsOneWidget,
      );
      expect(find.text(_registrar.displayFingerprint), findsOneWidget);
      expect(find.text('2026-11-17'), findsWidgets);
      expect(find.text('Trust and continue'), findsOneWidget);
    },
  );

  testWidgets('a self-signed certificate on the LAN reads as normal', (
    tester,
  ) async {
    await open(
      tester,
      host: '192.168.0.10',
      facts: _selfSigned,
      problems: const [CertificateProblem.selfSigned],
    );
    expect(
      find.textContaining(
        '192.168.0.10 uses a self-signed certificate. '
        "That's common for a server on your own network.",
      ),
      findsOneWidget,
    );
    expect(find.textContaining('impersonating'), findsNothing);
    expect(
      find.text(
        'Only trust it if you know this is your server. '
        'Any other certificate will still be refused.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a self-signed name mismatch on the LAN blames no hosting '
      'provider', (tester) async {
    // The homelab case: a certificate made for one name, reached by IP.
    await open(
      tester,
      host: '192.168.0.10',
      facts: CertificateFacts(
        sha256: '12' * 32,
        subject: '/CN=invoiceninja.local',
        issuer: '/CN=invoiceninja.local',
        notBefore: DateTime.utc(2026, 1, 1, 12),
        notAfter: DateTime.utc(2036, 1, 1, 12),
        subjectAltNames: const ['invoiceninja.local'],
      ),
      problems: const [
        CertificateProblem.nameMismatch,
        CertificateProblem.selfSigned,
      ],
    );
    expect(
      find.text(
        '192.168.0.10 is sending a certificate for invoiceninja.local.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Connect using the address the certificate was made'),
      findsOneWidget,
    );
    expect(find.textContaining('hosting'), findsNothing);
    expect(find.textContaining('impersonating'), findsNothing);
  });

  testWidgets('a CA-issued mismatch on a LAN host blames no hosting provider '
      'either', (tester) async {
    await open(tester, host: '10.0.0.5');
    expect(find.textContaining('hosting'), findsNothing);
    expect(
      find.textContaining('Connect using the address the certificate was made'),
      findsOneWidget,
    );
  });

  testWidgets('every problem after the lead gets a line', (tester) async {
    await open(
      tester,
      problems: const [
        CertificateProblem.expired,
        CertificateProblem.nameMismatch,
        CertificateProblem.selfSigned,
      ],
    );
    expect(
      find.textContaining('The certificate for pay.example.com expired on'),
      findsOneWidget,
    );
    expect(find.textContaining('check this device'), findsOneWidget);
    expect(find.textContaining("It's issued to"), findsOneWidget);
    expect(find.textContaining("It's self-signed."), findsOneWidget);
  });

  testWidgets('a changed certificate on a trusted server says so first', (
    tester,
  ) async {
    await open(
      tester,
      replacing: TrustedCertificate(
        host: 'pay.example.com',
        port: 443,
        facts: _selfSigned,
        trustedAt: DateTime.utc(2026, 3, 2, 12),
      ),
      continues: false,
    );
    expect(
      find.byKey(const ValueKey('certificate_replacing_warning')),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        "This isn't the certificate you trusted on 2026-03-02",
      ),
      findsOneWidget,
    );
    expect(find.text('Trust certificate'), findsOneWidget);
  });

  testWidgets('Cancel holds the focus, so Enter trusts nothing', (
    tester,
  ) async {
    final result = await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(result(), isFalse);
  });

  testWidgets('Trust returns true', (tester) async {
    final result = await open(tester);
    await tester.tap(find.byKey(const ValueKey('certificate_trust')));
    await tester.pumpAndSettle();
    expect(result(), isTrue);
  });

  testWidgets('Cancel and Trust sit side by side', (tester) async {
    await open(tester);
    final cancel = tester.getCenter(
      find.widgetWithText(OutlinedButton, 'Cancel'),
    );
    final trust = tester.getCenter(
      find.byKey(const ValueKey('certificate_trust')),
    );
    expect(cancel.dy, moreOrLessEquals(trust.dy, epsilon: 1));
    expect(cancel.dx, lessThan(trust.dx));
  });

  testWidgets("when it can't be trusted, Close is the only action", (
    tester,
  ) async {
    await open(tester, canTrust: false);
    expect(find.byKey(const ValueKey('certificate_trust')), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Close'), findsOneWidget);
    // No "only trust it if…" for something that can't be trusted.
    expect(find.textContaining('Only trust it'), findsNothing);
  });

  testWidgets('Copy details is offered', (tester) async {
    await open(tester);
    expect(
      find.byKey(const ValueKey('certificate_copy_details')),
      findsOneWidget,
    );
  });

  testWidgets('fits a phone at 1.4× text', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await open(
      tester,
      textScale: 1.4,
      problems: const [
        CertificateProblem.expired,
        CertificateProblem.nameMismatch,
        CertificateProblem.selfSigned,
      ],
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
