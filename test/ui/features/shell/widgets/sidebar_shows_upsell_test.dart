import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/features/shell/widgets/in_sidebar.dart';

/// The white-label upsell's viewport gate (invoiceninja/flutter#124).
///
/// A pure function precisely so it can be tested here: `InSidebar` itself
/// cannot be pumped (`sidebar_search_box_test.dart` records the tear-down
/// deadlock), and the alternative — scanning `in_sidebar.dart` for the gate
/// expression — pins spelling, not behaviour. Before this existed, changing the
/// threshold from 480 to 4800 made the card vanish on every device in the app
/// and turned nothing red.
void main() {
  group('sidebarShowsUpsell', () {
    // Every phone in landscape sits below the threshold: iPhone SE 375,
    // Pixel 8 412, iPhone 15 Pro Max 430. This is the reported case.
    test('a landscape phone drops the card', () {
      expect(sidebarShowsUpsell(touch: true, height: 375), isFalse);
      expect(sidebarShowsUpsell(touch: true, height: 412), isFalse);
      expect(sidebarShowsUpsell(touch: true, height: 430), isFalse);
    });

    test('a portrait phone and a tablet keep it', () {
      expect(sidebarShowsUpsell(touch: true, height: 667), isTrue); // SE
      expect(sidebarShowsUpsell(touch: true, height: 915), isTrue); // Pixel 8
      expect(sidebarShowsUpsell(touch: true, height: 1133), isTrue); // iPad
    });

    // The boundary, spelled out: `<` not `<=`, so 480 itself keeps the card.
    // Without these three a comparison flip is invisible.
    test('the threshold is exclusive at 480', () {
      expect(sidebarShowsUpsell(touch: true, height: 479), isFalse);
      expect(sidebarShowsUpsell(touch: true, height: 480), isTrue);
      expect(sidebarShowsUpsell(touch: true, height: 481), isTrue);
    });

    // The reason the gate is a conjunction rather than a bare height test: a
    // deliberately-short pointer window (a half-screen 1080p snap is 1920x540,
    // Chrome with DevTools docked ~1366x550) belongs to exactly the
    // self-hosted desktop user the CTA exists to convert, and has ~300 px of
    // nav list to spare. Drop the `touch &&` and this is the test that fails.
    test('a short pointer window keeps the card at any height', () {
      expect(sidebarShowsUpsell(touch: false, height: 540), isTrue);
      expect(sidebarShowsUpsell(touch: false, height: 100), isTrue);
      expect(sidebarShowsUpsell(touch: false, height: 0), isTrue);
    });
  });
}
