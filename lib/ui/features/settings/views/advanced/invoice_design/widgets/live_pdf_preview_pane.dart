import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/enabled_modules.dart';
import 'package:admin/data/services/live_design_service.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/save_download.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/utils/pdf_bytes_guard.dart';

/// Renders a live PDF preview of the current draft settings via
/// `POST /api/v1/live_design`. Listens to [SettingsDraftHost] and debounces
/// re-renders by 400 ms after any discrete change.
///
/// Designed to be embedded as a side pane on the Invoice Design General tab
/// at wide widths, or pushed into a full-screen modal sheet on narrow ones.
/// The pane manages its own request lifecycle — only the entity-type
/// selector lives in shared state.
///
/// When [embedded] is true (the wide-window side pane), the pane drops its
/// own "Preview" title strip and hides `PdfPreview`'s built-in print/share
/// toolbar — the only chrome left is the entity-type segmented control. On
/// narrow / modal use ([embedded] = false, default), the title strip + the
/// default `PdfPreview` toolbar are retained because the surrounding modal
/// is full-screen.
class LivePdfPreviewPane extends StatefulWidget {
  const LivePdfPreviewPane({
    super.key,
    required this.service,
    this.enabledModulesBitmask = 0,
    this.embedded = false,
  });

  final LiveDesignService service;

  /// Used to populate the entity-type selector. Pass
  /// `company.enabledModules` so disabled modules are filtered out.
  final int enabledModulesBitmask;

  /// True when the pane is mounted as a side pane (wide layout). Hides the
  /// title strip and the built-in `PdfPreview` toolbar so the column is one
  /// thin header + the rendered page.
  final bool embedded;

  @override
  State<LivePdfPreviewPane> createState() => _LivePdfPreviewPaneState();
}

class _LivePdfPreviewPaneState extends State<LivePdfPreviewPane> {
  static const Duration _debounce = Duration(milliseconds: 400);

  late SettingsDraftHost _host;
  Timer? _debounceTimer;
  String _entityType = 'invoice';

  Uint8List? _bytes;
  bool _loading = false;
  Object? _error;
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    _host = context.read<SettingsDraftHost>();
    _host.addListener(_onHostChanged);
    _entityType = _initialEntityType();
    // First-paint render: schedule post-frame so `setState` inside
    // `_renderNow` doesn't fire before the first build commits.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _renderNow();
    });
  }

  /// Follow a host *replacement* — `SettingsCompanyScopedHost` disposes the
  /// ViewModel and provides a fresh one in place on a company switch, with
  /// no key on this subtree. Without re-binding, every render would keep
  /// posting the disposed previous company's settings blob (wrong
  /// logo/colors/layout) and never update again. Called from [build] (the
  /// swap reaches this widget as a parent-driven rebuild; `read` registers
  /// no dependency, so `didChangeDependencies` never fires for it). The
  /// `identical` guard keeps ordinary rebuilds cheap and ensures the
  /// listener is never double-attached.
  void _rebindHostIfReplaced() {
    final next = context.read<SettingsDraftHost>();
    if (identical(next, _host)) return;
    _host.removeListener(_onHostChanged);
    _host = next;
    _host.addListener(_onHostChanged);
    // Build is in progress — `_renderNow` setStates, so defer one frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _renderNow();
    });
  }

  String _initialEntityType() {
    final options = _entityOptions();
    if (options.isEmpty) return 'invoice';
    return options.first.value;
  }

  @override
  void didUpdateWidget(LivePdfPreviewPane old) {
    super.didUpdateWidget(old);
    // If the company toggles modules and the active entity type falls off
    // the available list, snap to the first remaining option. Doing this
    // here (not in `build`) avoids a `setState`-during-build anti-pattern.
    if (widget.enabledModulesBitmask != old.enabledModulesBitmask) {
      final options = _entityOptions();
      if (options.isNotEmpty && options.every((o) => o.value != _entityType)) {
        setState(() => _entityType = options.first.value);
        _renderNow();
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _host.removeListener(_onHostChanged);
    super.dispose();
  }

  void _onHostChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, _renderNow);
  }

  Future<void> _renderNow() async {
    final seq = ++_requestSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final level = context.read<SettingsLevelController>();
      final settingsType = switch (level.level) {
        SettingsLevel.company => 'company',
        SettingsLevel.group => 'group',
        SettingsLevel.client => 'client',
      };
      final bytes = await widget.service.renderPreview(
        entityType: _entityType,
        settings: _host.settings,
        settingsType: settingsType,
        groupId: level.isGroup ? level.targetId : null,
        clientId: level.isClient ? level.targetId : null,
      );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _bytes = bytes;
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

  List<({String value, String labelKey})> _entityOptions() {
    final on = isModuleEnabled;
    final m = widget.enabledModulesBitmask;
    return [
      if (on(m, EnabledModule.invoices))
        (value: 'invoice', labelKey: 'invoice'),
      if (on(m, EnabledModule.quotes)) (value: 'quote', labelKey: 'quote'),
      if (on(m, EnabledModule.credits)) (value: 'credit', labelKey: 'credit'),
      if (on(m, EnabledModule.purchaseOrders))
        (value: 'purchase_order', labelKey: 'purchase_order'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    _rebindHostIfReplaced();
    final options = _entityOptions();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          embedded: widget.embedded,
          options: options,
          entityType: _entityType,
          onChanged: (v) {
            setState(() => _entityType = v);
            _renderNow();
          },
          showProgress: _loading,
        ),
        const Divider(height: 1),
        Expanded(child: _buildBody(context)),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    final bytes = _bytes;
    final err = _error;
    if (bytes == null && _loading && err == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (bytes == null && err != null) {
      return ErrorView(
        message: _errorMessage(context, err),
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
    // Embedded mode: hide `PdfPreview`'s built-in print/share toolbar and
    // top-align the page so it doesn't float in the middle of tall windows.
    // Non-embedded mode (full-screen modal) keeps the default toolbar.
    //
    // Deliberate divergence from the spec which called for the entity-type
    // segmented control to live inside `PdfPreview.actions` as a
    // `PdfPreviewAction`. The actions slot only takes icon-shaped widgets
    // (a wide `SegmentedButton` cramps the row), and stacking a custom
    // header with the segmented control reads more cleanly than a single
    // overcrowded toolbar. The cost is that the embedded pane drops the
    // print/share icons entirely — fine here because Cmd+P from the
    // surrounding form still works.
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
      pdfFileName: 'invoice_design_preview.pdf',
    );
    if (!widget.embedded) {
      return preview;
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 1100),
        child: preview,
      ),
    );
  }

  String _errorMessage(BuildContext context, Object e) {
    final raw = e.toString();
    if (raw.contains('SocketException')) {
      return context.tr('offline');
    }
    return raw;
  }
}

/// Slim top header. In embedded mode it's just the entity-type segmented
/// control (no "Preview" label — the `VerticalDivider` is the boundary).
/// Includes a thin `LinearProgressIndicator` underneath while a request is
/// in flight, so re-renders read as "working" without blocking the
/// previous PDF.
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
        // Thin progress strip below the header during a render request.
        // Replaces the old translucent full-screen scrim — the previous
        // PDF stays visible so the user sees the diff, not a blank screen.
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
