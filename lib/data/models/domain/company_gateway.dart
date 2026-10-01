import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/company_gateway_api_model.dart';
import 'package:admin/domain/gateway_constants.dart';

part 'company_gateway.freezed.dart';

/// Re-export the API-side `FeesAndLimitsApi` as the domain-side shape. The
/// shapes are identical (every field is plain JSON-compatible), and
/// re-declaring would force `fromApi` / `toApi` mappers on a hot path that
/// runs per-payment-type. Mirrors how `CompanySettings` is a typedef on
/// `CompanySettingsApi`.
typedef FeesAndLimits = FeesAndLimitsApi;

/// Domain `CompanyGateway` — what the UI binds to.
///
/// `config` is the raw JSON-encoded credentials blob exactly as the server
/// sent it; UI reads via [parsedConfig] and writes back via `copyWith` after
/// re-encoding. The `acceptedCreditCards` bitmask is wrapped by [supportsCard]
/// / [addCard] / [removeCard] so callers never see the bitwise math.
///
/// `isDirty` is layered on locally by the repo when an outbox row is still
/// pending (mirrors the Client / Product pattern).
@freezed
abstract class CompanyGateway with _$CompanyGateway {
  const CompanyGateway._();

  const factory CompanyGateway({
    @Default('') String id,
    @Default('') String gatewayKey,
    @Default(0) int acceptedCreditCards,
    @Default(false) bool requireCvv,
    @Default(false) bool requireBillingAddress,
    @Default(false) bool requireShippingAddress,
    @Default(false) bool requireClientName,
    @Default(false) bool requireClientPhone,
    @Default(false) bool requireContactName,
    @Default(true) bool requireContactEmail,
    @Default(true) bool requirePostalCode,
    @Default(false) bool requireCustomValue1,
    @Default(false) bool requireCustomValue2,
    @Default(false) bool requireCustomValue3,
    @Default(false) bool requireCustomValue4,
    @Default(false) bool updateDetails,
    @Default(true) bool alwaysShowRequiredFields,
    @Default(kAutoBillOff) String tokenBilling,
    @Default('') String label,
    @Default('') String config,
    @Default(<String, FeesAndLimits>{})
    Map<String, FeesAndLimits> feesAndLimits,
    @Default(false) bool testMode,
    @Default(0) int createdAt,
    @Default(0) int updatedAt,
    @Default(0) int archivedAt,
    @Default(false) bool isDeleted,
    @Default(false) bool isDirty,
  }) = _CompanyGateway;

  factory CompanyGateway.fromApi(CompanyGatewayApi api) => CompanyGateway(
    id: api.id,
    gatewayKey: api.gatewayKey,
    acceptedCreditCards: api.acceptedCreditCards,
    requireCvv: api.requireCvv,
    requireBillingAddress: api.requireBillingAddress,
    requireShippingAddress: api.requireShippingAddress,
    requireClientName: api.requireClientName,
    requireClientPhone: api.requireClientPhone,
    requireContactName: api.requireContactName,
    requireContactEmail: api.requireContactEmail,
    requirePostalCode: api.requirePostalCode,
    requireCustomValue1: api.requireCustomValue1,
    requireCustomValue2: api.requireCustomValue2,
    requireCustomValue3: api.requireCustomValue3,
    requireCustomValue4: api.requireCustomValue4,
    updateDetails: api.updateDetails,
    alwaysShowRequiredFields: api.alwaysShowRequiredFields,
    // Normalize to a known auto-bill option. The server can return '' (or,
    // for legacy rows, a stray value); coercing anything outside
    // `kAutoBillOptions` to `off` keeps the Settings-tab dropdown (and the
    // detail card) from rendering a value with no matching item.
    tokenBilling: kAutoBillOptions.contains(api.tokenBilling)
        ? api.tokenBilling
        : kAutoBillOff,
    label: api.label,
    config: api.config,
    feesAndLimits: Map<String, FeesAndLimits>.from(api.feesAndLimits),
    testMode: api.testMode,
    createdAt: api.createdAt,
    updatedAt: api.updatedAt,
    archivedAt: api.archivedAt,
    isDeleted: api.isDeleted,
  );

