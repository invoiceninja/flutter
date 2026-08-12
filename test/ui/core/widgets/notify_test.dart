import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
// `notify.dart` re-exports only NotifyAction + ToastController, so the variant
// enum comes from the controller directly.
import 'package:admin/ui/core/widgets/toast_controller.dart';

import '../../../_localization_helper.dart';

// The toast *rendering* behavior (stacking, close button, hover-pause, swipe,
// layering) is covered by `toast_host_test.dart` driving the controller +
// host directly; the `Notify.* → ToastController` routing is exercised
// end-to-end by `settings_actions_test.dart` (forceResync → toast). This file
// keeps the pure `formatNotifyError` unit tests plus the blank-message policy.

/// Mounts [c] — which `Notify._toastsOf` prefers over `Services` — plus the
/// real English strings, and hands back a context under both.
///
/// The context is returned rather than the toast being fired inside a
/// `builder`: `Notify.*` notifies the controller, and doing that mid-build
/// marks the listening provider dirty during its own build phase.
Future<BuildContext> _pumpNotify(WidgetTester tester, ToastController c) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      // `ChangeNotifierProvider`, not plain `Provider` — the controller is a
      // `ChangeNotifier`, which `Provider` asserts against. Matches
      // `billing_doc_bulk_pdf_test.dart`. `.value` doesn't take ownership, so
      // each test still disposes its own controller.
      home: ChangeNotifierProvider<ToastController>.value(
        value: c,
        child: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  return captured;
}

void main() {
  group('formatNotifyError', () {
    test('strips Exception prefix', () {
      expect(formatNotifyError(Exception('boom')), 'boom');
    });

    test('strips a custom *Exception type-name prefix', () {
      expect(
        formatNotifyError(_FakeNamedException('lookup failed')),
        'lookup failed',
      );
    });

    test('leaves plain strings untouched', () {
      expect(formatNotifyError('plain'), 'plain');
    });
  });

  /// invoiceninja/flutter#30 — `ToastController` drops a toast with nothing
  /// renderable. That's right for a confirmation and wrong for a failure, so
  /// the two variants that carry a `BuildContext` substitute a generic string.
  group('Notify — blank message policy', () {
    testWidgets('a blank error falls back to a generic message', (
      tester,
    ) async {
      final c = ToastController();
      final ctx = await _pumpNotify(tester, c);
      // Resolve the expected string the same way the app does rather than
      // hardcoding English — the Transifex copy is free to change.
      final generic = ctx.tr('an_error_occurred');
      expect(generic, isNot('an_error_occurred'), reason: 'key resolved');

      Notify.error(ctx, '');
      expect(c.toasts.single.message, generic);
      c.clearAll();
      c.dispose();
    });

    testWidgets('a blank warning falls back too', (tester) async {
      final c = ToastController();
      final ctx = await _pumpNotify(tester, c);

      Notify.warning(ctx, '  ');
      expect(c.toasts.single.variant, NotifyVariant.warning);
      expect(c.toasts.single.message, ctx.tr('an_error_occurred'));
      c.clearAll();
      c.dispose();
    });

    testWidgets('a real detail wins over the generic fallback', (tester) async {
      final c = ToastController();
      final ctx = await _pumpNotify(tester, c);

      Notify.error(ctx, '', detail: 'Bounce ID not found');
      // The controller promotes the detail into the title rather than burying
      // the real reason under "an error occurred".
      expect(c.toasts.single.message, 'Bounce ID not found');
      expect(c.toasts.single.detail, isNull);
      c.clearAll();
      c.dispose();
    });

    testWidgets('the error text is used as the title, not swallowed', (
      tester,
    ) async {
      final c = ToastController();
      final ctx = await _pumpNotify(tester, c);

      Notify.error(ctx, '', error: Exception('boom'));
      expect(c.toasts.single.message, 'boom');
      c.clearAll();
      c.dispose();
    });

    testWidgets('a blank success is dropped, not shown empty', (tester) async {
      final c = ToastController();
      final ctx = await _pumpNotify(tester, c);

      Notify.success(ctx, '');
      Notify.info(ctx, '\n\n');
      expect(c.toasts, isEmpty);
      c.dispose();
    });
  });
}

class _FakeNamedException implements Exception {
  _FakeNamedException(this.message);
  final String message;

  @override
  String toString() => 'SocketException: $message';
}
