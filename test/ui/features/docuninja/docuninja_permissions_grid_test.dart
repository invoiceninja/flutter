import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/ui/features/docuninja/views/docuninja_users_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../_localization_helper.dart';

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
}
