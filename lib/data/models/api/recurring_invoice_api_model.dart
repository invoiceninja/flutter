import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/api/invitation_api_model.dart';
import 'package:admin/data/models/api/json_coercion.dart';
import 'package:admin/data/models/api/tag_api_model.dart';
import 'package:admin/data/models/api/line_item_api_model.dart';

part 'recurring_invoice_api_model.freezed.dart';
part 'recurring_invoice_api_model.g.dart';

/// Raw JSON shape of `/api/v1/recurring_invoices/{id}`.
///
/// Same field set as [InvoiceApi] but with a recurring-specific status
/// enum (Draft / Active / Paused / Completed) and the `start` / `stop`
/// actions in addition to the shared mark_sent / email / clone_to* /
/// run_template surface.
@freezed
abstract class RecurringInvoiceApi with _$RecurringInvoiceApi {
  const factory RecurringInvoiceApi({
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
    @JsonKey(name: 'subscription_id') @Default('') String subscriptionId,
    @Default('0') Object amount,
    @Default('0') Object balance,
    @JsonKey(name: 'total_taxes') @Default('0') Object totalTaxes,
    @Default('0') Object discount,
    @JsonKey(name: 'partial') @Default('0') Object partial,
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
    // Recurring-specific fields — required for this entity, optional on
    // invoices generated from it.
    @JsonKey(name: 'frequency_id') @Default('') String frequencyId,
    @JsonKey(name: 'next_send_date') @Default('') String nextSendDate,
    @JsonKey(name: 'next_send_datetime') @Default('') String nextSendDatetime,
    @JsonKey(name: 'last_sent_date') @Default('') String lastSentDate,
    @JsonKey(name: 'remaining_cycles') @Default(0) int remainingCycles,
    @JsonKey(name: 'due_date_days') @Default('') String dueDateDays,
    @JsonKey(name: 'auto_bill') @Default('') String autoBill,
    @JsonKey(name: 'auto_bill_enabled') @Default(false) bool autoBillEnabled,
    @JsonKey(name: 'e_invoice') Map<String, dynamic>? eInvoice,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
  }) = _RecurringInvoiceApi;

  factory RecurringInvoiceApi.fromJson(Map<String, dynamic> json) =>
      _$RecurringInvoiceApiFromJson(json);
}

@freezed
abstract class RecurringInvoiceListApi with _$RecurringInvoiceListApi {
  const factory RecurringInvoiceListApi({
    @JsonKey(fromJson: _recurringInvoiceListData)
    @Default(<RecurringInvoiceApi>[])
    List<RecurringInvoiceApi> data,
  }) = _RecurringInvoiceListApi;

  factory RecurringInvoiceListApi.fromJson(Map<String, dynamic> json) =>
      _$RecurringInvoiceListApiFromJson(json);
}

@freezed
abstract class RecurringInvoiceItemApi with _$RecurringInvoiceItemApi {
  const factory RecurringInvoiceItemApi({required RecurringInvoiceApi data}) =
      _RecurringInvoiceItemApi;

  factory RecurringInvoiceItemApi.fromJson(Map<String, dynamic> json) =>
      _$RecurringInvoiceItemApiFromJson(json);
}

List<RecurringInvoiceApi> _recurringInvoiceListData(Object? raw) =>
    tolerantList(raw, RecurringInvoiceApi.fromJson, label: 'recurring_invoice');
