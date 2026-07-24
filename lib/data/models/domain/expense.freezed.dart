// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'expense.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Expense {

 String get id; String get userId; String get assignedUserId; String get vendorId; String get invoiceId; String get clientId; String get bankId; String get invoiceCurrencyId; String get expenseCurrencyId; String get currencyId; String get categoryId; String get paymentTypeId; String get recurringExpenseId; String get privateNotes; String get publicNotes; String get transactionReference; String get transactionId; Date? get date; String get number; Date? get paymentDate; String get customValue1; String get customValue2; String get customValue3; String get customValue4; String get taxName1; String get taxName2; String get taxName3; String get projectId; String get entityType; Decimal get amount; Decimal get foreignAmount; Decimal get exchangeRate; Decimal get taxAmount1; Decimal get taxAmount2; Decimal get taxAmount3; Decimal get taxRate1; Decimal get taxRate2; Decimal get taxRate3; bool get isDeleted; bool get shouldBeInvoiced; bool get invoiceDocuments; bool get usesInclusiveTaxes; bool get calculateTaxByAmount; DateTime get updatedAt; DateTime get createdAt; DateTime? get archivedAt; List<Document> get documents; List<String> get tagIds; bool get isDirty;
/// Create a copy of Expense
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExpenseCopyWith<Expense> get copyWith => _$ExpenseCopyWithImpl<Expense>(this as Expense, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Expense&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.vendorId, vendorId) || other.vendorId == vendorId)&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.bankId, bankId) || other.bankId == bankId)&&(identical(other.invoiceCurrencyId, invoiceCurrencyId) || other.invoiceCurrencyId == invoiceCurrencyId)&&(identical(other.expenseCurrencyId, expenseCurrencyId) || other.expenseCurrencyId == expenseCurrencyId)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.paymentTypeId, paymentTypeId) || other.paymentTypeId == paymentTypeId)&&(identical(other.recurringExpenseId, recurringExpenseId) || other.recurringExpenseId == recurringExpenseId)&&(identical(other.privateNotes, privateNotes) || other.privateNotes == privateNotes)&&(identical(other.publicNotes, publicNotes) || other.publicNotes == publicNotes)&&(identical(other.transactionReference, transactionReference) || other.transactionReference == transactionReference)&&(identical(other.transactionId, transactionId) || other.transactionId == transactionId)&&(identical(other.date, date) || other.date == date)&&(identical(other.number, number) || other.number == number)&&(identical(other.paymentDate, paymentDate) || other.paymentDate == paymentDate)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.taxName1, taxName1) || other.taxName1 == taxName1)&&(identical(other.taxName2, taxName2) || other.taxName2 == taxName2)&&(identical(other.taxName3, taxName3) || other.taxName3 == taxName3)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.entityType, entityType) || other.entityType == entityType)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.foreignAmount, foreignAmount) || other.foreignAmount == foreignAmount)&&(identical(other.exchangeRate, exchangeRate) || other.exchangeRate == exchangeRate)&&(identical(other.taxAmount1, taxAmount1) || other.taxAmount1 == taxAmount1)&&(identical(other.taxAmount2, taxAmount2) || other.taxAmount2 == taxAmount2)&&(identical(other.taxAmount3, taxAmount3) || other.taxAmount3 == taxAmount3)&&(identical(other.taxRate1, taxRate1) || other.taxRate1 == taxRate1)&&(identical(other.taxRate2, taxRate2) || other.taxRate2 == taxRate2)&&(identical(other.taxRate3, taxRate3) || other.taxRate3 == taxRate3)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.shouldBeInvoiced, shouldBeInvoiced) || other.shouldBeInvoiced == shouldBeInvoiced)&&(identical(other.invoiceDocuments, invoiceDocuments) || other.invoiceDocuments == invoiceDocuments)&&(identical(other.usesInclusiveTaxes, usesInclusiveTaxes) || other.usesInclusiveTaxes == usesInclusiveTaxes)&&(identical(other.calculateTaxByAmount, calculateTaxByAmount) || other.calculateTaxByAmount == calculateTaxByAmount)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&const DeepCollectionEquality().equals(other.documents, documents)&&const DeepCollectionEquality().equals(other.tagIds, tagIds)&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,userId,assignedUserId,vendorId,invoiceId,clientId,bankId,invoiceCurrencyId,expenseCurrencyId,currencyId,categoryId,paymentTypeId,recurringExpenseId,privateNotes,publicNotes,transactionReference,transactionId,date,number,paymentDate,customValue1,customValue2,customValue3,customValue4,taxName1,taxName2,taxName3,projectId,entityType,amount,foreignAmount,exchangeRate,taxAmount1,taxAmount2,taxAmount3,taxRate1,taxRate2,taxRate3,isDeleted,shouldBeInvoiced,invoiceDocuments,usesInclusiveTaxes,calculateTaxByAmount,updatedAt,createdAt,archivedAt,const DeepCollectionEquality().hash(documents),const DeepCollectionEquality().hash(tagIds),isDirty]);

