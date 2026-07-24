// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'invoice_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$InvoiceApi {

 String get id; String get number;@JsonKey(name: 'po_number') String get poNumber; String get date;@JsonKey(name: 'due_date') String get dueDate;@JsonKey(name: 'partial_due_date') String get partialDueDate;@JsonKey(name: 'status_id') String get statusId;@JsonKey(name: 'client_id') String get clientId;@JsonKey(name: 'vendor_id') String get vendorId;@JsonKey(name: 'project_id') String get projectId;@JsonKey(name: 'design_id') String get designId;@JsonKey(name: 'assigned_user_id') String get assignedUserId;@JsonKey(name: 'user_id') String get userId;@JsonKey(name: 'location_id') String get locationId;@JsonKey(name: 'subscription_id') String get subscriptionId;// Parent invoice for a quote/credit/PO linkage (admin-portal calls
// this `invoice_id` on quotes/credits to point at the resulting
// invoice when a conversion happens). Empty by default.
@JsonKey(name: 'invoice_id') String get parentInvoiceId;@JsonKey(name: 'recurring_id') String get recurringId;// Money
 Object get amount; Object get balance;@JsonKey(name: 'paid_to_date') Object get paidToDate;@JsonKey(name: 'total_taxes') Object get totalTaxes; Object get discount;@JsonKey(name: 'partial') Object get partial;@JsonKey(name: 'is_amount_discount') bool get isAmountDiscount;@JsonKey(name: 'exchange_rate') Object get exchangeRate;// Tax
@JsonKey(name: 'tax_name1') String get taxName1;@JsonKey(name: 'tax_name2') String get taxName2;@JsonKey(name: 'tax_name3') String get taxName3;@JsonKey(name: 'tax_rate1') Object get taxRate1;@JsonKey(name: 'tax_rate2') Object get taxRate2;@JsonKey(name: 'tax_rate3') Object get taxRate3;@JsonKey(name: 'uses_inclusive_taxes') bool get usesInclusiveTaxes;@JsonKey(name: 'custom_surcharge1') Object get customSurcharge1;@JsonKey(name: 'custom_surcharge2') Object get customSurcharge2;@JsonKey(name: 'custom_surcharge3') Object get customSurcharge3;@JsonKey(name: 'custom_surcharge4') Object get customSurcharge4;@JsonKey(name: 'custom_surcharge_tax1') bool get customTaxes1;@JsonKey(name: 'custom_surcharge_tax2') bool get customTaxes2;@JsonKey(name: 'custom_surcharge_tax3') bool get customTaxes3;@JsonKey(name: 'custom_surcharge_tax4') bool get customTaxes4;// Notes + content
@JsonKey(name: 'public_notes') String get publicNotes;@JsonKey(name: 'private_notes') String get privateNotes; String get terms; String get footer;@JsonKey(name: 'custom_value1') String get customValue1;@JsonKey(name: 'custom_value2') String get customValue2;@JsonKey(name: 'custom_value3') String get customValue3;@JsonKey(name: 'custom_value4') String get customValue4;// Nested arrays
@JsonKey(name: 'line_items') List<LineItemApi> get lineItems; List<InvitationApi> get invitations;// Nullable — `documents` only present when `?include=documents` was
// sent; same convention as ClientApi/ExpenseApi.
 List<DocumentApi>? get documents;@JsonKey(name: 'tags')@EmbeddedTagsConverter() List<TagRefApi> get tags;// Reminder timestamps
@JsonKey(name: 'reminder1_sent') String get reminder1Sent;@JsonKey(name: 'reminder2_sent') String get reminder2Sent;@JsonKey(name: 'reminder3_sent') String get reminder3Sent;@JsonKey(name: 'reminder_last_sent') String get reminderLastSent;@JsonKey(name: 'reminder_schedule') String get reminderSchedule;// Recurring + auto-bill (relevant for RecurringInvoice but carried
// on every invoice so the field shape stays consistent)
@JsonKey(name: 'frequency_id') String get frequencyId;@JsonKey(name: 'next_send_date') String get nextSendDate;@JsonKey(name: 'next_send_datetime') String get nextSendDatetime;@JsonKey(name: 'last_sent_date') String get lastSentDate;@JsonKey(name: 'remaining_cycles') int get remainingCycles;@JsonKey(name: 'due_date_days') String get dueDateDays;@JsonKey(name: 'auto_bill') String get autoBill;@JsonKey(name: 'auto_bill_enabled') bool get autoBillEnabled;// E-invoice / Verifactu — open-ended typed-deferred maps
@JsonKey(name: 'e_invoice') Map<String, dynamic>? get eInvoice;@JsonKey(name: 'backup') Map<String, dynamic>? get backup;@JsonKey(name: 'tax_info') Map<String, dynamic>? get taxInfo;// Rectification (Verifactu "factura rectificativa"): id of the original
// invoice this one corrects + the user-supplied rectification reason.
@JsonKey(name: 'modified_invoice_id') String? get modifiedInvoiceId;@JsonKey(name: 'reason') String? get reason;// Read-only payment-schedule projection. Present ONLY when the invoice
// is fetched with `?show_schedule=true` (probe-verified: absent on
// plain/list GETs). Nullable for the same reason as `documents` — the
// repo's `_apiToCompanion` must distinguish "key absent → preserve the
// stored column" from "present → authoritative". Persisted to a
// dedicated Drift column; `Invoice.toApiJson` omits it (read-only).
@JsonKey(name: 'schedule') List<ScheduleItemApi>? get schedule;// Flags
@JsonKey(name: 'is_locked') bool get isLocked;@JsonKey(name: 'is_deleted') bool get isDeleted;// Timestamps
@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt;
/// Create a copy of InvoiceApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InvoiceApiCopyWith<InvoiceApi> get copyWith => _$InvoiceApiCopyWithImpl<InvoiceApi>(this as InvoiceApi, _$identity);

  /// Serializes this InvoiceApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InvoiceApi&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.poNumber, poNumber) || other.poNumber == poNumber)&&(identical(other.date, date) || other.date == date)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.partialDueDate, partialDueDate) || other.partialDueDate == partialDueDate)&&(identical(other.statusId, statusId) || other.statusId == statusId)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.vendorId, vendorId) || other.vendorId == vendorId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.designId, designId) || other.designId == designId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.locationId, locationId) || other.locationId == locationId)&&(identical(other.subscriptionId, subscriptionId) || other.subscriptionId == subscriptionId)&&(identical(other.parentInvoiceId, parentInvoiceId) || other.parentInvoiceId == parentInvoiceId)&&(identical(other.recurringId, recurringId) || other.recurringId == recurringId)&&const DeepCollectionEquality().equals(other.amount, amount)&&const DeepCollectionEquality().equals(other.balance, balance)&&const DeepCollectionEquality().equals(other.paidToDate, paidToDate)&&const DeepCollectionEquality().equals(other.totalTaxes, totalTaxes)&&const DeepCollectionEquality().equals(other.discount, discount)&&const DeepCollectionEquality().equals(other.partial, partial)&&(identical(other.isAmountDiscount, isAmountDiscount) || other.isAmountDiscount == isAmountDiscount)&&const DeepCollectionEquality().equals(other.exchangeRate, exchangeRate)&&(identical(other.taxName1, taxName1) || other.taxName1 == taxName1)&&(identical(other.taxName2, taxName2) || other.taxName2 == taxName2)&&(identical(other.taxName3, taxName3) || other.taxName3 == taxName3)&&const DeepCollectionEquality().equals(other.taxRate1, taxRate1)&&const DeepCollectionEquality().equals(other.taxRate2, taxRate2)&&const DeepCollectionEquality().equals(other.taxRate3, taxRate3)&&(identical(other.usesInclusiveTaxes, usesInclusiveTaxes) || other.usesInclusiveTaxes == usesInclusiveTaxes)&&const DeepCollectionEquality().equals(other.customSurcharge1, customSurcharge1)&&const DeepCollectionEquality().equals(other.customSurcharge2, customSurcharge2)&&const DeepCollectionEquality().equals(other.customSurcharge3, customSurcharge3)&&const DeepCollectionEquality().equals(other.customSurcharge4, customSurcharge4)&&(identical(other.customTaxes1, customTaxes1) || other.customTaxes1 == customTaxes1)&&(identical(other.customTaxes2, customTaxes2) || other.customTaxes2 == customTaxes2)&&(identical(other.customTaxes3, customTaxes3) || other.customTaxes3 == customTaxes3)&&(identical(other.customTaxes4, customTaxes4) || other.customTaxes4 == customTaxes4)&&(identical(other.publicNotes, publicNotes) || other.publicNotes == publicNotes)&&(identical(other.privateNotes, privateNotes) || other.privateNotes == privateNotes)&&(identical(other.terms, terms) || other.terms == terms)&&(identical(other.footer, footer) || other.footer == footer)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&const DeepCollectionEquality().equals(other.lineItems, lineItems)&&const DeepCollectionEquality().equals(other.invitations, invitations)&&const DeepCollectionEquality().equals(other.documents, documents)&&const DeepCollectionEquality().equals(other.tags, tags)&&(identical(other.reminder1Sent, reminder1Sent) || other.reminder1Sent == reminder1Sent)&&(identical(other.reminder2Sent, reminder2Sent) || other.reminder2Sent == reminder2Sent)&&(identical(other.reminder3Sent, reminder3Sent) || other.reminder3Sent == reminder3Sent)&&(identical(other.reminderLastSent, reminderLastSent) || other.reminderLastSent == reminderLastSent)&&(identical(other.reminderSchedule, reminderSchedule) || other.reminderSchedule == reminderSchedule)&&(identical(other.frequencyId, frequencyId) || other.frequencyId == frequencyId)&&(identical(other.nextSendDate, nextSendDate) || other.nextSendDate == nextSendDate)&&(identical(other.nextSendDatetime, nextSendDatetime) || other.nextSendDatetime == nextSendDatetime)&&(identical(other.lastSentDate, lastSentDate) || other.lastSentDate == lastSentDate)&&(identical(other.remainingCycles, remainingCycles) || other.remainingCycles == remainingCycles)&&(identical(other.dueDateDays, dueDateDays) || other.dueDateDays == dueDateDays)&&(identical(other.autoBill, autoBill) || other.autoBill == autoBill)&&(identical(other.autoBillEnabled, autoBillEnabled) || other.autoBillEnabled == autoBillEnabled)&&const DeepCollectionEquality().equals(other.eInvoice, eInvoice)&&const DeepCollectionEquality().equals(other.backup, backup)&&const DeepCollectionEquality().equals(other.taxInfo, taxInfo)&&(identical(other.modifiedInvoiceId, modifiedInvoiceId) || other.modifiedInvoiceId == modifiedInvoiceId)&&(identical(other.reason, reason) || other.reason == reason)&&const DeepCollectionEquality().equals(other.schedule, schedule)&&(identical(other.isLocked, isLocked) || other.isLocked == isLocked)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,number,poNumber,date,dueDate,partialDueDate,statusId,clientId,vendorId,projectId,designId,assignedUserId,userId,locationId,subscriptionId,parentInvoiceId,recurringId,const DeepCollectionEquality().hash(amount),const DeepCollectionEquality().hash(balance),const DeepCollectionEquality().hash(paidToDate),const DeepCollectionEquality().hash(totalTaxes),const DeepCollectionEquality().hash(discount),const DeepCollectionEquality().hash(partial),isAmountDiscount,const DeepCollectionEquality().hash(exchangeRate),taxName1,taxName2,taxName3,const DeepCollectionEquality().hash(taxRate1),const DeepCollectionEquality().hash(taxRate2),const DeepCollectionEquality().hash(taxRate3),usesInclusiveTaxes,const DeepCollectionEquality().hash(customSurcharge1),const DeepCollectionEquality().hash(customSurcharge2),const DeepCollectionEquality().hash(customSurcharge3),const DeepCollectionEquality().hash(customSurcharge4),customTaxes1,customTaxes2,customTaxes3,customTaxes4,publicNotes,privateNotes,terms,footer,customValue1,customValue2,customValue3,customValue4,const DeepCollectionEquality().hash(lineItems),const DeepCollectionEquality().hash(invitations),const DeepCollectionEquality().hash(documents),const DeepCollectionEquality().hash(tags),reminder1Sent,reminder2Sent,reminder3Sent,reminderLastSent,reminderSchedule,frequencyId,nextSendDate,nextSendDatetime,lastSentDate,remainingCycles,dueDateDays,autoBill,autoBillEnabled,const DeepCollectionEquality().hash(eInvoice),const DeepCollectionEquality().hash(backup),const DeepCollectionEquality().hash(taxInfo),modifiedInvoiceId,reason,const DeepCollectionEquality().hash(schedule),isLocked,isDeleted,createdAt,updatedAt,archivedAt]);

