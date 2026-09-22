import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/dashboard/billing_status_tabs.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/list_status_tabs.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';

/// The union behind the dashboard's Invoices & Quotes strip
/// (invoiceninja/flutter#155).
///
/// Everything asserted here is silent if it breaks. A tab that borrows the
/// wrong entity's mode id still renders, still highlights and still counts —
/// it just counts and lists *every* row of that entity, because both DAO seams
/// fail OPEN on an id they don't recognise.
void main() {
  List<BillingStatusTab> tabs({bool invoices = true, bool quotes = true}) =>
      billingStatusTabsFor(
        invoiceModes: kInvoiceBadgeModes,
        quoteModes: kQuoteBadgeModes,
        includeInvoices: invoices,
        includeQuotes: quotes,
      );

  List<String> idsOf(List<BillingStatusTab> t) => [for (final x in t) x.id];

  group('the tab set', () {
    test('leads with All and then the declared order', () {
      expect(idsOf(tabs()), [
        '', // All
        'draft',
        'unpaid',
        'sent',
        'approved',
        'rejected',
        'cancelled',
        'expired',
      ]);
      expect(tabs().first.isAll, isTrue);
    });

    test('per-entity ids are never inferred from the tab', () {
      final byId = {for (final t in tabs()) t.id: t};

      // Quote-only buckets: the invoice side must be null, NOT the tab's id.
      // `InvoiceDao.badgeModePredicate` returns null for 'approved', and both
      // consumers treat null as "no narrowing" — `watchPage` skips its WHERE
      // and `watchBadgeCount` does `if (extra != null)` — so passing it down
      // would list and count every invoice in the company.
      for (final id in [
        'sent',
        'approved',
        'rejected',
        'cancelled',
        'expired',
      ]) {
        expect(byId[id]!.invoiceModeId, isNull, reason: id);
        expect(byId[id]!.quoteModeId, id, reason: id);
        expect(byId[id]!.isMixed, isFalse, reason: id);
      }

      // Invoice-only.
      expect(byId['unpaid']!.quoteModeId, isNull);
      expect(byId['unpaid']!.invoiceModeId, 'unpaid');

      // Mixed.
      expect(byId['draft']!.invoiceModeId, 'draft');
      expect(byId['draft']!.quoteModeId, 'draft');
      expect(byId['draft']!.isMixed, isTrue);

      // `All` counts both totals.
      expect(byId['']!.invoiceModeId, kBadgeModeTotal);
      expect(byId['']!.quoteModeId, kBadgeModeTotal);
    });

    test('a missing half drops its tabs and its side of a mixed one', () {
      expect(idsOf(tabs(quotes: false)), ['', 'draft', 'unpaid']);
      expect(idsOf(tabs(invoices: false)), [
        '',
        'draft',
        'sent',
        'approved',
        'rejected',
        'cancelled',
        'expired',
      ]);

      final invoicesOnly = {for (final t in tabs(quotes: false)) t.id: t};
      expect(invoicesOnly['draft']!.quoteModeId, isNull);
      expect(invoicesOnly['draft']!.isMixed, isFalse);
      expect(invoicesOnly['']!.quoteModeId, isNull);
    });

    test('no participating half → no strip at all', () {
      expect(tabs(invoices: false, quotes: false), isEmpty);
    });
  });

  group('derived from the list strips, not invented', () {
    // The reason the panel can never disagree with the list its footer links
    // land on: filtered to each entity, the panel order IS that entity's own
    // `kListStatusTabs` order. This fails the day someone reorders a strip.
    test('the invoice subsequence is the Invoices strip, minus overdue', () {
      final mine = [
        for (final id in kBillingPipelineTabOrder)
          if (isKnownStatusTabMode(EntityType.invoice, id)) id,
      ];
      final strip = [
        for (final s in kListStatusTabs[EntityType.invoice]!)
          if (s.modeId != 'overdue') s.modeId,
      ];
      expect(mine, strip);
    });

    test('the quote subsequence is the Quotes strip', () {
      final mine = [
        for (final id in kBillingPipelineTabOrder)
          if (isKnownStatusTabMode(EntityType.quote, id)) id,
      ];
      final strip = [
        for (final s in kListStatusTabs[EntityType.quote]!) s.modeId,
      ];
      expect(mine, strip);
    });

    test('the order holds every tabbable mode of either entity but overdue', () {
      // Both directions. The forward one catches a typo; the REVERSE one is
      // what catches a mode added to a list catalog later that never reaches
      // the panel — which nothing else would say out loud.
      final union = {
        for (final type in [EntityType.invoice, EntityType.quote])
          for (final s in kListStatusTabs[type]!) s.modeId,
      };
      expect(
        kBillingPipelineTabOrder.toSet(),
        union.difference({'overdue'}),
        reason:
            'overdue is omitted deliberately — "Needs your attention" already '
            'lists past-due invoices. Any OTHER difference is a tab that '
            'silently never reaches the panel, or one that names nothing.',
      );
    });

    test('no duplicates', () {
      expect(
        kBillingPipelineTabOrder.length,
        kBillingPipelineTabOrder.toSet().length,
      );
    });
  });

  group('a mixed tab borrows one side label and tone', () {
    test('and the two sides must agree on both', () {
      // A merged badge draws its label and tone from ONE catalog while counting
      // BOTH populations, so a divergence would make the badge an urgency claim
      // about rows that are half exempt — invisibly. Benign today only because
      // `draft` happens to be spelled identically in both.
      final invoiceById = {for (final m in kInvoiceBadgeModes) m.id: m};
      final quoteById = {for (final m in kQuoteBadgeModes) m.id: m};
      var checked = 0;
      for (final tab in tabs()) {
        if (!tab.isMixed) continue;
        final i = invoiceById[tab.invoiceModeId]!;
        final q = quoteById[tab.quoteModeId]!;
        expect(i.labelKey, q.labelKey, reason: tab.id);
        expect(i.tone, q.tone, reason: tab.id);
        checked++;
      }
      expect(checked, greaterThan(0), reason: 'no mixed tab was exercised');
    });

    test('label and tone resolve off the borrowed mode', () {
      final byId = {for (final t in tabs()) t.id: t};
      expect(byId['']!.labelKey, 'all');
      expect(byId['']!.tone, SidebarBadgeTone.neutral);
      expect(byId['draft']!.labelKey, 'draft');
      expect(byId['draft']!.tone, SidebarBadgeTone.muted);
      expect(byId['unpaid']!.tone, SidebarBadgeTone.warning);
      expect(byId['expired']!.tone, SidebarBadgeTone.danger);
      // Terminal, nothing to act on — and a second red bucket would compete
      // with Expired on a strip built to be glanced at.
      expect(byId['rejected']!.tone, SidebarBadgeTone.neutral);
    });
  });

  group('isLocalOnly', () {
    test('only `rejected` — the one bucket with no server branch', () {
      final byId = {for (final t in tabs()) t.id: t};
      expect(byId['rejected']!.isLocalOnly, isTrue);
      for (final id in ['draft', 'unpaid', 'sent', 'approved', 'expired']) {
        expect(byId[id]!.isLocalOnly, isFalse, reason: id);
      }
    });

    test('`All` is never local-only, on any module combination', () {
      // The trap this property exists to close. `All` carries
      // `kBadgeModeTotal`, which has no `ListStatusTabSpec` at all — so asking
      // `statusTabServerFilters` about it answers null exactly as a local-only
      // bucket does, and a naive derivation labels an ordinary unnarrowed
      // server page "not synced yet". Single-module companies are where it
      // showed, because there the other half is null too.
      for (final t in [tabs(), tabs(invoices: false), tabs(quotes: false)]) {
        expect(t.first.isAll, isTrue);
        expect(t.first.isLocalOnly, isFalse);
      }
    });

    test('a half dropping out does not make a server-narrowed tab local', () {
      final quotesOnly = {for (final t in tabs(invoices: false)) t.id: t};
      expect(quotesOnly['draft']!.isLocalOnly, isFalse);
      expect(quotesOnly['rejected']!.isLocalOnly, isTrue);
    });
  });

  group('billingStatusTabById heals a stored selection', () {
    test('resolves a live id', () {
      expect(billingStatusTabById(tabs(), 'expired')?.id, 'expired');
    });

    test('null for an id this company can no longer use', () {
      // Quotes module off, `view_quote` revoked, or a mode retired. Left
      // unhealed the strip shows nothing selected and the view model subscribes
      // to a tab with no participating halves.
      expect(billingStatusTabById(tabs(quotes: false), 'expired'), isNull);
      expect(billingStatusTabById(tabs(), 'gone'), isNull);
    });

    test('null for null/empty — the resting All selection', () {
      expect(billingStatusTabById(tabs(), null), isNull);
      expect(billingStatusTabById(tabs(), ''), isNull);
    });
  });
}
