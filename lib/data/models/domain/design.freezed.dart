// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'design.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Design {

 String get id; String get name; bool get isCustom; bool get isActive; bool get isTemplate; bool get isFree; List<String> get entities; DesignTemplate get template; DateTime get updatedAt; DateTime get createdAt; DateTime? get archivedAt; bool get isDeleted; bool get isDirty;
/// Create a copy of Design
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DesignCopyWith<Design> get copyWith => _$DesignCopyWithImpl<Design>(this as Design, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Design&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.isCustom, isCustom) || other.isCustom == isCustom)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.isTemplate, isTemplate) || other.isTemplate == isTemplate)&&(identical(other.isFree, isFree) || other.isFree == isFree)&&const DeepCollectionEquality().equals(other.entities, entities)&&(identical(other.template, template) || other.template == template)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,isCustom,isActive,isTemplate,isFree,const DeepCollectionEquality().hash(entities),template,updatedAt,createdAt,archivedAt,isDeleted,isDirty);

@override
String toString() {
  return 'Design(id: $id, name: $name, isCustom: $isCustom, isActive: $isActive, isTemplate: $isTemplate, isFree: $isFree, entities: $entities, template: $template, updatedAt: $updatedAt, createdAt: $createdAt, archivedAt: $archivedAt, isDeleted: $isDeleted, isDirty: $isDirty)';
}


}

/// @nodoc
abstract mixin class $DesignCopyWith<$Res>  {
  factory $DesignCopyWith(Design value, $Res Function(Design) _then) = _$DesignCopyWithImpl;
@useResult
$Res call({
 String id, String name, bool isCustom, bool isActive, bool isTemplate, bool isFree, List<String> entities, DesignTemplate template, DateTime updatedAt, DateTime createdAt, DateTime? archivedAt, bool isDeleted, bool isDirty
});


$DesignTemplateCopyWith<$Res> get template;

}
/// @nodoc
class _$DesignCopyWithImpl<$Res>
    implements $DesignCopyWith<$Res> {
  _$DesignCopyWithImpl(this._self, this._then);

  final Design _self;
  final $Res Function(Design) _then;

/// Create a copy of Design
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? isCustom = null,Object? isActive = null,Object? isTemplate = null,Object? isFree = null,Object? entities = null,Object? template = null,Object? updatedAt = null,Object? createdAt = null,Object? archivedAt = freezed,Object? isDeleted = null,Object? isDirty = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,isCustom: null == isCustom ? _self.isCustom : isCustom // ignore: cast_nullable_to_non_nullable
as bool,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,isTemplate: null == isTemplate ? _self.isTemplate : isTemplate // ignore: cast_nullable_to_non_nullable
as bool,isFree: null == isFree ? _self.isFree : isFree // ignore: cast_nullable_to_non_nullable
as bool,entities: null == entities ? _self.entities : entities // ignore: cast_nullable_to_non_nullable
as List<String>,template: null == template ? _self.template : template // ignore: cast_nullable_to_non_nullable
as DesignTemplate,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of Design
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DesignTemplateCopyWith<$Res> get template {
  
  return $DesignTemplateCopyWith<$Res>(_self.template, (value) {
    return _then(_self.copyWith(template: value));
  });
}
}


/// Adds pattern-matching-related methods to [Design].
extension DesignPatterns on Design {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Design value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Design() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Design value)  $default,){
final _that = this;
switch (_that) {
case _Design():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Design value)?  $default,){
final _that = this;
switch (_that) {
case _Design() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  bool isCustom,  bool isActive,  bool isTemplate,  bool isFree,  List<String> entities,  DesignTemplate template,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  bool isDeleted,  bool isDirty)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Design() when $default != null:
return $default(_that.id,_that.name,_that.isCustom,_that.isActive,_that.isTemplate,_that.isFree,_that.entities,_that.template,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.isDeleted,_that.isDirty);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  bool isCustom,  bool isActive,  bool isTemplate,  bool isFree,  List<String> entities,  DesignTemplate template,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  bool isDeleted,  bool isDirty)  $default,) {final _that = this;
switch (_that) {
case _Design():
return $default(_that.id,_that.name,_that.isCustom,_that.isActive,_that.isTemplate,_that.isFree,_that.entities,_that.template,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.isDeleted,_that.isDirty);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  bool isCustom,  bool isActive,  bool isTemplate,  bool isFree,  List<String> entities,  DesignTemplate template,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  bool isDeleted,  bool isDirty)?  $default,) {final _that = this;
switch (_that) {
case _Design() when $default != null:
return $default(_that.id,_that.name,_that.isCustom,_that.isActive,_that.isTemplate,_that.isFree,_that.entities,_that.template,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.isDeleted,_that.isDirty);case _:
  return null;

}
}

}

/// @nodoc


class _Design implements Design {
  const _Design({required this.id, required this.name, required this.isCustom, required this.isActive, required this.isTemplate, required this.isFree, required final  List<String> entities, required this.template, required this.updatedAt, required this.createdAt, required this.archivedAt, required this.isDeleted, this.isDirty = false}): _entities = entities;
  

@override final  String id;
@override final  String name;
@override final  bool isCustom;
@override final  bool isActive;
@override final  bool isTemplate;
@override final  bool isFree;
 final  List<String> _entities;
@override List<String> get entities {
  if (_entities is EqualUnmodifiableListView) return _entities;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entities);
}

@override final  DesignTemplate template;
@override final  DateTime updatedAt;
@override final  DateTime createdAt;
@override final  DateTime? archivedAt;
@override final  bool isDeleted;
@override@JsonKey() final  bool isDirty;

/// Create a copy of Design
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DesignCopyWith<_Design> get copyWith => __$DesignCopyWithImpl<_Design>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Design&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.isCustom, isCustom) || other.isCustom == isCustom)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.isTemplate, isTemplate) || other.isTemplate == isTemplate)&&(identical(other.isFree, isFree) || other.isFree == isFree)&&const DeepCollectionEquality().equals(other._entities, _entities)&&(identical(other.template, template) || other.template == template)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,isCustom,isActive,isTemplate,isFree,const DeepCollectionEquality().hash(_entities),template,updatedAt,createdAt,archivedAt,isDeleted,isDirty);

@override
String toString() {
  return 'Design(id: $id, name: $name, isCustom: $isCustom, isActive: $isActive, isTemplate: $isTemplate, isFree: $isFree, entities: $entities, template: $template, updatedAt: $updatedAt, createdAt: $createdAt, archivedAt: $archivedAt, isDeleted: $isDeleted, isDirty: $isDirty)';
}


}

