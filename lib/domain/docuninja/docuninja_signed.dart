/// What a billing document's `sync` blob says about DocuNinja signing.
///
/// The hosted admin service writes `sync.dn_completed` once every signer has
/// signed, and `sync.invitations[].dn_id` names the DocuNinja document
/// (`App\DataMapper\InvoiceSync`, `QuoteSync`, `PurchaseOrderSync`). The
/// signed PDF itself is stored as one of the document's own files and served
/// by the stored-PDF route (`lib/data/services/stored_pdf.dart`).
///
/// React shows its "Signed Document" badge only when both are present
/// (`src/pages/invoices/edit/Edit.tsx`); [isDocuNinjaSigned] keys on
/// `dn_completed` alone, because the app's pill opens the signed PDF, which
/// does not need the DocuNinja document's id.
library;

/// True when DocuNinja reports every signer has signed this document.
bool isDocuNinjaSigned(Map<String, dynamic>? sync) {
  final completed = sync?['dn_completed'];
  return completed == true || completed == 1 || completed == '1';
}

/// The DocuNinja document id for this document's signing, or null when the
/// sync carries none. React reads the first invitation's (`invitations[0]`).
String? docuNinjaDocumentId(Map<String, dynamic>? sync) {
  final invitations = sync?['invitations'];
  if (invitations is! List || invitations.isEmpty) return null;
  final first = invitations.first;
  if (first is! Map) return null;
  final id = first['dn_id'];
  if (id is! String || id.isEmpty) return null;
  return id;
}
