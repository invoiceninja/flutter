import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/link.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/contact_api_model.dart';
import 'package:admin/domain/phone/phone_candidates.dart';
import 'package:admin/ui/core/widgets/party_call_button.dart';

import '../../../_localization_helper.dart';
import '../../../_responsive_helper.dart';
import '../../../_support/phone_actions_test_services.dart';
import '../../features/shell/_shell_test_helpers.dart';

/// Deliberately local rather than lifted into
/// `test/_support/phone_actions_test_services.dart` — that file's own doc
/// scopes it to *layout* tests and points behaviour here.
class _FakeLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  final List<String> launched = <String>[];

  @override
  final LinkDelegate? linkDelegate = null;

  @override
  Future<bool> canLaunch(String url) async => false;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

void main() {
  late PhoneActionsTestServices services;
  late _FakeLauncher launcher;
  late UrlLauncherPlatform originalLauncher;
  late List<String> copied;

  const jane = (
    label: 'Jane Smith',
    phone: '+1 415 555 2671',
    isPrimary: true,
    isPartyOwnLine: false,
  );
  const bob = (
    label: 'Bob Lee',
    phone: '+1 415 555 9004',
    isPrimary: false,
    isPartyOwnLine: false,
  );
  const office = (
    label: 'Acme Corporation',
    phone: '+1 800 555 0100',
    isPrimary: false,
    isPartyOwnLine: true,
  );

  setUp(() {
    // No timezone configured, so `_outsideHoursLine` resolves null and a
    // launch is never intercepted by the quiet-hours dialog. (The harness's
    // *default* zone is UTC+13:45, whose wall clock sits outside 08:00–20:00
    // for a large slice of the day — a launch assertion under it flakes.)
    services = PhoneActionsTestServices(timezone: null);
    originalLauncher = UrlLauncherPlatform.instance;
    launcher = _FakeLauncher();
    UrlLauncherPlatform.instance = launcher;

    copied = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
  });

  tearDown(() {
    UrlLauncherPlatform.instance = originalLauncher;
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pump(
    WidgetTester tester,
    List<PhoneCandidate> candidates, {
    VoidCallback? onViewParty,
  }) async {
    await tester.binding.setSurfaceSize(const Size(500, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      Provider<Services>.value(
        value: services,
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            body: Center(
              child: PhoneCallButton(
                candidates: candidates,
                partyName: 'Acme Corporation',
                clientId: 'c1',
                onViewParty: onViewParty,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder trigger() => find.byIcon(Icons.call_outlined);

  group('rendering', () {
    testWidgets('renders nothing when the party has no dialable number', (
      tester,
    ) async {
      await services.phoneActions.setTapToCall(true);
      await pump(tester, const []);

      expect(trigger(), findsNothing);
    });

    testWidgets('renders nothing when tap-to-call is off', (tester) async {
      await services.phoneActions.setTapToCall(false);
      await pump(tester, const [jane]);

      expect(trigger(), findsNothing);
    });

    // The regression `PhoneActionsScope` exists for: a detail screen stays
    // mounted behind `/settings/**` while the switch is flipped.
    testWidgets('flipping the preference adds and removes it in place', (
      tester,
    ) async {
      await services.phoneActions.setTapToCall(false);
      await pump(tester, const [jane]);
      expect(trigger(), findsNothing);

      await services.phoneActions.setTapToCall(true);
      await tester.pump();
      expect(trigger(), findsOneWidget);

      await services.phoneActions.setTapToCall(false);
      await tester.pump();
      expect(trigger(), findsNothing);
    });

    testWidgets('one number gets no caret, several do', (tester) async {
      await services.phoneActions.setTapToCall(true);

      await pump(tester, const [jane]);
      expect(find.byIcon(Icons.arrow_drop_down), findsNothing);

      await pump(tester, const [jane, bob]);
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
    });

    // `Semantics(excludeSemantics: true)` wrapped *around* the ink widget
    // prunes the InkWell's own node, leaving a button a screen reader
    // announces but cannot activate. This is the assertion that catches it.
    testWidgets('the semantics node is actually activatable', (tester) async {
      final handle = tester.ensureSemantics();
      await services.phoneActions.setTapToCall(true);
      await pump(tester, const [jane]);

      final node = tester.getSemantics(trigger());
      expect(node.label, contains('Jane Smith'));
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
        reason: 'a labelled node with no tap action is a dead button',
      );
      handle.dispose();
    });
  });

  group('a single number', () {
    testWidgets('tap dials it', (tester) async {
      await services.phoneActions.setTapToCall(true);
      await pump(tester, const [jane]);

      await tester.tap(trigger());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(launcher.launched, ['tel:+14155552671']);
    });

    testWidgets('long-press copies and does not dial', (tester) async {
      await services.phoneActions.setTapToCall(true);
      await pump(tester, const [jane]);

      await tester.longPress(trigger());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(copied, ['+1 415 555 2671']);
      expect(launcher.launched, isEmpty);
    });
  });

  group('several numbers', () {
    Future<void> openPicker(WidgetTester tester) async {
      await tester.tap(trigger());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('tap opens a picker naming the party and every candidate', (
      tester,
    ) async {
      await services.phoneActions.setTapToCall(true);
      await pump(tester, const [jane, bob, office]);
      await openPicker(tester);

      expect(find.text('Call Acme Corporation'), findsOneWidget);
      expect(find.text('Jane Smith'), findsOneWidget);
      expect(find.text('Bob Lee'), findsOneWidget);
      expect(find.text('+1 415 555 9004'), findsOneWidget);
      // The party's own line is distinguished from a contact.
      expect(find.byIcon(Icons.business_outlined), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsNWidgets(2));
      // The primary contact carries the same star the contacts card uses.
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('picking the second row dials that number', (tester) async {
      await services.phoneActions.setTapToCall(true);
      await pump(tester, const [jane, bob, office]);
      await openPicker(tester);

      await tester.tap(find.text('Bob Lee'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(launcher.launched, ['tel:+14155559004']);
    });

    testWidgets('a row copy button copies without dialling', (tester) async {
      await services.phoneActions.setTapToCall(true);
      await pump(tester, const [jane, bob]);
      await openPicker(tester);

      await tester.tap(find.byIcon(Icons.content_copy).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(copied, ['+1 415 555 2671']);
      expect(launcher.launched, isEmpty);
    });

    testWidgets('the footer offers a way to the party screen', (tester) async {
      var viewed = false;
      await services.phoneActions.setTapToCall(true);
      await pump(tester, const [jane, bob], onViewParty: () => viewed = true);
      await openPicker(tester);

      await tester.tap(find.text('View Client'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(viewed, isTrue);
      expect(launcher.launched, isEmpty);
    });

    // The race the value-returning picker exists to prevent: `callPhoneNumber`
    // re-checks `context.mounted` only *after* awaiting the timezone cascade,
    // so dialling from the picker's own (mid-pop) context silently drops both
    // the confirm dialog and the call.
    testWidgets('the confirm dialog still runs after the picker closes', (
      tester,
    ) async {
      await services.phoneActions.setTapToCall(true);
      await services.phoneActions.setConfirmBeforeCall(true);
      await pump(tester, const [jane, bob]);
      await openPicker(tester);

      await tester.tap(find.text('Jane Smith'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Jane Smith'), findsOneWidget);
      expect(launcher.launched, isEmpty);

      await tester.tap(find.text('Call').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(launcher.launched, ['tel:+14155552671']);
    });
  });

  group('with a pointer', () {
    testWidgets('the picker is a dialog, not a bottom sheet', (tester) async {
      // Reset inside the body, not in `tearDown`: the binding verifies the
      // foundation debug vars at the end of `_runTestBody`, before teardown.
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await services.phoneActions.setTapToCall(true);
        await pump(tester, const [jane, bob]);

        await tester.tap(trigger());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // A bottom sheet would be confined to the master-detail pane's nested
        // navigator on a wide layout; a dialog uses the root navigator.
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
        // The pointer build gets a tooltip instead of the long-press copy.
        expect(find.byType(Tooltip), findsWidgets);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('PartyCallButton', () {
    testWidgets('resolves a client from Drift and offers its contacts', (
      tester,
    ) async {
      final fixture = await buildFixture(
        companies: [const FakeCompany(id: 'co1', name: 'Co')],
      );
      addTearDown(fixture.dispose);
      await fixture.services.phoneActions.setTapToCall(true);
      await fixture.services.clients.applyUpdateResponse(
        companyId: 'co1',
        serverResponse: const ClientApi(
          id: 'cl1',
          displayName: 'Acme Corporation',
          contacts: [
            ContactApi(
              id: 'ct1',
              firstName: 'Jane',
              lastName: 'Smith',
              phone: '+1 415 555 2671',
              isPrimary: true,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        wrapWithShell(
          fixture.services,
          const Scaffold(body: PartyCallButton(clientId: 'cl1')),
        ),
      );
      // The client watch emits asynchronously; bounded pumps, not
      // `pumpAndSettle` — the fixture's Services keep timers pending.
      for (var i = 0; i < 10 && trigger().evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(trigger(), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down), findsNothing);

      // Dispose the subtree inside the test body so the Drift watch's
      // stream-close timer runs before the binding is torn down.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 20));
    });

    testWidgets('renders nothing for a document with no party', (tester) async {
      final fixture = await buildFixture(
        companies: [const FakeCompany(id: 'co1', name: 'Co')],
      );
      addTearDown(fixture.dispose);
      await fixture.services.phoneActions.setTapToCall(true);

      await tester.pumpWidget(
        wrapWithShell(
          fixture.services,
          const Scaffold(body: PartyCallButton(clientId: '')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 20));

      expect(trigger(), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 20));
    });
  });

  /// The sizing decision the whole widget turns on: the trigger's box is
  /// [actionButtonSize()] **wide** and only as tall as the name row's line
  /// box, so it never drives the `Row`'s cross axis. A 44 px-tall box would
  /// push the dates + KPI strip down ~24 px on every billing-doc header — and,
  /// because the party resolves asynchronously, do it a frame or two *late* on
  /// a cold deep link. CLAUDE.md's touch-target trap 4 is the licence for it.
  ///
  /// The name is a plain `Text` stand-in rather than `ClientNameLabel`: the
  /// label resolves through a repository this harness deliberately doesn't
  /// carry, and it renders exactly this `Text` (via `LinkText`, which adds no
  /// size of its own) with exactly this style, so the measurement is the same.
  group('layout', () {
    const longName = 'Constantinopolitan Ironmongery & Sons Incorporated GmbH';

    Widget nameRow({required bool withButton}) => Builder(
      builder: (context) => Row(
        children: [
          Flexible(
            child: Text(
              longName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.inTheme.ink3),
            ),
          ),
          if (withButton)
            const PhoneCallButton(
              candidates: [jane, bob],
              partyName: 'Acme Corporation',
              clientId: 'c1',
            ),
        ],
      ),
    );

    for (final scale in [1.0, kTextScaleMax]) {
      testWidgets('adds no height to the name row at ${scale}x text', (
        tester,
      ) async {
        await pumpAt(
          tester,
          320,
          nameRow(withButton: false),
          textScale: scale,
          phoneActions: true,
        );
        expectNoOverflow(tester);
        final baseline = tester.getSize(find.byType(Row).first).height;

        await pumpAt(
          tester,
          320,
          nameRow(withButton: true),
          textScale: scale,
          phoneActions: true,
        );
        expectNoOverflow(tester);
        expect(find.byIcon(Icons.call_outlined), findsOneWidget);
        expect(
          tester.getSize(find.byType(Row).first).height,
          baseline,
          reason: 'the call button must not grow the header row — see trap 4',
        );
      });
    }

    testWidgets('the picker survives a narrow phone at max text scale', (
      tester,
    ) async {
      await pumpAt(
        tester,
        320,
        nameRow(withButton: true),
        textScale: kTextScaleMax,
        phoneActions: true,
      );
      await tester.tap(find.byIcon(Icons.call_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Jane Smith'), findsOneWidget);
      expectNoOverflow(tester);
    });
  });
}
