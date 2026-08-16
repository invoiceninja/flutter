import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/sync_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/connectivity_watcher.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';

void main() {
  group('GenericEditViewModel', () {
    test('save() returns the entity on success and clears errors', () async {
      final vm = _FakeEditVM(initialDraft: 'draft-v1');
      final saved = await vm.save();

      expect(saved, 'draft-v1');
      expect(vm.isSaving, isFalse);
      expect(vm.submitError, isNull);
      expect(vm.fieldErrors, isEmpty);
    });

    test('finalize hooks run after ALL before-save hooks', () async {
      final vm = _FakeEditVM(initialDraft: 'draft');
      final order = <String>[];
      vm.addBeforeSaveHook(() => order.add('before-1'));
      // Registered BETWEEN the before-save hooks, yet must still run last —
      // billing totals stamping (a finalize hook registered in a VM ctor) has
      // to observe the draft AFTER the line-item flush hooks (registered later
      // in a child widget's initState) have committed debounced edits.
      vm.addFinalizeSaveHook(() => order.add('finalize'));
      vm.addBeforeSaveHook(() => order.add('before-2'));

      await vm.save();

      expect(order, ['before-1', 'before-2', 'finalize']);
    });

    test(
      '422 ValidationException populates fieldErrors, returns null',
      () async {
        final vm = _FakeEditVM(
          initialDraft: 'draft',
          throwOnSave: const ValidationException(
            'The given data was invalid.',
            {
              'name': ['Name is required'],
              'email': ['Email must be valid', 'Email is required'],
            },
          ),
        );

        final result = await vm.save();

        expect(result, isNull);
        expect(vm.fieldErrorFor('name'), 'Name is required');
        expect(vm.fieldErrorFor('email'), 'Email must be valid');
        expect(vm.fieldErrorFor('phone'), isNull);
        // The top-level message is RETAINED alongside the per-field errors.
        // It used to be nulled here on the theory that the inline errors were
        // the whole story — but a 422 can name keys no field on the form
        // renders, and then the banner said "fix the errors below" with
        // nothing below and Discard as the only exit (invoiceninja/flutter#36).
        // The screen still suppresses the toast when fieldErrors is non-empty;
        // the banner is what consumes this.
        expect(vm.submitError, 'The given data was invalid.');
        expect(vm.failedStatusCode, 422);
        expect(vm.failedSaveIsRecordDeleted, isFalse);
        expect(vm.isSaving, isFalse);
      },
    );

    test(
      'non-422 errors land on submitError, fieldErrors stays empty',
      () async {
        final vm = _FakeEditVM(
          initialDraft: 'draft',
          throwOnSave: Exception('boom'),
        );

        await vm.save();

        expect(vm.fieldErrors, isEmpty);
        expect(vm.submitError, isNotNull);
        expect(vm.submitError, contains('boom'));
      },
    );

    test(
      'subsequent save() clears the prior fieldErrors before retrying',
      () async {
        final vm = _FakeEditVM(
          initialDraft: 'draft',
          throwOnSave: const ValidationException('Invalid', {
            'name': ['Name is required'],
          }),
        );
        await vm.save();
        expect(vm.fieldErrorFor('name'), isNotNull);

        // Subsequent attempt succeeds — old errors should be cleared.
        vm.clearThrow();
        final ok = await vm.save();
        expect(ok, 'draft');
        expect(vm.fieldErrors, isEmpty);
      },
    );

    test('reset() clears draft, submitError, and fieldErrors', () async {
      final vm = _FakeEditVM(
        initialDraft: 'draft',
        throwOnSave: const ValidationException('Invalid', {
          'name': ['Name is required'],
        }),
      );
      await vm.save();

      vm.reset(emptyDraft: 'fresh');

      expect(vm.draft, 'fresh');
      expect(vm.fieldErrors, isEmpty);
      expect(vm.submitError, isNull);
    });

    test(
      'reset() leaves a create-mode draft clean (no repeat discard prompts)',
      () {
        // _FakeEditVM is create mode (no `original`) and uses the base
        // `draftIsNonEmpty() == true`, so a typed draft reads dirty.
        final vm = _FakeEditVM(initialDraft: 'typed');
        expect(vm.isDirty, isTrue); // user made a change

        vm.reset(emptyDraft: 'fresh'); // discard

        expect(
          vm.isDirty,
          isFalse,
          reason:
              'a discarded draft must report clean so chained discard '
              'guards (sidebar → branch switch → route onExit) do not re-prompt',
        );
      },
    );
  });

  group('GenericEditViewModel.validate hook', () {
    test('default validate() is a no-op — save proceeds normally', () async {
      final vm = _FakeEditVM(initialDraft: 'draft');
      final saved = await vm.save();

      expect(saved, 'draft');
      expect(vm.localValidationOnly, isFalse);
      expect(vm.performSaveCount, 1);
    });

    test('validate() errors block the save before performSave runs', () async {
      final vm = _FakeEditVM(
        initialDraft: 'draft',
        validateErrors: const {
          'client_id': ['Please select a client'],
        },
      );

      final result = await vm.save();

      expect(result, isNull);
      expect(vm.performSaveCount, 0); // repo never called → no outbox row
      expect(vm.fieldErrorFor('client_id'), 'Please select a client');
      expect(vm.localValidationOnly, isTrue);
      expect(vm.submitError, isNull);
      expect(vm.isSaving, isFalse);
      expect(vm.isDirty, isTrue); // stays open, not marked clean
    });

    test(
      'fixing the field clears localValidationOnly and lets save proceed',
      () async {
        final vm = _FakeEditVM(
          initialDraft: 'draft',
          validateErrors: const {
            'client_id': ['Please select a client'],
          },
        );
        await vm.save();
        expect(vm.localValidationOnly, isTrue);

        vm.passValidation();
        final ok = await vm.save();

        expect(ok, 'draft');
        expect(vm.localValidationOnly, isFalse);
        expect(vm.fieldErrors, isEmpty);
        expect(vm.performSaveCount, 1);
      },
    );

    test('clearFailedSync() resets localValidationOnly', () async {
      final vm = _FakeEditVM(
        initialDraft: 'draft',
        validateErrors: const {
          'client_id': ['Please select a client'],
        },
      );
      await vm.save();
      expect(vm.localValidationOnly, isTrue);

      vm.clearFailedSync();

      expect(vm.localValidationOnly, isFalse);
      expect(vm.fieldErrors, isEmpty);
    });

    test(
      'a validate() block does NOT leak a one-shot SAVE-PARAM query into '
      'the next plain save (regression: early-return must run finally)',
      () async {
        final vm = _FakeEditVM(
          initialDraft: 'draft',
          validateErrors: const {
            'client_id': ['Please select a client'],
          },
        );
        // Simulate an action bar stashing a SAVE-PARAM query, then a
        // blocked save.
        vm.setPendingSaveQuery({'mark_sent': 'true'});
        final blocked = await vm.save();
        expect(blocked, isNull);

        // User picks a client and presses plain Save.
        vm.passValidation();
        final ok = await vm.save();

        expect(ok, 'draft');
        // The stale mark_sent query must have been cleared by the finally
        // on the blocked save — not replayed here.
        expect(vm.lastConsumedQuery, isNull);
      },
    );
  });

  group('GenericEditViewModel — online save flow', () {
    late AppDatabase db;
    late _FakeSyncRepository sync;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      sync = _FakeSyncRepository(db);
    });
    tearDown(() async {
      await db.close();
    });

    test('online + success → returns entity, lastSaveWasOptimistic=false, '
        'recoveryTempId cleared', () async {
      final vm = _FakeEditVM(
        initialDraft: 'tmp_AAA',
        sync: sync,
        connectivity: ConnectivityWatcher.fixed(online: true),
        companyId: 'co',
      );
      sync.handler = (_) =>
          const SyncRowResult(outcome: SyncRowOutcome.success);

      final result = await vm.save();

      expect(result, 'tmp_AAA');
      expect(vm.lastSaveWasOptimistic, isFalse);
      expect(
        vm.recoveryTempId,
        isNull,
        reason: 'success clears the recovery tmp id',
      );
      expect(sync.lastRowId, 1, reason: 'awaitRow was called with the row id');
    });

    test('blocked connectivity probe (Snap/AppArmor) → assume-online, save '
        'still succeeds (no "Could not save")', () async {
      final vm = _FakeEditVM(
        initialDraft: 'tmp_AAA',
        sync: sync,
        // The live watcher's probe throws — exactly what `connectivity_plus`
        // does on Linux when AppArmor blocks the NetworkManager D-Bus call
        // under Snap strict confinement. It must degrade to assume-online so
        // the save doesn't surface "Could not save" (the reported bug).
        connectivity: ConnectivityWatcher.liveWith(
          check: () async => throw Exception('AppArmor blocked NetworkManager'),
          changes: () => const Stream<List<ConnectivityResult>>.empty(),
        ),
        companyId: 'co',
      );
      sync.handler = (_) =>
          const SyncRowResult(outcome: SyncRowOutcome.success);

      final result = await vm.save();

      expect(result, 'tmp_AAA');
      expect(vm.submitError, isNull);
      expect(vm.isSaving, isFalse);
      expect(
        sync.lastRowId,
        1,
        reason:
            'assume-online routed into the awaitRow online branch, not skipped',
      );
    });

    test(
      'online + validationFailed (422) → returns null, fieldErrors populated, '
      'recoveryTempId preserved for retry',
      () async {
        final vm = _FakeEditVM(
          initialDraft: 'tmp_AAA',
          sync: sync,
          connectivity: ConnectivityWatcher.fixed(online: true),
          companyId: 'co',
        );
        // First save: VM stashes the tmpId during performSave.
        sync.handler = (_) => const SyncRowResult(
          outcome: SyncRowOutcome.validationFailed,
          fieldErrors: {
            'email': ['Email must be unique'],
          },
          statusCode: 422,
        );

        final result = await vm.save();

        expect(result, isNull);
        expect(vm.fieldErrorFor('email'), 'Email must be unique');
        expect(vm.lastSaveWasOptimistic, isFalse);
        expect(
          vm.recoveryTempId,
          'tmp_AAA',
          reason: 'tmp id is preserved across the failure for the retry',
        );
      },
    );

    test(
      'online + timeout → returns entity, lastSaveWasOptimistic=true',
      () async {
        final vm = _FakeEditVM(
          initialDraft: 'tmp_AAA',
          sync: sync,
          connectivity: ConnectivityWatcher.fixed(online: true),
          companyId: 'co',
        );
        sync.handler = (_) =>
            const SyncRowResult(outcome: SyncRowOutcome.timeout);

        final result = await vm.save();

        expect(result, 'tmp_AAA');
        expect(
          vm.lastSaveWasOptimistic,
          isTrue,
          reason: 'scaffold reads this to toast "Saving in background…"',
        );
      },
    );

    test(
      'online + serverError → returns null, submitError has the bare message '
      '(no ApiException: prefix), recoveryTempId preserved',
      () async {
        final vm = _FakeEditVM(
          initialDraft: 'tmp_AAA',
          sync: sync,
          connectivity: ConnectivityWatcher.fixed(online: true),
          companyId: 'co',
        );
        sync.handler = (_) => const SyncRowResult(
          outcome: SyncRowOutcome.serverError,
          message: 'Connection lost',
          statusCode: 503,
        );

        final result = await vm.save();

        expect(result, isNull);
        expect(
          vm.submitError,
          'Connection lost',
          reason: 'ApiException.toString prefix must be stripped',
        );
        expect(vm.submitError, isNot(contains('ServerException')));
        expect(
          vm.recoveryTempId,
          'tmp_AAA',
          reason: 'transient failures preserve the tmp id for retry',
        );
      },
    );

    test(
      'offline → returns entity, no awaitRow call, lastSaveWasOptimistic=false',
      () async {
        final vm = _FakeEditVM(
          initialDraft: 'tmp_AAA',
          sync: sync,
          connectivity: ConnectivityWatcher.fixed(online: false),
          companyId: 'co',
        );
        sync.handler = (_) {
          fail('awaitRow must not be called when offline');
        };

        final result = await vm.save();

        expect(result, 'tmp_AAA');
        expect(vm.lastSaveWasOptimistic, isFalse);
      },
    );

    test('recovery tmpId end-to-end: first save 422 stashes the tmp id, '
        'second save reuses it instead of minting a fresh one', () async {
      final vm = _FakeEditVM(
        initialDraft: 'tmp_AAA',
        sync: sync,
        connectivity: ConnectivityWatcher.fixed(online: true),
        companyId: 'co',
      );
      sync.handler = (_) => const SyncRowResult(
        outcome: SyncRowOutcome.validationFailed,
        fieldErrors: {
          'email': ['bad'],
        },
        statusCode: 422,
      );
      await vm.save();
      expect(vm.recoveryTempId, 'tmp_AAA');

      // Subclass would normally read recoveryTempId inside its performSave
      // override and pass it to repo.create(existingTempId: ...). The fake
      // captures it so we can assert the wiring lands.
      sync.handler = (_) =>
          const SyncRowResult(outcome: SyncRowOutcome.success);
      await vm.save();
      expect(
        vm.lastObservedRecoveryTempIdInPerformSave,
        'tmp_AAA',
        reason: 'subclass performSave saw the prior tmp id for reuse',
      );
    });

    test(
      'clearFailedSync() clears recoveryTempId (Bug 1 regression)',
      () async {
        final vm = _FakeEditVM(
          initialDraft: 'tmp_AAA',
          sync: sync,
          connectivity: ConnectivityWatcher.fixed(online: true),
          companyId: 'co',
        );
        sync.handler = (_) => const SyncRowResult(
          outcome: SyncRowOutcome.validationFailed,
          fieldErrors: {
            'email': ['bad'],
          },
          statusCode: 422,
        );
        await vm.save();
        expect(vm.recoveryTempId, 'tmp_AAA');

        vm.clearFailedSync();

        expect(
          vm.recoveryTempId,
          isNull,
          reason: 'discard must throw away the stale tmp id',
        );
      },
    );

    test('applyFailedSync(entityId: tmp_…) restores recoveryTempId (Bug 2 '
        'regression — post-reopen retry path)', () async {
      final vm = _FakeEditVM(
        initialDraft: 'tmp_AAA',
        sync: sync,
        connectivity: ConnectivityWatcher.fixed(online: true),
        companyId: 'co',
      );

      vm.applyFailedSync(
        rowId: 42,
        errors: const {
          'email': ['bad'],
        },
        entityId: 'tmp_AAA',
      );

      expect(vm.recoveryTempId, 'tmp_AAA');
      expect(vm.deadOutboxRowId, 42);
      expect(vm.fieldErrorFor('email'), 'bad');
    });

    test('applyFailedSync(entityId: real-id) leaves recoveryTempId null '
        '(only tmp_ ids are recoverable)', () async {
      final vm = _FakeEditVM(
        initialDraft: 'tmp_AAA',
        sync: sync,
        connectivity: ConnectivityWatcher.fixed(online: true),
        companyId: 'co',
      );

      vm.applyFailedSync(
        rowId: 42,
        errors: const {
          'email': ['bad'],
        },
        entityId: 'real_xyz',
      );

      expect(
        vm.recoveryTempId,
        isNull,
        reason: 'updates target a known real id — no recovery needed',
      );
    });

    test('reset() clears recoveryTempId', () async {
      final vm = _FakeEditVM(
        initialDraft: 'tmp_AAA',
        sync: sync,
        connectivity: ConnectivityWatcher.fixed(online: true),
        companyId: 'co',
      );
      sync.handler = (_) => const SyncRowResult(
        outcome: SyncRowOutcome.validationFailed,
        fieldErrors: {
          'email': ['bad'],
        },
        statusCode: 422,
      );
      await vm.save();
      expect(vm.recoveryTempId, 'tmp_AAA');

      vm.reset(emptyDraft: 'tmp_BBB');

      expect(vm.recoveryTempId, isNull);
    });

    test('finally block does not throw on notifyListeners after dispose '
        '(disposal-mid-save guard)', () async {
      final vm = _FakeEditVM(
        initialDraft: 'tmp_AAA',
        sync: sync,
        connectivity: ConnectivityWatcher.fixed(online: true),
        companyId: 'co',
      );
      // Block awaitRow on a completer we control so we can dispose mid-save.
      final gate = Completer<SyncRowResult>();
      sync.handler = (_) => throw _UseAsyncHandler();
      sync.asyncHandler = (_) => gate.future;

      final saveFuture = vm.save();
      // Disposal happens while awaitRow is pending.
      vm.dispose();
      expect(vm.isDisposed, isTrue);

      // Now let the awaitRow resolve. If the finally block tried to call
      // notifyListeners() on a disposed ChangeNotifier, this would throw
      // in debug mode and the test would fail.
      gate.complete(const SyncRowResult(outcome: SyncRowOutcome.success));
      final result = await saveFuture;
      expect(result, 'tmp_AAA');
    });
  });
}

