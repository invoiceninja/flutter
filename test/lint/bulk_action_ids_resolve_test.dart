import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CI lint: every `EntityListBulkAction.actionId` a list screen declares must
/// match a `BulkAction.id` registered on that screen's list ViewModel.
///
/// The two live in different files with no compile-time link between them, and
/// the failure mode is **silent**: `_onBulk` resolves the id via
/// `_vm.bulkActionById(actionId)` and simply `return`s when it comes back null
/// (`entity_list_screen_scaffold.dart`). So a typo'd or stale id renders a real
/// button in the bulk bar that does nothing at all when tapped — no action, no
/// error, not even the `nothingKey` toast.
///
/// That is exactly what shipped for Purchase Orders: the toolbar offered
/// `accept`, an action the server has never had (it isn't in
/// `BulkPurchaseOrderRequest`'s allow-list — a PO is accepted by the vendor via
/// the portal), while `add_to_inventory` — implemented on the VM and supported
/// by the server — had no toolbar entry at all.
///
/// The reverse direction (a VM action with no toolbar entry) is deliberately
/// NOT asserted: several settings-area lists register `delete` on the VM but
/// expose it only through the row menu.
void main() {
  test('every list-screen actionId resolves to a VM BulkAction id', () {
    final featuresDir = Directory('lib/ui/features');
    expect(
      featuresDir.existsSync(),
      isTrue,
      reason: 'lib/ui/features/ should exist',
    );

    // `actionId: 'foo'` on the screen; `id: 'foo'` on the VM. The VM side is a
    // deliberate superset (any `id:` string literal in the file) — over-matching
    // can only mask a mismatch, never invent one.
    final actionIdPattern = RegExp(r"actionId:\s*'([a-z0-9_]+)'");
    final vmIdPattern = RegExp(r"\bid:\s*'([a-z0-9_]+)'");

    final offenders = <String>[];
    var screensChecked = 0;

    for (final entity in featuresDir.listSync(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('_list_screen.dart')) continue;

      final source = entity.readAsStringSync();
      final declared = actionIdPattern
          .allMatches(source)
          .map((m) => m.group(1)!)
          .toSet();
      if (declared.isEmpty) continue;

      // `lib/ui/features/<feature>/views/x_list_screen.dart`
      //   → `lib/ui/features/<feature>/view_models/`
      final feature = entity.uri.pathSegments[3];
      final vmDir = Directory('lib/ui/features/$feature/view_models');
      final registered = <String>{};
      if (vmDir.existsSync()) {
        for (final vm in vmDir.listSync()) {
          if (vm is! File || !vm.path.endsWith('_list_view_model.dart')) {
            continue;
          }
          final vmSource = vm.readAsStringSync();
          registered.addAll(
            vmIdPattern.allMatches(vmSource).map((m) => m.group(1)!),
          );
          // The shared helper supplies these three without literal `id:` lines.
          if (vmSource.contains('standardCrudBulkActions')) {
            registered.addAll(const ['archive', 'restore', 'delete']);
          }
        }
      }

      screensChecked++;
      final unresolved = declared.difference(registered).toList()..sort();
      if (unresolved.isNotEmpty) {
        offenders.add('${entity.path}: ${unresolved.join(', ')}');
      }
    }

    expect(
      screensChecked,
      greaterThan(10),
      reason:
          'the lint should be scanning every list screen; a near-zero '
          'count means the path convention changed and this test went blind',
    );
    expect(
      offenders,
      isEmpty,
      reason:
          'These `EntityListBulkAction.actionId`s have no matching '
          '`BulkAction.id` on the screen\'s list ViewModel, so the button '
          'renders and silently does nothing when tapped. Either register the '
          'action on the VM or drop the toolbar entry. Found:\n  '
          '${offenders.join('\n  ')}',
    );
  });
}
