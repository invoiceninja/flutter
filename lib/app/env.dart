import 'package:flutter/foundation.dart';

/// Build-time + runtime configuration.
///
/// Values that vary by build flavor (hosted vs self-hosted, demo mode) are
/// passed via `--dart-define` and read here. Defaults are safe for local
/// development.
class Env {
  Env._();

  /// Hosted Invoice Ninja API base URL — used when the user picks "Hosted" on
  /// the login screen.
  static const String hostedApiUrl = String.fromEnvironment(
    'IN_HOSTED_API_URL',
    defaultValue: 'https://invoicing.co',
  );

  /// X-API-SECRET injected on hosted builds. Empty on self-hosted.
  static const String hostedApiSecret = String.fromEnvironment(
    'IN_HOSTED_API_SECRET',
  );

  /// Demo mode short-circuits all non-GET requests with a friendly toast.
  /// See `web_client.dart:31,266` in admin-portal for the precedent.
  static const bool demoMode = bool.fromEnvironment('IN_DEMO_MODE');

  /// Kill-switch for the Spanish VERI*FACTU e-invoicing standard. **On by
  /// default** — VERIFACTU shows for hosted Spanish companies with no build
  /// flag. Pass `--dart-define=IN_ENABLE_VERIFACTU=false` to hide the option
  /// (e.g. if the standard has to be pulled). Combined with a hosted + Spain
  /// check at the call site (`e_invoice_body.dart`); diverges from React's
  /// opt-in `VITE_ENABLE_VERIFACTU_STANDARD` by defaulting on.
  static const bool enableVerifactu = bool.fromEnvironment(
    'IN_ENABLE_VERIFACTU',
    defaultValue: true,
  );

  /// Dev-only login pre-fill. Consumed by `LoginViewModel` under `!kReleaseMode`
  /// (debug + profile builds), so release builds never ship pre-filled
  /// credentials — the guard is dead-code-eliminated and these constants are
  /// stripped from the release binary even if passed at build time (verified by
  /// build-and-grep). Typical usage: `flutter run --dart-define-from-file=dev.json`
  /// with a gitignored `dev.json` (see `dev.json.example`).
  static const String devEmail = String.fromEnvironment('IN_DEV_EMAIL');
  static const String devPassword = String.fromEnvironment('IN_DEV_PASSWORD');

  /// Demo build: a pre-issued API token baked in via
  /// `--dart-define=IN_DEMO_API_TOKEN=…`. When non-empty, `main.dart`
  /// bootstraps a session from it on boot (`AuthRepository.loginWithToken`)
  /// so the build lands on the dashboard instead of `/login`. Empty in every
  /// normal build → the bootstrap branch is never taken. Unlike the dev
  /// pre-fill above this is *not* `kReleaseMode`-gated — the deployed demo is
  /// a release build.
  static const String demoApiToken = String.fromEnvironment(
    'IN_DEMO_API_TOKEN',
  );
  static const String demoApiUrl = String.fromEnvironment(
    'IN_DEMO_API_URL',
    defaultValue: 'https://demo.invoiceninja.com',
  );

  /// Google OAuth Web/server client ID. Required on Android: the v7
  /// `google_sign_in` plugin routes through Credential Manager, which needs
  /// the Web OAuth client ID passed to `initialize(serverClientId:)` — it does
  /// not auto-resolve it from `google-services.json`. iOS resolves its own
  /// client ID from `Info.plist` / `GoogleService-Info.plist` and must NOT
  /// receive `serverClientId`. Empty = Google sign-in unconfigured for this
  /// build; deployments inject the real ID via
  /// `--dart-define=IN_GOOGLE_SERVER_CLIENT_ID=…` (per-app OAuth project — do
  /// not reuse another app's client ID, the bundle/package binding won't match).
  static const String googleServerClientId = String.fromEnvironment(
    'IN_GOOGLE_SERVER_CLIENT_ID',
  );

  /// Sentry DSN for remote error reporting. Empty (the default) disables
  /// Sentry entirely — deployments opt in via
  /// `--dart-define=IN_SENTRY_DSN=…` with their own Sentry project (do not
  /// hardcode another app's DSN). Also gated to release builds and the
  /// per-account `report_errors` opt-in (see `main.dart` / `sentry_gate`).
  static const String sentryDsn = String.fromEnvironment('IN_SENTRY_DSN');

  /// `X-CLIENT-PLATFORM` header value. Expands as we add platforms.
  ///
  /// Uses `defaultTargetPlatform` (web-safe — `dart:io`'s `Platform` can't be
  /// imported in a web build at all, not just called) and checks `kIsWeb`
  /// first so a browser reports `web`, not the underlying host OS.
  static String get clientPlatform {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'unknown';
    }
  }

  /// Single-letter platform code for the combined version label in the About
  /// dialog (mirrors admin-portal's `getPlatformLetter()`): web→`C`, iOS→`I`,
  /// android→`A`, windows→`W`, linux→`L`, macos→`M`, fuchsia→`F`. Web-safe like
  /// [clientPlatform] (`kIsWeb` first, then `defaultTargetPlatform`).
  static String get platformLetter {
    if (kIsWeb) return 'C';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'I';
      case TargetPlatform.android:
        return 'A';
      case TargetPlatform.windows:
        return 'W';
      case TargetPlatform.linux:
        return 'L';
      case TargetPlatform.macOS:
        return 'M';
      case TargetPlatform.fuchsia:
        return 'F';
    }
  }

  /// True on the three desktop platforms; never web or mobile. Single source of
  /// truth for "is this desktop" — mirrors the `fileDropSupported` check in
  /// `file_drop_zone.dart`. Web-safe (`kIsWeb` first, then `defaultTargetPlatform`).
  static bool get isDesktop {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return true;
      case TargetPlatform.iOS:
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  /// True only on the touch mobile platforms (iOS/Android); never web or
  /// desktop. Single source of truth for "is this mobile" — note web is
  /// *excluded* (a browser has a physical keyboard), so this is not the
  /// inverse of [isDesktop]. Web-safe (`kIsWeb` first, then `defaultTargetPlatform`).
  static bool get isMobile {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.android:
        return true;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  /// True when the primary pointer is a finger — iOS / Android, **including a
  /// mobile browser**. Unlike [isMobile] there is deliberately no `kIsWeb`
  /// guard: on web `defaultTargetPlatform` is derived from the browser's
  /// operating system, so Chrome on a Pixel reports `android` while a desktop
  /// browser reports `macOS` / `linux` / `windows` — exactly the split touch
  /// sizing wants.
  ///
  /// Drives touch-target sizing only (see `InSizes.touchTarget`). For "is this
  /// a native mobile build" — platform channels, haptics, biometrics — use
  /// [isMobile] instead.
  static bool get isTouchPrimary {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.android:
        return true;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return false;
    }
  }
}
