// The What's New dialog's automatic opener (docs/whats-new-dialog.md). It
// reads only `auth` and the unsaved-changes guard, so it takes a light fake
// rather than the shell fixture, whose live Drift watch streams never settle.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/app/whats_new_controller.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/domain/release_notes.dart';
import 'package:admin/ui/core/dialogs/automatic_dialogs.dart';
import 'package:admin/ui/core/unsaved_changes/unsaved_changes_guard.dart';
import 'package:admin/ui/features/whats_new/whats_new_host.dart';

import '../../../_localization_helper.dart';

class _FakeAuth implements AuthRepository {
  _FakeAuth(this._session);
  final ValueNotifier<AuthSession?> _session;
  @override
  ValueListenable<AuthSession?> get session => _session;
  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeServices implements Services {
  _FakeServices(AuthSession? session)
    : auth = _FakeAuth(ValueNotifier(session));
  @override
  final AuthRepository auth;
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

const _title = "What's new in v2.0.1";

void main() {
  tearDown(AutomaticDialogs.resetForTest);

  Future<WhatsNewController> pump(
    WidgetTester tester, {
    bool updated = true,
    bool provideController = true,
  }) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = WhatsNewController(
      prefs: DevicePrefsStore(null),
      currentVersion: '2.0.1',
      catalog: const [
        ReleaseNotes(version: '2.0.1', items: [ReleaseNoteItem('Added: x')]),
      ],
      surfaces: const {},
      isDemoBuild: false,
      demoMode: false,
    );
    addTearDown(controller.dispose);
    await controller.noteLaunch(existingInstall: updated);
    const child = WhatsNewHost(
      child: Scaffold(body: Center(child: TextField())),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Provider<Services>.value(
          value: _FakeServices(_session()),
          child: provideController
              ? ChangeNotifierProvider.value(value: controller, child: child)
              : child,
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  /// Past the settle and the dialog's half-second arm delay.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('opens on its own after an update, and closing it marks the '
      'notes seen', (tester) async {
    final c = await pump(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(_title), findsNothing);

    await settle(tester);
    expect(find.text(_title), findsOneWidget);
    expect(c.shownThisLaunch, isTrue);
    expect(c.state.shownAt, isNotNull, reason: 'recorded as it opens');
    expect(AutomaticDialogs.shownThisLaunch, isTrue);

    await tester.tap(find.text('Got it!'));
    await tester.pumpAndSettle();
    expect(c.pending, isEmpty);
    expect(c.state.seenVersion, '2.0.1');
  });

  testWidgets('a new install is told nothing', (tester) async {
    await pump(tester, updated: false);
    await tester.pump(const Duration(seconds: 30));
    expect(find.text(_title), findsNothing);
  });

  testWidgets('inert without a controller — every other harness', (
    tester,
  ) async {
    await pump(tester, provideController: false);
    await tester.pump(const Duration(seconds: 30));
    expect(find.text(_title), findsNothing);
  });

  testWidgets('waits behind another automatic dialog instead of standing '
      'down for the launch', (tester) async {
    AutomaticDialogs.noteShown();
    await pump(tester);
    final context = tester.element(find.byType(TextField));
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(content: Text('Your name?')),
      ),
    );
    await tester.pump(const Duration(seconds: 10));
    expect(find.text(_title), findsNothing);

    Navigator.of(context).pop();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(_title), findsOneWidget);
  });

  testWidgets('waits while the user keeps clicking', (tester) async {
    await pump(tester);
    for (var i = 0; i < 4; i++) {
      await tester.tapAt(const Offset(20, 20));
      await tester.pump(const Duration(seconds: 2));
    }
    expect(find.text(_title), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(_title), findsOneWidget);
  });

  testWidgets('waits while a form has unsaved changes, and a launch with no '
      'quiet moment counts an attempt', (tester) async {
    final c = await pump(tester);
    final services = tester.element(find.byType(WhatsNewHost)).read<Services>();
    final unregister = services.unsavedChangesGuard.register(
      isDirty: () => true,
      source: ValueNotifier(0),
    );
    addTearDown(unregister);
    await tester.pump(const Duration(seconds: 70));
    expect(find.text(_title), findsNothing);
    expect(c.attempts, 1);
    expect(c.pending, isNotEmpty, reason: 'still waiting for a later launch');
  });
}
