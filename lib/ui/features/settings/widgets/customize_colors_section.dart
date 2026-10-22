import 'package:flutter/material.dart';

import 'package:admin/app/color_hex.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme_controller.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/widgets/accent_swatch_grid.dart';
import 'package:admin/ui/features/settings/widgets/theme_tile.dart';

/// Collapsible "Customize colors" section — four device-local colour
/// overrides (background / surface / text / border) layered on the
/// selected preset for the brightness currently in effect. Pure
/// [ThemeController]: no save bar, persists immediately. Accent lives
/// elsewhere (it's the server-synced per-user setting on User Details).
class CustomizeColorsSection extends StatefulWidget {
  const CustomizeColorsSection({super.key, required this.controller});

  final ThemeController controller;

  @override
  State<CustomizeColorsSection> createState() => _CustomizeColorsSectionState();
}

class _CustomizeColorsSectionState extends State<CustomizeColorsSection> {
  bool _expanded = false;

  static const _tokenLabel = {
    CustomToken.background: 'background',
    CustomToken.surface: 'surface',
    CustomToken.ink: 'text_color',
    CustomToken.border: 'border',
  };

  static Color _tokenColor(InTheme t, CustomToken token) => switch (token) {
    CustomToken.background => t.bg,
    CustomToken.surface => t.surface,
    CustomToken.ink => t.ink,
    CustomToken.border => t.border,
  };

  static List<String> _ramp(CustomToken token, bool dark) => switch (token) {
    CustomToken.background ||
    CustomToken.surface => dark ? kDarkSurfaceSwatches : kLightSurfaceSwatches,
    CustomToken.ink => dark ? kDarkInkSwatches : kLightInkSwatches,
    CustomToken.border => dark ? kDarkBorderSwatches : kLightBorderSwatches,
  };

  /// Palette = the token's curated ramp verbatim (all six ramps are the same
  /// length and already contain the 3 preset colours for that brightness, so
  /// every row has the same swatch count — the custom tile lines up — and the
  /// active preset always has a matching swatch). An arbitrary custom override
  /// isn't in the ramp, so `AccentSwatchGrid`'s custom tile owns the ✓.
  (List<String>, Color) _paletteAndColor(
    CustomToken token,
    Brightness side,
    InTheme resolved,
  ) {
    final dark = side == Brightness.dark;
    return (_ramp(token, dark), _tokenColor(resolved, token));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: Text(context.tr('customize_colors')),
          trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded)
          Padding(
            padding: EdgeInsets.only(
              left: InSpacing.md(context),
              right: InSpacing.md(context),
              bottom: InSpacing.md(context),
            ),
            child: ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final theme = widget.controller;
                final side = activeBrightness(context, theme.themeMode);
                final dark = side == Brightness.dark;
                final resolved = dark ? theme.darkTokens : theme.lightTokens;
                final overrides = theme.customTheme.overridesFor(side);
                final presetKey = dark
                    ? darkVariantKey(theme.darkVariant)
                    : lightVariantKey(theme.lightVariant);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (theme.themeMode == ThemeMode.system)
                      Padding(
                        padding: EdgeInsets.only(bottom: InSpacing.md(context)),
                        child: Text(
                          context.tr('customize_follows_device'),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.inTheme.ink3),
                        ),
                      ),
                    for (final token in _tokenLabel.keys)
                      Builder(
                        builder: (context) {
                          final (palette, color) = _paletteAndColor(
                            token,
                            side,
                            resolved,
                          );
                          return _SwatchBlock(
                            label: context.tr(_tokenLabel[token]!),
                            child: AccentSwatchGrid(
                              palette: palette,
                              allowCustom: true,
                              selected: formatHexColor(color),
                              onSelected: (hex) {
                                final c = parseHexColor(hex);
                                if (c != null) {
                                  theme.setCustomOverride(side, token, c);
                                }
                              },
                            ),
                          );
                        },
                      ),
                    if (overrides.isNotEmpty)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            context
                                .tr('reset_to_preset')
                                .replaceFirst(
                                  '{preset}',
                                  context.tr(presetKey),
                                ),
                          ),
                          onPressed: () => theme.clearCustomSide(side),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}

class _SwatchBlock extends StatelessWidget {
  const _SwatchBlock({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: InSpacing.md(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          SizedBox(height: InSpacing.sm),
          child,
        ],
      ),
    );
  }
}
