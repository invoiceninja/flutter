import 'package:flutter/foundation.dart';

import 'package:admin/app/env.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/domain/entity_type.dart';

/// The rules for pointing users at Invoice Ninja's other apps — the WordPress
/// plugin and the "Invoice Ninja: Tasks" Chrome extension
/// (docs/companion-apps.md). The screens only draw what these decide; every
/// store-policy and plan question is answered here, where a unit test pins
/// it. Nothing here opens on its own: each link is a row or a button the user
/// taps.

/// Off switch for every companion-app link: the Integrations card, the API
/// Tokens and Task Settings cards, and the What's New highlights.
const bool kCompanionAppsEnabled = true;

/// The WordPress plugin's directory listing — a free download.
const String kWordPressPluginUrl =
    'https://wordpress.org/plugins/invoiceninja/';

/// The Chrome extension's Web Store listing. **Never reachable on native
/// macOS or iOS** (Apple guideline 2.3.10): only [chromeExtensionPlatform]
/// lets it out.
const String kChromeExtensionUrl =
    'https://chromewebstore.google.com/detail/invoice-ninja-tasks/dlfcbfdpemfnjbjlladogijcchfmmaaf';

/// Where every companion-app link lives for good: Settings → Account
/// Management → Integrations. What's New highlights open it — the dialog
/// never links out.
const String kCompanionAppsRoute = '/settings/account_management/integrations';

enum CompanionApp {
  wordPress,
  chromeExtension;

  String get url => switch (this) {
    CompanionApp.wordPress => kWordPressPluginUrl,
    CompanionApp.chromeExtension => kChromeExtensionUrl,
  };
}

/// Whether this build may name the Chrome extension at all: somewhere a
/// desktop Chrome could install it.
///
/// - **The web** on macOS, Windows or Linux — a desktop browser, so possibly
///   Chrome. Not a phone or tablet browser ([touchPrimary]): Chrome there
///   takes no extensions. On the web `defaultTargetPlatform` is the browser's
///   OS, and Flutter reports an iPad asking for the desktop site as iOS, not
///   macOS (its engine checks `maxTouchPoints`), so `Env.isTouchPrimary` is
///   the right signal.
/// - **Native Windows and Linux.**
/// - **Never native macOS or iOS.** Those are App Store builds, which may not
///   show "names, icons, or imagery of other … app marketplaces" (App Review
///   Guideline 2.3.10) — the Chrome Web Store and Google's brand among them.
///   A Mac *browser* is not the App Store build. Never native Android either:
///   it is a phone.
bool chromeExtensionPlatform({
  required bool isWeb,
  required TargetPlatform platform,
  required bool touchPrimary,
}) {
  if (isWeb) {
    if (touchPrimary) return false;
    return switch (platform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };
  }
  return switch (platform) {
    TargetPlatform.windows || TargetPlatform.linux => true,
    _ => false,
  };
}

/// [chromeExtensionPlatform] for this build.
bool currentChromeExtensionPlatform() => chromeExtensionPlatform(
  isWeb: kIsWeb,
  platform: defaultTargetPlatform,
  touchPrimary: Env.isTouchPrimary,
);

bool _isDemo(AuthSession session, bool isDemoBuild, bool demoMode) =>
    isDemoBuild || demoMode || session.isDemo;

/// Whether this session is offered the WordPress plugin.
///
/// The plugin connects with an admin API token, so it is offered only to an
/// admin or owner of an account that can make one — self-hosted on any plan,
/// hosted on Pro or Enterprise (trial included: the same `hasProAccess` gate
/// as API Tokens). A free hosted account sees nothing: no upsell, no "needs
/// Pro". Shown on every platform, Apple's included: WordPress is neither a
/// mobile platform nor an app marketplace, and the plugin is free.
bool wordPressPluginOffered(
  AuthSession? session, {
  bool isDemoBuild = Env.isDemoBuild,
  bool demoMode = Env.demoMode,
}) {
  if (!kCompanionAppsEnabled || session == null) return false;
  if (_isDemo(session, isDemoBuild, demoMode)) return false;
  final me = session.currentCompany;
  if (me == null || !(me.isAdmin || me.isOwner)) return false;
  return session.isSelfHosted || session.hasProAccess;
}

/// Whether this session is offered the Chrome extension.
///
/// It signs in with the user's own email and password, so there is no plan
/// or role gate — only a platform that can run it ([platformSupported],
/// defaulting to [currentChromeExtensionPlatform]) and a company with the
/// Tasks module on, since tasks are all it makes.
bool chromeExtensionOffered(
  AuthSession? session, {
  bool? platformSupported,
  bool isDemoBuild = Env.isDemoBuild,
  bool demoMode = Env.demoMode,
}) {
  if (!kCompanionAppsEnabled || session == null) return false;
  if (!(platformSupported ?? currentChromeExtensionPlatform())) return false;
  if (_isDemo(session, isDemoBuild, demoMode)) return false;
  return session.currentCompany?.moduleEnabled(EntityType.task) ?? false;
}

/// [wordPressPluginOffered] or [chromeExtensionOffered] for [app].
bool companionAppOffered(CompanionApp app, AuthSession? session) =>
    switch (app) {
      CompanionApp.wordPress => wordPressPluginOffered(session),
      CompanionApp.chromeExtension => chromeExtensionOffered(session),
    };

/// The address the WordPress plugin asks for: the server's base URL without
/// a trailing `/api/v1` or slash (the plugin strips `/api/v1` itself, but
/// a bare address is what its field shows as the example).
String wordPressServerAddress(String baseUrl) {
  var url = baseUrl.trim();
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  if (url.toLowerCase().endsWith('/api/v1')) {
    url = url.substring(0, url.length - '/api/v1'.length);
  }
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  return url;
}
