import 'dart:typed_data';

import 'package:admin/data/services/api_client.dart';

/// The server's own render of a saved billing document —
/// `GET /api/v1/<entity>/<invitationKey>/download` — or null when the caller
/// must fall back to `live_preview`.
///
/// That route is the document as its recipient gets it (the server's
/// `CreateRawPdf`, the same job behind the client portal, the email
/// attachment and React's View / Download / Print). A `live_preview` of the
/// same record is a fresh render of the JSON in hand, and it is missing
/// things only the stored path adds: the DocuNinja-signed PDF once a quote,
/// invoice or purchase order has been signed (`sync.dn_completed`), the
/// public documents merged by `embed_documents`, and the e-invoice payload.
/// Showing the re-render is how an approved quote's signature went missing
/// from the app while the web app showed it.
///
/// Null — so `live_preview` runs — when there is no [storedPdfKey] (see
/// `BillingDocStoredPdf.storedPdfInvitationKey`: unsaved, unsynced edits, or
/// no invitation), or when [designId] asks for a design other than the
/// document's own: the download route has no design override and renders
/// the saved `design_id`.
Future<Uint8List>? fetchStoredPdf({
  required ApiClient client,
  required String entity,
  required String? storedPdfKey,
  required Map<String, dynamic> entityJson,
  String? designId,
}) {
  if (storedPdfKey == null || storedPdfKey.isEmpty) return null;
  final ownDesign = (entityJson['design_id'] as String?) ?? '';
  if (designId != null && designId.isNotEmpty && designId != ownDesign) {
    return null;
  }
  return client.getRaw(
    '/api/v1/$entity/${Uri.encodeComponent(storedPdfKey)}/download',
    readOnly: true,
  );
}
