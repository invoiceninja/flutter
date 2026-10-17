import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/document_record.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/document_viewer.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/utils/document_preview.dart';

/// Past this the preview waits to be asked for, even on a wide window.
const int kDocumentAutoPreviewMaxBytes = 5 * 1000 * 1000;

/// How long a record has to stay open before its file is fetched by itself —
/// stepping through the list with J / K must not download every file passed.
const Duration kDocumentAutoPreviewDelay = Duration(milliseconds: 300);

/// An inline preview of the file on its record screen — admin-portal showed
/// one. Only for a type the app can draw (PDF, the common images); anything
/// else has nothing to preview and the card is left out.
///
/// Fetching costs the whole file, so it starts by itself only where that is
/// cheap and wanted: a wide window and a file under
/// [kDocumentAutoPreviewMaxBytes], after [kDocumentAutoPreviewDelay]. Anywhere
/// else the card offers "Show Preview".
class DocumentPreviewCard extends StatefulWidget {
  const DocumentPreviewCard({super.key, required this.document});

  final DocumentRecord document;

  /// Whether [document] is a type the preview can draw.
  static bool canPreview(DocumentRecord document) =>
      previewKindForType(document.type) != DocumentPreviewKind.none;

  @override
  State<DocumentPreviewCard> createState() => _DocumentPreviewCardState();
}

class _DocumentPreviewCardState extends State<DocumentPreviewCard> {
  bool _show = false;
  Timer? _auto;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_show || _auto != null) return;
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.wide;
    if (wide && widget.document.size <= kDocumentAutoPreviewMaxBytes) {
      _auto = Timer(kDocumentAutoPreviewDelay, () {
        if (mounted) setState(() => _show = true);
      });
    }
  }

  @override
  void dispose() {
    _auto?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DashboardCardShell(
      title: context.tr('preview'),
      child: _show
          ? SizedBox(
              height: 480,
              child: DocumentPreviewBody(
                doc: widget.document.attachment,
                fetch: _fetch,
              ),
            )
          : Center(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 40),
                ),
                onPressed: () {
                  _auto?.cancel();
                  setState(() => _show = true);
                },
                icon: const Icon(Icons.visibility_outlined),
                label: Text(context.tr('show_preview')),
              ),
            ),
    );
  }

  /// The bytes through the token-carrying client — never the document's
  /// `url` (`docs/document-urls.md`). A file the server no longer has drops
  /// its row, as View and Download do.
  Future<Uint8List> _fetch() async {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    try {
      return await services.documentsApi.download(widget.document.id);
    } on NotFoundException {
      unawaited(
        services.documents.forgetMissing(
          companyId: companyId,
          documentId: widget.document.id,
        ),
      );
      rethrow;
    }
  }
}
