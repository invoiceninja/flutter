// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'quote_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$QuoteApi {

 String get id; String get number;@JsonKey(name: 'po_number') String get poNumber; String get date;@JsonKey(name: 'due_date') String get dueDate;@JsonKey(name: 'partial_due_date') String get partialDueDate;// Server-computed, read-only (display only — never sent back).
@JsonKey(name: 'last_sent_date') String get lastSentDate;@JsonKey(name: 'next_send_date') String get nextSendDate;@JsonKey(name: 'status_id') String get statusId;@JsonKey(name: 'client_id') String get clientId;@JsonKey(name: 'vendor_id') String get vendorId;@JsonKey(name: 'project_id') String get projectId;@JsonKey(name: 'design_id') String get designId;@JsonKey(name: 'assigned_user_id') String get assignedUserId;@JsonKey(name: 'user_id') String get userId;@JsonKey(name: 'location_id') String get locationId;@JsonKey(name: 'subscription_id') String get subscriptionId;// The invoice this quote converted to (when status = converted).
@JsonKey(name: 'invoice_id') String get invoiceId; Object get amount; Object get balance;@JsonKey(name: 'total_taxes') Object get totalTaxes; Object get discount;@JsonKey(name: 'partial') Object get partial;@JsonKey(name: 'is_amount_discount') bool get isAmountDiscount;@JsonKey(name: 'exchange_rate') Object get exchangeRate;@JsonKey(name: 'tax_name1') String get taxName1;@JsonKey(name: 'tax_name2') String get taxName2;@JsonKey(name: 'tax_name3') String get taxName3;@JsonKey(name: 'tax_rate1') Object get taxRate1;@JsonKey(name: 'tax_rate2') Object get taxRate2;@JsonKey(name: 'tax_rate3') Object get taxRate3;@JsonKey(name: 'uses_inclusive_taxes') bool get usesInclusiveTaxes;@JsonKey(name: 'custom_surcharge1') Object get customSurcharge1;@JsonKey(name: 'custom_surcharge2') Object get customSurcharge2;@JsonKey(name: 'custom_surcharge3') Object get customSurcharge3;@JsonKey(name: 'custom_surcharge4') Object get customSurcharge4;@JsonKey(name: 'custom_surcharge_tax1') bool get customTaxes1;@JsonKey(name: 'custom_surcharge_tax2') bool get customTaxes2;@JsonKey(name: 'custom_surcharge_tax3') bool get customTaxes3;@JsonKey(name: 'custom_surcharge_tax4') bool get customTaxes4;@JsonKey(name: 'public_notes') String get publicNotes;@JsonKey(name: 'private_notes') String get privateNotes; String get terms; String get footer;@JsonKey(name: 'custom_value1') String get customValue1;@JsonKey(name: 'custom_value2') String get customValue2;@JsonKey(name: 'custom_value3') String get customValue3;@JsonKey(name: 'custom_value4') String get customValue4;@JsonKey(name: 'line_items') List<LineItemApi> get lineItems; List<InvitationApi> get invitations; List<DocumentApi>? get documents;@JsonKey(name: 'tags')@EmbeddedTagsConverter() List<TagRefApi> get tags;@JsonKey(name: 'e_invoice') Map<String, dynamic>? get eInvoice;@JsonKey(name: 'is_deleted') bool get isDeleted;@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt;
/// Create a copy of QuoteApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuoteApiCopyWith<QuoteApi> get copyWith => _$QuoteApiCopyWithImpl<QuoteApi>(this as QuoteApi, _$identity);

  /// Serializes this QuoteApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QuoteApi&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.poNumber, poNumber) || other.poNumber == poNumber)&&(identical(other.date, date) || other.date == date)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.partialDueDate, partialDueDate) || other.partialDueDate == partialDueDate)&&(identical(other.lastSentDate, lastSentDate) || other.lastSentDate == lastSentDate)&&(identical(other.nextSendDate, nextSendDate) || other.nextSendDate == nextSendDate)&&(identical(other.statusId, statusId) || other.statusId == statusId)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.vendorId, vendorId) || other.vendorId == vendorId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.designId, designId) || other.designId == designId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.locationId, locationId) || other.locationId == locationId)&&(identical(other.subscriptionId, subscriptionId) || other.subscriptionId == subscriptionId)&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&const DeepCollectionEquality().equals(other.amount, amount)&&const DeepCollectionEquality().equals(other.balance, balance)&&const DeepCollectionEquality().equals(other.totalTaxes, totalTaxes)&&const DeepCollectionEquality().equals(other.discount, discount)&&const DeepCollectionEquality().equals(other.partial, partial)&&(identical(other.isAmountDiscount, isAmountDiscount) || other.isAmountDiscount == isAmountDiscount)&&const DeepCollectionEquality().equals(other.exchangeRate, exchangeRate)&&(identical(other.taxName1, taxName1) || other.taxName1 == taxName1)&&(identical(other.taxName2, taxName2) || other.taxName2 == taxName2)&&(identical(other.taxName3, taxName3) || other.taxName3 == taxName3)&&const DeepCollectionEquality().equals(other.taxRate1, taxRate1)&&const DeepCollectionEquality().equals(other.taxRate2, taxRate2)&&const DeepCollectionEquality().equals(other.taxRate3, taxRate3)&&(identical(other.usesInclusiveTaxes, usesInclusiveTaxes) || other.usesInclusiveTaxes == usesInclusiveTaxes)&&const DeepCollectionEquality().equals(other.customSurcharge1, customSurcharge1)&&const DeepCollectionEquality().equals(other.customSurcharge2, customSurcharge2)&&const DeepCollectionEquality().equals(other.customSurcharge3, customSurcharge3)&&const DeepCollectionEquality().equals(other.customSurcharge4, customSurcharge4)&&(identical(other.customTaxes1, customTaxes1) || other.customTaxes1 == customTaxes1)&&(identical(other.customTaxes2, customTaxes2) || other.customTaxes2 == customTaxes2)&&(identical(other.customTaxes3, customTaxes3) || other.customTaxes3 == customTaxes3)&&(identical(other.customTaxes4, customTaxes4) || other.customTaxes4 == customTaxes4)&&(identical(other.publicNotes, publicNotes) || other.publicNotes == publicNotes)&&(identical(other.privateNotes, privateNotes) || other.privateNotes == privateNotes)&&(identical(other.terms, terms) || other.terms == terms)&&(identical(other.footer, footer) || other.footer == footer)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&const DeepCollectionEquality().equals(other.lineItems, lineItems)&&const DeepCollectionEquality().equals(other.invitations, invitations)&&const DeepCollectionEquality().equals(other.documents, documents)&&const DeepCollectionEquality().equals(other.tags, tags)&&const DeepCollectionEquality().equals(other.eInvoice, eInvoice)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,number,poNumber,date,dueDate,partialDueDate,lastSentDate,nextSendDate,statusId,clientId,vendorId,projectId,designId,assignedUserId,userId,locationId,subscriptionId,invoiceId,const DeepCollectionEquality().hash(amount),const DeepCollectionEquality().hash(balance),const DeepCollectionEquality().hash(totalTaxes),const DeepCollectionEquality().hash(discount),const DeepCollectionEquality().hash(partial),isAmountDiscount,const DeepCollectionEquality().hash(exchangeRate),taxName1,taxName2,taxName3,const DeepCollectionEquality().hash(taxRate1),const DeepCollectionEquality().hash(taxRate2),const DeepCollectionEquality().hash(taxRate3),usesInclusiveTaxes,const DeepCollectionEquality().hash(customSurcharge1),const DeepCollectionEquality().hash(customSurcharge2),const DeepCollectionEquality().hash(customSurcharge3),const DeepCollectionEquality().hash(customSurcharge4),customTaxes1,customTaxes2,customTaxes3,customTaxes4,publicNotes,privateNotes,terms,footer,customValue1,customValue2,customValue3,customValue4,const DeepCollectionEquality().hash(lineItems),const DeepCollectionEquality().hash(invitations),const DeepCollectionEquality().hash(documents),const DeepCollectionEquality().hash(tags),const DeepCollectionEquality().hash(eInvoice),isDeleted,createdAt,updatedAt,archivedAt]);

