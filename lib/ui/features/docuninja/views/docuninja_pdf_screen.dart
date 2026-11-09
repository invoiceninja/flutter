import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/data/services/docuninja/docuninja_api.dart';
import 'package:admin/data/services/docuninja/docuninja_client.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/save_bytes.dart';
import 'package:admin/ui/core/utils/save_download.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_download.dart';
import 'package:admin/utils/file_names.dart';

/// A completed DocuNinja document's signed PDF (`/docuninja/:id/pdf`), React's
/// `pdf/Pdf.tsx`. Downloads follow the app's rules (docs/file-downloads.md).
class DocuNinjaPdfScreen extends StatefulWidget {
  const DocuNinjaPdfScreen({super.key, required this.id});

  final String id;

  @override
  State<DocuNinjaPdfScreen> createState() => _DocuNinjaPdfScreenState();
}

/// The signed file's fetch failed (not the document's), so a 400 means
/// DocuNinja is still making it ([dnFileErrorKey]).
class _FileFailed implements Exception {
  const _FileFailed(this.cause);

  final Object cause;
}

class _DocuNinjaPdfScreenState extends State<DocuNinjaPdfScreen> {
  Future<({Uint8List bytes, String name})>? _pdf;

  /// The document's name, once its page has been read (React's breadcrumb).
  String? _title;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pdf ??= _load();
  }

  Future<({Uint8List bytes, String name})> _load() async {
    final api = context.read<DocuNinjaApi?>();
    if (api == null) throw StateError('No DocuNinja');
    // Only a completed document has a signed PDF: React sends any other
    // back to its page (a restored or linked route).
    final doc = await api.document(widget.id);
    if (mounted) {
      setState(
        () => _title = doc.description.isEmpty
            ? context.tr('untitled_document')
            : doc.description,
      );
    }
    if (doc.status != DnDocumentStatus.completed) {
      // Not from a page or branch the user has since left (a branch keeps
      // its route current offstage; its tickers stop): it would pull them
      // back.
      if (mounted &&
          TickerMode.valuesOf(context).enabled &&
          (ModalRoute.of(context)?.isCurrent ?? false)) {
        context.go('/docuninja/${widget.id}');
      }
      throw StateError('Not completed');
    }
    final DnFileBytes file;
    try {
      file = await api.download(widget.id);
    } on Object catch (e) {
      throw _FileFailed(e);
    }
    final name = sanitizeFileName(
      (file.filename ?? 'document').replaceAll(
        RegExp(r'\.pdf$', caseSensitive: false),
        '',
      ),
    );
    return (bytes: file.bytes, name: '$name.pdf');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: _appBarTitle(context)),
    body: FutureBuilder(
      future: _pdf,
      builder: (context, snapshot) {
        final pdf = snapshot.data;
        if (snapshot.hasError) {
          final error = snapshot.error;
          return ErrorView(
            // React's "File not ready for download" on a 400.
            message: context.tr(
              error is _FileFailed
                  ? dnFileErrorKey(error.cause)
                  : 'an_error_occurred_try_again',
            ),
            onRetry: () => setState(() => _pdf = _load()),
          );
        }
        if (pdf == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return PdfPreview(
          build: (_) => pdf.bytes,
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false,
          maxPageWidth: 800,
          pdfFileName: pdf.name,
          // On Windows / Linux the package's Share only opens a temp copy;
          // Download replaces it (docs/file-downloads.md).
          allowSharing: !pdfShareOpensTempCopy(),
          actions: [
            if (Env.isDesktop)
              IconButton(
                icon: const Icon(Icons.download),
                tooltip: context.tr('download_pdf'),
                onPressed: () =>
                    downloadPdf(context, fileName: pdf.name)(pdf.bytes),
              ),
          ],
        );
      },
    ),
  );

  /// React's title, with the document's name under it as its breadcrumb
  /// names it.
  Widget _appBarTitle(BuildContext context) {
    final title = _title;
    if (title == null) return Text(context.tr('view_pdf'));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('view_pdf')),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.inTheme.ink3),
        ),
      ],
    );
  }
}
