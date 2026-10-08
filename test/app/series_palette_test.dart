import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';

double _channel(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

const _presets = <String, InTheme>{
  'lightSand': InTheme.lightSand,
  'lightMist': InTheme.lightMist,
  'lightPaper': InTheme.lightPaper,
  'darkEspresso': InTheme.darkEspresso,
  'darkMidnight': InTheme.darkMidnight,
  'darkCarbon': InTheme.darkCarbon,
};

void main() {
  test('eight series colours in every preset, none of them repeated', () {
    for (final e in _presets.entries) {
      expect(e.value.series, hasLength(8), reason: e.key);
      expect(e.value.series.toSet(), hasLength(8), reason: e.key);
    }
  });

  test('light and dark are the two sets, picked by brightness', () {
    expect(InTheme.lightSand.series, InTheme.lightPaper.series);
    expect(InTheme.darkCarbon.series, InTheme.darkMidnight.series);
    expect(InTheme.lightSand.series, isNot(InTheme.darkCarbon.series));
    // Slot 6 (green) is the one step shared by both modes.
    expect(InTheme.lightSand.series[5], InTheme.darkCarbon.series[5]);
  });

  test('on a dark card every series colour clears 3:1', () {
    for (final name in ['darkEspresso', 'darkMidnight', 'darkCarbon']) {
      final t = _presets[name]!;
      for (final c in t.series) {
        expect(
          _contrast(c, t.surface),
          greaterThanOrEqualTo(3.0),
          reason: '$name ${c.toARGB32().toRadixString(16)}',
        );
      }
    }
  });

  test('on a light card five clear 3:1, and the three that do not are '
      'the ones a chart must label', () {
    // Aqua, yellow and magenta are under 3:1 on white by design — the palette
    // trades that for staying apart under colour-blindness — which obliges
    // every chart that uses them to show its values in text. If this count
    // changes, the palette changed.
    for (final name in ['lightSand', 'lightMist', 'lightPaper']) {
      final t = _presets[name]!;
      final weak = [
        for (var i = 0; i < t.series.length; i++)
          if (_contrast(t.series[i], t.surface) < 3.0) i,
      ];
      expect(weak, [2, 3, 4], reason: name);
      // None so faint it disappears.
      for (final c in t.series) {
        expect(_contrast(c, t.surface), greaterThan(2.0), reason: name);
      }
    }
  });

  test('a series colour is never the accent', () {
    for (final e in _presets.entries) {
      expect(e.value.series, isNot(contains(e.value.accent)), reason: e.key);
    }
  });

  test('"Other" is neutral ink, not one of the series', () {
    for (final e in _presets.entries) {
      expect(e.value.seriesOther, e.value.ink4, reason: e.key);
      expect(e.value.series, isNot(contains(e.value.seriesOther)));
    }
  });
}
