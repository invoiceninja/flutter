import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/vendor_api_model.dart';
import 'package:admin/data/models/domain/document.dart';
import 'package:admin/data/models/domain/vendor_contact.dart';
import 'package:admin/data/models/value/parsing.dart';

part 'vendor.freezed.dart';

/// Clean domain shape for a Vendor.
///
/// Timestamps are UTC [DateTime]. Mirror of [Client] minus the
/// invoicing-specific bits — Vendor has no statement and no group assignment,
/// and there is no server-side balance (a vendor's spend is derived locally
/// from its expenses). Like a client it carries currency / language /
/// classification and supports merge.
@freezed
abstract class Vendor with _$Vendor {
  const factory Vendor({
    required String id,
    required String name,
    required String number,
    required String idNumber,
    required String vatNumber,
    required String website,
    required String phone,
    required String address1,
    required String address2,
    required String city,
    required String state,
    required String postalCode,
    required String countryId,
    required String currencyId,
    @Default('') String languageId,
    @Default('') String classification,
    @Default(false) bool isTaxExempt,
    @Default('') String routingId,
    required String privateNotes,
    required String publicNotes,
    required String userId,
    required String assignedUserId,
    required DateTime updatedAt,
    required DateTime createdAt,
    required DateTime? archivedAt,
    required bool isDeleted,
    required String customValue1,
    required String customValue2,
    required String customValue3,
    required String customValue4,
    required List<VendorContact> contacts,
    // Last portal login (read-only, display-only); null when never signed in.
    DateTime? lastLogin,
    @Default(<Document>[]) List<Document> documents,
    @Default(<String>[]) List<String> tagIds,
    // Local-only — never sent to the server. Populated by the repository
    // from the Drift row's `is_dirty` column so the UI can render an
    // "Unsynced" chip on the detail screen.
    @Default(false) bool isDirty,
  }) = _Vendor;

  factory Vendor.fromApi(VendorApi a) => Vendor(
    id: a.id,
    name: a.name,
    number: a.number,
    idNumber: a.idNumber,
    vatNumber: a.vatNumber,
    website: a.website,
    phone: a.phone,
    address1: a.address1,
    address2: a.address2,
    city: a.city,
    state: a.state,
    postalCode: a.postalCode,
    countryId: a.countryId,
    currencyId: a.currencyId,
    languageId: a.languageId,
    classification: a.classification,
    isTaxExempt: a.isTaxExempt,
    routingId: a.routingId,
    privateNotes: a.privateNotes,
    publicNotes: a.publicNotes,
    userId: a.userId,
    assignedUserId: a.assignedUserId,
    updatedAt: epochSecondsToUtc(a.updatedAt),
    createdAt: epochSecondsToUtc(a.createdAt),
    archivedAt: epochSecondsToUtcOrNull(a.archivedAt),
    isDeleted: a.isDeleted,
    customValue1: a.customValue1,
    customValue2: a.customValue2,
    customValue3: a.customValue3,
    customValue4: a.customValue4,
    contacts: a.contacts.map(VendorContact.fromApi).toList(growable: false),
    lastLogin: epochSecondsToUtcOrNull(a.lastLogin),
    documents: mapDocuments(a.documents),
    tagIds: [
      for (final t in a.tags)
        if (t.id.isNotEmpty) t.id,
    ],
  );
}

extension VendorPayload on Vendor {
  /// Serialize back to the JSON shape the server expects for create/update.
  /// Empty `id` lets the server allocate one (the outbox handles tmp→real
  /// remapping after the response lands).
  ///
  /// [preserveTempId] is for **local storage** only — the Drift row needs
  /// to keep the tmp id so the detail screen can keep watching it. The
  /// outbox payload that goes to the server uses the default (drops tmp
  /// ids). Cascades into each contact's `toApiJson(preserveTempId: ...)` —
  /// new contacts added offline carry `tmp_<uuid>` ids the server can't
  /// accept on create.
  Map<String, dynamic> toApiJson({bool preserveTempId = false}) => {
    if (preserveTempId || !id.startsWith('tmp_')) 'id': id,
    'name': name,
    'number': number,
    'id_number': idNumber,
    'vat_number': vatNumber,
    'website': website,
    'phone': phone,
    'address1': address1,
    'address2': address2,
    'city': city,
    'state': state,
    'postal_code': postalCode,
    'country_id': countryId,
    'currency_id': currencyId,
    'language_id': languageId,
    'classification': classification,
    'is_tax_exempt': isTaxExempt,
    'routing_id': routingId,
    'private_notes': privateNotes,
    'public_notes': publicNotes,
    'user_id': userId,
    'assigned_user_id': assignedUserId,
    'custom_value1': customValue1,
    'custom_value2': customValue2,
    'custom_value3': customValue3,
    'custom_value4': customValue4,
    // Full-set replace: the server syncs attached tags to exactly this list.
    'tags': tagIds,
    // Read-only, but included so the local Drift payload round-trip
    // (`_domainToCompanion`) preserves it; the server ignores it on save.
    if (lastLogin != null)
      'last_login': lastLogin!.millisecondsSinceEpoch ~/ 1000,
    'contacts': contacts
        .map((c) => c.toApiJson(preserveTempId: preserveTempId))
        .toList(),
  };
}
