// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Project {

 String get id; String get userId; String get assignedUserId; String get clientId; String get number; String get name; Decimal get taskRate; Date? get dueDate; String get privateNotes; String get publicNotes; double get budgetedHours;/// Optional money budget, independent of `budgetedHours`. The server's
/// project charts fall back to `budgetedHours × taskRate` when this is
/// zero (`ProjectBurnUpService::budgetedAmount`).
 Decimal get budgetedAmount; double get currentHours; String get customValue1; String get customValue2; String get customValue3; String get customValue4; String get color; DateTime get updatedAt; DateTime get createdAt; DateTime? get archivedAt; bool get isDeleted; List<Document> get documents;// Attached tag ids (hashed); names/colors resolved from the tag cache.
 List<String> get tagIds; bool get isDirty;
/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectCopyWith<Project> get copyWith => _$ProjectCopyWithImpl<Project>(this as Project, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Project&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.number, number) || other.number == number)&&(identical(other.name, name) || other.name == name)&&(identical(other.taskRate, taskRate) || other.taskRate == taskRate)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.privateNotes, privateNotes) || other.privateNotes == privateNotes)&&(identical(other.publicNotes, publicNotes) || other.publicNotes == publicNotes)&&(identical(other.budgetedHours, budgetedHours) || other.budgetedHours == budgetedHours)&&(identical(other.budgetedAmount, budgetedAmount) || other.budgetedAmount == budgetedAmount)&&(identical(other.currentHours, currentHours) || other.currentHours == currentHours)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.color, color) || other.color == color)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&const DeepCollectionEquality().equals(other.documents, documents)&&const DeepCollectionEquality().equals(other.tagIds, tagIds)&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,userId,assignedUserId,clientId,number,name,taskRate,dueDate,privateNotes,publicNotes,budgetedHours,budgetedAmount,currentHours,customValue1,customValue2,customValue3,customValue4,color,updatedAt,createdAt,archivedAt,isDeleted,const DeepCollectionEquality().hash(documents),const DeepCollectionEquality().hash(tagIds),isDirty]);

@override
String toString() {
  return 'Project(id: $id, userId: $userId, assignedUserId: $assignedUserId, clientId: $clientId, number: $number, name: $name, taskRate: $taskRate, dueDate: $dueDate, privateNotes: $privateNotes, publicNotes: $publicNotes, budgetedHours: $budgetedHours, budgetedAmount: $budgetedAmount, currentHours: $currentHours, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, color: $color, updatedAt: $updatedAt, createdAt: $createdAt, archivedAt: $archivedAt, isDeleted: $isDeleted, documents: $documents, tagIds: $tagIds, isDirty: $isDirty)';
}


}

