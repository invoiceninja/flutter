import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';

/// A small "keycap" chip rendering a single keyboard key or glyph
/// (e.g. `⌘`, `K`, `Esc`, `↵`) in a bordered, monospaced badge.
///
/// The shared visual language for keyboard hints across the app: the
/// Keyboard Shortcuts help dialog, the command palette's `⌘/` hint, the
/// hold-modifier hint bar, and hover shortcut tooltips. Reads tokens via
/// `context.inTheme` so it tracks light/dark automatically.
class KeyCap extends StatelessWidget {
  const KeyCap({super.key, required this.label, this.color});

  final String label;

  /// Foreground color for the glyph. Defaults to `tokens.ink`; pass a
  /// dimmer token (e.g. `tokens.ink3`) for a subtler hint.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Semantics(
      label: 'Key: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: tokens.surfaceAlt,
          border: Border.all(color: tokens.border),
          borderRadius: BorderRadius.circular(InRadii.r1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: kMonoFontFamily,
            fontFeatures: const [FontFeature.tabularFigures()],
            fontSize: 12,
            color: color ?? tokens.ink,
          ),
        ),
      ),
    );
  }
}
