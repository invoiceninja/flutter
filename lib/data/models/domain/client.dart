import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/value/money.dart';
import 'package:admin/data/models/value/parsing.dart';
import 'package:admin/data/models/domain/contact.dart';
import 'package:admin/data/models/domain/document.dart';
import 'package:admin/data/models/domain/gateway_token.dart';
import 'package:admin/data/models/domain/location.dart';

part 'client.freezed.dart';

/// Clean domain shape for a Client.
///
/// Money is [Decimal] (never `double`). Timestamps are UTC [DateTime];
/// date-only server fields use the custom `Date` type when introduced.
@freezed
abstract class Client with _$Client {
  const factory Client({
    required String id,
    required String name,
    required String displayName,
    required String number,
    required String idNumber,
    required String vatNumber,
    // Server-assigned, read-only. Drives the client-portal silent
    // auto-login URL. `@Default('')` (not `required`) so existing
    // `Client(...)` fixtures don't all need updating.
    @Default('') String clientHash,
    required String website,
    required String phone,
    required String address1,
    required String address2,
    required String city,
    required String state,
    required String postalCode,
    required String countryId,
    required Decimal balance,
    required Decimal paidToDate,
    required Decimal creditBalance,
    required String currencyId,
    required String languageId,
    required String paymentTerms,
    required String privateNotes,
    required String publicNotes,
    required String groupSettingsId,
    required String assignedUserId,
    // Filterable client columns the API exposes but the model historically
    // omitted. `@Default('')` (not `required`) so existing `Client(...)`
    // fixtures don't all need updating — these are optional id/enum strings.
    @Default('') String industryId,
    @Default('') String sizeId,
    @Default('') String classification,
    required DateTime updatedAt,
    required DateTime createdAt,
    required DateTime? archivedAt,
    required bool isDeleted,
    required String customValue1,
    required String customValue2,
    required String customValue3,
    required String customValue4,
    required List<Contact> contacts,
    @Default(<Location>[]) List<Location> locations,
    @Default(<Document>[]) List<Document> documents,
    @Default(<String>[]) List<String> tagIds,
    // Shipping address (distinct from the billing address above). All
    // optional/defaulted so existing `Client(...)` fixtures don't need
    // updating — these were historically dropped on the floor.
    @Default('') String shippingAddress1,
    @Default('') String shippingAddress2,
    @Default('') String shippingCity,
    @Default('') String shippingState,
    @Default('') String shippingPostalCode,
    @Default('') String shippingCountryId,
    // Tax / e-invoice flags. Editable; the UI gates them on the company's
    // calculate_taxes / e-invoice toggles (React parity).
    @Default(false) bool isTaxExempt,
    @Default(false) bool hasValidVatNumber,
    @Default('') String routingId,
    // Read-only server fields surfaced in the UI. `userId` is the creator;
    // `paymentBalance` is the unapplied-payments KPI; `lastLogin` drives the
    // "Last login" list column (null when no portal login yet).
    @Default('') String userId,
    Decimal? paymentBalance,
    DateTime? lastLogin,
    // Saved payment methods (gateway tokens), read-embedded and display-only.
    // Never written to the server; survives a local save via a payload inject
    // in `ClientRepository._domainToCompanion` (no dedicated Drift column).
    @Default(<GatewayToken>[]) List<GatewayToken> gatewayTokens,
    // Sparse per-client settings overrides. Mirrors the wire shape — keys
    // not present mean "inherit from company via the cascade." Stored raw
    // because the wire is open-ended; the typed `CompanySettings` view is
    // reconstructed in the settings VM on demand.
    Map<String, dynamic>? settings,
    // Local-only — never sent to the server. Populated by the repository
    // from the Drift row's `is_dirty` column so the UI can render an
    // "Unsynced" chip on the detail screen.
    @Default(false) bool isDirty,
  }) = _Client;

  factory Client.fromApi(ClientApi a) {
    // currency_id / language_id / payment_terms are CASCADE settings on the
    // server — they live inside `settings`, never top-level (verified against
    // the live API: a client with a per-client currency carries
    // `settings.currency_id` and NO top-level `currency_id`). Read them from
    // `settings` first, falling back to the (normally empty) top-level field
    // for resilience. `toApiJson` folds them back into `settings`, so a
    // per-client override round-trips and `Formatter.money(clientCurrencyId:)`
    // actually sees it.
    final s = a.settings;
    String fromSettings(String key, String fallback) {
      final v = s == null ? null : s[key];
      return v == null ? fallback : v.toString();
    }

    return Client(
      id: a.id,
      name: a.name,
      displayName: a.displayName.isNotEmpty ? a.displayName : a.name,
      number: a.number,
      idNumber: a.idNumber,
      vatNumber: a.vatNumber,
      clientHash: a.clientHash,
      website: a.website,
      phone: a.phone,
      address1: a.address1,
      address2: a.address2,
      city: a.city,
      state: a.state,
      postalCode: a.postalCode,
      countryId: a.countryId,
      balance: parseMoney(a.balance),
      paidToDate: parseMoney(a.paidToDate),
      creditBalance: parseMoney(a.creditBalance),
      currencyId: fromSettings('currency_id', a.currencyId),
      languageId: fromSettings('language_id', a.languageId),
      paymentTerms: fromSettings('payment_terms', a.paymentTerms),
      privateNotes: a.privateNotes,
      publicNotes: a.publicNotes,
      groupSettingsId: a.groupSettingsId,
      assignedUserId: a.assignedUserId,
      industryId: a.industryId,
      sizeId: a.sizeId,
      classification: a.classification,
      updatedAt: epochSecondsToUtc(a.updatedAt),
      createdAt: epochSecondsToUtc(a.createdAt),
      archivedAt: epochSecondsToUtcOrNull(a.archivedAt),
      isDeleted: a.isDeleted,
      customValue1: a.customValue1,
      customValue2: a.customValue2,
      customValue3: a.customValue3,
      customValue4: a.customValue4,
      contacts: a.contacts.map(Contact.fromApi).toList(growable: false),
      locations: a.locations.map(Location.fromApi).toList(growable: false),
      documents: mapDocuments(a.documents),
      tagIds: [
        for (final t in a.tags)
          if (t.id.isNotEmpty) t.id,
      ],
      shippingAddress1: a.shippingAddress1,
      shippingAddress2: a.shippingAddress2,
      shippingCity: a.shippingCity,
      shippingState: a.shippingState,
      shippingPostalCode: a.shippingPostalCode,
      shippingCountryId: a.shippingCountryId,
      isTaxExempt: a.isTaxExempt,
      hasValidVatNumber: a.hasValidVatNumber,
      routingId: a.routingId,
      userId: a.userId,
      paymentBalance: parseMoney(a.paymentBalance),
      lastLogin: epochSecondsToUtcOrNull(a.lastLogin),
      gatewayTokens: a.gatewayTokens
          .map(GatewayToken.fromApi)
          .toList(growable: false),
      settings: a.settings,
    );
  }
}

