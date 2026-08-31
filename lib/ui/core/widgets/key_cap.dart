import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';

/// A small "keycap" chip rendering a single keyboard key or glyph
/// (e.g. `⌘`, `K`, `Esc`, `↵`) in a bordered, monospaced badge.
///
/// The shared visual language for keyboard hints across the app: the
/// Keyboard Shortcuts help dialog, the command palette's `⌘ /` hint, the
/// hold-modifier hint bar, and hover shortcut tooltips. Reads tokens via
/// `context.inTheme` so it tracks light/dark automatically.
///
/// A chord is **one cap per glyph** — build it with [KeyCapRow], never a
/// single cap carrying a concatenated label.
class KeyCap extends StatelessWidget {
  const KeyCap({
    super.key,
    required this.label,
    this.color,
    this.dense = false,
  });

  final String label;

  /// Foreground color for the glyph. Defaults to `tokens.ink`; pass a
  /// dimmer token (e.g. `tokens.ink3`) for a subtler hint.
  final Color? color;

  /// Smaller cap, for a hint that has to fit a narrow fixed-size popover
  /// (the invoice-design autocomplete footer, 320 px wide). ~17 px tall
  /// against the default ~22.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Semantics(
      label: 'Key: $label',
      excludeSemantics: true,
      child: Container(
        padding: dense
            ? const EdgeInsets.symmetric(horizontal: 4, vertical: 1)
            : const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: tokens.surfaceAlt,
          border: Border.all(color: tokens.border),
          borderRadius: BorderRadius.circular(InRadii.r1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: kMonoFontFamily,
            // The bundled JetBrains Mono has `↑ ↓ ← → ⌘ ⇧ ·` but NOT `↵`
            // (U+21B5), `⏎`, `↩`, `⌤`, `⎋` or `⌫`. Without this a cap for one
            // of those drops to whatever the platform font manager picks —
            // Menlo / Segoe UI Symbol / Noto — a different face and different
            // metrics beside the cap next to it. Inter Tight covers them all,
            // and a fallback is only consulted on a miss, so every glyph the
            // mono face does have is unaffected. No widget test can catch a
            // regression here: `flutter test` substitutes its own font.
            fontFamilyFallback: const [kSansFontFamily],
            fontFeatures: const [FontFeature.tabularFigures()],
            fontSize: dense ? 10 : 12,
            color: color ?? tokens.ink,
          ),
        ),
      ),
    );
  }
}

/// A keyboard hint: one [KeyCap] per glyph in [keys], 3 px apart, optionally
/// followed by [label] saying what those keys do.
///
/// **One cap per glyph** — `[⌘][/]`, never a single `⌘/` cap — so a hint reads
/// the same wherever it appears. The command palette shipped a concatenated
/// `Ctrl/` chip directly above a row of flat, middot-separated text: two
/// treatments of one idea ~40 px apart (invoiceninja/flutter#103). Runs of
/// hints separate on **spacing**, never a middot — a bordered cap is already
/// its own visual unit, and a dot between two of them invites the reading
/// "↑↓ *then* Enter".
///
/// [keys] is "the keys involved in this hint", *not* strictly a chord: the
/// palette footer's `['↑', '↓']` means **either** arrow, while the field
/// chip's `['⌘', '/']` means **both together**. Where that distinction has to
/// be explicit — the `?` help dialog, which lists genuine alternatives — the
/// caller renders one [KeyCapRow] per alternative and separates them with
/// `context.tr('or')`.
///
/// [label] is an already-localized string, not a key, which keeps this a leaf
/// widget with no l10n dependency; each caller does its own `context.tr`.
class KeyCapRow extends StatelessWidget {
  const KeyCapRow({
    super.key,
    required this.keys,
    this.label,
    this.dense = false,
    this.keyColor,
  });

  final List<String> keys;

  /// What the keys do. Null renders the caps alone.
  final String? label;

  /// Smaller caps + label — see [KeyCap.dense].
  final bool dense;

  /// Foreground for every cap — see [KeyCap.color]. Defaults to `tokens.ink`;
  /// the settings shortcuts screen passes `tokens.warning` to flag a chord
  /// that collides with another binding.
  final Color? keyColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final text = label;
    // One utterance per hint. `KeyCap` announces itself individually, so an
    // unmerged `[↑][↓] Navigate` is three screen-reader stops ("Key: ↑",
    // "Key: ↓", "Navigate") for what a sighted user reads as one phrase.
    // Inert at two of the call sites — `ShortcutHintOverlay` wraps its whole
    // bar in `ExcludeSemantics`, and `re_editor` does the same to the
    // design-editor popover — but it does real work in the command palette
    // (field chip + footer), the `?` dialog, and the settings screens.
    return MergeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < keys.length; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            KeyCap(label: keys[i], dense: dense, color: keyColor),
          ],
          if (text != null) ...[
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(fontSize: dense ? 11 : 13, color: tokens.ink2),
            ),
          ],
        ],
      ),
    );
  }
}
