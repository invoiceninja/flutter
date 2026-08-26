import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/views/advanced/user_management/views/user_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../shell/_shell_test_helpers.dart';

/// `pumpAndSettle` is unusable here: `buildFixture` wires a **real** Drift
/// database, and the screen's custom-fields section watches the company row —
/// a live watch stream never lets the frame scheduler go idle, so settle
/// spins for its full timeout and then fails. Pump a bounded number of frames
/// instead.
Future<void> _pumpFrames(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Unmount so drift's stream subscriptions cancel and the real `Services`
/// debounces fire, then pump the close timers out — otherwise the binding
/// reports "A Timer is still pending" at teardown. Same shape as
/// `system_logs_screen_test`.
Future<void> _teardownTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

/// Save on a blank **New User** form must report what's missing — it must not
/// ask the user to authenticate first.
///
/// Two changes collided to produce that: the Save gate was loosened to
/// `!isSaving` (a disabled button can't say *why* it's disabled — #66) while
/// the account-password prompt moved ahead of `vm.save()` so the outbox row
/// isn't parked and cancelled behind a "Successfully created user" toast
/// (#64). Between them, a blank form answered Save with a password sheet and
/// only then mentioned the empty fields.
void main() {
  Future<ShellFixture> pumpNewUser(WidgetTester tester) async {
    final fixture = await buildFixture(
      companies: [
        FakeCompany(id: 'co1', name: 'Co', isOwner: true, isAdmin: true),
      ],
    );
    addTearDown(fixture.dispose);

    // A settings page normally mounts under the settings shell, which owns
    // the scope controller `SettingsScopeBanner` reads.
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        ChangeNotifierProvider<SettingsLevelController>(
          create: (_) => SettingsLevelController(),
          child: const UserEditScreen(),
        ),
      ),
    );
    await _pumpFrames(tester);
    return fixture;
  }

  testWidgets('a blank create reports the empty fields, not a password sheet', (
    tester,
  ) async {
    final fixture = await pumpNewUser(tester);
    expect(
      fixture.services.passwordCache.read(),
      isNull,
      reason:
          'nothing primes the cache on the create path — so a prompt '
          'would be reachable if the ordering regressed',
    );

    await tester.tap(find.text('Save'));
    await _pumpFrames(tester);

    // Two occurrences each: the inline field error on the Details tab, plus
    // the toast that now names the first problem. The toast exists because the
    // errors render ONLY on the Details tab, so a Save tapped from the
    // Notifications or Permissions tab used to do nothing visible at all.
    expect(find.text('Please enter a first name'), findsWidgets);
    expect(find.text('Please enter a last name'), findsOneWidget);
    expect(find.text('Please enter your email'), findsOneWidget);
    // The regression: the password sheet must not have opened.
    expect(find.text('Confirm Password'), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    await _teardownTree(tester);
  });

  testWidgets('a blank Save from another tab is not silent', (tester) async {
    await pumpNewUser(tester);

    // Permissions is a natural first stop when provisioning a user. The field
    // errors live on the Details tab, so without the jump-and-toast this Save
    // produced no toast, no tab change and no visible error — indefinitely.
    await tester.tap(find.text('Permissions'));
    await _pumpFrames(tester, frames: 3);
    expect(find.text('Please enter a first name'), findsNothing);

    await tester.tap(find.text('Save'));
    await _pumpFrames(tester, frames: 5);

    // Back on the Details tab — assert on the tab's own content, not on the
    // error message: the toast carries that message too, so asserting it alone
    // passes even when the tab never switches.
    expect(
      find.widgetWithText(TextField, 'First Name *'),
      findsOneWidget,
      reason: 'a failed Save must land the user where the errors render',
    );
    expect(find.text('Please enter a first name'), findsWidgets);
    await _teardownTree(tester);
  });

  testWidgets('a filled-in create does reach the password sheet', (
    tester,
  ) async {
    await pumpNewUser(tester);

    Future<void> fill(String label, String value) async {
      await tester.enterText(find.widgetWithText(TextField, label), value);
      await _pumpFrames(tester, frames: 2);
    }

    await fill('First Name *', 'Ada');
    await fill('Last Name *', 'Lovelace');
    await fill('Email *', 'ada@example.com');

    await tester.tap(find.text('Save'));
    await _pumpFrames(tester);

    // Validation passed, so the gate the form *does* need now shows.
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Please enter a first name'), findsNothing);
    await _teardownTree(tester);
  });
}