/// @nodoc
abstract mixin class _$DesignCopyWith<$Res> implements $DesignCopyWith<$Res> {
  factory _$DesignCopyWith(_Design value, $Res Function(_Design) _then) = __$DesignCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, bool isCustom, bool isActive, bool isTemplate, bool isFree, List<String> entities, DesignTemplate template, DateTime updatedAt, DateTime createdAt, DateTime? archivedAt, bool isDeleted, bool isDirty
});


@override $DesignTemplateCopyWith<$Res> get template;

}
/// @nodoc
class __$DesignCopyWithImpl<$Res>
    implements _$DesignCopyWith<$Res> {
  __$DesignCopyWithImpl(this._self, this._then);

  final _Design _self;
  final $Res Function(_Design) _then;

/// Create a copy of Design
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? isCustom = null,Object? isActive = null,Object? isTemplate = null,Object? isFree = null,Object? entities = null,Object? template = null,Object? updatedAt = null,Object? createdAt = null,Object? archivedAt = freezed,Object? isDeleted = null,Object? isDirty = null,}) {
  return _then(_Design(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,isCustom: null == isCustom ? _self.isCustom : isCustom // ignore: cast_nullable_to_non_nullable
as bool,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,isTemplate: null == isTemplate ? _self.isTemplate : isTemplate // ignore: cast_nullable_to_non_nullable
as bool,isFree: null == isFree ? _self.isFree : isFree // ignore: cast_nullable_to_non_nullable
as bool,entities: null == entities ? _self._entities : entities // ignore: cast_nullable_to_non_nullable
as List<String>,template: null == template ? _self.template : template // ignore: cast_nullable_to_non_nullable
as DesignTemplate,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of Design
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DesignTemplateCopyWith<$Res> get template {
  
  return $DesignTemplateCopyWith<$Res>(_self.template, (value) {
    return _then(_self.copyWith(template: value));
  });
}
}

/// @nodoc
mixin _$DesignTemplate {

 String get body; String get header; String get footer; String get includes; String get product; String get task; List<DesignBlock> get blocks; DocumentSettings? get documentSettings;/// Fields the server sent that this model has no name for — carried so a
/// save hands them back (`kDesignExtraKey`).
 Map<String, dynamic> get extra;
/// Create a copy of DesignTemplate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DesignTemplateCopyWith<DesignTemplate> get copyWith => _$DesignTemplateCopyWithImpl<DesignTemplate>(this as DesignTemplate, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DesignTemplate&&(identical(other.body, body) || other.body == body)&&(identical(other.header, header) || other.header == header)&&(identical(other.footer, footer) || other.footer == footer)&&(identical(other.includes, includes) || other.includes == includes)&&(identical(other.product, product) || other.product == product)&&(identical(other.task, task) || other.task == task)&&const DeepCollectionEquality().equals(other.blocks, blocks)&&(identical(other.documentSettings, documentSettings) || other.documentSettings == documentSettings)&&const DeepCollectionEquality().equals(other.extra, extra));
}


@override
int get hashCode => Object.hash(runtimeType,body,header,footer,includes,product,task,const DeepCollectionEquality().hash(blocks),documentSettings,const DeepCollectionEquality().hash(extra));

@override
String toString() {
  return 'DesignTemplate(body: $body, header: $header, footer: $footer, includes: $includes, product: $product, task: $task, blocks: $blocks, documentSettings: $documentSettings, extra: $extra)';
}


}

/// @nodoc
abstract mixin class $DesignTemplateCopyWith<$Res>  {
  factory $DesignTemplateCopyWith(DesignTemplate value, $Res Function(DesignTemplate) _then) = _$DesignTemplateCopyWithImpl;
@useResult
$Res call({
 String body, String header, String footer, String includes, String product, String task, List<DesignBlock> blocks, DocumentSettings? documentSettings, Map<String, dynamic> extra
});


$DocumentSettingsCopyWith<$Res>? get documentSettings;

}
/// @nodoc
class _$DesignTemplateCopyWithImpl<$Res>
    implements $DesignTemplateCopyWith<$Res> {
  _$DesignTemplateCopyWithImpl(this._self, this._then);

  final DesignTemplate _self;
  final $Res Function(DesignTemplate) _then;

/// Create a copy of DesignTemplate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? body = null,Object? header = null,Object? footer = null,Object? includes = null,Object? product = null,Object? task = null,Object? blocks = null,Object? documentSettings = freezed,Object? extra = null,}) {
  return _then(_self.copyWith(
body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,header: null == header ? _self.header : header // ignore: cast_nullable_to_non_nullable
as String,footer: null == footer ? _self.footer : footer // ignore: cast_nullable_to_non_nullable
as String,includes: null == includes ? _self.includes : includes // ignore: cast_nullable_to_non_nullable
as String,product: null == product ? _self.product : product // ignore: cast_nullable_to_non_nullable
as String,task: null == task ? _self.task : task // ignore: cast_nullable_to_non_nullable
as String,blocks: null == blocks ? _self.blocks : blocks // ignore: cast_nullable_to_non_nullable
as List<DesignBlock>,documentSettings: freezed == documentSettings ? _self.documentSettings : documentSettings // ignore: cast_nullable_to_non_nullable
as DocumentSettings?,extra: null == extra ? _self.extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}
/// Create a copy of DesignTemplate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DocumentSettingsCopyWith<$Res>? get documentSettings {
    if (_self.documentSettings == null) {
    return null;
  }

  return $DocumentSettingsCopyWith<$Res>(_self.documentSettings!, (value) {
    return _then(_self.copyWith(documentSettings: value));
  });
}
}


/// Adds pattern-matching-related methods to [DesignTemplate].
extension DesignTemplatePatterns on DesignTemplate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DesignTemplate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DesignTemplate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DesignTemplate value)  $default,){
final _that = this;
switch (_that) {
case _DesignTemplate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DesignTemplate value)?  $default,){
final _that = this;
switch (_that) {
case _DesignTemplate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String body,  String header,  String footer,  String includes,  String product,  String task,  List<DesignBlock> blocks,  DocumentSettings? documentSettings,  Map<String, dynamic> extra)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DesignTemplate() when $default != null:
return $default(_that.body,_that.header,_that.footer,_that.includes,_that.product,_that.task,_that.blocks,_that.documentSettings,_that.extra);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String body,  String header,  String footer,  String includes,  String product,  String task,  List<DesignBlock> blocks,  DocumentSettings? documentSettings,  Map<String, dynamic> extra)  $default,) {final _that = this;
switch (_that) {
case _DesignTemplate():
return $default(_that.body,_that.header,_that.footer,_that.includes,_that.product,_that.task,_that.blocks,_that.documentSettings,_that.extra);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String body,  String header,  String footer,  String includes,  String product,  String task,  List<DesignBlock> blocks,  DocumentSettings? documentSettings,  Map<String, dynamic> extra)?  $default,) {final _that = this;
switch (_that) {
case _DesignTemplate() when $default != null:
return $default(_that.body,_that.header,_that.footer,_that.includes,_that.product,_that.task,_that.blocks,_that.documentSettings,_that.extra);case _:
  return null;

}
}

}

