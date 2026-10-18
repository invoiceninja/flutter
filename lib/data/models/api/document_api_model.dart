import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/json_coercion.dart';

part 'document_api_model.freezed.dart';
part 'document_api_model.g.dart';

/// Wire shape of an attachment record. Embedded as a JSON array on every
/// entity that supports documents (Company, Client, Product, …) — the
/// server's `documents` field has the same shape regardless of parent — and
/// listed company-wide by `GET /api/v1/documents` (the Documents screen).
///
/// The server sends a few more fields (`preview`, `disk`, `link`,
/// `project_id`, `vendor_id`) that nothing reads. `toJson` only ever writes
/// local Drift JSON (a parent's `documents` column, the `document_records`
/// payload); no parent's `toApiJson` sends documents back.
@freezed
abstract class DocumentApi with _$DocumentApi {
  @JsonSerializable(includeIfNull: false)
  const factory DocumentApi({
    @Default('') String id,
    @Default('') String name,
    @Default('') String hash,
    @Default('') String type,
    @Default('') String url,
    @Default(0) int size,
    // Pixel dimensions of an image; 0 for anything else.
    @Default(0) int width,
    @Default(0) int height,
    // Owner and assignee. `PUT` / `DELETE /documents/{id}` authorize against
    // these (`EntityPolicy::edit`), not against the record the file hangs off.
    @JsonKey(name: 'user_id', fromJson: jsonScalarToStringOrEmpty)
    @Default('')
    String userId,
    @JsonKey(name: 'assigned_user_id', fromJson: jsonScalarToStringOrEmpty)
    @Default('')
    String assignedUserId,
    @JsonKey(name: 'is_default') @Default(false) bool isDefault,
    @JsonKey(name: 'is_public') @Default(true) bool isPublic,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    // `deleted_at` on the server, which a document never sets: archive and
    // restore are no-ops (`DocumentRepository::archive`) and delete is a
    // hard `forceDelete`. Modeled so a server that starts archiving is read
    // honestly rather than silently.
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
    // The record the file is attached to. `DocumentTransformer` sends these
    // from invoiceninja/invoiceninja#13365 (BACKEND.md § Documents list); an
    // older server omits both, so they're nullable and read tolerantly.
    @JsonKey(name: 'documentable_type', fromJson: jsonScalarToString)
    String? documentableType,
    @JsonKey(name: 'documentable_id', fromJson: jsonScalarToString)
    String? documentableId,
  }) = _DocumentApi;

  factory DocumentApi.fromJson(Map<String, dynamic> json) =>
      _$DocumentApiFromJson(json);
}

/// `GET /api/v1/documents` response envelope.
@freezed
abstract class DocumentListApi with _$DocumentListApi {
  const factory DocumentListApi({
    @JsonKey(fromJson: _documentListData)
    @Default(<DocumentApi>[])
    List<DocumentApi> data,
  }) = _DocumentListApi;

  factory DocumentListApi.fromJson(Map<String, dynamic> json) =>
      _$DocumentListApiFromJson(json);
}

/// `GET` / `PUT /api/v1/documents/{id}` single-item envelope.
@freezed
abstract class DocumentItemApi with _$DocumentItemApi {
  const factory DocumentItemApi({required DocumentApi data}) = _DocumentItemApi;

  factory DocumentItemApi.fromJson(Map<String, dynamic> json) =>
      _$DocumentItemApiFromJson(json);
}

List<DocumentApi> _documentListData(Object? raw) =>
    tolerantList(raw, DocumentApi.fromJson, label: 'document');
