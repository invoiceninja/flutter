// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'design_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DesignTemplateApi {

 String get body; String get header; String get footer; String get includes; String get product; String get task; List<DesignBlockApi> get blocks;@JsonKey(includeIfNull: false) DocumentSettingsApi? get documentSettings;
/// Create a copy of DesignTemplateApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DesignTemplateApiCopyWith<DesignTemplateApi> get copyWith => _$DesignTemplateApiCopyWithImpl<DesignTemplateApi>(this as DesignTemplateApi, _$identity);

  /// Serializes this DesignTemplateApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DesignTemplateApi&&(identical(other.body, body) || other.body == body)&&(identical(other.header, header) || other.header == header)&&(identical(other.footer, footer) || other.footer == footer)&&(identical(other.includes, includes) || other.includes == includes)&&(identical(other.product, product) || other.product == product)&&(identical(other.task, task) || other.task == task)&&const DeepCollectionEquality().equals(other.blocks, blocks)&&(identical(other.documentSettings, documentSettings) || other.documentSettings == documentSettings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,body,header,footer,includes,product,task,const DeepCollectionEquality().hash(blocks),documentSettings);

@override
String toString() {
  return 'DesignTemplateApi(body: $body, header: $header, footer: $footer, includes: $includes, product: $product, task: $task, blocks: $blocks, documentSettings: $documentSettings)';
}


}

/// @nodoc
abstract mixin class $DesignTemplateApiCopyWith<$Res>  {
  factory $DesignTemplateApiCopyWith(DesignTemplateApi value, $Res Function(DesignTemplateApi) _then) = _$DesignTemplateApiCopyWithImpl;
@useResult
$Res call({
 String body, String header, String footer, String includes, String product, String task, List<DesignBlockApi> blocks,@JsonKey(includeIfNull: false) DocumentSettingsApi? documentSettings
});


$DocumentSettingsApiCopyWith<$Res>? get documentSettings;

}
/// @nodoc
class _$DesignTemplateApiCopyWithImpl<$Res>
    implements $DesignTemplateApiCopyWith<$Res> {
  _$DesignTemplateApiCopyWithImpl(this._self, this._then);

  final DesignTemplateApi _self;
  final $Res Function(DesignTemplateApi) _then;

/// Create a copy of DesignTemplateApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? body = null,Object? header = null,Object? footer = null,Object? includes = null,Object? product = null,Object? task = null,Object? blocks = null,Object? documentSettings = freezed,}) {
  return _then(_self.copyWith(
body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,header: null == header ? _self.header : header // ignore: cast_nullable_to_non_nullable
as String,footer: null == footer ? _self.footer : footer // ignore: cast_nullable_to_non_nullable
as String,includes: null == includes ? _self.includes : includes // ignore: cast_nullable_to_non_nullable
as String,product: null == product ? _self.product : product // ignore: cast_nullable_to_non_nullable
as String,task: null == task ? _self.task : task // ignore: cast_nullable_to_non_nullable
as String,blocks: null == blocks ? _self.blocks : blocks // ignore: cast_nullable_to_non_nullable
as List<DesignBlockApi>,documentSettings: freezed == documentSettings ? _self.documentSettings : documentSettings // ignore: cast_nullable_to_non_nullable
as DocumentSettingsApi?,
  ));
}
/// Create a copy of DesignTemplateApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DocumentSettingsApiCopyWith<$Res>? get documentSettings {
    if (_self.documentSettings == null) {
    return null;
  }

  return $DocumentSettingsApiCopyWith<$Res>(_self.documentSettings!, (value) {
    return _then(_self.copyWith(documentSettings: value));
  });
}
}


/// Adds pattern-matching-related methods to [DesignTemplateApi].
extension DesignTemplateApiPatterns on DesignTemplateApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DesignTemplateApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DesignTemplateApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DesignTemplateApi value)  $default,){
final _that = this;
switch (_that) {
case _DesignTemplateApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DesignTemplateApi value)?  $default,){
final _that = this;
switch (_that) {
case _DesignTemplateApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String body,  String header,  String footer,  String includes,  String product,  String task,  List<DesignBlockApi> blocks, @JsonKey(includeIfNull: false)  DocumentSettingsApi? documentSettings)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DesignTemplateApi() when $default != null:
return $default(_that.body,_that.header,_that.footer,_that.includes,_that.product,_that.task,_that.blocks,_that.documentSettings);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String body,  String header,  String footer,  String includes,  String product,  String task,  List<DesignBlockApi> blocks, @JsonKey(includeIfNull: false)  DocumentSettingsApi? documentSettings)  $default,) {final _that = this;
switch (_that) {
case _DesignTemplateApi():
return $default(_that.body,_that.header,_that.footer,_that.includes,_that.product,_that.task,_that.blocks,_that.documentSettings);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String body,  String header,  String footer,  String includes,  String product,  String task,  List<DesignBlockApi> blocks, @JsonKey(includeIfNull: false)  DocumentSettingsApi? documentSettings)?  $default,) {final _that = this;
switch (_that) {
case _DesignTemplateApi() when $default != null:
return $default(_that.body,_that.header,_that.footer,_that.includes,_that.product,_that.task,_that.blocks,_that.documentSettings);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DesignTemplateApi implements DesignTemplateApi {
  const _DesignTemplateApi({this.body = '', this.header = '', this.footer = '', this.includes = '', this.product = '', this.task = '', final  List<DesignBlockApi> blocks = const <DesignBlockApi>[], @JsonKey(includeIfNull: false) this.documentSettings}): _blocks = blocks;
  factory _DesignTemplateApi.fromJson(Map<String, dynamic> json) => _$DesignTemplateApiFromJson(json);

@override@JsonKey() final  String body;
@override@JsonKey() final  String header;
@override@JsonKey() final  String footer;
@override@JsonKey() final  String includes;
@override@JsonKey() final  String product;
@override@JsonKey() final  String task;
 final  List<DesignBlockApi> _blocks;
@override@JsonKey() List<DesignBlockApi> get blocks {
  if (_blocks is EqualUnmodifiableListView) return _blocks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_blocks);
}

@override@JsonKey(includeIfNull: false) final  DocumentSettingsApi? documentSettings;

/// Create a copy of DesignTemplateApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DesignTemplateApiCopyWith<_DesignTemplateApi> get copyWith => __$DesignTemplateApiCopyWithImpl<_DesignTemplateApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DesignTemplateApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DesignTemplateApi&&(identical(other.body, body) || other.body == body)&&(identical(other.header, header) || other.header == header)&&(identical(other.footer, footer) || other.footer == footer)&&(identical(other.includes, includes) || other.includes == includes)&&(identical(other.product, product) || other.product == product)&&(identical(other.task, task) || other.task == task)&&const DeepCollectionEquality().equals(other._blocks, _blocks)&&(identical(other.documentSettings, documentSettings) || other.documentSettings == documentSettings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,body,header,footer,includes,product,task,const DeepCollectionEquality().hash(_blocks),documentSettings);

@override
String toString() {
  return 'DesignTemplateApi(body: $body, header: $header, footer: $footer, includes: $includes, product: $product, task: $task, blocks: $blocks, documentSettings: $documentSettings)';
}


}

/// @nodoc
abstract mixin class _$DesignTemplateApiCopyWith<$Res> implements $DesignTemplateApiCopyWith<$Res> {
  factory _$DesignTemplateApiCopyWith(_DesignTemplateApi value, $Res Function(_DesignTemplateApi) _then) = __$DesignTemplateApiCopyWithImpl;
@override @useResult
$Res call({
 String body, String header, String footer, String includes, String product, String task, List<DesignBlockApi> blocks,@JsonKey(includeIfNull: false) DocumentSettingsApi? documentSettings
});


@override $DocumentSettingsApiCopyWith<$Res>? get documentSettings;

}
/// @nodoc
class __$DesignTemplateApiCopyWithImpl<$Res>
    implements _$DesignTemplateApiCopyWith<$Res> {
  __$DesignTemplateApiCopyWithImpl(this._self, this._then);

  final _DesignTemplateApi _self;
  final $Res Function(_DesignTemplateApi) _then;

/// Create a copy of DesignTemplateApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? body = null,Object? header = null,Object? footer = null,Object? includes = null,Object? product = null,Object? task = null,Object? blocks = null,Object? documentSettings = freezed,}) {
  return _then(_DesignTemplateApi(
body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,header: null == header ? _self.header : header // ignore: cast_nullable_to_non_nullable
as String,footer: null == footer ? _self.footer : footer // ignore: cast_nullable_to_non_nullable
as String,includes: null == includes ? _self.includes : includes // ignore: cast_nullable_to_non_nullable
as String,product: null == product ? _self.product : product // ignore: cast_nullable_to_non_nullable
as String,task: null == task ? _self.task : task // ignore: cast_nullable_to_non_nullable
as String,blocks: null == blocks ? _self._blocks : blocks // ignore: cast_nullable_to_non_nullable
as List<DesignBlockApi>,documentSettings: freezed == documentSettings ? _self.documentSettings : documentSettings // ignore: cast_nullable_to_non_nullable
as DocumentSettingsApi?,
  ));
}

/// Create a copy of DesignTemplateApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DocumentSettingsApiCopyWith<$Res>? get documentSettings {
    if (_self.documentSettings == null) {
    return null;
  }

  return $DocumentSettingsApiCopyWith<$Res>(_self.documentSettings!, (value) {
    return _then(_self.copyWith(documentSettings: value));
  });
}
}


