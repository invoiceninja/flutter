import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/features/settings/widgets/keyboard_shortcut_recorder.dart';

void main() {
  group('shortcutBindingRejection', () {
    String? reject(
      LogicalKeyboardKey key, {
      bool usesPrimary = false,
      bool alt = false,
    }) => shortcutBindingRejection(key, usesPrimary: usesPrimary, alt: alt);

    test('allows a bare letter and a primary-modified letter', () {
      expect(reject(LogicalKeyboardKey.keyS), isNull);
      expect(reject(LogicalKeyboardKey.keyS, usesPrimary: true), isNull);
      expect(reject(LogicalKeyboardKey.keyN), isNull);
    });

    test('rejects any Alt chord (unrepresentable in the binding model)', () {
      expect(reject(LogicalKeyboardKey.keyN, alt: true), 'shortcut_reserved');
      expect(
        reject(LogicalKeyboardKey.keyN, usesPrimary: true, alt: true),
        'shortcut_reserved',
      );
    });

    test('rejects arrow keys under every modifier (history + nav)', () {
      for (final arrow in [
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
      ]) {
        expect(reject(arrow), 'shortcut_reserved', reason: '$arrow bare');
        expect(
          reject(arrow, usesPrimary: true),
          'shortcut_reserved',
          reason: '$arrow + primary',
        );
      }
    });

    test('rejects bare G (leader key) but allows primary+G', () {
      expect(reject(LogicalKeyboardKey.keyG), 'shortcut_reserved');
      expect(reject(LogicalKeyboardKey.keyG, usesPrimary: true), isNull);
    });

    test('rejects primary-modified editing/OS letters', () {
      for (final k in [
        LogicalKeyboardKey.keyC,
        LogicalKeyboardKey.keyV,
        LogicalKeyboardKey.keyX,
        LogicalKeyboardKey.keyA,
        LogicalKeyboardKey.keyZ,
        LogicalKeyboardKey.keyQ,
        LogicalKeyboardKey.keyW,
        LogicalKeyboardKey.keyR,
        LogicalKeyboardKey.keyT,
      ]) {
        expect(reject(k, usesPrimary: true), 'shortcut_reserved', reason: '$k');
        // The same letter is fine WITHOUT the primary modifier.
        expect(reject(k), isNull, reason: '$k bare');
      }
    });

    test('rejects bare universal keys but allows them with primary', () {
      expect(reject(LogicalKeyboardKey.tab), 'shortcut_reserved');
      expect(reject(LogicalKeyboardKey.enter), 'shortcut_reserved');
      expect(reject(LogicalKeyboardKey.space), 'shortcut_reserved');
      expect(reject(LogicalKeyboardKey.backspace), 'shortcut_reserved');
      // With the primary modifier these bare-reserved keys are allowed.
      expect(reject(LogicalKeyboardKey.enter, usesPrimary: true), isNull);
    });
  });
}
