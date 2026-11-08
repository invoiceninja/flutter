import 'package:uuid/uuid.dart';

import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/auth_service.dart';

/// A passkey registered to the signed-in user, as `GET /settings/passkeys`
/// lists it.
class RegisteredPasskey {
  const RegisteredPasskey({
    required this.id,
    required this.name,
    this.createdAt,
    this.lastUsedAt,
  });

  /// `{id, name, created_at, last_used_at}` — the two dates in different
  /// shapes: `created_at` is an ISO string (a Carbon), `last_used_at` epoch
  /// seconds or null (`?->timestamp`).
  factory RegisteredPasskey.fromJson(Map<String, dynamic> json) {
    final created = json['created_at'];
    final lastUsed = json['last_used_at'];
    return RegisteredPasskey(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      createdAt: created is String ? DateTime.tryParse(created) : null,
      lastUsedAt: switch (lastUsed) {
        final num seconds when seconds > 0 =>
          DateTime.fromMillisecondsSinceEpoch(
            (seconds * 1000).round(),
            isUtc: true,
          ),
        final String text => DateTime.tryParse(text),
        _ => null,
      },
    );
  }

  final String id;
  final String name;
  final DateTime? createdAt;

  /// Null when it has never been used to sign in.
  final DateTime? lastUsedAt;
}

/// `/api/v1/settings/passkeys*` — list, register and remove the signed-in
/// user's passkeys. Direct calls, not the outbox: a registration's challenge
/// expires in five minutes and the OS sheet sits in the middle of it.
class PasskeyApi {
  PasskeyApi(this._api);

  final ApiClient _api;

  Future<List<RegisteredPasskey>> list() async {
    final raw = await _api.getOne('/api/v1/settings/passkeys');
    final data = raw is Map<String, dynamic> ? raw['data'] : null;
    if (data is! List) {
      throw StateError('Unexpected /settings/passkeys response');
    }
    return [
      for (final row in data)
        if (row is Map<String, dynamic>) RegisteredPasskey.fromJson(row),
    ];
  }

  /// The creation options. No `name` is sent: the server would use it as the
  /// WebAuthn `user.displayName`, the account label the password manager
  /// shows — the user's name belongs there, not the device's.
  Future<PasskeyLoginOptions> registrationOptions() async {
    final raw = await _api.postJson(
      '/api/v1/settings/passkeys/options',
      body: const {},
    );
    return _options(raw);
  }

  /// Stores the new credential. [credential] is the `PublicKeyCredential` in
  /// WebAuthn JSON; [name] labels it in this list (the server falls back to
  /// "Passkey" and a timestamp).
  Future<void> store({
    required String challengeToken,
    required Map<String, dynamic> credential,
    String? name,
  }) async {
    final response = credential['response'];
    final fields = response is Map ? response : const <String, dynamic>{};
    // Android's plugin reports `""` when the authenticator names none.
    final transports = [
      if (fields['transports'] case final List<Object?> list)
        for (final t in list)
          if (t is String && t.isNotEmpty) t,
    ];
    await _api.postJson(
      '/api/v1/settings/passkeys',
      body: {
        'challenge_token': challengeToken,
        'credential': {
          'clientDataJSON': fields['clientDataJSON'],
          'attestationObject': fields['attestationObject'],
          if (transports.isNotEmpty) 'transports': transports,
        },
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      },
    );
  }

  /// One shot, so a fresh key (the server ignores it anyway; CLAUDE.md §
  /// Sync — non-obvious rules).
  Future<void> remove(String id) => _api.mutate(
    method: 'DELETE',
    path: '/api/v1/settings/passkeys/${Uri.encodeComponent(id)}',
    idempotencyKey: const Uuid().v4(),
  );

  PasskeyLoginOptions _options(Object? raw) => PasskeyLoginOptions.fromData(
    raw is Map<String, dynamic> ? raw['data'] : null,
  );
}
