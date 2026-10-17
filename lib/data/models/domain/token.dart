import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/token_api_model.dart';
import 'package:admin/data/models/value/parsing.dart';

part 'token.freezed.dart';

/// Length of the suffix the server appends when masking a token. Confirmed
/// in admin-portal v1 (`lib/data/models/token_model.dart:96`).
const String _kMaskSuffix = 'xxxxxxxxxxx';
const int _kRawSecretPrefixLength = 10;

/// The server's masked form of [raw] — the first 10 chars plus
/// [_kMaskSuffix], exactly what `CompanyTokenHashedTransformer` returns — so
/// a secret that arrived raw can be stored the way every later payload
/// stores it. A value too short to have a prefix keeps none of it (the
/// server mints 64-char secrets, so that is only ever synthetic data).
String maskTokenSecret(String raw) => raw.length >= _kRawSecretPrefixLength
    ? '${raw.substring(0, _kRawSecretPrefixLength)}$_kMaskSuffix'
    : _kMaskSuffix;

/// Domain `Token` (wire entity: `token` / `company_token`). Settings-area
/// entity reached via Settings → Integrations → API Tokens. Bundled on
/// `/refresh?first_load=true` via `tokens_hashed`.
///
/// The server returns the **raw bearer secret** in [token] only on the
/// create response and `GET /tokens/{id}`; every other payload returns a
/// masked form, and that masked form is all Drift ever holds. We never
/// round-trip the masked value back to the server (see [toApiJson]).
@freezed
abstract class Token with _$Token {
  const Token._();

  const factory Token({
    required String id,
    required String userId,
    required String token,
    required String name,
    required bool isSystem,
    required bool isDeleted,
    required DateTime updatedAt,
    required DateTime createdAt,
    required DateTime? archivedAt,
    @Default(false) bool isDirty,
  }) = _Token;

  factory Token.fromApi(TokenApi a) => Token(
    id: a.id,
    userId: a.userId,
    token: a.token,
    name: a.name,
    isSystem: a.isSystem,
    isDeleted: a.isDeleted,
    updatedAt: epochSecondsToUtc(a.updatedAt),
    createdAt: epochSecondsToUtc(a.createdAt),
    archivedAt: epochSecondsToUtcOrNull(a.archivedAt),
  );

  /// `true` when [token] is the server's `<prefix>xxxxxxxxxxx` masked form
  /// — i.e. anything except the one-shot value returned on create.
  bool get isMasked =>
      token.length >= _kRawSecretPrefixLength + _kMaskSuffix.length &&
      token.endsWith(_kMaskSuffix);

  /// User-facing hint for the list page: `<first 10 chars>…`. Falls back to
  /// the bare token for short values (shouldn't happen with real server
  /// data, but defends against synthetic test rows).
  String get tokenHint => token.length >= _kRawSecretPrefixLength
      ? '${token.substring(0, _kRawSecretPrefixLength)}…'
      : token;

  /// The edit screen's stand-in for the hidden secret: the prefix, then a
  /// run of dots. Not [tokenHint] — a trailing `…` reads as text cut off for
  /// width, where this has to read as "hidden, ask to show it".
  String get obscuredHint {
    final prefix = token.length >= _kRawSecretPrefixLength
        ? token.substring(0, _kRawSecretPrefixLength)
        : '';
    return '$prefix${'•' * 12}';
  }

  /// Send-shape used by the outbox.
  ///
  /// **Never echoes the masked `token` back to the server.** The server
  /// mints the secret on create (we don't supply one) and ignores any
  /// `token` field on update (the masked string would be garbage to it).
  /// The joined `user_id` is read-only — owning user comes from the
  /// session, not the payload.
  Map<String, dynamic> toApiJson({bool preserveTempId = false}) {
    final json = TokenApi(
      id: id,
      name: name,
      isSystem: isSystem,
      isDeleted: isDeleted,
      updatedAt: updatedAt.millisecondsSinceEpoch ~/ 1000,
      createdAt: createdAt.millisecondsSinceEpoch ~/ 1000,
      archivedAt: archivedAt == null
          ? 0
          : archivedAt!.millisecondsSinceEpoch ~/ 1000,
    ).toJson();
    if (!preserveTempId && id.startsWith('tmp_')) {
      json.remove('id');
    }
    // `token` and `user_id` are read-only on this surface — strip them
    // from every outgoing payload.
    json.remove('token');
    json.remove('user_id');
    return json;
  }
}
