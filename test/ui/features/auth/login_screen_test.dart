import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/auth_service.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';
import 'package:admin/ui/features/auth/views/login_screen.dart';
import 'package:admin/ui/features/auth/widgets/auth_fields.dart';

import '../../../_localization_helper.dart';

/// The login screen only reads `services.auth` (to build its ViewModel in
/// initState). Continue asks `precheckLogin`; Login calls `login`, which
/// always fails here so no session is ever persisted.
class _FakeAuth implements AuthRepository {
  _FakeAuth({this.precheckResult});

  /// Canned `/login/precheck` answer. Null means "server didn't answer".
  final LoginPrecheck? precheckResult;

  int precheckCalls = 0;
  int loginCalls = 0;

  /// Held open to keep a request in flight.
  Completer<void>? precheckGate;
  Completer<void>? loginGate;
  Completer<void>? recoverGate;
  Completer<void>? sendGate;

  /// Thrown by `sendTwoFactorResetCode` / `confirmTwoFactorReset` when set.
  Object? sendError;
  Object? confirmError;

  @override
  Future<LoginPrecheck?> precheckLogin({
    required String baseUrl,
    required bool isHosted,
    required String email,
  }) async {
    precheckCalls++;
    if (precheckGate != null) await precheckGate!.future;
    return precheckResult;
  }

  @override
  Future<void> recoverPassword({
    required String baseUrl,
    required bool isHosted,
    required String email,
    String? secret,
  }) async {
    if (recoverGate != null) await recoverGate!.future;
  }

  @override
  Future<void> login({
    required String baseUrl,
    required bool isHosted,
    required String email,
    required String password,
    String? oneTimePassword,
    String? secret,
  }) async {
    loginCalls++;
    if (loginGate != null) await loginGate!.future;
    throw const NetworkException('offline');
  }

  final resetCalls = <String>[];

  @override
  Future<String?> sendTwoFactorResetCode({
    required String baseUrl,
    required bool isHosted,
    required String email,
  }) async {
    resetCalls.add('send $email');
    if (sendGate != null) await sendGate!.future;
    if (sendError != null) throw sendError!;
    return 'Code sent.';
  }

