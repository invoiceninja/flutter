// Pins who is offered a self-hosted server update, and which kind: a newer
// release, a Force Update of the installed one, or nothing. Mirrors
// admin-portal's gates (`AppState.isUpdateAvailable`, `menu_drawer.dart`).

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/domain/self_update.dart';

AuthSession _session({
  bool isHosted = false,
  String baseUrl = 'https://selfhost.example.test',
  bool isAdmin = true,
  bool isOwner = false,
  bool withCompany = true,
  String current = '5.13.40',
  String latest = '5.13.45',
  bool isDocker = false,
  bool disableAutoUpdate = false,
}) => AuthSession(
  baseUrl: baseUrl,
  isHosted: isHosted,
  accountId: 'acct',
  companies: [
    if (withCompany)
      AuthCompany(
        id: 'co-A',
        name: 'Co A',
        displayName: 'Co A',
        permissions: '',
        isAdmin: isAdmin,
        isOwner: isOwner,
      ),
  ],
  currentCompanyId: withCompany ? 'co-A' : '',
  serverCurrentVersion: current,
  serverLatestVersion: latest,
  isDocker: isDocker,
  disableAutoUpdate: disableAutoUpdate,
);

void main() {
  group('selfUpdateOffer', () {
    test('a self-hosted admin behind the latest release gets an update', () {
      expect(selfUpdateOffer(_session()), SelfUpdateOffer.update);
    });

    test('an owner who is not flagged admin gets it too', () {
      expect(
        selfUpdateOffer(_session(isAdmin: false, isOwner: true)),
        SelfUpdateOffer.update,
      );
    });

    test('on the latest release it is a Force Update', () {
      expect(
        selfUpdateOffer(_session(current: '5.13.45')),
        SelfUpdateOffer.forceUpdate,
      );
    });

    test('compares numerically, not as text', () {
      // '5.9.1' < '5.13.0' — a string compare gets this backwards.
      expect(
        selfUpdateOffer(_session(current: '5.9.1', latest: '5.13.0')),
        SelfUpdateOffer.update,
      );
      expect(
        selfUpdateOffer(_session(current: '5.13.0', latest: '5.9.1')),
        SelfUpdateOffer.forceUpdate,
      );
    });

    test('a server that has not checked yet is not told to update', () {
      expect(
        selfUpdateOffer(_session(latest: '')),
        SelfUpdateOffer.forceUpdate,
      );
    });

    test('Docker: the update still shows, a Force Update does not', () {
      expect(selfUpdateOffer(_session(isDocker: true)), SelfUpdateOffer.update);
      expect(
        selfUpdateOffer(_session(isDocker: true, current: '5.13.45')),
        SelfUpdateOffer.none,
      );
    });

    test('nothing when the server disables auto update', () {
      expect(
        selfUpdateOffer(_session(disableAutoUpdate: true)),
        SelfUpdateOffer.none,
      );
    });

    test('nothing on hosted, even with a lagging version', () {
      expect(selfUpdateOffer(_session(isHosted: true)), SelfUpdateOffer.none);
    });

    test('nothing for a user who is neither admin nor owner', () {
      expect(selfUpdateOffer(_session(isAdmin: false)), SelfUpdateOffer.none);
    });

    test('nothing before the company has loaded', () {
      expect(
        selfUpdateOffer(_session(withCompany: false)),
        SelfUpdateOffer.none,
      );
    });

    test('nothing on the demo server', () {
      expect(
        selfUpdateOffer(_session(baseUrl: 'https://demo.invoiceninja.com')),
        SelfUpdateOffer.none,
      );
    });

    test('nothing without a session', () {
      expect(selfUpdateOffer(null), SelfUpdateOffer.none);
    });
  });

  test('a leading v is ignored in the comparison', () {
    expect(isNewerRelease(installed: 'v5.13.40', latest: '5.13.45'), isTrue);
    expect(isNewerRelease(installed: '5.13.45', latest: 'v5.13.45'), isFalse);
    expect(bareVersion(' v5.13.45 '), '5.13.45');
  });

  test('View Changes compares the installed release with v5-stable', () {
    expect(
      serverChangesUrl(' 5.13.40 '),
      'https://github.com/invoiceninja/invoiceninja/compare/v5.13.40...v5-stable',
    );
  });
}
