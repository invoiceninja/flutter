// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'calendar_connection_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CalendarConnection {

 bool get connected; String? get provider; String? get email;@JsonKey(name: 'expires_at') int? get expiresAt; List<CalendarInfo> get calendars;
/// Create a copy of CalendarConnection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CalendarConnectionCopyWith<CalendarConnection> get copyWith => _$CalendarConnectionCopyWithImpl<CalendarConnection>(this as CalendarConnection, _$identity);

  /// Serializes this CalendarConnection to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CalendarConnection;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CalendarConnection&&(identical(other.connected, _this.connected) || other.connected == _this.connected)&&(identical(other.provider, _this.provider) || other.provider == _this.provider)&&(identical(other.email, _this.email) || other.email == _this.email)&&(identical(other.expiresAt, _this.expiresAt) || other.expiresAt == _this.expiresAt)&&const DeepCollectionEquality().equals(other.calendars, _this.calendars));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CalendarConnection;
  return Object.hash(runtimeType,_this.connected,_this.provider,_this.email,_this.expiresAt,const DeepCollectionEquality().hash(_this.calendars));
}

@override
String toString() {
  final _this = this as CalendarConnection;
  return 'CalendarConnection(connected: ${_this.connected}, provider: ${_this.provider}, email: ${_this.email}, expiresAt: ${_this.expiresAt}, calendars: ${_this.calendars})';
}


}

/// @nodoc
abstract mixin class $CalendarConnectionCopyWith<$Res>  {
  factory $CalendarConnectionCopyWith(CalendarConnection value, $Res Function(CalendarConnection) _then) = _$CalendarConnectionCopyWithImpl;
@useResult
$Res call({
 bool connected, String? provider, String? email,@JsonKey(name: 'expires_at') int? expiresAt, List<CalendarInfo> calendars
});




}
/// @nodoc
class _$CalendarConnectionCopyWithImpl<$Res>
    implements $CalendarConnectionCopyWith<$Res> {
  _$CalendarConnectionCopyWithImpl(this._self, this._then);

  final CalendarConnection _self;
  final $Res Function(CalendarConnection) _then;

/// Create a copy of CalendarConnection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? connected = null,Object? provider = freezed,Object? email = freezed,Object? expiresAt = freezed,Object? calendars = null,}) {
  return _then(CalendarConnection(
connected: null == connected ? _self.connected : connected // ignore: cast_nullable_to_non_nullable
as bool,provider: freezed == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as int?,calendars: null == calendars ? _self.calendars : calendars // ignore: cast_nullable_to_non_nullable
as List<CalendarInfo>,
  ));
}

}


/// Adds pattern-matching-related methods to [CalendarConnection].
extension CalendarConnectionPatterns on CalendarConnection {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CalendarConnection value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CalendarConnection() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CalendarConnection value)  $default,){
final _that = this;
switch (_that) {
case _CalendarConnection():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CalendarConnection value)?  $default,){
final _that = this;
switch (_that) {
case _CalendarConnection() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool connected,  String? provider,  String? email, @JsonKey(name: 'expires_at')  int? expiresAt,  List<CalendarInfo> calendars)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CalendarConnection() when $default != null:
return $default(_that.connected,_that.provider,_that.email,_that.expiresAt,_that.calendars);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool connected,  String? provider,  String? email, @JsonKey(name: 'expires_at')  int? expiresAt,  List<CalendarInfo> calendars)  $default,) {final _that = this;
switch (_that) {
case _CalendarConnection():
return $default(_that.connected,_that.provider,_that.email,_that.expiresAt,_that.calendars);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool connected,  String? provider,  String? email, @JsonKey(name: 'expires_at')  int? expiresAt,  List<CalendarInfo> calendars)?  $default,) {final _that = this;
switch (_that) {
case _CalendarConnection() when $default != null:
return $default(_that.connected,_that.provider,_that.email,_that.expiresAt,_that.calendars);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CalendarConnection implements CalendarConnection {
  const _CalendarConnection({this.connected = false, this.provider, this.email, @JsonKey(name: 'expires_at') this.expiresAt,  List<CalendarInfo> calendars = const <CalendarInfo>[]}): _calendars = calendars;
  factory _CalendarConnection.fromJson(Map<String, dynamic> json) => _$CalendarConnectionFromJson(json);

@override@JsonKey() final  bool connected;
@override final  String? provider;
@override final  String? email;
@override@JsonKey(name: 'expires_at') final  int? expiresAt;
 final  List<CalendarInfo> _calendars;
@override@JsonKey() List<CalendarInfo> get calendars {
  if (_calendars is EqualUnmodifiableListView) return _calendars;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_calendars);
}


/// Create a copy of CalendarConnection
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CalendarConnectionCopyWith<_CalendarConnection> get copyWith => __$CalendarConnectionCopyWithImpl<_CalendarConnection>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CalendarConnectionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CalendarConnection&&(identical(other.connected, connected) || other.connected == connected)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.email, email) || other.email == email)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&const DeepCollectionEquality().equals(other.calendars, _calendars));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,connected,provider,email,expiresAt,const DeepCollectionEquality().hash(_calendars));
}

