// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProjectApi {

 String get id;@JsonKey(name: 'user_id') String get userId;@JsonKey(name: 'assigned_user_id') String get assignedUserId;@JsonKey(name: 'client_id') String get clientId; String get number; String get name;@JsonKey(name: 'task_rate') Object get taskRate;@JsonKey(name: 'due_date') String get dueDate;@JsonKey(name: 'private_notes') String get privateNotes;@JsonKey(name: 'public_notes') String get publicNotes;@JsonKey(name: 'budgeted_hours') num get budgetedHours;// Money — typed `Object` like `task_rate` because the server has emitted
// both a number and a string for money fields; `parseMoney` normalizes.
@JsonKey(name: 'budgeted_amount') Object get budgetedAmount;@JsonKey(name: 'current_hours') num get currentHours;@JsonKey(name: 'custom_value1') String get customValue1;@JsonKey(name: 'custom_value2') String get customValue2;@JsonKey(name: 'custom_value3') String get customValue3;@JsonKey(name: 'custom_value4') String get customValue4; String get color;@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt;@JsonKey(name: 'is_deleted') bool get isDeleted;// Nullable so JSON-omitted (→ null) is distinguishable from
// JSON-present-and-empty (→ `const []`). Same convention as
// `ClientApi.documents` / `ProductApi.documents`.
 List<DocumentApi>? get documents;// See `TaskApi.tags` — tolerant of `[{id,name,color}]` and bare ids.
@JsonKey(name: 'tags')@EmbeddedTagsConverter() List<TagRefApi> get tags;
/// Create a copy of ProjectApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectApiCopyWith<ProjectApi> get copyWith => _$ProjectApiCopyWithImpl<ProjectApi>(this as ProjectApi, _$identity);

  /// Serializes this ProjectApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectApi&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.number, number) || other.number == number)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.taskRate, taskRate)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.privateNotes, privateNotes) || other.privateNotes == privateNotes)&&(identical(other.publicNotes, publicNotes) || other.publicNotes == publicNotes)&&(identical(other.budgetedHours, budgetedHours) || other.budgetedHours == budgetedHours)&&const DeepCollectionEquality().equals(other.budgetedAmount, budgetedAmount)&&(identical(other.currentHours, currentHours) || other.currentHours == currentHours)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.color, color) || other.color == color)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&const DeepCollectionEquality().equals(other.documents, documents)&&const DeepCollectionEquality().equals(other.tags, tags));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,assignedUserId,clientId,number,name,const DeepCollectionEquality().hash(taskRate),dueDate,privateNotes,publicNotes,budgetedHours,const DeepCollectionEquality().hash(budgetedAmount),currentHours,customValue1,customValue2,customValue3,customValue4,color,createdAt,updatedAt,archivedAt,isDeleted,const DeepCollectionEquality().hash(documents),const DeepCollectionEquality().hash(tags)]);

@override
String toString() {
  return 'ProjectApi(id: $id, userId: $userId, assignedUserId: $assignedUserId, clientId: $clientId, number: $number, name: $name, taskRate: $taskRate, dueDate: $dueDate, privateNotes: $privateNotes, publicNotes: $publicNotes, budgetedHours: $budgetedHours, budgetedAmount: $budgetedAmount, currentHours: $currentHours, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, color: $color, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted, documents: $documents, tags: $tags)';
}


}