@override
String toString() {
  return 'InvoiceApi(id: $id, number: $number, poNumber: $poNumber, date: $date, dueDate: $dueDate, partialDueDate: $partialDueDate, statusId: $statusId, clientId: $clientId, vendorId: $vendorId, projectId: $projectId, designId: $designId, assignedUserId: $assignedUserId, userId: $userId, locationId: $locationId, subscriptionId: $subscriptionId, parentInvoiceId: $parentInvoiceId, recurringId: $recurringId, amount: $amount, balance: $balance, paidToDate: $paidToDate, totalTaxes: $totalTaxes, discount: $discount, partial: $partial, isAmountDiscount: $isAmountDiscount, exchangeRate: $exchangeRate, taxName1: $taxName1, taxName2: $taxName2, taxName3: $taxName3, taxRate1: $taxRate1, taxRate2: $taxRate2, taxRate3: $taxRate3, usesInclusiveTaxes: $usesInclusiveTaxes, customSurcharge1: $customSurcharge1, customSurcharge2: $customSurcharge2, customSurcharge3: $customSurcharge3, customSurcharge4: $customSurcharge4, customTaxes1: $customTaxes1, customTaxes2: $customTaxes2, customTaxes3: $customTaxes3, customTaxes4: $customTaxes4, publicNotes: $publicNotes, privateNotes: $privateNotes, terms: $terms, footer: $footer, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, lineItems: $lineItems, invitations: $invitations, documents: $documents, tags: $tags, reminder1Sent: $reminder1Sent, reminder2Sent: $reminder2Sent, reminder3Sent: $reminder3Sent, reminderLastSent: $reminderLastSent, reminderSchedule: $reminderSchedule, frequencyId: $frequencyId, nextSendDate: $nextSendDate, nextSendDatetime: $nextSendDatetime, lastSentDate: $lastSentDate, remainingCycles: $remainingCycles, dueDateDays: $dueDateDays, autoBill: $autoBill, autoBillEnabled: $autoBillEnabled, eInvoice: $eInvoice, backup: $backup, taxInfo: $taxInfo, modifiedInvoiceId: $modifiedInvoiceId, reason: $reason, schedule: $schedule, isLocked: $isLocked, isDeleted: $isDeleted, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt)';
}


}

