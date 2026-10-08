import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_renderers/_shared.dart'
    show parseCssColor;
import 'package:admin/ui/features/settings/widgets/accent_swatch_grid.dart';

/// The designer's property controls.
///
/// One line each: the property's name on the left, its control on the right
/// ([PropertyRow]). The panel used to stack a caption over a full-width
/// outlined field for every property — a table ran to some fifteen hundred
/// pixels — and offered a colour as a hex code to type.
///
/// Conventions:
/// - `value` is whatever the underlying `block.properties[key]` shape is
///   (typically `String?` — '24px', '#000000', 'left'). Empty / null means
///   "use the renderer default."
/// - `onChanged` receives the new value, or `null` / `''` when the user
///   clears the control. Callers `mergePropertyOrOmit` so the key leaves the
///   properties map and the wire payload stays lean.

/// Width of the name column. Wide enough for "Alternate row background" to
/// wrap onto two lines rather than be cut.
const double _kLabelWidth = 112;

/// A row narrower than this puts its name above its control: the name's
/// column plus the widest control, a stepper with its unit and menu.
const double _kStackBelow = _kLabelWidth + 160;

/// One property: its name, then its control.
class PropertyRow extends StatelessWidget {
  const PropertyRow({super.key, required this.label, required this.child});

  /// Already translated.
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final name = Text(
      label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 13, height: 1.2, color: context.inTheme.ink2),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      // Beside the control where there is room for both, above it where
      // there is not — an editor nested in a list row's card is narrower
      // than the panel, and the widest control (a stepper) then ran 28px
      // past its edge.
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < _kStackBelow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [name, const SizedBox(height: 4), child],
            );
          }
          return Row(
            children: [
              SizedBox(
                width: _kLabelWidth,
                child: Padding(
                  padding: EdgeInsets.only(right: InSpacing.sm),
                  child: name,
                ),
              ),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: child,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A named group of properties. The name sits at the start with a rule
/// running to the edge.
class SectionDivider extends StatelessWidget {
  const SectionDivider({super.key, required this.labelKey});

  final String labelKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Padding(
      padding: EdgeInsets.only(
        top: InSpacing.lg(context),
        bottom: InSpacing.sm,
      ),
      child: Row(
        children: [
          Text(
            context.tr(labelKey).toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 1.1,
              color: tokens.ink3,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: InSpacing.sm),
          Expanded(child: Divider(height: 1, color: tokens.border)),
        ],
      ),
    );
  }
}

/// A group that starts closed: the rarely-touched properties (per-side
/// borders, cell padding, page-break rules). Everything a design usually
/// needs stays in view; this is the one place the panel hides anything.
/// Whether it is open is remembered per title for the session.
class PropertyDisclosure extends StatefulWidget {
  const PropertyDisclosure({
    super.key,
    this.titleKey = 'advanced',
    required this.children,
  });

  final String titleKey;
  final List<Widget> children;

  @override
  State<PropertyDisclosure> createState() => _PropertyDisclosureState();
}

class _PropertyDisclosureState extends State<PropertyDisclosure> {
  static final Map<String, bool> _remembered = {};

  bool get _open => _remembered[widget.titleKey] ?? false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: InSpacing.md(context)),
        InkWell(
          borderRadius: BorderRadius.circular(InRadii.r1),
          onTap: () => setState(() => _remembered[widget.titleKey] = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Text(
                  context.tr(widget.titleKey).toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 1.1,
                    color: tokens.ink3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: InSpacing.sm),
                Expanded(child: Divider(height: 1, color: tokens.border)),
                SizedBox(width: InSpacing.sm),
                Icon(
                  _open ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: tokens.ink3,
                  semanticLabel: context.tr(_open ? 'collapse' : 'expand'),
                ),
              ],
            ),
          ),
        ),
        if (_open) ...widget.children,
      ],
    );
  }
}

/// A named on/off property.
class PropertySwitch extends StatelessWidget {
  const PropertySwitch({
    super.key,
    required this.labelKey,
    required this.value,
    required this.onChanged,
    this.hintKey,
  });

