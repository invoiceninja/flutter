import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/repositories/token_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';
import 'package:admin/ui/features/tokens/widgets/token_created_dialog.dart';
import 'package:admin/ui/features/tokens/widgets/token_secret_field.dart';

import '../../../_localization_helper.dart';

const _secret =
    'Abc123defGhij456klmNop789qrsTuv012wxyZab345cdeFgh678ijkLmn901opq';
const _hint = 'Abc123defG••••••••••••';

/// The Token row on Edit Token. Reading the clipboard back hangs a widget test
/// (fake-async), so the `Clipboard.setData` channel call is intercepted.
void main() {
  late ToastController toasts;
  String? copied;

  setUp(() {
    toasts = ToastController();
    copied = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
  });

  tearDown(() {
    toasts.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: ChangeNotifierProvider<ToastController>.value(
        value: toasts,
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );

  /// A toast arms its auto-dismiss timer, and a timer still pending when the
  /// body returns fails the test before `tearDown` runs — so clear in-body.
  void toastTest(String description, WidgetTesterCallback body) =>
      testWidgets(description, (tester) async {
        try {
          await body(tester);
        } finally {
          toasts.clearAll();
        }
      });

  Finder showButton() => find.byIcon(Icons.visibility_outlined);
  Finder hideButton() => find.byIcon(Icons.visibility_off_outlined);
  Finder copyButton() => find.byIcon(Icons.content_copy);

  testWidgets('starts hidden: the dotted hint, never the secret', (
    tester,
  ) async {
    var calls = 0;
    await pump(
      tester,
      TokenSecretField(
        hint: _hint,
        fetchSecret: () async {
          calls++;
          return _secret;
        },
      ),
    );

    expect(find.text(_hint), findsOneWidget);
    expect(find.text(_secret), findsNothing);
    expect(calls, 0, reason: 'nothing is fetched until asked');
  });

  testWidgets('Show fetches once and reveals; Hide then Show reuses it', (
    tester,
  ) async {
    var calls = 0;
    await pump(
      tester,
      TokenSecretField(
        hint: _hint,
        fetchSecret: () async {
          calls++;
          return _secret;
        },
      ),
    );

    await tester.tap(showButton());
    await tester.pumpAndSettle();
    expect(find.text(_secret), findsOneWidget);

    await tester.tap(hideButton());
    await tester.pumpAndSettle();
    expect(find.text(_secret), findsNothing);
    expect(find.text(_hint), findsOneWidget);

    await tester.tap(showButton());
    await tester.pumpAndSettle();
    expect(find.text(_secret), findsOneWidget);
    expect(calls, 1);
  });

  toastTest('both buttons are disabled while a fetch runs, and the result is '
      'reused', (tester) async {
    var calls = 0;
    final pending = Completer<String?>();
    await pump(
      tester,
      TokenSecretField(
        hint: _hint,
        fetchSecret: () {
          calls++;
          return pending.future;
        },
      ),
    );

    await tester.tap(showButton());
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final copy = tester.widget<IconButton>(
      find.ancestor(of: copyButton(), matching: find.byType(IconButton)),
    );
    expect(copy.onPressed, isNull);

    pending.complete(_secret);
    await tester.pumpAndSettle();
    await tester.tap(copyButton());
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(copied, _secret);
  });

  toastTest('Copy writes the secret without revealing it, and the toast '
      'names the token instead of echoing it', (tester) async {
    await pump(
      tester,
      TokenSecretField(hint: _hint, fetchSecret: () async => _secret),
    );

    await tester.tap(copyButton());
    await tester.pumpAndSettle();

    expect(copied, _secret);
    expect(find.text(_secret), findsNothing);
    expect(find.text(_hint), findsOneWidget);
    final toast = toasts.toasts.single;
    expect(toast.variant, NotifyVariant.success);
    expect(toast.message, isNot(contains(_secret.substring(0, 10))));
  });

  toastTest('a failed fetch keeps the hint and offers Retry', (tester) async {
    var calls = 0;
    await pump(
      tester,
      TokenSecretField(
        hint: _hint,
        fetchSecret: () async {
          calls++;
          if (calls == 1) throw Exception('offline');
          return _secret;
        },
      ),
    );

    await tester.tap(showButton());
    await tester.pumpAndSettle();

    expect(find.text(_hint), findsOneWidget);
    final toast = toasts.toasts.single;
    expect(toast.variant, NotifyVariant.error);
    expect(toast.action, isNotNull, reason: 'a transient failure gets Retry');

    toast.action!.onPressed();
    await tester.pumpAndSettle();
    expect(find.text(_secret), findsOneWidget);
    expect(calls, 2);
  });

  toastTest('a refusal that would fail again gets no Retry', (tester) async {
    await pump(
      tester,
      TokenSecretField(
        hint: _hint,
        fetchSecret: () async =>
            throw const ServerException(403, 'This action is unauthorized.'),
      ),
    );

    await tester.tap(showButton());
    await tester.pumpAndSettle();

    final toast = toasts.toasts.single;
    expect(toast.variant, NotifyVariant.error);
    expect(toast.action, isNull);
  });

  toastTest('a stale Retry never hides a token a later Show revealed', (
    tester,
  ) async {
    var calls = 0;
    await pump(
      tester,
      TokenSecretField(
        hint: _hint,
        fetchSecret: () async {
          calls++;
          if (calls == 1) throw Exception('offline');
          return _secret;
        },
      ),
    );

    await tester.tap(showButton());
    await tester.pumpAndSettle();
    final staleRetry = toasts.toasts.single.action!;

    await tester.tap(showButton());
    await tester.pumpAndSettle();
    expect(find.text(_secret), findsOneWidget);

    staleRetry.onPressed();
    await tester.pumpAndSettle();
    expect(find.text(_secret), findsOneWidget);
  });

  toastTest('an unsynced token says so, as a warning', (tester) async {
    await pump(
      tester,
      TokenSecretField(
        hint: _hint,
        fetchSecret: () async => throw const TokenNotSyncedException(),
      ),
    );

    await tester.tap(showButton());
    await tester.pumpAndSettle();

    final toast = toasts.toasts.single;
    expect(toast.variant, NotifyVariant.warning);
    expect(toast.message, pendingStrings()['token_not_synced']);
    expect(find.text(_hint), findsOneWidget);
  });

  toastTest('a masked answer is an error, not a blank reveal', (tester) async {
    await pump(
      tester,
      TokenSecretField(hint: _hint, fetchSecret: () async => null),
    );

    await tester.tap(showButton());
    await tester.pumpAndSettle();

    expect(toasts.toasts.single.variant, NotifyVariant.error);
    expect(find.text(_hint), findsOneWidget);
  });

  toastTest('TokenCreatedDialog: Copy keeps the secret out of the toast', (
    tester,
  ) async {
    await pump(tester, const TokenCreatedDialog(secret: _secret));

    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();

    expect(copied, _secret);
    expect(
      toasts.toasts.single.message,
      isNot(contains(_secret.substring(0, 10))),
    );
  });
}
