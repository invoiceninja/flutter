import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/vendor_api_model.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/data/repositories/vendor_repository.dart';
import 'package:admin/data/services/vendors_api.dart';
import 'package:admin/ui/features/vendors/view_models/vendor_edit_view_model.dart';

/// First coverage for `VendorEditViewModel` — it was the only core-entity edit
/// VM with zero references anywhere under `test/`.
///
/// Two behaviours matter. `validate()` must block an empty-name create before
/// the optimistic Drift write, so the user gets an inline error instead of a
/// dead outbox row (`StoreVendorRequest` requires `name`). And
/// `draftIsNonEmpty()` drives the discard-changes prompt: the blank primary
/// contact seeded on a new vendor must NOT count as user input, but a contact
/// the user actually typed into must.
class _FakeVendorsApi implements VendorsApi {
  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  late VendorRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = VendorRepository(db: db, api: _FakeVendorsApi());
  });
  tearDown(() async => db.close());

  VendorEditViewModel createVm() => VendorEditViewModel(
    repo: repo,
    companyId: 'co',
    nameRequiredMessage: 'name required',
  );

  VendorEditViewModel editVm(Vendor existing) => VendorEditViewModel(
    repo: repo,
    companyId: 'co',
    nameRequiredMessage: 'name required',
    existing: existing,
  );

  Vendor existingVendor({String name = 'Acme Supplies'}) =>
      Vendor.fromApi(VendorApi(id: 'v1', name: name, updatedAt: 1700000000));

  Future<int> pendingOutboxCount() async {
    final rows = await db.outboxDao.nextReady(companyId: 'co', now: 1 << 60);
    return rows.length;
  }

  group('validate (create)', () {
    test('blocks an empty name — inline error, no local write', () async {
      final vm = createVm();

      final saved = await vm.save();

      expect(saved, isNull);
      expect(vm.fieldErrorFor('name'), 'name required');
      expect(vm.localValidationOnly, isTrue);
      expect(
        await pendingOutboxCount(),
        0,
        reason: 'a blocked create must not enqueue an outbox row',
      );
    });

    test('blocks a whitespace-only name', () async {
      final vm = createVm()..setName('   ');

      expect(await vm.save(), isNull);
      expect(vm.fieldErrorFor('name'), 'name required');
    });

    test('passes with a name — performs the optimistic create', () async {
      final vm = createVm()..setName('Acme Supplies');

      final saved = await vm.save();

      expect(saved, isNotNull);
      expect(vm.fieldErrors, isEmpty);
      expect(await pendingOutboxCount(), 1);
    });
  });

  group('validate (edit)', () {
    test('still blocks a blanked name on an existing vendor', () async {
      final vm = editVm(existingVendor())..setName('');

      expect(await vm.save(), isNull);
      expect(vm.fieldErrorFor('name'), 'name required');
    });

    test('a valid edit enqueues an update', () async {
      final vm = editVm(existingVendor())..setName('Renamed');

      expect(await vm.save(), isNotNull);
      expect(await pendingOutboxCount(), 1);
    });
  });

  group('draftIsNonEmpty drives the discard prompt', () {
    test('a fresh create is empty', () {
      expect(createVm().draftIsNonEmpty(), isFalse);
    });

    test('any filled identity field marks it dirty', () {
      expect((createVm()..setName('A')).draftIsNonEmpty(), isTrue);
      expect((createVm()..setNumber('V-1')).draftIsNonEmpty(), isTrue);
    });

    test('an existing vendor reads as non-empty', () {
      expect(editVm(existingVendor()).draftIsNonEmpty(), isTrue);
    });
  });

  test('resetToEmpty clears the draft back to a blank vendor', () {
    final vm = createVm()..setName('Typed');
    expect(vm.draftIsNonEmpty(), isTrue);

    vm.resetToEmpty();

    expect(vm.draftIsNonEmpty(), isFalse);
    expect(vm.draft.name, isEmpty);
  });

  test('cloneFrom seeds the draft without marking it an edit', () {
    final vm = VendorEditViewModel(
      repo: repo,
      companyId: 'co',
      nameRequiredMessage: 'name required',
      cloneFrom: existingVendor(name: 'Source'),
    );

    expect(vm.draft.name, 'Source');
    expect(
      vm.isCreate,
      isTrue,
      reason: 'a clone saves as a new vendor, not an update to the source',
    );
  });
}