/// @nodoc


class _DesignTemplate implements DesignTemplate {
  const _DesignTemplate({this.body = '', this.header = '', this.footer = '', this.includes = '', this.product = '', this.task = '', final  List<DesignBlock> blocks = const <DesignBlock>[], this.documentSettings, final  Map<String, dynamic> extra = const <String, dynamic>{}}): _blocks = blocks,_extra = extra;
  

@override@JsonKey() final  String body;
@override@JsonKey() final  String header;
@override@JsonKey() final  String footer;
@override@JsonKey() final  String includes;
@override@JsonKey() final  String product;
@override@JsonKey() final  String task;
 final  List<DesignBlock> _blocks;
@override@JsonKey() List<DesignBlock> get blocks {
  if (_blocks is EqualUnmodifiableListView) return _blocks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_blocks);
}

@override final  DocumentSettings? documentSettings;
/// Fields the server sent that this model has no name for — carried so a
/// save hands them back (`kDesignExtraKey`).
 final  Map<String, dynamic> _extra;
/// Fields the server sent that this model has no name for — carried so a
/// save hands them back (`kDesignExtraKey`).
@override@JsonKey() Map<String, dynamic> get extra {
  if (_extra is EqualUnmodifiableMapView) return _extra;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_extra);
}


/// Create a copy of DesignTemplate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DesignTemplateCopyWith<_DesignTemplate> get copyWith => __$DesignTemplateCopyWithImpl<_DesignTemplate>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DesignTemplate&&(identical(other.body, body) || other.body == body)&&(identical(other.header, header) || other.header == header)&&(identical(other.footer, footer) || other.footer == footer)&&(identical(other.includes, includes) || other.includes == includes)&&(identical(other.product, product) || other.product == product)&&(identical(other.task, task) || other.task == task)&&const DeepCollectionEquality().equals(other._blocks, _blocks)&&(identical(other.documentSettings, documentSettings) || other.documentSettings == documentSettings)&&const DeepCollectionEquality().equals(other._extra, _extra));
}


@override
int get hashCode => Object.hash(runtimeType,body,header,footer,includes,product,task,const DeepCollectionEquality().hash(_blocks),documentSettings,const DeepCollectionEquality().hash(_extra));

@override
String toString() {
  return 'DesignTemplate(body: $body, header: $header, footer: $footer, includes: $includes, product: $product, task: $task, blocks: $blocks, documentSettings: $documentSettings, extra: $extra)';
}


}

/// @nodoc
abstract mixin class _$DesignTemplateCopyWith<$Res> implements $DesignTemplateCopyWith<$Res> {
  factory _$DesignTemplateCopyWith(_DesignTemplate value, $Res Function(_DesignTemplate) _then) = __$DesignTemplateCopyWithImpl;
@override @useResult
$Res call({
 String body, String header, String footer, String includes, String product, String task, List<DesignBlock> blocks, DocumentSettings? documentSettings, Map<String, dynamic> extra
});


@override $DocumentSettingsCopyWith<$Res>? get documentSettings;

}
/// @nodoc
class __$DesignTemplateCopyWithImpl<$Res>
    implements _$DesignTemplateCopyWith<$Res> {
  __$DesignTemplateCopyWithImpl(this._self, this._then);

  final _DesignTemplate _self;
  final $Res Function(_DesignTemplate) _then;

/// Create a copy of DesignTemplate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? body = null,Object? header = null,Object? footer = null,Object? includes = null,Object? product = null,Object? task = null,Object? blocks = null,Object? documentSettings = freezed,Object? extra = null,}) {
  return _then(_DesignTemplate(
body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,header: null == header ? _self.header : header // ignore: cast_nullable_to_non_nullable
as String,footer: null == footer ? _self.footer : footer // ignore: cast_nullable_to_non_nullable
as String,includes: null == includes ? _self.includes : includes // ignore: cast_nullable_to_non_nullable
as String,product: null == product ? _self.product : product // ignore: cast_nullable_to_non_nullable
as String,task: null == task ? _self.task : task // ignore: cast_nullable_to_non_nullable
as String,blocks: null == blocks ? _self._blocks : blocks // ignore: cast_nullable_to_non_nullable
as List<DesignBlock>,documentSettings: freezed == documentSettings ? _self.documentSettings : documentSettings // ignore: cast_nullable_to_non_nullable
as DocumentSettings?,extra: null == extra ? _self._extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

/// Create a copy of DesignTemplate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DocumentSettingsCopyWith<$Res>? get documentSettings {
    if (_self.documentSettings == null) {
    return null;
  }

  return $DocumentSettingsCopyWith<$Res>(_self.documentSettings!, (value) {
    return _then(_self.copyWith(documentSettings: value));
  });
}
}

/// @nodoc
mixin _$DesignBlock {

 String get id; String get type; GridPosition get gridPosition; Map<String, dynamic> get properties; bool get locked;/// Unknown fields, as on [DesignTemplate.extra] — e.g. a block's `region`.
 Map<String, dynamic> get extra;
/// Create a copy of DesignBlock
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DesignBlockCopyWith<DesignBlock> get copyWith => _$DesignBlockCopyWithImpl<DesignBlock>(this as DesignBlock, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DesignBlock&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.gridPosition, gridPosition) || other.gridPosition == gridPosition)&&const DeepCollectionEquality().equals(other.properties, properties)&&(identical(other.locked, locked) || other.locked == locked)&&const DeepCollectionEquality().equals(other.extra, extra));
}


@override
int get hashCode => Object.hash(runtimeType,id,type,gridPosition,const DeepCollectionEquality().hash(properties),locked,const DeepCollectionEquality().hash(extra));

