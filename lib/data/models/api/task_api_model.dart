import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/api/json_coercion.dart';
import 'package:admin/data/models/api/tag_api_model.dart';

part 'task_api_model.freezed.dart';
part 'task_api_model.g.dart';

/// Raw JSON shape of a task as returned by `/api/v1/tasks`.
///
/// `timeLog` stays as a `String` here (the raw JSON-array-of-arrays the
/// server returns). The domain model parses it into `List<TimeEntry>`
/// once in `Task.fromApi`.
@freezed
abstract class TaskApi with _$TaskApi {
  const factory TaskApi({
    @Default('') String id,
    @JsonKey(name: 'user_id') @Default('') String userId,
    @JsonKey(name: 'assigned_user_id') @Default('') String assignedUserId,
    @Default('') String number,
    @Default('') String description,
    @JsonKey(name: 'rate') @Default('0') Object rate,
    @JsonKey(name: 'invoice_id') @Default('') String invoiceId,
    @JsonKey(name: 'client_id') @Default('') String clientId,
    @JsonKey(name: 'project_id') @Default('') String projectId,
    @JsonKey(name: 'status_id') @Default('') String statusId,
    @JsonKey(name: 'status_order') int? statusOrder,
    @JsonKey(name: 'time_log') @Default('') String timeLog,
    @JsonKey(name: 'custom_value1') @Default('') String customValue1,
    @JsonKey(name: 'custom_value2') @Default('') String customValue2,
    @JsonKey(name: 'custom_value3') @Default('') String customValue3,
    @JsonKey(name: 'custom_value4') @Default('') String customValue4,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
    @JsonKey(name: 'is_running') @Default(false) bool isRunning,
    @JsonKey(name: 'is_date_based') @Default(false) bool isDateBased,
    // Nullable so JSON-omitted (→ null) is distinguishable from
    // JSON-present-and-empty (→ const []). Same convention as `ExpenseApi`.
    List<DocumentApi>? documents,
    // Server sends `[{id, name, color}]`; our payload round-trip sends bare
    // ids. The tolerant converter handles both. Names carried only for the
    // `tag_names` sort column — the domain keeps just the ids.
    @JsonKey(name: 'tags')
    @EmbeddedTagsConverter()
    @Default(<TagRefApi>[])
    List<TagRefApi> tags,
    // Server emits `meta` as `''` when unset (see `TaskTransformer`) or
    // `{calendar_event_id: ...}` when the task was converted from a calendar
    // event. The tolerant [TaskMetaConverter] maps the empty-string form → null
    // so json_serializable doesn't choke trying to decode a String as an object.
    @TaskMetaConverter() TaskMetaApi? meta,
  }) = _TaskApi;

  factory TaskApi.fromJson(Map<String, dynamic> json) =>
      _$TaskApiFromJson(json);
}

/// `meta` block on a task. Today this only carries the calendar-event link
/// the server uses to dedupe "convert event → task" (one task per user per
/// event); the server's `TaskMeta` DataMapper stores only `calendar_event_id`.
@freezed
abstract class TaskMetaApi with _$TaskMetaApi {
  const factory TaskMetaApi({
    @JsonKey(name: 'calendar_event_id') @Default('') String calendarEventId,
  }) = _TaskMetaApi;

  factory TaskMetaApi.fromJson(Map<String, dynamic> json) =>
      _$TaskMetaApiFromJson(json);
}

/// Tolerant converter for the task `meta` field. The server emits `''` for an
/// unset meta and `{calendar_event_id: ...}` otherwise; anything that isn't a
/// JSON object maps to `null`.
class TaskMetaConverter implements JsonConverter<TaskMetaApi?, Object?> {
  const TaskMetaConverter();

  @override
  TaskMetaApi? fromJson(Object? json) {
    if (json is Map) {
      return TaskMetaApi.fromJson(json.cast<String, dynamic>());
    }
    return null;
  }

  @override
  Object? toJson(TaskMetaApi? object) => object?.toJson();
}

/// `GET /tasks` response envelope.
@freezed
abstract class TaskListApi with _$TaskListApi {
  const factory TaskListApi({
    @JsonKey(fromJson: _taskListData) @Default([]) List<TaskApi> data,
  }) = _TaskListApi;

  factory TaskListApi.fromJson(Map<String, dynamic> json) =>
      _$TaskListApiFromJson(json);
}

/// `POST/PUT /tasks/{id}` single-item envelope.
@freezed
abstract class TaskItemApi with _$TaskItemApi {
  const factory TaskItemApi({required TaskApi data}) = _TaskItemApi;

  factory TaskItemApi.fromJson(Map<String, dynamic> json) =>
      _$TaskItemApiFromJson(json);
}

List<TaskApi> _taskListData(Object? raw) =>
    tolerantList(raw, TaskApi.fromJson, label: 'task');