@override
String toString() {
  return 'QuoteApi(id: $id, number: $number, poNumber: $poNumber, date: $date, dueDate: $dueDate, partialDueDate: $partialDueDate, lastSentDate: $lastSentDate, nextSendDate: $nextSendDate, statusId: $statusId, clientId: $clientId, vendorId: $vendorId, projectId: $projectId, designId: $designId, assignedUserId: $assignedUserId, userId: $userId, locationId: $locationId, subscriptionId: $subscriptionId, invoiceId: $invoiceId, amount: $amount, balance: $balance, totalTaxes: $totalTaxes, discount: $discount, partial: $partial, isAmountDiscount: $isAmountDiscount, exchangeRate: $exchangeRate, taxName1: $taxName1, taxName2: $taxName2, taxName3: $taxName3, taxRate1: $taxRate1, taxRate2: $taxRate2, taxRate3: $taxRate3, usesInclusiveTaxes: $usesInclusiveTaxes, customSurcharge1: $customSurcharge1, customSurcharge2: $customSurcharge2, customSurcharge3: $customSurcharge3, customSurcharge4: $customSurcharge4, customTaxes1: $customTaxes1, customTaxes2: $customTaxes2, customTaxes3: $customTaxes3, customTaxes4: $customTaxes4, publicNotes: $publicNotes, privateNotes: $privateNotes, terms: $terms, footer: $footer, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, lineItems: $lineItems, invitations: $invitations, documents: $documents, tags: $tags, eInvoice: $eInvoice, isDeleted: $isDeleted, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt)';
}


}