/// @nodoc
mixin _$DesignBlockApi {

 String get id; String get type; GridPositionApi get gridPosition;@JsonKey(includeIfNull: false) Map<String, dynamic>? get properties;@JsonKey(includeIfNull: false) bool? get locked;@JsonKey(includeIfNull: false) String? get rowAlign;@JsonKey(includeIfNull: false) String? get rowWidth;@JsonKey(includeIfNull: false) int? get colStart;@JsonKey(includeIfNull: false) int? get colSpan;
/// Create a copy of DesignBlockApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DesignBlockApiCopyWith<DesignBlockApi> get copyWith => _$DesignBlockApiCopyWithImpl<DesignBlockApi>(this as DesignBlockApi, _$identity);

  /// Serializes this DesignBlockApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DesignBlockApi&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.gridPosition, gridPosition) || other.gridPosition == gridPosition)&&const DeepCollectionEquality().equals(other.properties, properties)&&(identical(other.locked, locked) || other.locked == locked)&&(identical(other.rowAlign, rowAlign) || other.rowAlign == rowAlign)&&(identical(other.rowWidth, rowWidth) || other.rowWidth == rowWidth)&&(identical(other.colStart, colStart) || other.colStart == colStart)&&(identical(other.colSpan, colSpan) || other.colSpan == colSpan));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,type,gridPosition,const DeepCollectionEquality().hash(properties),locked,rowAlign,rowWidth,colStart,colSpan);

@override
String toString() {
  return 'DesignBlockApi(id: $id, type: $type, gridPosition: $gridPosition, properties: $properties, locked: $locked, rowAlign: $rowAlign, rowWidth: $rowWidth, colStart: $colStart, colSpan: $colSpan)';
}


}

/// @nodoc
abstract mixin class $DesignBlockApiCopyWith<$Res>  {
  factory $DesignBlockApiCopyWith(DesignBlockApi value, $Res Function(DesignBlockApi) _then) = _$DesignBlockApiCopyWithImpl;
@useResult
$Res call({
 String id, String type, GridPositionApi gridPosition,@JsonKey(includeIfNull: false) Map<String, dynamic>? properties,@JsonKey(includeIfNull: false) bool? locked,@JsonKey(includeIfNull: false) String? rowAlign,@JsonKey(includeIfNull: false) String? rowWidth,@JsonKey(includeIfNull: false) int? colStart,@JsonKey(includeIfNull: false) int? colSpan
});


$GridPositionApiCopyWith<$Res> get gridPosition;

}
/// @nodoc
class _$DesignBlockApiCopyWithImpl<$Res>
    implements $DesignBlockApiCopyWith<$Res> {
  _$DesignBlockApiCopyWithImpl(this._self, this._then);

  final DesignBlockApi _self;
  final $Res Function(DesignBlockApi) _then;

/// Create a copy of DesignBlockApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? gridPosition = null,Object? properties = freezed,Object? locked = freezed,Object? rowAlign = freezed,Object? rowWidth = freezed,Object? colStart = freezed,Object? colSpan = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,gridPosition: null == gridPosition ? _self.gridPosition : gridPosition // ignore: cast_nullable_to_non_nullable
as GridPositionApi,properties: freezed == properties ? _self.properties : properties // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,locked: freezed == locked ? _self.locked : locked // ignore: cast_nullable_to_non_nullable
as bool?,rowAlign: freezed == rowAlign ? _self.rowAlign : rowAlign // ignore: cast_nullable_to_non_nullable
as String?,rowWidth: freezed == rowWidth ? _self.rowWidth : rowWidth // ignore: cast_nullable_to_non_nullable
as String?,colStart: freezed == colStart ? _self.colStart : colStart // ignore: cast_nullable_to_non_nullable
as int?,colSpan: freezed == colSpan ? _self.colSpan : colSpan // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of DesignBlockApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GridPositionApiCopyWith<$Res> get gridPosition {
  
  return $GridPositionApiCopyWith<$Res>(_self.gridPosition, (value) {
    return _then(_self.copyWith(gridPosition: value));
  });
}
}


