import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/api/json_coercion.dart';

part 'group_setting_api_model.freezed.dart';
part 'group_setting_api_model.g.dart';

/// Raw JSON shape of a group_settings row as returned by
/// `/api/v1/group_settings`. The `settings` map is kept raw because keys
/// vary widely and the cascade resolver in the UI reads them directly.
@freezed
abstract class GroupSettingApi with _$GroupSettingApi {
  const factory GroupSettingApi({
    @Default('') String id,
    @JsonKey(name: 'user_id') @Default('') String userId,
    @JsonKey(name: 'assigned_user_id') @Default('') String assignedUserId,
    @Default('') String name,
    @JsonKey(name: 'custom_value1') @Default('') String customValue1,
    @JsonKey(name: 'custom_value2') @Default('') String customValue2,
    @JsonKey(name: 'custom_value3') @Default('') String customValue3,
    @JsonKey(name: 'custom_value4') @Default('') String customValue4,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
    @JsonKey(name: 'settings', includeIfNull: false)
    Map<String, dynamic>? settings,
    // Nullable to distinguish JSON-omitted (list endpoint without
    // `?include=documents`) from JSON-present-and-empty. Lives in its own
    // Drift column; the repo's `_fromRow` overlays it. See `ClientApi.documents`.
    List<DocumentApi>? documents,
  }) = _GroupSettingApi;

  factory GroupSettingApi.fromJson(Map<String, dynamic> json) =>
      _$GroupSettingApiFromJson(json);
}

/// `GET /group_settings` response envelope.
@freezed
abstract class GroupSettingListApi with _$GroupSettingListApi {
  const factory GroupSettingListApi({
    @JsonKey(fromJson: _groupSettingListData)
    @Default([])
    List<GroupSettingApi> data,
  }) = _GroupSettingListApi;

  factory GroupSettingListApi.fromJson(Map<String, dynamic> json) =>
      _$GroupSettingListApiFromJson(json);
}

/// `POST/PUT /group_settings/{id}` single-item envelope.
@freezed
abstract class GroupSettingItemApi with _$GroupSettingItemApi {
  const factory GroupSettingItemApi({required GroupSettingApi data}) =
      _GroupSettingItemApi;

  factory GroupSettingItemApi.fromJson(Map<String, dynamic> json) =>
      _$GroupSettingItemApiFromJson(json);
}

List<GroupSettingApi> _groupSettingListData(Object? raw) =>
    tolerantList(raw, GroupSettingApi.fromJson, label: 'group_setting');
