import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/api/invitation_api_model.dart';
import 'package:admin/data/models/api/json_coercion.dart';
import 'package:admin/data/models/api/tag_api_model.dart';
import 'package:admin/data/models/api/line_item_api_model.dart';

part 'credit_api_model.freezed.dart';
part 'credit_api_model.g.dart';

/// Raw JSON shape of `/api/v1/credits/{id}`. Identical to [QuoteApi]
/// minus the `convert_to_*` linkage. Credits track an applied amount
/// (`paid_to_date`) like invoices do, since they can be partially
/// applied against multiple invoices.
@freezed
abstract class CreditApi with _$CreditApi {
  const factory CreditApi({
    @Default('') String id,
    @Default('') String number,
    @JsonKey(name: 'po_number') @Default('') String poNumber,
    @Default('') String date,
    @JsonKey(name: 'due_date') @Default('') String dueDate,
    @JsonKey(name: 'partial_due_date') @Default('') String partialDueDate,
    @JsonKey(name: 'status_id') @Default('1') String statusId,
    @JsonKey(name: 'client_id') @Default('') String clientId,
    @JsonKey(name: 'vendor_id') @Default('') String vendorId,
    @JsonKey(name: 'project_id') @Default('') String projectId,
    @JsonKey(name: 'design_id') @Default('') String designId,
    @JsonKey(name: 'assigned_user_id') @Default('') String assignedUserId,
    @JsonKey(name: 'user_id') @Default('') String userId,
    @JsonKey(name: 'location_id') @Default('') String locationId,
    @Default('0') Object amount,
    @Default('0') Object balance,
    @JsonKey(name: 'paid_to_date') @Default('0') Object paidToDate,
    @JsonKey(name: 'partial') @Default('0') Object partial,
    @JsonKey(name: 'total_taxes') @Default('0') Object totalTaxes,
    @Default('0') Object discount,
    @JsonKey(name: 'is_amount_discount') @Default(false) bool isAmountDiscount,
    @JsonKey(name: 'exchange_rate') @Default('1') Object exchangeRate,
    @JsonKey(name: 'tax_name1') @Default('') String taxName1,
    @JsonKey(name: 'tax_name2') @Default('') String taxName2,
    @JsonKey(name: 'tax_name3') @Default('') String taxName3,
    @JsonKey(name: 'tax_rate1') @Default('0') Object taxRate1,
    @JsonKey(name: 'tax_rate2') @Default('0') Object taxRate2,
    @JsonKey(name: 'tax_rate3') @Default('0') Object taxRate3,
    @JsonKey(name: 'uses_inclusive_taxes')
    @Default(false)
    bool usesInclusiveTaxes,
    @JsonKey(name: 'custom_surcharge1') @Default('0') Object customSurcharge1,
    @JsonKey(name: 'custom_surcharge2') @Default('0') Object customSurcharge2,
    @JsonKey(name: 'custom_surcharge3') @Default('0') Object customSurcharge3,
    @JsonKey(name: 'custom_surcharge4') @Default('0') Object customSurcharge4,
    @JsonKey(name: 'custom_surcharge_tax1') @Default(false) bool customTaxes1,
    @JsonKey(name: 'custom_surcharge_tax2') @Default(false) bool customTaxes2,
    @JsonKey(name: 'custom_surcharge_tax3') @Default(false) bool customTaxes3,
    @JsonKey(name: 'custom_surcharge_tax4') @Default(false) bool customTaxes4,
    @JsonKey(name: 'public_notes') @Default('') String publicNotes,
    @JsonKey(name: 'private_notes') @Default('') String privateNotes,
    @Default('') String terms,
    @Default('') String footer,
    @JsonKey(name: 'custom_value1') @Default('') String customValue1,
    @JsonKey(name: 'custom_value2') @Default('') String customValue2,
    @JsonKey(name: 'custom_value3') @Default('') String customValue3,
    @JsonKey(name: 'custom_value4') @Default('') String customValue4,
    @JsonKey(name: 'line_items')
    @Default(<LineItemApi>[])
    List<LineItemApi> lineItems,
    @Default(<InvitationApi>[]) List<InvitationApi> invitations,
    List<DocumentApi>? documents,
    @JsonKey(name: 'tags')
    @EmbeddedTagsConverter()
    @Default(<TagRefApi>[])
    List<TagRefApi> tags,
    @JsonKey(name: 'e_invoice') Map<String, dynamic>? eInvoice,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
  }) = _CreditApi;

  factory CreditApi.fromJson(Map<String, dynamic> json) =>
      _$CreditApiFromJson(json);
}

@freezed
abstract class CreditListApi with _$CreditListApi {
  const factory CreditListApi({
    @JsonKey(fromJson: _creditListData)
    @Default(<CreditApi>[])
    List<CreditApi> data,
  }) = _CreditListApi;

  factory CreditListApi.fromJson(Map<String, dynamic> json) =>
      _$CreditListApiFromJson(json);
}

@freezed
abstract class CreditItemApi with _$CreditItemApi {
  const factory CreditItemApi({required CreditApi data}) = _CreditItemApi;

  factory CreditItemApi.fromJson(Map<String, dynamic> json) =>
      _$CreditItemApiFromJson(json);
}

List<CreditApi> _creditListData(Object? raw) =>
    tolerantList(raw, CreditApi.fromJson, label: 'credit');
