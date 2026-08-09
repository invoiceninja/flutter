import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/env.dart';

/// Drives [Env.isDesktop] / [Env.isMobile] across the platform matrix by
/// overriding `defaultTargetPlatform`. The `kIsWeb` branch is a compile-time
/// const `false` in a VM test run, so the web case (both getters return false)
/// can't be exercised here — it's guaranteed by construction, not asserted.
void main() {
  // Restore the ambient platform after each case so overrides don't leak.
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  void withPlatform(TargetPlatform platform, void Function() body) {
    debugDefaultTargetPlatformOverride = platform;
    body();
  }

  group('Env.isDesktop', () {
    test('true on the three desktop platforms', () {
      for (final p in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        withPlatform(p, () => expect(Env.isDesktop, isTrue, reason: '$p'));
      }
    });

    test('false on mobile and fuchsia', () {
      for (final p in [
        TargetPlatform.iOS,
        TargetPlatform.android,
        TargetPlatform.fuchsia,
      ]) {
        withPlatform(p, () => expect(Env.isDesktop, isFalse, reason: '$p'));
      }
    });
  });

  group('Env.isMobile', () {
    test('true only on iOS and Android', () {
      for (final p in [TargetPlatform.iOS, TargetPlatform.android]) {
        withPlatform(p, () => expect(Env.isMobile, isTrue, reason: '$p'));
      }
    });

    test('false on desktop and fuchsia', () {
      for (final p in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.fuchsia,
      ]) {
        withPlatform(p, () => expect(Env.isMobile, isFalse, reason: '$p'));
      }
    });

    test('is not the inverse of isDesktop — fuchsia is neither', () {
      withPlatform(TargetPlatform.fuchsia, () {
        expect(Env.isMobile, isFalse);
        expect(Env.isDesktop, isFalse);
      });
    });
  });

  // Unlike the two getters above, this one has *no* `kIsWeb` guard — that
  // absence is the point (a mobile browser reports `android`, and a finger is
  // still a finger). A VM run can't observe the web path either way, so the
  // contract is documented on the getter rather than asserted here.
  group('Env.isTouchPrimary', () {
    test('true only on iOS and Android', () {
      for (final p in [TargetPlatform.iOS, TargetPlatform.android]) {
        withPlatform(p, () => expect(Env.isTouchPrimary, isTrue, reason: '$p'));
      }
    });

    test('false on desktop and fuchsia', () {
      for (final p in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.fuchsia,
      ]) {
        withPlatform(
          p,
          () => expect(Env.isTouchPrimary, isFalse, reason: '$p'),
        );
      }
    });
  });
}
