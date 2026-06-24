// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'activity_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ActivityLabelApi {

 String get label;@JsonKey(name: 'hashed_id') String get hashedId;// Only the `contact` object carries this ('clients' | 'vendors'); it
// routes a contact link to the right detail screen. Harmless default
// for every other label object.
@JsonKey(name: 'contact_entity') String get contactEntity;
/// Create a copy of ActivityLabelApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<ActivityLabelApi> get copyWith => _$ActivityLabelApiCopyWithImpl<ActivityLabelApi>(this as ActivityLabelApi, _$identity);

  /// Serializes this ActivityLabelApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ActivityLabelApi&&(identical(other.label, label) || other.label == label)&&(identical(other.hashedId, hashedId) || other.hashedId == hashedId)&&(identical(other.contactEntity, contactEntity) || other.contactEntity == contactEntity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,label,hashedId,contactEntity);

@override
String toString() {
  return 'ActivityLabelApi(label: $label, hashedId: $hashedId, contactEntity: $contactEntity)';
}


}

/// @nodoc
abstract mixin class $ActivityLabelApiCopyWith<$Res>  {
  factory $ActivityLabelApiCopyWith(ActivityLabelApi value, $Res Function(ActivityLabelApi) _then) = _$ActivityLabelApiCopyWithImpl;
@useResult
$Res call({
 String label,@JsonKey(name: 'hashed_id') String hashedId,@JsonKey(name: 'contact_entity') String contactEntity
});




}
/// @nodoc
class _$ActivityLabelApiCopyWithImpl<$Res>
    implements $ActivityLabelApiCopyWith<$Res> {
  _$ActivityLabelApiCopyWithImpl(this._self, this._then);

  final ActivityLabelApi _self;
  final $Res Function(ActivityLabelApi) _then;

/// Create a copy of ActivityLabelApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? label = null,Object? hashedId = null,Object? contactEntity = null,}) {
  return _then(_self.copyWith(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,hashedId: null == hashedId ? _self.hashedId : hashedId // ignore: cast_nullable_to_non_nullable
as String,contactEntity: null == contactEntity ? _self.contactEntity : contactEntity // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ActivityLabelApi].
extension ActivityLabelApiPatterns on ActivityLabelApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ActivityLabelApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ActivityLabelApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ActivityLabelApi value)  $default,){
final _that = this;
switch (_that) {
case _ActivityLabelApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ActivityLabelApi value)?  $default,){
final _that = this;
switch (_that) {
case _ActivityLabelApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String label, @JsonKey(name: 'hashed_id')  String hashedId, @JsonKey(name: 'contact_entity')  String contactEntity)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ActivityLabelApi() when $default != null:
return $default(_that.label,_that.hashedId,_that.contactEntity);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String label, @JsonKey(name: 'hashed_id')  String hashedId, @JsonKey(name: 'contact_entity')  String contactEntity)  $default,) {final _that = this;
switch (_that) {
case _ActivityLabelApi():
return $default(_that.label,_that.hashedId,_that.contactEntity);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String label, @JsonKey(name: 'hashed_id')  String hashedId, @JsonKey(name: 'contact_entity')  String contactEntity)?  $default,) {final _that = this;
switch (_that) {
case _ActivityLabelApi() when $default != null:
return $default(_that.label,_that.hashedId,_that.contactEntity);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ActivityLabelApi implements ActivityLabelApi {
  const _ActivityLabelApi({this.label = '', @JsonKey(name: 'hashed_id') this.hashedId = '', @JsonKey(name: 'contact_entity') this.contactEntity = ''});
  factory _ActivityLabelApi.fromJson(Map<String, dynamic> json) => _$ActivityLabelApiFromJson(json);

@override@JsonKey() final  String label;
@override@JsonKey(name: 'hashed_id') final  String hashedId;
// Only the `contact` object carries this ('clients' | 'vendors'); it
// routes a contact link to the right detail screen. Harmless default
// for every other label object.
@override@JsonKey(name: 'contact_entity') final  String contactEntity;

/// Create a copy of ActivityLabelApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ActivityLabelApiCopyWith<_ActivityLabelApi> get copyWith => __$ActivityLabelApiCopyWithImpl<_ActivityLabelApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ActivityLabelApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ActivityLabelApi&&(identical(other.label, label) || other.label == label)&&(identical(other.hashedId, hashedId) || other.hashedId == hashedId)&&(identical(other.contactEntity, contactEntity) || other.contactEntity == contactEntity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,label,hashedId,contactEntity);

@override
String toString() {
  return 'ActivityLabelApi(label: $label, hashedId: $hashedId, contactEntity: $contactEntity)';
}


}

/// @nodoc
abstract mixin class _$ActivityLabelApiCopyWith<$Res> implements $ActivityLabelApiCopyWith<$Res> {
  factory _$ActivityLabelApiCopyWith(_ActivityLabelApi value, $Res Function(_ActivityLabelApi) _then) = __$ActivityLabelApiCopyWithImpl;
@override @useResult
$Res call({
 String label,@JsonKey(name: 'hashed_id') String hashedId,@JsonKey(name: 'contact_entity') String contactEntity
});




}
/// @nodoc
class __$ActivityLabelApiCopyWithImpl<$Res>
    implements _$ActivityLabelApiCopyWith<$Res> {
  __$ActivityLabelApiCopyWithImpl(this._self, this._then);

  final _ActivityLabelApi _self;
  final $Res Function(_ActivityLabelApi) _then;

/// Create a copy of ActivityLabelApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? label = null,Object? hashedId = null,Object? contactEntity = null,}) {
  return _then(_ActivityLabelApi(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,hashedId: null == hashedId ? _self.hashedId : hashedId // ignore: cast_nullable_to_non_nullable
as String,contactEntity: null == contactEntity ? _self.contactEntity : contactEntity // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ActivityApi {

@JsonKey(name: 'hashed_id') String get id;@JsonKey(name: 'activity_type_id') int get activityTypeId; String get notes;@JsonKey(name: 'created_at') int get createdAt; String get ip; ActivityLabelApi? get user; ActivityLabelApi? get client; ActivityLabelApi? get invoice; ActivityLabelApi? get contact; ActivityLabelApi? get quote; ActivityLabelApi? get payment;@JsonKey(name: 'payment_amount') ActivityLabelApi? get paymentAmount; ActivityLabelApi? get expense; ActivityLabelApi? get credit; ActivityLabelApi? get task; ActivityLabelApi? get vendor;@JsonKey(name: 'recurring_invoice') ActivityLabelApi? get recurringInvoice;@JsonKey(name: 'recurring_expense') ActivityLabelApi? get recurringExpense;@JsonKey(name: 'purchase_order') ActivityLabelApi? get purchaseOrder; ActivityLabelApi? get subscription; ActivityLabelApi? get adjustment;
/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ActivityApiCopyWith<ActivityApi> get copyWith => _$ActivityApiCopyWithImpl<ActivityApi>(this as ActivityApi, _$identity);

  /// Serializes this ActivityApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ActivityApi&&(identical(other.id, id) || other.id == id)&&(identical(other.activityTypeId, activityTypeId) || other.activityTypeId == activityTypeId)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.ip, ip) || other.ip == ip)&&(identical(other.user, user) || other.user == user)&&(identical(other.client, client) || other.client == client)&&(identical(other.invoice, invoice) || other.invoice == invoice)&&(identical(other.contact, contact) || other.contact == contact)&&(identical(other.quote, quote) || other.quote == quote)&&(identical(other.payment, payment) || other.payment == payment)&&(identical(other.paymentAmount, paymentAmount) || other.paymentAmount == paymentAmount)&&(identical(other.expense, expense) || other.expense == expense)&&(identical(other.credit, credit) || other.credit == credit)&&(identical(other.task, task) || other.task == task)&&(identical(other.vendor, vendor) || other.vendor == vendor)&&(identical(other.recurringInvoice, recurringInvoice) || other.recurringInvoice == recurringInvoice)&&(identical(other.recurringExpense, recurringExpense) || other.recurringExpense == recurringExpense)&&(identical(other.purchaseOrder, purchaseOrder) || other.purchaseOrder == purchaseOrder)&&(identical(other.subscription, subscription) || other.subscription == subscription)&&(identical(other.adjustment, adjustment) || other.adjustment == adjustment));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,activityTypeId,notes,createdAt,ip,user,client,invoice,contact,quote,payment,paymentAmount,expense,credit,task,vendor,recurringInvoice,recurringExpense,purchaseOrder,subscription,adjustment]);

@override
String toString() {
  return 'ActivityApi(id: $id, activityTypeId: $activityTypeId, notes: $notes, createdAt: $createdAt, ip: $ip, user: $user, client: $client, invoice: $invoice, contact: $contact, quote: $quote, payment: $payment, paymentAmount: $paymentAmount, expense: $expense, credit: $credit, task: $task, vendor: $vendor, recurringInvoice: $recurringInvoice, recurringExpense: $recurringExpense, purchaseOrder: $purchaseOrder, subscription: $subscription, adjustment: $adjustment)';
}


}

/// @nodoc
abstract mixin class $ActivityApiCopyWith<$Res>  {
  factory $ActivityApiCopyWith(ActivityApi value, $Res Function(ActivityApi) _then) = _$ActivityApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'hashed_id') String id,@JsonKey(name: 'activity_type_id') int activityTypeId, String notes,@JsonKey(name: 'created_at') int createdAt, String ip, ActivityLabelApi? user, ActivityLabelApi? client, ActivityLabelApi? invoice, ActivityLabelApi? contact, ActivityLabelApi? quote, ActivityLabelApi? payment,@JsonKey(name: 'payment_amount') ActivityLabelApi? paymentAmount, ActivityLabelApi? expense, ActivityLabelApi? credit, ActivityLabelApi? task, ActivityLabelApi? vendor,@JsonKey(name: 'recurring_invoice') ActivityLabelApi? recurringInvoice,@JsonKey(name: 'recurring_expense') ActivityLabelApi? recurringExpense,@JsonKey(name: 'purchase_order') ActivityLabelApi? purchaseOrder, ActivityLabelApi? subscription, ActivityLabelApi? adjustment
});


$ActivityLabelApiCopyWith<$Res>? get user;$ActivityLabelApiCopyWith<$Res>? get client;$ActivityLabelApiCopyWith<$Res>? get invoice;$ActivityLabelApiCopyWith<$Res>? get contact;$ActivityLabelApiCopyWith<$Res>? get quote;$ActivityLabelApiCopyWith<$Res>? get payment;$ActivityLabelApiCopyWith<$Res>? get paymentAmount;$ActivityLabelApiCopyWith<$Res>? get expense;$ActivityLabelApiCopyWith<$Res>? get credit;$ActivityLabelApiCopyWith<$Res>? get task;$ActivityLabelApiCopyWith<$Res>? get vendor;$ActivityLabelApiCopyWith<$Res>? get recurringInvoice;$ActivityLabelApiCopyWith<$Res>? get recurringExpense;$ActivityLabelApiCopyWith<$Res>? get purchaseOrder;$ActivityLabelApiCopyWith<$Res>? get subscription;$ActivityLabelApiCopyWith<$Res>? get adjustment;

}
/// @nodoc
class _$ActivityApiCopyWithImpl<$Res>
    implements $ActivityApiCopyWith<$Res> {
  _$ActivityApiCopyWithImpl(this._self, this._then);

  final ActivityApi _self;
  final $Res Function(ActivityApi) _then;

/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? activityTypeId = null,Object? notes = null,Object? createdAt = null,Object? ip = null,Object? user = freezed,Object? client = freezed,Object? invoice = freezed,Object? contact = freezed,Object? quote = freezed,Object? payment = freezed,Object? paymentAmount = freezed,Object? expense = freezed,Object? credit = freezed,Object? task = freezed,Object? vendor = freezed,Object? recurringInvoice = freezed,Object? recurringExpense = freezed,Object? purchaseOrder = freezed,Object? subscription = freezed,Object? adjustment = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,activityTypeId: null == activityTypeId ? _self.activityTypeId : activityTypeId // ignore: cast_nullable_to_non_nullable
as int,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,user: freezed == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as ActivityLabelApi?,client: freezed == client ? _self.client : client // ignore: cast_nullable_to_non_nullable
as ActivityLabelApi?,invoice: freezed == invoice ? _self.invoice : invoice // ignore: cast_nullable_to_non_nullable
as ActivityLabelApi?,contact: freezed == contact ? _self.contact : contact // ignore: cast_nullable_to_non_nullable
as ActivityLabelApi?,quote: freezed == quote ? _self.quote : quote // ignore: cast_nullable_to_non_nullable
as ActivityLabelApi?,payment: freezed == payment ? _self.payment : payment // ignore: cast_nullable_to_non_nullable
as ActivityLabelApi?,paymentAmount: freezed == paymentAmount ? _self.paymentAmount : paymentAmount // ignore: cast_nullable_to_non_nullable
as ActivityLabelApi?,expense: freezed == expense ? _self.expense : expense // ignore: cast_nullable_to_non_nullable
as ActivityLabelApi?,credit: freezed == credit ? _self.credit : credit // ignore: cast_nullable_to_non_nullable
as ActivityLabelApi?,task: freezed == task ? _self.task : task // ignore: cast_nullable_to_non_nullable
as ActivityLabelApi?,vendor: freezed == vendor ? _self.vendor : vendor // ignore: cast_nullable_to_non_nullable
as ActivityLabelApi?,recurringInvoice: freezed == recurringInvoice ? _self.recurringInvoice : recurringInvoice // ignore: cast_nullable_to_non_nullable
as ActivityLabelApi?,recurringExpense: freezed == recurringExpense ? _self.recurringExpense : recurringExpense // ignore: cast_nullable_to_non_nullable
as ActivityLabelApi?,purchaseOrder: freezed == purchaseOrder ? _self.purchaseOrder : purchaseOrder // ignore: cast_nullable_to_non_nullable
as ActivityLabelApi?,subscription: freezed == subscription ? _self.subscription : subscription // ignore: cast_nullable_to_non_nullable
as ActivityLabelApi?,adjustment: freezed == adjustment ? _self.adjustment : adjustment // ignore: cast_nullable_to_non_nullable
as ActivityLabelApi?,
  ));
}
/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<$Res>? get user {
    if (_self.user == null) {
    return null;
  }

  return $ActivityLabelApiCopyWith<$Res>(_self.user!, (value) {
    return _then(_self.copyWith(user: value));
  });
}/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<$Res>? get client {
    if (_self.client == null) {
    return null;
  }

  return $ActivityLabelApiCopyWith<$Res>(_self.client!, (value) {
    return _then(_self.copyWith(client: value));
  });
}/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<$Res>? get invoice {
    if (_self.invoice == null) {
    return null;
  }

  return $ActivityLabelApiCopyWith<$Res>(_self.invoice!, (value) {
    return _then(_self.copyWith(invoice: value));
  });
}/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<$Res>? get contact {
    if (_self.contact == null) {
    return null;
  }

  return $ActivityLabelApiCopyWith<$Res>(_self.contact!, (value) {
    return _then(_self.copyWith(contact: value));
  });
}/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<$Res>? get quote {
    if (_self.quote == null) {
    return null;
  }

  return $ActivityLabelApiCopyWith<$Res>(_self.quote!, (value) {
    return _then(_self.copyWith(quote: value));
  });
}/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<$Res>? get payment {
    if (_self.payment == null) {
    return null;
  }

  return $ActivityLabelApiCopyWith<$Res>(_self.payment!, (value) {
    return _then(_self.copyWith(payment: value));
  });
}/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<$Res>? get paymentAmount {
    if (_self.paymentAmount == null) {
    return null;
  }

  return $ActivityLabelApiCopyWith<$Res>(_self.paymentAmount!, (value) {
    return _then(_self.copyWith(paymentAmount: value));
  });
}/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<$Res>? get expense {
    if (_self.expense == null) {
    return null;
  }

  return $ActivityLabelApiCopyWith<$Res>(_self.expense!, (value) {
    return _then(_self.copyWith(expense: value));
  });
}/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<$Res>? get credit {
    if (_self.credit == null) {
    return null;
  }

  return $ActivityLabelApiCopyWith<$Res>(_self.credit!, (value) {
    return _then(_self.copyWith(credit: value));
  });
}/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<$Res>? get task {
    if (_self.task == null) {
    return null;
  }

  return $ActivityLabelApiCopyWith<$Res>(_self.task!, (value) {
    return _then(_self.copyWith(task: value));
  });
}/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<$Res>? get vendor {
    if (_self.vendor == null) {
    return null;
  }

  return $ActivityLabelApiCopyWith<$Res>(_self.vendor!, (value) {
    return _then(_self.copyWith(vendor: value));
  });
}/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<$Res>? get recurringInvoice {
    if (_self.recurringInvoice == null) {
    return null;
  }

  return $ActivityLabelApiCopyWith<$Res>(_self.recurringInvoice!, (value) {
    return _then(_self.copyWith(recurringInvoice: value));
  });
}/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<$Res>? get recurringExpense {
    if (_self.recurringExpense == null) {
    return null;
  }

  return $ActivityLabelApiCopyWith<$Res>(_self.recurringExpense!, (value) {
    return _then(_self.copyWith(recurringExpense: value));
  });
}/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<$Res>? get purchaseOrder {
    if (_self.purchaseOrder == null) {
    return null;
  }

  return $ActivityLabelApiCopyWith<$Res>(_self.purchaseOrder!, (value) {
    return _then(_self.copyWith(purchaseOrder: value));
  });
}/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<$Res>? get subscription {
    if (_self.subscription == null) {
    return null;
  }

  return $ActivityLabelApiCopyWith<$Res>(_self.subscription!, (value) {
    return _then(_self.copyWith(subscription: value));
  });
}/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<$Res>? get adjustment {
    if (_self.adjustment == null) {
    return null;
  }

  return $ActivityLabelApiCopyWith<$Res>(_self.adjustment!, (value) {
    return _then(_self.copyWith(adjustment: value));
  });
}
}


