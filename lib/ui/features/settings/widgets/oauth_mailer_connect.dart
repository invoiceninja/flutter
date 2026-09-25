import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:admin/data/repositories/auth_repository.dart';

/// Connecting a Gmail / Microsoft mailer (send-as) is the server's own browser
/// flow, not an in-app one: `GET <base>/auth/{google|microsoft}` →
/// `LoginController::redirectToProvider` asks for the send scope with offline
/// access, and the callback stores the token on whichever user owns that
/// Google / Microsoft account (`OAuth::handleAuth`) — no web session needed.
/// Shared by Settings → Email Settings (empty picker) and User Details →
/// Connect so the two can't disagree about the URL or the platforms.
///
/// The provider segment is `microsoft`, never `microsoft365`: the server
/// accepts only `google` / `microsoft` / `oidc` and answers anything else with
/// 400 "Invalid provider" (that is what the Email Settings button did).
Uri mailerConnectUri(String baseUrl, {required bool isGoogle}) {
  final base = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  return Uri.parse('$base/auth/${isGoogle ? 'google' : 'microsoft'}');
}

/// Whether this platform may send the user off to the browser to connect.
/// Native iOS / macOS say "use the web app" instead, as admin-portal did.
/// On web `defaultTargetPlatform` is the host OS (Safari on a Mac reads
/// `macOS`), so web is always allowed.
bool canLaunchMailerConnect(String baseUrl) {
  if (baseUrl.isEmpty) return false;
  if (kIsWeb) return true;
  return defaultTargetPlatform != TargetPlatform.iOS &&
      defaultTargetPlatform != TargetPlatform.macOS;
}

/// Opens the connect flow in the browser, then refreshes the session the next
/// time the app comes back to the foreground. The resume-time refresh the app
/// already runs is min-gap gated and can skip, which left the new mailer
/// invisible until some later refresh.
Future<void> launchMailerConnect(
  AuthRepository auth,
  String baseUrl, {
  required bool isGoogle,
}) async {
  final opened = await launchUrl(
    mailerConnectUri(baseUrl, isGoogle: isGoogle),
    mode: LaunchMode.externalApplication,
  );
  if (!opened) return;
  late final AppLifecycleListener listener;
  listener = AppLifecycleListener(
    onResume: () {
      listener.dispose();
      unawaited(auth.refresh().catchError((Object _) {}));
    },
  );
}
