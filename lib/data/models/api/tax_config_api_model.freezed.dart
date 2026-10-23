// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tax_config_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TaxConfigApi {

 String get version;@JsonKey(name: 'seller_subregion') String get sellerSubregion;@JsonKey(name: 'acts_as_sender') bool get actsAsSender;@JsonKey(name: 'acts_as_receiver') bool get actsAsReceiver; Map<String, TaxRegionApi> get regions;
/// Create a copy of TaxConfigApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaxConfigApiCopyWith<TaxConfigApi> get copyWith => _$TaxConfigApiCopyWithImpl<TaxConfigApi>(this as TaxConfigApi, _$identity);

  /// Serializes this TaxConfigApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TaxConfigApi;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaxConfigApi&&(identical(other.version, _this.version) || other.version == _this.version)&&(identical(other.sellerSubregion, _this.sellerSubregion) || other.sellerSubregion == _this.sellerSubregion)&&(identical(other.actsAsSender, _this.actsAsSender) || other.actsAsSender == _this.actsAsSender)&&(identical(other.actsAsReceiver, _this.actsAsReceiver) || other.actsAsReceiver == _this.actsAsReceiver)&&const DeepCollectionEquality().equals(other.regions, _this.regions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TaxConfigApi;
  return Object.hash(runtimeType,_this.version,_this.sellerSubregion,_this.actsAsSender,_this.actsAsReceiver,const DeepCollectionEquality().hash(_this.regions));
}

@override
String toString() {
  final _this = this as TaxConfigApi;
  return 'TaxConfigApi(version: ${_this.version}, sellerSubregion: ${_this.sellerSubregion}, actsAsSender: ${_this.actsAsSender}, actsAsReceiver: ${_this.actsAsReceiver}, regions: ${_this.regions})';
}


}

