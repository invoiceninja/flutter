// The create-form baseline, late defaults and flush hooks of
// `GenericEditViewModel` — the seams the billing documents' dirty check,
// inclusive-tax seeding and line-item picker are built on.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';

class _Vm extends GenericEditViewModel<String> {
  _Vm({required super.initialDraft, super.original, super.prefilled});

  /// Held open by a test to observe the form mid-save.
  Completer<void>? gate;

  @override
  bool draftIsNonEmpty() => draft != createBaseline || prefilled;

  void set(String v) => updateDraft(v);

  bool seed(String Function(String) f, {bool remember = true}) =>
      seedCreateDefault(f, rememberForReset: remember);

  @override
  Future<SaveResult<String>> performSave() async {
    await gate?.future;
    return SaveResult(entity: draft, outboxRowId: 1);
  }
}

void main() {
  group('seedCreateDefault', () {
    test('lands on an untouched create form without dirtying it', () {
      final vm = _Vm(initialDraft: 'a');
      expect(vm.seed((d) => '$d+tax'), isTrue);
      expect(vm.draft, 'a+tax');
      expect(vm.isDirty, isFalse);
    });

    test('keeps an edit the user made meanwhile, and it stays dirty', () {
      final vm = _Vm(initialDraft: 'a');
      vm.set('ab');
      vm.seed((d) => '$d+tax');
      expect(vm.draft, 'ab+tax');
      expect(vm.isDirty, isTrue);
    });

    test('is a no-op on an edit form', () {
      final vm = _Vm(initialDraft: 'a', original: 'a');
      expect(vm.seed((d) => '$d+tax'), isFalse);
      expect(vm.draft, 'a');
    });

    test('is a no-op mid-save', () async {
      final vm = _Vm(initialDraft: 'a')..gate = Completer<void>();
      final saving = vm.save();
      expect(vm.isSaving, isTrue);
      expect(vm.seed((d) => '$d+tax'), isFalse);
      vm.gate!.complete();
      await saving;
      expect(vm.draft, 'a');
    });

    test('is a no-op after a save, and leaves the form clean', () async {
      final vm = _Vm(initialDraft: 'a');
      vm.set('b');
      await vm.save();
      expect(vm.seed((d) => '$d+tax'), isFalse);
      expect(vm.draft, 'b');
      expect(vm.isDirty, isFalse);
    });
  });

  group('reset on a create form', () {
    test('rebases onto the blank draft with the remembered seeds', () {
      final vm = _Vm(initialDraft: 'a');
      vm.seed((d) => '$d+company');
      vm.seed((d) => '$d+client', remember: false);
      vm.set('edited');
      vm.reset(emptyDraft: 'blank');
      expect(vm.draft, 'blank+company');
      expect(vm.isDirty, isFalse);
      // An edit after the discard, and back again, is clean — the baseline
      // is the rebased blank, not the one the form opened on.
      vm.set('x');
      expect(vm.isDirty, isTrue);
      vm.set('blank+company');
      expect(vm.isDirty, isFalse);
    });

    test('clears prefilled: a discarded clone is a blank form', () {
      final vm = _Vm(initialDraft: 'clone', prefilled: true);
      expect(vm.isDirty, isTrue);
      vm.reset(emptyDraft: 'blank');
      expect(vm.isDirty, isFalse);
      vm.set('y');
      vm.set('blank');
      expect(vm.isDirty, isFalse);
    });
  });

  group('flush hooks', () {
    test('save runs flush, then before-save, then finalize hooks', () async {
      final vm = _Vm(initialDraft: 'a');
      final order = <String>[];
      vm.addFinalizeSaveHook(() => order.add('finalize'));
      vm.addBeforeSaveHook(() => order.add('before'));
      vm.addFlushHook(() => order.add('flush'));
      await vm.save();
      expect(order, ['flush', 'before', 'finalize']);
    });

    test('flushPendingEdits runs only the flush hooks', () {
      final vm = _Vm(initialDraft: 'a');
      final order = <String>[];
      vm.addBeforeSaveHook(() => order.add('before'));
      final unregister = vm.addFlushHook(() => order.add('flush'));
      vm.flushPendingEdits();
      expect(order, ['flush']);
      unregister();
      vm.flushPendingEdits();
      expect(order, ['flush']);
    });

    test('a save already in flight runs none of them', () async {
      final vm = _Vm(initialDraft: 'a')..gate = Completer<void>();
      var flushes = 0;
      vm.addFlushHook(() => flushes++);
      final first = vm.save();
      expect(flushes, 1);
      expect(await vm.save(), isNull);
      expect(flushes, 1);
      vm.gate!.complete();
      await first;
    });
  });
}
