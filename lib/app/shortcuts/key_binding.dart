import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart'
    show CharacterActivator, ShortcutActivator, SingleActivator;

/// A single remappable keyboard chord, stored in a platform-neutral form so one
/// binding works on every OS.
///
/// Two shapes:
/// - **logical-key chord** ([logicalKeyId] set): a modified key like ⌘K.
///   [usesPrimary] means "the platform primary modifier" — [toActivators]
///   expands it to BOTH a `meta` (Apple) and a `control` (elsewhere) activator,
///   exactly as the hand-written `const` shell maps did. A `control`-only combo
///   can't fire on macOS and a `meta`-only combo can't fire on Windows, so
///   emitting both is harmless and keeps the binding portable.
/// - **character trigger** ([character] set): an unmodified produced glyph like
///   `?` or `/`, layout-independent via [CharacterActivator] (`Shift+/` on US,
///   `Shift+Comma` on AZERTY both produce `?`).
///
/// Deliberately *not* representable here: the browser-history ⌘/Alt+Arrow combo
/// (asymmetric per-OS modifier) and the `G`+letter leader sequence — both stay
/// fixed and non-remappable (see `shortcut_catalog.dart`).
@immutable
class KeyBinding {
  const KeyBinding.logical(
    this.logicalKeyId, {
    this.usesPrimary = false,
    this.shift = false,
  }) : character = null;

  const KeyBinding.character(String this.character)
    : logicalKeyId = null,
      usesPrimary = false,
      shift = false;

  /// [LogicalKeyboardKey.keyId] for the logical-key shape; null for a character
  /// trigger. Stored as the raw int so the binding round-trips through JSON
  /// without a key registry.
  final int? logicalKeyId;

  /// The produced glyph for a [CharacterActivator]; null for a logical chord.
  final String? character;

  /// Expand [usesPrimary] to both meta (Apple) and control (elsewhere).
  final bool usesPrimary;
  final bool shift;

  bool get isCharacter => character != null;

  LogicalKeyboardKey? get logicalKey =>
      logicalKeyId == null ? null : LogicalKeyboardKey(logicalKeyId!);

  /// Expand to the concrete activator(s). A primary-modified logical chord
  /// yields two entries (meta + control); everything else yields one.
  List<ShortcutActivator> toActivators() {
    final char = character;
    if (char != null) return [CharacterActivator(char)];
    final key = LogicalKeyboardKey(logicalKeyId!);
    if (usesPrimary) {
      return [
        SingleActivator(key, meta: true, shift: shift),
        SingleActivator(key, control: true, shift: shift),
      ];
    }
    return [SingleActivator(key, shift: shift)];
  }

  /// Canonical, comparable string key(s) for each produced activator — one per
  /// entry [toActivators] would emit. Needed because Flutter's [SingleActivator]
  /// / [CharacterActivator] use *identity* equality (they're matched at runtime
  /// via `accepts`, never by map-key equality), so they can't key a Set/Map for
  /// conflict or dedup detection. Two bindings clash iff their signature sets
  /// intersect.
  List<String> activatorSignatures() {
    final char = character;
    if (char != null) return ['char:$char'];
    final base = 'key:$logicalKeyId:shift=$shift';
    if (usesPrimary) return ['$base:meta', '$base:control'];
    return [base];
  }

  /// Human-facing glyph sequence for `KeyCap` chips. [primaryModifierLabel] is
  /// injected (`⌘`/`Ctrl`) so this stays pure + unit-testable — no platform
  /// lookups at the model layer.
  List<String> displayGlyphs(String primaryModifierLabel) {
    final char = character;
    if (char != null) return [char];
    final glyphs = <String>[];
    if (usesPrimary) glyphs.add(primaryModifierLabel);
    if (shift) glyphs.add('⇧');
    glyphs.add(_glyphForLogicalKey(LogicalKeyboardKey(logicalKeyId!)));
    return glyphs;
  }

  Map<String, dynamic> toJson() => {
    if (logicalKeyId != null) 'key': logicalKeyId,
    if (character != null) 'char': character,
    if (usesPrimary) 'primary': true,
    if (shift) 'shift': true,
  };

  /// Parse a stored binding. Returns null for an unrecognized / empty payload
  /// (treated by the controller as "no binding").
  static KeyBinding? fromJson(Map<String, dynamic> json) {
    final char = json['char'];
    if (char is String && char.isNotEmpty) return KeyBinding.character(char);
    final key = json['key'];
    if (key is int) {
      return KeyBinding.logical(
        key,
        usesPrimary: json['primary'] == true,
        shift: json['shift'] == true,
      );
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is KeyBinding &&
      other.logicalKeyId == logicalKeyId &&
      other.character == character &&
      other.usesPrimary == usesPrimary &&
      other.shift == shift;

  @override
  int get hashCode => Object.hash(logicalKeyId, character, usesPrimary, shift);

  @override
  String toString() =>
      'KeyBinding(${character ?? 'key:$logicalKeyId'}'
      '${usesPrimary ? ',primary' : ''}${shift ? ',shift' : ''})';
}

/// Punctuation keys whose `keyLabel` isn't reliably a single glyph across
/// platforms. Letters/digits fall through to `keyLabel`.
const Map<int, String> _symbolGlyphs = {
  0x0000002c: ',', // comma
  0x0000002e: '.', // period
  0x0000002f: '/', // slash
  0x0000003b: ';', // semicolon
  0x00000027: "'", // quote
  0x0000005b: '[', // bracketLeft
  0x0000005d: ']', // bracketRight
  0x0000005c: r'\', // backslash
  0x00000060: '`', // backquote
  0x0000002d: '-', // minus
  0x0000003d: '=', // equal
};

String _glyphForLogicalKey(LogicalKeyboardKey key) {
  final symbol = _symbolGlyphs[key.keyId];
  if (symbol != null) return symbol;
  final label = key.keyLabel;
  if (label.isNotEmpty) {
    return label.length == 1 ? label.toUpperCase() : label;
  }
  return key.debugName ?? '?';
}
