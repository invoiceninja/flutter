import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/services.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/utils/call_note_sink.dart';

/// `canLogCallAgainst` gates whether a surface offers to log at all;
/// `enqueueCallNote` is what actually writes. They are two lists, and a
/// divergence is silent in the worst possible way: the user fills in the form,
/// taps Save, and the note is dropped on the floor.
///
/// The second test proves the switch really has an arm for every type the
/// predicate offers, without building ten repositories: a `Services` whose
/// `noSuchMethod` throws turns "reached the right repo" into an exception and
/// "fell through to `_ => null`" into a null. The dangerous direction is the
/// second one, and it is the one that would otherwise ship silently.
class _ThrowingServices implements Services {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  test('the predicate names exactly the ten comment-capable entities', () {
    // The same set `services_entity_wiring.dart` registers a
    // `MutationKind.addComment` handler for. Task and Project are accepted by
    // the server's `StoreNoteRequest` but have no `addComment` on their
    // repositories — adding one is a deliberate, separate change.
    const expected = {
      EntityType.client,
      EntityType.vendor,
      EntityType.invoice,
      EntityType.quote,
      EntityType.credit,
      EntityType.purchaseOrder,
      EntityType.recurringInvoice,
      EntityType.payment,
      EntityType.expense,
      EntityType.recurringExpense,
    };
    final actual = EntityType.values.where(canLogCallAgainst).toSet();
    expect(actual, expected);
  });

  test('every offered type reaches a real repository arm', () {
    final services = _ThrowingServices();
    for (final type in EntityType.values.where(canLogCallAgainst)) {
      // The thunk must exist *and* reach a repository when invoked — a factory
      // that returns null, or one whose body never touches `Services`, would
      // both slip past a "not null" assertion.
      final op = enqueueCallNote(
        services,
        type: type,
        entityId: 'x',
        companyId: 'co',
        note: 'n',
      );
      expect(op, isNotNull, reason: '$type has no arm in the switch');
      expect(
        op,
        throwsA(isA<UnimplementedError>()),
        reason:
            '$type is offered by canLogCallAgainst but falls through to the '
            'switch default — the user would fill in the form and lose it',
      );
    }
  });

  test('an unoffered type returns null instead of half-writing', () {
    final services = _ThrowingServices();
    for (final type in [
      EntityType.task,
      EntityType.project,
      EntityType.product,
    ]) {
      expect(canLogCallAgainst(type), isFalse);
      expect(
        enqueueCallNote(
          services,
          type: type,
          entityId: 'x',
          companyId: 'co',
          note: 'n',
        ),
        isNull,
      );
    }
  });
}
