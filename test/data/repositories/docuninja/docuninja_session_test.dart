import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/data/repositories/docuninja/docuninja_session.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/docuninja/docuninja_login_api.dart';
import 'package:admin/domain/docuninja/docuninja_access.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _LoginApi implements DocuNinjaLoginApi {
  Future<DnLogin> Function() answer = () async =>
      throw const DocuNinjaRefused();
  int calls = 0;

  @override
  Future<DnLogin> login() {
    calls++;
    return answer();
  }

  @override
  Future<void> createAccount() async {}
}

DnLogin _fixtureLogin() => DnLogin.fromJson(
  jsonDecode(File('test/fixtures/docuninja/login.json').readAsStringSync())
      as Map<String, dynamic>,
);

AuthSession _auth({
  bool hosted = true,
  int seats = 0,
  String company = 'co1',
}) => AuthSession(
  baseUrl: 'https://invoicing.co',
  isHosted: hosted,
  accountId: 'a',
  companies: [
    AuthCompany(
      id: company,
      name: 'Acme',
      displayName: 'Acme',
      permissions: '',
      isAdmin: true,
      isOwner: true,
    ),
  ],
  currentCompanyId: company,
  docuninjaNumUsers: seats,
);

void main() {
  late _LoginApi api;
  late ValueNotifier<AuthSession?> auth;
  late Map<String, String> keys;

  DocuNinjaSession session() => DocuNinjaSession(
    loginApi: api,
    auth: auth,
    companyKeyOf: (id) async => keys[id],
  );

  setUp(() {
    api = _LoginApi();
    auth = ValueNotifier(_auth());
    keys = {'co1': 'ninja-company-key-1', 'co2': 'ninja-company-key-2'};
  });

  test(
    'ready: pairs the IN company with its DocuNinja company and token',
    () async {
      api.answer = () async => _fixtureLogin();
      final s = session();
      await s.load();
      expect(s.value.access, DocuNinjaAccess.ready);
      expect(s.value.company?.name, 'Test Company');
      expect(s.token, 'dn-test-token');
    },
  );

  test('an IN company DocuNinja does not know is company setup', () async {
    api.answer = () async => _fixtureLogin();
    keys['co1'] = 'some-other-company';
    final s = session();
    await s.load();
    expect(s.value.access, DocuNinjaAccess.companySetup);
    expect(s.token, isNull);
  });

  test('a refusal is Join, or no access when the account has seats', () async {
    final s = session();
    await s.load();
    expect(s.value.access, DocuNinjaAccess.notJoined);

    auth.value = _auth(seats: 2);
    s.reset();
    await s.load();
    expect(s.value.access, DocuNinjaAccess.noAccess);
  });

  test('offline is offline, and self-hosted never calls the server', () async {
    api.answer = () async => throw const NetworkException('down');
    final s = session();
    await s.load();
    expect(s.value.access, DocuNinjaAccess.offline);

    auth.value = _auth(hosted: false);
    s.reset();
    api.calls = 0;
    await s.load();
    expect(s.value.access, DocuNinjaAccess.unavailable);
    expect(api.calls, 0);
  });

  test('loads once, shares a request, and reloads only when forced', () async {
    final answer = Completer<DnLogin>();
    api.answer = () => answer.future;
    final s = session();
    final a = s.load();
    final b = s.load();
    answer.complete(_fixtureLogin());
    await Future.wait([a, b]);
    expect(api.calls, 1);
    await s.load();
    expect(api.calls, 1);
    expect(await s.refreshToken(), 'dn-test-token');
    expect(api.calls, 2);
  });

  test('an answer that lands after a reset is dropped', () async {
    final answer = Completer<DnLogin>();
    api.answer = () => answer.future;
    final s = session();
    final pending = s.load();
    // The user switches company while the handshake is out.
    s.reset();
    auth.value = _auth(company: 'co2');
    answer.complete(_fixtureLogin());
    await pending;
    expect(s.value.access, DocuNinjaAccess.unavailable);
    expect(s.token, isNull);

    // The new company loads its own pairing.
    api.answer = () async => _fixtureLogin();
    await s.load();
    expect(s.value.company?.name, 'The Beatles');
  });
}
