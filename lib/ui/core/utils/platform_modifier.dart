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
String platformHistoryModifierLabel([TargetPlatform? override]) {
  final p = override ?? defaultTargetPlatform;
  return (p == TargetPlatform.macOS || p == TargetPlatform.iOS) ? '⌘' : 'Alt+';
}
