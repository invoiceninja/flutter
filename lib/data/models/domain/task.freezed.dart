// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Task {

 String get id; String get number; String get description; Decimal get rate; String get invoiceId; String get clientId; String get projectId; String get statusId; int get statusOrder; String get assignedUserId;/// Creator. Read-only (server-assigned) and payload-backed — the `tasks`
/// table has no `user_id` column — so the list column that renders it is
/// display-only.
 String get userId; List<TimeEntry> get timeLog; String get customValue1; String get customValue2; String get customValue3; String get customValue4; DateTime get updatedAt; DateTime get createdAt; DateTime? get archivedAt; bool get isDeleted; List<Document> get documents;// Attached tag ids (hashed). Names/colors are resolved from the tag
// cache for rendering; `toApiJson` sends the full set (server `sync()`s).
 List<String> get tagIds;// Set only when this task was converted from a calendar event — carries the
// event link the server uses to dedupe (one task per user per event).
 TaskMeta? get meta; bool get isDirty;
/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskCopyWith<Task> get copyWith => _$TaskCopyWithImpl<Task>(this as Task, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Task&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.description, description) || other.description == description)&&(identical(other.rate, rate) || other.rate == rate)&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.statusId, statusId) || other.statusId == statusId)&&(identical(other.statusOrder, statusOrder) || other.statusOrder == statusOrder)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.userId, userId) || other.userId == userId)&&const DeepCollectionEquality().equals(other.timeLog, timeLog)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&const DeepCollectionEquality().equals(other.documents, documents)&&const DeepCollectionEquality().equals(other.tagIds, tagIds)&&(identical(other.meta, meta) || other.meta == meta)&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,number,description,rate,invoiceId,clientId,projectId,statusId,statusOrder,assignedUserId,userId,const DeepCollectionEquality().hash(timeLog),customValue1,customValue2,customValue3,customValue4,updatedAt,createdAt,archivedAt,isDeleted,const DeepCollectionEquality().hash(documents),const DeepCollectionEquality().hash(tagIds),meta,isDirty]);

@override
String toString() {
  return 'Task(id: $id, number: $number, description: $description, rate: $rate, invoiceId: $invoiceId, clientId: $clientId, projectId: $projectId, statusId: $statusId, statusOrder: $statusOrder, assignedUserId: $assignedUserId, userId: $userId, timeLog: $timeLog, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, updatedAt: $updatedAt, createdAt: $createdAt, archivedAt: $archivedAt, isDeleted: $isDeleted, documents: $documents, tagIds: $tagIds, meta: $meta, isDirty: $isDirty)';
}


}

/// @nodoc
abstract mixin class $TaskCopyWith<$Res>  {
  factory $TaskCopyWith(Task value, $Res Function(Task) _then) = _$TaskCopyWithImpl;
@useResult
$Res call({
 String id, String number, String description, Decimal rate, String invoiceId, String clientId, String projectId, String statusId, int statusOrder, String assignedUserId, String userId, List<TimeEntry> timeLog, String customValue1, String customValue2, String customValue3, String customValue4, DateTime updatedAt, DateTime createdAt, DateTime? archivedAt, bool isDeleted, List<Document> documents, List<String> tagIds, TaskMeta? meta, bool isDirty
});


$TaskMetaCopyWith<$Res>? get meta;

}
/// @nodoc
class _$TaskCopyWithImpl<$Res>
    implements $TaskCopyWith<$Res> {
  _$TaskCopyWithImpl(this._self, this._then);

  final Task _self;
  final $Res Function(Task) _then;

/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? number = null,Object? description = null,Object? rate = null,Object? invoiceId = null,Object? clientId = null,Object? projectId = null,Object? statusId = null,Object? statusOrder = null,Object? assignedUserId = null,Object? userId = null,Object? timeLog = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? updatedAt = null,Object? createdAt = null,Object? archivedAt = freezed,Object? isDeleted = null,Object? documents = null,Object? tagIds = null,Object? meta = freezed,Object? isDirty = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,rate: null == rate ? _self.rate : rate // ignore: cast_nullable_to_non_nullable
as Decimal,invoiceId: null == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as String,clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,statusId: null == statusId ? _self.statusId : statusId // ignore: cast_nullable_to_non_nullable
as String,statusOrder: null == statusOrder ? _self.statusOrder : statusOrder // ignore: cast_nullable_to_non_nullable
as int,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,timeLog: null == timeLog ? _self.timeLog : timeLog // ignore: cast_nullable_to_non_nullable
as List<TimeEntry>,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,documents: null == documents ? _self.documents : documents // ignore: cast_nullable_to_non_nullable
as List<Document>,tagIds: null == tagIds ? _self.tagIds : tagIds // ignore: cast_nullable_to_non_nullable
as List<String>,meta: freezed == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as TaskMeta?,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TaskMetaCopyWith<$Res>? get meta {
    if (_self.meta == null) {
    return null;
  }

  return $TaskMetaCopyWith<$Res>(_self.meta!, (value) {
    return _then(_self.copyWith(meta: value));
  });
}
}


