import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

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
class DnSignatureField extends StatelessWidget {
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

  Future<void> _upload(BuildContext context, List<UploadSource> files) async {
    if (files.isEmpty) return;
    try {
      final source = files.first;
      final bytes = await source.readRange(0, await source.length());
      final rgba = await _decode(bytes);
      if (rgba == null) throw const FormatException('not an image');
      onChanged(dnSignatureDataUrl(rgba, kind));
    } on Object catch (e, st) {
      _log.info('Reading the uploaded signature failed', e, st);
      if (context.mounted) {
        Notify.error(context, context.tr('invalid_file'));
      }
    }
  }

  Future<void> _draw(BuildContext context) async {
    final url = await showDialog<String>(
      context: context,
      builder: (_) => _DrawDialog(title: label, kind: kind),
    );
    if (url != null) onChanged(url);
  }

  Future<void> _generate(BuildContext context) async {
    final url = await showDialog<String>(
      context: context,
      builder: (_) => _GenerateDialog(kind: kind),
    );
    if (url != null) onChanged(url);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final bytes = dnSignatureBytes(value);
    final has = bytes != null && bytes.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: TextStyle(color: tokens.ink3, fontSize: 12)),
        const SizedBox(height: 4),
        FileDropZone(
          allowedExtensions: _kImageExtensions,
          onFiles: (files) => _upload(context, files),
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
              onPressed: enabled ? () => _draw(context) : null,
              icon: const Icon(Icons.draw_outlined, size: 18),
              label: Text(context.tr('draw')),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: enabled ? () => _generate(context) : null,
              icon: const Icon(Icons.text_fields, size: 18),
              label: Text(context.tr('generate')),
            ),
            if (has)
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(64, 40)),
                onPressed: enabled ? () => onChanged('') : null,
                child: Text(context.tr('clear')),
              ),
          ],
        ),
      ],
    );
  }
}

/// [bytes] (an image file) decoded by the platform, or null.
Future<img.Image?> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    final frame = await codec.getNextFrame();
    return await _toImage(frame.image);
  } finally {
    codec.dispose();
  }
}

/// A rendered [image] as pixels the signature helpers take.
Future<img.Image?> _toImage(ui.Image image) async {
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    return dnImageFromRgba(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      image.width,
      image.height,
    );
  } finally {
    image.dispose();
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

  Offset _norm(Offset p, Size size) =>
      Offset((p.dx / size.width).clamp(0, 1), (p.dy / size.height).clamp(0, 1));

  Future<void> _use() async {
    if (_strokes.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      // Drawn large, then trimmed and scaled down to what React stores.
      const width = 1200.0;
      final height = width / _aspect(widget.kind);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      _SignaturePainter(
        _strokes,
        strokeWidth: 6,
      ).paint(canvas, Size(width, height));
      final image = await recorder.endRecording().toImage(
        width.round(),
        height.round(),
      );
      final pixels = await _toImage(image);
      if (!mounted || pixels == null) return;
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
    final width = math.min(520.0, MediaQuery.sizeOf(context).width - 96);
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
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
                  child: GestureDetector(
                    key: const ValueKey('dn-signature-pad'),
                    onPanStart: (d) => setState(
                      () => _strokes.add([_norm(d.localPosition, size)]),
                    ),
                    onPanUpdate: (d) => setState(
                      () => _strokes.last.add(_norm(d.localPosition, size)),
                    ),
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
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
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
      ),
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

  TextStyle _style(String font, double size) => GoogleFonts.getFont(
    font,
    textStyle: TextStyle(fontSize: size, color: Colors.black, height: 1.2),
  );

  Future<void> _use() async {
    final text = _text.text.trim();
    if (text.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final style = _style(_font, 200);
      // The font must be in before it can be drawn.
      await GoogleFonts.pendingFonts([style]);
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      const pad = kDnSignaturePadding * 2.0;
      final width = painter.width + pad * 2;
      final height = painter.height + pad * 2;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)
        ..drawRect(
          Rect.fromLTWH(0, 0, width, height),
          Paint()..color = Colors.white,
        );
      painter.paint(canvas, const Offset(pad, pad));
      painter.dispose();
      final image = await recorder.endRecording().toImage(
        width.ceil(),
        height.ceil(),
      );
      final pixels = await _toImage(image);
      if (!mounted || pixels == null) return;
      Navigator.of(
        context,
      ).pop(dnSignatureDataUrl(dnTrimToInk(pixels), widget.kind));
    } on Object catch (e, st) {
      // Offline, the font cannot be fetched.
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
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(
          context.tr(initials ? 'enter_initials' : 'create_signature'),
        ),
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
                                style: _style(font, 30),
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
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
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
      ),
    );
  }
}
