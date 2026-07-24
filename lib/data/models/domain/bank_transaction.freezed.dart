// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bank_transaction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BankTransaction {

 String get id; Decimal get amount; String get currencyId; String get category; String get baseType; Date? get date; String get bankAccountId; String get description; String get statusId; String get categoryId; String get invoiceIds; String get paymentId; String get expenseId; String get vendorId; String get transactionId; String get transactionRuleId; String get participantName; String get participant; bool get isDeleted; DateTime get updatedAt; DateTime get createdAt; DateTime? get archivedAt; List<String> get tagIds; bool get isDirty;
/// Create a copy of BankTransaction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BankTransactionCopyWith<BankTransaction> get copyWith => _$BankTransactionCopyWithImpl<BankTransaction>(this as BankTransaction, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BankTransaction&&(identical(other.id, id) || other.id == id)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.category, category) || other.category == category)&&(identical(other.baseType, baseType) || other.baseType == baseType)&&(identical(other.date, date) || other.date == date)&&(identical(other.bankAccountId, bankAccountId) || other.bankAccountId == bankAccountId)&&(identical(other.description, description) || other.description == description)&&(identical(other.statusId, statusId) || other.statusId == statusId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.invoiceIds, invoiceIds) || other.invoiceIds == invoiceIds)&&(identical(other.paymentId, paymentId) || other.paymentId == paymentId)&&(identical(other.expenseId, expenseId) || other.expenseId == expenseId)&&(identical(other.vendorId, vendorId) || other.vendorId == vendorId)&&(identical(other.transactionId, transactionId) || other.transactionId == transactionId)&&(identical(other.transactionRuleId, transactionRuleId) || other.transactionRuleId == transactionRuleId)&&(identical(other.participantName, participantName) || other.participantName == participantName)&&(identical(other.participant, participant) || other.participant == participant)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&const DeepCollectionEquality().equals(other.tagIds, tagIds)&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,amount,currencyId,category,baseType,date,bankAccountId,description,statusId,categoryId,invoiceIds,paymentId,expenseId,vendorId,transactionId,transactionRuleId,participantName,participant,isDeleted,updatedAt,createdAt,archivedAt,const DeepCollectionEquality().hash(tagIds),isDirty]);

@override
String toString() {
  return 'BankTransaction(id: $id, amount: $amount, currencyId: $currencyId, category: $category, baseType: $baseType, date: $date, bankAccountId: $bankAccountId, description: $description, statusId: $statusId, categoryId: $categoryId, invoiceIds: $invoiceIds, paymentId: $paymentId, expenseId: $expenseId, vendorId: $vendorId, transactionId: $transactionId, transactionRuleId: $transactionRuleId, participantName: $participantName, participant: $participant, isDeleted: $isDeleted, updatedAt: $updatedAt, createdAt: $createdAt, archivedAt: $archivedAt, tagIds: $tagIds, isDirty: $isDirty)';
}


}

