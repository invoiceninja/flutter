// Pins the white-label offer predicates and — critically — the checkout URL.
//
// The URL assertion is not ceremony: the constant this replaced
// (`https://invoiceninja.com/self-host-white-label/`, on the Overview tab)
// was a marketing path that returns 404, and nothing caught it because
// nothing pinned it. Both reference apps point at the subscription below
// (React `Licence.tsx:39-41`, admin-portal `constants.dart:21-22`).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/domain/upgrade/white_label.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';

import '../../_localization_helper.dart';

AuthSession _session({
  required bool isHosted,
  String plan = '',
  String baseUrl = 'https://selfhost.example.test',
  bool isAdmin = false,
  bool isOwner = false,
  bool withCompany = true,
}) => AuthSession(
  baseUrl: baseUrl,
  isHosted: isHosted,
  accountId: 'acct',
  companies: [
    if (withCompany)
      AuthCompany(
        id: 'co-A',
        name: 'Co A',
        displayName: 'Co A',
        permissions: '',
        isAdmin: isAdmin,
        isOwner: isOwner,
      ),
  ],
  currentCompanyId: withCompany ? 'co-A' : '',
  plan: plan,
);

void main() {
  test('checkout URL is the live subscription both reference apps use', () {
    expect(
      kWhiteLabelPurchaseUrl,
      'https://invoiceninja.invoicing.co/client/subscriptions/O5xe7Rwd7r/purchase',
    );
  });

  group('canPurchaseWhiteLabel', () {
    test('offered to an unlicensed self-host', () {
      expect(canPurchaseWhiteLabel(_session(isHosted: false)), isTrue);
    });

    test('a failed claim leaves plan == "free" and is still an offer', () {
      // `LicenseController` resets the slug to 'free' on a failed legacy
      // claim, which must not read as "already licensed".
      expect(
        canPurchaseWhiteLabel(_session(isHosted: false, plan: 'free')),
        isTrue,
      );
    });

    test('not offered once licensed', () {
      expect(
        canPurchaseWhiteLabel(_session(isHosted: false, plan: 'white_label')),
        isFalse,
      );
    });

    test('never offered on hosted — claim_license 400s there', () {
      expect(canPurchaseWhiteLabel(_session(isHosted: true)), isFalse);
    });

    test('never offered on the demo server', () {
      // Load-bearing: the demo bootstrap logs in with `isHosted: false`, so
      // the public GitHub Pages build satisfies isSelfHosted and would
      // otherwise grow a live checkout link on every screen.
      expect(
        canPurchaseWhiteLabel(_session(isHosted: false, baseUrl: kDemoBaseUrl)),
        isFalse,
      );
    });

    test('null session is not an offer', () {
      expect(canPurchaseWhiteLabel(null), isFalse);
    });
  });

  group('showWhiteLabelCard', () {
    test('shown to an unlicensed self-host', () {
      expect(showWhiteLabelCard(_session(isHosted: false)), isTrue);
    });

    test('still shown once licensed — a renewed key needs re-applying', () {
      expect(
        showWhiteLabelCard(_session(isHosted: false, plan: 'white_label')),
        isTrue,
      );
    });

    test('NEVER shown on hosted, even on the white_label slug', () {
      // `white_label` is a hosted tier too (`_kProSlugs`, hosted billing's
      // `whitelabel` product), so the bare `isWhiteLabeled` this replaced
      // leaked the card onto hosted next to the upgrade card — where its
      // Apply License would POST a claim the server 400s.
      for (final plan in const ['', 'pro', 'enterprise', 'white_label']) {
        expect(
          showWhiteLabelCard(_session(isHosted: true, plan: plan)),
          isFalse,
          reason: 'hosted plan "$plan" must not get the self-hosted card',
        );
      }
    });

    test('hidden on demo, licensed or not', () {
      for (final plan in const ['', 'white_label']) {
        expect(
          showWhiteLabelCard(
            _session(isHosted: false, plan: plan, baseUrl: kDemoBaseUrl),
          ),
          isFalse,
        );
      }
    });

    test('null session shows nothing', () {
      expect(showWhiteLabelCard(null), isFalse);
    });
  });

  group('shouldNagForWhiteLabel — persistent chrome adds a role check', () {
    test('shown to an owner', () {
      expect(
        shouldNagForWhiteLabel(_session(isHosted: false, isOwner: true)),
        isTrue,
      );
    });

    test('shown to an admin', () {
      expect(
        shouldNagForWhiteLabel(_session(isHosted: false, isAdmin: true)),
        isTrue,
      );
    });

    test('hidden from a plain user who could not act on it', () {
      expect(shouldNagForWhiteLabel(_session(isHosted: false)), isFalse);
    });

    test('fails closed while the company is still loading', () {
      expect(
        shouldNagForWhiteLabel(_session(isHosted: false, withCompany: false)),
        isFalse,
      );
    });

    test('inherits every canPurchaseWhiteLabel disqualifier', () {
      for (final s in [
        _session(isHosted: true, isOwner: true),
        _session(isHosted: false, plan: 'white_label', isOwner: true),
        _session(isHosted: false, baseUrl: kDemoBaseUrl, isOwner: true),
      ]) {
        expect(shouldNagForWhiteLabel(s), isFalse);
      }
    });
  });

  group('launchWhiteLabelPurchase', () {
    // There is no `url_launcher` platform implementation under `flutter test`,
    // so `canLaunchUrl` throws `MissingPluginException`. That is the branch
    // worth pinning: the launcher must swallow it and surface a toast rather
    // than let it escape to the zone handler as a crash. The success path is a
    // thin `launchUrl` passthrough and the URL itself is pinned above.
    //
    // Driven through `runAsync` + a captured context rather than a button tap:
    // the call awaits a real platform-channel round-trip, which `pumpAndSettle`
    // does NOT flush (it advances fake async only), so a tap-based version
    // silently asserts against an unfinished future.
    testWidgets('an unlaunchable URL toasts instead of throwing', (
      tester,
    ) async {
      final toasts = ToastController();
      addTearDown(toasts.dispose);
      late BuildContext ctx;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          // `ChangeNotifierProvider`, not plain `Provider` — the controller is
          // a `ChangeNotifier`, which `Provider` asserts against (see
          // `notify_test.dart`).
          home: ChangeNotifierProvider<ToastController>.value(
            value: toasts,
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  ctx = context;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      await tester.runAsync(() => launchWhiteLabelPurchase(ctx));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(toasts.toasts, hasLength(1));
      expect(toasts.toasts.single.message, "Couldn't open the link");
    });
  });
}