/// Test double for [SyncRepository] — only `awaitRow` is exercised by
/// `GenericEditViewModel.save()`, so the other inherited methods stay
/// untouched. Subclassing the concrete class avoids having to stub the
/// entire (large) implements surface.
class _FakeSyncRepository extends SyncRepository {
  _FakeSyncRepository(AppDatabase db)
    : super(db: db, registry: EntityRegistry(const {}));

  SyncRowResult Function(int rowId)? handler;
  Future<SyncRowResult> Function(int rowId)? asyncHandler;
  int? lastRowId;

  @override
  Future<SyncRowResult> awaitRow({
    required int rowId,
    required String companyId,
    Duration timeout = const Duration(seconds: 30),
    Duration pollInterval = const Duration(milliseconds: 200),
    bool callerWillDisplayFailure = true,
  }) async {
    lastRowId = rowId;
    if (asyncHandler != null) return asyncHandler!(rowId);
    return handler?.call(rowId) ??
        const SyncRowResult(outcome: SyncRowOutcome.success);
  }
}

/// Sentinel used to switch the fake from the sync `handler` callback to the
/// async one inside a single test (avoids an extra setter dance).
class _UseAsyncHandler implements Exception {}

class _FakeEditVM extends GenericEditViewModel<String> {
  _FakeEditVM({
    required super.initialDraft,
    this.throwOnSave,
    Map<String, List<String>> validateErrors = const {},
    super.sync,
    super.connectivity,
    super.companyId,
  }) : _validateErrors = validateErrors;

  Object? throwOnSave;
  Map<String, List<String>> _validateErrors;

  int performSaveCount = 0;
  Map<String, String>? lastConsumedQuery;

  /// Captures `recoveryTempId` as seen by `performSave` so the recovery-flow
  /// test can assert the subclass's view of the stashed tmp id.
  String? lastObservedRecoveryTempIdInPerformSave;

  void clearThrow() => throwOnSave = null;

  /// Make subsequent validate() pass (simulates the user fixing the field).
  void passValidation() => _validateErrors = const {};

  @override
  Map<String, List<String>> validate() => _validateErrors;

  @override
  Future<SaveResult<String>> performSave() async {
    performSaveCount++;
    lastConsumedQuery = consumeSaveQuery();
    lastObservedRecoveryTempIdInPerformSave = recoveryTempId;
    if (throwOnSave != null) throw throwOnSave!;
    // Mirror the entity-repo contract: stash the tmp id so the base VM's
    // success/timeout paths can clear it. Real subclasses do this via
    // `rememberCreateTempId(result.entity.id)` after `repo.create(...)`.
    rememberCreateTempId(draft);
    return SaveResult(entity: draft, outboxRowId: 1);
  }
}
