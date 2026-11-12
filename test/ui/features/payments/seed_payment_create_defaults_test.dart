// A new payment takes its Type from Settings → Online Payments → Default
// Payment Type (`payment_type_id`, cascading client → group → company), as
// v1 and React did. The server never applies it, so without this the user
// picked "Check" on every payment though Check was their default
// (beta-user report).

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/data/repositories/payment_repository.dart';
import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/data/services/payments_api.dart';
import 'package:admin/ui/features/payments/seed_payment_create_defaults.dart';
import 'package:admin/ui/features/payments/view_models/payment_edit_view_model.dart';

class _UnusedPaymentsApi implements PaymentsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// `payment_type_id` per layer: `null` is the company, else a client id.
class _Settings extends SettingsRepository {
  _Settings(AppDatabase db) : super(db: db);

  final types = <String?, Object?>{};

  Map<String, dynamic> _layer(String? clientId) => {
    'payment_type_id': types.containsKey(clientId)
        ? types[clientId]
        : types[null],
  };

  @override
  Future<Map<String, dynamic>> resolved({
    required String companyId,
    String? clientId,
  }) async => _layer(clientId);

  @override
  Map<String, dynamic>? resolvedIfReady({
    required String companyId,
    String? clientId,
  }) => null;
}

void main() {
  late AppDatabase db;
  late PaymentRepository repo;
  late _Settings settings;
  const companyId = 'co_1';

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = PaymentRepository(db: db, api: _UnusedPaymentsApi());
    settings = _Settings(db);
  });
  tearDown(() => db.close());

  PaymentEditViewModel seeded({Payment? existing, Payment? staged}) {
    final vm = PaymentEditViewModel(
      repo: repo,
      companyId: companyId,
      existing: existing,
      cloneFrom: staged,
    );
    seedPaymentCreateDefaults(settings: settings, companyId: companyId, vm: vm);
    return vm;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('defaultPaymentTypeId reads the server\'s "0" and an int', () {
    expect(defaultPaymentTypeId({'payment_type_id': '0'}), '');
    expect(defaultPaymentTypeId({}), '');
    expect(defaultPaymentTypeId({'payment_type_id': 6}), '6');
    expect(defaultPaymentTypeId({'payment_type_id': '6'}), '6');
  });

  test(
    'a new payment opens on the company default, and is not dirty',
    () async {
      settings.types[null] = '6';
      final vm = seeded();
      await settle();
      expect(vm.draft.typeId, '6');
      expect(vm.isDirty, isFalse);
    },
  );

  test('Enter Payment from an invoice seeds the client\'s cascade', () async {
    settings.types[null] = '6';
    settings.types['c1'] = '1';
    final vm = seeded(staged: emptyPayment().copyWith(clientId: 'c1'));
    await settle();
    expect(vm.draft.typeId, '1');
  });

  test(
    'the type follows a newly picked client until the user picks one',
    () async {
      settings.types[null] = '6';
      settings.types['c1'] = '1';
      final vm = seeded();
      await settle();
      vm.setClientId('c1');
      await settle();
      expect(vm.draft.typeId, '1');

      vm.setTypeId('2');
      vm.setClientId('c2');
      await settle();
      expect(vm.draft.typeId, '2');
    },
  );

  test('a clone keeps its source\'s type', () async {
    settings.types[null] = '6';
    final vm = seeded(staged: emptyPayment().copyWith(typeId: '3'));
    await settle();
    expect(vm.draft.typeId, '3');
  });

  test('an existing payment is never seeded', () async {
    settings.types[null] = '6';
    final vm = seeded(
      existing: emptyPayment().copyWith(id: 'p1', clientId: 'c1'),
    );
    await settle();
    expect(vm.draft.typeId, '');
  });

  test('a Discard re-applies the company default', () async {
    settings.types[null] = '6';
    final vm = seeded();
    await settle();
    vm.setTypeId('2');
    vm.resetToEmpty();
    expect(vm.draft.typeId, '6');
  });
}