/// Adds pattern-matching-related methods to [ActivityApi].
extension ActivityApiPatterns on ActivityApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ActivityApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ActivityApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ActivityApi value)  $default,){
final _that = this;
switch (_that) {
case _ActivityApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ActivityApi value)?  $default,){
final _that = this;
switch (_that) {
case _ActivityApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'hashed_id')  String id, @JsonKey(name: 'activity_type_id')  int activityTypeId,  String notes, @JsonKey(name: 'created_at')  int createdAt,  String ip,  ActivityLabelApi? user,  ActivityLabelApi? client,  ActivityLabelApi? invoice,  ActivityLabelApi? contact,  ActivityLabelApi? quote,  ActivityLabelApi? payment, @JsonKey(name: 'payment_amount')  ActivityLabelApi? paymentAmount,  ActivityLabelApi? expense,  ActivityLabelApi? credit,  ActivityLabelApi? task,  ActivityLabelApi? vendor, @JsonKey(name: 'recurring_invoice')  ActivityLabelApi? recurringInvoice, @JsonKey(name: 'recurring_expense')  ActivityLabelApi? recurringExpense, @JsonKey(name: 'purchase_order')  ActivityLabelApi? purchaseOrder,  ActivityLabelApi? subscription,  ActivityLabelApi? adjustment)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ActivityApi() when $default != null:
return $default(_that.id,_that.activityTypeId,_that.notes,_that.createdAt,_that.ip,_that.user,_that.client,_that.invoice,_that.contact,_that.quote,_that.payment,_that.paymentAmount,_that.expense,_that.credit,_that.task,_that.vendor,_that.recurringInvoice,_that.recurringExpense,_that.purchaseOrder,_that.subscription,_that.adjustment);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'hashed_id')  String id, @JsonKey(name: 'activity_type_id')  int activityTypeId,  String notes, @JsonKey(name: 'created_at')  int createdAt,  String ip,  ActivityLabelApi? user,  ActivityLabelApi? client,  ActivityLabelApi? invoice,  ActivityLabelApi? contact,  ActivityLabelApi? quote,  ActivityLabelApi? payment, @JsonKey(name: 'payment_amount')  ActivityLabelApi? paymentAmount,  ActivityLabelApi? expense,  ActivityLabelApi? credit,  ActivityLabelApi? task,  ActivityLabelApi? vendor, @JsonKey(name: 'recurring_invoice')  ActivityLabelApi? recurringInvoice, @JsonKey(name: 'recurring_expense')  ActivityLabelApi? recurringExpense, @JsonKey(name: 'purchase_order')  ActivityLabelApi? purchaseOrder,  ActivityLabelApi? subscription,  ActivityLabelApi? adjustment)  $default,) {final _that = this;
switch (_that) {
case _ActivityApi():
return $default(_that.id,_that.activityTypeId,_that.notes,_that.createdAt,_that.ip,_that.user,_that.client,_that.invoice,_that.contact,_that.quote,_that.payment,_that.paymentAmount,_that.expense,_that.credit,_that.task,_that.vendor,_that.recurringInvoice,_that.recurringExpense,_that.purchaseOrder,_that.subscription,_that.adjustment);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'hashed_id')  String id, @JsonKey(name: 'activity_type_id')  int activityTypeId,  String notes, @JsonKey(name: 'created_at')  int createdAt,  String ip,  ActivityLabelApi? user,  ActivityLabelApi? client,  ActivityLabelApi? invoice,  ActivityLabelApi? contact,  ActivityLabelApi? quote,  ActivityLabelApi? payment, @JsonKey(name: 'payment_amount')  ActivityLabelApi? paymentAmount,  ActivityLabelApi? expense,  ActivityLabelApi? credit,  ActivityLabelApi? task,  ActivityLabelApi? vendor, @JsonKey(name: 'recurring_invoice')  ActivityLabelApi? recurringInvoice, @JsonKey(name: 'recurring_expense')  ActivityLabelApi? recurringExpense, @JsonKey(name: 'purchase_order')  ActivityLabelApi? purchaseOrder,  ActivityLabelApi? subscription,  ActivityLabelApi? adjustment)?  $default,) {final _that = this;
switch (_that) {
case _ActivityApi() when $default != null:
return $default(_that.id,_that.activityTypeId,_that.notes,_that.createdAt,_that.ip,_that.user,_that.client,_that.invoice,_that.contact,_that.quote,_that.payment,_that.paymentAmount,_that.expense,_that.credit,_that.task,_that.vendor,_that.recurringInvoice,_that.recurringExpense,_that.purchaseOrder,_that.subscription,_that.adjustment);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ActivityApi implements ActivityApi {
  const _ActivityApi({@JsonKey(name: 'hashed_id') this.id = '', @JsonKey(name: 'activity_type_id') this.activityTypeId = 0, this.notes = '', @JsonKey(name: 'created_at') this.createdAt = 0, this.ip = '', this.user, this.client, this.invoice, this.contact, this.quote, this.payment, @JsonKey(name: 'payment_amount') this.paymentAmount, this.expense, this.credit, this.task, this.vendor, @JsonKey(name: 'recurring_invoice') this.recurringInvoice, @JsonKey(name: 'recurring_expense') this.recurringExpense, @JsonKey(name: 'purchase_order') this.purchaseOrder, this.subscription, this.adjustment});
  factory _ActivityApi.fromJson(Map<String, dynamic> json) => _$ActivityApiFromJson(json);

@override@JsonKey(name: 'hashed_id') final  String id;
@override@JsonKey(name: 'activity_type_id') final  int activityTypeId;
@override@JsonKey() final  String notes;
@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey() final  String ip;
@override final  ActivityLabelApi? user;
@override final  ActivityLabelApi? client;
@override final  ActivityLabelApi? invoice;
@override final  ActivityLabelApi? contact;
@override final  ActivityLabelApi? quote;
@override final  ActivityLabelApi? payment;
@override@JsonKey(name: 'payment_amount') final  ActivityLabelApi? paymentAmount;
@override final  ActivityLabelApi? expense;
@override final  ActivityLabelApi? credit;
@override final  ActivityLabelApi? task;
@override final  ActivityLabelApi? vendor;
@override@JsonKey(name: 'recurring_invoice') final  ActivityLabelApi? recurringInvoice;
@override@JsonKey(name: 'recurring_expense') final  ActivityLabelApi? recurringExpense;
@override@JsonKey(name: 'purchase_order') final  ActivityLabelApi? purchaseOrder;
@override final  ActivityLabelApi? subscription;
@override final  ActivityLabelApi? adjustment;

/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ActivityApiCopyWith<_ActivityApi> get copyWith => __$ActivityApiCopyWithImpl<_ActivityApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ActivityApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ActivityApi&&(identical(other.id, id) || other.id == id)&&(identical(other.activityTypeId, activityTypeId) || other.activityTypeId == activityTypeId)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.ip, ip) || other.ip == ip)&&(identical(other.user, user) || other.user == user)&&(identical(other.client, client) || other.client == client)&&(identical(other.invoice, invoice) || other.invoice == invoice)&&(identical(other.contact, contact) || other.contact == contact)&&(identical(other.quote, quote) || other.quote == quote)&&(identical(other.payment, payment) || other.payment == payment)&&(identical(other.paymentAmount, paymentAmount) || other.paymentAmount == paymentAmount)&&(identical(other.expense, expense) || other.expense == expense)&&(identical(other.credit, credit) || other.credit == credit)&&(identical(other.task, task) || other.task == task)&&(identical(other.vendor, vendor) || other.vendor == vendor)&&(identical(other.recurringInvoice, recurringInvoice) || other.recurringInvoice == recurringInvoice)&&(identical(other.recurringExpense, recurringExpense) || other.recurringExpense == recurringExpense)&&(identical(other.purchaseOrder, purchaseOrder) || other.purchaseOrder == purchaseOrder)&&(identical(other.subscription, subscription) || other.subscription == subscription)&&(identical(other.adjustment, adjustment) || other.adjustment == adjustment));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,activityTypeId,notes,createdAt,ip,user,client,invoice,contact,quote,payment,paymentAmount,expense,credit,task,vendor,recurringInvoice,recurringExpense,purchaseOrder,subscription,adjustment]);

