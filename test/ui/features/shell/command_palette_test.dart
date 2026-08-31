import 'dart:io';

import 'package:flutter/material.dart' show Icons, SizedBox;
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/entity_modules.dart' show DisabledEntityDispatcher;
import 'package:admin/data/models/domain/search_result.dart';
import 'package:admin/domain/entity_registry.dart';
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

  group('deepLinkSearchHit — pasting a shared link', () {
    final registry = EntityRegistry({
      EntityType.client: EntityHandlers(
        type: EntityType.client,
        wireName: 'client',
        apiPath: '/api/v1/clients',
        routePath: '/clients',
        icon: Icons.circle,
        dispatcher: DisabledEntityDispatcher(EntityType.client),
        detailBuilder: (_, _) => const SizedBox.shrink(),
      ),
    });

    test('resolves a pasted record link to one hit', () {
      final hit = deepLinkSearchHit(
        '  invoiceninja://app/clients/abc?company=co1  ',
        registry,
      );
      expect(hit, isNotNull);
      expect(hit!.group, kDeepLinkSearchGroup);
      expect(hit.name, '/clients/abc');
      // The ORIGINAL uri, not the resolved route — activation hands it back to
      // DeepLinkRouter so a cross-company link still switches company.
      expect(hit.path, 'invoiceninja://app/clients/abc?company=co1');
    });

    test('ignores ordinary search text', () {
      expect(deepLinkSearchHit('acme corp', registry), isNull);
      expect(deepLinkSearchHit('', registry), isNull);
      expect(deepLinkSearchHit('https://example.test', registry), isNull);
    });

    test('ignores a link this build cannot route', () {
      expect(
        deepLinkSearchHit('invoiceninja://app/widgets/x', registry),
        isNull,
      );
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

  // Issue #101 was "poor information density" about the sidebar's Search box.
  // The palette it opens had the same defect on the same device: three
  // keyboard-only affordances rendered unconditionally, including the `Ctrl/`
  // chip visible in the reporter's Android screenshot. Scanned rather than
  // pumped — the palette body is private and DI-bound, and `flutter test`'s
  // default 800x600 surface has `shortestSide == 600`, so `isPhone` is false
  // out of the box and a pump would need an explicit resize.
  group('phone chrome (issue #101)', () {
    // Comments stripped: these scans assert what the widget *does*, and the
    // prose explaining a guard names the very identifiers the guard forbids —
    // the `_onChanged` check below first went red against the comment that
    // documents why the close button must not call it.
    final palette = File('lib/ui/features/shell/widgets/command_palette.dart')
        .readAsStringSync()
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');

    test('both hint spread sites are gated on isPhone', () {
      // The footer is one `_keyboardHints` definition spread twice, so the
      // check is a short marker per site — the earlier version scanned a fixed
      // 900-char window back from each `Text('esc')` against an actual
      // distance of 604, i.e. ~300 chars of slack before a couple of added
      // comment lines turned CI red with no behaviour change.
      final spreads = RegExp(
        r'\.\.\._keyboardHints\(',
      ).allMatches(palette).toList();
      expect(
        spreads,
        hasLength(2),
        reason: 'the hints render under both the results and recents lists',
      );
      for (final m in spreads) {
        expect(
          palette.substring(m.start - 20, m.start).contains('if (!phone)'),
          isTrue,
          reason:
              'a keyboard hint row still renders on a phone, where none of '
              '↑↓ / ↵ / esc can be pressed',
        );
      }
      expect(
        RegExp(r"Text\('esc'\)").allMatches(palette),
        hasLength(1),
        reason:
            'one definition, two spread sites — a second literal means the '
            'block was copied back and the two states can now diverge',
      );
    });

    test('the modifier keycap is gated, and the close button is not', () {
      final suffix = palette.indexOf('suffixIcon:');
      expect(suffix, isNot(-1));
      final slot = palette.substring(suffix, suffix + 2000);

      expect(
        slot.contains('if (!phone)'),
        isTrue,
        reason: 'the ⌘/ chip is keyboard-only chrome',
      );
      expect(
        slot.contains('if (touch)'),
        isTrue,
        reason:
            'the close button is gated on touch, not isPhone: the sidebar '
            'mounts its Search box on Env.isTouchPrimary, so a tablet can '
            'reach this dialog and needs a visible way out of it',
      );
      expect(
        slot.contains('Icons.close'),
        isTrue,
        reason: 'the freed slot carries the close button',
      );
    });

    test('the close button closes — it never doubles as a clear', () {
      final close = palette.indexOf('Icons.close');
      expect(close, isNot(-1));
      final button = palette.substring(close, close + 1400);

      expect(
        button.contains('Navigator.of(context).pop()'),
        isTrue,
        reason: 'tapping it must always leave the palette',
      );
      // Clearing through `_onChanged('')` arms the debounce into `_run('')`,
      // and `SearchApi.search` omits the `search` param for a blank query, so
      // the server answers with an unfiltered page (up to 1000 clients) under
      // an empty field instead of the Recents list.
      expect(
        button.contains('_onChanged'),
        isFalse,
        reason: 'a clear must reset _results/_selected itself, not refetch',
      );
      expect(
        button.contains('_controller.clear()'),
        isFalse,
        reason: 'this button closes; clearing is the keyboard\'s job',
      );
    });

    test('the dialog takes phone geometry', () {
      // `Dialog` adds the keyboard height to `insetPadding`, so the desktop
      // `top: 120` + `maxHeight: 520` overflowed a landscape phone by ~50 px
      // and clipped the search field itself.
      expect(
        RegExp(r'Breakpoints\.isPhone\(').allMatches(palette),
        hasLength(2),
        reason:
            'the gate is resolved twice by design — once in the dialog '
            'builder for geometry, once in the State for its chrome. Matched '
            'without the argument name: pinning `(ctx)` failed on a rename '
            'claiming the gate had been removed.',
      );
      final inset = palette.indexOf('insetPadding:');
      expect(inset, isNot(-1));
      expect(
        palette.substring(inset, inset + 200).contains('phone'),
        isTrue,
        reason: 'insetPadding must branch on phone',
      );
      final maxH = palette.indexOf('maxHeight:');
      expect(maxH, isNot(-1));
      expect(
        palette.substring(maxH, maxH + 120).contains('phone'),
        isTrue,
        reason: 'maxHeight must branch on phone',
      );
    });
  });
}