/// @nodoc
abstract mixin class $InvoiceApiCopyWith<$Res>  {
  factory $InvoiceApiCopyWith(InvoiceApi value, $Res Function(InvoiceApi) _then) = _$InvoiceApiCopyWithImpl;
@useResult
$Res call({
 String id, String number,@JsonKey(name: 'po_number') String poNumber, String date,@JsonKey(name: 'due_date') String dueDate,@JsonKey(name: 'partial_due_date') String partialDueDate,@JsonKey(name: 'status_id') String statusId,@JsonKey(name: 'client_id') String clientId,@JsonKey(name: 'vendor_id') String vendorId,@JsonKey(name: 'project_id') String projectId,@JsonKey(name: 'design_id') String designId,@JsonKey(name: 'assigned_user_id') String assignedUserId,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'location_id') String locationId,@JsonKey(name: 'subscription_id') String subscriptionId,@JsonKey(name: 'invoice_id') String parentInvoiceId,@JsonKey(name: 'recurring_id') String recurringId, Object amount, Object balance,@JsonKey(name: 'paid_to_date') Object paidToDate,@JsonKey(name: 'total_taxes') Object totalTaxes, Object discount,@JsonKey(name: 'partial') Object partial,@JsonKey(name: 'is_amount_discount') bool isAmountDiscount,@JsonKey(name: 'exchange_rate') Object exchangeRate,@JsonKey(name: 'tax_name1') String taxName1,@JsonKey(name: 'tax_name2') String taxName2,@JsonKey(name: 'tax_name3') String taxName3,@JsonKey(name: 'tax_rate1') Object taxRate1,@JsonKey(name: 'tax_rate2') Object taxRate2,@JsonKey(name: 'tax_rate3') Object taxRate3,@JsonKey(name: 'uses_inclusive_taxes') bool usesInclusiveTaxes,@JsonKey(name: 'custom_surcharge1') Object customSurcharge1,@JsonKey(name: 'custom_surcharge2') Object customSurcharge2,@JsonKey(name: 'custom_surcharge3') Object customSurcharge3,@JsonKey(name: 'custom_surcharge4') Object customSurcharge4,@JsonKey(name: 'custom_surcharge_tax1') bool customTaxes1,@JsonKey(name: 'custom_surcharge_tax2') bool customTaxes2,@JsonKey(name: 'custom_surcharge_tax3') bool customTaxes3,@JsonKey(name: 'custom_surcharge_tax4') bool customTaxes4,@JsonKey(name: 'public_notes') String publicNotes,@JsonKey(name: 'private_notes') String privateNotes, String terms, String footer,@JsonKey(name: 'custom_value1') String customValue1,@JsonKey(name: 'custom_value2') String customValue2,@JsonKey(name: 'custom_value3') String customValue3,@JsonKey(name: 'custom_value4') String customValue4,@JsonKey(name: 'line_items') List<LineItemApi> lineItems, List<InvitationApi> invitations, List<DocumentApi>? documents,@JsonKey(name: 'tags')@EmbeddedTagsConverter() List<TagRefApi> tags,@JsonKey(name: 'reminder1_sent') String reminder1Sent,@JsonKey(name: 'reminder2_sent') String reminder2Sent,@JsonKey(name: 'reminder3_sent') String reminder3Sent,@JsonKey(name: 'reminder_last_sent') String reminderLastSent,@JsonKey(name: 'reminder_schedule') String reminderSchedule,@JsonKey(name: 'frequency_id') String frequencyId,@JsonKey(name: 'next_send_date') String nextSendDate,@JsonKey(name: 'next_send_datetime') String nextSendDatetime,@JsonKey(name: 'last_sent_date') String lastSentDate,@JsonKey(name: 'remaining_cycles') int remainingCycles,@JsonKey(name: 'due_date_days') String dueDateDays,@JsonKey(name: 'auto_bill') String autoBill,@JsonKey(name: 'auto_bill_enabled') bool autoBillEnabled,@JsonKey(name: 'e_invoice') Map<String, dynamic>? eInvoice,@JsonKey(name: 'backup') Map<String, dynamic>? backup,@JsonKey(name: 'tax_info') Map<String, dynamic>? taxInfo,@JsonKey(name: 'modified_invoice_id') String? modifiedInvoiceId,@JsonKey(name: 'reason') String? reason,@JsonKey(name: 'schedule') List<ScheduleItemApi>? schedule,@JsonKey(name: 'is_locked') bool isLocked,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt
});




}
/// @nodoc
class _$InvoiceApiCopyWithImpl<$Res>
    implements $InvoiceApiCopyWith<$Res> {
  _$InvoiceApiCopyWithImpl(this._self, this._then);

  final InvoiceApi _self;
  final $Res Function(InvoiceApi) _then;

/// Create a copy of InvoiceApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? number = null,Object? poNumber = null,Object? date = null,Object? dueDate = null,Object? partialDueDate = null,Object? statusId = null,Object? clientId = null,Object? vendorId = null,Object? projectId = null,Object? designId = null,Object? assignedUserId = null,Object? userId = null,Object? locationId = null,Object? subscriptionId = null,Object? parentInvoiceId = null,Object? recurringId = null,Object? amount = null,Object? balance = null,Object? paidToDate = null,Object? totalTaxes = null,Object? discount = null,Object? partial = null,Object? isAmountDiscount = null,Object? exchangeRate = null,Object? taxName1 = null,Object? taxName2 = null,Object? taxName3 = null,Object? taxRate1 = null,Object? taxRate2 = null,Object? taxRate3 = null,Object? usesInclusiveTaxes = null,Object? customSurcharge1 = null,Object? customSurcharge2 = null,Object? customSurcharge3 = null,Object? customSurcharge4 = null,Object? customTaxes1 = null,Object? customTaxes2 = null,Object? customTaxes3 = null,Object? customTaxes4 = null,Object? publicNotes = null,Object? privateNotes = null,Object? terms = null,Object? footer = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? lineItems = null,Object? invitations = null,Object? documents = freezed,Object? tags = null,Object? reminder1Sent = null,Object? reminder2Sent = null,Object? reminder3Sent = null,Object? reminderLastSent = null,Object? reminderSchedule = null,Object? frequencyId = null,Object? nextSendDate = null,Object? nextSendDatetime = null,Object? lastSentDate = null,Object? remainingCycles = null,Object? dueDateDays = null,Object? autoBill = null,Object? autoBillEnabled = null,Object? eInvoice = freezed,Object? backup = freezed,Object? taxInfo = freezed,Object? modifiedInvoiceId = freezed,Object? reason = freezed,Object? schedule = freezed,Object? isLocked = null,Object? isDeleted = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,poNumber: null == poNumber ? _self.poNumber : poNumber // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,dueDate: null == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as String,partialDueDate: null == partialDueDate ? _self.partialDueDate : partialDueDate // ignore: cast_nullable_to_non_nullable
as String,statusId: null == statusId ? _self.statusId : statusId // ignore: cast_nullable_to_non_nullable
as String,clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,vendorId: null == vendorId ? _self.vendorId : vendorId // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,designId: null == designId ? _self.designId : designId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,locationId: null == locationId ? _self.locationId : locationId // ignore: cast_nullable_to_non_nullable
as String,subscriptionId: null == subscriptionId ? _self.subscriptionId : subscriptionId // ignore: cast_nullable_to_non_nullable
as String,parentInvoiceId: null == parentInvoiceId ? _self.parentInvoiceId : parentInvoiceId // ignore: cast_nullable_to_non_nullable
as String,recurringId: null == recurringId ? _self.recurringId : recurringId // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount ,balance: null == balance ? _self.balance : balance ,paidToDate: null == paidToDate ? _self.paidToDate : paidToDate ,totalTaxes: null == totalTaxes ? _self.totalTaxes : totalTaxes ,discount: null == discount ? _self.discount : discount ,partial: null == partial ? _self.partial : partial ,isAmountDiscount: null == isAmountDiscount ? _self.isAmountDiscount : isAmountDiscount // ignore: cast_nullable_to_non_nullable
as bool,exchangeRate: null == exchangeRate ? _self.exchangeRate : exchangeRate ,taxName1: null == taxName1 ? _self.taxName1 : taxName1 // ignore: cast_nullable_to_non_nullable
as String,taxName2: null == taxName2 ? _self.taxName2 : taxName2 // ignore: cast_nullable_to_non_nullable
as String,taxName3: null == taxName3 ? _self.taxName3 : taxName3 // ignore: cast_nullable_to_non_nullable
as String,taxRate1: null == taxRate1 ? _self.taxRate1 : taxRate1 ,taxRate2: null == taxRate2 ? _self.taxRate2 : taxRate2 ,taxRate3: null == taxRate3 ? _self.taxRate3 : taxRate3 ,usesInclusiveTaxes: null == usesInclusiveTaxes ? _self.usesInclusiveTaxes : usesInclusiveTaxes // ignore: cast_nullable_to_non_nullable
as bool,customSurcharge1: null == customSurcharge1 ? _self.customSurcharge1 : customSurcharge1 ,customSurcharge2: null == customSurcharge2 ? _self.customSurcharge2 : customSurcharge2 ,customSurcharge3: null == customSurcharge3 ? _self.customSurcharge3 : customSurcharge3 ,customSurcharge4: null == customSurcharge4 ? _self.customSurcharge4 : customSurcharge4 ,customTaxes1: null == customTaxes1 ? _self.customTaxes1 : customTaxes1 // ignore: cast_nullable_to_non_nullable
as bool,customTaxes2: null == customTaxes2 ? _self.customTaxes2 : customTaxes2 // ignore: cast_nullable_to_non_nullable
as bool,customTaxes3: null == customTaxes3 ? _self.customTaxes3 : customTaxes3 // ignore: cast_nullable_to_non_nullable
as bool,customTaxes4: null == customTaxes4 ? _self.customTaxes4 : customTaxes4 // ignore: cast_nullable_to_non_nullable
as bool,publicNotes: null == publicNotes ? _self.publicNotes : publicNotes // ignore: cast_nullable_to_non_nullable
as String,privateNotes: null == privateNotes ? _self.privateNotes : privateNotes // ignore: cast_nullable_to_non_nullable
as String,terms: null == terms ? _self.terms : terms // ignore: cast_nullable_to_non_nullable
as String,footer: null == footer ? _self.footer : footer // ignore: cast_nullable_to_non_nullable
as String,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,lineItems: null == lineItems ? _self.lineItems : lineItems // ignore: cast_nullable_to_non_nullable
as List<LineItemApi>,invitations: null == invitations ? _self.invitations : invitations // ignore: cast_nullable_to_non_nullable
as List<InvitationApi>,documents: freezed == documents ? _self.documents : documents // ignore: cast_nullable_to_non_nullable
as List<DocumentApi>?,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagRefApi>,reminder1Sent: null == reminder1Sent ? _self.reminder1Sent : reminder1Sent // ignore: cast_nullable_to_non_nullable
as String,reminder2Sent: null == reminder2Sent ? _self.reminder2Sent : reminder2Sent // ignore: cast_nullable_to_non_nullable
as String,reminder3Sent: null == reminder3Sent ? _self.reminder3Sent : reminder3Sent // ignore: cast_nullable_to_non_nullable
as String,reminderLastSent: null == reminderLastSent ? _self.reminderLastSent : reminderLastSent // ignore: cast_nullable_to_non_nullable
as String,reminderSchedule: null == reminderSchedule ? _self.reminderSchedule : reminderSchedule // ignore: cast_nullable_to_non_nullable
as String,frequencyId: null == frequencyId ? _self.frequencyId : frequencyId // ignore: cast_nullable_to_non_nullable
as String,nextSendDate: null == nextSendDate ? _self.nextSendDate : nextSendDate // ignore: cast_nullable_to_non_nullable
as String,nextSendDatetime: null == nextSendDatetime ? _self.nextSendDatetime : nextSendDatetime // ignore: cast_nullable_to_non_nullable
as String,lastSentDate: null == lastSentDate ? _self.lastSentDate : lastSentDate // ignore: cast_nullable_to_non_nullable
as String,remainingCycles: null == remainingCycles ? _self.remainingCycles : remainingCycles // ignore: cast_nullable_to_non_nullable
as int,dueDateDays: null == dueDateDays ? _self.dueDateDays : dueDateDays // ignore: cast_nullable_to_non_nullable
as String,autoBill: null == autoBill ? _self.autoBill : autoBill // ignore: cast_nullable_to_non_nullable
as String,autoBillEnabled: null == autoBillEnabled ? _self.autoBillEnabled : autoBillEnabled // ignore: cast_nullable_to_non_nullable
as bool,eInvoice: freezed == eInvoice ? _self.eInvoice : eInvoice // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,backup: freezed == backup ? _self.backup : backup // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,taxInfo: freezed == taxInfo ? _self.taxInfo : taxInfo // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,modifiedInvoiceId: freezed == modifiedInvoiceId ? _self.modifiedInvoiceId : modifiedInvoiceId // ignore: cast_nullable_to_non_nullable
as String?,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,schedule: freezed == schedule ? _self.schedule : schedule // ignore: cast_nullable_to_non_nullable
as List<ScheduleItemApi>?,isLocked: null == isLocked ? _self.isLocked : isLocked // ignore: cast_nullable_to_non_nullable
as bool,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [InvoiceApi].
extension InvoiceApiPatterns on InvoiceApi {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InvoiceApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InvoiceApi() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InvoiceApi value)  $default,){
final _that = this;
switch (_that) {
case _InvoiceApi():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InvoiceApi value)?  $default,){
final _that = this;
switch (_that) {
case _InvoiceApi() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String number, @JsonKey(name: 'po_number')  String poNumber,  String date, @JsonKey(name: 'due_date')  String dueDate, @JsonKey(name: 'partial_due_date')  String partialDueDate, @JsonKey(name: 'status_id')  String statusId, @JsonKey(name: 'client_id')  String clientId, @JsonKey(name: 'vendor_id')  String vendorId, @JsonKey(name: 'project_id')  String projectId, @JsonKey(name: 'design_id')  String designId, @JsonKey(name: 'assigned_user_id')  String assignedUserId, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'location_id')  String locationId, @JsonKey(name: 'subscription_id')  String subscriptionId, @JsonKey(name: 'invoice_id')  String parentInvoiceId, @JsonKey(name: 'recurring_id')  String recurringId,  Object amount,  Object balance, @JsonKey(name: 'paid_to_date')  Object paidToDate, @JsonKey(name: 'total_taxes')  Object totalTaxes,  Object discount, @JsonKey(name: 'partial')  Object partial, @JsonKey(name: 'is_amount_discount')  bool isAmountDiscount, @JsonKey(name: 'exchange_rate')  Object exchangeRate, @JsonKey(name: 'tax_name1')  String taxName1, @JsonKey(name: 'tax_name2')  String taxName2, @JsonKey(name: 'tax_name3')  String taxName3, @JsonKey(name: 'tax_rate1')  Object taxRate1, @JsonKey(name: 'tax_rate2')  Object taxRate2, @JsonKey(name: 'tax_rate3')  Object taxRate3, @JsonKey(name: 'uses_inclusive_taxes')  bool usesInclusiveTaxes, @JsonKey(name: 'custom_surcharge1')  Object customSurcharge1, @JsonKey(name: 'custom_surcharge2')  Object customSurcharge2, @JsonKey(name: 'custom_surcharge3')  Object customSurcharge3, @JsonKey(name: 'custom_surcharge4')  Object customSurcharge4, @JsonKey(name: 'custom_surcharge_tax1')  bool customTaxes1, @JsonKey(name: 'custom_surcharge_tax2')  bool customTaxes2, @JsonKey(name: 'custom_surcharge_tax3')  bool customTaxes3, @JsonKey(name: 'custom_surcharge_tax4')  bool customTaxes4, @JsonKey(name: 'public_notes')  String publicNotes, @JsonKey(name: 'private_notes')  String privateNotes,  String terms,  String footer, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'line_items')  List<LineItemApi> lineItems,  List<InvitationApi> invitations,  List<DocumentApi>? documents, @JsonKey(name: 'tags')@EmbeddedTagsConverter()  List<TagRefApi> tags, @JsonKey(name: 'reminder1_sent')  String reminder1Sent, @JsonKey(name: 'reminder2_sent')  String reminder2Sent, @JsonKey(name: 'reminder3_sent')  String reminder3Sent, @JsonKey(name: 'reminder_last_sent')  String reminderLastSent, @JsonKey(name: 'reminder_schedule')  String reminderSchedule, @JsonKey(name: 'frequency_id')  String frequencyId, @JsonKey(name: 'next_send_date')  String nextSendDate, @JsonKey(name: 'next_send_datetime')  String nextSendDatetime, @JsonKey(name: 'last_sent_date')  String lastSentDate, @JsonKey(name: 'remaining_cycles')  int remainingCycles, @JsonKey(name: 'due_date_days')  String dueDateDays, @JsonKey(name: 'auto_bill')  String autoBill, @JsonKey(name: 'auto_bill_enabled')  bool autoBillEnabled, @JsonKey(name: 'e_invoice')  Map<String, dynamic>? eInvoice, @JsonKey(name: 'backup')  Map<String, dynamic>? backup, @JsonKey(name: 'tax_info')  Map<String, dynamic>? taxInfo, @JsonKey(name: 'modified_invoice_id')  String? modifiedInvoiceId, @JsonKey(name: 'reason')  String? reason, @JsonKey(name: 'schedule')  List<ScheduleItemApi>? schedule, @JsonKey(name: 'is_locked')  bool isLocked, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InvoiceApi() when $default != null:
return $default(_that.id,_that.number,_that.poNumber,_that.date,_that.dueDate,_that.partialDueDate,_that.statusId,_that.clientId,_that.vendorId,_that.projectId,_that.designId,_that.assignedUserId,_that.userId,_that.locationId,_that.subscriptionId,_that.parentInvoiceId,_that.recurringId,_that.amount,_that.balance,_that.paidToDate,_that.totalTaxes,_that.discount,_that.partial,_that.isAmountDiscount,_that.exchangeRate,_that.taxName1,_that.taxName2,_that.taxName3,_that.taxRate1,_that.taxRate2,_that.taxRate3,_that.usesInclusiveTaxes,_that.customSurcharge1,_that.customSurcharge2,_that.customSurcharge3,_that.customSurcharge4,_that.customTaxes1,_that.customTaxes2,_that.customTaxes3,_that.customTaxes4,_that.publicNotes,_that.privateNotes,_that.terms,_that.footer,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.lineItems,_that.invitations,_that.documents,_that.tags,_that.reminder1Sent,_that.reminder2Sent,_that.reminder3Sent,_that.reminderLastSent,_that.reminderSchedule,_that.frequencyId,_that.nextSendDate,_that.nextSendDatetime,_that.lastSentDate,_that.remainingCycles,_that.dueDateDays,_that.autoBill,_that.autoBillEnabled,_that.eInvoice,_that.backup,_that.taxInfo,_that.modifiedInvoiceId,_that.reason,_that.schedule,_that.isLocked,_that.isDeleted,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String number, @JsonKey(name: 'po_number')  String poNumber,  String date, @JsonKey(name: 'due_date')  String dueDate, @JsonKey(name: 'partial_due_date')  String partialDueDate, @JsonKey(name: 'status_id')  String statusId, @JsonKey(name: 'client_id')  String clientId, @JsonKey(name: 'vendor_id')  String vendorId, @JsonKey(name: 'project_id')  String projectId, @JsonKey(name: 'design_id')  String designId, @JsonKey(name: 'assigned_user_id')  String assignedUserId, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'location_id')  String locationId, @JsonKey(name: 'subscription_id')  String subscriptionId, @JsonKey(name: 'invoice_id')  String parentInvoiceId, @JsonKey(name: 'recurring_id')  String recurringId,  Object amount,  Object balance, @JsonKey(name: 'paid_to_date')  Object paidToDate, @JsonKey(name: 'total_taxes')  Object totalTaxes,  Object discount, @JsonKey(name: 'partial')  Object partial, @JsonKey(name: 'is_amount_discount')  bool isAmountDiscount, @JsonKey(name: 'exchange_rate')  Object exchangeRate, @JsonKey(name: 'tax_name1')  String taxName1, @JsonKey(name: 'tax_name2')  String taxName2, @JsonKey(name: 'tax_name3')  String taxName3, @JsonKey(name: 'tax_rate1')  Object taxRate1, @JsonKey(name: 'tax_rate2')  Object taxRate2, @JsonKey(name: 'tax_rate3')  Object taxRate3, @JsonKey(name: 'uses_inclusive_taxes')  bool usesInclusiveTaxes, @JsonKey(name: 'custom_surcharge1')  Object customSurcharge1, @JsonKey(name: 'custom_surcharge2')  Object customSurcharge2, @JsonKey(name: 'custom_surcharge3')  Object customSurcharge3, @JsonKey(name: 'custom_surcharge4')  Object customSurcharge4, @JsonKey(name: 'custom_surcharge_tax1')  bool customTaxes1, @JsonKey(name: 'custom_surcharge_tax2')  bool customTaxes2, @JsonKey(name: 'custom_surcharge_tax3')  bool customTaxes3, @JsonKey(name: 'custom_surcharge_tax4')  bool customTaxes4, @JsonKey(name: 'public_notes')  String publicNotes, @JsonKey(name: 'private_notes')  String privateNotes,  String terms,  String footer, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'line_items')  List<LineItemApi> lineItems,  List<InvitationApi> invitations,  List<DocumentApi>? documents, @JsonKey(name: 'tags')@EmbeddedTagsConverter()  List<TagRefApi> tags, @JsonKey(name: 'reminder1_sent')  String reminder1Sent, @JsonKey(name: 'reminder2_sent')  String reminder2Sent, @JsonKey(name: 'reminder3_sent')  String reminder3Sent, @JsonKey(name: 'reminder_last_sent')  String reminderLastSent, @JsonKey(name: 'reminder_schedule')  String reminderSchedule, @JsonKey(name: 'frequency_id')  String frequencyId, @JsonKey(name: 'next_send_date')  String nextSendDate, @JsonKey(name: 'next_send_datetime')  String nextSendDatetime, @JsonKey(name: 'last_sent_date')  String lastSentDate, @JsonKey(name: 'remaining_cycles')  int remainingCycles, @JsonKey(name: 'due_date_days')  String dueDateDays, @JsonKey(name: 'auto_bill')  String autoBill, @JsonKey(name: 'auto_bill_enabled')  bool autoBillEnabled, @JsonKey(name: 'e_invoice')  Map<String, dynamic>? eInvoice, @JsonKey(name: 'backup')  Map<String, dynamic>? backup, @JsonKey(name: 'tax_info')  Map<String, dynamic>? taxInfo, @JsonKey(name: 'modified_invoice_id')  String? modifiedInvoiceId, @JsonKey(name: 'reason')  String? reason, @JsonKey(name: 'schedule')  List<ScheduleItemApi>? schedule, @JsonKey(name: 'is_locked')  bool isLocked, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)  $default,) {final _that = this;
switch (_that) {
case _InvoiceApi():
return $default(_that.id,_that.number,_that.poNumber,_that.date,_that.dueDate,_that.partialDueDate,_that.statusId,_that.clientId,_that.vendorId,_that.projectId,_that.designId,_that.assignedUserId,_that.userId,_that.locationId,_that.subscriptionId,_that.parentInvoiceId,_that.recurringId,_that.amount,_that.balance,_that.paidToDate,_that.totalTaxes,_that.discount,_that.partial,_that.isAmountDiscount,_that.exchangeRate,_that.taxName1,_that.taxName2,_that.taxName3,_that.taxRate1,_that.taxRate2,_that.taxRate3,_that.usesInclusiveTaxes,_that.customSurcharge1,_that.customSurcharge2,_that.customSurcharge3,_that.customSurcharge4,_that.customTaxes1,_that.customTaxes2,_that.customTaxes3,_that.customTaxes4,_that.publicNotes,_that.privateNotes,_that.terms,_that.footer,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.lineItems,_that.invitations,_that.documents,_that.tags,_that.reminder1Sent,_that.reminder2Sent,_that.reminder3Sent,_that.reminderLastSent,_that.reminderSchedule,_that.frequencyId,_that.nextSendDate,_that.nextSendDatetime,_that.lastSentDate,_that.remainingCycles,_that.dueDateDays,_that.autoBill,_that.autoBillEnabled,_that.eInvoice,_that.backup,_that.taxInfo,_that.modifiedInvoiceId,_that.reason,_that.schedule,_that.isLocked,_that.isDeleted,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String number, @JsonKey(name: 'po_number')  String poNumber,  String date, @JsonKey(name: 'due_date')  String dueDate, @JsonKey(name: 'partial_due_date')  String partialDueDate, @JsonKey(name: 'status_id')  String statusId, @JsonKey(name: 'client_id')  String clientId, @JsonKey(name: 'vendor_id')  String vendorId, @JsonKey(name: 'project_id')  String projectId, @JsonKey(name: 'design_id')  String designId, @JsonKey(name: 'assigned_user_id')  String assignedUserId, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'location_id')  String locationId, @JsonKey(name: 'subscription_id')  String subscriptionId, @JsonKey(name: 'invoice_id')  String parentInvoiceId, @JsonKey(name: 'recurring_id')  String recurringId,  Object amount,  Object balance, @JsonKey(name: 'paid_to_date')  Object paidToDate, @JsonKey(name: 'total_taxes')  Object totalTaxes,  Object discount, @JsonKey(name: 'partial')  Object partial, @JsonKey(name: 'is_amount_discount')  bool isAmountDiscount, @JsonKey(name: 'exchange_rate')  Object exchangeRate, @JsonKey(name: 'tax_name1')  String taxName1, @JsonKey(name: 'tax_name2')  String taxName2, @JsonKey(name: 'tax_name3')  String taxName3, @JsonKey(name: 'tax_rate1')  Object taxRate1, @JsonKey(name: 'tax_rate2')  Object taxRate2, @JsonKey(name: 'tax_rate3')  Object taxRate3, @JsonKey(name: 'uses_inclusive_taxes')  bool usesInclusiveTaxes, @JsonKey(name: 'custom_surcharge1')  Object customSurcharge1, @JsonKey(name: 'custom_surcharge2')  Object customSurcharge2, @JsonKey(name: 'custom_surcharge3')  Object customSurcharge3, @JsonKey(name: 'custom_surcharge4')  Object customSurcharge4, @JsonKey(name: 'custom_surcharge_tax1')  bool customTaxes1, @JsonKey(name: 'custom_surcharge_tax2')  bool customTaxes2, @JsonKey(name: 'custom_surcharge_tax3')  bool customTaxes3, @JsonKey(name: 'custom_surcharge_tax4')  bool customTaxes4, @JsonKey(name: 'public_notes')  String publicNotes, @JsonKey(name: 'private_notes')  String privateNotes,  String terms,  String footer, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'line_items')  List<LineItemApi> lineItems,  List<InvitationApi> invitations,  List<DocumentApi>? documents, @JsonKey(name: 'tags')@EmbeddedTagsConverter()  List<TagRefApi> tags, @JsonKey(name: 'reminder1_sent')  String reminder1Sent, @JsonKey(name: 'reminder2_sent')  String reminder2Sent, @JsonKey(name: 'reminder3_sent')  String reminder3Sent, @JsonKey(name: 'reminder_last_sent')  String reminderLastSent, @JsonKey(name: 'reminder_schedule')  String reminderSchedule, @JsonKey(name: 'frequency_id')  String frequencyId, @JsonKey(name: 'next_send_date')  String nextSendDate, @JsonKey(name: 'next_send_datetime')  String nextSendDatetime, @JsonKey(name: 'last_sent_date')  String lastSentDate, @JsonKey(name: 'remaining_cycles')  int remainingCycles, @JsonKey(name: 'due_date_days')  String dueDateDays, @JsonKey(name: 'auto_bill')  String autoBill, @JsonKey(name: 'auto_bill_enabled')  bool autoBillEnabled, @JsonKey(name: 'e_invoice')  Map<String, dynamic>? eInvoice, @JsonKey(name: 'backup')  Map<String, dynamic>? backup, @JsonKey(name: 'tax_info')  Map<String, dynamic>? taxInfo, @JsonKey(name: 'modified_invoice_id')  String? modifiedInvoiceId, @JsonKey(name: 'reason')  String? reason, @JsonKey(name: 'schedule')  List<ScheduleItemApi>? schedule, @JsonKey(name: 'is_locked')  bool isLocked, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)?  $default,) {final _that = this;
switch (_that) {
case _InvoiceApi() when $default != null:
return $default(_that.id,_that.number,_that.poNumber,_that.date,_that.dueDate,_that.partialDueDate,_that.statusId,_that.clientId,_that.vendorId,_that.projectId,_that.designId,_that.assignedUserId,_that.userId,_that.locationId,_that.subscriptionId,_that.parentInvoiceId,_that.recurringId,_that.amount,_that.balance,_that.paidToDate,_that.totalTaxes,_that.discount,_that.partial,_that.isAmountDiscount,_that.exchangeRate,_that.taxName1,_that.taxName2,_that.taxName3,_that.taxRate1,_that.taxRate2,_that.taxRate3,_that.usesInclusiveTaxes,_that.customSurcharge1,_that.customSurcharge2,_that.customSurcharge3,_that.customSurcharge4,_that.customTaxes1,_that.customTaxes2,_that.customTaxes3,_that.customTaxes4,_that.publicNotes,_that.privateNotes,_that.terms,_that.footer,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.lineItems,_that.invitations,_that.documents,_that.tags,_that.reminder1Sent,_that.reminder2Sent,_that.reminder3Sent,_that.reminderLastSent,_that.reminderSchedule,_that.frequencyId,_that.nextSendDate,_that.nextSendDatetime,_that.lastSentDate,_that.remainingCycles,_that.dueDateDays,_that.autoBill,_that.autoBillEnabled,_that.eInvoice,_that.backup,_that.taxInfo,_that.modifiedInvoiceId,_that.reason,_that.schedule,_that.isLocked,_that.isDeleted,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InvoiceApi implements InvoiceApi {
  const _InvoiceApi({this.id = '', this.number = '', @JsonKey(name: 'po_number') this.poNumber = '', this.date = '', @JsonKey(name: 'due_date') this.dueDate = '', @JsonKey(name: 'partial_due_date') this.partialDueDate = '', @JsonKey(name: 'status_id') this.statusId = '1', @JsonKey(name: 'client_id') this.clientId = '', @JsonKey(name: 'vendor_id') this.vendorId = '', @JsonKey(name: 'project_id') this.projectId = '', @JsonKey(name: 'design_id') this.designId = '', @JsonKey(name: 'assigned_user_id') this.assignedUserId = '', @JsonKey(name: 'user_id') this.userId = '', @JsonKey(name: 'location_id') this.locationId = '', @JsonKey(name: 'subscription_id') this.subscriptionId = '', @JsonKey(name: 'invoice_id') this.parentInvoiceId = '', @JsonKey(name: 'recurring_id') this.recurringId = '', this.amount = '0', this.balance = '0', @JsonKey(name: 'paid_to_date') this.paidToDate = '0', @JsonKey(name: 'total_taxes') this.totalTaxes = '0', this.discount = '0', @JsonKey(name: 'partial') this.partial = '0', @JsonKey(name: 'is_amount_discount') this.isAmountDiscount = false, @JsonKey(name: 'exchange_rate') this.exchangeRate = '1', @JsonKey(name: 'tax_name1') this.taxName1 = '', @JsonKey(name: 'tax_name2') this.taxName2 = '', @JsonKey(name: 'tax_name3') this.taxName3 = '', @JsonKey(name: 'tax_rate1') this.taxRate1 = '0', @JsonKey(name: 'tax_rate2') this.taxRate2 = '0', @JsonKey(name: 'tax_rate3') this.taxRate3 = '0', @JsonKey(name: 'uses_inclusive_taxes') this.usesInclusiveTaxes = false, @JsonKey(name: 'custom_surcharge1') this.customSurcharge1 = '0', @JsonKey(name: 'custom_surcharge2') this.customSurcharge2 = '0', @JsonKey(name: 'custom_surcharge3') this.customSurcharge3 = '0', @JsonKey(name: 'custom_surcharge4') this.customSurcharge4 = '0', @JsonKey(name: 'custom_surcharge_tax1') this.customTaxes1 = false, @JsonKey(name: 'custom_surcharge_tax2') this.customTaxes2 = false, @JsonKey(name: 'custom_surcharge_tax3') this.customTaxes3 = false, @JsonKey(name: 'custom_surcharge_tax4') this.customTaxes4 = false, @JsonKey(name: 'public_notes') this.publicNotes = '', @JsonKey(name: 'private_notes') this.privateNotes = '', this.terms = '', this.footer = '', @JsonKey(name: 'custom_value1') this.customValue1 = '', @JsonKey(name: 'custom_value2') this.customValue2 = '', @JsonKey(name: 'custom_value3') this.customValue3 = '', @JsonKey(name: 'custom_value4') this.customValue4 = '', @JsonKey(name: 'line_items') final  List<LineItemApi> lineItems = const <LineItemApi>[], final  List<InvitationApi> invitations = const <InvitationApi>[], final  List<DocumentApi>? documents, @JsonKey(name: 'tags')@EmbeddedTagsConverter() final  List<TagRefApi> tags = const <TagRefApi>[], @JsonKey(name: 'reminder1_sent') this.reminder1Sent = '', @JsonKey(name: 'reminder2_sent') this.reminder2Sent = '', @JsonKey(name: 'reminder3_sent') this.reminder3Sent = '', @JsonKey(name: 'reminder_last_sent') this.reminderLastSent = '', @JsonKey(name: 'reminder_schedule') this.reminderSchedule = '', @JsonKey(name: 'frequency_id') this.frequencyId = '', @JsonKey(name: 'next_send_date') this.nextSendDate = '', @JsonKey(name: 'next_send_datetime') this.nextSendDatetime = '', @JsonKey(name: 'last_sent_date') this.lastSentDate = '', @JsonKey(name: 'remaining_cycles') this.remainingCycles = 0, @JsonKey(name: 'due_date_days') this.dueDateDays = '', @JsonKey(name: 'auto_bill') this.autoBill = '', @JsonKey(name: 'auto_bill_enabled') this.autoBillEnabled = false, @JsonKey(name: 'e_invoice') final  Map<String, dynamic>? eInvoice, @JsonKey(name: 'backup') final  Map<String, dynamic>? backup, @JsonKey(name: 'tax_info') final  Map<String, dynamic>? taxInfo, @JsonKey(name: 'modified_invoice_id') this.modifiedInvoiceId, @JsonKey(name: 'reason') this.reason, @JsonKey(name: 'schedule') final  List<ScheduleItemApi>? schedule, @JsonKey(name: 'is_locked') this.isLocked = false, @JsonKey(name: 'is_deleted') this.isDeleted = false, @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0}): _lineItems = lineItems,_invitations = invitations,_documents = documents,_tags = tags,_eInvoice = eInvoice,_backup = backup,_taxInfo = taxInfo,_schedule = schedule;
  factory _InvoiceApi.fromJson(Map<String, dynamic> json) => _$InvoiceApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey() final  String number;
@override@JsonKey(name: 'po_number') final  String poNumber;
@override@JsonKey() final  String date;
@override@JsonKey(name: 'due_date') final  String dueDate;
@override@JsonKey(name: 'partial_due_date') final  String partialDueDate;
@override@JsonKey(name: 'status_id') final  String statusId;
@override@JsonKey(name: 'client_id') final  String clientId;
@override@JsonKey(name: 'vendor_id') final  String vendorId;
@override@JsonKey(name: 'project_id') final  String projectId;
@override@JsonKey(name: 'design_id') final  String designId;
@override@JsonKey(name: 'assigned_user_id') final  String assignedUserId;
@override@JsonKey(name: 'user_id') final  String userId;
@override@JsonKey(name: 'location_id') final  String locationId;
@override@JsonKey(name: 'subscription_id') final  String subscriptionId;
// Parent invoice for a quote/credit/PO linkage (admin-portal calls
// this `invoice_id` on quotes/credits to point at the resulting
// invoice when a conversion happens). Empty by default.
@override@JsonKey(name: 'invoice_id') final  String parentInvoiceId;
@override@JsonKey(name: 'recurring_id') final  String recurringId;
// Money
@override@JsonKey() final  Object amount;
@override@JsonKey() final  Object balance;
@override@JsonKey(name: 'paid_to_date') final  Object paidToDate;
@override@JsonKey(name: 'total_taxes') final  Object totalTaxes;
@override@JsonKey() final  Object discount;
@override@JsonKey(name: 'partial') final  Object partial;
@override@JsonKey(name: 'is_amount_discount') final  bool isAmountDiscount;
@override@JsonKey(name: 'exchange_rate') final  Object exchangeRate;
// Tax
@override@JsonKey(name: 'tax_name1') final  String taxName1;
@override@JsonKey(name: 'tax_name2') final  String taxName2;
@override@JsonKey(name: 'tax_name3') final  String taxName3;
@override@JsonKey(name: 'tax_rate1') final  Object taxRate1;
@override@JsonKey(name: 'tax_rate2') final  Object taxRate2;
@override@JsonKey(name: 'tax_rate3') final  Object taxRate3;
@override@JsonKey(name: 'uses_inclusive_taxes') final  bool usesInclusiveTaxes;
@override@JsonKey(name: 'custom_surcharge1') final  Object customSurcharge1;
@override@JsonKey(name: 'custom_surcharge2') final  Object customSurcharge2;
@override@JsonKey(name: 'custom_surcharge3') final  Object customSurcharge3;
@override@JsonKey(name: 'custom_surcharge4') final  Object customSurcharge4;
@override@JsonKey(name: 'custom_surcharge_tax1') final  bool customTaxes1;
@override@JsonKey(name: 'custom_surcharge_tax2') final  bool customTaxes2;
@override@JsonKey(name: 'custom_surcharge_tax3') final  bool customTaxes3;
@override@JsonKey(name: 'custom_surcharge_tax4') final  bool customTaxes4;
// Notes + content
@override@JsonKey(name: 'public_notes') final  String publicNotes;
@override@JsonKey(name: 'private_notes') final  String privateNotes;
@override@JsonKey() final  String terms;
@override@JsonKey() final  String footer;
@override@JsonKey(name: 'custom_value1') final  String customValue1;
@override@JsonKey(name: 'custom_value2') final  String customValue2;
@override@JsonKey(name: 'custom_value3') final  String customValue3;
@override@JsonKey(name: 'custom_value4') final  String customValue4;
// Nested arrays
 final  List<LineItemApi> _lineItems;
// Nested arrays
@override@JsonKey(name: 'line_items') List<LineItemApi> get lineItems {
  if (_lineItems is EqualUnmodifiableListView) return _lineItems;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lineItems);
}

 final  List<InvitationApi> _invitations;
@override@JsonKey() List<InvitationApi> get invitations {
  if (_invitations is EqualUnmodifiableListView) return _invitations;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_invitations);
}

// Nullable — `documents` only present when `?include=documents` was
// sent; same convention as ClientApi/ExpenseApi.
 final  List<DocumentApi>? _documents;
// Nullable — `documents` only present when `?include=documents` was
// sent; same convention as ClientApi/ExpenseApi.
@override List<DocumentApi>? get documents {
  final value = _documents;
  if (value == null) return null;
  if (_documents is EqualUnmodifiableListView) return _documents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<TagRefApi> _tags;
@override@JsonKey(name: 'tags')@EmbeddedTagsConverter() List<TagRefApi> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

// Reminder timestamps
@override@JsonKey(name: 'reminder1_sent') final  String reminder1Sent;
@override@JsonKey(name: 'reminder2_sent') final  String reminder2Sent;
@override@JsonKey(name: 'reminder3_sent') final  String reminder3Sent;
@override@JsonKey(name: 'reminder_last_sent') final  String reminderLastSent;
@override@JsonKey(name: 'reminder_schedule') final  String reminderSchedule;
// Recurring + auto-bill (relevant for RecurringInvoice but carried
// on every invoice so the field shape stays consistent)
@override@JsonKey(name: 'frequency_id') final  String frequencyId;
@override@JsonKey(name: 'next_send_date') final  String nextSendDate;
@override@JsonKey(name: 'next_send_datetime') final  String nextSendDatetime;
@override@JsonKey(name: 'last_sent_date') final  String lastSentDate;
@override@JsonKey(name: 'remaining_cycles') final  int remainingCycles;
@override@JsonKey(name: 'due_date_days') final  String dueDateDays;
@override@JsonKey(name: 'auto_bill') final  String autoBill;
@override@JsonKey(name: 'auto_bill_enabled') final  bool autoBillEnabled;
// E-invoice / Verifactu — open-ended typed-deferred maps
 final  Map<String, dynamic>? _eInvoice;
// E-invoice / Verifactu — open-ended typed-deferred maps
@override@JsonKey(name: 'e_invoice') Map<String, dynamic>? get eInvoice {
  final value = _eInvoice;
  if (value == null) return null;
  if (_eInvoice is EqualUnmodifiableMapView) return _eInvoice;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Map<String, dynamic>? _backup;
@override@JsonKey(name: 'backup') Map<String, dynamic>? get backup {
  final value = _backup;
  if (value == null) return null;
  if (_backup is EqualUnmodifiableMapView) return _backup;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Map<String, dynamic>? _taxInfo;
@override@JsonKey(name: 'tax_info') Map<String, dynamic>? get taxInfo {
  final value = _taxInfo;
  if (value == null) return null;
  if (_taxInfo is EqualUnmodifiableMapView) return _taxInfo;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

// Rectification (Verifactu "factura rectificativa"): id of the original
// invoice this one corrects + the user-supplied rectification reason.
@override@JsonKey(name: 'modified_invoice_id') final  String? modifiedInvoiceId;
@override@JsonKey(name: 'reason') final  String? reason;
// Read-only payment-schedule projection. Present ONLY when the invoice
// is fetched with `?show_schedule=true` (probe-verified: absent on
// plain/list GETs). Nullable for the same reason as `documents` — the
// repo's `_apiToCompanion` must distinguish "key absent → preserve the
// stored column" from "present → authoritative". Persisted to a
// dedicated Drift column; `Invoice.toApiJson` omits it (read-only).
 final  List<ScheduleItemApi>? _schedule;
// Read-only payment-schedule projection. Present ONLY when the invoice
// is fetched with `?show_schedule=true` (probe-verified: absent on
// plain/list GETs). Nullable for the same reason as `documents` — the
// repo's `_apiToCompanion` must distinguish "key absent → preserve the
// stored column" from "present → authoritative". Persisted to a
// dedicated Drift column; `Invoice.toApiJson` omits it (read-only).
@override@JsonKey(name: 'schedule') List<ScheduleItemApi>? get schedule {
  final value = _schedule;
  if (value == null) return null;
  if (_schedule is EqualUnmodifiableListView) return _schedule;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

// Flags
@override@JsonKey(name: 'is_locked') final  bool isLocked;
@override@JsonKey(name: 'is_deleted') final  bool isDeleted;
// Timestamps
@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'archived_at') final  int archivedAt;

/// Create a copy of InvoiceApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InvoiceApiCopyWith<_InvoiceApi> get copyWith => __$InvoiceApiCopyWithImpl<_InvoiceApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InvoiceApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InvoiceApi&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.poNumber, poNumber) || other.poNumber == poNumber)&&(identical(other.date, date) || other.date == date)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.partialDueDate, partialDueDate) || other.partialDueDate == partialDueDate)&&(identical(other.statusId, statusId) || other.statusId == statusId)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.vendorId, vendorId) || other.vendorId == vendorId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.designId, designId) || other.designId == designId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.locationId, locationId) || other.locationId == locationId)&&(identical(other.subscriptionId, subscriptionId) || other.subscriptionId == subscriptionId)&&(identical(other.parentInvoiceId, parentInvoiceId) || other.parentInvoiceId == parentInvoiceId)&&(identical(other.recurringId, recurringId) || other.recurringId == recurringId)&&const DeepCollectionEquality().equals(other.amount, amount)&&const DeepCollectionEquality().equals(other.balance, balance)&&const DeepCollectionEquality().equals(other.paidToDate, paidToDate)&&const DeepCollectionEquality().equals(other.totalTaxes, totalTaxes)&&const DeepCollectionEquality().equals(other.discount, discount)&&const DeepCollectionEquality().equals(other.partial, partial)&&(identical(other.isAmountDiscount, isAmountDiscount) || other.isAmountDiscount == isAmountDiscount)&&const DeepCollectionEquality().equals(other.exchangeRate, exchangeRate)&&(identical(other.taxName1, taxName1) || other.taxName1 == taxName1)&&(identical(other.taxName2, taxName2) || other.taxName2 == taxName2)&&(identical(other.taxName3, taxName3) || other.taxName3 == taxName3)&&const DeepCollectionEquality().equals(other.taxRate1, taxRate1)&&const DeepCollectionEquality().equals(other.taxRate2, taxRate2)&&const DeepCollectionEquality().equals(other.taxRate3, taxRate3)&&(identical(other.usesInclusiveTaxes, usesInclusiveTaxes) || other.usesInclusiveTaxes == usesInclusiveTaxes)&&const DeepCollectionEquality().equals(other.customSurcharge1, customSurcharge1)&&const DeepCollectionEquality().equals(other.customSurcharge2, customSurcharge2)&&const DeepCollectionEquality().equals(other.customSurcharge3, customSurcharge3)&&const DeepCollectionEquality().equals(other.customSurcharge4, customSurcharge4)&&(identical(other.customTaxes1, customTaxes1) || other.customTaxes1 == customTaxes1)&&(identical(other.customTaxes2, customTaxes2) || other.customTaxes2 == customTaxes2)&&(identical(other.customTaxes3, customTaxes3) || other.customTaxes3 == customTaxes3)&&(identical(other.customTaxes4, customTaxes4) || other.customTaxes4 == customTaxes4)&&(identical(other.publicNotes, publicNotes) || other.publicNotes == publicNotes)&&(identical(other.privateNotes, privateNotes) || other.privateNotes == privateNotes)&&(identical(other.terms, terms) || other.terms == terms)&&(identical(other.footer, footer) || other.footer == footer)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&const DeepCollectionEquality().equals(other._lineItems, _lineItems)&&const DeepCollectionEquality().equals(other._invitations, _invitations)&&const DeepCollectionEquality().equals(other._documents, _documents)&&const DeepCollectionEquality().equals(other._tags, _tags)&&(identical(other.reminder1Sent, reminder1Sent) || other.reminder1Sent == reminder1Sent)&&(identical(other.reminder2Sent, reminder2Sent) || other.reminder2Sent == reminder2Sent)&&(identical(other.reminder3Sent, reminder3Sent) || other.reminder3Sent == reminder3Sent)&&(identical(other.reminderLastSent, reminderLastSent) || other.reminderLastSent == reminderLastSent)&&(identical(other.reminderSchedule, reminderSchedule) || other.reminderSchedule == reminderSchedule)&&(identical(other.frequencyId, frequencyId) || other.frequencyId == frequencyId)&&(identical(other.nextSendDate, nextSendDate) || other.nextSendDate == nextSendDate)&&(identical(other.nextSendDatetime, nextSendDatetime) || other.nextSendDatetime == nextSendDatetime)&&(identical(other.lastSentDate, lastSentDate) || other.lastSentDate == lastSentDate)&&(identical(other.remainingCycles, remainingCycles) || other.remainingCycles == remainingCycles)&&(identical(other.dueDateDays, dueDateDays) || other.dueDateDays == dueDateDays)&&(identical(other.autoBill, autoBill) || other.autoBill == autoBill)&&(identical(other.autoBillEnabled, autoBillEnabled) || other.autoBillEnabled == autoBillEnabled)&&const DeepCollectionEquality().equals(other._eInvoice, _eInvoice)&&const DeepCollectionEquality().equals(other._backup, _backup)&&const DeepCollectionEquality().equals(other._taxInfo, _taxInfo)&&(identical(other.modifiedInvoiceId, modifiedInvoiceId) || other.modifiedInvoiceId == modifiedInvoiceId)&&(identical(other.reason, reason) || other.reason == reason)&&const DeepCollectionEquality().equals(other._schedule, _schedule)&&(identical(other.isLocked, isLocked) || other.isLocked == isLocked)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,number,poNumber,date,dueDate,partialDueDate,statusId,clientId,vendorId,projectId,designId,assignedUserId,userId,locationId,subscriptionId,parentInvoiceId,recurringId,const DeepCollectionEquality().hash(amount),const DeepCollectionEquality().hash(balance),const DeepCollectionEquality().hash(paidToDate),const DeepCollectionEquality().hash(totalTaxes),const DeepCollectionEquality().hash(discount),const DeepCollectionEquality().hash(partial),isAmountDiscount,const DeepCollectionEquality().hash(exchangeRate),taxName1,taxName2,taxName3,const DeepCollectionEquality().hash(taxRate1),const DeepCollectionEquality().hash(taxRate2),const DeepCollectionEquality().hash(taxRate3),usesInclusiveTaxes,const DeepCollectionEquality().hash(customSurcharge1),const DeepCollectionEquality().hash(customSurcharge2),const DeepCollectionEquality().hash(customSurcharge3),const DeepCollectionEquality().hash(customSurcharge4),customTaxes1,customTaxes2,customTaxes3,customTaxes4,publicNotes,privateNotes,terms,footer,customValue1,customValue2,customValue3,customValue4,const DeepCollectionEquality().hash(_lineItems),const DeepCollectionEquality().hash(_invitations),const DeepCollectionEquality().hash(_documents),const DeepCollectionEquality().hash(_tags),reminder1Sent,reminder2Sent,reminder3Sent,reminderLastSent,reminderSchedule,frequencyId,nextSendDate,nextSendDatetime,lastSentDate,remainingCycles,dueDateDays,autoBill,autoBillEnabled,const DeepCollectionEquality().hash(_eInvoice),const DeepCollectionEquality().hash(_backup),const DeepCollectionEquality().hash(_taxInfo),modifiedInvoiceId,reason,const DeepCollectionEquality().hash(_schedule),isLocked,isDeleted,createdAt,updatedAt,archivedAt]);

@override
String toString() {
  return 'InvoiceApi(id: $id, number: $number, poNumber: $poNumber, date: $date, dueDate: $dueDate, partialDueDate: $partialDueDate, statusId: $statusId, clientId: $clientId, vendorId: $vendorId, projectId: $projectId, designId: $designId, assignedUserId: $assignedUserId, userId: $userId, locationId: $locationId, subscriptionId: $subscriptionId, parentInvoiceId: $parentInvoiceId, recurringId: $recurringId, amount: $amount, balance: $balance, paidToDate: $paidToDate, totalTaxes: $totalTaxes, discount: $discount, partial: $partial, isAmountDiscount: $isAmountDiscount, exchangeRate: $exchangeRate, taxName1: $taxName1, taxName2: $taxName2, taxName3: $taxName3, taxRate1: $taxRate1, taxRate2: $taxRate2, taxRate3: $taxRate3, usesInclusiveTaxes: $usesInclusiveTaxes, customSurcharge1: $customSurcharge1, customSurcharge2: $customSurcharge2, customSurcharge3: $customSurcharge3, customSurcharge4: $customSurcharge4, customTaxes1: $customTaxes1, customTaxes2: $customTaxes2, customTaxes3: $customTaxes3, customTaxes4: $customTaxes4, publicNotes: $publicNotes, privateNotes: $privateNotes, terms: $terms, footer: $footer, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, lineItems: $lineItems, invitations: $invitations, documents: $documents, tags: $tags, reminder1Sent: $reminder1Sent, reminder2Sent: $reminder2Sent, reminder3Sent: $reminder3Sent, reminderLastSent: $reminderLastSent, reminderSchedule: $reminderSchedule, frequencyId: $frequencyId, nextSendDate: $nextSendDate, nextSendDatetime: $nextSendDatetime, lastSentDate: $lastSentDate, remainingCycles: $remainingCycles, dueDateDays: $dueDateDays, autoBill: $autoBill, autoBillEnabled: $autoBillEnabled, eInvoice: $eInvoice, backup: $backup, taxInfo: $taxInfo, modifiedInvoiceId: $modifiedInvoiceId, reason: $reason, schedule: $schedule, isLocked: $isLocked, isDeleted: $isDeleted, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt)';
}


}

/// @nodoc
abstract mixin class _$InvoiceApiCopyWith<$Res> implements $InvoiceApiCopyWith<$Res> {
  factory _$InvoiceApiCopyWith(_InvoiceApi value, $Res Function(_InvoiceApi) _then) = __$InvoiceApiCopyWithImpl;
@override @useResult
$Res call({
 String id, String number,@JsonKey(name: 'po_number') String poNumber, String date,@JsonKey(name: 'due_date') String dueDate,@JsonKey(name: 'partial_due_date') String partialDueDate,@JsonKey(name: 'status_id') String statusId,@JsonKey(name: 'client_id') String clientId,@JsonKey(name: 'vendor_id') String vendorId,@JsonKey(name: 'project_id') String projectId,@JsonKey(name: 'design_id') String designId,@JsonKey(name: 'assigned_user_id') String assignedUserId,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'location_id') String locationId,@JsonKey(name: 'subscription_id') String subscriptionId,@JsonKey(name: 'invoice_id') String parentInvoiceId,@JsonKey(name: 'recurring_id') String recurringId, Object amount, Object balance,@JsonKey(name: 'paid_to_date') Object paidToDate,@JsonKey(name: 'total_taxes') Object totalTaxes, Object discount,@JsonKey(name: 'partial') Object partial,@JsonKey(name: 'is_amount_discount') bool isAmountDiscount,@JsonKey(name: 'exchange_rate') Object exchangeRate,@JsonKey(name: 'tax_name1') String taxName1,@JsonKey(name: 'tax_name2') String taxName2,@JsonKey(name: 'tax_name3') String taxName3,@JsonKey(name: 'tax_rate1') Object taxRate1,@JsonKey(name: 'tax_rate2') Object taxRate2,@JsonKey(name: 'tax_rate3') Object taxRate3,@JsonKey(name: 'uses_inclusive_taxes') bool usesInclusiveTaxes,@JsonKey(name: 'custom_surcharge1') Object customSurcharge1,@JsonKey(name: 'custom_surcharge2') Object customSurcharge2,@JsonKey(name: 'custom_surcharge3') Object customSurcharge3,@JsonKey(name: 'custom_surcharge4') Object customSurcharge4,@JsonKey(name: 'custom_surcharge_tax1') bool customTaxes1,@JsonKey(name: 'custom_surcharge_tax2') bool customTaxes2,@JsonKey(name: 'custom_surcharge_tax3') bool customTaxes3,@JsonKey(name: 'custom_surcharge_tax4') bool customTaxes4,@JsonKey(name: 'public_notes') String publicNotes,@JsonKey(name: 'private_notes') String privateNotes, String terms, String footer,@JsonKey(name: 'custom_value1') String customValue1,@JsonKey(name: 'custom_value2') String customValue2,@JsonKey(name: 'custom_value3') String customValue3,@JsonKey(name: 'custom_value4') String customValue4,@JsonKey(name: 'line_items') List<LineItemApi> lineItems, List<InvitationApi> invitations, List<DocumentApi>? documents,@JsonKey(name: 'tags')@EmbeddedTagsConverter() List<TagRefApi> tags,@JsonKey(name: 'reminder1_sent') String reminder1Sent,@JsonKey(name: 'reminder2_sent') String reminder2Sent,@JsonKey(name: 'reminder3_sent') String reminder3Sent,@JsonKey(name: 'reminder_last_sent') String reminderLastSent,@JsonKey(name: 'reminder_schedule') String reminderSchedule,@JsonKey(name: 'frequency_id') String frequencyId,@JsonKey(name: 'next_send_date') String nextSendDate,@JsonKey(name: 'next_send_datetime') String nextSendDatetime,@JsonKey(name: 'last_sent_date') String lastSentDate,@JsonKey(name: 'remaining_cycles') int remainingCycles,@JsonKey(name: 'due_date_days') String dueDateDays,@JsonKey(name: 'auto_bill') String autoBill,@JsonKey(name: 'auto_bill_enabled') bool autoBillEnabled,@JsonKey(name: 'e_invoice') Map<String, dynamic>? eInvoice,@JsonKey(name: 'backup') Map<String, dynamic>? backup,@JsonKey(name: 'tax_info') Map<String, dynamic>? taxInfo,@JsonKey(name: 'modified_invoice_id') String? modifiedInvoiceId,@JsonKey(name: 'reason') String? reason,@JsonKey(name: 'schedule') List<ScheduleItemApi>? schedule,@JsonKey(name: 'is_locked') bool isLocked,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt
});




}
/// @nodoc
class __$InvoiceApiCopyWithImpl<$Res>
    implements _$InvoiceApiCopyWith<$Res> {
  __$InvoiceApiCopyWithImpl(this._self, this._then);

  final _InvoiceApi _self;
  final $Res Function(_InvoiceApi) _then;

/// Create a copy of InvoiceApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? number = null,Object? poNumber = null,Object? date = null,Object? dueDate = null,Object? partialDueDate = null,Object? statusId = null,Object? clientId = null,Object? vendorId = null,Object? projectId = null,Object? designId = null,Object? assignedUserId = null,Object? userId = null,Object? locationId = null,Object? subscriptionId = null,Object? parentInvoiceId = null,Object? recurringId = null,Object? amount = null,Object? balance = null,Object? paidToDate = null,Object? totalTaxes = null,Object? discount = null,Object? partial = null,Object? isAmountDiscount = null,Object? exchangeRate = null,Object? taxName1 = null,Object? taxName2 = null,Object? taxName3 = null,Object? taxRate1 = null,Object? taxRate2 = null,Object? taxRate3 = null,Object? usesInclusiveTaxes = null,Object? customSurcharge1 = null,Object? customSurcharge2 = null,Object? customSurcharge3 = null,Object? customSurcharge4 = null,Object? customTaxes1 = null,Object? customTaxes2 = null,Object? customTaxes3 = null,Object? customTaxes4 = null,Object? publicNotes = null,Object? privateNotes = null,Object? terms = null,Object? footer = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? lineItems = null,Object? invitations = null,Object? documents = freezed,Object? tags = null,Object? reminder1Sent = null,Object? reminder2Sent = null,Object? reminder3Sent = null,Object? reminderLastSent = null,Object? reminderSchedule = null,Object? frequencyId = null,Object? nextSendDate = null,Object? nextSendDatetime = null,Object? lastSentDate = null,Object? remainingCycles = null,Object? dueDateDays = null,Object? autoBill = null,Object? autoBillEnabled = null,Object? eInvoice = freezed,Object? backup = freezed,Object? taxInfo = freezed,Object? modifiedInvoiceId = freezed,Object? reason = freezed,Object? schedule = freezed,Object? isLocked = null,Object? isDeleted = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,}) {
  return _then(_InvoiceApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,poNumber: null == poNumber ? _self.poNumber : poNumber // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,dueDate: null == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as String,partialDueDate: null == partialDueDate ? _self.partialDueDate : partialDueDate // ignore: cast_nullable_to_non_nullable
as String,statusId: null == statusId ? _self.statusId : statusId // ignore: cast_nullable_to_non_nullable
as String,clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,vendorId: null == vendorId ? _self.vendorId : vendorId // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,designId: null == designId ? _self.designId : designId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,locationId: null == locationId ? _self.locationId : locationId // ignore: cast_nullable_to_non_nullable
as String,subscriptionId: null == subscriptionId ? _self.subscriptionId : subscriptionId // ignore: cast_nullable_to_non_nullable
as String,parentInvoiceId: null == parentInvoiceId ? _self.parentInvoiceId : parentInvoiceId // ignore: cast_nullable_to_non_nullable
as String,recurringId: null == recurringId ? _self.recurringId : recurringId // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount ,balance: null == balance ? _self.balance : balance ,paidToDate: null == paidToDate ? _self.paidToDate : paidToDate ,totalTaxes: null == totalTaxes ? _self.totalTaxes : totalTaxes ,discount: null == discount ? _self.discount : discount ,partial: null == partial ? _self.partial : partial ,isAmountDiscount: null == isAmountDiscount ? _self.isAmountDiscount : isAmountDiscount // ignore: cast_nullable_to_non_nullable
as bool,exchangeRate: null == exchangeRate ? _self.exchangeRate : exchangeRate ,taxName1: null == taxName1 ? _self.taxName1 : taxName1 // ignore: cast_nullable_to_non_nullable
as String,taxName2: null == taxName2 ? _self.taxName2 : taxName2 // ignore: cast_nullable_to_non_nullable
as String,taxName3: null == taxName3 ? _self.taxName3 : taxName3 // ignore: cast_nullable_to_non_nullable
as String,taxRate1: null == taxRate1 ? _self.taxRate1 : taxRate1 ,taxRate2: null == taxRate2 ? _self.taxRate2 : taxRate2 ,taxRate3: null == taxRate3 ? _self.taxRate3 : taxRate3 ,usesInclusiveTaxes: null == usesInclusiveTaxes ? _self.usesInclusiveTaxes : usesInclusiveTaxes // ignore: cast_nullable_to_non_nullable
as bool,customSurcharge1: null == customSurcharge1 ? _self.customSurcharge1 : customSurcharge1 ,customSurcharge2: null == customSurcharge2 ? _self.customSurcharge2 : customSurcharge2 ,customSurcharge3: null == customSurcharge3 ? _self.customSurcharge3 : customSurcharge3 ,customSurcharge4: null == customSurcharge4 ? _self.customSurcharge4 : customSurcharge4 ,customTaxes1: null == customTaxes1 ? _self.customTaxes1 : customTaxes1 // ignore: cast_nullable_to_non_nullable
as bool,customTaxes2: null == customTaxes2 ? _self.customTaxes2 : customTaxes2 // ignore: cast_nullable_to_non_nullable
as bool,customTaxes3: null == customTaxes3 ? _self.customTaxes3 : customTaxes3 // ignore: cast_nullable_to_non_nullable
as bool,customTaxes4: null == customTaxes4 ? _self.customTaxes4 : customTaxes4 // ignore: cast_nullable_to_non_nullable
as bool,publicNotes: null == publicNotes ? _self.publicNotes : publicNotes // ignore: cast_nullable_to_non_nullable
as String,privateNotes: null == privateNotes ? _self.privateNotes : privateNotes // ignore: cast_nullable_to_non_nullable
as String,terms: null == terms ? _self.terms : terms // ignore: cast_nullable_to_non_nullable
as String,footer: null == footer ? _self.footer : footer // ignore: cast_nullable_to_non_nullable
as String,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,lineItems: null == lineItems ? _self._lineItems : lineItems // ignore: cast_nullable_to_non_nullable
as List<LineItemApi>,invitations: null == invitations ? _self._invitations : invitations // ignore: cast_nullable_to_non_nullable
as List<InvitationApi>,documents: freezed == documents ? _self._documents : documents // ignore: cast_nullable_to_non_nullable
as List<DocumentApi>?,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagRefApi>,reminder1Sent: null == reminder1Sent ? _self.reminder1Sent : reminder1Sent // ignore: cast_nullable_to_non_nullable
as String,reminder2Sent: null == reminder2Sent ? _self.reminder2Sent : reminder2Sent // ignore: cast_nullable_to_non_nullable
as String,reminder3Sent: null == reminder3Sent ? _self.reminder3Sent : reminder3Sent // ignore: cast_nullable_to_non_nullable
as String,reminderLastSent: null == reminderLastSent ? _self.reminderLastSent : reminderLastSent // ignore: cast_nullable_to_non_nullable
as String,reminderSchedule: null == reminderSchedule ? _self.reminderSchedule : reminderSchedule // ignore: cast_nullable_to_non_nullable
as String,frequencyId: null == frequencyId ? _self.frequencyId : frequencyId // ignore: cast_nullable_to_non_nullable
as String,nextSendDate: null == nextSendDate ? _self.nextSendDate : nextSendDate // ignore: cast_nullable_to_non_nullable
as String,nextSendDatetime: null == nextSendDatetime ? _self.nextSendDatetime : nextSendDatetime // ignore: cast_nullable_to_non_nullable
as String,lastSentDate: null == lastSentDate ? _self.lastSentDate : lastSentDate // ignore: cast_nullable_to_non_nullable
as String,remainingCycles: null == remainingCycles ? _self.remainingCycles : remainingCycles // ignore: cast_nullable_to_non_nullable
as int,dueDateDays: null == dueDateDays ? _self.dueDateDays : dueDateDays // ignore: cast_nullable_to_non_nullable
as String,autoBill: null == autoBill ? _self.autoBill : autoBill // ignore: cast_nullable_to_non_nullable
as String,autoBillEnabled: null == autoBillEnabled ? _self.autoBillEnabled : autoBillEnabled // ignore: cast_nullable_to_non_nullable
as bool,eInvoice: freezed == eInvoice ? _self._eInvoice : eInvoice // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,backup: freezed == backup ? _self._backup : backup // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,taxInfo: freezed == taxInfo ? _self._taxInfo : taxInfo // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,modifiedInvoiceId: freezed == modifiedInvoiceId ? _self.modifiedInvoiceId : modifiedInvoiceId // ignore: cast_nullable_to_non_nullable
as String?,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,schedule: freezed == schedule ? _self._schedule : schedule // ignore: cast_nullable_to_non_nullable
as List<ScheduleItemApi>?,isLocked: null == isLocked ? _self.isLocked : isLocked // ignore: cast_nullable_to_non_nullable
as bool,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$InvoiceListApi {

@JsonKey(fromJson: _invoiceListData) List<InvoiceApi> get data;
/// Create a copy of InvoiceListApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InvoiceListApiCopyWith<InvoiceListApi> get copyWith => _$InvoiceListApiCopyWithImpl<InvoiceListApi>(this as InvoiceListApi, _$identity);

  /// Serializes this InvoiceListApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InvoiceListApi&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'InvoiceListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $InvoiceListApiCopyWith<$Res>  {
  factory $InvoiceListApiCopyWith(InvoiceListApi value, $Res Function(InvoiceListApi) _then) = _$InvoiceListApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _invoiceListData) List<InvoiceApi> data
});




}
/// @nodoc
class _$InvoiceListApiCopyWithImpl<$Res>
    implements $InvoiceListApiCopyWith<$Res> {
  _$InvoiceListApiCopyWithImpl(this._self, this._then);

  final InvoiceListApi _self;
  final $Res Function(InvoiceListApi) _then;

/// Create a copy of InvoiceListApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<InvoiceApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [InvoiceListApi].
extension InvoiceListApiPatterns on InvoiceListApi {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InvoiceListApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InvoiceListApi() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InvoiceListApi value)  $default,){
final _that = this;
switch (_that) {
case _InvoiceListApi():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InvoiceListApi value)?  $default,){
final _that = this;
switch (_that) {
case _InvoiceListApi() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _invoiceListData)  List<InvoiceApi> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InvoiceListApi() when $default != null:
return $default(_that.data);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _invoiceListData)  List<InvoiceApi> data)  $default,) {final _that = this;
switch (_that) {
case _InvoiceListApi():
return $default(_that.data);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _invoiceListData)  List<InvoiceApi> data)?  $default,) {final _that = this;
switch (_that) {
case _InvoiceListApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InvoiceListApi implements InvoiceListApi {
  const _InvoiceListApi({@JsonKey(fromJson: _invoiceListData) final  List<InvoiceApi> data = const <InvoiceApi>[]}): _data = data;
  factory _InvoiceListApi.fromJson(Map<String, dynamic> json) => _$InvoiceListApiFromJson(json);

 final  List<InvoiceApi> _data;
@override@JsonKey(fromJson: _invoiceListData) List<InvoiceApi> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of InvoiceListApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InvoiceListApiCopyWith<_InvoiceListApi> get copyWith => __$InvoiceListApiCopyWithImpl<_InvoiceListApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InvoiceListApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InvoiceListApi&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'InvoiceListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$InvoiceListApiCopyWith<$Res> implements $InvoiceListApiCopyWith<$Res> {
  factory _$InvoiceListApiCopyWith(_InvoiceListApi value, $Res Function(_InvoiceListApi) _then) = __$InvoiceListApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _invoiceListData) List<InvoiceApi> data
});




}
/// @nodoc
class __$InvoiceListApiCopyWithImpl<$Res>
    implements _$InvoiceListApiCopyWith<$Res> {
  __$InvoiceListApiCopyWithImpl(this._self, this._then);

  final _InvoiceListApi _self;
  final $Res Function(_InvoiceListApi) _then;

/// Create a copy of InvoiceListApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_InvoiceListApi(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<InvoiceApi>,
  ));
}


}


