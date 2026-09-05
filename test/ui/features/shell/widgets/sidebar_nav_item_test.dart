import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';
import 'package:admin/ui/features/shell/widgets/sidebar_badge.dart';
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

/// Stands in for the private `_SavedViewMenuButton` (`in_sidebar.dart`) in its
/// touch configuration. Kept structurally identical — `iconSize`, zero padding,
/// `shrinkWrap`, no `visualDensity`, and the same `constraints` — because every
/// one of those participates in the final size; a plain `SizedBox` would prove
/// the row arithmetic while hiding the Material sizing rules that actually bite.
Widget _savedViewMenuButtonLookalike() => IconButton(
  iconSize: 16,
  padding: EdgeInsets.zero,
  style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
  constraints: const BoxConstraints.tightFor(
    width: InSizes.touchTarget,
    height: 30,
  ),
  icon: const Icon(Icons.more_vert),
  onPressed: () {},
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
    'trailingHover appears alongside the count badge on hover and the row '
    'height stays constant',
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

      // On hover: BOTH show. The badge used to be swapped out for the hover
      // affordance, which was harmless for a plain total but not once the
      // number can be a red "3 overdue" — hovering a row must not hide the
      // thing it's warning you about.
      expect(find.text('7'), findsOneWidget);
      expect(find.byKey(const Key('trailing')), findsOneWidget);
      expect(
        tester.getSize(find.byType(SidebarNavItem)).height,
        heightBefore,
        reason: 'hovering must not change the row height',
      );

      // Off hover: badge stays, trailing goes.
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

  // The rows only ever render at the sidebar's real host widths — 280 (the
  // `AppDrawer`) and 232 (the persistent rail). The generic sweep in
  // responsive_regression_test.dart starts at 500, where a nav row has so much
  // slack it can't overflow, so these live here instead.
  //
  // Height is asserted as *equal* to the target, not merely above it: the row's
  // `trailing` sits inside its Row, so an over-tall trailing widget drives the
  // Row's cross axis and the row's own 7/7 padding stacks on top. A 44-px-tall
  // `⋮` renders a 58-px row — taller than every other row, and invisible to an
  // overflow check.
  group('touch density at real sidebar widths (issue #11)', () {
    const hostWidths = <double>[232, 280];
    const longLabel = 'Recurring purchase orders — awaiting approval';

    Future<void> pumpAtWidth(
      WidgetTester tester,
      double width,
      Widget child,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _wrap(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: child),
          ),
        ),
      );
      await tester.pump();
    }

    for (final width in hostWidths) {
      testWidgets(
        'badge row is exactly the touch target @ ${width.toInt()}px',
        (tester) async {
          await pumpAtWidth(
            tester,
            width,
            SidebarNavItem(
              label: longLabel,
              icon: Icons.receipt_long_outlined,
              active: true,
              touch: true,
              count: 1234,
              countLabel: 'Overdue',
              onTap: () {},
            ),
          );

          expect(tester.getSize(find.byType(SidebarNavItem)).height, 44);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('saved-view row keeps the same height as every other row '
          '@ ${width.toInt()}px', (tester) async {
        await pumpAtWidth(
          tester,
          width,
          SidebarNavItem(
            label: longLabel,
            icon: Icons.bookmark_outline,
            active: false,
            touch: true,
            trailing: _savedViewMenuButtonLookalike(),
            onTap: () {},
          ),
        );

        // The button itself: proof the `constraints` actually govern. Drop the
        // `shrinkWrap` and android's `padded` tap target inflates this to
        // 48×48; keep `visualDensity.compact` and it shrinks to 36 wide.
        expect(
          tester.getSize(find.byType(IconButton)),
          const Size(InSizes.touchTarget, 30),
        );
        expect(
          tester.getSize(find.byType(SidebarNavItem)).height,
          44,
          reason:
              'an over-tall trailing widget silently inflates the row past '
              'the touch target and breaks the sidebar rhythm',
        );
        expect(tester.takeException(), isNull);
        // `touch` only ever means android/iOS, and both the tap-target and
        // visual-density defaults governing this button differ from desktop —
        // measure on a real touch platform, not the test host's.
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));
    }
  });

  group('touch density (issue #11)', () {
    testWidgets('row is floored at the touch target when touch: true', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SidebarNavItem(
            label: 'Clients',
            icon: Icons.people_outline,
            active: false,
            touch: true,
            onTap: () {},
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(SidebarNavItem)).height,
        greaterThanOrEqualTo(InSizes.touchTarget),
      );
    });

    testWidgets('pointer platforms keep the dense row (touch defaults false)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SidebarNavItem(
            label: 'Clients',
            icon: Icons.people_outline,
            active: false,
            onTap: () {},
          ),
        ),
      );
      // Guards the desktop rail against the touch floor leaking out of its
      // branch. Asserted as "under the target" rather than an exact number —
      // the row sizes to max(18px icon, label line box), so the pixel value
      // moves with the font.
      expect(
        tester.getSize(find.byType(SidebarNavItem)).height,
        lessThan(InSizes.touchTarget),
      );
    });

    testWidgets(
      'the touch floor is a minimum, not a clamp — the label keeps its full '
      'line box at large text scale',
      (tester) async {
        const label = 'Payments'; // has p / y descenders
        const scale = 2.0;

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

        await tester.pumpWidget(
          _wrap(
            _scaled(
              scale,
              SidebarNavItem(
                label: label,
                icon: Icons.payments_outlined,
                active: false,
                touch: true,
                onTap: () {},
              ),
            ),
          ),
        );

        expect(
          tester.getSize(find.text(label)).height,
          greaterThanOrEqualTo(naturalHeight - 0.5),
          reason:
              'a SizedBox(height:) floor would slice the label; the touch '
              'target must be expressed as a minimum constraint',
        );
      },
    );
  });

  // The cases above pass `touch:` by hand, so none of them would notice the
  // sidebar forgetting to derive or forward it. `_fixedNav` / `_entityNav` /
  // `_SavedViewsSection` take it as a *required* param, so the analyzer covers
  // that half; what it can't see is the derivation and the three leaf handoffs
  // to `SidebarNavItem`, which silently fall back to the dense default.
  //
  // A source scan rather than a pump, same rationale as the sibling guard in
  // nav_history_buttons_test.dart: `InSidebar` needs the whole `Services`
  // graph, and pumping it holds live Drift watch streams that never settle.
  group('sidebar wiring (issue #11)', () {
    final sidebar = File(
      'lib/ui/features/shell/widgets/in_sidebar.dart',
    ).readAsStringSync();

    test('InSidebar derives the touch flag from the platform', () {
      expect(
        sidebar.contains('Env.isTouchPrimary'),
        isTrue,
        reason:
            'in_sidebar.dart must read Env.isTouchPrimary — without it every '
            'row silently falls back to the 32-px pointer density.',
      );
    });

    test('every SidebarNavItem in the sidebar is passed touch', () {
      const marker = 'SidebarNavItem(';
      final starts = <int>[];
      for (var i = sidebar.indexOf(marker); i != -1;) {
        starts.add(i);
        i = sidebar.indexOf(marker, i + marker.length);
      }
      expect(starts, isNotEmpty, reason: 'no SidebarNavItem constructions?');
      for (final start in starts) {
        final end = (start + 600).clamp(0, sidebar.length);
        expect(
          sidebar.substring(start, end).contains('touch:'),
          isTrue,
          reason:
              'the SidebarNavItem at offset $start does not forward `touch:` — '
              'that row keeps the dense height on phones.',
        );
      }
    });
  });

  group('counter badge tones', () {
    // A red overdue count has to stay red on the row you're standing on — the
    // whole point is that it keeps warning you.
    for (final active in [false, true]) {
      testWidgets('danger tone uses the overdue palette (active: $active)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(
            SidebarNavItem(
              label: 'Invoices',
              icon: Icons.receipt_long_outlined,
              active: active,
              count: 3,
              countTone: SidebarBadgeTone.danger,
              onTap: () {},
            ),
          ),
        );
        final container = tester.widget<Container>(
          find
              .ancestor(of: find.text('3'), matching: find.byType(Container))
              .first,
        );
        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.color, InTheme.light.overdueSoft);
      });
    }

    testWidgets('neutral tone keeps the pre-existing palette', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SidebarNavItem(
            label: 'Clients',
            icon: Icons.people_outline,
            active: false,
            count: 12,
            onTap: () {},
          ),
        ),
      );
      final container = tester.widget<Container>(
        find
            .ancestor(of: find.text('12'), matching: find.byType(Container))
            .first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, InTheme.light.surfaceAlt);
    });

    testWidgets('compact dot picks up the tone', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SidebarNavItem(
            label: 'Invoices',
            icon: Icons.receipt_long_outlined,
            active: false,
            compact: true,
            count: 3,
            countTone: SidebarBadgeTone.warning,
            onTap: () {},
          ),
        ),
      );
      final dot = tester.widget<Container>(
        find.byKey(const Key('clients-badge-dot')),
      );
      expect((dot.decoration! as BoxDecoration).color, InTheme.light.warning);
    });
  });

  group('counter badge labelling', () {
    // A bare red `3` is only useful if you can find out what it counts.
    testWidgets('badge carries a tooltip naming what it counts', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SidebarNavItem(
            label: 'Invoices',
            icon: Icons.receipt_long_outlined,
            active: false,
            count: 3,
            countTone: SidebarBadgeTone.danger,
            countLabel: 'Overdue',
            onTap: () {},
          ),
        ),
      );
      final tooltip = tester.widget<Tooltip>(
        find
            .ancestor(
              of: find.byType(SidebarBadge),
              matching: find.byType(Tooltip),
            )
            .first,
      );
      expect(tooltip.message, '3 Overdue');
    });

    testWidgets('a plain total gets no tooltip — nothing to explain', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SidebarNavItem(
            label: 'Clients',
            icon: Icons.people_outline,
            active: false,
            count: 12,
            onTap: () {},
          ),
        ),
      );
      expect(
        find.ancestor(
          of: find.byType(SidebarBadge),
          matching: find.byType(Tooltip),
        ),
        findsNothing,
      );
    });

    testWidgets(
      'compact rail folds the count into the row tooltip — the dot has no '
      'number, so this is the only place that information exists',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            SidebarNavItem(
              label: 'Invoices',
              icon: Icons.receipt_long_outlined,
              active: false,
              compact: true,
              count: 3,
              countTone: SidebarBadgeTone.danger,
              countLabel: 'Overdue',
              onTap: () {},
            ),
          ),
        );
        final tooltip = tester.widget<Tooltip>(find.byType(Tooltip).first);
        expect(tooltip.message, 'Invoices — 3 Overdue');
      },
    );
  });

  group('tile (grid menu layout, invoiceninja/flutter#125)', () {
    /// The tile's border-only Container — the one carrying a `Border`.
    Container borderBoxOf(WidgetTester tester) => tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(SidebarNavItem),
            matching: find.byType(Container),
          ),
        )
        .firstWhere((c) => (c.decoration as BoxDecoration?)?.border != null);

    testWidgets('stacks the icon above a centred label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SidebarNavItem(
            label: 'Recurring Invoices',
            icon: Icons.autorenew_outlined,
            active: false,
            tile: true,
            onTap: () {},
          ),
        ),
      );
      final icon = tester.getCenter(find.byIcon(Icons.autorenew_outlined));
      final label = tester.getCenter(find.text('Recurring Invoices'));
      expect(icon.dy, lessThan(label.dy));
      expect(icon.dx, moreOrLessEquals(label.dx, epsilon: 1));
    });

    testWidgets('an active tile takes the accent fill and accent border', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SidebarNavItem(
            label: 'Clients',
            icon: Icons.people_outline,
            active: true,
            tile: true,
            onTap: () {},
          ),
        ),
      );
      // The fill rides on the Material so the InkWell's ripple paints above it;
      // the Container only draws the outline, which is what lets the ripple
      // show through. Painting the fill on the Container would hide it.
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(SidebarNavItem),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, InTheme.light.accentSoft);
      final border = (borderBoxOf(tester).decoration as BoxDecoration).border!;
      expect(border.top.color, InTheme.light.accent);
      expect(
        (borderBoxOf(tester).decoration as BoxDecoration).color,
        isNull,
        reason: 'the Container must not be opaque, or it hides the ripple',
      );
    });

    testWidgets('an inactive tile is outlined, not filled', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SidebarNavItem(
            label: 'Clients',
            icon: Icons.people_outline,
            active: false,
            tile: true,
            onTap: () {},
          ),
        ),
      );
      final border = (borderBoxOf(tester).decoration as BoxDecoration).border!;
      expect(border.top.color, InTheme.light.border);
    });

    testWidgets('the badge keeps its number, beside the icon', (tester) async {
      // The rail degrades to an 8-px dot because 64 px has no room for digits.
      // A tile has room, and dropping to a dot would quietly downgrade the
      // sidebar-counters feature for anyone who picked the grid.
      await tester.pumpWidget(
        _wrap(
          SidebarNavItem(
            label: 'Invoices',
            icon: Icons.receipt_long_outlined,
            active: false,
            tile: true,
            count: 12,
            countTone: SidebarBadgeTone.danger,
            countLabel: 'Overdue',
            onTap: () {},
          ),
        ),
      );
      expect(find.text('12'), findsOneWidget);
      expect(find.byKey(const Key('clients-badge-dot')), findsNothing);
      final iconY = tester
          .getCenter(find.byIcon(Icons.receipt_long_outlined))
          .dy;
      expect(
        tester.getCenter(find.text('12')).dy,
        moreOrLessEquals(iconY, epsilon: 2),
      );
      expect(tester.getCenter(find.text('Invoices')).dy, greaterThan(iconY));
    });

    testWidgets('trailing wins the icon-row slot — it is the Reports Pro lock, '
        'the only signal the destination is gated before you tap it', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SidebarNavItem(
            label: 'Reports',
            icon: Icons.bar_chart_outlined,
            active: false,
            tile: true,
            trailing: const Icon(Icons.lock_outline, size: 16),
            onTap: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      final iconY = tester.getCenter(find.byIcon(Icons.bar_chart_outlined)).dy;
      expect(
        tester.getCenter(find.byIcon(Icons.lock_outline)).dy,
        moreOrLessEquals(iconY, epsilon: 2),
      );
    });

    testWidgets('trailingHover is dropped, and so is the MouseRegion that '
        'would have watched for it', (tester) async {
      // The visible half of this (no `+` on hover) would pass with or without
      // the `!tile` guard, because the tile body never renders trailingHover
      // anyway. The guard is about the *listener*: without it every pointer
      // crossing over a tile mounts a MouseRegion and calls setState for a
      // widget that can never appear. Counting them is the only way to see it.
      int mouseRegions() => tester
          .widgetList(
            find.descendant(
              of: find.byType(SidebarNavItem),
              matching: find.byType(MouseRegion),
            ),
          )
          .length;

      Widget item({required bool hover, required Key key}) => SidebarNavItem(
        key: key,
        label: 'Clients',
        icon: Icons.people_outline,
        active: false,
        tile: true,
        trailingHover: hover
            ? const Icon(Icons.add, key: Key('hover-add'))
            : null,
        onTap: () {},
      );

      // Tile against tile, not tile against row: the two layouts happen to
      // mount the same number for unrelated reasons (the tile's own label
      // tooltip stands in for the row's hover watcher), so only holding the
      // layout fixed and varying `trailingHover` isolates the guard.
      await tester.pumpWidget(
        _wrap(item(hover: false, key: const Key('bare'))),
      );
      final withoutHover = mouseRegions();

      await tester.pumpWidget(
        _wrap(item(hover: true, key: const Key('hover'))),
      );
      expect(mouseRegions(), withoutHover);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(SidebarNavItem)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hover-add')), findsNothing);
    });

    testWidgets('a long press still reaches the counter menu wrapped around '
        'the tile, rather than being eaten by the label tooltip', (
      tester,
    ) async {
      // `_BadgeModeMenuTarget` (private to in_sidebar.dart) wraps each entity
      // row in exactly this gesture detector. Replicated rather than imported
      // for the same reason `_savedViewMenuButtonLookalike` is: the shape is
      // what participates in the arena, and that is what is under test.
      //
      // The tile's own tooltip registers a competing LongPressGestureRecognizer
      // *below* this one unless its trigger mode is manual, and being deeper it
      // wins the arena — which on touch, the grid's whole audience, would leave
      // the counter menu unreachable with no right-click to fall back on.
      var opened = false;
      await tester.pumpWidget(
        _wrap(
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onLongPressStart: (_) => opened = true,
            child: SidebarNavItem(
              label: 'Transactions',
              icon: Icons.account_balance_outlined,
              active: false,
              tile: true,
              onTap: () {},
            ),
          ),
        ),
      );

      await tester.longPress(find.byType(SidebarNavItem));
      await tester.pumpAndSettle();
      expect(opened, isTrue);
    });

    testWidgets('carries the full label as a tooltip', (tester) async {
      // A tile ellipsizes a long single word once the text scale passes Normal,
      // and unlike a row it has no width to grow into.
      await tester.pumpWidget(
        _wrap(
          SidebarNavItem(
            label: 'Transactions',
            icon: Icons.account_balance_outlined,
            active: false,
            tile: true,
            onTap: () {},
          ),
        ),
      );
      expect(find.byTooltip('Transactions'), findsOneWidget);
    });

    testWidgets('compact wins over tile — the 64-px rail is already denser', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SidebarNavItem(
            label: 'Clients',
            icon: Icons.people_outline,
            active: false,
            compact: true,
            tile: true,
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Clients'), findsNothing);
    });

    testWidgets('the label grows with the text scaler instead of clipping', (
      tester,
    ) async {
      double labelHeight(WidgetTester tester) =>
          tester.getSize(find.text('Clients')).height;
      final heights = <double, double>{};
      for (final scale in [1.0, 1.4]) {
        await tester.pumpWidget(
          _wrap(
            _scaled(
              scale,
              SidebarNavItem(
                label: 'Clients',
                icon: Icons.people_outline,
                active: false,
                tile: true,
                onTap: () {},
              ),
            ),
          ),
        );
        heights[scale] = labelHeight(tester);
        expect(tester.takeException(), isNull);
      }
      expect(heights[1.4]!, greaterThan(heights[1.0]!));
    });
  });
}
