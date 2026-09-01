import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/user.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/user_repository.dart';
import 'package:admin/ui/core/widgets/initials_avatar.dart';
import 'package:admin/ui/core/widgets/user_avatar.dart';

import '../../../_localization_helper.dart';

/// Resolves user watches from an in-memory map (id → User) so the StreamBuilder
/// settles synchronously — no Drift stream, no `pumpAndSettle` timeout.
class _FakeUserRepo implements UserRepository {
  _FakeUserRepo(this.byId);
  final Map<String, User> byId;

  /// Every watch this widget opens, in call order — lets a test assert the
  /// company it resolved against.
  final List<({String companyId, String id})> calls = [];

  @override
  Stream<User?> watch({required String companyId, required String id}) {
    calls.add((companyId: companyId, id: id));
    return Stream<User?>.value(byId[id]);
  }

  // Cold peek cache: keeps these tests on the async watch path (and out of
  // `calls`), exactly as before `BaseEntityRepository.peek` existed.
  @override
  User? peek({required String companyId, required String id}) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeAuth implements AuthRepository {
  _FakeAuth(this._session);
  final ValueListenable<AuthSession?> _session;
  @override
  ValueListenable<AuthSession?> get session => _session;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeServices implements Services {
  _FakeServices({required this.auth, required this.user});
  @override
  final AuthRepository auth;
  @override
  final UserRepository user;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late _FakeUserRepo users;
  late _FakeServices services;

  setUp(() {
    final ada = const User().copyWith(
      id: 'u1',
      firstName: 'Ada',
      lastName: 'Lovelace',
    );
    users = _FakeUserRepo({'u1': ada});
    final session = ValueNotifier<AuthSession?>(
      const AuthSession(
        baseUrl: '',
        isHosted: false,
        accountId: '',
        companies: [],
        currentCompanyId: 'session-co',
      ),
    );
    services = _FakeServices(auth: _FakeAuth(session), user: users);
  });

  Future<void> pump(
    WidgetTester tester,
    String userId, {
    String? companyId,
  }) async {
    await tester.pumpWidget(
      Provider<Services>.value(
        value: services,
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            body: Center(
              child: UserAvatar(userId: userId, companyId: companyId),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the initials of a user in the local roster', (
    tester,
  ) async {
    await pump(tester, 'u1');
    expect(find.text('AL'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsNothing);
  });

  testWidgets('renders the unassigned placeholder for an empty id', (
    tester,
  ) async {
    await pump(tester, '');
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.byType(InitialsAvatar), findsNothing);
    // Nothing to watch — an unassigned row must not open a subscription.
    expect(users.calls, isEmpty);
  });

  testWidgets('renders a tinted "?" for an id the roster cannot resolve — an '
      'ex-employee id is still an assignment, so it must not fall back to the '
      'unassigned placeholder', (tester) async {
    await pump(tester, 'ghost');
    expect(find.text('?'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsNothing);
    expect(find.text('ghost'), findsNothing);
  });

  testWidgets('keeps the leading-slot footprint whether assigned or not', (
    tester,
  ) async {
    await pump(tester, 'u1');
    expect(tester.getSize(find.byType(UserAvatar)), const Size(32, 32));

    await pump(tester, '');
    expect(tester.getSize(find.byType(UserAvatar)), const Size(32, 32));
  });

  testWidgets('resolves against the caller-supplied company', (tester) async {
    await pump(tester, 'u1', companyId: 'co-explicit');
    expect(users.calls.first.companyId, 'co-explicit');
  });

  testWidgets('falls back to the session company when none is passed', (
    tester,
  ) async {
    await pump(tester, 'u1');
    expect(users.calls.first.companyId, 'session-co');
  });
}
