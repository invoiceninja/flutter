import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/api/json_coercion.dart';
import 'package:admin/data/models/api/tag_api_model.dart';

part 'product_api_model.freezed.dart';
part 'product_api_model.g.dart';

/// Raw JSON shape of a product as returned by `/api/v1/products`.
///
/// Mirrors the server keys exactly so `fromJson` is mechanical. Money
/// fields stay as `Object` (the server's flip between number and string)
/// and are parsed via `parseMoney` in [Product.fromApi].
@freezed
abstract class ProductApi with _$ProductApi {
  const factory ProductApi({
    @Default('') String id,
    @JsonKey(name: 'user_id') @Default('') String userId,
    @JsonKey(name: 'assigned_user_id') @Default('') String assignedUserId,
    @JsonKey(name: 'product_key') @Default('') String productKey,
    @Default('') String notes,
    @JsonKey(name: 'cost') @Default('0') Object cost,
    @JsonKey(name: 'price') @Default('0') Object price,
    @JsonKey(name: 'quantity') @Default('0') Object quantity,
    @JsonKey(name: 'tax_name1') @Default('') String taxName1,
    @JsonKey(name: 'tax_rate1') @Default(0) num taxRate1,
    @JsonKey(name: 'tax_name2') @Default('') String taxName2,
    @JsonKey(name: 'tax_rate2') @Default(0) num taxRate2,
    @JsonKey(name: 'tax_name3') @Default('') String taxName3,
    @JsonKey(name: 'tax_rate3') @Default(0) num taxRate3,
    @JsonKey(name: 'tax_id') @Default('') String taxId,
    @JsonKey(name: 'custom_value1') @Default('') String customValue1,
    @JsonKey(name: 'custom_value2') @Default('') String customValue2,
    @JsonKey(name: 'custom_value3') @Default('') String customValue3,
    @JsonKey(name: 'custom_value4') @Default('') String customValue4,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
    @JsonKey(name: 'in_stock_quantity') @Default(0) num inStockQuantity,
    @JsonKey(name: 'stock_notification') @Default(false) bool stockNotification,
    @JsonKey(name: 'stock_notification_threshold')
    @Default(0)
    num stockNotificationThreshold,
    @JsonKey(name: 'max_quantity') @Default(0) num maxQuantity,
    @JsonKey(name: 'product_image') @Default('') String productImage,
    @JsonKey(name: 'income_account_id') @Default('') String incomeAccountId,
    // Attached tags — `[{id, name, color}]` from the server (or bare ids on the
    // Drift-payload round-trip). The domain keeps just the ids.
    @JsonKey(name: 'tags')
    @EmbeddedTagsConverter()
    @Default(<TagRefApi>[])
    List<TagRefApi> tags,
    // Nullable so JSON-omitted (→ null) is distinguishable from
    // JSON-present-and-empty (→ `const []`). See `ClientApi.documents` for
    // the rationale.
    List<DocumentApi>? documents,
  }) = _ProductApi;

  factory ProductApi.fromJson(Map<String, dynamic> json) =>
      _$ProductApiFromJson(json);
}

/// `GET /products` response envelope.
@freezed
abstract class ProductListApi with _$ProductListApi {
  const factory ProductListApi({
    @JsonKey(fromJson: _productListData) @Default([]) List<ProductApi> data,
  }) = _ProductListApi;

  factory ProductListApi.fromJson(Map<String, dynamic> json) =>
      _$ProductListApiFromJson(json);
}

/// `POST/PUT /products/{id}` single-item envelope.
@freezed
abstract class ProductItemApi with _$ProductItemApi {
  const factory ProductItemApi({required ProductApi data}) = _ProductItemApi;

  factory ProductItemApi.fromJson(Map<String, dynamic> json) =>
      _$ProductItemApiFromJson(json);
}

List<ProductApi> _productListData(Object? raw) =>
    tolerantList(raw, ProductApi.fromJson, label: 'product');
