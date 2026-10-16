import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/features/settings/state/settings_reveal_controller.dart';

/// How long a page keeps looking for a requested field. Tab bodies and their
/// view models arrive a few frames after the route does.
const _kRevealSearchWindow = Duration(milliseconds: 1500);

/// The flash: held, then faded. Same length as the activity row's reveal —
/// the page changed under the user, so the eye needs time to find it.
const _kFlashDuration = Duration(milliseconds: 1600);

/// The tallest box that still reads as one field's row. Walking up from the
/// label stops before anything taller, which would be the card around it.
const _kMaxRowHeight = 160.0;

/// Centered, scrolling, max-width-constrained body for any settings page.
/// Pass [sections] for the standard "list of [FormSection] cards" layout
/// (covers ~every settings page) — the shell wraps them in a stretched
/// [Column] for you. Pass [child] for the rare custom body that isn't a
/// section list.
///
/// It is also where a settings search hit lands: every page under
/// `/settings` renders through here, so this is the one place that can
/// scroll to and flash the field a hit named, without an anchor on each of
/// ~40 screens. See [_SettingsFormShellState._attempt] and
/// `docs/settings-screens.md` § A search hit reveals its field by label, not
/// by anchor.
class SettingsFormShell extends StatefulWidget {
  const SettingsFormShell({
    super.key,
    this.child,
    this.sections,
    this.maxWidth = 720,
  }) : assert(
         child != null || sections != null,
         'Provide either child or sections',
       ),
       assert(
         child == null || sections == null,
         'Provide child or sections, not both',
       );

  final Widget? child;
  final List<Widget>? sections;
  final double maxWidth;

  @override
  State<SettingsFormShell> createState() => _SettingsFormShellState();
}

