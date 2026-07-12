import 'package:flutter/material.dart';

import 'package:admin/app/color_hex.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

/// Default accent palette. Hex values are stored as `#RRGGBB` on
/// `company_user.settings.accent_color` — same wire format admin-portal and
/// React use, so a value chosen here round-trips through both. The first
/// entry is the admin-portal default (`kDefaultAccentColor`) so users get
/// the familiar blue when "reset" applies.
const kAccentSwatches = <String>[
  '#2F7DC3',
  '#1F2937',
  '#298AAB',
  '#16A34A',
  '#0EA5E9',
  '#6366F1',
  '#A855F7',
  '#EC4899',
  '#EF4444',
  '#F97316',
  '#F59E0B',
  '#84CC16',
  '#14B8A6',
];

/// Palette for TaskStatus colors. Leading grey is the default for newly
/// created statuses — communicates "set me up" without staking out a
/// workflow meaning the way blue / green / red would. The remaining
/// colors are tuned for kanban legibility (high contrast against the
/// white card surface).
const kStatusSwatches = <String>[
  '#9CA3AF', // neutral grey — default for new statuses
  '#0EA5E9', // sky blue
  '#16A34A', // emerald — "Done"-ish
  '#F59E0B', // amber — "In Progress"-ish
  '#EF4444', // red — "Blocked"-ish
  '#A855F7', // purple
  '#EC4899', // pink
  '#14B8A6', // teal
  '#6366F1', // indigo
  '#1F2937', // slate
];

// ─────────── Neutral ramps for the custom-palette editor ───────────
//
// The custom theme's structural tokens (page background, card surface, text,
// borders) need *neutral* quick-picks, not saturated brand hues — a user
// setting a "Background" wants near-white on the light side and near-black on
// the dark side, with a few greys, plus a couple of tints. These ramps are
// brightness-aware: `…Light` leads with the lightest, `…Dark` with the
// darkest, so the first swatch is the sensible default for that side. The hex
// field still allows any colour; these just make the grid usable.

// Every customize ramp is exactly 9 entries and contains its token's preset
// colours for the 3 presets of that brightness, so each row shows the same
// swatch count (the trailing custom tile lines up) and the active preset
// always has a matching swatch (✓ shows).

/// Page-background / card-surface ramp — light side. Includes the light
/// bg+surface presets (#F6F4EF, #ECEEF2, #FFFFFF, #FAFAF9).
const kLightSurfaceSwatches = <String>[
  '#FFFFFF',
  '#FAFAF9',
  '#F6F4EF',
  '#ECEEF2',
  '#E5E5E4',
  '#D6CFBF',
  '#BFC7D3',
  '#9CA3AF',
  '#6B7280',
];

/// Page-background / card-surface ramp — dark side. Includes the dark
/// bg+surface presets (#15140F/#0F1115/#000000 and #1F1E18/#181B21/#0E0E0E).
const kDarkSurfaceSwatches = <String>[
  '#000000',
  '#0E0E0E',
  '#0F1115',
  '#15140F',
  '#161616',
  '#181B21',
  '#1F1E18',
  '#28261F',
  '#2E2B22',
];

/// Text / ink ramp — light side. Includes the light ink presets
/// (#1A1814, #16171A, #18181A).
const kLightInkSwatches = <String>[
  '#1A1814',
  '#16171A',
  '#18181A',
  '#2B2A28',
  '#45454A',
  '#4A4540',
  '#7A7E85',
  '#857F73',
  '#B5AE9F',
];

/// Text / ink ramp — dark side. Includes the dark ink presets
/// (#F6F4EF, #ECEEF2, #F2F2F2).
const kDarkInkSwatches = <String>[
  '#FFFFFF',
  '#F6F4EF',
  '#F2F2F2',
  '#ECEEF2',
  '#C8C2B5',
  '#ADB2BA',
  '#9CA3AF',
  '#857F73',
  '#5A554B',
];

/// Border / divider ramp — light side. Includes the light border presets
/// (#E8E3D8, #DDE2EA, #E5E5E4).
const kLightBorderSwatches = <String>[
  '#E8E3D8',
  '#E5E5E4',
  '#DDE2EA',
  '#D6CFBF',
  '#CECDCB',
  '#BFC7D3',
  '#ADB2BA',
  '#9CA3AF',
  '#6B7280',
];

/// Border / divider ramp — dark side. Includes the dark border presets
/// (#2E2B22, #262A32, #1F1F1F).
const kDarkBorderSwatches = <String>[
  '#1F1F1F',
  '#262A32',
  '#2E2B22',
  '#28261F',
  '#1F232B',
  '#3A362B',
  '#3A3A3A',
  '#4A4540',
  '#5A554B',
];

/// Grid of selectable accent-colour chips. Lives outside any feature folder
/// so Preferences can compose it (settings > user_details > preferences)
/// without dragging the screen-level chrome along.
class AccentSwatchGrid extends StatelessWidget {
  const AccentSwatchGrid({
    required this.selected,
    required this.onSelected,
    this.palette = kAccentSwatches,
    this.allowCustom = false,
    super.key,
  });