/// @nodoc
abstract mixin class $ProjectApiCopyWith<$Res>  {
  factory $ProjectApiCopyWith(ProjectApi value, $Res Function(ProjectApi) _then) = _$ProjectApiCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'assigned_user_id') String assignedUserId,@JsonKey(name: 'client_id') String clientId, String number, String name,@JsonKey(name: 'task_rate') Object taskRate,@JsonKey(name: 'due_date') String dueDate,@JsonKey(name: 'private_notes') String privateNotes,@JsonKey(name: 'public_notes') String publicNotes,@JsonKey(name: 'budgeted_hours') num budgetedHours,@JsonKey(name: 'budgeted_amount') Object budgetedAmount,@JsonKey(name: 'current_hours') num currentHours,@JsonKey(name: 'custom_value1') String customValue1,@JsonKey(name: 'custom_value2') String customValue2,@JsonKey(name: 'custom_value3') String customValue3,@JsonKey(name: 'custom_value4') String customValue4, String color,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'is_deleted') bool isDeleted, List<DocumentApi>? documents,@JsonKey(name: 'tags')@EmbeddedTagsConverter() List<TagRefApi> tags
});




}
/// @nodoc
class _$ProjectApiCopyWithImpl<$Res>
    implements $ProjectApiCopyWith<$Res> {
  _$ProjectApiCopyWithImpl(this._self, this._then);

  final ProjectApi _self;
  final $Res Function(ProjectApi) _then;

/// Create a copy of ProjectApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? assignedUserId = null,Object? clientId = null,Object? number = null,Object? name = null,Object? taskRate = null,Object? dueDate = null,Object? privateNotes = null,Object? publicNotes = null,Object? budgetedHours = null,Object? budgetedAmount = null,Object? currentHours = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? color = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,Object? documents = freezed,Object? tags = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,taskRate: null == taskRate ? _self.taskRate : taskRate ,dueDate: null == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as String,privateNotes: null == privateNotes ? _self.privateNotes : privateNotes // ignore: cast_nullable_to_non_nullable
as String,publicNotes: null == publicNotes ? _self.publicNotes : publicNotes // ignore: cast_nullable_to_non_nullable
as String,budgetedHours: null == budgetedHours ? _self.budgetedHours : budgetedHours // ignore: cast_nullable_to_non_nullable
as num,budgetedAmount: null == budgetedAmount ? _self.budgetedAmount : budgetedAmount ,currentHours: null == currentHours ? _self.currentHours : currentHours // ignore: cast_nullable_to_non_nullable
as num,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,documents: freezed == documents ? _self.documents : documents // ignore: cast_nullable_to_non_nullable
as List<DocumentApi>?,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagRefApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [ProjectApi].
extension ProjectApiPatterns on ProjectApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProjectApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProjectApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProjectApi value)  $default,){
final _that = this;
switch (_that) {
case _ProjectApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProjectApi value)?  $default,){
final _that = this;
switch (_that) {
case _ProjectApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'assigned_user_id')  String assignedUserId, @JsonKey(name: 'client_id')  String clientId,  String number,  String name, @JsonKey(name: 'task_rate')  Object taskRate, @JsonKey(name: 'due_date')  String dueDate, @JsonKey(name: 'private_notes')  String privateNotes, @JsonKey(name: 'public_notes')  String publicNotes, @JsonKey(name: 'budgeted_hours')  num budgetedHours, @JsonKey(name: 'budgeted_amount')  Object budgetedAmount, @JsonKey(name: 'current_hours')  num currentHours, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4,  String color, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted,  List<DocumentApi>? documents, @JsonKey(name: 'tags')@EmbeddedTagsConverter()  List<TagRefApi> tags)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProjectApi() when $default != null:
return $default(_that.id,_that.userId,_that.assignedUserId,_that.clientId,_that.number,_that.name,_that.taskRate,_that.dueDate,_that.privateNotes,_that.publicNotes,_that.budgetedHours,_that.budgetedAmount,_that.currentHours,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.color,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted,_that.documents,_that.tags);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'assigned_user_id')  String assignedUserId, @JsonKey(name: 'client_id')  String clientId,  String number,  String name, @JsonKey(name: 'task_rate')  Object taskRate, @JsonKey(name: 'due_date')  String dueDate, @JsonKey(name: 'private_notes')  String privateNotes, @JsonKey(name: 'public_notes')  String publicNotes, @JsonKey(name: 'budgeted_hours')  num budgetedHours, @JsonKey(name: 'budgeted_amount')  Object budgetedAmount, @JsonKey(name: 'current_hours')  num currentHours, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4,  String color, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted,  List<DocumentApi>? documents, @JsonKey(name: 'tags')@EmbeddedTagsConverter()  List<TagRefApi> tags)  $default,) {final _that = this;
switch (_that) {
case _ProjectApi():
return $default(_that.id,_that.userId,_that.assignedUserId,_that.clientId,_that.number,_that.name,_that.taskRate,_that.dueDate,_that.privateNotes,_that.publicNotes,_that.budgetedHours,_that.budgetedAmount,_that.currentHours,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.color,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted,_that.documents,_that.tags);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'assigned_user_id')  String assignedUserId, @JsonKey(name: 'client_id')  String clientId,  String number,  String name, @JsonKey(name: 'task_rate')  Object taskRate, @JsonKey(name: 'due_date')  String dueDate, @JsonKey(name: 'private_notes')  String privateNotes, @JsonKey(name: 'public_notes')  String publicNotes, @JsonKey(name: 'budgeted_hours')  num budgetedHours, @JsonKey(name: 'budgeted_amount')  Object budgetedAmount, @JsonKey(name: 'current_hours')  num currentHours, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4,  String color, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted,  List<DocumentApi>? documents, @JsonKey(name: 'tags')@EmbeddedTagsConverter()  List<TagRefApi> tags)?  $default,) {final _that = this;
switch (_that) {
case _ProjectApi() when $default != null:
return $default(_that.id,_that.userId,_that.assignedUserId,_that.clientId,_that.number,_that.name,_that.taskRate,_that.dueDate,_that.privateNotes,_that.publicNotes,_that.budgetedHours,_that.budgetedAmount,_that.currentHours,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.color,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted,_that.documents,_that.tags);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProjectApi implements ProjectApi {
  const _ProjectApi({this.id = '', @JsonKey(name: 'user_id') this.userId = '', @JsonKey(name: 'assigned_user_id') this.assignedUserId = '', @JsonKey(name: 'client_id') this.clientId = '', this.number = '', this.name = '', @JsonKey(name: 'task_rate') this.taskRate = '0', @JsonKey(name: 'due_date') this.dueDate = '', @JsonKey(name: 'private_notes') this.privateNotes = '', @JsonKey(name: 'public_notes') this.publicNotes = '', @JsonKey(name: 'budgeted_hours') this.budgetedHours = 0, @JsonKey(name: 'budgeted_amount') this.budgetedAmount = '0', @JsonKey(name: 'current_hours') this.currentHours = 0, @JsonKey(name: 'custom_value1') this.customValue1 = '', @JsonKey(name: 'custom_value2') this.customValue2 = '', @JsonKey(name: 'custom_value3') this.customValue3 = '', @JsonKey(name: 'custom_value4') this.customValue4 = '', this.color = '', @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0, @JsonKey(name: 'is_deleted') this.isDeleted = false, final  List<DocumentApi>? documents, @JsonKey(name: 'tags')@EmbeddedTagsConverter() final  List<TagRefApi> tags = const <TagRefApi>[]}): _documents = documents,_tags = tags;
  factory _ProjectApi.fromJson(Map<String, dynamic> json) => _$ProjectApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey(name: 'user_id') final  String userId;
@override@JsonKey(name: 'assigned_user_id') final  String assignedUserId;
@override@JsonKey(name: 'client_id') final  String clientId;
@override@JsonKey() final  String number;
@override@JsonKey() final  String name;
@override@JsonKey(name: 'task_rate') final  Object taskRate;
@override@JsonKey(name: 'due_date') final  String dueDate;
@override@JsonKey(name: 'private_notes') final  String privateNotes;
@override@JsonKey(name: 'public_notes') final  String publicNotes;
@override@JsonKey(name: 'budgeted_hours') final  num budgetedHours;
// Money — typed `Object` like `task_rate` because the server has emitted
// both a number and a string for money fields; `parseMoney` normalizes.
@override@JsonKey(name: 'budgeted_amount') final  Object budgetedAmount;
@override@JsonKey(name: 'current_hours') final  num currentHours;
@override@JsonKey(name: 'custom_value1') final  String customValue1;
@override@JsonKey(name: 'custom_value2') final  String customValue2;
@override@JsonKey(name: 'custom_value3') final  String customValue3;
@override@JsonKey(name: 'custom_value4') final  String customValue4;
@override@JsonKey() final  String color;
@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'archived_at') final  int archivedAt;
@override@JsonKey(name: 'is_deleted') final  bool isDeleted;
// Nullable so JSON-omitted (→ null) is distinguishable from
// JSON-present-and-empty (→ `const []`). Same convention as
// `ClientApi.documents` / `ProductApi.documents`.
 final  List<DocumentApi>? _documents;
// Nullable so JSON-omitted (→ null) is distinguishable from
// JSON-present-and-empty (→ `const []`). Same convention as
// `ClientApi.documents` / `ProductApi.documents`.
@override List<DocumentApi>? get documents {
  final value = _documents;
  if (value == null) return null;
  if (_documents is EqualUnmodifiableListView) return _documents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

// See `TaskApi.tags` — tolerant of `[{id,name,color}]` and bare ids.
 final  List<TagRefApi> _tags;
// See `TaskApi.tags` — tolerant of `[{id,name,color}]` and bare ids.
@override@JsonKey(name: 'tags')@EmbeddedTagsConverter() List<TagRefApi> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}


/// Create a copy of ProjectApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectApiCopyWith<_ProjectApi> get copyWith => __$ProjectApiCopyWithImpl<_ProjectApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectApi&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.number, number) || other.number == number)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.taskRate, taskRate)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.privateNotes, privateNotes) || other.privateNotes == privateNotes)&&(identical(other.publicNotes, publicNotes) || other.publicNotes == publicNotes)&&(identical(other.budgetedHours, budgetedHours) || other.budgetedHours == budgetedHours)&&const DeepCollectionEquality().equals(other.budgetedAmount, budgetedAmount)&&(identical(other.currentHours, currentHours) || other.currentHours == currentHours)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.color, color) || other.color == color)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&const DeepCollectionEquality().equals(other._documents, _documents)&&const DeepCollectionEquality().equals(other._tags, _tags));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,assignedUserId,clientId,number,name,const DeepCollectionEquality().hash(taskRate),dueDate,privateNotes,publicNotes,budgetedHours,const DeepCollectionEquality().hash(budgetedAmount),currentHours,customValue1,customValue2,customValue3,customValue4,color,createdAt,updatedAt,archivedAt,isDeleted,const DeepCollectionEquality().hash(_documents),const DeepCollectionEquality().hash(_tags)]);

@override
String toString() {
  return 'ProjectApi(id: $id, userId: $userId, assignedUserId: $assignedUserId, clientId: $clientId, number: $number, name: $name, taskRate: $taskRate, dueDate: $dueDate, privateNotes: $privateNotes, publicNotes: $publicNotes, budgetedHours: $budgetedHours, budgetedAmount: $budgetedAmount, currentHours: $currentHours, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, color: $color, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted, documents: $documents, tags: $tags)';
}


}

/// @nodoc
abstract mixin class _$ProjectApiCopyWith<$Res> implements $ProjectApiCopyWith<$Res> {
  factory _$ProjectApiCopyWith(_ProjectApi value, $Res Function(_ProjectApi) _then) = __$ProjectApiCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'assigned_user_id') String assignedUserId,@JsonKey(name: 'client_id') String clientId, String number, String name,@JsonKey(name: 'task_rate') Object taskRate,@JsonKey(name: 'due_date') String dueDate,@JsonKey(name: 'private_notes') String privateNotes,@JsonKey(name: 'public_notes') String publicNotes,@JsonKey(name: 'budgeted_hours') num budgetedHours,@JsonKey(name: 'budgeted_amount') Object budgetedAmount,@JsonKey(name: 'current_hours') num currentHours,@JsonKey(name: 'custom_value1') String customValue1,@JsonKey(name: 'custom_value2') String customValue2,@JsonKey(name: 'custom_value3') String customValue3,@JsonKey(name: 'custom_value4') String customValue4, String color,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'is_deleted') bool isDeleted, List<DocumentApi>? documents,@JsonKey(name: 'tags')@EmbeddedTagsConverter() List<TagRefApi> tags
});




}
/// @nodoc
class __$ProjectApiCopyWithImpl<$Res>
    implements _$ProjectApiCopyWith<$Res> {
  __$ProjectApiCopyWithImpl(this._self, this._then);

  final _ProjectApi _self;
  final $Res Function(_ProjectApi) _then;

/// Create a copy of ProjectApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? assignedUserId = null,Object? clientId = null,Object? number = null,Object? name = null,Object? taskRate = null,Object? dueDate = null,Object? privateNotes = null,Object? publicNotes = null,Object? budgetedHours = null,Object? budgetedAmount = null,Object? currentHours = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? color = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,Object? documents = freezed,Object? tags = null,}) {
  return _then(_ProjectApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,taskRate: null == taskRate ? _self.taskRate : taskRate ,dueDate: null == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as String,privateNotes: null == privateNotes ? _self.privateNotes : privateNotes // ignore: cast_nullable_to_non_nullable
as String,publicNotes: null == publicNotes ? _self.publicNotes : publicNotes // ignore: cast_nullable_to_non_nullable
as String,budgetedHours: null == budgetedHours ? _self.budgetedHours : budgetedHours // ignore: cast_nullable_to_non_nullable
as num,budgetedAmount: null == budgetedAmount ? _self.budgetedAmount : budgetedAmount ,currentHours: null == currentHours ? _self.currentHours : currentHours // ignore: cast_nullable_to_non_nullable
as num,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,documents: freezed == documents ? _self._documents : documents // ignore: cast_nullable_to_non_nullable
as List<DocumentApi>?,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagRefApi>,
  ));
}


}


