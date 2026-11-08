import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/data/services/docuninja/docuninja_client.dart';

/// DocuNinja's endpoints (`api.docuninja.co/api/…`: documents, templates,
/// users, the company's settings, email templates and reminder schedules),
/// as React calls them. Everything is online-only and none of it goes
/// through the outbox: DocuNinja's send, sign and void are server-side state
/// machines a queued replay could not run safely (docs/docuninja.md).
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
      '/api/documents/${_seg(id)}',
      query: const {
        'includeUrl': 'true',
        'includePreviews': 'true',
        'includeUser': 'true',
      },
    );
    return DnDocument.fromJson(_data(json));
  }

  /// The templates, newest first (React's `Blueprints.tsx`). [status] is
  /// the lifecycle list (`active`, `archived`, `deleted`), comma-separated.
  Future<DnPage<DnBlueprint>> blueprints({
    int page = 1,
    int perPage = 20,
    String search = '',
    String status = 'active',
  }) async {
    final json = await _client.getJson(
      '/api/blueprints',
      query: {
        'page': '$page',
        'per_page': '$perPage',
        'sort': 'id|desc',
        if (search.isNotEmpty) 'search': search,
        if (status.isNotEmpty) 'status': status,
      },
    );
    return DnPage.fromJson(_asMap(json), DnBlueprint.fromJson);
  }

  /// A template of the user's own (React's "Create your own"); its PDF is
  /// uploaded in the template builder.
  Future<DnBlueprint> createBlueprint({
    required String name,
    required String description,
  }) async {
    final json = await _client.postJson(
      '/api/blueprints',
      body: {'name': name, 'description': description},
    );
    return DnBlueprint.fromJson(_data(json));
  }

  /// React's template Options: the whole template back, with the new name
  /// and description.
  Future<DnBlueprint> updateBlueprint(
    DnBlueprint blueprint, {
    required String name,
    required String description,
  }) async {
    final json = await _client.putJson(
      '/api/blueprints/${_seg(blueprint.id)}',
      body: {...blueprint.raw, 'name': name, 'description': description},
    );
    return DnBlueprint.fromJson(_data(json));
  }

  /// `archive`, `restore` or `delete` on several templates.
  Future<void> blueprintBulk(String action, List<String> ids) => _client
      .postJson('/api/blueprints/bulk', body: {'action': action, 'ids': ids});

  /// React's Use Template: a new document from the template, whose signers
  /// are mapped in the builder. Returns the new document's id.
  Future<String> makeDocument(String blueprintId) async {
    final json = await _client.postJson(
      '/api/blueprints/${_seg(blueprintId)}/action',
      body: const {'action': 'make_document'},
    );
    return '${_data(json)['id'] ?? ''}';
  }

  /// React's Clone to Template: a template from a document. Returns its id.
  Future<String> makeBlueprint(String documentId) async {
    final json = await _client.postJson(
      '/api/documents/${_seg(documentId)}/action',
      body: {'action': 'make_blueprint', 'id': documentId},
    );
    return '${_data(json)['id'] ?? ''}';
  }

  /// The company's DocuNinja users (React's `Users.tsx`), by the Invoice
  /// Ninja company they belong to.
  Future<DnPage<DnUser>> users({
    required String ninjaCompanyKey,
    int page = 1,
    int perPage = 20,
    String search = '',
    String status = 'active',
  }) async {
    final json = await _client.getJson(
      '/api/users',
      query: {
        'page': '$page',
        'per_page': '$perPage',
        'sort': 'id|desc',
        'ninjaCompanyKey': ninjaCompanyKey,
        if (search.isNotEmpty) 'search': search,
        if (status.isNotEmpty) 'status': status,
      },
    );
    return DnPage.fromJson(_asMap(json), DnUser.fromJson);
  }

  Future<DnUser> user(String id) async =>
      DnUser.fromJson(_data(await _client.getJson('/api/users/${_seg(id)}')));

  /// React's user Save: the whole user back with the role, permissions and
  /// notifications (an admin carries no permissions).
  Future<DnUser> updateUser(
    DnUser user, {
    required bool isAdmin,
    required List<DnPermission> permissions,
    required List<String> notifications,
  }) async {
    final json = await _client.putJson(
      '/api/users/${_seg(user.id)}',
      body: {
        ...user.raw,
        'is_admin': isAdmin,
        'permissions': isAdmin
            ? const <Object>[]
            : [for (final p in permissions) p.toJson()],
        'notifications': notifications,
      },
    );
    return DnUser.fromJson(_data(json));
  }

  /// `archive`, `restore` or `delete` on several users.
  Future<void> userBulk(String action, List<String> ids) =>
      _client.postJson('/api/users/bulk', body: {'action': action, 'ids': ids});

  /// React's settings pages: the whole company back with its settings
  /// replaced (`PUT /api/companies/{id}`).
  Future<void> updateCompanySettings(
    DnCompany company,
    Map<String, dynamic> settings,
  ) => _client.putJson(
    '/api/companies/${_seg(company.id)}',
    body: {...company.raw, 'settings': settings},
  );

  /// The company's email templates.
  Future<List<DnEmailTemplate>> emailTemplates() async {
    final json = await _client.getJson('/api/templates');
    final rows = _asMap(json)['data'];
    return [
      if (rows is List)
        for (final r in rows)
          if (r is Map) DnEmailTemplate.fromJson(Map<String, dynamic>.from(r)),
    ];
  }

  /// Saves every email template at once, as React does.
  Future<void> saveEmailTemplates(List<DnEmailTemplate> templates) =>
      _client.postJson(
        '/api/templates/bulk',
        body: {
          'action': 'update',
          'templates': [for (final t in templates) t.toJson()],
        },
      );

  /// The live reminder schedules (React hides archived and deleted ones).
  Future<List<DnReminderSchedule>> reminderSchedules() async {
    final json = await _client.getJson('/api/reminder_schedules');
    final rows = _asMap(json)['data'];
    return [
      if (rows is List)
        for (final r in rows)
          if (r is Map)
            DnReminderSchedule.fromJson(Map<String, dynamic>.from(r)),
    ].where((r) => !r.isDeleted && r.archivedAt == null).toList();
  }

  /// Creates a reminder schedule, or updates the one with [id].
  Future<void> saveReminderSchedule(
    DnReminderSchedule schedule, {
    String? id,
  }) => id == null
      ? _client.postJson('/api/reminder_schedules', body: schedule.toJson())
      : _client.putJson(
          '/api/reminder_schedules/${_seg(id)}',
          body: schedule.toJson(),
        );

  /// React's row toggle: only `enabled`.
  Future<void> setReminderScheduleEnabled(String id, bool enabled) =>
      _client.putJson(
        '/api/reminder_schedules/${_seg(id)}',
        body: {'enabled': enabled},
      );

  Future<void> deleteReminderSchedule(String id) =>
      _client.deleteJson('/api/reminder_schedules/${_seg(id)}');

  /// Creates a document from uploaded files (`POST /api/documents`,
  /// React's `Create.tsx` and drop zone): its fields are placed later, in
  /// the builder.
  Future<DnDocument> createDocument({
    required String description,
    required List<DnUploadPart> files,
  }) async {
    final json = await _client.postMultipart(
      '/api/documents',
      fields: {'description': description},
      files: files,
    );
    return DnDocument.fromJson(_data(json));
  }

  Future<List<DnTimelineEntry>> timeline(String id) async {
    final json = await _client.postJson('/api/documents/${_seg(id)}/timeline');
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
      '/api/documents/${_seg(id)}',
      body: {
        'description': description,
        if (setExpiry) 'expires_at': expiresAt,
      },
    );
    return DnDocument.fromJson(_data(json));
  }

  /// `archive`, `restore` or `delete` on several documents. React deletes
  /// through here too; its `DELETE /api/documents/{id}` is unreachable code.
  Future<void> bulk(String action, List<String> ids) => _client.postJson(
    '/api/documents/bulk',
    body: {'action': action, 'ids': ids},
  );

  /// `void`, `clone` or `make_blueprint`.
  Future<Object?> action(String id, String action) => _client.postJson(
    '/api/documents/${_seg(id)}/action',
    body: {'action': action, 'id': id},
  );

  /// Emails the invitations: all of them, or one to resend.
  Future<void> send(String id, List<DnInvitation> invitations) =>
      _client.postJson(
        '/api/documents/${_seg(id)}/send',
        body: {
          'invitations': [for (final i in invitations) i.raw],
        },
      );

  /// The signed PDF (Completed documents only).
  Future<DnFileBytes> download(String id) =>
      _client.postForFile('/api/documents/${_seg(id)}/download');

  /// The audit log PDF (Completed documents only).
  Future<DnFileBytes> auditLog(String id) =>
      _client.postForFile('/api/documents/${_seg(id)}/audit_log');

  /// One path segment: an id from a route (a web URL, decoded) can carry
  /// `/`, `?` or `..`, which must never reach another endpoint.
  static String _seg(String id) => Uri.encodeComponent(id);

  static Map<String, dynamic> _asMap(Object? json) =>
      json is Map ? Map<String, dynamic>.from(json) : <String, dynamic>{};

  static Map<String, dynamic> _data(Object? json) {
    final map = _asMap(json);
    final data = map['data'];
    return data is Map ? Map<String, dynamic>.from(data) : map;
  }
}