/// @nodoc
mixin _$InvoiceItemApi {

 InvoiceApi get data;
/// Create a copy of InvoiceItemApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InvoiceItemApiCopyWith<InvoiceItemApi> get copyWith => _$InvoiceItemApiCopyWithImpl<InvoiceItemApi>(this as InvoiceItemApi, _$identity);

  /// Serializes this InvoiceItemApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InvoiceItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'InvoiceItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $InvoiceItemApiCopyWith<$Res>  {
  factory $InvoiceItemApiCopyWith(InvoiceItemApi value, $Res Function(InvoiceItemApi) _then) = _$InvoiceItemApiCopyWithImpl;
@useResult
$Res call({
 InvoiceApi data
});


$InvoiceApiCopyWith<$Res> get data;

}
/// @nodoc
class _$InvoiceItemApiCopyWithImpl<$Res>
    implements $InvoiceItemApiCopyWith<$Res> {
  _$InvoiceItemApiCopyWithImpl(this._self, this._then);

  final InvoiceItemApi _self;
  final $Res Function(InvoiceItemApi) _then;

/// Create a copy of InvoiceItemApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as InvoiceApi,
  ));
}
/// Create a copy of InvoiceItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$InvoiceApiCopyWith<$Res> get data {
  
  return $InvoiceApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [InvoiceItemApi].