@override
String toString() {
  return 'ActivityApi(id: $id, activityTypeId: $activityTypeId, notes: $notes, createdAt: $createdAt, ip: $ip, user: $user, client: $client, invoice: $invoice, contact: $contact, quote: $quote, payment: $payment, paymentAmount: $paymentAmount, expense: $expense, credit: $credit, task: $task, vendor: $vendor, recurringInvoice: $recurringInvoice, recurringExpense: $recurringExpense, purchaseOrder: $purchaseOrder, subscription: $subscription, adjustment: $adjustment)';
}


}

/// @nodoc
abstract mixin class _$ActivityApiCopyWith<$Res> implements $ActivityApiCopyWith<$Res> {
  factory _$ActivityApiCopyWith(_ActivityApi value, $Res Function(_ActivityApi) _then) = __$ActivityApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'hashed_id') String id,@JsonKey(name: 'activity_type_id') int activityTypeId, String notes,@JsonKey(name: 'created_at') int createdAt, String ip, ActivityLabelApi? user, ActivityLabelApi? client, ActivityLabelApi? invoice, ActivityLabelApi? contact, ActivityLabelApi? quote, ActivityLabelApi? payment,@JsonKey(name: 'payment_amount') ActivityLabelApi? paymentAmount, ActivityLabelApi? expense, ActivityLabelApi? credit, ActivityLabelApi? task, ActivityLabelApi? vendor,@JsonKey(name: 'recurring_invoice') ActivityLabelApi? recurringInvoice,@JsonKey(name: 'recurring_expense') ActivityLabelApi? recurringExpense,@JsonKey(name: 'purchase_order') ActivityLabelApi? purchaseOrder, ActivityLabelApi? subscription, ActivityLabelApi? adjustment
});


