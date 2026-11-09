import 'package:flutter/material.dart';

import 'package:admin/data/services/docuninja/docuninja_client.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/save_bytes.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/utils/file_names.dart';

/// The message key for a failed DocuNinja file fetch (the signed PDF or the
/// audit log). DocuNinja answers 400 while the file is still being made, and
/// React then says `not_ready_for_download` (`useDownloadDocument.ts`);
/// anything else is the generic retry message.
String dnFileErrorKey(Object error) =>
    error is DocuNinjaException && error.statusCode == 400
    ? 'not_ready_for_download'
    : 'an_error_occurred_try_again';

/// Fetches a DocuNinja file and saves it as a PDF, under the name DocuNinja
/// gives it ([fallbackName] when it gives none), through `downloadPdf`
/// (docs/file-downloads.md). A failure is a toast ([dnFileErrorKey]), never
/// thrown. The caller keeps its own busy flag around the call.
///
/// Used by the document page (download, audit log) and the list's row menu.
Future<void> dnSaveFile(
  BuildContext context, {
  required Future<DnFileBytes> Function() fetch,
  required String fallbackName,
}) async {
  try {
    final file = await fetch();
    if (!context.mounted) return;
    final base = (file.filename ?? fallbackName).replaceAll(
      RegExp(r'\.pdf$', caseSensitive: false),
      '',
    );
    await downloadPdf(context, fileName: '${sanitizeFileName(base)}.pdf')(
      file.bytes,
    );
  } on Object catch (e) {
    if (context.mounted) Notify.error(context, context.tr(dnFileErrorKey(e)));
  }
}
