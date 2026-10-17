import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/back_online_signal.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/sync_repository.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/connectivity_watcher.dart';
import 'package:admin/data/services/refresh_scheduler.dart';
import 'package:admin/data/services/tls/certificate_facts.dart';
import 'package:admin/data/services/tls/certificate_trust_store.dart';
import 'package:admin/ui/core/widgets/certificate_banner.dart';
import 'package:admin/utils/formatting.dart';

import '../../../_localization_helper.dart';

final _old = CertificateFacts(
  sha256: 'aa' * 32,
  subject: '/CN=ninja.lan',
  issuer: '/CN=ninja.lan',
  notBefore: DateTime.utc(2025, 1, 1, 12),
  notAfter: DateTime.utc(2026, 1, 1, 12),
  subjectAltNames: const ['ninja.lan'],
);
final _renewed = CertificateFacts(
  sha256: 'bb' * 32,
  subject: '/CN=ninja.lan',
  issuer: '/CN=ninja.lan',
  notBefore: DateTime.utc(2026, 1, 1, 12),
  notAfter: DateTime.utc(2027, 1, 1, 12),
  subjectAltNames: const ['ninja.lan'],
);

class _FakeAuth implements AuthRepository {
  _FakeAuth(ApiCredentials creds) : credentials = ValueNotifier(creds);

  @override
  final ValueNotifier<ApiCredentials?> credentials;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeSync implements SyncRepository {
  final drained = <String>[];

  @override
  Future<int> drainOnce({required String companyId}) async {
    drained.add(companyId);
    return 0;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeRefresh implements RefreshScheduler {
  int requests = 0;

  @override
  Future<bool> requestSoon() async {
    requests++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeServices implements Services {
  _FakeServices(this.auth, {required bool online})
    : connectivity = ConnectivityWatcher.fixed(online: online);

  @override
  final AuthRepository auth;
  @override
  final ConnectivityWatcher connectivity;
  @override
  final _FakeSync sync = _FakeSync();
  @override
  final _FakeRefresh refreshScheduler = _FakeRefresh();
  @override
  final BackOnlineSignal backOnline = BackOnlineSignal();
  @override
  Formatter? formatterIfReady(String companyId) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Finder get _banner => find.byKey(const ValueKey('certificate_banner'));

void main() {
  late CertificateTrustStore trust;
  late _FakeServices services;

  setUp(() => trust = CertificateTrustStore(prefs: DevicePrefsStore(null)));

  Future<void> pump(
    WidgetTester tester, {
    String baseUrl = 'https://ninja.lan',
    bool isHosted = false,
    bool online = true,
    bool withStore = true,
    double textScale = 1,
  }) async {
    services = _FakeServices(
      _FakeAuth(
        ApiCredentials(
          baseUrl: baseUrl,
          token: 't',
          isHosted: isHosted,
          companyId: 'c1',
        ),
      ),
      online: online,
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<Services>.value(value: services),
          if (withStore)
            ChangeNotifierProvider<CertificateTrustStore>.value(value: trust),
        ],
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const Scaffold(body: CertificateBanner()),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> refuse(
    WidgetTester tester,
    String host,
    CertificateFacts f,
  ) async {
    trust.recordRejection(host, 443, f);
    await tester.pump(); // the store notifies on a microtask
    await tester.pump();
  }

  testWidgets('nothing until the signed-in server is refused', (tester) async {
    await pump(tester);
    expect(_banner, findsNothing);

    await refuse(tester, 'elsewhere.example.com', _renewed);
    expect(_banner, findsNothing, reason: 'another server is not ours');

    await refuse(tester, 'ninja.lan', _renewed);
    expect(_banner, findsOneWidget);
    expect(
      find.textContaining("ninja.lan's certificate can't be verified"),
      findsOneWidget,
    );
  });

  testWidgets('a renewed certificate on a trusted server says it changed', (
    tester,
  ) async {
    await trust.trust('ninja.lan', 443, _old);
    await pump(tester);
    await refuse(tester, 'ninja.lan', _renewed);
    expect(
      find.textContaining('has changed since you trusted it'),
      findsOneWidget,
    );
  });

  testWidgets('Review → Trust clears it and sends what waited', (tester) async {
    await trust.trust('ninja.lan', 443, _old);
    await pump(tester);
    await refuse(tester, 'ninja.lan', _renewed);

    await tester.tap(find.byKey(const ValueKey('certificate_banner_review')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('certificate_replacing_warning')),
      findsOneWidget,
    );
    expect(find.text('Trust certificate'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('certificate_trust')));
    await tester.pumpAndSettle();

    expect(trust.isTrusted('ninja.lan', 443, _renewed.sha256), isTrue);
    expect(_banner, findsNothing);
    expect(services.sync.drained, ['c1']);
    expect(services.refreshScheduler.requests, 1);
  });

  testWidgets('clears itself when the server answers again', (tester) async {
    await pump(tester);
    await refuse(tester, 'ninja.lan', _renewed);
    expect(_banner, findsOneWidget);

    trust.noteReached('ninja.lan', 443);
    await tester.pump();
    await tester.pump();
    expect(_banner, findsNothing);
  });

  testWidgets('hosted: explained, never offered for review', (tester) async {
    await pump(tester, baseUrl: 'https://invoicing.co', isHosted: true);
    await refuse(tester, 'invoicing.co', _renewed);
    expect(_banner, findsOneWidget);
    expect(find.textContaining('intercepting'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('certificate_banner_review')),
      findsNothing,
    );
  });

  // One test per strip: a second pump of the same tree keeps the banner's
  // State, and with it the first strip's credentials.
  for (final (baseUrl, host, isHosted, phrase) in [
    ('https://invoicing.co', 'invoicing.co', true, 'intercepting'),
    ('https://ninja.lan', 'ninja.lan', false, "can't be verified"),
  ]) {
    testWidgets('the $host strip reads in full on a phone at 1.4× text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(tester, baseUrl: baseUrl, isHosted: isHosted, textScale: 1.4);
      await refuse(tester, host, _renewed);
      // The message's own paragraph — not the icon's, which is a RichText too.
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.textContaining(phrase),
          matching: find.byType(RichText),
        ),
      );
      expect(paragraph.maxLines, isNull, reason: 'never clamped');
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('stands down while offline', (tester) async {
    await pump(tester, online: false);
    await refuse(tester, 'ninja.lan', _renewed);
    expect(_banner, findsNothing);
  });

  testWidgets('without the root provider it is inert', (tester) async {
    await pump(tester, withStore: false);
    expect(_banner, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
