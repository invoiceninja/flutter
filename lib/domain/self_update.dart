import 'package:admin/app/env.dart';
import 'package:admin/app/version.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';

/// What the app offers a self-hosted admin about updating their server —
/// admin-portal's sidebar warning icon and About-screen button
/// (`menu_drawer.dart`, `update_dialog.dart`), and React's `UpdateAppModal`.
enum SelfUpdateOffer {
  /// Hosted, demo, not an admin, or the server set `DISABLE_AUTO_UPDATE`.
  none,

  /// `latest_version` is newer than `current_version`.
  update,

  /// Already on the latest release, but `POST /self-update` re-downloads it —
  /// how a self-hosted admin picks up a fix shipped under the same version.
  /// Never offered on Docker, where there is nothing to re-download.
  forceUpdate,
}

/// The offer for [session]. Gated like admin-portal: self-hosted, admin or
/// owner (the server's `SelfUpdateRequest` refuses anyone else), and not
/// `disable_auto_update`. Demo sessions are excluded — the demo build logs in
/// as self-hosted and has no server of its own to update.
SelfUpdateOffer selfUpdateOffer(AuthSession? session) {
  if (session == null || session.isHosted) return SelfUpdateOffer.none;
  if (Env.demoMode || session.isDemo) return SelfUpdateOffer.none;
  if (session.disableAutoUpdate) return SelfUpdateOffer.none;
  final me = session.currentCompany;
  // Fail closed on a not-yet-loaded company, like the white-label nag.
  if (me == null || !(me.isAdmin || me.isOwner)) return SelfUpdateOffer.none;
  if (isNewerRelease(
    installed: session.serverCurrentVersion,
    latest: session.serverLatestVersion,
  )) {
    return SelfUpdateOffer.update;
  }
  return session.isDocker ? SelfUpdateOffer.none : SelfUpdateOffer.forceUpdate;
}

/// Whether [latest] is a newer release than [installed]. Either blank (the
/// server has not run its version check yet) is false, so a fresh install
/// is not told to update.
bool isNewerRelease({required String installed, required String latest}) {
  final a = bareVersion(installed);
  final b = bareVersion(latest);
  if (a.isEmpty || b.isEmpty) return false;
  return compareSemver(a, b) < 0;
}

/// [version] without whitespace or a leading `v` — the server sends a bare
/// `5.13.45`, but a `v` would read as segment 0 in [compareSemver] and as
/// `vv5.13.45` on screen.
String bareVersion(String version) {
  final v = version.trim();
  return v.startsWith('v') || v.startsWith('V') ? v.substring(1) : v;
}

/// The commands a Docker install updates with, shown in place of Update Now
/// (admin-portal's `UpdateDialog`).
const String kDockerUpdateCommand =
    'docker-compose down\ndocker-compose pull\ndocker-compose up';

/// Where Release Notes leads when an update is available.
const String kServerReleaseNotesUrl =
    'https://github.com/invoiceninja/invoiceninja/releases';

/// What changed on `v5-stable` since [installed] — View Changes, for a
/// Force Update.
String serverChangesUrl(String installed) =>
    'https://github.com/invoiceninja/invoiceninja/compare/v${bareVersion(installed)}...v5-stable';
