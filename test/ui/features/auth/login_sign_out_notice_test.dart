import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/sign_out_notice.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';
import 'package:admin/ui/features/auth/views/login_screen.dart';

import '../../../_localization_helper.dart';

/// The sign-in screen says why the last session ended on its own — the one
/// trace of it a release build keeps.
class _FakeAuth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeServices implements Services {
  @override
  final AuthRepository auth = _FakeAuth();
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Finder _key(String key) => find.byKey(ValueKey(key));

void main() {
  late SignOutNotice notice;

  Future<void> pumpLogin(WidgetTester tester) async {
    notice = SignOutNotice(
      prefs: DevicePrefsStore(null),
      credentials: ValueNotifier<ApiCredentials?>(null),
    );
    addTearDown(notice.dispose);
    final toasts = ToastController();
    addTearDown(toasts.clearAll);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<Services>.value(value: _FakeServices()),
          ChangeNotifierProvider<ToastController>.value(value: toasts),
          ChangeNotifierProvider<SignOutNotice>.value(value: notice),
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

  testWidgets('nothing to say, nothing shown', (tester) async {
    await pumpLogin(tester);
    expect(_key('login_sign_out_notice'), findsNothing);
  });

  testWidgets('a rejected session says so and names the request', (
    tester,
  ) async {
    await pumpLogin(tester);
    await notice.record(
      SignOutReason.sessionRejected,
      detail: 'PUT invoicing.co/api/v1/tasks/abc',
    );
    await tester.pump();

    expect(_key('login_sign_out_notice'), findsOneWidget);
    expect(find.text('Your session has expired.'), findsOneWidget);
    expect(find.text('PUT invoicing.co/api/v1/tasks/abc'), findsOneWidget);
  });

  testWidgets('inactivity says so, and ✕ dismisses it', (tester) async {
    await pumpLogin(tester);
    await notice.record(SignOutReason.inactivity);
    await tester.pump();
    expect(
      find.text('You have been logged out due to inactivity'),
      findsOneWidget,
    );

    await tester.tap(_key('login_sign_out_notice_dismiss'));
    await tester.pump();
    expect(_key('login_sign_out_notice'), findsNothing);
    expect(notice.pending, isNull);
  });
}