/// @nodoc
abstract mixin class $ProjectCopyWith<$Res>  {
  factory $ProjectCopyWith(Project value, $Res Function(Project) _then) = _$ProjectCopyWithImpl;
@useResult
$Res call({
 String id, String userId, String assignedUserId, String clientId, String number, String name, Decimal taskRate, Date? dueDate, String privateNotes, String publicNotes, double budgetedHours, Decimal budgetedAmount, double currentHours, String customValue1, String customValue2, String customValue3, String customValue4, String color, DateTime updatedAt, DateTime createdAt, DateTime? archivedAt, bool isDeleted, List<Document> documents, List<String> tagIds, bool isDirty
});




}
/// @nodoc
class _$ProjectCopyWithImpl<$Res>
    implements $ProjectCopyWith<$Res> {
  _$ProjectCopyWithImpl(this._self, this._then);

  final Project _self;
  final $Res Function(Project) _then;

/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? assignedUserId = null,Object? clientId = null,Object? number = null,Object? name = null,Object? taskRate = null,Object? dueDate = freezed,Object? privateNotes = null,Object? publicNotes = null,Object? budgetedHours = null,Object? budgetedAmount = null,Object? currentHours = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? color = null,Object? updatedAt = null,Object? createdAt = null,Object? archivedAt = freezed,Object? isDeleted = null,Object? documents = null,Object? tagIds = null,Object? isDirty = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,taskRate: null == taskRate ? _self.taskRate : taskRate // ignore: cast_nullable_to_non_nullable
as Decimal,dueDate: freezed == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as Date?,privateNotes: null == privateNotes ? _self.privateNotes : privateNotes // ignore: cast_nullable_to_non_nullable
as String,publicNotes: null == publicNotes ? _self.publicNotes : publicNotes // ignore: cast_nullable_to_non_nullable
as String,budgetedHours: null == budgetedHours ? _self.budgetedHours : budgetedHours // ignore: cast_nullable_to_non_nullable
as double,budgetedAmount: null == budgetedAmount ? _self.budgetedAmount : budgetedAmount // ignore: cast_nullable_to_non_nullable
as Decimal,currentHours: null == currentHours ? _self.currentHours : currentHours // ignore: cast_nullable_to_non_nullable
as double,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,documents: null == documents ? _self.documents : documents // ignore: cast_nullable_to_non_nullable
as List<Document>,tagIds: null == tagIds ? _self.tagIds : tagIds // ignore: cast_nullable_to_non_nullable
as List<String>,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Project].
extension ProjectPatterns on Project {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Project value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Project() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Project value)  $default,){
final _that = this;
switch (_that) {
case _Project():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Project value)?  $default,){
final _that = this;
switch (_that) {
case _Project() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String userId,  String assignedUserId,  String clientId,  String number,  String name,  Decimal taskRate,  Date? dueDate,  String privateNotes,  String publicNotes,  double budgetedHours,  Decimal budgetedAmount,  double currentHours,  String customValue1,  String customValue2,  String customValue3,  String customValue4,  String color,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  bool isDeleted,  List<Document> documents,  List<String> tagIds,  bool isDirty)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Project() when $default != null:
return $default(_that.id,_that.userId,_that.assignedUserId,_that.clientId,_that.number,_that.name,_that.taskRate,_that.dueDate,_that.privateNotes,_that.publicNotes,_that.budgetedHours,_that.budgetedAmount,_that.currentHours,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.color,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.isDeleted,_that.documents,_that.tagIds,_that.isDirty);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String userId,  String assignedUserId,  String clientId,  String number,  String name,  Decimal taskRate,  Date? dueDate,  String privateNotes,  String publicNotes,  double budgetedHours,  Decimal budgetedAmount,  double currentHours,  String customValue1,  String customValue2,  String customValue3,  String customValue4,  String color,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  bool isDeleted,  List<Document> documents,  List<String> tagIds,  bool isDirty)  $default,) {final _that = this;
switch (_that) {
case _Project():
return $default(_that.id,_that.userId,_that.assignedUserId,_that.clientId,_that.number,_that.name,_that.taskRate,_that.dueDate,_that.privateNotes,_that.publicNotes,_that.budgetedHours,_that.budgetedAmount,_that.currentHours,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.color,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.isDeleted,_that.documents,_that.tagIds,_that.isDirty);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String userId,  String assignedUserId,  String clientId,  String number,  String name,  Decimal taskRate,  Date? dueDate,  String privateNotes,  String publicNotes,  double budgetedHours,  Decimal budgetedAmount,  double currentHours,  String customValue1,  String customValue2,  String customValue3,  String customValue4,  String color,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  bool isDeleted,  List<Document> documents,  List<String> tagIds,  bool isDirty)?  $default,) {final _that = this;
switch (_that) {
case _Project() when $default != null:
return $default(_that.id,_that.userId,_that.assignedUserId,_that.clientId,_that.number,_that.name,_that.taskRate,_that.dueDate,_that.privateNotes,_that.publicNotes,_that.budgetedHours,_that.budgetedAmount,_that.currentHours,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.color,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.isDeleted,_that.documents,_that.tagIds,_that.isDirty);case _:
  return null;

}
}

}

/// @nodoc


class _Project implements Project {
  const _Project({required this.id, required this.userId, required this.assignedUserId, required this.clientId, required this.number, required this.name, required this.taskRate, required this.dueDate, required this.privateNotes, required this.publicNotes, required this.budgetedHours, required this.budgetedAmount, required this.currentHours, required this.customValue1, required this.customValue2, required this.customValue3, required this.customValue4, required this.color, required this.updatedAt, required this.createdAt, required this.archivedAt, required this.isDeleted, final  List<Document> documents = const <Document>[], final  List<String> tagIds = const <String>[], this.isDirty = false}): _documents = documents,_tagIds = tagIds;
  

@override final  String id;
@override final  String userId;
@override final  String assignedUserId;
@override final  String clientId;
@override final  String number;
@override final  String name;
@override final  Decimal taskRate;
@override final  Date? dueDate;
@override final  String privateNotes;
@override final  String publicNotes;
@override final  double budgetedHours;
/// Optional money budget, independent of `budgetedHours`. The server's
/// project charts fall back to `budgetedHours × taskRate` when this is
/// zero (`ProjectBurnUpService::budgetedAmount`).
@override final  Decimal budgetedAmount;
@override final  double currentHours;
@override final  String customValue1;
@override final  String customValue2;
@override final  String customValue3;
@override final  String customValue4;
@override final  String color;
@override final  DateTime updatedAt;
@override final  DateTime createdAt;
@override final  DateTime? archivedAt;
@override final  bool isDeleted;
 final  List<Document> _documents;
@override@JsonKey() List<Document> get documents {
  if (_documents is EqualUnmodifiableListView) return _documents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_documents);
}

// Attached tag ids (hashed); names/colors resolved from the tag cache.
 final  List<String> _tagIds;
