// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'credit_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CreditApi {

 String get id; String get number;@JsonKey(name: 'po_number') String get poNumber; String get date;@JsonKey(name: 'due_date') String get dueDate;@JsonKey(name: 'partial_due_date') String get partialDueDate;@JsonKey(name: 'status_id') String get statusId;@JsonKey(name: 'client_id') String get clientId;@JsonKey(name: 'vendor_id') String get vendorId;@JsonKey(name: 'project_id') String get projectId;@JsonKey(name: 'design_id') String get designId;@JsonKey(name: 'assigned_user_id') String get assignedUserId;@JsonKey(name: 'user_id') String get userId;@JsonKey(name: 'location_id') String get locationId; Object get amount; Object get balance;@JsonKey(name: 'paid_to_date') Object get paidToDate;@JsonKey(name: 'partial') Object get partial;@JsonKey(name: 'total_taxes') Object get totalTaxes; Object get discount;@JsonKey(name: 'is_amount_discount') bool get isAmountDiscount;@JsonKey(name: 'exchange_rate') Object get exchangeRate;@JsonKey(name: 'tax_name1') String get taxName1;@JsonKey(name: 'tax_name2') String get taxName2;@JsonKey(name: 'tax_name3') String get taxName3;@JsonKey(name: 'tax_rate1') Object get taxRate1;@JsonKey(name: 'tax_rate2') Object get taxRate2;@JsonKey(name: 'tax_rate3') Object get taxRate3;@JsonKey(name: 'uses_inclusive_taxes') bool get usesInclusiveTaxes;@JsonKey(name: 'custom_surcharge1') Object get customSurcharge1;@JsonKey(name: 'custom_surcharge2') Object get customSurcharge2;@JsonKey(name: 'custom_surcharge3') Object get customSurcharge3;@JsonKey(name: 'custom_surcharge4') Object get customSurcharge4;@JsonKey(name: 'custom_surcharge_tax1') bool get customTaxes1;@JsonKey(name: 'custom_surcharge_tax2') bool get customTaxes2;@JsonKey(name: 'custom_surcharge_tax3') bool get customTaxes3;@JsonKey(name: 'custom_surcharge_tax4') bool get customTaxes4;@JsonKey(name: 'public_notes') String get publicNotes;@JsonKey(name: 'private_notes') String get privateNotes; String get terms; String get footer;@JsonKey(name: 'custom_value1') String get customValue1;@JsonKey(name: 'custom_value2') String get customValue2;@JsonKey(name: 'custom_value3') String get customValue3;@JsonKey(name: 'custom_value4') String get customValue4;@JsonKey(name: 'line_items') List<LineItemApi> get lineItems; List<InvitationApi> get invitations; List<DocumentApi>? get documents;@JsonKey(name: 'e_invoice') Map<String, dynamic>? get eInvoice;@JsonKey(name: 'is_deleted') bool get isDeleted;@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt;
/// Create a copy of CreditApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CreditApiCopyWith<CreditApi> get copyWith => _$CreditApiCopyWithImpl<CreditApi>(this as CreditApi, _$identity);

  /// Serializes this CreditApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CreditApi&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.poNumber, poNumber) || other.poNumber == poNumber)&&(identical(other.date, date) || other.date == date)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.partialDueDate, partialDueDate) || other.partialDueDate == partialDueDate)&&(identical(other.statusId, statusId) || other.statusId == statusId)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.vendorId, vendorId) || other.vendorId == vendorId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.designId, designId) || other.designId == designId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.locationId, locationId) || other.locationId == locationId)&&const DeepCollectionEquality().equals(other.amount, amount)&&const DeepCollectionEquality().equals(other.balance, balance)&&const DeepCollectionEquality().equals(other.paidToDate, paidToDate)&&const DeepCollectionEquality().equals(other.partial, partial)&&const DeepCollectionEquality().equals(other.totalTaxes, totalTaxes)&&const DeepCollectionEquality().equals(other.discount, discount)&&(identical(other.isAmountDiscount, isAmountDiscount) || other.isAmountDiscount == isAmountDiscount)&&const DeepCollectionEquality().equals(other.exchangeRate, exchangeRate)&&(identical(other.taxName1, taxName1) || other.taxName1 == taxName1)&&(identical(other.taxName2, taxName2) || other.taxName2 == taxName2)&&(identical(other.taxName3, taxName3) || other.taxName3 == taxName3)&&const DeepCollectionEquality().equals(other.taxRate1, taxRate1)&&const DeepCollectionEquality().equals(other.taxRate2, taxRate2)&&const DeepCollectionEquality().equals(other.taxRate3, taxRate3)&&(identical(other.usesInclusiveTaxes, usesInclusiveTaxes) || other.usesInclusiveTaxes == usesInclusiveTaxes)&&const DeepCollectionEquality().equals(other.customSurcharge1, customSurcharge1)&&const DeepCollectionEquality().equals(other.customSurcharge2, customSurcharge2)&&const DeepCollectionEquality().equals(other.customSurcharge3, customSurcharge3)&&const DeepCollectionEquality().equals(other.customSurcharge4, customSurcharge4)&&(identical(other.customTaxes1, customTaxes1) || other.customTaxes1 == customTaxes1)&&(identical(other.customTaxes2, customTaxes2) || other.customTaxes2 == customTaxes2)&&(identical(other.customTaxes3, customTaxes3) || other.customTaxes3 == customTaxes3)&&(identical(other.customTaxes4, customTaxes4) || other.customTaxes4 == customTaxes4)&&(identical(other.publicNotes, publicNotes) || other.publicNotes == publicNotes)&&(identical(other.privateNotes, privateNotes) || other.privateNotes == privateNotes)&&(identical(other.terms, terms) || other.terms == terms)&&(identical(other.footer, footer) || other.footer == footer)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&const DeepCollectionEquality().equals(other.lineItems, lineItems)&&const DeepCollectionEquality().equals(other.invitations, invitations)&&const DeepCollectionEquality().equals(other.documents, documents)&&const DeepCollectionEquality().equals(other.eInvoice, eInvoice)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,number,poNumber,date,dueDate,partialDueDate,statusId,clientId,vendorId,projectId,designId,assignedUserId,userId,locationId,const DeepCollectionEquality().hash(amount),const DeepCollectionEquality().hash(balance),const DeepCollectionEquality().hash(paidToDate),const DeepCollectionEquality().hash(partial),const DeepCollectionEquality().hash(totalTaxes),const DeepCollectionEquality().hash(discount),isAmountDiscount,const DeepCollectionEquality().hash(exchangeRate),taxName1,taxName2,taxName3,const DeepCollectionEquality().hash(taxRate1),const DeepCollectionEquality().hash(taxRate2),const DeepCollectionEquality().hash(taxRate3),usesInclusiveTaxes,const DeepCollectionEquality().hash(customSurcharge1),const DeepCollectionEquality().hash(customSurcharge2),const DeepCollectionEquality().hash(customSurcharge3),const DeepCollectionEquality().hash(customSurcharge4),customTaxes1,customTaxes2,customTaxes3,customTaxes4,publicNotes,privateNotes,terms,footer,customValue1,customValue2,customValue3,customValue4,const DeepCollectionEquality().hash(lineItems),const DeepCollectionEquality().hash(invitations),const DeepCollectionEquality().hash(documents),const DeepCollectionEquality().hash(eInvoice),isDeleted,createdAt,updatedAt,archivedAt]);

