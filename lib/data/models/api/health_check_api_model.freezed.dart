// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'health_check_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HealthCheckResponse {

@JsonKey(name: 'system_health') bool get systemHealth;@JsonKey(name: 'simple_db_check') bool get dbCheck;@JsonKey(name: 'php_version') HealthCheckPhpResponse get phpVersion;@JsonKey(name: 'queue_data') HealthCheckQueueResponse get queueData; String get queue;@JsonKey(name: 'mail_mailer') String get emailDriver;@JsonKey(name: 'pdf_engine') String get pdfEngine;@JsonKey(name: 'file_permissions') String get filePermissions;@JsonKey(name: 'trailing_slash') bool get trailingSlash;@JsonKey(name: 'exchange_rate_api_not_configured') bool get exchangeRateApiNotConfigured;@JsonKey(name: 'pending_migrations') bool get pendingMigration;@JsonKey(name: 'cache_enabled') bool get cacheEnabled;@JsonKey(name: 'env_writable') bool get envWritable;@JsonKey(name: 'open_basedir') bool get openBasedir;@JsonKey(name: 'exec') bool get execEnabled;@JsonKey(name: 'phantom_enabled') bool get phantomEnabled;@JsonKey(name: 'is_docker') bool get isDocker;@JsonKey(name: 'jobs_pending') int get pendingJobs;
/// Create a copy of HealthCheckResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HealthCheckResponseCopyWith<HealthCheckResponse> get copyWith => _$HealthCheckResponseCopyWithImpl<HealthCheckResponse>(this as HealthCheckResponse, _$identity);

  /// Serializes this HealthCheckResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as HealthCheckResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HealthCheckResponse&&(identical(other.systemHealth, _this.systemHealth) || other.systemHealth == _this.systemHealth)&&(identical(other.dbCheck, _this.dbCheck) || other.dbCheck == _this.dbCheck)&&(identical(other.phpVersion, _this.phpVersion) || other.phpVersion == _this.phpVersion)&&(identical(other.queueData, _this.queueData) || other.queueData == _this.queueData)&&(identical(other.queue, _this.queue) || other.queue == _this.queue)&&(identical(other.emailDriver, _this.emailDriver) || other.emailDriver == _this.emailDriver)&&(identical(other.pdfEngine, _this.pdfEngine) || other.pdfEngine == _this.pdfEngine)&&(identical(other.filePermissions, _this.filePermissions) || other.filePermissions == _this.filePermissions)&&(identical(other.trailingSlash, _this.trailingSlash) || other.trailingSlash == _this.trailingSlash)&&(identical(other.exchangeRateApiNotConfigured, _this.exchangeRateApiNotConfigured) || other.exchangeRateApiNotConfigured == _this.exchangeRateApiNotConfigured)&&(identical(other.pendingMigration, _this.pendingMigration) || other.pendingMigration == _this.pendingMigration)&&(identical(other.cacheEnabled, _this.cacheEnabled) || other.cacheEnabled == _this.cacheEnabled)&&(identical(other.envWritable, _this.envWritable) || other.envWritable == _this.envWritable)&&(identical(other.openBasedir, _this.openBasedir) || other.openBasedir == _this.openBasedir)&&(identical(other.execEnabled, _this.execEnabled) || other.execEnabled == _this.execEnabled)&&(identical(other.phantomEnabled, _this.phantomEnabled) || other.phantomEnabled == _this.phantomEnabled)&&(identical(other.isDocker, _this.isDocker) || other.isDocker == _this.isDocker)&&(identical(other.pendingJobs, _this.pendingJobs) || other.pendingJobs == _this.pendingJobs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as HealthCheckResponse;
  return Object.hash(runtimeType,_this.systemHealth,_this.dbCheck,_this.phpVersion,_this.queueData,_this.queue,_this.emailDriver,_this.pdfEngine,_this.filePermissions,_this.trailingSlash,_this.exchangeRateApiNotConfigured,_this.pendingMigration,_this.cacheEnabled,_this.envWritable,_this.openBasedir,_this.execEnabled,_this.phantomEnabled,_this.isDocker,_this.pendingJobs);
}

@override
String toString() {
  final _this = this as HealthCheckResponse;
  return 'HealthCheckResponse(systemHealth: ${_this.systemHealth}, dbCheck: ${_this.dbCheck}, phpVersion: ${_this.phpVersion}, queueData: ${_this.queueData}, queue: ${_this.queue}, emailDriver: ${_this.emailDriver}, pdfEngine: ${_this.pdfEngine}, filePermissions: ${_this.filePermissions}, trailingSlash: ${_this.trailingSlash}, exchangeRateApiNotConfigured: ${_this.exchangeRateApiNotConfigured}, pendingMigration: ${_this.pendingMigration}, cacheEnabled: ${_this.cacheEnabled}, envWritable: ${_this.envWritable}, openBasedir: ${_this.openBasedir}, execEnabled: ${_this.execEnabled}, phantomEnabled: ${_this.phantomEnabled}, isDocker: ${_this.isDocker}, pendingJobs: ${_this.pendingJobs})';
}


}

/// @nodoc
abstract mixin class $HealthCheckResponseCopyWith<$Res>  {
  factory $HealthCheckResponseCopyWith(HealthCheckResponse value, $Res Function(HealthCheckResponse) _then) = _$HealthCheckResponseCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'system_health') bool systemHealth,@JsonKey(name: 'simple_db_check') bool dbCheck,@JsonKey(name: 'php_version') HealthCheckPhpResponse phpVersion,@JsonKey(name: 'queue_data') HealthCheckQueueResponse queueData, String queue,@JsonKey(name: 'mail_mailer') String emailDriver,@JsonKey(name: 'pdf_engine') String pdfEngine,@JsonKey(name: 'file_permissions') String filePermissions,@JsonKey(name: 'trailing_slash') bool trailingSlash,@JsonKey(name: 'exchange_rate_api_not_configured') bool exchangeRateApiNotConfigured,@JsonKey(name: 'pending_migrations') bool pendingMigration,@JsonKey(name: 'cache_enabled') bool cacheEnabled,@JsonKey(name: 'env_writable') bool envWritable,@JsonKey(name: 'open_basedir') bool openBasedir,@JsonKey(name: 'exec') bool execEnabled,@JsonKey(name: 'phantom_enabled') bool phantomEnabled,@JsonKey(name: 'is_docker') bool isDocker,@JsonKey(name: 'jobs_pending') int pendingJobs
});


