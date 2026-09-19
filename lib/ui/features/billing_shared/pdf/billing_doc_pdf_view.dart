import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/ui/core/widgets/notify.dart' show formatNotifyError;
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/utils/file_names.dart';
import 'package:admin/utils/pdf_bytes_guard.dart';

/// Shared PDF preview pane for billing docs. Fetches bytes via the
/// caller-supplied [fetcher] (typically `services.invoices.api.downloadPdf`)
/// and renders via the `printing` package's [PdfPreview] (which carries
/// its own print/share/download toolbar).
///
/// State machine:
///   * First load → full-pane spinner.
///   * Subsequent reloads (design change, delivery-note toggle) → keep the
///     last-good PDF visible behind a translucent overlay so the user
///     doesn't see a blink.
///   * Error → [ErrorView] with retry.
///
/// `entity` decides what extra controls render (only [BillingDocType.invoice]
/// gets the delivery-note toggle today).
class BillingDocPdfView extends StatefulWidget {
  const BillingDocPdfView({
    super.key,
    required this.entity,
    required this.entityNumber,
    required this.fetcher,
    this.initialDeliveryNote = false,
    this.deliveryNoteAvailable = true,
    this.revision,
    this.autoRefreshDebounce = const Duration(milliseconds: 600),
  });

  /// When non-null and it changes by `==`, the preview re-fetches after
  /// [autoRefreshDebounce]. Edit screens pass the freezed draft (value
  /// equality, so any field change re-renders); detail / pdf-route screens
  /// leave it null → fetch-once, no auto-refresh.
  final Object? revision;

  /// Quiet period after a [revision] change before the refetch fires.
  final Duration autoRefreshDebounce;

  /// Whether the first render requests the delivery-note variant (and the
  /// toggle starts in the on position). Only meaningful when
  /// [BillingDocType.supportsDeliveryNote] — i.e. invoices.
  final bool initialDeliveryNote;

  /// Whether the delivery-note toggle should be offered at all. The dedicated
  /// `/api/v1/invoices/{id}/delivery_note` route needs a real (saved) id, so
  /// the edit screen passes `false` while the invoice is still `tmp_<uuid>`.
  /// Detail / pdf-route call sites watch saved entities and leave the default.
  final bool deliveryNoteAvailable;

  /// Which billing-doc type this widget is rendering. Used for the file
  /// name on download + to gate the delivery-note toggle.
  final BillingDocType entity;

  /// Human-readable identifier (e.g. invoice `number`) used as the
  /// downloaded file name's stem.
  final String entityNumber;

  /// Fetches PDF bytes. Receives `(designId, deliveryNote)` — both
  /// optional. Caller maps to the right repo/api method. Throws on
  /// failure; the widget catches and renders [ErrorView].
  final Future<Uint8List> Function({
    String? designId,
    required bool deliveryNote,
  })
  fetcher;

  @override
  State<BillingDocPdfView> createState() => _BillingDocPdfViewState();
}

class _BillingDocPdfViewState extends State<BillingDocPdfView> {
  Uint8List? _bytes;
  Object? _error;
  bool _loading = true;
  late bool _deliveryNote = widget.initialDeliveryNote;
  String? _designId;
  int _generation = 0;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(BillingDocPdfView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revision != oldWidget.revision) {
      _debounce?.cancel();
      _debounce = Timer(widget.autoRefreshDebounce, () {
        if (mounted) _load();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final myGen = ++_generation;
    try {
      final bytes = await widget.fetcher(
        designId: _designId,
        deliveryNote: _deliveryNote,
      );
      if (!mounted || myGen != _generation) return;
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || myGen != _generation) return;
      setState(() {
        _error = e;
        // Drop the last-good bytes. The "keep the previous page visible"
        // behaviour above is for the *loading* window only — holding them
        // through an error renders a stale document under whatever the
        // caller's chrome now claims is on screen, with no error shown at
        // all (the error branch in `build` is gated on `_bytes == null`).
        // Version history makes that a designed-for condition rather than a
        // corner: a `Backup` row with no stored file 404s with "No backup
        // exists for this activity" yet still appears in the version picker,
        // so picking it would otherwise leave the *live* document on screen
        // under that version's title.
        _bytes = null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    final err = _error;
    if (bytes == null && _loading && err == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (bytes == null && err != null) {
      // Localized framing + exception-type-stripped detail — a raw
      // toString() filled the content pane with Dart class names and OS
      // socket errors on the day-one "open invoice offline" flow.
      return ErrorView(
        message: context.tr('failed_to_load_with_error', {
          'error': formatNotifyError(err),
        }),
        onRetry: _load,
      );
    }
    if (bytes == null) {
      return EmptyState(
        icon: Icons.picture_as_pdf_outlined,
        title: context.tr('view_pdf'),
      );
    }
    if (!isRenderablePdf(bytes)) {
      // Empty / non-PDF response — don't feed printing's rasterizer a
      // zero-page document (RangeError).
      return EmptyState(
        icon: Icons.picture_as_pdf_outlined,
        title: context.tr('view_pdf'),
      );
    }
    // Sanitized here rather than at each producer: `entityNumber` arrives
    // carrying a company-configured document number (`INV/2026/0001` is an
    // ordinary European pattern) and, on the History tab, a saved-version
    // timestamp rendered through the company's `date_format_id` — which is `/`
    // separated on the server's own default and colon-separated on all of them.
    // `printing` hands this straight to the native share, which concatenates it
    // onto a temp path and swallows the write error, so an illegal character was
    // a Share/Download button that silently did nothing. See [sanitizeFileName].
    final previewName = '${widget.entity.wireName}_preview';
    final rawName = widget.entityNumber.isEmpty
        ? previewName
        : '${widget.entity.wireName}_${widget.entityNumber}';
    final fileName = '${sanitizeFileName(rawName, fallback: previewName)}.pdf';
    final scrim = Theme.of(context).colorScheme.scrim.withValues(alpha: 0.4);
    final preview = Stack(
      children: [
        Positioned.fill(
          child: PdfPreview(
            build: (_) => bytes,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            maxPageWidth: 800,
            pdfFileName: fileName,
          ),
        ),
        if (widget.entity.supportsDeliveryNote && widget.deliveryNoteAvailable)
          Positioned(
            top: InSpacing.md(context),
            right: InSpacing.md(context),
            child: _DeliveryNoteToggle(
              value: _deliveryNote,
              onChanged: (v) {
                setState(() => _deliveryNote = v);
                _load();
              },
            ),
          ),
        if (_loading)
          Positioned.fill(
            child: ColoredBox(
              color: scrim,
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
    // Disable text selection over the PDF: an ancestor SelectionArea (entity
    // detail bodies) would otherwise capture the PdfPreview's drag-to-pan /
    // scroll gestures. No-op where there's no SelectionArea (edit layouts).
    return SelectionContainer.disabled(child: preview);
  }
}

class _DeliveryNoteToggle extends StatelessWidget {
  const _DeliveryNoteToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.inTheme;
    return Material(
      color: t.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(InRadii.r2),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: InSpacing.md(context),
          vertical: 4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('delivery_note')),
            const SizedBox(width: 8),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
