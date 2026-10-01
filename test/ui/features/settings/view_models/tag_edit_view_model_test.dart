import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/tag_repository.dart';
import 'package:admin/data/services/tags_api.dart';
import 'package:admin/ui/features/settings/view_models/tag_edit_view_model.dart';

/// The server rejects a tag name containing a comma (invoiceninja/ui#3371);
/// the edit screen must say so inline, as the comma is typed, and never let
/// the save reach the outbox.
void main() {
  late AppDatabase db;
  late TagEditViewModel vm;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    vm = TagEditViewModel(
      repo: TagRepository(db: db, api: _UnusedTagsApi()),
      companyId: 'co1',
      entityType: 'task',
      commasNotAllowedMessage: 'Commas are not allowed',
    );
  });

  tearDown(() async {
    vm.dispose();
    await db.close();
  });

  test('typing a comma shows the error immediately', () {
    vm.setName('vip');
    expect(vm.fieldErrorFor('name'), isNull);

    vm.setName('vip,');
    expect(vm.fieldErrorFor('name'), 'Commas are not allowed');
  });

  test('removing the comma clears the error', () {
    vm.setName('vip, gold');
    vm.setName('vip gold');
    expect(vm.fieldErrorFor('name'), isNull);
  });

  test('save is blocked before anything is queued', () async {
    vm.setName('a,b');
    await vm.save();

    expect(vm.fieldErrorFor('name'), 'Commas are not allowed');
    expect(vm.localValidationOnly, isTrue);
    expect(await db.select(db.outbox).get(), isEmpty);
  });
}

class _UnusedTagsApi implements TagsApi {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('validation must not reach the API');
}
