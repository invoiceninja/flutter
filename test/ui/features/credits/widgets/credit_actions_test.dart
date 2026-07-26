import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/credit_api_model.dart';
import 'package:admin/data/models/domain/credit.dart';
import 'package:admin/data/models/domain/credit_status.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/features/credits/widgets/credit_actions.dart';

import '../../shell/_shell_test_helpers.dart';

/// Gating coverage for `CreditActions.itemsFor`, mirroring the harness in
/// `purchase_order_actions_test.dart`.
///
/// The credit-specific rule is **Mark paid**: it is *hidden entirely* (not
/// merely disabled) unless the credit amount is negative — a negative credit
/// behaves like a receivable — and the credit is still open (Draft / Sent /
/// Partial). Mirrors React's `amount < 0` + status gate.
///
/// Apply-credit is orthogonal: it keys off a positive remaining balance, not
/// the status.
Credit _credit({
  String id = 'cr1',
  CreditStatus status = CreditStatus.draft,
  String amount = '100',
  String balance = '100',
  bool isDeleted = false,
  int archivedAt = 0,
}) => Credit.fromApi(
  CreditApi(
    id: id,
    statusId: status.wireId,
    amount: amount,
    balance: balance,
    isDeleted: isDeleted,
    archivedAt: archivedAt,
  ),
);

void main() {
  Future<List<EntityActionItem<CreditAction>>> resolveItems(
    WidgetTester tester,
    Credit credit, {
    bool isAdmin = true,
    String permissions = '',
  }) async {
    final fixture = await buildFixture(
      companies: [
        FakeCompany(
          id: 'co1',
          name: 'Co',
          isOwner: isAdmin,
          isAdmin: isAdmin,
          permissions: permissions,
        ),
      ],
    );
    addTearDown(fixture.dispose);

    late List<EntityActionItem<CreditAction>> items;
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Builder(
          builder: (context) {
            items = CreditActions.itemsFor(context, credit, (_) {});
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return items;
  }

  bool enabled(List<EntityActionItem<CreditAction>> items, CreditAction kind) {
    final match = flattenActionItems(items).where((i) => i.kind == kind);
    return match.isNotEmpty && match.first.enabled;
  }

  bool present(List<EntityActionItem<CreditAction>> items, CreditAction kind) =>
      flattenActionItems(items).any((i) => i.kind == kind);

  group('mark paid — negative credits only, and only while open', () {
    testWidgets('hidden on an ordinary positive credit', (tester) async {
      final items = await resolveItems(tester, _credit(amount: '100'));

      expect(
        present(items, CreditAction.markPaid),
        isFalse,
        reason: 'the action is conditionally rendered, not merely disabled',
      );
    });

    for (final entry in {
      CreditStatus.draft: true,
      CreditStatus.sent: true,
      CreditStatus.partial: true,
      CreditStatus.applied: false,
    }.entries) {
      testWidgets('negative credit, ${entry.key.name} → ${entry.value}', (
        tester,
      ) async {
        final items = await resolveItems(
          tester,
          _credit(status: entry.key, amount: '-100'),
        );

        expect(present(items, CreditAction.markPaid), entry.value);
      });
    }

    testWidgets('a zero-amount credit does not qualify', (tester) async {
      final items = await resolveItems(tester, _credit(amount: '0'));

      expect(present(items, CreditAction.markPaid), isFalse);
    });
  });

  group('apply credit — keys off the remaining balance', () {
    testWidgets('enabled with a positive balance', (tester) async {
      final items = await resolveItems(tester, _credit(balance: '50'));

      expect(enabled(items, CreditAction.applyToInvoice), isTrue);
    });

    testWidgets('disabled once fully applied', (tester) async {
      final items = await resolveItems(
        tester,
        _credit(status: CreditStatus.applied, balance: '0'),
      );

      expect(enabled(items, CreditAction.applyToInvoice), isFalse);
    });

    testWidgets('disabled on a deleted credit', (tester) async {
      final items = await resolveItems(
        tester,
        _credit(balance: '50', isDeleted: true),
      );

      expect(enabled(items, CreditAction.applyToInvoice), isFalse);
    });
  });

  group('mark sent — Draft only', () {
    for (final status in CreditStatus.values) {
      testWidgets('${status.name} → ${status == CreditStatus.draft}', (
        tester,
      ) async {
        final items = await resolveItems(tester, _credit(status: status));

        expect(
          enabled(items, CreditAction.markSent),
          status == CreditStatus.draft,
        );
      });
    }
  });

  group('permission gating (non-admin, non-owner)', () {
    testWidgets('no permissions hides edit and the clone group', (
      tester,
    ) async {
      final items = await resolveItems(tester, _credit(), isAdmin: false);

      expect(present(items, CreditAction.edit), isFalse);
      expect(present(items, CreditAction.cloneGroup), isFalse);
      expect(enabled(items, CreditAction.sendEmail), isFalse);
    });

    testWidgets('edit_credit alone enables mark sent but not clone', (
      tester,
    ) async {
      final items = await resolveItems(
        tester,
        _credit(),
        isAdmin: false,
        permissions: 'edit_credit',
      );

      expect(present(items, CreditAction.edit), isTrue);
      expect(enabled(items, CreditAction.markSent), isTrue);
      expect(present(items, CreditAction.cloneGroup), isFalse);
    });

    testWidgets('edit_credit is also required for mark paid', (tester) async {
      // Positive control first: this credit qualifies on amount + status, so
      // an isFalse below can only be the permission.
      final withEdit = await resolveItems(
        tester,
        _credit(amount: '-100'),
        isAdmin: false,
        permissions: 'edit_credit',
      );
      expect(present(withEdit, CreditAction.markPaid), isTrue);

      final withoutEdit = await resolveItems(
        tester,
        _credit(amount: '-100'),
        isAdmin: false,
        permissions: 'create_credit',
      );

      expect(present(withoutEdit, CreditAction.markPaid), isFalse);
    });
  });

  group('lifecycle actions reflect entity state', () {
    testWidgets('a live credit offers archive, not restore', (tester) async {
      final items = await resolveItems(tester, _credit());

      expect(present(items, CreditAction.archive), isTrue);
      expect(present(items, CreditAction.restore), isFalse);
    });

    testWidgets('a deleted credit offers restore', (tester) async {
      final items = await resolveItems(tester, _credit(isDeleted: true));

      expect(present(items, CreditAction.restore), isTrue);
    });
  });

  testWidgets('the PDF group is always available', (tester) async {
    final items = await resolveItems(
      tester,
      _credit(status: CreditStatus.applied),
    );

    expect(enabled(items, CreditAction.viewPdf), isTrue);
    expect(enabled(items, CreditAction.downloadPdf), isTrue);
    expect(enabled(items, CreditAction.printPdf), isTrue);
  });
}