@override
String toString() {
  return 'Expense(id: $id, userId: $userId, assignedUserId: $assignedUserId, vendorId: $vendorId, invoiceId: $invoiceId, clientId: $clientId, bankId: $bankId, invoiceCurrencyId: $invoiceCurrencyId, expenseCurrencyId: $expenseCurrencyId, currencyId: $currencyId, categoryId: $categoryId, paymentTypeId: $paymentTypeId, recurringExpenseId: $recurringExpenseId, privateNotes: $privateNotes, publicNotes: $publicNotes, transactionReference: $transactionReference, transactionId: $transactionId, date: $date, number: $number, paymentDate: $paymentDate, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, taxName1: $taxName1, taxName2: $taxName2, taxName3: $taxName3, projectId: $projectId, entityType: $entityType, amount: $amount, foreignAmount: $foreignAmount, exchangeRate: $exchangeRate, taxAmount1: $taxAmount1, taxAmount2: $taxAmount2, taxAmount3: $taxAmount3, taxRate1: $taxRate1, taxRate2: $taxRate2, taxRate3: $taxRate3, isDeleted: $isDeleted, shouldBeInvoiced: $shouldBeInvoiced, invoiceDocuments: $invoiceDocuments, usesInclusiveTaxes: $usesInclusiveTaxes, calculateTaxByAmount: $calculateTaxByAmount, updatedAt: $updatedAt, createdAt: $createdAt, archivedAt: $archivedAt, documents: $documents, tagIds: $tagIds, isDirty: $isDirty)';
}


}