@override
String toString() {
  return 'DesignBlock(id: $id, type: $type, gridPosition: $gridPosition, properties: $properties, locked: $locked, extra: $extra)';
}


}

/// @nodoc
abstract mixin class $DesignBlockCopyWith<$Res>  {
  factory $DesignBlockCopyWith(DesignBlock value, $Res Function(DesignBlock) _then) = _$DesignBlockCopyWithImpl;
@useResult
$Res call({
 String id, String type, GridPosition gridPosition, Map<String, dynamic> properties, bool locked, Map<String, dynamic> extra
});


$GridPositionCopyWith<$Res> get gridPosition;

}
/// @nodoc
class _$DesignBlockCopyWithImpl<$Res>
    implements $DesignBlockCopyWith<$Res> {
  _$DesignBlockCopyWithImpl(this._self, this._then);

  final DesignBlock _self;
  final $Res Function(DesignBlock) _then;

/// Create a copy of DesignBlock
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? gridPosition = null,Object? properties = null,Object? locked = null,Object? extra = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,gridPosition: null == gridPosition ? _self.gridPosition : gridPosition // ignore: cast_nullable_to_non_nullable
as GridPosition,properties: null == properties ? _self.properties : properties // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,locked: null == locked ? _self.locked : locked // ignore: cast_nullable_to_non_nullable
as bool,extra: null == extra ? _self.extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}
/// Create a copy of DesignBlock
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GridPositionCopyWith<$Res> get gridPosition {
  
  return $GridPositionCopyWith<$Res>(_self.gridPosition, (value) {
    return _then(_self.copyWith(gridPosition: value));
  });
}
}


/// Adds pattern-matching-related methods to [DesignBlock].
extension DesignBlockPatterns on DesignBlock {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DesignBlock value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DesignBlock() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DesignBlock value)  $default,){
final _that = this;
switch (_that) {
case _DesignBlock():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DesignBlock value)?  $default,){
final _that = this;
switch (_that) {
case _DesignBlock() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String type,  GridPosition gridPosition,  Map<String, dynamic> properties,  bool locked,  Map<String, dynamic> extra)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DesignBlock() when $default != null:
return $default(_that.id,_that.type,_that.gridPosition,_that.properties,_that.locked,_that.extra);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String type,  GridPosition gridPosition,  Map<String, dynamic> properties,  bool locked,  Map<String, dynamic> extra)  $default,) {final _that = this;
switch (_that) {
case _DesignBlock():
return $default(_that.id,_that.type,_that.gridPosition,_that.properties,_that.locked,_that.extra);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String type,  GridPosition gridPosition,  Map<String, dynamic> properties,  bool locked,  Map<String, dynamic> extra)?  $default,) {final _that = this;
switch (_that) {
case _DesignBlock() when $default != null:
return $default(_that.id,_that.type,_that.gridPosition,_that.properties,_that.locked,_that.extra);case _:
  return null;

}
}

}

/// @nodoc


class _DesignBlock implements DesignBlock {
  const _DesignBlock({required this.id, required this.type, required this.gridPosition, final  Map<String, dynamic> properties = const <String, dynamic>{}, this.locked = false, final  Map<String, dynamic> extra = const <String, dynamic>{}}): _properties = properties,_extra = extra;
  

@override final  String id;
@override final  String type;
@override final  GridPosition gridPosition;
 final  Map<String, dynamic> _properties;
@override@JsonKey() Map<String, dynamic> get properties {
  if (_properties is EqualUnmodifiableMapView) return _properties;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_properties);
}

@override@JsonKey() final  bool locked;
/// Unknown fields, as on [DesignTemplate.extra] — e.g. a block's `region`.
 final  Map<String, dynamic> _extra;
/// Unknown fields, as on [DesignTemplate.extra] — e.g. a block's `region`.
@override@JsonKey() Map<String, dynamic> get extra {
  if (_extra is EqualUnmodifiableMapView) return _extra;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_extra);
}


/// Create a copy of DesignBlock
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DesignBlockCopyWith<_DesignBlock> get copyWith => __$DesignBlockCopyWithImpl<_DesignBlock>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DesignBlock&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.gridPosition, gridPosition) || other.gridPosition == gridPosition)&&const DeepCollectionEquality().equals(other._properties, _properties)&&(identical(other.locked, locked) || other.locked == locked)&&const DeepCollectionEquality().equals(other._extra, _extra));
}


@override
int get hashCode => Object.hash(runtimeType,id,type,gridPosition,const DeepCollectionEquality().hash(_properties),locked,const DeepCollectionEquality().hash(_extra));

@override
String toString() {
  return 'DesignBlock(id: $id, type: $type, gridPosition: $gridPosition, properties: $properties, locked: $locked, extra: $extra)';
}


}

/// @nodoc
abstract mixin class _$DesignBlockCopyWith<$Res> implements $DesignBlockCopyWith<$Res> {
  factory _$DesignBlockCopyWith(_DesignBlock value, $Res Function(_DesignBlock) _then) = __$DesignBlockCopyWithImpl;
@override @useResult
$Res call({
 String id, String type, GridPosition gridPosition, Map<String, dynamic> properties, bool locked, Map<String, dynamic> extra
});


@override $GridPositionCopyWith<$Res> get gridPosition;

}
/// @nodoc
class __$DesignBlockCopyWithImpl<$Res>
    implements _$DesignBlockCopyWith<$Res> {
  __$DesignBlockCopyWithImpl(this._self, this._then);

  final _DesignBlock _self;
  final $Res Function(_DesignBlock) _then;

/// Create a copy of DesignBlock
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? gridPosition = null,Object? properties = null,Object? locked = null,Object? extra = null,}) {
  return _then(_DesignBlock(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,gridPosition: null == gridPosition ? _self.gridPosition : gridPosition // ignore: cast_nullable_to_non_nullable
as GridPosition,properties: null == properties ? _self._properties : properties // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,locked: null == locked ? _self.locked : locked // ignore: cast_nullable_to_non_nullable
as bool,extra: null == extra ? _self._extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

/// Create a copy of DesignBlock
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GridPositionCopyWith<$Res> get gridPosition {
  
  return $GridPositionCopyWith<$Res>(_self.gridPosition, (value) {
    return _then(_self.copyWith(gridPosition: value));
  });
}
}

/// @nodoc
mixin _$GridPosition {

 int get x; int get y; int get w; int get h;
/// Create a copy of GridPosition
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GridPositionCopyWith<GridPosition> get copyWith => _$GridPositionCopyWithImpl<GridPosition>(this as GridPosition, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GridPosition&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y)&&(identical(other.w, w) || other.w == w)&&(identical(other.h, h) || other.h == h));
}


@override
int get hashCode => Object.hash(runtimeType,x,y,w,h);

@override
String toString() {
  return 'GridPosition(x: $x, y: $y, w: $w, h: $h)';
}


}

