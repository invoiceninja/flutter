import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/save_bytes.dart';
import 'package:admin/ui/core/utils/save_download.dart';
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
///   * A different document ([revision], the delivery-note toggle) → keep the
///     last-good PDF visible behind a translucent overlay so the user
///     doesn't see a blink; an error drops it for [ErrorView] with retry.
///   * Newer content of the same document ([contentRevision]) → a quiet
///     refresh: the last-good PDF stays usable under a thin progress bar,
///     and an error keeps it, marked stale, with a retry.
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
    this.contentRevision,
    this.hasUnsyncedChanges = false,
    this.autoRefreshDebounce = const Duration(milliseconds: 600),
    this.onOpenFullSize,
  });

  /// Adds a Maximize button to the toolbar, beside print and share. The wide
  /// detail screen's pane passes it: there the PDF gets only part of the
  /// window, and the toolbar is where a user looks for a bigger one. Called
  /// with whether the view shows the delivery note, so the full-size screen
  /// opens on the same document.
  final ValueChanged<bool>? onOpenFullSize;

  /// Which document this is. A change by `==` re-fetches at once, behind the
  /// scrim, and an error drops the last-good PDF — showing it under the next
  /// document's title would be a lie. The history version seam passes the
  /// selected activity id.
  final Object? revision;

  /// The document's content. A change by `==` re-fetches after
  /// [autoRefreshDebounce] without blocking the pane, and an error keeps the
  /// last-good PDF, marked stale. Every caller showing a live document passes
  /// the freezed record (deep equality, so a re-emit of an unchanged row does
  /// not re-fetch) — the edit screens their draft, the record screens and
  /// `/pdf` routes the watched row, so a save lands in the preview without
  /// reopening the record. See docs/pdf-preview-refresh.md.
  final Object? contentRevision;

  /// The document carries a local edit the server has not seen yet. Only the
  /// delivery note reads it: that variant is the server's saved copy, so it
  /// cannot show the edit, and the view says so instead of passing it off as
  /// current.
  final bool hasUnsyncedChanges;

  /// Quiet period after a [contentRevision] change before the refetch fires.
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

  /// Handed to [PdfPreview.build], and replaced only where [_bytes] is.
  /// `PdfPreview` re-rasters whenever this closure changes identity, and its
  /// raster skips — never retries — a request that lands while one is still
  /// running (upstream-workarounds.md #14). A closure rebuilt on every build
  /// re-rastered the old bytes on each scrim toggle, and new bytes arriving
  /// mid-raster were dropped: the same stale page this view exists to fix.
  LayoutCallback? _build;
  Object? _error;
  bool _loading = true;

  /// A quiet ([BillingDocPdfView.contentRevision]) refresh is in flight.
  bool _refreshing = false;

  /// The progress bar for [_refreshing], held back so a fast refresh draws
  /// nothing at all.
  bool _showProgress = false;

  /// The last quiet refresh failed, so the PDF on screen predates the
  /// document's latest content.
  bool _stale = false;
  late bool _deliveryNote = widget.initialDeliveryNote;
  String? _designId;
  int _generation = 0;
  Timer? _debounce;
  Timer? _progressDelay;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(BillingDocPdfView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different document wins over newer content in the same rebuild:
    // switching back to the live document changes both.
    if (widget.revision != oldWidget.revision) {
      _debounce?.cancel();
      _debounce = Timer(Duration.zero, () {
        if (mounted) _load();
      });
    } else if (widget.contentRevision != oldWidget.contentRevision) {
      _debounce?.cancel();
      _debounce = Timer(widget.autoRefreshDebounce, () {
        if (mounted) _load(quiet: true);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _progressDelay?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    // A quiet refresh needs a PDF to keep on screen; from the spinner or the
    // error view it is an ordinary load. So is one that lands while a full
    // load (a version switch, the delivery-note toggle) is still pending: the
    // bytes on screen are then the *previous* document's, and keeping them
    // would put one document under another's title.
    final keep = quiet && _bytes != null && !_loading;
    _debounce?.cancel();
    _progressDelay?.cancel();
    setState(() {
      _loading = !keep;
      _refreshing = keep;
      _showProgress = false;
      _error = null;
    });
    if (keep) {
      _progressDelay = Timer(const Duration(milliseconds: 300), () {
        if (mounted && _refreshing) setState(() => _showProgress = true);
      });
    }
    final myGen = ++_generation;
    try {
      final bytes = await widget.fetcher(
        designId: _designId,
        deliveryNote: _deliveryNote,
      );
      if (!mounted || myGen != _generation) return;
      setState(() {
        _bytes = bytes;
        _build = (_) => bytes;
        _loading = false;
        _refreshing = false;
        _showProgress = false;
        _stale = false;
      });
    } catch (e) {
      if (!mounted || myGen != _generation) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _showProgress = false;
        if (keep) {
          // Newer content of the same document failed to render — offline,
          // most often, since `live_preview` is a POST. The PDF on screen is
          // still this document, so it stays, marked stale; the outbox's
          // echo changes the row again and refreshes it without a tap.
          _stale = true;
          return;
        }
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
        _build = null;
        _stale = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    final build = _build;
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
    if (bytes == null || build == null) {
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
    final showToggle =
        widget.entity.supportsDeliveryNote && widget.deliveryNoteAvailable;
    // The delivery note is the server's saved copy, so an unsynced edit is
    // missing from it however often it is re-fetched.
    final unsyncedNote =
        showToggle && _deliveryNote && widget.hasUnsyncedChanges;
    final stale = _stale || unsyncedNote;
    final previewName = '${widget.entity.wireName}_preview';
    final baseName = widget.entityNumber.isEmpty
        ? previewName
        : '${widget.entity.wireName}_${widget.entityNumber}';
    // A downloaded delivery note must not take the document's own name.
    final rawName = showToggle && _deliveryNote
        ? '${baseName}_delivery_note'
        : baseName;
    final fileName = '${sanitizeFileName(rawName, fallback: previewName)}.pdf';
    final scrim = Theme.of(context).colorScheme.scrim.withValues(alpha: 0.4);
    final preview = Stack(
      children: [
        Positioned.fill(
          child: PdfPreview(
            build: build,
            // Printing or sharing a stale render would send out a document
            // that no longer matches the record. On Windows / Linux the
            // package's Share only opens a temp copy; Download replaces it
            // (docs/file-downloads.md).
            allowPrinting: !stale,
            allowSharing: !stale && !pdfShareOpensTempCopy(),
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            maxPageWidth: 800,
            pdfFileName: fileName,
            actions: [
              if (Env.isDesktop && !stale)
                IconButton(
                  icon: const Icon(Icons.download),
                  tooltip: context.tr('download_pdf'),
                  onPressed: () =>
                      downloadPdf(context, fileName: fileName)(bytes),
                ),
              if (widget.onOpenFullSize case final open?)
                IconButton(
                  icon: const Icon(Icons.open_in_full),
                  tooltip: context.tr('maximize'),
                  onPressed: () => open(_deliveryNote),
                ),
            ],
          ),
        ),
        if (stale || showToggle)
          PositionedDirectional(
            top: InSpacing.md(context),
            start: InSpacing.md(context),
            end: InSpacing.md(context),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Empty space here passes taps through to the PDF: neither
                // `Align` nor `Row` hit-tests itself.
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: stale
                        ? _StaleNotice(
                            // Only a failed fetch is worth retrying; the
                            // delivery note can't show the edit at all.
                            onRetry: _stale ? () => _load(quiet: true) : null,
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                if (showToggle) ...[
                  SizedBox(width: InSpacing.md(context)),
                  _DeliveryNoteToggle(
                    value: _deliveryNote,
                    onChanged: (v) {
                      setState(() => _deliveryNote = v);
                      _load();
                    },
                  ),
                ],
              ],
            ),
          ),
        if (_showProgress)
          const PositionedDirectional(
            top: 0,
            start: 0,
            end: 0,
            child: LinearProgressIndicator(minHeight: 2),
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

/// Says the PDF on screen predates the document's latest content, so it is
/// never passed off as current. A floating card like [_DeliveryNoteToggle],
/// over the PDF rather than above it: a slot that comes and goes above the
/// preview would resize it and re-raster every page.
class _StaleNotice extends StatelessWidget {
  const _StaleNotice({required this.onRetry});

  /// Null when retrying cannot help (the delivery note of a document with an
  /// unsynced edit).
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.inTheme;
    final retry = onRetry;
    return Material(
      color: t.warningSoft,
      elevation: 2,
      borderRadius: BorderRadius.circular(InRadii.r2),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: InSpacing.md(context),
          end: retry == null ? InSpacing.md(context) : 4,
          top: 4,
          bottom: 4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sync_problem_outlined, size: 16, color: t.warning),
            const SizedBox(width: 8),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  context.tr('pdf_preview_out_of_date'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: t.ink),
                ),
              ),
            ),
            if (retry != null) ...[
              const SizedBox(width: 4),
              TextButton(onPressed: retry, child: Text(context.tr('retry'))),
            ],
          ],
        ),
      ),
    );
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
