import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_exception.dart';

/// The Invoice Ninja server's DocuNinja handshake (`POST /api/docuninja/login`,
/// at the host root, not `/api/v1`). It answers with the user's DocuNinja
/// companies and tokens, or refuses with 400 / 401 when the user has no
/// DocuNinja account — an answer, never a reason to sign out, so the call
/// opts out of `ApiClient`'s 401 handling (docs/docuninja.md).
class DocuNinjaLoginApi {
  const DocuNinjaLoginApi(this._api);

  final ApiClient _api;

  /// The handshake. Throws [DocuNinjaRefused] on a 400 / 401; network and
  /// other failures propagate as `ApiClient` exceptions.
  Future<DnLogin> login() async {
    try {
      final json = await _api.postJson(
        '/api/docuninja/login',
        body: const {},
        readOnly: true,
        unauthorizedIsAnswer: true,
      );
      if (json is! Map) throw const DocuNinjaRefused();
      return DnLogin.fromJson(Map<String, dynamic>.from(json));
    } on ServerException catch (e) {
      if (e.statusCode == 400 || e.statusCode == 401) {
        throw const DocuNinjaRefused();
      }
      rethrow;
    }
  }

  /// Creates the DocuNinja account, or pairs this company with an existing
  /// one (`POST /api/docuninja/create`): React's Join and company-setup
  /// buttons, for an Invoice Ninja owner or admin. The server then turns on
  /// the company's `enable_modules`, so the caller refreshes the session.
  ///
  /// Like the handshake, a 401 here is DocuNinja's answer and never ends the
  /// Invoice Ninja session (React's `skipIntercept`).
  Future<void> createAccount() async {
    await _api.postJson(
      '/api/docuninja/create',
      body: const {},
      unauthorizedIsAnswer: true,
    );
  }
}

/// The handshake's "no DocuNinja account for you" answer.
class DocuNinjaRefused implements Exception {
  const DocuNinjaRefused();
}
