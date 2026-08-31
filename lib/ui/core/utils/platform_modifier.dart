import 'package:flutter/foundation.dart';

/// Show `⌘` on macOS/iOS, `Ctrl` everywhere else. The canonical glyph for
/// the primary keyboard modifier, shared by the keyboard-shortcuts help
/// dialog, the command palette, the hold-modifier hint bar, and hover
/// shortcut tooltips. Pass an [override] in tests to assert both branches.
String platformModifierLabel([TargetPlatform? override]) {
  final p = override ?? defaultTargetPlatform;
  return (p == TargetPlatform.macOS || p == TargetPlatform.iOS) ? '⌘' : 'Ctrl';
}

/// Modifier for browser-style history (back/forward). Follows the per-OS
/// browser convention: macOS uses ⌘+Arrow, Windows/Linux use Alt+Arrow —
/// which is *not* the same as [platformModifierLabel]'s Ctrl elsewhere.
///
/// Returns a `+`-joined *prose* label. For keycaps use
/// [platformHistoryModifierGlyphs], which is one entry per key.
String platformHistoryModifierLabel([TargetPlatform? override]) {
  final p = override ?? defaultTargetPlatform;
  return (p == TargetPlatform.macOS || p == TargetPlatform.iOS) ? '⌘' : 'Alt+';
}

/// [platformHistoryModifierLabel] split into one glyph per key, for `KeyCapRow`.
///
/// A keycap row already reads as a combination, so the `+` in `'Alt+'` must not
/// end up inside a cap. Both call sites — the sidebar's history tooltips and
/// the `?` dialog — used to hand-roll `.replaceAll('+', '')`, which quietly
/// depends on there being at most one modifier: a future `'Ctrl+Shift+'` would
/// collapse into a single `CtrlShift` cap, which is the concatenated-label
/// defect invoiceninja/flutter#103 removed. Splitting can't do that.
List<String> platformHistoryModifierGlyphs([TargetPlatform? override]) =>
    platformHistoryModifierLabel(
      override,
    ).split('+').where((g) => g.isNotEmpty).toList();