/// @nodoc
abstract mixin class $ExpenseCopyWith<$Res>  {
  factory $ExpenseCopyWith(Expense value, $Res Function(Expense) _then) = _$ExpenseCopyWithImpl;
@useResult
$Res call({
 String id, String userId, String assignedUserId, String vendorId, String invoiceId, String clientId, String bankId, String invoiceCurrencyId, String expenseCurrencyId, String currencyId, String categoryId, String paymentTypeId, String recurringExpenseId, String privateNotes, String publicNotes, String transactionReference, String transactionId, Date? date, String number, Date? paymentDate, String customValue1, String customValue2, String customValue3, String customValue4, String taxName1, String taxName2, String taxName3, String projectId, String entityType, Decimal amount, Decimal foreignAmount, Decimal exchangeRate, Decimal taxAmount1, Decimal taxAmount2, Decimal taxAmount3, Decimal taxRate1, Decimal taxRate2, Decimal taxRate3, bool isDeleted, bool shouldBeInvoiced, bool invoiceDocuments, bool usesInclusiveTaxes, bool calculateTaxByAmount, DateTime updatedAt, DateTime createdAt, DateTime? archivedAt, List<Document> documents, List<String> tagIds, bool isDirty
});




}
/// @nodoc
class _$ExpenseCopyWithImpl<$Res>
    implements $ExpenseCopyWith<$Res> {
  _$ExpenseCopyWithImpl(this._self, this._then);

  final Expense _self;
  final $Res Function(Expense) _then;

/// Create a copy of Expense
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? assignedUserId = null,Object? vendorId = null,Object? invoiceId = null,Object? clientId = null,Object? bankId = null,Object? invoiceCurrencyId = null,Object? expenseCurrencyId = null,Object? currencyId = null,Object? categoryId = null,Object? paymentTypeId = null,Object? recurringExpenseId = null,Object? privateNotes = null,Object? publicNotes = null,Object? transactionReference = null,Object? transactionId = null,Object? date = freezed,Object? number = null,Object? paymentDate = freezed,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? taxName1 = null,Object? taxName2 = null,Object? taxName3 = null,Object? projectId = null,Object? entityType = null,Object? amount = null,Object? foreignAmount = null,Object? exchangeRate = null,Object? taxAmount1 = null,Object? taxAmount2 = null,Object? taxAmount3 = null,Object? taxRate1 = null,Object? taxRate2 = null,Object? taxRate3 = null,Object? isDeleted = null,Object? shouldBeInvoiced = null,Object? invoiceDocuments = null,Object? usesInclusiveTaxes = null,Object? calculateTaxByAmount = null,Object? updatedAt = null,Object? createdAt = null,Object? archivedAt = freezed,Object? documents = null,Object? tagIds = null,Object? isDirty = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,vendorId: null == vendorId ? _self.vendorId : vendorId // ignore: cast_nullable_to_non_nullable
as String,invoiceId: null == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as String,clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,bankId: null == bankId ? _self.bankId : bankId // ignore: cast_nullable_to_non_nullable
as String,invoiceCurrencyId: null == invoiceCurrencyId ? _self.invoiceCurrencyId : invoiceCurrencyId // ignore: cast_nullable_to_non_nullable
as String,expenseCurrencyId: null == expenseCurrencyId ? _self.expenseCurrencyId : expenseCurrencyId // ignore: cast_nullable_to_non_nullable
as String,currencyId: null == currencyId ? _self.currencyId : currencyId // ignore: cast_nullable_to_non_nullable
as String,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String,paymentTypeId: null == paymentTypeId ? _self.paymentTypeId : paymentTypeId // ignore: cast_nullable_to_non_nullable
as String,recurringExpenseId: null == recurringExpenseId ? _self.recurringExpenseId : recurringExpenseId // ignore: cast_nullable_to_non_nullable
as String,privateNotes: null == privateNotes ? _self.privateNotes : privateNotes // ignore: cast_nullable_to_non_nullable
as String,publicNotes: null == publicNotes ? _self.publicNotes : publicNotes // ignore: cast_nullable_to_non_nullable
as String,transactionReference: null == transactionReference ? _self.transactionReference : transactionReference // ignore: cast_nullable_to_non_nullable
as String,transactionId: null == transactionId ? _self.transactionId : transactionId // ignore: cast_nullable_to_non_nullable
as String,date: freezed == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as Date?,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,paymentDate: freezed == paymentDate ? _self.paymentDate : paymentDate // ignore: cast_nullable_to_non_nullable
as Date?,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,taxName1: null == taxName1 ? _self.taxName1 : taxName1 // ignore: cast_nullable_to_non_nullable
as String,taxName2: null == taxName2 ? _self.taxName2 : taxName2 // ignore: cast_nullable_to_non_nullable
as String,taxName3: null == taxName3 ? _self.taxName3 : taxName3 // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,entityType: null == entityType ? _self.entityType : entityType // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as Decimal,foreignAmount: null == foreignAmount ? _self.foreignAmount : foreignAmount // ignore: cast_nullable_to_non_nullable
as Decimal,exchangeRate: null == exchangeRate ? _self.exchangeRate : exchangeRate // ignore: cast_nullable_to_non_nullable
as Decimal,taxAmount1: null == taxAmount1 ? _self.taxAmount1 : taxAmount1 // ignore: cast_nullable_to_non_nullable
as Decimal,taxAmount2: null == taxAmount2 ? _self.taxAmount2 : taxAmount2 // ignore: cast_nullable_to_non_nullable
as Decimal,taxAmount3: null == taxAmount3 ? _self.taxAmount3 : taxAmount3 // ignore: cast_nullable_to_non_nullable
as Decimal,taxRate1: null == taxRate1 ? _self.taxRate1 : taxRate1 // ignore: cast_nullable_to_non_nullable
as Decimal,taxRate2: null == taxRate2 ? _self.taxRate2 : taxRate2 // ignore: cast_nullable_to_non_nullable
as Decimal,taxRate3: null == taxRate3 ? _self.taxRate3 : taxRate3 // ignore: cast_nullable_to_non_nullable
as Decimal,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,shouldBeInvoiced: null == shouldBeInvoiced ? _self.shouldBeInvoiced : shouldBeInvoiced // ignore: cast_nullable_to_non_nullable
as bool,invoiceDocuments: null == invoiceDocuments ? _self.invoiceDocuments : invoiceDocuments // ignore: cast_nullable_to_non_nullable
as bool,usesInclusiveTaxes: null == usesInclusiveTaxes ? _self.usesInclusiveTaxes : usesInclusiveTaxes // ignore: cast_nullable_to_non_nullable
as bool,calculateTaxByAmount: null == calculateTaxByAmount ? _self.calculateTaxByAmount : calculateTaxByAmount // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,documents: null == documents ? _self.documents : documents // ignore: cast_nullable_to_non_nullable
as List<Document>,tagIds: null == tagIds ? _self.tagIds : tagIds // ignore: cast_nullable_to_non_nullable
as List<String>,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Expense].
extension ExpensePatterns on Expense {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Expense value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Expense() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Expense value)  $default,){
final _that = this;
switch (_that) {
case _Expense():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Expense value)?  $default,){
final _that = this;
switch (_that) {
case _Expense() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String userId,  String assignedUserId,  String vendorId,  String invoiceId,  String clientId,  String bankId,  String invoiceCurrencyId,  String expenseCurrencyId,  String currencyId,  String categoryId,  String paymentTypeId,  String recurringExpenseId,  String privateNotes,  String publicNotes,  String transactionReference,  String transactionId,  Date? date,  String number,  Date? paymentDate,  String customValue1,  String customValue2,  String customValue3,  String customValue4,  String taxName1,  String taxName2,  String taxName3,  String projectId,  String entityType,  Decimal amount,  Decimal foreignAmount,  Decimal exchangeRate,  Decimal taxAmount1,  Decimal taxAmount2,  Decimal taxAmount3,  Decimal taxRate1,  Decimal taxRate2,  Decimal taxRate3,  bool isDeleted,  bool shouldBeInvoiced,  bool invoiceDocuments,  bool usesInclusiveTaxes,  bool calculateTaxByAmount,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  List<Document> documents,  List<String> tagIds,  bool isDirty)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Expense() when $default != null:
return $default(_that.id,_that.userId,_that.assignedUserId,_that.vendorId,_that.invoiceId,_that.clientId,_that.bankId,_that.invoiceCurrencyId,_that.expenseCurrencyId,_that.currencyId,_that.categoryId,_that.paymentTypeId,_that.recurringExpenseId,_that.privateNotes,_that.publicNotes,_that.transactionReference,_that.transactionId,_that.date,_that.number,_that.paymentDate,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.taxName1,_that.taxName2,_that.taxName3,_that.projectId,_that.entityType,_that.amount,_that.foreignAmount,_that.exchangeRate,_that.taxAmount1,_that.taxAmount2,_that.taxAmount3,_that.taxRate1,_that.taxRate2,_that.taxRate3,_that.isDeleted,_that.shouldBeInvoiced,_that.invoiceDocuments,_that.usesInclusiveTaxes,_that.calculateTaxByAmount,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.documents,_that.tagIds,_that.isDirty);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String userId,  String assignedUserId,  String vendorId,  String invoiceId,  String clientId,  String bankId,  String invoiceCurrencyId,  String expenseCurrencyId,  String currencyId,  String categoryId,  String paymentTypeId,  String recurringExpenseId,  String privateNotes,  String publicNotes,  String transactionReference,  String transactionId,  Date? date,  String number,  Date? paymentDate,  String customValue1,  String customValue2,  String customValue3,  String customValue4,  String taxName1,  String taxName2,  String taxName3,  String projectId,  String entityType,  Decimal amount,  Decimal foreignAmount,  Decimal exchangeRate,  Decimal taxAmount1,  Decimal taxAmount2,  Decimal taxAmount3,  Decimal taxRate1,  Decimal taxRate2,  Decimal taxRate3,  bool isDeleted,  bool shouldBeInvoiced,  bool invoiceDocuments,  bool usesInclusiveTaxes,  bool calculateTaxByAmount,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  List<Document> documents,  List<String> tagIds,  bool isDirty)  $default,) {final _that = this;
switch (_that) {
case _Expense():
return $default(_that.id,_that.userId,_that.assignedUserId,_that.vendorId,_that.invoiceId,_that.clientId,_that.bankId,_that.invoiceCurrencyId,_that.expenseCurrencyId,_that.currencyId,_that.categoryId,_that.paymentTypeId,_that.recurringExpenseId,_that.privateNotes,_that.publicNotes,_that.transactionReference,_that.transactionId,_that.date,_that.number,_that.paymentDate,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.taxName1,_that.taxName2,_that.taxName3,_that.projectId,_that.entityType,_that.amount,_that.foreignAmount,_that.exchangeRate,_that.taxAmount1,_that.taxAmount2,_that.taxAmount3,_that.taxRate1,_that.taxRate2,_that.taxRate3,_that.isDeleted,_that.shouldBeInvoiced,_that.invoiceDocuments,_that.usesInclusiveTaxes,_that.calculateTaxByAmount,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.documents,_that.tagIds,_that.isDirty);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String userId,  String assignedUserId,  String vendorId,  String invoiceId,  String clientId,  String bankId,  String invoiceCurrencyId,  String expenseCurrencyId,  String currencyId,  String categoryId,  String paymentTypeId,  String recurringExpenseId,  String privateNotes,  String publicNotes,  String transactionReference,  String transactionId,  Date? date,  String number,  Date? paymentDate,  String customValue1,  String customValue2,  String customValue3,  String customValue4,  String taxName1,  String taxName2,  String taxName3,  String projectId,  String entityType,  Decimal amount,  Decimal foreignAmount,  Decimal exchangeRate,  Decimal taxAmount1,  Decimal taxAmount2,  Decimal taxAmount3,  Decimal taxRate1,  Decimal taxRate2,  Decimal taxRate3,  bool isDeleted,  bool shouldBeInvoiced,  bool invoiceDocuments,  bool usesInclusiveTaxes,  bool calculateTaxByAmount,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  List<Document> documents,  List<String> tagIds,  bool isDirty)?  $default,) {final _that = this;
switch (_that) {
case _Expense() when $default != null:
return $default(_that.id,_that.userId,_that.assignedUserId,_that.vendorId,_that.invoiceId,_that.clientId,_that.bankId,_that.invoiceCurrencyId,_that.expenseCurrencyId,_that.currencyId,_that.categoryId,_that.paymentTypeId,_that.recurringExpenseId,_that.privateNotes,_that.publicNotes,_that.transactionReference,_that.transactionId,_that.date,_that.number,_that.paymentDate,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.taxName1,_that.taxName2,_that.taxName3,_that.projectId,_that.entityType,_that.amount,_that.foreignAmount,_that.exchangeRate,_that.taxAmount1,_that.taxAmount2,_that.taxAmount3,_that.taxRate1,_that.taxRate2,_that.taxRate3,_that.isDeleted,_that.shouldBeInvoiced,_that.invoiceDocuments,_that.usesInclusiveTaxes,_that.calculateTaxByAmount,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.documents,_that.tagIds,_that.isDirty);case _:
  return null;

}
}

}

