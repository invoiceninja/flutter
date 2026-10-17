import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'package:admin/data/models/domain/document.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/utils/save_bytes.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/utils/document_preview.dart';

/// Opens [doc] in the in-app viewer: a PDF in `printing`'s [PdfPreview], an
/// image in an [InteractiveViewer], anything else as a "no preview" state with
/// a Download button.
///
/// [fetch] returns the file's bytes — `DocumentsApi.download`, which carries
/// the API token. The document's own `url` is never opened: it is an API route
/// that answers a browser with `{"message":"Invalid token"}`
/// (`docs/document-urls.md`).
Future<void> showDocumentViewer(
  BuildContext context, {
  required Document doc,
  required Future<Uint8List> Function() fetch,
}) => showDialog<void>(
  context: context,
  builder: (_) => DocumentViewer(doc: doc, fetch: fetch),
);

/// The viewer [showDocumentViewer] puts in a dialog — full screen on a narrow
/// window, a large windowed dialog otherwise. Public so it can be pumped on
/// its own in a test.
class DocumentViewer extends StatefulWidget {
  const DocumentViewer({super.key, required this.doc, required this.fetch});

  final Document doc;
  final Future<Uint8List> Function() fetch;

  @override
  State<DocumentViewer> createState() => _DocumentViewerState();
}

/// A 200 with nothing in it: the server starts streaming before it reads the
/// file, so a file missing from storage arrives as an empty body rather than
/// an error status.
class _EmptyFile implements Exception {
  const _EmptyFile();
}

class _DocumentViewerState extends State<DocumentViewer> {
  /// Set by the body once the file has arrived — what the Download button in
  /// the bar saves.
  Uint8List? _bytes;

  Document get _doc => widget.doc;

  String get _title => _doc.name.isNotEmpty ? _doc.name : _doc.hash;

  Future<void> _download() async {
    final bytes = _bytes;
    if (bytes == null) return;
    await saveBytesAs(
      context,
      fileName: documentFileName(_doc.name, _doc.type),
      bytes: bytes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: context.tr('close'),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(_title, overflow: TextOverflow.ellipsis),
        actions: [
          if (_bytes != null)
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: context.tr('download'),
              onPressed: _download,
            ),
        ],
      ),
      body: SafeArea(
        child: DocumentPreviewBody(
          doc: _doc,
          fetch: widget.fetch,
          onLoaded: (bytes) => setState(() => _bytes = bytes),
        ),
      ),
    );
    final size = MediaQuery.sizeOf(context);
    if (size.width < Breakpoints.wide) {
      return Dialog.fullscreen(child: scaffold);
    }
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: size.width * 0.9 > 960 ? 960 : size.width * 0.9,
        height: size.height * 0.9,
        child: scaffold,
      ),
    );
  }
}

/// The viewer's content without its dialog chrome: fetches the file, then
/// draws it — a PDF in [PdfPreview], an image in an [InteractiveViewer],
/// anything else as "no preview" with a Download button — or an error with
/// Retry. [DocumentViewer] puts it in a dialog; the Documents record screen
/// puts it in a card. Needs a bounded height.
class DocumentPreviewBody extends StatefulWidget {
  const DocumentPreviewBody({
    super.key,
    required this.doc,
    required this.fetch,
    this.onLoaded,
  });

  final Document doc;
  final Future<Uint8List> Function() fetch;

  /// The file's bytes once they arrive, or null when a fetch failed or came
  /// back empty — for a host that offers its own Download.
  final ValueChanged<Uint8List?>? onLoaded;

  @override
  State<DocumentPreviewBody> createState() => _DocumentPreviewBodyState();
}

class _DocumentPreviewBodyState extends State<DocumentPreviewBody> {
  Uint8List? _bytes;
  Object? _error;
  bool _loading = true;
  int _generation = 0;

  Document get _doc => widget.doc;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final myGen = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes = await widget.fetch();
      if (!mounted || myGen != _generation) return;
      setState(() {
        _bytes = bytes.isEmpty ? null : bytes;
        _error = bytes.isEmpty ? const _EmptyFile() : null;
        _loading = false;
      });
      widget.onLoaded?.call(_bytes);
    } catch (e) {
      if (!mounted || myGen != _generation) return;
      setState(() {
        _bytes = null;
        _error = e;
        _loading = false;
      });
      widget.onLoaded?.call(null);
    }
  }

  Future<void> _download() async {
    final bytes = _bytes;
    if (bytes == null) return;
    await saveBytesAs(
      context,
      fileName: documentFileName(_doc.name, _doc.type),
      bytes: bytes,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final bytes = _bytes;
    if (bytes == null) {
      final err = _error ?? const _EmptyFile();
      return ErrorView(
        message: err is _EmptyFile
            ? context.tr('document_file_empty')
            : err is NotFoundException
            ? context.tr('document_not_found')
            : context.tr('failed_to_load_with_error', {
                'error': formatNotifyError(err),
              }),
        // Retrying a file the server has deleted can only fail again.
        onRetry: err is NotFoundException ? null : _load,
      );
    }
    final noPreview = _NoPreview(onDownload: _download);
    switch (previewKindForBytes(_doc.type, bytes)) {
      case DocumentPreviewKind.pdf:
        // Disabled selection for the same reason as `BillingDocPdfView`: an
        // ancestor `SelectionArea` would otherwise take the preview's
        // drag-to-pan and scroll gestures.
        return SelectionContainer.disabled(
          child: PdfPreview(
            build: (_) => bytes,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            maxPageWidth: 800,
            pdfFileName: documentFileName(_doc.name, _doc.type),
          ),
        );
      case DocumentPreviewKind.image:
        return InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              // The decoder is the only honest judge of an image: a `.png`
              // that isn't one lands here, not in a red error box.
              errorBuilder: (context, error, stackTrace) => noPreview,
            ),
          ),
        );
      case DocumentPreviewKind.none:
        return noPreview;
    }
  }
}

class _NoPreview extends StatelessWidget {
  const _NoPreview({required this.onDownload});

  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.description_outlined,
      title: context.tr('no_preview_available'),
      action: FilledButton.icon(
        // Sized to its label — the theme default is full width.
        style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
        onPressed: onDownload,
        icon: const Icon(Icons.download_outlined),
        label: Text(context.tr('download')),
      ),
    );
  }
}