@override $ActivityLabelApiCopyWith<$Res>? get user;@override $ActivityLabelApiCopyWith<$Res>? get client;@override $ActivityLabelApiCopyWith<$Res>? get invoice;@override $ActivityLabelApiCopyWith<$Res>? get contact;@override $ActivityLabelApiCopyWith<$Res>? get quote;@override $ActivityLabelApiCopyWith<$Res>? get payment;@override $ActivityLabelApiCopyWith<$Res>? get paymentAmount;@override $ActivityLabelApiCopyWith<$Res>? get expense;@override $ActivityLabelApiCopyWith<$Res>? get credit;@override $ActivityLabelApiCopyWith<$Res>? get task;@override $ActivityLabelApiCopyWith<$Res>? get vendor;@override $ActivityLabelApiCopyWith<$Res>? get recurringInvoice;@override $ActivityLabelApiCopyWith<$Res>? get recurringExpense;@override $ActivityLabelApiCopyWith<$Res>? get purchaseOrder;@override $ActivityLabelApiCopyWith<$Res>? get subscription;@override $ActivityLabelApiCopyWith<$Res>? get adjustment;

}
/// @nodoc
class __$ActivityApiCopyWithImpl<$Res>
    implements _$ActivityApiCopyWith<$Res> {
  __$ActivityApiCopyWithImpl(this._self, this._then);

  final _ActivityApi _self;
  final $Res Function(_ActivityApi) _then;

/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? activityTypeId = null,Object? notes = null,Object? createdAt = null,Object? ip = null,Object? user = freezed,Object? client = freezed,Object? invoice = freezed,Object? contact = freezed,Object? quote = freezed,Object? payment = freezed,Object? paymentAmount = freezed,Object? expense = freezed,Object? credit = freezed,Object? task = freezed,Object? vendor = freezed,Object? recurringInvoice = freezed,Object? recurringExpense = freezed,Object? purchaseOrder = freezed,Object? subscription = freezed,Object? adjustment = freezed,}) {
  return _then(_ActivityApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,activityTypeId: null == activityTypeId ? _self.activityTypeId : activityTypeId // ignore: cast_nullable_to_non_nullable
as int,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,user: freezed == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as ActivityLabelApi?,client: freezed == client ? _self.client : client // ignore: cast_nullable_to_non_nullable
as ActivityLabelApi?,invoice: freezed == invoice ? _self.invoice : invoice // ignore: cast_nullable_to_non_nullable
as ActivityLabelApi?,contact: freezed == contact ? _self.contact : contact // ignore: cast_nullable_to_non_nullable
as ActivityLabelApi?,quote: freezed == quote ? _self.quote : quote // ignore: cast_nullable_to_non_nullable
as ActivityLabelApi?,payment: freezed == payment ? _self.payment : payment // ignore: cast_nullable_to_non_nullable
as ActivityLabelApi?,paymentAmount: freezed == paymentAmount ? _self.paymentAmount : paymentAmount // ignore: cast_nullable_to_non_nullable
as ActivityLabelApi?,expense: freezed == expense ? _self.expense : expense // ignore: cast_nullable_to_non_nullable
as ActivityLabelApi?,credit: freezed == credit ? _self.credit : credit // ignore: cast_nullable_to_non_nullable
as ActivityLabelApi?,task: freezed == task ? _self.task : task // ignore: cast_nullable_to_non_nullable
as ActivityLabelApi?,vendor: freezed == vendor ? _self.vendor : vendor // ignore: cast_nullable_to_non_nullable
as ActivityLabelApi?,recurringInvoice: freezed == recurringInvoice ? _self.recurringInvoice : recurringInvoice // ignore: cast_nullable_to_non_nullable
as ActivityLabelApi?,recurringExpense: freezed == recurringExpense ? _self.recurringExpense : recurringExpense // ignore: cast_nullable_to_non_nullable
as ActivityLabelApi?,purchaseOrder: freezed == purchaseOrder ? _self.purchaseOrder : purchaseOrder // ignore: cast_nullable_to_non_nullable
as ActivityLabelApi?,subscription: freezed == subscription ? _self.subscription : subscription // ignore: cast_nullable_to_non_nullable
as ActivityLabelApi?,adjustment: freezed == adjustment ? _self.adjustment : adjustment // ignore: cast_nullable_to_non_nullable
as ActivityLabelApi?,
  ));
}