/// @nodoc


class _Expense implements Expense {
  const _Expense({required this.id, required this.userId, required this.assignedUserId, required this.vendorId, required this.invoiceId, required this.clientId, required this.bankId, required this.invoiceCurrencyId, required this.expenseCurrencyId, required this.currencyId, required this.categoryId, required this.paymentTypeId, required this.recurringExpenseId, required this.privateNotes, required this.publicNotes, required this.transactionReference, required this.transactionId, required this.date, required this.number, required this.paymentDate, required this.customValue1, required this.customValue2, required this.customValue3, required this.customValue4, required this.taxName1, required this.taxName2, required this.taxName3, required this.projectId, required this.entityType, required this.amount, required this.foreignAmount, required this.exchangeRate, required this.taxAmount1, required this.taxAmount2, required this.taxAmount3, required this.taxRate1, required this.taxRate2, required this.taxRate3, required this.isDeleted, required this.shouldBeInvoiced, required this.invoiceDocuments, required this.usesInclusiveTaxes, required this.calculateTaxByAmount, required this.updatedAt, required this.createdAt, required this.archivedAt, final  List<Document> documents = const <Document>[], final  List<String> tagIds = const <String>[], this.isDirty = false}): _documents = documents,_tagIds = tagIds;
  

@override final  String id;
@override final  String userId;
@override final  String assignedUserId;
@override final  String vendorId;
@override final  String invoiceId;
@override final  String clientId;
@override final  String bankId;
@override final  String invoiceCurrencyId;
@override final  String expenseCurrencyId;
@override final  String currencyId;
@override final  String categoryId;
@override final  String paymentTypeId;
@override final  String recurringExpenseId;
@override final  String privateNotes;
@override final  String publicNotes;
@override final  String transactionReference;
@override final  String transactionId;
@override final  Date? date;
@override final  String number;
@override final  Date? paymentDate;
@override final  String customValue1;
@override final  String customValue2;
@override final  String customValue3;
@override final  String customValue4;
@override final  String taxName1;
@override final  String taxName2;
@override final  String taxName3;
@override final  String projectId;
@override final  String entityType;
@override final  Decimal amount;
@override final  Decimal foreignAmount;
@override final  Decimal exchangeRate;
@override final  Decimal taxAmount1;
@override final  Decimal taxAmount2;
@override final  Decimal taxAmount3;
@override final  Decimal taxRate1;
@override final  Decimal taxRate2;
@override final  Decimal taxRate3;
@override final  bool isDeleted;
@override final  bool shouldBeInvoiced;
@override final  bool invoiceDocuments;
@override final  bool usesInclusiveTaxes;
@override final  bool calculateTaxByAmount;
@override final  DateTime updatedAt;
@override final  DateTime createdAt;
@override final  DateTime? archivedAt;
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

@override@JsonKey() final  bool isDirty;

/// Create a copy of Expense
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExpenseCopyWith<_Expense> get copyWith => __$ExpenseCopyWithImpl<_Expense>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Expense&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.vendorId, vendorId) || other.vendorId == vendorId)&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.bankId, bankId) || other.bankId == bankId)&&(identical(other.invoiceCurrencyId, invoiceCurrencyId) || other.invoiceCurrencyId == invoiceCurrencyId)&&(identical(other.expenseCurrencyId, expenseCurrencyId) || other.expenseCurrencyId == expenseCurrencyId)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.paymentTypeId, paymentTypeId) || other.paymentTypeId == paymentTypeId)&&(identical(other.recurringExpenseId, recurringExpenseId) || other.recurringExpenseId == recurringExpenseId)&&(identical(other.privateNotes, privateNotes) || other.privateNotes == privateNotes)&&(identical(other.publicNotes, publicNotes) || other.publicNotes == publicNotes)&&(identical(other.transactionReference, transactionReference) || other.transactionReference == transactionReference)&&(identical(other.transactionId, transactionId) || other.transactionId == transactionId)&&(identical(other.date, date) || other.date == date)&&(identical(other.number, number) || other.number == number)&&(identical(other.paymentDate, paymentDate) || other.paymentDate == paymentDate)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.taxName1, taxName1) || other.taxName1 == taxName1)&&(identical(other.taxName2, taxName2) || other.taxName2 == taxName2)&&(identical(other.taxName3, taxName3) || other.taxName3 == taxName3)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.entityType, entityType) || other.entityType == entityType)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.foreignAmount, foreignAmount) || other.foreignAmount == foreignAmount)&&(identical(other.exchangeRate, exchangeRate) || other.exchangeRate == exchangeRate)&&(identical(other.taxAmount1, taxAmount1) || other.taxAmount1 == taxAmount1)&&(identical(other.taxAmount2, taxAmount2) || other.taxAmount2 == taxAmount2)&&(identical(other.taxAmount3, taxAmount3) || other.taxAmount3 == taxAmount3)&&(identical(other.taxRate1, taxRate1) || other.taxRate1 == taxRate1)&&(identical(other.taxRate2, taxRate2) || other.taxRate2 == taxRate2)&&(identical(other.taxRate3, taxRate3) || other.taxRate3 == taxRate3)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.shouldBeInvoiced, shouldBeInvoiced) || other.shouldBeInvoiced == shouldBeInvoiced)&&(identical(other.invoiceDocuments, invoiceDocuments) || other.invoiceDocuments == invoiceDocuments)&&(identical(other.usesInclusiveTaxes, usesInclusiveTaxes) || other.usesInclusiveTaxes == usesInclusiveTaxes)&&(identical(other.calculateTaxByAmount, calculateTaxByAmount) || other.calculateTaxByAmount == calculateTaxByAmount)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&const DeepCollectionEquality().equals(other._documents, _documents)&&const DeepCollectionEquality().equals(other._tagIds, _tagIds)&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,userId,assignedUserId,vendorId,invoiceId,clientId,bankId,invoiceCurrencyId,expenseCurrencyId,currencyId,categoryId,paymentTypeId,recurringExpenseId,privateNotes,publicNotes,transactionReference,transactionId,date,number,paymentDate,customValue1,customValue2,customValue3,customValue4,taxName1,taxName2,taxName3,projectId,entityType,amount,foreignAmount,exchangeRate,taxAmount1,taxAmount2,taxAmount3,taxRate1,taxRate2,taxRate3,isDeleted,shouldBeInvoiced,invoiceDocuments,usesInclusiveTaxes,calculateTaxByAmount,updatedAt,createdAt,archivedAt,const DeepCollectionEquality().hash(_documents),const DeepCollectionEquality().hash(_tagIds),isDirty]);

