import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/l10n/supported_locales.dart';
import 'package:admin/ui/core/unsaved_changes/unsaved_changes_guard.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

class _DirtyNotifier extends ChangeNotifier {
  bool isDirty = false;
  int discardCount = 0;

  void markDirty() {
    isDirty = true;
    notifyListeners();
  }

  void reset() {
    isDirty = false;
    discardCount++;
    notifyListeners();
  }
}

void main() {
  group('UnsavedChangesGuard', () {
    test('hasUnsaved is false when nothing is registered', () {
      final guard = UnsavedChangesGuard();
      expect(guard.hasUnsaved, isFalse);
      expect(guard.registeredCount, 0);
    });

    test('hasUnsaved reflects registered entries', () {
      final guard = UnsavedChangesGuard();
      final src = _DirtyNotifier();
      final dispose = guard.register(
        isDirty: () => src.isDirty,
        source: src,
        onDiscard: src.reset,
      );
      expect(guard.hasUnsaved, isFalse);
      src.markDirty();
      expect(guard.hasUnsaved, isTrue);
      src.reset();
      expect(guard.hasUnsaved, isFalse);
      dispose();
    });

    test('unregister stops tracking and notifies', () {
      final guard = UnsavedChangesGuard();
      final src = _DirtyNotifier()..isDirty = true;
      final dispose = guard.register(isDirty: () => src.isDirty, source: src);
      expect(guard.hasUnsaved, isTrue);
      expect(guard.registeredCount, 1);

      var notifyCount = 0;
      guard.addListener(() => notifyCount++);
      dispose();
      expect(guard.hasUnsaved, isFalse);
      expect(guard.registeredCount, 0);
      expect(notifyCount, greaterThanOrEqualTo(1));
    });

    testWidgets('confirmIfDirty returns true immediately when clean', (
      tester,
    ) async {
      final guard = UnsavedChangesGuard();
      late bool result;
      await tester.pumpWidget(
        _LocalizationHost(
          child: Builder(
            builder: (ctx) {
              return TextButton(
                onPressed: () async {
                  result = await guard.confirmIfDirty(ctx);
                },
                child: const Text('go'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      expect(result, isTrue);
      // No dialog appeared.
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('confirmIfDirty prompts and Discard fires onDiscard', (
      tester,
    ) async {
      final guard = UnsavedChangesGuard();
      final src = _DirtyNotifier()..isDirty = true;
      guard.register(
        isDirty: () => src.isDirty,
        source: src,
        onDiscard: src.reset,
      );

      late bool result;
      await tester.pumpWidget(
        _LocalizationHost(
          child: Builder(
            builder: (ctx) {
              return TextButton(
                onPressed: () async {
                  result = await guard.confirmIfDirty(ctx);
                },
                child: const Text('go'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      // Dialog appears. Tap Discard.
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(src.discardCount, 1);
      expect(src.isDirty, isFalse);
    });

    testWidgets('an entry that blocks leaving refuses, says why, and is never '
        'discarded', (tester) async {
      final guard = UnsavedChangesGuard();
      final editor = _DirtyNotifier()..isDirty = true;
      final payment = _DirtyNotifier()..isDirty = true;
      guard
        ..register(
          isDirty: () => editor.isDirty,
          source: editor,
          onDiscard: editor.reset,
        )
        ..register(
          isDirty: () => payment.isDirty,
          source: payment,
          onDiscard: payment.reset,
          blockedMessage: (_) => 'A card payment is under way.',
        );

      late bool result;
      await tester.pumpWidget(
        _LocalizationHost(
          child: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                result = await guard.confirmIfDirty(ctx);
              },
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('A card payment is under way.'), findsOneWidget);
      expect(find.text('Discard'), findsNothing);
      await tester.tap(find.byType(PrimaryDialogAction));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(editor.discardCount, 0);
      expect(payment.discardCount, 0);

      // Once the payment is over, leaving is the usual question again.
      payment.reset();
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Discard'), findsOneWidget);
    });

    testWidgets('confirmIfDirty returns false on Keep editing', (tester) async {
      final guard = UnsavedChangesGuard();
      final src = _DirtyNotifier()..isDirty = true;
      guard.register(
        isDirty: () => src.isDirty,
        source: src,
        onDiscard: src.reset,
      );

      late bool result;
      await tester.pumpWidget(
        _LocalizationHost(
          child: Builder(
            builder: (ctx) {
              return TextButton(
                onPressed: () async {
                  result = await guard.confirmIfDirty(ctx);
                },
                child: const Text('go'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
      expect(src.discardCount, 0);
      expect(src.isDirty, isTrue);
    });
  });
}

class _LocalizationHost extends StatelessWidget {
  const _LocalizationHost({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('en'),
      supportedLocales: kSupportedLocales,
      localizationsDelegates: [_PendingOnlyDelegate()],
      home: Scaffold(body: child),
    );
  }
}

class _PendingOnlyDelegate extends LocalizationsDelegate<Localization> {
  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<Localization> load(Locale locale) => SynchronousFuture(
    Localization.forTesting(
      strings: const {},
      pending: const {
        'discard_changes_question': 'Discard changes?',
        'discard_changes_warning': 'Your edits will be lost.',
        'keep_editing': 'Keep editing',
        'discard': 'Discard',
      },
    ),
  );

  @override
  bool shouldReload(LocalizationsDelegate<Localization> old) => false;
}
