import 'package:admin/app/serving_server_parse.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/login_response_api_model.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/auth_service.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/token_storage.dart';
import 'package:admin/data/services/web_oauth.dart';
import 'package:admin/data/services/web_sign_in.dart';
import 'package:admin/ui/features/auth/view_models/login_view_model.dart';
import 'package:admin/ui/features/auth/view_models/signup_view_model.dart';
import 'package:admin/ui/features/auth/view_models/social_sign_in.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Google, Microsoft and Apple on the web build (docs/web-deploy.md § Web
/// sign-in): which page offers which, what reaches `oauth_login`, and what
/// the user is told when a window or the server says no.

/// Records the `oauth_login` call, then answers with [reply].
class _OAuthService implements AuthService {
  _OAuthService(this.reply);

  Object reply;
  final calls = <Map<String, Object?>>[];

  @override
  Future<LoginResponseApi> oauthLogin({
    required String baseUrl,
    required String provider,
    required bool isHosted,
    String? idToken,
    String? authCode,
    String? accessToken,
    String? email,
    String? firstName,
    String? lastName,
    bool create = false,
  }) async {
    calls.add({
      'baseUrl': baseUrl,
      'provider': provider,
      'accessToken': accessToken,
      'idToken': idToken,
      'create': create,
    });
    throw reply;
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

const _hosted = ServingServer(
  apiUrl: 'https://invoicing.co',
  isHosted: true,
  googleClientId: 'g.apps.googleusercontent.com',
  microsoftClientId: 'ms-hosted',
  appleClientId: 'com.invoiceninja.client',
);

const _selfHosted = ServingServer(
  apiUrl: 'https://ninja.example.com/sub',
  isHosted: false,
  // A server can't name these, but if one did they must stay off.
  googleClientId: 'g.apps.googleusercontent.com',
  microsoftClientId: 'ms-own',
  appleClientId: 'com.example',
);

void main() {
  tearDown(WebSignIn.reset);

  group('WebSignIn gates', () {
    test('the hosted page offers all three, Microsoft returning to itself', () {
      WebSignIn.debugIsWeb = true;
      WebSignIn.configure(
        _hosted,
        pageOrigin: 'https://admin.invoicing.co',
        secureContext: true,
      );
      expect(WebSignIn.googleEnabled, isTrue);
      expect(WebSignIn.microsoftEnabled, isTrue);
      expect(WebSignIn.appleEnabled, isTrue);
      expect(WebSignIn.microsoftRedirectUri, 'https://admin.invoicing.co');
      expect(WebSignIn.appleRedirectUri, 'https://admin.invoicing.co');
    });

    test('a self-hosted page offers only its own Microsoft app', () {
      WebSignIn.debugIsWeb = true;
      WebSignIn.configure(
        _selfHosted,
        pageOrigin: 'https://ninja.example.com',
        secureContext: true,
      );
      expect(WebSignIn.googleEnabled, isFalse);
      expect(WebSignIn.appleEnabled, isFalse);
      expect(WebSignIn.microsoftEnabled, isTrue);
      expect(WebSignIn.microsoftClientId, 'ms-own');
      // admin-portal's redirect URI, so the admin's Azure entry still matches.
      expect(WebSignIn.microsoftRedirectUri, 'https://ninja.example.com/sub');
    });

    test('an empty client ID hides that provider', () {
      WebSignIn.debugIsWeb = true;
      WebSignIn.configure(
        const ServingServer(apiUrl: 'https://invoicing.co', isHosted: true),
        pageOrigin: 'https://admin.invoicing.co',
        secureContext: true,
      );
      expect(WebSignIn.googleEnabled, isFalse);
      expect(WebSignIn.microsoftEnabled, isFalse);
      expect(WebSignIn.appleEnabled, isFalse);
    });

    test('a self-hosted page on plain http offers nothing', () {
      // MSAL can't hash without crypto.subtle, which only a secure page has.
      WebSignIn.debugIsWeb = true;
      WebSignIn.configure(
        _selfHosted,
        pageOrigin: 'http://192.168.0.10:8080',
        secureContext: false,
      );
      expect(WebSignIn.microsoftEnabled, isFalse);
    });

    test('nothing is offered off the web, or on a page no server served', () {
      WebSignIn.configure(_hosted, pageOrigin: '', secureContext: true);
      WebSignIn.debugIsWeb = false;
      expect(WebSignIn.googleEnabled, isFalse);
      expect(WebSignIn.microsoftEnabled, isFalse);
      expect(WebSignIn.appleEnabled, isFalse);

      WebSignIn.debugIsWeb = true;
      WebSignIn.configure(
        null,
        pageOrigin: 'http://localhost:8080',
        secureContext: true,
      );
      expect(WebSignIn.googleEnabled, isFalse);
      expect(WebSignIn.microsoftEnabled, isFalse);
      expect(WebSignIn.appleEnabled, isFalse);
    });
  });

  group('signInWithMicrosoft', () {
    late AppDatabase db;
    late _OAuthService service;
    late AuthRepository auth;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      service = _OAuthService(const NetworkException('offline'));
      auth = AuthRepository(
        db: db,
        authService: service,
        tokenStorage: InMemoryTokenStorage(),
        passwordCache: PasswordCache(),
      );
      WebSignIn.debugIsWeb = true;
      WebSignIn.configure(
        _hosted,
        pageOrigin: 'https://admin.invoicing.co',
        secureContext: true,
      );
    });
    tearDown(() => db.close());

    Future<Object?> run({bool create = false}) async {
      try {
        return await signInWithMicrosoft(
          auth: auth,
          baseUrl: 'https://invoicing.co',
          isHosted: true,
          create: create,
        );
      } on SocialSignInFailure catch (f) {
        return f;
      }
    }

    test("sends MSAL's access token as provider microsoft", () async {
      WebSignIn.debugMicrosoftAccessToken = () async => 'graph-token';
      final result = await run(create: true);
      expect(service.calls, [
        {
          'baseUrl': 'https://invoicing.co',
          'provider': 'microsoft',
          'accessToken': 'graph-token',
          'idToken': null,
          'create': true,
        },
      ]);
      // The fake then fails like an offline network.
      expect(
        (result! as SocialSignInFailure).key,
        'network_error_with_message',
      );
    });

    test(
      'a closed window is a quiet false that never reaches the server',
      () async {
        WebSignIn.debugMicrosoftAccessToken = () async => null;
        expect(await run(), isFalse);
        expect(service.calls, isEmpty);
      },
    );

    test('a blocked window and an unloaded script each say so', () async {
      WebSignIn.debugMicrosoftAccessToken = () =>
          Future.error(const WebOAuthException(WebOAuthFailure.blocked));
      expect((await run() as SocialSignInFailure).key, 'web_sign_in_blocked');

      WebSignIn.debugMicrosoftAccessToken = () =>
          Future.error(const WebOAuthException(WebOAuthFailure.notLoaded));
      expect((await run() as SocialSignInFailure).key, 'web_sign_in_loading');
      expect(service.calls, isEmpty);
    });

    test('off where Microsoft is not offered', () async {
      WebSignIn.debugIsWeb = false;
      WebSignIn.debugMicrosoftAccessToken = () async => 'graph-token';
      expect(await run(), isFalse);
      expect(service.calls, isEmpty);
    });

    test('the window opens straight from the tap, on both screens', () {
      // A browser blocks a window opened after the tap's activation runs out,
      // so nothing may be awaited before the provider is asked. Not awaiting
      // the submit and finding the provider already called pins that.
      var asked = 0;
      WebSignIn.debugMicrosoftAccessToken = () async {
        asked++;
        return null;
      };
      WebSignIn.debugGoogleAccessToken = () async {
        asked++;
        return null;
      };
      final login = LoginViewModel(auth: auth, served: _hosted);
      final signup = SignupViewModel(auth: auth, served: _hosted)
        ..setAcceptedTerms(true);
      addTearDown(login.dispose);
      addTearDown(signup.dispose);

      login.submitMicrosoft().ignore();
      expect(asked, 1);
      login.submitGoogle().ignore();
      // Busy with the first: the second tap asks nothing.
      expect(asked, 1);
      signup.submitMicrosoft().ignore();
      expect(asked, 2);
    });

    test('Google on the hosted page is asked straight from the tap too', () {
      var asked = 0;
      WebSignIn.debugGoogleAccessToken = () async {
        asked++;
        return null;
      };
      final login = LoginViewModel(auth: auth, served: _hosted);
      addTearDown(login.dispose);

      login.submitGoogle().ignore();
      expect(asked, 1);
    });

    group("the server's refusals, in plain words", () {
      Future<SocialSignInFailure> refused(String message) async {
        WebSignIn.debugMicrosoftAccessToken = () async => 'graph-token';
        service.reply = ServerException(400, message);
        return (await run())! as SocialSignInFailure;
      }

      test(
        'an unknown account on a self-hosted page has no signup to name',
        () async {
          WebSignIn.debugMicrosoftAccessToken = () async => 'graph-token';
          service.reply = const ServerException(400, 'User not found.');
          Object? f;
          try {
            await signInWithMicrosoft(
              auth: auth,
              baseUrl: 'https://ninja.example.com',
              isHosted: false,
            );
          } on SocialSignInFailure catch (e) {
            f = e;
          }
          expect((f! as SocialSignInFailure).key, 'oauth_user_not_found_here');
        },
      );

      test('an unknown account', () async {
        final f = await refused(
          'User not found. If you believe this is an error, please send an '
          'email to contact@invoiceninja.com',
        );
        expect(f.key, 'oauth_user_not_found');
        expect(f.params, {'provider': 'Microsoft'});
      });

      test('a password account', () async {
        final f = await refused(
          'User exists, but never authenticated with OAuth, please use your '
          'email and password to login.',
        );
        expect(f.key, 'oauth_email_uses_password');
      });

      test('an account on another provider', () async {
        final f = await refused(
          'This email is already linked to google sign-in. Please sign in '
          'with google.',
        );
        expect(f.key, 'oauth_email_uses_provider');
        expect(f.params, {'provider': 'Google'});
      });

      test('anything else is the server text', () async {
        final f = await refused('Invalid Microsoft token: audience mismatch.');
        expect(f.key, isNull);
        expect(f.message, 'Invalid Microsoft token: audience mismatch.');
      });
    });
  });
}
