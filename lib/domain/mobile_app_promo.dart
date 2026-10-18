import 'package:flutter/foundation.dart';

import 'package:admin/app/env.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/utils/local_network_host.dart';

/// The "get the mobile app" promo's pure rules — which phones to offer, how,
/// and to whom (docs/mobile-app-promo.md). The controller owns the schedule
/// and the dialog draws it; everything a store reviewer could object to is
/// decided here, where a unit test pins it.

/// Off switch for the whole promo: the auto-open, the sidebar card, and the
/// About and Device Settings entries.
const bool kMobilePromoEnabled = true;

/// The iPhone/iPad beta — TestFlight's public join link. Swap for the App
/// Store listing once the iOS app is public — see
/// docs/mobile-app-promo.md § Swap the links at launch.
const String kMobileAppIosUrl = 'https://testflight.apple.com/join/YY1BZ7uR';

/// The Android beta — Google Play's open-testing opt-in page. **Never
/// reachable on native macOS** (Apple guideline 2.3.10): only
/// [mobilePromoTargets] hands it out.
const String kMobileAppAndroidUrl =
    'https://play.google.com/apps/testing/com.invoiceninja.admin';

enum MobilePromoTarget {
  ios,
  android;

  String get url => switch (this) {
    MobilePromoTarget.ios => kMobileAppIosUrl,
    MobilePromoTarget.android => kMobileAppAndroidUrl,
  };
}

/// How the dialog hands the app over: a QR code to scan from another screen,
/// or — on a phone's own browser, which can't scan itself — a store button.
enum MobilePromoPresentation { qr, storeButton }

/// The phones this surface may offer, in display order.
///
/// Native macOS is **iPhone/iPad only**. The Mac App Store build may not show
/// "names, icons, or imagery of other mobile platforms or alternative app
/// marketplaces" (App Review Guideline 2.3.10), and reviewers reject a bare
/// "Google Play" mention. The web is not an App Store app, so a Mac *browser*
/// offers both. Native iOS and Android are already on the phone app: nothing.
List<MobilePromoTarget> mobilePromoTargets({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  const both = [MobilePromoTarget.ios, MobilePromoTarget.android];
  if (isWeb) {
    return switch (platform) {
      TargetPlatform.iOS => const [MobilePromoTarget.ios],
      TargetPlatform.android => const [MobilePromoTarget.android],
      _ => both,
    };
  }
  return switch (platform) {
    TargetPlatform.macOS => const [MobilePromoTarget.ios],
    TargetPlatform.windows || TargetPlatform.linux => both,
    _ => const [],
  };
}

/// The live surface's targets — [mobilePromoTargets] for this build.
List<MobilePromoTarget> currentMobilePromoTargets() =>
    mobilePromoTargets(isWeb: kIsWeb, platform: defaultTargetPlatform);

MobilePromoPresentation mobilePromoPresentation({
  required bool isWeb,
  required bool touch,
}) => isWeb && touch
    ? MobilePromoPresentation.storeButton
    : MobilePromoPresentation.qr;

/// The live surface's presentation — [mobilePromoPresentation] for this build.
MobilePromoPresentation currentMobilePromoPresentation() =>
    mobilePromoPresentation(isWeb: kIsWeb, touch: Env.isTouchPrimary);

/// Whether this session may be offered the phone app at all: a live,
/// non-demo session whose server a phone could reach. A `localhost` server
/// is only reachable from this machine, so pointing a phone at it is a dead
/// end.
bool mobilePromoEligible(
  AuthSession? session, {
  bool isDemoBuild = Env.isDemoBuild,
  bool demoMode = Env.demoMode,
}) {
  if (!kMobilePromoEnabled || session == null) return false;
  if (isDemoBuild || demoMode || session.isDemo) return false;
  return !isLoopbackHost(session.baseUrl);
}

/// A server only this machine can reach — `localhost`, `127.*`, `0.0.0.0`,
/// `::1`.
bool isLoopbackHost(String url) {
  final host = _host(url);
  if (host == null) return false;
  if (host == 'localhost' || host.endsWith('.localhost')) return true;
  if (host.contains(':')) {
    try {
      final bytes = Uri.parseIPv6Address(host);
      return bytes[15] == 1 && bytes.take(15).every((b) => b == 0);
    } on FormatException {
      return false;
    }
  }
  return host == '0.0.0.0' ||
      (host.startsWith('127.') && isLocalNetworkHost(host));
}

/// A server a phone reaches only from the same network: a private, link-local
/// or CGNAT address, or a `.local` / `.lan` / `.home.arpa` / `.internal` name
/// — `isLocalNetworkHost`, the self-hosted login's classifier, minus the
/// loopback addresses no phone can reach at all.
bool isPrivateNetworkHost(String url) {
  final host = _host(url);
  if (host == null) return false;
  return isLocalNetworkHost(host) && !isLoopbackHost(url);
}

String? _host(String url) {
  final uri = Uri.tryParse(url.trim());
  final host = uri?.host.toLowerCase();
  return host == null || host.isEmpty ? null : host;
}

/// The OAuth provider a user signs in with here, when the phone app can't
/// sign them in the same way — so the dialog can say they'll need a
/// password. Null when they have a password, use none, or the phone offers
/// the same button.
///
/// The phone app offers Google on both phones and Apple on iPhone only,
/// and neither on a self-hosted server (`login_screen.dart`). There is no
/// Microsoft sign-in in this app at all.
String? mobileSignInProviderGap(
  AuthSession? session,
  MobilePromoTarget target,
) {
  if (session == null || session.userHasPassword) return null;
  final provider = session.userOauthProviderId;
  if (provider.isEmpty) return null;
  if (session.isSelfHosted) return provider;
  return switch (provider) {
    'google' => null,
    'apple' => target == MobilePromoTarget.ios ? null : provider,
    _ => provider,
  };
}

/// The provider's own name, for "You sign in here with Google". Brand names
/// read the same in every locale.
String oauthProviderDisplayName(String id) => switch (id) {
  'google' => 'Google',
  'microsoft' => 'Microsoft',
  'apple' => 'Apple',
  _ => id,
};

/// What the dialog's "Sign in on your phone" step says about this account —
/// read off the session once, so the dialog needs no `Services`.
@immutable
class MobilePromoAccount {
  const MobilePromoAccount({
    this.email = '',
    this.serverUrl,
    this.privateNetwork = false,
    this.expensesEnabled = true,
    this.providerGaps = const {},
  });

  factory MobilePromoAccount.fromSession(AuthSession? session) {
    if (session == null) return const MobilePromoAccount();
    final me = session.currentCompany;
    return MobilePromoAccount(
      email: session.userEmail,
      // Hosted users pick "Hosted" on the phone; only a self-hosted server
      // has an address to type.
      serverUrl: session.isSelfHosted ? session.baseUrl : null,
      privateNetwork: isPrivateNetworkHost(session.baseUrl),
      expensesEnabled: me?.moduleEnabled(EntityType.expense) ?? true,
      providerGaps: {
        for (final target in MobilePromoTarget.values)
          if (mobileSignInProviderGap(session, target) case final gap?)
            target: gap,
      },
    );
  }

  final String email;

  /// The server address to type on the phone — null when hosted.
  final String? serverUrl;

  /// The server is on a private network, so the phone must be too.
  final bool privateNetwork;

  /// Whether the receipts pitch applies — it is about expenses.
  final bool expensesEnabled;

  /// Per phone, the OAuth provider the phone app can't sign this user in
  /// with ([mobileSignInProviderGap]).
  final Map<MobilePromoTarget, String> providerGaps;
}