/// @nodoc
abstract mixin class $TaxConfigApiCopyWith<$Res>  {
  factory $TaxConfigApiCopyWith(TaxConfigApi value, $Res Function(TaxConfigApi) _then) = _$TaxConfigApiCopyWithImpl;
@useResult
$Res call({
 String version,@JsonKey(name: 'seller_subregion') String sellerSubregion,@JsonKey(name: 'acts_as_sender') bool actsAsSender,@JsonKey(name: 'acts_as_receiver') bool actsAsReceiver, Map<String, TaxRegionApi> regions
});




}
/// @nodoc
class _$TaxConfigApiCopyWithImpl<$Res>
    implements $TaxConfigApiCopyWith<$Res> {
  _$TaxConfigApiCopyWithImpl(this._self, this._then);

  final TaxConfigApi _self;
  final $Res Function(TaxConfigApi) _then;

/// Create a copy of TaxConfigApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? version = null,Object? sellerSubregion = null,Object? actsAsSender = null,Object? actsAsReceiver = null,Object? regions = null,}) {
  return _then(TaxConfigApi(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,sellerSubregion: null == sellerSubregion ? _self.sellerSubregion : sellerSubregion // ignore: cast_nullable_to_non_nullable
as String,actsAsSender: null == actsAsSender ? _self.actsAsSender : actsAsSender // ignore: cast_nullable_to_non_nullable
as bool,actsAsReceiver: null == actsAsReceiver ? _self.actsAsReceiver : actsAsReceiver // ignore: cast_nullable_to_non_nullable
as bool,regions: null == regions ? _self.regions : regions // ignore: cast_nullable_to_non_nullable
as Map<String, TaxRegionApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [TaxConfigApi].
extension TaxConfigApiPatterns on TaxConfigApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TaxConfigApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TaxConfigApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TaxConfigApi value)  $default,){
final _that = this;
switch (_that) {
case _TaxConfigApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TaxConfigApi value)?  $default,){
final _that = this;
switch (_that) {
case _TaxConfigApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String version, @JsonKey(name: 'seller_subregion')  String sellerSubregion, @JsonKey(name: 'acts_as_sender')  bool actsAsSender, @JsonKey(name: 'acts_as_receiver')  bool actsAsReceiver,  Map<String, TaxRegionApi> regions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaxConfigApi() when $default != null:
return $default(_that.version,_that.sellerSubregion,_that.actsAsSender,_that.actsAsReceiver,_that.regions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String version, @JsonKey(name: 'seller_subregion')  String sellerSubregion, @JsonKey(name: 'acts_as_sender')  bool actsAsSender, @JsonKey(name: 'acts_as_receiver')  bool actsAsReceiver,  Map<String, TaxRegionApi> regions)  $default,) {final _that = this;
switch (_that) {
case _TaxConfigApi():
return $default(_that.version,_that.sellerSubregion,_that.actsAsSender,_that.actsAsReceiver,_that.regions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String version, @JsonKey(name: 'seller_subregion')  String sellerSubregion, @JsonKey(name: 'acts_as_sender')  bool actsAsSender, @JsonKey(name: 'acts_as_receiver')  bool actsAsReceiver,  Map<String, TaxRegionApi> regions)?  $default,) {final _that = this;
switch (_that) {
case _TaxConfigApi() when $default != null:
return $default(_that.version,_that.sellerSubregion,_that.actsAsSender,_that.actsAsReceiver,_that.regions);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(includeIfNull: false)
class _TaxConfigApi implements TaxConfigApi {
  const _TaxConfigApi({this.version = '', @JsonKey(name: 'seller_subregion') this.sellerSubregion = '', @JsonKey(name: 'acts_as_sender') this.actsAsSender = false, @JsonKey(name: 'acts_as_receiver') this.actsAsReceiver = false,  Map<String, TaxRegionApi> regions = const <String, TaxRegionApi>{}}): _regions = regions;
  factory _TaxConfigApi.fromJson(Map<String, dynamic> json) => _$TaxConfigApiFromJson(json);

@override@JsonKey() final  String version;
@override@JsonKey(name: 'seller_subregion') final  String sellerSubregion;
@override@JsonKey(name: 'acts_as_sender') final  bool actsAsSender;
@override@JsonKey(name: 'acts_as_receiver') final  bool actsAsReceiver;
 final  Map<String, TaxRegionApi> _regions;
@override@JsonKey() Map<String, TaxRegionApi> get regions {
  if (_regions is EqualUnmodifiableMapView) return _regions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_regions);
}


/// Create a copy of TaxConfigApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaxConfigApiCopyWith<_TaxConfigApi> get copyWith => __$TaxConfigApiCopyWithImpl<_TaxConfigApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaxConfigApiToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaxConfigApi&&(identical(other.version, version) || other.version == version)&&(identical(other.sellerSubregion, sellerSubregion) || other.sellerSubregion == sellerSubregion)&&(identical(other.actsAsSender, actsAsSender) || other.actsAsSender == actsAsSender)&&(identical(other.actsAsReceiver, actsAsReceiver) || other.actsAsReceiver == actsAsReceiver)&&const DeepCollectionEquality().equals(other.regions, _regions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,version,sellerSubregion,actsAsSender,actsAsReceiver,const DeepCollectionEquality().hash(_regions));
}

@override
String toString() {
    return 'TaxConfigApi(version: $version, sellerSubregion: $sellerSubregion, actsAsSender: $actsAsSender, actsAsReceiver: $actsAsReceiver, regions: $regions)';
}


}

/// @nodoc
abstract mixin class _$TaxConfigApiCopyWith<$Res> implements $TaxConfigApiCopyWith<$Res> {
  factory _$TaxConfigApiCopyWith(_TaxConfigApi value, $Res Function(_TaxConfigApi) _then) = __$TaxConfigApiCopyWithImpl;
@override @useResult
$Res call({
 String version,@JsonKey(name: 'seller_subregion') String sellerSubregion,@JsonKey(name: 'acts_as_sender') bool actsAsSender,@JsonKey(name: 'acts_as_receiver') bool actsAsReceiver, Map<String, TaxRegionApi> regions
});




}
/// @nodoc
class __$TaxConfigApiCopyWithImpl<$Res>
    implements _$TaxConfigApiCopyWith<$Res> {
  __$TaxConfigApiCopyWithImpl(this._self, this._then);

  final _TaxConfigApi _self;
  final $Res Function(_TaxConfigApi) _then;

/// Create a copy of TaxConfigApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? version = null,Object? sellerSubregion = null,Object? actsAsSender = null,Object? actsAsReceiver = null,Object? regions = null,}) {
  return _then(_TaxConfigApi(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,sellerSubregion: null == sellerSubregion ? _self.sellerSubregion : sellerSubregion // ignore: cast_nullable_to_non_nullable
as String,actsAsSender: null == actsAsSender ? _self.actsAsSender : actsAsSender // ignore: cast_nullable_to_non_nullable
as bool,actsAsReceiver: null == actsAsReceiver ? _self.actsAsReceiver : actsAsReceiver // ignore: cast_nullable_to_non_nullable
as bool,regions: null == regions ? _self._regions : regions // ignore: cast_nullable_to_non_nullable
as Map<String, TaxRegionApi>,
  ));
}


}


/// @nodoc
mixin _$TaxRegionApi {

@JsonKey(name: 'tax_all_subregions') bool get taxAllSubregions;@JsonKey(name: 'tax_threshold') double get taxThreshold;@JsonKey(name: 'has_sales_above_threshold') bool get hasSalesAboveThreshold; Map<String, TaxSubregionApi> get subregions;
/// Create a copy of TaxRegionApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaxRegionApiCopyWith<TaxRegionApi> get copyWith => _$TaxRegionApiCopyWithImpl<TaxRegionApi>(this as TaxRegionApi, _$identity);

  /// Serializes this TaxRegionApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TaxRegionApi;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaxRegionApi&&(identical(other.taxAllSubregions, _this.taxAllSubregions) || other.taxAllSubregions == _this.taxAllSubregions)&&(identical(other.taxThreshold, _this.taxThreshold) || other.taxThreshold == _this.taxThreshold)&&(identical(other.hasSalesAboveThreshold, _this.hasSalesAboveThreshold) || other.hasSalesAboveThreshold == _this.hasSalesAboveThreshold)&&const DeepCollectionEquality().equals(other.subregions, _this.subregions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TaxRegionApi;
  return Object.hash(runtimeType,_this.taxAllSubregions,_this.taxThreshold,_this.hasSalesAboveThreshold,const DeepCollectionEquality().hash(_this.subregions));
}

@override
String toString() {
  final _this = this as TaxRegionApi;
  return 'TaxRegionApi(taxAllSubregions: ${_this.taxAllSubregions}, taxThreshold: ${_this.taxThreshold}, hasSalesAboveThreshold: ${_this.hasSalesAboveThreshold}, subregions: ${_this.subregions})';
}


}

/// @nodoc
abstract mixin class $TaxRegionApiCopyWith<$Res>  {
  factory $TaxRegionApiCopyWith(TaxRegionApi value, $Res Function(TaxRegionApi) _then) = _$TaxRegionApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'tax_all_subregions') bool taxAllSubregions,@JsonKey(name: 'tax_threshold') double taxThreshold,@JsonKey(name: 'has_sales_above_threshold') bool hasSalesAboveThreshold, Map<String, TaxSubregionApi> subregions
});




}
/// @nodoc
class _$TaxRegionApiCopyWithImpl<$Res>
    implements $TaxRegionApiCopyWith<$Res> {
  _$TaxRegionApiCopyWithImpl(this._self, this._then);

  final TaxRegionApi _self;
  final $Res Function(TaxRegionApi) _then;

/// Create a copy of TaxRegionApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? taxAllSubregions = null,Object? taxThreshold = null,Object? hasSalesAboveThreshold = null,Object? subregions = null,}) {
  return _then(TaxRegionApi(
taxAllSubregions: null == taxAllSubregions ? _self.taxAllSubregions : taxAllSubregions // ignore: cast_nullable_to_non_nullable
as bool,taxThreshold: null == taxThreshold ? _self.taxThreshold : taxThreshold // ignore: cast_nullable_to_non_nullable
as double,hasSalesAboveThreshold: null == hasSalesAboveThreshold ? _self.hasSalesAboveThreshold : hasSalesAboveThreshold // ignore: cast_nullable_to_non_nullable
as bool,subregions: null == subregions ? _self.subregions : subregions // ignore: cast_nullable_to_non_nullable
as Map<String, TaxSubregionApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [TaxRegionApi].
extension TaxRegionApiPatterns on TaxRegionApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TaxRegionApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TaxRegionApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TaxRegionApi value)  $default,){
final _that = this;
switch (_that) {
case _TaxRegionApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TaxRegionApi value)?  $default,){
final _that = this;
switch (_that) {
case _TaxRegionApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'tax_all_subregions')  bool taxAllSubregions, @JsonKey(name: 'tax_threshold')  double taxThreshold, @JsonKey(name: 'has_sales_above_threshold')  bool hasSalesAboveThreshold,  Map<String, TaxSubregionApi> subregions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaxRegionApi() when $default != null:
return $default(_that.taxAllSubregions,_that.taxThreshold,_that.hasSalesAboveThreshold,_that.subregions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'tax_all_subregions')  bool taxAllSubregions, @JsonKey(name: 'tax_threshold')  double taxThreshold, @JsonKey(name: 'has_sales_above_threshold')  bool hasSalesAboveThreshold,  Map<String, TaxSubregionApi> subregions)  $default,) {final _that = this;
switch (_that) {
case _TaxRegionApi():
return $default(_that.taxAllSubregions,_that.taxThreshold,_that.hasSalesAboveThreshold,_that.subregions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'tax_all_subregions')  bool taxAllSubregions, @JsonKey(name: 'tax_threshold')  double taxThreshold, @JsonKey(name: 'has_sales_above_threshold')  bool hasSalesAboveThreshold,  Map<String, TaxSubregionApi> subregions)?  $default,) {final _that = this;
switch (_that) {
case _TaxRegionApi() when $default != null:
return $default(_that.taxAllSubregions,_that.taxThreshold,_that.hasSalesAboveThreshold,_that.subregions);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(includeIfNull: false)
class _TaxRegionApi implements TaxRegionApi {
  const _TaxRegionApi({@JsonKey(name: 'tax_all_subregions') this.taxAllSubregions = false, @JsonKey(name: 'tax_threshold') this.taxThreshold = 0.0, @JsonKey(name: 'has_sales_above_threshold') this.hasSalesAboveThreshold = false,  Map<String, TaxSubregionApi> subregions = const <String, TaxSubregionApi>{}}): _subregions = subregions;
  factory _TaxRegionApi.fromJson(Map<String, dynamic> json) => _$TaxRegionApiFromJson(json);

@override@JsonKey(name: 'tax_all_subregions') final  bool taxAllSubregions;
@override@JsonKey(name: 'tax_threshold') final  double taxThreshold;
@override@JsonKey(name: 'has_sales_above_threshold') final  bool hasSalesAboveThreshold;
 final  Map<String, TaxSubregionApi> _subregions;
@override@JsonKey() Map<String, TaxSubregionApi> get subregions {
  if (_subregions is EqualUnmodifiableMapView) return _subregions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_subregions);
}


/// Create a copy of TaxRegionApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaxRegionApiCopyWith<_TaxRegionApi> get copyWith => __$TaxRegionApiCopyWithImpl<_TaxRegionApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaxRegionApiToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaxRegionApi&&(identical(other.taxAllSubregions, taxAllSubregions) || other.taxAllSubregions == taxAllSubregions)&&(identical(other.taxThreshold, taxThreshold) || other.taxThreshold == taxThreshold)&&(identical(other.hasSalesAboveThreshold, hasSalesAboveThreshold) || other.hasSalesAboveThreshold == hasSalesAboveThreshold)&&const DeepCollectionEquality().equals(other.subregions, _subregions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,taxAllSubregions,taxThreshold,hasSalesAboveThreshold,const DeepCollectionEquality().hash(_subregions));
}

@override
String toString() {
    return 'TaxRegionApi(taxAllSubregions: $taxAllSubregions, taxThreshold: $taxThreshold, hasSalesAboveThreshold: $hasSalesAboveThreshold, subregions: $subregions)';
}


}

