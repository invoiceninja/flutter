import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/sign_out_notice.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/data/services/api_credentials.dart';

/// Release builds keep no diagnostics log, so an automatic sign-out used to
/// leave the user on the sign-in screen with no idea why. The notice is the
/// one record of it: written before the logout, kept across it, said once.
void main() {
  const signedIn = ApiCredentials(baseUrl: 'https://test', token: 't');

  late DevicePrefsStore prefs;
  late ValueNotifier<ApiCredentials?> credentials;

  setUp(() {
    prefs = DevicePrefsStore(null);
    credentials = ValueNotifier<ApiCredentials?>(signedIn);
  });

  SignOutNotice notice() {
    final n = SignOutNotice(prefs: prefs, credentials: credentials);
    addTearDown(n.dispose);
    return n;
  }

  test('record keeps the reason and the request, in memory and in the '
      'store', () async {
    final n = notice();
    await n.record(SignOutReason.sessionRejected, detail: 'PUT test/x');
    expect(n.pending, (
      reason: SignOutReason.sessionRejected,
      detail: 'PUT test/x',
    ));
    expect(prefs.read(DevicePrefKeys.signOutNotice), contains('PUT test/x'));
  });

  test(
    'it outlives the sign-out it explains, and a later launch reads it',
    () async {
      await notice().record(SignOutReason.inactivity);
      credentials.value = null;

      final next = notice();
      expect(next.pending, (reason: SignOutReason.inactivity, detail: null));
    },
  );

  test('a session going live again drops it', () async {
    final n = notice();
    await n.record(SignOutReason.inactivity);
    credentials.value = null;
    expect(n.pending, isNotNull);

    credentials.value = signedIn;
    await Future<void>.delayed(Duration.zero);
    expect(n.pending, isNull);
    expect(prefs.read(DevicePrefKeys.signOutNotice), isNull);
  });

  test('one found while signed in is stale, and dropped', () async {
    await prefs.write(
      DevicePrefKeys.signOutNotice,
      '{"reason":"sessionRejected"}',
    );
    final n = notice();
    await Future<void>.delayed(Duration.zero);
    expect(n.pending, isNull);
    expect(prefs.read(DevicePrefKeys.signOutNotice), isNull);
  });

  test('dismiss forgets it', () async {
    final n = notice();
    await n.record(SignOutReason.inactivity);
    await n.dismiss();
    expect(n.pending, isNull);
    expect(prefs.read(DevicePrefKeys.signOutNotice), isNull);
  });

  test('an unreadable value reads as no notice', () async {
    credentials.value = null;
    for (final raw in ['not json', '[]', '{"reason":"from_a_newer_build"}']) {
      await prefs.write(DevicePrefKeys.signOutNotice, raw);
      expect(notice().pending, isNull, reason: raw);
    }
  });
}
