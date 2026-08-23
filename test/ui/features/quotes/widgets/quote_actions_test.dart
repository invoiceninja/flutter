import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/quote_api_model.dart';
import 'package:admin/data/models/domain/quote.dart';
import 'package:admin/data/models/domain/quote_status.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/features/quotes/widgets/quote_actions.dart';

import '../../shell/_shell_test_helpers.dart';

/// Gating coverage for `QuoteActions.itemsFor`, mirroring the harness in
/// `purchase_order_actions_test.dart`.
///
/// Rules the source documents:
///   - mark sent is Draft-only;
///   - approve covers any non-terminal quote (Draft or Sent) — React's
///     `Draft || Sent`, admin-portal's `!isApproved`;
///   - convert-to-invoice gates purely on "not yet converted", drafts included;
///   - convert-to-project additionally needs an empty `projectId`;
///   - there is deliberately **no Cancel** — the server's quote bulk allow-list
///     has none, so it only ever produced a success toast and a dead 422'd
///     outbox row. The enum member survives as an unreachable no-op.
Quote _quote({
  String id = 'q1',
  QuoteStatus status = QuoteStatus.draft,
  String projectId = '',
  String invoiceId = '',
  bool isDeleted = false,
  int archivedAt = 0,
}) => Quote.fromApi(
  QuoteApi(
    id: id,
    statusId: status.wireId,
    projectId: projectId,
    invoiceId: invoiceId,
    isDeleted: isDeleted,
    archivedAt: archivedAt,
  ),
);

