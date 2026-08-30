import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the calendar OAuth authorize URL the right way per platform.
///
/// - **Web**: navigate the current tab to the authorize URL (a full-page
///   redirect, mirroring React); the OAuth round-trip returns to the app at
///   `/calendar_connection/complete`.
/// - **Native**: open the system browser (Google blocks OAuth inside embedded
///   webviews); the return arrives via a custom-scheme deep link bridged by
///   `AppDeepLinks`.
///
/// Throws [StateError] when the platform refuses to launch the URL.
Future<void> openCalendarAuthorize(Uri authorizeUrl) async {
  final ok = kIsWeb
      // `_self` = same-tab navigation, so the OAuth return lands back here.
      ? await launchUrl(authorizeUrl, webOnlyWindowName: '_self')
      : await launchUrl(authorizeUrl, mode: LaunchMode.externalApplication);
  if (!ok) {
    throw StateError('could not open calendar authorize URL');
  }
}