extension InvoiceItemApiPatterns on InvoiceItemApi {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InvoiceItemApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InvoiceItemApi() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InvoiceItemApi value)  $default,){
final _that = this;
switch (_that) {
case _InvoiceItemApi():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InvoiceItemApi value)?  $default,){
final _that = this;
switch (_that) {
case _InvoiceItemApi() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( InvoiceApi data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InvoiceItemApi() when $default != null:
return $default(_that.data);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( InvoiceApi data)  $default,) {final _that = this;
switch (_that) {
case _InvoiceItemApi():
return $default(_that.data);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( InvoiceApi data)?  $default,) {final _that = this;
switch (_that) {
case _InvoiceItemApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InvoiceItemApi implements InvoiceItemApi {
  const _InvoiceItemApi({required this.data});
  factory _InvoiceItemApi.fromJson(Map<String, dynamic> json) => _$InvoiceItemApiFromJson(json);

@override final  InvoiceApi data;

/// Create a copy of InvoiceItemApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InvoiceItemApiCopyWith<_InvoiceItemApi> get copyWith => __$InvoiceItemApiCopyWithImpl<_InvoiceItemApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InvoiceItemApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InvoiceItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'InvoiceItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$InvoiceItemApiCopyWith<$Res> implements $InvoiceItemApiCopyWith<$Res> {
  factory _$InvoiceItemApiCopyWith(_InvoiceItemApi value, $Res Function(_InvoiceItemApi) _then) = __$InvoiceItemApiCopyWithImpl;
@override @useResult
$Res call({
 InvoiceApi data
});


@override $InvoiceApiCopyWith<$Res> get data;

}
/// @nodoc
class __$InvoiceItemApiCopyWithImpl<$Res>
    implements _$InvoiceItemApiCopyWith<$Res> {
  __$InvoiceItemApiCopyWithImpl(this._self, this._then);

  final _InvoiceItemApi _self;
  final $Res Function(_InvoiceItemApi) _then;

/// Create a copy of InvoiceItemApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_InvoiceItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as InvoiceApi,
  ));
}

/// Create a copy of InvoiceItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$InvoiceApiCopyWith<$Res> get data {
  
  return $InvoiceApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

// dart format on
