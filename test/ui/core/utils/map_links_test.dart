import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/utils/map_links.dart';
import 'package:admin/utils/url_safety.dart';

/// A map link is an ordinary https link, so it goes through `isSafeWebUrl`
/// like every other outbound URL — no scheme exemption.
void main() {
  const address = '12 Main St, 10115 Berlin, Germany';

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Apple Maps on Apple platforms', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
      debugDefaultTargetPlatformOverride = platform;
      final uri = mapSearchUri(address);
      expect(uri.host, 'maps.apple.com', reason: '$platform');
      expect(uri.queryParameters['q'], address);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  test('Google Maps everywhere else', () {
    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      final uri = mapSearchUri(address);
      expect(uri.host, 'www.google.com', reason: '$platform');
      expect(uri.queryParameters['query'], address);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  test('the address is encoded, and the result passes the web-url gate', () {
    for (final platform in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = platform;
      final url = mapSearchUri('1 A&B St #4, "Quote" City?x=1').toString();
      expect(isSafeWebUrl(url), isTrue, reason: '$platform');
      // Nothing in the address can add a parameter of its own.
      final params = Uri.parse(url).queryParameters;
      expect(params.containsKey('x'), isFalse, reason: '$platform');
    }
    debugDefaultTargetPlatformOverride = null;
  });
}