/// @nodoc
mixin _$ProjectListApi {

@JsonKey(fromJson: _projectListData) List<ProjectApi> get data;
/// Create a copy of ProjectListApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectListApiCopyWith<ProjectListApi> get copyWith => _$ProjectListApiCopyWithImpl<ProjectListApi>(this as ProjectListApi, _$identity);

  /// Serializes this ProjectListApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectListApi&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'ProjectListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $ProjectListApiCopyWith<$Res>  {
  factory $ProjectListApiCopyWith(ProjectListApi value, $Res Function(ProjectListApi) _then) = _$ProjectListApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _projectListData) List<ProjectApi> data
});




}
/// @nodoc
class _$ProjectListApiCopyWithImpl<$Res>
    implements $ProjectListApiCopyWith<$Res> {
  _$ProjectListApiCopyWithImpl(this._self, this._then);

  final ProjectListApi _self;
  final $Res Function(ProjectListApi) _then;

/// Create a copy of ProjectListApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<ProjectApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [ProjectListApi].
extension ProjectListApiPatterns on ProjectListApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProjectListApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProjectListApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProjectListApi value)  $default,){
final _that = this;
switch (_that) {
case _ProjectListApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProjectListApi value)?  $default,){
final _that = this;
switch (_that) {
case _ProjectListApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _projectListData)  List<ProjectApi> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProjectListApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _projectListData)  List<ProjectApi> data)  $default,) {final _that = this;
switch (_that) {
case _ProjectListApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _projectListData)  List<ProjectApi> data)?  $default,) {final _that = this;
switch (_that) {
case _ProjectListApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProjectListApi implements ProjectListApi {
  const _ProjectListApi({@JsonKey(fromJson: _projectListData) final  List<ProjectApi> data = const []}): _data = data;
  factory _ProjectListApi.fromJson(Map<String, dynamic> json) => _$ProjectListApiFromJson(json);

 final  List<ProjectApi> _data;
@override@JsonKey(fromJson: _projectListData) List<ProjectApi> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of ProjectListApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectListApiCopyWith<_ProjectListApi> get copyWith => __$ProjectListApiCopyWithImpl<_ProjectListApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectListApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectListApi&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'ProjectListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$ProjectListApiCopyWith<$Res> implements $ProjectListApiCopyWith<$Res> {
  factory _$ProjectListApiCopyWith(_ProjectListApi value, $Res Function(_ProjectListApi) _then) = __$ProjectListApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _projectListData) List<ProjectApi> data
});




}
/// @nodoc
class __$ProjectListApiCopyWithImpl<$Res>
    implements _$ProjectListApiCopyWith<$Res> {
  __$ProjectListApiCopyWithImpl(this._self, this._then);

  final _ProjectListApi _self;
  final $Res Function(_ProjectListApi) _then;

/// Create a copy of ProjectListApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_ProjectListApi(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<ProjectApi>,
  ));
}


}


