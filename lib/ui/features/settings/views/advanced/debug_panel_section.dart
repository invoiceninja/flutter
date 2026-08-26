import 'dart:typed_data';

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:admin/app/debug_capture_store.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/app/screenshot_window_controller.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';
import 'package:admin/ui/features/settings/views/advanced/debug_panel_window_controls.dart';
import 'package:admin/utils/formatting.dart';

/// Hidden Debug Panel revealed from the About dialog's "Debug Panel" button.
/// Renders as a Chrome DevTools-style band pinned to the bottom of the
/// authenticated shell: a compact toolbar (capture toggle + screenshot tools
/// on desktop + clear / copy / hide) above a Material `TabBar` switching
/// between a Network Requests list and a Recent Errors list. Reactive to
/// [DebugCaptureStore]; the desktop screenshot tools react to
/// [ScreenshotWindowController].
///
/// All data is in-memory and reset on app restart. The store applies
/// redaction (`redact()` / `redactHeaders()`) before anything reaches this
/// widget; toggling capture off pauses recording but keeps already-captured
/// entries until the user hits Clear.
class DebugPanelSection extends StatelessWidget {
  const DebugPanelSection({
    super.key,
    required this.store,
    required this.windowController,
    required this.onHide,
  });

  final DebugCaptureStore store;

  /// Screenshot tools state (window size presets + hidden traffic lights).
  /// Lives on `Services` so it survives hiding the panel for the capture.
  final ScreenshotWindowController windowController;