// Attached tag ids (hashed); names/colors resolved from the tag cache.
@override@JsonKey() List<String> get tagIds {
  if (_tagIds is EqualUnmodifiableListView) return _tagIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tagIds);
}

@override@JsonKey() final  bool isDirty;

/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectCopyWith<_Project> get copyWith => __$ProjectCopyWithImpl<_Project>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Project&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.number, number) || other.number == number)&&(identical(other.name, name) || other.name == name)&&(identical(other.taskRate, taskRate) || other.taskRate == taskRate)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.privateNotes, privateNotes) || other.privateNotes == privateNotes)&&(identical(other.publicNotes, publicNotes) || other.publicNotes == publicNotes)&&(identical(other.budgetedHours, budgetedHours) || other.budgetedHours == budgetedHours)&&(identical(other.budgetedAmount, budgetedAmount) || other.budgetedAmount == budgetedAmount)&&(identical(other.currentHours, currentHours) || other.currentHours == currentHours)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.color, color) || other.color == color)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&const DeepCollectionEquality().equals(other._documents, _documents)&&const DeepCollectionEquality().equals(other._tagIds, _tagIds)&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,userId,assignedUserId,clientId,number,name,taskRate,dueDate,privateNotes,publicNotes,budgetedHours,budgetedAmount,currentHours,customValue1,customValue2,customValue3,customValue4,color,updatedAt,createdAt,archivedAt,isDeleted,const DeepCollectionEquality().hash(_documents),const DeepCollectionEquality().hash(_tagIds),isDirty]);

@override
String toString() {
  return 'Project(id: $id, userId: $userId, assignedUserId: $assignedUserId, clientId: $clientId, number: $number, name: $name, taskRate: $taskRate, dueDate: $dueDate, privateNotes: $privateNotes, publicNotes: $publicNotes, budgetedHours: $budgetedHours, budgetedAmount: $budgetedAmount, currentHours: $currentHours, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, color: $color, updatedAt: $updatedAt, createdAt: $createdAt, archivedAt: $archivedAt, isDeleted: $isDeleted, documents: $documents, tagIds: $tagIds, isDirty: $isDirty)';
}


}

/// @nodoc
abstract mixin class _$ProjectCopyWith<$Res> implements $ProjectCopyWith<$Res> {
  factory _$ProjectCopyWith(_Project value, $Res Function(_Project) _then) = __$ProjectCopyWithImpl;
@override @useResult
$Res call({
 String id, String userId, String assignedUserId, String clientId, String number, String name, Decimal taskRate, Date? dueDate, String privateNotes, String publicNotes, double budgetedHours, Decimal budgetedAmount, double currentHours, String customValue1, String customValue2, String customValue3, String customValue4, String color, DateTime updatedAt, DateTime createdAt, DateTime? archivedAt, bool isDeleted, List<Document> documents, List<String> tagIds, bool isDirty
});




}
/// @nodoc
class __$ProjectCopyWithImpl<$Res>
    implements _$ProjectCopyWith<$Res> {
  __$ProjectCopyWithImpl(this._self, this._then);

  final _Project _self;
  final $Res Function(_Project) _then;

/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? assignedUserId = null,Object? clientId = null,Object? number = null,Object? name = null,Object? taskRate = null,Object? dueDate = freezed,Object? privateNotes = null,Object? publicNotes = null,Object? budgetedHours = null,Object? budgetedAmount = null,Object? currentHours = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? color = null,Object? updatedAt = null,Object? createdAt = null,Object? archivedAt = freezed,Object? isDeleted = null,Object? documents = null,Object? tagIds = null,Object? isDirty = null,}) {
  return _then(_Project(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,taskRate: null == taskRate ? _self.taskRate : taskRate // ignore: cast_nullable_to_non_nullable
as Decimal,dueDate: freezed == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as Date?,privateNotes: null == privateNotes ? _self.privateNotes : privateNotes // ignore: cast_nullable_to_non_nullable
as String,publicNotes: null == publicNotes ? _self.publicNotes : publicNotes // ignore: cast_nullable_to_non_nullable
as String,budgetedHours: null == budgetedHours ? _self.budgetedHours : budgetedHours // ignore: cast_nullable_to_non_nullable
as double,budgetedAmount: null == budgetedAmount ? _self.budgetedAmount : budgetedAmount // ignore: cast_nullable_to_non_nullable
as Decimal,currentHours: null == currentHours ? _self.currentHours : currentHours // ignore: cast_nullable_to_non_nullable
as double,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,documents: null == documents ? _self._documents : documents // ignore: cast_nullable_to_non_nullable
as List<Document>,tagIds: null == tagIds ? _self._tagIds : tagIds // ignore: cast_nullable_to_non_nullable
as List<String>,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