/// @nodoc
abstract mixin class $GridPositionCopyWith<$Res>  {
  factory $GridPositionCopyWith(GridPosition value, $Res Function(GridPosition) _then) = _$GridPositionCopyWithImpl;
@useResult
$Res call({
 int x, int y, int w, int h
});




}
/// @nodoc
class _$GridPositionCopyWithImpl<$Res>
    implements $GridPositionCopyWith<$Res> {
  _$GridPositionCopyWithImpl(this._self, this._then);

  final GridPosition _self;
  final $Res Function(GridPosition) _then;

/// Create a copy of GridPosition
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? x = null,Object? y = null,Object? w = null,Object? h = null,}) {
  return _then(_self.copyWith(
x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as int,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as int,w: null == w ? _self.w : w // ignore: cast_nullable_to_non_nullable
as int,h: null == h ? _self.h : h // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [GridPosition].
extension GridPositionPatterns on GridPosition {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GridPosition value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GridPosition() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GridPosition value)  $default,){
final _that = this;
switch (_that) {
case _GridPosition():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GridPosition value)?  $default,){
final _that = this;
switch (_that) {
case _GridPosition() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int x,  int y,  int w,  int h)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GridPosition() when $default != null:
return $default(_that.x,_that.y,_that.w,_that.h);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int x,  int y,  int w,  int h)  $default,) {final _that = this;
switch (_that) {
case _GridPosition():
return $default(_that.x,_that.y,_that.w,_that.h);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int x,  int y,  int w,  int h)?  $default,) {final _that = this;
switch (_that) {
case _GridPosition() when $default != null:
return $default(_that.x,_that.y,_that.w,_that.h);case _:
  return null;

}
}

}

/// @nodoc


class _GridPosition implements GridPosition {
  const _GridPosition({required this.x, required this.y, required this.w, required this.h});
  

@override final  int x;
@override final  int y;
@override final  int w;
@override final  int h;

/// Create a copy of GridPosition
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GridPositionCopyWith<_GridPosition> get copyWith => __$GridPositionCopyWithImpl<_GridPosition>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GridPosition&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y)&&(identical(other.w, w) || other.w == w)&&(identical(other.h, h) || other.h == h));
}


@override
int get hashCode => Object.hash(runtimeType,x,y,w,h);

@override
String toString() {
  return 'GridPosition(x: $x, y: $y, w: $w, h: $h)';
}


}

