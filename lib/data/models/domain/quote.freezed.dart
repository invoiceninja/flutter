// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'quote.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Quote {

 String get id; String get number; String get poNumber; Date? get date; Date? get dueDate; Date? get partialDueDate; QuoteStatus get statusId; String get clientId; String get vendorId; String get projectId; String get designId; String get assignedUserId; String get userId; String get locationId; String get subscriptionId; String get invoiceId; Decimal get amount; Decimal get balance; Decimal get taxAmount; Decimal get discount; Decimal get partial; bool get isAmountDiscount; Decimal get exchangeRate; String get taxName1; String get taxName2; String get taxName3; Decimal get taxRate1; Decimal get taxRate2; Decimal get taxRate3; bool get usesInclusiveTaxes; Decimal get customSurcharge1; Decimal get customSurcharge2; Decimal get customSurcharge3; Decimal get customSurcharge4; bool get customTaxes1; bool get customTaxes2; bool get customTaxes3; bool get customTaxes4; String get publicNotes; String get privateNotes; String get terms; String get footer; String get customValue1; String get customValue2; String get customValue3; String get customValue4; bool get isDeleted; DateTime get updatedAt; DateTime get createdAt; DateTime? get archivedAt; List<LineItem> get lineItems; List<Invitation> get invitations; List<Document> get documents; List<String> get tagIds; Map<String, dynamic>? get eInvoice;// Server-computed, read-only (display only — omitted from toApiJson).
 Date? get lastSentDate; Date? get nextSendDate; bool get isDirty;
/// Create a copy of Quote
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuoteCopyWith<Quote> get copyWith => _$QuoteCopyWithImpl<Quote>(this as Quote, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Quote&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.poNumber, poNumber) || other.poNumber == poNumber)&&(identical(other.date, date) || other.date == date)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.partialDueDate, partialDueDate) || other.partialDueDate == partialDueDate)&&(identical(other.statusId, statusId) || other.statusId == statusId)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.vendorId, vendorId) || other.vendorId == vendorId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.designId, designId) || other.designId == designId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.locationId, locationId) || other.locationId == locationId)&&(identical(other.subscriptionId, subscriptionId) || other.subscriptionId == subscriptionId)&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.taxAmount, taxAmount) || other.taxAmount == taxAmount)&&(identical(other.discount, discount) || other.discount == discount)&&(identical(other.partial, partial) || other.partial == partial)&&(identical(other.isAmountDiscount, isAmountDiscount) || other.isAmountDiscount == isAmountDiscount)&&(identical(other.exchangeRate, exchangeRate) || other.exchangeRate == exchangeRate)&&(identical(other.taxName1, taxName1) || other.taxName1 == taxName1)&&(identical(other.taxName2, taxName2) || other.taxName2 == taxName2)&&(identical(other.taxName3, taxName3) || other.taxName3 == taxName3)&&(identical(other.taxRate1, taxRate1) || other.taxRate1 == taxRate1)&&(identical(other.taxRate2, taxRate2) || other.taxRate2 == taxRate2)&&(identical(other.taxRate3, taxRate3) || other.taxRate3 == taxRate3)&&(identical(other.usesInclusiveTaxes, usesInclusiveTaxes) || other.usesInclusiveTaxes == usesInclusiveTaxes)&&(identical(other.customSurcharge1, customSurcharge1) || other.customSurcharge1 == customSurcharge1)&&(identical(other.customSurcharge2, customSurcharge2) || other.customSurcharge2 == customSurcharge2)&&(identical(other.customSurcharge3, customSurcharge3) || other.customSurcharge3 == customSurcharge3)&&(identical(other.customSurcharge4, customSurcharge4) || other.customSurcharge4 == customSurcharge4)&&(identical(other.customTaxes1, customTaxes1) || other.customTaxes1 == customTaxes1)&&(identical(other.customTaxes2, customTaxes2) || other.customTaxes2 == customTaxes2)&&(identical(other.customTaxes3, customTaxes3) || other.customTaxes3 == customTaxes3)&&(identical(other.customTaxes4, customTaxes4) || other.customTaxes4 == customTaxes4)&&(identical(other.publicNotes, publicNotes) || other.publicNotes == publicNotes)&&(identical(other.privateNotes, privateNotes) || other.privateNotes == privateNotes)&&(identical(other.terms, terms) || other.terms == terms)&&(identical(other.footer, footer) || other.footer == footer)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&const DeepCollectionEquality().equals(other.lineItems, lineItems)&&const DeepCollectionEquality().equals(other.invitations, invitations)&&const DeepCollectionEquality().equals(other.documents, documents)&&const DeepCollectionEquality().equals(other.tagIds, tagIds)&&const DeepCollectionEquality().equals(other.eInvoice, eInvoice)&&(identical(other.lastSentDate, lastSentDate) || other.lastSentDate == lastSentDate)&&(identical(other.nextSendDate, nextSendDate) || other.nextSendDate == nextSendDate)&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,number,poNumber,date,dueDate,partialDueDate,statusId,clientId,vendorId,projectId,designId,assignedUserId,userId,locationId,subscriptionId,invoiceId,amount,balance,taxAmount,discount,partial,isAmountDiscount,exchangeRate,taxName1,taxName2,taxName3,taxRate1,taxRate2,taxRate3,usesInclusiveTaxes,customSurcharge1,customSurcharge2,customSurcharge3,customSurcharge4,customTaxes1,customTaxes2,customTaxes3,customTaxes4,publicNotes,privateNotes,terms,footer,customValue1,customValue2,customValue3,customValue4,isDeleted,updatedAt,createdAt,archivedAt,const DeepCollectionEquality().hash(lineItems),const DeepCollectionEquality().hash(invitations),const DeepCollectionEquality().hash(documents),const DeepCollectionEquality().hash(tagIds),const DeepCollectionEquality().hash(eInvoice),lastSentDate,nextSendDate,isDirty]);

