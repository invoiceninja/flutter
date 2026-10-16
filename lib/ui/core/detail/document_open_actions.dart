import 'package:flutter/widgets.dart';

import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/document.dart';
import 'package:admin/data/services/documents_api.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/save_bytes.dart';
import 'package:admin/ui/core/widgets/document_viewer.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';
import 'package:admin/utils/document_preview.dart';

// The **View** and **Download** row actions every document list shares — an
// entity's Documents tab and the company's Documents screen.
//
// Both fetch the file through `DocumentsApi.download`, which carries the API
// token. A document's `url` is that same API route, so handing it to the
// browser — what both lists did before — got `{"message":"Invalid token"}`
// back for every document there is (`docs/document-urls.md`).

/// Opens [doc] in the in-app viewer, or saves it when nothing in the app can
/// draw its type (a `.docx` has no preview to show).
Future<void> viewDocument(BuildContext context, Document doc) async {
  if (previewKindForType(doc.type) == DocumentPreviewKind.none) {
    return downloadDocument(context, doc);
  }
  final api = _documentsApi(context);
  if (api == null) return;
  await showDocumentViewer(
    context,
    doc: doc,
    fetch: () => api.download(doc.id),
  );
}

/// Fetches [doc] and saves it through the platform's save dialog.
Future<void> downloadDocument(BuildContext context, Document doc) async {
  final api = _documentsApi(context);
  if (api == null) return;
  // Resolved before the fetch, which can outlive this row.
  final toasts = Notify.capture(context);
  final l10n = Localization.of(context);
  String tr(String key, [Map<String, String>? params]) =>
      l10n?.lookup(key, params) ?? key;
  final save = bytesSaver(context);

  // A large file takes a while to arrive and the tap shows nothing else.
  final progress = toasts?.show(
    variant: NotifyVariant.info,
    message: tr('processing'),
  );
  try {
    final bytes = await api.download(doc.id);
    if (progress != null) toasts?.dismiss(progress);
    if (bytes.isEmpty) {
      // The server streams before it reads the file, so one missing from
      // storage arrives as an empty 200 — there is nothing to save.
      toasts?.error(tr('document_file_empty'));
      return;
    }
    await save(fileName: documentFileName(doc.name, doc.type), bytes: bytes);
  } catch (e) {
    if (progress != null) toasts?.dismiss(progress);
    toasts?.error(
      tr('failed_to_load_with_error', {'error': formatNotifyError(e)}),
    );
  }
}

/// The documents api, or null — with the standard toast — where no [Services]
/// is mounted. The document lists are shared leaves that some widget tests
/// pump without one.
DocumentsApi? _documentsApi(BuildContext context) {
  try {
    return context.read<Services>().documents;
  } catch (_) {
    Notify.error(context, context.tr('failed_to_open_url'));
    return null;
  }
}