  final String labelKey;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? hintKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return MergeSemantics(
      child: InkWell(
        borderRadius: BorderRadius.circular(InRadii.r1),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(labelKey),
                      style: TextStyle(fontSize: 13, color: tokens.ink2),
                    ),
                    if (hintKey != null)
                      Text(
                        context.tr(hintKey!),
                        style: TextStyle(fontSize: 11, color: tokens.ink3),
                      ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.8,
                alignment: AlignmentDirectional.centerEnd,
                child: Switch(value: value, onChanged: onChanged),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Left / centre / right.
class AlignmentInput extends StatelessWidget {
  const AlignmentInput({
    super.key,
    required this.labelKey,
    required this.value,
    required this.onChanged,
  });

  final String labelKey;
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final v = (value == null || value!.isEmpty) ? 'left' : value!;
    return PropertyRow(
      label: context.tr(labelKey),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (key, icon) in const [
            ('left', Icons.format_align_left),
            ('center', Icons.format_align_center),
            ('right', Icons.format_align_right),
          ])
            _ToggleIcon(
              icon: icon,
              tooltip: context.tr(key),
              selected: v == key,
              onPressed: () => onChanged(key),
            ),
        ],
      ),
    );
  }
}

/// Bold, and — where the PDF honours it — italic.
class FontStyleInput extends StatelessWidget {
  const FontStyleInput({
    super.key,
    required this.fontWeight,
    required this.fontStyle,
    required this.onFontWeightChanged,
    required this.onFontStyleChanged,
    this.showItalic = true,
  });

  final String? fontWeight;
  final String? fontStyle;
  final ValueChanged<String> onFontWeightChanged;
  final ValueChanged<String> onFontStyleChanged;

  /// False where the value has no italic to set — a control that changed
  /// nothing on the page or the PDF was worse than no control.
  final bool showItalic;

  @override
  Widget build(BuildContext context) {
    final isBold = fontWeight == 'bold' || fontWeight == '700';
    final isItalic = fontStyle == 'italic';
    return PropertyRow(
      label: context.tr('style'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleIcon(
            icon: Icons.format_bold,
            tooltip: context.tr('bold'),
            selected: isBold,
            onPressed: () => onFontWeightChanged(isBold ? 'normal' : 'bold'),
          ),
          if (showItalic)
            _ToggleIcon(
              icon: Icons.format_italic,
              tooltip: context.tr('italic'),
              selected: isItalic,
              onPressed: () =>
                  onFontStyleChanged(isItalic ? 'normal' : 'italic'),
            ),
        ],
      ),
    );
  }
}