/// @nodoc
abstract mixin class _$TaxRegionApiCopyWith<$Res> implements $TaxRegionApiCopyWith<$Res> {
  factory _$TaxRegionApiCopyWith(_TaxRegionApi value, $Res Function(_TaxRegionApi) _then) = __$TaxRegionApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'tax_all_subregions') bool taxAllSubregions,@JsonKey(name: 'tax_threshold') double taxThreshold,@JsonKey(name: 'has_sales_above_threshold') bool hasSalesAboveThreshold, Map<String, TaxSubregionApi> subregions
});




}
/// @nodoc
class __$TaxRegionApiCopyWithImpl<$Res>
    implements _$TaxRegionApiCopyWith<$Res> {
  __$TaxRegionApiCopyWithImpl(this._self, this._then);

  final _TaxRegionApi _self;
  final $Res Function(_TaxRegionApi) _then;

/// Create a copy of TaxRegionApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? taxAllSubregions = null,Object? taxThreshold = null,Object? hasSalesAboveThreshold = null,Object? subregions = null,}) {
  return _then(_TaxRegionApi(
taxAllSubregions: null == taxAllSubregions ? _self.taxAllSubregions : taxAllSubregions // ignore: cast_nullable_to_non_nullable
as bool,taxThreshold: null == taxThreshold ? _self.taxThreshold : taxThreshold // ignore: cast_nullable_to_non_nullable
as double,hasSalesAboveThreshold: null == hasSalesAboveThreshold ? _self.hasSalesAboveThreshold : hasSalesAboveThreshold // ignore: cast_nullable_to_non_nullable
as bool,subregions: null == subregions ? _self._subregions : subregions // ignore: cast_nullable_to_non_nullable
as Map<String, TaxSubregionApi>,
  ));
}


}


