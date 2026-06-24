import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/json_coercion.dart';

part 'system_log_api_model.freezed.dart';
part 'system_log_api_model.g.dart';

/// Raw JSON shape of a system log row as returned by `/api/v1/system_logs`.
/// The `log` field is a plain string; for most events the server JSON-encodes
/// a request/response object into it, but a handful (e.g. SwiftMailer errors)
/// arrive as plain text — callers must `jsonDecode` defensively.
@freezed
abstract class SystemLogApi with _$SystemLogApi {
  const factory SystemLogApi({
    @Default('') String id,
    @JsonKey(name: 'company_id') @Default('') String companyId,
    @JsonKey(name: 'user_id') @Default('') String userId,
    @JsonKey(name: 'client_id') @Default('') String clientId,
    @JsonKey(name: 'event_id') @Default(0) int eventId,
    @JsonKey(name: 'category_id') @Default(0) int categoryId,
    @JsonKey(name: 'type_id') @Default(0) int typeId,
    @Default('') String log,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
  }) = _SystemLogApi;

  factory SystemLogApi.fromJson(Map<String, dynamic> json) =>
      _$SystemLogApiFromJson(json);
}

/// `GET /system_logs` response envelope. We only need `data` — the `meta`
/// pagination block is ignored (we fetch a single fixed page).
@freezed
abstract class SystemLogListApi with _$SystemLogListApi {
  const factory SystemLogListApi({
    @JsonKey(fromJson: _systemLogListData) @Default([]) List<SystemLogApi> data,
  }) = _SystemLogListApi;

  factory SystemLogListApi.fromJson(Map<String, dynamic> json) =>
      _$SystemLogListApiFromJson(json);
}

List<SystemLogApi> _systemLogListData(Object? raw) =>
    tolerantList(raw, SystemLogApi.fromJson, label: 'system_log');
