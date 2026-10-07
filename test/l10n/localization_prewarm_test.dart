import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/l10n/localization.dart';

/// Flutter holds the first frame until the localization delegate's `load`
/// resolves, and that load used to begin only after `runApp` — behind the
/// database open and the session restore. `Localization.prewarm` starts the
/// two bundles every locale needs from the top of `main()` instead. It must
/// hand `load` the same result, read each file once, and never be the reason
/// boot fails to reach `runApp`.
class _CountingBundle extends AssetBundle {
  _CountingBundle(this.files);

  final Map<String, String> files;
  final loads = <String>[];

  @override
  Future<ByteData> load(String key) async {
    loads.add(key);
    final body = files[key];
    if (body == null) throw FlutterError('Unable to load asset: $key');
    return ByteData.sublistView(utf8.encode(body));
  }
}

void main() {
  setUp(Localization.resetCachesForTest);
  tearDown(Localization.resetCachesForTest);

  test(
    'the delegate finds the prewarmed bundles and reads nothing more',
    () async {
      final bundle = _CountingBundle({
        'assets/i18n/en.json': '{"greeting":"from the prewarm"}',
        'assets/i18n/_app_pending.json': '{"pending_only":"also prewarmed"}',
      });

      Localization.prewarm(bundle: bundle);
      // A second call while the first is in flight is the delegate's situation
      // exactly: it must join that load, not start another.
      Localization.prewarm(bundle: bundle);

      final loaded = await Localization.delegate.load(const Locale('en'));

      expect(loaded.lookup('greeting'), 'from the prewarm');
      expect(loaded.lookup('pending_only'), 'also prewarmed');
      expect(
        bundle.loads,
        unorderedEquals([
          'assets/i18n/en.json',
          'assets/i18n/_app_pending.json',
        ]),
        reason: 'each file is read once, and only from the bundle prewarm used',
      );
    },
  );

  test('a bundle that cannot be read does not throw out of prewarm', () async {
    final bundle = _CountingBundle(const {});

    expect(() => Localization.prewarm(bundle: bundle), returnsNormally);
    // Let both loads fail. Each swallows its own error; one that escaped
    // would fail this test as an unhandled async error.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(bundle.loads, hasLength(2));
  });
}
