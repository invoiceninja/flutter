import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sidebar_menu.dart';

List<String> _ids(List<SidebarMenuEntryPref> entries) => [
  for (final e in entries) e.id,
];

void main() {
  group('kSidebarMenuFixedIds', () {
    // The two id spaces share one stored list, so a collision would hand one
    // row the other's position — silently, and only for users who had
    // customised their menu.
    test('never collides with an EntityType name', () {
      final entityNames = {for (final t in EntityType.values) t.name};
      for (final id in kSidebarMenuFixedIds) {
        expect(
          entityNames,
          isNot(contains(id)),
          reason:
              'Menu id "$id" is also an EntityType name. Rename one of them — '
              'the sidebar stores both in a single ordered list.',
        );
      }
    });

    test('has no duplicates', () {
      expect(
        kSidebarMenuFixedIds.toSet(),
        hasLength(kSidebarMenuFixedIds.length),
      );
    });
  });

  group('SidebarMenuEntryPref', () {
    test('round-trips through toJson / tryParse', () {
      for (final pref in [
        const SidebarMenuEntryPref(id: 'client'),
        const SidebarMenuEntryPref(id: 'invoice', visible: false),
      ]) {
        expect(SidebarMenuEntryPref.tryParse(pref.toJson()), pref);
      }
    });

    test('rejects anything that is not exactly "<id>|<0 or 1>"', () {
      // A truncated entry must be dropped, not read as hidden — that would make
      // a destination vanish from the menu with nothing to explain why.
      for (final raw in <Object?>[
        null,
        42,
        '',
        'client',
        'client|',
        'client|2',
        'client|true',
        '|1',
        'client|1|extra',
      ]) {
        expect(
          SidebarMenuEntryPref.tryParse(raw),
          isNull,
          reason: 'should have rejected ${raw.runtimeType}: $raw',
        );
      }
    });
  });

  group('sidebarMenuLayoutFromName', () {
    test('parses known names and falls back to list', () {
      expect(sidebarMenuLayoutFromName('grid'), SidebarMenuLayout.grid);
      expect(sidebarMenuLayoutFromName('list'), SidebarMenuLayout.list);
      // A layout written by a newer build, or a corrupt value, renders as what
      // every install shows today rather than throwing at boot.
      expect(sidebarMenuLayoutFromName('carousel'), SidebarMenuLayout.list);
      expect(sidebarMenuLayoutFromName(null), SidebarMenuLayout.list);
      expect(sidebarMenuLayoutFromName(7), SidebarMenuLayout.list);
    });
  });

  group('resolveMenuEntries', () {
    const defaults = ['dashboard', 'client', 'invoice', 'quote', 'reports'];

    test('an empty preference is the default order, all visible', () {
      final resolved = resolveMenuEntries(defaultOrder: defaults, stored: []);
      expect(_ids(resolved), defaults);
      expect(resolved.every((e) => e.visible), isTrue);
    });

    test('applies the stored order and visibility', () {
      final resolved = resolveMenuEntries(
        defaultOrder: defaults,
        stored: const [
          SidebarMenuEntryPref(id: 'dashboard'),
          SidebarMenuEntryPref(id: 'invoice'),
          SidebarMenuEntryPref(id: 'quote'),
          SidebarMenuEntryPref(id: 'client', visible: false),
          SidebarMenuEntryPref(id: 'reports'),
        ],
      );
      expect(_ids(resolved), [
        'dashboard',
        'invoice',
        'quote',
        'client',
        'reports',
      ]);
      expect(resolved[3].visible, isFalse);
    });

    test('drops a stored id the caller cannot render', () {
      // A module the company switched off, or an entity removed between
      // releases. Dropped from the render only — the controller keeps the
      // stored entry, so re-enabling the module restores its position.
      final resolved = resolveMenuEntries(
        defaultOrder: defaults,
        stored: const [
          SidebarMenuEntryPref(id: 'invoice'),
          SidebarMenuEntryPref(id: 'task'),
          SidebarMenuEntryPref(id: 'dashboard'),
        ],
      );
      expect(_ids(resolved), isNot(contains('task')));
      expect(_ids(resolved).toSet(), defaults.toSet());
    });

    test('splices a newly-added destination in at its default index', () {
      // Without this an entity shipped in a later release would be missing from
      // the menu of every user who had ever customised it, with no way for them
      // to discover it was missing.
      final resolved = resolveMenuEntries(
        defaultOrder: defaults,
        stored: const [
          SidebarMenuEntryPref(id: 'dashboard'),
          SidebarMenuEntryPref(id: 'client'),
          SidebarMenuEntryPref(id: 'invoice'),
          SidebarMenuEntryPref(id: 'reports'),
        ],
      );
      // 'quote' sits at default index 3 and lands there.
      expect(_ids(resolved), [
        'dashboard',
        'client',
        'invoice',
        'quote',
        'reports',
      ]);
      expect(resolved.firstWhere((e) => e.id == 'quote').visible, isTrue);
    });

    test('several new destinations keep their relative default order', () {
      final resolved = resolveMenuEntries(
        defaultOrder: defaults,
        stored: const [
          SidebarMenuEntryPref(id: 'reports'),
          SidebarMenuEntryPref(id: 'dashboard'),
        ],
      );
      final ids = _ids(resolved);
      expect(ids.toSet(), defaults.toSet());
      expect(ids.indexOf('client'), lessThan(ids.indexOf('invoice')));
      expect(ids.indexOf('invoice'), lessThan(ids.indexOf('quote')));
      // The user's own two stay in the order they chose.
      expect(ids.indexOf('reports'), lessThan(ids.indexOf('dashboard')));
    });

    test('a duplicated id keeps its first occurrence', () {
      final resolved = resolveMenuEntries(
        defaultOrder: defaults,
        stored: const [
          SidebarMenuEntryPref(id: 'invoice'),
          SidebarMenuEntryPref(id: 'invoice', visible: false),
          SidebarMenuEntryPref(id: 'dashboard'),
        ],
      );
      expect(_ids(resolved).where((id) => id == 'invoice'), hasLength(1));
      expect(resolved.firstWhere((e) => e.id == 'invoice').visible, isTrue);
    });

    test('always returns exactly the ids it was given', () {
      // Callers index the result against their own list without a containment
      // check, so this is a contract, not an observation.
      for (final stored in <List<SidebarMenuEntryPref>>[
        [],
        const [SidebarMenuEntryPref(id: 'nope')],
        const [SidebarMenuEntryPref(id: 'reports', visible: false)],
      ]) {
        final resolved = resolveMenuEntries(
          defaultOrder: defaults,
          stored: stored,
        );
        expect(_ids(resolved)..sort(), [...defaults]..sort());
      }
    });
  });
}
