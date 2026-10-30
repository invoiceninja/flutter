import 'package:admin/data/models/api/health_check_api_model.dart';
import 'package:admin/data/services/api_client.dart';

/// HTTP service for the self-hosted server diagnostic endpoints surfaced by
/// the Health Check dialog: `/health_check`, `/ping?clear_cache=true`, and
/// `/last_error`. All three are read-only (or read-only-in-effect) and
/// bypass the outbox — the Health Check dialog owns its own loading state.
///
/// Also `/self-update`, which updates the server itself: not a record write,
/// so it has no business in the outbox either, and the Update dialog waits
/// on it.
class SystemApi {
  SystemApi(this._client);

  final ApiClient _client;

  Future<HealthCheckResponse> getHealthCheck() async {
    final raw = await _client.getOne('/api/v1/health_check');
    return HealthCheckResponse.fromJson(raw as Map<String, dynamic>);
  }

  Future<void> clearCache() {
    return _client.getOneWithQuery(
      '/api/v1/ping',
      query: const {'clear_cache': 'true'},
    );
  }

  Future<HealthCheckLastErrorResponse> getLastError() async {
    final raw = await _client.getOne('/api/v1/last_error');
    return HealthCheckLastErrorResponse.fromJson(raw as Map<String, dynamic>);
  }

  /// `POST /api/v1/self-update`: the server downloads the latest release,
  /// unpacks it over itself and migrates. Password-protected — throws
  /// `PasswordRequiredException` with no cached password, so the caller can
  /// prompt and retry. Returns the server's message (`Update completed`).
  ///
  /// The download, unpack and migrations routinely outlast the client's
  /// 60-second request timeout, and giving up early would report a failure
  /// for an update still running on the server.
  Future<String> selfUpdate() async {
    final raw = await _client.postJson(
      '/api/v1/self-update',
      requiresPassword: true,
      timeout: const Duration(minutes: 10),
    );
    if (raw is Map && raw['message'] is String) return raw['message'] as String;
    return '';
  }
}