/// @nodoc
mixin _$TaxSubregionApi {

@JsonKey(name: 'apply_tax') bool get applyTax;@JsonKey(name: 'tax_name') String get taxName;@JsonKey(name: 'tax_rate') double get taxRate;@JsonKey(name: 'reduced_tax_rate') double get reducedTaxRate;@JsonKey(name: 'vat_number') String get vatNumber;
/// Create a copy of TaxSubregionApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaxSubregionApiCopyWith<TaxSubregionApi> get copyWith => _$TaxSubregionApiCopyWithImpl<TaxSubregionApi>(this as TaxSubregionApi, _$identity);

  /// Serializes this TaxSubregionApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TaxSubregionApi;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaxSubregionApi&&(identical(other.applyTax, _this.applyTax) || other.applyTax == _this.applyTax)&&(identical(other.taxName, _this.taxName) || other.taxName == _this.taxName)&&(identical(other.taxRate, _this.taxRate) || other.taxRate == _this.taxRate)&&(identical(other.reducedTaxRate, _this.reducedTaxRate) || other.reducedTaxRate == _this.reducedTaxRate)&&(identical(other.vatNumber, _this.vatNumber) || other.vatNumber == _this.vatNumber));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TaxSubregionApi;
  return Object.hash(runtimeType,_this.applyTax,_this.taxName,_this.taxRate,_this.reducedTaxRate,_this.vatNumber);
}