@override
String toString() {
  return 'Quote(id: $id, number: $number, poNumber: $poNumber, date: $date, dueDate: $dueDate, partialDueDate: $partialDueDate, statusId: $statusId, clientId: $clientId, vendorId: $vendorId, projectId: $projectId, designId: $designId, assignedUserId: $assignedUserId, userId: $userId, locationId: $locationId, subscriptionId: $subscriptionId, invoiceId: $invoiceId, amount: $amount, balance: $balance, taxAmount: $taxAmount, discount: $discount, partial: $partial, isAmountDiscount: $isAmountDiscount, exchangeRate: $exchangeRate, taxName1: $taxName1, taxName2: $taxName2, taxName3: $taxName3, taxRate1: $taxRate1, taxRate2: $taxRate2, taxRate3: $taxRate3, usesInclusiveTaxes: $usesInclusiveTaxes, customSurcharge1: $customSurcharge1, customSurcharge2: $customSurcharge2, customSurcharge3: $customSurcharge3, customSurcharge4: $customSurcharge4, customTaxes1: $customTaxes1, customTaxes2: $customTaxes2, customTaxes3: $customTaxes3, customTaxes4: $customTaxes4, publicNotes: $publicNotes, privateNotes: $privateNotes, terms: $terms, footer: $footer, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, isDeleted: $isDeleted, updatedAt: $updatedAt, createdAt: $createdAt, archivedAt: $archivedAt, lineItems: $lineItems, invitations: $invitations, documents: $documents, tagIds: $tagIds, eInvoice: $eInvoice, lastSentDate: $lastSentDate, nextSendDate: $nextSendDate, isDirty: $isDirty)';
}


}