$HealthCheckPhpResponseCopyWith<$Res> get phpVersion;$HealthCheckQueueResponseCopyWith<$Res> get queueData;

}
/// @nodoc
class _$HealthCheckResponseCopyWithImpl<$Res>
    implements $HealthCheckResponseCopyWith<$Res> {
  _$HealthCheckResponseCopyWithImpl(this._self, this._then);

  final HealthCheckResponse _self;
  final $Res Function(HealthCheckResponse) _then;

/// Create a copy of HealthCheckResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? systemHealth = null,Object? dbCheck = null,Object? phpVersion = null,Object? queueData = null,Object? queue = null,Object? emailDriver = null,Object? pdfEngine = null,Object? filePermissions = null,Object? trailingSlash = null,Object? exchangeRateApiNotConfigured = null,Object? pendingMigration = null,Object? cacheEnabled = null,Object? envWritable = null,Object? openBasedir = null,Object? execEnabled = null,Object? phantomEnabled = null,Object? isDocker = null,Object? pendingJobs = null,}) {
  return _then(HealthCheckResponse(
systemHealth: null == systemHealth ? _self.systemHealth : systemHealth // ignore: cast_nullable_to_non_nullable
as bool,dbCheck: null == dbCheck ? _self.dbCheck : dbCheck // ignore: cast_nullable_to_non_nullable
as bool,phpVersion: null == phpVersion ? _self.phpVersion : phpVersion // ignore: cast_nullable_to_non_nullable
as HealthCheckPhpResponse,queueData: null == queueData ? _self.queueData : queueData // ignore: cast_nullable_to_non_nullable
as HealthCheckQueueResponse,queue: null == queue ? _self.queue : queue // ignore: cast_nullable_to_non_nullable
as String,emailDriver: null == emailDriver ? _self.emailDriver : emailDriver // ignore: cast_nullable_to_non_nullable
as String,pdfEngine: null == pdfEngine ? _self.pdfEngine : pdfEngine // ignore: cast_nullable_to_non_nullable
as String,filePermissions: null == filePermissions ? _self.filePermissions : filePermissions // ignore: cast_nullable_to_non_nullable
as String,trailingSlash: null == trailingSlash ? _self.trailingSlash : trailingSlash // ignore: cast_nullable_to_non_nullable
as bool,exchangeRateApiNotConfigured: null == exchangeRateApiNotConfigured ? _self.exchangeRateApiNotConfigured : exchangeRateApiNotConfigured // ignore: cast_nullable_to_non_nullable
as bool,pendingMigration: null == pendingMigration ? _self.pendingMigration : pendingMigration // ignore: cast_nullable_to_non_nullable
as bool,cacheEnabled: null == cacheEnabled ? _self.cacheEnabled : cacheEnabled // ignore: cast_nullable_to_non_nullable
as bool,envWritable: null == envWritable ? _self.envWritable : envWritable // ignore: cast_nullable_to_non_nullable
as bool,openBasedir: null == openBasedir ? _self.openBasedir : openBasedir // ignore: cast_nullable_to_non_nullable
as bool,execEnabled: null == execEnabled ? _self.execEnabled : execEnabled // ignore: cast_nullable_to_non_nullable
as bool,phantomEnabled: null == phantomEnabled ? _self.phantomEnabled : phantomEnabled // ignore: cast_nullable_to_non_nullable
as bool,isDocker: null == isDocker ? _self.isDocker : isDocker // ignore: cast_nullable_to_non_nullable
as bool,pendingJobs: null == pendingJobs ? _self.pendingJobs : pendingJobs // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of HealthCheckResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$HealthCheckPhpResponseCopyWith<$Res> get phpVersion {
  
  return $HealthCheckPhpResponseCopyWith<$Res>(_self.phpVersion, (value) {
    return _then(_self.copyWith(phpVersion: value));
  });
}/// Create a copy of HealthCheckResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$HealthCheckQueueResponseCopyWith<$Res> get queueData {
  
  return $HealthCheckQueueResponseCopyWith<$Res>(_self.queueData, (value) {
    return _then(_self.copyWith(queueData: value));
  });
}
}


