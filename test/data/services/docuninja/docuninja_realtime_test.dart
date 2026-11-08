import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/data/repositories/docuninja/docuninja_session.dart';
import 'package:admin/data/services/docuninja/docuninja_client.dart';
import 'package:admin/data/services/docuninja/docuninja_login_api.dart';
import 'package:admin/data/services/docuninja/docuninja_realtime.dart';
import 'package:admin/data/services/realtime/pusher_connection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Connection implements PusherConnection {
  final events$ = StreamController<PusherEvent>.broadcast();
  final subscribed = <String>[];
  ChannelAuthorizer? authorizer;
  var connects = 0;
  var disconnects = 0;

  @override
  Stream<PusherEvent> get events => events$.stream;

  @override
  void subscribe(
    String channel,
    ChannelAuthorizer authorize, {
    String slot = kDefaultChannelSlot,
  }) {
    subscribed.add(channel);
    authorizer = authorize;
  }

  @override
  void unsubscribe({String? slot}) => subscribed.add('-');

  @override
  void connect() => connects++;

  @override
  void disconnect() => disconnects++;

  @override
  void dispose() => events$.close();

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _LoginApi implements DocuNinjaLoginApi {
  @override
  Future<DnLogin> login() async => DnLogin.fromJson(
    jsonDecode(File('test/fixtures/docuninja/login.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// DocuNinja's live updates follow the session, are signed by DocuNinja,
/// and only ever ask the screens to re-read.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DocuNinjaSession session;
  late _Connection connection;
  late List<http.Request> authCalls;

  setUp(() {
    session = DocuNinjaSession(
      loginApi: _LoginApi(),
      auth: ValueNotifier<AuthSession?>(
        AuthSession(
          baseUrl: 'https://invoicing.co',
          isHosted: true,
          accountId: 'a',
          companies: [
            AuthCompany(
              id: 'co1',
              name: 'Acme',
              displayName: 'Acme',
              permissions: '',
              isAdmin: true,
              isOwner: true,
            ),
          ],
          currentCompanyId: 'co1',
        ),
      ),
      companyKeyOf: (_) async => 'ninja-company-key-1',
    );
    connection = _Connection();
    authCalls = [];
  });

  DocuNinjaRealtime realtime() => DocuNinjaRealtime(
    session: session,
    client: DocuNinjaClient(
      tokens: session,
      httpClient: MockClient((r) async {
        authCalls.add(r);
        return http.Response(jsonEncode({'auth': 'key:sig'}), 200);
      }),
    ),
    connection: connection,
  );

  test('connects to the paired company\'s channel once ready', () async {
    final r = realtime();
    expect(connection.connects, 0, reason: 'nothing before the handshake');
    await session.load();
    final companyId = session.value.company!.id;
    expect(connection.subscribed.last, 'private-company-$companyId');
    expect(connection.connects, 1);

    // Signed by DocuNinja's broadcasting auth with the company token.
    final auth = await connection.authorizer!('1.2', 'private-company-x');
    expect(auth, 'key:sig');
    expect(
      authCalls.single.url.toString(),
      'https://api.docuninja.co/broadcasting/auth',
    );
    expect(
      authCalls.single.headers['Authorization'],
      'Bearer ${session.token}',
    );
    r.dispose();
  });

  test('a signature or new previews ask the screens to re-read', () async {
    final r = realtime();
    await session.load();
    final channel = connection.subscribed.last;
    connection.events$
      ..add(
        PusherEvent(
          channel: channel,
          event: r'App\Events\Document\DocumentWasSigned',
          data: const {},
        ),
      )
      ..add(
        PusherEvent(
          channel: channel,
          event: r'App\Events\Invoice\InvoiceWasPaid',
          data: const {},
        ),
      )
      ..add(
        PusherEvent(
          channel: 'private-company-other',
          event: r'App\Events\Document\DocumentWasSigned',
          data: const {},
        ),
      );
    await Future<void>.delayed(Duration.zero);
    expect(session.remoteChanged.value, 1);
    r.dispose();
  });

  test('a reset (sign-out, company switch) disconnects', () async {
    final r = realtime();
    await session.load();
    session.reset();
    expect(connection.disconnects, greaterThan(0));
    expect(connection.subscribed.last, '-');
    r.dispose();
  });
}
