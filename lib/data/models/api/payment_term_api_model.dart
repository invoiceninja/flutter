import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/json_coercion.dart';

part 'payment_term_api_model.freezed.dart';
part 'payment_term_api_model.g.dart';

/// Raw JSON shape of a payment term as returned by `/api/v1/payment_terms`.
@freezed
abstract class PaymentTermApi with _$PaymentTermApi {
  const factory PaymentTermApi({
    @Default('') String id,
    @Default('') String name,
    @JsonKey(name: 'num_days') @Default(0) int numDays,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
  }) = _PaymentTermApi;

  factory PaymentTermApi.fromJson(Map<String, dynamic> json) =>
      _$PaymentTermApiFromJson(json);
}

/// `GET /payment_terms` response envelope.
@freezed
abstract class PaymentTermListApi with _$PaymentTermListApi {
  const factory PaymentTermListApi({
    @JsonKey(fromJson: _paymentTermListData)
    @Default([])
    List<PaymentTermApi> data,
  }) = _PaymentTermListApi;

  factory PaymentTermListApi.fromJson(Map<String, dynamic> json) =>
      _$PaymentTermListApiFromJson(json);
}

/// `POST/PUT /payment_terms/{id}` single-item envelope.
@freezed
abstract class PaymentTermItemApi with _$PaymentTermItemApi {
  const factory PaymentTermItemApi({required PaymentTermApi data}) =
      _PaymentTermItemApi;

  factory PaymentTermItemApi.fromJson(Map<String, dynamic> json) =>
      _$PaymentTermItemApiFromJson(json);
}

List<PaymentTermApi> _paymentTermListData(Object? raw) =>
    tolerantList(raw, PaymentTermApi.fromJson, label: 'payment_term');