  /// Build the PUT/POST body. Mirrors the typed fields back into a
  /// `CompanyGatewayApi` and then `toJson()` — the freezed
  /// `includeIfNull: false` on the API model keeps the wire payload tidy.
  /// `isDirty` is a local flag and intentionally not round-tripped.
  ///
  /// `preserveTempId`: keep the tmp id in the JSON. Local Drift writes pass
  /// `true` so id-remap continues to work; outbound `POST /company_gateways`
  /// passes `false` so the server assigns the real id.
  Map<String, dynamic> toApiJson({bool preserveTempId = false}) {
    final json = CompanyGatewayApi(
      id: id,
      gatewayKey: gatewayKey,
      acceptedCreditCards: acceptedCreditCards,
      requireCvv: requireCvv,
      requireBillingAddress: requireBillingAddress,
      requireShippingAddress: requireShippingAddress,
      requireClientName: requireClientName,
      requireClientPhone: requireClientPhone,
      requireContactName: requireContactName,
      requireContactEmail: requireContactEmail,
      requirePostalCode: requirePostalCode,
      requireCustomValue1: requireCustomValue1,
      requireCustomValue2: requireCustomValue2,
      requireCustomValue3: requireCustomValue3,
      requireCustomValue4: requireCustomValue4,
      updateDetails: updateDetails,
      alwaysShowRequiredFields: alwaysShowRequiredFields,
      tokenBilling: tokenBilling,
      label: label,
      config: config,
      feesAndLimits: feesAndLimits,
      testMode: testMode,
      createdAt: createdAt,
      updatedAt: updatedAt,
      archivedAt: archivedAt,
      isDeleted: isDeleted,
    ).toJson();
    if (!preserveTempId && id.startsWith('tmp_')) {
      json.remove('id');
    }
    return json;
  }

  /// Decoded credentials blob. Empty when [config] is blank or malformed —
  /// callers should never throw on missing fields. Re-evaluated per call;
  /// if profiling shows this is hot enough to cache, promote behind a
  /// memoized lazy field.
  Map<String, dynamic> get parsedConfig {
    if (config.isEmpty) return const {};
    try {
      final decoded = jsonDecode(config);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }

  /// The connected Stripe account (`acct_…`) a Stripe Connect gateway was
  /// authorized against, or `''` when it was never connected / has been
  /// disconnected — the server's `disconnect` blanks this field and keeps the
  /// row, so it is the only "is this connected" signal there is.
  String get stripeAccountId {
    final raw = parsedConfig['account_id'];
    return raw is String ? raw.trim() : '';
  }

  /// Re-encode [parsedConfig]-shaped `next` back into the `config` string.
  /// Always sorts keys for deterministic output (helps diff readability +
  /// equality comparisons on the dirty-tracking path).
  CompanyGateway withConfig(Map<String, dynamic> next) {
    if (next.isEmpty) return copyWith(config: '');
    final sorted = <String, dynamic>{
      for (final k in next.keys.toList()..sort()) k: next[k],
    };
    return copyWith(config: jsonEncode(sorted));
  }

  /// Bitmask accessors for [acceptedCreditCards]. The per-brand editing UI was
  /// intentionally removed (React + admin-portal omit it), but the field is
  /// still round-tripped to/from the server, so these are retained as the model
  /// API for it rather than deleted as dead code.
  ///
  /// Whether the [card] bit is set in [acceptedCreditCards].
  bool supportsCard(int card) => acceptedCreditCards & card == card;

  CompanyGateway addCard(int card) =>
      copyWith(acceptedCreditCards: acceptedCreditCards | card);

  CompanyGateway removeCard(int card) =>
      copyWith(acceptedCreditCards: acceptedCreditCards & ~card);

  CompanyGateway toggleCard(int card, {required bool selected}) =>
      selected ? addCard(card) : removeCard(card);

  /// User-visible name — prefers the label set on this row, falls back to a
  /// caller-provided gateway provider name (typically `Gateway.name` from
  /// statics), and finally to "Custom" if neither is available.
  String resolveDisplayName({
    String? gatewayName,
    String customFallback = 'Custom',
  }) {
    if (label.isNotEmpty) return label;
    if (gatewayName != null && gatewayName.isNotEmpty) return gatewayName;
    return customFallback;
  }

  /// True when this entity points at one of the OAuth-driven gateway types
  /// (Stripe Connect, PayPal Platform / PPCP, WePay, GoCardless OAuth,
  /// Square). The Credentials tab swaps to a setup-stub card for these.
  bool get isOAuthGateway => kOAuthGatewayKeys.contains(gatewayKey);

  /// True when this gateway has `kGatewayCustom` as its provider — these
  /// have no `fields` schema; users define their own credential keys.
  bool get isCustom => gatewayKey == kGatewayCustom;
}
