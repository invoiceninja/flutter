import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/api/invitation_api_model.dart';
import 'package:admin/data/models/api/json_coercion.dart';
import 'package:admin/data/models/api/tag_api_model.dart';
import 'package:admin/data/models/api/line_item_api_model.dart';
import 'package:admin/data/models/api/schedule_item_api_model.dart';

part 'invoice_api_model.freezed.dart';
part 'invoice_api_model.g.dart';

/// Raw JSON shape of `/api/v1/invoices/{id}`.
///
/// Money fields stay as `Object` (the server flips between number and
/// string) and get parsed via `parseMoney` in [Invoice.fromApi]. Dates are
/// raw `YYYY-MM-DD` strings; the domain factory lifts them via
/// `Date.tryParse`.
///
/// `e_invoice` + `backup` are typed as `Map<String, dynamic>?` for v1 —
/// the PEPPOL UBL / Verifactu shapes are open-ended and stay as raw JSON
/// until the UI needs typed accessors. Recurring fields (`frequency_id`,
/// `next_send_date`, etc.) live on every invoice payload because invoices
/// generated from recurring templates carry the linkage; `RecurringInvoice`
/// will reuse this same envelope.
@freezed
abstract class InvoiceApi with _$InvoiceApi {
  const factory InvoiceApi({
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
    // Parent invoice for a quote/credit/PO linkage (admin-portal calls
    // this `invoice_id` on quotes/credits to point at the resulting
    // invoice when a conversion happens). Empty by default.
    @JsonKey(name: 'invoice_id') @Default('') String parentInvoiceId,
    @JsonKey(name: 'recurring_id') @Default('') String recurringId,
    // Money
    @Default('0') Object amount,
    @Default('0') Object balance,
    @JsonKey(name: 'paid_to_date') @Default('0') Object paidToDate,
    @JsonKey(name: 'total_taxes') @Default('0') Object totalTaxes,
    @Default('0') Object discount,
    @JsonKey(name: 'partial') @Default('0') Object partial,
    @JsonKey(name: 'is_amount_discount') @Default(false) bool isAmountDiscount,
    @JsonKey(name: 'exchange_rate') @Default('1') Object exchangeRate,
    // Tax
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
    // Notes + content
    @JsonKey(name: 'public_notes') @Default('') String publicNotes,
    @JsonKey(name: 'private_notes') @Default('') String privateNotes,
    @Default('') String terms,
    @Default('') String footer,
    @JsonKey(name: 'custom_value1') @Default('') String customValue1,
    @JsonKey(name: 'custom_value2') @Default('') String customValue2,
    @JsonKey(name: 'custom_value3') @Default('') String customValue3,
    @JsonKey(name: 'custom_value4') @Default('') String customValue4,
    // Nested arrays
    @JsonKey(name: 'line_items')
    @Default(<LineItemApi>[])
    List<LineItemApi> lineItems,
    @Default(<InvitationApi>[]) List<InvitationApi> invitations,
    // Nullable — `documents` only present when `?include=documents` was
    // sent; same convention as ClientApi/ExpenseApi.
    List<DocumentApi>? documents,
    @JsonKey(name: 'tags')
    @EmbeddedTagsConverter()
    @Default(<TagRefApi>[])
    List<TagRefApi> tags,
    // Reminder timestamps
    @JsonKey(name: 'reminder1_sent') @Default('') String reminder1Sent,
    @JsonKey(name: 'reminder2_sent') @Default('') String reminder2Sent,
    @JsonKey(name: 'reminder3_sent') @Default('') String reminder3Sent,
    @JsonKey(name: 'reminder_last_sent') @Default('') String reminderLastSent,
    @JsonKey(name: 'reminder_schedule') @Default('') String reminderSchedule,
    // Recurring + auto-bill (relevant for RecurringInvoice but carried
    // on every invoice so the field shape stays consistent)
    @JsonKey(name: 'frequency_id') @Default('') String frequencyId,
    @JsonKey(name: 'next_send_date') @Default('') String nextSendDate,
    @JsonKey(name: 'next_send_datetime') @Default('') String nextSendDatetime,
    @JsonKey(name: 'last_sent_date') @Default('') String lastSentDate,
    @JsonKey(name: 'remaining_cycles') @Default(0) int remainingCycles,
    @JsonKey(name: 'due_date_days') @Default('') String dueDateDays,
    @JsonKey(name: 'auto_bill') @Default('') String autoBill,
    @JsonKey(name: 'auto_bill_enabled') @Default(false) bool autoBillEnabled,
    // E-invoice / Verifactu — open-ended typed-deferred maps
    @JsonKey(name: 'e_invoice') Map<String, dynamic>? eInvoice,
    @JsonKey(name: 'backup') Map<String, dynamic>? backup,
    @JsonKey(name: 'tax_info') Map<String, dynamic>? taxInfo,
    // Rectification (Verifactu "factura rectificativa"): id of the original
    // invoice this one corrects + the user-supplied rectification reason.
    @JsonKey(name: 'modified_invoice_id') String? modifiedInvoiceId,
    @JsonKey(name: 'reason') String? reason,
    // Read-only payment-schedule projection. Present ONLY when the invoice
    // is fetched with `?show_schedule=true` (probe-verified: absent on
    // plain/list GETs). Nullable for the same reason as `documents` — the
    // repo's `_apiToCompanion` must distinguish "key absent → preserve the
    // stored column" from "present → authoritative". Persisted to a
    // dedicated Drift column; `Invoice.toApiJson` omits it (read-only).
    @JsonKey(name: 'schedule') List<ScheduleItemApi>? schedule,
    // Flags
    @JsonKey(name: 'is_locked') @Default(false) bool isLocked,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
    // Timestamps
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
  }) = _InvoiceApi;

  factory InvoiceApi.fromJson(Map<String, dynamic> json) =>
      _$InvoiceApiFromJson(json);
}

/// `GET /invoices` list envelope.
@freezed
abstract class InvoiceListApi with _$InvoiceListApi {
  const factory InvoiceListApi({
    @JsonKey(fromJson: _invoiceListData)
    @Default(<InvoiceApi>[])
    List<InvoiceApi> data,
  }) = _InvoiceListApi;

  factory InvoiceListApi.fromJson(Map<String, dynamic> json) =>
      _$InvoiceListApiFromJson(json);
}

/// `POST/PUT /invoices/{id}` single-item envelope.
@freezed
abstract class InvoiceItemApi with _$InvoiceItemApi {
  const factory InvoiceItemApi({required InvoiceApi data}) = _InvoiceItemApi;

  factory InvoiceItemApi.fromJson(Map<String, dynamic> json) =>
      _$InvoiceItemApiFromJson(json);
}

List<InvoiceApi> _invoiceListData(Object? raw) =>
    tolerantList(raw, InvoiceApi.fromJson, label: 'invoice');
