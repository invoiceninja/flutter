import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/detail/generic_detail_view_model.dart';

/// First coverage for `GenericDetailViewModel` — the base class every entity
/// detail screen extends, and the only one of the three generic VM bases with
/// no test (`GenericListViewModel` and `GenericEditViewModel` both have one).
///
/// The load-bearing behaviour is the **post-dispose guard** (`if (_disposed)
/// return` in the `notifyListeners` override), which stops
/// "A ChangeNotifier was used after being disposed" when a detail screen is
/// popped while async work is still in flight.
///
/// Worth being precise about who can actually reach that guard: **not** the
/// bound stream. `dispose()` cancels the subscription, and a cancelled
/// `StreamController` silently drops later events (`_add` no-ops once
/// `hasListener` is false), so the listener can never fire again. The reachable
/// caller is a *subclass* computing derived state asynchronously and notifying
/// after the screen is gone — which is why the base also exposes `isDisposed`.
/// The tests below cover both halves separately rather than pretending a late
/// stream event exercises the guard.
///
/// Streams here are plain controllers, never a real Drift watch — a widget-test
/// pump over a live Drift stream hangs.
void main() {
  group('initial state', () {
    test('starts resolving with no item', () {
      final vm = GenericDetailViewModel<String>();
      addTearDown(vm.dispose);

      expect(vm.item, isNull);
      expect(vm.isResolving, isTrue);
      expect(vm.isDisposed, isFalse);
    });

    test('.bound stays resolving until the stream emits', () async {
      final controller = StreamController<String?>();
      addTearDown(controller.close);
      final vm = GenericDetailViewModel<String>.bound(controller.stream);
      addTearDown(vm.dispose);

      expect(vm.isResolving, isTrue);

      controller.add('first');
      await Future<void>.delayed(Duration.zero);

      expect(vm.isResolving, isFalse);
      expect(vm.item, 'first');
    });
  });

  group('emissions', () {
    test('each emission updates item and notifies', () async {
      final controller = StreamController<String?>();
      addTearDown(controller.close);
      final vm = GenericDetailViewModel<String>.bound(controller.stream);
      addTearDown(vm.dispose);

      var notifications = 0;
      vm.addListener(() => notifications++);

      controller.add('a');
      await Future<void>.delayed(Duration.zero);
      controller.add('b');
      await Future<void>.delayed(Duration.zero);

      expect(vm.item, 'b');
      expect(notifications, 2);
    });

    test('a null emission clears the item but still resolves — the row was '
        'deleted server-side', () async {
      final controller = StreamController<String?>();
      addTearDown(controller.close);
      final vm = GenericDetailViewModel<String>.bound(controller.stream);
      addTearDown(vm.dispose);

      controller.add('present');
      await Future<void>.delayed(Duration.zero);
      controller.add(null);
      await Future<void>.delayed(Duration.zero);

      expect(vm.item, isNull);
      expect(
        vm.isResolving,
        isFalse,
        reason:
            'a resolved-to-nothing detail must render its empty state, '
            'not spin forever',
      );
    });
  });

  group('bindStream replaces any prior subscription', () {
    test('the old stream stops driving the VM', () async {
      final first = StreamController<String?>();
      final second = StreamController<String?>();
      addTearDown(first.close);
      addTearDown(second.close);

      final vm = _ReboundViewModel(first.stream);
      addTearDown(vm.dispose);

      first.add('from-first');
      await Future<void>.delayed(Duration.zero);
      expect(vm.item, 'from-first');

      vm.rebind(second.stream);
      expect(vm.isResolving, isTrue, reason: 'rebinding re-enters resolving');

      first.add('stale');
      await Future<void>.delayed(Duration.zero);
      expect(
        vm.item,
        'from-first',
        reason: 'the cancelled subscription must not write through',
      );

      second.add('from-second');
      await Future<void>.delayed(Duration.zero);
      expect(vm.item, 'from-second');
    });
  });

  group('dispose', () {
    test('a late emission is dropped, not delivered', () async {
      final controller = StreamController<String?>();
      addTearDown(controller.close);
      final vm = GenericDetailViewModel<String>.bound(controller.stream);

      vm.dispose();
      controller.add('late');
      await Future<void>.delayed(Duration.zero);

      expect(
        vm.item,
        isNull,
        reason:
            'dispose() cancels the subscription, so the listener — and '
            'with it any write to _item — must never run',
      );
    });

    test('notifyListeners after dispose is a silent no-op', () {
      // This is the ONLY route to the `if (_disposed) return` guard. A
      // cancelled StreamSubscription can never invoke the listener again
      // (StreamController._add is a no-op once cancelled), so the guard exists
      // for subclasses that do their own async work and notify late —
      // ClientDetailViewModel and friends. Exercise it the way they hit it.
      final vm = GenericDetailViewModel<String>();
      vm.dispose();

      expect(vm.notifyListeners, returnsNormally);
    });

    test('a listener added before dispose is not called afterwards', () {
      final vm = GenericDetailViewModel<String>();
      var calls = 0;
      vm.addListener(() => calls++);

      vm.dispose();
      vm.notifyListeners();

      expect(calls, 0);
    });
  });
}

/// Exposes the protected `bindStream` so the rebinding contract is testable —
/// exactly how `ClientDetailViewModel` and friends call it.
class _ReboundViewModel extends GenericDetailViewModel<String> {
  _ReboundViewModel(Stream<String?> stream) {
    bindStream(stream);
  }

  void rebind(Stream<String?> stream) => bindStream(stream);
}
