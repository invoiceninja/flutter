import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/features/shell/widgets/sidebar_nav_item.dart';

/// Theme that supplies the `InTheme` extension `SidebarNavItem` reads via
/// `context.inTheme`.
ThemeData _theme() => ThemeData.light().copyWith(
  extensions: <ThemeExtension<dynamic>>[InTheme.light],
);

Widget _wrap(Widget child) => MaterialApp(
  theme: _theme(),
  home: Scaffold(body: child),
);

/// Overrides only the text scaler for [child] so a row can be measured at the
/// app's Large / Extra-Large text sizes (the device text-scale preference and
/// the OS accessibility scaler both feed `MediaQuery.textScaler`).
Widget _scaled(double factor, Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(factor)),
    child: child,
  ),
);

void main() {
  testWidgets('trailingHover is hidden until the mouse enters, shown on hover, '
      'hidden again on exit', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SidebarNavItem(
          label: 'Clients',
          icon: Icons.people_outline,
          active: false,
          onTap: () {},
          trailingHover: const SizedBox(
            key: Key('trailing'),
            width: 20,
            height: 20,
          ),
        ),
      ),
    );
    await tester.pump();

    // Hidden before any pointer activity.
    expect(find.byKey(const Key('trailing')), findsNothing);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    // Moving over the row reveals the trailing widget.
    await gesture.moveTo(tester.getCenter(find.byType(SidebarNavItem)));
    await tester.pump();
    expect(find.byKey(const Key('trailing')), findsOneWidget);

    // Moving off the row hides it again.
    await gesture.moveTo(const Offset(1000, 1000));
    await tester.pump();
    expect(find.byKey(const Key('trailing')), findsNothing);
  });

  testWidgets(
    'tapping the trailingHover button does not also fire the row\'s onTap',
    (tester) async {
      var rowTaps = 0;
      var trailingTaps = 0;
      await tester.pumpWidget(
        _wrap(
          SidebarNavItem(
            label: 'Clients',
            icon: Icons.people_outline,
            active: false,
            onTap: () => rowTaps++,
            trailingHover: IconButton(
              key: const Key('trailing-btn'),
              icon: const Icon(Icons.add),
              onPressed: () => trailingTaps++,
            ),
          ),
        ),
      );
      await tester.pump();

      // Hover to reveal the trailing button.
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(SidebarNavItem)));
      await tester.pump();

      await tester.tap(find.byKey(const Key('trailing-btn')));
      await tester.pump();

      expect(trailingTaps, 1);
      expect(
        rowTaps,
        0,
        reason:
            "IconButton's GestureDetector consumes the tap so the "
            "ancestor InkWell.onTap doesn't also fire",
      );
    },
  );

  testWidgets('compact mode ignores trailingHover even on hover', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        SidebarNavItem(
          label: 'Clients',
          icon: Icons.people_outline,
          active: false,
          compact: true,
          onTap: () {},
          trailingHover: const SizedBox(
            key: Key('trailing'),
            width: 20,
            height: 20,
          ),
        ),
      ),
    );
    await tester.pump();
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.byType(SidebarNavItem)));
    await tester.pump();
    expect(find.byKey(const Key('trailing')), findsNothing);
  });

  testWidgets(
    'trailingHover replaces the count badge on hover and the row height '
    'stays constant',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          Center(
            child: SidebarNavItem(
              label: 'Clients',
              icon: Icons.people_outline,
              active: false,
              count: 7,
              onTap: () {},
              trailingHover: const SizedBox(
                key: Key('trailing'),
                width: 18,
                height: 18,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Before hover: count visible, trailing hidden.
      expect(find.text('7'), findsOneWidget);
      expect(find.byKey(const Key('trailing')), findsNothing);
      final heightBefore = tester.getSize(find.byType(SidebarNavItem)).height;

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(SidebarNavItem)));
      await tester.pump();

      // On hover: count hidden, trailing visible.
      expect(find.text('7'), findsNothing);
      expect(find.byKey(const Key('trailing')), findsOneWidget);
      expect(
        tester.getSize(find.byType(SidebarNavItem)).height,
        heightBefore,
        reason: 'hovering must not change the row height',
      );

      // Off hover: count returns.
      await gesture.moveTo(const Offset(1000, 1000));
      await tester.pump();
      expect(find.text('7'), findsOneWidget);
      expect(find.byKey(const Key('trailing')), findsNothing);
    },
  );

  testWidgets('disabled rows do not surface the hover trailing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        SidebarNavItem(
          label: 'Invoices',
          icon: Icons.receipt_long_outlined,
          active: false,
          disabled: true,
          trailingHover: const SizedBox(
            key: Key('trailing'),
            width: 20,
            height: 20,
          ),
        ),
      ),
    );
    await tester.pump();
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.byType(SidebarNavItem)));
    await tester.pump();
    expect(find.byKey(const Key('trailing')), findsNothing);
  });

  testWidgets('persistent trailing renders without hover', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SidebarNavItem(
          label: 'Deleted Invoices',
          icon: Icons.bookmark_outline,
          active: false,
          trailing: const SizedBox(
            key: Key('persistent'),
            width: 20,
            height: 20,
          ),
        ),
      ),
    );
    await tester.pump();
    // No mouse hover at all — still visible (unlike trailingHover).
    expect(find.byKey(const Key('persistent')), findsOneWidget);
  });

  testWidgets('persistent trailing takes priority over the count badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        SidebarNavItem(
          label: 'Deleted Invoices',
          icon: Icons.bookmark_outline,
          active: false,
          count: 7,
          trailing: const SizedBox(
            key: Key('persistent'),
            width: 20,
            height: 20,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('persistent')), findsOneWidget);
    expect(find.text('7'), findsNothing);
  });

  testWidgets('compact mode ignores persistent trailing', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SidebarNavItem(
          label: 'Deleted Invoices',
          icon: Icons.bookmark_outline,
          active: false,
          compact: true,
          trailing: const SizedBox(
            key: Key('persistent'),
            width: 20,
            height: 20,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('persistent')), findsNothing);
  });

  testWidgets(
    'label is not vertically clamped at large text scale — descenders stay '
    'visible (the row sizes to the text, not a fixed height)',
    (tester) async {
      const label = 'Payments'; // has p / y descenders
      // 2.0 is well past the ~1.14 scale where Inter Tight's line box first
      // exceeds the row; the assertion holds for any font with a clear margin.
      const scale = 2.0;

      // Natural, unconstrained single-line height of the label at this scale.
      await tester.pumpWidget(
        _wrap(
          _scaled(
            scale,
            const Align(
              alignment: Alignment.topLeft,
              child: Text(label, style: TextStyle(fontSize: 13)),
            ),
          ),
        ),
      );
      final naturalHeight = tester.getSize(find.text(label)).height;

      // The same label inside the real nav row.
      await tester.pumpWidget(
        _wrap(
          _scaled(
            scale,
            SidebarNavItem(
              label: label,
              icon: Icons.payments_outlined,
              active: false,
              onTap: () {},
            ),
          ),
        ),
      );
      final rowTextHeight = tester.getSize(find.text(label)).height;

      expect(
        rowTextHeight,
        greaterThanOrEqualTo(naturalHeight - 0.5),
        reason:
            'a fixed-height clamp on the row slices the label at large text '
            'scale; the row must grow to give the text its full line box',
      );
    },
  );
}