/// @nodoc
abstract mixin class $QuoteCopyWith<$Res>  {
  factory $QuoteCopyWith(Quote value, $Res Function(Quote) _then) = _$QuoteCopyWithImpl;
@useResult
$Res call({
 String id, String number, String poNumber, Date? date, Date? dueDate, Date? partialDueDate, QuoteStatus statusId, String clientId, String vendorId, String projectId, String designId, String assignedUserId, String userId, String locationId, String subscriptionId, String invoiceId, Decimal amount, Decimal balance, Decimal taxAmount, Decimal discount, Decimal partial, bool isAmountDiscount, Decimal exchangeRate, String taxName1, String taxName2, String taxName3, Decimal taxRate1, Decimal taxRate2, Decimal taxRate3, bool usesInclusiveTaxes, Decimal customSurcharge1, Decimal customSurcharge2, Decimal customSurcharge3, Decimal customSurcharge4, bool customTaxes1, bool customTaxes2, bool customTaxes3, bool customTaxes4, String publicNotes, String privateNotes, String terms, String footer, String customValue1, String customValue2, String customValue3, String customValue4, bool isDeleted, DateTime updatedAt, DateTime createdAt, DateTime? archivedAt, List<LineItem> lineItems, List<Invitation> invitations, List<Document> documents, List<String> tagIds, Map<String, dynamic>? eInvoice, Date? lastSentDate, Date? nextSendDate, bool isDirty
});




}
/// @nodoc
class _$QuoteCopyWithImpl<$Res>
    implements $QuoteCopyWith<$Res> {
  _$QuoteCopyWithImpl(this._self, this._then);

  final Quote _self;
  final $Res Function(Quote) _then;

/// Create a copy of Quote
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? number = null,Object? poNumber = null,Object? date = freezed,Object? dueDate = freezed,Object? partialDueDate = freezed,Object? statusId = null,Object? clientId = null,Object? vendorId = null,Object? projectId = null,Object? designId = null,Object? assignedUserId = null,Object? userId = null,Object? locationId = null,Object? subscriptionId = null,Object? invoiceId = null,Object? amount = null,Object? balance = null,Object? taxAmount = null,Object? discount = null,Object? partial = null,Object? isAmountDiscount = null,Object? exchangeRate = null,Object? taxName1 = null,Object? taxName2 = null,Object? taxName3 = null,Object? taxRate1 = null,Object? taxRate2 = null,Object? taxRate3 = null,Object? usesInclusiveTaxes = null,Object? customSurcharge1 = null,Object? customSurcharge2 = null,Object? customSurcharge3 = null,Object? customSurcharge4 = null,Object? customTaxes1 = null,Object? customTaxes2 = null,Object? customTaxes3 = null,Object? customTaxes4 = null,Object? publicNotes = null,Object? privateNotes = null,Object? terms = null,Object? footer = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? isDeleted = null,Object? updatedAt = null,Object? createdAt = null,Object? archivedAt = freezed,Object? lineItems = null,Object? invitations = null,Object? documents = null,Object? tagIds = null,Object? eInvoice = freezed,Object? lastSentDate = freezed,Object? nextSendDate = freezed,Object? isDirty = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,poNumber: null == poNumber ? _self.poNumber : poNumber // ignore: cast_nullable_to_non_nullable
as String,date: freezed == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as Date?,dueDate: freezed == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as Date?,partialDueDate: freezed == partialDueDate ? _self.partialDueDate : partialDueDate // ignore: cast_nullable_to_non_nullable
as Date?,statusId: null == statusId ? _self.statusId : statusId // ignore: cast_nullable_to_non_nullable
as QuoteStatus,clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,vendorId: null == vendorId ? _self.vendorId : vendorId // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,designId: null == designId ? _self.designId : designId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,locationId: null == locationId ? _self.locationId : locationId // ignore: cast_nullable_to_non_nullable
as String,subscriptionId: null == subscriptionId ? _self.subscriptionId : subscriptionId // ignore: cast_nullable_to_non_nullable
as String,invoiceId: null == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as Decimal,balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as Decimal,taxAmount: null == taxAmount ? _self.taxAmount : taxAmount // ignore: cast_nullable_to_non_nullable
as Decimal,discount: null == discount ? _self.discount : discount // ignore: cast_nullable_to_non_nullable
as Decimal,partial: null == partial ? _self.partial : partial // ignore: cast_nullable_to_non_nullable
as Decimal,isAmountDiscount: null == isAmountDiscount ? _self.isAmountDiscount : isAmountDiscount // ignore: cast_nullable_to_non_nullable
as bool,exchangeRate: null == exchangeRate ? _self.exchangeRate : exchangeRate // ignore: cast_nullable_to_non_nullable
as Decimal,taxName1: null == taxName1 ? _self.taxName1 : taxName1 // ignore: cast_nullable_to_non_nullable
as String,taxName2: null == taxName2 ? _self.taxName2 : taxName2 // ignore: cast_nullable_to_non_nullable
as String,taxName3: null == taxName3 ? _self.taxName3 : taxName3 // ignore: cast_nullable_to_non_nullable
as String,taxRate1: null == taxRate1 ? _self.taxRate1 : taxRate1 // ignore: cast_nullable_to_non_nullable
as Decimal,taxRate2: null == taxRate2 ? _self.taxRate2 : taxRate2 // ignore: cast_nullable_to_non_nullable
as Decimal,taxRate3: null == taxRate3 ? _self.taxRate3 : taxRate3 // ignore: cast_nullable_to_non_nullable
as Decimal,usesInclusiveTaxes: null == usesInclusiveTaxes ? _self.usesInclusiveTaxes : usesInclusiveTaxes // ignore: cast_nullable_to_non_nullable
as bool,customSurcharge1: null == customSurcharge1 ? _self.customSurcharge1 : customSurcharge1 // ignore: cast_nullable_to_non_nullable
as Decimal,customSurcharge2: null == customSurcharge2 ? _self.customSurcharge2 : customSurcharge2 // ignore: cast_nullable_to_non_nullable
as Decimal,customSurcharge3: null == customSurcharge3 ? _self.customSurcharge3 : customSurcharge3 // ignore: cast_nullable_to_non_nullable
as Decimal,customSurcharge4: null == customSurcharge4 ? _self.customSurcharge4 : customSurcharge4 // ignore: cast_nullable_to_non_nullable
as Decimal,customTaxes1: null == customTaxes1 ? _self.customTaxes1 : customTaxes1 // ignore: cast_nullable_to_non_nullable
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
as String,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lineItems: null == lineItems ? _self.lineItems : lineItems // ignore: cast_nullable_to_non_nullable
as List<LineItem>,invitations: null == invitations ? _self.invitations : invitations // ignore: cast_nullable_to_non_nullable
as List<Invitation>,documents: null == documents ? _self.documents : documents // ignore: cast_nullable_to_non_nullable
as List<Document>,tagIds: null == tagIds ? _self.tagIds : tagIds // ignore: cast_nullable_to_non_nullable
as List<String>,eInvoice: freezed == eInvoice ? _self.eInvoice : eInvoice // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,lastSentDate: freezed == lastSentDate ? _self.lastSentDate : lastSentDate // ignore: cast_nullable_to_non_nullable
as Date?,nextSendDate: freezed == nextSendDate ? _self.nextSendDate : nextSendDate // ignore: cast_nullable_to_non_nullable
as Date?,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Quote].
extension QuotePatterns on Quote {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Quote value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Quote() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Quote value)  $default,){
final _that = this;
switch (_that) {
case _Quote():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Quote value)?  $default,){
final _that = this;
switch (_that) {
case _Quote() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String number,  String poNumber,  Date? date,  Date? dueDate,  Date? partialDueDate,  QuoteStatus statusId,  String clientId,  String vendorId,  String projectId,  String designId,  String assignedUserId,  String userId,  String locationId,  String subscriptionId,  String invoiceId,  Decimal amount,  Decimal balance,  Decimal taxAmount,  Decimal discount,  Decimal partial,  bool isAmountDiscount,  Decimal exchangeRate,  String taxName1,  String taxName2,  String taxName3,  Decimal taxRate1,  Decimal taxRate2,  Decimal taxRate3,  bool usesInclusiveTaxes,  Decimal customSurcharge1,  Decimal customSurcharge2,  Decimal customSurcharge3,  Decimal customSurcharge4,  bool customTaxes1,  bool customTaxes2,  bool customTaxes3,  bool customTaxes4,  String publicNotes,  String privateNotes,  String terms,  String footer,  String customValue1,  String customValue2,  String customValue3,  String customValue4,  bool isDeleted,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  List<LineItem> lineItems,  List<Invitation> invitations,  List<Document> documents,  List<String> tagIds,  Map<String, dynamic>? eInvoice,  Date? lastSentDate,  Date? nextSendDate,  bool isDirty)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Quote() when $default != null:
return $default(_that.id,_that.number,_that.poNumber,_that.date,_that.dueDate,_that.partialDueDate,_that.statusId,_that.clientId,_that.vendorId,_that.projectId,_that.designId,_that.assignedUserId,_that.userId,_that.locationId,_that.subscriptionId,_that.invoiceId,_that.amount,_that.balance,_that.taxAmount,_that.discount,_that.partial,_that.isAmountDiscount,_that.exchangeRate,_that.taxName1,_that.taxName2,_that.taxName3,_that.taxRate1,_that.taxRate2,_that.taxRate3,_that.usesInclusiveTaxes,_that.customSurcharge1,_that.customSurcharge2,_that.customSurcharge3,_that.customSurcharge4,_that.customTaxes1,_that.customTaxes2,_that.customTaxes3,_that.customTaxes4,_that.publicNotes,_that.privateNotes,_that.terms,_that.footer,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.isDeleted,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.lineItems,_that.invitations,_that.documents,_that.tagIds,_that.eInvoice,_that.lastSentDate,_that.nextSendDate,_that.isDirty);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String number,  String poNumber,  Date? date,  Date? dueDate,  Date? partialDueDate,  QuoteStatus statusId,  String clientId,  String vendorId,  String projectId,  String designId,  String assignedUserId,  String userId,  String locationId,  String subscriptionId,  String invoiceId,  Decimal amount,  Decimal balance,  Decimal taxAmount,  Decimal discount,  Decimal partial,  bool isAmountDiscount,  Decimal exchangeRate,  String taxName1,  String taxName2,  String taxName3,  Decimal taxRate1,  Decimal taxRate2,  Decimal taxRate3,  bool usesInclusiveTaxes,  Decimal customSurcharge1,  Decimal customSurcharge2,  Decimal customSurcharge3,  Decimal customSurcharge4,  bool customTaxes1,  bool customTaxes2,  bool customTaxes3,  bool customTaxes4,  String publicNotes,  String privateNotes,  String terms,  String footer,  String customValue1,  String customValue2,  String customValue3,  String customValue4,  bool isDeleted,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  List<LineItem> lineItems,  List<Invitation> invitations,  List<Document> documents,  List<String> tagIds,  Map<String, dynamic>? eInvoice,  Date? lastSentDate,  Date? nextSendDate,  bool isDirty)  $default,) {final _that = this;
switch (_that) {
case _Quote():
return $default(_that.id,_that.number,_that.poNumber,_that.date,_that.dueDate,_that.partialDueDate,_that.statusId,_that.clientId,_that.vendorId,_that.projectId,_that.designId,_that.assignedUserId,_that.userId,_that.locationId,_that.subscriptionId,_that.invoiceId,_that.amount,_that.balance,_that.taxAmount,_that.discount,_that.partial,_that.isAmountDiscount,_that.exchangeRate,_that.taxName1,_that.taxName2,_that.taxName3,_that.taxRate1,_that.taxRate2,_that.taxRate3,_that.usesInclusiveTaxes,_that.customSurcharge1,_that.customSurcharge2,_that.customSurcharge3,_that.customSurcharge4,_that.customTaxes1,_that.customTaxes2,_that.customTaxes3,_that.customTaxes4,_that.publicNotes,_that.privateNotes,_that.terms,_that.footer,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.isDeleted,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.lineItems,_that.invitations,_that.documents,_that.tagIds,_that.eInvoice,_that.lastSentDate,_that.nextSendDate,_that.isDirty);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String number,  String poNumber,  Date? date,  Date? dueDate,  Date? partialDueDate,  QuoteStatus statusId,  String clientId,  String vendorId,  String projectId,  String designId,  String assignedUserId,  String userId,  String locationId,  String subscriptionId,  String invoiceId,  Decimal amount,  Decimal balance,  Decimal taxAmount,  Decimal discount,  Decimal partial,  bool isAmountDiscount,  Decimal exchangeRate,  String taxName1,  String taxName2,  String taxName3,  Decimal taxRate1,  Decimal taxRate2,  Decimal taxRate3,  bool usesInclusiveTaxes,  Decimal customSurcharge1,  Decimal customSurcharge2,  Decimal customSurcharge3,  Decimal customSurcharge4,  bool customTaxes1,  bool customTaxes2,  bool customTaxes3,  bool customTaxes4,  String publicNotes,  String privateNotes,  String terms,  String footer,  String customValue1,  String customValue2,  String customValue3,  String customValue4,  bool isDeleted,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  List<LineItem> lineItems,  List<Invitation> invitations,  List<Document> documents,  List<String> tagIds,  Map<String, dynamic>? eInvoice,  Date? lastSentDate,  Date? nextSendDate,  bool isDirty)?  $default,) {final _that = this;
switch (_that) {
case _Quote() when $default != null:
return $default(_that.id,_that.number,_that.poNumber,_that.date,_that.dueDate,_that.partialDueDate,_that.statusId,_that.clientId,_that.vendorId,_that.projectId,_that.designId,_that.assignedUserId,_that.userId,_that.locationId,_that.subscriptionId,_that.invoiceId,_that.amount,_that.balance,_that.taxAmount,_that.discount,_that.partial,_that.isAmountDiscount,_that.exchangeRate,_that.taxName1,_that.taxName2,_that.taxName3,_that.taxRate1,_that.taxRate2,_that.taxRate3,_that.usesInclusiveTaxes,_that.customSurcharge1,_that.customSurcharge2,_that.customSurcharge3,_that.customSurcharge4,_that.customTaxes1,_that.customTaxes2,_that.customTaxes3,_that.customTaxes4,_that.publicNotes,_that.privateNotes,_that.terms,_that.footer,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.isDeleted,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.lineItems,_that.invitations,_that.documents,_that.tagIds,_that.eInvoice,_that.lastSentDate,_that.nextSendDate,_that.isDirty);case _:
  return null;

}
}

}

