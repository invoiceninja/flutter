import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/auth_service.dart';
import 'package:admin/ui/features/auth/views/login_screen.dart';
import 'package:admin/ui/features/auth/widgets/auth_fields.dart';

import '../../../_localization_helper.dart';

/// The login screen only reads `services.auth` (to build its ViewModel in
/// initState); every other member is unused during render, except
/// `precheckLogin` once an email field blurs.
class _FakeAuth implements AuthRepository {
  _FakeAuth({this.precheckResult, this.gate});

  /// Canned `/login/precheck` answer. Null means "server didn't answer".
  final LoginPrecheck? precheckResult;

  /// Held open so a test can keep the answer in flight while the user types —
  /// the real endpoint has a ~250 ms constant-time floor, so it always lands
  /// after the user has moved on to the next field.
  final Completer<void>? gate;

  @override
  Future<LoginPrecheck?> precheckLogin({
    required String baseUrl,
    required bool isHosted,
    required String email,
    String? secret,
  }) async {
    if (gate != null) await gate!.future;
    return precheckResult;
  }

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
  testWidgets(
    'optional API secret field is hidden when hosted, shown when self-hosted',
    (tester) async {
      await tester.pumpWidget(
        Provider<Services>.value(
          value: _FakeServices(_FakeAuth()),
          child: MaterialApp(
            theme: buildInTheme(InTheme.light),
            localizationsDelegates: kTestLocalizationsDelegates,
            supportedLocales: kTestSupportedLocales,
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.pump();
      // Swallow the async asset-load report for the logo image — irrelevant to
      // the form fields under test.
      tester.takeException();

      const secretLabel = 'API secret (Optional)';

      // Hosted (default): the whole self-hosted block — Server URL + secret —
      // is not rendered.
      expect(find.text('Self-Hosted'), findsOneWidget);
      expect(find.text('Server URL'), findsNothing);
      expect(find.text(secretLabel), findsNothing);

      // Switch to Self-Hosted → Server URL and the optional API secret appear.
      await tester.tap(find.text('Self-Hosted'));
      await tester.pump();

      expect(find.text('Server URL'), findsOneWidget);
      expect(find.text(secretLabel), findsOneWidget);
    },
  );

  // The API-secret block sits ABOVE the email/password fields and the OTP block
  // sits BELOW them. A single precheck answer commonly removes both at once
  // (self-hosted server with no API_SECRET + an account without 2FA), which puts
  // the email and password fields in the unkeyed middle range of the Column —
  // Flutter's element sync then discards and re-inflates them, taking their
  // controllers and focus with them. The user is typing their password when the
  // answer lands, so the caret vanishes and every later keystroke is dropped.
  testWidgets(
    'password field keeps focus and text when the precheck answer lands',
    (tester) async {
      final gate = Completer<void>();
      await tester.pumpWidget(
        Provider<Services>.value(
          value: _FakeServices(
            // No API secret, no TOTP → both optional blocks disappear at once.
            _FakeAuth(
              precheckResult: const LoginPrecheck(
                methods: {'password'},
                secretRequired: false,
              ),
              gate: gate,
            ),
          ),
          child: MaterialApp(
            theme: buildInTheme(InTheme.light),
            localizationsDelegates: kTestLocalizationsDelegates,
            supportedLocales: kTestSupportedLocales,
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.pump();
      tester.takeException();

      await tester.tap(find.text('Self-Hosted'));
      await tester.pump();

      // The label is a sibling `Text` above the input, so locate each field
      // through its wrapper widget rather than by key — the assertions must
      // hold regardless of how the fix identifies the elements.
      Finder inputOf(Type wrapper, String label) => find.descendant(
        of: find.widgetWithText(wrapper, label),
        matching: find.byType(TextField),
      );
      // `AuthPasswordField` lets its `TextField` own the focus node, so read
      // focus + text off the `EditableText` underneath it.
      Finder editableOf(Type wrapper, String label) => find.descendant(
        of: find.widgetWithText(wrapper, label),
        matching: find.byType(EditableText),
      );

      await tester.enterText(
        inputOf(AuthField, 'Server URL'),
        'https://invoice.example.com',
      );
      await tester.pump();
      await tester.enterText(inputOf(AuthField, 'Email'), 'a@b.com');
      await tester.pump();

      // Move to the password field (this blurs email → fires the precheck) and
      // start typing, exactly as a user tabbing through the form would.
      final password = inputOf(AuthPasswordField, 'Password');
      await tester.tap(password);
      await tester.pump();
      await tester.enterText(password, 'hunter2');
      await tester.pump();
      final editable = editableOf(AuthPasswordField, 'Password');
      expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue);
      // Still in flight, so both optional blocks are still on screen — the
      // rebuild that follows is the one that removes them.
      expect(find.text('API secret (Optional)'), findsOneWidget);

      // The answer lands mid-typing and rebuilds the form.
      gate.complete();
      await tester.pumpAndSettle();

      // The optional blocks are gone — i.e. the rebuild really happened.
      expect(find.text('API secret (Optional)'), findsNothing);

      final field = tester.widget<EditableText>(editable);
      expect(
        field.controller.text,
        'hunter2',
        reason: 'the password the user already typed must survive the rebuild',
      );
      expect(
        field.focusNode.hasFocus,
        isTrue,
        reason:
            'the password field must keep focus — losing it silently drops '
            'every subsequent keystroke',
      );
    },
  );
}