/// @nodoc
mixin _$ProjectItemApi {

 ProjectApi get data;
/// Create a copy of ProjectItemApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectItemApiCopyWith<ProjectItemApi> get copyWith => _$ProjectItemApiCopyWithImpl<ProjectItemApi>(this as ProjectItemApi, _$identity);

  /// Serializes this ProjectItemApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'ProjectItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $ProjectItemApiCopyWith<$Res>  {
  factory $ProjectItemApiCopyWith(ProjectItemApi value, $Res Function(ProjectItemApi) _then) = _$ProjectItemApiCopyWithImpl;
@useResult
$Res call({
 ProjectApi data
});


$ProjectApiCopyWith<$Res> get data;

}
/// @nodoc
class _$ProjectItemApiCopyWithImpl<$Res>
    implements $ProjectItemApiCopyWith<$Res> {
  _$ProjectItemApiCopyWithImpl(this._self, this._then);

  final ProjectItemApi _self;
  final $Res Function(ProjectItemApi) _then;

/// Create a copy of ProjectItemApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as ProjectApi,
  ));
}
/// Create a copy of ProjectItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProjectApiCopyWith<$Res> get data {
  
  return $ProjectApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [ProjectItemApi].
extension ProjectItemApiPatterns on ProjectItemApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProjectItemApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProjectItemApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProjectItemApi value)  $default,){
final _that = this;
switch (_that) {
case _ProjectItemApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProjectItemApi value)?  $default,){
final _that = this;
switch (_that) {
case _ProjectItemApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ProjectApi data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProjectItemApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ProjectApi data)  $default,) {final _that = this;
switch (_that) {
case _ProjectItemApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ProjectApi data)?  $default,) {final _that = this;
switch (_that) {
case _ProjectItemApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProjectItemApi implements ProjectItemApi {
  const _ProjectItemApi({required this.data});
  factory _ProjectItemApi.fromJson(Map<String, dynamic> json) => _$ProjectItemApiFromJson(json);

@override final  ProjectApi data;

/// Create a copy of ProjectItemApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectItemApiCopyWith<_ProjectItemApi> get copyWith => __$ProjectItemApiCopyWithImpl<_ProjectItemApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectItemApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'ProjectItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$ProjectItemApiCopyWith<$Res> implements $ProjectItemApiCopyWith<$Res> {
  factory _$ProjectItemApiCopyWith(_ProjectItemApi value, $Res Function(_ProjectItemApi) _then) = __$ProjectItemApiCopyWithImpl;
@override @useResult
$Res call({
 ProjectApi data
});


@override $ProjectApiCopyWith<$Res> get data;

}
/// @nodoc
class __$ProjectItemApiCopyWithImpl<$Res>
    implements _$ProjectItemApiCopyWith<$Res> {
  __$ProjectItemApiCopyWithImpl(this._self, this._then);

  final _ProjectItemApi _self;
  final $Res Function(_ProjectItemApi) _then;

/// Create a copy of ProjectItemApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_ProjectItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as ProjectApi,
  ));
}

/// Create a copy of ProjectItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProjectApiCopyWith<$Res> get data {
  
  return $ProjectApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

// dart format on