  /// Called when the user taps the Hide button in the toolbar. The parent
  /// flips its `_debugRevealed` back to false so the panel returns to its
  /// hidden state without requiring a screen pop.
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    // The narrow (mobile) shell hosts this band in a bare Column with no
    // Scaffold above it, so there's no ambient Material ancestor — yet the
    // toolbar Switch / IconButtons / TextField / TabBar all require one. Supply
    // it here so the panel is self-contained (harmless on the wide layout,
    // which already nests it in a Scaffold). The Material paints the surface;
    // the Container keeps the 1px top border.
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      child: Material(
        color: tokens.surface,
        // One width decision shared by the toolbar layout and the TabBar so
        // they flip to their narrow forms together.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = !Breakpoints.isWide(constraints);
            return AnimatedBuilder(
              animation: store,
              builder: (context, _) {
                final network = store.networkEntries;
                final errors = store.diagnosticEntries;
                return DefaultTabController(
                  length: 2,
                  // The band is the bottom-most viewport element on phones, so
                  // it owns the home-indicator inset; the surface Material
                  // behind it paints into that gap. No-op on desktop/web.
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        _Toolbar(
                          store: store,
                          windowController: windowController,
                          onHide: onHide,
                          isNarrow: isNarrow,
                        ),
                        Divider(height: 1, thickness: 1, color: tokens.border),
                        TabBar(
                          // Fixed tabs get ~160 px each on a 320 px band —
                          // not enough for the counted labels.
                          isScrollable: isNarrow,
                          tabAlignment: isNarrow ? TabAlignment.start : null,
                          tabs: [
                            Tab(
                              text:
                                  '${context.tr('network_requests')} (${network.length})',
                            ),
                            Tab(
                              text:
                                  '${context.tr('debug_recent_errors')} (${errors.length})',
                            ),
                          ],
                        ),
                        Divider(height: 1, thickness: 1, color: tokens.border),
                        Expanded(
                          child: TabBarView(
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _NetworkTab(
                                entries: network,
                                enabled: store.enabled,
                              ),
                              _ErrorsTab(
                                entries: errors,
                                enabled: store.enabled,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Compact controls at the top of the panel: capture label + Switch on the
/// left, then (desktop only) the screenshot tools, then Clear / Copy / Close
/// icon buttons on the right. On narrow bands (<600 px) it stacks into two
/// rows — label + Switch + Close up top, the action cluster right-aligned
/// below — so nothing overflows at phone widths.
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.store,
    required this.windowController,
    required this.onHide,
    required this.isNarrow,
  });

  final DebugCaptureStore store;
  final ScreenshotWindowController windowController;
  final VoidCallback onHide;
  final bool isNarrow;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final hasAny =
        store.networkEntries.isNotEmpty || store.diagnosticEntries.isNotEmpty;

    // Scoped to the label + switch so it doesn't compete with the action
    // buttons' own tooltips.
    final captureCluster = Tooltip(
      message: context.tr('debug_capture_help'),
      waitDuration: const Duration(milliseconds: 600),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              context.tr('capture_network_and_errors'),
              style: TextStyle(color: tokens.ink, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
          SizedBox(width: InSpacing.md(context)),
          Switch(
            value: store.enabled,
            onChanged: store.setEnabled,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );

    final clearButton = IconButton(
      icon: const Icon(Icons.clear_all),
      tooltip: context.tr('clear_capture'),
      onPressed: hasAny ? store.clear : null,
    );
    final copyButton = IconButton(
      icon: const Icon(Icons.copy_outlined),
      tooltip: context.tr('copy_debug_capture'),
      onPressed: hasAny ? () => _copyAll(context, store) : null,
    );
    final closeButton = IconButton(
      icon: const Icon(Icons.close),
      tooltip: context.tr('hide'),
      onPressed: onHide,
    );
    final cameraButton = IconButton(
      icon: const Icon(Icons.photo_camera),
      tooltip: context.tr('take_screenshot'),
      onPressed: () => _captureAndSave(context, windowController),
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: InSpacing.sm,
      ),
      // The screenshot controls read the window controller (menu checkmark,
      // toggle state) — rebuild them when it notifies.
      child: ListenableBuilder(
        listenable: windowController,
        builder: (context, _) {
          final screenshotControls = Env.isDesktop
              ? <Widget>[
                  ScreenshotSizeMenuButton(controller: windowController),
                  WindowButtonsToggle(controller: windowController),
                ]
              : const <Widget>[];
          if (!isNarrow) {
            return Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: captureCluster,
                  ),
                ),
                ...screenshotControls,
                cameraButton,
                clearButton,
                copyButton,
                closeButton,
              ],
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: captureCluster,
                    ),
                  ),
                  closeButton,
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ...screenshotControls,
                  cameraButton,
                  clearButton,
                  copyButton,
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> _copyAll(BuildContext context, DebugCaptureStore store) async {
  final buf = StringBuffer();
  final network = store.networkEntries;
  final errors = store.diagnosticEntries;
  buf.writeln('# Debug Capture');
  buf.writeln('Captured at: ${DateTime.now().toUtc().toIso8601String()}');
  buf.writeln('Network entries: ${network.length}');
  buf.writeln('Diagnostic entries: ${errors.length}');
  buf.writeln();
  buf.writeln('## Network');
  for (final n in network) {
    buf.writeln('--');
    buf.writeln(
      '${n.startedAt.toUtc().toIso8601String()}  '
      '${n.method} ${n.url}',
    );
    buf.writeln(
      'status: ${n.statusCode ?? "—"}  '
      'duration: ${n.duration.inMilliseconds}ms',
    );
    if (n.error != null) buf.writeln('error: ${n.error}');
    buf.writeln('request_headers: ${n.requestHeaders}');
    if (n.requestBody != null) buf.writeln('request_body: ${n.requestBody}');
    if (n.responseHeaders != null) {
      buf.writeln('response_headers: ${n.responseHeaders}');
    }
    if (n.responseBody != null) buf.writeln('response_body: ${n.responseBody}');
  }
  buf.writeln();
  buf.writeln('## Errors');
  for (final e in errors) {
    buf.writeln('--');
    buf.writeln(
      '${e.time.toUtc().toIso8601String()}  '
      '[${e.level}]${e.loggerName == null ? "" : " ${e.loggerName}"}',
    );
    buf.writeln(e.message);
    if (e.stack != null) buf.writeln(e.stack);
  }
  // Label rather than payload: the buffer is a debug dump with stack traces.
  await copyToClipboard(
    context,
    buf.toString(),
    label: context.tr('recent_errors'),
  );
}

/// Capture the whole app window to a PNG and save it via the native save dialog.
///
/// Flips the controller's `capturing` flag so the panel goes Offstage (see
/// `_DebugPanelBand`) — out of the shot and out of the layout, so the content is
/// captured at full window size — then snapshots the root `RepaintBoundary` from
/// `main.dart` and restores the panel before the (blocking) save dialog opens.
Future<void> _captureAndSave(
  BuildContext context,
  ScreenshotWindowController controller,
) async {
  // A double-tap can fire a second capture in the gap before the panel goes
  // Offstage; guard synchronously on the flag `setCapturing(true)` sets below.
  if (controller.capturing) return;

  // Grab everything context-bound before the first await; nothing reads the
  // BuildContext afterward, so the result toast goes through the captured
  // toast queue.
  final toasts = Notify.capture(context);
  final dpr = View.of(context).devicePixelRatio;
  final savedMsg = context.tr('exported');
  final errorMsg = context.tr('an_error_occurred');

  Uint8List? bytes;
  int? width;
  int? height;
  try {
    controller.setCapturing(true);
    // Wait for the Offstage relayout to build, paint, and rasterize before
    // snapshotting the boundary's current layer (a lone endOfFrame can race the
    // just-made change).
    final binding = WidgetsBinding.instance;
    binding.scheduleFrame();
    final painted = Completer<void>();
    binding.addPostFrameCallback((_) => painted.complete());
    await painted.future;
    await binding.endOfFrame;

    final boundary =
        controller.boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary != null) {
      final image = await boundary.toImage(pixelRatio: dpr);
      try {
        width = image.width;
        height = image.height;
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        bytes = data?.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    }
  } catch (_) {
    // Capture failed (e.g. a transient raster error) — fall through to the error
    // toast below with `bytes` still null.
  } finally {
    controller.setCapturing(false);
  }

  if (bytes == null) {
    toasts?.error(errorMsg);
    return;
  }

  // Same save-to-disk path as the report / design-JSON exports: desktop returns a
  // path to write defensively; web downloads via `bytes` and skips the `File`
  // write (which would throw `UnsupportedError`). Tag with the actual captured
  // pixel size (not the requested preset, which differs when the window clamped).
  final sizeTag = (width != null && height != null) ? '-${width}x$height' : '';
  final name =
      'invoice-ninja$sizeTag-${DateTime.now().millisecondsSinceEpoch}.png';
  try {
    final path = await FilePicker.saveFile(fileName: name, bytes: bytes);
    if (path == null) return; // user cancelled the dialog
    if (!kIsWeb) {
      final file = File(path);
      if (!await file.exists() || await file.length() == 0) {
        await file.writeAsBytes(bytes);
      }
    }
    toasts?.success(savedMsg);
  } catch (_) {
    toasts?.error(errorMsg);
  }
}

class _NetworkTab extends StatefulWidget {
  const _NetworkTab({required this.entries, required this.enabled});

  final List<NetworkCaptureEntry> entries;
  final bool enabled;

  @override
  State<_NetworkTab> createState() => _NetworkTabState();
}

class _NetworkTabState extends State<_NetworkTab>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _filter = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  List<NetworkCaptureEntry> _applyFilter(List<NetworkCaptureEntry> entries) {
    final q = _filter.text.trim().toLowerCase();
    if (q.isEmpty) return entries;
    return entries
        .where(
          (e) =>
              e.method.toLowerCase().contains(q) ||
              e.url.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filtered = _applyFilter(widget.entries);
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: InSpacing.lg(context),
            vertical: InSpacing.sm,
          ),
          child: TextField(
            controller: _filter,
            enabled: widget.entries.isNotEmpty,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 18),
              hintText: context.tr('filter_by_path_or_method'),
              suffixIcon: _filter.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(_filter.clear),
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        if (_filter.text.isNotEmpty)
          _FilteredCount(shown: filtered.length, total: widget.entries.length),
        Expanded(
          child: _ListBody(
            isEmpty: widget.entries.isEmpty,
            filteredEmpty: widget.entries.isNotEmpty && filtered.isEmpty,
            enabled: widget.enabled,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: InSpacing.lg(context)),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                thickness: 1,
                color: context.inTheme.border,
              ),
              itemBuilder: (_, i) => _NetworkRow(entry: filtered[i]),
            ),
          ),
        ),
      ],
    );
  }
}