class _SettingsFormShellState extends State<SettingsFormShell>
    with SingleTickerProviderStateMixin {
  SettingsRevealController? _reveal;

  /// Made on the first reveal only — most settings pages never flash.
  AnimationController? _flashController;
  AnimationController get _flash => _flashController ??=
      AnimationController(vsync: this, duration: _kFlashDuration)
        // Let go of the field's render box once the flash is over — it may be
        // detached by a later rebuild, and the page lives on.
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _target = null);
          }
        });

  /// The box the flash paints around. It is the painter's own `CustomPaint`
  /// that carries a key, never the field — a key arriving on someone else's
  /// widget would re-inflate it (see `ActivityRecordRow`'s reveal).
  final GlobalKey _paintKey = GlobalKey();
  RenderBox? _target;

  int? _searchingSeq;

  /// Bumped by every [_onRequest]; an attempt scheduled under an older value
  /// stops. Without it a request arriving mid-search left the old chain of
  /// post-frame attempts running beside the new one — two looks per frame,
  /// the second always "still" against the first, which collapsed the
  /// stillness gate to a single frame.
  int _generation = 0;

  /// Frame time of the first look, so the window is measured in frames the
  /// user saw (and in the clock a widget test drives), not wall time.
  Duration? _searchStart;
  Rect? _lastRect;

  /// Consecutive frames [_lastRect] has held still.
  int _stillFrames = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Nullable: absent in a widget test that pumps the page bare.
    final reveal = context.read<SettingsRevealController?>();
    if (identical(reveal, _reveal)) return;
    _reveal?.removeListener(_onRequest);
    _reveal = reveal?..addListener(_onRequest);
    // The usual case: the hit was tapped elsewhere and this page is mounting
    // because of it, so the request is already waiting.
    _onRequest();
  }

  @override
  void dispose() {
    _reveal?.removeListener(_onRequest);
    _flashController?.dispose();
    super.dispose();
  }

  void _onRequest() {
    final request = _reveal?.request;
    if (request == null || request.seq == _searchingSeq) return;
    _searchingSeq = request.seq;
    _searchStart = null;
    _lastRect = null;
    _stillFrames = 0;
    _generation++;
    _scheduleAttempt();
  }

  void _scheduleAttempt() {
    final generation = _generation;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => _attempt(generation))
      // Post-frame callbacks don't schedule frames; a settled page has none
      // coming, so ask for one or the search would stall.
      ..ensureVisualUpdate();
  }

  /// One look for the requested label, once per frame until it is found and
  /// still, or [_kRevealSearchWindow] runs out.
  ///
  /// "Still" is the gate that matters: the same on-screen rect three frames
  /// running, wholly inside the window horizontally. A `TabBarView` keeps the
  /// outgoing tab built while the incoming one slides in, and both render
  /// through here — the slide is what tells the visible page from the one
  /// leaving. `TickerMode` is read here, not when the request arrived: the
  /// `Offstage` around an inactive branch flips a frame after the fact.
  void _attempt(int generation) {
    if (!mounted || generation != _generation) return;
    final reveal = _reveal;
    final request = reveal?.request;
    if (reveal == null || request == null || request.seq != _searchingSeq) {
      return;
    }
    final path = GoRouter.maybeOf(
      context,
    )?.routerDelegate.currentConfiguration.uri.path;
    // No router at all only happens in a widget test that pumps the page bare.
    final onRoute = path == null || path == request.route;
    if (onRoute && TickerMode.getValuesNotifier(context).value.enabled) {
      final label = _findLabel(request.label);
      final box = label?.renderObject;
      final rect = box is RenderBox ? _globalRect(box) : null;
      final last = _lastRect;
      _stillFrames = rect != null && last != null && _isStill(rect, last)
          ? _stillFrames + 1
          : 0;
      // Two still frames, not one: a shell moves its `TabController` in a
      // post-frame callback, so the outgoing tab can sit still for the one
      // frame before its slide begins.
      if (label != null &&
          rect != null &&
          _stillFrames >= 2 &&
          _isOnScreen(rect)) {
        reveal.consume(request.seq);
        _show(label, request.label);
        return;
      }
      _lastRect = rect;
    }
    final now = SchedulerBinding.instance.currentFrameTimeStamp;
    final start = _searchStart ??= now;
    if (now - start > _kRevealSearchWindow) {
      // Looked on the field's own page and it isn't there (a collapsed
      // disclosure, a key only an edit screen renders): the user lands at the
      // top, as before. Off the page, leave it for the page it names.
      if (onRoute) reveal.consume(request.seq);
      return;
    }
    _scheduleAttempt();
  }

  /// The first laid-out text in this page that reads [label], in tree order.
  Element? _findLabel(String label) {
    final want = _normalizeLabel(label);
    if (want.isEmpty) return null;
    Element? found;
    void visit(Element element) {
      if (found != null) return;
      final widget = element.widget;
      if (widget is Offstage && widget.offstage) return;
      if (widget is RichText &&
          _normalizeLabel(widget.text.toPlainText()) == want) {
        final box = element.renderObject;
        if (box is RenderBox && box.attached && box.hasSize) {
          found = element;
          return;
        }
      }
      element.visitChildElements(visit);
    }

    context.visitChildElements(visit);
    return found;
  }

  /// Wholly inside this page's window, left to right.
  bool _isOnScreen(Rect r) {
    final view = View.maybeOf(context);
    if (view == null) return true;
    final width = view.physicalSize.width / view.devicePixelRatio;
    return r.left >= -0.5 && r.right <= width + 0.5;
  }

  void _show(Element label, String text) {
    setState(() => _target = _rowFor(label.renderObject! as RenderBox));
    Scrollable.ensureVisible(
      label,
      alignment: 0.3,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    _flash.forward(from: 0);
    // A scroll and a flash are invisible to a screen reader; say where the
    // user is now.
    SemanticsService.sendAnnouncement(
      View.of(context),
      text,
      Directionality.of(context),
    );
  }

  /// The field's row: the largest box around [label], below this page's own
  /// paint box, that is still no taller than one row — a text field's whole
  /// decorator, a switch tile, a section title's line. Falls back to the
  /// label itself.
  RenderBox _rowFor(RenderBox label) {
    final paintBox = _paintKey.currentContext?.findRenderObject();
    RenderBox best = label;
    RenderObject? node = label.parent;
    while (node != null && node != paintBox) {
      if (node is RenderBox && node.hasSize) {
        if (node.size.height > _kMaxRowHeight) break;
        best = node;
      }
      node = node.parent;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final body = widget.sections != null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: widget.sections!,
          )
        : widget.child!;
    final tokens = context.inTheme;
    // Widget-order (not geometry) Tab traversal for every settings page.
    // Settings forms are laid out in source order, so reading-order and
    // widget-order Tab sequence are visually identical here — but widget
    // order never calls `FocusNode.rect`, so Tab can't trip the
    // `'hasSize': RenderBox was not laid out` assertion when a stacked
    // markdown field (e.g. Defaults' 8) is built but scrolled off-screen
    // and therefore unlaid.
    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: ListView(
        padding: const EdgeInsets.all(InSpacing.xl),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: widget.maxWidth),
              // Inside the scroll view, so the flash scrolls with the field.
              child: CustomPaint(
                key: _paintKey,
                foregroundPainter: _target == null
                    ? null
                    : _RevealFlashPainter(
                        target: _target!,
                        paintKey: _paintKey,
                        progress: _flash,
                        accent: tokens.accent,
                      ),
                child: body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lower-cased and trimmed, inner whitespace collapsed, and a required-field
/// `*` or a trailing `:` dropped — the decorations a label wears on screen
/// but not in the bundle.
String _normalizeLabel(String s) => s
    .trim()
    .replaceAll(RegExp(r'\s*[*:]$'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .toLowerCase();

Rect? _globalRect(RenderBox box) {
  if (!box.attached || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

bool _isStill(Rect a, Rect b) =>
    (a.left - b.left).abs() < 0.5 && (a.top - b.top).abs() < 0.5;

/// A tinted, outlined rounded rect around [target], held and then faded.
/// The rect is re-read from the live render tree on every paint, so it
/// follows the field through the scroll and any relayout.
class _RevealFlashPainter extends CustomPainter {
  _RevealFlashPainter({
    required this.target,
    required this.paintKey,
    required this.progress,
    required this.accent,
  }) : super(repaint: progress);

  final RenderBox target;
  final GlobalKey paintKey;
  final Animation<double> progress;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t <= 0 || t >= 1) return;
    final paintBox = paintKey.currentContext?.findRenderObject();
    if (paintBox is! RenderBox || !target.attached || !target.hasSize) return;
    final rect = MatrixUtils.transformRect(
      target.getTransformTo(paintBox),
      Offset.zero & target.size,
    ).inflate(6);
    // Full strength for the first 40%, then fade out.
    final strength = t < 0.4 ? 1.0 : 1 - (t - 0.4) / 0.6;
    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(InRadii.r2),
    );
    canvas
      ..drawRRect(
        rrect,
        Paint()..color = accent.withValues(alpha: 0.12 * strength),
      )
      ..drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = accent.withValues(alpha: 0.9 * strength),
      );
  }

  @override
  bool shouldRepaint(_RevealFlashPainter old) =>
      old.target != target || old.accent != accent;
}
