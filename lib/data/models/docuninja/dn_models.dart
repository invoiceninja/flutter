/// DocuNinja's own API shapes (`https://api.docuninja.co`), read from the
/// live service and React's `src/common/interfaces/docuninja/api.ts`
/// (docs/docuninja.md).
///
/// Prefixed `Dn` so they never collide with the Invoice Ninja `Document` and
/// `Invitation` models. Hand-written rather than freezed: every parse is
/// tolerant (a missing or mistyped field takes a default, never a throw, since
/// this is another team's API), and the records the app writes back whole
/// keep their [raw] JSON so a save carries the fields the app does not model.
library;

import 'package:admin/data/models/api/json_coercion.dart';

String _str(Object? v) => jsonScalarToString(v) ?? '';
String? _strOrNull(Object? v) {
  final s = jsonScalarToString(v);
  return s == null || s.isEmpty ? null : s;
}

int _int(Object? v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

double _double(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<Map<String, dynamic>> _maps(Object? v) => v is List
    ? [
        for (final e in v)
          if (e is Map) Map<String, dynamic>.from(e),
      ]
    : const [];

List<String> _strings(Object? v) => v is List
    ? [
        for (final e in v)
          if (e != null) _str(e),
      ]
    : const [];

/// A document's lifecycle (`DocumentStatus` in React's `api.ts`).
enum DnDocumentStatus {
  draft(1),
  pendingApproval(2),
  approved(3),
  rejected(4),
  sent(5),
  completed(6),
  expired(7),
  voided(8);

  const DnDocumentStatus(this.id);
  final int id;

  static DnDocumentStatus? fromId(int id) {
    for (final s in values) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// What the IN server's `POST /api/docuninja/login` returns: the DocuNinja
/// user, every DocuNinja company they belong to (each with its own token),
/// and their role on the account. The role and permissions are the user's,
/// once, not per company (observed live).
class DnLogin {
  const DnLogin({
    required this.user,
    required this.companies,
    required this.companyUser,
    required this.account,
    required this.permissions,
  });

  factory DnLogin.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map ? _map(json['data']) : json;
    return DnLogin(
      user: DnUser.fromJson(data),
      companies: [
        for (final c in _maps(data['companies'])) DnCompany.fromJson(c),
      ],
      companyUser: DnCompanyUser.fromJson(_map(data['company_user'])),
      account: DnAccount.fromJson(_map(data['account'])),
      permissions: [
        for (final p in _maps(data['permissions'])) DnPermission.fromJson(p),
      ],
    );
  }

  final DnUser user;
  final List<DnCompany> companies;
  final DnCompanyUser companyUser;
  final DnAccount account;
  final List<DnPermission> permissions;

  /// The DocuNinja company paired with the Invoice Ninja company whose
  /// `company_key` is [ninjaCompanyKey], as React picks it
  /// (`DocuNinjaProvider.tsx`). Null when this IN company has none yet —
  /// React's company-setup step.
  DnCompany? companyFor(String ninjaCompanyKey) {
    if (ninjaCompanyKey.isEmpty) return null;
    for (final c in companies) {
      if (c.ninjaCompanyKey == ninjaCompanyKey) return c;
    }
    return null;
  }
}

class DnCompany {
  const DnCompany({
    required this.id,
    required this.name,
    required this.token,
    required this.ninjaCompanyKey,
    required this.dateFormat,
    required this.documentLimit,
    required this.isPaid,
    required this.settings,
    this.raw = const {},
  });

  factory DnCompany.fromJson(Map<String, dynamic> json) => DnCompany(
    raw: json,
    id: _str(json['id']),
    name: _str(json['name']),
    token: _str(json['token']),
    ninjaCompanyKey: _str(json['ninja_company_key']),
    dateFormat: _str(json['date_format']),
    documentLimit: _int(json['document_limit']),
    isPaid: jsonScalarToBool(json['is_paid']),
    settings: _map(json['settings']),
  );

  final String id;
  final String name;

  /// This company's DocuNinja bearer token. Held in memory only.
  final String token;
  final String ninjaCompanyKey;

  /// A PHP date format (`d/M/Y`).
  final String dateFormat;

  /// How many documents the company may create on its plan.
  final int documentLimit;
  final bool isPaid;

  /// The company's DocuNinja settings, raw (written back whole).
  final Map<String, dynamic> settings;

  /// Every key, as the login answer carried it: React's settings pages put
  /// the whole company back with `settings` changed.
  final Map<String, dynamic> raw;
}

class DnAccount {
  const DnAccount({
    required this.id,
    required this.plan,
    required this.planExpires,
    required this.numUsers,
  });

  factory DnAccount.fromJson(Map<String, dynamic> json) => DnAccount(
    id: _str(json['id']),
    plan: _str(json['plan']),
    planExpires: _str(json['plan_expires']),
    numUsers: _int(json['num_users']),
  );

  final String id;

  /// `free` or `pro` (observed). React walls a DocuNinja admin off the module
  /// when this is not `pro` (`Documents.tsx` `needsPlanUpgrade`).
  final String plan;
  final String planExpires;

  /// DocuNinja seats on the account: the limit React's user selection checks.
  final int numUsers;
}

class DnCompanyUser {
  const DnCompanyUser({
    required this.isAdmin,
    required this.isOwner,
    required this.notifications,
  });

  factory DnCompanyUser.fromJson(Map<String, dynamic> json) => DnCompanyUser(
    isAdmin: jsonScalarToBool(json['is_admin']),
    isOwner: jsonScalarToBool(json['is_owner']),
    notifications: _strings(json['notifications']),
  );

  final bool isAdmin;
  final bool isOwner;
  final List<String> notifications;
}

class DnPermission {
  const DnPermission({
    required this.model,
    required this.permissionId,
    this.permissionableId,
  });

  factory DnPermission.fromJson(Map<String, dynamic> json) => DnPermission(
    model: _str(json['model']),
    permissionId: _int(json['permission_id']),
    // React counts a grant as global only when this is exactly `null`
    // (`permission.ts`); a missing key or `""` is not, so both stay scoped
    // here and the check fails closed.
    permissionableId:
        json.containsKey('permissionable_id') &&
            json['permissionable_id'] == null
        ? null
        : jsonScalarToString(json['permissionable_id']) ?? '',
  );

  final String model;
  final int permissionId;

  /// React's grid writes a global grant (`permissionable_id: null`).
  Map<String, dynamic> toJson() => {
    'model': model,
    'id': '',
    'permission_id': permissionId,
    'permissionable_id': permissionableId,
  };

  /// Set on a grant scoped to one record. React counts only global grants:
  /// null here, and only when DocuNinja sent an explicit `null`.
  final String? permissionableId;
}

class DnUser {
  const DnUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.eSignature,
    required this.eInitials,
    this.isDeleted = false,
    this.archivedAt,
    this.isAdmin = false,
    this.isOwner = false,
    this.permissions = const [],
    this.notifications = const [],
    this.raw = const {},
  });

  factory DnUser.fromJson(Map<String, dynamic> json) {
    final cu = _map(json['company_user']);
    return DnUser(
      id: _str(json['id']),
      firstName: _str(json['first_name']),
      lastName: _str(json['last_name']),
      email: _str(json['email']),
      eSignature: _str(json['e_signature']),
      eInitials: _str(json['e_initials']),
      isDeleted: jsonScalarToBool(json['is_deleted']),
      archivedAt: _strOrNull(json['archived_at']),
      isAdmin: jsonScalarToBool(cu['is_admin']),
      isOwner: jsonScalarToBool(cu['is_owner']),
      permissions: [
        for (final p in _maps(json['permissions'])) DnPermission.fromJson(p),
      ],
      notifications: _strings(cu['notifications']),
      raw: json,
    );
  }

  final String id;
  final String firstName;
  final String lastName;
  final String email;

  /// The saved signature / initials (an image data URL), or empty.
  final String eSignature;
  final String eInitials;

  final bool isDeleted;
  final String? archivedAt;

  /// The DocuNinja role (`company_user`), not the Invoice Ninja one.
  final bool isAdmin;
  final bool isOwner;
  final List<DnPermission> permissions;

  /// React's notification codes: `all`, `all_user`, or `<type>` /
  /// `<type>_user` per document event.
  final List<String> notifications;

  /// Every key, so a save writes back what the app does not model (React
  /// puts the whole user back).
  final Map<String, dynamic> raw;

  String get name => [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
  bool get isArchived => archivedAt != null && !isDeleted;
  bool get isActive => !isDeleted && archivedAt == null;
}

/// A client contact as DocuNinja holds it: its own copy, with the IN
/// `contact_key`.
class DnContact {
  const DnContact({
    required this.id,
    required this.clientId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.contactKey,
  });

  factory DnContact.fromJson(Map<String, dynamic> json) => DnContact(
    id: _str(json['id']),
    clientId: _str(json['client_id']),
    firstName: _str(json['first_name']),
    lastName: _str(json['last_name']),
    email: _str(json['email']),
    contactKey: _str(json['contact_key']),
  );

  final String id;
  final String clientId;
  final String firstName;
  final String lastName;
  final String email;
  final String contactKey;

  String get name => [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
}

class DnDocument {
  const DnDocument({
    required this.id,
    required this.description,
    required this.statusId,
    required this.isDeleted,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    required this.files,
    required this.invitations,
    required this.raw,
    this.archivedAt,
    this.completedAt,
    this.voidedAt,
    this.expiresAt,
    this.user,
  });

  factory DnDocument.fromJson(Map<String, dynamic> json) => DnDocument(
    id: _str(json['id']),
    description: _str(json['description']),
    // A missing status is not a draft: 0 matches no status, so nothing is
    // offered on a document whose state is unknown.
    statusId: _int(json['status_id']),
    isDeleted: jsonScalarToBool(json['is_deleted']),
    userId: _str(json['user_id']),
    createdAt: _str(json['created_at']),
    updatedAt: _str(json['updated_at']),
    archivedAt: _strOrNull(json['archived_at']),
    completedAt: _strOrNull(json['completed_at']),
    voidedAt: _strOrNull(json['voided_at']),
    expiresAt: _strOrNull(json['expires_at']),
    files: [for (final f in _maps(json['files'])) DnFile.fromJson(f)],
    invitations: [
      for (final i in _maps(json['invitations'])) DnInvitation.fromJson(i),
    ],
    user: json['user'] is Map ? DnUser.fromJson(_map(json['user'])) : null,
    raw: json,
  );

  final String id;
  final String description;
  final int statusId;
  final bool isDeleted;
  final String userId;
  final String createdAt;
  final String updatedAt;
  final String? archivedAt;
  final String? completedAt;
  final String? voidedAt;
  final String? expiresAt;
  final List<DnFile> files;
  final List<DnInvitation> invitations;

  /// Who created it.
  final DnUser? user;

  /// The JSON as received, for whole-object writes.
  final Map<String, dynamic> raw;

  DnDocumentStatus? get status => DnDocumentStatus.fromId(statusId);
  bool get isArchived => archivedAt != null && !isDeleted;

  /// Invitations in signing order (React's `Invitations.tsx`).
  List<DnInvitation> get invitationsInOrder =>
      [...invitations]
        ..sort((a, b) => a.signingOrder.compareTo(b.signingOrder));
}

class DnFile {
  const DnFile({
    required this.id,
    required this.filename,
    required this.mimeType,
    required this.pagePosition,
    required this.pageCount,
    required this.previews,
    required this.url,
    required this.rectangles,
    required this.raw,
  });

  factory DnFile.fromJson(Map<String, dynamic> json) {
    final metadata = _map(json['metadata']);
    return DnFile(
      id: _str(json['id']),
      filename: _str(json['filename']),
      mimeType: _str(json['mime_type']),
      pagePosition: _int(json['page_position']),
      pageCount: _int(json['page_count']),
      previews: _strings(json['previews']),
      url: _str(json['url']),
      rectangles: [
        for (final r in _maps(metadata['rectangles'])) DnRectangle.fromJson(r),
      ],
      raw: json,
    );
  }

  final String id;
  final String filename;
  final String mimeType;
  final int pagePosition;
  final int pageCount;

  /// One page image per page, server-rendered. Signed URLs that expire
  /// (an hour, observed), so they are re-read with the document, never
  /// stored.
  final List<String> previews;

  /// The canonical file (needs the bearer token). Read only in `lib/data`.
  final String url;
  final List<DnRectangle> rectangles;
  final Map<String, dynamic> raw;
}

/// A field placed on a page. `left` / `top` / `width` / `height` are
/// percentages (0–100) of the page box, `page` is 1-based, and `signatoryId`
/// is the invitation's `client_contact_id` or `user_id` (docs/docuninja.md).
class DnRectangle {
  const DnRectangle({
    required this.id,
    required this.type,
    required this.label,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.page,
    required this.signatoryId,
    required this.color,
    required this.required,
    required this.showLabel,
    required this.raw,
  });

  factory DnRectangle.fromJson(Map<String, dynamic> json) => DnRectangle(
    id: _str(json['id']),
    type: _str(json['type']),
    label: _str(json['label']),
    left: _double(json['left']),
    top: _double(json['top']),
    width: _double(json['width']),
    height: _double(json['height']),
    page: _int(json['page'], 1),
    signatoryId: _str(json['signatory_id']),
    color: _str(json['color']),
    required: jsonScalarToBool(json['required']),
    showLabel: jsonScalarToBool(json['show_label']),
    raw: json,
  );

  final String id;

  /// signature, initial, input, date, checkbox, select, radio, multiselect,
  /// number or variable.
  final String type;
  final String label;
  final double left;
  final double top;
  final double width;
  final double height;
  final int page;
  final String signatoryId;
  final String color;
  final bool required;
  final bool showLabel;

  /// Everything else (`options`, `conditional`, `copyToAllPages`, …), as
  /// received.
  final Map<String, dynamic> raw;
}

/// Where a signer is, derived from the dates as React does
/// (`Invitations.tsx`).
enum DnInvitationState { signed, viewed, sent, pending }

class DnInvitation {
  const DnInvitation({
    required this.id,
    required this.entity,
    required this.userId,
    required this.clientContactId,
    required this.clientId,
    required this.signingOrder,
    required this.emailError,
    required this.raw,
    this.sentDate,
    this.viewedDate,
    this.openedDate,
    this.signedDate,
    this.contact,
    this.user,
  });

  factory DnInvitation.fromJson(Map<String, dynamic> json) => DnInvitation(
    id: _str(json['id']),
    entity: _str(json['entity']),
    userId: _str(json['user_id']),
    clientContactId: _str(json['client_contact_id']),
    clientId: _str(json['client_id']),
    signingOrder: _int(json['signing_order']),
    emailError: _str(json['email_error']),
    sentDate: _strOrNull(json['sent_date']),
    viewedDate: _strOrNull(json['viewed_date']),
    openedDate: _strOrNull(json['opened_date']),
    signedDate: _strOrNull(json['signed_date']),
    contact: json['contact'] is Map
        ? DnContact.fromJson(_map(json['contact']))
        : null,
    user: json['user'] is Map ? DnUser.fromJson(_map(json['user'])) : null,
    raw: json,
  );

  final String id;

  /// `contact` or `user`.
  final String entity;
  final String userId;
  final String clientContactId;
  final String clientId;
  final int signingOrder;
  final String emailError;
  final String? sentDate;
  final String? viewedDate;
  final String? openedDate;
  final String? signedDate;
  final DnContact? contact;
  final DnUser? user;
  final Map<String, dynamic> raw;

  bool get isContact => entity == 'contact';

  /// The id a rectangle's `signatory_id` names for this signer.
  String get signatoryId =>
      clientContactId.isNotEmpty ? clientContactId : userId;

  String get signerName => contact?.name ?? user?.name ?? '';
  String get signerEmail => contact?.email ?? user?.email ?? '';

  DnInvitationState get state {
    if (signedDate != null) return DnInvitationState.signed;
    if (viewedDate != null) return DnInvitationState.viewed;
    if (sentDate != null) return DnInvitationState.sent;
    return DnInvitationState.pending;
  }
}

/// One row of `POST /api/documents/{id}/timeline` (a bare array).
class DnTimelineEntry {
  const DnTimelineEntry({
    required this.id,
    required this.title,
    required this.description,
    required this.time,
    required this.completed,
  });

  factory DnTimelineEntry.fromJson(Map<String, dynamic> json) =>
      DnTimelineEntry(
        id: _int(json['id']),
        title: _str(json['title']),
        description: _str(json['description']),
        time: _str(json['time']),
        completed: jsonScalarToBool(json['completed']),
      );

  final int id;
  final String title;
  final String description;

  /// `YYYY-MM-DD HH:MM:SS`, or empty for a step not reached yet.
  final String time;
  final bool completed;
}

/// A DocuNinja template (React's "template", the API's blueprint): a
/// document with its fields placed, from which new documents are made.
class DnBlueprint {
  const DnBlueprint({
    required this.id,
    required this.name,
    required this.description,
    required this.isDeleted,
    required this.designHash,
    required this.entityType,
    required this.raw,
    this.archivedAt,
  });

  factory DnBlueprint.fromJson(Map<String, dynamic> json) {
    final document = _map(json['document']);
    final metadata = _map(document['metadata']);
    return DnBlueprint(
      id: _str(json['id']),
      name: _str(json['name']),
      description: _str(json['description']),
      isDeleted: jsonScalarToBool(json['is_deleted']),
      archivedAt: _strOrNull(json['archived_at']),
      designHash: _str(json['design_hash']),
      entityType: _str(metadata['entity_type']),
      raw: json,
    );
  }

  final String id;
  final String name;
  final String description;
  final bool isDeleted;
  final String? archivedAt;

  /// Set on a template made from an Invoice Ninja design
  /// (`/api/docuninja/stub_blueprint`); empty on one the user made.
  final String designHash;

  /// The Invoice Ninja document type a design template is for (`invoice`,
  /// `quote`, `credit`, `purchase_order`), or empty.
  final String entityType;

  /// Every key, so an edit writes back what the app does not model (React's
  /// Options modal sends the whole blueprint).
  final Map<String, dynamic> raw;

  bool get isArchived => archivedAt != null && !isDeleted;
  bool get isActive => !isDeleted && archivedAt == null;
  bool get isInvoiceNinjaDesign => designHash.isNotEmpty;
}

/// One of the company's DocuNinja email templates (the emails DocuNinja
/// sends signers), edited as subject and body.
class DnEmailTemplate {
  const DnEmailTemplate({
    required this.id,
    required this.name,
    required this.subject,
    required this.body,
    required this.raw,
  });

  factory DnEmailTemplate.fromJson(Map<String, dynamic> json) =>
      DnEmailTemplate(
        id: _str(json['id']),
        name: _str(json['name']),
        subject: _str(json['subject']),
        body: _str(json['body']),
        raw: json,
      );

  final String id;

  /// The server's own name for the email ("Document Sent", ...): shown as
  /// is, as React does.
  final String name;
  final String subject;
  final String body;
  final Map<String, dynamic> raw;

  DnEmailTemplate copyWith({String? subject, String? body}) => DnEmailTemplate(
    id: id,
    name: name,
    subject: subject ?? this.subject,
    body: body ?? this.body,
    raw: raw,
  );

  Map<String, dynamic> toJson() => {...raw, 'subject': subject, 'body': body};
}

/// A DocuNinja reminder schedule: an email [numDays] days before or after
/// an event.
class DnReminderSchedule {
  const DnReminderSchedule({
    required this.id,
    required this.name,
    required this.subject,
    required this.body,
    required this.numDays,
    required this.direction,
    required this.enabled,
    required this.isDeleted,
    this.archivedAt,
  });

  factory DnReminderSchedule.fromJson(Map<String, dynamic> json) =>
      DnReminderSchedule(
        id: _str(json['id']),
        name: _str(json['name']),
        subject: _str(json['subject']),
        body: _str(json['body']),
        numDays: _int(json['num_days']),
        direction: _str(json['schedule_direction']).isEmpty
            ? 'after_event'
            : _str(json['schedule_direction']),
        enabled: jsonScalarToBool(json['enabled']),
        isDeleted: jsonScalarToBool(json['is_deleted']),
        archivedAt: _strOrNull(json['archived_at']),
      );

  final String id;
  final String name;
  final String subject;
  final String body;
  final int numDays;

  /// `after_event` or `before_event`.
  final String direction;
  final bool enabled;
  final bool isDeleted;
  final String? archivedAt;

  /// What React's create and update send.
  Map<String, dynamic> toJson() => {
    'name': name,
    'subject': subject,
    'body': body,
    'num_days': numDays,
    'schedule_direction': direction,
    'enabled': enabled,
  };
}

/// A page of a DocuNinja list (`data` + Laravel's `meta`).
class DnPage<T> {
  const DnPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  factory DnPage.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parse,
  ) {
    final meta = _map(json['meta']);
    return DnPage(
      items: [for (final m in _maps(json['data'])) parse(m)],
      currentPage: _int(meta['current_page'], 1),
      lastPage: _int(meta['last_page'], 1),
      total: _int(meta['total']),
    );
  }

  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;
}
