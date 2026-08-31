import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keyboard hints are keycaps, not glyphs typed into a string.
///
/// The command palette shipped a bordered `KeyCap` reading `Ctrl/` directly
/// above a row of flat text — `↑↓ · ↵ · esc` — so one modal spoke two visual
/// dialects ~40 px apart (invoiceninja/flutter#103). The invoice-design
/// autocomplete popover had the same defect in its own footer.
///
/// Both now build from `KeyCapRow`, which renders one `KeyCap` per glyph. The
/// tell for a relapse is an **adjacent arrow pair** in a string literal:
/// `'↑↓'` only reads as a unit when nobody drew the caps. A single `'↑'` is
/// fine — that is exactly what a cap label looks like.
///
/// Comment lines are stripped before scanning: the doc comments on
/// `_keyboardHints` and `KeyCapRow` quote the old row to explain what replaced
/// it, and this guard must not punish them for it.
void main() {
  /// Source lines of `lib/`, comments stripped, as `path:lineNo -> text`.
  Iterable<MapEntry<String, String>> codeLines() sync* {
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart') ||
          entity.path.endsWith('.freezed.dart')) {
        continue;
      }
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trimLeft().startsWith('//')) continue;
        yield MapEntry('${entity.path}:${i + 1}', lines[i]);
      }
    }
  }

  test('no lib/ source packs keyboard glyphs into one string', () {
    // `↵`/`⏎` are deliberately absent from this pattern: a bare `↵` beside the
    // control it activates is a separate, sanctioned tier (PrimaryDialogAction,
    // FilterSuggestionMenu). What this catches is a *row of hints* rebuilt as
    // text.
    final packed = RegExp('[↑↓←→]\\s*[↑↓←→]');
    final offenders = [
      for (final line in codeLines())
        if (packed.hasMatch(line.value)) line.key,
    ];

    expect(
      offenders,
      isEmpty,
      reason:
          'Two arrow glyphs in one literal means a keyboard hint was written '
          'as text. Build it with KeyCapRow (lib/ui/core/widgets/key_cap.dart) '
          "— `KeyCapRow(keys: const ['↑', '↓'], label: context.tr('navigate'))` "
          '— so it matches every other hint surface in the app.',
    );
  });

  // The defect the reporter actually filed: a chord flattened into one cap
  // label, which paints `Ctrl/` with no gap on Windows and Linux. The arrow
  // check above never saw this shape — it caught the two *footers*, not the
  // chip — so without this the guard misses invoiceninja/flutter#103 itself.
  test('no lib/ source concatenates a chord into one cap label', () {
    // A modifier is only ever its own cap. Catches the three spellings that
    // shipped: an interpolated platform modifier, a literal ⌘/⇧/Ctrl/Alt
    // glued to another character, and `displayGlyphs(...).join()`.
    final interpolatedModifier = RegExp(
      r'''\$\{?platform(History)?Modifier(Label|Glyphs)\(\)\}?[^'"\s,)\]]''',
    );
    final gluedModifier = RegExp(
      // `\$\{?(mod|navMod)\}?` covers both interpolation spellings — `$mod`
      // and `${mod}` — since the ? dialog used the braced one.
      r'''(⌘|⇧|Ctrl|Alt|\$\{?(mod|navMod)\}?)[^'"\s,)\]+]''',
    );
    final joinedGlyphs = RegExp(r'displayGlyphs\([^)]*\)\s*\.join\(');

    final offenders = <String>[];
    for (final line in codeLines()) {
      final text = line.value;
      if (joinedGlyphs.hasMatch(text)) {
        offenders.add('${line.key}  (displayGlyphs().join())');
        continue;
      }
      // Only where a cap is being built. Without this gate `isAltPressed`
      // (shortcut_hint_overlay.dart) matches `gluedModifier` — 'Alt' followed
      // by 'P' — and the guard fires on the modifier *detector*.
      if (!text.contains('label:') &&
          !text.contains('keys:') &&
          !text.contains('chords:')) {
        continue;
      }
      if (interpolatedModifier.hasMatch(text) || gluedModifier.hasMatch(text)) {
        offenders.add('${line.key}  (concatenated chord)');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'A chord is one KeyCap per glyph. A single cap carrying `⌘/` or '
          '`\${mod}S` reads as one key and renders `Ctrl/` with no gap on '
          'Windows and Linux — that was invoiceninja/flutter#103. Use '
          'KeyCapRow(keys: [platformModifierLabel(), ...]) instead.',
    );
  });
}
