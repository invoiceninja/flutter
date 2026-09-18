import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/json_coercion.dart';

part 'document_version_api_model.freezed.dart';
part 'document_version_api_model.g.dart';

/// Wire models for a billing document's **version history** — the `Backup`
/// rows the server writes on every non-email activity, surfaced as
/// `GET /api/v1/<entity>/{id}?include=activities.history`.
///
/// Deliberately separate from `activity_api_model.dart`, which models the
/// *other* activity serializer: `POST /api/v1/activities/entity` returns
/// `Activity::activity_string()` (denormalized `{label, hashed_id}` objects)
/// and explicitly calls `->without('backup')`, so it can never carry history.
/// This shape is `ActivityTransformer`'s — flat ids, and a nested `history`
/// object from `InvoiceHistoryTransformer`.
///
/// Only the nested `activities.history` include works. `?include=history` is
/// silently dropped (`history` is not in the billing-doc transformers'
/// `availableIncludes`, and `BaseController::getRequestIncludes()` drops
/// unknown includes), and `?include=activities` alone carries no history.

/// `GET /api/v1/<entity>/{id}?include=activities.history` response envelope.
@freezed
abstract class DocumentVersionItemApi with _$DocumentVersionItemApi {
  const factory DocumentVersionItemApi({
    @JsonKey(fromJson: _versionEntity)
    @Default(DocumentVersionEntityApi())
    DocumentVersionEntityApi data,
  }) = _DocumentVersionItemApi;

  factory DocumentVersionItemApi.fromJson(Map<String, dynamic> json) =>
      _$DocumentVersionItemApiFromJson(json);
}

/// The entity body. Every field but `activities` is ignored — this request is
/// only ever made for the history, and the record itself already lives in
/// Drift.
@freezed
abstract class DocumentVersionEntityApi with _$DocumentVersionEntityApi {
  const factory DocumentVersionEntityApi({
    @JsonKey(fromJson: _versionActivities)
    @Default([])
    List<DocumentVersionActivityApi> activities,
  }) = _DocumentVersionEntityApi;

  factory DocumentVersionEntityApi.fromJson(Map<String, dynamic> json) =>
      _$DocumentVersionEntityApiFromJson(json);
}

/// One activity row, carrying the backup it produced (if any).
///
/// `activity_type_id` arrives as a **string** (`"5"`) from
/// `ActivityTransformer`, unlike the int the `/activities/entity` serializer
/// emits — hence [jsonScalarToStringOrEmpty], which also survives a future
/// flip back to int.
///
/// `user_id` / `contact_id` / `is_system` are what let a history row name who
/// made the change without a second request.
@freezed
abstract class DocumentVersionActivityApi with _$DocumentVersionActivityApi {
  const factory DocumentVersionActivityApi({
    @JsonKey(fromJson: jsonScalarToStringOrEmpty) @Default('') String id,
    @JsonKey(name: 'activity_type_id', fromJson: jsonScalarToStringOrEmpty)
    @Default('')
    String activityTypeId,
    @JsonKey(name: 'user_id', fromJson: jsonScalarToStringOrEmpty)
    @Default('')
    String userId,
    @JsonKey(name: 'contact_id', fromJson: jsonScalarToStringOrEmpty)
    @Default('')
    String contactId,
    @JsonKey(name: 'is_system') @Default(false) bool isSystem,
    DocumentVersionHistoryApi? history,
  }) = _DocumentVersionActivityApi;

  factory DocumentVersionActivityApi.fromJson(Map<String, dynamic> json) =>
      _$DocumentVersionActivityApiFromJson(json);
}

/// The `history` object — one `Backup` row, via `InvoiceHistoryTransformer`.
///
/// **`json_backup` and `html_backup` are hardcoded to `''` server-side** (the
/// latter is marked deprecated; its column was dropped from the table in
/// 2022), so they are not modelled: there is no data snapshot to read, only a
/// frozen HTML render fetched as a PDF from
/// `GET /api/v1/activities/download_entity/{activity_id}`.
///
/// The object is **present but blank** when the activity produced no backup
/// (`activity_id: ""`, `amount: 0`), so `id.isNotEmpty` is the real gate —
/// the same test legacy admin-portal and the React client both apply.
///
/// `amount` is the document total *after* the event (`$backup->amount =
/// $entity->amount`, assigned after `$entity->fresh()`), which is what makes
/// a delta between consecutive versions honest. It arrives as a float but is
/// typed `Object` and parsed with `parseMoney` at the domain seam — raw-JSON
/// blobs bypass the server's read-time casts, so an int or a string is
/// possible.
@freezed
abstract class DocumentVersionHistoryApi with _$DocumentVersionHistoryApi {
  const factory DocumentVersionHistoryApi({
    @JsonKey(fromJson: jsonScalarToStringOrEmpty) @Default('') String id,
    @JsonKey(name: 'activity_id', fromJson: jsonScalarToStringOrEmpty)
    @Default('')
    String activityId,
    @Default('0') Object amount,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
  }) = _DocumentVersionHistoryApi;

  factory DocumentVersionHistoryApi.fromJson(Map<String, dynamic> json) =>
      _$DocumentVersionHistoryApiFromJson(json);
}

/// Tolerant of a `data` that is absent or not an object. The generated cast
/// would otherwise throw an uncaught `TypeError` out of the fetch, which is a
/// worse failure than an empty history for a surface that is purely
/// informational.
DocumentVersionEntityApi _versionEntity(Object? raw) =>
    raw is Map<String, dynamic>
    ? DocumentVersionEntityApi.fromJson(raw)
    : const DocumentVersionEntityApi();

List<DocumentVersionActivityApi> _versionActivities(Object? raw) =>
    tolerantList(
      raw,
      DocumentVersionActivityApi.fromJson,
      label: 'document version activity',
    );
