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
  static const String kClientVersion = '5.1.7';

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
