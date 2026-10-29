import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/enabled_modules.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/live_design_service.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/save_download.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/ui/features/settings/view_models/design_edit_view_model.dart';
import 'package:admin/utils/pdf_bytes_guard.dart';

/// Live PDF preview of an **in-progress** custom design. Sibling of
/// `LivePdfPreviewPane`, but bound to a [DesignEditViewModel] instead of the
/// settings `SettingsDraftHost` — so it works on the editor's pushed
/// `MaterialPageRoute` where no settings-draft / cascade provider scope
/// exists. It deliberately does **not** read `SettingsDraftHost` or
/// `SettingsLevelController` from context.
///
/// Debounces re-renders 400 ms after any draft change, keeps the last good
/// PDF visible while a new one renders, and on a 422 surfaces the
/// section-specific Twig/HTML error via [onSectionErrors] (the workspace
/// pins it to the offending section tab) instead of replacing the preview
/// with a raw exception card.
class DesignLivePreviewPane extends StatefulWidget {
  const DesignLivePreviewPane({
    super.key,
    required this.service,
    required this.vm,
    this.enabledModulesBitmask = 0,
    this.embedded = false,
    this.onSectionErrors,
  });

  final LiveDesignService service;
  final DesignEditViewModel vm;

  /// `company.enabledModules` — filters the entity-type selector.
  final int enabledModulesBitmask;

  /// True for the wide-window side pane: drops the title strip and the
  /// `PdfPreview` print/share toolbar.
  final bool embedded;

  /// Fired after every render with the section→message map decoded from a
  /// 422 (empty map clears). The workspace badges the affected section tabs.
  final ValueChanged<Map<String, String>>? onSectionErrors;

  @override
  State<DesignLivePreviewPane> createState() => _DesignLivePreviewPaneState();
}

class _DesignLivePreviewPaneState extends State<DesignLivePreviewPane> {
  static const Duration _debounce = Duration(milliseconds: 400);

  // Remembered per design id so re-opening an editor keeps the last
  // previewed document type instead of snapping back to "invoice".
  static final Map<String, String> _entityByDesign = {};

  Timer? _debounceTimer;
  String _entityType = 'invoice';

  Uint8List? _bytes;
  bool _loading = false;
  Object? _error;
  int _requestSeq = 0;

  String get _designKey =>
      widget.vm.original?.id ?? '__new__${widget.vm.hashCode}';

