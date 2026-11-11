import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/detail/portal_link_action.dart';

import '../../../_localization_helper.dart';

/// The portal link is the one a customer can open, and it is named apart from
/// the Internal Link everywhere. A beta user sent a customer the Internal Link from an
/// invoice's menu because the menu had only one "Share Link".
void main() {
  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

  Future<({List<String> copied, List<Map<Object?, Object?>> shared})> run(
    WidgetTester tester,
    List<PortalLinkTarget> targets, {
    bool vendor = false,
    Future<void> Function()? whileOpen,
  }) async {
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
      shared.add(call.arguments as Map<Object?, Object?>);
      return 'com.example.someapp';
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockMethodCallHandler(shareChannel, null);
    });

    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        home: Builder(
          builder: (c) {
            context = c;
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );
    await tester.pump();

    final done = sharePortalLink(context, vendor: vendor, targets: targets);
    await tester.pumpAndSettle();
    if (whileOpen != null) {
      await whileOpen();
      await tester.pumpAndSettle();
    }
    await done;
    // Let a "copied" toast run out its clock before the tree goes.
    await tester.pump(const Duration(seconds: 10));
    return (copied: copied, shared: shared);
  }

  testWidgets('a pointer copies the one link', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final r = await run(tester, const [
      PortalLinkTarget(link: 'https://portal.example.com/i/k1'),
    ]);
    debugDefaultTargetPlatformOverride = null;

    expect(r.copied, ['https://portal.example.com/i/k1']);
    expect(r.shared, isEmpty);
  });

  testWidgets('touch hands the link to the share sheet', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final r = await run(tester, const [
      PortalLinkTarget(link: 'https://portal.example.com/i/k1'),
    ]);
    debugDefaultTargetPlatformOverride = null;

    expect(r.shared.single['uri'], 'https://portal.example.com/i/k1');
    expect(r.copied, isEmpty);
  });

  testWidgets('several contacts: the user picks whose link goes out, and a '
      'contact with no link is not offered', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final r = await run(
      tester,
      const [
        PortalLinkTarget(
          link: 'https://portal.example.com/i/k1',
          name: 'Ada Lovelace',
          email: 'ada@example.com',
        ),
        PortalLinkTarget(link: '', name: 'No Link'),
        PortalLinkTarget(
          link: 'https://portal.example.com/i/k2',
          email: 'grace@example.com',
        ),
      ],
      vendor: true,
      whileOpen: () async {
        expect(find.text('Vendor Portal Link'), findsOneWidget);
        expect(find.text('Ada Lovelace'), findsOneWidget);
        expect(find.text('No Link'), findsNothing);
        await tester.tap(find.text('grace@example.com'));
      },
    );
    debugDefaultTargetPlatformOverride = null;

    expect(r.copied, ['https://portal.example.com/i/k2']);
  });

  testWidgets('the menu item is named for the portal, follows the input '
      'device, and does not exist with nothing to share', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    String? label({required bool vendor, bool hasLink = true}) =>
        portalLinkActionItem<int>(
          context: context,
          kind: 0,
          vendor: vendor,
          hasLink: hasLink,
          onTap: () {},
        )?.label;

    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final pointer = label(vendor: false);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final touch = label(vendor: false);
    final touchVendor = label(vendor: true);
    final none = label(vendor: false, hasLink: false);
    debugDefaultTargetPlatformOverride = null;

    expect(pointer, 'Copy Client Portal Link');
    expect(touch, 'Share Client Portal Link');
    expect(touchVendor, 'Share Vendor Portal Link');
    expect(none, isNull);
  });
}