/// Adds pattern-matching-related methods to [HealthCheckResponse].
extension HealthCheckResponsePatterns on HealthCheckResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HealthCheckResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HealthCheckResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HealthCheckResponse value)  $default,){
final _that = this;
switch (_that) {
case _HealthCheckResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HealthCheckResponse value)?  $default,){
final _that = this;
switch (_that) {
case _HealthCheckResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'system_health')  bool systemHealth, @JsonKey(name: 'simple_db_check')  bool dbCheck, @JsonKey(name: 'php_version')  HealthCheckPhpResponse phpVersion, @JsonKey(name: 'queue_data')  HealthCheckQueueResponse queueData,  String queue, @JsonKey(name: 'mail_mailer')  String emailDriver, @JsonKey(name: 'pdf_engine')  String pdfEngine, @JsonKey(name: 'file_permissions')  String filePermissions, @JsonKey(name: 'trailing_slash')  bool trailingSlash, @JsonKey(name: 'exchange_rate_api_not_configured')  bool exchangeRateApiNotConfigured, @JsonKey(name: 'pending_migrations')  bool pendingMigration, @JsonKey(name: 'cache_enabled')  bool cacheEnabled, @JsonKey(name: 'env_writable')  bool envWritable, @JsonKey(name: 'open_basedir')  bool openBasedir, @JsonKey(name: 'exec')  bool execEnabled, @JsonKey(name: 'phantom_enabled')  bool phantomEnabled, @JsonKey(name: 'is_docker')  bool isDocker, @JsonKey(name: 'jobs_pending')  int pendingJobs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HealthCheckResponse() when $default != null:
return $default(_that.systemHealth,_that.dbCheck,_that.phpVersion,_that.queueData,_that.queue,_that.emailDriver,_that.pdfEngine,_that.filePermissions,_that.trailingSlash,_that.exchangeRateApiNotConfigured,_that.pendingMigration,_that.cacheEnabled,_that.envWritable,_that.openBasedir,_that.execEnabled,_that.phantomEnabled,_that.isDocker,_that.pendingJobs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'system_health')  bool systemHealth, @JsonKey(name: 'simple_db_check')  bool dbCheck, @JsonKey(name: 'php_version')  HealthCheckPhpResponse phpVersion, @JsonKey(name: 'queue_data')  HealthCheckQueueResponse queueData,  String queue, @JsonKey(name: 'mail_mailer')  String emailDriver, @JsonKey(name: 'pdf_engine')  String pdfEngine, @JsonKey(name: 'file_permissions')  String filePermissions, @JsonKey(name: 'trailing_slash')  bool trailingSlash, @JsonKey(name: 'exchange_rate_api_not_configured')  bool exchangeRateApiNotConfigured, @JsonKey(name: 'pending_migrations')  bool pendingMigration, @JsonKey(name: 'cache_enabled')  bool cacheEnabled, @JsonKey(name: 'env_writable')  bool envWritable, @JsonKey(name: 'open_basedir')  bool openBasedir, @JsonKey(name: 'exec')  bool execEnabled, @JsonKey(name: 'phantom_enabled')  bool phantomEnabled, @JsonKey(name: 'is_docker')  bool isDocker, @JsonKey(name: 'jobs_pending')  int pendingJobs)  $default,) {final _that = this;
switch (_that) {
case _HealthCheckResponse():
return $default(_that.systemHealth,_that.dbCheck,_that.phpVersion,_that.queueData,_that.queue,_that.emailDriver,_that.pdfEngine,_that.filePermissions,_that.trailingSlash,_that.exchangeRateApiNotConfigured,_that.pendingMigration,_that.cacheEnabled,_that.envWritable,_that.openBasedir,_that.execEnabled,_that.phantomEnabled,_that.isDocker,_that.pendingJobs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'system_health')  bool systemHealth, @JsonKey(name: 'simple_db_check')  bool dbCheck, @JsonKey(name: 'php_version')  HealthCheckPhpResponse phpVersion, @JsonKey(name: 'queue_data')  HealthCheckQueueResponse queueData,  String queue, @JsonKey(name: 'mail_mailer')  String emailDriver, @JsonKey(name: 'pdf_engine')  String pdfEngine, @JsonKey(name: 'file_permissions')  String filePermissions, @JsonKey(name: 'trailing_slash')  bool trailingSlash, @JsonKey(name: 'exchange_rate_api_not_configured')  bool exchangeRateApiNotConfigured, @JsonKey(name: 'pending_migrations')  bool pendingMigration, @JsonKey(name: 'cache_enabled')  bool cacheEnabled, @JsonKey(name: 'env_writable')  bool envWritable, @JsonKey(name: 'open_basedir')  bool openBasedir, @JsonKey(name: 'exec')  bool execEnabled, @JsonKey(name: 'phantom_enabled')  bool phantomEnabled, @JsonKey(name: 'is_docker')  bool isDocker, @JsonKey(name: 'jobs_pending')  int pendingJobs)?  $default,) {final _that = this;
switch (_that) {
case _HealthCheckResponse() when $default != null:
return $default(_that.systemHealth,_that.dbCheck,_that.phpVersion,_that.queueData,_that.queue,_that.emailDriver,_that.pdfEngine,_that.filePermissions,_that.trailingSlash,_that.exchangeRateApiNotConfigured,_that.pendingMigration,_that.cacheEnabled,_that.envWritable,_that.openBasedir,_that.execEnabled,_that.phantomEnabled,_that.isDocker,_that.pendingJobs);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _HealthCheckResponse implements HealthCheckResponse {
  const _HealthCheckResponse({@JsonKey(name: 'system_health') this.systemHealth = false, @JsonKey(name: 'simple_db_check') this.dbCheck = false, @JsonKey(name: 'php_version') this.phpVersion = const HealthCheckPhpResponse(), @JsonKey(name: 'queue_data') this.queueData = const HealthCheckQueueResponse(), this.queue = '', @JsonKey(name: 'mail_mailer') this.emailDriver = '', @JsonKey(name: 'pdf_engine') this.pdfEngine = '', @JsonKey(name: 'file_permissions') this.filePermissions = '', @JsonKey(name: 'trailing_slash') this.trailingSlash = false, @JsonKey(name: 'exchange_rate_api_not_configured') this.exchangeRateApiNotConfigured = false, @JsonKey(name: 'pending_migrations') this.pendingMigration = false, @JsonKey(name: 'cache_enabled') this.cacheEnabled = false, @JsonKey(name: 'env_writable') this.envWritable = false, @JsonKey(name: 'open_basedir') this.openBasedir = false, @JsonKey(name: 'exec') this.execEnabled = false, @JsonKey(name: 'phantom_enabled') this.phantomEnabled = false, @JsonKey(name: 'is_docker') this.isDocker = false, @JsonKey(name: 'jobs_pending') this.pendingJobs = 0});
  factory _HealthCheckResponse.fromJson(Map<String, dynamic> json) => _$HealthCheckResponseFromJson(json);

@override@JsonKey(name: 'system_health') final  bool systemHealth;
@override@JsonKey(name: 'simple_db_check') final  bool dbCheck;
@override@JsonKey(name: 'php_version') final  HealthCheckPhpResponse phpVersion;
@override@JsonKey(name: 'queue_data') final  HealthCheckQueueResponse queueData;
@override@JsonKey() final  String queue;
@override@JsonKey(name: 'mail_mailer') final  String emailDriver;
@override@JsonKey(name: 'pdf_engine') final  String pdfEngine;
@override@JsonKey(name: 'file_permissions') final  String filePermissions;
@override@JsonKey(name: 'trailing_slash') final  bool trailingSlash;
@override@JsonKey(name: 'exchange_rate_api_not_configured') final  bool exchangeRateApiNotConfigured;
@override@JsonKey(name: 'pending_migrations') final  bool pendingMigration;
@override@JsonKey(name: 'cache_enabled') final  bool cacheEnabled;
@override@JsonKey(name: 'env_writable') final  bool envWritable;
@override@JsonKey(name: 'open_basedir') final  bool openBasedir;
@override@JsonKey(name: 'exec') final  bool execEnabled;
@override@JsonKey(name: 'phantom_enabled') final  bool phantomEnabled;
@override@JsonKey(name: 'is_docker') final  bool isDocker;
@override@JsonKey(name: 'jobs_pending') final  int pendingJobs;

/// Create a copy of HealthCheckResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HealthCheckResponseCopyWith<_HealthCheckResponse> get copyWith => __$HealthCheckResponseCopyWithImpl<_HealthCheckResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HealthCheckResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _HealthCheckResponse&&(identical(other.systemHealth, systemHealth) || other.systemHealth == systemHealth)&&(identical(other.dbCheck, dbCheck) || other.dbCheck == dbCheck)&&(identical(other.phpVersion, phpVersion) || other.phpVersion == phpVersion)&&(identical(other.queueData, queueData) || other.queueData == queueData)&&(identical(other.queue, queue) || other.queue == queue)&&(identical(other.emailDriver, emailDriver) || other.emailDriver == emailDriver)&&(identical(other.pdfEngine, pdfEngine) || other.pdfEngine == pdfEngine)&&(identical(other.filePermissions, filePermissions) || other.filePermissions == filePermissions)&&(identical(other.trailingSlash, trailingSlash) || other.trailingSlash == trailingSlash)&&(identical(other.exchangeRateApiNotConfigured, exchangeRateApiNotConfigured) || other.exchangeRateApiNotConfigured == exchangeRateApiNotConfigured)&&(identical(other.pendingMigration, pendingMigration) || other.pendingMigration == pendingMigration)&&(identical(other.cacheEnabled, cacheEnabled) || other.cacheEnabled == cacheEnabled)&&(identical(other.envWritable, envWritable) || other.envWritable == envWritable)&&(identical(other.openBasedir, openBasedir) || other.openBasedir == openBasedir)&&(identical(other.execEnabled, execEnabled) || other.execEnabled == execEnabled)&&(identical(other.phantomEnabled, phantomEnabled) || other.phantomEnabled == phantomEnabled)&&(identical(other.isDocker, isDocker) || other.isDocker == isDocker)&&(identical(other.pendingJobs, pendingJobs) || other.pendingJobs == pendingJobs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,systemHealth,dbCheck,phpVersion,queueData,queue,emailDriver,pdfEngine,filePermissions,trailingSlash,exchangeRateApiNotConfigured,pendingMigration,cacheEnabled,envWritable,openBasedir,execEnabled,phantomEnabled,isDocker,pendingJobs);
}

@override
String toString() {
    return 'HealthCheckResponse(systemHealth: $systemHealth, dbCheck: $dbCheck, phpVersion: $phpVersion, queueData: $queueData, queue: $queue, emailDriver: $emailDriver, pdfEngine: $pdfEngine, filePermissions: $filePermissions, trailingSlash: $trailingSlash, exchangeRateApiNotConfigured: $exchangeRateApiNotConfigured, pendingMigration: $pendingMigration, cacheEnabled: $cacheEnabled, envWritable: $envWritable, openBasedir: $openBasedir, execEnabled: $execEnabled, phantomEnabled: $phantomEnabled, isDocker: $isDocker, pendingJobs: $pendingJobs)';
}


}

/// @nodoc
abstract mixin class _$HealthCheckResponseCopyWith<$Res> implements $HealthCheckResponseCopyWith<$Res> {
  factory _$HealthCheckResponseCopyWith(_HealthCheckResponse value, $Res Function(_HealthCheckResponse) _then) = __$HealthCheckResponseCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'system_health') bool systemHealth,@JsonKey(name: 'simple_db_check') bool dbCheck,@JsonKey(name: 'php_version') HealthCheckPhpResponse phpVersion,@JsonKey(name: 'queue_data') HealthCheckQueueResponse queueData, String queue,@JsonKey(name: 'mail_mailer') String emailDriver,@JsonKey(name: 'pdf_engine') String pdfEngine,@JsonKey(name: 'file_permissions') String filePermissions,@JsonKey(name: 'trailing_slash') bool trailingSlash,@JsonKey(name: 'exchange_rate_api_not_configured') bool exchangeRateApiNotConfigured,@JsonKey(name: 'pending_migrations') bool pendingMigration,@JsonKey(name: 'cache_enabled') bool cacheEnabled,@JsonKey(name: 'env_writable') bool envWritable,@JsonKey(name: 'open_basedir') bool openBasedir,@JsonKey(name: 'exec') bool execEnabled,@JsonKey(name: 'phantom_enabled') bool phantomEnabled,@JsonKey(name: 'is_docker') bool isDocker,@JsonKey(name: 'jobs_pending') int pendingJobs
});


