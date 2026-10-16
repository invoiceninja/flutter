import 'dart:typed_data';

import 'package:logging/logging.dart';

import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_exception.dart';

final _log = Logger('StoredPdf');

/// The server's own render of a saved billing document —
/// `GET /api/v1/<entity>/<invitationKey>/download` — or [livePreview] when
/// that render is not the one to show, or the server will not give it.
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
/// [livePreview] runs instead when there is no [storedPdfKey] (see
/// `BillingDocStoredPdf.storedPdfInvitationKey`: unsaved, unsynced edits, or
/// no invitation), or when [designId] asks for a design other than the
/// document's own: the download route has no design override and renders
/// the saved `design_id`.
///
/// It also runs when the server answers the stored route with an error. The
/// key is the first invitation *held locally*, and it can be dead: deleting
/// a client contact soft-deletes that contact's invitations
/// (`ClientContactObserver::deleted`) without touching the document's
/// `updated_at`, so no refresh brings the new ones, and the route answers
/// `400 no record found`. The re-render lacks a signature; nothing at all
/// is worse.
///
/// Only a refusal — an HTTP error status — falls back. A connection failure
/// would fail the same way twice; a permission denial is about this user,
/// and the re-render would be denied too; and a redirect or a 2xx that is
/// not a PDF (a proxy rewriting the response) is something to surface, not
/// to paper over with an unsigned copy on every open. Those, and anything
/// about the session, still throw.
Future<Uint8List> fetchStoredPdf({
  required ApiClient client,
  required String entity,
  required String? storedPdfKey,
  required Map<String, dynamic> entityJson,
  required Future<Uint8List> Function() livePreview,
  String? designId,
}) async {
  if (storedPdfKey == null || storedPdfKey.isEmpty) return livePreview();
  final ownDesign = (entityJson['design_id'] as String?) ?? '';
  if (designId != null && designId.isNotEmpty && designId != ownDesign) {
    return livePreview();
  }
  try {
    return await client.getRaw(
      '/api/v1/$entity/${Uri.encodeComponent(storedPdfKey)}/download',
      readOnly: true,
    );
  } on PermissionDeniedException {
    rethrow;
  } on ServerException catch (e) {
    // A refused redirect (3xx) or the content-type guard on a 2xx.
    if (e.statusCode < 400) rethrow;
    _log.warning(
      'Stored $entity PDF refused (HTTP ${e.statusCode}: ${e.message}); '
      'rendering it with live_preview instead',
    );
  } on NotFoundException catch (e) {
    _log.warning(
      'Stored $entity PDF not found (${e.message}); '
      'rendering it with live_preview instead',
    );
  }
  return livePreview();
}