/// @nodoc
abstract mixin class $BankTransactionCopyWith<$Res>  {
  factory $BankTransactionCopyWith(BankTransaction value, $Res Function(BankTransaction) _then) = _$BankTransactionCopyWithImpl;
@useResult
$Res call({
 String id, Decimal amount, String currencyId, String category, String baseType, Date? date, String bankAccountId, String description, String statusId, String categoryId, String invoiceIds, String paymentId, String expenseId, String vendorId, String transactionId, String transactionRuleId, String participantName, String participant, bool isDeleted, DateTime updatedAt, DateTime createdAt, DateTime? archivedAt, List<String> tagIds, bool isDirty
});




}
/// @nodoc
class _$BankTransactionCopyWithImpl<$Res>
    implements $BankTransactionCopyWith<$Res> {
  _$BankTransactionCopyWithImpl(this._self, this._then);

  final BankTransaction _self;
  final $Res Function(BankTransaction) _then;

/// Create a copy of BankTransaction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? amount = null,Object? currencyId = null,Object? category = null,Object? baseType = null,Object? date = freezed,Object? bankAccountId = null,Object? description = null,Object? statusId = null,Object? categoryId = null,Object? invoiceIds = null,Object? paymentId = null,Object? expenseId = null,Object? vendorId = null,Object? transactionId = null,Object? transactionRuleId = null,Object? participantName = null,Object? participant = null,Object? isDeleted = null,Object? updatedAt = null,Object? createdAt = null,Object? archivedAt = freezed,Object? tagIds = null,Object? isDirty = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as Decimal,currencyId: null == currencyId ? _self.currencyId : currencyId // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,baseType: null == baseType ? _self.baseType : baseType // ignore: cast_nullable_to_non_nullable
as String,date: freezed == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as Date?,bankAccountId: null == bankAccountId ? _self.bankAccountId : bankAccountId // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,statusId: null == statusId ? _self.statusId : statusId // ignore: cast_nullable_to_non_nullable
as String,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String,invoiceIds: null == invoiceIds ? _self.invoiceIds : invoiceIds // ignore: cast_nullable_to_non_nullable
as String,paymentId: null == paymentId ? _self.paymentId : paymentId // ignore: cast_nullable_to_non_nullable
as String,expenseId: null == expenseId ? _self.expenseId : expenseId // ignore: cast_nullable_to_non_nullable
as String,vendorId: null == vendorId ? _self.vendorId : vendorId // ignore: cast_nullable_to_non_nullable
as String,transactionId: null == transactionId ? _self.transactionId : transactionId // ignore: cast_nullable_to_non_nullable
as String,transactionRuleId: null == transactionRuleId ? _self.transactionRuleId : transactionRuleId // ignore: cast_nullable_to_non_nullable
as String,participantName: null == participantName ? _self.participantName : participantName // ignore: cast_nullable_to_non_nullable
as String,participant: null == participant ? _self.participant : participant // ignore: cast_nullable_to_non_nullable
as String,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,tagIds: null == tagIds ? _self.tagIds : tagIds // ignore: cast_nullable_to_non_nullable
as List<String>,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [BankTransaction].
extension BankTransactionPatterns on BankTransaction {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BankTransaction value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BankTransaction() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BankTransaction value)  $default,){
final _that = this;
switch (_that) {
case _BankTransaction():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BankTransaction value)?  $default,){
final _that = this;
switch (_that) {
case _BankTransaction() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  Decimal amount,  String currencyId,  String category,  String baseType,  Date? date,  String bankAccountId,  String description,  String statusId,  String categoryId,  String invoiceIds,  String paymentId,  String expenseId,  String vendorId,  String transactionId,  String transactionRuleId,  String participantName,  String participant,  bool isDeleted,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  List<String> tagIds,  bool isDirty)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BankTransaction() when $default != null:
return $default(_that.id,_that.amount,_that.currencyId,_that.category,_that.baseType,_that.date,_that.bankAccountId,_that.description,_that.statusId,_that.categoryId,_that.invoiceIds,_that.paymentId,_that.expenseId,_that.vendorId,_that.transactionId,_that.transactionRuleId,_that.participantName,_that.participant,_that.isDeleted,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.tagIds,_that.isDirty);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  Decimal amount,  String currencyId,  String category,  String baseType,  Date? date,  String bankAccountId,  String description,  String statusId,  String categoryId,  String invoiceIds,  String paymentId,  String expenseId,  String vendorId,  String transactionId,  String transactionRuleId,  String participantName,  String participant,  bool isDeleted,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  List<String> tagIds,  bool isDirty)  $default,) {final _that = this;
switch (_that) {
case _BankTransaction():
return $default(_that.id,_that.amount,_that.currencyId,_that.category,_that.baseType,_that.date,_that.bankAccountId,_that.description,_that.statusId,_that.categoryId,_that.invoiceIds,_that.paymentId,_that.expenseId,_that.vendorId,_that.transactionId,_that.transactionRuleId,_that.participantName,_that.participant,_that.isDeleted,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.tagIds,_that.isDirty);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  Decimal amount,  String currencyId,  String category,  String baseType,  Date? date,  String bankAccountId,  String description,  String statusId,  String categoryId,  String invoiceIds,  String paymentId,  String expenseId,  String vendorId,  String transactionId,  String transactionRuleId,  String participantName,  String participant,  bool isDeleted,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  List<String> tagIds,  bool isDirty)?  $default,) {final _that = this;
switch (_that) {
case _BankTransaction() when $default != null:
return $default(_that.id,_that.amount,_that.currencyId,_that.category,_that.baseType,_that.date,_that.bankAccountId,_that.description,_that.statusId,_that.categoryId,_that.invoiceIds,_that.paymentId,_that.expenseId,_that.vendorId,_that.transactionId,_that.transactionRuleId,_that.participantName,_that.participant,_that.isDeleted,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.tagIds,_that.isDirty);case _:
  return null;

}
}

}