/// @nodoc


class _Quote implements Quote {
  const _Quote({required this.id, required this.number, required this.poNumber, required this.date, required this.dueDate, required this.partialDueDate, required this.statusId, required this.clientId, required this.vendorId, required this.projectId, required this.designId, required this.assignedUserId, required this.userId, required this.locationId, required this.subscriptionId, required this.invoiceId, required this.amount, required this.balance, required this.taxAmount, required this.discount, required this.partial, required this.isAmountDiscount, required this.exchangeRate, required this.taxName1, required this.taxName2, required this.taxName3, required this.taxRate1, required this.taxRate2, required this.taxRate3, required this.usesInclusiveTaxes, required this.customSurcharge1, required this.customSurcharge2, required this.customSurcharge3, required this.customSurcharge4, required this.customTaxes1, required this.customTaxes2, required this.customTaxes3, required this.customTaxes4, required this.publicNotes, required this.privateNotes, required this.terms, required this.footer, required this.customValue1, required this.customValue2, required this.customValue3, required this.customValue4, required this.isDeleted, required this.updatedAt, required this.createdAt, required this.archivedAt, final  List<LineItem> lineItems = const <LineItem>[], final  List<Invitation> invitations = const <Invitation>[], final  List<Document> documents = const <Document>[], final  List<String> tagIds = const <String>[], final  Map<String, dynamic>? eInvoice, this.lastSentDate, this.nextSendDate, this.isDirty = false}): _lineItems = lineItems,_invitations = invitations,_documents = documents,_tagIds = tagIds,_eInvoice = eInvoice;
  

@override final  String id;
@override final  String number;
@override final  String poNumber;
@override final  Date? date;
@override final  Date? dueDate;
@override final  Date? partialDueDate;
@override final  QuoteStatus statusId;
@override final  String clientId;
@override final  String vendorId;
@override final  String projectId;
@override final  String designId;
@override final  String assignedUserId;
@override final  String userId;
@override final  String locationId;
@override final  String subscriptionId;
@override final  String invoiceId;
@override final  Decimal amount;
@override final  Decimal balance;
@override final  Decimal taxAmount;
@override final  Decimal discount;
@override final  Decimal partial;
@override final  bool isAmountDiscount;
@override final  Decimal exchangeRate;
@override final  String taxName1;
@override final  String taxName2;
@override final  String taxName3;
@override final  Decimal taxRate1;
@override final  Decimal taxRate2;
@override final  Decimal taxRate3;
@override final  bool usesInclusiveTaxes;
@override final  Decimal customSurcharge1;
@override final  Decimal customSurcharge2;
@override final  Decimal customSurcharge3;
@override final  Decimal customSurcharge4;
@override final  bool customTaxes1;
@override final  bool customTaxes2;
@override final  bool customTaxes3;
@override final  bool customTaxes4;
@override final  String publicNotes;
@override final  String privateNotes;
@override final  String terms;
@override final  String footer;
@override final  String customValue1;
@override final  String customValue2;
@override final  String customValue3;
@override final  String customValue4;
@override final  bool isDeleted;
@override final  DateTime updatedAt;
@override final  DateTime createdAt;
@override final  DateTime? archivedAt;
 final  List<LineItem> _lineItems;
@override@JsonKey() List<LineItem> get lineItems {
  if (_lineItems is EqualUnmodifiableListView) return _lineItems;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lineItems);
}

 final  List<Invitation> _invitations;