@override
String toString() {
  return 'CreditApi(id: $id, number: $number, poNumber: $poNumber, date: $date, dueDate: $dueDate, partialDueDate: $partialDueDate, statusId: $statusId, clientId: $clientId, vendorId: $vendorId, projectId: $projectId, designId: $designId, assignedUserId: $assignedUserId, userId: $userId, locationId: $locationId, amount: $amount, balance: $balance, paidToDate: $paidToDate, partial: $partial, totalTaxes: $totalTaxes, discount: $discount, isAmountDiscount: $isAmountDiscount, exchangeRate: $exchangeRate, taxName1: $taxName1, taxName2: $taxName2, taxName3: $taxName3, taxRate1: $taxRate1, taxRate2: $taxRate2, taxRate3: $taxRate3, usesInclusiveTaxes: $usesInclusiveTaxes, customSurcharge1: $customSurcharge1, customSurcharge2: $customSurcharge2, customSurcharge3: $customSurcharge3, customSurcharge4: $customSurcharge4, customTaxes1: $customTaxes1, customTaxes2: $customTaxes2, customTaxes3: $customTaxes3, customTaxes4: $customTaxes4, publicNotes: $publicNotes, privateNotes: $privateNotes, terms: $terms, footer: $footer, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, lineItems: $lineItems, invitations: $invitations, documents: $documents, eInvoice: $eInvoice, isDeleted: $isDeleted, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt)';
}


}

