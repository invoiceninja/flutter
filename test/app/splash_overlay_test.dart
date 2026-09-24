import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/native_splash.dart';
import 'package:admin/app/splash_overlay.dart';

/// When the iOS splash finished, [SplashOverlay] returned its child in place
/// of its own `Stack`. Flutter matched the two `Stack`s by type and remounted
/// every unkeyed sibling inside the app's — the router survived only through
/// its GlobalKey — so the notice of a local-data reset, which remembers in its
/// State that it has spoken, told the user a second time.
void main() {
  tearDown(() => NativeSplash.dismissed.value = false);

  testWidgets(
    'what the splash covers keeps its state when the splash ends',
    (tester) async {
      var mounts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SplashOverlay(
            // The shape `main` hands it: the app's own Stack of siblings.
            child: Stack(
              children: [
                const SizedBox.expand(),
                _Mounts(onMount: () => mounts++),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(mounts, 1);

      NativeSplash.dismissed.value = true;
      // The overlay's exit starts on the next frame; in the app its own entry
      // animation has one scheduled, here nothing does.
      tester.binding.scheduleFrame();
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(SplashOverlay),
          matching: find.byType(IgnorePointer),
        ),
        findsNothing,
        reason: 'the splash has gone',
      );

      expect(mounts, 1, reason: 'a remount repeats whatever it does on mount');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'elsewhere it is a passthrough',
    (tester) async {
      const child = SizedBox.expand(key: Key('app'));
      await tester.pumpWidget(
        const MaterialApp(home: SplashOverlay(child: child)),
      );
      expect(
        find.descendant(
          of: find.byType(SplashOverlay),
          matching: find.byType(Stack),
        ),
        findsNothing,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}

class _Mounts extends StatefulWidget {
  const _Mounts({required this.onMount});

  final VoidCallback onMount;

  @override
  State<_Mounts> createState() => _MountsState();
}

class _MountsState extends State<_Mounts> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
