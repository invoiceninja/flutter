import 'package:admin/app/env.dart';
import 'package:admin/app/serving_server_io.dart' as io;
import 'package:admin/app/router.dart';
import 'package:admin/app/serving_server_parse.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/login_response_api_model.dart';
import 'package:admin/data/repositories/auth/auth_helpers.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/auth_service.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/token_storage.dart';
import 'package:admin/ui/features/auth/view_models/login_view_model.dart';
import 'package:admin/ui/features/auth/view_models/signup_view_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// A web page an Invoice Ninja server served signs in to that server
/// (docs/web-deploy.md): the boot page's `data-*` attributes and the page's
/// own location decide the server, never `Env.hostedApiUrl`.

/// Records what the view models send, then fails like an offline network so
/// no session is persisted.
class _CapturingAuthService implements AuthService {
  String? loginBaseUrl;
  bool? loginIsHosted;
  String? signupBaseUrl;
  String? signupReferralCode;

  @override
  Future<LoginResponseApi> login({
    required String baseUrl,
    required bool isHosted,
    required String email,
    required String password,
    String? oneTimePassword,
    String? secret,
  }) async {
    loginBaseUrl = baseUrl;
    loginIsHosted = isHosted;
    throw const NetworkException('captured');
  }

  @override
  Future<LoginResponseApi> signup({
    required String baseUrl,
    required bool isHosted,
    required String email,
    required String password,
    String referralCode = '',
  }) async {
    signupBaseUrl = baseUrl;
    signupReferralCode = referralCode;
    throw const NetworkException('captured');
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

ServingServer? parse(
  Map<String, String> attributes, {
  String origin = 'https://invoicing.co',
  String pathname = '/',
}) => parseServingServer(
  attribute: (name) => attributes[name],
  origin: origin,
  pathname: pathname,
);

void main() {
  group('parseServingServer', () {
    test('a page without data-served="1" was not served', () {
      expect(parse({}), isNull);
      expect(parse({'data-served': '0', 'data-hosted': '1'}), isNull);
      expect(io.readServingServer(), isNull);
    });

    test('the API root is the page origin plus path, canonical and stable', () {
      String? url(String origin, String pathname) => parse(
        {'data-served': '1'},
        origin: origin,
        pathname: pathname,
      )?.apiUrl;

      expect(url('https://host', '/'), 'https://host');
      // A visit through index.php is the same server: a different canonical
      // URL would make AuthRepository wipe the local data on the next sign-in.
      expect(url('https://host', '/index.php'), 'https://host');
      expect(url('https://Host:443', '/'), 'https://host');
      expect(url('http://host:8000', '/'), 'http://host:8000');
      expect(url('https://host', '/ninja/index.php'), 'https://host/ninja');
      expect(url('https://host', '/ninja/'), 'https://host/ninja');
    });

    test('data-api-url names the server when the page is not on its host', () {
      // The hosted page on Cloudflare Pages: admin.invoicing.co serves the
      // app, invoicing.co is the API.
      final served = parse({
        'data-served': '1',
        'data-hosted': '1',
        'data-api-url': 'https://invoicing.co',
      }, origin: 'https://admin.invoicing.co')!;
      expect(served.apiUrl, 'https://invoicing.co');
      expect(served.isHosted, isTrue);
      // Byte-equal to the hosted URL a native sign-in stores, so signing in
      // on the web never reads as a different server and wipes local data.
      expect(served.apiUrl, canonicalBaseUrl(Env.hostedApiUrl));
      expect(
        parse({
          'data-served': '1',
          'data-api-url': ' https://Invoicing.co:443/ ',
        }, origin: 'https://admin.invoicing.co')!.apiUrl,
        'https://invoicing.co',
      );
    });

    test('an unusable data-api-url makes the page unserved, never a guess', () {
      for (final bad in [
        'invoicing.co',
        'ftp://invoicing.co',
        'https://',
        '/api',
        'not a url',
      ]) {
        expect(
          parse({'data-served': '1', 'data-api-url': bad}),
          isNull,
          reason: bad,
        );
      }
      // Blank is the same as absent: the page's own origin.
      expect(
        parse({'data-served': '1', 'data-api-url': '  '})!.apiUrl,
        'https://invoicing.co',
      );
    });

    test('flags are exact string matches, as the server writes them', () {
      final served = parse({
        'data-served': '1',
        'data-hosted': '1',
        'data-signup': 'true',
        'data-rc': ' ABC ',
        'data-white-label': '1',
      })!;
      expect(served.isHosted, isTrue);
      expect(served.signup, isTrue);
      expect(served.referralCode, 'ABC');
      expect(served.whiteLabel, isTrue);

      final plain = parse({
        'data-served': '1',
        'data-signup': 'false',
        'data-white-label': '',
      })!;
      expect(plain.isHosted, isFalse, reason: 'a missing data-hosted is false');
      expect(plain.signup, isFalse);
      expect(plain.referralCode, '');
      expect(plain.whiteLabel, isFalse);
    });
  });

  group('the login and signup view models use the page\'s server', () {
    late AppDatabase db;
    late _CapturingAuthService service;
    late AuthRepository auth;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      service = _CapturingAuthService();
      auth = AuthRepository(
        db: db,
        authService: service,
        tokenStorage: InMemoryTokenStorage(),
        passwordCache: PasswordCache(),
      );
    });
    tearDown(() => db.close());

    test(
      'a hosted page signs in to its own URL, not Env.hostedApiUrl',
      () async {
        const staging = ServingServer(
          apiUrl: 'https://staging.invoicing.co',
          isHosted: true,
        );
        final vm = LoginViewModel(auth: auth, served: staging)
          ..setEmail('a@b.test')
          ..setPassword('pw');
        expect(vm.isHosted, isTrue);
        await vm.submit();
        expect(service.loginBaseUrl, 'https://staging.invoicing.co');
        expect(service.loginIsHosted, isTrue);
      },
    );

    test(
      'a self-hosted page signs in to its own URL, even over http',
      () async {
        const lan = ServingServer(
          apiUrl: 'http://ninja.local',
          isHosted: false,
        );
        final vm = LoginViewModel(auth: auth, served: lan, isWeb: true)
          ..setEmail('a@b.test')
          ..setPassword('pw');
        expect(vm.isHosted, isFalse);
        // The platform can't be switched on a served page.
        vm.setHosted(true);
        expect(vm.isHosted, isFalse);
        await vm.submit();
        expect(service.loginBaseUrl, 'http://ninja.local');
        expect(service.loginIsHosted, isFalse);
        // The browser just loaded this page from that server: a certificate
        // isn't what failed, so no "open the server" hint.
        expect(vm.errorDetailKey, isNull);
        expect(vm.openServerUrl, isNull);
        expect(vm.trustedCertificateForUrl, isNull);
      },
    );

    test(
      'a hosted page signs up on its own URL with its referral code',
      () async {
        const page = ServingServer(
          apiUrl: 'https://demo.invoicing.co',
          isHosted: true,
          referralCode: 'FRIEND',
        );
        final vm = SignupViewModel(auth: auth, served: page)
          ..setEmail('a@b.test')
          ..setPassword('password1')
          ..setConfirmPassword('password1')
          ..setAcceptedTerms(true);
        await vm.submit();
        expect(service.signupBaseUrl, 'https://demo.invoicing.co');
        expect(service.signupReferralCode, 'FRIEND');
      },
    );
  });

  test(
    'a self-hosted page blocks /signup; everywhere else it is reachable',
    () {
      expect(
        signupRedirect(
          loggedIn: false,
          location: '/signup',
          signupAllowed: false,
        ),
        '/login',
      );
      expect(
        signupRedirect(
          loggedIn: false,
          location: '/signup',
          signupAllowed: true,
        ),
        isNull,
      );
      expect(
        signupRedirect(
          loggedIn: false,
          location: '/login',
          signupAllowed: false,
        ),
        isNull,
      );
      expect(
        signupRedirect(
          loggedIn: true,
          location: '/signup',
          signupAllowed: false,
        ),
        isNull,
        reason: 'a signed-in user is bounced by the general auth-page rule',
      );
    },
  );
}
