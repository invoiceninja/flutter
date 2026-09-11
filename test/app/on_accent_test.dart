import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';

/// `InTheme.onAccent` — the foreground for content on a filled `accent`.
///
/// It exists because `accentInk` (the *text-on-surface* accent) reads about
/// 2:1 against `accent` itself, and it is computed rather than constant
/// because `accent` is user-overridable. That makes it exactly the kind of
/// thing that can be quietly wrong: the first cut compared its dark candidate
/// against pure black while returning near-black, which flipped the choice for
/// accents in a narrow luminance band — a band containing the stock swatch.

double _channel(double v) =>
    v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

double _ratio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

const _white = Color(0xFFFFFFFF);
const _nearBlack = Color(0xFF10161C);

void main() {
  final presets = <String, InTheme>{
    'lightSand': InTheme.lightSand,
    'lightMist': InTheme.lightMist,
    'lightPaper': InTheme.lightPaper,
    'darkEspresso': InTheme.darkEspresso,
    'darkMidnight': InTheme.darkMidnight,
    'darkCarbon': InTheme.darkCarbon,
  };

  group('onAccent picks the higher-contrast candidate', () {
    for (final entry in presets.entries) {
      test(entry.key, () {
        final t = entry.value;
        final picked = t.onAccent;
        final other = picked == _white ? _nearBlack : _white;
        expect(
          _ratio(picked, t.accent),
          greaterThanOrEqualTo(_ratio(other, t.accent)),
          reason:
              '${entry.key}: picked $picked at '
              '${_ratio(picked, t.accent).toStringAsFixed(2)}:1 over $other at '
              '${_ratio(other, t.accent).toStringAsFixed(2)}:1',
        );
      });
    }

    // The accent swatches a user can pick, plus the stock one. `#2F7DC3` is
    // the case the first implementation got wrong, and `#16A34A` is the case
    // that proves the choice really does flip — a selector hardcoded to white
    // would pass every blue and fail here.
    for (final hex in const [0xFF2F7DC3, 0xFF1F2937, 0xFF16A34A, 0xFFEF4444]) {
      test('override #${hex.toRadixString(16).substring(2).toUpperCase()}', () {
        // `buildInTheme` hands back a `ThemeData`; the tokens ride on it as a
        // `ThemeExtension`, and it is that derived copy — not `InTheme.light`
        // — which carries the overridden accent family.
        final t = buildInTheme(
          InTheme.light,
          accentOverride: Color(hex),
        ).extension<InTheme>()!;
        final picked = t.onAccent;
        final other = picked == _white ? _nearBlack : _white;
        expect(
          _ratio(picked, t.accent),
          greaterThanOrEqualTo(_ratio(other, t.accent)),
        );
      });
    }
  });

  test('the stock accent takes white, not near-black', () {
    // Pinned explicitly: this is the default every user sees, it is the case
    // the arithmetic bug flipped, and the margin (4.34 vs 4.20) is small
    // enough that only an exact assertion would catch a regression.
    expect(InTheme.light.accent, const Color(0xFF2F7DC3));
    expect(InTheme.light.onAccent, _white);
  });

  test('it beats accentInk, which is what the token exists for', () {
    for (final entry in presets.entries) {
      final t = entry.value;
      expect(
        _ratio(t.onAccent, t.accent),
        greaterThan(_ratio(t.accentInk, t.accent)),
        reason: '${entry.key}: onAccent must beat the accentInk pairing',
      );
    }
  });
}
