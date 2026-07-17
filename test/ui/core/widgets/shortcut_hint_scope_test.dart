import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/app/shortcut_hint_controller.dart';
import 'package:admin/ui/core/widgets/shortcut_hint_scope.dart';

/// Minimal Services — ShortcutHintScope only reads `shortcutHints`.
class _FakeServices implements Services {
  _FakeServices(this.shortcutHints);
  @override
  final ShortcutHintController shortcutHints;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  // #40: go_router's StatefulShellRoute.indexedStack keeps every visited branch
  // mounted but wraps the inactive ones in TickerMode(enabled: false). A hint
  // scope in an offstage branch must NOT contribute its ⌘S/⌘N chips to the
  // visible screen's hold-modifier bar.
  const onstage = ShortcutHint(keys: ['⌘', 'B'], labelKey: 'onstage_hint');
  const offstage = ShortcutHint(keys: ['⌘', 'S'], labelKey: 'offstage_hint');

  testWidgets('an offstage (TickerMode-disabled) scope contributes no hints', (
    tester,
  ) async {
    final controller = ShortcutHintController();
    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(controller),
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              TickerMode(
                enabled: true,
                child: ShortcutHintScope(hints: [onstage], child: SizedBox()),
              ),
              TickerMode(
                enabled: false,
                child: ShortcutHintScope(hints: [offstage], child: SizedBox()),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final labels = controller.activeHints.map((h) => h.labelKey).toList();
    expect(labels, contains('onstage_hint'));
    expect(
      labels,
      isNot(contains('offstage_hint')),
      reason:
          'an offstage IndexedStack branch must not advertise its shortcuts',
    );
  });

  testWidgets('flipping a scope on-stage re-registers its hints', (
    tester,
  ) async {
    final controller = ShortcutHintController();
    var enabled = false;
    late StateSetter setEnabled;
    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(controller),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: StatefulBuilder(
            builder: (context, setState) {
              setEnabled = setState;
              return TickerMode(
                enabled: enabled,
                child: const ShortcutHintScope(
                  hints: [offstage],
                  child: SizedBox(),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      controller.activeHints.map((h) => h.labelKey),
      isNot(contains('offstage_hint')),
      reason: 'starts offstage → not registered',
    );

    setEnabled(() => enabled = true);
    await tester.pumpAndSettle();
    expect(
      controller.activeHints.map((h) => h.labelKey),
      contains('offstage_hint'),
      reason: 'flipping on-stage re-registers',
    );
  });
}