@override $HealthCheckPhpResponseCopyWith<$Res> get phpVersion;@override $HealthCheckQueueResponseCopyWith<$Res> get queueData;

}
/// @nodoc
class __$HealthCheckResponseCopyWithImpl<$Res>
    implements _$HealthCheckResponseCopyWith<$Res> {
  __$HealthCheckResponseCopyWithImpl(this._self, this._then);

  final _HealthCheckResponse _self;
  final $Res Function(_HealthCheckResponse) _then;

/// Create a copy of HealthCheckResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? systemHealth = null,Object? dbCheck = null,Object? phpVersion = null,Object? queueData = null,Object? queue = null,Object? emailDriver = null,Object? pdfEngine = null,Object? filePermissions = null,Object? trailingSlash = null,Object? exchangeRateApiNotConfigured = null,Object? pendingMigration = null,Object? cacheEnabled = null,Object? envWritable = null,Object? openBasedir = null,Object? execEnabled = null,Object? phantomEnabled = null,Object? isDocker = null,Object? pendingJobs = null,}) {
  return _then(_HealthCheckResponse(
systemHealth: null == systemHealth ? _self.systemHealth : systemHealth // ignore: cast_nullable_to_non_nullable
as bool,dbCheck: null == dbCheck ? _self.dbCheck : dbCheck // ignore: cast_nullable_to_non_nullable
as bool,phpVersion: null == phpVersion ? _self.phpVersion : phpVersion // ignore: cast_nullable_to_non_nullable
as HealthCheckPhpResponse,queueData: null == queueData ? _self.queueData : queueData // ignore: cast_nullable_to_non_nullable
as HealthCheckQueueResponse,queue: null == queue ? _self.queue : queue // ignore: cast_nullable_to_non_nullable
as String,emailDriver: null == emailDriver ? _self.emailDriver : emailDriver // ignore: cast_nullable_to_non_nullable
as String,pdfEngine: null == pdfEngine ? _self.pdfEngine : pdfEngine // ignore: cast_nullable_to_non_nullable
as String,filePermissions: null == filePermissions ? _self.filePermissions : filePermissions // ignore: cast_nullable_to_non_nullable
as String,trailingSlash: null == trailingSlash ? _self.trailingSlash : trailingSlash // ignore: cast_nullable_to_non_nullable
as bool,exchangeRateApiNotConfigured: null == exchangeRateApiNotConfigured ? _self.exchangeRateApiNotConfigured : exchangeRateApiNotConfigured // ignore: cast_nullable_to_non_nullable
as bool,pendingMigration: null == pendingMigration ? _self.pendingMigration : pendingMigration // ignore: cast_nullable_to_non_nullable
as bool,cacheEnabled: null == cacheEnabled ? _self.cacheEnabled : cacheEnabled // ignore: cast_nullable_to_non_nullable
as bool,envWritable: null == envWritable ? _self.envWritable : envWritable // ignore: cast_nullable_to_non_nullable
as bool,openBasedir: null == openBasedir ? _self.openBasedir : openBasedir // ignore: cast_nullable_to_non_nullable
as bool,execEnabled: null == execEnabled ? _self.execEnabled : execEnabled // ignore: cast_nullable_to_non_nullable
as bool,phantomEnabled: null == phantomEnabled ? _self.phantomEnabled : phantomEnabled // ignore: cast_nullable_to_non_nullable
as bool,isDocker: null == isDocker ? _self.isDocker : isDocker // ignore: cast_nullable_to_non_nullable
as bool,pendingJobs: null == pendingJobs ? _self.pendingJobs : pendingJobs // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of HealthCheckResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$HealthCheckPhpResponseCopyWith<$Res> get phpVersion {
  
  return $HealthCheckPhpResponseCopyWith<$Res>(_self.phpVersion, (value) {
    return _then(_self.copyWith(phpVersion: value));
  });
}/// Create a copy of HealthCheckResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$HealthCheckQueueResponseCopyWith<$Res> get queueData {
  
  return $HealthCheckQueueResponseCopyWith<$Res>(_self.queueData, (value) {
    return _then(_self.copyWith(queueData: value));
  });
}
}


