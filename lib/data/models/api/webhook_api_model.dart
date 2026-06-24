import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/json_coercion.dart';

part 'webhook_api_model.freezed.dart';
part 'webhook_api_model.g.dart';

/// PHP's `json_encode` serializes an empty associative array as `[]` instead
/// of `{}`. The strict generated parser crashes on the `Map` cast — coerce
/// a non-Map value to an empty map and stringify values defensively.
Map<String, String> _headersFromJson(Object? value) {
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
  }
  return const <String, String>{};
}

/// Wire shape of `/api/v1/webhooks/{id}`.
///
/// One webhook subscribes a single `target_url` to a single event (`event_id`,
/// e.g. `create_client`, `update_invoice`). The server `POST`s the event
/// payload to the URL using [restMethod] with the headers in [headers]; the
/// body is always JSON for now (`format = "JSON"`).
@freezed
abstract class WebhookApi with _$WebhookApi {
  @JsonSerializable(includeIfNull: false)
  const factory WebhookApi({
    @Default('') String id,
    @JsonKey(name: 'event_id') @Default('') String eventId,
    @JsonKey(name: 'target_url') @Default('') String targetUrl,
    @Default('JSON') String format,
    @JsonKey(name: 'rest_method') @Default('post') String restMethod,
    @JsonKey(fromJson: _headersFromJson)
    @Default(<String, String>{})
    Map<String, String> headers,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
  }) = _WebhookApi;

  factory WebhookApi.fromJson(Map<String, dynamic> json) =>
      _$WebhookApiFromJson(json);
}

/// `GET /webhooks` envelope.
@freezed
abstract class WebhookListApi with _$WebhookListApi {
  const factory WebhookListApi({
    @JsonKey(fromJson: _webhookListData) @Default([]) List<WebhookApi> data,
  }) = _WebhookListApi;

  factory WebhookListApi.fromJson(Map<String, dynamic> json) =>
      _$WebhookListApiFromJson(json);
}

/// `POST/PUT /webhooks/{id}` single-item envelope.
@freezed
abstract class WebhookItemApi with _$WebhookItemApi {
  const factory WebhookItemApi({required WebhookApi data}) = _WebhookItemApi;

  factory WebhookItemApi.fromJson(Map<String, dynamic> json) =>
      _$WebhookItemApiFromJson(json);
}

List<WebhookApi> _webhookListData(Object? raw) =>
    tolerantList(raw, WebhookApi.fromJson, label: 'webhook');