/// @nodoc


class _BankTransaction extends BankTransaction {
  const _BankTransaction({required this.id, required this.amount, required this.currencyId, required this.category, required this.baseType, required this.date, required this.bankAccountId, required this.description, required this.statusId, required this.categoryId, required this.invoiceIds, required this.paymentId, required this.expenseId, required this.vendorId, required this.transactionId, required this.transactionRuleId, required this.participantName, required this.participant, required this.isDeleted, required this.updatedAt, required this.createdAt, required this.archivedAt, final  List<String> tagIds = const <String>[], this.isDirty = false}): _tagIds = tagIds,super._();
  

@override final  String id;
@override final  Decimal amount;
@override final  String currencyId;
@override final  String category;
@override final  String baseType;
@override final  Date? date;
@override final  String bankAccountId;
@override final  String description;
@override final  String statusId;
@override final  String categoryId;
@override final  String invoiceIds;
@override final  String paymentId;
@override final  String expenseId;
@override final  String vendorId;
@override final  String transactionId;
@override final  String transactionRuleId;
@override final  String participantName;
@override final  String participant;
@override final  bool isDeleted;
@override final  DateTime updatedAt;
@override final  DateTime createdAt;
@override final  DateTime? archivedAt;
 final  List<String> _tagIds;
@override@JsonKey() List<String> get tagIds {
  if (_tagIds is EqualUnmodifiableListView) return _tagIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tagIds);
}

@override@JsonKey() final  bool isDirty;

/// Create a copy of BankTransaction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BankTransactionCopyWith<_BankTransaction> get copyWith => __$BankTransactionCopyWithImpl<_BankTransaction>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BankTransaction&&(identical(other.id, id) || other.id == id)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.category, category) || other.category == category)&&(identical(other.baseType, baseType) || other.baseType == baseType)&&(identical(other.date, date) || other.date == date)&&(identical(other.bankAccountId, bankAccountId) || other.bankAccountId == bankAccountId)&&(identical(other.description, description) || other.description == description)&&(identical(other.statusId, statusId) || other.statusId == statusId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.invoiceIds, invoiceIds) || other.invoiceIds == invoiceIds)&&(identical(other.paymentId, paymentId) || other.paymentId == paymentId)&&(identical(other.expenseId, expenseId) || other.expenseId == expenseId)&&(identical(other.vendorId, vendorId) || other.vendorId == vendorId)&&(identical(other.transactionId, transactionId) || other.transactionId == transactionId)&&(identical(other.transactionRuleId, transactionRuleId) || other.transactionRuleId == transactionRuleId)&&(identical(other.participantName, participantName) || other.participantName == participantName)&&(identical(other.participant, participant) || other.participant == participant)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&const DeepCollectionEquality().equals(other._tagIds, _tagIds)&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,amount,currencyId,category,baseType,date,bankAccountId,description,statusId,categoryId,invoiceIds,paymentId,expenseId,vendorId,transactionId,transactionRuleId,participantName,participant,isDeleted,updatedAt,createdAt,archivedAt,const DeepCollectionEquality().hash(_tagIds),isDirty]);

