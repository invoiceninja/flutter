import 'package:admin/data/services/api_client.dart';

/// Talks to the `/api/v1/company_users/{userId}` endpoint — the same one the
/// old admin-portal hits in `SettingsRepository.saveUserSettings`.
///
/// The body is the full UserEntity JSON (with embedded `company_user` →
/// `settings` → `table_columns`). The new app doesn't model the UserEntity
/// — instead we round-trip the raw JSON we captured at login.
class UserSettingsApi {
  UserSettingsApi(this._client);
  final ApiClient _client;

  /// PUT the user settings. Returns the server's response (the canonical
  /// `UserCompanyEntity` shape).
  Future<Map<String, dynamic>?> update({
    required String userId,
    required Map<String, dynamic> body,
    required String idempotencyKey,
  }) async {
    final raw = await _client.mutate(
      method: 'PUT',
      path: '/api/v1/company_users/$userId',
      idempotencyKey: idempotencyKey,
      body: body,
    );
    if (raw is Map<String, dynamic>) return raw;
    return null;
  }

  /// PUT `react_settings` whole — the server replaces the stored blob — to
  /// `/api/v1/company_users/{userId}/preferences`, the route React saves
  /// through. Unlike [update] it needs no admin rights: the server only checks
  /// that [userId] is the signed-in user.
  Future<void> updatePreferences({
    required String userId,
    required Map<String, dynamic> reactSettings,
    required String idempotencyKey,
  }) async {
    await _client.mutate(
      method: 'PUT',
      path: '/api/v1/company_users/$userId/preferences',
      idempotencyKey: idempotencyKey,
      body: {'react_settings': reactSettings},
    );
  }
}
