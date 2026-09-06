import 'package:admin/data/services/biometric_service.dart';
import 'package:admin/ui/features/auth/views/lock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../shell/_shell_test_helpers.dart';

/// The lock screen's Sign out runs a FULL logout — it wipes every company's
/// local DB, including the still-pending outbox rows the idle-timeout preserve
/// path deliberately kept alive. It shipped with no confirmation.
///
/// The fake biometric is not optional: the real `local_auth` impl's
/// `authenticate()` never completes under `flutter test`, so the screen's
/// auto-prompt would leave `busy` true, the Sign out button disabled, and
/// `pumpAndSettle` spinning on the Unlock spinner until it times out.
void main() {
  testWidgets('Sign out confirms, and cancelling leaves the session intact', (
    tester,
  ) async {
    final fixture = await buildFixture(
      companies: const [
        FakeCompany(id: 'c1', name: 'Acme Co', token: 'tok-c1'),
      ],
      currentCompanyId: 'c1',
      biometricService: _DeclinedBiometric(),
    );
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      wrapWithShell(fixture.services, const LockScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('lock_sign_out')));
    await tester.pumpAndSettle();

    expect(find.text('Sign out?'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Sign out?'), findsNothing);
    expect(
      fixture.services.auth.session.value?.currentCompanyId,
      'c1',
      reason: 'Cancel must not end the session',
    );
    expect(
      find.byType(LockScreen),
      findsOneWidget,
      reason: 'and must leave the user on the lock screen',
    );

    fixture.services.recentlyViewed.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

/// Available, but the user dismisses it — the state the lock screen sits in
/// when someone reaches for Sign out.
class _DeclinedBiometric implements BiometricService {
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> authenticate({required String reason}) async => false;
}
