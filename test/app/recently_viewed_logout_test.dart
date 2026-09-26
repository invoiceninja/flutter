import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/data/models/api/login_response_api_model.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/domain/entity_type.dart';

import '../ui/features/shell/_shell_test_helpers.dart';

/// The recently-viewed list across the three ways a session ends, through the
/// real `Services.build` wiring.
///
/// Its reset used to sit in `onBeforeLogout`, which also runs on the 401 / idle
/// re-lock (`LocalDataPolicy.keep`): the same user signing straight back in
/// found their command palette's Recent group empty, although the nav_state
/// behind it was kept. It now runs from `onBeforeDataWipe`, i.e. only when the
/// data goes — a destructive sign-out, or a different identity's sign-in over
/// kept data.
LoginResponseApi _envelope(String userId) => LoginResponseApi(
  data: [
    UserCompanyApi(
      permissions: '',
      isAdmin: true,
      isOwner: true,
      user: UserSummaryApi(id: userId),
      company: const CompanyEnvelopeApi(id: 'co_a', name: 'Acme'),
      token: const SessionTokenApi(token: 'tok_a'),
      account: const AccountEnvelopeApi(
        id: 'acct1',
        defaultCompanyId: 'co_a',
        plan: 'pro',
      ),
    ),
  ],
);

void main() {
  late ShellFixture fixture;
  final logins = <String>[];

  setUp(() async {
    logins.clear();
    fixture = await buildFixture(
      companies: const [FakeCompany(id: 'co_a', name: 'Acme', token: 'tok_a')],
      httpClient: MockClient((req) async {
        if (req.url.path == '/api/v1/login') {
          return http.Response(
            jsonEncode(_envelope(logins.removeAt(0)).toJson()),
            200,
          );
        }
        return http.Response('{"data":[]}', 200);
      }),
    );
  });

  tearDown(() => fixture.dispose());

  Future<void> loginAs(String userId) async {
    logins.add(userId);
    await fixture.services.auth.login(
      baseUrl: 'https://example.com',
      isHosted: true,
      email: '$userId@example.com',
      password: 'pw',
    );
    fixture.services.refreshScheduler.stop();
  }

  List<String> recentIds() =>
      fixture.services.recentlyViewed.items.map((r) => r.id).toList();

  Future<void> signInAndView() async {
    await loginAs('user_a');
    fixture.services.recentlyViewed.record(
      type: EntityType.client,
      id: 'cl_1',
      label: 'Private client',
    );
    expect(recentIds(), ['cl_1']);
  }

  test('a kept-data logout and the same user back keeps the recents', () async {
    await signInAndView();
    await fixture.services.auth.logout(data: LocalDataPolicy.keep);
    await loginAs('user_a');

    expect(recentIds(), [
      'cl_1',
    ], reason: 'a 401 re-login is the same user; nothing was wiped');
  });

  test('a destructive sign-out clears them', () async {
    await signInAndView();
    await fixture.services.auth.logout(data: LocalDataPolicy.destroy);
    await loginAs('user_a');

    expect(recentIds(), isEmpty);
  });

  test('a kept-data logout and a DIFFERENT user clears them', () async {
    await signInAndView();
    await fixture.services.auth.logout(data: LocalDataPolicy.keep);
    await loginAs('user_b');

    expect(
      recentIds(),
      isEmpty,
      reason: "user B's palette must not list user A's records",
    );
  });
}