enum _LevelFilter { all, warningPlus, errorPlus }

class _ErrorsTab extends StatefulWidget {
  const _ErrorsTab({required this.entries, required this.enabled});

  final List<DiagnosticCaptureEntry> entries;
  final bool enabled;

  @override
  State<_ErrorsTab> createState() => _ErrorsTabState();
}

class _ErrorsTabState extends State<_ErrorsTab>
    with AutomaticKeepAliveClientMixin {
  _LevelFilter _level = _LevelFilter.all;

  @override
  bool get wantKeepAlive => true;

  List<DiagnosticCaptureEntry> _applyFilter(
    List<DiagnosticCaptureEntry> entries,
  ) {
    switch (_level) {
      case _LevelFilter.all:
        return entries;
      case _LevelFilter.warningPlus:
        return entries
            .where((e) => _rank(e.level) >= _rank('WARNING'))
            .toList(growable: false);
      case _LevelFilter.errorPlus:
        return entries
            .where((e) => _rank(e.level) >= _rank('SEVERE'))
            .toList(growable: false);
    }
  }

  static int _rank(String level) {
    switch (level.toUpperCase()) {
      case 'SHOUT':
        return 4;
      case 'SEVERE':
      case 'ERROR':
        return 3;
      case 'WARNING':
        return 2;
      case 'INFO':
        return 1;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filtered = _applyFilter(widget.entries);
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: InSpacing.lg(context),
            vertical: InSpacing.sm,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            // Horizontal scroll keeps the three segments usable on a 320 px
            // band instead of overflowing.
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<_LevelFilter>(
                segments: [
                  ButtonSegment(
                    value: _LevelFilter.all,
                    label: Text(context.tr('all')),
                  ),
                  ButtonSegment(
                    value: _LevelFilter.warningPlus,
                    label: Text(context.tr('warning_plus')),
                  ),
                  ButtonSegment(
                    value: _LevelFilter.errorPlus,
                    label: Text(context.tr('error_plus')),
                  ),
                ],
                selected: {_level},
                onSelectionChanged: widget.entries.isEmpty
                    ? null
                    : (s) => setState(() => _level = s.first),
                showSelectedIcon: false,
              ),
            ),
          ),
        ),
        if (_level != _LevelFilter.all)
          _FilteredCount(shown: filtered.length, total: widget.entries.length),
        Expanded(
          child: _ListBody(
            isEmpty: widget.entries.isEmpty,
            filteredEmpty: widget.entries.isNotEmpty && filtered.isEmpty,
            enabled: widget.enabled,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: InSpacing.lg(context)),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                thickness: 1,
                color: context.inTheme.border,
              ),
              itemBuilder: (_, i) => _ErrorRow(entry: filtered[i]),
            ),
          ),
        ),
      ],
    );
  }
}

