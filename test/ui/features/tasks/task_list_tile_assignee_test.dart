import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/user.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/user_repository.dart';
import 'package:admin/ui/core/widgets/selection_checkbox.dart';
import 'package:admin/ui/core/widgets/user_avatar.dart';
import 'package:admin/ui/features/tasks/widgets/task_list_tile.dart';

import '../../../_localization_helper.dart';

/// The leading assigned-user badge on task rows (invoiceninja/flutter#57):
/// present in both layouts, empty-but-reserved when unassigned, and yielding
/// to the selection checkbox in multi-select.
///
/// Deliberately NOT on `_shell_test_helpers.buildFixture` like its sibling
/// `task_list_tile_test.dart`: that fixture's real in-memory Drift database
/// can't drive a `watch` stream inside a widget test — mounting one wedges the
/// test until it times out. The repo is faked with `Stream.value` instead, so
/// the badge resolves synchronously.
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

final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

Task _task({String assignedUserId = ''}) => Task(
  id: 't1',
  number: '1',
  description: 'Task',
  rate: Decimal.zero,
  invoiceId: '',
  clientId: '',
  projectId: '',
  statusId: '',
  statusOrder: 0,
  assignedUserId: assignedUserId,
  timeLog: const [],
  customValue1: '',
  customValue2: '',
  customValue3: '',
  customValue4: '',
  updatedAt: _epoch,
  createdAt: _epoch,
  archivedAt: null,
  isDeleted: false,
);

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
        currentCompanyId: 'co1',
      ),
    );
    services = _FakeServices(
      auth: _FakeAuth(session),
      user: _FakeUserRepo({'u1': ada}),
    );
  });

  Future<void> pumpTile(
    WidgetTester tester, {
    required Task task,
    required bool wide,
    bool selecting = false,
  }) async {
    await tester.pumpWidget(
      Provider<Services>.value(
        value: services,
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            // No onAction: the ⋮ menu is irrelevant here and overflows its
            // fixed slot under the plain test font.
            body: TaskListTile(
              task: task,
              companyId: 'co1',
              columns: const [],
              wide: wide,
              selecting: selecting,
              onTap: () {},
              onSelectTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final wide in [true, false]) {
    final mode = wide ? 'wide' : 'narrow';

    testWidgets('$mode: shows the assigned user\'s initials', (tester) async {
      await pumpTile(
        tester,
        task: _task(assignedUserId: 'u1'),
        wide: wide,
      );
      expect(find.text('AL'), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsNothing);
    });

    testWidgets('$mode: resolves against the row\'s own company rather than '
        'the session, so a company switch mid-flight can\'t mis-resolve it', (
      tester,
    ) async {
      await pumpTile(
        tester,
        task: _task(assignedUserId: 'u1'),
        wide: wide,
      );
      final avatar = tester.widget<UserAvatar>(find.byType(UserAvatar));
      expect(avatar.companyId, 'co1');
      expect(avatar.userId, 'u1');
    });

    testWidgets('$mode: an unassigned task shows the empty-slot placeholder', (
      tester,
    ) async {
      await pumpTile(tester, task: _task(), wide: wide);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      expect(find.text('AL'), findsNothing);
    });

    testWidgets('$mode: multi-select swaps the badge for the checkbox', (
      tester,
    ) async {
      await pumpTile(
        tester,
        task: _task(assignedUserId: 'u1'),
        wide: wide,
        selecting: true,
      );
      expect(find.byType(UserAvatar), findsNothing);
      expect(find.byType(SelectionCheckbox), findsOneWidget);
    });
  }
}
