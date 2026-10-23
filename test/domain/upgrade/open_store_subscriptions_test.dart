import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/upgrade/upgrade_launcher.dart';

/// An IAP-billed plan is managed in the store. On iOS that is Apple's sheet
/// over the app (in_app_purchase_storekit 0.4.14); the subscriptions page is
/// the fallback, never a dead end.
void main() {
  late List<Uri> launched;
  late int sheets;

  setUp(() {
    launched = [];
    sheets = 0;
  });

  Future<void> open(TargetPlatform platform, {required bool sheetShown}) =>
      openStoreSubscriptions(
        platform: platform,
        showAppleSheet: () async {
          sheets++;
          return sheetShown;
        },
        launch: (uri) async {
          launched.add(uri);
          return true;
        },
      );

  test('iOS shows Apple\'s sheet and opens nothing else', () async {
    await open(TargetPlatform.iOS, sheetShown: true);
    expect(sheets, 1);
    expect(launched, isEmpty);
  });

  test(
    'iOS falls back to the App Store page when the sheet is not shown',
    () async {
      await open(TargetPlatform.iOS, sheetShown: false);
      expect(sheets, 1);
      expect(launched, [
        Uri.parse('https://apps.apple.com/account/subscriptions'),
      ]);
    },
  );

  test(
    'Android opens Play\'s page and never asks for the Apple sheet',
    () async {
      await open(TargetPlatform.android, sheetShown: true);
      expect(sheets, 0);
      expect(launched, [
        Uri.parse('https://play.google.com/store/account/subscriptions'),
      ]);
    },
  );
}
