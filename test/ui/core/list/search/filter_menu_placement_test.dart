import 'dart:ui';

import 'package:admin/ui/core/list/search/filter_menu_placement.dart';
import 'package:flutter_test/flutter_test.dart';

/// The whole placement rule of the token search field's popups, pinned without
/// pumping the field. "The popup appears too far over" was four separate
/// causes; the two that are pure geometry — anchored at the caret instead of
/// the token start, and clamped to the Overlay instead of the search box —
/// live here.
void main() {
  const overlay = Size(1200, 800);
  // A search box 100..900 wide, 40 tall, near the top of the pane.
  const field = Rect.fromLTWH(100, 20, 800, 40);

  FilterMenuPlacement place({
    double anchorStart = 150,
    Rect box = field,
    Size size = overlay,
    double preferredWidth = 420,
    double bottomInset = 0,
    TextDirection dir = TextDirection.ltr,
    bool containInField = true,
    FilterMenuSide? latched,
  }) => placeFilterMenu(
    field: box,
    anchorStart: anchorStart,
    anchorTop: box.top,
    anchorBottom: box.bottom,
    overlay: size,
    preferredWidth: preferredWidth,
    bottomInset: bottomInset,
    textDirection: dir,
    containInField: containInField,
    latchedSide: latched,
  );

  test('row content lines up under the anchor, 4 px below the box', () {
    final p = place(anchorStart: 150);
    expect(p.left, 150 - 12);
    expect(p.width, 420);
    expect(p.side, FilterMenuSide.below);
    expect(p.top, field.bottom + 4);
    expect(p.bottom, isNull);
  });

  test('never hangs past the search box on the right', () {
    // Token start far right, after several chips.
    final p = place(anchorStart: 850);
    expect(p.left + p.width, field.right);
  });

  test('never starts before the search box on the left', () {
    final p = place(anchorStart: 104);
    expect(p.left, field.left);
  });

  test('a box narrower than the menu falls back to the overlay', () {
    const narrow = Rect.fromLTWH(700, 20, 300, 40);
    final p = place(box: narrow, anchorStart: 740);
    // Start-aligned with the token, then kept on screen by the overlay clamp.
    expect(p.left, 740 - 12);
    expect(p.left + p.width, lessThanOrEqualTo(overlay.width - 8));

    final edge = place(
      box: const Rect.fromLTWH(950, 20, 240, 40),
      anchorStart: 1100,
    );
    expect(edge.left + edge.width, overlay.width - 8);
  });

  test(
    'an overlay narrower than the menu shrinks it instead of overflowing',
    () {
      const pane = Size(400, 800);
      final p = place(
        size: pane,
        box: const Rect.fromLTWH(16, 20, 368, 40),
        anchorStart: 60,
      );
      expect(p.width, 400 - 16);
      expect(p.left, 8);
    },
  );

  test('RTL mirrors: the menu ends at the token start', () {
    final p = place(anchorStart: 800, dir: TextDirection.rtl);
    expect(p.left + p.width, 800 + 12);
    // …and is still kept inside the box.
    final clamped = place(anchorStart: 895, dir: TextDirection.rtl);
    expect(clamped.left + clamped.width, field.right);
  });

  test('containInField: false clamps to the overlay only', () {
    // 700 would be pulled back to 480 by the box (see the right-edge test).
    final p = place(anchorStart: 700, containInField: false);
    expect(p.left, 700 - 12);
    expect(place(anchorStart: 700).left, field.right - 420);
    final off = place(anchorStart: 1150, containInField: false);
    expect(off.left + off.width, overlay.width - 8);
  });

  test('height is capped to the room above the keyboard', () {
    // 800 tall, 500 of keyboard: 300 visible, menu starts at 64.
    final p = place(bottomInset: 500);
    expect(p.side, FilterMenuSide.below);
    expect(p.maxHeight, 800 - 500 - 8 - (field.bottom + 4));
    expect(p.maxHeight, lessThan(320));
  });

  test('flips above only when below is unusable and above is roomier', () {
    const low = Rect.fromLTWH(100, 700, 800, 40);
    final p = place(box: low);
    expect(p.side, FilterMenuSide.above);
    expect(p.top, isNull);
    // Bottom edge sits 4 px above the box.
    expect(p.bottom, overlay.height - (low.top - 4));
    expect(p.maxHeight, 320);

    // Short below but even shorter above: stays below.
    const short = Size(1200, 180);
    final stay = place(size: short, box: const Rect.fromLTWH(100, 20, 800, 40));
    expect(stay.side, FilterMenuSide.below);
  });

  test('a latched side survives the keyboard rising', () {
    const low = Rect.fromLTWH(100, 400, 800, 40);
    final open = place(box: low);
    expect(open.side, FilterMenuSide.below);
    final keyboardUp = place(box: low, bottomInset: 300, latched: open.side);
    expect(keyboardUp.side, FilterMenuSide.below);
    // Unlatched, the same geometry would have flipped.
    expect(place(box: low, bottomInset: 300).side, FilterMenuSide.above);
  });

  test('never collapses below a few rows', () {
    final p = place(bottomInset: 760);
    expect(p.maxHeight, greaterThanOrEqualTo(96));
  });
}
