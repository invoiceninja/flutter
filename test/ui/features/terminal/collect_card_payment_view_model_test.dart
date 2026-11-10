import 'dart:async';
import 'package:admin/app/terminal_controller.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/terminal_models.dart';
import 'package:admin/data/models/domain/invoice_status.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/terminal_server_error.dart';
import 'package:admin/data/services/token_storage.dart';
import 'package:admin/ui/features/invoices/view_models/invoice_edit_view_model.dart';
import 'package:admin/ui/features/terminal/view_models/collect_card_payment_view_model.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:store_services/store_services.dart';

import '_terminal_fakes.dart';

void main() {
  late AppDatabase db;
  late AuthRepository auth;
  late DevicePrefsStore prefs;
  late FakeTerminalRepo repo;
  late FakeTerminalPlatform platform;
  late TerminalController terminal;
  late DateTime now;
  var ids = 0;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final authService = FakeAuthService();
    auth = AuthRepository(
      db: db,
      authService: authService,
      tokenStorage: InMemoryTokenStorage(),
      passwordCache: PasswordCache(),
    );
    authService.queueLogin(fakeEnvelope());
    await auth.login(
      baseUrl: 'https://test',
      isHosted: false,
      email: 'a',
      password: 'b',
    );
    prefs = DevicePrefsStore(db);
    await prefs.load();
    repo = FakeTerminalRepo();
    platform = FakeTerminalPlatform();
    terminal = TerminalController(
      repository: repo,
      platform: platform,
      auth: auth,
      prefs: prefs,
      platformReady: true,
    );
    now = DateTime(2026, 11, 10, 12);
    ids = 0;
  });
  tearDown(() async {
    terminal.dispose();
    await db.close();
  });

  final invoice = emptyInvoice().copyWith(
    id: 'inv_1',
    statusId: InvoiceStatus.sent,
    amount: Decimal.fromInt(100),
    balance: Decimal.fromInt(100),
  );

  Future<CollectCardPaymentViewModel> ready() async {
    final vm = CollectCardPaymentViewModel(
      companyId: 'co_a',
      invoice: invoice,
      terminal: terminal,
      repository: repo,
      isAdmin: true,
      merchantDisplayName: 'Acme',
      precision: 2,
      clock: () => now,
      newId: () => 'col_${++ids}',
      pollDelay: Duration.zero,
    );
    await vm.start();
    expect(vm.readerState, ReaderState.ready);
    expect(vm.canCollect, isTrue);
    return vm;
  }

  test(
    'a card is read, the server decides, and the charge is recorded',
    () async {
      final vm = await ready();
      repo.creates.add(fakeIntent());
      platform.session.reads.add(fakeCard);
      repo.finalizes.add(fakeFinalize(10000));
      platform.session.confirms.add(
        const TerminalPaymentOutcome(
          paymentIntentId: 'pi_1',
          status: 'succeeded',
        ),
      );
      repo.completes.add(fakeCompletion('recorded'));

      await vm.collect();

      expect(vm.stage, CollectStage.approved);
      expect(repo.calls.where((c) => c.startsWith('create')), [
        'create:col_1:100',
      ]);
      expect(platform.session.calls, ['collect', 'confirm:pi_1:10000']);
      expect(repo.calls, isNot(contains(startsWith('cancel'))));
    },
  );

  test('surcharge on a credit card: raised, read again, charged at the raised '
      'amount', () async {
    final vm = await ready();
    vm.setSurcharge(true);
    await pumpEventQueue();
    expect(vm.quote!.total, Decimal.fromInt(103));
    repo.creates.add(fakeIntent());
    platform.session.reads
      ..add(fakeCard)
      ..add(fakeRead(10300));
    repo.finalizes
      ..add(fakeFinalize(10300, recollect: true))
      ..add(fakeFinalize(10300));
    platform.session.confirms.add(
      const TerminalPaymentOutcome(
        paymentIntentId: 'pi_1',
        status: 'succeeded',
      ),
    );
    repo.completes.add(fakeCompletion('recorded'));

    await vm.collect();

    expect(repo.calls, contains('create:col_1:103'));
    expect(platform.session.calls, [
      'collect',
      'collect',
      'confirm:pi_1:10300',
    ]);
    expect(vm.stage, CollectStage.approved);
  });

  test(
    'a debit card on the second read is charged the lowered amount',
    () async {
      final vm = await ready();
      repo.creates.add(fakeIntent());
      platform.session.reads
        ..add(fakeCard)
        ..add(fakeRead(10300, funding: 'debit'))
        ..add(fakeRead(10000, funding: 'debit'));
      repo.finalizes
        ..add(fakeFinalize(10300, recollect: true))
        ..add(fakeFinalize(10000, recollect: true))
        ..add(fakeFinalize(10000));
      platform.session.confirms.add(
        const TerminalPaymentOutcome(
          paymentIntentId: 'pi_1',
          status: 'succeeded',
        ),
      );
      repo.completes.add(fakeCompletion('recorded'));

      await vm.collect();

      expect(platform.session.calls.last, 'confirm:pi_1:10000');
    },
  );

  test(
    'a finalize that fails cancels; nothing is charged on a guess',
    () async {
      final vm = await ready();
      repo.creates.add(fakeIntent());
      platform.session.reads.add(fakeCard);
      repo.finalizes.add(const NetworkException('timeout'));
      repo.cancels.add(fakeCompletion('canceled'));

      await vm.collect();

      expect(platform.session.calls, ['collect', 'cancel']);
      expect(repo.calls, contains('cancel:pi_1'));
      expect(vm.stage, CollectStage.cancelled);
    },
  );

  test(
    'too long between reading and finalizing: the card is read again',
    () async {
      final vm = await ready();
      repo.creates.add(fakeIntent());
      platform.session.reads
        ..add(fakeCard)
        ..add(fakeCard);
      final slow = Completer<TerminalFinalize>();
      repo.finalizes
        ..add(slow)
        ..add(fakeFinalize(10000));
      platform.session.confirms.add(
        const TerminalPaymentOutcome(
          paymentIntentId: 'pi_1',
          status: 'succeeded',
        ),
      );
      repo.completes.add(fakeCompletion('recorded'));

      final collecting = vm.collect();
      await pumpEventQueue();
      now = now.add(const Duration(seconds: 26));
      slow.complete(fakeFinalize(10000));
      await collecting;

      expect(platform.session.calls, [
        'collect',
        'collect',
        'confirm:pi_1:10000',
      ]);
    },
  );

  test('a decline leaves the PaymentIntent open for another card, which is '
      'finalized again', () async {
    final vm = await ready();
    repo.creates.add(fakeIntent());
    platform.session.reads
      ..add(fakeCard)
      ..add(fakeCard);
    repo.finalizes
      ..add(fakeFinalize(10000))
      ..add(fakeFinalize(10000));
    platform.session.confirms
      ..add(const TerminalError(TerminalErrorCode.declined))
      ..add(
        const TerminalPaymentOutcome(
          paymentIntentId: 'pi_1',
          status: 'succeeded',
        ),
      );
    repo.completes.add(fakeCompletion('recorded'));

    await vm.collect();
    expect(vm.stage, CollectStage.declined);
    expect(vm.problem!.code, TerminalErrorCode.declined);

    await vm.tryAnotherCard();
    expect(repo.calls.where((c) => c == 'finalize'), hasLength(2));
    expect(vm.stage, CollectStage.approved);
  });

  test(
    'a confirm whose outcome is unknown is never called "not charged"',
    () async {
      final vm = await ready();
      repo.creates.add(fakeIntent());
      platform.session.reads.add(fakeCard);
      repo.finalizes.add(fakeFinalize(10000));
      platform.session.confirms.add(
        const TerminalError(TerminalErrorCode.outcomeUnknown),
      );
      for (var i = 0; i < 3; i++) {
        repo.completes.add(fakeCompletion('requires_confirmation'));
      }

      await vm.collect();

      expect(vm.stage, CollectStage.checking);
      expect(repo.calls.where((c) => c == 'complete'), hasLength(3));
      expect(repo.calls, isNot(contains(startsWith('cancel'))));

      repo.completes.add(fakeCompletion('recorded'));
      await vm.checkAgain();
      expect(vm.stage, CollectStage.approved);
    },
  );

  test(
    'processing, rejected and canceled answers each have their own stage',
    () async {
      for (final (status, stage) in [
        ('processing', CollectStage.recording),
        ('rejected', CollectStage.unrecorded),
        ('orphaned', CollectStage.unrecorded),
        ('unapplied', CollectStage.approved),
      ]) {
        final vm = await ready();
        platform.session.calls.clear();
        repo.creates.add(fakeIntent());
        platform.session.reads.add(fakeCard);
        repo.finalizes.add(fakeFinalize(10000));
        platform.session.confirms.add(
          const TerminalPaymentOutcome(
            paymentIntentId: 'pi_1',
            status: 'succeeded',
          ),
        );
        repo.completes.add(fakeCompletion(status));
        await vm.collect();
        expect(vm.stage, stage, reason: status);
        vm.dispose();
      }
    },
  );

  test(
    'a create whose answer was lost is retried with the same collection_id',
    () async {
      final vm = await ready();
      repo.creates
        ..add(const NetworkException('reset by peer'))
        ..add(fakeIntent());
      platform.session.reads.add(fakeCard);
      repo.finalizes.add(fakeFinalize(10000));
      platform.session.confirms.add(
        const TerminalPaymentOutcome(
          paymentIntentId: 'pi_1',
          status: 'succeeded',
        ),
      );
      repo.completes.add(fakeCompletion('recorded'));

      await vm.collect();

      expect(repo.createdCollectionIds, ['col_1', 'col_1']);
      expect(vm.stage, CollectStage.approved);
    },
  );

  test('a closed collection_id is replaced once; a refusal starts the next '
      'attempt with a new one', () async {
    final vm = await ready();
    repo.creates
      ..add(const TerminalServerError(TerminalServerError.collectionClosed, ''))
      ..add(const TerminalServerError(TerminalServerError.amountMismatch, ''));
    await vm.collect();
    expect(repo.createdCollectionIds, ['col_1', 'col_2']);
    expect(vm.stage, CollectStage.configure);
    expect(vm.problem!.serverCode, TerminalServerError.amountMismatch);
    await pumpEventQueue();

    repo.creates.add(const RequestNotSentException('offline'));
    await vm.collect();
    expect(repo.createdCollectionIds.last, 'col_3');
  });

  test('a collection left open can be cancelled and started again', () async {
    final vm = await ready();
    repo.creates.add(
      const TerminalServerError(TerminalServerError.collectionOpen, '', {
        'payment_intent_id': 'pi_old',
        'user': 'Sam',
        'age': 90,
      }),
    );
    await vm.collect();
    expect(vm.stage, CollectStage.openCollection);

    repo.cancels.add(fakeCompletion('canceled'));
    await vm.cancelOpenCollection();
    expect(repo.calls, contains('cancel:pi_old'));
    expect(vm.stage, CollectStage.configure);
  });

  test('cancelling an open collection that was charged after all shows it '
      'recorded', () async {
    final vm = await ready();
    repo.creates.add(
      const TerminalServerError(TerminalServerError.collectionOpen, '', {
        'payment_intent_id': 'pi_old',
      }),
    );
    await vm.collect();
    repo.cancels.add(fakeCompletion('recorded'));
    await vm.cancelOpenCollection();
    expect(vm.stage, CollectStage.approved);
  });

  test('cancel while waiting for the card cancels the read and the '
      'PaymentIntent', () async {
    final vm = await ready();
    repo.creates.add(fakeIntent());
    final read = Completer<TerminalCollected>();
    platform.session.reads.add(read);
    repo.cancels.add(fakeCompletion('canceled'));

    final collecting = vm.collect();
    await pumpEventQueue();
    expect(vm.stage, CollectStage.waiting);
    await vm.cancel();
    read.completeError(const TerminalError(TerminalErrorCode.canceled));
    await collecting;

    expect(platform.session.calls, ['collect', 'cancel']);
    expect(repo.calls, contains('cancel:pi_1'));
    expect(vm.stage, CollectStage.cancelled);
  });

  test(
    'a cancel the server answers "recorded" is a payment, not a cancel',
    () async {
      final vm = await ready();
      repo.creates.add(fakeIntent());
      final read = Completer<TerminalCollected>();
      platform.session.reads.add(read);
      repo.cancels.add(fakeCompletion('recorded'));

      final collecting = vm.collect();
      await pumpEventQueue();
      await vm.cancel();
      read.completeError(const TerminalError(TerminalErrorCode.canceled));
      await collecting;

      expect(vm.stage, CollectStage.approved);
    },
  );

  test('cancel while the PaymentIntent is being created cancels it once it '
      'exists', () async {
    final vm = await ready();
    final creating = Completer<TerminalIntent>();
    repo.creates.add(creating);
    repo.cancels.add(fakeCompletion('canceled'));

    final collecting = vm.collect();
    await pumpEventQueue();
    await vm.cancel();
    creating.complete(fakeIntent());
    await collecting;

    expect(platform.session.calls, isEmpty);
    expect(repo.calls, contains('cancel:pi_1'));
    expect(vm.stage, CollectStage.cancelled);
  });

  test('nothing cancels a confirm in flight', () async {
    final vm = await ready();
    repo.creates.add(fakeIntent());
    platform.session.reads.add(fakeCard);
    repo.finalizes.add(fakeFinalize(10000));
    final confirming = Completer<TerminalPaymentOutcome>();
    platform.session.confirms.add(confirming);
    repo.completes.add(fakeCompletion('recorded'));

    final collecting = vm.collect();
    await pumpEventQueue();
    expect(vm.stage, CollectStage.processing);
    expect(vm.locked, isTrue);
    await vm.cancel();
    expect(platform.session.calls, isNot(contains('cancel')));
    confirming.complete(
      const TerminalPaymentOutcome(
        paymentIntentId: 'pi_1',
        status: 'succeeded',
      ),
    );
    await collecting;
    expect(vm.stage, CollectStage.approved);
  });

  test('a confirm refused for a stale read reads the card again', () async {
    final vm = await ready();
    repo.creates.add(fakeIntent());
    platform.session.reads
      ..add(fakeCard)
      ..add(fakeCard);
    repo.finalizes
      ..add(fakeFinalize(10000))
      ..add(fakeFinalize(10000));
    platform.session.confirms
      ..add(const TerminalError(TerminalErrorCode.invalidState))
      ..add(
        const TerminalPaymentOutcome(
          paymentIntentId: 'pi_1',
          status: 'succeeded',
        ),
      );
    repo.completes.add(fakeCompletion('recorded'));

    await vm.collect();
    await pumpEventQueue();

    expect(platform.session.calls, [
      'collect',
      'confirm:pi_1:10000',
      'collect',
      'confirm:pi_1:10000',
    ]);
    expect(vm.stage, CollectStage.approved);
  });

  test('a refused permission stops before anything is created', () async {
    platform.permission = TerminalPermission.blocked;
    final vm = CollectCardPaymentViewModel(
      companyId: 'co_a',
      invoice: invoice,
      terminal: terminal,
      repository: repo,
      isAdmin: true,
      merchantDisplayName: 'Acme',
      precision: 2,
    );
    await vm.start();
    expect(vm.readerState, ReaderState.blocked);
    expect(vm.canCollect, isFalse);
  });

  test('the amount defaults to a deposit when one is due', () {
    expect(
      CollectCardPaymentViewModel.defaultAmount(
        invoice.copyWith(partial: Decimal.fromInt(40)),
      ),
      Decimal.fromInt(40),
    );
    expect(
      CollectCardPaymentViewModel.defaultAmount(
        invoice.copyWith(statusId: InvoiceStatus.draft, balance: Decimal.zero),
      ),
      Decimal.fromInt(100),
    );
  });

  group('money review (2026-11-11)', () {
    const charged = TerminalPaymentOutcome(
      paymentIntentId: 'pi_1',
      status: 'succeeded',
    );

    test('a screen closed while the server decides never charges', () async {
      final vm = await ready();
      repo.creates.add(fakeIntent());
      platform.session.reads.add(fakeCard);
      final deciding = Completer<TerminalFinalize>();
      repo.finalizes.add(deciding);
      repo.cancels.add(fakeCompletion('canceled'));

      final collecting = vm.collect();
      await pumpEventQueue();
      expect(vm.stage, CollectStage.finalizing);
      vm.dispose();
      deciding.complete(fakeFinalize(10000));
      await collecting;

      expect(platform.session.calls, isNot(contains(startsWith('confirm'))));
      expect(repo.calls, contains('cancel:pi_1'));
    });

    test(
      'a decline nobody sees gives the reader and the invoice back',
      () async {
        final vm = await ready();
        repo.creates.add(fakeIntent());
        platform.session.reads.add(fakeCard);
        repo.finalizes.add(fakeFinalize(10000));
        final confirming = Completer<TerminalPaymentOutcome>();
        platform.session.confirms.add(confirming);
        repo.cancels.add(fakeCompletion('canceled'));

        final collecting = vm.collect();
        await pumpEventQueue();
        expect(vm.stage, CollectStage.processing);
        vm.dispose();
        confirming.completeError(
          const TerminalError(TerminalErrorCode.declined),
        );
        await collecting;
        await pumpEventQueue();

        expect(platform.session.isFinished, isTrue);
        expect(repo.calls, contains('cancel:pi_1'));
      },
    );

    test('a reset waits from finalize to the server\'s answer', () async {
      final vm = await ready();
      repo.creates.add(fakeIntent());
      platform.session.reads.add(fakeCard);
      final deciding = Completer<TerminalFinalize>();
      repo.finalizes.add(deciding);
      platform.session.confirms.add(charged);
      repo.completes.add(fakeCompletion('recorded'));

      final collecting = vm.collect();
      await pumpEventQueue();
      var reset = false;
      final resetting = terminal.reset().then((_) => reset = true);
      await pumpEventQueue();
      expect(reset, isFalse);
      deciding.complete(fakeFinalize(10000));
      await collecting;
      await resetting;
      expect(vm.stage, CollectStage.approved);
      expect(reset, isTrue);
    });

    test('an unknown outcome the server says failed takes another card on a '
        'new payment', () async {
      final vm = await ready();
      repo.creates.add(fakeIntent());
      platform.session.reads
        ..add(fakeCard)
        ..add(fakeCard);
      repo.finalizes
        ..add(fakeFinalize(10000))
        ..add(fakeFinalize(10000));
      platform.session.confirms
        ..add(const TerminalError(TerminalErrorCode.outcomeUnknown))
        ..add(charged);
      repo.completes
        ..add(fakeCompletion('requires_payment_method'))
        ..add(fakeCompletion('recorded'));

      await vm.collect();
      expect(vm.stage, CollectStage.declined);
      await vm.tryAnotherCard();
      expect(platform.begun, 2);
      expect(vm.stage, CollectStage.approved);
    });

    test('Checking can cancel the payment, which frees the invoice', () async {
      final vm = await ready();
      repo.creates.add(fakeIntent());
      platform.session.reads.add(fakeCard);
      repo.finalizes.add(fakeFinalize(10000));
      platform.session.confirms.add(
        const TerminalError(TerminalErrorCode.outcomeUnknown),
      );
      for (var i = 0; i < 3; i++) {
        repo.completes.add(fakeCompletion('requires_confirmation'));
      }
      await vm.collect();
      expect(vm.stage, CollectStage.checking);

      repo.cancels.add(fakeCompletion('canceled'));
      await vm.cancelUnconfirmed();
      expect(vm.stage, CollectStage.cancelled);
    });

    test(
      'an open collection still being created can\'t be cancelled yet',
      () async {
        final vm = await ready();
        repo.creates.add(
          const TerminalServerError(TerminalServerError.collectionOpen, '', {
            'payment_intent_id': null,
            'user': 'Sam',
          }),
        );
        await vm.collect();
        await vm.cancelOpenCollection();
        expect(vm.stage, CollectStage.openCollection);
        expect(vm.problem!.serverCode, 'collection_starting');
        expect(repo.calls, isNot(contains(startsWith('cancel'))));
      },
    );

    test('an open collection still charging is checked by its own '
        'PaymentIntent', () async {
      final vm = await ready();
      repo.creates.add(
        const TerminalServerError(TerminalServerError.collectionOpen, '', {
          'payment_intent_id': 'pi_old',
        }),
      );
      await vm.collect();
      repo.cancels.add(fakeCompletion('processing'));
      await vm.cancelOpenCollection();
      expect(vm.stage, CollectStage.recording);

      repo.completes.add(fakeCompletion('recorded'));
      await vm.checkAgain();
      expect(vm.stage, CollectStage.approved);
    });

    test('reads are bounded even when the facade keeps refusing', () async {
      final vm = await ready();
      repo.creates.add(fakeIntent());
      for (var i = 0; i < 3; i++) {
        platform.session.reads.add(fakeCard);
        // The server says 10300, the read says 10000: always refused.
        repo.finalizes.add(fakeFinalize(10300));
      }
      repo.cancels.add(fakeCompletion('canceled'));
      await vm.collect();
      expect(vm.stage, CollectStage.cancelled);
      expect(platform.session.calls.where((c) => c == 'collect'), hasLength(3));
    });
  });

  group('re-review (2026-11-11)', () {
    test('an amount is rounded to the currency, and the same amount again is '
        'no change', () async {
      final vm = await ready();
      expect(vm.setAmount(Decimal.parse('10.005')), isTrue);
      expect(vm.amount, Decimal.parse('10.01'));
      expect(vm.setAmount(Decimal.parse('10.005')), isFalse);
      expect(vm.setAmount(Decimal.parse('10.01')), isFalse);
    });

    test('a reset while waiting for the card gives the payment up', () async {
      final vm = await ready();
      repo.creates.add(fakeIntent());
      final read = Completer<TerminalCollected>();
      platform.session.reads.add(read);
      repo.cancels.add(fakeCompletion('canceled'));

      final collecting = vm.collect();
      await pumpEventQueue();
      expect(vm.stage, CollectStage.waiting);
      await terminal.reset();
      read.completeError(const TerminalError(TerminalErrorCode.canceled));
      await collecting;

      expect(vm.stage, CollectStage.cancelled);
      expect(repo.calls, contains('cancel:pi_1'));
    });

    test('a closed screen never reads the card again', () async {
      final vm = await ready();
      repo.creates.add(fakeIntent());
      platform.session.reads.add(fakeCard);
      repo.finalizes.add(fakeFinalize(10000));
      final confirming = Completer<TerminalPaymentOutcome>();
      platform.session.confirms.add(confirming);
      repo.cancels.add(fakeCompletion('canceled'));

      final collecting = vm.collect();
      await pumpEventQueue();
      expect(vm.stage, CollectStage.processing);
      vm.dispose();
      confirming.completeError(
        const TerminalError(TerminalErrorCode.invalidState),
      );
      await collecting;

      expect(platform.session.calls.where((c) => c == 'collect'), hasLength(1));
      expect(repo.calls, contains('cancel:pi_1'));
    });

    test('a payment the server reports failed is not charged', () async {
      final vm = await ready();
      repo.creates.add(fakeIntent());
      platform.session.reads.add(fakeCard);
      repo.finalizes.add(fakeFinalize(10000));
      platform.session.confirms.add(
        const TerminalError(TerminalErrorCode.outcomeUnknown),
      );
      repo.completes.add(fakeCompletion('failed'));
      await vm.collect();
      expect(vm.stage, CollectStage.cancelled);
    });
  });
}
