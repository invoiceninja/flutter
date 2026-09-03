import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/invoice_status.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/features/invoices/widgets/invoice_actions.dart';

import '../../shell/_shell_test_helpers.dart';

/// Gating coverage for `InvoiceActions.itemsFor` — at 798 lines the largest
/// action set in the app, and untested until now. Mirrors the harness in
/// `purchase_order_actions_test.dart`.
///
/// Encodes the rules the source documents, on two axes:
///   - **status**: mark sent is Draft-only; mark paid needs an outstanding
///     balance; cancel is Sent/Partial but explicitly NOT Paid (the server's
///     `cancel` path has no paid guard, so the client gate is load-bearing);
///     auto-bill excludes Draft; refund needs Paid or Partial.
///   - **permission**: `edit_invoice` / `create_invoice` / `create_payment`
///     each gate a different slice. `AuthCompany.can()` short-circuits for an
///     admin or owner, so the restricted cases below set both false and drive
///     the comma-separated `permissions` string.
///
/// `isLocked` (Verifactu) blocks only `markPaid` — status transitions like
/// mark-sent and auto-bill stay available on a locked invoice.
Invoice _invoice({
  String id = 'inv1',
  InvoiceStatus status = InvoiceStatus.draft,
  bool isDeleted = false,
  int archivedAt = 0,
  bool isLocked = false,
}) => Invoice.fromApi(
  InvoiceApi(
    id: id,
    statusId: status.wireId,
    isDeleted: isDeleted,
    archivedAt: archivedAt,
    isLocked: isLocked,
  ),
);

