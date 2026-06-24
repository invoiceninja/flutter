import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/json_coercion.dart';

part 'tag_api_model.freezed.dart';
part 'tag_api_model.g.dart';

/// Normalize a tag's `entity_type` to the short key (`task` / `project`).
///
/// The server stores + echoes the FQCN (`App\Models\Task`) because the
/// morphMap only aliases invoices/proposals, but the index endpoint and our
/// create payload both speak the short key. We normalize on every ingest so
/// the rest of the app only ever sees `task` / `project`.
String normalizeTagEntityType(String raw) {
  final v = raw.trim();
  if (v == 'task' || v == 'project') return v;
  final lower = v.toLowerCase();
  if (lower.endsWith('project')) return 'project';
  if (lower.endsWith('task')) return 'task';
  // Defensive: anything else (unexpected) falls back to the raw value so a
  // future taggable type isn't silently coerced to task/project.
  return v;
}

/// Raw JSON shape of a tag as returned by `/api/v1/tags`.
@freezed
abstract class TagApi with _$TagApi {
  const factory TagApi({
    @Default('') String id,
    // Echoed as the FQCN by the server; normalize via [normalizeTagEntityType]
    // before it reaches the domain model.
    @JsonKey(name: 'entity_type') @Default('') String entityType,
    @Default('') String name,
    // Hex string (`#RRGGBB`) or null when unset.
    String? color,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
  }) = _TagApi;

  factory TagApi.fromJson(Map<String, dynamic> json) => _$TagApiFromJson(json);
}

/// Minimal embedded tag shape as it appears on a task/project (`tags:
/// [{id, name, color}]`). Carried only so the repository can derive the
/// denormalized `tag_names` sort column on ingest — the domain model keeps
/// just the ids and resolves name/color from the tag cache for rendering.
@freezed
abstract class TagRefApi with _$TagRefApi {
  const factory TagRefApi({
    @Default('') String id,
    @Default('') String name,
    String? color,
  }) = _TagRefApi;

  factory TagRefApi.fromJson(Map<String, dynamic> json) =>
      _$TagRefApiFromJson(json);
}

/// Tolerant converter for a task/project `tags` field. Accepts both the
/// server's `[{id, name, color}]` mini-objects and the bare `["id", ...]`
/// form our own `toApiJson` / Drift-payload round-trip emits, yielding
/// [TagRefApi]s either way (name/color empty for the bare-id form).
class EmbeddedTagsConverter implements JsonConverter<List<TagRefApi>, Object?> {
  const EmbeddedTagsConverter();

  @override
  List<TagRefApi> fromJson(Object? json) {
    if (json is! List) return const <TagRefApi>[];
    final out = <TagRefApi>[];
    for (final e in json) {
      if (e is String) {
        if (e.isNotEmpty) out.add(TagRefApi(id: e));
      } else if (e is Map) {
        out.add(TagRefApi.fromJson(e.cast<String, dynamic>()));
      }
    }
    return out;
  }

  @override
  Object toJson(List<TagRefApi> object) =>
      object.map((t) => t.toJson()).toList();
}

/// `GET /tags` response envelope.
@freezed
abstract class TagListApi with _$TagListApi {
  const factory TagListApi({
    @JsonKey(fromJson: _tagListData) @Default([]) List<TagApi> data,
  }) = _TagListApi;

  factory TagListApi.fromJson(Map<String, dynamic> json) =>
      _$TagListApiFromJson(json);
}

/// `POST/PUT /tags/{id}` single-item envelope.
@freezed
abstract class TagItemApi with _$TagItemApi {
  const factory TagItemApi({required TagApi data}) = _TagItemApi;

  factory TagItemApi.fromJson(Map<String, dynamic> json) =>
      _$TagItemApiFromJson(json);
}

List<TagApi> _tagListData(Object? raw) =>
    tolerantList(raw, TagApi.fromJson, label: 'tag');
