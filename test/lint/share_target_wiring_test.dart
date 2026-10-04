import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/app_deep_links.dart';
import 'package:admin/app/app_share_intake.dart';
import 'package:admin/data/services/shared_intake_files.dart';

/// Sharing files into the app (invoiceninja/flutter#173) — and, on Android,
/// deep links, which take the same engine-free route — is split across five
/// languages' worth of files that agree on three strings by convention only:
///
///   * the App Group the iOS Share Extension hands files to the Runner
///     through — named in both entitlements files and both Swift files. A
///     mismatch builds, installs, and then the extension writes into a
///     container the app never reads (or isn't entitled to);
///   * the folder the native sides copy into, which Dart sweeps and purges. A
///     mismatch means shared receipts are never cleaned up — nor removed on
///     sign-out;
///   * the method channel both native sides answer on. A mismatch is a
///     `MissingPluginException` the bridge swallows by design, so nothing
///     arrives and nothing says why.
///
/// None of it is reachable from a Dart test any other way.
void main() {
  String read(String path) => File(path).readAsStringSync();

  const kotlinShare =
      'android/app/src/main/kotlin/com/invoiceninja/admin/ShareReceiverActivity.kt';
  const kotlinMain =
      'android/app/src/main/kotlin/com/invoiceninja/admin/MainActivity.kt';
  const kotlinLink =
      'android/app/src/main/kotlin/com/invoiceninja/admin/DeepLinkReceiverActivity.kt';
  const kotlinHandoff =
      'android/app/src/main/kotlin/com/invoiceninja/admin/Handoff.kt';
  const swiftExtension = 'ios/ShareExtension/ShareViewController.swift';
  const swiftRunner = 'ios/Runner/AppDelegate.swift';

  String appGroupIn(String path) {
    final m = RegExp(r'static let appGroup = "([^"]+)"').firstMatch(read(path));
    expect(m, isNotNull, reason: '$path should declare `static let appGroup`');
    return m!.group(1)!;
  }

  test('one App Group, in both Swift files and both entitlements', () {
    final group = appGroupIn(swiftExtension);
    expect(appGroupIn(swiftRunner), group);
    for (final entitlements in [
      'ios/Runner/Runner.entitlements',
      'ios/ShareExtension/ShareExtension.entitlements',
    ]) {
      final xml = read(entitlements).replaceAll(RegExp(r'\s+'), ' ');
      expect(
        xml,
        contains(
          '<key>com.apple.security.application-groups</key> <array> '
          '<string>$group</string>',
        ),
        reason: '$entitlements must claim $group',
      );
    }
  });

  test('the native sides copy into the folder Dart sweeps', () {
    const folder = SharedIntakeFiles.kFolderName;
    expect(read(kotlinShare), contains('INTAKE_FOLDER = "$folder"'));
    expect(read(swiftRunner), contains('intakeFolder = "$folder"'));
    // Under filesDir — what path_provider's application-support directory is.
    // cacheDir would pass the name check, leave Dart sweeping the wrong root,
    // and let the OS evict files an outbox row still needs.
    expect(read(kotlinShare), contains('File(filesDir, INTAKE_FOLDER)'));
    expect(read(kotlinMain), contains('File(filesDir, INTAKE_FOLDER)'));
  });

  // The forwarded intent becomes the base intent of the app's task, and a
  // launcher tap is matched against it with Intent.filterEquals (action and
  // categories count, extras don't). Any other shape, with a picker above
  // MainActivity, makes Android start a SECOND MainActivity — a second engine
  // on the store (ActivityStarter.complyActivityFlags, `!isSameIntentFilter`).
  test('both trampolines forward the one launcher-shaped intent', () {
    final handoff = read(kotlinHandoff);
    expect(handoff, contains('Intent(Intent.ACTION_MAIN)'));
    expect(handoff, contains('.addCategory(Intent.CATEGORY_LAUNCHER)'));
    for (final flag in [
      'FLAG_ACTIVITY_NEW_TASK',
      'FLAG_ACTIVITY_CLEAR_TOP',
      'FLAG_ACTIVITY_SINGLE_TOP',
    ]) {
      expect(handoff, contains('Intent.$flag'), reason: flag);
    }
    for (final path in [kotlinShare, kotlinLink]) {
      final source = read(path);
      expect(source, contains('Handoff.launchIntent(this, '), reason: path);
      expect(source, isNot(contains('Intent(Intent.')), reason: path);
      expect(source, isNot(contains('.action = ')), reason: path);
    }
  });

  // MainActivity is exported: a payload read from its intent could be forged
  // to name the app's own private files, and FlutterFragmentActivity reads its
  // launch configuration (initial route, engine flags) from the extras. Only a
  // token, read defensively, and then every extra goes.
  test('MainActivity reads only the handoff token, then strips every extra '
      'before Flutter sees the intent', () {
    final main = read(kotlinMain);
    final extras = RegExp(r'getStringExtra\(([^)]*)\)').allMatches(main);
    expect(extras, hasLength(1));
    expect(extras.single.group(1), 'Handoff.EXTRA_TOKEN');
    expect(
      main,
      contains('runCatching { intent.getStringExtra(Handoff.EXTRA_TOKEN) }'),
      reason: 'before API 33 the read unparcels the whole bundle and can throw',
    );
    expect(main, contains('intent.replaceExtras(null as Bundle?)'));
    expect(main, isNot(contains('getParcelable')));

    String body(String signature) {
      final start = main.indexOf(signature);
      expect(start, greaterThanOrEqualTo(0), reason: signature);
      return main.substring(start, main.indexOf('\n  }', start));
    }

    for (final (signature, superCall) in [
      ('override fun onCreate(', 'super.onCreate('),
      ('override fun onNewIntent(', 'super.onNewIntent('),
    ]) {
      final b = body(signature);
      expect(
        b.indexOf('sanitize(intent)'),
        allOf(greaterThanOrEqualTo(0), lessThan(b.indexOf(superCall))),
        reason: '$signature must strip the extras before $superCall',
      );
    }
  });

  // A power-button lock stops the trampoline without finishing it, and a
  // stopped activity's startActivity is refused (background activity starts):
  // the share would be lost.
  test('ShareReceiverActivity hands a copy on only while resumed', () {
    final share = read(kotlinShare);
    expect(share, contains('override fun onResume()'));
    expect(share, contains('override fun onPause()'));
    expect(share, contains('if (!resumed) {'));
  });

  test('both native sides answer the channel the bridge calls', () {
    final name = AppShareIntake.kChannel.name;
    expect(read(kotlinMain), contains('SHARE_CHANNEL = "$name"'));
    expect(read(swiftRunner), contains('name: "$name"'));
    for (final path in [kotlinMain, swiftRunner]) {
      expect(read(path), contains('"takeShares"'), reason: path);
    }
    expect(read(kotlinMain), contains('"sharesAvailable"'));
  });

  test('MainActivity answers the deep-link channel AppDeepLinks pulls', () {
    final main = read(kotlinMain);
    expect(main, contains('LINK_CHANNEL = "${AppDeepLinks.kChannel.name}"'));
    expect(main, contains('"takeLinks"'));
    expect(main, contains('"linksAvailable"'));
  });

  test('the Runner embeds the Share Extension, ahead of Flutter\'s Thin '
      'Binary phase', () {
    final pbx = read('ios/Runner.xcodeproj/project.pbxproj');
    expect(pbx, contains('com.invoiceninja.admin.ShareExtension'));
    // Embedding after "Thin Binary" is what Xcode reports as a dependency
    // cycle inside Runner.
    final runnerPhases = RegExp(
      r'97C146ED1CF9000F007C117D /\* Runner \*/ = \{.*?buildPhases = \((.*?)\);',
      dotAll: true,
    ).firstMatch(pbx)?.group(1);
    expect(runnerPhases, isNotNull, reason: 'Runner target not found');
    final embed = runnerPhases!.indexOf('Embed Foundation Extensions');
    final thin = runnerPhases.indexOf('Thin Binary');
    expect(embed, greaterThanOrEqualTo(0));
    expect(embed, lessThan(thin));
  });
}