void main() {
  /// Resolves the action list under a company with the given permission
  /// posture. [permissions] only bites when the company is neither admin
  /// nor owner.
  Future<List<EntityActionItem<InvoiceAction>>> resolveItems(
    WidgetTester tester,
    Invoice invoice, {
    bool isAdmin = true,
    String permissions = '',
    bool rectifyEligible = false,
    String? eInvoiceType,
    bool sendEInvoicePending = false,
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

    late List<EntityActionItem<InvoiceAction>> items;
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Builder(
          builder: (context) {
            items = InvoiceActions.itemsFor(
              context,
              invoice,
              (_) {},
              rectifyEligible: rectifyEligible,
              eInvoiceType: eInvoiceType,
              sendEInvoicePending: sendEInvoicePending,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return items;
  }

  bool enabled(
    List<EntityActionItem<InvoiceAction>> items,
    InvoiceAction kind,
  ) {
    final match = flattenActionItems(items).where((i) => i.kind == kind);
    return match.isNotEmpty && match.first.enabled;
  }

  bool present(
    List<EntityActionItem<InvoiceAction>> items,
    InvoiceAction kind,
  ) => flattenActionItems(items).any((i) => i.kind == kind);

  group('mark sent — Draft only', () {
    for (final status in InvoiceStatus.values) {
      testWidgets('${status.name} → ${status == InvoiceStatus.draft}', (
        tester,
      ) async {
        final items = await resolveItems(tester, _invoice(status: status));

        expect(
          enabled(items, InvoiceAction.markSent),
          status == InvoiceStatus.draft,
        );
      });
    }
  });

  // NB: the source comment says "only when there's still a balance", but
  // `canMarkPaid` has no balance term — it is `!isPaid && !isCancelled &&
  // !isReversed`, i.e. purely status-driven. Named for what the code does.
  group('mark paid — any status that is not already settled', () {
    testWidgets('enabled on a sent invoice', (tester) async {
      final items = await resolveItems(
        tester,
        _invoice(status: InvoiceStatus.sent),
      );

      expect(enabled(items, InvoiceAction.markPaid), isTrue);
    });

    for (final status in [
      InvoiceStatus.paid,
      InvoiceStatus.cancelled,
      InvoiceStatus.reversed,
    ]) {
      testWidgets('disabled on ${status.name}', (tester) async {
        final items = await resolveItems(tester, _invoice(status: status));

        expect(enabled(items, InvoiceAction.markPaid), isFalse);
      });
    }

    testWidgets('a Verifactu-locked invoice blocks mark paid but NOT the '
        'status transitions', (tester) async {
      final items = await resolveItems(
        tester,
        _invoice(status: InvoiceStatus.sent, isLocked: true),
      );

      expect(enabled(items, InvoiceAction.markPaid), isFalse);
      expect(
        enabled(items, InvoiceAction.autoBill),
        isTrue,
        reason: 'locking prevents edits, not status transitions',
      );
      expect(enabled(items, InvoiceAction.cancel), isTrue);
    });
  });

  group('cancel — Sent or Partial, never Paid', () {
    for (final entry in {
      InvoiceStatus.draft: false,
      InvoiceStatus.sent: true,
      InvoiceStatus.partial: true,
      InvoiceStatus.paid: false,
      InvoiceStatus.cancelled: false,
      InvoiceStatus.reversed: false,
    }.entries) {
      testWidgets('${entry.key.name} → ${entry.value}', (tester) async {
        final items = await resolveItems(tester, _invoice(status: entry.key));

        expect(
          enabled(items, InvoiceAction.cancel),
          entry.value,
          reason:
              'the server cancel path has no paid guard — this gate is the '
              'only thing stopping a paid invoice being cancelled',
        );
      });
    }
  });

  group('auto-bill — payable and not a draft', () {
    for (final entry in {
      InvoiceStatus.draft: false,
      InvoiceStatus.sent: true,
      InvoiceStatus.partial: true,
      InvoiceStatus.paid: false,
      InvoiceStatus.cancelled: false,
    }.entries) {
      testWidgets('${entry.key.name} → ${entry.value}', (tester) async {
        final items = await resolveItems(tester, _invoice(status: entry.key));

        expect(enabled(items, InvoiceAction.autoBill), entry.value);
      });
    }
  });

  group('refund — Paid or Partial only', () {
    for (final entry in {
      InvoiceStatus.draft: false,
      InvoiceStatus.sent: false,
      InvoiceStatus.partial: true,
      InvoiceStatus.paid: true,
      InvoiceStatus.reversed: false,
    }.entries) {
      testWidgets('${entry.key.name} → ${entry.value}', (tester) async {
        final items = await resolveItems(tester, _invoice(status: entry.key));

        expect(enabled(items, InvoiceAction.refund), entry.value);
      });
    }
  });

  group('send email — not on a cancelled or reversed invoice', () {
    testWidgets('enabled on sent', (tester) async {
      final items = await resolveItems(
        tester,
        _invoice(status: InvoiceStatus.sent),
      );

      expect(enabled(items, InvoiceAction.sendEmail), isTrue);
    });

    for (final status in [InvoiceStatus.cancelled, InvoiceStatus.reversed]) {
      testWidgets('disabled on ${status.name}', (tester) async {
        final items = await resolveItems(tester, _invoice(status: status));

        expect(enabled(items, InvoiceAction.sendEmail), isFalse);
      });
    }
  });

  // Same caveat as mark paid: no balance term in `canEnterPayment`, only
  // `!isDraft && !isPaid && !isCancelled && !isReversed` + the permission.
  group('enter payment — non-draft, unsettled, needs create_payment', () {
    testWidgets('is the primary action on a sent invoice', (tester) async {
      final items = await resolveItems(
        tester,
        _invoice(status: InvoiceStatus.sent),
      );

      final enterPayment = flattenActionItems(
        items,
      ).firstWhere((i) => i.kind == InvoiceAction.enterPayment);
      expect(enterPayment.isPrimary, isTrue);
      expect(
        flattenActionItems(
          items,
        ).firstWhere((i) => i.kind == InvoiceAction.edit).isPrimary,
        isFalse,
        reason: 'Edit demotes to a secondary while money is outstanding',
      );
    });

    testWidgets('absent on a draft', (tester) async {
      final items = await resolveItems(tester, _invoice());

      expect(present(items, InvoiceAction.enterPayment), isFalse);
      expect(
        flattenActionItems(
          items,
        ).firstWhere((i) => i.kind == InvoiceAction.edit).isPrimary,
        isTrue,
      );
    });

    testWidgets('absent without create_payment', (tester) async {
      final items = await resolveItems(
        tester,
        _invoice(status: InvoiceStatus.sent),
        isAdmin: false,
        permissions: 'edit_invoice',
      );

      expect(present(items, InvoiceAction.enterPayment), isFalse);
    });
  });

  group('permission gating (non-admin, non-owner)', () {
    testWidgets('no permissions at all hides edit, clone and comment', (
      tester,
    ) async {
      final items = await resolveItems(
        tester,
        _invoice(status: InvoiceStatus.sent),
        isAdmin: false,
      );

      expect(present(items, InvoiceAction.edit), isFalse);
      expect(present(items, InvoiceAction.cloneGroup), isFalse);
      expect(present(items, InvoiceAction.addComment), isFalse);
      // `logCall` writes the same activity note through the same repo method,
      // so it must sit inside the same `canEditInvoice` block — a divergence
      // here is a permission hole that nothing else would catch.
      expect(present(items, InvoiceAction.logCall), isFalse);
      expect(present(items, InvoiceAction.archive), isFalse);
    });

    testWidgets('edit_invoice alone surfaces edit but not the clone group', (
      tester,
    ) async {
      final items = await resolveItems(
        tester,
        _invoice(status: InvoiceStatus.sent),
        isAdmin: false,
        permissions: 'edit_invoice',
      );

      expect(present(items, InvoiceAction.edit), isTrue);
      expect(present(items, InvoiceAction.addComment), isTrue);
      expect(present(items, InvoiceAction.logCall), isTrue);
      expect(
        present(items, InvoiceAction.cloneGroup),
        isFalse,
        reason: 'cloning creates a new invoice — needs create_invoice',
      );
    });

    testWidgets('create_invoice alone surfaces the clone group but not edit', (
      tester,
    ) async {
      final items = await resolveItems(
        tester,
        _invoice(status: InvoiceStatus.sent),
        isAdmin: false,
        permissions: 'create_invoice',
      );

      expect(present(items, InvoiceAction.cloneGroup), isTrue);
      expect(present(items, InvoiceAction.clone), isTrue);
      expect(present(items, InvoiceAction.edit), isFalse);
      expect(enabled(items, InvoiceAction.markSent), isFalse);
    });

    testWidgets('an admin bypasses the permission string entirely', (
      tester,
    ) async {
      final items = await resolveItems(
        tester,
        _invoice(status: InvoiceStatus.sent),
      );

      expect(present(items, InvoiceAction.edit), isTrue);
      expect(present(items, InvoiceAction.cloneGroup), isTrue);
    });
  });

  group('archive / restore reflect entity state', () {
    testWidgets('a live invoice offers archive, not restore', (tester) async {
      final items = await resolveItems(tester, _invoice());

      expect(present(items, InvoiceAction.archive), isTrue);
      expect(present(items, InvoiceAction.restore), isFalse);
    });

    testWidgets('an archived invoice offers restore, not archive', (
      tester,
    ) async {
      final items = await resolveItems(
        tester,
        _invoice(archivedAt: 1700000000),
      );

      expect(present(items, InvoiceAction.restore), isTrue);
      expect(present(items, InvoiceAction.archive), isFalse);
    });

    testWidgets('a deleted invoice offers restore', (tester) async {
      final items = await resolveItems(tester, _invoice(isDeleted: true));

      expect(present(items, InvoiceAction.restore), isTrue);
    });
  });

  group('e-invoice actions require a configured channel', () {
    testWidgets('absent with no e-invoice type', (tester) async {
      final items = await resolveItems(
        tester,
        _invoice(status: InvoiceStatus.sent),
      );

      expect(present(items, InvoiceAction.sendEInvoice), isFalse);
      expect(present(items, InvoiceAction.validateEInvoice), isFalse);
    });

    testWidgets('both appear on a sent invoice once a channel is configured', (
      tester,
    ) async {
      // Positive control for the suppression test below — without it, an
      // `isFalse` there would also pass if the *status* gate were the cause
      // (canSendEInvoice requires status == sent) rather than the pending flag.
      final items = await resolveItems(
        tester,
        _invoice(status: InvoiceStatus.sent),
        eInvoiceType: 'PEPPOL',
      );

      expect(present(items, InvoiceAction.sendEInvoice), isTrue);
      expect(present(items, InvoiceAction.validateEInvoice), isTrue);
    });

    testWidgets('a queued send suppresses the send action but keeps validate', (
      tester,
    ) async {
      final withPending = await resolveItems(
        tester,
        _invoice(status: InvoiceStatus.sent),
        eInvoiceType: 'PEPPOL',
        sendEInvoicePending: true,
      );

      expect(
        present(withPending, InvoiceAction.sendEInvoice),
        isFalse,
        reason: 'double-enqueue would duplicate a compliance transmission',
      );
      expect(
        present(withPending, InvoiceAction.validateEInvoice),
        isTrue,
        reason:
            'validate is a read-only pre-flight — it is not gated on a '
            'pending send, so it must survive the suppression',
      );
    });

    testWidgets('send is status-gated to sent; validate is not', (
      tester,
    ) async {
      final draft = await resolveItems(
        tester,
        _invoice(),
        eInvoiceType: 'PEPPOL',
      );

      expect(present(draft, InvoiceAction.sendEInvoice), isFalse);
      expect(
        present(draft, InvoiceAction.validateEInvoice),
        isTrue,
        reason: 'validating a draft before sending is the main use case',
      );
    });
  });

  group('rectify is hidden unless the caller says it is eligible', () {
    testWidgets('absent by default', (tester) async {
      final items = await resolveItems(
        tester,
        _invoice(status: InvoiceStatus.sent),
      );

      expect(present(items, InvoiceAction.rectify), isFalse);
    });

    testWidgets('present when eligible', (tester) async {
      final items = await resolveItems(
        tester,
        _invoice(status: InvoiceStatus.sent),
        rectifyEligible: true,
      );

      expect(present(items, InvoiceAction.rectify), isTrue);
    });
  });

  testWidgets('the PDF group is always available regardless of status', (
    tester,
  ) async {
    final items = await resolveItems(
      tester,
      _invoice(status: InvoiceStatus.cancelled),
    );

    expect(enabled(items, InvoiceAction.viewPdf), isTrue);
    expect(enabled(items, InvoiceAction.downloadPdf), isTrue);
    expect(enabled(items, InvoiceAction.printPdf), isTrue);
    expect(enabled(items, InvoiceAction.deliveryNote), isTrue);
  });
}