  @override
  void initState() {
    super.initState();
    widget.vm.addListener(_onDraftChanged);
    _entityType = _initialEntityType();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _renderNow();
    });
  }

  @override
  void didUpdateWidget(DesignLivePreviewPane old) {
    super.didUpdateWidget(old);
    if (!identical(old.vm, widget.vm)) {
      old.vm.removeListener(_onDraftChanged);
      widget.vm.addListener(_onDraftChanged);
      _onDraftChanged();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    widget.vm.removeListener(_onDraftChanged);
    super.dispose();
  }

  void _onDraftChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, _renderNow);
  }

  String _initialEntityType() {
    final options = _entityOptions();
    final remembered = _entityByDesign[_designKey];
    if (remembered != null && options.any((o) => o.value == remembered)) {
      return remembered;
    }
    return options.isEmpty ? 'invoice' : options.first.value;
  }

  List<({String value, String labelKey})> _entityOptions() {
    final on = isModuleEnabled;
    final m = widget.enabledModulesBitmask;
    final selected = widget.vm.draft.entities;
    final all = <({String value, String labelKey})>[
      if (on(m, EnabledModule.invoices))
        (value: 'invoice', labelKey: 'invoice'),
      if (on(m, EnabledModule.quotes)) (value: 'quote', labelKey: 'quote'),
      if (on(m, EnabledModule.credits)) (value: 'credit', labelKey: 'credit'),
      if (on(m, EnabledModule.purchaseOrders))
        (value: 'purchase_order', labelKey: 'purchase_order'),
    ];
    // Narrow to the design's own entities when it has declared some;
    // otherwise offer everything the company has enabled.
    final scoped = all.where((o) => selected.contains(o.value)).toList();
    return scoped.isNotEmpty ? scoped : all;
  }

  Future<void> _renderNow() async {
    if (!widget.vm.templateIsNonEmpty) {
      setState(() {
        _bytes = null;
        _loading = false;
        _error = null;
      });
      widget.onSectionErrors?.call(const {});
      return;
    }
    final seq = ++_requestSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes = await widget.service.renderDesignPreview(
        entityType: _entityType,
        design: widget.vm.draft,
      );
      if (!mounted || seq != _requestSeq) return;
      widget.onSectionErrors?.call(const {});
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    } on ValidationException catch (e) {
      if (!mounted || seq != _requestSeq) return;
      final sections = designSectionErrors(e);
      widget.onSectionErrors?.call(sections);
      setState(() {
        // Keep the last good PDF visible; show a compact banner instead of
        // wiping the preview to a raw error.
        _error = sections.isNotEmpty ? sections.entries.first.value : e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _entityOptions();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          embedded: widget.embedded,
          options: options,
          entityType: _entityType,
          showProgress: _loading,
          onChanged: (v) {
            setState(() => _entityType = v);
            _entityByDesign[_designKey] = v;
            _renderNow();
          },
        ),
        const Divider(height: 1),
        if (_error != null && _bytes != null)
          _ErrorBanner(message: _errorMessage(context, _error!)),
        Expanded(child: _buildBody(context)),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    final bytes = _bytes;
    if (!widget.vm.templateIsNonEmpty) {
      return EmptyState(
        icon: Icons.dashboard_customize_outlined,
        title: context.tr('pick_a_template_to_preview'),
      );
    }
    if (bytes == null && _loading && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (bytes == null && _error != null) {
      return ErrorView(
        message: _errorMessage(context, _error!),
        onRetry: _renderNow,
      );
    }
    if (bytes == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!isRenderablePdf(bytes)) {
      // Empty / non-PDF response — don't feed printing's rasterizer a
      // zero-page document (RangeError). Show the neutral empty state.
      return EmptyState(
        icon: Icons.picture_as_pdf_outlined,
        title: context.tr('no_preview_available'),
      );
    }
    final preview = PdfPreview(
      build: (_) => bytes,
      canChangePageFormat: false,
      canChangeOrientation: false,
      canDebug: false,
      useActions: !widget.embedded,
      allowPrinting: !widget.embedded,
      // On Windows / Linux Share only opens a temp copy
      // (docs/file-downloads.md).
      allowSharing: !widget.embedded && !pdfShareOpensTempCopy(),
      maxPageWidth: 800,
      pdfFileName: 'design_preview.pdf',
    );
    if (!widget.embedded) return preview;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 1100),
        child: preview,
      ),
    );
  }

  String _errorMessage(BuildContext context, Object e) {
    if (e is String) return e;
    final raw = e.toString();
    if (raw.contains('SocketException')) return context.tr('offline');
    return raw;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.embedded,
    required this.options,
    required this.entityType,
    required this.onChanged,
    required this.showProgress,
  });

  final bool embedded;
  final List<({String value, String labelKey})> options;
  final String entityType;
  final ValueChanged<String> onChanged;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final selector = options.length > 1
        ? SegmentedButton<String>(
            segments: [
              for (final o in options)
                ButtonSegment(
                  value: o.value,
                  label: Text(context.tr(o.labelKey)),
                ),
            ],
            selected: {entityType},
            showSelectedIcon: false,
            onSelectionChanged: (set) => onChanged(set.first),
          )
        : const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: InSpacing.md(context),
            vertical: embedded ? InSpacing.sm : InSpacing.md(context),
          ),
          child: embedded
              ? Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: selector,
                )
              : Row(
                  children: [
                    Text(
                      context.tr('preview'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    selector,
                  ],
                ),
        ),
        SizedBox(
          height: 2,
          child: showProgress
              ? const LinearProgressIndicator(minHeight: 2)
              : null,
        ),
      ],
    );
  }
}

/// Compact strip shown above a still-valid preview when the latest render
/// failed validation — the previous PDF stays visible underneath.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Container(
      width: double.infinity,
      color: tokens.overdueSoft,
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.md(context),
        vertical: InSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: tokens.overdue),
          SizedBox(width: InSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: tokens.overdue, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
