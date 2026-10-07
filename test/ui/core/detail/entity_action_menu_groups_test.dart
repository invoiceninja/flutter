import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';

import '../../../_responsive_helper.dart';

/// `EntityActionItem.menuChildrenFor` draws the dividers in a record's `⋮`
/// menu. Two things ask for one — the first lifecycle item, and any item
/// marked `startsGroup` — and the rule for both is the same: never two in a
/// row, never one at the top.

EntityActionItem<String> _item(
  String kind, {
  bool startsGroup = false,
  bool isLifecycle = false,
  bool enabled = true,
}) => EntityActionItem<String>(
  kind: kind,
  icon: Icons.bolt,
  label: kind,
  enabled: enabled,
  startsGroup: startsGroup,
  isLifecycle: isLifecycle,
  onTap: () {},
);

/// The menu as a string: item labels, with `|` for a divider.
Future<String> _shape(
  WidgetTester tester,
  List<EntityActionItem<String>> items,
) async {
  late List<Widget> children;
  await pumpAt(
    tester,
    400,
    Builder(
      builder: (context) {
        children = EntityActionItem.menuChildrenFor<String>(context, items);
        return const SizedBox();
      },
    ),
  );
  return [
    for (final c in children)
      c is Divider ? '|' : ((c as MenuItemButton).child! as Text).data!,
  ].join(' ');
}

void main() {
  testWidgets('a group break draws a divider above its first item', (
    tester,
  ) async {
    expect(
      await _shape(tester, [
        _item('statement'),
        _item('portal'),
        _item('comment', startsGroup: true),
        _item('call'),
        _item('clone', startsGroup: true),
      ]),
      'statement portal | comment call | clone',
    );
  });

  testWidgets('no divider at the top of the menu', (tester) async {
    expect(
      await _shape(tester, [_item('a', startsGroup: true), _item('b')]),
      'a b',
    );
  });

  testWidgets('a hidden item does not leave its divider behind', (
    tester,
  ) async {
    // A whole group gated away (no permission) must not leave two dividers
    // back to back, or one above nothing.
    expect(
      await _shape(tester, [
        _item('a'),
        _item('b', startsGroup: true, enabled: false),
        _item('c', startsGroup: true),
      ]),
      'a | c',
    );
  });

  testWidgets('the lifecycle divider is still exactly one', (tester) async {
    expect(
      await _shape(tester, [
        _item('a'),
        _item('copy', startsGroup: true),
        _item('archive', isLifecycle: true),
        _item('delete', isLifecycle: true),
      ]),
      'a | copy | archive delete',
    );
  });

  testWidgets('a lifecycle-only slice opens without a divider', (tester) async {
    // The overflow "More" menu whose hidden tail is all lifecycle.
    expect(
      await _shape(tester, [
        _item('archive', isLifecycle: true),
        _item('delete', isLifecycle: true),
      ]),
      'archive delete',
    );
  });
}
