import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/ui/core/widgets/confirm_password_sheet.dart';

import '../../../_localization_helper.dart';

/// Who is asked what — admin-portal's `passwordCallback`, ported:
/// an OAuth user the server lets through is not asked at all, an Apple user
/// can confirm with Apple, and a user with no password is never shown a
/// field they cannot fill.
void main() {
  PasswordCache cacheFor(PasswordSubject subject) =>
      PasswordCache()..subject = () => subject;

  PasswordSubject subject({
    String provider = '',
    bool hasPassword = true,
    bool required = false,
  }) => PasswordSubject(
    oauthProvider: provider,
    hasPassword: hasPassword,
    oauthPasswordRequired: required,
  );

  /// Pumps a button that opens the sheet and records what it returned.
  Future<List<bool>> pumpOpener(
    WidgetTester tester,
    PasswordCache cache, {
    bool afterRejection = false,
  }) async {
    final results = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await showConfirmPasswordSheet(
                context,
                cache: cache,
                afterRejection: afterRejection,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('an exempt OAuth user is not asked at all', (tester) async {
    final results = await pumpOpener(
      tester,
      cacheFor(subject(provider: 'google', hasPassword: false)),
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(results, [true]);
  });

  testWidgets('after the server refused, even an "exempt" user is asked', (
    tester,
  ) async {
    await pumpOpener(
      tester,
      cacheFor(subject(provider: 'google')),
      afterRejection: true,
    );
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('an email/password user gets the password field', (tester) async {
    await pumpOpener(tester, cacheFor(subject()));
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Confirm with Apple'), findsNothing);
  });

  testWidgets('no password and no Apple route → "set a password", no field', (
    tester,
  ) async {
    final results = await pumpOpener(
      tester,
      cacheFor(subject(provider: 'google', hasPassword: false, required: true)),
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Please set an account password'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(results, [false]);
  });

  testWidgets('an Apple user with no password confirms with Apple on iOS', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await pumpOpener(
        tester,
        cacheFor(
          subject(provider: 'apple', hasPassword: false, required: true),
        ),
      );
      expect(find.text('Confirm with Apple'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      // No Confirm that could never enable.
      expect(find.text('Confirm'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Apple is not offered where the native flow does not exist', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await pumpOpener(
        tester,
        cacheFor(
          subject(provider: 'apple', hasPassword: false, required: true),
        ),
      );
      expect(find.text('Confirm with Apple'), findsNothing);
      expect(find.text('Please set an account password'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
