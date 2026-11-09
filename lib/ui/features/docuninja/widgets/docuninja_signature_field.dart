import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/docuninja/docuninja_signature.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/file_drop_zone.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

final _log = Logger('DocuNinjaSignatureField');

/// React's typed-signature fonts (`SignatureFontSelector.tsx`), all Google
/// Fonts, fetched on demand as the invoice designer fetches its fonts.
const kDnSignatureFonts = [
  'Dancing Script',
  'Great Vibes',
  'Pacifico',
  'Satisfy',
  'Alex Brush',
];

/// The image types an uploaded signature may be (`accept="image/*"` in
/// React), the ones `dart:ui` decodes everywhere.
const _kImageExtensions = ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'];

/// A DocuNinja user's saved signature or initials, edited the three ways
/// React's user page offers (`users/common/components/Details.tsx`): drawn,
/// uploaded (a click or a drop on the box) or generated from typed text in
/// a handwriting font; and cleared. [value] is the stored data URL, empty
/// for none. docs/docuninja.md § Users.
class DnSignatureField extends StatefulWidget {
  const DnSignatureField({
    super.key,
    required this.label,
    required this.value,
    required this.kind,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final String value;
  final DnSignatureKind kind;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  State<DnSignatureField> createState() => _DnSignatureFieldState();
}

class _DnSignatureFieldState extends State<DnSignatureField> {
  /// The preview's bytes, decoded once per value: `MemoryImage` compares by
  /// identity, so fresh bytes on every rebuild of the editor (ticking a
  /// permission) would re-decode and blink the preview.
  String? _bytesFor;
  Uint8List? _bytes;

  Uint8List? get _preview {
    if (_bytesFor != widget.value) {
      _bytesFor = widget.value;
      _bytes = dnSignatureBytes(widget.value);
    }
    return _bytes;
  }

  /// Hands [url] up, unless the editor has gone meanwhile.
  void _changed(String? url) {
    if (url != null && mounted) widget.onChanged(url);
  }

  Future<void> _upload(List<UploadSource> files) async {
    if (files.isEmpty) return;
    try {
      final source = files.first;
      final bytes = await source.readRange(0, await source.length());
      final image = await _decode(bytes, widget.kind);
      _changed(dnSignatureDataUrl(image, widget.kind));
    } on Object catch (e, st) {
      _log.info('Reading the uploaded signature failed', e, st);
      if (mounted) Notify.error(context, context.tr('invalid_file'));
    }
  }

  Future<void> _draw() async => _changed(
    await showDialog<String>(
      context: context,
      builder: (_) => _DrawDialog(title: widget.label, kind: widget.kind),
    ),
  );

  Future<void> _generate() async => _changed(
    await showDialog<String>(
      context: context,
      builder: (_) => _GenerateDialog(kind: widget.kind),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final label = widget.label;
    final enabled = widget.enabled;
    final bytes = _preview;
    final has = bytes != null && bytes.isNotEmpty;
    // Something is stored even when it is no image the app can show (a URL
    // another client saved): it can still be cleared.
    final stored = widget.value.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: TextStyle(color: tokens.ink3, fontSize: 12)),
        const SizedBox(height: 4),
        FileDropZone(
          allowedExtensions: _kImageExtensions,
          onFiles: _upload,
          enabled: enabled,
          preview: has
              ? Container(
                  constraints: const BoxConstraints(maxHeight: 112),
                  // The ink is dark on white in either theme.
                  color: Colors.white,
                  padding: const EdgeInsets.all(InSpacing.sm),
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    semanticLabel: label,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                )
              : null,
        ),
        const SizedBox(height: InSpacing.sm),
        Wrap(
          spacing: InSpacing.sm,
          runSpacing: InSpacing.sm,
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: enabled ? _draw : null,
              icon: const Icon(Icons.draw_outlined, size: 18),
              label: Text(context.tr('draw')),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: enabled ? _generate : null,
              icon: const Icon(Icons.text_fields, size: 18),
              label: Text(context.tr('generate')),
            ),
            if (stored)
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(64, 40)),
                onPressed: enabled ? () => widget.onChanged('') : null,
                child: Text(context.tr('clear')),
              ),
          ],
        ),
      ],
    );
  }
}