@override
String toString() {
    return 'CalendarConnection(connected: $connected, provider: $provider, email: $email, expiresAt: $expiresAt, calendars: $calendars)';
}


}

/// @nodoc
abstract mixin class _$CalendarConnectionCopyWith<$Res> implements $CalendarConnectionCopyWith<$Res> {
  factory _$CalendarConnectionCopyWith(_CalendarConnection value, $Res Function(_CalendarConnection) _then) = __$CalendarConnectionCopyWithImpl;
@override @useResult
$Res call({
 bool connected, String? provider, String? email,@JsonKey(name: 'expires_at') int? expiresAt, List<CalendarInfo> calendars
});




}
/// @nodoc
class __$CalendarConnectionCopyWithImpl<$Res>
    implements _$CalendarConnectionCopyWith<$Res> {
  __$CalendarConnectionCopyWithImpl(this._self, this._then);

  final _CalendarConnection _self;
  final $Res Function(_CalendarConnection) _then;

/// Create a copy of CalendarConnection
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? connected = null,Object? provider = freezed,Object? email = freezed,Object? expiresAt = freezed,Object? calendars = null,}) {
  return _then(_CalendarConnection(
connected: null == connected ? _self.connected : connected // ignore: cast_nullable_to_non_nullable
as bool,provider: freezed == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as int?,calendars: null == calendars ? _self._calendars : calendars // ignore: cast_nullable_to_non_nullable
as List<CalendarInfo>,
  ));
}


}


/// @nodoc
mixin _$CalendarInfo {

@JsonKey(name: 'calendar_id') String get calendarId; String get name; bool get primary; bool get writable; bool get selected;
/// Create a copy of CalendarInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CalendarInfoCopyWith<CalendarInfo> get copyWith => _$CalendarInfoCopyWithImpl<CalendarInfo>(this as CalendarInfo, _$identity);

  /// Serializes this CalendarInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CalendarInfo;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CalendarInfo&&(identical(other.calendarId, _this.calendarId) || other.calendarId == _this.calendarId)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.primary, _this.primary) || other.primary == _this.primary)&&(identical(other.writable, _this.writable) || other.writable == _this.writable)&&(identical(other.selected, _this.selected) || other.selected == _this.selected));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CalendarInfo;
  return Object.hash(runtimeType,_this.calendarId,_this.name,_this.primary,_this.writable,_this.selected);
}

@override
String toString() {
  final _this = this as CalendarInfo;
  return 'CalendarInfo(calendarId: ${_this.calendarId}, name: ${_this.name}, primary: ${_this.primary}, writable: ${_this.writable}, selected: ${_this.selected})';
}


}