/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<$Res>? get user {
    if (_self.user == null) {
    return null;
  }

  return $ActivityLabelApiCopyWith<$Res>(_self.user!, (value) {
    return _then(_self.copyWith(user: value));
  });
}/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<$Res>? get client {
    if (_self.client == null) {
    return null;
  }

  return $ActivityLabelApiCopyWith<$Res>(_self.client!, (value) {
    return _then(_self.copyWith(client: value));
  });
}/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<$Res>? get invoice {
    if (_self.invoice == null) {
    return null;
  }

  return $ActivityLabelApiCopyWith<$Res>(_self.invoice!, (value) {
    return _then(_self.copyWith(invoice: value));
  });
}/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<$Res>? get contact {
    if (_self.contact == null) {
    return null;
  }

  return $ActivityLabelApiCopyWith<$Res>(_self.contact!, (value) {
    return _then(_self.copyWith(contact: value));
  });
}/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<$Res>? get quote {
    if (_self.quote == null) {
    return null;
  }

  return $ActivityLabelApiCopyWith<$Res>(_self.quote!, (value) {
    return _then(_self.copyWith(quote: value));
  });
}/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<$Res>? get payment {
    if (_self.payment == null) {
    return null;
  }

  return $ActivityLabelApiCopyWith<$Res>(_self.payment!, (value) {
    return _then(_self.copyWith(payment: value));
  });
}/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<$Res>? get paymentAmount {
    if (_self.paymentAmount == null) {
    return null;
  }

  return $ActivityLabelApiCopyWith<$Res>(_self.paymentAmount!, (value) {
    return _then(_self.copyWith(paymentAmount: value));
  });
}/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<$Res>? get expense {
    if (_self.expense == null) {
    return null;
  }

  return $ActivityLabelApiCopyWith<$Res>(_self.expense!, (value) {
    return _then(_self.copyWith(expense: value));
  });
}/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<$Res>? get credit {
    if (_self.credit == null) {
    return null;
  }

  return $ActivityLabelApiCopyWith<$Res>(_self.credit!, (value) {
    return _then(_self.copyWith(credit: value));
  });
}/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<$Res>? get task {
    if (_self.task == null) {
    return null;
  }

  return $ActivityLabelApiCopyWith<$Res>(_self.task!, (value) {
    return _then(_self.copyWith(task: value));
  });
}/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<$Res>? get vendor {
    if (_self.vendor == null) {
    return null;
  }

  return $ActivityLabelApiCopyWith<$Res>(_self.vendor!, (value) {
    return _then(_self.copyWith(vendor: value));
  });
}/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<$Res>? get recurringInvoice {
    if (_self.recurringInvoice == null) {
    return null;
  }

  return $ActivityLabelApiCopyWith<$Res>(_self.recurringInvoice!, (value) {
    return _then(_self.copyWith(recurringInvoice: value));
  });
}/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<$Res>? get recurringExpense {
    if (_self.recurringExpense == null) {
    return null;
  }

  return $ActivityLabelApiCopyWith<$Res>(_self.recurringExpense!, (value) {
    return _then(_self.copyWith(recurringExpense: value));
  });
}/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<$Res>? get purchaseOrder {
    if (_self.purchaseOrder == null) {
    return null;
  }

  return $ActivityLabelApiCopyWith<$Res>(_self.purchaseOrder!, (value) {
    return _then(_self.copyWith(purchaseOrder: value));
  });
}/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<$Res>? get subscription {
    if (_self.subscription == null) {
    return null;
  }

  return $ActivityLabelApiCopyWith<$Res>(_self.subscription!, (value) {
    return _then(_self.copyWith(subscription: value));
  });
}/// Create a copy of ActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivityLabelApiCopyWith<$Res>? get adjustment {
    if (_self.adjustment == null) {
    return null;
  }

  return $ActivityLabelApiCopyWith<$Res>(_self.adjustment!, (value) {
    return _then(_self.copyWith(adjustment: value));
  });
}
}