/// Adds pattern-matching-related methods to [DesignBlockApi].
extension DesignBlockApiPatterns on DesignBlockApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DesignBlockApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DesignBlockApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DesignBlockApi value)  $default,){
final _that = this;
switch (_that) {
case _DesignBlockApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DesignBlockApi value)?  $default,){
final _that = this;
switch (_that) {
case _DesignBlockApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String type,  GridPositionApi gridPosition, @JsonKey(includeIfNull: false)  Map<String, dynamic>? properties, @JsonKey(includeIfNull: false)  bool? locked, @JsonKey(includeIfNull: false)  String? rowAlign, @JsonKey(includeIfNull: false)  String? rowWidth, @JsonKey(includeIfNull: false)  int? colStart, @JsonKey(includeIfNull: false)  int? colSpan)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DesignBlockApi() when $default != null:
return $default(_that.id,_that.type,_that.gridPosition,_that.properties,_that.locked,_that.rowAlign,_that.rowWidth,_that.colStart,_that.colSpan);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String type,  GridPositionApi gridPosition, @JsonKey(includeIfNull: false)  Map<String, dynamic>? properties, @JsonKey(includeIfNull: false)  bool? locked, @JsonKey(includeIfNull: false)  String? rowAlign, @JsonKey(includeIfNull: false)  String? rowWidth, @JsonKey(includeIfNull: false)  int? colStart, @JsonKey(includeIfNull: false)  int? colSpan)  $default,) {final _that = this;
switch (_that) {
case _DesignBlockApi():
return $default(_that.id,_that.type,_that.gridPosition,_that.properties,_that.locked,_that.rowAlign,_that.rowWidth,_that.colStart,_that.colSpan);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String type,  GridPositionApi gridPosition, @JsonKey(includeIfNull: false)  Map<String, dynamic>? properties, @JsonKey(includeIfNull: false)  bool? locked, @JsonKey(includeIfNull: false)  String? rowAlign, @JsonKey(includeIfNull: false)  String? rowWidth, @JsonKey(includeIfNull: false)  int? colStart, @JsonKey(includeIfNull: false)  int? colSpan)?  $default,) {final _that = this;
switch (_that) {
case _DesignBlockApi() when $default != null:
return $default(_that.id,_that.type,_that.gridPosition,_that.properties,_that.locked,_that.rowAlign,_that.rowWidth,_that.colStart,_that.colSpan);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DesignBlockApi implements DesignBlockApi {
  const _DesignBlockApi({this.id = '', this.type = '', this.gridPosition = const GridPositionApi(), @JsonKey(includeIfNull: false) final  Map<String, dynamic>? properties, @JsonKey(includeIfNull: false) this.locked, @JsonKey(includeIfNull: false) this.rowAlign, @JsonKey(includeIfNull: false) this.rowWidth, @JsonKey(includeIfNull: false) this.colStart, @JsonKey(includeIfNull: false) this.colSpan}): _properties = properties;
  factory _DesignBlockApi.fromJson(Map<String, dynamic> json) => _$DesignBlockApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey() final  String type;
@override@JsonKey() final  GridPositionApi gridPosition;
 final  Map<String, dynamic>? _properties;
@override@JsonKey(includeIfNull: false) Map<String, dynamic>? get properties {
  final value = _properties;
  if (value == null) return null;
  if (_properties is EqualUnmodifiableMapView) return _properties;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override@JsonKey(includeIfNull: false) final  bool? locked;
@override@JsonKey(includeIfNull: false) final  String? rowAlign;
@override@JsonKey(includeIfNull: false) final  String? rowWidth;
@override@JsonKey(includeIfNull: false) final  int? colStart;
@override@JsonKey(includeIfNull: false) final  int? colSpan;

/// Create a copy of DesignBlockApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DesignBlockApiCopyWith<_DesignBlockApi> get copyWith => __$DesignBlockApiCopyWithImpl<_DesignBlockApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DesignBlockApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DesignBlockApi&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.gridPosition, gridPosition) || other.gridPosition == gridPosition)&&const DeepCollectionEquality().equals(other._properties, _properties)&&(identical(other.locked, locked) || other.locked == locked)&&(identical(other.rowAlign, rowAlign) || other.rowAlign == rowAlign)&&(identical(other.rowWidth, rowWidth) || other.rowWidth == rowWidth)&&(identical(other.colStart, colStart) || other.colStart == colStart)&&(identical(other.colSpan, colSpan) || other.colSpan == colSpan));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,type,gridPosition,const DeepCollectionEquality().hash(_properties),locked,rowAlign,rowWidth,colStart,colSpan);

@override
String toString() {
  return 'DesignBlockApi(id: $id, type: $type, gridPosition: $gridPosition, properties: $properties, locked: $locked, rowAlign: $rowAlign, rowWidth: $rowWidth, colStart: $colStart, colSpan: $colSpan)';
}


}

/// @nodoc
abstract mixin class _$DesignBlockApiCopyWith<$Res> implements $DesignBlockApiCopyWith<$Res> {
  factory _$DesignBlockApiCopyWith(_DesignBlockApi value, $Res Function(_DesignBlockApi) _then) = __$DesignBlockApiCopyWithImpl;
@override @useResult
$Res call({
 String id, String type, GridPositionApi gridPosition,@JsonKey(includeIfNull: false) Map<String, dynamic>? properties,@JsonKey(includeIfNull: false) bool? locked,@JsonKey(includeIfNull: false) String? rowAlign,@JsonKey(includeIfNull: false) String? rowWidth,@JsonKey(includeIfNull: false) int? colStart,@JsonKey(includeIfNull: false) int? colSpan
});


@override $GridPositionApiCopyWith<$Res> get gridPosition;

}
/// @nodoc
class __$DesignBlockApiCopyWithImpl<$Res>
    implements _$DesignBlockApiCopyWith<$Res> {
  __$DesignBlockApiCopyWithImpl(this._self, this._then);

  final _DesignBlockApi _self;
  final $Res Function(_DesignBlockApi) _then;

/// Create a copy of DesignBlockApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? gridPosition = null,Object? properties = freezed,Object? locked = freezed,Object? rowAlign = freezed,Object? rowWidth = freezed,Object? colStart = freezed,Object? colSpan = freezed,}) {
  return _then(_DesignBlockApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,gridPosition: null == gridPosition ? _self.gridPosition : gridPosition // ignore: cast_nullable_to_non_nullable
as GridPositionApi,properties: freezed == properties ? _self._properties : properties // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,locked: freezed == locked ? _self.locked : locked // ignore: cast_nullable_to_non_nullable
as bool?,rowAlign: freezed == rowAlign ? _self.rowAlign : rowAlign // ignore: cast_nullable_to_non_nullable
as String?,rowWidth: freezed == rowWidth ? _self.rowWidth : rowWidth // ignore: cast_nullable_to_non_nullable
as String?,colStart: freezed == colStart ? _self.colStart : colStart // ignore: cast_nullable_to_non_nullable
as int?,colSpan: freezed == colSpan ? _self.colSpan : colSpan // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of DesignBlockApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GridPositionApiCopyWith<$Res> get gridPosition {
  
  return $GridPositionApiCopyWith<$Res>(_self.gridPosition, (value) {
    return _then(_self.copyWith(gridPosition: value));
  });
}
}


/// @nodoc
mixin _$GridPositionApi {

 int get x; int get y; int get w; int get h;
/// Create a copy of GridPositionApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GridPositionApiCopyWith<GridPositionApi> get copyWith => _$GridPositionApiCopyWithImpl<GridPositionApi>(this as GridPositionApi, _$identity);

  /// Serializes this GridPositionApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GridPositionApi&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y)&&(identical(other.w, w) || other.w == w)&&(identical(other.h, h) || other.h == h));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,x,y,w,h);

@override
String toString() {
  return 'GridPositionApi(x: $x, y: $y, w: $w, h: $h)';
}


}

/// @nodoc
abstract mixin class $GridPositionApiCopyWith<$Res>  {
  factory $GridPositionApiCopyWith(GridPositionApi value, $Res Function(GridPositionApi) _then) = _$GridPositionApiCopyWithImpl;
@useResult
$Res call({
 int x, int y, int w, int h
});




}
/// @nodoc
class _$GridPositionApiCopyWithImpl<$Res>
    implements $GridPositionApiCopyWith<$Res> {
  _$GridPositionApiCopyWithImpl(this._self, this._then);

  final GridPositionApi _self;
  final $Res Function(GridPositionApi) _then;

/// Create a copy of GridPositionApi
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


/// Adds pattern-matching-related methods to [GridPositionApi].
extension GridPositionApiPatterns on GridPositionApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GridPositionApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GridPositionApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GridPositionApi value)  $default,){
final _that = this;
switch (_that) {
case _GridPositionApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GridPositionApi value)?  $default,){
final _that = this;
switch (_that) {
case _GridPositionApi() when $default != null:
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
case _GridPositionApi() when $default != null:
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
case _GridPositionApi():
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
case _GridPositionApi() when $default != null:
return $default(_that.x,_that.y,_that.w,_that.h);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GridPositionApi implements GridPositionApi {
  const _GridPositionApi({this.x = 0, this.y = 0, this.w = 1, this.h = 1});
  factory _GridPositionApi.fromJson(Map<String, dynamic> json) => _$GridPositionApiFromJson(json);

@override@JsonKey() final  int x;
@override@JsonKey() final  int y;
@override@JsonKey() final  int w;
@override@JsonKey() final  int h;

/// Create a copy of GridPositionApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GridPositionApiCopyWith<_GridPositionApi> get copyWith => __$GridPositionApiCopyWithImpl<_GridPositionApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GridPositionApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GridPositionApi&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y)&&(identical(other.w, w) || other.w == w)&&(identical(other.h, h) || other.h == h));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,x,y,w,h);

@override
String toString() {
  return 'GridPositionApi(x: $x, y: $y, w: $w, h: $h)';
}


}

/// @nodoc
abstract mixin class _$GridPositionApiCopyWith<$Res> implements $GridPositionApiCopyWith<$Res> {
  factory _$GridPositionApiCopyWith(_GridPositionApi value, $Res Function(_GridPositionApi) _then) = __$GridPositionApiCopyWithImpl;
@override @useResult
$Res call({
 int x, int y, int w, int h
});




}
/// @nodoc
class __$GridPositionApiCopyWithImpl<$Res>
    implements _$GridPositionApiCopyWith<$Res> {
  __$GridPositionApiCopyWithImpl(this._self, this._then);

  final _GridPositionApi _self;
  final $Res Function(_GridPositionApi) _then;

/// Create a copy of GridPositionApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? x = null,Object? y = null,Object? w = null,Object? h = null,}) {
  return _then(_GridPositionApi(
x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as int,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as int,w: null == w ? _self.w : w // ignore: cast_nullable_to_non_nullable
as int,h: null == h ? _self.h : h // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$DocumentSettingsApi {

 String get pageLayout; String get pageSize; int get globalFontSize; String get primaryFont; String get secondaryFont; bool get showPaidStamp; bool get showShippingAddress; bool get embedDocuments; bool get hideEmptyColumns; bool get pageNumbering; int get pageMarginTop; int get pageMarginRight; int get pageMarginBottom; int get pageMarginLeft; int get pagePaddingTop; int get pagePaddingRight; int get pagePaddingBottom; int get pagePaddingLeft;
/// Create a copy of DocumentSettingsApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DocumentSettingsApiCopyWith<DocumentSettingsApi> get copyWith => _$DocumentSettingsApiCopyWithImpl<DocumentSettingsApi>(this as DocumentSettingsApi, _$identity);

  /// Serializes this DocumentSettingsApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DocumentSettingsApi&&(identical(other.pageLayout, pageLayout) || other.pageLayout == pageLayout)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize)&&(identical(other.globalFontSize, globalFontSize) || other.globalFontSize == globalFontSize)&&(identical(other.primaryFont, primaryFont) || other.primaryFont == primaryFont)&&(identical(other.secondaryFont, secondaryFont) || other.secondaryFont == secondaryFont)&&(identical(other.showPaidStamp, showPaidStamp) || other.showPaidStamp == showPaidStamp)&&(identical(other.showShippingAddress, showShippingAddress) || other.showShippingAddress == showShippingAddress)&&(identical(other.embedDocuments, embedDocuments) || other.embedDocuments == embedDocuments)&&(identical(other.hideEmptyColumns, hideEmptyColumns) || other.hideEmptyColumns == hideEmptyColumns)&&(identical(other.pageNumbering, pageNumbering) || other.pageNumbering == pageNumbering)&&(identical(other.pageMarginTop, pageMarginTop) || other.pageMarginTop == pageMarginTop)&&(identical(other.pageMarginRight, pageMarginRight) || other.pageMarginRight == pageMarginRight)&&(identical(other.pageMarginBottom, pageMarginBottom) || other.pageMarginBottom == pageMarginBottom)&&(identical(other.pageMarginLeft, pageMarginLeft) || other.pageMarginLeft == pageMarginLeft)&&(identical(other.pagePaddingTop, pagePaddingTop) || other.pagePaddingTop == pagePaddingTop)&&(identical(other.pagePaddingRight, pagePaddingRight) || other.pagePaddingRight == pagePaddingRight)&&(identical(other.pagePaddingBottom, pagePaddingBottom) || other.pagePaddingBottom == pagePaddingBottom)&&(identical(other.pagePaddingLeft, pagePaddingLeft) || other.pagePaddingLeft == pagePaddingLeft));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pageLayout,pageSize,globalFontSize,primaryFont,secondaryFont,showPaidStamp,showShippingAddress,embedDocuments,hideEmptyColumns,pageNumbering,pageMarginTop,pageMarginRight,pageMarginBottom,pageMarginLeft,pagePaddingTop,pagePaddingRight,pagePaddingBottom,pagePaddingLeft);

@override
String toString() {
  return 'DocumentSettingsApi(pageLayout: $pageLayout, pageSize: $pageSize, globalFontSize: $globalFontSize, primaryFont: $primaryFont, secondaryFont: $secondaryFont, showPaidStamp: $showPaidStamp, showShippingAddress: $showShippingAddress, embedDocuments: $embedDocuments, hideEmptyColumns: $hideEmptyColumns, pageNumbering: $pageNumbering, pageMarginTop: $pageMarginTop, pageMarginRight: $pageMarginRight, pageMarginBottom: $pageMarginBottom, pageMarginLeft: $pageMarginLeft, pagePaddingTop: $pagePaddingTop, pagePaddingRight: $pagePaddingRight, pagePaddingBottom: $pagePaddingBottom, pagePaddingLeft: $pagePaddingLeft)';
}


}

/// @nodoc
abstract mixin class $DocumentSettingsApiCopyWith<$Res>  {
  factory $DocumentSettingsApiCopyWith(DocumentSettingsApi value, $Res Function(DocumentSettingsApi) _then) = _$DocumentSettingsApiCopyWithImpl;
@useResult
$Res call({
 String pageLayout, String pageSize, int globalFontSize, String primaryFont, String secondaryFont, bool showPaidStamp, bool showShippingAddress, bool embedDocuments, bool hideEmptyColumns, bool pageNumbering, int pageMarginTop, int pageMarginRight, int pageMarginBottom, int pageMarginLeft, int pagePaddingTop, int pagePaddingRight, int pagePaddingBottom, int pagePaddingLeft
});




}
/// @nodoc
class _$DocumentSettingsApiCopyWithImpl<$Res>
    implements $DocumentSettingsApiCopyWith<$Res> {
  _$DocumentSettingsApiCopyWithImpl(this._self, this._then);

  final DocumentSettingsApi _self;
  final $Res Function(DocumentSettingsApi) _then;

/// Create a copy of DocumentSettingsApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pageLayout = null,Object? pageSize = null,Object? globalFontSize = null,Object? primaryFont = null,Object? secondaryFont = null,Object? showPaidStamp = null,Object? showShippingAddress = null,Object? embedDocuments = null,Object? hideEmptyColumns = null,Object? pageNumbering = null,Object? pageMarginTop = null,Object? pageMarginRight = null,Object? pageMarginBottom = null,Object? pageMarginLeft = null,Object? pagePaddingTop = null,Object? pagePaddingRight = null,Object? pagePaddingBottom = null,Object? pagePaddingLeft = null,}) {
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
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [DocumentSettingsApi].
extension DocumentSettingsApiPatterns on DocumentSettingsApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DocumentSettingsApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DocumentSettingsApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DocumentSettingsApi value)  $default,){
final _that = this;
switch (_that) {
case _DocumentSettingsApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DocumentSettingsApi value)?  $default,){
final _that = this;
switch (_that) {
case _DocumentSettingsApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String pageLayout,  String pageSize,  int globalFontSize,  String primaryFont,  String secondaryFont,  bool showPaidStamp,  bool showShippingAddress,  bool embedDocuments,  bool hideEmptyColumns,  bool pageNumbering,  int pageMarginTop,  int pageMarginRight,  int pageMarginBottom,  int pageMarginLeft,  int pagePaddingTop,  int pagePaddingRight,  int pagePaddingBottom,  int pagePaddingLeft)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DocumentSettingsApi() when $default != null:
return $default(_that.pageLayout,_that.pageSize,_that.globalFontSize,_that.primaryFont,_that.secondaryFont,_that.showPaidStamp,_that.showShippingAddress,_that.embedDocuments,_that.hideEmptyColumns,_that.pageNumbering,_that.pageMarginTop,_that.pageMarginRight,_that.pageMarginBottom,_that.pageMarginLeft,_that.pagePaddingTop,_that.pagePaddingRight,_that.pagePaddingBottom,_that.pagePaddingLeft);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String pageLayout,  String pageSize,  int globalFontSize,  String primaryFont,  String secondaryFont,  bool showPaidStamp,  bool showShippingAddress,  bool embedDocuments,  bool hideEmptyColumns,  bool pageNumbering,  int pageMarginTop,  int pageMarginRight,  int pageMarginBottom,  int pageMarginLeft,  int pagePaddingTop,  int pagePaddingRight,  int pagePaddingBottom,  int pagePaddingLeft)  $default,) {final _that = this;
switch (_that) {
case _DocumentSettingsApi():
return $default(_that.pageLayout,_that.pageSize,_that.globalFontSize,_that.primaryFont,_that.secondaryFont,_that.showPaidStamp,_that.showShippingAddress,_that.embedDocuments,_that.hideEmptyColumns,_that.pageNumbering,_that.pageMarginTop,_that.pageMarginRight,_that.pageMarginBottom,_that.pageMarginLeft,_that.pagePaddingTop,_that.pagePaddingRight,_that.pagePaddingBottom,_that.pagePaddingLeft);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String pageLayout,  String pageSize,  int globalFontSize,  String primaryFont,  String secondaryFont,  bool showPaidStamp,  bool showShippingAddress,  bool embedDocuments,  bool hideEmptyColumns,  bool pageNumbering,  int pageMarginTop,  int pageMarginRight,  int pageMarginBottom,  int pageMarginLeft,  int pagePaddingTop,  int pagePaddingRight,  int pagePaddingBottom,  int pagePaddingLeft)?  $default,) {final _that = this;
switch (_that) {
case _DocumentSettingsApi() when $default != null:
return $default(_that.pageLayout,_that.pageSize,_that.globalFontSize,_that.primaryFont,_that.secondaryFont,_that.showPaidStamp,_that.showShippingAddress,_that.embedDocuments,_that.hideEmptyColumns,_that.pageNumbering,_that.pageMarginTop,_that.pageMarginRight,_that.pageMarginBottom,_that.pageMarginLeft,_that.pagePaddingTop,_that.pagePaddingRight,_that.pagePaddingBottom,_that.pagePaddingLeft);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DocumentSettingsApi implements DocumentSettingsApi {
  const _DocumentSettingsApi({this.pageLayout = 'portrait', this.pageSize = 'A4', this.globalFontSize = 16, this.primaryFont = 'Roboto', this.secondaryFont = 'Roboto', this.showPaidStamp = false, this.showShippingAddress = false, this.embedDocuments = false, this.hideEmptyColumns = false, this.pageNumbering = false, this.pageMarginTop = 0, this.pageMarginRight = 0, this.pageMarginBottom = 0, this.pageMarginLeft = 0, this.pagePaddingTop = 30, this.pagePaddingRight = 30, this.pagePaddingBottom = 30, this.pagePaddingLeft = 30});
  factory _DocumentSettingsApi.fromJson(Map<String, dynamic> json) => _$DocumentSettingsApiFromJson(json);

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

/// Create a copy of DocumentSettingsApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DocumentSettingsApiCopyWith<_DocumentSettingsApi> get copyWith => __$DocumentSettingsApiCopyWithImpl<_DocumentSettingsApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DocumentSettingsApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DocumentSettingsApi&&(identical(other.pageLayout, pageLayout) || other.pageLayout == pageLayout)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize)&&(identical(other.globalFontSize, globalFontSize) || other.globalFontSize == globalFontSize)&&(identical(other.primaryFont, primaryFont) || other.primaryFont == primaryFont)&&(identical(other.secondaryFont, secondaryFont) || other.secondaryFont == secondaryFont)&&(identical(other.showPaidStamp, showPaidStamp) || other.showPaidStamp == showPaidStamp)&&(identical(other.showShippingAddress, showShippingAddress) || other.showShippingAddress == showShippingAddress)&&(identical(other.embedDocuments, embedDocuments) || other.embedDocuments == embedDocuments)&&(identical(other.hideEmptyColumns, hideEmptyColumns) || other.hideEmptyColumns == hideEmptyColumns)&&(identical(other.pageNumbering, pageNumbering) || other.pageNumbering == pageNumbering)&&(identical(other.pageMarginTop, pageMarginTop) || other.pageMarginTop == pageMarginTop)&&(identical(other.pageMarginRight, pageMarginRight) || other.pageMarginRight == pageMarginRight)&&(identical(other.pageMarginBottom, pageMarginBottom) || other.pageMarginBottom == pageMarginBottom)&&(identical(other.pageMarginLeft, pageMarginLeft) || other.pageMarginLeft == pageMarginLeft)&&(identical(other.pagePaddingTop, pagePaddingTop) || other.pagePaddingTop == pagePaddingTop)&&(identical(other.pagePaddingRight, pagePaddingRight) || other.pagePaddingRight == pagePaddingRight)&&(identical(other.pagePaddingBottom, pagePaddingBottom) || other.pagePaddingBottom == pagePaddingBottom)&&(identical(other.pagePaddingLeft, pagePaddingLeft) || other.pagePaddingLeft == pagePaddingLeft));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pageLayout,pageSize,globalFontSize,primaryFont,secondaryFont,showPaidStamp,showShippingAddress,embedDocuments,hideEmptyColumns,pageNumbering,pageMarginTop,pageMarginRight,pageMarginBottom,pageMarginLeft,pagePaddingTop,pagePaddingRight,pagePaddingBottom,pagePaddingLeft);

@override
String toString() {
  return 'DocumentSettingsApi(pageLayout: $pageLayout, pageSize: $pageSize, globalFontSize: $globalFontSize, primaryFont: $primaryFont, secondaryFont: $secondaryFont, showPaidStamp: $showPaidStamp, showShippingAddress: $showShippingAddress, embedDocuments: $embedDocuments, hideEmptyColumns: $hideEmptyColumns, pageNumbering: $pageNumbering, pageMarginTop: $pageMarginTop, pageMarginRight: $pageMarginRight, pageMarginBottom: $pageMarginBottom, pageMarginLeft: $pageMarginLeft, pagePaddingTop: $pagePaddingTop, pagePaddingRight: $pagePaddingRight, pagePaddingBottom: $pagePaddingBottom, pagePaddingLeft: $pagePaddingLeft)';
}


}

/// @nodoc
abstract mixin class _$DocumentSettingsApiCopyWith<$Res> implements $DocumentSettingsApiCopyWith<$Res> {
  factory _$DocumentSettingsApiCopyWith(_DocumentSettingsApi value, $Res Function(_DocumentSettingsApi) _then) = __$DocumentSettingsApiCopyWithImpl;
@override @useResult
$Res call({
 String pageLayout, String pageSize, int globalFontSize, String primaryFont, String secondaryFont, bool showPaidStamp, bool showShippingAddress, bool embedDocuments, bool hideEmptyColumns, bool pageNumbering, int pageMarginTop, int pageMarginRight, int pageMarginBottom, int pageMarginLeft, int pagePaddingTop, int pagePaddingRight, int pagePaddingBottom, int pagePaddingLeft
});




}
/// @nodoc
class __$DocumentSettingsApiCopyWithImpl<$Res>
    implements _$DocumentSettingsApiCopyWith<$Res> {
  __$DocumentSettingsApiCopyWithImpl(this._self, this._then);

  final _DocumentSettingsApi _self;
  final $Res Function(_DocumentSettingsApi) _then;

/// Create a copy of DocumentSettingsApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pageLayout = null,Object? pageSize = null,Object? globalFontSize = null,Object? primaryFont = null,Object? secondaryFont = null,Object? showPaidStamp = null,Object? showShippingAddress = null,Object? embedDocuments = null,Object? hideEmptyColumns = null,Object? pageNumbering = null,Object? pageMarginTop = null,Object? pageMarginRight = null,Object? pageMarginBottom = null,Object? pageMarginLeft = null,Object? pagePaddingTop = null,Object? pagePaddingRight = null,Object? pagePaddingBottom = null,Object? pagePaddingLeft = null,}) {
  return _then(_DocumentSettingsApi(
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
as int,
  ));
}


}


/// @nodoc
mixin _$DesignApi {

 String get id; String get name;@JsonKey(name: 'is_custom') bool get isCustom;@JsonKey(name: 'is_active') bool get isActive;@JsonKey(name: 'is_template') bool get isTemplate;@JsonKey(name: 'is_free') bool get isFree; String get entities; DesignTemplateApi get design;@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt;@JsonKey(name: 'is_deleted') bool get isDeleted;
/// Create a copy of DesignApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DesignApiCopyWith<DesignApi> get copyWith => _$DesignApiCopyWithImpl<DesignApi>(this as DesignApi, _$identity);

  /// Serializes this DesignApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DesignApi&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.isCustom, isCustom) || other.isCustom == isCustom)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.isTemplate, isTemplate) || other.isTemplate == isTemplate)&&(identical(other.isFree, isFree) || other.isFree == isFree)&&(identical(other.entities, entities) || other.entities == entities)&&(identical(other.design, design) || other.design == design)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,isCustom,isActive,isTemplate,isFree,entities,design,createdAt,updatedAt,archivedAt,isDeleted);

@override
String toString() {
  return 'DesignApi(id: $id, name: $name, isCustom: $isCustom, isActive: $isActive, isTemplate: $isTemplate, isFree: $isFree, entities: $entities, design: $design, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted)';
}


}

/// @nodoc
abstract mixin class $DesignApiCopyWith<$Res>  {
  factory $DesignApiCopyWith(DesignApi value, $Res Function(DesignApi) _then) = _$DesignApiCopyWithImpl;
@useResult
$Res call({
 String id, String name,@JsonKey(name: 'is_custom') bool isCustom,@JsonKey(name: 'is_active') bool isActive,@JsonKey(name: 'is_template') bool isTemplate,@JsonKey(name: 'is_free') bool isFree, String entities, DesignTemplateApi design,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'is_deleted') bool isDeleted
});


$DesignTemplateApiCopyWith<$Res> get design;

}
/// @nodoc
class _$DesignApiCopyWithImpl<$Res>
    implements $DesignApiCopyWith<$Res> {
  _$DesignApiCopyWithImpl(this._self, this._then);

  final DesignApi _self;
  final $Res Function(DesignApi) _then;

/// Create a copy of DesignApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? isCustom = null,Object? isActive = null,Object? isTemplate = null,Object? isFree = null,Object? entities = null,Object? design = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,isCustom: null == isCustom ? _self.isCustom : isCustom // ignore: cast_nullable_to_non_nullable
as bool,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,isTemplate: null == isTemplate ? _self.isTemplate : isTemplate // ignore: cast_nullable_to_non_nullable
as bool,isFree: null == isFree ? _self.isFree : isFree // ignore: cast_nullable_to_non_nullable
as bool,entities: null == entities ? _self.entities : entities // ignore: cast_nullable_to_non_nullable
as String,design: null == design ? _self.design : design // ignore: cast_nullable_to_non_nullable
as DesignTemplateApi,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of DesignApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DesignTemplateApiCopyWith<$Res> get design {
  
  return $DesignTemplateApiCopyWith<$Res>(_self.design, (value) {
    return _then(_self.copyWith(design: value));
  });
}
}


/// Adds pattern-matching-related methods to [DesignApi].
extension DesignApiPatterns on DesignApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DesignApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DesignApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DesignApi value)  $default,){
final _that = this;
switch (_that) {
case _DesignApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DesignApi value)?  $default,){
final _that = this;
switch (_that) {
case _DesignApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name, @JsonKey(name: 'is_custom')  bool isCustom, @JsonKey(name: 'is_active')  bool isActive, @JsonKey(name: 'is_template')  bool isTemplate, @JsonKey(name: 'is_free')  bool isFree,  String entities,  DesignTemplateApi design, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DesignApi() when $default != null:
return $default(_that.id,_that.name,_that.isCustom,_that.isActive,_that.isTemplate,_that.isFree,_that.entities,_that.design,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name, @JsonKey(name: 'is_custom')  bool isCustom, @JsonKey(name: 'is_active')  bool isActive, @JsonKey(name: 'is_template')  bool isTemplate, @JsonKey(name: 'is_free')  bool isFree,  String entities,  DesignTemplateApi design, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted)  $default,) {final _that = this;
switch (_that) {
case _DesignApi():
return $default(_that.id,_that.name,_that.isCustom,_that.isActive,_that.isTemplate,_that.isFree,_that.entities,_that.design,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name, @JsonKey(name: 'is_custom')  bool isCustom, @JsonKey(name: 'is_active')  bool isActive, @JsonKey(name: 'is_template')  bool isTemplate, @JsonKey(name: 'is_free')  bool isFree,  String entities,  DesignTemplateApi design, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted)?  $default,) {final _that = this;
switch (_that) {
case _DesignApi() when $default != null:
return $default(_that.id,_that.name,_that.isCustom,_that.isActive,_that.isTemplate,_that.isFree,_that.entities,_that.design,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DesignApi implements DesignApi {
  const _DesignApi({this.id = '', this.name = '', @JsonKey(name: 'is_custom') this.isCustom = false, @JsonKey(name: 'is_active') this.isActive = true, @JsonKey(name: 'is_template') this.isTemplate = false, @JsonKey(name: 'is_free') this.isFree = true, this.entities = '', this.design = const DesignTemplateApi(), @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0, @JsonKey(name: 'is_deleted') this.isDeleted = false});
  factory _DesignApi.fromJson(Map<String, dynamic> json) => _$DesignApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey() final  String name;
@override@JsonKey(name: 'is_custom') final  bool isCustom;
@override@JsonKey(name: 'is_active') final  bool isActive;
@override@JsonKey(name: 'is_template') final  bool isTemplate;
@override@JsonKey(name: 'is_free') final  bool isFree;
@override@JsonKey() final  String entities;
@override@JsonKey() final  DesignTemplateApi design;
@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'archived_at') final  int archivedAt;
@override@JsonKey(name: 'is_deleted') final  bool isDeleted;

/// Create a copy of DesignApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DesignApiCopyWith<_DesignApi> get copyWith => __$DesignApiCopyWithImpl<_DesignApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DesignApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DesignApi&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.isCustom, isCustom) || other.isCustom == isCustom)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.isTemplate, isTemplate) || other.isTemplate == isTemplate)&&(identical(other.isFree, isFree) || other.isFree == isFree)&&(identical(other.entities, entities) || other.entities == entities)&&(identical(other.design, design) || other.design == design)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,isCustom,isActive,isTemplate,isFree,entities,design,createdAt,updatedAt,archivedAt,isDeleted);

@override
String toString() {
  return 'DesignApi(id: $id, name: $name, isCustom: $isCustom, isActive: $isActive, isTemplate: $isTemplate, isFree: $isFree, entities: $entities, design: $design, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted)';
}


}

/// @nodoc
abstract mixin class _$DesignApiCopyWith<$Res> implements $DesignApiCopyWith<$Res> {
  factory _$DesignApiCopyWith(_DesignApi value, $Res Function(_DesignApi) _then) = __$DesignApiCopyWithImpl;
@override @useResult
$Res call({
 String id, String name,@JsonKey(name: 'is_custom') bool isCustom,@JsonKey(name: 'is_active') bool isActive,@JsonKey(name: 'is_template') bool isTemplate,@JsonKey(name: 'is_free') bool isFree, String entities, DesignTemplateApi design,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'is_deleted') bool isDeleted
});


@override $DesignTemplateApiCopyWith<$Res> get design;

}
/// @nodoc
class __$DesignApiCopyWithImpl<$Res>
    implements _$DesignApiCopyWith<$Res> {
  __$DesignApiCopyWithImpl(this._self, this._then);

  final _DesignApi _self;
  final $Res Function(_DesignApi) _then;

/// Create a copy of DesignApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? isCustom = null,Object? isActive = null,Object? isTemplate = null,Object? isFree = null,Object? entities = null,Object? design = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,}) {
  return _then(_DesignApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,isCustom: null == isCustom ? _self.isCustom : isCustom // ignore: cast_nullable_to_non_nullable
as bool,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,isTemplate: null == isTemplate ? _self.isTemplate : isTemplate // ignore: cast_nullable_to_non_nullable
as bool,isFree: null == isFree ? _self.isFree : isFree // ignore: cast_nullable_to_non_nullable
as bool,entities: null == entities ? _self.entities : entities // ignore: cast_nullable_to_non_nullable
as String,design: null == design ? _self.design : design // ignore: cast_nullable_to_non_nullable
as DesignTemplateApi,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of DesignApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DesignTemplateApiCopyWith<$Res> get design {
  
  return $DesignTemplateApiCopyWith<$Res>(_self.design, (value) {
    return _then(_self.copyWith(design: value));
  });
}
}


/// @nodoc
mixin _$DesignListApi {

@JsonKey(fromJson: _designListData) List<DesignApi> get data;
/// Create a copy of DesignListApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DesignListApiCopyWith<DesignListApi> get copyWith => _$DesignListApiCopyWithImpl<DesignListApi>(this as DesignListApi, _$identity);

  /// Serializes this DesignListApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DesignListApi&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'DesignListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $DesignListApiCopyWith<$Res>  {
  factory $DesignListApiCopyWith(DesignListApi value, $Res Function(DesignListApi) _then) = _$DesignListApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _designListData) List<DesignApi> data
});




}
/// @nodoc
class _$DesignListApiCopyWithImpl<$Res>
    implements $DesignListApiCopyWith<$Res> {
  _$DesignListApiCopyWithImpl(this._self, this._then);

  final DesignListApi _self;
  final $Res Function(DesignListApi) _then;

/// Create a copy of DesignListApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<DesignApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [DesignListApi].
extension DesignListApiPatterns on DesignListApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DesignListApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DesignListApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DesignListApi value)  $default,){
final _that = this;
switch (_that) {
case _DesignListApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DesignListApi value)?  $default,){
final _that = this;
switch (_that) {
case _DesignListApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _designListData)  List<DesignApi> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DesignListApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _designListData)  List<DesignApi> data)  $default,) {final _that = this;
switch (_that) {
case _DesignListApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _designListData)  List<DesignApi> data)?  $default,) {final _that = this;
switch (_that) {
case _DesignListApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DesignListApi implements DesignListApi {
  const _DesignListApi({@JsonKey(fromJson: _designListData) final  List<DesignApi> data = const <DesignApi>[]}): _data = data;
  factory _DesignListApi.fromJson(Map<String, dynamic> json) => _$DesignListApiFromJson(json);

 final  List<DesignApi> _data;
@override@JsonKey(fromJson: _designListData) List<DesignApi> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of DesignListApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DesignListApiCopyWith<_DesignListApi> get copyWith => __$DesignListApiCopyWithImpl<_DesignListApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DesignListApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DesignListApi&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'DesignListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$DesignListApiCopyWith<$Res> implements $DesignListApiCopyWith<$Res> {
  factory _$DesignListApiCopyWith(_DesignListApi value, $Res Function(_DesignListApi) _then) = __$DesignListApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _designListData) List<DesignApi> data
});




}
/// @nodoc
class __$DesignListApiCopyWithImpl<$Res>
    implements _$DesignListApiCopyWith<$Res> {
  __$DesignListApiCopyWithImpl(this._self, this._then);

  final _DesignListApi _self;
  final $Res Function(_DesignListApi) _then;

/// Create a copy of DesignListApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_DesignListApi(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<DesignApi>,
  ));
}


}


