import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/json_coercion.dart';

part 'task_status_api_model.freezed.dart';
part 'task_status_api_model.g.dart';

/// Raw JSON shape of a task status as returned by `/api/v1/task_statuses`.
@freezed
abstract class TaskStatusApi with _$TaskStatusApi {
  const factory TaskStatusApi({
    @Default('') String id,
    @Default('') String name,
    @Default('') String color,
    @JsonKey(name: 'status_order') int? statusOrder,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
  }) = _TaskStatusApi;

  factory TaskStatusApi.fromJson(Map<String, dynamic> json) =>
      _$TaskStatusApiFromJson(json);
}

/// `GET /task_statuses` response envelope.
@freezed
abstract class TaskStatusListApi with _$TaskStatusListApi {
  const factory TaskStatusListApi({
    @JsonKey(fromJson: _taskStatusListData)
    @Default([])
    List<TaskStatusApi> data,
  }) = _TaskStatusListApi;

  factory TaskStatusListApi.fromJson(Map<String, dynamic> json) =>
      _$TaskStatusListApiFromJson(json);
}

/// `POST/PUT /task_statuses/{id}` single-item envelope.
@freezed
abstract class TaskStatusItemApi with _$TaskStatusItemApi {
  const factory TaskStatusItemApi({required TaskStatusApi data}) =
      _TaskStatusItemApi;

  factory TaskStatusItemApi.fromJson(Map<String, dynamic> json) =>
      _$TaskStatusItemApiFromJson(json);
}

List<TaskStatusApi> _taskStatusListData(Object? raw) =>
    tolerantList(raw, TaskStatusApi.fromJson, label: 'task_status');
