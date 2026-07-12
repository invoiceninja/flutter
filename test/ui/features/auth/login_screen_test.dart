import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/ui/features/auth/views/login_screen.dart';

import '../../../_localization_helper.dart';

/// The login screen only reads `services.auth` (to build its ViewModel in
/// initState); every other member is unused during render.
class _FakeAuth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeServices implements Services {
  _FakeServices(this.auth);
  @override
  final AuthRepository auth;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  testWidgets(
    'optional API secret field is hidden when hosted, shown when self-hosted',
    (tester) async {
      await tester.pumpWidget(
        Provider<Services>.value(
          value: _FakeServices(_FakeAuth()),
          child: MaterialApp(
            theme: buildInTheme(InTheme.light),
            localizationsDelegates: kTestLocalizationsDelegates,
            supportedLocales: kTestSupportedLocales,
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.pump();
      // Swallow the async asset-load report for the logo image — irrelevant to
      // the form fields under test.
      tester.takeException();

      const secretLabel = 'API secret (Optional)';

      // Hosted (default): the whole self-hosted block — Server URL + secret —
      // is not rendered.
      expect(find.text('Self-Hosted'), findsOneWidget);
      expect(find.text('Server URL'), findsNothing);
      expect(find.text(secretLabel), findsNothing);

      // Switch to Self-Hosted → Server URL and the optional API secret appear.
      await tester.tap(find.text('Self-Hosted'));
      await tester.pump();

      expect(find.text('Server URL'), findsOneWidget);
      expect(find.text(secretLabel), findsOneWidget);
    },
  );
}
