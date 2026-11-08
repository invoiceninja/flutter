import 'package:flutter/widgets.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/domain/docuninja/docuninja_signed.dart';
import 'package:admin/ui/features/billing_shared/detail/signed_document_pill.dart';

/// The `?signed=1` half of an invoice's, quote's or purchase order's PDF
/// route: the Signed Document pill opens the stored signed copy even while
/// the record has unsynced edits (docs/docuninja.md).
///
/// The flag is only a request. A restored or remembered link can outlive
/// what made it true, so the route asks for the signed copy only while the
/// server would still serve it: DocuNinja active for the company and the
/// plan, the document signed, and the signed file still attached. Otherwise
/// it shows what the PDF route always shows, a dirty record included.
mixin SignedCopyRouteMixin<T extends StatefulWidget> on State<T> {
  Company? _company;
  bool _ready = true;

  /// From `initState`, when the route carries `?signed=1`: reads the
  /// company row once, which decides whether DocuNinja is still on.
  void initSignedCopy(Services services, String companyId, bool requested) {
    if (!requested) return;
    _ready = false;
    services.company
        .watchCompany(companyId)
        .first
        .then((c) => _company = c, onError: (Object _) => _company = null)
        .whenComplete(() {
          if (mounted) setState(() => _ready = true);
        });
  }

  /// False until [initSignedCopy]'s read answers; the route waits for it,
  /// so its first fetch already asks for the right render.
  bool get signedCopyReady => _ready;

  /// Whether this fetch asks for the stored signed copy.
  bool opensSignedCopy({
    required Services services,
    required bool requested,
    required Map<String, dynamic>? sync,
    required List<Document> documents,
  }) =>
      requested &&
      _ready &&
      showSignedDocumentPill(
        sync,
        _company,
        planActive: docuNinjaPlanActive(services.auth.session.value),
      ) &&
      hasSignedFile(sync, documents.map((d) => d.id));
}
