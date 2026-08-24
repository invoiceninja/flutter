import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/user.dart';
import 'package:admin/data/repositories/user_repository.dart';
import 'package:admin/data/services/users_api.dart';
import 'package:admin/ui/features/settings/views/advanced/user_management/view_models/user_edit_view_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// `StoreUserRequest` marks first name, last name and email `required|bail`,
/// but the create form only gated the first and third — so saving without a
/// last name toasted "Successfully created user" and left a dead 422 row in
/// the outbox (invoiceninja/flutter#66).
class _FakeUsersApi implements UsersApi {
  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  UserEditViewModel vmFor({User? existing}) => UserEditViewModel(
    repo: UserRepository(db: db, api: _FakeUsersApi()),
    companyId: 'co',
    existing: existing,
    firstNameRequiredMessage: 'Please enter a first name',
    lastNameRequiredMessage: 'Please enter a last name',
    emailRequiredMessage: 'Please enter your email',
  );

  Future<int> pendingOutboxCount() async {
    final rows = await db.outboxDao.nextReady(companyId: 'co', now: 1 << 60);
    return rows.length;
  }

  test('a blank create is rejected on every required field', () async {
    final vm = vmFor();

    expect(await vm.save(), isNull);
    expect(vm.fieldErrorFor('first_name'), 'Please enter a first name');
    expect(vm.fieldErrorFor('last_name'), 'Please enter a last name');
    expect(vm.fieldErrorFor('email'), 'Please enter your email');
    // Nothing optimistic was written — that is the whole point.
    expect(await pendingOutboxCount(), 0);
  });

  test('a missing last name alone still blocks the save', () async {
    final vm = vmFor()
      ..setFirstName('Ada')
      ..setEmail('ada@example.com');

    expect(await vm.save(), isNull);
    expect(vm.fieldErrorFor('first_name'), isNull);
    expect(vm.fieldErrorFor('last_name'), 'Please enter a last name');
    expect(vm.fieldErrorFor('email'), isNull);
    expect(await pendingOutboxCount(), 0);
  });

  test('whitespace is not a name', () async {
    final vm = vmFor()
      ..setFirstName('  ')
      ..setLastName('Lovelace')
      ..setEmail('ada@example.com');

    expect(await vm.save(), isNull);
    expect(vm.fieldErrorFor('first_name'), 'Please enter a first name');
  });

  test('a complete create enqueues one outbox row', () async {
    final vm = vmFor()
      ..setFirstName('Ada')
      ..setLastName('Lovelace')
      ..setEmail('ada@example.com');

    expect(await vm.save(), isNotNull);
    expect(vm.fieldErrors, isEmpty);
    expect(await pendingOutboxCount(), 1);
  });

  test('edit mode does not re-impose the create-only name rules', () async {
    // `UpdateUserRequest` marks email `sometimes` and says nothing about the
    // names, so a legacy record with a blank one has to stay editable.
    const existing = User(id: 'u1', firstName: 'Ada', email: 'ada@x.com');
    final vm = vmFor(existing: existing)..setPhone('555');

    expect(await vm.save(), isNotNull);
    expect(vm.fieldErrors, isEmpty);
  });
}
