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
import 'package:admin/ui/core/widgets/user_name_label.dart';

import '../../../_localization_helper.dart';

/// Resolves user watches from an in-memory map (id → User) so the StreamBuilder
/// settles synchronously — no Drift stream, no `pumpAndSettle` timeout.
class _FakeUserRepo implements UserRepository {
  _FakeUserRepo(this.byId);
  final Map<String, User> byId;
  @override
  Stream<User?> watch({required String companyId, required String id}) =>
      Stream<User?>.value(byId[id]);
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
  late _FakeServices services;

  setUp(() {
    final ada = const User().copyWith(
      id: 'u1',
      firstName: 'Ada',
      lastName: 'Lovelace',
    );
    final session = ValueNotifier<AuthSession?>(
      const AuthSession(
        baseUrl: '',
        isHosted: false,
        accountId: '',
        companies: [],
        currentCompanyId: 'co',
      ),
    );
    services = _FakeServices(
      auth: _FakeAuth(session),
      user: _FakeUserRepo({'u1': ada}),
    );
  });

  Future<void> pump(WidgetTester tester, String userId) async {
    await tester.pumpWidget(
      Provider<Services>.value(
        value: services,
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            body: Center(child: UserNameLabel(userId: userId)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('resolves the display name from the local roster', (
    tester,
  ) async {
    await pump(tester, 'u1');
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('u1'), findsNothing);
  });

  testWidgets('falls back to the raw id for a user not in the roster', (
    tester,
  ) async {
    await pump(tester, 'ghost');
    expect(find.text('ghost'), findsOneWidget);
  });

  testWidgets('renders an em-dash for an empty id', (tester) async {
    await pump(tester, '');
    expect(find.text('—'), findsOneWidget);
  });
}
