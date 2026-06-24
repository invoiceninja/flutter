import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/json_coercion.dart';

part 'tax_rate_api_model.freezed.dart';
part 'tax_rate_api_model.g.dart';

/// Raw JSON shape of a tax rate as returned by `/api/v1/tax_rates`.
/// Loaded bundled via `/refresh?first_load=true` — the entity exists in
/// `kDisabledEntityModules` until the CRUD screen lands.
@freezed
abstract class TaxRateApi with _$TaxRateApi {
  const factory TaxRateApi({
    @Default('') String id,
    @Default('') String name,
    @Default(0.0) double rate,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
  }) = _TaxRateApi;

  factory TaxRateApi.fromJson(Map<String, dynamic> json) =>
      _$TaxRateApiFromJson(json);
}

@freezed
abstract class TaxRateListApi with _$TaxRateListApi {
  const factory TaxRateListApi({
    @JsonKey(fromJson: _taxRateListData) @Default([]) List<TaxRateApi> data,
  }) = _TaxRateListApi;

  factory TaxRateListApi.fromJson(Map<String, dynamic> json) =>
      _$TaxRateListApiFromJson(json);
}

@freezed
abstract class TaxRateItemApi with _$TaxRateItemApi {
  const factory TaxRateItemApi({required TaxRateApi data}) = _TaxRateItemApi;

  factory TaxRateItemApi.fromJson(Map<String, dynamic> json) =>
      _$TaxRateItemApiFromJson(json);
}

List<TaxRateApi> _taxRateListData(Object? raw) =>
    tolerantList(raw, TaxRateApi.fromJson, label: 'tax_rate');
