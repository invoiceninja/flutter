import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/data/services/docuninja/docuninja_client.dart';

/// DocuNinja's document endpoints (`api.docuninja.co/api/documents…`), as
/// React calls them (`src/common/queries/docuninja/documents.ts` and the
/// detail page's actions). Everything is online-only (docs/docuninja.md).
class DocuNinjaApi {
  const DocuNinjaApi(this._client);

  final DocuNinjaClient _client;

  /// A page of documents, newest first. [status] is React's comma list of
  /// lifecycle states and document statuses (`active`, `archived`,
  /// `deleted`, `draft`, `sent`, …): the service matches a document whose
  /// state *and* status are listed, so a list always names a state. [search]
  /// goes out as `search` (probed live: DocuNinja ignores `filter`, React's
  /// tables set `filterParameterKey="search"`).
  Future<DnPage<DnDocument>> documents({
    int page = 1,
    int perPage = 20,
    String search = '',
    String status = '',
    String sort = 'id|desc',
  }) async {
    final json = await _client.getJson(
      '/api/documents',
      query: {
        'page': '$page',
        'per_page': '$perPage',
        'sort': sort,
        if (search.isNotEmpty) 'search': search,
        if (status.isNotEmpty) 'status': status,
      },
    );
    return DnPage.fromJson(_asMap(json), DnDocument.fromJson);
  }

  /// One document with its files' URLs and page previews.
  Future<DnDocument> document(String id) async {
    final json = await _client.getJson(
      '/api/documents/$id',
      query: const {
        'includeUrl': 'true',
        'includePreviews': 'true',
        'includeUser': 'true',
      },
    );
    return DnDocument.fromJson(_data(json));
  }

  Future<List<DnTimelineEntry>> timeline(String id) async {
    final json = await _client.postJson('/api/documents/$id/timeline');
    final rows = json is List ? json : (json is Map ? json['data'] : null);
    if (rows is! List) return const [];
    return [
      for (final r in rows)
        if (r is Map) DnTimelineEntry.fromJson(Map<String, dynamic>.from(r)),
    ];
  }

  /// The settings modal (`DocumentSettingsModal.tsx`). `expires_at` is sent
  /// only when [setExpiry]: `YYYY-MM-DD`, as React's date input sends it, or
  /// null to clear it.
  Future<DnDocument> updateDocument(
    String id, {
    required String description,
    bool setExpiry = false,
    String? expiresAt,
  }) async {
    final json = await _client.putJson(
      '/api/documents/$id',
      body: {
        'description': description,
        if (setExpiry) 'expires_at': expiresAt,
      },
    );
    return DnDocument.fromJson(_data(json));
  }

  Future<void> deleteDocument(String id) =>
      _client.deleteJson('/api/documents/$id');

  /// `archive` or `restore` on several documents.
  Future<void> bulk(String action, List<String> ids) => _client.postJson(
    '/api/documents/bulk',
    body: {'action': action, 'ids': ids},
  );

  /// `void`, `clone` or `make_blueprint`.
  Future<Object?> action(String id, String action) => _client.postJson(
    '/api/documents/$id/action',
    body: {'action': action, 'id': id},
  );

  /// Emails the invitations: all of them, or one to resend.
  Future<void> send(String id, List<DnInvitation> invitations) =>
      _client.postJson(
        '/api/documents/$id/send',
        body: {
          'invitations': [for (final i in invitations) i.raw],
        },
      );

  /// The signed PDF (Completed documents only).
  Future<DnFileBytes> download(String id) =>
      _client.postForFile('/api/documents/$id/download');

  /// The audit log PDF (Completed documents only).
  Future<DnFileBytes> auditLog(String id) =>
      _client.postForFile('/api/documents/$id/audit_log');

  static Map<String, dynamic> _asMap(Object? json) =>
      json is Map ? Map<String, dynamic>.from(json) : <String, dynamic>{};

  static Map<String, dynamic> _data(Object? json) {
    final map = _asMap(json);
    final data = map['data'];
    return data is Map ? Map<String, dynamic>.from(data) : map;
  }
}