extension ClientCascade on Client {
  /// Return a copy with `settings[key]` set to [value], or with the key
  /// **removed** when [value] is null or empty. Removing the key is the
  /// admin-portal convention for "inherit from the parent (group →
  /// company)" — an empty string would otherwise be an explicit
  /// override-to-blank. Mirrors `GroupSetting.withCascadeOverride`.
  Client withCascadeOverride(String key, String? value) {
    final next = Map<String, dynamic>.from(settings ?? const {});
    if (value == null || value.isEmpty) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    return copyWith(settings: next.isEmpty ? null : next);
  }
}

extension ClientPayload on Client {
  /// Serialize back to the JSON shape the server expects for create/update.
  /// Empty `id` lets the server allocate one (the outbox handles tmp→real
  /// remapping after the response lands).
  ///
  /// [preserveTempId] is for **local storage** only — the Drift row needs to
  /// keep the tmp id so the detail screen can keep watching it. The outbox
  /// payload that goes to the server uses the default (drops tmp ids).
  Map<String, dynamic> toApiJson({bool preserveTempId = false}) {
    // currency_id / language_id / payment_terms are cascade settings — fold
    // them INTO `settings` (their real wire home) rather than emitting them
    // top-level, where the server silently ignores them. An empty value
    // removes the key (= "inherit from the company/group cascade"), matching
    // the admin-portal convention (`withCascadeOverride`).
    final mergedSettings = <String, dynamic>{...?settings};
    void foldSetting(String key, String value) {
      if (value.isEmpty) {
        mergedSettings.remove(key);
      } else {
        mergedSettings[key] = value;
      }
    }

    foldSetting('currency_id', currencyId);
    foldSetting('language_id', languageId);
    foldSetting('payment_terms', paymentTerms);

    return {
      if (preserveTempId || !id.startsWith('tmp_')) 'id': id,
      'name': name,
      'display_name': displayName,
      'number': number,
      'id_number': idNumber,
      'vat_number': vatNumber,
      'client_hash': clientHash,
      'website': website,
      'phone': phone,
      'address1': address1,
      'address2': address2,
      'city': city,
      'state': state,
      'postal_code': postalCode,
      'country_id': countryId,
      'shipping_address1': shippingAddress1,
      'shipping_address2': shippingAddress2,
      'shipping_city': shippingCity,
      'shipping_state': shippingState,
      'shipping_postal_code': shippingPostalCode,
      'shipping_country_id': shippingCountryId,
      'balance': balance.toString(),
      'paid_to_date': paidToDate.toString(),
      'credit_balance': creditBalance.toString(),
      'payment_balance': (paymentBalance ?? Decimal.zero).toString(),
      'private_notes': privateNotes,
      'public_notes': publicNotes,
      'group_settings_id': groupSettingsId,
      'assigned_user_id': assignedUserId,
      'industry_id': industryId,
      'size_id': sizeId,
      'classification': classification,
      'is_tax_exempt': isTaxExempt,
      'has_valid_vat_number': hasValidVatNumber,
      'routing_id': routingId,
      'custom_value1': customValue1,
      'custom_value2': customValue2,
      'custom_value3': customValue3,
      'custom_value4': customValue4,
      // Read-only server fields — echoed only for the local payload round-trip
      // (server `fill()` ignores non-fillable keys, same as `client_hash`).
      if (userId.isNotEmpty) 'user_id': userId,
      if (lastLogin != null)
        'last_login': lastLogin!.millisecondsSinceEpoch ~/ 1000,
      'contacts': contacts.map((c) => c.toApiJson()).toList(),
      // Full-set replace: the server syncs attached tags to exactly this list.
      'tags': tagIds,
      // Only emit `settings` when there's at least one override — an empty
      // map means the same as "inherit," so omit it to keep the wire minimal.
      if (mergedSettings.isNotEmpty) 'settings': mergedSettings,
    };
  }
}