/// @nodoc
abstract mixin class $QuoteApiCopyWith<$Res>  {
  factory $QuoteApiCopyWith(QuoteApi value, $Res Function(QuoteApi) _then) = _$QuoteApiCopyWithImpl;
@useResult
$Res call({
 String id, String number,@JsonKey(name: 'po_number') String poNumber, String date,@JsonKey(name: 'due_date') String dueDate,@JsonKey(name: 'partial_due_date') String partialDueDate,@JsonKey(name: 'last_sent_date') String lastSentDate,@JsonKey(name: 'next_send_date') String nextSendDate,@JsonKey(name: 'status_id') String statusId,@JsonKey(name: 'client_id') String clientId,@JsonKey(name: 'vendor_id') String vendorId,@JsonKey(name: 'project_id') String projectId,@JsonKey(name: 'design_id') String designId,@JsonKey(name: 'assigned_user_id') String assignedUserId,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'location_id') String locationId,@JsonKey(name: 'subscription_id') String subscriptionId,@JsonKey(name: 'invoice_id') String invoiceId, Object amount, Object balance,@JsonKey(name: 'total_taxes') Object totalTaxes, Object discount,@JsonKey(name: 'partial') Object partial,@JsonKey(name: 'is_amount_discount') bool isAmountDiscount,@JsonKey(name: 'exchange_rate') Object exchangeRate,@JsonKey(name: 'tax_name1') String taxName1,@JsonKey(name: 'tax_name2') String taxName2,@JsonKey(name: 'tax_name3') String taxName3,@JsonKey(name: 'tax_rate1') Object taxRate1,@JsonKey(name: 'tax_rate2') Object taxRate2,@JsonKey(name: 'tax_rate3') Object taxRate3,@JsonKey(name: 'uses_inclusive_taxes') bool usesInclusiveTaxes,@JsonKey(name: 'custom_surcharge1') Object customSurcharge1,@JsonKey(name: 'custom_surcharge2') Object customSurcharge2,@JsonKey(name: 'custom_surcharge3') Object customSurcharge3,@JsonKey(name: 'custom_surcharge4') Object customSurcharge4,@JsonKey(name: 'custom_surcharge_tax1') bool customTaxes1,@JsonKey(name: 'custom_surcharge_tax2') bool customTaxes2,@JsonKey(name: 'custom_surcharge_tax3') bool customTaxes3,@JsonKey(name: 'custom_surcharge_tax4') bool customTaxes4,@JsonKey(name: 'public_notes') String publicNotes,@JsonKey(name: 'private_notes') String privateNotes, String terms, String footer,@JsonKey(name: 'custom_value1') String customValue1,@JsonKey(name: 'custom_value2') String customValue2,@JsonKey(name: 'custom_value3') String customValue3,@JsonKey(name: 'custom_value4') String customValue4,@JsonKey(name: 'line_items') List<LineItemApi> lineItems, List<InvitationApi> invitations, List<DocumentApi>? documents,@JsonKey(name: 'tags')@EmbeddedTagsConverter() List<TagRefApi> tags,@JsonKey(name: 'e_invoice') Map<String, dynamic>? eInvoice,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt
});




}
/// @nodoc
class _$QuoteApiCopyWithImpl<$Res>
    implements $QuoteApiCopyWith<$Res> {
  _$QuoteApiCopyWithImpl(this._self, this._then);

  final QuoteApi _self;
  final $Res Function(QuoteApi) _then;

/// Create a copy of QuoteApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? number = null,Object? poNumber = null,Object? date = null,Object? dueDate = null,Object? partialDueDate = null,Object? lastSentDate = null,Object? nextSendDate = null,Object? statusId = null,Object? clientId = null,Object? vendorId = null,Object? projectId = null,Object? designId = null,Object? assignedUserId = null,Object? userId = null,Object? locationId = null,Object? subscriptionId = null,Object? invoiceId = null,Object? amount = null,Object? balance = null,Object? totalTaxes = null,Object? discount = null,Object? partial = null,Object? isAmountDiscount = null,Object? exchangeRate = null,Object? taxName1 = null,Object? taxName2 = null,Object? taxName3 = null,Object? taxRate1 = null,Object? taxRate2 = null,Object? taxRate3 = null,Object? usesInclusiveTaxes = null,Object? customSurcharge1 = null,Object? customSurcharge2 = null,Object? customSurcharge3 = null,Object? customSurcharge4 = null,Object? customTaxes1 = null,Object? customTaxes2 = null,Object? customTaxes3 = null,Object? customTaxes4 = null,Object? publicNotes = null,Object? privateNotes = null,Object? terms = null,Object? footer = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? lineItems = null,Object? invitations = null,Object? documents = freezed,Object? tags = null,Object? eInvoice = freezed,Object? isDeleted = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,poNumber: null == poNumber ? _self.poNumber : poNumber // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,dueDate: null == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as String,partialDueDate: null == partialDueDate ? _self.partialDueDate : partialDueDate // ignore: cast_nullable_to_non_nullable
as String,lastSentDate: null == lastSentDate ? _self.lastSentDate : lastSentDate // ignore: cast_nullable_to_non_nullable
as String,nextSendDate: null == nextSendDate ? _self.nextSendDate : nextSendDate // ignore: cast_nullable_to_non_nullable
as String,statusId: null == statusId ? _self.statusId : statusId // ignore: cast_nullable_to_non_nullable
as String,clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,vendorId: null == vendorId ? _self.vendorId : vendorId // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,designId: null == designId ? _self.designId : designId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,locationId: null == locationId ? _self.locationId : locationId // ignore: cast_nullable_to_non_nullable
as String,subscriptionId: null == subscriptionId ? _self.subscriptionId : subscriptionId // ignore: cast_nullable_to_non_nullable
as String,invoiceId: null == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount ,balance: null == balance ? _self.balance : balance ,totalTaxes: null == totalTaxes ? _self.totalTaxes : totalTaxes ,discount: null == discount ? _self.discount : discount ,partial: null == partial ? _self.partial : partial ,isAmountDiscount: null == isAmountDiscount ? _self.isAmountDiscount : isAmountDiscount // ignore: cast_nullable_to_non_nullable
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
as List<TagRefApi>,eInvoice: freezed == eInvoice ? _self.eInvoice : eInvoice // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [QuoteApi].
extension QuoteApiPatterns on QuoteApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _QuoteApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _QuoteApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _QuoteApi value)  $default,){
final _that = this;
switch (_that) {
case _QuoteApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _QuoteApi value)?  $default,){
final _that = this;
switch (_that) {
case _QuoteApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String number, @JsonKey(name: 'po_number')  String poNumber,  String date, @JsonKey(name: 'due_date')  String dueDate, @JsonKey(name: 'partial_due_date')  String partialDueDate, @JsonKey(name: 'last_sent_date')  String lastSentDate, @JsonKey(name: 'next_send_date')  String nextSendDate, @JsonKey(name: 'status_id')  String statusId, @JsonKey(name: 'client_id')  String clientId, @JsonKey(name: 'vendor_id')  String vendorId, @JsonKey(name: 'project_id')  String projectId, @JsonKey(name: 'design_id')  String designId, @JsonKey(name: 'assigned_user_id')  String assignedUserId, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'location_id')  String locationId, @JsonKey(name: 'subscription_id')  String subscriptionId, @JsonKey(name: 'invoice_id')  String invoiceId,  Object amount,  Object balance, @JsonKey(name: 'total_taxes')  Object totalTaxes,  Object discount, @JsonKey(name: 'partial')  Object partial, @JsonKey(name: 'is_amount_discount')  bool isAmountDiscount, @JsonKey(name: 'exchange_rate')  Object exchangeRate, @JsonKey(name: 'tax_name1')  String taxName1, @JsonKey(name: 'tax_name2')  String taxName2, @JsonKey(name: 'tax_name3')  String taxName3, @JsonKey(name: 'tax_rate1')  Object taxRate1, @JsonKey(name: 'tax_rate2')  Object taxRate2, @JsonKey(name: 'tax_rate3')  Object taxRate3, @JsonKey(name: 'uses_inclusive_taxes')  bool usesInclusiveTaxes, @JsonKey(name: 'custom_surcharge1')  Object customSurcharge1, @JsonKey(name: 'custom_surcharge2')  Object customSurcharge2, @JsonKey(name: 'custom_surcharge3')  Object customSurcharge3, @JsonKey(name: 'custom_surcharge4')  Object customSurcharge4, @JsonKey(name: 'custom_surcharge_tax1')  bool customTaxes1, @JsonKey(name: 'custom_surcharge_tax2')  bool customTaxes2, @JsonKey(name: 'custom_surcharge_tax3')  bool customTaxes3, @JsonKey(name: 'custom_surcharge_tax4')  bool customTaxes4, @JsonKey(name: 'public_notes')  String publicNotes, @JsonKey(name: 'private_notes')  String privateNotes,  String terms,  String footer, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'line_items')  List<LineItemApi> lineItems,  List<InvitationApi> invitations,  List<DocumentApi>? documents, @JsonKey(name: 'tags')@EmbeddedTagsConverter()  List<TagRefApi> tags, @JsonKey(name: 'e_invoice')  Map<String, dynamic>? eInvoice, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _QuoteApi() when $default != null:
return $default(_that.id,_that.number,_that.poNumber,_that.date,_that.dueDate,_that.partialDueDate,_that.lastSentDate,_that.nextSendDate,_that.statusId,_that.clientId,_that.vendorId,_that.projectId,_that.designId,_that.assignedUserId,_that.userId,_that.locationId,_that.subscriptionId,_that.invoiceId,_that.amount,_that.balance,_that.totalTaxes,_that.discount,_that.partial,_that.isAmountDiscount,_that.exchangeRate,_that.taxName1,_that.taxName2,_that.taxName3,_that.taxRate1,_that.taxRate2,_that.taxRate3,_that.usesInclusiveTaxes,_that.customSurcharge1,_that.customSurcharge2,_that.customSurcharge3,_that.customSurcharge4,_that.customTaxes1,_that.customTaxes2,_that.customTaxes3,_that.customTaxes4,_that.publicNotes,_that.privateNotes,_that.terms,_that.footer,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.lineItems,_that.invitations,_that.documents,_that.tags,_that.eInvoice,_that.isDeleted,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String number, @JsonKey(name: 'po_number')  String poNumber,  String date, @JsonKey(name: 'due_date')  String dueDate, @JsonKey(name: 'partial_due_date')  String partialDueDate, @JsonKey(name: 'last_sent_date')  String lastSentDate, @JsonKey(name: 'next_send_date')  String nextSendDate, @JsonKey(name: 'status_id')  String statusId, @JsonKey(name: 'client_id')  String clientId, @JsonKey(name: 'vendor_id')  String vendorId, @JsonKey(name: 'project_id')  String projectId, @JsonKey(name: 'design_id')  String designId, @JsonKey(name: 'assigned_user_id')  String assignedUserId, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'location_id')  String locationId, @JsonKey(name: 'subscription_id')  String subscriptionId, @JsonKey(name: 'invoice_id')  String invoiceId,  Object amount,  Object balance, @JsonKey(name: 'total_taxes')  Object totalTaxes,  Object discount, @JsonKey(name: 'partial')  Object partial, @JsonKey(name: 'is_amount_discount')  bool isAmountDiscount, @JsonKey(name: 'exchange_rate')  Object exchangeRate, @JsonKey(name: 'tax_name1')  String taxName1, @JsonKey(name: 'tax_name2')  String taxName2, @JsonKey(name: 'tax_name3')  String taxName3, @JsonKey(name: 'tax_rate1')  Object taxRate1, @JsonKey(name: 'tax_rate2')  Object taxRate2, @JsonKey(name: 'tax_rate3')  Object taxRate3, @JsonKey(name: 'uses_inclusive_taxes')  bool usesInclusiveTaxes, @JsonKey(name: 'custom_surcharge1')  Object customSurcharge1, @JsonKey(name: 'custom_surcharge2')  Object customSurcharge2, @JsonKey(name: 'custom_surcharge3')  Object customSurcharge3, @JsonKey(name: 'custom_surcharge4')  Object customSurcharge4, @JsonKey(name: 'custom_surcharge_tax1')  bool customTaxes1, @JsonKey(name: 'custom_surcharge_tax2')  bool customTaxes2, @JsonKey(name: 'custom_surcharge_tax3')  bool customTaxes3, @JsonKey(name: 'custom_surcharge_tax4')  bool customTaxes4, @JsonKey(name: 'public_notes')  String publicNotes, @JsonKey(name: 'private_notes')  String privateNotes,  String terms,  String footer, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'line_items')  List<LineItemApi> lineItems,  List<InvitationApi> invitations,  List<DocumentApi>? documents, @JsonKey(name: 'tags')@EmbeddedTagsConverter()  List<TagRefApi> tags, @JsonKey(name: 'e_invoice')  Map<String, dynamic>? eInvoice, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)  $default,) {final _that = this;
switch (_that) {
case _QuoteApi():
return $default(_that.id,_that.number,_that.poNumber,_that.date,_that.dueDate,_that.partialDueDate,_that.lastSentDate,_that.nextSendDate,_that.statusId,_that.clientId,_that.vendorId,_that.projectId,_that.designId,_that.assignedUserId,_that.userId,_that.locationId,_that.subscriptionId,_that.invoiceId,_that.amount,_that.balance,_that.totalTaxes,_that.discount,_that.partial,_that.isAmountDiscount,_that.exchangeRate,_that.taxName1,_that.taxName2,_that.taxName3,_that.taxRate1,_that.taxRate2,_that.taxRate3,_that.usesInclusiveTaxes,_that.customSurcharge1,_that.customSurcharge2,_that.customSurcharge3,_that.customSurcharge4,_that.customTaxes1,_that.customTaxes2,_that.customTaxes3,_that.customTaxes4,_that.publicNotes,_that.privateNotes,_that.terms,_that.footer,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.lineItems,_that.invitations,_that.documents,_that.tags,_that.eInvoice,_that.isDeleted,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String number, @JsonKey(name: 'po_number')  String poNumber,  String date, @JsonKey(name: 'due_date')  String dueDate, @JsonKey(name: 'partial_due_date')  String partialDueDate, @JsonKey(name: 'last_sent_date')  String lastSentDate, @JsonKey(name: 'next_send_date')  String nextSendDate, @JsonKey(name: 'status_id')  String statusId, @JsonKey(name: 'client_id')  String clientId, @JsonKey(name: 'vendor_id')  String vendorId, @JsonKey(name: 'project_id')  String projectId, @JsonKey(name: 'design_id')  String designId, @JsonKey(name: 'assigned_user_id')  String assignedUserId, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'location_id')  String locationId, @JsonKey(name: 'subscription_id')  String subscriptionId, @JsonKey(name: 'invoice_id')  String invoiceId,  Object amount,  Object balance, @JsonKey(name: 'total_taxes')  Object totalTaxes,  Object discount, @JsonKey(name: 'partial')  Object partial, @JsonKey(name: 'is_amount_discount')  bool isAmountDiscount, @JsonKey(name: 'exchange_rate')  Object exchangeRate, @JsonKey(name: 'tax_name1')  String taxName1, @JsonKey(name: 'tax_name2')  String taxName2, @JsonKey(name: 'tax_name3')  String taxName3, @JsonKey(name: 'tax_rate1')  Object taxRate1, @JsonKey(name: 'tax_rate2')  Object taxRate2, @JsonKey(name: 'tax_rate3')  Object taxRate3, @JsonKey(name: 'uses_inclusive_taxes')  bool usesInclusiveTaxes, @JsonKey(name: 'custom_surcharge1')  Object customSurcharge1, @JsonKey(name: 'custom_surcharge2')  Object customSurcharge2, @JsonKey(name: 'custom_surcharge3')  Object customSurcharge3, @JsonKey(name: 'custom_surcharge4')  Object customSurcharge4, @JsonKey(name: 'custom_surcharge_tax1')  bool customTaxes1, @JsonKey(name: 'custom_surcharge_tax2')  bool customTaxes2, @JsonKey(name: 'custom_surcharge_tax3')  bool customTaxes3, @JsonKey(name: 'custom_surcharge_tax4')  bool customTaxes4, @JsonKey(name: 'public_notes')  String publicNotes, @JsonKey(name: 'private_notes')  String privateNotes,  String terms,  String footer, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'line_items')  List<LineItemApi> lineItems,  List<InvitationApi> invitations,  List<DocumentApi>? documents, @JsonKey(name: 'tags')@EmbeddedTagsConverter()  List<TagRefApi> tags, @JsonKey(name: 'e_invoice')  Map<String, dynamic>? eInvoice, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)?  $default,) {final _that = this;
switch (_that) {
case _QuoteApi() when $default != null:
return $default(_that.id,_that.number,_that.poNumber,_that.date,_that.dueDate,_that.partialDueDate,_that.lastSentDate,_that.nextSendDate,_that.statusId,_that.clientId,_that.vendorId,_that.projectId,_that.designId,_that.assignedUserId,_that.userId,_that.locationId,_that.subscriptionId,_that.invoiceId,_that.amount,_that.balance,_that.totalTaxes,_that.discount,_that.partial,_that.isAmountDiscount,_that.exchangeRate,_that.taxName1,_that.taxName2,_that.taxName3,_that.taxRate1,_that.taxRate2,_that.taxRate3,_that.usesInclusiveTaxes,_that.customSurcharge1,_that.customSurcharge2,_that.customSurcharge3,_that.customSurcharge4,_that.customTaxes1,_that.customTaxes2,_that.customTaxes3,_that.customTaxes4,_that.publicNotes,_that.privateNotes,_that.terms,_that.footer,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.lineItems,_that.invitations,_that.documents,_that.tags,_that.eInvoice,_that.isDeleted,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _QuoteApi implements QuoteApi {
  const _QuoteApi({this.id = '', this.number = '', @JsonKey(name: 'po_number') this.poNumber = '', this.date = '', @JsonKey(name: 'due_date') this.dueDate = '', @JsonKey(name: 'partial_due_date') this.partialDueDate = '', @JsonKey(name: 'last_sent_date') this.lastSentDate = '', @JsonKey(name: 'next_send_date') this.nextSendDate = '', @JsonKey(name: 'status_id') this.statusId = '1', @JsonKey(name: 'client_id') this.clientId = '', @JsonKey(name: 'vendor_id') this.vendorId = '', @JsonKey(name: 'project_id') this.projectId = '', @JsonKey(name: 'design_id') this.designId = '', @JsonKey(name: 'assigned_user_id') this.assignedUserId = '', @JsonKey(name: 'user_id') this.userId = '', @JsonKey(name: 'location_id') this.locationId = '', @JsonKey(name: 'subscription_id') this.subscriptionId = '', @JsonKey(name: 'invoice_id') this.invoiceId = '', this.amount = '0', this.balance = '0', @JsonKey(name: 'total_taxes') this.totalTaxes = '0', this.discount = '0', @JsonKey(name: 'partial') this.partial = '0', @JsonKey(name: 'is_amount_discount') this.isAmountDiscount = false, @JsonKey(name: 'exchange_rate') this.exchangeRate = '1', @JsonKey(name: 'tax_name1') this.taxName1 = '', @JsonKey(name: 'tax_name2') this.taxName2 = '', @JsonKey(name: 'tax_name3') this.taxName3 = '', @JsonKey(name: 'tax_rate1') this.taxRate1 = '0', @JsonKey(name: 'tax_rate2') this.taxRate2 = '0', @JsonKey(name: 'tax_rate3') this.taxRate3 = '0', @JsonKey(name: 'uses_inclusive_taxes') this.usesInclusiveTaxes = false, @JsonKey(name: 'custom_surcharge1') this.customSurcharge1 = '0', @JsonKey(name: 'custom_surcharge2') this.customSurcharge2 = '0', @JsonKey(name: 'custom_surcharge3') this.customSurcharge3 = '0', @JsonKey(name: 'custom_surcharge4') this.customSurcharge4 = '0', @JsonKey(name: 'custom_surcharge_tax1') this.customTaxes1 = false, @JsonKey(name: 'custom_surcharge_tax2') this.customTaxes2 = false, @JsonKey(name: 'custom_surcharge_tax3') this.customTaxes3 = false, @JsonKey(name: 'custom_surcharge_tax4') this.customTaxes4 = false, @JsonKey(name: 'public_notes') this.publicNotes = '', @JsonKey(name: 'private_notes') this.privateNotes = '', this.terms = '', this.footer = '', @JsonKey(name: 'custom_value1') this.customValue1 = '', @JsonKey(name: 'custom_value2') this.customValue2 = '', @JsonKey(name: 'custom_value3') this.customValue3 = '', @JsonKey(name: 'custom_value4') this.customValue4 = '', @JsonKey(name: 'line_items') final  List<LineItemApi> lineItems = const <LineItemApi>[], final  List<InvitationApi> invitations = const <InvitationApi>[], final  List<DocumentApi>? documents, @JsonKey(name: 'tags')@EmbeddedTagsConverter() final  List<TagRefApi> tags = const <TagRefApi>[], @JsonKey(name: 'e_invoice') final  Map<String, dynamic>? eInvoice, @JsonKey(name: 'is_deleted') this.isDeleted = false, @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0}): _lineItems = lineItems,_invitations = invitations,_documents = documents,_tags = tags,_eInvoice = eInvoice;
  factory _QuoteApi.fromJson(Map<String, dynamic> json) => _$QuoteApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey() final  String number;
@override@JsonKey(name: 'po_number') final  String poNumber;
@override@JsonKey() final  String date;
@override@JsonKey(name: 'due_date') final  String dueDate;
@override@JsonKey(name: 'partial_due_date') final  String partialDueDate;
// Server-computed, read-only (display only — never sent back).
@override@JsonKey(name: 'last_sent_date') final  String lastSentDate;
@override@JsonKey(name: 'next_send_date') final  String nextSendDate;
@override@JsonKey(name: 'status_id') final  String statusId;
@override@JsonKey(name: 'client_id') final  String clientId;
@override@JsonKey(name: 'vendor_id') final  String vendorId;
@override@JsonKey(name: 'project_id') final  String projectId;
@override@JsonKey(name: 'design_id') final  String designId;
@override@JsonKey(name: 'assigned_user_id') final  String assignedUserId;
@override@JsonKey(name: 'user_id') final  String userId;
@override@JsonKey(name: 'location_id') final  String locationId;
@override@JsonKey(name: 'subscription_id') final  String subscriptionId;
// The invoice this quote converted to (when status = converted).
@override@JsonKey(name: 'invoice_id') final  String invoiceId;
@override@JsonKey() final  Object amount;
@override@JsonKey() final  Object balance;
@override@JsonKey(name: 'total_taxes') final  Object totalTaxes;
@override@JsonKey() final  Object discount;
@override@JsonKey(name: 'partial') final  Object partial;
@override@JsonKey(name: 'is_amount_discount') final  bool isAmountDiscount;
@override@JsonKey(name: 'exchange_rate') final  Object exchangeRate;
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
@override@JsonKey(name: 'public_notes') final  String publicNotes;
@override@JsonKey(name: 'private_notes') final  String privateNotes;
@override@JsonKey() final  String terms;
@override@JsonKey() final  String footer;
@override@JsonKey(name: 'custom_value1') final  String customValue1;
@override@JsonKey(name: 'custom_value2') final  String customValue2;
@override@JsonKey(name: 'custom_value3') final  String customValue3;
@override@JsonKey(name: 'custom_value4') final  String customValue4;
 final  List<LineItemApi> _lineItems;
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

 final  List<DocumentApi>? _documents;
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

 final  Map<String, dynamic>? _eInvoice;
@override@JsonKey(name: 'e_invoice') Map<String, dynamic>? get eInvoice {
  final value = _eInvoice;
  if (value == null) return null;
  if (_eInvoice is EqualUnmodifiableMapView) return _eInvoice;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override@JsonKey(name: 'is_deleted') final  bool isDeleted;
@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'archived_at') final  int archivedAt;

/// Create a copy of QuoteApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QuoteApiCopyWith<_QuoteApi> get copyWith => __$QuoteApiCopyWithImpl<_QuoteApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QuoteApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QuoteApi&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.poNumber, poNumber) || other.poNumber == poNumber)&&(identical(other.date, date) || other.date == date)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.partialDueDate, partialDueDate) || other.partialDueDate == partialDueDate)&&(identical(other.lastSentDate, lastSentDate) || other.lastSentDate == lastSentDate)&&(identical(other.nextSendDate, nextSendDate) || other.nextSendDate == nextSendDate)&&(identical(other.statusId, statusId) || other.statusId == statusId)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.vendorId, vendorId) || other.vendorId == vendorId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.designId, designId) || other.designId == designId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.locationId, locationId) || other.locationId == locationId)&&(identical(other.subscriptionId, subscriptionId) || other.subscriptionId == subscriptionId)&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&const DeepCollectionEquality().equals(other.amount, amount)&&const DeepCollectionEquality().equals(other.balance, balance)&&const DeepCollectionEquality().equals(other.totalTaxes, totalTaxes)&&const DeepCollectionEquality().equals(other.discount, discount)&&const DeepCollectionEquality().equals(other.partial, partial)&&(identical(other.isAmountDiscount, isAmountDiscount) || other.isAmountDiscount == isAmountDiscount)&&const DeepCollectionEquality().equals(other.exchangeRate, exchangeRate)&&(identical(other.taxName1, taxName1) || other.taxName1 == taxName1)&&(identical(other.taxName2, taxName2) || other.taxName2 == taxName2)&&(identical(other.taxName3, taxName3) || other.taxName3 == taxName3)&&const DeepCollectionEquality().equals(other.taxRate1, taxRate1)&&const DeepCollectionEquality().equals(other.taxRate2, taxRate2)&&const DeepCollectionEquality().equals(other.taxRate3, taxRate3)&&(identical(other.usesInclusiveTaxes, usesInclusiveTaxes) || other.usesInclusiveTaxes == usesInclusiveTaxes)&&const DeepCollectionEquality().equals(other.customSurcharge1, customSurcharge1)&&const DeepCollectionEquality().equals(other.customSurcharge2, customSurcharge2)&&const DeepCollectionEquality().equals(other.customSurcharge3, customSurcharge3)&&const DeepCollectionEquality().equals(other.customSurcharge4, customSurcharge4)&&(identical(other.customTaxes1, customTaxes1) || other.customTaxes1 == customTaxes1)&&(identical(other.customTaxes2, customTaxes2) || other.customTaxes2 == customTaxes2)&&(identical(other.customTaxes3, customTaxes3) || other.customTaxes3 == customTaxes3)&&(identical(other.customTaxes4, customTaxes4) || other.customTaxes4 == customTaxes4)&&(identical(other.publicNotes, publicNotes) || other.publicNotes == publicNotes)&&(identical(other.privateNotes, privateNotes) || other.privateNotes == privateNotes)&&(identical(other.terms, terms) || other.terms == terms)&&(identical(other.footer, footer) || other.footer == footer)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&const DeepCollectionEquality().equals(other._lineItems, _lineItems)&&const DeepCollectionEquality().equals(other._invitations, _invitations)&&const DeepCollectionEquality().equals(other._documents, _documents)&&const DeepCollectionEquality().equals(other._tags, _tags)&&const DeepCollectionEquality().equals(other._eInvoice, _eInvoice)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,number,poNumber,date,dueDate,partialDueDate,lastSentDate,nextSendDate,statusId,clientId,vendorId,projectId,designId,assignedUserId,userId,locationId,subscriptionId,invoiceId,const DeepCollectionEquality().hash(amount),const DeepCollectionEquality().hash(balance),const DeepCollectionEquality().hash(totalTaxes),const DeepCollectionEquality().hash(discount),const DeepCollectionEquality().hash(partial),isAmountDiscount,const DeepCollectionEquality().hash(exchangeRate),taxName1,taxName2,taxName3,const DeepCollectionEquality().hash(taxRate1),const DeepCollectionEquality().hash(taxRate2),const DeepCollectionEquality().hash(taxRate3),usesInclusiveTaxes,const DeepCollectionEquality().hash(customSurcharge1),const DeepCollectionEquality().hash(customSurcharge2),const DeepCollectionEquality().hash(customSurcharge3),const DeepCollectionEquality().hash(customSurcharge4),customTaxes1,customTaxes2,customTaxes3,customTaxes4,publicNotes,privateNotes,terms,footer,customValue1,customValue2,customValue3,customValue4,const DeepCollectionEquality().hash(_lineItems),const DeepCollectionEquality().hash(_invitations),const DeepCollectionEquality().hash(_documents),const DeepCollectionEquality().hash(_tags),const DeepCollectionEquality().hash(_eInvoice),isDeleted,createdAt,updatedAt,archivedAt]);

@override
String toString() {
  return 'QuoteApi(id: $id, number: $number, poNumber: $poNumber, date: $date, dueDate: $dueDate, partialDueDate: $partialDueDate, lastSentDate: $lastSentDate, nextSendDate: $nextSendDate, statusId: $statusId, clientId: $clientId, vendorId: $vendorId, projectId: $projectId, designId: $designId, assignedUserId: $assignedUserId, userId: $userId, locationId: $locationId, subscriptionId: $subscriptionId, invoiceId: $invoiceId, amount: $amount, balance: $balance, totalTaxes: $totalTaxes, discount: $discount, partial: $partial, isAmountDiscount: $isAmountDiscount, exchangeRate: $exchangeRate, taxName1: $taxName1, taxName2: $taxName2, taxName3: $taxName3, taxRate1: $taxRate1, taxRate2: $taxRate2, taxRate3: $taxRate3, usesInclusiveTaxes: $usesInclusiveTaxes, customSurcharge1: $customSurcharge1, customSurcharge2: $customSurcharge2, customSurcharge3: $customSurcharge3, customSurcharge4: $customSurcharge4, customTaxes1: $customTaxes1, customTaxes2: $customTaxes2, customTaxes3: $customTaxes3, customTaxes4: $customTaxes4, publicNotes: $publicNotes, privateNotes: $privateNotes, terms: $terms, footer: $footer, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, lineItems: $lineItems, invitations: $invitations, documents: $documents, tags: $tags, eInvoice: $eInvoice, isDeleted: $isDeleted, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt)';
}


}

/// @nodoc
abstract mixin class _$QuoteApiCopyWith<$Res> implements $QuoteApiCopyWith<$Res> {
  factory _$QuoteApiCopyWith(_QuoteApi value, $Res Function(_QuoteApi) _then) = __$QuoteApiCopyWithImpl;
@override @useResult
$Res call({
 String id, String number,@JsonKey(name: 'po_number') String poNumber, String date,@JsonKey(name: 'due_date') String dueDate,@JsonKey(name: 'partial_due_date') String partialDueDate,@JsonKey(name: 'last_sent_date') String lastSentDate,@JsonKey(name: 'next_send_date') String nextSendDate,@JsonKey(name: 'status_id') String statusId,@JsonKey(name: 'client_id') String clientId,@JsonKey(name: 'vendor_id') String vendorId,@JsonKey(name: 'project_id') String projectId,@JsonKey(name: 'design_id') String designId,@JsonKey(name: 'assigned_user_id') String assignedUserId,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'location_id') String locationId,@JsonKey(name: 'subscription_id') String subscriptionId,@JsonKey(name: 'invoice_id') String invoiceId, Object amount, Object balance,@JsonKey(name: 'total_taxes') Object totalTaxes, Object discount,@JsonKey(name: 'partial') Object partial,@JsonKey(name: 'is_amount_discount') bool isAmountDiscount,@JsonKey(name: 'exchange_rate') Object exchangeRate,@JsonKey(name: 'tax_name1') String taxName1,@JsonKey(name: 'tax_name2') String taxName2,@JsonKey(name: 'tax_name3') String taxName3,@JsonKey(name: 'tax_rate1') Object taxRate1,@JsonKey(name: 'tax_rate2') Object taxRate2,@JsonKey(name: 'tax_rate3') Object taxRate3,@JsonKey(name: 'uses_inclusive_taxes') bool usesInclusiveTaxes,@JsonKey(name: 'custom_surcharge1') Object customSurcharge1,@JsonKey(name: 'custom_surcharge2') Object customSurcharge2,@JsonKey(name: 'custom_surcharge3') Object customSurcharge3,@JsonKey(name: 'custom_surcharge4') Object customSurcharge4,@JsonKey(name: 'custom_surcharge_tax1') bool customTaxes1,@JsonKey(name: 'custom_surcharge_tax2') bool customTaxes2,@JsonKey(name: 'custom_surcharge_tax3') bool customTaxes3,@JsonKey(name: 'custom_surcharge_tax4') bool customTaxes4,@JsonKey(name: 'public_notes') String publicNotes,@JsonKey(name: 'private_notes') String privateNotes, String terms, String footer,@JsonKey(name: 'custom_value1') String customValue1,@JsonKey(name: 'custom_value2') String customValue2,@JsonKey(name: 'custom_value3') String customValue3,@JsonKey(name: 'custom_value4') String customValue4,@JsonKey(name: 'line_items') List<LineItemApi> lineItems, List<InvitationApi> invitations, List<DocumentApi>? documents,@JsonKey(name: 'tags')@EmbeddedTagsConverter() List<TagRefApi> tags,@JsonKey(name: 'e_invoice') Map<String, dynamic>? eInvoice,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt
});




}
/// @nodoc
class __$QuoteApiCopyWithImpl<$Res>
    implements _$QuoteApiCopyWith<$Res> {
  __$QuoteApiCopyWithImpl(this._self, this._then);

  final _QuoteApi _self;
  final $Res Function(_QuoteApi) _then;

/// Create a copy of QuoteApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? number = null,Object? poNumber = null,Object? date = null,Object? dueDate = null,Object? partialDueDate = null,Object? lastSentDate = null,Object? nextSendDate = null,Object? statusId = null,Object? clientId = null,Object? vendorId = null,Object? projectId = null,Object? designId = null,Object? assignedUserId = null,Object? userId = null,Object? locationId = null,Object? subscriptionId = null,Object? invoiceId = null,Object? amount = null,Object? balance = null,Object? totalTaxes = null,Object? discount = null,Object? partial = null,Object? isAmountDiscount = null,Object? exchangeRate = null,Object? taxName1 = null,Object? taxName2 = null,Object? taxName3 = null,Object? taxRate1 = null,Object? taxRate2 = null,Object? taxRate3 = null,Object? usesInclusiveTaxes = null,Object? customSurcharge1 = null,Object? customSurcharge2 = null,Object? customSurcharge3 = null,Object? customSurcharge4 = null,Object? customTaxes1 = null,Object? customTaxes2 = null,Object? customTaxes3 = null,Object? customTaxes4 = null,Object? publicNotes = null,Object? privateNotes = null,Object? terms = null,Object? footer = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? lineItems = null,Object? invitations = null,Object? documents = freezed,Object? tags = null,Object? eInvoice = freezed,Object? isDeleted = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,}) {
  return _then(_QuoteApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,poNumber: null == poNumber ? _self.poNumber : poNumber // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,dueDate: null == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as String,partialDueDate: null == partialDueDate ? _self.partialDueDate : partialDueDate // ignore: cast_nullable_to_non_nullable
as String,lastSentDate: null == lastSentDate ? _self.lastSentDate : lastSentDate // ignore: cast_nullable_to_non_nullable
as String,nextSendDate: null == nextSendDate ? _self.nextSendDate : nextSendDate // ignore: cast_nullable_to_non_nullable
as String,statusId: null == statusId ? _self.statusId : statusId // ignore: cast_nullable_to_non_nullable
as String,clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,vendorId: null == vendorId ? _self.vendorId : vendorId // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,designId: null == designId ? _self.designId : designId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,locationId: null == locationId ? _self.locationId : locationId // ignore: cast_nullable_to_non_nullable
as String,subscriptionId: null == subscriptionId ? _self.subscriptionId : subscriptionId // ignore: cast_nullable_to_non_nullable
as String,invoiceId: null == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount ,balance: null == balance ? _self.balance : balance ,totalTaxes: null == totalTaxes ? _self.totalTaxes : totalTaxes ,discount: null == discount ? _self.discount : discount ,partial: null == partial ? _self.partial : partial ,isAmountDiscount: null == isAmountDiscount ? _self.isAmountDiscount : isAmountDiscount // ignore: cast_nullable_to_non_nullable
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
as List<TagRefApi>,eInvoice: freezed == eInvoice ? _self._eInvoice : eInvoice // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$QuoteListApi {

@JsonKey(fromJson: _quoteListData) List<QuoteApi> get data;
/// Create a copy of QuoteListApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuoteListApiCopyWith<QuoteListApi> get copyWith => _$QuoteListApiCopyWithImpl<QuoteListApi>(this as QuoteListApi, _$identity);

  /// Serializes this QuoteListApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QuoteListApi&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'QuoteListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $QuoteListApiCopyWith<$Res>  {
  factory $QuoteListApiCopyWith(QuoteListApi value, $Res Function(QuoteListApi) _then) = _$QuoteListApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _quoteListData) List<QuoteApi> data
});




}
/// @nodoc
class _$QuoteListApiCopyWithImpl<$Res>
    implements $QuoteListApiCopyWith<$Res> {
  _$QuoteListApiCopyWithImpl(this._self, this._then);

  final QuoteListApi _self;
  final $Res Function(QuoteListApi) _then;

/// Create a copy of QuoteListApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<QuoteApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [QuoteListApi].
extension QuoteListApiPatterns on QuoteListApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _QuoteListApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _QuoteListApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _QuoteListApi value)  $default,){
final _that = this;
switch (_that) {
case _QuoteListApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _QuoteListApi value)?  $default,){
final _that = this;
switch (_that) {
case _QuoteListApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _quoteListData)  List<QuoteApi> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _QuoteListApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _quoteListData)  List<QuoteApi> data)  $default,) {final _that = this;
switch (_that) {
case _QuoteListApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _quoteListData)  List<QuoteApi> data)?  $default,) {final _that = this;
switch (_that) {
case _QuoteListApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _QuoteListApi implements QuoteListApi {
  const _QuoteListApi({@JsonKey(fromJson: _quoteListData) final  List<QuoteApi> data = const <QuoteApi>[]}): _data = data;
  factory _QuoteListApi.fromJson(Map<String, dynamic> json) => _$QuoteListApiFromJson(json);

 final  List<QuoteApi> _data;
@override@JsonKey(fromJson: _quoteListData) List<QuoteApi> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of QuoteListApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QuoteListApiCopyWith<_QuoteListApi> get copyWith => __$QuoteListApiCopyWithImpl<_QuoteListApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QuoteListApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QuoteListApi&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'QuoteListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$QuoteListApiCopyWith<$Res> implements $QuoteListApiCopyWith<$Res> {
  factory _$QuoteListApiCopyWith(_QuoteListApi value, $Res Function(_QuoteListApi) _then) = __$QuoteListApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _quoteListData) List<QuoteApi> data
});




}
/// @nodoc
class __$QuoteListApiCopyWithImpl<$Res>
    implements _$QuoteListApiCopyWith<$Res> {
  __$QuoteListApiCopyWithImpl(this._self, this._then);

  final _QuoteListApi _self;
  final $Res Function(_QuoteListApi) _then;

/// Create a copy of QuoteListApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_QuoteListApi(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<QuoteApi>,
  ));
}


}