void main() {
  Future<List<EntityActionItem<QuoteAction>>> resolveItems(
    WidgetTester tester,
    Quote quote, {
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

    late List<EntityActionItem<QuoteAction>> items;
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Builder(
          builder: (context) {
            items = QuoteActions.itemsFor(context, quote, (_) {});
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return items;
  }

  bool enabled(List<EntityActionItem<QuoteAction>> items, QuoteAction kind) {
    final match = flattenActionItems(items).where((i) => i.kind == kind);
    return match.isNotEmpty && match.first.enabled;
  }

  bool present(List<EntityActionItem<QuoteAction>> items, QuoteAction kind) =>
      flattenActionItems(items).any((i) => i.kind == kind);

  group('mark sent — Draft only', () {
    for (final status in QuoteStatus.values) {
      testWidgets('${status.name} → ${status == QuoteStatus.draft}', (
        tester,
      ) async {
        final items = await resolveItems(tester, _quote(status: status));

        expect(
          enabled(items, QuoteAction.markSent),
          status == QuoteStatus.draft,
        );
      });
    }
  });

  group('approve — any non-terminal quote', () {
    for (final entry in {
      QuoteStatus.draft: true,
      QuoteStatus.sent: true,
      QuoteStatus.approved: false,
      QuoteStatus.converted: false,
      QuoteStatus.rejected: false,
    }.entries) {
      testWidgets('${entry.key.name} → ${entry.value}', (tester) async {
        final items = await resolveItems(tester, _quote(status: entry.key));

        expect(enabled(items, QuoteAction.approve), entry.value);
      });
    }
  });

  group('convert to invoice — until converted, drafts included', () {
    testWidgets('enabled on a draft', (tester) async {
      final items = await resolveItems(tester, _quote());

      expect(enabled(items, QuoteAction.convertToInvoice), isTrue);
    });

    testWidgets('disabled once the status is converted', (tester) async {
      final items = await resolveItems(
        tester,
        _quote(status: QuoteStatus.converted),
      );

      expect(enabled(items, QuoteAction.convertToInvoice), isFalse);
    });

    testWidgets('disabled once an invoice is linked', (tester) async {
      final items = await resolveItems(tester, _quote(invoiceId: 'inv1'));

      expect(enabled(items, QuoteAction.convertToInvoice), isFalse);
    });
  });

  group('convert to project — also needs an empty projectId', () {
    testWidgets('enabled on an unconverted quote with no project', (
      tester,
    ) async {
      final items = await resolveItems(tester, _quote());

      expect(enabled(items, QuoteAction.convertToProject), isTrue);
    });

    testWidgets('disabled once a project is linked', (tester) async {
      final items = await resolveItems(tester, _quote(projectId: 'p1'));

      expect(enabled(items, QuoteAction.convertToProject), isFalse);
    });

    testWidgets('disabled on a converted quote', (tester) async {
      final items = await resolveItems(
        tester,
        _quote(status: QuoteStatus.converted),
      );

      expect(enabled(items, QuoteAction.convertToProject), isFalse);
    });
  });

  // One case per status rather than a loop inside a single test: each
  // resolveItems call builds a full ShellFixture (in-memory DB + Services +
  // a periodic refresh timer), and looping would keep all five alive at once.
  group('Cancel is never offered — the server bulk allow-list has none', () {
    for (final status in QuoteStatus.values) {
      testWidgets('on a ${status.name} quote', (tester) async {
        final items = await resolveItems(tester, _quote(status: status));

        expect(
          present(items, QuoteAction.cancel),
          isFalse,
          reason: 'a cancel on ${status.name} would 422 in the outbox',
        );
      });
    }
  });

  group('permission gating (non-admin, non-owner)', () {
    testWidgets('no permissions hides edit and the clone group', (
      tester,
    ) async {
      final items = await resolveItems(tester, _quote(), isAdmin: false);

      expect(present(items, QuoteAction.edit), isFalse);
      expect(present(items, QuoteAction.cloneGroup), isFalse);
      expect(enabled(items, QuoteAction.approve), isFalse);
      expect(enabled(items, QuoteAction.sendEmail), isFalse);
    });

    testWidgets('edit_quote alone enables the workflow actions but not clone', (
      tester,
    ) async {
      final items = await resolveItems(
        tester,
        _quote(),
        isAdmin: false,
        permissions: 'edit_quote',
      );

      expect(present(items, QuoteAction.edit), isTrue);
      expect(enabled(items, QuoteAction.approve), isTrue);
      expect(enabled(items, QuoteAction.markSent), isTrue);
      expect(present(items, QuoteAction.cloneGroup), isFalse);
    });

    testWidgets('create_quote alone surfaces the clone group only', (
      tester,
    ) async {
      final items = await resolveItems(
        tester,
        _quote(),
        isAdmin: false,
        permissions: 'create_quote',
      );

      expect(present(items, QuoteAction.cloneGroup), isTrue);
      expect(present(items, QuoteAction.edit), isFalse);
      expect(enabled(items, QuoteAction.approve), isFalse);
    });
  });

  group('lifecycle actions reflect entity state', () {
    testWidgets('a live quote offers archive, not restore', (tester) async {
      final items = await resolveItems(tester, _quote());

      expect(present(items, QuoteAction.archive), isTrue);
      expect(present(items, QuoteAction.restore), isFalse);
    });

    testWidgets('an archived quote offers restore, not archive', (
      tester,
    ) async {
      final items = await resolveItems(tester, _quote(archivedAt: 1700000000));

      expect(present(items, QuoteAction.restore), isTrue);
      expect(present(items, QuoteAction.archive), isFalse);
    });
  });

  testWidgets('the PDF group is always available', (tester) async {
    final items = await resolveItems(
      tester,
      _quote(status: QuoteStatus.rejected),
    );

    expect(enabled(items, QuoteAction.viewPdf), isTrue);
    expect(enabled(items, QuoteAction.downloadPdf), isTrue);
    expect(enabled(items, QuoteAction.printPdf), isTrue);
  });

  group('confirm gating (invoiceninja/flutter#49)', () {
    // Approve is the action the issue names. The rule: gate a verb that fires
    // immediately and is outward-facing or hard to reverse; leave alone
    // anything that navigates to a screen with its own action button.
    const gated = {
      QuoteAction.approve,
      QuoteAction.markSent,
      QuoteAction.convertToInvoice,
      QuoteAction.convertToProject,
      QuoteAction.archive,
      QuoteAction.delete,
    };
    const ungated = {
      QuoteAction.edit,
      QuoteAction.clone,
      QuoteAction.viewPdf,
      QuoteAction.downloadPdf,
      QuoteAction.printPdf,
      // Opens the full Send Email screen, which has its own Send button.
      QuoteAction.sendEmail,
      QuoteAction.scheduleEmail,
      QuoteAction.addComment,
      QuoteAction.restore,
    };

    testWidgets('gates the immediate, outward-facing verbs', (tester) async {
      final items = await resolveItems(tester, _quote());
      final all = flattenActionItems(items);
      for (final kind in gated) {
        final match = all.where((i) => i.kind == kind);
        expect(match, isNotEmpty, reason: '$kind should be present on a draft');
        expect(match.first.confirm, isTrue, reason: '$kind should be gated');
      }
    });

    testWidgets('leaves navigation and reversible verbs alone', (tester) async {
      // Archived so `restore` is in the list too.
      final items = await resolveItems(
        tester,
        _quote(status: QuoteStatus.sent, archivedAt: 1700000000),
      );
      final all = flattenActionItems(items);
      for (final kind in ungated) {
        for (final item in all.where((i) => i.kind == kind)) {
          expect(item.confirm, isFalse, reason: '$kind should not be gated');
        }
      }
    });

    testWidgets('a gated item names the quote in the prompt', (tester) async {
      // The subject is what tells the user *which* row they hit — the whole
      // reason the prompt is worth an extra tap on a phone.
      final numbered = Quote.fromApi(
        const QuoteApi(id: 'q1', statusId: '1', number: '0012'),
      );
      final items = await resolveItems(tester, numbered);
      final approve = flattenActionItems(
        items,
      ).firstWhere((i) => i.kind == QuoteAction.approve);
      expect(approve.confirmSubject, '#0012');
    });

    testWidgets('an unnumbered quote yields a blank subject, not a bare #', (
      tester,
    ) async {
      final items = await resolveItems(tester, _quote());
      final approve = flattenActionItems(
        items,
      ).firstWhere((i) => i.kind == QuoteAction.approve);
      expect(approve.confirmSubject, isEmpty);
    });
  });
}
