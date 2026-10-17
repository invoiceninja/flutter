import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/entity_modules.dart';
import 'package:admin/app/shortcuts/shortcut_catalog.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/quick_create.dart';

/// Catches "added an entity to `kBranchOrder` but forgot to enable its
/// screen builders" or "added a sidebar entry but forgot `disabled: true`".
///
/// The router's `_buildBranch` has the same checks as runtime asserts, but
/// those only fire in debug builds and only when the router actually gets
/// constructed. This test runs always.
void main() {
  test('every entity in kBranchOrder has its list / detail / edit builders + '
      'matching wired module', () {
    final wiredByType = {for (final m in kWiredEntityModules) m.type: m};
    final problems = <String>[];
    for (final spec in kBranchOrder) {
      if (spec is! EntityBranch) continue;
      final module = wiredByType[spec.type];
      if (module == null) {
        problems.add(
          '${spec.type}: appears in kBranchOrder but has no entry in '
          'kWiredEntityModules (move from kDisabledEntityModules?)',
        );
        continue;
      }
      if (module.disabled) {
        problems.add(
          '${spec.type}: wired module is marked disabled=true; either '
          'remove from kBranchOrder or drop the disabled flag',
        );
      }
      if (module.listBuilder == null) {
        problems.add('${spec.type}: missing listBuilder');
      }
      // A create screen is optional: Documents has none (a file is uploaded
      // on its record) — see the next test for what that commits it to.
      if (module.detailBuilder == null) {
        problems.add('${spec.type}: missing detailBuilder');
      }
      if (module.editBuilder == null) {
        problems.add('${spec.type}: missing editBuilder');
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('a routed entity with no create screen offers creating one nowhere', () {
    final problems = <String>[];
    for (final spec in kBranchOrder) {
      if (spec is! EntityBranch) continue;
      final module = kWiredEntityModules.firstWhere((m) => m.type == spec.type);
      if (module.createBuilder != null) continue;
      // `newRoute` drives the sidebar's hover "+", the shortcut catalog's
      // create targets and the dashboard's create sheet.
      final handlers = module.toHandlers(DisabledEntityDispatcher(spec.type));
      if (handlers.newRoute != null) {
        problems.add('${spec.type}: newRoute is ${handlers.newRoute}');
      }
      if (kQuickCreateEntities.contains(spec.type)) {
        problems.add('${spec.type}: listed in kQuickCreateEntities');
      }
      if (kCreateShortcutEntities.contains(spec.type)) {
        problems.add('${spec.type}: listed in kCreateShortcutEntities');
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test(
    'kWiredEntityModules and kDisabledEntityModules have disjoint '
    'EntityType sets (a wired entity must not also exist as a placeholder)',
    () {
      final wired = {for (final m in kWiredEntityModules) m.type};
      final disabled = {for (final m in kDisabledEntityModules) m.type};
      final overlap = wired.intersection(disabled);
      expect(
        overlap,
        isEmpty,
        reason:
            'These EntityTypes appear in both lists — remove the placeholder '
            'from kDisabledEntityModules when an entity graduates to wired: '
            '$overlap',
      );
    },
  );

  test('disabled entity modules carry no screen builders (defensive sanity '
      'check; lets us assume routability from `disabled`)', () {
    final problems = <String>[];
    for (final spec in kDisabledEntityModules) {
      if (!spec.disabled) {
        problems.add(
          '${spec.type}: in kDisabledEntityModules but '
          'disabled=false',
        );
      }
      if (spec.listBuilder != null ||
          spec.createBuilder != null ||
          spec.detailBuilder != null ||
          spec.editBuilder != null) {
        problems.add(
          '${spec.type}: disabled placeholder has a non-null screen '
          'builder — drop the builder or move to kWiredEntityModules',
        );
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
