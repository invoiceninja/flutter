import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/json_coercion.dart';

part 'schedule_api_model.freezed.dart';
part 'schedule_api_model.g.dart';

/// Raw JSON shape of a task scheduler as returned by
/// `/api/v1/task_schedulers`. The server name is "task_scheduler" — the
/// user-facing label is "Schedule" everywhere in both legacy apps and we
/// keep that convention here.
///
/// `parameters` is intentionally a free `Map<String, dynamic>`. The actual
/// keys present depend on `template` (5 templates × — for `email_report`
/// — 19 report types, with overlapping but distinct keys). Modeling it as
/// a typed class would force us to drop unknown keys on round-trip, which
/// is the same trade-off `CompanyApi.settings` makes. The typed view lives
/// on the domain model. The nested lists inside `parameters`
/// (`clients: string[]`, `report_keys: string[]`, `schedule: [...]`)
/// survive the `jsonEncode(toJson())` round-trip because their leaves
/// are primitives — no `explicitToJson` annotation needed today.
@freezed
abstract class ScheduleApi with _$ScheduleApi {
  const factory ScheduleApi({
    @Default('') String id,
    @Default('') String name,
    @Default('') String template,
    @JsonKey(name: 'frequency_id') @Default('') String frequencyId,
    @JsonKey(name: 'next_run') @Default('') String nextRun,
    @JsonKey(name: 'is_paused') @Default(false) bool isPaused,
    @JsonKey(name: 'remaining_cycles') @Default(-1) int remainingCycles,
    @Default(<String, dynamic>{}) Map<String, dynamic> parameters,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
    @JsonKey(name: 'user_id') @Default('') String userId,
    @JsonKey(name: 'assigned_user_id') @Default('') String assignedUserId,
  }) = _ScheduleApi;

  factory ScheduleApi.fromJson(Map<String, dynamic> json) =>
      _$ScheduleApiFromJson(json);
}

/// `GET /task_schedulers` response envelope.
@freezed
abstract class ScheduleListApi with _$ScheduleListApi {
  const factory ScheduleListApi({
    @JsonKey(fromJson: _scheduleListData) @Default([]) List<ScheduleApi> data,
  }) = _ScheduleListApi;

  factory ScheduleListApi.fromJson(Map<String, dynamic> json) =>
      _$ScheduleListApiFromJson(json);
}

/// `POST/PUT /task_schedulers/{id}` single-item envelope.
@freezed
abstract class ScheduleItemApi with _$ScheduleItemApi {
  const factory ScheduleItemApi({required ScheduleApi data}) = _ScheduleItemApi;

  factory ScheduleItemApi.fromJson(Map<String, dynamic> json) =>
      _$ScheduleItemApiFromJson(json);
}

List<ScheduleApi> _scheduleListData(Object? raw) =>
    tolerantList(raw, ScheduleApi.fromJson, label: 'schedule');
