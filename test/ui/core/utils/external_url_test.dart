import 'package:admin/ui/core/utils/external_url.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../_localization_helper.dart';
import '../../../_support/fake_url_launcher.dart';

/// Payment Links' View button reported "Couldn't open the link" for a URL that
/// pasted into a browser fine, because every external link in the app gated on
/// `canLaunchUrl` — a package-visibility query that answers false on plenty of
/// Android devices where the launch itself works (invoiceninja/flutter#80).
/// That is why `FakeUrlLauncher.canLaunch` returns a flat false and why
/// `canLaunchCalls` is asserted to be 0 below.
void main() {
  late UrlLauncherPlatform original;

  setUp(() => original = UrlLauncherPlatform.instance);
  tearDown(() => UrlLauncherPlatform.instance = original);

  group('launchExternalUri', () {
    test('launches without ever consulting canLaunchUrl', () async {
      final fake = FakeUrlLauncher();
      UrlLauncherPlatform.instance = fake;

      expect(await launchExternalUri(Uri.parse('https://example.com/x')), true);
      expect(fake.launched, ['https://example.com/x']);
      expect(fake.modes.single, PreferredLaunchMode.externalApplication);
      // The gate is the whole bug — it must not be reintroduced.
      expect(fake.canLaunchCalls, 0);
    });

    test('falls back to the platform default when external fails', () async {
      final fake = FakeUrlLauncher(results: [false, true]);
      UrlLauncherPlatform.instance = fake;

      expect(await launchExternalUri(Uri.parse('https://example.com')), true);
      expect(fake.modes, [
        PreferredLaunchMode.externalApplication,
        PreferredLaunchMode.platformDefault,
      ]);
    });

    test('reports failure when every mode fails', () async {
      final fake = FakeUrlLauncher(results: [false]);
      UrlLauncherPlatform.instance = fake;

      expect(await launchExternalUri(Uri.parse('https://example.com')), false);
      expect(fake.launched, hasLength(2));
    });

    test('swallows a thrown launch and reports failure', () async {
      final fake = FakeUrlLauncher(throwOnLaunch: true);
      UrlLauncherPlatform.instance = fake;

      expect(await launchExternalUri(Uri.parse('https://example.com')), false);
    });
  });

  group('openExternalUrl', () {
    late ToastController toasts;

    setUp(() => toasts = ToastController());
    tearDown(() => toasts.dispose());

    // `Notify` prefers a provided ToastController over `Services`; reading the
    // queue is cheaper (and less brittle) than driving the real ToastHost.
    Future<BuildContext> pumpContext(WidgetTester tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: ChangeNotifierProvider<ToastController>.value(
            value: toasts,
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  captured = context;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      return captured;
    }

    testWidgets('opens a safe URL and shows no toast', (tester) async {
      final fake = FakeUrlLauncher();
      UrlLauncherPlatform.instance = fake;
      final context = await pumpContext(tester);

      expect(await openExternalUrl(context, 'https://example.com/p'), true);
      await tester.pumpAndSettle();

      expect(fake.launched, ['https://example.com/p']);
      expect(toasts.toasts, isEmpty);
    });

    testWidgets('toasts when the launch fails', (tester) async {
      final fake = FakeUrlLauncher(results: [false]);
      UrlLauncherPlatform.instance = fake;
      final context = await pumpContext(tester);

      expect(await openExternalUrl(context, 'https://example.com'), false);
      await tester.pump();

      expect(toasts.toasts.single.message, "Couldn't open the link");
      // Drain the toast's auto-dismiss timer so the binding's
      // "timer still pending" invariant doesn't fire at teardown.
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('never launches an unsafe scheme', (tester) async {
      final fake = FakeUrlLauncher();
      UrlLauncherPlatform.instance = fake;
      final context = await pumpContext(tester);

      expect(await openExternalUrl(context, 'javascript:alert(1)'), false);
      await tester.pump();

      expect(fake.launched, isEmpty);
      expect(toasts.toasts.single.message, "Couldn't open the link");
      await tester.pump(const Duration(seconds: 10));
    });
  });
}