/// @nodoc
abstract mixin class _$GridPositionCopyWith<$Res> implements $GridPositionCopyWith<$Res> {
  factory _$GridPositionCopyWith(_GridPosition value, $Res Function(_GridPosition) _then) = __$GridPositionCopyWithImpl;
@override @useResult
$Res call({
 int x, int y, int w, int h
});




}
/// @nodoc
class __$GridPositionCopyWithImpl<$Res>
    implements _$GridPositionCopyWith<$Res> {
  __$GridPositionCopyWithImpl(this._self, this._then);

  final _GridPosition _self;
  final $Res Function(_GridPosition) _then;

/// Create a copy of GridPosition
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? x = null,Object? y = null,Object? w = null,Object? h = null,}) {
  return _then(_GridPosition(
x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as int,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as int,w: null == w ? _self.w : w // ignore: cast_nullable_to_non_nullable
as int,h: null == h ? _self.h : h // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$DocumentSettings {

 String get pageLayout; String get pageSize; int get globalFontSize; String get primaryFont; String get secondaryFont; bool get showPaidStamp; bool get showShippingAddress; bool get embedDocuments; bool get hideEmptyColumns; bool get pageNumbering; int get pageMarginTop; int get pageMarginRight; int get pageMarginBottom; int get pageMarginLeft; int get pagePaddingTop; int get pagePaddingRight; int get pagePaddingBottom; int get pagePaddingLeft;/// Unknown fields, as on [DesignTemplate.extra] — e.g. `pagination`.
 Map<String, dynamic> get extra;
/// Create a copy of DocumentSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DocumentSettingsCopyWith<DocumentSettings> get copyWith => _$DocumentSettingsCopyWithImpl<DocumentSettings>(this as DocumentSettings, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DocumentSettings&&(identical(other.pageLayout, pageLayout) || other.pageLayout == pageLayout)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize)&&(identical(other.globalFontSize, globalFontSize) || other.globalFontSize == globalFontSize)&&(identical(other.primaryFont, primaryFont) || other.primaryFont == primaryFont)&&(identical(other.secondaryFont, secondaryFont) || other.secondaryFont == secondaryFont)&&(identical(other.showPaidStamp, showPaidStamp) || other.showPaidStamp == showPaidStamp)&&(identical(other.showShippingAddress, showShippingAddress) || other.showShippingAddress == showShippingAddress)&&(identical(other.embedDocuments, embedDocuments) || other.embedDocuments == embedDocuments)&&(identical(other.hideEmptyColumns, hideEmptyColumns) || other.hideEmptyColumns == hideEmptyColumns)&&(identical(other.pageNumbering, pageNumbering) || other.pageNumbering == pageNumbering)&&(identical(other.pageMarginTop, pageMarginTop) || other.pageMarginTop == pageMarginTop)&&(identical(other.pageMarginRight, pageMarginRight) || other.pageMarginRight == pageMarginRight)&&(identical(other.pageMarginBottom, pageMarginBottom) || other.pageMarginBottom == pageMarginBottom)&&(identical(other.pageMarginLeft, pageMarginLeft) || other.pageMarginLeft == pageMarginLeft)&&(identical(other.pagePaddingTop, pagePaddingTop) || other.pagePaddingTop == pagePaddingTop)&&(identical(other.pagePaddingRight, pagePaddingRight) || other.pagePaddingRight == pagePaddingRight)&&(identical(other.pagePaddingBottom, pagePaddingBottom) || other.pagePaddingBottom == pagePaddingBottom)&&(identical(other.pagePaddingLeft, pagePaddingLeft) || other.pagePaddingLeft == pagePaddingLeft)&&const DeepCollectionEquality().equals(other.extra, extra));
}


@override
int get hashCode => Object.hashAll([runtimeType,pageLayout,pageSize,globalFontSize,primaryFont,secondaryFont,showPaidStamp,showShippingAddress,embedDocuments,hideEmptyColumns,pageNumbering,pageMarginTop,pageMarginRight,pageMarginBottom,pageMarginLeft,pagePaddingTop,pagePaddingRight,pagePaddingBottom,pagePaddingLeft,const DeepCollectionEquality().hash(extra)]);

@override
String toString() {
  return 'DocumentSettings(pageLayout: $pageLayout, pageSize: $pageSize, globalFontSize: $globalFontSize, primaryFont: $primaryFont, secondaryFont: $secondaryFont, showPaidStamp: $showPaidStamp, showShippingAddress: $showShippingAddress, embedDocuments: $embedDocuments, hideEmptyColumns: $hideEmptyColumns, pageNumbering: $pageNumbering, pageMarginTop: $pageMarginTop, pageMarginRight: $pageMarginRight, pageMarginBottom: $pageMarginBottom, pageMarginLeft: $pageMarginLeft, pagePaddingTop: $pagePaddingTop, pagePaddingRight: $pagePaddingRight, pagePaddingBottom: $pagePaddingBottom, pagePaddingLeft: $pagePaddingLeft, extra: $extra)';
}


}

/// @nodoc
abstract mixin class $DocumentSettingsCopyWith<$Res>  {
  factory $DocumentSettingsCopyWith(DocumentSettings value, $Res Function(DocumentSettings) _then) = _$DocumentSettingsCopyWithImpl;
@useResult
$Res call({
 String pageLayout, String pageSize, int globalFontSize, String primaryFont, String secondaryFont, bool showPaidStamp, bool showShippingAddress, bool embedDocuments, bool hideEmptyColumns, bool pageNumbering, int pageMarginTop, int pageMarginRight, int pageMarginBottom, int pageMarginLeft, int pagePaddingTop, int pagePaddingRight, int pagePaddingBottom, int pagePaddingLeft, Map<String, dynamic> extra
});




}
/// @nodoc
class _$DocumentSettingsCopyWithImpl<$Res>
    implements $DocumentSettingsCopyWith<$Res> {
  _$DocumentSettingsCopyWithImpl(this._self, this._then);

  final DocumentSettings _self;
  final $Res Function(DocumentSettings) _then;

/// Create a copy of DocumentSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pageLayout = null,Object? pageSize = null,Object? globalFontSize = null,Object? primaryFont = null,Object? secondaryFont = null,Object? showPaidStamp = null,Object? showShippingAddress = null,Object? embedDocuments = null,Object? hideEmptyColumns = null,Object? pageNumbering = null,Object? pageMarginTop = null,Object? pageMarginRight = null,Object? pageMarginBottom = null,Object? pageMarginLeft = null,Object? pagePaddingTop = null,Object? pagePaddingRight = null,Object? pagePaddingBottom = null,Object? pagePaddingLeft = null,Object? extra = null,}) {
  return _then(_self.copyWith(
pageLayout: null == pageLayout ? _self.pageLayout : pageLayout // ignore: cast_nullable_to_non_nullable
as String,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as String,globalFontSize: null == globalFontSize ? _self.globalFontSize : globalFontSize // ignore: cast_nullable_to_non_nullable
as int,primaryFont: null == primaryFont ? _self.primaryFont : primaryFont // ignore: cast_nullable_to_non_nullable
as String,secondaryFont: null == secondaryFont ? _self.secondaryFont : secondaryFont // ignore: cast_nullable_to_non_nullable
as String,showPaidStamp: null == showPaidStamp ? _self.showPaidStamp : showPaidStamp // ignore: cast_nullable_to_non_nullable
as bool,showShippingAddress: null == showShippingAddress ? _self.showShippingAddress : showShippingAddress // ignore: cast_nullable_to_non_nullable
as bool,embedDocuments: null == embedDocuments ? _self.embedDocuments : embedDocuments // ignore: cast_nullable_to_non_nullable
as bool,hideEmptyColumns: null == hideEmptyColumns ? _self.hideEmptyColumns : hideEmptyColumns // ignore: cast_nullable_to_non_nullable
as bool,pageNumbering: null == pageNumbering ? _self.pageNumbering : pageNumbering // ignore: cast_nullable_to_non_nullable
as bool,pageMarginTop: null == pageMarginTop ? _self.pageMarginTop : pageMarginTop // ignore: cast_nullable_to_non_nullable
as int,pageMarginRight: null == pageMarginRight ? _self.pageMarginRight : pageMarginRight // ignore: cast_nullable_to_non_nullable
as int,pageMarginBottom: null == pageMarginBottom ? _self.pageMarginBottom : pageMarginBottom // ignore: cast_nullable_to_non_nullable
as int,pageMarginLeft: null == pageMarginLeft ? _self.pageMarginLeft : pageMarginLeft // ignore: cast_nullable_to_non_nullable
as int,pagePaddingTop: null == pagePaddingTop ? _self.pagePaddingTop : pagePaddingTop // ignore: cast_nullable_to_non_nullable
as int,pagePaddingRight: null == pagePaddingRight ? _self.pagePaddingRight : pagePaddingRight // ignore: cast_nullable_to_non_nullable
as int,pagePaddingBottom: null == pagePaddingBottom ? _self.pagePaddingBottom : pagePaddingBottom // ignore: cast_nullable_to_non_nullable
as int,pagePaddingLeft: null == pagePaddingLeft ? _self.pagePaddingLeft : pagePaddingLeft // ignore: cast_nullable_to_non_nullable
as int,extra: null == extra ? _self.extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

}


/// Adds pattern-matching-related methods to [DocumentSettings].
extension DocumentSettingsPatterns on DocumentSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DocumentSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DocumentSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DocumentSettings value)  $default,){
final _that = this;
switch (_that) {
case _DocumentSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DocumentSettings value)?  $default,){
final _that = this;
switch (_that) {
case _DocumentSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String pageLayout,  String pageSize,  int globalFontSize,  String primaryFont,  String secondaryFont,  bool showPaidStamp,  bool showShippingAddress,  bool embedDocuments,  bool hideEmptyColumns,  bool pageNumbering,  int pageMarginTop,  int pageMarginRight,  int pageMarginBottom,  int pageMarginLeft,  int pagePaddingTop,  int pagePaddingRight,  int pagePaddingBottom,  int pagePaddingLeft,  Map<String, dynamic> extra)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DocumentSettings() when $default != null:
return $default(_that.pageLayout,_that.pageSize,_that.globalFontSize,_that.primaryFont,_that.secondaryFont,_that.showPaidStamp,_that.showShippingAddress,_that.embedDocuments,_that.hideEmptyColumns,_that.pageNumbering,_that.pageMarginTop,_that.pageMarginRight,_that.pageMarginBottom,_that.pageMarginLeft,_that.pagePaddingTop,_that.pagePaddingRight,_that.pagePaddingBottom,_that.pagePaddingLeft,_that.extra);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String pageLayout,  String pageSize,  int globalFontSize,  String primaryFont,  String secondaryFont,  bool showPaidStamp,  bool showShippingAddress,  bool embedDocuments,  bool hideEmptyColumns,  bool pageNumbering,  int pageMarginTop,  int pageMarginRight,  int pageMarginBottom,  int pageMarginLeft,  int pagePaddingTop,  int pagePaddingRight,  int pagePaddingBottom,  int pagePaddingLeft,  Map<String, dynamic> extra)  $default,) {final _that = this;
switch (_that) {
case _DocumentSettings():
return $default(_that.pageLayout,_that.pageSize,_that.globalFontSize,_that.primaryFont,_that.secondaryFont,_that.showPaidStamp,_that.showShippingAddress,_that.embedDocuments,_that.hideEmptyColumns,_that.pageNumbering,_that.pageMarginTop,_that.pageMarginRight,_that.pageMarginBottom,_that.pageMarginLeft,_that.pagePaddingTop,_that.pagePaddingRight,_that.pagePaddingBottom,_that.pagePaddingLeft,_that.extra);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String pageLayout,  String pageSize,  int globalFontSize,  String primaryFont,  String secondaryFont,  bool showPaidStamp,  bool showShippingAddress,  bool embedDocuments,  bool hideEmptyColumns,  bool pageNumbering,  int pageMarginTop,  int pageMarginRight,  int pageMarginBottom,  int pageMarginLeft,  int pagePaddingTop,  int pagePaddingRight,  int pagePaddingBottom,  int pagePaddingLeft,  Map<String, dynamic> extra)?  $default,) {final _that = this;
switch (_that) {
case _DocumentSettings() when $default != null:
return $default(_that.pageLayout,_that.pageSize,_that.globalFontSize,_that.primaryFont,_that.secondaryFont,_that.showPaidStamp,_that.showShippingAddress,_that.embedDocuments,_that.hideEmptyColumns,_that.pageNumbering,_that.pageMarginTop,_that.pageMarginRight,_that.pageMarginBottom,_that.pageMarginLeft,_that.pagePaddingTop,_that.pagePaddingRight,_that.pagePaddingBottom,_that.pagePaddingLeft,_that.extra);case _:
  return null;

}
}

}

