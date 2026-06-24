import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/api/json_coercion.dart';
import 'package:admin/data/models/api/tag_api_model.dart';

part 'project_api_model.freezed.dart';
part 'project_api_model.g.dart';

/// Raw JSON shape of a project as returned by `/api/v1/projects`.
///
/// Mirrors the server keys exactly so `fromJson` is mechanical. Money fields
/// stay as `Object` (the server flips between number and string) and are
/// parsed via `parseMoney` in [Project.fromApi]. Hour fields are `num` so
/// they cleanly land as `double` in the domain model — they are not money.
@freezed
abstract class ProjectApi with _$ProjectApi {
  const factory ProjectApi({
    @Default('') String id,
    @JsonKey(name: 'user_id') @Default('') String userId,
    @JsonKey(name: 'assigned_user_id') @Default('') String assignedUserId,
    @JsonKey(name: 'client_id') @Default('') String clientId,
    @Default('') String number,
    @Default('') String name,
    @JsonKey(name: 'task_rate') @Default('0') Object taskRate,
    @JsonKey(name: 'due_date') @Default('') String dueDate,
    @JsonKey(name: 'private_notes') @Default('') String privateNotes,
    @JsonKey(name: 'public_notes') @Default('') String publicNotes,
    @JsonKey(name: 'budgeted_hours') @Default(0) num budgetedHours,
    @JsonKey(name: 'current_hours') @Default(0) num currentHours,
    @JsonKey(name: 'custom_value1') @Default('') String customValue1,
    @JsonKey(name: 'custom_value2') @Default('') String customValue2,
    @JsonKey(name: 'custom_value3') @Default('') String customValue3,
    @JsonKey(name: 'custom_value4') @Default('') String customValue4,
    @Default('') String color,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
    // Nullable so JSON-omitted (→ null) is distinguishable from
    // JSON-present-and-empty (→ `const []`). Same convention as
    // `ClientApi.documents` / `ProductApi.documents`.
    List<DocumentApi>? documents,
    // See `TaskApi.tags` — tolerant of `[{id,name,color}]` and bare ids.
    @JsonKey(name: 'tags')
    @EmbeddedTagsConverter()
    @Default(<TagRefApi>[])
    List<TagRefApi> tags,
  }) = _ProjectApi;

  factory ProjectApi.fromJson(Map<String, dynamic> json) =>
      _$ProjectApiFromJson(json);
}

/// `GET /projects` response envelope.
@freezed
abstract class ProjectListApi with _$ProjectListApi {
  const factory ProjectListApi({
    @JsonKey(fromJson: _projectListData) @Default([]) List<ProjectApi> data,
  }) = _ProjectListApi;

  factory ProjectListApi.fromJson(Map<String, dynamic> json) =>
      _$ProjectListApiFromJson(json);
}

/// `POST/PUT /projects/{id}` single-item envelope.
@freezed
abstract class ProjectItemApi with _$ProjectItemApi {
  const factory ProjectItemApi({required ProjectApi data}) = _ProjectItemApi;

  factory ProjectItemApi.fromJson(Map<String, dynamic> json) =>
      _$ProjectItemApiFromJson(json);
}

List<ProjectApi> _projectListData(Object? raw) =>
    tolerantList(raw, ProjectApi.fromJson, label: 'project');