/// @nodoc
abstract mixin class $CalendarInfoCopyWith<$Res>  {
  factory $CalendarInfoCopyWith(CalendarInfo value, $Res Function(CalendarInfo) _then) = _$CalendarInfoCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'calendar_id') String calendarId, String name, bool primary, bool writable, bool selected
});




}
/// @nodoc
class _$CalendarInfoCopyWithImpl<$Res>
    implements $CalendarInfoCopyWith<$Res> {
  _$CalendarInfoCopyWithImpl(this._self, this._then);

  final CalendarInfo _self;
  final $Res Function(CalendarInfo) _then;

/// Create a copy of CalendarInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? calendarId = null,Object? name = null,Object? primary = null,Object? writable = null,Object? selected = null,}) {
  return _then(CalendarInfo(
calendarId: null == calendarId ? _self.calendarId : calendarId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,primary: null == primary ? _self.primary : primary // ignore: cast_nullable_to_non_nullable
as bool,writable: null == writable ? _self.writable : writable // ignore: cast_nullable_to_non_nullable
as bool,selected: null == selected ? _self.selected : selected // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [CalendarInfo].
extension CalendarInfoPatterns on CalendarInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CalendarInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CalendarInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CalendarInfo value)  $default,){
final _that = this;
switch (_that) {
case _CalendarInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CalendarInfo value)?  $default,){
final _that = this;
switch (_that) {
case _CalendarInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'calendar_id')  String calendarId,  String name,  bool primary,  bool writable,  bool selected)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CalendarInfo() when $default != null:
return $default(_that.calendarId,_that.name,_that.primary,_that.writable,_that.selected);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'calendar_id')  String calendarId,  String name,  bool primary,  bool writable,  bool selected)  $default,) {final _that = this;
switch (_that) {
case _CalendarInfo():
return $default(_that.calendarId,_that.name,_that.primary,_that.writable,_that.selected);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'calendar_id')  String calendarId,  String name,  bool primary,  bool writable,  bool selected)?  $default,) {final _that = this;
switch (_that) {
case _CalendarInfo() when $default != null:
return $default(_that.calendarId,_that.name,_that.primary,_that.writable,_that.selected);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CalendarInfo implements CalendarInfo {
  const _CalendarInfo({@JsonKey(name: 'calendar_id') this.calendarId = '', this.name = '', this.primary = false, this.writable = false, this.selected = false});
  factory _CalendarInfo.fromJson(Map<String, dynamic> json) => _$CalendarInfoFromJson(json);

@override@JsonKey(name: 'calendar_id') final  String calendarId;
@override@JsonKey() final  String name;
@override@JsonKey() final  bool primary;
@override@JsonKey() final  bool writable;
@override@JsonKey() final  bool selected;

/// Create a copy of CalendarInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CalendarInfoCopyWith<_CalendarInfo> get copyWith => __$CalendarInfoCopyWithImpl<_CalendarInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CalendarInfoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CalendarInfo&&(identical(other.calendarId, calendarId) || other.calendarId == calendarId)&&(identical(other.name, name) || other.name == name)&&(identical(other.primary, primary) || other.primary == primary)&&(identical(other.writable, writable) || other.writable == writable)&&(identical(other.selected, selected) || other.selected == selected));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,calendarId,name,primary,writable,selected);
}

@override
String toString() {
    return 'CalendarInfo(calendarId: $calendarId, name: $name, primary: $primary, writable: $writable, selected: $selected)';
}


}

/// @nodoc
abstract mixin class _$CalendarInfoCopyWith<$Res> implements $CalendarInfoCopyWith<$Res> {
  factory _$CalendarInfoCopyWith(_CalendarInfo value, $Res Function(_CalendarInfo) _then) = __$CalendarInfoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'calendar_id') String calendarId, String name, bool primary, bool writable, bool selected
});




}
/// @nodoc
class __$CalendarInfoCopyWithImpl<$Res>
    implements _$CalendarInfoCopyWith<$Res> {
  __$CalendarInfoCopyWithImpl(this._self, this._then);

  final _CalendarInfo _self;
  final $Res Function(_CalendarInfo) _then;

/// Create a copy of CalendarInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? calendarId = null,Object? name = null,Object? primary = null,Object? writable = null,Object? selected = null,}) {
  return _then(_CalendarInfo(
calendarId: null == calendarId ? _self.calendarId : calendarId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,primary: null == primary ? _self.primary : primary // ignore: cast_nullable_to_non_nullable
as bool,writable: null == writable ? _self.writable : writable // ignore: cast_nullable_to_non_nullable
as bool,selected: null == selected ? _self.selected : selected // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$CalendarEvent {

 String get id;@JsonKey(name: 'calendar_event_id') String get calendarEventId; String get provider;@JsonKey(name: 'provider_event_id') String get providerEventId;@JsonKey(name: 'calendar_id') String get calendarId;@JsonKey(name: 'calendar_name') String get calendarName; String get title; String get description; String get location; String get start; String get end;@JsonKey(name: 'all_day') bool get allDay; String get status; String get updated;
/// Create a copy of CalendarEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CalendarEventCopyWith<CalendarEvent> get copyWith => _$CalendarEventCopyWithImpl<CalendarEvent>(this as CalendarEvent, _$identity);

  /// Serializes this CalendarEvent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CalendarEvent;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CalendarEvent&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.calendarEventId, _this.calendarEventId) || other.calendarEventId == _this.calendarEventId)&&(identical(other.provider, _this.provider) || other.provider == _this.provider)&&(identical(other.providerEventId, _this.providerEventId) || other.providerEventId == _this.providerEventId)&&(identical(other.calendarId, _this.calendarId) || other.calendarId == _this.calendarId)&&(identical(other.calendarName, _this.calendarName) || other.calendarName == _this.calendarName)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.location, _this.location) || other.location == _this.location)&&(identical(other.start, _this.start) || other.start == _this.start)&&(identical(other.end, _this.end) || other.end == _this.end)&&(identical(other.allDay, _this.allDay) || other.allDay == _this.allDay)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.updated, _this.updated) || other.updated == _this.updated));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CalendarEvent;
  return Object.hash(runtimeType,_this.id,_this.calendarEventId,_this.provider,_this.providerEventId,_this.calendarId,_this.calendarName,_this.title,_this.description,_this.location,_this.start,_this.end,_this.allDay,_this.status,_this.updated);
}

@override
String toString() {
  final _this = this as CalendarEvent;
  return 'CalendarEvent(id: ${_this.id}, calendarEventId: ${_this.calendarEventId}, provider: ${_this.provider}, providerEventId: ${_this.providerEventId}, calendarId: ${_this.calendarId}, calendarName: ${_this.calendarName}, title: ${_this.title}, description: ${_this.description}, location: ${_this.location}, start: ${_this.start}, end: ${_this.end}, allDay: ${_this.allDay}, status: ${_this.status}, updated: ${_this.updated})';
}


}

/// @nodoc
abstract mixin class $CalendarEventCopyWith<$Res>  {
  factory $CalendarEventCopyWith(CalendarEvent value, $Res Function(CalendarEvent) _then) = _$CalendarEventCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'calendar_event_id') String calendarEventId, String provider,@JsonKey(name: 'provider_event_id') String providerEventId,@JsonKey(name: 'calendar_id') String calendarId,@JsonKey(name: 'calendar_name') String calendarName, String title, String description, String location, String start, String end,@JsonKey(name: 'all_day') bool allDay, String status, String updated
});




}
/// @nodoc
class _$CalendarEventCopyWithImpl<$Res>
    implements $CalendarEventCopyWith<$Res> {
  _$CalendarEventCopyWithImpl(this._self, this._then);

  final CalendarEvent _self;
  final $Res Function(CalendarEvent) _then;

/// Create a copy of CalendarEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? calendarEventId = null,Object? provider = null,Object? providerEventId = null,Object? calendarId = null,Object? calendarName = null,Object? title = null,Object? description = null,Object? location = null,Object? start = null,Object? end = null,Object? allDay = null,Object? status = null,Object? updated = null,}) {
  return _then(CalendarEvent(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,calendarEventId: null == calendarEventId ? _self.calendarEventId : calendarEventId // ignore: cast_nullable_to_non_nullable
as String,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,providerEventId: null == providerEventId ? _self.providerEventId : providerEventId // ignore: cast_nullable_to_non_nullable
as String,calendarId: null == calendarId ? _self.calendarId : calendarId // ignore: cast_nullable_to_non_nullable
as String,calendarName: null == calendarName ? _self.calendarName : calendarName // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as String,end: null == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as String,allDay: null == allDay ? _self.allDay : allDay // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,updated: null == updated ? _self.updated : updated // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [CalendarEvent].
extension CalendarEventPatterns on CalendarEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CalendarEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CalendarEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CalendarEvent value)  $default,){
final _that = this;
switch (_that) {
case _CalendarEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CalendarEvent value)?  $default,){
final _that = this;
switch (_that) {
case _CalendarEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'calendar_event_id')  String calendarEventId,  String provider, @JsonKey(name: 'provider_event_id')  String providerEventId, @JsonKey(name: 'calendar_id')  String calendarId, @JsonKey(name: 'calendar_name')  String calendarName,  String title,  String description,  String location,  String start,  String end, @JsonKey(name: 'all_day')  bool allDay,  String status,  String updated)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CalendarEvent() when $default != null:
return $default(_that.id,_that.calendarEventId,_that.provider,_that.providerEventId,_that.calendarId,_that.calendarName,_that.title,_that.description,_that.location,_that.start,_that.end,_that.allDay,_that.status,_that.updated);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'calendar_event_id')  String calendarEventId,  String provider, @JsonKey(name: 'provider_event_id')  String providerEventId, @JsonKey(name: 'calendar_id')  String calendarId, @JsonKey(name: 'calendar_name')  String calendarName,  String title,  String description,  String location,  String start,  String end, @JsonKey(name: 'all_day')  bool allDay,  String status,  String updated)  $default,) {final _that = this;
switch (_that) {
case _CalendarEvent():
return $default(_that.id,_that.calendarEventId,_that.provider,_that.providerEventId,_that.calendarId,_that.calendarName,_that.title,_that.description,_that.location,_that.start,_that.end,_that.allDay,_that.status,_that.updated);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'calendar_event_id')  String calendarEventId,  String provider, @JsonKey(name: 'provider_event_id')  String providerEventId, @JsonKey(name: 'calendar_id')  String calendarId, @JsonKey(name: 'calendar_name')  String calendarName,  String title,  String description,  String location,  String start,  String end, @JsonKey(name: 'all_day')  bool allDay,  String status,  String updated)?  $default,) {final _that = this;
switch (_that) {
case _CalendarEvent() when $default != null:
return $default(_that.id,_that.calendarEventId,_that.provider,_that.providerEventId,_that.calendarId,_that.calendarName,_that.title,_that.description,_that.location,_that.start,_that.end,_that.allDay,_that.status,_that.updated);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CalendarEvent implements CalendarEvent {
  const _CalendarEvent({this.id = '', @JsonKey(name: 'calendar_event_id') this.calendarEventId = '', this.provider = '', @JsonKey(name: 'provider_event_id') this.providerEventId = '', @JsonKey(name: 'calendar_id') this.calendarId = '', @JsonKey(name: 'calendar_name') this.calendarName = '', this.title = '', this.description = '', this.location = '', this.start = '', this.end = '', @JsonKey(name: 'all_day') this.allDay = false, this.status = '', this.updated = ''});
  factory _CalendarEvent.fromJson(Map<String, dynamic> json) => _$CalendarEventFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey(name: 'calendar_event_id') final  String calendarEventId;
@override@JsonKey() final  String provider;
@override@JsonKey(name: 'provider_event_id') final  String providerEventId;
@override@JsonKey(name: 'calendar_id') final  String calendarId;
@override@JsonKey(name: 'calendar_name') final  String calendarName;
@override@JsonKey() final  String title;
@override@JsonKey() final  String description;
@override@JsonKey() final  String location;
@override@JsonKey() final  String start;
@override@JsonKey() final  String end;
@override@JsonKey(name: 'all_day') final  bool allDay;
@override@JsonKey() final  String status;
@override@JsonKey() final  String updated;

/// Create a copy of CalendarEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CalendarEventCopyWith<_CalendarEvent> get copyWith => __$CalendarEventCopyWithImpl<_CalendarEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CalendarEventToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CalendarEvent&&(identical(other.id, id) || other.id == id)&&(identical(other.calendarEventId, calendarEventId) || other.calendarEventId == calendarEventId)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.providerEventId, providerEventId) || other.providerEventId == providerEventId)&&(identical(other.calendarId, calendarId) || other.calendarId == calendarId)&&(identical(other.calendarName, calendarName) || other.calendarName == calendarName)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.location, location) || other.location == location)&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end)&&(identical(other.allDay, allDay) || other.allDay == allDay)&&(identical(other.status, status) || other.status == status)&&(identical(other.updated, updated) || other.updated == updated));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,calendarEventId,provider,providerEventId,calendarId,calendarName,title,description,location,start,end,allDay,status,updated);
}

@override
String toString() {
    return 'CalendarEvent(id: $id, calendarEventId: $calendarEventId, provider: $provider, providerEventId: $providerEventId, calendarId: $calendarId, calendarName: $calendarName, title: $title, description: $description, location: $location, start: $start, end: $end, allDay: $allDay, status: $status, updated: $updated)';
}


}

/// @nodoc
abstract mixin class _$CalendarEventCopyWith<$Res> implements $CalendarEventCopyWith<$Res> {
  factory _$CalendarEventCopyWith(_CalendarEvent value, $Res Function(_CalendarEvent) _then) = __$CalendarEventCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'calendar_event_id') String calendarEventId, String provider,@JsonKey(name: 'provider_event_id') String providerEventId,@JsonKey(name: 'calendar_id') String calendarId,@JsonKey(name: 'calendar_name') String calendarName, String title, String description, String location, String start, String end,@JsonKey(name: 'all_day') bool allDay, String status, String updated
});




}
/// @nodoc
class __$CalendarEventCopyWithImpl<$Res>
    implements _$CalendarEventCopyWith<$Res> {
  __$CalendarEventCopyWithImpl(this._self, this._then);

  final _CalendarEvent _self;
  final $Res Function(_CalendarEvent) _then;

/// Create a copy of CalendarEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? calendarEventId = null,Object? provider = null,Object? providerEventId = null,Object? calendarId = null,Object? calendarName = null,Object? title = null,Object? description = null,Object? location = null,Object? start = null,Object? end = null,Object? allDay = null,Object? status = null,Object? updated = null,}) {
  return _then(_CalendarEvent(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,calendarEventId: null == calendarEventId ? _self.calendarEventId : calendarEventId // ignore: cast_nullable_to_non_nullable
as String,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,providerEventId: null == providerEventId ? _self.providerEventId : providerEventId // ignore: cast_nullable_to_non_nullable
as String,calendarId: null == calendarId ? _self.calendarId : calendarId // ignore: cast_nullable_to_non_nullable
as String,calendarName: null == calendarName ? _self.calendarName : calendarName // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as String,end: null == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as String,allDay: null == allDay ? _self.allDay : allDay // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,updated: null == updated ? _self.updated : updated // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