/// @nodoc
abstract mixin class $CreditApiCopyWith<$Res>  {
  factory $CreditApiCopyWith(CreditApi value, $Res Function(CreditApi) _then) = _$CreditApiCopyWithImpl;
@useResult
$Res call({
 String id, String number,@JsonKey(name: 'po_number') String poNumber, String date,@JsonKey(name: 'due_date') String dueDate,@JsonKey(name: 'partial_due_date') String partialDueDate,@JsonKey(name: 'status_id') String statusId,@JsonKey(name: 'client_id') String clientId,@JsonKey(name: 'vendor_id') String vendorId,@JsonKey(name: 'project_id') String projectId,@JsonKey(name: 'design_id') String designId,@JsonKey(name: 'assigned_user_id') String assignedUserId,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'location_id') String locationId, Object amount, Object balance,@JsonKey(name: 'paid_to_date') Object paidToDate,@JsonKey(name: 'partial') Object partial,@JsonKey(name: 'total_taxes') Object totalTaxes, Object discount,@JsonKey(name: 'is_amount_discount') bool isAmountDiscount,@JsonKey(name: 'exchange_rate') Object exchangeRate,@JsonKey(name: 'tax_name1') String taxName1,@JsonKey(name: 'tax_name2') String taxName2,@JsonKey(name: 'tax_name3') String taxName3,@JsonKey(name: 'tax_rate1') Object taxRate1,@JsonKey(name: 'tax_rate2') Object taxRate2,@JsonKey(name: 'tax_rate3') Object taxRate3,@JsonKey(name: 'uses_inclusive_taxes') bool usesInclusiveTaxes,@JsonKey(name: 'custom_surcharge1') Object customSurcharge1,@JsonKey(name: 'custom_surcharge2') Object customSurcharge2,@JsonKey(name: 'custom_surcharge3') Object customSurcharge3,@JsonKey(name: 'custom_surcharge4') Object customSurcharge4,@JsonKey(name: 'custom_surcharge_tax1') bool customTaxes1,@JsonKey(name: 'custom_surcharge_tax2') bool customTaxes2,@JsonKey(name: 'custom_surcharge_tax3') bool customTaxes3,@JsonKey(name: 'custom_surcharge_tax4') bool customTaxes4,@JsonKey(name: 'public_notes') String publicNotes,@JsonKey(name: 'private_notes') String privateNotes, String terms, String footer,@JsonKey(name: 'custom_value1') String customValue1,@JsonKey(name: 'custom_value2') String customValue2,@JsonKey(name: 'custom_value3') String customValue3,@JsonKey(name: 'custom_value4') String customValue4,@JsonKey(name: 'line_items') List<LineItemApi> lineItems, List<InvitationApi> invitations, List<DocumentApi>? documents,@JsonKey(name: 'e_invoice') Map<String, dynamic>? eInvoice,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt
});




}
/// @nodoc
class _$CreditApiCopyWithImpl<$Res>
    implements $CreditApiCopyWith<$Res> {
  _$CreditApiCopyWithImpl(this._self, this._then);

  final CreditApi _self;
  final $Res Function(CreditApi) _then;

/// Create a copy of CreditApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? number = null,Object? poNumber = null,Object? date = null,Object? dueDate = null,Object? partialDueDate = null,Object? statusId = null,Object? clientId = null,Object? vendorId = null,Object? projectId = null,Object? designId = null,Object? assignedUserId = null,Object? userId = null,Object? locationId = null,Object? amount = null,Object? balance = null,Object? paidToDate = null,Object? partial = null,Object? totalTaxes = null,Object? discount = null,Object? isAmountDiscount = null,Object? exchangeRate = null,Object? taxName1 = null,Object? taxName2 = null,Object? taxName3 = null,Object? taxRate1 = null,Object? taxRate2 = null,Object? taxRate3 = null,Object? usesInclusiveTaxes = null,Object? customSurcharge1 = null,Object? customSurcharge2 = null,Object? customSurcharge3 = null,Object? customSurcharge4 = null,Object? customTaxes1 = null,Object? customTaxes2 = null,Object? customTaxes3 = null,Object? customTaxes4 = null,Object? publicNotes = null,Object? privateNotes = null,Object? terms = null,Object? footer = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? lineItems = null,Object? invitations = null,Object? documents = freezed,Object? eInvoice = freezed,Object? isDeleted = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,}) {
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
as String,amount: null == amount ? _self.amount : amount ,balance: null == balance ? _self.balance : balance ,paidToDate: null == paidToDate ? _self.paidToDate : paidToDate ,partial: null == partial ? _self.partial : partial ,totalTaxes: null == totalTaxes ? _self.totalTaxes : totalTaxes ,discount: null == discount ? _self.discount : discount ,isAmountDiscount: null == isAmountDiscount ? _self.isAmountDiscount : isAmountDiscount // ignore: cast_nullable_to_non_nullable
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
as List<DocumentApi>?,eInvoice: freezed == eInvoice ? _self.eInvoice : eInvoice // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CreditApi].
extension CreditApiPatterns on CreditApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CreditApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CreditApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CreditApi value)  $default,){
final _that = this;
switch (_that) {
case _CreditApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CreditApi value)?  $default,){
final _that = this;
switch (_that) {
case _CreditApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String number, @JsonKey(name: 'po_number')  String poNumber,  String date, @JsonKey(name: 'due_date')  String dueDate, @JsonKey(name: 'partial_due_date')  String partialDueDate, @JsonKey(name: 'status_id')  String statusId, @JsonKey(name: 'client_id')  String clientId, @JsonKey(name: 'vendor_id')  String vendorId, @JsonKey(name: 'project_id')  String projectId, @JsonKey(name: 'design_id')  String designId, @JsonKey(name: 'assigned_user_id')  String assignedUserId, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'location_id')  String locationId,  Object amount,  Object balance, @JsonKey(name: 'paid_to_date')  Object paidToDate, @JsonKey(name: 'partial')  Object partial, @JsonKey(name: 'total_taxes')  Object totalTaxes,  Object discount, @JsonKey(name: 'is_amount_discount')  bool isAmountDiscount, @JsonKey(name: 'exchange_rate')  Object exchangeRate, @JsonKey(name: 'tax_name1')  String taxName1, @JsonKey(name: 'tax_name2')  String taxName2, @JsonKey(name: 'tax_name3')  String taxName3, @JsonKey(name: 'tax_rate1')  Object taxRate1, @JsonKey(name: 'tax_rate2')  Object taxRate2, @JsonKey(name: 'tax_rate3')  Object taxRate3, @JsonKey(name: 'uses_inclusive_taxes')  bool usesInclusiveTaxes, @JsonKey(name: 'custom_surcharge1')  Object customSurcharge1, @JsonKey(name: 'custom_surcharge2')  Object customSurcharge2, @JsonKey(name: 'custom_surcharge3')  Object customSurcharge3, @JsonKey(name: 'custom_surcharge4')  Object customSurcharge4, @JsonKey(name: 'custom_surcharge_tax1')  bool customTaxes1, @JsonKey(name: 'custom_surcharge_tax2')  bool customTaxes2, @JsonKey(name: 'custom_surcharge_tax3')  bool customTaxes3, @JsonKey(name: 'custom_surcharge_tax4')  bool customTaxes4, @JsonKey(name: 'public_notes')  String publicNotes, @JsonKey(name: 'private_notes')  String privateNotes,  String terms,  String footer, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'line_items')  List<LineItemApi> lineItems,  List<InvitationApi> invitations,  List<DocumentApi>? documents, @JsonKey(name: 'e_invoice')  Map<String, dynamic>? eInvoice, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CreditApi() when $default != null:
return $default(_that.id,_that.number,_that.poNumber,_that.date,_that.dueDate,_that.partialDueDate,_that.statusId,_that.clientId,_that.vendorId,_that.projectId,_that.designId,_that.assignedUserId,_that.userId,_that.locationId,_that.amount,_that.balance,_that.paidToDate,_that.partial,_that.totalTaxes,_that.discount,_that.isAmountDiscount,_that.exchangeRate,_that.taxName1,_that.taxName2,_that.taxName3,_that.taxRate1,_that.taxRate2,_that.taxRate3,_that.usesInclusiveTaxes,_that.customSurcharge1,_that.customSurcharge2,_that.customSurcharge3,_that.customSurcharge4,_that.customTaxes1,_that.customTaxes2,_that.customTaxes3,_that.customTaxes4,_that.publicNotes,_that.privateNotes,_that.terms,_that.footer,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.lineItems,_that.invitations,_that.documents,_that.eInvoice,_that.isDeleted,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String number, @JsonKey(name: 'po_number')  String poNumber,  String date, @JsonKey(name: 'due_date')  String dueDate, @JsonKey(name: 'partial_due_date')  String partialDueDate, @JsonKey(name: 'status_id')  String statusId, @JsonKey(name: 'client_id')  String clientId, @JsonKey(name: 'vendor_id')  String vendorId, @JsonKey(name: 'project_id')  String projectId, @JsonKey(name: 'design_id')  String designId, @JsonKey(name: 'assigned_user_id')  String assignedUserId, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'location_id')  String locationId,  Object amount,  Object balance, @JsonKey(name: 'paid_to_date')  Object paidToDate, @JsonKey(name: 'partial')  Object partial, @JsonKey(name: 'total_taxes')  Object totalTaxes,  Object discount, @JsonKey(name: 'is_amount_discount')  bool isAmountDiscount, @JsonKey(name: 'exchange_rate')  Object exchangeRate, @JsonKey(name: 'tax_name1')  String taxName1, @JsonKey(name: 'tax_name2')  String taxName2, @JsonKey(name: 'tax_name3')  String taxName3, @JsonKey(name: 'tax_rate1')  Object taxRate1, @JsonKey(name: 'tax_rate2')  Object taxRate2, @JsonKey(name: 'tax_rate3')  Object taxRate3, @JsonKey(name: 'uses_inclusive_taxes')  bool usesInclusiveTaxes, @JsonKey(name: 'custom_surcharge1')  Object customSurcharge1, @JsonKey(name: 'custom_surcharge2')  Object customSurcharge2, @JsonKey(name: 'custom_surcharge3')  Object customSurcharge3, @JsonKey(name: 'custom_surcharge4')  Object customSurcharge4, @JsonKey(name: 'custom_surcharge_tax1')  bool customTaxes1, @JsonKey(name: 'custom_surcharge_tax2')  bool customTaxes2, @JsonKey(name: 'custom_surcharge_tax3')  bool customTaxes3, @JsonKey(name: 'custom_surcharge_tax4')  bool customTaxes4, @JsonKey(name: 'public_notes')  String publicNotes, @JsonKey(name: 'private_notes')  String privateNotes,  String terms,  String footer, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'line_items')  List<LineItemApi> lineItems,  List<InvitationApi> invitations,  List<DocumentApi>? documents, @JsonKey(name: 'e_invoice')  Map<String, dynamic>? eInvoice, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)  $default,) {final _that = this;
switch (_that) {
case _CreditApi():
return $default(_that.id,_that.number,_that.poNumber,_that.date,_that.dueDate,_that.partialDueDate,_that.statusId,_that.clientId,_that.vendorId,_that.projectId,_that.designId,_that.assignedUserId,_that.userId,_that.locationId,_that.amount,_that.balance,_that.paidToDate,_that.partial,_that.totalTaxes,_that.discount,_that.isAmountDiscount,_that.exchangeRate,_that.taxName1,_that.taxName2,_that.taxName3,_that.taxRate1,_that.taxRate2,_that.taxRate3,_that.usesInclusiveTaxes,_that.customSurcharge1,_that.customSurcharge2,_that.customSurcharge3,_that.customSurcharge4,_that.customTaxes1,_that.customTaxes2,_that.customTaxes3,_that.customTaxes4,_that.publicNotes,_that.privateNotes,_that.terms,_that.footer,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.lineItems,_that.invitations,_that.documents,_that.eInvoice,_that.isDeleted,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String number, @JsonKey(name: 'po_number')  String poNumber,  String date, @JsonKey(name: 'due_date')  String dueDate, @JsonKey(name: 'partial_due_date')  String partialDueDate, @JsonKey(name: 'status_id')  String statusId, @JsonKey(name: 'client_id')  String clientId, @JsonKey(name: 'vendor_id')  String vendorId, @JsonKey(name: 'project_id')  String projectId, @JsonKey(name: 'design_id')  String designId, @JsonKey(name: 'assigned_user_id')  String assignedUserId, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'location_id')  String locationId,  Object amount,  Object balance, @JsonKey(name: 'paid_to_date')  Object paidToDate, @JsonKey(name: 'partial')  Object partial, @JsonKey(name: 'total_taxes')  Object totalTaxes,  Object discount, @JsonKey(name: 'is_amount_discount')  bool isAmountDiscount, @JsonKey(name: 'exchange_rate')  Object exchangeRate, @JsonKey(name: 'tax_name1')  String taxName1, @JsonKey(name: 'tax_name2')  String taxName2, @JsonKey(name: 'tax_name3')  String taxName3, @JsonKey(name: 'tax_rate1')  Object taxRate1, @JsonKey(name: 'tax_rate2')  Object taxRate2, @JsonKey(name: 'tax_rate3')  Object taxRate3, @JsonKey(name: 'uses_inclusive_taxes')  bool usesInclusiveTaxes, @JsonKey(name: 'custom_surcharge1')  Object customSurcharge1, @JsonKey(name: 'custom_surcharge2')  Object customSurcharge2, @JsonKey(name: 'custom_surcharge3')  Object customSurcharge3, @JsonKey(name: 'custom_surcharge4')  Object customSurcharge4, @JsonKey(name: 'custom_surcharge_tax1')  bool customTaxes1, @JsonKey(name: 'custom_surcharge_tax2')  bool customTaxes2, @JsonKey(name: 'custom_surcharge_tax3')  bool customTaxes3, @JsonKey(name: 'custom_surcharge_tax4')  bool customTaxes4, @JsonKey(name: 'public_notes')  String publicNotes, @JsonKey(name: 'private_notes')  String privateNotes,  String terms,  String footer, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'line_items')  List<LineItemApi> lineItems,  List<InvitationApi> invitations,  List<DocumentApi>? documents, @JsonKey(name: 'e_invoice')  Map<String, dynamic>? eInvoice, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)?  $default,) {final _that = this;
switch (_that) {
case _CreditApi() when $default != null:
return $default(_that.id,_that.number,_that.poNumber,_that.date,_that.dueDate,_that.partialDueDate,_that.statusId,_that.clientId,_that.vendorId,_that.projectId,_that.designId,_that.assignedUserId,_that.userId,_that.locationId,_that.amount,_that.balance,_that.paidToDate,_that.partial,_that.totalTaxes,_that.discount,_that.isAmountDiscount,_that.exchangeRate,_that.taxName1,_that.taxName2,_that.taxName3,_that.taxRate1,_that.taxRate2,_that.taxRate3,_that.usesInclusiveTaxes,_that.customSurcharge1,_that.customSurcharge2,_that.customSurcharge3,_that.customSurcharge4,_that.customTaxes1,_that.customTaxes2,_that.customTaxes3,_that.customTaxes4,_that.publicNotes,_that.privateNotes,_that.terms,_that.footer,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.lineItems,_that.invitations,_that.documents,_that.eInvoice,_that.isDeleted,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CreditApi implements CreditApi {
  const _CreditApi({this.id = '', this.number = '', @JsonKey(name: 'po_number') this.poNumber = '', this.date = '', @JsonKey(name: 'due_date') this.dueDate = '', @JsonKey(name: 'partial_due_date') this.partialDueDate = '', @JsonKey(name: 'status_id') this.statusId = '1', @JsonKey(name: 'client_id') this.clientId = '', @JsonKey(name: 'vendor_id') this.vendorId = '', @JsonKey(name: 'project_id') this.projectId = '', @JsonKey(name: 'design_id') this.designId = '', @JsonKey(name: 'assigned_user_id') this.assignedUserId = '', @JsonKey(name: 'user_id') this.userId = '', @JsonKey(name: 'location_id') this.locationId = '', this.amount = '0', this.balance = '0', @JsonKey(name: 'paid_to_date') this.paidToDate = '0', @JsonKey(name: 'partial') this.partial = '0', @JsonKey(name: 'total_taxes') this.totalTaxes = '0', this.discount = '0', @JsonKey(name: 'is_amount_discount') this.isAmountDiscount = false, @JsonKey(name: 'exchange_rate') this.exchangeRate = '1', @JsonKey(name: 'tax_name1') this.taxName1 = '', @JsonKey(name: 'tax_name2') this.taxName2 = '', @JsonKey(name: 'tax_name3') this.taxName3 = '', @JsonKey(name: 'tax_rate1') this.taxRate1 = '0', @JsonKey(name: 'tax_rate2') this.taxRate2 = '0', @JsonKey(name: 'tax_rate3') this.taxRate3 = '0', @JsonKey(name: 'uses_inclusive_taxes') this.usesInclusiveTaxes = false, @JsonKey(name: 'custom_surcharge1') this.customSurcharge1 = '0', @JsonKey(name: 'custom_surcharge2') this.customSurcharge2 = '0', @JsonKey(name: 'custom_surcharge3') this.customSurcharge3 = '0', @JsonKey(name: 'custom_surcharge4') this.customSurcharge4 = '0', @JsonKey(name: 'custom_surcharge_tax1') this.customTaxes1 = false, @JsonKey(name: 'custom_surcharge_tax2') this.customTaxes2 = false, @JsonKey(name: 'custom_surcharge_tax3') this.customTaxes3 = false, @JsonKey(name: 'custom_surcharge_tax4') this.customTaxes4 = false, @JsonKey(name: 'public_notes') this.publicNotes = '', @JsonKey(name: 'private_notes') this.privateNotes = '', this.terms = '', this.footer = '', @JsonKey(name: 'custom_value1') this.customValue1 = '', @JsonKey(name: 'custom_value2') this.customValue2 = '', @JsonKey(name: 'custom_value3') this.customValue3 = '', @JsonKey(name: 'custom_value4') this.customValue4 = '', @JsonKey(name: 'line_items') final  List<LineItemApi> lineItems = const <LineItemApi>[], final  List<InvitationApi> invitations = const <InvitationApi>[], final  List<DocumentApi>? documents, @JsonKey(name: 'e_invoice') final  Map<String, dynamic>? eInvoice, @JsonKey(name: 'is_deleted') this.isDeleted = false, @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0}): _lineItems = lineItems,_invitations = invitations,_documents = documents,_eInvoice = eInvoice;
  factory _CreditApi.fromJson(Map<String, dynamic> json) => _$CreditApiFromJson(json);

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
@override@JsonKey() final  Object amount;
@override@JsonKey() final  Object balance;
@override@JsonKey(name: 'paid_to_date') final  Object paidToDate;
@override@JsonKey(name: 'partial') final  Object partial;
@override@JsonKey(name: 'total_taxes') final  Object totalTaxes;
@override@JsonKey() final  Object discount;
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

/// Create a copy of CreditApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CreditApiCopyWith<_CreditApi> get copyWith => __$CreditApiCopyWithImpl<_CreditApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CreditApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CreditApi&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.poNumber, poNumber) || other.poNumber == poNumber)&&(identical(other.date, date) || other.date == date)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.partialDueDate, partialDueDate) || other.partialDueDate == partialDueDate)&&(identical(other.statusId, statusId) || other.statusId == statusId)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.vendorId, vendorId) || other.vendorId == vendorId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.designId, designId) || other.designId == designId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.locationId, locationId) || other.locationId == locationId)&&const DeepCollectionEquality().equals(other.amount, amount)&&const DeepCollectionEquality().equals(other.balance, balance)&&const DeepCollectionEquality().equals(other.paidToDate, paidToDate)&&const DeepCollectionEquality().equals(other.partial, partial)&&const DeepCollectionEquality().equals(other.totalTaxes, totalTaxes)&&const DeepCollectionEquality().equals(other.discount, discount)&&(identical(other.isAmountDiscount, isAmountDiscount) || other.isAmountDiscount == isAmountDiscount)&&const DeepCollectionEquality().equals(other.exchangeRate, exchangeRate)&&(identical(other.taxName1, taxName1) || other.taxName1 == taxName1)&&(identical(other.taxName2, taxName2) || other.taxName2 == taxName2)&&(identical(other.taxName3, taxName3) || other.taxName3 == taxName3)&&const DeepCollectionEquality().equals(other.taxRate1, taxRate1)&&const DeepCollectionEquality().equals(other.taxRate2, taxRate2)&&const DeepCollectionEquality().equals(other.taxRate3, taxRate3)&&(identical(other.usesInclusiveTaxes, usesInclusiveTaxes) || other.usesInclusiveTaxes == usesInclusiveTaxes)&&const DeepCollectionEquality().equals(other.customSurcharge1, customSurcharge1)&&const DeepCollectionEquality().equals(other.customSurcharge2, customSurcharge2)&&const DeepCollectionEquality().equals(other.customSurcharge3, customSurcharge3)&&const DeepCollectionEquality().equals(other.customSurcharge4, customSurcharge4)&&(identical(other.customTaxes1, customTaxes1) || other.customTaxes1 == customTaxes1)&&(identical(other.customTaxes2, customTaxes2) || other.customTaxes2 == customTaxes2)&&(identical(other.customTaxes3, customTaxes3) || other.customTaxes3 == customTaxes3)&&(identical(other.customTaxes4, customTaxes4) || other.customTaxes4 == customTaxes4)&&(identical(other.publicNotes, publicNotes) || other.publicNotes == publicNotes)&&(identical(other.privateNotes, privateNotes) || other.privateNotes == privateNotes)&&(identical(other.terms, terms) || other.terms == terms)&&(identical(other.footer, footer) || other.footer == footer)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&const DeepCollectionEquality().equals(other._lineItems, _lineItems)&&const DeepCollectionEquality().equals(other._invitations, _invitations)&&const DeepCollectionEquality().equals(other._documents, _documents)&&const DeepCollectionEquality().equals(other._eInvoice, _eInvoice)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,number,poNumber,date,dueDate,partialDueDate,statusId,clientId,vendorId,projectId,designId,assignedUserId,userId,locationId,const DeepCollectionEquality().hash(amount),const DeepCollectionEquality().hash(balance),const DeepCollectionEquality().hash(paidToDate),const DeepCollectionEquality().hash(partial),const DeepCollectionEquality().hash(totalTaxes),const DeepCollectionEquality().hash(discount),isAmountDiscount,const DeepCollectionEquality().hash(exchangeRate),taxName1,taxName2,taxName3,const DeepCollectionEquality().hash(taxRate1),const DeepCollectionEquality().hash(taxRate2),const DeepCollectionEquality().hash(taxRate3),usesInclusiveTaxes,const DeepCollectionEquality().hash(customSurcharge1),const DeepCollectionEquality().hash(customSurcharge2),const DeepCollectionEquality().hash(customSurcharge3),const DeepCollectionEquality().hash(customSurcharge4),customTaxes1,customTaxes2,customTaxes3,customTaxes4,publicNotes,privateNotes,terms,footer,customValue1,customValue2,customValue3,customValue4,const DeepCollectionEquality().hash(_lineItems),const DeepCollectionEquality().hash(_invitations),const DeepCollectionEquality().hash(_documents),const DeepCollectionEquality().hash(_eInvoice),isDeleted,createdAt,updatedAt,archivedAt]);

@override
String toString() {
  return 'CreditApi(id: $id, number: $number, poNumber: $poNumber, date: $date, dueDate: $dueDate, partialDueDate: $partialDueDate, statusId: $statusId, clientId: $clientId, vendorId: $vendorId, projectId: $projectId, designId: $designId, assignedUserId: $assignedUserId, userId: $userId, locationId: $locationId, amount: $amount, balance: $balance, paidToDate: $paidToDate, partial: $partial, totalTaxes: $totalTaxes, discount: $discount, isAmountDiscount: $isAmountDiscount, exchangeRate: $exchangeRate, taxName1: $taxName1, taxName2: $taxName2, taxName3: $taxName3, taxRate1: $taxRate1, taxRate2: $taxRate2, taxRate3: $taxRate3, usesInclusiveTaxes: $usesInclusiveTaxes, customSurcharge1: $customSurcharge1, customSurcharge2: $customSurcharge2, customSurcharge3: $customSurcharge3, customSurcharge4: $customSurcharge4, customTaxes1: $customTaxes1, customTaxes2: $customTaxes2, customTaxes3: $customTaxes3, customTaxes4: $customTaxes4, publicNotes: $publicNotes, privateNotes: $privateNotes, terms: $terms, footer: $footer, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, lineItems: $lineItems, invitations: $invitations, documents: $documents, eInvoice: $eInvoice, isDeleted: $isDeleted, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt)';
}


}

/// @nodoc
abstract mixin class _$CreditApiCopyWith<$Res> implements $CreditApiCopyWith<$Res> {
  factory _$CreditApiCopyWith(_CreditApi value, $Res Function(_CreditApi) _then) = __$CreditApiCopyWithImpl;
@override @useResult
$Res call({
 String id, String number,@JsonKey(name: 'po_number') String poNumber, String date,@JsonKey(name: 'due_date') String dueDate,@JsonKey(name: 'partial_due_date') String partialDueDate,@JsonKey(name: 'status_id') String statusId,@JsonKey(name: 'client_id') String clientId,@JsonKey(name: 'vendor_id') String vendorId,@JsonKey(name: 'project_id') String projectId,@JsonKey(name: 'design_id') String designId,@JsonKey(name: 'assigned_user_id') String assignedUserId,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'location_id') String locationId, Object amount, Object balance,@JsonKey(name: 'paid_to_date') Object paidToDate,@JsonKey(name: 'partial') Object partial,@JsonKey(name: 'total_taxes') Object totalTaxes, Object discount,@JsonKey(name: 'is_amount_discount') bool isAmountDiscount,@JsonKey(name: 'exchange_rate') Object exchangeRate,@JsonKey(name: 'tax_name1') String taxName1,@JsonKey(name: 'tax_name2') String taxName2,@JsonKey(name: 'tax_name3') String taxName3,@JsonKey(name: 'tax_rate1') Object taxRate1,@JsonKey(name: 'tax_rate2') Object taxRate2,@JsonKey(name: 'tax_rate3') Object taxRate3,@JsonKey(name: 'uses_inclusive_taxes') bool usesInclusiveTaxes,@JsonKey(name: 'custom_surcharge1') Object customSurcharge1,@JsonKey(name: 'custom_surcharge2') Object customSurcharge2,@JsonKey(name: 'custom_surcharge3') Object customSurcharge3,@JsonKey(name: 'custom_surcharge4') Object customSurcharge4,@JsonKey(name: 'custom_surcharge_tax1') bool customTaxes1,@JsonKey(name: 'custom_surcharge_tax2') bool customTaxes2,@JsonKey(name: 'custom_surcharge_tax3') bool customTaxes3,@JsonKey(name: 'custom_surcharge_tax4') bool customTaxes4,@JsonKey(name: 'public_notes') String publicNotes,@JsonKey(name: 'private_notes') String privateNotes, String terms, String footer,@JsonKey(name: 'custom_value1') String customValue1,@JsonKey(name: 'custom_value2') String customValue2,@JsonKey(name: 'custom_value3') String customValue3,@JsonKey(name: 'custom_value4') String customValue4,@JsonKey(name: 'line_items') List<LineItemApi> lineItems, List<InvitationApi> invitations, List<DocumentApi>? documents,@JsonKey(name: 'e_invoice') Map<String, dynamic>? eInvoice,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt
});




}
/// @nodoc
class __$CreditApiCopyWithImpl<$Res>
    implements _$CreditApiCopyWith<$Res> {
  __$CreditApiCopyWithImpl(this._self, this._then);

  final _CreditApi _self;
  final $Res Function(_CreditApi) _then;

/// Create a copy of CreditApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? number = null,Object? poNumber = null,Object? date = null,Object? dueDate = null,Object? partialDueDate = null,Object? statusId = null,Object? clientId = null,Object? vendorId = null,Object? projectId = null,Object? designId = null,Object? assignedUserId = null,Object? userId = null,Object? locationId = null,Object? amount = null,Object? balance = null,Object? paidToDate = null,Object? partial = null,Object? totalTaxes = null,Object? discount = null,Object? isAmountDiscount = null,Object? exchangeRate = null,Object? taxName1 = null,Object? taxName2 = null,Object? taxName3 = null,Object? taxRate1 = null,Object? taxRate2 = null,Object? taxRate3 = null,Object? usesInclusiveTaxes = null,Object? customSurcharge1 = null,Object? customSurcharge2 = null,Object? customSurcharge3 = null,Object? customSurcharge4 = null,Object? customTaxes1 = null,Object? customTaxes2 = null,Object? customTaxes3 = null,Object? customTaxes4 = null,Object? publicNotes = null,Object? privateNotes = null,Object? terms = null,Object? footer = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? lineItems = null,Object? invitations = null,Object? documents = freezed,Object? eInvoice = freezed,Object? isDeleted = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,}) {
  return _then(_CreditApi(
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
as String,amount: null == amount ? _self.amount : amount ,balance: null == balance ? _self.balance : balance ,paidToDate: null == paidToDate ? _self.paidToDate : paidToDate ,partial: null == partial ? _self.partial : partial ,totalTaxes: null == totalTaxes ? _self.totalTaxes : totalTaxes ,discount: null == discount ? _self.discount : discount ,isAmountDiscount: null == isAmountDiscount ? _self.isAmountDiscount : isAmountDiscount // ignore: cast_nullable_to_non_nullable
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
as List<DocumentApi>?,eInvoice: freezed == eInvoice ? _self._eInvoice : eInvoice // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$CreditListApi {

@JsonKey(fromJson: _creditListData) List<CreditApi> get data;
/// Create a copy of CreditListApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CreditListApiCopyWith<CreditListApi> get copyWith => _$CreditListApiCopyWithImpl<CreditListApi>(this as CreditListApi, _$identity);

  /// Serializes this CreditListApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CreditListApi&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'CreditListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $CreditListApiCopyWith<$Res>  {
  factory $CreditListApiCopyWith(CreditListApi value, $Res Function(CreditListApi) _then) = _$CreditListApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _creditListData) List<CreditApi> data
});




}
/// @nodoc
class _$CreditListApiCopyWithImpl<$Res>
    implements $CreditListApiCopyWith<$Res> {
  _$CreditListApiCopyWithImpl(this._self, this._then);

  final CreditListApi _self;
  final $Res Function(CreditListApi) _then;

/// Create a copy of CreditListApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<CreditApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [CreditListApi].
extension CreditListApiPatterns on CreditListApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CreditListApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CreditListApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CreditListApi value)  $default,){
final _that = this;
switch (_that) {
case _CreditListApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CreditListApi value)?  $default,){
final _that = this;
switch (_that) {
case _CreditListApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _creditListData)  List<CreditApi> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CreditListApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _creditListData)  List<CreditApi> data)  $default,) {final _that = this;
switch (_that) {
case _CreditListApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _creditListData)  List<CreditApi> data)?  $default,) {final _that = this;
switch (_that) {
case _CreditListApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CreditListApi implements CreditListApi {
  const _CreditListApi({@JsonKey(fromJson: _creditListData) final  List<CreditApi> data = const <CreditApi>[]}): _data = data;
  factory _CreditListApi.fromJson(Map<String, dynamic> json) => _$CreditListApiFromJson(json);

 final  List<CreditApi> _data;
@override@JsonKey(fromJson: _creditListData) List<CreditApi> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of CreditListApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CreditListApiCopyWith<_CreditListApi> get copyWith => __$CreditListApiCopyWithImpl<_CreditListApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CreditListApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CreditListApi&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'CreditListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$CreditListApiCopyWith<$Res> implements $CreditListApiCopyWith<$Res> {
  factory _$CreditListApiCopyWith(_CreditListApi value, $Res Function(_CreditListApi) _then) = __$CreditListApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _creditListData) List<CreditApi> data
});




}
/// @nodoc
class __$CreditListApiCopyWithImpl<$Res>
    implements _$CreditListApiCopyWith<$Res> {
  __$CreditListApiCopyWithImpl(this._self, this._then);

  final _CreditListApi _self;
  final $Res Function(_CreditListApi) _then;

/// Create a copy of CreditListApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_CreditListApi(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<CreditApi>,
  ));
}


}