/// Small caption shown under the filter row when filtering is active.
class _FilteredCount extends StatelessWidget {
  const _FilteredCount({required this.shown, required this.total});

  final int shown;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        InSpacing.lg(context),
        0,
        InSpacing.lg(context),
        InSpacing.sm,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '$shown / $total',
          style: TextStyle(color: context.inTheme.ink3, fontSize: 12),
        ),
      ),
    );
  }
}

/// Routes between three states: empty (no entries captured), filtered-empty
/// (entries exist but the filter excludes them all), or list ([child]).
class _ListBody extends StatelessWidget {
  const _ListBody({
    required this.isEmpty,
    required this.filteredEmpty,
    required this.enabled,
    required this.child,
  });

  final bool isEmpty;
  final bool filteredEmpty;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (isEmpty) return _EmptyHint(enabled: enabled);
    if (filteredEmpty) {
      return Center(
        child: Text(
          context.tr('no_matching_entries'),
          style: TextStyle(color: context.inTheme.ink3, fontSize: 13),
        ),
      );
    }
    return child;
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(InSpacing.lg(context)),
        child: Text(
          enabled
              ? context.tr('debug_capture_waiting')
              : context.tr('capture_off_hint'),
          style: TextStyle(color: tokens.ink3, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _NetworkRow extends StatelessWidget {
  const _NetworkRow({required this.entry});

  final NetworkCaptureEntry entry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final (fg, bg) = _statusColors(tokens, entry);
    final pillLabel = entry.error != null
        ? 'ERR'
        : entry.statusCode?.toString() ?? '—';
    final time = formatRelativeTime(
      context,
      DateTime.now().difference(entry.startedAt),
    );
    final durationMs = entry.duration.inMilliseconds;
    final wallClock = _wallClock(entry.startedAt);
    final pathPreview = _shortenUrl(entry.url);
    return InkWell(
      onTap: () => _showDetail(context, entry),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 56,
              child: StatusPill(label: pillLabel, fgColor: fg, bgColor: bg),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.method}  $pathPreview',
                    style: TextStyle(
                      color: tokens.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: kMonoFontFamily,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${durationMs}ms · $wallClock · $time',
                    style: TextStyle(color: tokens.ink3, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: tokens.ink3),
          ],
        ),
      ),
    );
  }

  static (Color, Color) _statusColors(InTheme t, NetworkCaptureEntry e) {
    if (e.error != null) return (t.overdue, t.overdueSoft);
    final s = e.statusCode ?? 0;
    if (s >= 200 && s < 300) return (t.paid, t.paidSoft);
    if (s >= 300 && s < 400) return (t.partial, t.partialSoft);
    if (s >= 400 && s < 500) return (t.sent, t.sentSoft);
    return (t.overdue, t.overdueSoft);
  }

  static String _shortenUrl(String url) {
    final parsed = Uri.tryParse(url);
    if (parsed == null) return url;
    final path = parsed.path;
    final query = parsed.hasQuery ? '?${parsed.query}' : '';
    return '$path$query';
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.entry});

  final DiagnosticCaptureEntry entry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final (fg, bg) = _levelColors(tokens, entry.level);
    final time = formatRelativeTime(
      context,
      DateTime.now().difference(entry.time),
    );
    final source = entry.loggerName ?? entry.level;
    final wallClock = _wallClock(entry.time);
    return InkWell(
      onTap: () => _showDetail(context, entry),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 76,
              child: StatusPill(label: entry.level, fgColor: fg, bgColor: bg),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.message,
                    style: TextStyle(
                      color: tokens.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$source · $wallClock · $time',
                    style: TextStyle(color: tokens.ink3, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: tokens.ink3),
          ],
        ),
      ),
    );
  }

  static (Color, Color) _levelColors(InTheme t, String level) {
    final upper = level.toUpperCase();
    if (upper == 'ERROR' || upper == 'SEVERE' || upper == 'SHOUT') {
      return (t.overdue, t.overdueSoft);
    }
    if (upper == 'WARNING') return (t.sent, t.sentSoft);
    return (t.ink3, t.accentSoft);
  }
}

