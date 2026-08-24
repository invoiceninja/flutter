import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/utils/url_safety.dart';

/// Hands [uri] to the platform browser. Returns false only when the launch
/// genuinely failed.
///
/// **Never gate this on `canLaunchUrl`.** That call answers "can I *see* an
/// app that handles this?", which on Android 11+ is a package-visibility
/// question — and the plugin's own docs say it "will always return false
/// unless the application has been configured to allow querying". Starting an
/// implicit intent is *not* restricted the same way: `UrlLauncher.launchUrl`
/// on Android goes straight to `startActivity` and reports false only on
/// `ActivityNotFoundException`. So the gate was strictly less accurate than
/// the thing it guarded, and it was the gate that failed — Payment Links'
/// View button said "Couldn't open the link" while Copy handed over a URL
/// that pasted into a browser fine (invoiceninja/flutter#80; the manifest
/// half of the same defect was flutter#12). Every external link in the app
/// had the same latent bug, so they all route through here now, and
/// `test/lint/no_can_launch_url_test.dart` keeps the gate from coming back.
///
/// Falls back to [LaunchMode.platformDefault] when the external-application
/// mode reports failure, so a device with no standalone browser can still
/// open the page in a custom tab / web view.
Future<bool> launchExternalUri(Uri uri) async {
  for (final mode in const [
    LaunchMode.externalApplication,
    LaunchMode.platformDefault,
  ]) {
    try {
      if (await launchUrl(uri, mode: mode)) return true;
    } catch (_) {
      // Try the next mode; failure is only reported once both are spent.
    }
  }
  return false;
}

/// [launchExternalUri] for a URL string, with the standard "Couldn't open the
/// link" toast when it doesn't open. Returns whether the launch succeeded.
///
/// The URL is validated with [isSafeWebUrl] first: these come from the server
/// (a purchase page, a portal link) or from user input (a client's website),
/// and only http(s) should ever reach the launcher. A rejected URL takes the
/// same failure path as a failed launch — from the user's side it did not
/// open, and there is nothing actionable to say beyond that.
Future<bool> openExternalUrl(BuildContext context, String url) async {
  // Both resolved before the first await — `context` may be gone by the time
  // the launcher answers. `Notify.capture` is the sanctioned replacement for
  // the old "capture a ScaffoldMessenger" dance; the toast host is global and
  // outlives any context. The captured path has no blank-message fallback, so
  // the message has to be `tr()`-derived — it is.
  final toasts = Notify.capture(context);
  final errorMessage =
      Localization.of(context)?.lookup('failed_to_open_url') ??
      'failed_to_open_url';

  final uri = isSafeWebUrl(url) ? Uri.tryParse(url) : null;
  if (uri != null && await launchExternalUri(uri)) return true;

  toasts?.error(errorMessage);
  return false;
}