/// @nodoc


class _DocumentSettings implements DocumentSettings {
  const _DocumentSettings({this.pageLayout = 'portrait', this.pageSize = 'A4', this.globalFontSize = 16, this.primaryFont = 'Roboto', this.secondaryFont = 'Roboto', this.showPaidStamp = false, this.showShippingAddress = false, this.embedDocuments = false, this.hideEmptyColumns = false, this.pageNumbering = false, this.pageMarginTop = 0, this.pageMarginRight = 0, this.pageMarginBottom = 0, this.pageMarginLeft = 0, this.pagePaddingTop = 30, this.pagePaddingRight = 30, this.pagePaddingBottom = 30, this.pagePaddingLeft = 30, final  Map<String, dynamic> extra = const <String, dynamic>{}}): _extra = extra;
  

@override@JsonKey() final  String pageLayout;
@override@JsonKey() final  String pageSize;
@override@JsonKey() final  int globalFontSize;
@override@JsonKey() final  String primaryFont;
@override@JsonKey() final  String secondaryFont;
@override@JsonKey() final  bool showPaidStamp;
@override@JsonKey() final  bool showShippingAddress;
@override@JsonKey() final  bool embedDocuments;
@override@JsonKey() final  bool hideEmptyColumns;
@override@JsonKey() final  bool pageNumbering;
@override@JsonKey() final  int pageMarginTop;
@override@JsonKey() final  int pageMarginRight;
@override@JsonKey() final  int pageMarginBottom;
@override@JsonKey() final  int pageMarginLeft;
@override@JsonKey() final  int pagePaddingTop;
@override@JsonKey() final  int pagePaddingRight;
@override@JsonKey() final  int pagePaddingBottom;
@override@JsonKey() final  int pagePaddingLeft;
/// Unknown fields, as on [DesignTemplate.extra] — e.g. `pagination`.
 final  Map<String, dynamic> _extra;
/// Unknown fields, as on [DesignTemplate.extra] — e.g. `pagination`.
@override@JsonKey() Map<String, dynamic> get extra {
  if (_extra is EqualUnmodifiableMapView) return _extra;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_extra);
}


/// Create a copy of DocumentSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DocumentSettingsCopyWith<_DocumentSettings> get copyWith => __$DocumentSettingsCopyWithImpl<_DocumentSettings>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DocumentSettings&&(identical(other.pageLayout, pageLayout) || other.pageLayout == pageLayout)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize)&&(identical(other.globalFontSize, globalFontSize) || other.globalFontSize == globalFontSize)&&(identical(other.primaryFont, primaryFont) || other.primaryFont == primaryFont)&&(identical(other.secondaryFont, secondaryFont) || other.secondaryFont == secondaryFont)&&(identical(other.showPaidStamp, showPaidStamp) || other.showPaidStamp == showPaidStamp)&&(identical(other.showShippingAddress, showShippingAddress) || other.showShippingAddress == showShippingAddress)&&(identical(other.embedDocuments, embedDocuments) || other.embedDocuments == embedDocuments)&&(identical(other.hideEmptyColumns, hideEmptyColumns) || other.hideEmptyColumns == hideEmptyColumns)&&(identical(other.pageNumbering, pageNumbering) || other.pageNumbering == pageNumbering)&&(identical(other.pageMarginTop, pageMarginTop) || other.pageMarginTop == pageMarginTop)&&(identical(other.pageMarginRight, pageMarginRight) || other.pageMarginRight == pageMarginRight)&&(identical(other.pageMarginBottom, pageMarginBottom) || other.pageMarginBottom == pageMarginBottom)&&(identical(other.pageMarginLeft, pageMarginLeft) || other.pageMarginLeft == pageMarginLeft)&&(identical(other.pagePaddingTop, pagePaddingTop) || other.pagePaddingTop == pagePaddingTop)&&(identical(other.pagePaddingRight, pagePaddingRight) || other.pagePaddingRight == pagePaddingRight)&&(identical(other.pagePaddingBottom, pagePaddingBottom) || other.pagePaddingBottom == pagePaddingBottom)&&(identical(other.pagePaddingLeft, pagePaddingLeft) || other.pagePaddingLeft == pagePaddingLeft)&&const DeepCollectionEquality().equals(other._extra, _extra));
}


