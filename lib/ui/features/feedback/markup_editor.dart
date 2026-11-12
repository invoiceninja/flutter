import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/domain/feedback/markup.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/dialogs/discard_changes_dialog.dart';
import 'package:admin/ui/core/utils/text_input_focus.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/feedback/markup_painter.dart';

/// The tool the editor opens on — the last one used this session, Box at
/// first.
MarkupTool _lastTool = MarkupTool.box;

/// Opens [image] with [marks] for markup (docs/feedback-screenshots.md).
/// Resolves to the new marks on Done — the image itself is never flattened
/// here, so reopening it can still undo them — or null on Cancel.
///
/// Full-screen on a phone, a large dialog elsewhere. Dismissible by Esc and a
/// barrier tap, both of which go through the discard prompt when marks were
/// added.
Future<List<MarkupMark>?> showMarkupEditor(
  BuildContext context, {
  required ui.Image image,
  required List<MarkupMark> marks,
}) {
  final fullScreen = Breakpoints.isPhone(context);
  return showDialog<List<MarkupMark>>(
    context: context,
    // Esc and a barrier tap pop through maybePop → the PopScope guard. A
    // non-dismissible route ignores Esc entirely (`_DismissModalAction`).
    barrierDismissible: true,
    // The full-screen page's AppBar and body take the insets themselves.
    useSafeArea: !fullScreen,
    builder: (_) =>
        _MarkupEditor(image: image, initial: marks, fullScreen: fullScreen),
  );
}

class _UndoIntent extends Intent {
  const _UndoIntent();
}

class _MarkupEditor extends StatefulWidget {
  const _MarkupEditor({
    required this.image,
    required this.initial,
    required this.fullScreen,
  });

  final ui.Image image;
  final List<MarkupMark> initial;
  final bool fullScreen;

  @override
  State<_MarkupEditor> createState() => _MarkupEditorState();
}

class _MarkupEditorState extends State<_MarkupEditor> {
  late final MarkupHistory _history = MarkupHistory(widget.initial);

  /// Owns the editor's keys. The dialog sits on the root navigator, outside
  /// the shell's keyboard layer, so nothing else would answer ⌘Z here — and
  /// nothing of the shell's can fire inside it.
  final FocusNode _focus = FocusNode(debugLabel: 'markup editor');

  MarkupTool _tool = _lastTool;

  /// The pointer drawing right now, and what it has drawn so far (image px).
  int? _pointer;
  List<MarkPoint>? _penPoints;
  MarkPoint? _dragStart;
  MarkPoint? _dragEnd;
  Offset? _dragStartLocal;

  /// Image pixels per screen point at the current fit, for the stroke widths.
  double _fitScale = 1;

  Size get _imageSize =>
      Size(widget.image.width.toDouble(), widget.image.height.toDouble());

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// Marks were added, removed or cleared since the editor opened.
  bool get _changed => _history.canUndo;

  void _setTool(MarkupTool tool) => setState(() => _tool = _lastTool = tool);

  void _undo() {
    if (!_history.canUndo) return;
    setState(_history.undo);
  }

  void _clear() {
    if (_history.marks.isEmpty) return;
    setState(_history.clear);
  }

  void _done() => Navigator.of(context).pop(_history.marks);

  Future<void> _onPopInvoked(bool didPop, Object? result) async {
    if (didPop) return;
    final discard = await showDiscardChangesDialog(context);
    if (discard && mounted) Navigator.of(context).pop();
  }

  // ── Drawing ───────────────────────────────────────────────────────────

  MarkPoint _toImage(Offset local, Size box) {
    final fit = fitImage(_imageSize, box);
    final p = (local - fit.origin) / fit.scale;
    return MarkPoint(
      p.dx.clamp(0, _imageSize.width),
      p.dy.clamp(0, _imageSize.height),
    );
  }

  void _down(PointerDownEvent e, Size box) {
    _focus.requestFocus();
    if (_pointer != null) {
      // A second finger: a pinch or a slip, not part of the mark.
      _cancelStroke();
      return;
    }
    if (e.kind == PointerDeviceKind.mouse && e.buttons != kPrimaryMouseButton) {
      return;
    }
    final p = _toImage(e.localPosition, box);
    setState(() {
      _pointer = e.pointer;
      _fitScale = fitImage(_imageSize, box).scale;
      if (_tool == MarkupTool.pen) {
        _penPoints = [p];
      } else {
        _dragStart = p;
        _dragEnd = p;
        _dragStartLocal = e.localPosition;
      }
    });
  }

  void _move(PointerMoveEvent e, Size box) {
    if (e.pointer != _pointer) return;
    final p = _toImage(e.localPosition, box);
    setState(() {
      if (_penPoints case final points?) {
        points.add(p);
      } else {
        _dragEnd = p;
      }
    });
  }

  void _up(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    final mark = _inProgress(forCommit: e.localPosition);
    setState(() {
      if (mark != null) _history.add(mark);
      _resetStroke();
    });
  }