/// @nodoc
mixin _$ActivityListApi {

@JsonKey(fromJson: _activityListData) List<ActivityApi> get data;
/// Create a copy of ActivityListApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ActivityListApiCopyWith<ActivityListApi> get copyWith => _$ActivityListApiCopyWithImpl<ActivityListApi>(this as ActivityListApi, _$identity);

  /// Serializes this ActivityListApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ActivityListApi&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'ActivityListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $ActivityListApiCopyWith<$Res>  {
  factory $ActivityListApiCopyWith(ActivityListApi value, $Res Function(ActivityListApi) _then) = _$ActivityListApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _activityListData) List<ActivityApi> data
});




}
/// @nodoc
class _$ActivityListApiCopyWithImpl<$Res>
    implements $ActivityListApiCopyWith<$Res> {
  _$ActivityListApiCopyWithImpl(this._self, this._then);

  final ActivityListApi _self;
  final $Res Function(ActivityListApi) _then;

/// Create a copy of ActivityListApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<ActivityApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [ActivityListApi].
extension ActivityListApiPatterns on ActivityListApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ActivityListApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ActivityListApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ActivityListApi value)  $default,){
final _that = this;
switch (_that) {
case _ActivityListApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ActivityListApi value)?  $default,){
final _that = this;
switch (_that) {
case _ActivityListApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _activityListData)  List<ActivityApi> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ActivityListApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _activityListData)  List<ActivityApi> data)  $default,) {final _that = this;
switch (_that) {
case _ActivityListApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _activityListData)  List<ActivityApi> data)?  $default,) {final _that = this;
switch (_that) {
case _ActivityListApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ActivityListApi implements ActivityListApi {
  const _ActivityListApi({@JsonKey(fromJson: _activityListData) final  List<ActivityApi> data = const []}): _data = data;
  factory _ActivityListApi.fromJson(Map<String, dynamic> json) => _$ActivityListApiFromJson(json);

 final  List<ActivityApi> _data;
@override@JsonKey(fromJson: _activityListData) List<ActivityApi> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of ActivityListApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ActivityListApiCopyWith<_ActivityListApi> get copyWith => __$ActivityListApiCopyWithImpl<_ActivityListApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ActivityListApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ActivityListApi&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'ActivityListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$ActivityListApiCopyWith<$Res> implements $ActivityListApiCopyWith<$Res> {
  factory _$ActivityListApiCopyWith(_ActivityListApi value, $Res Function(_ActivityListApi) _then) = __$ActivityListApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _activityListData) List<ActivityApi> data
});




}
/// @nodoc
class __$ActivityListApiCopyWithImpl<$Res>
    implements _$ActivityListApiCopyWith<$Res> {
  __$ActivityListApiCopyWithImpl(this._self, this._then);

  final _ActivityListApi _self;
  final $Res Function(_ActivityListApi) _then;

/// Create a copy of ActivityListApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_ActivityListApi(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<ActivityApi>,
  ));
}


}

// dart format on
