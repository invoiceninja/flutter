import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/contact_api_model.dart';
import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/api/gateway_token_api_model.dart';
import 'package:admin/data/models/api/json_coercion.dart';
import 'package:admin/data/models/api/location_api_model.dart';
import 'package:admin/data/models/api/tag_api_model.dart';

part 'client_api_model.freezed.dart';
part 'client_api_model.g.dart';

/// Raw JSON shape of `/api/v1/clients/{id}` as returned by the server.
///
/// Field names mirror the server keys via `@JsonKey`. Numeric monetary fields
/// stay as `String` here because the server is inconsistent (sometimes
/// `"100.00"`, sometimes `100`) — they get parsed via `parseMoney` in
/// `Client.fromApi`.
@freezed
abstract class ClientApi with _$ClientApi {
  const factory ClientApi({
    @Default('') String id,
    @Default('') String name,
    @JsonKey(name: 'display_name') @Default('') String displayName,
    @Default('') String number,
    @JsonKey(name: 'id_number') @Default('') String idNumber,
    @JsonKey(name: 'vat_number') @Default('') String vatNumber,
    // Server-assigned, read-only. Used to build the client-portal silent
    // auto-login URL (`?silent=true&client_hash=…`). Always present on
    // client GET/list responses.
    @JsonKey(name: 'client_hash') @Default('') String clientHash,
    @Default('') String website,
    @JsonKey(name: 'phone') @Default('') String phone,
    @Default('') String address1,
    @Default('') String address2,
    @Default('') String city,
    @Default('') String state,
    @JsonKey(name: 'postal_code') @Default('') String postalCode,
    @JsonKey(name: 'country_id') @Default('') String countryId,
    @JsonKey(name: 'shipping_address1') @Default('') String shippingAddress1,
    @JsonKey(name: 'shipping_address2') @Default('') String shippingAddress2,
    @JsonKey(name: 'shipping_city') @Default('') String shippingCity,
    @JsonKey(name: 'shipping_state') @Default('') String shippingState,
    @JsonKey(name: 'shipping_postal_code')
    @Default('')
    String shippingPostalCode,
    @JsonKey(name: 'shipping_country_id') @Default('') String shippingCountryId,
    @JsonKey(name: 'balance') @Default('0') Object balance,
    @JsonKey(name: 'paid_to_date') @Default('0') Object paidToDate,
    @JsonKey(name: 'credit_balance') @Default('0') Object creditBalance,
    @JsonKey(name: 'payment_balance') @Default('0') Object paymentBalance,
    @JsonKey(name: 'currency_id') @Default('') String currencyId,
    @JsonKey(name: 'language_id') @Default('') String languageId,
    @JsonKey(name: 'payment_terms') @Default('') String paymentTerms,
    @JsonKey(name: 'private_notes') @Default('') String privateNotes,
    @JsonKey(name: 'public_notes') @Default('') String publicNotes,
    @JsonKey(name: 'custom_value1') @Default('') String customValue1,
    @JsonKey(name: 'custom_value2') @Default('') String customValue2,
    @JsonKey(name: 'custom_value3') @Default('') String customValue3,
    @JsonKey(name: 'custom_value4') @Default('') String customValue4,
    @JsonKey(name: 'group_settings_id') @Default('') String groupSettingsId,
    @JsonKey(name: 'assigned_user_id') @Default('') String assignedUserId,
    @JsonKey(name: 'industry_id') @Default('') String industryId,
    @JsonKey(name: 'size_id') @Default('') String sizeId,
    @JsonKey(name: 'classification') @Default('') String classification,
    @JsonKey(name: 'is_tax_exempt') @Default(false) bool isTaxExempt,
    @JsonKey(name: 'has_valid_vat_number')
    @Default(false)
    bool hasValidVatNumber,
    @JsonKey(name: 'routing_id') @Default('') String routingId,
    @JsonKey(name: 'user_id') @Default('') String userId,
    @JsonKey(name: 'last_login') @Default(0) int lastLogin,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
    @Default(<ContactApi>[]) List<ContactApi> contacts,
    // Non-nullable (unlike `documents`) on purpose: the IN server embeds
    // `locations` on every client GET/list response *unconditionally* —
    // it is NOT `?include=`-gated the way `documents` is (probed against
    // demo.invoiceninja.com, 2026-05: the `locations` key is always present,
    // `[]` when empty). So the authoritative array always round-trips
    // through the Drift `payload` JSON and no preserve-on-missing guard /
    // dedicated column is needed. The client_repository round-trip test
    // locks this contract — if the server ever makes it include-gated that
    // test fails loudly instead of silently wiping locations.
    @Default(<LocationApi>[]) List<LocationApi> locations,
    // Saved payment methods (cards / bank accounts) stored at the gateway.
    // Present on client GET/list responses (probe-verified: top-level key,
    // `[]` when none). Read-only — surfaced in the "Payment Methods" detail
    // card and never written back as part of the client save payload.
    @JsonKey(name: 'gateway_tokens')
    @Default(<GatewayTokenApi>[])
    List<GatewayTokenApi> gatewayTokens,
    @JsonKey(name: 'tags')
    @EmbeddedTagsConverter()
    @Default(<TagRefApi>[])
    List<TagRefApi> tags,
    // Nullable on purpose: the IN list endpoint omits the `documents` field
    // unless `?include=documents` is requested. Distinguishing "key missing
    // from JSON" (→ null) from "key present, array empty" (→ `const []`)
    // lets `_apiToCompanion` preserve local docs on responses that didn't
    // include them while still propagating server-side deletes on responses
    // that did. See `ClientRepository._apiToCompanion` for the guard.
    List<DocumentApi>? documents,
    // Sparse per-client settings overrides. Each key is a wire field name
    // on the company `settings` blob (mirrors `CompanySettingsApi` shape).
    // Absent keys mean "inherit from the company-level cascade." Stored
    // raw as a JSON map because the wire shape is open-ended and the
    // typed `CompanySettings` view is reconstructed in the VM.
    @JsonKey(name: 'settings', includeIfNull: false)
    Map<String, dynamic>? settings,
  }) = _ClientApi;

  factory ClientApi.fromJson(Map<String, dynamic> json) =>
      _$ClientApiFromJson(json);
}

/// Envelope for `/api/v1/clients` list responses.
@freezed
abstract class ClientListApi with _$ClientListApi {
  const factory ClientListApi({
    @JsonKey(fromJson: _clientListData)
    @Default(<ClientApi>[])
    List<ClientApi> data,
  }) = _ClientListApi;

  factory ClientListApi.fromJson(Map<String, dynamic> json) =>
      _$ClientListApiFromJson(json);
}

/// Envelope for `/api/v1/clients/{id}` item responses.
@freezed
abstract class ClientItemApi with _$ClientItemApi {
  const factory ClientItemApi({required ClientApi data}) = _ClientItemApi;

  factory ClientItemApi.fromJson(Map<String, dynamic> json) =>
      _$ClientItemApiFromJson(json);
}

List<ClientApi> _clientListData(Object? raw) =>
    tolerantList(raw, ClientApi.fromJson, label: 'client');