@override
String toString() {
  final _this = this as TaxSubregionApi;
  return 'TaxSubregionApi(applyTax: ${_this.applyTax}, taxName: ${_this.taxName}, taxRate: ${_this.taxRate}, reducedTaxRate: ${_this.reducedTaxRate}, vatNumber: ${_this.vatNumber})';
}


}

/// @nodoc
abstract mixin class $TaxSubregionApiCopyWith<$Res>  {
  factory $TaxSubregionApiCopyWith(TaxSubregionApi value, $Res Function(TaxSubregionApi) _then) = _$TaxSubregionApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'apply_tax') bool applyTax,@JsonKey(name: 'tax_name') String taxName,@JsonKey(name: 'tax_rate') double taxRate,@JsonKey(name: 'reduced_tax_rate') double reducedTaxRate,@JsonKey(name: 'vat_number') String vatNumber
});




}
/// @nodoc
class _$TaxSubregionApiCopyWithImpl<$Res>
    implements $TaxSubregionApiCopyWith<$Res> {
  _$TaxSubregionApiCopyWithImpl(this._self, this._then);

  final TaxSubregionApi _self;
  final $Res Function(TaxSubregionApi) _then;

/// Create a copy of TaxSubregionApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? applyTax = null,Object? taxName = null,Object? taxRate = null,Object? reducedTaxRate = null,Object? vatNumber = null,}) {
  return _then(TaxSubregionApi(
applyTax: null == applyTax ? _self.applyTax : applyTax // ignore: cast_nullable_to_non_nullable
as bool,taxName: null == taxName ? _self.taxName : taxName // ignore: cast_nullable_to_non_nullable
as String,taxRate: null == taxRate ? _self.taxRate : taxRate // ignore: cast_nullable_to_non_nullable
as double,reducedTaxRate: null == reducedTaxRate ? _self.reducedTaxRate : reducedTaxRate // ignore: cast_nullable_to_non_nullable
as double,vatNumber: null == vatNumber ? _self.vatNumber : vatNumber // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TaxSubregionApi].
extension TaxSubregionApiPatterns on TaxSubregionApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TaxSubregionApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TaxSubregionApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TaxSubregionApi value)  $default,){
final _that = this;
switch (_that) {
case _TaxSubregionApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TaxSubregionApi value)?  $default,){
final _that = this;
switch (_that) {
case _TaxSubregionApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'apply_tax')  bool applyTax, @JsonKey(name: 'tax_name')  String taxName, @JsonKey(name: 'tax_rate')  double taxRate, @JsonKey(name: 'reduced_tax_rate')  double reducedTaxRate, @JsonKey(name: 'vat_number')  String vatNumber)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaxSubregionApi() when $default != null:
return $default(_that.applyTax,_that.taxName,_that.taxRate,_that.reducedTaxRate,_that.vatNumber);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'apply_tax')  bool applyTax, @JsonKey(name: 'tax_name')  String taxName, @JsonKey(name: 'tax_rate')  double taxRate, @JsonKey(name: 'reduced_tax_rate')  double reducedTaxRate, @JsonKey(name: 'vat_number')  String vatNumber)  $default,) {final _that = this;
switch (_that) {
case _TaxSubregionApi():
return $default(_that.applyTax,_that.taxName,_that.taxRate,_that.reducedTaxRate,_that.vatNumber);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'apply_tax')  bool applyTax, @JsonKey(name: 'tax_name')  String taxName, @JsonKey(name: 'tax_rate')  double taxRate, @JsonKey(name: 'reduced_tax_rate')  double reducedTaxRate, @JsonKey(name: 'vat_number')  String vatNumber)?  $default,) {final _that = this;
switch (_that) {
case _TaxSubregionApi() when $default != null:
return $default(_that.applyTax,_that.taxName,_that.taxRate,_that.reducedTaxRate,_that.vatNumber);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(includeIfNull: false)
class _TaxSubregionApi implements TaxSubregionApi {
  const _TaxSubregionApi({@JsonKey(name: 'apply_tax') this.applyTax = false, @JsonKey(name: 'tax_name') this.taxName = '', @JsonKey(name: 'tax_rate') this.taxRate = 0.0, @JsonKey(name: 'reduced_tax_rate') this.reducedTaxRate = 0.0, @JsonKey(name: 'vat_number') this.vatNumber = ''});
  factory _TaxSubregionApi.fromJson(Map<String, dynamic> json) => _$TaxSubregionApiFromJson(json);

@override@JsonKey(name: 'apply_tax') final  bool applyTax;
@override@JsonKey(name: 'tax_name') final  String taxName;
@override@JsonKey(name: 'tax_rate') final  double taxRate;
@override@JsonKey(name: 'reduced_tax_rate') final  double reducedTaxRate;
@override@JsonKey(name: 'vat_number') final  String vatNumber;

/// Create a copy of TaxSubregionApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaxSubregionApiCopyWith<_TaxSubregionApi> get copyWith => __$TaxSubregionApiCopyWithImpl<_TaxSubregionApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaxSubregionApiToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaxSubregionApi&&(identical(other.applyTax, applyTax) || other.applyTax == applyTax)&&(identical(other.taxName, taxName) || other.taxName == taxName)&&(identical(other.taxRate, taxRate) || other.taxRate == taxRate)&&(identical(other.reducedTaxRate, reducedTaxRate) || other.reducedTaxRate == reducedTaxRate)&&(identical(other.vatNumber, vatNumber) || other.vatNumber == vatNumber));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,applyTax,taxName,taxRate,reducedTaxRate,vatNumber);
}

@override
String toString() {
    return 'TaxSubregionApi(applyTax: $applyTax, taxName: $taxName, taxRate: $taxRate, reducedTaxRate: $reducedTaxRate, vatNumber: $vatNumber)';
}


}

/// @nodoc
abstract mixin class _$TaxSubregionApiCopyWith<$Res> implements $TaxSubregionApiCopyWith<$Res> {
  factory _$TaxSubregionApiCopyWith(_TaxSubregionApi value, $Res Function(_TaxSubregionApi) _then) = __$TaxSubregionApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'apply_tax') bool applyTax,@JsonKey(name: 'tax_name') String taxName,@JsonKey(name: 'tax_rate') double taxRate,@JsonKey(name: 'reduced_tax_rate') double reducedTaxRate,@JsonKey(name: 'vat_number') String vatNumber
});




}
/// @nodoc
class __$TaxSubregionApiCopyWithImpl<$Res>
    implements _$TaxSubregionApiCopyWith<$Res> {
  __$TaxSubregionApiCopyWithImpl(this._self, this._then);

  final _TaxSubregionApi _self;
  final $Res Function(_TaxSubregionApi) _then;

/// Create a copy of TaxSubregionApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? applyTax = null,Object? taxName = null,Object? taxRate = null,Object? reducedTaxRate = null,Object? vatNumber = null,}) {
  return _then(_TaxSubregionApi(
applyTax: null == applyTax ? _self.applyTax : applyTax // ignore: cast_nullable_to_non_nullable
as bool,taxName: null == taxName ? _self.taxName : taxName // ignore: cast_nullable_to_non_nullable
as String,taxRate: null == taxRate ? _self.taxRate : taxRate // ignore: cast_nullable_to_non_nullable
as double,reducedTaxRate: null == reducedTaxRate ? _self.reducedTaxRate : reducedTaxRate // ignore: cast_nullable_to_non_nullable
as double,vatNumber: null == vatNumber ? _self.vatNumber : vatNumber // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