@override
String toString() {
  return 'BankTransaction(id: $id, amount: $amount, currencyId: $currencyId, category: $category, baseType: $baseType, date: $date, bankAccountId: $bankAccountId, description: $description, statusId: $statusId, categoryId: $categoryId, invoiceIds: $invoiceIds, paymentId: $paymentId, expenseId: $expenseId, vendorId: $vendorId, transactionId: $transactionId, transactionRuleId: $transactionRuleId, participantName: $participantName, participant: $participant, isDeleted: $isDeleted, updatedAt: $updatedAt, createdAt: $createdAt, archivedAt: $archivedAt, tagIds: $tagIds, isDirty: $isDirty)';
}


}

/// @nodoc
abstract mixin class _$BankTransactionCopyWith<$Res> implements $BankTransactionCopyWith<$Res> {
  factory _$BankTransactionCopyWith(_BankTransaction value, $Res Function(_BankTransaction) _then) = __$BankTransactionCopyWithImpl;
@override @useResult
$Res call({
 String id, Decimal amount, String currencyId, String category, String baseType, Date? date, String bankAccountId, String description, String statusId, String categoryId, String invoiceIds, String paymentId, String expenseId, String vendorId, String transactionId, String transactionRuleId, String participantName, String participant, bool isDeleted, DateTime updatedAt, DateTime createdAt, DateTime? archivedAt, List<String> tagIds, bool isDirty
});




}
/// @nodoc
class __$BankTransactionCopyWithImpl<$Res>
    implements _$BankTransactionCopyWith<$Res> {
  __$BankTransactionCopyWithImpl(this._self, this._then);

  final _BankTransaction _self;
  final $Res Function(_BankTransaction) _then;

/// Create a copy of BankTransaction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? amount = null,Object? currencyId = null,Object? category = null,Object? baseType = null,Object? date = freezed,Object? bankAccountId = null,Object? description = null,Object? statusId = null,Object? categoryId = null,Object? invoiceIds = null,Object? paymentId = null,Object? expenseId = null,Object? vendorId = null,Object? transactionId = null,Object? transactionRuleId = null,Object? participantName = null,Object? participant = null,Object? isDeleted = null,Object? updatedAt = null,Object? createdAt = null,Object? archivedAt = freezed,Object? tagIds = null,Object? isDirty = null,}) {
  return _then(_BankTransaction(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as Decimal,currencyId: null == currencyId ? _self.currencyId : currencyId // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,baseType: null == baseType ? _self.baseType : baseType // ignore: cast_nullable_to_non_nullable
as String,date: freezed == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as Date?,bankAccountId: null == bankAccountId ? _self.bankAccountId : bankAccountId // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,statusId: null == statusId ? _self.statusId : statusId // ignore: cast_nullable_to_non_nullable
as String,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String,invoiceIds: null == invoiceIds ? _self.invoiceIds : invoiceIds // ignore: cast_nullable_to_non_nullable
as String,paymentId: null == paymentId ? _self.paymentId : paymentId // ignore: cast_nullable_to_non_nullable
as String,expenseId: null == expenseId ? _self.expenseId : expenseId // ignore: cast_nullable_to_non_nullable
as String,vendorId: null == vendorId ? _self.vendorId : vendorId // ignore: cast_nullable_to_non_nullable
as String,transactionId: null == transactionId ? _self.transactionId : transactionId // ignore: cast_nullable_to_non_nullable
as String,transactionRuleId: null == transactionRuleId ? _self.transactionRuleId : transactionRuleId // ignore: cast_nullable_to_non_nullable
as String,participantName: null == participantName ? _self.participantName : participantName // ignore: cast_nullable_to_non_nullable
as String,participant: null == participant ? _self.participant : participant // ignore: cast_nullable_to_non_nullable
as String,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,tagIds: null == tagIds ? _self._tagIds : tagIds // ignore: cast_nullable_to_non_nullable
as List<String>,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