/// @nodoc
mixin _$QuoteItemApi {

 QuoteApi get data;
/// Create a copy of QuoteItemApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuoteItemApiCopyWith<QuoteItemApi> get copyWith => _$QuoteItemApiCopyWithImpl<QuoteItemApi>(this as QuoteItemApi, _$identity);

  /// Serializes this QuoteItemApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QuoteItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'QuoteItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $QuoteItemApiCopyWith<$Res>  {
  factory $QuoteItemApiCopyWith(QuoteItemApi value, $Res Function(QuoteItemApi) _then) = _$QuoteItemApiCopyWithImpl;
@useResult
$Res call({
 QuoteApi data
});


$QuoteApiCopyWith<$Res> get data;

}
/// @nodoc
class _$QuoteItemApiCopyWithImpl<$Res>
    implements $QuoteItemApiCopyWith<$Res> {
  _$QuoteItemApiCopyWithImpl(this._self, this._then);

  final QuoteItemApi _self;
  final $Res Function(QuoteItemApi) _then;

/// Create a copy of QuoteItemApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as QuoteApi,
  ));
}
/// Create a copy of QuoteItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$QuoteApiCopyWith<$Res> get data {
  
  return $QuoteApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [QuoteItemApi].
extension QuoteItemApiPatterns on QuoteItemApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _QuoteItemApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _QuoteItemApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _QuoteItemApi value)  $default,){
final _that = this;
switch (_that) {
case _QuoteItemApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _QuoteItemApi value)?  $default,){
final _that = this;
switch (_that) {
case _QuoteItemApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( QuoteApi data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _QuoteItemApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( QuoteApi data)  $default,) {final _that = this;
switch (_that) {
case _QuoteItemApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( QuoteApi data)?  $default,) {final _that = this;
switch (_that) {
case _QuoteItemApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _QuoteItemApi implements QuoteItemApi {
  const _QuoteItemApi({required this.data});
  factory _QuoteItemApi.fromJson(Map<String, dynamic> json) => _$QuoteItemApiFromJson(json);

@override final  QuoteApi data;

/// Create a copy of QuoteItemApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QuoteItemApiCopyWith<_QuoteItemApi> get copyWith => __$QuoteItemApiCopyWithImpl<_QuoteItemApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QuoteItemApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QuoteItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'QuoteItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$QuoteItemApiCopyWith<$Res> implements $QuoteItemApiCopyWith<$Res> {
  factory _$QuoteItemApiCopyWith(_QuoteItemApi value, $Res Function(_QuoteItemApi) _then) = __$QuoteItemApiCopyWithImpl;
@override @useResult
$Res call({
 QuoteApi data
});


@override $QuoteApiCopyWith<$Res> get data;

}
/// @nodoc
class __$QuoteItemApiCopyWithImpl<$Res>
    implements _$QuoteItemApiCopyWith<$Res> {
  __$QuoteItemApiCopyWithImpl(this._self, this._then);

  final _QuoteItemApi _self;
  final $Res Function(_QuoteItemApi) _then;

/// Create a copy of QuoteItemApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_QuoteItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as QuoteApi,
  ));
}

/// Create a copy of QuoteItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$QuoteApiCopyWith<$Res> get data {
  
  return $QuoteApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

// dart format on
