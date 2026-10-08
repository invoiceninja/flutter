import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/live_design_service.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/view_models/design_edit_view_model.dart';
import 'package:admin/utils/pdf_bytes_guard.dart';

/// Server-PDF preview of the current WYSIWYG draft. Sends the [Design]
/// through `POST /api/v1/preview?html=false` via
/// [LiveDesignService.renderDesignPreview] and renders the response bytes
/// with the `printing` package.
///
/// Phase 0 confirmed the server accepts the new `blocks` +
/// `documentSettings` shape; Phase 1.5 #1 makes sure the annotated blocks
/// ride along on the request. 422 responses surface as an inline banner
/// (no green PDF over a real error).
///
/// Entity-type picker lives in the header — the design's `entities` list
/// drives the options (e.g. `['invoice', 'quote', 'credit']`). Defaults to
/// the first entity.
class WysiwygPreviewSheet extends StatefulWidget {
  const WysiwygPreviewSheet({
    super.key,
    required this.service,
    required this.design,
    this.initialEntityType,
    this.debounce = const Duration(milliseconds: 800),
    this.isPro = true,
    this.onClose,
    this.embedded = false,
    this.entityId,
    this.documentPicker,
    this.onEntityTypeChanged,
  });

  final LiveDesignService service;
  final Design design;

  /// Initial entity type (defaults to `design.entities.first` or
  /// `'invoice'` if the list is empty).
  final String? initialEntityType;

  /// Time between [design] / entity-type changes and the server call. Tests
  /// pass [Duration.zero] to skip the wait.
  final Duration debounce;

  /// When false, overlay a diagonal "Pro required" watermark over the
  /// rendered PDF — Phase 8l acceptance criterion. Defaults to `true`
  /// so existing call sites + tests aren't affected; the WYSIWYG screen
  /// passes the auth-derived value explicitly.
  final bool isPro;

  /// What the header's close button does. Null pops the route — right for a
  /// sheet; the designer shows the preview in place of its canvas and passes
  /// the switch back.
  final VoidCallback? onClose;

  /// Shown in place of the designer's canvas rather than as a sheet: the
  /// screen's own Design | Preview switch is the title and the way back, so
  /// the header carries neither.
  final bool embedded;

  /// The invoice to render, when previewing an invoice. Null leaves the
  /// choice of document to the server.
  final String? entityId;

  /// The control that chooses [entityId], shown in the header beside the
  /// document type while that type is `invoice`.
  final Widget? documentPicker;

  /// Reports the document type picked, so the owner can open the next
  /// preview on it instead of back on the first.
  final ValueChanged<String>? onEntityTypeChanged;

  @override
  State<WysiwygPreviewSheet> createState() => _WysiwygPreviewSheetState();
}

