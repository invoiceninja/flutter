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
}

/// The handshake's "no DocuNinja account for you" answer.
class DocuNinjaRefused implements Exception {
  const DocuNinjaRefused();
}
