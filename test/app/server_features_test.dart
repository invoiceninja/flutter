import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/version.dart';

void main() {
  group('compareSemver', () {
    test('orders by numeric segment, not lexically', () {
      expect(compareSemver('5.13.44', '5.13.43'), 1);
      expect(compareSemver('5.13.9', '5.13.10'), -1);
      expect(compareSemver('5.13.43', '5.13.43'), 0);
    });

    test('ignores a pre-release suffix and pads short versions', () {
      expect(compareSemver('5.13.44-beta', '5.13.44'), 0);
      expect(compareSemver('5.14', '5.13.99'), 1);
    });
  });

  group('ServerFeatures.supports', () {
    test('at or above the release that shipped it', () {
      expect(ServerFeatures.supports('5.13.44', '5.13.44'), isTrue);
      expect(ServerFeatures.supports('5.14.0', '5.13.44'), isTrue);
    });

    test('below it', () {
      expect(ServerFeatures.supports('5.13.43', '5.13.44'), isFalse);
    });

    test('an unknown server version is not assumed to support anything', () {
      expect(ServerFeatures.supports(null, '5.0.0'), isFalse);
      expect(ServerFeatures.supports('  ', '5.0.0'), isFalse);
    });

    test('hosted always has it — its version header lags', () {
      expect(
        ServerFeatures.supports('5.13.32', '5.13.44', isHosted: true),
        isTrue,
      );
      expect(ServerFeatures.supports(null, '5.13.44', isHosted: true), isTrue);
    });
  });
}