/// Adds pattern-matching-related methods to [Task].
extension TaskPatterns on Task {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Task value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Task() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Task value)  $default,){
final _that = this;
switch (_that) {
case _Task():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Task value)?  $default,){
final _that = this;
switch (_that) {
case _Task() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String number,  String description,  Decimal rate,  String invoiceId,  String clientId,  String projectId,  String statusId,  int statusOrder,  String assignedUserId,  String userId,  List<TimeEntry> timeLog,  String customValue1,  String customValue2,  String customValue3,  String customValue4,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  bool isDeleted,  List<Document> documents,  List<String> tagIds,  TaskMeta? meta,  bool isDirty)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Task() when $default != null:
return $default(_that.id,_that.number,_that.description,_that.rate,_that.invoiceId,_that.clientId,_that.projectId,_that.statusId,_that.statusOrder,_that.assignedUserId,_that.userId,_that.timeLog,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.isDeleted,_that.documents,_that.tagIds,_that.meta,_that.isDirty);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String number,  String description,  Decimal rate,  String invoiceId,  String clientId,  String projectId,  String statusId,  int statusOrder,  String assignedUserId,  String userId,  List<TimeEntry> timeLog,  String customValue1,  String customValue2,  String customValue3,  String customValue4,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  bool isDeleted,  List<Document> documents,  List<String> tagIds,  TaskMeta? meta,  bool isDirty)  $default,) {final _that = this;
switch (_that) {
case _Task():
return $default(_that.id,_that.number,_that.description,_that.rate,_that.invoiceId,_that.clientId,_that.projectId,_that.statusId,_that.statusOrder,_that.assignedUserId,_that.userId,_that.timeLog,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.isDeleted,_that.documents,_that.tagIds,_that.meta,_that.isDirty);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String number,  String description,  Decimal rate,  String invoiceId,  String clientId,  String projectId,  String statusId,  int statusOrder,  String assignedUserId,  String userId,  List<TimeEntry> timeLog,  String customValue1,  String customValue2,  String customValue3,  String customValue4,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  bool isDeleted,  List<Document> documents,  List<String> tagIds,  TaskMeta? meta,  bool isDirty)?  $default,) {final _that = this;
switch (_that) {
case _Task() when $default != null:
return $default(_that.id,_that.number,_that.description,_that.rate,_that.invoiceId,_that.clientId,_that.projectId,_that.statusId,_that.statusOrder,_that.assignedUserId,_that.userId,_that.timeLog,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.isDeleted,_that.documents,_that.tagIds,_that.meta,_that.isDirty);case _:
  return null;

}
}

}

/// @nodoc


class _Task implements Task {
  const _Task({required this.id, required this.number, required this.description, required this.rate, required this.invoiceId, required this.clientId, required this.projectId, required this.statusId, required this.statusOrder, required this.assignedUserId, this.userId = '', required final  List<TimeEntry> timeLog, required this.customValue1, required this.customValue2, required this.customValue3, required this.customValue4, required this.updatedAt, required this.createdAt, required this.archivedAt, required this.isDeleted, final  List<Document> documents = const <Document>[], final  List<String> tagIds = const <String>[], this.meta, this.isDirty = false}): _timeLog = timeLog,_documents = documents,_tagIds = tagIds;
  

@override final  String id;
@override final  String number;
@override final  String description;
@override final  Decimal rate;
@override final  String invoiceId;
@override final  String clientId;
@override final  String projectId;
@override final  String statusId;
@override final  int statusOrder;
@override final  String assignedUserId;
/// Creator. Read-only (server-assigned) and payload-backed — the `tasks`
/// table has no `user_id` column — so the list column that renders it is
/// display-only.
@override@JsonKey() final  String userId;
 final  List<TimeEntry> _timeLog;
@override List<TimeEntry> get timeLog {
  if (_timeLog is EqualUnmodifiableListView) return _timeLog;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_timeLog);
}