@override
int get hashCode => Object.hashAll([runtimeType,pageLayout,pageSize,globalFontSize,primaryFont,secondaryFont,showPaidStamp,showShippingAddress,embedDocuments,hideEmptyColumns,pageNumbering,pageMarginTop,pageMarginRight,pageMarginBottom,pageMarginLeft,pagePaddingTop,pagePaddingRight,pagePaddingBottom,pagePaddingLeft,const DeepCollectionEquality().hash(_extra)]);

@override
String toString() {
  return 'DocumentSettings(pageLayout: $pageLayout, pageSize: $pageSize, globalFontSize: $globalFontSize, primaryFont: $primaryFont, secondaryFont: $secondaryFont, showPaidStamp: $showPaidStamp, showShippingAddress: $showShippingAddress, embedDocuments: $embedDocuments, hideEmptyColumns: $hideEmptyColumns, pageNumbering: $pageNumbering, pageMarginTop: $pageMarginTop, pageMarginRight: $pageMarginRight, pageMarginBottom: $pageMarginBottom, pageMarginLeft: $pageMarginLeft, pagePaddingTop: $pagePaddingTop, pagePaddingRight: $pagePaddingRight, pagePaddingBottom: $pagePaddingBottom, pagePaddingLeft: $pagePaddingLeft, extra: $extra)';
}


}

/// @nodoc
abstract mixin class _$DocumentSettingsCopyWith<$Res> implements $DocumentSettingsCopyWith<$Res> {
  factory _$DocumentSettingsCopyWith(_DocumentSettings value, $Res Function(_DocumentSettings) _then) = __$DocumentSettingsCopyWithImpl;
@override @useResult
$Res call({
 String pageLayout, String pageSize, int globalFontSize, String primaryFont, String secondaryFont, bool showPaidStamp, bool showShippingAddress, bool embedDocuments, bool hideEmptyColumns, bool pageNumbering, int pageMarginTop, int pageMarginRight, int pageMarginBottom, int pageMarginLeft, int pagePaddingTop, int pagePaddingRight, int pagePaddingBottom, int pagePaddingLeft, Map<String, dynamic> extra
});




}
/// @nodoc
class __$DocumentSettingsCopyWithImpl<$Res>
    implements _$DocumentSettingsCopyWith<$Res> {
  __$DocumentSettingsCopyWithImpl(this._self, this._then);

  final _DocumentSettings _self;
  final $Res Function(_DocumentSettings) _then;

/// Create a copy of DocumentSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pageLayout = null,Object? pageSize = null,Object? globalFontSize = null,Object? primaryFont = null,Object? secondaryFont = null,Object? showPaidStamp = null,Object? showShippingAddress = null,Object? embedDocuments = null,Object? hideEmptyColumns = null,Object? pageNumbering = null,Object? pageMarginTop = null,Object? pageMarginRight = null,Object? pageMarginBottom = null,Object? pageMarginLeft = null,Object? pagePaddingTop = null,Object? pagePaddingRight = null,Object? pagePaddingBottom = null,Object? pagePaddingLeft = null,Object? extra = null,}) {
  return _then(_DocumentSettings(
pageLayout: null == pageLayout ? _self.pageLayout : pageLayout // ignore: cast_nullable_to_non_nullable
as String,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as String,globalFontSize: null == globalFontSize ? _self.globalFontSize : globalFontSize // ignore: cast_nullable_to_non_nullable
as int,primaryFont: null == primaryFont ? _self.primaryFont : primaryFont // ignore: cast_nullable_to_non_nullable
as String,secondaryFont: null == secondaryFont ? _self.secondaryFont : secondaryFont // ignore: cast_nullable_to_non_nullable
as String,showPaidStamp: null == showPaidStamp ? _self.showPaidStamp : showPaidStamp // ignore: cast_nullable_to_non_nullable
as bool,showShippingAddress: null == showShippingAddress ? _self.showShippingAddress : showShippingAddress // ignore: cast_nullable_to_non_nullable
as bool,embedDocuments: null == embedDocuments ? _self.embedDocuments : embedDocuments // ignore: cast_nullable_to_non_nullable
as bool,hideEmptyColumns: null == hideEmptyColumns ? _self.hideEmptyColumns : hideEmptyColumns // ignore: cast_nullable_to_non_nullable
as bool,pageNumbering: null == pageNumbering ? _self.pageNumbering : pageNumbering // ignore: cast_nullable_to_non_nullable
as bool,pageMarginTop: null == pageMarginTop ? _self.pageMarginTop : pageMarginTop // ignore: cast_nullable_to_non_nullable
as int,pageMarginRight: null == pageMarginRight ? _self.pageMarginRight : pageMarginRight // ignore: cast_nullable_to_non_nullable
as int,pageMarginBottom: null == pageMarginBottom ? _self.pageMarginBottom : pageMarginBottom // ignore: cast_nullable_to_non_nullable
as int,pageMarginLeft: null == pageMarginLeft ? _self.pageMarginLeft : pageMarginLeft // ignore: cast_nullable_to_non_nullable
as int,pagePaddingTop: null == pagePaddingTop ? _self.pagePaddingTop : pagePaddingTop // ignore: cast_nullable_to_non_nullable
as int,pagePaddingRight: null == pagePaddingRight ? _self.pagePaddingRight : pagePaddingRight // ignore: cast_nullable_to_non_nullable
as int,pagePaddingBottom: null == pagePaddingBottom ? _self.pagePaddingBottom : pagePaddingBottom // ignore: cast_nullable_to_non_nullable
as int,pagePaddingLeft: null == pagePaddingLeft ? _self.pagePaddingLeft : pagePaddingLeft // ignore: cast_nullable_to_non_nullable
as int,extra: null == extra ? _self._extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}

// dart format on
