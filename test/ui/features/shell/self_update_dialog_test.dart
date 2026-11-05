// A self-hosted server update outlives a typical reverse proxy's ~60 s, so a
// 504 or a timeout usually means the update is still running on the server.
// Reported as a plain failure, that invited Update Now again — a second unpack
// and migration over one still in progress.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/system_api.dart';
import 'package:admin/ui/features/shell/widgets/self_update_dialog.dart';

import '../../../_localization_helper.dart';

class _FakeSystem implements SystemApi {
  _FakeSystem(this.error);
  final Object error;

  @override
  Future<String> selfUpdate() async => throw error;

  @override
  Object? noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

class _FakeAuth implements AuthRepository {
  @override
  final ValueListenable<AuthSession?> session = ValueNotifier<AuthSession?>(
    const AuthSession(
      baseUrl: 'https://selfhost.example.test',
      isHosted: false,
      accountId: 'a1',
      userId: 'u1',
      currentCompanyId: 'c1',
      companies: [
        AuthCompany(
          id: 'c1',
          name: 'Acme',
          displayName: 'Acme',
          permissions: '',
          isAdmin: true,
          isOwner: false,
        ),
      ],
      serverCurrentVersion: '5.13.40',
      serverLatestVersion: '5.13.45',
    ),
  );

  @override
  Object? noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

class _FakeServices implements Services {
  _FakeServices(Object error) : system = _FakeSystem(error);

  @override
  final SystemApi system;

  @override
  final AuthRepository auth = _FakeAuth();

  @override
  Object? noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

void main() {
  Future<void> updateFailingWith(WidgetTester tester, Object error) async {
    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(error),
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: const Scaffold(body: SelfUpdateDialog()),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Update Now'));
    await tester.pump();
    await tester.pump();
  }

  const stillRunning =
      "The server didn't answer in time, but the update may still be "
      "running. Wait a few minutes, then check the server's version before "
      'trying again.';

  testWidgets('a proxy timeout says the update may still be running', (
    tester,
  ) async {
    await updateFailingWith(tester, const ServerException(504));
    expect(find.text(stillRunning), findsOneWidget);
  });

  testWidgets('so does a timeout after the request went out', (tester) async {
    await updateFailingWith(tester, const NetworkException('timed out'));
    expect(find.text(stillRunning), findsOneWidget);
  });

  testWidgets('a request that never left is an ordinary failure', (
    tester,
  ) async {
    await updateFailingWith(tester, const RequestNotSentException('offline'));
    expect(find.text(stillRunning), findsNothing);
  });
}