/// [bytes] (an image file) decoded by the platform, at no more than twice
/// what [kind] stores: a 48 MP photo decoded whole would be ~200 MB of
/// pixels, copied twice more, on the UI isolate. Throws when it is not an
/// image.
Future<img.Image> _decode(Uint8List bytes, DnSignatureKind kind) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final codec = await ui.instantiateImageCodecWithSize(
    buffer,
    getTargetSize: (w, h) {
      final scale = [
        1.0,
        kind.maxWidth * 2 / w,
        kind.maxHeight * 2 / h,
      ].reduce(math.min);
      return ui.TargetImageSize(
        width: math.max(1, (w * scale).round()),
        height: math.max(1, (h * scale).round()),
      );
    },
  );
  try {
    final frame = await codec.getNextFrame();
    return await _toImage(frame.image);
  } finally {
    codec.dispose();
  }
}

/// A rendered [image] as pixels the signature helpers take (straight alpha:
/// the helpers lay it on white themselves). Disposes [image].
Future<img.Image> _toImage(ui.Image image) async {
  try {
    final data = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    if (data == null) throw StateError('the image could not be read');
    return dnImageFromRgba(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      image.width,
      image.height,
    );
  } finally {
    image.dispose();
  }
}

/// [paint] recorded onto a [width] × [height] image.
Future<img.Image> _render(
  int width,
  int height,
  void Function(Canvas canvas) paint,
) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final picture = recorder.endRecording();
  try {
    return await _toImage(await picture.toImage(width, height));
  } finally {
    picture.dispose();
  }
}

/// The pad's shape for [kind]: a signature is wide, initials are boxy.
double _aspect(DnSignatureKind kind) =>
    kind == DnSignatureKind.signature ? 3 : 4 / 3;

/// React's signature pad, in a dialog so a stroke never scrolls the page.
class _DrawDialog extends StatefulWidget {
  const _DrawDialog({required this.title, required this.kind});

  final String title;
  final DnSignatureKind kind;

  @override
  State<_DrawDialog> createState() => _DrawDialogState();
}

class _DrawDialogState extends State<_DrawDialog> {
  /// Each stroke's points, as fractions of the pad, so a resize keeps them.
  final _strokes = <List<Offset>>[];
  bool _saving = false;

  /// The pointer drawing the current stroke.
  int? _pointer;

  Offset _norm(Offset p, Size size) =>
      Offset((p.dx / size.width).clamp(0, 1), (p.dy / size.height).clamp(0, 1));