@override@JsonKey() List<Invitation> get invitations {
  if (_invitations is EqualUnmodifiableListView) return _invitations;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_invitations);
}

 final  List<Document> _documents;
@override@JsonKey() List<Document> get documents {
  if (_documents is EqualUnmodifiableListView) return _documents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_documents);
}

 final  List<String> _tagIds;
@override@JsonKey() List<String> get tagIds {
  if (_tagIds is EqualUnmodifiableListView) return _tagIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tagIds);
}

 final  Map<String, dynamic>? _eInvoice;
@override Map<String, dynamic>? get eInvoice {
  final value = _eInvoice;
  if (value == null) return null;
  if (_eInvoice is EqualUnmodifiableMapView) return _eInvoice;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

// Server-computed, read-only (display only — omitted from toApiJson).
@override final  Date? lastSentDate;
@override final  Date? nextSendDate;
@override@JsonKey() final  bool isDirty;

/// Create a copy of Quote
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QuoteCopyWith<_Quote> get copyWith => __$QuoteCopyWithImpl<_Quote>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Quote&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.poNumber, poNumber) || other.poNumber == poNumber)&&(identical(other.date, date) || other.date == date)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.partialDueDate, partialDueDate) || other.partialDueDate == partialDueDate)&&(identical(other.statusId, statusId) || other.statusId == statusId)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.vendorId, vendorId) || other.vendorId == vendorId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.designId, designId) || other.designId == designId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.locationId, locationId) || other.locationId == locationId)&&(identical(other.subscriptionId, subscriptionId) || other.subscriptionId == subscriptionId)&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.taxAmount, taxAmount) || other.taxAmount == taxAmount)&&(identical(other.discount, discount) || other.discount == discount)&&(identical(other.partial, partial) || other.partial == partial)&&(identical(other.isAmountDiscount, isAmountDiscount) || other.isAmountDiscount == isAmountDiscount)&&(identical(other.exchangeRate, exchangeRate) || other.exchangeRate == exchangeRate)&&(identical(other.taxName1, taxName1) || other.taxName1 == taxName1)&&(identical(other.taxName2, taxName2) || other.taxName2 == taxName2)&&(identical(other.taxName3, taxName3) || other.taxName3 == taxName3)&&(identical(other.taxRate1, taxRate1) || other.taxRate1 == taxRate1)&&(identical(other.taxRate2, taxRate2) || other.taxRate2 == taxRate2)&&(identical(other.taxRate3, taxRate3) || other.taxRate3 == taxRate3)&&(identical(other.usesInclusiveTaxes, usesInclusiveTaxes) || other.usesInclusiveTaxes == usesInclusiveTaxes)&&(identical(other.customSurcharge1, customSurcharge1) || other.customSurcharge1 == customSurcharge1)&&(identical(other.customSurcharge2, customSurcharge2) || other.customSurcharge2 == customSurcharge2)&&(identical(other.customSurcharge3, customSurcharge3) || other.customSurcharge3 == customSurcharge3)&&(identical(other.customSurcharge4, customSurcharge4) || other.customSurcharge4 == customSurcharge4)&&(identical(other.customTaxes1, customTaxes1) || other.customTaxes1 == customTaxes1)&&(identical(other.customTaxes2, customTaxes2) || other.customTaxes2 == customTaxes2)&&(identical(other.customTaxes3, customTaxes3) || other.customTaxes3 == customTaxes3)&&(identical(other.customTaxes4, customTaxes4) || other.customTaxes4 == customTaxes4)&&(identical(other.publicNotes, publicNotes) || other.publicNotes == publicNotes)&&(identical(other.privateNotes, privateNotes) || other.privateNotes == privateNotes)&&(identical(other.terms, terms) || other.terms == terms)&&(identical(other.footer, footer) || other.footer == footer)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&const DeepCollectionEquality().equals(other._lineItems, _lineItems)&&const DeepCollectionEquality().equals(other._invitations, _invitations)&&const DeepCollectionEquality().equals(other._documents, _documents)&&const DeepCollectionEquality().equals(other._tagIds, _tagIds)&&const DeepCollectionEquality().equals(other._eInvoice, _eInvoice)&&(identical(other.lastSentDate, lastSentDate) || other.lastSentDate == lastSentDate)&&(identical(other.nextSendDate, nextSendDate) || other.nextSendDate == nextSendDate)&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,number,poNumber,date,dueDate,partialDueDate,statusId,clientId,vendorId,projectId,designId,assignedUserId,userId,locationId,subscriptionId,invoiceId,amount,balance,taxAmount,discount,partial,isAmountDiscount,exchangeRate,taxName1,taxName2,taxName3,taxRate1,taxRate2,taxRate3,usesInclusiveTaxes,customSurcharge1,customSurcharge2,customSurcharge3,customSurcharge4,customTaxes1,customTaxes2,customTaxes3,customTaxes4,publicNotes,privateNotes,terms,footer,customValue1,customValue2,customValue3,customValue4,isDeleted,updatedAt,createdAt,archivedAt,const DeepCollectionEquality().hash(_lineItems),const DeepCollectionEquality().hash(_invitations),const DeepCollectionEquality().hash(_documents),const DeepCollectionEquality().hash(_tagIds),const DeepCollectionEquality().hash(_eInvoice),lastSentDate,nextSendDate,isDirty]);