void _showDetail(BuildContext context, Object entry) {
  showDialog<void>(
    context: context,
    builder: (context) => _DetailDialog(entry: entry),
  );
}

class _DetailDialog extends StatelessWidget {
  const _DetailDialog({required this.entry});

  final Object entry;

  @override
  Widget build(BuildContext context) {
    final entry = this.entry;
    final title = entry is NetworkCaptureEntry
        ? '${entry.method} ${_pathOf(entry.url)}'
        : entry is DiagnosticCaptureEntry
        ? '[${entry.level}] ${entry.loggerName ?? ''}'
        : '';
    return AlertDialog(
      title: Text(
        title,
        style: const TextStyle(fontFamily: kMonoFontFamily, fontSize: 14),
      ),
      content: SizedBox(
        width: math.min(720, MediaQuery.of(context).size.width - 48),
        child: SingleChildScrollView(
          child: entry is NetworkCaptureEntry
              ? _NetworkDetail(entry: entry)
              : entry is DiagnosticCaptureEntry
              ? _ErrorDetail(entry: entry)
              : const SizedBox.shrink(),
        ),
      ),
      actions: [
        if (entry is NetworkCaptureEntry)
          TextButton(
            // `curl` is a tool name, not translatable prose.
            onPressed: () =>
                copyToClipboard(context, _entryAsCurl(entry), label: 'curl'),
            child: Text(context.tr('copy_as_curl')),
          ),
        TextButton(
          onPressed: () => copyToClipboard(
            context,
            _entryAsText(entry),
            label: context.tr('details'),
          ),
          child: Text(context.tr('copy')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('close')),
        ),
      ],
    );
  }