@override
String toString() {
  return 'Expense(id: $id, userId: $userId, assignedUserId: $assignedUserId, vendorId: $vendorId, invoiceId: $invoiceId, clientId: $clientId, bankId: $bankId, invoiceCurrencyId: $invoiceCurrencyId, expenseCurrencyId: $expenseCurrencyId, currencyId: $currencyId, categoryId: $categoryId, paymentTypeId: $paymentTypeId, recurringExpenseId: $recurringExpenseId, privateNotes: $privateNotes, publicNotes: $publicNotes, transactionReference: $transactionReference, transactionId: $transactionId, date: $date, number: $number, paymentDate: $paymentDate, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, taxName1: $taxName1, taxName2: $taxName2, taxName3: $taxName3, projectId: $projectId, entityType: $entityType, amount: $amount, foreignAmount: $foreignAmount, exchangeRate: $exchangeRate, taxAmount1: $taxAmount1, taxAmount2: $taxAmount2, taxAmount3: $taxAmount3, taxRate1: $taxRate1, taxRate2: $taxRate2, taxRate3: $taxRate3, isDeleted: $isDeleted, shouldBeInvoiced: $shouldBeInvoiced, invoiceDocuments: $invoiceDocuments, usesInclusiveTaxes: $usesInclusiveTaxes, calculateTaxByAmount: $calculateTaxByAmount, updatedAt: $updatedAt, createdAt: $createdAt, archivedAt: $archivedAt, documents: $documents, tagIds: $tagIds, isDirty: $isDirty)';
}


}