  /// `#RRGGBB` of the currently-selected swatch, or empty for none.
  final String selected;

  /// Called with the chosen swatch's `#RRGGBB` hex.
  final ValueChanged<String> onSelected;

  /// Source list of swatches. Defaults to [kAccentSwatches] (the user-
  /// accent palette). TaskStatuses passes [kStatusSwatches] for a
  /// kanban-tuned set led by neutral grey.
  final List<String> palette;

  /// When true, append a trailing tile that opens a hex picker for an
  /// arbitrary colour. The tile also renders the current [selected] colour
  /// (and shows the ✓) when it isn't one of the [palette] swatches, so any
  /// value always has a visible selected state.
  final bool allowCustom;

  bool _inPalette(String hex) =>
      palette.any((p) => p.toLowerCase() == hex.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final selectedInPalette = _inPalette(selected);
    return Wrap(
      spacing: InSpacing.md(context),
      runSpacing: InSpacing.md(context),
      children: [
        for (final hex in palette)
          _Swatch(
            hex: hex,
            isSelected: hex.toLowerCase() == selected.toLowerCase(),
            onTap: () => onSelected(hex),
          ),
        if (allowCustom)
          _CustomSwatch(
            // Show the custom value (selected) when it isn't a palette entry;
            // otherwise it's a neutral "pick custom" affordance.
            current: !selectedInPalette ? parseHexColor(selected) : null,
            isSelected: !selectedInPalette && parseHexColor(selected) != null,
            onPicked: onSelected,
            seed: selected,
          ),
      ],
    );
  }
}

/// Trailing tile for [AccentSwatchGrid.allowCustom]: opens a validated hex
/// dialog. Doubles as the selected-state indicator for arbitrary colours.
class _CustomSwatch extends StatelessWidget {
  const _CustomSwatch({
    required this.current,
    required this.isSelected,
    required this.onPicked,
    required this.seed,
  });

  final Color? current;
  final bool isSelected;
  final ValueChanged<String> onPicked;
  final String seed;

  Future<void> _open(BuildContext context) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => _HexPickerDialog(seed: seed),
    );
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Tooltip(
      message: context.tr('custom_color'),
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(InRadii.r2),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: current ?? tokens.surface,
            borderRadius: BorderRadius.circular(InRadii.r2),
            border: Border.all(
              color: isSelected ? tokens.ink : tokens.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: isSelected && current != null
              ? Icon(
                  Icons.check,
                  size: 18,
                  color:
                      ThemeData.estimateBrightnessForColor(current!) ==
                          Brightness.dark
                      ? Colors.white
                      : Colors.black,
                )
              : Icon(Icons.colorize, size: 18, color: tokens.ink3),
        ),
      ),
    );
  }
}

/// HSV spectrum picker: a saturation/brightness area + a hue bar + a hex
/// field + a large live preview. Canonical state is [HSVColor]; the hex
/// field is a two-way input that updates the HSV state when it parses.
class _HexPickerDialog extends StatefulWidget {
  const _HexPickerDialog({required this.seed});
  final String seed;

  @override
  State<_HexPickerDialog> createState() => _HexPickerDialogState();
}

class _HexPickerDialogState extends State<_HexPickerDialog> {
  late HSVColor _hsv;
  late final TextEditingController _hex;

