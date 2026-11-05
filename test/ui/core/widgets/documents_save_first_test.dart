import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/widgets/documents_save_first.dart';
import 'package:admin/ui/features/settings/widgets/plan_gate_banner.dart';

import '../../../_localization_helper.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(body: child),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('with no session, the notice is the save-first line', (
    tester,
  ) async {
    await _pump(tester, const DocumentsSaveFirstNotice());
    expect(find.text('Save the record to upload documents'), findsOneWidget);
    expect(find.byType(PlanGateBanner), findsNothing);
  });
}
