import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'package:admin/data/services/api_client.dart';

/// One image sent with a support message: its bytes and the file name the
/// server attaches it under (docs/feedback-screenshots.md).
class SupportAttachment {
  const SupportAttachment({required this.bytes, required this.fileName});

  final Uint8List bytes;

  /// Required: a multipart part with no filename reaches PHP as a plain
  /// field, not a file, and the server names the attachment from it.
  final String fileName;
}

/// HTTP-only wrapper for the Invoice Ninja support endpoint.
///
/// `POST /api/v1/support/messages/send` with `{ message, send_logs, platform,
/// version }`, plus `attachments[]` images since server 5.13.53
/// (`SendMessageRequest`: `image` files, 10 MB in all; throttled to one per
/// minute per user). Interactive — the caller awaits the response and
/// surfaces the outcome inline — so it calls [ApiClient] directly rather than
/// the outbox (CLAUDE.md § Strict rules lists it among the exceptions).
class SupportApi {
  SupportApi(this._api);

  final ApiClient _api;

  static const _path = '/api/v1/support/messages/send';

  /// Send a support message. [appVersion] is printed verbatim as the email's
  /// `Version:` line — the Contact Us dialog passes
  /// `AppVersion.supportVersionLabel` (`<server>+<clientBuild>`).
  ///
  /// `send_logs` goes as a JSON `false`, as React sends it. It used to go as
  /// `''`, which Laravel's `ConvertEmptyStringsToNull` turns into `null` — and
  /// a server before 5.13.53 attaches its debug info and the tail of
  /// `laravel.log` whenever `send_logs !== false`, so every self-hosted
  /// message carried them (and failed outright where that log file doesn't
  /// exist).
  Future<void> sendMessage({
    required String message,
    required String appVersion,
    bool includeLogs = false,
  }) {
    return _api.postJson(
      _path,
      body: {
        'message': message,
        'send_logs': includeLogs,
        'platform': _platformLetter(),
        'version': appVersion,
      },
    );
  }

  /// [sendMessage] with images, as multipart `attachments[]`.
  ///
  /// No `send_logs` field at all: multipart sends every field as a string,
  /// and `"0"` / `"false"` are both `!== false` to a server before 5.13.53.
  /// [timeout] bounds a stalled upload — the dialog can't be closed while it
  /// sends.
  Future<void> sendMessageWithAttachments({
    required String message,
    required String appVersion,
    required List<SupportAttachment> attachments,
    Duration timeout = const Duration(seconds: 90),
  }) {
    return _api.uploadMultipart(
      path: _path,
      fields: {
        'message': message,
        'platform': _platformLetter(),
        'version': appVersion,
      },
      files: [
        for (final a in attachments)
          http.MultipartFile.fromBytes(
            'attachments[]',
            a.bytes,
            filename: a.fileName,
          ),
      ],
      idempotencyKey: const Uuid().v4(),
      timeout: timeout,
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
