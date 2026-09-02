// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Records what the app asked the platform to launch, and answers `canLaunch`
/// with a flat **false**.
///
/// That false is the point, not laziness: `canLaunchUrl` is banned by
/// `test/lint/no_can_launch_url_test.dart` because on Android 11+ it answers a
/// package-visibility question and says no on plenty of devices where the
/// launch itself works — which is how Payment Links' View button came to
/// report "Couldn't open the link" for a URL that pasted into a browser fine
/// (invoiceninja/flutter#80). A fake that answered true would let a
/// reintroduced gate pass every test.
///
/// Shared by every test that asserts on a launch — `external_url_test`,
/// `phone_number_value_test`, `party_call_button_test`, and the list-tile call
/// button tests. Prefer [installFakeUrlLauncher], which restores the previous
/// platform instance for you.
class FakeUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  FakeUrlLauncher({this.results = const [true], this.throwOnLaunch = false});

  /// One entry per `launchUrl` call, in order. The last value repeats.
  final List<bool> results;
  final bool throwOnLaunch;

  /// Every launched URL, in order.
  final List<String> launched = <String>[];
  final List<PreferredLaunchMode?> modes = <PreferredLaunchMode?>[];
  int canLaunchCalls = 0;

  @override
  final LinkDelegate? linkDelegate = null;

  @override
  Future<bool> canLaunch(String url) async {
    canLaunchCalls++;
    // Android 11+ without matching manifest <queries>: always false.
    return false;
  }

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    modes.add(options.mode);
    if (throwOnLaunch) throw PlatformException(code: 'boom');
    return results[launched.length.clamp(1, results.length) - 1];
  }
}

/// Installs a [FakeUrlLauncher] as the platform instance and restores the
/// previous one via `addTearDown`, so a test that swaps it can't leak into the
/// next file in the same process.
FakeUrlLauncher installFakeUrlLauncher({
  List<bool> results = const [true],
  bool throwOnLaunch = false,
}) {
  final original = UrlLauncherPlatform.instance;
  final fake = FakeUrlLauncher(results: results, throwOnLaunch: throwOnLaunch);
  UrlLauncherPlatform.instance = fake;
  addTearDown(() => UrlLauncherPlatform.instance = original);
  return fake;
}