  @override
  void initState() {
    super.initState();
    final seed = parseHexColor(widget.seed) ?? const Color(0xFF2F7DC3);
    _hsv = HSVColor.fromColor(seed);
    _hex = TextEditingController(text: formatHexColor(seed));
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  Color get _color => _hsv.toColor();

  void _setHsv(HSVColor v) {
    setState(() => _hsv = v);
    final hex = formatHexColor(v.toColor());
    if (_hex.text.toUpperCase() != hex.toUpperCase()) {
      _hex.text = hex; // keep the field in sync with drags
    }
  }

  void _onHexChanged(String s) {
    final c = parseHexColor(s);
    if (c != null) setState(() => _hsv = HSVColor.fromColor(c));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return AlertDialog(
      title: Text(context.tr('custom_color')),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 160,
              child: Row(
                children: [
                  Expanded(
                    child: _SVBox(hsv: _hsv, onChanged: _setHsv),
                  ),
                  SizedBox(width: InSpacing.md(context)),
                  Container(
                    width: 44,
                    decoration: BoxDecoration(
                      color: _color,
                      borderRadius: BorderRadius.circular(InRadii.r2),
                      border: Border.all(color: tokens.border),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: InSpacing.md(context)),
            SizedBox(
              height: 24,
              child: _HueBar(hsv: _hsv, onChanged: _setHsv),
            ),
            SizedBox(height: InSpacing.md(context)),
            TextField(
              controller: _hex,
              maxLines: 1,
              textInputAction: TextInputAction.done,
              style: const TextStyle(fontFamily: 'monospace'),
              decoration: const InputDecoration(
                hintText: '#RRGGBB',
                isDense: true,
              ),
              onChanged: _onHexChanged,
              onSubmitted: (_) {
                final c = parseHexColor(_hex.text);
                if (c != null) {
                  Navigator.of(context).pop(formatHexColor(c));
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('cancel')),
        ),
        SizedBox(width: InSpacing.md(context)),
        PrimaryDialogAction(
          label: context.tr('save'),
          autofocus: false,
          onPressed: () => Navigator.of(context).pop(formatHexColor(_color)),
        ),
      ],
    );
  }
}

/// Saturation (x) × brightness/value (y) area for the current hue.
class _SVBox extends StatelessWidget {
  const _SVBox({required this.hsv, required this.onChanged});
  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;

  void _emit(Offset p, Size size) {
    final s = (p.dx / size.width).clamp(0.0, 1.0);
    final v = (1 - p.dy / size.height).clamp(0.0, 1.0);
    onChanged(hsv.withSaturation(s).withValue(v));
  }

  @override
  Widget build(BuildContext context) {
    final border = context.inTheme.border;
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => _emit(d.localPosition, size),
          onPanUpdate: (d) => _emit(d.localPosition, size),
          child: CustomPaint(
            size: size,
            painter: _SVPainter(hsv: hsv, border: border),
          ),
        );
      },
    );
  }
}

class _SVPainter extends CustomPainter {
  _SVPainter({required this.hsv, required this.border});
  final HSVColor hsv;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(InRadii.r2),
    );
    canvas.save();
    canvas.clipRRect(rrect);
    final base = HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor();
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white, base],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xFF000000)],
        ).createShader(rect),
    );
    canvas.restore();
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = border,
    );
    final c = Offset(
      (hsv.saturation * size.width).clamp(0.0, size.width),
      ((1 - hsv.value) * size.height).clamp(0.0, size.height),
    );
    canvas.drawCircle(
      c,
      7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white,
    );
    canvas.drawCircle(
      c,
      7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black,
    );
  }

  @override
  bool shouldRepaint(_SVPainter old) => old.hsv != hsv || old.border != border;
}

/// Full-spectrum hue selector.
class _HueBar extends StatelessWidget {
  const _HueBar({required this.hsv, required this.onChanged});
  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;

  void _emit(Offset p, Size size) {
    final h = (p.dx / size.width).clamp(0.0, 1.0) * 360.0;
    onChanged(hsv.withHue(h));
  }

  @override
  Widget build(BuildContext context) {
    final border = context.inTheme.border;
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => _emit(d.localPosition, size),
          onPanUpdate: (d) => _emit(d.localPosition, size),
          child: CustomPaint(
            size: size,
            painter: _HuePainter(hue: hsv.hue, border: border),
          ),
        );
      },
    );
  }
}

class _HuePainter extends CustomPainter {
  _HuePainter({required this.hue, required this.border});
  final double hue;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(InRadii.r2),
    );
    final colors = [
      for (final h in const [0.0, 60.0, 120.0, 180.0, 240.0, 300.0, 360.0])
        HSVColor.fromAHSV(1, h, 1, 1).toColor(),
    ];
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(
      rect,
      Paint()..shader = LinearGradient(colors: colors).createShader(rect),
    );
    canvas.restore();
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = border,
    );
    final x = (hue / 360.0 * size.width).clamp(0.0, size.width);
    final thumb = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(x, size.height / 2),
        width: 6,
        height: size.height + 4,
      ),
      const Radius.circular(InRadii.r1),
    );
    canvas.drawRRect(
      thumb,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white,
    );
    canvas.drawRRect(
      thumb,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black,
    );
  }

  @override
  bool shouldRepaint(_HuePainter old) => old.hue != hue || old.border != border;
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.hex,
    required this.isSelected,
    required this.onTap,
  });

  final String hex;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final color = parseAccentHex(hex) ?? tokens.accent;
    return Tooltip(
      message: hex,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(InRadii.r2),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(InRadii.r2),
            border: Border.all(
              color: isSelected ? tokens.ink : tokens.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: isSelected
              ? Icon(
                  Icons.check,
                  size: 18,
                  color:
                      ThemeData.estimateBrightnessForColor(color) ==
                          Brightness.dark
                      ? Colors.white
                      : Colors.black,
                )
              : null,
        ),
      ),
    );
  }
}

/// Parse `#RRGGBB` / `#AARRGGBB` (case-insensitive). Returns `null` for an
/// empty or malformed input. Thin alias over the foundational
/// [parseHexColor] so existing call sites keep the accent-flavoured name.
Color? parseAccentHex(String hex) => parseHexColor(hex);

/// Inverse of [parseAccentHex] — alias over [formatHexColor].
String formatAccentHex(Color color) => formatHexColor(color);
