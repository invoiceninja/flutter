// The review prompt's automatic opener (docs/review-prompt.md). It reads
// `auth`, `sync` and the unsaved-changes guard, so it takes a light fake
// rather than the shell fixture, whose live Drift watch streams never settle.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/review_prompt_controller.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/sync_repository.dart';
import 'package:admin/domain/review_prompt.dart';
import 'package:admin/domain/sync/entity_type.dart';
import 'package:admin/domain/sync/landed_mutation.dart';
import 'package:admin/domain/sync/sync_event.dart';
import 'package:admin/ui/core/dialogs/automatic_dialogs.dart';
import 'package:admin/ui/core/unsaved_changes/unsaved_changes_guard.dart';
import 'package:admin/ui/features/review_prompt/review_prompt_host.dart';

import '../../../_localization_helper.dart';

class _FakeAuth implements AuthRepository {
  _FakeAuth(this._session);
  final ValueNotifier<AuthSession?> _session;
  final ValueNotifier<bool> locked = ValueNotifier(false);
  @override
  ValueListenable<AuthSession?> get session => _session;
  @override
  ValueListenable<bool> get requiresBiometricUnlock => locked;
  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeSync implements SyncRepository {
  final StreamController<LandedMutation> landedController =
      StreamController.broadcast();
  final StreamController<SyncEvent> eventsController =
      StreamController.broadcast();
  @override
  Stream<LandedMutation> get landed => landedController.stream;
  @override
  Stream<SyncEvent> get events => eventsController.stream;
  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeServices implements Services {
  _FakeServices(AuthSession? session)
    : auth = _FakeAuth(ValueNotifier(session));
  @override
  final _FakeAuth auth;
  @override
  final _FakeSync sync = _FakeSync();
  @override
  final UnsavedChangesGuard unsavedChangesGuard = UnsavedChangesGuard();
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

AuthSession _session() => AuthSession(
  baseUrl: 'https://invoicing.co',
  isHosted: true,
  accountId: 'acct',
  companies: [
    AuthCompany(
      id: 'co',
      name: 'Co',
      displayName: 'Co',
      permissions: '',
      isAdmin: true,
      isOwner: true,
      enabledModules: 0x7fffffff,
    ),
  ],
  currentCompanyId: 'co',
  userEmail: 'me@example.com',
);

const _question = 'Are you enjoying the app?';

void main() {
  tearDown(AutomaticDialogs.resetForTest);

  late DateTime now;
  late ReviewPromptController controller;
  late _FakeServices services;
  late int pending;
  late int attention;
  late bool online;
  late int prepares;
  late int requests;
  late bool requestSucceeds;

  setUp(() {
    now = DateTime.utc(2026, 11, 2, 12);
    pending = 0;
    attention = 0;
    online = true;
    prepares = 0;
    requests = 0;
    requestSucceeds = true;
  });

  LandedMutation emailed() => LandedMutation(
    entityType: 'invoice',
    mutationKind: 'email_entity',
    rowCreatedAt: now,
  );

  /// Every gate met but the moment — as `review_prompt_controller_test`
  /// builds it.
  Future<void> establish() async {
    for (var i = 0; i < 5; i++) {
      await controller.recordUseDay(Date(now.year, now.month, now.day));
      if (i < 3) {
        await controller.noteWin(
          LandedMutation(
            entityType: 'invoice',
            mutationKind: 'create',
            rowCreatedAt: now,
          ),
        );
      }
      now = now.add(const Duration(days: 1));
    }
    now = now.add(const Duration(days: 3));
  }

  Future<void> pump(
    WidgetTester tester, {
    ReviewChannel channel = ReviewChannel.capterra,
    bool isBeta = false,
    bool autoAsk = true,
    bool established = true,
  }) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    controller = ReviewPromptController(
      prefs: DevicePrefsStore(null),
      autoAsk: autoAsk,
      channel: channel,
      isBeta: isBeta,
      version: '5.2.0',
      clock: () => now,
    );
    addTearDown(controller.dispose);
    if (established) await establish();
    services = _FakeServices(_session());
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Provider<Services>.value(
          value: services,
          child: ChangeNotifierProvider.value(
            value: controller,
            child: ReviewPromptHost(
              prepareNativeReview: () async {
                prepares++;
                return true;
              },
              requestNativeReview: () async {
                requests++;
                return requestSucceeds;
              },
              outboxCounts: (_) async =>
                  (pending: pending, attention: attention),
              isOnline: () async => online,
              child: const Scaffold(body: Center(child: Text('home'))),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// A win lands, then enough time for the settle, two empty-outbox checks
  /// and the card's arm delay.
  Future<void> land(WidgetTester tester, [LandedMutation? m]) async {
    services.sync.landedController.add(m ?? emailed());
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 3));
    }
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('a finishing win opens the card on a non-store build', (
    tester,
  ) async {
    await pump(tester);
    await land(tester);
    expect(find.text(_question), findsOneWidget);
    expect(controller.state.cardShows, 1, reason: 'recorded as it opens');
    expect(AutomaticDialogs.shownThisLaunch, isTrue);
    expect(controller.askedThisLaunch, isTrue);
    expect(prepares, 0, reason: 'the card needs no store warm-up');
  });

  testWidgets('a store build asks the OS sheet and shows nothing of its '
      'own', (tester) async {
    await pump(tester, channel: ReviewChannel.playStore);
    await land(tester);
    expect(find.text(_question), findsNothing);
    expect(prepares, 1, reason: 'warmed when the win armed');
    expect(requests, 1);
    expect(controller.state.asks, hasLength(1));
  });

  testWidgets('an OS sheet that could not be asked records no ask', (
    tester,
  ) async {
    requestSucceeds = false;
    await pump(tester, channel: ReviewChannel.appleStore);
    await land(tester);
    expect(requests, 1);
    expect(controller.state.asks, isEmpty);
  });

  testWidgets('nothing during the beta', (tester) async {
    await pump(tester, isBeta: true);
    await land(tester);
    expect(find.text(_question), findsNothing);
    expect(controller.state.wins, 4, reason: 'but the win still counts');
  });

  testWidgets('inert with autoAsk off — every other harness', (tester) async {
    await pump(tester, autoAsk: false);
    await land(tester);
    expect(find.text(_question), findsNothing);
    expect(controller.state.wins, 3, reason: 'not even counted');
  });

  testWidgets('stands down when another automatic dialog showed this '
      'launch', (tester) async {
    AutomaticDialogs.noteShown();
    await pump(tester);
    await land(tester);
    expect(find.text(_question), findsNothing);
  });

  testWidgets('waits while the app is locked, then asks', (tester) async {
    await pump(tester);
    services.auth.locked.value = true;
    await land(tester);
    expect(find.text(_question), findsNothing);
    services.auth.locked.value = false;
    // Two settled outbox checks after the unlock.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(_question), findsOneWidget);
  });

  testWidgets('waits for a draining outbox, then asks', (tester) async {
    pending = 3;
    await pump(tester);
    await land(tester);
    expect(find.text(_question), findsNothing);
    pending = 0;
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(_question), findsOneWidget);
  });

  testWidgets('never while the outbox needs attention, or offline', (
    tester,
  ) async {
    attention = 1;
    await pump(tester);
    await land(tester);
    expect(find.text(_question), findsNothing);
    attention = 0;
    online = false;
    await land(tester);
    expect(find.text(_question), findsNothing);
    online = true;
    await land(tester);
    expect(find.text(_question), findsOneWidget);
  });

  testWidgets('a failure the user was not shown holds it off', (tester) async {
    await pump(tester);
    services.sync.eventsController.add(
      const DeadEvent(
        entityType: EntityType.invoice,
        entityId: 'x',
        message: 'boom',
        statusCode: 500,
      ),
    );
    await tester.pump();
    await land(tester);
    expect(find.text(_question), findsNothing);
    expect(controller.state.lastProblemAt, isNotNull);
  });

  testWidgets('a failure shown in its own form does not', (tester) async {
    await pump(tester);
    services.sync.eventsController.add(
      const DeadEvent(
        entityType: EntityType.invoice,
        entityId: 'x',
        message: 'boom',
        statusCode: 500,
        handledByCaller: true,
      ),
    );
    await tester.pump();
    await land(tester);
    expect(find.text(_question), findsOneWidget);
  });

  testWidgets('closing after Not really waits 180 days, not 30', (
    tester,
  ) async {
    await pump(tester);
    await land(tester);
    await tester.tap(find.text('Not really'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text(_question), findsNothing);
    expect(controller.state.nextAt, now.add(const Duration(days: 180)));
    expect(controller.state.newerThan, '5.2.0');
  });

  testWidgets('Send feedback opens Contact Us after the card has closed', (
    tester,
  ) async {
    await pump(tester);
    await land(tester);
    await tester.tap(find.text('Not really'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Send feedback'));
    await tester.pumpAndSettle();
    expect(find.text(_question), findsNothing);
    expect(find.text('Contact Us'), findsOneWidget);
    expect(
      find.text('Sorry to hear that. What could we do better?'),
      findsOneWidget,
      reason: 'the intro carries the conversation over',
    );
  });

  testWidgets('a day of use is counted on every resume', (tester) async {
    await pump(tester, established: false);
    await tester.pump();
    expect(controller.state.daysSeen, 1);
    now = now.add(const Duration(days: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(controller.state.daysSeen, 2);
  });
}