/// @nodoc
mixin _$HealthCheckPhpResponse {

@JsonKey(name: 'current_php_version') String get currentPhpVersion;@JsonKey(name: 'current_php_cli_version') String get currentPhpCliVersion;@JsonKey(name: 'minimum_php_version') String get minimumPhpVersion;@JsonKey(name: 'is_okay') bool get isOkay;@JsonKey(name: 'memory_limit') String get memoryLimit;
/// Create a copy of HealthCheckPhpResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HealthCheckPhpResponseCopyWith<HealthCheckPhpResponse> get copyWith => _$HealthCheckPhpResponseCopyWithImpl<HealthCheckPhpResponse>(this as HealthCheckPhpResponse, _$identity);

  /// Serializes this HealthCheckPhpResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as HealthCheckPhpResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HealthCheckPhpResponse&&(identical(other.currentPhpVersion, _this.currentPhpVersion) || other.currentPhpVersion == _this.currentPhpVersion)&&(identical(other.currentPhpCliVersion, _this.currentPhpCliVersion) || other.currentPhpCliVersion == _this.currentPhpCliVersion)&&(identical(other.minimumPhpVersion, _this.minimumPhpVersion) || other.minimumPhpVersion == _this.minimumPhpVersion)&&(identical(other.isOkay, _this.isOkay) || other.isOkay == _this.isOkay)&&(identical(other.memoryLimit, _this.memoryLimit) || other.memoryLimit == _this.memoryLimit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as HealthCheckPhpResponse;
  return Object.hash(runtimeType,_this.currentPhpVersion,_this.currentPhpCliVersion,_this.minimumPhpVersion,_this.isOkay,_this.memoryLimit);
}

@override
String toString() {
  final _this = this as HealthCheckPhpResponse;
  return 'HealthCheckPhpResponse(currentPhpVersion: ${_this.currentPhpVersion}, currentPhpCliVersion: ${_this.currentPhpCliVersion}, minimumPhpVersion: ${_this.minimumPhpVersion}, isOkay: ${_this.isOkay}, memoryLimit: ${_this.memoryLimit})';
}


}