class _ToggleIcon extends StatelessWidget {
  const _ToggleIcon({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: selected ? tokens.accentSoft : Colors.transparent,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: selected ? tokens.accent : tokens.border),
            borderRadius: BorderRadius.circular(InRadii.r1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Semantics(
              button: true,
              selected: selected,
              label: tooltip,
              child: SizedBox(
                width: 36,
                height: 32,
                child: Icon(
                  icon,
                  size: 18,
                  color: selected ? tokens.accent : tokens.ink2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Colours ─────────────────────────────────────────────────────────────

/// The colours the picker offers before its general palette: the ones this
/// design already uses, and the company's own. Reusing a colour is how a
/// document ends up looking designed; a hex field invited six near-greys.
class DesignerPaletteScope extends InheritedWidget {
  const DesignerPaletteScope({
    super.key,
    required this.inUse,
    required this.brand,
    required super.child,
  });

  final List<String> inUse;
  final List<String> brand;

  static DesignerPaletteScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DesignerPaletteScope>();

  @override
  bool updateShouldNotify(DesignerPaletteScope old) =>
      old.inUse.join() != inUse.join() || old.brand.join() != brand.join();
}

final RegExp _hexColor = RegExp(r'^#[0-9A-F]{6}$');

/// Every `#RRGGBB` colour set anywhere in [value], in first-seen order.
List<String> collectHexColors(Object? value, [List<String>? into]) {
  final out = into ?? <String>[];
  if (value is String) {
    // A colour is seven characters. An uploaded image is a `data:` URL of a
    // megabyte or two in the same map, and this runs on every panel rebuild.
    if (value.length > 9) return out;
    final hex = value.trim().toUpperCase();
    if (_hexColor.hasMatch(hex) && !out.contains(hex)) out.add(hex);
  } else if (value is Map) {
    for (final v in value.values) {
      collectHexColors(v, out);
    }
  } else if (value is Iterable) {
    for (final v in value) {
      collectHexColors(v, out);
    }
  }
  return out;
}

/// The neutrals a document is mostly made of, then the accent hues.
const List<String> _kDocumentSwatches = [
  '#000000',
  '#374151',
  '#6B7280',
  '#9CA3AF',
  '#E5E7EB',
  '#F3F4F6',
  '#FFFFFF',
  ...kAccentSwatches,
];

/// A colour property: a swatch and its code, opening a picker. Emits `''`
/// for "back to the default".
class ColorInput extends StatelessWidget {
  const ColorInput({
    super.key,
    required this.labelKey,
    required this.value,
    required this.onChanged,
    this.defaultValue,
  });

  final String labelKey;
  final String? value;
  final ValueChanged<String> onChanged;

  /// What the renderer uses when the property is unset.
  final String? defaultValue;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final set = value != null && value!.trim().isNotEmpty;
    final effective = set ? value!.trim() : (defaultValue ?? '#000000');
    final label = context.tr(labelKey);
    return PropertyRow(
      label: label,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: tokens.border),
          borderRadius: BorderRadius.circular(InRadii.r1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            final picked = await showDesignerColorPicker(
              context,
              title: label,
              current: set ? effective : null,
              defaultValue: defaultValue,
            );
            if (picked != null) onChanged(picked);
          },
          child: Semantics(
            button: true,
            label: '$label, ${set ? effective : context.tr('default')}',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: parseCssColor(effective),
                      borderRadius: BorderRadius.circular(InRadii.r1),
                      border: Border.all(color: tokens.border),
                    ),
                  ),
                  SizedBox(width: InSpacing.sm),
                  Expanded(
                    child: Text(
                      set ? effective.toUpperCase() : context.tr('default'),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontFamily: set ? kMonoFontFamily : null,
                        color: set ? tokens.ink : tokens.ink3,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, size: 18, color: tokens.ink3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pick a colour. Returns the `#RRGGBB` chosen, `''` for "use the default",
/// or null when dismissed.
///
/// A dialog on a wide window, a sheet on a narrow one — both routes, so
/// Android's back closes either with no overlay wiring.
Future<String?> showDesignerColorPicker(
  BuildContext context, {
  required String title,
  String? current,
  String? defaultValue,
}) {
  final scope = DesignerPaletteScope.maybeOf(context);
  final body = _ColorPickerBody(
    title: title,
    current: current,
    defaultValue: defaultValue,
    inUse: scope?.inUse ?? const [],
    brand: scope?.brand ?? const [],
  );
  if (MediaQuery.sizeOf(context).width >= 600) {
    return showDialog<String>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: body,
        ),
      ),
    );
  }
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SafeArea(child: body),
  );
}

class _ColorPickerBody extends StatelessWidget {
  const _ColorPickerBody({
    required this.title,
    required this.current,
    required this.defaultValue,
    required this.inUse,
    required this.brand,
  });

  final String title;
  final String? current;
  final String? defaultValue;
  final List<String> inUse;
  final List<String> brand;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final selected = (current ?? '').toUpperCase();
    Widget group(String labelKey, List<String> colors) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(labelKey),
          style: TextStyle(fontSize: 12, color: tokens.ink3),
        ),
        SizedBox(height: InSpacing.sm),
        AccentSwatchGrid(
          selected: selected,
          palette: colors,
          onSelected: (hex) => Navigator.of(context).pop(hex.toUpperCase()),
        ),
        SizedBox(height: InSpacing.lg(context)),
      ],
    );
    final general = [
      for (final hex in _kDocumentSwatches)
        if (!inUse.contains(hex) && !brand.contains(hex)) hex,
    ];
    return SingleChildScrollView(
      padding: EdgeInsets.all(InSpacing.lg(context)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: InSpacing.lg(context)),
          if (inUse.isNotEmpty)
            group('in_this_design', inUse.take(14).toList()),
          if (brand.isNotEmpty) group('company', brand),
          AccentSwatchGrid(
            selected: selected,
            palette: general,
            allowCustom: true,
            onSelected: (hex) => Navigator.of(context).pop(hex.toUpperCase()),
          ),
          SizedBox(height: InSpacing.lg(context)),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(''),
                child: Text(context.tr('default')),
              ),
              SizedBox(width: InSpacing.md(context)),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 40),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.tr('cancel')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Numbers ─────────────────────────────────────────────────────────────

/// A font size in px: step it, type it, or pick a preset. Unset means the
/// document's size.
class FontSizeInput extends StatelessWidget {
  const FontSizeInput({
    super.key,
    required this.labelKey,
    required this.value,
    required this.onChanged,
    this.presets = const [
      '10px',
      '12px',
      '14px',
      '16px',
      '18px',
      '24px',
      '32px',
    ],
  });

