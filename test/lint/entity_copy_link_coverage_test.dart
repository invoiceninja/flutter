import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CI lint: every entity actions menu offers "Copy Link".
///
/// A shareable link to a record (invoiceninja/flutter#96) is only useful if it
/// exists on every record, and one half of that is invisible to the compiler.
///
/// Adding a `copyLink` enum value without its `dispatch` case is already a
/// build error (the dispatch switches are exhaustive — none has a `default:`).
/// The hole is the **`itemsFor` entry**: add the enum value and the dispatch
/// case, forget the `?copyLinkActionItem(...)` element, and the entity ships
/// with no way to link to it while analyze and every other test stay green.
/// So this asserts on the two call sites, not on the enum. Same rationale as
/// `sidebar_badge_count_test`.
///
/// Scope: files under `lib/ui/features/` named `*_actions.dart` that build
/// `EntityActionItem`s — i.e. an entity's action set, not the settings /
/// sidebar-footer action lists, which aren't records.
void main() {
  test('every entity action set declares a copyLink action', () {
    // Deliberate opt-outs. Empty today; add an entry WITH its reason rather
    // than deleting the assertion.
    const allowlist = <String>{};

    final offenders = <String>[];
    final root = Directory('lib/ui/features');
    expect(root.existsSync(), isTrue, reason: 'lib/ui/features should exist');

    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('_actions.dart')) continue;
      if (allowlist.contains(entity.path)) continue;
      final content = entity.readAsStringSync();
      if (!content.contains('EntityActionItem')) continue;
      if (!RegExp(r'^enum \w+Action\b', multiLine: true).hasMatch(content)) {
        continue;
      }
      final hasItem = content.contains('copyLinkActionItem(');
      final hasDispatch = content.contains('copyEntityLink(');
      if (!hasItem || !hasDispatch) offenders.add(entity.path);
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Add a `copyLink` value to the action enum, a `?copyLinkActionItem(...)` '
          'element in `itemsFor`, and a `dispatch` case calling '
          '`copyEntityLink(context, EntityType.<x>, <entity>.id)`.\n'
          'Place the item as a SIBLING list element just above the lifecycle '
          'block — above any collection-`if` that guards Archive, not between '
          'the guard and it. Getting that wrong silently un-guards Archive '
          '(it happened once, in the five billing-document files). Missing in:\n  '
          '${offenders.join('\n  ')}',
    );
  });
}
