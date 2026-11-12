// A new payment takes its Type from Settings → Online Payments → Default
// Payment Type (`payment_type_id`, cascading client → group → company), as
// v1 and React did. The server never applies it, so without this the user
// picked "Check" on every payment though Check was their default
// (beta-user report).

import 'dart:async';

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

/// The client lookups, programmable per client.
class _Lookups {
  final overrides = <String, String>{};
  final local = <String, String>{};

  /// What the server refresh adds to [local] when it lands.
  final remote = <String, String>{};
  final hidden = <String>{};

  /// When set, each refresh waits for the test to complete it.
  Completer<void>? holdRefresh;
  var refreshes = 0;

  PaymentClientLookups get lookups => PaymentClientLookups(
    clientOverride: (id) async => overrides[id] ?? '',
    lastPaymentType: (id) async => local[id],
    refreshLastPayment: (id) async {
      refreshes++;
      await holdRefresh?.future;
      final r = remote[id];
      if (r == null) return false;
      local[id] = r;
      return true;
    },
    hiddenTypeIds: () => hidden,
  );
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

  PaymentEditViewModel seeded({
    Payment? existing,
    Payment? staged,
    _Lookups? client,
  }) {
    final vm = PaymentEditViewModel(
      repo: repo,
      companyId: companyId,
      existing: existing,
      cloneFrom: staged,
    );
    seedPaymentCreateDefaults(
      settings: settings,
      companyId: companyId,
      vm: vm,
      client: client?.lookups,
    );
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

  // invoiceninja/flutter#191: remember each client's payment type.
  group('the client\'s last payment', () {
    late _Lookups client;
    setUp(() {
      settings.types[null] = '6';
      client = _Lookups();
    });

    Payment forClient(String id) => emptyPayment().copyWith(clientId: id);

    test('beats the group / company default, with the hint', () async {
      client.local['c1'] = '1';
      final vm = seeded(staged: forClient('c1'), client: client);
      await settle();
      expect(vm.draft.typeId, '1');
      expect(vm.typeSeedSource, PaymentTypeSeedSource.lastPayment);
      expect(vm.isDirty, isTrue, reason: 'a staged client is unsaved work');
    });

    test('the same value as the default shows no hint', () async {
      client.local['c1'] = '6';
      final vm = seeded(staged: forClient('c1'), client: client);
      await settle();
      expect(vm.draft.typeId, '6');
      expect(vm.typeSeedSource, PaymentTypeSeedSource.settings);
    });

    test('loses to a Default Payment Type set on the client itself', () async {
      settings.types['c1'] = '2';
      client.overrides['c1'] = '2';
      client.local['c1'] = '1';
      final vm = seeded(staged: forClient('c1'), client: client);
      await settle();
      expect(vm.draft.typeId, '2');
    });

    test('a hidden last type falls through to the default', () async {
      client.local['c1'] = '1';
      client.hidden.add('1');
      final vm = seeded(staged: forClient('c1'), client: client);
      await settle();
      expect(vm.draft.typeId, '6');
    });

    test('seeds from Drift first, then from the server refresh', () async {
      client.local['c1'] = '1';
      client.remote['c1'] = '3';
      client.holdRefresh = Completer<void>();
      final vm = seeded(staged: forClient('c1'), client: client);
      await settle();
      expect(vm.draft.typeId, '1', reason: 'offline answer first');
      client.holdRefresh!.complete();
      await settle();
      expect(vm.draft.typeId, '3');
    });

    test('a late answer for a client the user left is dropped', () async {
      client.remote['c1'] = '3';
      client.local['c2'] = '4';
      client.holdRefresh = Completer<void>();
      final vm = seeded(client: client);
      vm.setClientId('c1');
      await settle();
      vm.setClientId('c2');
      client.holdRefresh!.complete();
      await settle();
      expect(vm.draft.typeId, '4');
    });

    test('never overwrites a type the user picked', () async {
      client.remote['c1'] = '3';
      client.holdRefresh = Completer<void>();
      final vm = seeded(staged: forClient('c1'), client: client);
      await settle();
      vm.setTypeId('2');
      expect(vm.typeSeedSource, PaymentTypeSeedSource.none);
      client.holdRefresh!.complete();
      await settle();
      expect(vm.draft.typeId, '2');
    });

    test('without a client only the company default applies', () async {
      final vm = seeded(client: client);
      await settle();
      expect(vm.draft.typeId, '6');
      expect(client.refreshes, 0);
    });
  });
}
