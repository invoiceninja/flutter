import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/api/invitation_api_model.dart';
import 'package:admin/data/models/api/json_coercion.dart';
import 'package:admin/data/models/api/tag_api_model.dart';
import 'package:admin/data/models/api/line_item_api_model.dart';

part 'quote_api_model.freezed.dart';
part 'quote_api_model.g.dart';

/// Raw JSON shape of `/api/v1/quotes/{id}`.
///
/// Identical to [InvoiceApi] in shape — quotes share line items,
/// invitations, taxes, surcharges, custom fields, design, exchange rate,
/// and the deposit (`partial` / `partial_due_date`). The differences live
/// in the *status enum* and the payment-side fields quotes don't carry
/// (`paid_to_date`, recurring linkage). Including those as `@Default` here
/// would also work — the server tolerates extras — but we drop them to
/// keep the wire shape lean.
@freezed
abstract class QuoteApi with _$QuoteApi {
  const factory QuoteApi({
    @Default('') String id,
    @Default('') String number,
    @JsonKey(name: 'po_number') @Default('') String poNumber,
    @Default('') String date,
    @JsonKey(name: 'due_date') @Default('') String dueDate,
    @JsonKey(name: 'partial_due_date') @Default('') String partialDueDate,
    // Server-computed, read-only (display only — never sent back).
    @JsonKey(name: 'last_sent_date') @Default('') String lastSentDate,
    @JsonKey(name: 'next_send_date') @Default('') String nextSendDate,
    @JsonKey(name: 'status_id') @Default('1') String statusId,
    @JsonKey(name: 'client_id') @Default('') String clientId,
    @JsonKey(name: 'vendor_id') @Default('') String vendorId,
    @JsonKey(name: 'project_id') @Default('') String projectId,
    @JsonKey(name: 'design_id') @Default('') String designId,
    @JsonKey(name: 'assigned_user_id') @Default('') String assignedUserId,
    @JsonKey(name: 'user_id') @Default('') String userId,
    @JsonKey(name: 'location_id') @Default('') String locationId,
    @JsonKey(name: 'subscription_id') @Default('') String subscriptionId,
    // The invoice this quote converted to (when status = converted).
    @JsonKey(name: 'invoice_id') @Default('') String invoiceId,
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
    @JsonKey(name: 'e_invoice') Map<String, dynamic>? eInvoice,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
  }) = _QuoteApi;

  factory QuoteApi.fromJson(Map<String, dynamic> json) =>
      _$QuoteApiFromJson(json);
}

@freezed
abstract class QuoteListApi with _$QuoteListApi {
  const factory QuoteListApi({
    @JsonKey(fromJson: _quoteListData)
    @Default(<QuoteApi>[])
    List<QuoteApi> data,
  }) = _QuoteListApi;

  factory QuoteListApi.fromJson(Map<String, dynamic> json) =>
      _$QuoteListApiFromJson(json);
}

@freezed
abstract class QuoteItemApi with _$QuoteItemApi {
  const factory QuoteItemApi({required QuoteApi data}) = _QuoteItemApi;

  factory QuoteItemApi.fromJson(Map<String, dynamic> json) =>
      _$QuoteItemApiFromJson(json);
}

List<QuoteApi> _quoteListData(Object? raw) =>
    tolerantList(raw, QuoteApi.fromJson, label: 'quote');