/// @nodoc
mixin _$DesignItemApi {

 DesignApi get data;
/// Create a copy of DesignItemApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DesignItemApiCopyWith<DesignItemApi> get copyWith => _$DesignItemApiCopyWithImpl<DesignItemApi>(this as DesignItemApi, _$identity);

  /// Serializes this DesignItemApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DesignItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'DesignItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $DesignItemApiCopyWith<$Res>  {
  factory $DesignItemApiCopyWith(DesignItemApi value, $Res Function(DesignItemApi) _then) = _$DesignItemApiCopyWithImpl;
@useResult
$Res call({
 DesignApi data
});


$DesignApiCopyWith<$Res> get data;

}
/// @nodoc
class _$DesignItemApiCopyWithImpl<$Res>
    implements $DesignItemApiCopyWith<$Res> {
  _$DesignItemApiCopyWithImpl(this._self, this._then);

  final DesignItemApi _self;
  final $Res Function(DesignItemApi) _then;

/// Create a copy of DesignItemApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as DesignApi,
  ));
}
/// Create a copy of DesignItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DesignApiCopyWith<$Res> get data {
  
  return $DesignApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [DesignItemApi].
extension DesignItemApiPatterns on DesignItemApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DesignItemApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DesignItemApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DesignItemApi value)  $default,){
final _that = this;
switch (_that) {
case _DesignItemApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DesignItemApi value)?  $default,){
final _that = this;
switch (_that) {
case _DesignItemApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DesignApi data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DesignItemApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DesignApi data)  $default,) {final _that = this;
switch (_that) {
case _DesignItemApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DesignApi data)?  $default,) {final _that = this;
switch (_that) {
case _DesignItemApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DesignItemApi implements DesignItemApi {
  const _DesignItemApi({required this.data});
  factory _DesignItemApi.fromJson(Map<String, dynamic> json) => _$DesignItemApiFromJson(json);

@override final  DesignApi data;

/// Create a copy of DesignItemApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DesignItemApiCopyWith<_DesignItemApi> get copyWith => __$DesignItemApiCopyWithImpl<_DesignItemApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DesignItemApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DesignItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'DesignItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$DesignItemApiCopyWith<$Res> implements $DesignItemApiCopyWith<$Res> {
  factory _$DesignItemApiCopyWith(_DesignItemApi value, $Res Function(_DesignItemApi) _then) = __$DesignItemApiCopyWithImpl;
@override @useResult
$Res call({
 DesignApi data
});


@override $DesignApiCopyWith<$Res> get data;

}
/// @nodoc
class __$DesignItemApiCopyWithImpl<$Res>
    implements _$DesignItemApiCopyWith<$Res> {
  __$DesignItemApiCopyWithImpl(this._self, this._then);

  final _DesignItemApi _self;
  final $Res Function(_DesignItemApi) _then;

/// Create a copy of DesignItemApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_DesignItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as DesignApi,
  ));
}

/// Create a copy of DesignItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DesignApiCopyWith<$Res> get data {
  
  return $DesignApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

// dart format on