  static String _pathOf(String url) {
    final u = Uri.tryParse(url);
    if (u == null) return url;
    return u.path;
  }

  /// Builds a `curl` invocation for a captured network entry. Skips headers
  /// whose value is `<redacted>` and emits a leading `#` comment line when
  /// any were dropped so the user knows to refill them. Single-quotes the
  /// URL and body via the standard `'\''` escape trick.
  static String _entryAsCurl(NetworkCaptureEntry e) {
    final omitted = <String>[];
    final headerLines = <String>[];
    e.requestHeaders.forEach((k, v) {
      if (v == '<redacted>') {
        omitted.add(k);
        return;
      }
      // curl recomputes Content-Length; passing the captured one would
      // silently break uploads after the body is escaped.
      if (k.toLowerCase() == 'content-length') return;
      headerLines.add("  -H '${_sq(k)}: ${_sq(v)}'");
    });
    final lines = <String>[];
    if (omitted.isNotEmpty) {
      lines.add('# Some headers omitted (redacted): ${omitted.join(', ')}');
    }
    lines.add('curl -X ${e.method.toUpperCase()} \\');
    for (final h in headerLines) {
      lines.add('$h \\');
    }
    final body = e.requestBody;
    if (body != null && body.isNotEmpty && e.method.toUpperCase() != 'GET') {
      lines.add("  --data-raw '${_sq(body)}' \\");
    }
    lines.add("  '${_sq(e.url)}'");
    return lines.join('\n');
  }

  /// Escape single-quotes for shell single-quoted strings: every `'` becomes
  /// `'\''` (close, escaped-quote, reopen).
  static String _sq(String s) => s.replaceAll("'", r"'\''");

  static String _entryAsText(Object e) {
    if (e is NetworkCaptureEntry) {
      final buf = StringBuffer()
        ..writeln('${e.method} ${e.url}')
        ..writeln('started: ${e.startedAt.toUtc().toIso8601String()}')
        ..writeln('status:  ${e.statusCode ?? "—"}')
        ..writeln('duration: ${e.duration.inMilliseconds}ms');
      if (e.error != null) buf.writeln('error: ${e.error}');
      buf
        ..writeln()
        ..writeln('request_headers:')
        ..writeln(_formatMap(e.requestHeaders));
      if (e.requestBody != null) {
        buf
          ..writeln()
          ..writeln('request_body:')
          ..writeln(_prettyJson(e.requestBody!));
      }
      if (e.responseHeaders != null) {
        buf
          ..writeln()
          ..writeln('response_headers:')
          ..writeln(_formatMap(e.responseHeaders!));
      }
      if (e.responseBody != null) {
        buf
          ..writeln()
          ..writeln('response_body:')
          ..writeln(_prettyJson(e.responseBody!));
      }
      return buf.toString();
    }
    if (e is DiagnosticCaptureEntry) {
      final buf = StringBuffer()
        ..writeln('[${e.level}] ${e.loggerName ?? ""}')
        ..writeln(e.time.toUtc().toIso8601String())
        ..writeln()
        ..writeln(e.message);
      if (e.stack != null) {
        buf
          ..writeln()
          ..writeln(e.stack);
      }
      return buf.toString();
    }
    return e.toString();
  }
}

