import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/features/shell/branch_company_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('entersAtInitialLocation', () {
    test('the Outbox is always entered at its first page — the page it was '
        'left on can be another company\'s queue', () {
      // The sign-out review's View leaves the Outbox branch on
      // `/sync/outbox?company=<other>`, and a later tap on Outbox restored
      // it: that company's queue, beside a badge counting this one's.
      expect(
        entersAtInitialLocation(const FixedBranch(FixedBranchKind.outbox)),
        isTrue,
      );
    });

    test('every other branch comes back where it was left', () {
      for (final kind in FixedBranchKind.values) {
        if (kind == FixedBranchKind.outbox) continue;
        expect(entersAtInitialLocation(FixedBranch(kind)), isFalse);
      }
      expect(
        entersAtInitialLocation(const EntityBranch(EntityType.client)),
        isFalse,
      );
      expect(entersAtInitialLocation(null), isFalse);
    });
  });

  group('BranchCompanyGate', () {
    test('first entry into a branch never resets', () {
      final gate = BranchCompanyGate();
      expect(gate.shouldResetOnEnter(index: 0, companyId: 'co_a'), isFalse);
    });

    test('re-entry under the same company never resets', () {
      final gate = BranchCompanyGate();
      gate.shouldResetOnEnter(index: 2, companyId: 'co_a');
      expect(gate.shouldResetOnEnter(index: 2, companyId: 'co_a'), isFalse);
    });

    test('re-entry under a different company resets exactly once', () {
      final gate = BranchCompanyGate();
      gate.shouldResetOnEnter(index: 2, companyId: 'co_a');
      expect(
        gate.shouldResetOnEnter(index: 2, companyId: 'co_b'),
        isTrue,
        reason: 'the preserved stack belongs to co_a',
      );
      expect(
        gate.shouldResetOnEnter(index: 2, companyId: 'co_b'),
        isFalse,
        reason: 'the record now points at co_b',
      );
    });

    test('branches are tracked independently', () {
      final gate = BranchCompanyGate();
      gate.shouldResetOnEnter(index: 0, companyId: 'co_a');
      gate.shouldResetOnEnter(index: 1, companyId: 'co_a');
      expect(gate.shouldResetOnEnter(index: 0, companyId: 'co_b'), isTrue);
      // Branch 1 hasn't been re-entered yet — its first co_b entry resets too,
      // then settles.
      expect(gate.shouldResetOnEnter(index: 1, companyId: 'co_b'), isTrue);
      expect(gate.shouldResetOnEnter(index: 1, companyId: 'co_b'), isFalse);
    });

    test('empty company ids (no session) never reset', () {
      final gate = BranchCompanyGate();
      expect(gate.shouldResetOnEnter(index: 0, companyId: ''), isFalse);
      expect(gate.shouldResetOnEnter(index: 0, companyId: 'co_a'), isFalse);
      gate.shouldResetOnEnter(index: 1, companyId: 'co_a');
      expect(gate.shouldResetOnEnter(index: 1, companyId: ''), isFalse);
    });
  });
}
