import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/billing/invitation.dart';

void main() {
  test('freshClone keeps the contact ids and drops all transient state', () {
    const inv = Invitation(
      id: 'i1',
      key: 'k1',
      link: 'https://portal/x',
      clientContactId: 'cc1',
      vendorContactId: 'vc1',
      sentDate: '2026-01-01',
      viewedDate: '2026-01-02',
      openedDate: '2026-01-03',
      emailStatus: 'bounced',
      emailError: 'mailbox full',
      messageId: 'm1',
    );

    final fresh = inv.freshClone();

    // Recipient survives…
    expect(fresh.clientContactId, 'cc1');
    expect(fresh.vendorContactId, 'vc1');
    // …every per-send lifecycle field is wiped.
    expect(fresh.id, isEmpty);
    expect(fresh.key, isEmpty);
    expect(fresh.link, isEmpty);
    expect(fresh.sentDate, isEmpty);
    expect(fresh.viewedDate, isEmpty);
    expect(fresh.openedDate, isEmpty);
    expect(fresh.emailStatus, isEmpty);
    expect(fresh.emailError, isEmpty);
    expect(fresh.messageId, isEmpty);
    // A cloned draft must not inherit a bounce flag.
    expect(fresh.hasBounced, isFalse);
  });

  group('hasSendHistory', () {
    // The server seeds one invitation per send-email contact when the
    // DOCUMENT is saved, so this — not `invitations.isNotEmpty` — is what the
    // Email History tab filters on (invoiceninja/flutter#146).
    test('a freshly seeded invitation has none', () {
      const inv = Invitation(id: 'i1', clientContactId: 'cc1');
      expect(inv.hasSendHistory, isFalse);
    });

    test('any single lifecycle field alone is enough', () {
      const base = Invitation(id: 'i1', clientContactId: 'cc1');
      expect(base.copyWith(sentDate: '2026-01-01').hasSendHistory, isTrue);
      expect(base.copyWith(openedDate: '2026-01-01').hasSendHistory, isTrue);
      // A portal view rather than a send — still history, deliberately.
      expect(base.copyWith(viewedDate: '2026-01-01').hasSendHistory, isTrue);
    });

    // The two disjuncts that keep Reactivate reachable. `showReactivate` is
    // gated on `hasBounced || hasError`, both strict subsets of these, so a
    // pending reactivate can never belong to a filtered-out row.
    test('a bounce with no sent_date survives', () {
      const inv = Invitation(
        id: 'i1',
        clientContactId: 'cc1',
        emailStatus: 'bounced',
        messageId: 'm1',
      );
      expect(inv.sentDate, isEmpty);
      expect(inv.hasSendHistory, isTrue);
      expect(inv.hasBounced, isTrue);
    });

    test('a failed send (email_error, no sent_date) survives', () {
      // NinjaMailerJob writes email_error without ever stamping sent_date.
      const inv = Invitation(
        id: 'i1',
        clientContactId: 'cc1',
        emailError: 'Connection refused',
      );
      expect(inv.sentDate, isEmpty);
      expect(inv.hasSendHistory, isTrue);
      expect(inv.hasError, isTrue);
    });

    test('a clone starts with an empty history', () {
      const inv = Invitation(
        id: 'i1',
        clientContactId: 'cc1',
        sentDate: '2026-01-01',
        emailStatus: 'delivered',
      );
      expect(inv.hasSendHistory, isTrue);
      expect(inv.freshClone().hasSendHistory, isFalse);
    });
  });

  group('sendState', () {
    const base = Invitation(id: 'i1', clientContactId: 'cc1');

    test('resolves each server-written email_status', () {
      expect(base.sendState, InvitationSendState.none);
      expect(
        base.copyWith(emailStatus: 'bounced').sendState,
        InvitationSendState.bounced,
      );
      expect(
        base.copyWith(emailStatus: 'spam').sendState,
        InvitationSendState.spam,
      );
      expect(
        base.copyWith(emailStatus: 'delivered').sendState,
        InvitationSendState.delivered,
      );
      expect(
        base.copyWith(emailError: 'boom').sendState,
        InvitationSendState.errored,
      );
    });

    test('a sent-but-unacknowledged row gets no pill', () {
      // Self-hosted SMTP never receives a webhook, so email_status stays
      // empty and the row carries only its `Sent:` line.
      expect(
        base.copyWith(sentDate: '2026-01-01').sendState,
        InvitationSendState.none,
      );
    });

    test('email_status wins over email_error whenever it is set', () {
      // The shape every webhook ESP actually produces: Postmark assigns
      // `email_error = Details` BEFORE branching on record type, and its
      // Delivery payload carries `Details` — the MTA's success line. Ranking
      // `errored` first would paint every successful hosted send red.
      final delivered = base.copyWith(
        emailStatus: 'delivered',
        emailError: 'smtp;250 2.0.0 OK 1615496594 z6si',
      );
      expect(delivered.sendState, InvitationSendState.delivered);
      // …and the same for the two failure states, which also carry Details.
      expect(
        base
            .copyWith(emailStatus: 'bounced', emailError: 'mailbox full')
            .sendState,
        InvitationSendState.bounced,
      );
      expect(
        base
            .copyWith(emailStatus: 'spam', emailError: 'marked as spam')
            .sendState,
        InvitationSendState.spam,
      );
    });

    test('errored is reached only when no webhook has spoken', () {
      // An MTA failure (NinjaMailerJob) and the VeriFactu 'primed' sentinel
      // are the two states that set email_error with no email_status.
      expect(
        base.copyWith(emailError: 'Connection refused').sendState,
        InvitationSendState.errored,
      );
      expect(
        base.copyWith(emailError: 'primed').sendState,
        InvitationSendState.errored,
      );
    });

    test('the dead email_status == error arm still resolves', () {
      // The server never writes it (the column is an enum of the other
      // three), but hasError's clause is still live code.
      expect(
        base.copyWith(emailStatus: 'error').sendState,
        InvitationSendState.errored,
      );
    });
  });

  group('hasSendHistory delegates its delivery half to sendState', () {
    const base = Invitation(id: 'i1', clientContactId: 'c1');

    test('an unmapped email_status cannot slip through as a bare row', () {
      // Unreachable today — the column is enum('delivered','bounced','spam') —
      // but the two predicates are one expression so a fourth value can never
      // pass the filter without a pill to render.
      final unknown = base.copyWith(emailStatus: 'deferred');
      expect(unknown.sendState, InvitationSendState.none);
      expect(unknown.hasSendHistory, isFalse);
    });

    test('every surviving row has a pill or a lifecycle line', () {
      const rows = [
        Invitation(id: 'a', sentDate: '2026-01-01'),
        Invitation(id: 'b', openedDate: '2026-01-01'),
        Invitation(id: 'c', viewedDate: '2026-01-01'),
        Invitation(id: 'd', emailStatus: 'bounced'),
        Invitation(id: 'e', emailStatus: 'spam'),
        Invitation(id: 'f', emailStatus: 'delivered'),
        Invitation(id: 'g', emailError: 'boom'),
      ];
      for (final row in rows.where((r) => r.hasSendHistory)) {
        final hasLifecycle =
            row.hasBeenSent || row.hasBeenOpened || row.hasBeenViewed;
        expect(
          hasLifecycle || row.sendState != InvitationSendState.none,
          isTrue,
          reason: 'row ${row.id} would render bare',
        );
      }
    });
  });

  group('who viewed it, and when (invoiceninja/flutter#154)', () {
    test('orders by parsed instant, not by string compare', () {
      // The trap this exists for: `viewedDate` is a raw wire String and the
      // server sends a MySQL datetime (space-separated). A lexical sort is
      // correct only while every value shares that shape — 'T' (84) sorts above
      // ' ' (32), so an ISO-T row would beat a space-form row at the same
      // instant. Both spellings here, deliberately.
      const rows = [
        Invitation(id: 'a', viewedDate: '2026-03-01 10:00:00'),
        Invitation(id: 'b', viewedDate: '2026-05-01T09:00:00'),
        Invitation(id: 'c', viewedDate: '2026-04-01 23:59:59'),
      ];
      expect(rows.viewedNewestFirst.map((i) => i.id), ['b', 'c', 'a']);
      expect(rows.newestViewed?.id, 'b');
    });

    test('ignores invitations nobody opened', () {
      const rows = [
        Invitation(id: 'sent', sentDate: '2026-03-01 10:00:00'),
        Invitation(id: 'seen', viewedDate: '2026-03-02 10:00:00'),
      ];
      expect(rows.viewedNewestFirst.map((i) => i.id), ['seen']);
      expect(rows.viewedCount, 1);
    });

    test('an unparseable date is still a view', () {
      // Dropping it would under-report; it sorts last among its own kind.
      const rows = [
        Invitation(id: 'junk', viewedDate: 'not-a-date'),
        Invitation(id: 'real', viewedDate: '2026-03-01 10:00:00'),
      ];
      expect(rows.viewedCount, 2);
      expect(rows.newestViewed?.id, 'real');
    });

    test('nobody looked', () {
      const rows = [Invitation(id: 'a'), Invitation(id: 'b')];
      expect(rows.newestViewed, isNull);
      expect(rows.viewedCount, 0);
      expect(const <Invitation>[].newestViewed, isNull);
    });

    test('the count is contacts, not views', () {
      // `markViewed()` is gated on `! $invitation->viewed_date`, so the server
      // records the FIRST view per contact and keeps no repeat count. Anything
      // rendered from this must say "people".
      const rows = [
        Invitation(
          id: 'a',
          clientContactId: 'c1',
          viewedDate: '2026-03-01 10:00:00',
        ),
        Invitation(
          id: 'b',
          clientContactId: 'c2',
          viewedDate: '2026-03-02 10:00:00',
        ),
      ];
      expect(rows.viewedCount, 2);
    });
  });
}
