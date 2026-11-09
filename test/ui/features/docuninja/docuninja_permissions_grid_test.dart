import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/ui/features/docuninja/views/docuninja_users_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../_localization_helper.dart';

Widget _host(Widget grid) => MaterialApp(
  theme: buildInTheme(InTheme.light),
  localizationsDelegates: kTestLocalizationsDelegates,
  supportedLocales: kTestSupportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: grid)),
);

void _view(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// React's permissions grid: lays out on a phone, and a box adds a global
/// grant while a record-scoped one survives.
void main() {
  testWidgets('lays out at phone width and toggles one grant', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var permissions = const [
      DnPermission(model: 'documents', permissionId: 2, permissionableId: 'd1'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: DnPermissionsGrid(
                isAdmin: false,
                permissions: permissions,
                onAdminChanged: (_) {},
                onChanged: (p) => setState(() => permissions = p),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    // All + four models, four basic boxes each, and approval on documents.
    expect(find.byType(Checkbox), findsNWidgets(5 * 4 + 1));
    await tester.tap(find.byType(Checkbox).at(4)); // documents › create
    await tester.pump();
    expect(permissions, hasLength(2));
    expect(permissions.first.permissionableId, 'd1');
    expect(permissions.last.permissionableId, isNull);
    expect(permissions.last.model, 'documents');
    expect(permissions.last.permissionId, 4, reason: 'create');
  });

  testWidgets('a phone gets a block per model, every permission on screen '
      'and a touch target, without a sideways scroll', (tester) async {
    _view(tester, const Size(393, 852));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    var permissions = const <DnPermission>[];
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => _host(
          DnPermissionsGrid(
            isAdmin: false,
            permissions: permissions,
            onAdminChanged: (_) {},
            onChanged: (p) => setState(() => permissions = p),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
      ),
      findsNothing,
    );
    // Every label stays: a block each for All and the four models.
    for (final label in ['All', 'Documents', 'Templates', 'Clients']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Requires Approval'), findsOneWidget);
    for (final box in tester.widgetList<Checkbox>(find.byType(Checkbox))) {
      final rect = tester.getRect(find.byWidget(box));
      expect(rect.right, lessThanOrEqualTo(393));
    }
    final chip = find.ancestor(
      of: find.text('Requires Approval'),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(chip.first).height, greaterThanOrEqualTo(44));

    // The whole chip is the target: its label ticks the box.
    await tester.ensureVisible(find.text('Requires Approval'));
    await tester.tap(find.text('Requires Approval'));
    await tester.pump();
    expect(permissions, hasLength(1));
    expect(permissions.single.model, 'documents');
    expect(find.byType(Checkbox).evaluate().length, 5 * 4 + 1);
  });

  testWidgets('an administrator\'s chips are off', (tester) async {
    _view(tester, const Size(393, 852));
    var changed = 0;
    await tester.pumpWidget(
      _host(
        DnPermissionsGrid(
          isAdmin: true,
          permissions: const [],
          onAdminChanged: (_) {},
          onChanged: (_) => changed++,
        ),
      ),
    );
    await tester.tap(find.text('Requires Approval'));
    await tester.pump();
    expect(changed, 0);
    expect(
      tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .every((c) => c.onChanged == null),
      isTrue,
    );
  });

  testWidgets('a wide pane keeps React\'s grid', (tester) async {
    _view(tester, const Size(800, 600));
    await tester.pumpWidget(
      _host(
        DnPermissionsGrid(
          isAdmin: false,
          permissions: const [],
          onAdminChanged: (_) {},
          onChanged: (_) {},
        ),
      ),
    );
    // The grid's dashes: no approval for All and the three other models.
    expect(find.text('—'), findsNWidgets(4));
    expect(find.byType(Checkbox), findsNWidgets(5 * 4 + 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
