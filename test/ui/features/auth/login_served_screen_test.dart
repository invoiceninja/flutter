import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/serving_server.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';
import 'package:admin/ui/features/auth/views/login_screen.dart';

import '../../../_localization_helper.dart';

/// On a page an Invoice Ninja server served (docs/web-deploy.md) the login
/// screen has no server to choose: no Hosted / Self-Hosted toggle and no URL
/// field. Without the provider it is the screen it always was.
class _FakeAuth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeServices implements Services {
  _FakeServices(this.auth);
  @override
  final AuthRepository auth;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  Future<void> pumpLogin(WidgetTester tester, {ServingServer? served}) async {
    final toasts = ToastController();
    addTearDown(toasts.clearAll);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<Services>.value(value: _FakeServices(_FakeAuth())),
          ChangeNotifierProvider<ToastController>.value(value: toasts),
          if (served != null) Provider<ServingServer>.value(value: served),
        ],
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pump();
    tester.takeException(); // the logo asset
  }

  testWidgets('not served: the platform toggle is there', (tester) async {
    await pumpLogin(tester);
    expect(find.text('Self-Hosted'), findsOneWidget);
    expect(find.byKey(const ValueKey('login_email')), findsOneWidget);
  });

  testWidgets('served by a self-hosted server: no toggle, no URL field', (
    tester,
  ) async {
    await pumpLogin(
      tester,
      served: const ServingServer(
        apiUrl: 'https://ninja.example.com',
        isHosted: false,
      ),
    );
    expect(find.text('Self-Hosted'), findsNothing);
    expect(find.text('Hosted'), findsNothing);
    expect(find.byKey(const ValueKey('login_url')), findsNothing);
    expect(find.byKey(const ValueKey('login_email')), findsOneWidget);
  });

  // One page per test: a second pumpWidget of the same screen keeps the first
  // one's State, and with it the first ServingServer.
  const react = ValueKey('login_open_react');
  const choose = ValueKey('login_choose_app');

  testWidgets('the hosted page points to the other web app', (tester) async {
    // admin.invoicing.co names invoicing.co as its server.
    await pumpLogin(
      tester,
      served: const ServingServer(
        apiUrl: 'https://invoicing.co',
        isHosted: true,
      ),
    );
    expect(find.byKey(react), findsOneWidget);
    expect(find.byKey(choose), findsOneWidget);
  });

  testWidgets('a self-hosted server\'s page has no other web app', (
    tester,
  ) async {
    await pumpLogin(
      tester,
      served: const ServingServer(
        apiUrl: 'https://ninja.example.com',
        isHosted: false,
      ),
    );
    expect(find.byKey(react), findsNothing);
    expect(find.byKey(choose), findsNothing);
  });

  testWidgets('a page nothing served has no other web app', (tester) async {
    await pumpLogin(tester);
    expect(find.byKey(react), findsNothing);
    expect(find.byKey(choose), findsNothing);
  });

  testWidgets('a white-labelled server shows no logo', (tester) async {
    await pumpLogin(
      tester,
      served: const ServingServer(
        apiUrl: 'https://ninja.example.com',
        isHosted: false,
        whiteLabel: true,
      ),
    );
    expect(find.byType(Image), findsNothing);
  });
}
