import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/json_coercion.dart';

part 'expense_category_api_model.freezed.dart';
part 'expense_category_api_model.g.dart';

/// Raw JSON shape of an expense category as returned by
/// `/api/v1/expense_categories` and the `expense_categories` array bundled
/// onto each `data[N].company` in `/refresh?first_load=true`.
///
/// Mirrors [TaskStatusApi] minus `status_order` — expense categories don't
/// carry an ordering field. Keep the shape narrow; admin-portal's
/// `expense_category_model.dart` confirms there are no custom values, no
/// documents, no extra metadata.
@freezed
abstract class ExpenseCategoryApi with _$ExpenseCategoryApi {
  const factory ExpenseCategoryApi({
    @Default('') String id,
    @JsonKey(name: 'user_id') @Default('') String userId,
    @JsonKey(name: 'assigned_user_id') @Default('') String assignedUserId,
    @Default('') String name,
    @Default('') String color,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
  }) = _ExpenseCategoryApi;

  factory ExpenseCategoryApi.fromJson(Map<String, dynamic> json) =>
      _$ExpenseCategoryApiFromJson(json);
}

/// `GET /expense_categories` response envelope.
@freezed
abstract class ExpenseCategoryListApi with _$ExpenseCategoryListApi {
  const factory ExpenseCategoryListApi({
    @JsonKey(fromJson: _expenseCategoryListData)
    @Default([])
    List<ExpenseCategoryApi> data,
  }) = _ExpenseCategoryListApi;

  factory ExpenseCategoryListApi.fromJson(Map<String, dynamic> json) =>
      _$ExpenseCategoryListApiFromJson(json);
}

/// `POST/PUT /expense_categories/{id}` single-item envelope.
@freezed
abstract class ExpenseCategoryItemApi with _$ExpenseCategoryItemApi {
  const factory ExpenseCategoryItemApi({required ExpenseCategoryApi data}) =
      _ExpenseCategoryItemApi;

  factory ExpenseCategoryItemApi.fromJson(Map<String, dynamic> json) =>
      _$ExpenseCategoryItemApiFromJson(json);
}

List<ExpenseCategoryApi> _expenseCategoryListData(Object? raw) =>
    tolerantList(raw, ExpenseCategoryApi.fromJson, label: 'expense_category');
