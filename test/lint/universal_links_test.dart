import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/entity_links.dart';
import 'package:admin/app/env.dart';

/// Guards the platform half of shared https links (invoiceninja/flutter#144).
///
/// Every assertion here fails silently in every way that matters: the build
/// succeeds, `flutter analyze` is clean, every widget test passes, and the app
/// only misbehaves on a real device — or, worse, only on a device that happens
/// to have tapped a link from a messenger. None of it is reachable from Dart.
///
/// What can go wrong, in the order the file checks it:
///   * the claimed host drifting from the origin the app actually ships with;
///   * the `<intent-filter>` losing `autoVerify`, its `pathPrefix` (which is
///     what keeps the claim off the client portal), or having its `<data>`
///     attributes split across elements — Android matches the CROSS-PRODUCT of
///     `<data>` attributes in a filter, so `scheme` in one and `host` in another
///     claims `https://<anything>` and `invoiceninja://invoicing.co`;
///   * `autoVerify` migrating onto the custom-scheme filter, which before
///     Android 12 made one failing host fail verification for every host;
///   * `flutter_deeplinking_enabled` landing on `<application>` instead of the
///     activity, where `shouldHandleDeeplinking()` never reads it — so the app
///     ships believing Flutter's built-in handling is off while it is still
///     racing `DeepLinkRouter` and, for an https link, replacing the whole app
///     with go_router's route-error screen;
///   * a VIEW filter moving back onto MainActivity, where a link can start a
///     second MainActivity — a second Flutter engine on the store;
///   * either Swift shim being deleted, each of which is one line away from
///     killing iOS cold-start links or macOS universal links outright.
void main() {
  // Plain reads, not `expect`-guarded ones: some of these run at group scope to
  // build the regex matches, and `expect` outside a test body throws. A missing
  // file fails loudly enough on its own.
  String read(String path) => File(path).readAsStringSync();

  /// Whitespace-normalised, so the assertions survive reformatting.
  String flat(String path) => read(path).replaceAll(RegExp(r'\s+'), ' ');

  test('the claimed host is the hosted origin the app ships with', () {
    expect(
      Uri.parse(Env.hostedApiUrl).host,
      kHostedAppLinkHost,
      reason:
          'kHostedAppLinkHost is what the manifest and both entitlements claim. '
          'If the hosted API origin ever moves, the claim has to move with it '
          'or hosted links silently stop opening the app.',
    );
  });

  group('AndroidManifest', () {
    final xml = flat('android/app/src/main/AndroidManifest.xml');
    final filters = RegExp(
      r'<intent-filter.*?</intent-filter>',
    ).allMatches(xml).map((m) => m.group(0)!).toList();

    test('declares one autoVerify https filter for the hosted host', () {
      final verified = filters
          .where((f) => f.contains('android:autoVerify="true"'))
          .toList();
      expect(
        verified,
        hasLength(1),
        reason: 'exactly one filter should claim https links',
      );

      // One <data> element carrying all three: split across elements, Android
      // matches their cross-product instead.
      final data = RegExp(
        r'<data [^>]*/>',
      ).allMatches(verified.single).map((m) => m.group(0)!).toList();
      expect(data, hasLength(1), reason: 'one <data>, or the claim widens');
      expect(data.single, contains('android:scheme="https"'));
      expect(data.single, contains('android:host="$kHostedAppLinkHost"'));
      expect(
        data.single,
        contains('android:pathPrefix="$kAppLinkPathPrefix/"'),
        reason:
            '$kHostedAppLinkHost also serves the client portal and payment '
            'pages; without the path prefix this app claims all of them',
      );
      expect(verified.single, contains('android.intent.action.VIEW'));
      expect(verified.single, contains('android.intent.category.BROWSABLE'));
    });

    test('the custom-scheme filter keeps its hosts and stays unverified', () {
      final scheme = filters
          .where((f) => f.contains('android:scheme="$kAppLinkScheme"'))
          .toList();
      expect(scheme, hasLength(1));
      expect(scheme.single, contains('android:host="$kAppLinkHost"'));
      expect(scheme.single, contains('android:host="$kCalendarLinkHost"'));
      expect(
        scheme.single.contains('autoVerify'),
        isFalse,
        reason:
            'before Android 12 a single failing autoVerify host failed '
            'verification for every host in the app',
      );
    });

    /// The `<activity …>…</activity>` block named [name], matched by name
    /// rather than position: the share target sits beside MainActivity.
    String? activityNamed(String name) => RegExp(r'<activity .*?</activity>')
        .allMatches(xml)
        .map((m) => m.group(0)!)
        .where((a) {
          return a.contains('android:name="$name"');
        })
        .firstOrNull;

    test('flutter_deeplinking_enabled is false INSIDE the <activity>', () {
      final activity = activityNamed('.MainActivity');
      expect(
        activity,
        isNotNull,
        reason: 'the manifest should declare MainActivity',
      );
      final meta = RegExp(
        r'<meta-data android:name="flutter_deeplinking_enabled"[^>]*/>',
      ).firstMatch(activity!)?.group(0);
      expect(
        meta,
        isNotNull,
        reason:
            'an <application>-level entry is silently ignored — '
            'shouldHandleDeeplinking() reads ActivityInfo meta-data',
      );
      expect(meta, contains('android:value="false"'));
    });

    // A VIEW intent delivered to MainActivity can start a second one: in the
    // sender's task when it lacks NEW_TASK, and on the next launcher tap with
    // a picker on top otherwise (the link became the task's base intent).
    // Only the engine-free trampoline may receive links.
    test('only DeepLinkReceiverActivity receives deep links', () {
      const view = 'android.intent.action.VIEW"';
      final main = activityNamed('.MainActivity')!;
      expect(main, isNot(contains(view)));

      final link = activityNamed('.DeepLinkReceiverActivity');
      expect(link, isNotNull, reason: 'the link target must be declared');
      final linkFilters = filters.where(link!.contains).toList();
      expect(linkFilters, hasLength(2), reason: 'custom scheme + App Links');
      expect(linkFilters.every((f) => f.contains(view)), isTrue);
      expect(link, contains('android:exported="true"'));
      expect(link, contains('android:noHistory="true"'));
      expect(link, contains('android:excludeFromRecents="true"'));
      expect(link, contains('android:taskAffinity=""'));
      expect(link, isNot(contains('flutter_deeplinking_enabled')));
    });

    // invoiceninja/flutter#173. The share sheet starts its target in the
    // SENDER's task, so a SEND filter on singleTop MainActivity would start a
    // second instance — a second Flutter engine opening the store twice. Only
    // the engine-free trampoline may receive shares.
    test('only ShareReceiverActivity receives shares', () {
      const send = 'android.intent.action.SEND"';
      const sendMultiple = 'android.intent.action.SEND_MULTIPLE"';
      final main = activityNamed('.MainActivity')!;
      expect(main, isNot(contains(send)));
      expect(main, isNot(contains(sendMultiple)));

      final share = activityNamed('.ShareReceiverActivity');
      expect(share, isNotNull, reason: 'the share target must be declared');
      expect(share, contains(send));
      expect(share, contains(sendMultiple));
      expect(share, contains('android:mimeType="image/*"'));
      expect(share, contains('android:mimeType="application/pdf"'));
      // A share must not leave a Recents entry that replays it.
      expect(share, contains('android:noHistory="true"'));
      expect(share, contains('android:excludeFromRecents="true"'));
      // A recreation mid-copy (rotation, dark mode) would lose the share.
      expect(share, contains('android:configChanges="orientation|screenSize'));
      // What the launcher-shaped forward relies on to reach the live instance.
      expect(main, contains('android:launchMode="singleTop"'));
    });
  });

  group('Apple', () {
    test('iOS turns Flutter\'s built-in deep linking off', () {
      final plist = flat('ios/Runner/Info.plist');
      expect(
        plist,
        contains('<key>FlutterDeepLinkingEnabled</key> <false/>'),
        reason:
            'left unset it defaults to YES, and the raw URI then reaches '
            'go_router beside DeepLinkRouter',
      );
    });

    test('the entitlement claims the host on iOS and macOS Release', () {
      for (final path in const [
        'ios/Runner/Runner.entitlements',
        'macos/Runner/Release.entitlements',
      ]) {
        expect(
          flat(path),
          contains('<string>applinks:$kHostedAppLinkHost</string>'),
          reason: '$path should claim the hosted host',
        );
      }
    });

    test('macOS DebugProfile deliberately does NOT claim it', () {
      expect(
        flat('macos/Runner/DebugProfile.entitlements'),
        isNot(contains('applinks:')),
        reason:
            'Debug/Profile sign with Apple Development provisioning that has no '
            'Associated Domains capability, so adding it breaks '
            '`flutter run -d macos` for everyone — the same asymmetry that file '
            'already documents for applesignin. Nothing is lost: a universal '
            'link needs the AASA served from the claimed host anyway.',
      );
    });

    test('both app_links shims are still there', () {
      final ios = read('ios/Runner/SceneDelegate.swift');
      expect(
        ios,
        contains('AppLinks.shared.handleLink'),
        reason:
            'without it a link tapped with the app not running does NOTHING on '
            'iOS: UIKit delivers the launch URL only in connectionOptions, and '
            'app_links implements no didFinishLaunchingWithOptions',
      );
      expect(ios, contains('willConnectTo'));

      final macos = read('macos/Runner/AppDelegate.swift');
      expect(
        macos,
        contains('AppLinks.shared.handleLink'),
        reason:
            'app_links ships its macOS universal-link handler commented out, '
            'and the macOS embedder has no built-in deep linking to fall back '
            'on — so the entitlement without this shim takes the click away '
            'from the browser and then does nothing',
      );
      expect(macos, contains('NSUserActivityTypeBrowsingWeb'));
    });
  });
}
