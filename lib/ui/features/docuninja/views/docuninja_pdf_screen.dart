import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/env.dart';
import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/data/services/docuninja/docuninja_api.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/save_bytes.dart';
import 'package:admin/ui/core/utils/save_download.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/utils/file_names.dart';

/// A completed DocuNinja document's signed PDF (`/docuninja/:id/pdf`), React's
/// `pdf/Pdf.tsx`. Downloads follow the app's rules (docs/file-downloads.md).
class DocuNinjaPdfScreen extends StatefulWidget {
  const DocuNinjaPdfScreen({super.key, required this.id});

  final String id;

  @override
  State<DocuNinjaPdfScreen> createState() => _DocuNinjaPdfScreenState();
}

class _DocuNinjaPdfScreenState extends State<DocuNinjaPdfScreen> {
  Future<({Uint8List bytes, String name})>? _pdf;

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
    if (doc.status != DnDocumentStatus.completed) {
      if (mounted) context.go('/docuninja/${widget.id}');
      throw StateError('Not completed');
    }
    final file = await api.download(widget.id);
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
    appBar: AppBar(title: Text(context.tr('view_pdf'))),
    body: FutureBuilder(
      future: _pdf,
      builder: (context, snapshot) {
        final pdf = snapshot.data;
        if (snapshot.hasError) {
          return ErrorView(
            message: context.tr('an_error_occurred_try_again'),
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
}
