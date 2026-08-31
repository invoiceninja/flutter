import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/entity_modules.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/list_status_tabs.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';

/// Coherence between the status-tab strip (issue #98) and the sidebar-counter
/// catalog it is built on.
///
/// The failure this exists for is silent in both directions: declare a tab for
/// a mode the entity doesn't have and it just never renders; add a badge mode
/// and forget the tab and the strip quietly stays one bucket short of what the
/// sidebar offers. Neither shows up in a build or a screenshot.
void main() {
  final modesByType = {
    for (final m in kWiredEntityModules) m.type: m.badgeModes,
  };

  /// The modes that are eligible to be a tab: everything the entity declares
  /// minus the two universals and the personal lens.
  Set<String> tabbableModeIds(List<SidebarBadgeMode> modes) => {
    for (final m in modes)
      if (m.id != kBadgeModeTotal &&
          m.id != kBadgeModeNone &&
          m.id != kBadgeModeAssignedToMe)
        m.id,
  };

  test('every tab names a mode the entity actually declares', () {
    for (final entry in kListStatusTabs.entries) {
      final modes = modesByType[entry.key];
      expect(
        modes,
        isNotNull,
        reason: '${entry.key.name} has tabs but no wired entity module',
      );
      final declared = tabbableModeIds(modes!);
      for (final spec in entry.value) {
        expect(
          declared,
          contains(spec.modeId),
          reason:
              '${entry.key.name} tab "${spec.modeId}" is not one of its badge '
              'modes ($declared) — it would render no label and count nothing',
        );
      }
    }
  });

  test('every tabbable badge mode has a tab', () {
    for (final entry in kListStatusTabs.entries) {
      final declared = tabbableModeIds(modesByType[entry.key]!);
      final tabbed = {for (final s in entry.value) s.modeId};
      expect(
        tabbed,
        declared,
        reason:
            '${entry.key.name}: the strip and the sidebar counter menu offer '
            'different buckets. If a mode genuinely should not be a tab, say so '
            'here rather than leaving the gap implicit.',
      );
    }
  });

  test('every entity with tabbable modes has a strip', () {
    for (final module in kWiredEntityModules) {
      if (tabbableModeIds(module.badgeModes).isEmpty) continue;
      expect(
        kListStatusTabs,
        contains(module.type),
        reason:
            '${module.type.name} declares status counters but no tabs — add it '
            'to kListStatusTabs (in lifecycle order), or a new entity ships '
            'with a sidebar counter and no way to filter by it',
      );
    }
  });

  test('no tab duplicates a mode within one entity', () {
    for (final entry in kListStatusTabs.entries) {
      final ids = [for (final s in entry.value) s.modeId];
      expect(ids, hasLength(ids.toSet().length), reason: entry.key.name);
    }
  });

  test('assigned_to_me is never a tab — badgeModeListFilter hard-codes an '
      'empty user id, so one would silently match nothing', () {
    for (final entry in kListStatusTabs.entries) {
      expect(
        [for (final s in entry.value) s.modeId],
        isNot(contains(kBadgeModeAssignedToMe)),
        reason: entry.key.name,
      );
    }
  });

  group('server filters', () {
    test('are never empty when present — an empty set would send a blank '
        'query param rather than meaning "local-only"', () {
      for (final entry in kListStatusTabs.entries) {
        for (final spec in entry.value) {
          for (final values in spec.serverFilters.values) {
            expect(
              values,
              isNotEmpty,
              reason: '${entry.key.name}/${spec.modeId}',
            );
          }
        }
      }
    });

    test('statusTabServerFilters returns null exactly for the local-only '
        'tabs', () {
      // The audited local-only set (see the plan / the doc comments in
      // list_status_tabs.dart). Spelled out so widening one of these later is a
      // deliberate edit here, with the superset argument made in review.
      const localOnly = {
        (EntityType.expense, 'unpaid'),
        (EntityType.purchaseOrder, 'sent'),
        // Both were mapped once and deliberately un-mapped: the only available
        // superset is nearly the whole table, so it bought no narrowing while
        // costing the delta cursor and the auto-chain.
        (EntityType.payment, 'unapplied'),
        (EntityType.credit, 'unapplied'),
        (EntityType.client, 'outstanding'),
        (EntityType.client, 'overdue'),
        (EntityType.product, 'low_stock'),
        (EntityType.product, 'out_of_stock'),
        (EntityType.project, 'overdue'),
        (EntityType.project, 'over_budget'),
        (EntityType.vendor, 'unpaid_expenses'),
        (EntityType.vendor, 'open_purchase_orders'),
        (EntityType.recurringExpense, 'draft'),
        (EntityType.recurringExpense, 'pending'),
        (EntityType.recurringExpense, 'active'),
        (EntityType.recurringExpense, 'paused'),
      };
      for (final entry in kListStatusTabs.entries) {
        for (final spec in entry.value) {
          final resolved = statusTabServerFilters(entry.key, spec.modeId);
          final expectedLocal = localOnly.contains((entry.key, spec.modeId));
          expect(
            resolved == null,
            expectedLocal,
            reason:
                '${entry.key.name}/${spec.modeId} is '
                '${expectedLocal ? "expected to be local-only" : "expected to "
                          "narrow the fetch"}',
          );
        }
      }
    });
  });

  group('local narrowing (the auto-chain contract)', () {
    test('a widened spec must actually carry a server filter — widened means '
        '"the mapping is a superset", which is meaningless without one', () {
      for (final entry in kListStatusTabs.entries) {
        for (final spec in entry.value) {
          if (!spec.widened) continue;
          expect(
            spec.serverFilters,
            isNotEmpty,
            reason: '${entry.key.name}/${spec.modeId}',
          );
        }
      }
    });

    test('statusTabNarrowsLocally is true for BOTH unmapped and widened tabs — '
        'a widened fetch still leaves the local predicate throwing rows away, '
        'which is what starves the page and fakes "No records found"', () {
      // Widened: the fetch narrows, but not all the way.
      expect(statusTabNarrowsLocally(EntityType.quote, 'expired'), isTrue);
      expect(statusTabNarrowsLocally(EntityType.expense, 'logged'), isTrue);
      expect(statusTabNarrowsLocally(EntityType.invoice, 'overdue'), isTrue);
      // Unmapped: the fetch doesn't narrow at all.
      expect(statusTabNarrowsLocally(EntityType.payment, 'unapplied'), isTrue);
      expect(
        statusTabNarrowsLocally(EntityType.project, 'over_budget'),
        isTrue,
      );
      // Exact: the server returns precisely the tab's rows, so paging is its
      // job and the chain would only burn fetches.
      expect(statusTabNarrowsLocally(EntityType.invoice, 'draft'), isFalse);
      expect(statusTabNarrowsLocally(EntityType.quote, 'sent'), isFalse);
      expect(
        statusTabNarrowsLocally(EntityType.transaction, 'matched'),
        isFalse,
      );
      // Unknown mode / entity: nothing to narrow.
      expect(statusTabNarrowsLocally(EntityType.invoice, 'nope'), isFalse);
      expect(statusTabNarrowsLocally(EntityType.design, 'draft'), isFalse);
    });
  });

  group('resolution', () {
    test('All leads the strip and filters nothing', () {
      final tabs = listStatusTabsFor(
        EntityType.invoice,
        modes: kInvoiceBadgeModes,
        trackInventory: false,
      );
      expect(tabs.first.isAll, isTrue);
      expect(tabs.first.listModeId, isNull);
      expect(tabs.first.countModeId, kBadgeModeTotal);
      expect(tabs.first.labelKey, 'all');
      expect(tabs.map((t) => t.listModeId).skip(1), [
        'draft',
        'unpaid',
        'overdue',
      ]);
    });

    test('label and tone come from the mode, so the strip and the rail can '
        'never disagree about what a bucket is called', () {
      final tabs = listStatusTabsFor(
        EntityType.invoice,
        modes: kInvoiceBadgeModes,
        trackInventory: false,
      );
      final overdue = tabs.firstWhere((t) => t.listModeId == 'overdue');
      expect(overdue.labelKey, 'overdue');
      expect(overdue.tone, SidebarBadgeTone.danger);
    });

    test('an inventory-gated strip collapses to nothing rather than to a '
        'lone All tab', () {
      expect(
        listStatusTabsFor(
          EntityType.product,
          modes: kProductBadgeModes,
          trackInventory: false,
        ),
        isEmpty,
      );
      expect(
        listStatusTabsFor(
          EntityType.product,
          modes: kProductBadgeModes,
          trackInventory: true,
        ),
        hasLength(3),
      );
    });

    test('an entity with no spec gets no strip', () {
      expect(
        listStatusTabsFor(
          EntityType.design,
          modes: kDefaultBadgeModes,
          trackInventory: true,
        ),
        isEmpty,
      );
    });
  });

  group('isKnownStatusTabMode', () {
    test('accepts a live mode and rejects a retired one', () {
      expect(isKnownStatusTabMode(EntityType.invoice, 'draft'), isTrue);
      expect(isKnownStatusTabMode(EntityType.invoice, 'gone'), isFalse);
      // Cross-entity: quote has `sent`, invoice does not.
      expect(isKnownStatusTabMode(EntityType.quote, 'sent'), isTrue);
      expect(isKnownStatusTabMode(EntityType.invoice, 'sent'), isFalse);
      expect(isKnownStatusTabMode(EntityType.design, 'draft'), isFalse);
    });
  });
}