class _WysiwygPreviewSheetState extends State<WysiwygPreviewSheet> {
  late String _entityType;
  Timer? _debounce;
  bool _loading = false;
  Uint8List? _pdf;
  String? _errorMessage;
  Map<String, List<String>>? _fieldErrors;
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    _entityType =
        widget.initialEntityType ??
        widget.design.entities.firstOrNull ??
        'invoice';
    _scheduleRender(immediate: true);
  }

  @override
  void didUpdateWidget(WysiwygPreviewSheet old) {
    super.didUpdateWidget(old);
    // Re-render when the design draft changes (parent rebuilds with a new
    // [Design] reference each time the VM notifies).
    if (old.entityId != widget.entityId) {
      // A different document is a different picture: no waiting.
      _scheduleRender(immediate: true);
    } else if (!identical(old.design, widget.design)) {
      _scheduleRender();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onEntityChanged(String? next) {
    if (next == null || next == _entityType) return;
    setState(() => _entityType = next);
    widget.onEntityTypeChanged?.call(next);
    _scheduleRender(immediate: true);
  }

  /// The chosen invoice, while it is an invoice being previewed.
  String? get _realEntityId =>
      _entityType == 'invoice' ? widget.entityId : null;

  void _scheduleRender({bool immediate = false}) {
    _debounce?.cancel();
    if (immediate || widget.debounce == Duration.zero) {
      _render();
      return;
    }
    _debounce = Timer(widget.debounce, _render);
  }

  Future<void> _render() async {
    if (!mounted) return;
    final seq = ++_requestSeq;
    setState(() {
      _loading = true;
      _errorMessage = null;
      _fieldErrors = null;
    });
    try {
      final bytes = await widget.service.renderDesignPreview(
        entityType: _entityType,
        design: widget.design,
        entityId: _realEntityId,
      );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        // Guard: an empty / non-PDF body would crash printing's rasterizer
        // (RangeError on a zero-page document). Leave _pdf null so the body
        // falls back to the existing "no preview available" placeholder.
        _pdf = isRenderablePdf(bytes) ? bytes : null;
        _loading = false;
      });
    } on ValidationException catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _loading = false;
        _errorMessage = e.message;
        _fieldErrors = e.fieldErrors;
      });
    } on NetworkException catch (_) {
      // Phase 20c: the api client wraps SocketException / TimeoutException
      // / failed-host-lookup into NetworkException. Map to a friendly
      // banner string instead of dumping the raw exception.
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _loading = false;
        _errorMessage = context.tr('network_error');
      });
    } on ApiException catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _loading = false;
        _errorMessage = e.message.trim().isEmpty
            ? context.tr('an_error_occurred')
            : e.message;
      });
    } catch (_) {
      // Not a sentence for a user: say that it failed, and offer Retry.
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _loading = false;
        _errorMessage = context.tr('an_error_occurred');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    // Phase 18: dropdown lists every supported entity type (invoice /
    // quote / credit / purchase_order; broader set for templates) so
    // the user can preview any rendering regardless of which entities
    // the design happens to be bound to. The default selection logic
    // in initState still prefers `design.entities.first` when set.
    final entityOptions = widget.design.isTemplate
        ? DesignEditViewModel.supportedTemplateEntities
        : DesignEditViewModel.supportedEntities;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Header(
          entityType: _entityType,
          entityOptions: entityOptions,
          loading: _loading,
          onChanged: _onEntityChanged,
          onClose: widget.onClose,
          embedded: widget.embedded,
          documentPicker: _entityType == 'invoice'
              ? widget.documentPicker
              : null,
          serverPicksDocument: _realEntityId == null,
        ),
        if (_errorMessage != null)
          _ErrorBanner(
            message: _errorMessage!,
            fieldErrors: _fieldErrors,
            onRetry: _loading ? null : _render,
          ),
        Expanded(
          child: _pdf == null
              ? Center(
                  child: _loading
                      ? const CircularProgressIndicator()
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.tr('no_preview_available'),
                              style: TextStyle(color: tokens.ink3),
                            ),
                            SizedBox(height: InSpacing.sm),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(64, 40),
                              ),
                              onPressed: _render,
                              child: Text(context.tr('retry')),
                            ),
                          ],
                        ),
                )
              : Stack(
                  children: [
                    PdfPreview(
                      build: (_) => _pdf!,
                      canChangePageFormat: false,
                      canChangeOrientation: false,
                      canDebug: false,
                      maxPageWidth: 800,
                      pdfFileName: 'invoice_design_preview.pdf',
                    ),
                    // Phase 8l: free-user watermark. Doesn't block
                    // pointer input — print/share buttons inside the
                    // PdfPreview stay usable.
                    if (!widget.isPro)
                      const Positioned.fill(
                        key: ValueKey('wysiwyg-preview-watermark'),
                        child: IgnorePointer(child: _PreviewWatermark()),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.entityType,
    required this.entityOptions,
    required this.loading,
    required this.onChanged,
    this.onClose,
    this.embedded = false,
    this.documentPicker,
    this.serverPicksDocument = false,
  });

  final String entityType;
  final List<String> entityOptions;
  final bool loading;
  final ValueChanged<String?> onChanged;
  final VoidCallback? onClose;
  final bool embedded;
  final Widget? documentPicker;

  /// No particular record was asked for, so what is shown is the server's
  /// choice — said, because it is not the document on the designer's page.
  final bool serverPicksDocument;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: InSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.inTheme.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          if (!embedded) ...[
            Text(
              context.tr('preview'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(width: InSpacing.lg(context)),
          ],
          DropdownButton<String>(
            value: entityType,
            underline: const SizedBox.shrink(),
            items: [
              for (final type in entityOptions)
                DropdownMenuItem(value: type, child: Text(context.tr(type))),
            ],
            onChanged: onChanged,
          ),
          if (documentPicker != null) Flexible(child: documentPicker!),
          if (embedded && serverPicksDocument)
            Flexible(
              child: Padding(
                padding: EdgeInsets.only(left: InSpacing.sm),
                child: Text(
                  context.tr('preview_server_sample'),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: context.inTheme.ink3),
                ),
              ),
            ),
          const Spacer(),
          if (loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          if (!embedded)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: context.tr('close'),
              onPressed: onClose ?? () => Navigator.of(context).maybePop(),
            )
          else
            // Keeps the row the height the close button gave it.
            const SizedBox(height: 40),
        ],
      ),
    );
  }
}

/// Phase 8l: diagonal "Pro required" watermark over the PDF preview for
/// free users. Translucent so the underlying design stays inspectable;
/// large rotated text reads as "you can preview, but not save without
/// upgrading."
class _PreviewWatermark extends StatelessWidget {
  const _PreviewWatermark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.rotate(
        angle: -math.pi / 6,
        child: Text(
          context.tr('pro_required_to_save_visual_designer').toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w900,
            color: context.inTheme.overdue.withValues(alpha: 0.18),
            letterSpacing: 4,
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, this.fieldErrors, this.onRetry});

  final String message;
  final Map<String, List<String>>? fieldErrors;

  /// Null while a render is already running.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final firstFieldError = fieldErrors?.values
        .expand((msgs) => msgs)
        .firstOrNull;
    return Material(
      color: context.inTheme.overdueSoft,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: InSpacing.lg(context),
          vertical: InSpacing.md(context),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 18, color: context.inTheme.overdue),
            SizedBox(width: InSpacing.sm),
            Expanded(
              child: Text(
                firstFieldError ?? message,
                style: TextStyle(color: context.inTheme.overdue),
              ),
            ),
            SizedBox(width: InSpacing.sm),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: context.inTheme.overdue,
                minimumSize: const Size(44, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onRetry,
              child: Text(context.tr('retry')),
            ),
          ],
        ),
      ),
    );
  }
}