/// @nodoc
mixin _$CreditItemApi {

 CreditApi get data;
/// Create a copy of CreditItemApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CreditItemApiCopyWith<CreditItemApi> get copyWith => _$CreditItemApiCopyWithImpl<CreditItemApi>(this as CreditItemApi, _$identity);

  /// Serializes this CreditItemApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CreditItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'CreditItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $CreditItemApiCopyWith<$Res>  {
  factory $CreditItemApiCopyWith(CreditItemApi value, $Res Function(CreditItemApi) _then) = _$CreditItemApiCopyWithImpl;
@useResult
$Res call({
 CreditApi data
});


$CreditApiCopyWith<$Res> get data;

}
/// @nodoc
class _$CreditItemApiCopyWithImpl<$Res>
    implements $CreditItemApiCopyWith<$Res> {
  _$CreditItemApiCopyWithImpl(this._self, this._then);

  final CreditItemApi _self;
  final $Res Function(CreditItemApi) _then;

/// Create a copy of CreditItemApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as CreditApi,
  ));
}
/// Create a copy of CreditItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CreditApiCopyWith<$Res> get data {
  
  return $CreditApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [CreditItemApi].
extension CreditItemApiPatterns on CreditItemApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CreditItemApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CreditItemApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CreditItemApi value)  $default,){
final _that = this;
switch (_that) {
case _CreditItemApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CreditItemApi value)?  $default,){
final _that = this;
switch (_that) {
case _CreditItemApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( CreditApi data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CreditItemApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( CreditApi data)  $default,) {final _that = this;
switch (_that) {
case _CreditItemApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( CreditApi data)?  $default,) {final _that = this;
switch (_that) {
case _CreditItemApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CreditItemApi implements CreditItemApi {
  const _CreditItemApi({required this.data});
  factory _CreditItemApi.fromJson(Map<String, dynamic> json) => _$CreditItemApiFromJson(json);

@override final  CreditApi data;

/// Create a copy of CreditItemApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CreditItemApiCopyWith<_CreditItemApi> get copyWith => __$CreditItemApiCopyWithImpl<_CreditItemApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CreditItemApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CreditItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'CreditItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$CreditItemApiCopyWith<$Res> implements $CreditItemApiCopyWith<$Res> {
  factory _$CreditItemApiCopyWith(_CreditItemApi value, $Res Function(_CreditItemApi) _then) = __$CreditItemApiCopyWithImpl;
@override @useResult
$Res call({
 CreditApi data
});


@override $CreditApiCopyWith<$Res> get data;

}
/// @nodoc
class __$CreditItemApiCopyWithImpl<$Res>
    implements _$CreditItemApiCopyWith<$Res> {
  __$CreditItemApiCopyWithImpl(this._self, this._then);

  final _CreditItemApi _self;
  final $Res Function(_CreditItemApi) _then;

/// Create a copy of CreditItemApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_CreditItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as CreditApi,
  ));
}

/// Create a copy of CreditItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CreditApiCopyWith<$Res> get data {
  
  return $CreditApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

// dart format on
