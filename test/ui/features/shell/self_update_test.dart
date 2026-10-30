// The self-hosted server update: the sidebar's Update Available card and the
// dialog it opens (admin-portal's warning icon + `UpdateDialog`).
//
// Both read only `services.auth`, `services.system` and
// `services.passwordCache`, so they take light fakes rather than
// `_shell_test_helpers.dart`'s Drift-backed fixture.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/system_api.dart';
import 'package:admin/domain/self_update.dart';
import 'package:admin/ui/features/shell/widgets/update_available_footer.dart';

import '../../../_localization_helper.dart';

class _FakeAuth implements AuthRepository {
  _FakeAuth(this._session);
  final ValueNotifier<AuthSession?> _session;
  int refreshes = 0;
  @override
  ValueListenable<AuthSession?> get session => _session;
  @override
  Future<void> refresh({bool fullSync = false}) async => refreshes++;
  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Answers `selfUpdate` from [results] in order; a [PasswordCache] with no
/// password makes the first call throw like the real client does.
class _FakeSystem implements SystemApi {
  _FakeSystem(this.cache, {this.error, this.message = 'Update completed'});
  final PasswordCache cache;
  final Object? error;
  final String message;
  int calls = 0;
  @override
  Future<String> selfUpdate() async {
    calls++;
    if (cache.read() == null) throw const PasswordRequiredException();
    if (error != null) throw error!;
    return message;
  }

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeServices implements Services {
  _FakeServices({
    required this.auth,
    required this.system,
    required this.passwordCache,
  });
  @override
  final AuthRepository auth;
  @override
  final SystemApi system;
  @override
  final PasswordCache passwordCache;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

AuthSession _session({
  String current = '5.13.40',
  String latest = '5.13.45',
  bool isDocker = false,
}) => AuthSession(
  baseUrl: 'https://selfhost.example.test',
  isHosted: false,
  accountId: 'acct',
  companies: const [
    AuthCompany(
      id: 'co-A',
      name: 'Co A',
      displayName: 'Co A',
      permissions: '',
      isAdmin: true,
      isOwner: false,
    ),
  ],
  currentCompanyId: 'co-A',
  serverCurrentVersion: current,
  serverLatestVersion: latest,
  isDocker: isDocker,
);

Future<({_FakeAuth auth, _FakeSystem system})> _pump(
  WidgetTester tester,
  AuthSession session, {
  Object? error,
  String message = 'Update completed',
  String? cachedPassword,
  bool exemptUser = false,
}) async {
  final cache = PasswordCache();
  if (cachedPassword != null) cache.set(cachedPassword);
  if (exemptUser) {
    cache.subject = () => const PasswordSubject(
      oauthProvider: 'google',
      hasPassword: true,
      oauthPasswordRequired: false,
    );
  }
  final auth = _FakeAuth(ValueNotifier(session));
  final system = _FakeSystem(cache, error: error, message: message);
  // Above the MaterialApp, as in the app: the dialog is its own route.
  await tester.pumpWidget(
    Provider<Services>.value(
      value: _FakeServices(auth: auth, system: system, passwordCache: cache),
      child: MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: const Scaffold(
          body: SizedBox(width: 260, child: UpdateAvailableFooter()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (auth: auth, system: system);
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.text('Update Available'));
  await tester.pumpAndSettle();
}

void main() {
  group('UpdateAvailableFooter', () {
    testWidgets('shown when the server is behind the latest release', (
      tester,
    ) async {
      await _pump(tester, _session());
      expect(find.text('Update Available'), findsOneWidget);
    });

    testWidgets('hidden on the latest release', (tester) async {
      await _pump(tester, _session(current: '5.13.45'));
      expect(find.text('Update Available'), findsNothing);
    });

    testWidgets('hidden on the collapsed rail', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: const Scaffold(body: UpdateAvailableFooter(compact: true)),
        ),
      );
      expect(find.text('Update Available'), findsNothing);
    });
  });

  group('self-update dialog', () {
    testWidgets('shows both versions', (tester) async {
      await _pump(tester, _session());
      await _openDialog(tester);
      expect(find.text('v5.13.40'), findsOneWidget);
      expect(find.text('v5.13.45'), findsOneWidget);
      expect(find.text('Update Now'), findsOneWidget);
    });

    testWidgets('Update Now runs the update and refreshes the session', (
      tester,
    ) async {
      final fakes = await _pump(tester, _session(), cachedPassword: 'pw');
      await _openDialog(tester);
      await tester.tap(find.text('Update Now'));
      await tester.pumpAndSettle();
      expect(fakes.system.calls, 1);
      expect(find.text('Update successfully completed'), findsOneWidget);
      expect(fakes.auth.refreshes, 1);
    });

    testWidgets('asks for the password, then retries', (tester) async {
      final fakes = await _pump(tester, _session());
      await _openDialog(tester);
      await tester.tap(find.text('Update Now'));
      await tester.pumpAndSettle();
      // The first call found no cached password.
      expect(fakes.system.calls, 1);
      await tester.enterText(find.byType(TextField), 'secret');
      // Confirm enables on the rebuild that follows the typing.
      await tester.pump();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(fakes.system.calls, 2);
      expect(find.text('Update successfully completed'), findsOneWidget);
    });

    testWidgets('cancelling the password prompt goes back to the offer', (
      tester,
    ) async {
      final fakes = await _pump(tester, _session());
      await _openDialog(tester);
      await tester.tap(find.text('Update Now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(fakes.system.calls, 1);
      expect(find.text('Update Now'), findsOneWidget);
      expect(fakes.auth.refreshes, 0);
    });

    testWidgets('a refused update shows the server message', (tester) async {
      final fakes = await _pump(
        tester,
        _session(),
        cachedPassword: 'pw',
        error: const ServerException(
          500,
          'Cannot update system because composer.json is not writable',
        ),
      );
      await _openDialog(tester);
      await tester.tap(find.text('Update Now'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('composer.json is not writable'),
        findsOneWidget,
      );
      expect(find.text('Update successfully completed'), findsNothing);
      expect(fakes.auth.refreshes, 0);
    });

    testWidgets('a 2xx that reports a failure is shown as one', (tester) async {
      // Older servers answered a failed unpack with a 200.
      final fakes = await _pump(
        tester,
        _session(),
        cachedPassword: 'pw',
        message: 'Update failed: could not extract the release',
      );
      await _openDialog(tester);
      await tester.tap(find.text('Update Now'));
      await tester.pumpAndSettle();
      expect(find.textContaining('could not extract'), findsOneWidget);
      expect(find.text('Update successfully completed'), findsNothing);
      expect(find.text('git checkout .'), findsOneWidget);
      expect(fakes.auth.refreshes, 0);
    });

    testWidgets('an exempt OAuth user refused by the server is asked', (
      tester,
    ) async {
      // The session says no password is needed; the server's 412 says it
      // is. The sheet must ask rather than wave the retry through.
      final fakes = await _pump(tester, _session(), exemptUser: true);
      await _openDialog(tester);
      await tester.tap(find.text('Update Now'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'secret');
      await tester.pump();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(fakes.system.calls, 2);
      expect(find.text('Update successfully completed'), findsOneWidget);
    });

    testWidgets('Docker shows the commands instead of Update Now', (
      tester,
    ) async {
      await _pump(tester, _session(isDocker: true));
      await _openDialog(tester);
      expect(find.text('Update Now'), findsNothing);
      expect(find.text(kDockerUpdateCommand), findsOneWidget);
    });
  });
}
