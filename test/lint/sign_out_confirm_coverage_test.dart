import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CI lint: every user-facing sign-out routes through a confirmation.
///
/// `AuthRepository.logout()` wipes the whole Drift DB — every company's
/// still-pending outbox rows included — and `endAllSessions()` additionally
/// rotates every `is_system` token on the company, signing out every user of
/// it on all their devices. A new surface that calls either and forgets the
/// prompt compiles, runs, and passes every other test; it just destroys data
/// on one tap. That invisibility is why this is a build-time check.
///
/// "Routes through a confirmation" means the file imports either
/// `confirm_sign_out_dialog.dart` (it prompts itself) or `settings_actions.dart`
/// (it delegates to `SettingsActions.signOut`, which prompts).
void main() {
  // Exempt call sites, mapped to the file that prompts on their behalf — or
  // null where the call simply isn't user-initiated. A delegate is asserted
  // below, so an exemption can't outlive the prompt that justified it.
  const allowed = <String, String?>{
    // Fires on a timer, not a tap; preserves local data when work is queued.
    'lib/app/idle_timeout_controller.dart': null,
    // The 401 handler — the server ended the session, there is nobody to ask.
    'lib/app/services.dart': null,
    // The inside of `endAllSessions()`; its caller owns the prompt.
    'lib/data/repositories/auth_repository.dart':
        'lib/ui/features/settings/views/basic/account_management/'
        'security_settings_screen.dart',
    // This VM only holds the busy flag; the lock screen owns the prompt.
    'lib/ui/features/auth/view_models/lock_view_model.dart':
        'lib/ui/features/auth/views/lock_screen.dart',
    // Reached only after type-to-confirm + a password gate (cancel account /
    // delete the last company), where a sign-out prompt would be a fourth.
    'lib/ui/features/settings/views/basic/account_management/'
            'danger_zone_screen.dart':
        null,
  };

  // The CALL, not the import. Three files (`device_settings_screen.dart`,
  // `account_management/overview_screen.dart`, `in_sidebar.dart`) already
  // import `settings_actions.dart` for `forceResync` / `addCompany`, so an
  // import-presence check would exempt them for free — and a "Sign out" tile
  // added to Device Settings would wipe every company's DB with the lint
  // still green, which is the exact failure this file exists to catch.
  const confirmCall = 'showConfirmSignOutDialog(';
  const delegateCall = 'SettingsActions.signOut(';

  test('every sign-out call site confirms or delegates to one that does', () {
    // Any receiver, not just `auth.` — the lock screen's VM holds it as
    // `_auth`, and a `\bauth\.` anchor would silently skip that whole shape.
    final pattern = RegExp(r'\.logout\(|\bendAllSessions\(');
    final offenders = <String>[];

    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'lib/ should exist');

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart')) continue;
      if (entity.path.endsWith('.freezed.dart')) continue;
      if (allowed.containsKey(entity.path)) continue;

      // Comment lines don't call anything: several files name
      // `AuthRepository.logout()` in their doc comments.
      final code = entity
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      if (!pattern.hasMatch(code)) continue;
      if (code.contains(confirmCall) || code.contains(delegateCall)) continue;
      offenders.add(entity.path);
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These end the session with no confirmation. Call '
          '`showConfirmSignOutDialog` first, or delegate to '
          '`SettingsActions.signOut`. If the call is genuinely not '
          'user-initiated, add it to `allowed` with a reason. Found:\n  '
          '${offenders.join('\n  ')}',
    );
  });

  test(
    'the allowlisted files still exist and their delegates still prompt',
    () {
      // A rename would silently empty the allowlist rather than fail; the same
      // guard `guarded_action_tap_test.dart` keeps over its owners.
      allowed.forEach((path, delegate) {
        expect(
          File(path).existsSync(),
          isTrue,
          reason: '$path moved or renamed',
        );
        if (delegate == null) return;
        // The exemption is only sound while the delegate really prompts. The
        // lock screen calls `_vm.signOut()`, not `.logout(`, so the scan above
        // never reaches it — without this, dropping its confirm would be
        // invisible to the very lint written to see that.
        final file = File(delegate);
        expect(file.existsSync(), isTrue, reason: '$delegate moved or renamed');
        expect(
          file.readAsStringSync().contains(confirmCall),
          isTrue,
          reason:
              '$delegate is why $path is exempt, but it no longer calls '
              '$confirmCall',
        );
      });
    },
  );

  test('the two confirming seams still exist', () {
    for (final path in const [
      'lib/ui/core/dialogs/confirm_sign_out_dialog.dart',
      'lib/ui/features/settings/settings_actions.dart',
    ]) {
      expect(File(path).existsSync(), isTrue, reason: '$path moved or renamed');
    }
  });
}
