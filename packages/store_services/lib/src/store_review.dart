import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';

/// The operating system's own "rate this app" sheet — StoreKit's
/// `requestReview` on iOS and macOS, Play's In-App Review on Android
/// (docs/review-prompt.md).
///
/// Never call it from a button: both stores ration the sheet with a quota,
/// Google Play's policy forbids a call-to-action that triggers it, and
/// neither OS reports whether a sheet appeared. A permanent "Rate the app"
/// entry opens the store listing instead.
class StoreReview {
  StoreReview._();

  /// Whether this is a store build (true) or the F-Droid one (false). The
  /// review channel is chosen from this, not from [prepare]: a Play build on
  /// a phone without Play Services is still a Play build, and must never
  /// fall back to a custom prompt.
  static const bool isStoreBuild = true;

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// Whether the native sheet can be requested here. On Android this also
  /// fetches and caches the review flow, so call it a moment before
  /// [requestReview] and the sheet opens without a round trip. False off
  /// iOS, macOS and Android, where the plugin has no native side.
  static Future<bool> prepare() async {
    if (!_supported) return false;
    try {
      return await InAppReview.instance.isAvailable();
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Asks the OS to show its review sheet. True means the OS was asked —
  /// not that it showed anything: Apple shows it at most three times a year
  /// and Google rations it silently. False when it could not be asked at all
  /// (no Play Services, no main window on macOS, an unsupported platform).
  static Future<bool> requestReview() async {
    if (!await prepare()) return false;
    try {
      await InAppReview.instance.requestReview();
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