@override final  String customValue1;
@override final  String customValue2;
@override final  String customValue3;
@override final  String customValue4;
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

// Attached tag ids (hashed). Names/colors are resolved from the tag
// cache for rendering; `toApiJson` sends the full set (server `sync()`s).
 final  List<String> _tagIds;
// Attached tag ids (hashed). Names/colors are resolved from the tag
// cache for rendering; `toApiJson` sends the full set (server `sync()`s).
@override@JsonKey() List<String> get tagIds {
  if (_tagIds is EqualUnmodifiableListView) return _tagIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tagIds);
}

// Set only when this task was converted from a calendar event — carries the
// event link the server uses to dedupe (one task per user per event).
@override final  TaskMeta? meta;
@override@JsonKey() final  bool isDirty;

/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskCopyWith<_Task> get copyWith => __$TaskCopyWithImpl<_Task>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Task&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.description, description) || other.description == description)&&(identical(other.rate, rate) || other.rate == rate)&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.statusId, statusId) || other.statusId == statusId)&&(identical(other.statusOrder, statusOrder) || other.statusOrder == statusOrder)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.userId, userId) || other.userId == userId)&&const DeepCollectionEquality().equals(other._timeLog, _timeLog)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&const DeepCollectionEquality().equals(other._documents, _documents)&&const DeepCollectionEquality().equals(other._tagIds, _tagIds)&&(identical(other.meta, meta) || other.meta == meta)&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,number,description,rate,invoiceId,clientId,projectId,statusId,statusOrder,assignedUserId,userId,const DeepCollectionEquality().hash(_timeLog),customValue1,customValue2,customValue3,customValue4,updatedAt,createdAt,archivedAt,isDeleted,const DeepCollectionEquality().hash(_documents),const DeepCollectionEquality().hash(_tagIds),meta,isDirty]);

@override
String toString() {
  return 'Task(id: $id, number: $number, description: $description, rate: $rate, invoiceId: $invoiceId, clientId: $clientId, projectId: $projectId, statusId: $statusId, statusOrder: $statusOrder, assignedUserId: $assignedUserId, userId: $userId, timeLog: $timeLog, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, updatedAt: $updatedAt, createdAt: $createdAt, archivedAt: $archivedAt, isDeleted: $isDeleted, documents: $documents, tagIds: $tagIds, meta: $meta, isDirty: $isDirty)';
}


}