/// @nodoc
abstract mixin class _$ExpenseCopyWith<$Res> implements $ExpenseCopyWith<$Res> {
  factory _$ExpenseCopyWith(_Expense value, $Res Function(_Expense) _then) = __$ExpenseCopyWithImpl;
@override @useResult
$Res call({
 String id, String userId, String assignedUserId, String vendorId, String invoiceId, String clientId, String bankId, String invoiceCurrencyId, String expenseCurrencyId, String currencyId, String categoryId, String paymentTypeId, String recurringExpenseId, String privateNotes, String publicNotes, String transactionReference, String transactionId, Date? date, String number, Date? paymentDate, String customValue1, String customValue2, String customValue3, String customValue4, String taxName1, String taxName2, String taxName3, String projectId, String entityType, Decimal amount, Decimal foreignAmount, Decimal exchangeRate, Decimal taxAmount1, Decimal taxAmount2, Decimal taxAmount3, Decimal taxRate1, Decimal taxRate2, Decimal taxRate3, bool isDeleted, bool shouldBeInvoiced, bool invoiceDocuments, bool usesInclusiveTaxes, bool calculateTaxByAmount, DateTime updatedAt, DateTime createdAt, DateTime? archivedAt, List<Document> documents, List<String> tagIds, bool isDirty
});




}
/// @nodoc
class __$ExpenseCopyWithImpl<$Res>
    implements _$ExpenseCopyWith<$Res> {
  __$ExpenseCopyWithImpl(this._self, this._then);

  final _Expense _self;
  final $Res Function(_Expense) _then;

/// Create a copy of Expense
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? assignedUserId = null,Object? vendorId = null,Object? invoiceId = null,Object? clientId = null,Object? bankId = null,Object? invoiceCurrencyId = null,Object? expenseCurrencyId = null,Object? currencyId = null,Object? categoryId = null,Object? paymentTypeId = null,Object? recurringExpenseId = null,Object? privateNotes = null,Object? publicNotes = null,Object? transactionReference = null,Object? transactionId = null,Object? date = freezed,Object? number = null,Object? paymentDate = freezed,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? taxName1 = null,Object? taxName2 = null,Object? taxName3 = null,Object? projectId = null,Object? entityType = null,Object? amount = null,Object? foreignAmount = null,Object? exchangeRate = null,Object? taxAmount1 = null,Object? taxAmount2 = null,Object? taxAmount3 = null,Object? taxRate1 = null,Object? taxRate2 = null,Object? taxRate3 = null,Object? isDeleted = null,Object? shouldBeInvoiced = null,Object? invoiceDocuments = null,Object? usesInclusiveTaxes = null,Object? calculateTaxByAmount = null,Object? updatedAt = null,Object? createdAt = null,Object? archivedAt = freezed,Object? documents = null,Object? tagIds = null,Object? isDirty = null,}) {
  return _then(_Expense(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,vendorId: null == vendorId ? _self.vendorId : vendorId // ignore: cast_nullable_to_non_nullable
as String,invoiceId: null == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as String,clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,bankId: null == bankId ? _self.bankId : bankId // ignore: cast_nullable_to_non_nullable
as String,invoiceCurrencyId: null == invoiceCurrencyId ? _self.invoiceCurrencyId : invoiceCurrencyId // ignore: cast_nullable_to_non_nullable
as String,expenseCurrencyId: null == expenseCurrencyId ? _self.expenseCurrencyId : expenseCurrencyId // ignore: cast_nullable_to_non_nullable
as String,currencyId: null == currencyId ? _self.currencyId : currencyId // ignore: cast_nullable_to_non_nullable
as String,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String,paymentTypeId: null == paymentTypeId ? _self.paymentTypeId : paymentTypeId // ignore: cast_nullable_to_non_nullable
as String,recurringExpenseId: null == recurringExpenseId ? _self.recurringExpenseId : recurringExpenseId // ignore: cast_nullable_to_non_nullable
as String,privateNotes: null == privateNotes ? _self.privateNotes : privateNotes // ignore: cast_nullable_to_non_nullable
as String,publicNotes: null == publicNotes ? _self.publicNotes : publicNotes // ignore: cast_nullable_to_non_nullable
as String,transactionReference: null == transactionReference ? _self.transactionReference : transactionReference // ignore: cast_nullable_to_non_nullable
as String,transactionId: null == transactionId ? _self.transactionId : transactionId // ignore: cast_nullable_to_non_nullable
as String,date: freezed == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as Date?,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,paymentDate: freezed == paymentDate ? _self.paymentDate : paymentDate // ignore: cast_nullable_to_non_nullable
as Date?,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,taxName1: null == taxName1 ? _self.taxName1 : taxName1 // ignore: cast_nullable_to_non_nullable
as String,taxName2: null == taxName2 ? _self.taxName2 : taxName2 // ignore: cast_nullable_to_non_nullable
as String,taxName3: null == taxName3 ? _self.taxName3 : taxName3 // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,entityType: null == entityType ? _self.entityType : entityType // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as Decimal,foreignAmount: null == foreignAmount ? _self.foreignAmount : foreignAmount // ignore: cast_nullable_to_non_nullable
as Decimal,exchangeRate: null == exchangeRate ? _self.exchangeRate : exchangeRate // ignore: cast_nullable_to_non_nullable
as Decimal,taxAmount1: null == taxAmount1 ? _self.taxAmount1 : taxAmount1 // ignore: cast_nullable_to_non_nullable
as Decimal,taxAmount2: null == taxAmount2 ? _self.taxAmount2 : taxAmount2 // ignore: cast_nullable_to_non_nullable
as Decimal,taxAmount3: null == taxAmount3 ? _self.taxAmount3 : taxAmount3 // ignore: cast_nullable_to_non_nullable
as Decimal,taxRate1: null == taxRate1 ? _self.taxRate1 : taxRate1 // ignore: cast_nullable_to_non_nullable
as Decimal,taxRate2: null == taxRate2 ? _self.taxRate2 : taxRate2 // ignore: cast_nullable_to_non_nullable
as Decimal,taxRate3: null == taxRate3 ? _self.taxRate3 : taxRate3 // ignore: cast_nullable_to_non_nullable
as Decimal,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,shouldBeInvoiced: null == shouldBeInvoiced ? _self.shouldBeInvoiced : shouldBeInvoiced // ignore: cast_nullable_to_non_nullable
as bool,invoiceDocuments: null == invoiceDocuments ? _self.invoiceDocuments : invoiceDocuments // ignore: cast_nullable_to_non_nullable
as bool,usesInclusiveTaxes: null == usesInclusiveTaxes ? _self.usesInclusiveTaxes : usesInclusiveTaxes // ignore: cast_nullable_to_non_nullable
as bool,calculateTaxByAmount: null == calculateTaxByAmount ? _self.calculateTaxByAmount : calculateTaxByAmount // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,documents: null == documents ? _self._documents : documents // ignore: cast_nullable_to_non_nullable
as List<Document>,tagIds: null == tagIds ? _self._tagIds : tagIds // ignore: cast_nullable_to_non_nullable
as List<String>,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