  Future<void> _use() async {
    if (_strokes.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      // Drawn large, then trimmed and scaled down to what React stores.
      const width = 1200.0;
      final height = width / _aspect(widget.kind);
      final pixels = await _render(
        width.round(),
        height.round(),
        (canvas) => _SignaturePainter(
          _strokes,
          strokeWidth: 6,
        ).paint(canvas, Size(width, height)),
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(dnSignatureDataUrl(dnTrimToInk(pixels), widget.kind));
    } on Object catch (e, st) {
      _log.warning('Rendering the signature failed', e, st);
      if (mounted) {
        setState(() => _saving = false);
        Notify.error(context, context.tr('an_error_occurred_try_again'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final screen = MediaQuery.sizeOf(context);
    // Sized from the height too: on a landscape phone a pad as wide as the
    // dialog would be squeezed out of its shape, and the strokes (stored
    // per axis) would stretch when drawn at the stored shape.
    final width = [
      520.0,
      screen.width - 96,
      (screen.height - 240) * _aspect(widget.kind),
    ].reduce(math.min).clamp(120.0, 520.0);
    // Cancel and Back stay live while it renders: a render that finishes
    // after the dialog has gone hands nothing back.
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: width,
        child: AspectRatio(
          aspectRatio: _aspect(widget.kind),
          child: LayoutBuilder(
            builder: (context, c) {
              final size = c.biggest;
              return Semantics(
                label: widget.title,
                // Raw pointers, not a pan: a pan starts only once a finger
                // has moved past the touch slop (36 px), which clipped the
                // start of every stroke and never recorded a dot.
                child: Listener(
                  key: const ValueKey('dn-signature-pad'),
                  behavior: HitTestBehavior.opaque,
                  // One pointer draws at a time: a second finger (a palm on
                  // a tablet) and a mouse's other buttons draw nothing.
                  onPointerDown: (e) {
                    if (_pointer != null) return;
                    if (e.kind == PointerDeviceKind.mouse &&
                        e.buttons != kPrimaryButton) {
                      return;
                    }
                    _pointer = e.pointer;
                    setState(
                      () => _strokes.add([_norm(e.localPosition, size)]),
                    );
                  },
                  onPointerMove: (e) {
                    if (e.pointer != _pointer || _strokes.isEmpty) return;
                    setState(
                      () => _strokes.last.add(_norm(e.localPosition, size)),
                    );
                  },
                  onPointerUp: (e) {
                    if (e.pointer == _pointer) _pointer = null;
                  },
                  onPointerCancel: (e) {
                    if (e.pointer == _pointer) _pointer = null;
                  },
                  child: DecoratedBox(
                    // Paper is white in either theme: the ink is black.
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: tokens.border),
                      borderRadius: BorderRadius.circular(InRadii.r1),
                    ),
                    child: CustomPaint(
                      painter: _SignaturePainter(_strokes, strokeWidth: 2.5),
                      size: Size.infinite,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _strokes.isEmpty || _saving
              ? null
              : () => setState(_strokes.clear),
          child: Text(context.tr('clear')),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('cancel')),
        ),
        PrimaryDialogAction(
          label: context.tr('done'),
          enabled: _strokes.isNotEmpty,
          busy: _saving,
          // Starts disabled: Enter can't reach it until there is ink.
          showEnterHint: false,
          onPressed: _use,
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.strokes, {required this.strokeWidth});

  final List<List<Offset>> strokes;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    Offset at(Offset f) => Offset(f.dx * size.width, f.dy * size.height);
    for (final stroke in strokes) {
      if (stroke.length == 1) {
        canvas.drawCircle(
          at(stroke.first),
          strokeWidth / 2,
          paint..style = PaintingStyle.fill,
        );
        paint.style = PaintingStyle.stroke;
        continue;
      }
      final path = Path()..moveTo(at(stroke.first).dx, at(stroke.first).dy);
      for (final p in stroke.skip(1)) {
        path.lineTo(at(p).dx, at(p).dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  // Strokes grow in place, so every repaint is a real change.
  @override
  bool shouldRepaint(_SignaturePainter old) => true;
}

/// React's Generate (`SignatureFontSelector.tsx`): typed text in one of five
/// handwriting fonts, drawn black on white.
class _GenerateDialog extends StatefulWidget {
  const _GenerateDialog({required this.kind});

  final DnSignatureKind kind;

  @override
  State<_GenerateDialog> createState() => _GenerateDialogState();
}

class _GenerateDialogState extends State<_GenerateDialog> {
  final _text = TextEditingController();
  String _font = kDnSignatureFonts.first;
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Whether [style]'s font arrived: a fixed Latin probe in it is never as
  /// wide as in the default face it falls back to. Not the user's text: a
  /// name in a script the handwriting font lacks (Hebrew, Arabic, CJK
  /// initials) falls back to the same platform face either way, and would
  /// read as never arrived on every attempt.
  static bool _fontLoaded(TextStyle style) {
    const probe = 'AaBbGgQq';
    double width(TextStyle s) {
      final p = TextPainter(
        text: TextSpan(text: probe, style: s),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final w = p.width;
      p.dispose();
      return w;
    }

    return width(style) != width(TextStyle(fontSize: style.fontSize));
  }

  static const _kMaxTextWidth = 2400.0;

  static TextPainter _paint(String text, TextStyle style) => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();

  /// The previews' styles, asked for once: asking again on every keystroke
  /// would, offline, start all five downloads again each time.
  late final Map<String, TextStyle> _previews = {
    for (final f in kDnSignatureFonts) f: _style(f, 30),
  };

  TextStyle _style(String font, double size) => GoogleFonts.getFont(
    font,
    textStyle: TextStyle(fontSize: size, color: Colors.black, height: 1.2),
  );

  Future<void> _use() async {
    final text = _text.text.trim();
    if (text.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      // Asking for the style starts the chosen font's fetch again if it
      // failed (offline) when the previews asked.
      final style = _style(_font, 200);
      // google_fonts can only wait on every font in flight (the previews'
      // too), and without a timeout of its own. Wait a while, ignore the
      // others' failures, then check the chosen one actually draws.
      try {
        await GoogleFonts.pendingFonts([
          style,
        ]).timeout(const Duration(seconds: 20));
      } on Object catch (e) {
        _log.fine('Waiting for the signature fonts: $e');
      }
      if (!mounted) return;
      if (!_fontLoaded(style)) {
        throw StateError('$_font is not loaded');
      }
      // Drawn at 200 px, smaller for a long text (React fits its text to
      // its canvas): a long paste would otherwise be wider than an image
      // can be.
      var painter = _paint(text, style);
      if (painter.width > _kMaxTextWidth) {
        final size = 200 * _kMaxTextWidth / painter.width;
        painter.dispose();
        painter = _paint(text, _style(_font, size.clamp(24, 200)));
      }
      final img.Image pixels;
      try {
        const pad = kDnSignaturePadding * 2.0;
        final width = painter.width + pad * 2;
        final height = painter.height + pad * 2;
        pixels = await _render(width.ceil(), height.ceil(), (canvas) {
          canvas.drawRect(
            Rect.fromLTWH(0, 0, width, height),
            Paint()..color = Colors.white,
          );
          painter.paint(canvas, const Offset(pad, pad));
        });
      } finally {
        painter.dispose();
      }
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(dnSignatureDataUrl(dnTrimToInk(pixels), widget.kind));
    } on Object catch (e, st) {
      // Offline, the font cannot be fetched: the generic error says so.
      _log.warning('Generating the signature failed', e, st);
      if (mounted) {
        setState(() => _saving = false);
        Notify.error(context, context.tr('an_error_occurred_try_again'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final initials = widget.kind == DnSignatureKind.initials;
    // Cancel and Back stay live while it renders (a font fetch can stall):
    // a render that finishes after the dialog has gone hands nothing back.
    return AlertDialog(
      title: Text(context.tr(initials ? 'enter_initials' : 'create_signature')),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _text,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: context.tr(
                    initials ? 'enter_initials' : 'type_signature',
                  ),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _use(),
              ),
              SizedBox(height: InSpacing.md(context)),
              RadioGroup<String>(
                groupValue: _font,
                onChanged: (f) {
                  if (f != null && !_saving) setState(() => _font = f);
                },
                child: Column(
                  children: [
                    for (final font in kDnSignatureFonts)
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        value: font,
                        // The name is the preview until there is text.
                        title: Container(
                          height: 56,
                          alignment: AlignmentDirectional.centerStart,
                          color: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: InSpacing.sm,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              _text.text.trim().isEmpty
                                  ? font
                                  : _text.text.trim(),
                              maxLines: 1,
                              style: _previews[font],
                              semanticsLabel: font,
                            ),
                          ),
                        ),
                        tileColor: tokens.surface,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('cancel')),
        ),
        PrimaryDialogAction(
          label: context.tr(initials ? 'done' : 'use_signature'),
          enabled: _text.text.trim().isNotEmpty,
          busy: _saving,
          showEnterHint: false,
          onPressed: _use,
        ),
      ],
    );
  }
}
