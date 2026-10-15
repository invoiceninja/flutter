import 'package:flutter/foundation.dart';

import 'package:admin/data/services/api_client.dart';

/// HTTP-only wrapper for the Invoice Ninja support endpoint.
///
/// Mirrors `admin-portal/lib/ui/app/menu_drawer.dart:1658-1770` —
/// `POST /api/v1/support/messages/send` with `{ message, send_logs, platform,
/// version }`. Interactive (caller awaits the response and surfaces the
/// outcome inline) so the call goes through [ApiClient.postJson] directly,
/// not the outbox pipeline.
class SupportApi {
  SupportApi(this._api);

  final ApiClient _api;

  /// Send a support message. [appVersion] is printed verbatim as the email's
  /// `Version:` line — the Contact Us dialog passes
  /// `AppVersion.supportVersionLabel` (`<server>+<clientBuild>`).
  ///
  /// [includeLogs] is wired now so the wire shape doesn't drift, but the UI
  /// always passes `false` until log collection lands in a later milestone.
  Future<void> sendMessage({
    required String message,
    required String appVersion,
    bool includeLogs = false,
  }) {
    return _api.postJson(
      '/api/v1/support/messages/send',
      body: {
        'message': message,
        'send_logs': includeLogs ? 'true' : '',
        'platform': _platformLetter(),
        'version': appVersion,
      },
    );
  }

  /// One-letter platform identifier the server expects. Mirrors
  /// `admin-portal/lib/utils/platforms.dart:183-200`.
  static String _platformLetter() {
    if (kIsWeb) return 'C';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'I';
      case TargetPlatform.android:
        return 'A';
      case TargetPlatform.macOS:
        return 'M';
      case TargetPlatform.windows:
        return 'W';
      case TargetPlatform.linux:
        return 'L';
      case TargetPlatform.fuchsia:
        return 'F';
    }
  }
}
