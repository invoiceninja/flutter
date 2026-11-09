import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_states.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_status_pill.dart';

import '../../../_localization_helper.dart';

Widget _host(Widget child) => MaterialApp(
  theme: buildInTheme(InTheme.light),
  localizationsDelegates: kTestLocalizationsDelegates,
  supportedLocales: kTestSupportedLocales,
  home: Scaffold(body: child),
);

/// React's Join (`Join.tsx`): Create for an eligible owner or admin, Upgrade
/// for one on another plan, "contact your admin" for everyone else.
void main() {
  testWidgets('an eligible admin can create the account', (tester) async {
    var created = 0;
    await tester.pumpWidget(
      _host(
        DocuNinjaJoinView(
          isAdmin: true,
          isEligible: true,
          isCreating: false,
          onCreate: () => created++,
          onUpgrade: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welcome to DocuNinja'), findsOneWidget);
    expect(find.text('Everything You Get'), findsOneWidget);
    await tester.tap(find.text('Create DocuNinja Account'));
    expect(created, 1);
  });

  testWidgets('an admin on another plan is offered the upgrade', (
    tester,
  ) async {
    var upgraded = 0;
    await tester.pumpWidget(
      _host(
        DocuNinjaJoinView(
          isAdmin: true,
          isEligible: false,
          isCreating: false,
          onCreate: () {},
          onUpgrade: () => upgraded++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Upgrade your plan to enable DocuNinja'), findsOneWidget);
    await tester.tap(find.text('Upgrade'));
    expect(upgraded, 1);
  });

  testWidgets('everyone else is told to ask their admin', (tester) async {
    await tester.pumpWidget(
      _host(
        DocuNinjaJoinView(
          isAdmin: false,
          isEligible: true,
          isCreating: false,
          onCreate: () {},
          onUpgrade: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Contact your admin for access to DocuNinja.'),
      findsOneWidget,
    );
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('company setup and the status pill use React\'s copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            DocuNinjaCompanySetupView(isWorking: false, onSetUp: () {}),
            DocuNinjaStatusPill(
              document: DnDocument.fromJson({'status_id': 6}),
            ),
            DocuNinjaStatusPill(
              document: DnDocument.fromJson({
                'status_id': 5,
                'archived_at': '2026-01-01',
              }),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Setup company'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    // Archived wins over the status, as in React's table.
    expect(find.text('Archived'), findsOneWidget);
  });

  for (final size in const [Size(393, 852), Size(360, 760)]) {
    testWidgets('on a phone at twice the text size the Join button is above '
        'the fold (${size.width.toInt()} wide)', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        _host(
          DocuNinjaJoinView(
            isAdmin: true,
            isEligible: true,
            isCreating: false,
            onCreate: () {},
            onUpgrade: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final button = tester.getRect(find.byType(FilledButton));
      expect(button.bottom, lessThanOrEqualTo(size.height));
      // Ahead of the features card.
      final features = tester.getTopLeft(find.text('Everything You Get'));
      expect(button.bottom, lessThan(features.dy));
    });
  }

  testWidgets('a desktop window keeps the button after the features', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        DocuNinjaJoinView(
          isAdmin: true,
          isEligible: true,
          isCreating: false,
          onCreate: () {},
          onUpgrade: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = tester.getTopLeft(find.byType(FilledButton));
    final features = tester.getTopLeft(find.text('Everything You Get'));
    expect(button.dy, greaterThan(features.dy));
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('company setup says "click" on a pointer device', (tester) async {
    await tester.pumpWidget(
      _host(DocuNinjaCompanySetupView(isWorking: false, onSetUp: () {})),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('click'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('company setup on touch does not say "click"', (tester) async {
    await tester.pumpWidget(
      _host(DocuNinjaCompanySetupView(isWorking: false, onSetUp: () {})),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('click'), findsNothing);
  });
}