  final String labelKey;
  final String? value;
  final ValueChanged<String?> onChanged;
  final List<String> presets;

  @override
  Widget build(BuildContext context) => PxInput(
    labelKey: labelKey,
    value: value,
    onChanged: onChanged,
    resettable: true,
    minPx: 4,
    maxPx: 96,
    presets: presets,
  );
}

/// A length in px: `−`, the number, `+`. Empty emits `null` so callers can
/// remove the key and fall back to the default; [minPx] / [maxPx] clamp what
/// is typed or stepped to.
class PxInput extends StatefulWidget {
  const PxInput({
    super.key,
    required this.labelKey,
    required this.value,
    required this.onChanged,
    this.hintText,
    this.resettable = false,
    this.minPx = 0,
    this.maxPx,
    this.presets = const [],
  });

  final String labelKey;
  final Object? value;
  final ValueChanged<String?> onChanged;

  /// Shown while empty — what the renderer uses then.
  final String? hintText;

  /// Offer "Default" (clears the value).
  final bool resettable;

  /// The least it can be stepped or typed to. Zero unless said otherwise:
  /// every length here is a size, a padding or a gap, and with no floor one
  /// press of "−" on an empty padding wrote `-1px` — invalid CSS for the
  /// server, and an assertion on the canvas.
  final int minPx;
  final int? maxPx;

  /// Values offered in a menu beside the field.
  final List<String> presets;

