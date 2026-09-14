import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/detail/copy_entity_link.dart';

import '../../features/shell/_shell_test_helpers.dart';

/// The one line that arms invoiceninja/flutter#144, and the branch that spends
/// it.
///
/// `baseUrl` is an *optional* parameter on `buildEntityDeepLink`, so dropping it
/// at this single call site compiles, analyzes clean, passes every other test —
/// and silently reverts Copy Link to the `invoiceninja://` form no messenger
/// will linkify, which is the whole bug. Nothing else in the suite sees that.
void main() {
  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
  const expected = 'https://example.com/app/clients/Wpmbk5ezJn?company=co1';

  /// Pumps the fixture and returns what each surface received.
  Future<({List<String> copied, List<Map<Object?, Object?>> shared})> run(
    WidgetTester tester, {
    String? shareResult,
    bool sharePluginPresent = true,
  }) async {
    final f = await buildFixture(
      companies: [FakeCompany(id: 'co1', name: 'Co', isOwner: true)],
    );
    addTearDown(f.dispose);

    final copied = <String>[];
    final shared = <Map<Object?, Object?>>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    messenger.setMockMethodCallHandler(shareChannel, (call) async {
      if (!sharePluginPresent) {
        // What a platform with no share implementation raises. (Leaving the
        // channel unmocked instead would hang: in flutter_test an unhandled
        // channel call never completes.)
        throw MissingPluginException(
          'No implementation found for ${call.method}',
        );
      }
      shared.add(call.arguments as Map<Object?, Object?>);
      return shareResult;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockMethodCallHandler(shareChannel, null);
    });

    late BuildContext context;
    await tester.pumpWidget(
      wrapWithShell(
        f.services,
        Builder(
          builder: (c) {
            context = c;
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );
    await tester.pump();

    await copyEntityLink(context, EntityType.client, 'Wpmbk5ezJn');
    await tester.pump();
    return (copied: copied, shared: shared);
  }

  testWidgets('desktop copies the https form, built on the session\'s own '
      'instance', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final r = await run(tester);
    // Reset inside the body: `addTearDown` runs after the binding's
    // "a foundation debug variable was changed" invariant check.
    debugDefaultTargetPlatformOverride = null;

    // `https://example.com` is the fixture's base URL; `/app/` is the segment
    // the OS claim and the server's bridge route both key off.
    expect(r.copied, [expected]);
    expect(
      r.shared,
      isEmpty,
      reason: 'a mouse has no share sheet worth having',
    );
  });

  testWidgets('touch hands the same link to the system share sheet instead — '
      'copy, leave the app, paste is three steps for what one tap does', (
    tester,
  ) async {
    // `flutter test` reports TargetPlatform.android, so this is the default
    // branch; pinned explicitly so a harness change can't silently flip it.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final r = await run(tester, shareResult: 'com.example.someapp');
    debugDefaultTargetPlatformOverride = null;

    expect(r.shared, hasLength(1));
    expect(r.shared.single['uri'], expected);
    // iPadOS anchors the popover on this; a null rect throws there.
    expect(r.shared.single['originX'], isNotNull);
    expect(r.copied, isEmpty, reason: 'a successful share must not also copy');
  });

  testWidgets('…and falls back to the clipboard when there is no share sheet '
      'at all', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    // No plugin on the other end of the channel, which is what a platform
    // without a share sheet looks like from here. Note a *returned*
    // `unavailable` is not this case: share_plus answers that when the sheet
    // was shown and the chosen app simply can't be identified.
    final r = await run(tester, sharePluginPresent: false);
    debugDefaultTargetPlatformOverride = null;

    expect(r.shared, isEmpty);
    expect(r.copied, [expected], reason: 'the user must still get the link');
  });
}
