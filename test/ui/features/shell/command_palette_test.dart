import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/search_result.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/features/settings/settings_search_catalog.dart';
import 'package:admin/ui/features/shell/widgets/command_palette.dart';

void main() {
  group('entityTypeForSearchGroup', () {
    test('maps every entity search group to its EntityType', () {
      expect(entityTypeForSearchGroup('clients'), EntityType.client);
      expect(entityTypeForSearchGroup('client_contacts'), EntityType.client);
      expect(entityTypeForSearchGroup('invoices'), EntityType.invoice);
      expect(entityTypeForSearchGroup('quotes'), EntityType.quote);
      expect(entityTypeForSearchGroup('credits'), EntityType.credit);
      expect(entityTypeForSearchGroup('payments'), EntityType.payment);
      expect(
        entityTypeForSearchGroup('recurrings'),
        EntityType.recurringInvoice,
      );
      expect(
        entityTypeForSearchGroup('recurring_invoices'),
        EntityType.recurringInvoice,
      );
      expect(entityTypeForSearchGroup('projects'), EntityType.project);
      expect(entityTypeForSearchGroup('tasks'), EntityType.task);
      expect(entityTypeForSearchGroup('products'), EntityType.product);
      expect(entityTypeForSearchGroup('expenses'), EntityType.expense);
      expect(entityTypeForSearchGroup('vendors'), EntityType.vendor);
      expect(entityTypeForSearchGroup('vendor_contacts'), EntityType.vendor);
    });

    test('purchase orders route through the registry, not the raw path', () {
      // Without this the group fell through to `context.go(r.path)`, skipping
      // the module + permission gate every other entity hit goes through.
      expect(
        entityTypeForSearchGroup('purchase_orders'),
        EntityType.purchaseOrder,
      );
    });

    test('settings + unknown groups → null (caller uses server path)', () {
      expect(entityTypeForSearchGroup('settings'), isNull);
      expect(entityTypeForSearchGroup('whatever'), isNull);
      expect(entityTypeForSearchGroup(''), isNull);
    });
  });

  group('recordIdForSearchHit', () {
    SearchResult hit(
      String group, {
      required String id,
      required String path,
    }) => SearchResult(group: group, name: 'x', id: id, path: path);

    test('contact hits route by the PARENT id from `path`, not their own', () {
      // Elasticsearch branch: `id` is the CONTACT's hashed id, `path` carries
      // the parent. Routing by `id` opened a client that doesn't exist.
      expect(
        recordIdForSearchHit(
          hit('client_contacts', id: 'CONTACT9', path: '/clients/CLIENT1'),
        ),
        'CLIENT1',
      );
      expect(
        recordIdForSearchHit(
          hit('vendor_contacts', id: 'CONTACT9', path: '/vendors/VENDOR1'),
        ),
        'VENDOR1',
      );
    });

    test('non-ES fallback shape resolves identically', () {
      // `clientMap` puts the parent id in BOTH fields, so one code path covers
      // either backend.
      expect(
        recordIdForSearchHit(
          hit('client_contacts', id: 'CLIENT1', path: '/clients/CLIENT1'),
        ),
        'CLIENT1',
      );
    });

    test('degrades to `id` when the path is unusable', () {
      expect(
        recordIdForSearchHit(hit('client_contacts', id: 'FALLBACK', path: '')),
        'FALLBACK',
      );
      expect(
        recordIdForSearchHit(hit('client_contacts', id: 'FALLBACK', path: '/')),
        'FALLBACK',
      );
    });

    test('non-contact groups keep their own id', () {
      expect(
        recordIdForSearchHit(
          hit('clients', id: 'CLIENT1', path: '/clients/CLIENT1'),
        ),
        'CLIENT1',
      );
      // Invoices carry `/invoices/{id}/edit`; the trailing segment is NOT an id.
      expect(
        recordIdForSearchHit(
          hit('invoices', id: 'INV1', path: '/invoices/INV1/edit'),
        ),
        'INV1',
      );
    });
  });

  group('settings hits are served locally', () {
    test('SearchResult.isSettings identifies the group the palette drops', () {
      expect(
        const SearchResult(
          group: 'settings',
          name: 'x',
          id: '',
          path: '/settings/subscriptions',
        ).isSettings,
        isTrue,
      );
      expect(
        const SearchResult(
          group: 'clients',
          name: 'x',
          id: 'a',
          path: '/clients/a',
        ).isSettings,
        isFalse,
      );
    });

    test('every catalog section route is a registered app route', () {
      // The palette now navigates `hit.section.route`, so an unroutable entry
      // would reproduce the very dead-end this replaced — and `errorBuilder`
      // is registered at the ROOT, so it takes the whole shell down with it.
      final routes = File(
        'lib/ui/features/settings/settings_routes.dart',
      ).readAsStringSync();
      final modules = File('lib/app/entity_modules.dart').readAsStringSync();
      final registered =
          RegExp(
              r"path: '([a-z_]+)'",
            ).allMatches(routes).map((m) => m.group(1)!).toSet()
            ..addAll(
              RegExp(
                r"_leaf\(\s*'([a-z_/]+)'",
              ).allMatches(routes).map((m) => m.group(1)!),
            )
            ..addAll(
              RegExp(
                r"routePath: '/settings/([a-z_/]+)'",
              ).allMatches(modules).map((m) => m.group(1)!),
            );

      final sections = {for (final s in kSettingsSections) s.slug: s.route};
      expect(sections, isNotEmpty);
      final unroutable = [
        for (final entry in sections.entries)
          if (!registered.contains(entry.key)) '${entry.key} → ${entry.value}',
      ];
      expect(
        unroutable,
        isEmpty,
        reason:
            'These settings sections are reachable from the command palette '
            'but have no registered route:\n  ${unroutable.join('\n  ')}',
      );
    });
  });
}
