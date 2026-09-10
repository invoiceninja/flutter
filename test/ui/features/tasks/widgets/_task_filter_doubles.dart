// Shared doubles for the Tasks filter surfaces: the filter bar, the filter
// sheet and the calendar header all need the same `Services` shape and the same
// filter notifier, and three hand-copied sets is how they drift.
//
// Not a `_test.dart` file, so the runner ignores it — the convention
// `test/ui/features/dashboard/_fake_dashboard_repo.dart` and
// `test/ui/features/shell/_shell_test_helpers.dart` already use.

import 'package:flutter/foundation.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/api/calendar_connection_api_model.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/project_api_model.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/models/domain/user.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/calendar_connection_repository.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/project_repository.dart';
import 'package:admin/data/repositories/user_repository.dart';
import 'package:admin/ui/features/tasks/view_models/task_filters_mixin.dart';

/// The whole filter state, with no view model, no Drift and no repositories.
class TaskFiltersDouble extends ChangeNotifier with TaskFiltersMixin {}

/// A one-value stream that survives re-subscription.
///
/// `Stream.multi`, not `Stream.value`: a `StreamBuilder` re-subscribes on every
/// rebuild and a single-subscription stream throws the second time — the
/// finding `activity_filter_sheet_test.dart` records.
Stream<T> oneShot<T>(T value) => Stream<T>.multi((c) {
  c.add(value);
  c.close();
});

final Project kFakeProject = Project.fromApi(
  const ProjectApi(id: 'p1', name: 'Website redesign'),
);

final Client kFakeClient = Client.fromApi(
  const ClientApi(id: 'c1', name: 'Acme Corp'),
);

final User kFakeUser = const User().copyWith(
  id: 'u1',
  firstName: 'Ada',
  lastName: 'Lovelace',
);

class FakeProjectRepo implements ProjectRepository {
  @override
  Stream<List<({String id, String name})>> watchActiveNames({
    required String companyId,
  }) => oneShot([(id: kFakeProject.id, name: kFakeProject.name)]);

  @override
  Stream<Project?> watch({required String companyId, required String id}) =>
      oneShot(kFakeProject);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeClientRepo implements ClientRepository {
  @override
  Stream<List<({String id, String name})>> watchActiveNames({
    required String companyId,
  }) => oneShot([(id: kFakeClient.id, name: kFakeClient.name)]);

  @override
  Stream<Client?> watch({required String companyId, required String id}) =>
      oneShot(kFakeClient);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeUserRepo implements UserRepository {
  @override
  Stream<List<User>> watchAllForPicker({required String companyId}) =>
      oneShot([kFakeUser]);

  @override
  Stream<User?> watch({required String companyId, required String id}) =>
      oneShot(kFakeUser);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeAuthRepo implements AuthRepository {
  FakeAuthRepo({bool isHosted = false})
    : session = ValueNotifier<AuthSession?>(
        AuthSession(
          baseUrl: '',
          isHosted: isHosted,
          accountId: '',
          companies: const [],
          currentCompanyId: 'co',
        ),
      );

  @override
  final ValueNotifier<AuthSession?> session;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Seeded before the view model is built, so `CalendarConnectionViewModel`'s
/// constructor sees a value and reports `statusLoaded` — the menu renders
/// nothing until it does, which would quietly make a width test measure the
/// *empty* menu, i.e. the one state that already fits.
class FakeCalendarConnectionRepo implements CalendarConnectionRepository {
  FakeCalendarConnectionRepo({CalendarConnection? connection})
    : connectionState = ValueNotifier<CalendarConnection?>(connection);

  @override
  final ValueNotifier<CalendarConnection?> connectionState;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Only the four repositories these surfaces actually reach; everything else
/// throws, so a new dependency shows up as a failing test rather than as a
/// silent live call.
class FakeServices implements Services {
  FakeServices({bool isHosted = false})
    : auth = FakeAuthRepo(isHosted: isHosted);

  @override
  final AuthRepository auth;
  @override
  final ProjectRepository projects = FakeProjectRepo();
  @override
  final ClientRepository clients = FakeClientRepo();
  @override
  final UserRepository user = FakeUserRepo();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
