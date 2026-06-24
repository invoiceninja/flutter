import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/json_coercion.dart';

part 'token_api_model.freezed.dart';
part 'token_api_model.g.dart';

/// Wire shape of `/api/v1/tokens/{id}`.
///
/// The server returns the **raw bearer secret** in the `token` field only on
/// the create response (`POST /tokens`). Every subsequent payload — list,
/// get, refresh-envelope `tokens_hashed` — returns the value masked as the
/// first 10 chars of the secret followed by the literal string
/// `xxxxxxxxxxx`. The domain model surfaces an `isMasked` helper to detect
/// this and a `tokenHint` getter for the list display.
@freezed
abstract class TokenApi with _$TokenApi {
  @JsonSerializable(includeIfNull: false)
  const factory TokenApi({
    @Default('') String id,
    @JsonKey(name: 'user_id') @Default('') String userId,
    @Default('') String token,
    @Default('') String name,
    @JsonKey(name: 'is_system') @Default(false) bool isSystem,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
  }) = _TokenApi;

  factory TokenApi.fromJson(Map<String, dynamic> json) =>
      _$TokenApiFromJson(json);
}

/// `GET /tokens` envelope.
@freezed
abstract class TokenListApi with _$TokenListApi {
  const factory TokenListApi({
    @JsonKey(fromJson: _tokenListData) @Default([]) List<TokenApi> data,
  }) = _TokenListApi;

  factory TokenListApi.fromJson(Map<String, dynamic> json) =>
      _$TokenListApiFromJson(json);
}

/// `POST/PUT /tokens/{id}` single-item envelope.
@freezed
abstract class TokenItemApi with _$TokenItemApi {
  const factory TokenItemApi({required TokenApi data}) = _TokenItemApi;

  factory TokenItemApi.fromJson(Map<String, dynamic> json) =>
      _$TokenItemApiFromJson(json);
}

List<TokenApi> _tokenListData(Object? raw) =>
    tolerantList(raw, TokenApi.fromJson, label: 'token');