  void _cancelStroke() => setState(_resetStroke);

  void _resetStroke() {
    _pointer = null;
    _penPoints = null;
    _dragStart = null;
    _dragEnd = null;
    _dragStartLocal = null;
  }

  /// The mark the current drag would make. With [forCommit] (the pointer's
  /// final position) a box or redact shorter than [kMinMarkDragPoints] is a
  /// stray tap and makes nothing.
  MarkupMark? _inProgress({Offset? forCommit}) {
    final scale = _fitScale <= 0 ? 1 : _fitScale;
    if (_penPoints case final points?) {
      return PenStroke(List.of(points), width: kPenWidthPoints / scale);
    }
    final start = _dragStart;
    final end = _dragEnd;
    if (start == null || end == null) return null;
    if (forCommit != null) {
      final from = _dragStartLocal ?? forCommit;
      if ((forCommit - from).distance < kMinMarkDragPoints) return null;
    }
    final rect = MarkRect.fromPoints(start, end);
    return switch (_tool) {
      MarkupTool.redact => RedactMark(rect),
      _ => BoxMark(rect, width: kBoxWidthPoints / scale),
    };
  }

  // ── Layout ────────────────────────────────────────────────────────────

  Widget _canvas(BuildContext context) {
    final color = context.inTheme.annotationMark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = constraints.biggest;
        // rtl: physical image space — the picture is the same either way.
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Semantics(
            label: context.tr('markup_canvas_label', {
              'count': '${_history.marks.length}',
            }),
            child: MouseRegion(
              cursor: SystemMouseCursors.precise,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) => _down(e, box),
                onPointerMove: (e) => _move(e, box),
                onPointerUp: _up,
                onPointerCancel: (e) {
                  if (e.pointer == _pointer) _cancelStroke();
                },
                child: CustomPaint(
                  size: box,
                  painter: MarkedImagePainter(
                    image: widget.image,
                    marks: _history.marks,
                    color: color,
                    inProgress: _pointer == null ? null : _inProgress(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tools(BuildContext context, {required bool labels}) {
    ButtonSegment<MarkupTool> segment(
      MarkupTool tool,
      IconData icon,
      String key,
    ) => ButtonSegment(
      value: tool,
      icon: Icon(icon),
      label: labels ? Text(context.tr(key)) : null,
      tooltip: context.tr(key),
    );
    return Wrap(
      spacing: InSpacing.sm,
      runSpacing: InSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<MarkupTool>(
          showSelectedIcon: false,
          segments: [
            segment(MarkupTool.box, Icons.crop_square, 'box'),
            segment(MarkupTool.pen, Icons.gesture, 'pen'),
            segment(MarkupTool.redact, Icons.rectangle, 'redact'),
          ],
          selected: {_tool},
          onSelectionChanged: (s) => _setTool(s.first),
        ),
        IconButton(
          icon: const Icon(Icons.undo),
          tooltip: context.tr('undo'),
          onPressed: _history.canUndo ? _undo : null,
        ),
        IconButton(
          icon: const Icon(Icons.delete_sweep_outlined),
          tooltip: context.tr('clear'),
          onPressed: _history.marks.isEmpty ? null : _clear,
        ),
      ],
    );
  }

  Widget _withKeys(Widget child) => Shortcuts(
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _UndoIntent(),
      SingleActivator(LogicalKeyboardKey.keyZ, control: true): _UndoIntent(),
    },
    child: Actions(
      actions: {
        _UndoIntent: GuardedShortcutAction<_UndoIntent>(
          onInvoke: (_) {
            _undo();
            return null;
          },
        ),
      },
      child: Focus(focusNode: _focus, autofocus: true, child: child),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final title = context.tr('mark_up_screenshot');
    final Widget body;
    if (widget.fullScreen) {
      body = Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: context.tr('cancel'),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: Text(title),
            actions: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: InSpacing.sm),
                child: TextButton(
                  onPressed: _done,
                  child: Text(context.tr('done')),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(child: _canvas(context)),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(InSpacing.sm),
                  child: _tools(context, labels: false),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final size = MediaQuery.sizeOf(context);
      final width = math.min(size.width - 96, 1100.0);
      final height = math.max(240.0, math.min(size.height - 260, 760.0));
      body = AlertDialog(
        title: Semantics(header: true, headingLevel: 1, child: Text(title)),
        content: SizedBox(
          width: width,
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tools(context, labels: true),
              const SizedBox(height: InSpacing.sm),
              Expanded(child: _canvas(context)),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(context.tr('cancel')),
          ),
          PrimaryDialogAction(
            label: context.tr('done'),
            autofocus: false,
            showEnterHint: false,
            onPressed: _done,
          ),
        ],
      );
    }
    return PopScope(
      canPop: !_changed,
      onPopInvokedWithResult: _onPopInvoked,
      child: _withKeys(body),
    );
  }
}
