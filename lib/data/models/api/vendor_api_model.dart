import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/api/json_coercion.dart';

part 'vendor_api_model.freezed.dart';
part 'vendor_api_model.g.dart';

/// Raw JSON shape of `/api/v1/vendors/{id}` as returned by the server.
///
/// Field names mirror the server keys via `@JsonKey`. The vendor resource has
/// no server-side `balance`/`paid_to_date` (unlike clients) — a vendor's spend
/// is derived locally from its expenses. Unlike clients, `currency_id` /
/// `language_id` / `classification` live top-level here, not under `settings`.
@freezed
abstract class VendorApi with _$VendorApi {
  const factory VendorApi({
    @Default('') String id,
    @Default('') String name,
    @Default('') String number,
    @JsonKey(name: 'id_number') @Default('') String idNumber,
    @JsonKey(name: 'vat_number') @Default('') String vatNumber,
    @Default('') String website,
    @Default('') String phone,
    @Default('') String address1,
    @Default('') String address2,
    @Default('') String city,
    @Default('') String state,
    @JsonKey(name: 'postal_code') @Default('') String postalCode,
    @JsonKey(name: 'country_id') @Default('') String countryId,
    @JsonKey(name: 'currency_id') @Default('') String currencyId,
    @JsonKey(name: 'language_id') @Default('') String languageId,
    @Default('') String classification,
    @JsonKey(name: 'is_tax_exempt') @Default(false) bool isTaxExempt,
    @JsonKey(name: 'routing_id') @Default('') String routingId,
    @JsonKey(name: 'private_notes') @Default('') String privateNotes,
    @JsonKey(name: 'public_notes') @Default('') String publicNotes,
    @JsonKey(name: 'custom_value1') @Default('') String customValue1,
    @JsonKey(name: 'custom_value2') @Default('') String customValue2,
    @JsonKey(name: 'custom_value3') @Default('') String customValue3,
    @JsonKey(name: 'custom_value4') @Default('') String customValue4,
    @JsonKey(name: 'assigned_user_id') @Default('') String assignedUserId,
    @JsonKey(name: 'user_id') @Default('') String userId,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
    @JsonKey(name: 'last_login') @Default(0) int lastLogin,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
    @Default(<VendorContactApi>[]) List<VendorContactApi> contacts,
    // Nullable on purpose: the IN list endpoint omits `documents` unless
    // `?include=documents` is requested. Distinguishing "key missing"
    // (→ null) from "key present, array empty" (→ `const []`) lets
    // `_apiToCompanion` preserve local docs on responses that didn't
    // include them while still propagating server-side deletes on
    // responses that did. See `VendorRepository._apiToCompanion`.
    List<DocumentApi>? documents,
  }) = _VendorApi;

  factory VendorApi.fromJson(Map<String, dynamic> json) =>
      _$VendorApiFromJson(json);
}

/// Raw JSON shape of a `vendor.contacts[]` entry as returned by the server.
///
/// Field names mirror the server keys via `@JsonKey`. Vendor contacts carry
/// the same shape as client contacts minus `contact_key`: identity + email +
/// phone + password + `send_email`/`cc_only`/`is_primary`/`can_sign` flags +
/// portal `link` + `last_login` + `custom_value1..4`.
@freezed
abstract class VendorContactApi with _$VendorContactApi {
  const factory VendorContactApi({
    @Default('') String id,
    @JsonKey(name: 'first_name') @Default('') String firstName,
    @JsonKey(name: 'last_name') @Default('') String lastName,
    @Default('') String email,
    @Default('') String phone,
    @Default('') String password,
    @JsonKey(name: 'send_email') @Default(true) bool sendEmail,
    @JsonKey(name: 'cc_only') @Default(false) bool ccOnly,
    @JsonKey(name: 'is_primary') @Default(false) bool isPrimary,
    @JsonKey(name: 'can_sign') @Default(false) bool canSign,
    @Default('') String link,
    @JsonKey(name: 'custom_value1') @Default('') String customValue1,
    @JsonKey(name: 'custom_value2') @Default('') String customValue2,
    @JsonKey(name: 'custom_value3') @Default('') String customValue3,
    @JsonKey(name: 'custom_value4') @Default('') String customValue4,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
    @JsonKey(name: 'last_login') @Default(0) int lastLogin,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
  }) = _VendorContactApi;

  factory VendorContactApi.fromJson(Map<String, dynamic> json) =>
      _$VendorContactApiFromJson(json);
}

/// Envelope for `/api/v1/vendors` list responses.
@freezed
abstract class VendorListApi with _$VendorListApi {
  const factory VendorListApi({
    @JsonKey(fromJson: _vendorListData)
    @Default(<VendorApi>[])
    List<VendorApi> data,
  }) = _VendorListApi;

  factory VendorListApi.fromJson(Map<String, dynamic> json) =>
      _$VendorListApiFromJson(json);
}

/// Envelope for `/api/v1/vendors/{id}` item responses.
@freezed
abstract class VendorItemApi with _$VendorItemApi {
  const factory VendorItemApi({required VendorApi data}) = _VendorItemApi;

  factory VendorItemApi.fromJson(Map<String, dynamic> json) =>
      _$VendorItemApiFromJson(json);
}

List<VendorApi> _vendorListData(Object? raw) =>
    tolerantList(raw, VendorApi.fromJson, label: 'vendor');