@override
String toString() {
  return 'Quote(id: $id, number: $number, poNumber: $poNumber, date: $date, dueDate: $dueDate, partialDueDate: $partialDueDate, statusId: $statusId, clientId: $clientId, vendorId: $vendorId, projectId: $projectId, designId: $designId, assignedUserId: $assignedUserId, userId: $userId, locationId: $locationId, subscriptionId: $subscriptionId, invoiceId: $invoiceId, amount: $amount, balance: $balance, taxAmount: $taxAmount, discount: $discount, partial: $partial, isAmountDiscount: $isAmountDiscount, exchangeRate: $exchangeRate, taxName1: $taxName1, taxName2: $taxName2, taxName3: $taxName3, taxRate1: $taxRate1, taxRate2: $taxRate2, taxRate3: $taxRate3, usesInclusiveTaxes: $usesInclusiveTaxes, customSurcharge1: $customSurcharge1, customSurcharge2: $customSurcharge2, customSurcharge3: $customSurcharge3, customSurcharge4: $customSurcharge4, customTaxes1: $customTaxes1, customTaxes2: $customTaxes2, customTaxes3: $customTaxes3, customTaxes4: $customTaxes4, publicNotes: $publicNotes, privateNotes: $privateNotes, terms: $terms, footer: $footer, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, isDeleted: $isDeleted, updatedAt: $updatedAt, createdAt: $createdAt, archivedAt: $archivedAt, lineItems: $lineItems, invitations: $invitations, documents: $documents, tagIds: $tagIds, eInvoice: $eInvoice, lastSentDate: $lastSentDate, nextSendDate: $nextSendDate, isDirty: $isDirty)';
}


}