/// @nodoc
abstract mixin class $HealthCheckPhpResponseCopyWith<$Res>  {
  factory $HealthCheckPhpResponseCopyWith(HealthCheckPhpResponse value, $Res Function(HealthCheckPhpResponse) _then) = _$HealthCheckPhpResponseCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'current_php_version') String currentPhpVersion,@JsonKey(name: 'current_php_cli_version') String currentPhpCliVersion,@JsonKey(name: 'minimum_php_version') String minimumPhpVersion,@JsonKey(name: 'is_okay') bool isOkay,@JsonKey(name: 'memory_limit') String memoryLimit
});




}
/// @nodoc
class _$HealthCheckPhpResponseCopyWithImpl<$Res>
    implements $HealthCheckPhpResponseCopyWith<$Res> {
  _$HealthCheckPhpResponseCopyWithImpl(this._self, this._then);

  final HealthCheckPhpResponse _self;
  final $Res Function(HealthCheckPhpResponse) _then;

/// Create a copy of HealthCheckPhpResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? currentPhpVersion = null,Object? currentPhpCliVersion = null,Object? minimumPhpVersion = null,Object? isOkay = null,Object? memoryLimit = null,}) {
  return _then(HealthCheckPhpResponse(
currentPhpVersion: null == currentPhpVersion ? _self.currentPhpVersion : currentPhpVersion // ignore: cast_nullable_to_non_nullable
as String,currentPhpCliVersion: null == currentPhpCliVersion ? _self.currentPhpCliVersion : currentPhpCliVersion // ignore: cast_nullable_to_non_nullable
as String,minimumPhpVersion: null == minimumPhpVersion ? _self.minimumPhpVersion : minimumPhpVersion // ignore: cast_nullable_to_non_nullable
as String,isOkay: null == isOkay ? _self.isOkay : isOkay // ignore: cast_nullable_to_non_nullable
as bool,memoryLimit: null == memoryLimit ? _self.memoryLimit : memoryLimit // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [HealthCheckPhpResponse].
extension HealthCheckPhpResponsePatterns on HealthCheckPhpResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HealthCheckPhpResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HealthCheckPhpResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HealthCheckPhpResponse value)  $default,){
final _that = this;
switch (_that) {
case _HealthCheckPhpResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HealthCheckPhpResponse value)?  $default,){
final _that = this;
switch (_that) {
case _HealthCheckPhpResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'current_php_version')  String currentPhpVersion, @JsonKey(name: 'current_php_cli_version')  String currentPhpCliVersion, @JsonKey(name: 'minimum_php_version')  String minimumPhpVersion, @JsonKey(name: 'is_okay')  bool isOkay, @JsonKey(name: 'memory_limit')  String memoryLimit)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HealthCheckPhpResponse() when $default != null:
return $default(_that.currentPhpVersion,_that.currentPhpCliVersion,_that.minimumPhpVersion,_that.isOkay,_that.memoryLimit);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'current_php_version')  String currentPhpVersion, @JsonKey(name: 'current_php_cli_version')  String currentPhpCliVersion, @JsonKey(name: 'minimum_php_version')  String minimumPhpVersion, @JsonKey(name: 'is_okay')  bool isOkay, @JsonKey(name: 'memory_limit')  String memoryLimit)  $default,) {final _that = this;
switch (_that) {
case _HealthCheckPhpResponse():
return $default(_that.currentPhpVersion,_that.currentPhpCliVersion,_that.minimumPhpVersion,_that.isOkay,_that.memoryLimit);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'current_php_version')  String currentPhpVersion, @JsonKey(name: 'current_php_cli_version')  String currentPhpCliVersion, @JsonKey(name: 'minimum_php_version')  String minimumPhpVersion, @JsonKey(name: 'is_okay')  bool isOkay, @JsonKey(name: 'memory_limit')  String memoryLimit)?  $default,) {final _that = this;
switch (_that) {
case _HealthCheckPhpResponse() when $default != null:
return $default(_that.currentPhpVersion,_that.currentPhpCliVersion,_that.minimumPhpVersion,_that.isOkay,_that.memoryLimit);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _HealthCheckPhpResponse implements HealthCheckPhpResponse {
  const _HealthCheckPhpResponse({@JsonKey(name: 'current_php_version') this.currentPhpVersion = '', @JsonKey(name: 'current_php_cli_version') this.currentPhpCliVersion = '', @JsonKey(name: 'minimum_php_version') this.minimumPhpVersion = '', @JsonKey(name: 'is_okay') this.isOkay = false, @JsonKey(name: 'memory_limit') this.memoryLimit = ''});
  factory _HealthCheckPhpResponse.fromJson(Map<String, dynamic> json) => _$HealthCheckPhpResponseFromJson(json);

@override@JsonKey(name: 'current_php_version') final  String currentPhpVersion;
@override@JsonKey(name: 'current_php_cli_version') final  String currentPhpCliVersion;
@override@JsonKey(name: 'minimum_php_version') final  String minimumPhpVersion;
@override@JsonKey(name: 'is_okay') final  bool isOkay;
@override@JsonKey(name: 'memory_limit') final  String memoryLimit;

/// Create a copy of HealthCheckPhpResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HealthCheckPhpResponseCopyWith<_HealthCheckPhpResponse> get copyWith => __$HealthCheckPhpResponseCopyWithImpl<_HealthCheckPhpResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HealthCheckPhpResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _HealthCheckPhpResponse&&(identical(other.currentPhpVersion, currentPhpVersion) || other.currentPhpVersion == currentPhpVersion)&&(identical(other.currentPhpCliVersion, currentPhpCliVersion) || other.currentPhpCliVersion == currentPhpCliVersion)&&(identical(other.minimumPhpVersion, minimumPhpVersion) || other.minimumPhpVersion == minimumPhpVersion)&&(identical(other.isOkay, isOkay) || other.isOkay == isOkay)&&(identical(other.memoryLimit, memoryLimit) || other.memoryLimit == memoryLimit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,currentPhpVersion,currentPhpCliVersion,minimumPhpVersion,isOkay,memoryLimit);
}

@override
String toString() {
    return 'HealthCheckPhpResponse(currentPhpVersion: $currentPhpVersion, currentPhpCliVersion: $currentPhpCliVersion, minimumPhpVersion: $minimumPhpVersion, isOkay: $isOkay, memoryLimit: $memoryLimit)';
}


}

/// @nodoc
abstract mixin class _$HealthCheckPhpResponseCopyWith<$Res> implements $HealthCheckPhpResponseCopyWith<$Res> {
  factory _$HealthCheckPhpResponseCopyWith(_HealthCheckPhpResponse value, $Res Function(_HealthCheckPhpResponse) _then) = __$HealthCheckPhpResponseCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'current_php_version') String currentPhpVersion,@JsonKey(name: 'current_php_cli_version') String currentPhpCliVersion,@JsonKey(name: 'minimum_php_version') String minimumPhpVersion,@JsonKey(name: 'is_okay') bool isOkay,@JsonKey(name: 'memory_limit') String memoryLimit
});




}
/// @nodoc
class __$HealthCheckPhpResponseCopyWithImpl<$Res>
    implements _$HealthCheckPhpResponseCopyWith<$Res> {
  __$HealthCheckPhpResponseCopyWithImpl(this._self, this._then);

  final _HealthCheckPhpResponse _self;
  final $Res Function(_HealthCheckPhpResponse) _then;

/// Create a copy of HealthCheckPhpResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? currentPhpVersion = null,Object? currentPhpCliVersion = null,Object? minimumPhpVersion = null,Object? isOkay = null,Object? memoryLimit = null,}) {
  return _then(_HealthCheckPhpResponse(
currentPhpVersion: null == currentPhpVersion ? _self.currentPhpVersion : currentPhpVersion // ignore: cast_nullable_to_non_nullable
as String,currentPhpCliVersion: null == currentPhpCliVersion ? _self.currentPhpCliVersion : currentPhpCliVersion // ignore: cast_nullable_to_non_nullable
as String,minimumPhpVersion: null == minimumPhpVersion ? _self.minimumPhpVersion : minimumPhpVersion // ignore: cast_nullable_to_non_nullable
as String,isOkay: null == isOkay ? _self.isOkay : isOkay // ignore: cast_nullable_to_non_nullable
as bool,memoryLimit: null == memoryLimit ? _self.memoryLimit : memoryLimit // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$HealthCheckQueueResponse {

 int get pending; int get failed;@JsonKey(name: 'last_error') String get lastError;
/// Create a copy of HealthCheckQueueResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HealthCheckQueueResponseCopyWith<HealthCheckQueueResponse> get copyWith => _$HealthCheckQueueResponseCopyWithImpl<HealthCheckQueueResponse>(this as HealthCheckQueueResponse, _$identity);

  /// Serializes this HealthCheckQueueResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as HealthCheckQueueResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HealthCheckQueueResponse&&(identical(other.pending, _this.pending) || other.pending == _this.pending)&&(identical(other.failed, _this.failed) || other.failed == _this.failed)&&(identical(other.lastError, _this.lastError) || other.lastError == _this.lastError));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as HealthCheckQueueResponse;
  return Object.hash(runtimeType,_this.pending,_this.failed,_this.lastError);
}

@override
String toString() {
  final _this = this as HealthCheckQueueResponse;
  return 'HealthCheckQueueResponse(pending: ${_this.pending}, failed: ${_this.failed}, lastError: ${_this.lastError})';
}


}

/// @nodoc
abstract mixin class $HealthCheckQueueResponseCopyWith<$Res>  {
  factory $HealthCheckQueueResponseCopyWith(HealthCheckQueueResponse value, $Res Function(HealthCheckQueueResponse) _then) = _$HealthCheckQueueResponseCopyWithImpl;
@useResult
$Res call({
 int pending, int failed,@JsonKey(name: 'last_error') String lastError
});




}
/// @nodoc
class _$HealthCheckQueueResponseCopyWithImpl<$Res>
    implements $HealthCheckQueueResponseCopyWith<$Res> {
  _$HealthCheckQueueResponseCopyWithImpl(this._self, this._then);

  final HealthCheckQueueResponse _self;
  final $Res Function(HealthCheckQueueResponse) _then;

/// Create a copy of HealthCheckQueueResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pending = null,Object? failed = null,Object? lastError = null,}) {
  return _then(HealthCheckQueueResponse(
pending: null == pending ? _self.pending : pending // ignore: cast_nullable_to_non_nullable
as int,failed: null == failed ? _self.failed : failed // ignore: cast_nullable_to_non_nullable
as int,lastError: null == lastError ? _self.lastError : lastError // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [HealthCheckQueueResponse].
extension HealthCheckQueueResponsePatterns on HealthCheckQueueResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HealthCheckQueueResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HealthCheckQueueResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HealthCheckQueueResponse value)  $default,){
final _that = this;
switch (_that) {
case _HealthCheckQueueResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HealthCheckQueueResponse value)?  $default,){
final _that = this;
switch (_that) {
case _HealthCheckQueueResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int pending,  int failed, @JsonKey(name: 'last_error')  String lastError)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HealthCheckQueueResponse() when $default != null:
return $default(_that.pending,_that.failed,_that.lastError);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int pending,  int failed, @JsonKey(name: 'last_error')  String lastError)  $default,) {final _that = this;
switch (_that) {
case _HealthCheckQueueResponse():
return $default(_that.pending,_that.failed,_that.lastError);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int pending,  int failed, @JsonKey(name: 'last_error')  String lastError)?  $default,) {final _that = this;
switch (_that) {
case _HealthCheckQueueResponse() when $default != null:
return $default(_that.pending,_that.failed,_that.lastError);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _HealthCheckQueueResponse implements HealthCheckQueueResponse {
  const _HealthCheckQueueResponse({this.pending = 0, this.failed = 0, @JsonKey(name: 'last_error') this.lastError = ''});
  factory _HealthCheckQueueResponse.fromJson(Map<String, dynamic> json) => _$HealthCheckQueueResponseFromJson(json);

@override@JsonKey() final  int pending;
@override@JsonKey() final  int failed;
@override@JsonKey(name: 'last_error') final  String lastError;

/// Create a copy of HealthCheckQueueResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HealthCheckQueueResponseCopyWith<_HealthCheckQueueResponse> get copyWith => __$HealthCheckQueueResponseCopyWithImpl<_HealthCheckQueueResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HealthCheckQueueResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _HealthCheckQueueResponse&&(identical(other.pending, pending) || other.pending == pending)&&(identical(other.failed, failed) || other.failed == failed)&&(identical(other.lastError, lastError) || other.lastError == lastError));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,pending,failed,lastError);
}

@override
String toString() {
    return 'HealthCheckQueueResponse(pending: $pending, failed: $failed, lastError: $lastError)';
}


}

/// @nodoc
abstract mixin class _$HealthCheckQueueResponseCopyWith<$Res> implements $HealthCheckQueueResponseCopyWith<$Res> {
  factory _$HealthCheckQueueResponseCopyWith(_HealthCheckQueueResponse value, $Res Function(_HealthCheckQueueResponse) _then) = __$HealthCheckQueueResponseCopyWithImpl;
@override @useResult
$Res call({
 int pending, int failed,@JsonKey(name: 'last_error') String lastError
});




}
/// @nodoc
class __$HealthCheckQueueResponseCopyWithImpl<$Res>
    implements _$HealthCheckQueueResponseCopyWith<$Res> {
  __$HealthCheckQueueResponseCopyWithImpl(this._self, this._then);

  final _HealthCheckQueueResponse _self;
  final $Res Function(_HealthCheckQueueResponse) _then;

/// Create a copy of HealthCheckQueueResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pending = null,Object? failed = null,Object? lastError = null,}) {
  return _then(_HealthCheckQueueResponse(
pending: null == pending ? _self.pending : pending // ignore: cast_nullable_to_non_nullable
as int,failed: null == failed ? _self.failed : failed // ignore: cast_nullable_to_non_nullable
as int,lastError: null == lastError ? _self.lastError : lastError // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$HealthCheckLastErrorResponse {

@JsonKey(name: 'last_error') String get lastError;
/// Create a copy of HealthCheckLastErrorResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HealthCheckLastErrorResponseCopyWith<HealthCheckLastErrorResponse> get copyWith => _$HealthCheckLastErrorResponseCopyWithImpl<HealthCheckLastErrorResponse>(this as HealthCheckLastErrorResponse, _$identity);

  /// Serializes this HealthCheckLastErrorResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as HealthCheckLastErrorResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HealthCheckLastErrorResponse&&(identical(other.lastError, _this.lastError) || other.lastError == _this.lastError));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as HealthCheckLastErrorResponse;
  return Object.hash(runtimeType,_this.lastError);
}

@override
String toString() {
  final _this = this as HealthCheckLastErrorResponse;
  return 'HealthCheckLastErrorResponse(lastError: ${_this.lastError})';
}


}

/// @nodoc
abstract mixin class $HealthCheckLastErrorResponseCopyWith<$Res>  {
  factory $HealthCheckLastErrorResponseCopyWith(HealthCheckLastErrorResponse value, $Res Function(HealthCheckLastErrorResponse) _then) = _$HealthCheckLastErrorResponseCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'last_error') String lastError
});




}
/// @nodoc
class _$HealthCheckLastErrorResponseCopyWithImpl<$Res>
    implements $HealthCheckLastErrorResponseCopyWith<$Res> {
  _$HealthCheckLastErrorResponseCopyWithImpl(this._self, this._then);

  final HealthCheckLastErrorResponse _self;
  final $Res Function(HealthCheckLastErrorResponse) _then;

/// Create a copy of HealthCheckLastErrorResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? lastError = null,}) {
  return _then(HealthCheckLastErrorResponse(
lastError: null == lastError ? _self.lastError : lastError // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [HealthCheckLastErrorResponse].
extension HealthCheckLastErrorResponsePatterns on HealthCheckLastErrorResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HealthCheckLastErrorResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HealthCheckLastErrorResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HealthCheckLastErrorResponse value)  $default,){
final _that = this;
switch (_that) {
case _HealthCheckLastErrorResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HealthCheckLastErrorResponse value)?  $default,){
final _that = this;
switch (_that) {
case _HealthCheckLastErrorResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'last_error')  String lastError)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HealthCheckLastErrorResponse() when $default != null:
return $default(_that.lastError);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'last_error')  String lastError)  $default,) {final _that = this;
switch (_that) {
case _HealthCheckLastErrorResponse():
return $default(_that.lastError);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'last_error')  String lastError)?  $default,) {final _that = this;
switch (_that) {
case _HealthCheckLastErrorResponse() when $default != null:
return $default(_that.lastError);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _HealthCheckLastErrorResponse implements HealthCheckLastErrorResponse {
  const _HealthCheckLastErrorResponse({@JsonKey(name: 'last_error') this.lastError = ''});
  factory _HealthCheckLastErrorResponse.fromJson(Map<String, dynamic> json) => _$HealthCheckLastErrorResponseFromJson(json);

@override@JsonKey(name: 'last_error') final  String lastError;

/// Create a copy of HealthCheckLastErrorResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HealthCheckLastErrorResponseCopyWith<_HealthCheckLastErrorResponse> get copyWith => __$HealthCheckLastErrorResponseCopyWithImpl<_HealthCheckLastErrorResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HealthCheckLastErrorResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _HealthCheckLastErrorResponse&&(identical(other.lastError, lastError) || other.lastError == lastError));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,lastError);
}

@override
String toString() {
    return 'HealthCheckLastErrorResponse(lastError: $lastError)';
}


}

/// @nodoc
abstract mixin class _$HealthCheckLastErrorResponseCopyWith<$Res> implements $HealthCheckLastErrorResponseCopyWith<$Res> {
  factory _$HealthCheckLastErrorResponseCopyWith(_HealthCheckLastErrorResponse value, $Res Function(_HealthCheckLastErrorResponse) _then) = __$HealthCheckLastErrorResponseCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'last_error') String lastError
});




}
/// @nodoc
class __$HealthCheckLastErrorResponseCopyWithImpl<$Res>
    implements _$HealthCheckLastErrorResponseCopyWith<$Res> {
  __$HealthCheckLastErrorResponseCopyWithImpl(this._self, this._then);

  final _HealthCheckLastErrorResponse _self;
  final $Res Function(_HealthCheckLastErrorResponse) _then;

/// Create a copy of HealthCheckLastErrorResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? lastError = null,}) {
  return _then(_HealthCheckLastErrorResponse(
lastError: null == lastError ? _self.lastError : lastError // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