  @override
  State<PxInput> createState() => _PxInputState();
}

class _PxInputState extends State<PxInput> {
  late final TextEditingController _controller;
  Object? _lastBoundValue;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _stringify(widget.value));
    _lastBoundValue = widget.value;
  }

  static String _stringify(Object? v) {
    if (v == null) return '';
    return v.toString().replaceAll('px', '').trim();
  }

  @override
  void didUpdateWidget(covariant PxInput old) {
    super.didUpdateWidget(old);
    if (widget.value != _lastBoundValue) {
      _lastBoundValue = widget.value;
      final next = _stringify(widget.value);
      if (next != _controller.text) _controller.text = next;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _clamp(int v) {
    var out = v;
    if (out < widget.minPx) out = widget.minPx;
    if (widget.maxPx != null && out > widget.maxPx!) out = widget.maxPx!;
    return out;
  }

  void _emit(int? px) {
    if (px == null) {
      _lastBoundValue = null;
      widget.onChanged(null);
      return;
    }
    final next = '${_clamp(px)}px';
    _lastBoundValue = next;
    widget.onChanged(next);
  }

  void _step(int by) {
    final current =
        int.tryParse(_controller.text.trim()) ??
        int.tryParse(widget.hintText ?? '') ??
        widget.minPx;
    final next = _clamp(current + by);
    _controller.text = '$next';
    _emit(next);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final label = context.tr(widget.labelKey);
    final hasMenu = widget.presets.isNotEmpty || widget.resettable;
    return PropertyRow(
      label: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove,
            tooltip: '$label −',
            onPressed: () => _step(-1),
          ),
          SizedBox(
            width: 52,
            child: TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                hintText: widget.hintText ?? '–',
                hintStyle: TextStyle(color: tokens.ink3, fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: tokens.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: tokens.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: tokens.accent, width: 1.5),
                ),
              ),
              onChanged: (v) {
                final trimmed = v.trim();
                _emit(trimmed.isEmpty ? null : int.tryParse(trimmed));
              },
            ),
          ),
          _StepButton(
            icon: Icons.add,
            tooltip: '$label +',
            onPressed: () => _step(1),
            trailing: true,
          ),
          SizedBox(width: InSpacing.xs),
          Text('px', style: TextStyle(fontSize: 11, color: tokens.ink3)),
          if (hasMenu)
            PopupMenuButton<String>(
              tooltip: label,
              padding: EdgeInsets.zero,
              // `child`, not `icon`: an icon button here is 48 wide, which
              // the row does not have.
              child: SizedBox(
                width: 24,
                height: 34,
                child: Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: tokens.ink3,
                ),
              ),
              onSelected: (v) {
                if (v.isEmpty) {
                  _controller.clear();
                  _emit(null);
                } else {
                  _controller.text = _stringify(v);
                  _emit(int.tryParse(_stringify(v)));
                }
              },
              itemBuilder: (ctx) => [
                if (widget.resettable)
                  PopupMenuItem(value: '', child: Text(ctx.tr('default'))),
                for (final p in widget.presets)
                  PopupMenuItem(value: p, child: Text(p)),
              ],
            ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.trailing = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    const r = Radius.circular(InRadii.r1);
    return Material(
      color: tokens.surfaceAlt,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: tokens.border),
        borderRadius: trailing
            ? const BorderRadius.horizontal(right: r)
            : const BorderRadius.horizontal(left: r),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Semantics(
          button: true,
          label: tooltip,
          child: SizedBox(
            width: 28,
            height: 34,
            child: Icon(icon, size: 14, color: tokens.ink2),
          ),
        ),
      ),
    );
  }
}

/// A unit-less line height.
class LineHeightInput extends StatelessWidget {
  const LineHeightInput({
    super.key,
    required this.labelKey,
    required this.value,
    required this.onChanged,
  });

  final String labelKey;
  final String? value;
  final ValueChanged<String?> onChanged;

  static const List<String> _presets = [
    '1.0',
    '1.2',
    '1.3',
    '1.4',
    '1.5',
    '1.6',
    '2.0',
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final current = (value == null || value!.isEmpty) ? null : value;
    return PropertyRow(
      label: context.tr(labelKey),
      child: DropdownButtonHideUnderline(
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: tokens.border),
            borderRadius: BorderRadius.circular(InRadii.r1),
          ),
          child: DropdownButton<String>(
            value: current,
            isDense: true,
            hint: Text(
              context.tr('default'),
              style: TextStyle(fontSize: 13, color: tokens.ink3),
            ),
            style: DefaultTextStyle.of(
              context,
            ).style.copyWith(fontSize: 13, color: tokens.ink),
            items: [
              DropdownMenuItem(value: '', child: Text(context.tr('default'))),
              for (final p in {..._presets, ?current})
                DropdownMenuItem(value: p, child: Text(p)),
            ],
            onChanged: (v) => onChanged((v == null || v.isEmpty) ? null : v),
          ),
        ),
      ),
    );
  }
}

/// Property-mutation helper mirroring React's `mergePxOrOmit`:
/// - `null` / empty → remove the key from `properties` entirely.
/// - everything else → set the key to the value.
/// Centralizes the "lean wire payload" rule from React.
Map<String, dynamic> mergePropertyOrOmit(
  Map<String, dynamic> properties,
  String key,
  Object? value,
) {
  final next = Map<String, dynamic>.from(properties);
  if (value == null || (value is String && value.isEmpty)) {
    next.remove(key);
  } else {
    next[key] = value;
  }
  return next;
}
