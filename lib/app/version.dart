/// Client-side version identifiers used in API request headers and the
/// version-negotiation handshake with the server.
///
/// Bump [kClientVersion] on every release. Bump [kMinServerVersion] only when
/// we start depending on a server API change.
///
/// We share Invoice Ninja's version envelope: see
/// `admin-portal/lib/constants.dart:9`. This rebuild speaks `/api/v1` the
/// same way admin-portal does, so claiming the same version keeps us inside
/// the server's `x-minimum-client-version` floor without forcing the server
/// team to special-case us.
class AppVersion {
  AppVersion._();

  /// Sent as `X-CLIENT-VERSION` on every request.
  static const String kClientVersion = '5.1.15';

  /// The minimum Invoice Ninja server version this client can talk to.
  ///
  /// The server returns `x-app-version` on every response; if it's below this
  /// we surface a "server needs upgrade" screen.
  static const String kMinServerVersion = '5.0.0';

  /// Combined version label shown in the About dialog, mirroring admin-portal's
  /// `AppState.appVersion`: `v<serverVersion>-<platformLetter><clientBuild>`
  /// (e.g. `v5.11.40-M0`). `clientBuild` is the last dotted segment of
  /// [kClientVersion]; pass [platformLetter] from `Env.platformLetter`.
  ///
  /// [serverVersion] is the server's `x-app-version` value
  /// (`Services.serverVersion`); when it's null/empty the label is `v-<…>`,
  /// matching the old app before the first response arrives.
  static String versionLabel({
    required String? serverVersion,
    required String platformLetter,
  }) {
    final server = (serverVersion ?? '').trim();
    final clientBuild = kClientVersion.split('.').last;
    return 'v$server-$platformLetter$clientBuild';
  }
}

/// Compare two semver-ish strings (`a.b.c[-pre]`). Returns -1, 0, 1. A missing
/// or non-numeric segment counts as 0.
int compareSemver(String a, String b) {
  final aParts = a.split('-').first.split('.').map(int.tryParse).toList();
  final bParts = b.split('-').first.split('.').map(int.tryParse).toList();
  for (var i = 0; i < 3; i++) {
    final av = (i < aParts.length ? aParts[i] : null) ?? 0;
    final bv = (i < bParts.length ? bParts[i] : null) ?? 0;
    if (av != bv) return av.compareTo(bv);
  }
  return 0;
}

/// Server releases that introduced an API this client only uses when the
/// server has it — an older self-hosted install would otherwise 422 the
/// request into a dead outbox row, or silently ignore a filter and return the
/// wrong rows.
///
/// Each constant is the first **release** (`x-app-version`) carrying the
/// change, so a server built from an unreleased branch that still reports the
/// previous version keeps the feature hidden until its next release — the safe
/// direction.
///
/// **Hosted is exempt.** It runs current code (the React client ships these
/// features to it ungated), but its `x-app-version` comes from an
/// `APP_VERSION` env setting that lags: `invoicing.co` reported 5.13.32 on
/// 2026-10-01, older than any release carrying these. Gating hosted on it hid
/// quote Cancel from every hosted user.
class ServerFeatures {
  ServerFeatures._();

  /// Quote `cancel` bulk action + `Quote::STATUS_CANCELLED` (React #3393).
  /// Absent from v5-stable 5.13.43's `BulkActionQuoteRequest`.
  static const String quoteCancel = '5.13.44';

  /// `GET /tasks?activity_dates=start,end` — tasks with a time entry in the
  /// range, not just those that *start* in it (React #3378).
  static const String taskActivityDates = '5.13.43';

  /// Whether the server has the feature that shipped in [since]: always on
  /// hosted ([isHosted] — see the class doc), else whether [serverVersion]
  /// (`Services.serverVersion`, the server's `x-app-version`) is at least
  /// [since]. Unknown (null / blank — no response seen yet) is **false** on
  /// self-hosted: hiding an action until the first response is cheaper than
  /// queueing one the server rejects.
  static bool supports(
    String? serverVersion,
    String since, {
    bool isHosted = false,
  }) {
    if (isHosted) return true;
    final v = (serverVersion ?? '').trim();
    if (v.isEmpty) return false;
    return compareSemver(v, since) >= 0;
  }
}