/// @nodoc
abstract mixin class _$TaskCopyWith<$Res> implements $TaskCopyWith<$Res> {
  factory _$TaskCopyWith(_Task value, $Res Function(_Task) _then) = __$TaskCopyWithImpl;
@override @useResult
$Res call({
 String id, String number, String description, Decimal rate, String invoiceId, String clientId, String projectId, String statusId, int statusOrder, String assignedUserId, String userId, List<TimeEntry> timeLog, String customValue1, String customValue2, String customValue3, String customValue4, DateTime updatedAt, DateTime createdAt, DateTime? archivedAt, bool isDeleted, List<Document> documents, List<String> tagIds, TaskMeta? meta, bool isDirty
});


@override $TaskMetaCopyWith<$Res>? get meta;

}
/// @nodoc
class __$TaskCopyWithImpl<$Res>
    implements _$TaskCopyWith<$Res> {
  __$TaskCopyWithImpl(this._self, this._then);

  final _Task _self;
  final $Res Function(_Task) _then;

/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? number = null,Object? description = null,Object? rate = null,Object? invoiceId = null,Object? clientId = null,Object? projectId = null,Object? statusId = null,Object? statusOrder = null,Object? assignedUserId = null,Object? userId = null,Object? timeLog = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? updatedAt = null,Object? createdAt = null,Object? archivedAt = freezed,Object? isDeleted = null,Object? documents = null,Object? tagIds = null,Object? meta = freezed,Object? isDirty = null,}) {
  return _then(_Task(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,rate: null == rate ? _self.rate : rate // ignore: cast_nullable_to_non_nullable
as Decimal,invoiceId: null == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as String,clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,statusId: null == statusId ? _self.statusId : statusId // ignore: cast_nullable_to_non_nullable
as String,statusOrder: null == statusOrder ? _self.statusOrder : statusOrder // ignore: cast_nullable_to_non_nullable
as int,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,timeLog: null == timeLog ? _self._timeLog : timeLog // ignore: cast_nullable_to_non_nullable
as List<TimeEntry>,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,documents: null == documents ? _self._documents : documents // ignore: cast_nullable_to_non_nullable
as List<Document>,tagIds: null == tagIds ? _self._tagIds : tagIds // ignore: cast_nullable_to_non_nullable
as List<String>,meta: freezed == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as TaskMeta?,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TaskMetaCopyWith<$Res>? get meta {
    if (_self.meta == null) {
    return null;
  }

  return $TaskMetaCopyWith<$Res>(_self.meta!, (value) {
    return _then(_self.copyWith(meta: value));
  });
}
}

/// @nodoc
mixin _$TaskMeta {

 String get calendarEventId;
/// Create a copy of TaskMeta
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskMetaCopyWith<TaskMeta> get copyWith => _$TaskMetaCopyWithImpl<TaskMeta>(this as TaskMeta, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskMeta&&(identical(other.calendarEventId, calendarEventId) || other.calendarEventId == calendarEventId));
}


@override
int get hashCode => Object.hash(runtimeType,calendarEventId);

@override
String toString() {
  return 'TaskMeta(calendarEventId: $calendarEventId)';
}


}

/// @nodoc
abstract mixin class $TaskMetaCopyWith<$Res>  {
  factory $TaskMetaCopyWith(TaskMeta value, $Res Function(TaskMeta) _then) = _$TaskMetaCopyWithImpl;
@useResult
$Res call({
 String calendarEventId
});




}
/// @nodoc
class _$TaskMetaCopyWithImpl<$Res>
    implements $TaskMetaCopyWith<$Res> {
  _$TaskMetaCopyWithImpl(this._self, this._then);

  final TaskMeta _self;
  final $Res Function(TaskMeta) _then;

/// Create a copy of TaskMeta
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? calendarEventId = null,}) {
  return _then(_self.copyWith(
calendarEventId: null == calendarEventId ? _self.calendarEventId : calendarEventId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TaskMeta].
extension TaskMetaPatterns on TaskMeta {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TaskMeta value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TaskMeta() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TaskMeta value)  $default,){
final _that = this;
switch (_that) {
case _TaskMeta():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TaskMeta value)?  $default,){
final _that = this;
switch (_that) {
case _TaskMeta() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String calendarEventId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaskMeta() when $default != null:
return $default(_that.calendarEventId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String calendarEventId)  $default,) {final _that = this;
switch (_that) {
case _TaskMeta():
return $default(_that.calendarEventId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String calendarEventId)?  $default,) {final _that = this;
switch (_that) {
case _TaskMeta() when $default != null:
return $default(_that.calendarEventId);case _:
  return null;

}
}

}

/// @nodoc


class _TaskMeta implements TaskMeta {
  const _TaskMeta({this.calendarEventId = ''});
  

@override@JsonKey() final  String calendarEventId;

/// Create a copy of TaskMeta
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskMetaCopyWith<_TaskMeta> get copyWith => __$TaskMetaCopyWithImpl<_TaskMeta>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaskMeta&&(identical(other.calendarEventId, calendarEventId) || other.calendarEventId == calendarEventId));
}


@override
int get hashCode => Object.hash(runtimeType,calendarEventId);

@override
String toString() {
  return 'TaskMeta(calendarEventId: $calendarEventId)';
}


}

/// @nodoc
abstract mixin class _$TaskMetaCopyWith<$Res> implements $TaskMetaCopyWith<$Res> {
  factory _$TaskMetaCopyWith(_TaskMeta value, $Res Function(_TaskMeta) _then) = __$TaskMetaCopyWithImpl;
@override @useResult
$Res call({
 String calendarEventId
});




}
/// @nodoc
class __$TaskMetaCopyWithImpl<$Res>
    implements _$TaskMetaCopyWith<$Res> {
  __$TaskMetaCopyWithImpl(this._self, this._then);

  final _TaskMeta _self;
  final $Res Function(_TaskMeta) _then;

/// Create a copy of TaskMeta
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? calendarEventId = null,}) {
  return _then(_TaskMeta(
calendarEventId: null == calendarEventId ? _self.calendarEventId : calendarEventId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
