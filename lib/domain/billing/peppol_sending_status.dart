/// Whether an invoice or credit went out over PEPPOL, as the list shows it
/// beside the status pill (React ui#3410, `PeppolSendingStatus.tsx`).
enum PeppolSendingStatus {
  /// `backup.guid` is set — the network accepted the document.
  sent,

  /// A non-draft, live document to a PEPPOL client with no `guid`: it should
  /// have gone out and did not.
  failed,
}

/// Which client classifications PEPPOL can deliver to, per country — React's
/// `PEPPOL_CLASSIFICATIONS`, cut to the countries in its `PEPPOL_COUNTRIES`
/// (v2's `kPeppolCountries`): React requires both, and a country missing from
/// either gets no icon. A test pins the key set to `kPeppolCountries`.
const Map<String, Set<String>> kPeppolClientClassifications = {
  '20': {'business', 'government'}, // Andorra
  '40': {'business', 'government'}, // Austria
  '56': {'business', 'government'}, // Belgium
  '208': {'business', 'government'}, // Denmark
  '250': {'business', 'government'}, // France
  '276': {'business', 'government'}, // Germany
  '352': {'business', 'government'}, // Iceland
  '372': {'business', 'government'}, // Ireland
  '442': {'business', 'government'}, // Luxembourg
  '528': {'business', 'government'}, // Netherlands
  '578': {'business', 'government'}, // Norway
  '616': {'business', 'government'}, // Poland
  '702': {'business', 'government'}, // Singapore
  '752': {'business', 'government'}, // Sweden
  '826': {'business'}, // United Kingdom
};

/// The document's PEPPOL state, or null when there is nothing to show.
///
/// Mirrors React's `PeppolSendingStatus` clause for clause:
///
/// - Nothing unless the company sends by PEPPOL ([companyUsesPeppol]: its
///   `e_invoice_type` is `PEPPOL`) and the client is one the network reaches —
///   a listed country, and a classification that country accepts. A client
///   with no classification counts as a business, as on the server.
/// - [guid] set (`backup.guid`) → [PeppolSendingStatus.sent], whatever the
///   document's state now.
/// - Otherwise nothing for a draft, a deleted or an archived document — none
///   was due to go out — and [PeppolSendingStatus.failed] for the rest.
///
/// [clientCountryId] is null while the client is still loading, which shows
/// nothing rather than guessing.
PeppolSendingStatus? peppolSendingStatus({
  required bool companyUsesPeppol,
  required String? clientCountryId,
  required String clientClassification,
  required String guid,
  required bool isDraft,
  required bool isDeleted,
  required bool isArchived,
}) {
  if (!companyUsesPeppol || clientCountryId == null) return null;
  final classification = clientClassification.isEmpty
      ? 'business'
      : clientClassification;
  final accepted = kPeppolClientClassifications[clientCountryId];
  if (accepted == null || !accepted.contains(classification)) return null;
  if (guid.isNotEmpty) return PeppolSendingStatus.sent;
  if (isDraft || isDeleted || isArchived) return null;
  return PeppolSendingStatus.failed;
}

/// `backup.guid` from a document's raw `backup` map, or `''`.
String peppolGuidOf(Map<String, dynamic>? backup) {
  final guid = backup?['guid'];
  return guid is String ? guid : '';
}
