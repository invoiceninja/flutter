import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/json_coercion.dart';

part 'activity_api_model.freezed.dart';
part 'activity_api_model.g.dart';

/// Admin-portal's `kActivityComment` — the activity_type_id assigned by the
/// server to user-authored notes added via `/api/v1/activities/notes`. See
/// admin-portal `lib/constants.dart:1362`.
const int kCommentActivityTypeId = 141;

/// Denormalized `{ label, hashed_id }` link returned by the
/// `/api/v1/activities/entity` endpoint for the user / related entities of
/// each activity row. The fields the server omits arrive as null, hence the
/// nullable shape.
@freezed
abstract class ActivityLabelApi with _$ActivityLabelApi {
  const factory ActivityLabelApi({
    @Default('') String label,
    @JsonKey(name: 'hashed_id') @Default('') String hashedId,
    // Only the `contact` object carries this ('clients' | 'vendors'); it
    // routes a contact link to the right detail screen. Harmless default
    // for every other label object.
    @JsonKey(name: 'contact_entity') @Default('') String contactEntity,
  }) = _ActivityLabelApi;

  factory ActivityLabelApi.fromJson(Map<String, dynamic> json) =>
      _$ActivityLabelApiFromJson(json);
}

/// Rich activity row as returned by `POST /api/v1/activities/entity`.
///
/// We don't model the embedded `?include=activities` shape — that form
/// returns flat ids (`user_id`, `client_id`, …) which would force the UI to
/// look up display names from a users table we don't ship yet.
@freezed
abstract class ActivityApi with _$ActivityApi {
  const factory ActivityApi({
    @JsonKey(name: 'hashed_id') @Default('') String id,
    @JsonKey(name: 'activity_type_id') @Default(0) int activityTypeId,
    @Default('') String notes,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @Default('') String ip,
    ActivityLabelApi? user,
    ActivityLabelApi? client,
    ActivityLabelApi? invoice,
    ActivityLabelApi? contact,
    ActivityLabelApi? quote,
    ActivityLabelApi? payment,
    @JsonKey(name: 'payment_amount') ActivityLabelApi? paymentAmount,
    ActivityLabelApi? expense,
    ActivityLabelApi? credit,
    ActivityLabelApi? task,
    ActivityLabelApi? vendor,
    @JsonKey(name: 'recurring_invoice') ActivityLabelApi? recurringInvoice,
    @JsonKey(name: 'recurring_expense') ActivityLabelApi? recurringExpense,
    @JsonKey(name: 'purchase_order') ActivityLabelApi? purchaseOrder,
    ActivityLabelApi? subscription,
    ActivityLabelApi? adjustment,
  }) = _ActivityApi;

  factory ActivityApi.fromJson(Map<String, dynamic> json) =>
      _$ActivityApiFromJson(json);
}

/// `POST /api/v1/activities/entity` response envelope.
@freezed
abstract class ActivityListApi with _$ActivityListApi {
  const factory ActivityListApi({
    @JsonKey(fromJson: _activityListData) @Default([]) List<ActivityApi> data,
  }) = _ActivityListApi;

  factory ActivityListApi.fromJson(Map<String, dynamic> json) =>
      _$ActivityListApiFromJson(json);
}

List<ActivityApi> _activityListData(Object? raw) =>
    tolerantList(raw, ActivityApi.fromJson, label: 'activity');
