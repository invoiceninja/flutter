import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/app/welcome_controller.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/domain/welcome.dart';
import 'package:admin/ui/features/auth/view_models/setup_wizard_view_model.dart';
import 'package:admin/ui/features/auth/views/setup_wizard_screen.dart';

import '../../shell/_shell_test_helpers.dart';

/// The two-step setup wizard (docs/first-run-welcome.md): nothing is saved
/// until it is finished, then one company PUT and, after it, the logo.
void main() {
  Future<ShellFixture> fixture() async {
    final f = await buildFixture(
      companies: const [FakeCompany(id: 'c1', name: 'Untitled Company')],
      currentCompanyId: 'c1',
    );
    f.services.refreshScheduler.stop();
    return f;
  }

  SetupWizardViewModel vmFor(Services s, {WelcomeController? welcome}) =>
      SetupWizardViewModel(
        companyId: 'c1',
        session: s.auth.session.value,
        company: s.company,
        user: s.user,
        sync: s.sync,
        passwordCache: s.passwordCache,
        welcome: welcome,
      );

  Future<List<String>> outboxActions(ShellFixture f) async {
    final rows = await f.db.outboxDao.watchAll('c1').first;
    // `watchAll` is newest first.
    return [
      for (final r in rows.reversed)
        if (r.entityType == 'company')
          (jsonDecode(r.payload) as Map)['_action'] as String? ?? 'update',
    ];
  }

  group('SetupWizardViewModel', () {
    test('step 1 needs a business name before it moves on', () async {
      final f = await fixture();
      addTearDown(f.dispose);
      final vm = vmFor(f.services);
      addTearDown(vm.dispose);
      expect(vm.advance(), isFalse);
      expect(vm.showNameError, isTrue);
      vm.setBusinessName('Acme Studio');
      expect(vm.showNameError, isFalse);
      expect(vm.advance(), isTrue);
      expect(vm.step, SetupWizardStep.logo);
      expect(vm.back(), isTrue);
      expect(vm.back(), isFalse, reason: 'back from step 1 leaves the screen');
    });

    test('nothing is written until the commit', () async {
      final f = await fixture();
      addTearDown(f.dispose);
      final vm = vmFor(f.services)..setBusinessName('Acme Studio');
      addTearDown(vm.dispose);
      vm.advance();
      expect(await outboxActions(f), isEmpty);
      expect(
        f.services.auth.session.value?.currentCompany?.displayName,
        isNot('Acme Studio'),
        reason: 'a name saved early would open the /setup gate',
      );
    });

    test('the commit is one company PUT, then the logo after it', () async {
      final f = await fixture();
      addTearDown(f.dispose);
      final vm = vmFor(f.services)
        ..setBusinessName('Acme Studio')
        ..setCurrency('2')
        ..setLogo(Uint8List.fromList([1, 2, 3]));
      addTearDown(vm.dispose);
      expect(await vm.commit(), isTrue);
      // The PUT carries the old `company_logo`; an upload sent before it
      // would be cleared by it.
      expect(await outboxActions(f), ['update', 'upload_logo']);
      final company = await f.services.company.get('c1');
      expect(company?.settings.name, 'Acme Studio');
      expect(company?.settings.currencyId, '2');
    });

    test('the commit settles a new account and arms its checklist', () async {
      final f = await fixture();
      addTearDown(f.dispose);
      // A session with a user, as a real sign-up has.
      await f.db.userSettingsDao.upsert(
        UserSettingsCompanion.insert(
          companyId: 'c1',
          userId: 'u1',
          updatedAt: 0,
        ),
      );
      await f.services.auth.restore();
      f.services.refreshScheduler.stop();
      final welcome = WelcomeController(
        prefs: DevicePrefsStore(null),
        currentUserKey: () => null,
        isDemoBuild: false,
        demoMode: false,
      );
      addTearDown(welcome.dispose);
      final s = f.services.auth.session.value!;
      final key = welcomeUserKey(s.baseUrl, s.userId);
      welcome.noteSignIn(SignInFacts(userKey: key, isSignup: true));
      final vm = vmFor(f.services, welcome: welcome)
        ..setBusinessName('Acme Studio');
      addTearDown(vm.dispose);
      await vm.commit();
      expect(welcome.state.users[key]?.status, WelcomeStatus.seen);
      expect(welcome.showsChecklist('c1'), isTrue);
    });

    test(
      'a placeholder name is refused, or the gate would never open',
      () async {
        final f = await fixture();
        addTearDown(f.dispose);
        final vm = vmFor(f.services)..setBusinessName('Untitled Company');
        addTearDown(vm.dispose);
        expect(vm.advance(), isFalse);
        expect(vm.showNameError, isTrue);
        expect(await vm.commit(), isFalse);
        expect(await outboxActions(f), isEmpty);
      },
    );

    test('a lapsed password is asked for before the name is saved', () async {
      final f = await fixture();
      addTearDown(f.dispose);
      await f.db.userSettingsDao.upsert(
        UserSettingsCompanion.insert(
          companyId: 'c1',
          userId: 'u1',
          updatedAt: 0,
        ),
      );
      await f.services.auth.restore();
      f.services.refreshScheduler.stop();
      f.services.passwordCache.set('secret');
      final queued = <String>[];
      final vm = SetupWizardViewModel(
        companyId: 'c1',
        session: f.services.auth.session.value,
        company: f.services.company,
        user: f.services.user,
        sync: f.services.sync,
        passwordCache: f.services.passwordCache,
        onNameQueued: (first, last) => queued.add('$first $last'),
      )..setUserName(first: 'Ada', last: 'Lovelace');
      addTearDown(vm.dispose);
      expect(vm.askUserName, isTrue);
      expect(vm.nameNeedsPassword, isFalse);
      // Backgrounding the app clears the cache.
      f.services.passwordCache.clear();
      expect(vm.nameNeedsPassword, isTrue);
      // Declined: the company still saves, the name is left for later.
      vm
        ..skipUserName = true
        ..setBusinessName('Acme Studio');
      expect(await vm.commit(), isTrue);
      expect(queued, isEmpty);
    });

    test('suggests the user\'s own name for a freelancer', () async {
      final f = await fixture();
      addTearDown(f.dispose);
      final vm = vmFor(f.services)..setUserName(first: 'Ada', last: 'Lovelace');
      addTearDown(vm.dispose);
      expect(vm.suggestedBusinessName, 'Ada Lovelace');
    });
  });

  group('SetupWizardScreen', () {
    Future<void> pump(WidgetTester tester, ShellFixture f) async {
      await tester.pumpWidget(
        wrapWithShell(
          f.services,
          ChangeNotifierProvider<WelcomeController?>.value(
            value: null,
            child: const SetupWizardScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('Continue with no name explains, then moves on', (
      tester,
    ) async {
      final f = await fixture();
      addTearDown(f.dispose);
      await pump(tester, f);
      expect(find.text('Step 1 of 2'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('setup_submit')));
      await tester.pump();
      expect(find.text('Enter your business name'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('setup_company_name')),
        'Acme Studio',
      );
      await tester.pump();
      // The preview shows the name as it is typed.
      expect(find.text('Acme Studio'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('setup_submit')));
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 2'), findsOneWidget);
      expect(find.text('Add your logo'), findsOneWidget);
      // With no logo the primary offers to skip, not to finish.
      expect(find.text('Skip for Now'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('setup_back')));
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 2'), findsOneWidget);
    });

    testWidgets('Esc goes back a step', (tester) async {
      final f = await fixture();
      addTearDown(f.dispose);
      await pump(tester, f);
      await tester.enterText(
        find.byKey(const ValueKey('setup_company_name')),
        'Acme Studio',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 2'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 2'), findsOneWidget);
    });

    testWidgets('fits a phone at a large text size', (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final f = await fixture();
      addTearDown(f.dispose);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 720),
            textScaler: TextScaler.linear(2),
          ),
          child: wrapWithShell(f.services, const SetupWizardScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    });
  });
}
