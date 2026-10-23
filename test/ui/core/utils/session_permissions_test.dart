import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/utils/session_permissions.dart';

class _FakeAuth implements AuthRepository {
  _FakeAuth(this._session);
  final ValueListenable<AuthSession?> _session;
  @override
  ValueListenable<AuthSession?> get session => _session;
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

AuthSession _session({
  String permissions = '',
  bool isAdmin = false,
  bool isOwner = false,
}) => AuthSession(
  baseUrl: '',
  isHosted: false,
  accountId: '',
  currentCompanyId: 'co',
  companies: [
    AuthCompany(
      id: 'co',
      name: 'Co',
      displayName: 'Co',
      permissions: permissions,
      isAdmin: isAdmin,
      isOwner: isOwner,
    ),
  ],
);

/// The four buttons that lead to an admin-only `/new` route — Add gateway,
/// New task status (kanban), New group (assign-group dialog) and the report's
/// Schedule — ask [sessionMayCreate]. It must answer as the router's `/new`
/// bounce does, or a tap goes nowhere with nothing said.
void main() {
  Future<Map<EntityType, bool>> answers(
    WidgetTester tester,
    AuthSession? session,
  ) async {
    late Map<EntityType, bool> out;
    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(_FakeAuth(ValueNotifier(session))),
        child: Builder(
          builder: (context) {
            out = {
              for (final type in const [
                EntityType.companyGateway,
                EntityType.taskStatus,
                EntityType.group,
                EntityType.schedule,
                EntityType.client,
              ])
                type: sessionMayCreate(context, type),
            };
            return const SizedBox();
          },
        ),
      ),
    );
    return out;
  }

  testWidgets('an admin may create every settings type', (tester) async {
    final got = await answers(tester, _session(isAdmin: true));
    expect(got.values, everyElement(isTrue));
  });

  testWidgets('the owner counts as an admin', (tester) async {
    final got = await answers(tester, _session(isOwner: true));
    expect(got.values, everyElement(isTrue));
  });

  testWidgets('create_all does not reach the admin-only settings types', (
    tester,
  ) async {
    final got = await answers(tester, _session(permissions: 'create_all'));
    expect(got, {
      EntityType.companyGateway: false,
      EntityType.taskStatus: false,
      EntityType.group: false,
      EntityType.schedule: false,
      EntityType.client: true,
    });
  });

  testWidgets('no session means no', (tester) async {
    final got = await answers(tester, null);
    expect(got.values, everyElement(isFalse));
  });
}
