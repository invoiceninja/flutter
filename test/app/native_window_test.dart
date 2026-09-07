import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/native_window.dart';

/// `WindowChrome.fromMap` had no test at all before the frameless Windows /
/// Linux title bar added fields to it. Every case here is about the *absent*
/// key: the payload comes from three different runners at three different
/// versions, so "an older runner keeps the old behaviour exactly" is the
/// invariant that matters, and it is the one nothing else would catch.
void main() {
  group('WindowChrome.fromMap', () {
    test('an empty payload reproduces the default chrome exactly', () {
      expect(WindowChrome.fromMap(const {}), const WindowChrome());
    });

    test('the macOS payload is unchanged by the new fields', () {
      // Exactly what the macOS runner sends today — no `maximized`, no
      // `active`. It must still describe a normal, focused, non-maximized
      // window with real traffic lights.
      final chrome = WindowChrome.fromMap(const {
        'fullscreen': false,
        'captionHeight': 32.0,
        'buttonsCenterY': 16.0,
        'buttonsTrailingX': 69.0,
      });

      expect(chrome.captionHeight, 32.0);
      expect(chrome.buttonsCenterY, 16.0);
      expect(chrome.buttonsTrailingX, 69.0);
      expect(chrome.hasWindowButtons, isTrue);
      expect(chrome.maximized, isFalse);
      expect(chrome.active, isTrue);
    });

    test('maximized parses, and defaults false when absent', () {
      expect(WindowChrome.fromMap(const {'maximized': true}).maximized, isTrue);
      expect(
        WindowChrome.fromMap(const {'maximized': false}).maximized,
        isFalse,
      );
      expect(WindowChrome.fromMap(const {}).maximized, isFalse);
      // A malformed value is treated as absent, like every other field here.
      expect(
        WindowChrome.fromMap(const {'maximized': 'yes'}).maximized,
        isFalse,
      );
    });

    test(
      'active defaults TRUE when absent — it cannot use the == true shape',
      () {
        // The regression this guards: `active` is the one flag whose default is
        // true, so parsing it as `map['active'] == true` would report every
        // window from every runner that does not send the key as unfocused, and
        // permanently dim the drawn caption glyphs.
        expect(WindowChrome.fromMap(const {}).active, isTrue);
        expect(WindowChrome.fromMap(const {'active': false}).active, isFalse);
        expect(WindowChrome.fromMap(const {'active': true}).active, isTrue);
        expect(WindowChrome.fromMap(const {'active': 'no'}).active, isTrue);
      },
    );

    test(
      'an explicit zero buttonsTrailingX survives, but an absent key does not',
      () {
        // The Windows/Linux runners must send 0 explicitly: absent means "this
        // runner did not measure", which keeps the macOS fallback of 70.
        expect(
          WindowChrome.fromMap(const {'buttonsTrailingX': 0}).buttonsTrailingX,
          0,
        );
        expect(
          WindowChrome.fromMap(const {}).buttonsTrailingX,
          kFallbackButtonsTrailingX,
        );
      },
    );

    test('customFrame defaults TRUE when absent — same trap as active', () {
      // A runner predating the key, or any platform that never reports, must
      // read as "the app owns the title bar" — the value the app has always
      // assumed. Parsed with `== true` it would invert, and every Windows and
      // Linux build would silently stop painting its band.
      expect(WindowChrome.fromMap(const {}).customFrame, isTrue);
      expect(
        WindowChrome.fromMap(const {'customFrame': false}).customFrame,
        isFalse,
      );
      expect(
        WindowChrome.fromMap(const {'customFrame': true}).customFrame,
        isTrue,
      );
      expect(
        WindowChrome.fromMap(const {'customFrame': 'no'}).customFrame,
        isTrue,
      );
    });

    test('the new fields participate in equality and hashCode', () {
      const base = WindowChrome();
      expect(base == const WindowChrome(maximized: true), isFalse);
      expect(base == const WindowChrome(active: false), isFalse);
      expect(base == const WindowChrome(customFrame: false), isFalse);
      expect(
        const WindowChrome(maximized: true, active: false).hashCode,
        const WindowChrome(maximized: true, active: false).hashCode,
      );
    });
  });

  group('platform predicates', () {
    test('only macOS hosts the real-traffic-light caption row', () {
      for (final platform in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = platform;
        try {
          expect(
            hostsMacCaptionRow(),
            platform == TargetPlatform.macOS,
            reason: '$platform',
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      }
    });

    test('only Windows and Linux paint their own title bar', () {
      for (final platform in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = platform;
        try {
          expect(
            paintsAppTitleBar(),
            platform == TargetPlatform.windows ||
                platform == TargetPlatform.linux,
            reason: '$platform',
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      }
    });

    test('the three desktop platforms host the arrows; mobile does not', () {
      for (final platform in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = platform;
        try {
          expect(
            windowChromeHostsNavArrows(),
            platform == TargetPlatform.macOS ||
                platform == TargetPlatform.windows ||
                platform == TargetPlatform.linux,
            reason: '$platform',
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      }
    });
  });
}