/// @nodoc
abstract mixin class _$QuoteCopyWith<$Res> implements $QuoteCopyWith<$Res> {
  factory _$QuoteCopyWith(_Quote value, $Res Function(_Quote) _then) = __$QuoteCopyWithImpl;
@override @useResult
$Res call({
 String id, String number, String poNumber, Date? date, Date? dueDate, Date? partialDueDate, QuoteStatus statusId, String clientId, String vendorId, String projectId, String designId, String assignedUserId, String userId, String locationId, String subscriptionId, String invoiceId, Decimal amount, Decimal balance, Decimal taxAmount, Decimal discount, Decimal partial, bool isAmountDiscount, Decimal exchangeRate, String taxName1, String taxName2, String taxName3, Decimal taxRate1, Decimal taxRate2, Decimal taxRate3, bool usesInclusiveTaxes, Decimal customSurcharge1, Decimal customSurcharge2, Decimal customSurcharge3, Decimal customSurcharge4, bool customTaxes1, bool customTaxes2, bool customTaxes3, bool customTaxes4, String publicNotes, String privateNotes, String terms, String footer, String customValue1, String customValue2, String customValue3, String customValue4, bool isDeleted, DateTime updatedAt, DateTime createdAt, DateTime? archivedAt, List<LineItem> lineItems, List<Invitation> invitations, List<Document> documents, List<String> tagIds, Map<String, dynamic>? eInvoice, Date? lastSentDate, Date? nextSendDate, bool isDirty
});




}
/// @nodoc
class __$QuoteCopyWithImpl<$Res>
    implements _$QuoteCopyWith<$Res> {
  __$QuoteCopyWithImpl(this._self, this._then);

  final _Quote _self;
  final $Res Function(_Quote) _then;

/// Create a copy of Quote
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? number = null,Object? poNumber = null,Object? date = freezed,Object? dueDate = freezed,Object? partialDueDate = freezed,Object? statusId = null,Object? clientId = null,Object? vendorId = null,Object? projectId = null,Object? designId = null,Object? assignedUserId = null,Object? userId = null,Object? locationId = null,Object? subscriptionId = null,Object? invoiceId = null,Object? amount = null,Object? balance = null,Object? taxAmount = null,Object? discount = null,Object? partial = null,Object? isAmountDiscount = null,Object? exchangeRate = null,Object? taxName1 = null,Object? taxName2 = null,Object? taxName3 = null,Object? taxRate1 = null,Object? taxRate2 = null,Object? taxRate3 = null,Object? usesInclusiveTaxes = null,Object? customSurcharge1 = null,Object? customSurcharge2 = null,Object? customSurcharge3 = null,Object? customSurcharge4 = null,Object? customTaxes1 = null,Object? customTaxes2 = null,Object? customTaxes3 = null,Object? customTaxes4 = null,Object? publicNotes = null,Object? privateNotes = null,Object? terms = null,Object? footer = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? isDeleted = null,Object? updatedAt = null,Object? createdAt = null,Object? archivedAt = freezed,Object? lineItems = null,Object? invitations = null,Object? documents = null,Object? tagIds = null,Object? eInvoice = freezed,Object? lastSentDate = freezed,Object? nextSendDate = freezed,Object? isDirty = null,}) {
  return _then(_Quote(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,poNumber: null == poNumber ? _self.poNumber : poNumber // ignore: cast_nullable_to_non_nullable
as String,date: freezed == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as Date?,dueDate: freezed == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as Date?,partialDueDate: freezed == partialDueDate ? _self.partialDueDate : partialDueDate // ignore: cast_nullable_to_non_nullable
as Date?,statusId: null == statusId ? _self.statusId : statusId // ignore: cast_nullable_to_non_nullable
as QuoteStatus,clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,vendorId: null == vendorId ? _self.vendorId : vendorId // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,designId: null == designId ? _self.designId : designId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,locationId: null == locationId ? _self.locationId : locationId // ignore: cast_nullable_to_non_nullable
as String,subscriptionId: null == subscriptionId ? _self.subscriptionId : subscriptionId // ignore: cast_nullable_to_non_nullable
as String,invoiceId: null == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as Decimal,balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as Decimal,taxAmount: null == taxAmount ? _self.taxAmount : taxAmount // ignore: cast_nullable_to_non_nullable
as Decimal,discount: null == discount ? _self.discount : discount // ignore: cast_nullable_to_non_nullable
as Decimal,partial: null == partial ? _self.partial : partial // ignore: cast_nullable_to_non_nullable
as Decimal,isAmountDiscount: null == isAmountDiscount ? _self.isAmountDiscount : isAmountDiscount // ignore: cast_nullable_to_non_nullable
as bool,exchangeRate: null == exchangeRate ? _self.exchangeRate : exchangeRate // ignore: cast_nullable_to_non_nullable
as Decimal,taxName1: null == taxName1 ? _self.taxName1 : taxName1 // ignore: cast_nullable_to_non_nullable
as String,taxName2: null == taxName2 ? _self.taxName2 : taxName2 // ignore: cast_nullable_to_non_nullable
as String,taxName3: null == taxName3 ? _self.taxName3 : taxName3 // ignore: cast_nullable_to_non_nullable
as String,taxRate1: null == taxRate1 ? _self.taxRate1 : taxRate1 // ignore: cast_nullable_to_non_nullable
as Decimal,taxRate2: null == taxRate2 ? _self.taxRate2 : taxRate2 // ignore: cast_nullable_to_non_nullable
as Decimal,taxRate3: null == taxRate3 ? _self.taxRate3 : taxRate3 // ignore: cast_nullable_to_non_nullable
as Decimal,usesInclusiveTaxes: null == usesInclusiveTaxes ? _self.usesInclusiveTaxes : usesInclusiveTaxes // ignore: cast_nullable_to_non_nullable
as bool,customSurcharge1: null == customSurcharge1 ? _self.customSurcharge1 : customSurcharge1 // ignore: cast_nullable_to_non_nullable
as Decimal,customSurcharge2: null == customSurcharge2 ? _self.customSurcharge2 : customSurcharge2 // ignore: cast_nullable_to_non_nullable
as Decimal,customSurcharge3: null == customSurcharge3 ? _self.customSurcharge3 : customSurcharge3 // ignore: cast_nullable_to_non_nullable
as Decimal,customSurcharge4: null == customSurcharge4 ? _self.customSurcharge4 : customSurcharge4 // ignore: cast_nullable_to_non_nullable
as Decimal,customTaxes1: null == customTaxes1 ? _self.customTaxes1 : customTaxes1 // ignore: cast_nullable_to_non_nullable
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
as String,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lineItems: null == lineItems ? _self._lineItems : lineItems // ignore: cast_nullable_to_non_nullable
as List<LineItem>,invitations: null == invitations ? _self._invitations : invitations // ignore: cast_nullable_to_non_nullable
as List<Invitation>,documents: null == documents ? _self._documents : documents // ignore: cast_nullable_to_non_nullable
as List<Document>,tagIds: null == tagIds ? _self._tagIds : tagIds // ignore: cast_nullable_to_non_nullable
as List<String>,eInvoice: freezed == eInvoice ? _self._eInvoice : eInvoice // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,lastSentDate: freezed == lastSentDate ? _self.lastSentDate : lastSentDate // ignore: cast_nullable_to_non_nullable
as Date?,nextSendDate: freezed == nextSendDate ? _self.nextSendDate : nextSendDate // ignore: cast_nullable_to_non_nullable
as Date?,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