  @override
  Future<String?> confirmTwoFactorReset({
    required String baseUrl,
    required bool isHosted,
    required String email,
    required String code,
  }) async {
    resetCalls.add('confirm $email $code');
    if (confirmError != null) throw confirmError!;
    return 'SMS verified, 2FA disabled.';
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

const _passwordOnly = LoginPrecheck(
  methods: {'password'},
  secretRequired: false,
);
const _withTotp = LoginPrecheck(
  methods: {'password', 'totp'},
  secretRequired: false,
);

Finder _key(String key) => find.byKey(ValueKey(key));

/// The `TextField` inside a keyed `AuthField` / `AuthPasswordField`.
Finder _input(String key) =>
    find.descendant(of: _key(key), matching: find.byType(TextField));

EditableText _editable(WidgetTester tester, String key) => tester.widget(
  find.descendant(of: _key(key), matching: find.byType(EditableText)),
);

void main() {
  late ToastController toasts;

  Future<_FakeAuth> pumpLogin(
    WidgetTester tester, {
    LoginPrecheck? precheck,
  }) async {
    final auth = _FakeAuth(precheckResult: precheck);
    toasts = ToastController();
    addTearDown(toasts.clearAll);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<Services>.value(value: _FakeServices(auth)),
          ChangeNotifierProvider<ToastController>.value(value: toasts),
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
    // Swallow the async asset-load report for the logo image — irrelevant to
    // the form under test.
    tester.takeException();
    return auth;
  }

  Future<void> goSelfHosted(WidgetTester tester) async {
    await tester.tap(find.text('Self-Hosted'));
    await tester.pump();
    await tester.enterText(_input('login_url'), 'https://ninja.example.com');
  }

  Future<void> continueWith(WidgetTester tester, String email) async {
    await tester.enterText(_input('login_email'), email);
    await tester.tap(_key('login_continue'));
    await tester.pumpAndSettle();
  }

  group('step 1', () {
    testWidgets('hosted shows only the email and Continue', (tester) async {
      await pumpLogin(tester);

      expect(find.text('Login'), findsOneWidget, reason: 'the card title');
      expect(_key('login_email'), findsOneWidget);
      expect(_key('login_continue'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(_key('login_url'), findsNothing);
      expect(_key('login_password'), findsNothing);
      expect(_key('login_otp'), findsNothing);
      expect(_key('login_secret'), findsNothing);
      expect(_key('login_signup'), findsOneWidget);
      expect(_key('login_check_status'), findsOneWidget);
    });

    testWidgets('self-hosted adds the server URL and drops hosted links', (
      tester,
    ) async {
      await pumpLogin(tester);
      await tester.tap(find.text('Self-Hosted'));
      await tester.pump();

      expect(find.text('Server URL'), findsOneWidget);
      // The secret belongs to step 2 now, and only when the server needs it.
      expect(find.textContaining('API secret'), findsNothing);
      expect(_key('login_signup'), findsNothing);
      expect(_key('login_check_status'), findsNothing);
    });

    testWidgets('social sign-in sits under Continue, on step 1 only', (
      tester,
    ) async {
      // Apple is offered only where its native flow exists.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await pumpLogin(tester, precheck: _passwordOnly);
        expect(_key('login_apple'), findsOneWidget);
        expect(find.text('OR'), findsOneWidget, reason: "React's casing");

        await continueWith(tester, 'a@b.com');
        expect(_key('login_apple'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('an invalid email is flagged inline, with no toast', (
      tester,
    ) async {
      final auth = await pumpLogin(tester);
      await continueWith(tester, 'not-an-email');

      expect(find.text('Email is invalid'), findsOneWidget);
      expect(toasts.toasts, isEmpty);
      expect(auth.precheckCalls, 0);
      expect(_key('login_password'), findsNothing);
    });
  });

  group('step 1 while Continue is in flight', () {
    testWidgets('the server URL is read-only, not disabled', (tester) async {
      // A disabled field drops focus and never gives it back.
      final auth = await pumpLogin(tester);
      await goSelfHosted(tester);
      await tester.enterText(_input('login_email'), 'a@b.com');
      final gate = auth.precheckGate = Completer<void>();

      await tester.tap(_key('login_continue'));
      await tester.pump();
      final url = tester.widget<TextField>(_input('login_url'));
      expect(url.readOnly, isTrue);
      expect(url.enabled, isNot(false));

      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('the email field keeps the keyboard up (next, not done)', (
      tester,
    ) async {
      await pumpLogin(tester);
      expect(
        tester.widget<TextField>(_input('login_email')).textInputAction,
        TextInputAction.next,
      );
    });
  });

  group('step 2', () {
    testWidgets('Continue shows the credentials and focuses the password', (
      tester,
    ) async {
      await pumpLogin(tester, precheck: _passwordOnly);
      await continueWith(tester, 'a@b.com');

      expect(_key('login_email_confirmed'), findsOneWidget);
      expect(
        _editable(tester, 'login_email_confirmed').controller.text,
        'a@b.com',
      );
      expect(_editable(tester, 'login_email_confirmed').readOnly, isTrue);
      expect(_key('login_change'), findsOneWidget);
      expect(_key('login_forgot_password'), findsOneWidget);
      expect(find.text('Forgot your password?'), findsOneWidget);
      expect(_key('login_submit'), findsOneWidget);
      expect(_key('login_continue'), findsNothing);
      // Password-only account: nothing optional to show.
      expect(_key('login_otp'), findsNothing);
      expect(_key('login_disable_2fa'), findsNothing);
      expect(_editable(tester, 'login_password').focusNode.hasFocus, isTrue);
    });

    testWidgets('a confirmed TOTP account gets a required code field', (
      tester,
    ) async {
      await pumpLogin(tester, precheck: _withTotp);
      await continueWith(tester, 'a@b.com');

      expect(find.text('2FA - One Time Password'), findsOneWidget);
      expect(find.textContaining('(Optional)'), findsNothing);
      expect(_key('login_disable_2fa'), findsOneWidget, reason: 'hosted');
    });

    testWidgets('an unanswered precheck shows both optional fields', (
      tester,
    ) async {
      await pumpLogin(tester);
      await goSelfHosted(tester);
      await continueWith(tester, 'a@b.com');

      expect(find.text('2FA - One Time Password (Optional)'), findsOneWidget);
      expect(find.text('API secret (Optional)'), findsOneWidget);
      expect(_key('login_disable_2fa'), findsNothing);
    });

    testWidgets(
      'Enter on the password moves to an empty required code, not the eye',
      (tester) async {
        final auth = await pumpLogin(tester, precheck: _withTotp);
        await continueWith(tester, 'a@b.com');

        await tester.enterText(_input('login_password'), 'hunter2');
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pump();

        expect(_editable(tester, 'login_otp').focusNode.hasFocus, isTrue);
        expect(
          auth.loginCalls,
          0,
          reason: 'a login without the code must fail',
        );
      },
    );

    testWidgets('Enter on the password submits past an optional code field', (
      tester,
    ) async {
      final auth = await pumpLogin(tester);
      await continueWith(tester, 'a@b.com');
      expect(_key('login_otp'), findsOneWidget, reason: 'optional, unanswered');

      await tester.enterText(_input('login_password'), 'hunter2');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(auth.loginCalls, 1);
      // The fake's network failure is request-level, so it is toasted.
      expect(toasts.toasts, hasLength(1));
      // Cancel the auto-dismiss timer before the binding checks for pending
      // timers (which runs before tearDown).
      toasts.clearAll();
    });

    testWidgets('Enter logs in without moving focus when nothing is missing', (
      tester,
    ) async {
      // The password field's action is `next` (a required code follows), so
      // without its no-op `onEditingComplete` the framework would move focus
      // to the reveal button before `onSubmitted` logs in.
      final auth = await pumpLogin(tester, precheck: _withTotp);
      await continueWith(tester, 'a@b.com');
      await tester.enterText(_input('login_otp'), '123456');
      await tester.enterText(_input('login_password'), 'hunter2');

      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();

      expect(auth.loginCalls, 1);
      expect(_editable(tester, 'login_password').focusNode.hasFocus, isTrue);
      toasts.clearAll();
    });

    testWidgets('Forgot your password? spins while the email is sent', (
      tester,
    ) async {
      final auth = await pumpLogin(tester, precheck: _passwordOnly);
      await continueWith(tester, 'a@b.com');
      final gate = auth.recoverGate = Completer<void>();

      await tester.tap(_key('login_forgot_password'));
      await tester.pump();
      expect(
        find.descendant(
          of: _key('login_forgot_password'),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      gate.complete();
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: _key('login_forgot_password'),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
      expect(
        toasts.toasts.single.message,
        'Check your email for a reset link.',
      );
      toasts.clearAll();
    });

    testWidgets('the Login button stops on an empty confirmed code', (
      tester,
    ) async {
      // The server would answer with a 400 toast and spend one of hosted's
      // four login attempts a minute.
      final auth = await pumpLogin(tester, precheck: _withTotp);
      await continueWith(tester, 'a@b.com');
      await tester.enterText(_input('login_password'), 'hunter2');

      await tester.tap(_key('login_submit'));
      await tester.pumpAndSettle();

      expect(auth.loginCalls, 0);
      expect(find.text('Please enter a value'), findsOneWidget);
      expect(toasts.toasts, isEmpty, reason: 'inline, not a toast');
      expect(_editable(tester, 'login_otp').focusNode.hasFocus, isTrue);
    });

    testWidgets('sign-up is disabled while a login is in flight', (
      tester,
    ) async {
      final auth = await pumpLogin(tester, precheck: _passwordOnly);
      await continueWith(tester, 'a@b.com');
      await tester.enterText(_input('login_password'), 'hunter2');
      final gate = auth.loginGate = Completer<void>();

      await tester.tap(_key('login_submit'));
      await tester.pump();
      expect(tester.widget<TextButton>(_key('login_signup')).onPressed, isNull);

      gate.complete();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextButton>(_key('login_signup')).onPressed,
        isNotNull,
      );
      toasts.clearAll();
    });

    testWidgets('Change returns to step 1 with the email kept', (tester) async {
      await pumpLogin(tester, precheck: _passwordOnly);
      await continueWith(tester, 'a@b.com');
      final group = tester.state(find.byType(AutofillGroup));

      await tester.tap(_key('login_change'));
      await tester.pumpAndSettle();

      expect(_key('login_continue'), findsOneWidget);
      expect(_editable(tester, 'login_email').controller.text, 'a@b.com');
      expect(_editable(tester, 'login_email').focusNode.hasFocus, isTrue);
      // The same group survived the switch — a torn-down one would have
      // committed its autofill context (an OS "save password" prompt).
      expect(tester.state(find.byType(AutofillGroup)), same(group));
    });

    testWidgets('Android back on step 2 returns to step 1', (tester) async {
      await pumpLogin(tester, precheck: _passwordOnly);
      await continueWith(tester, 'a@b.com');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(_key('login_continue'), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('Disable 2FA (SMS reset)', () {
    testWidgets('send → verify disables 2FA and drops the code field', (
      tester,
    ) async {
      final auth = await pumpLogin(tester, precheck: _withTotp);
      await continueWith(tester, 'a@b.com');

      await tester.tap(_key('login_disable_2fa'));
      await tester.pumpAndSettle();
      // Starts on the form's address.
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('disable_2fa_email')))
            .controller!
            .text,
        'a@b.com',
      );
      await tester.tap(_key('disable_2fa_send'));
      await tester.pumpAndSettle();
      expect(auth.resetCalls, ['send a@b.com']);

      // Verify stays disabled until six digits are in.
      FilledButton verify() => tester.widget<FilledButton>(
        find.descendant(
          of: _key('disable_2fa_verify'),
          matching: find.byType(FilledButton),
          matchRoot: true,
        ),
      );
      await tester.enterText(_key('disable_2fa_code'), '12345');
      await tester.pump();
      expect(verify().onPressed, isNull);
      await tester.enterText(_key('disable_2fa_code'), '123456');
      await tester.pump();
      expect(verify().onPressed, isNotNull);

      await tester.tap(_key('disable_2fa_verify'));
      await tester.pumpAndSettle();

      expect(auth.resetCalls.last, 'confirm a@b.com 123456');
      expect(find.byType(AlertDialog), findsNothing);
      expect(_key('login_otp'), findsNothing);
      expect(_key('login_disable_2fa'), findsNothing);
      expect(_editable(tester, 'login_password').focusNode.hasFocus, isTrue);
      expect(toasts.toasts.map((t) => t.message), [
        'A code has been sent via SMS',
        'Successfully disabled 2FA',
      ]);
      toasts.clearAll();
    });

    testWidgets('Send cannot be dismissed while it is in flight', (
      tester,
    ) async {
      // A Send dismissed mid-flight still texts a code — one of hosted's
      // twelve a day — with no Verify dialog left to type it into.
      final auth = await pumpLogin(tester, precheck: _withTotp);
      await continueWith(tester, 'a@b.com');
      await tester.tap(_key('login_disable_2fa'));
      await tester.pumpAndSettle();
      final gate = auth.sendGate = Completer<void>();

      await tester.tap(_key('disable_2fa_send'));
      await tester.pump();
      await tester.tapAt(const Offset(4, 4)); // the barrier
      await tester.pump();
      await tester.binding.handlePopRoute(); // Android back
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Disable Two Factor'), findsOneWidget, reason: 'Verify');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      toasts.clearAll();
    });

    testWidgets('a rejected address shows under the dialog field', (
      tester,
    ) async {
      final auth = await pumpLogin(tester, precheck: _withTotp);
      await continueWith(tester, 'a@b.com');
      await tester.tap(_key('login_disable_2fa'));
      await tester.pumpAndSettle();
      auth.sendError = const ValidationException(
        'The given data was invalid.',
        {
          'email': ['The selected email is invalid.'],
        },
      );

      await tester.tap(_key('disable_2fa_send'));
      await tester.pumpAndSettle();

      expect(find.text('The selected email is invalid.'), findsOneWidget);
      expect(toasts.toasts, isEmpty, reason: 'inline, not a toast');
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.enterText(_key('disable_2fa_email'), 'x@b.com');
      await tester.pump();
      expect(find.text('The selected email is invalid.'), findsNothing);
    });

    Future<void> openVerify(WidgetTester tester) async {
      await tester.tap(_key('login_disable_2fa'));
      await tester.pumpAndSettle();
      await tester.tap(_key('disable_2fa_send'));
      await tester.pumpAndSettle();
      expect(find.text('Disable Two Factor'), findsOneWidget);
    }

    testWidgets('Verify cannot be cancelled while a resend is in flight', (
      tester,
    ) async {
      final auth = await pumpLogin(tester, precheck: _withTotp);
      await continueWith(tester, 'a@b.com');
      await openVerify(tester);
      final gate = auth.sendGate = Completer<void>();

      await tester.tap(_key('disable_2fa_resend'));
      await tester.pump();
      TextButton cancel() =>
          tester.widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'));
      expect(cancel().onPressed, isNull);

      gate.complete();
      await tester.pumpAndSettle();
      expect(cancel().onPressed, isNotNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      toasts.clearAll();
    });

    testWidgets('a timed-out Verify keeps the typed code, now optional', (
      tester,
    ) async {
      // The server may already have turned 2FA off, so the code field turns
      // optional — but the code the user typed stays visible and is sent.
      final auth = await pumpLogin(tester, precheck: _withTotp);
      await continueWith(tester, 'a@b.com');
      await tester.enterText(_input('login_otp'), '123456');
      await openVerify(tester);
      auth.confirmError = const NetworkException('timed out');

      await tester.enterText(_key('disable_2fa_code'), '654321');
      await tester.pump();
      await tester.tap(_key('disable_2fa_verify'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget, reason: 'stays open');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('2FA - One Time Password (Optional)'), findsOneWidget);
      expect(_editable(tester, 'login_otp').controller.text, '123456');
      toasts.clearAll();
    });

    testWidgets('cancelling the first dialog changes nothing', (tester) async {
      final auth = await pumpLogin(tester, precheck: _withTotp);
      await continueWith(tester, 'a@b.com');

      await tester.tap(_key('login_disable_2fa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(auth.resetCalls, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
      expect(_key('login_otp'), findsOneWidget);
    });
  });

  group('AuthField label row', () {
    Widget host(Widget child) => MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(body: Center(child: child)),
    );

    testWidgets('lays out under IntrinsicWidth (as in an AlertDialog)', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const IntrinsicWidth(
            child: AuthPasswordField(
              label: 'Password',
              labelTrailing: Text('Forgot your password?'),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Forgot your password?'), findsOneWidget);
    });

    testWidgets('wraps the trailing widget beneath when it does not fit', (
      tester,
    ) async {
      Future<(double, double)> rows(double width) async {
        await tester.pumpWidget(
          host(
            SizedBox(
              width: width,
              child: const AuthPasswordField(
                label: 'Password',
                labelTrailing: Text('Forgot your password?'),
              ),
            ),
          ),
        );
        return (
          tester.getTopLeft(find.text('Password')).dy,
          tester.getTopLeft(find.text('Forgot your password?')).dy,
        );
      }

      // The test font is monospace at the font size (~400 px for the pair).
      final (wideLabel, wideLink) = await rows(700);
      expect(wideLink, closeTo(wideLabel, 4), reason: 'one row when it fits');
      final (narrowLabel, narrowLink) = await rows(320);
      expect(narrowLink, greaterThan(narrowLabel + 8), reason: 'wrapped');
    });
  });
}