class _NetworkDetail extends StatelessWidget {
  const _NetworkDetail({required this.entry});

  final NetworkCaptureEntry entry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _kv(context, [
          ('URL', entry.url),
          ('Started', entry.startedAt.toUtc().toIso8601String()),
          ('Status', entry.statusCode?.toString() ?? '—'),
          ('Duration', '${entry.duration.inMilliseconds}ms'),
          if (entry.error != null) ('Error', entry.error!),
        ]),
        const SizedBox(height: 12),
        _MonoBlock(
          label: context.tr('request_headers'),
          text: _formatMap(entry.requestHeaders),
          tokens: tokens,
        ),
        if (entry.requestBody != null) ...[
          const SizedBox(height: 12),
          _MonoBlock(
            label: context.tr('request_body'),
            text: _prettyJson(entry.requestBody!),
            tokens: tokens,
          ),
        ],
        if (entry.responseHeaders != null) ...[
          const SizedBox(height: 12),
          _MonoBlock(
            label: 'Response headers',
            text: _formatMap(entry.responseHeaders!),
            tokens: tokens,
          ),
        ],
        if (entry.responseBody != null) ...[
          const SizedBox(height: 12),
          _MonoBlock(
            label: context.tr('response_body'),
            text: _prettyJson(entry.responseBody!),
            tokens: tokens,
          ),
        ],
      ],
    );
  }

  Widget _kv(BuildContext context, List<(String, String)> rows) {
    final tokens = context.inTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    row.$1,
                    style: TextStyle(color: tokens.ink3, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    row.$2,
                    style: TextStyle(
                      color: tokens.ink,
                      fontSize: 12,
                      fontFamily: kMonoFontFamily,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ErrorDetail extends StatelessWidget {
  const _ErrorDetail({required this.entry});

  final DiagnosticCaptureEntry entry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          entry.time.toUtc().toIso8601String(),
          style: TextStyle(color: tokens.ink3, fontSize: 12),
        ),
        const SizedBox(height: 8),
        SelectableText(
          entry.message,
          style: TextStyle(
            color: tokens.ink,
            fontSize: 13,
            fontFamily: kMonoFontFamily,
          ),
        ),
        if (entry.stack != null) ...[
          const SizedBox(height: 12),
          _MonoBlock(label: 'Stack', text: entry.stack!, tokens: tokens),
        ],
      ],
    );
  }
}

class _MonoBlock extends StatelessWidget {
  const _MonoBlock({
    required this.label,
    required this.text,
    required this.tokens,
  });

  final String label;
  final String text;
  final InTheme tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: TextStyle(color: tokens.ink3, fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: tokens.accentSoft,
            borderRadius: BorderRadius.circular(InRadii.r2),
          ),
          padding: const EdgeInsets.all(8),
          child: SelectableText(
            text,
            style: TextStyle(
              color: tokens.ink,
              fontSize: 12,
              fontFamily: kMonoFontFamily,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

String _wallClock(DateTime t) {
  final local = t.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  final ss = local.second.toString().padLeft(2, '0');
  return '$hh:$mm:$ss';
}

String _formatMap(Map<String, String> map) {
  if (map.isEmpty) return '(none)';
  final buf = StringBuffer();
  final entries = map.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  for (final e in entries) {
    buf.writeln('${e.key}: ${e.value}');
  }
  return buf.toString().trimRight();
}

String _prettyJson(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '(empty)';
  final first = trimmed.codeUnitAt(0);
  if (first != 0x7B && first != 0x5B) return raw;
  try {
    return const JsonEncoder.withIndent('  ').convert(jsonDecode(trimmed));
  } catch (_) {
    return raw;
  }
}
