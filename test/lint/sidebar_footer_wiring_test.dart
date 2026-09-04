import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level guards for the sidebar footer's inset ownership
/// (invoiceninja/flutter#124).
///
/// Scanned rather than pumped, for the reason `sidebar_search_box_test.dart`
/// records at its own source scan: a widget test of `InSidebar` was tried and
/// **deadlocks** — `AppDatabase.close()` in the fixture tear-down waits on the
/// saved-views watch releasing its Drift subscriptions, and that chain resolves
/// on `Timer.run`, which fake time never advances again after the last pump. The
/// file hangs with no output rather than failing. The geometry these lines
/// produce is covered against replicas in
/// `test/ui/features/shell/sidebar_footer_actions_widget_test.dart` and
/// `white_label_footer_test.dart`; this file is the only thing that knows the
/// replica still describes the real call site.
///
/// Every property here is silent on a desktop dev machine, where the bottom
/// safe-area inset is 0 and all of them are unobservable.
///
/// **Deliberately not pinned here: the height threshold itself.** That is a pure
/// function, `sidebarShowsUpsell`, unit-tested in
/// `test/ui/features/shell/widgets/sidebar_shows_upsell_test.dart`. Scanning for
/// a gate *expression* is a trap this repo has already sprung once — see
/// `sidebar_search_box_test.dart`, which "pinned `if (touch && !collapsed)` and
/// went red the day the mount became a ternary, reporting a removed gate that
/// was right there". A bare identifier is the most a scan should ever match,
/// because `dart format` re-wraps by line width and so reformats on renames that
/// change no behaviour.
void main() {
  final sidebar = File(
    'lib/ui/features/shell/widgets/in_sidebar.dart',
  ).readAsStringSync();
  final footerActions = File(
    'lib/ui/features/shell/widgets/sidebar_footer_actions.dart',
  ).readAsStringSync();

  /// Source between [from] and [to], clamped so a marker that has moved fails
  /// the enclosing expectation instead of throwing `RangeError` out of
  /// `substring` — which reads like a broken harness rather than a diagnosis.
  String slice(String src, int from, String to) {
    final end = src.indexOf(to, from);
    return src.substring(from, end == -1 ? src.length : end);
  }

  test('the sidebar SafeArea owns the bottom inset', () {
    final start = sidebar.indexOf('final content = SafeArea(');
    expect(
      start,
      greaterThan(-1),
      reason: 'the outer SafeArea moved or was renamed',
    );

    final args = slice(sidebar, start, 'child:');
    // `bottom: false` specifically, not any `bottom:` — writing the default out
    // as `bottom: true` for clarity, or adding a `minimum:`, is fine and must
    // not fail a test whose whole point is that the bottom edge IS paid here.
    expect(
      args.contains('bottom: false'),
      isFalse,
      reason:
          'The sidebar has three footer children (icon row, TrialFooter, '
          'WhiteLabelFooter). `bottom: false` here hands the inset to the '
          'FIRST of them, which pads the middle of the footer instead of the '
          'end of it and leaves the last card inside the gesture bar.',
    );
    expect(args.contains('left: false'), isTrue);
    expect(args.contains('right: false'), isTrue);
  });

  test('SidebarFooterActions owns no inset of its own', () {
    // A `SafeArea` here is the #124 bug exactly: this widget is not the last
    // thing in the footer, so its inset lands between the icons and the card.
    final code = footerActions
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(
      code.contains('SafeArea'),
      isFalse,
      reason:
          "the sidebar's outer SafeArea pays this row's bottom inset — see "
          'its comment in in_sidebar.dart',
    );
  });

  test('the white-label upsell is gated, and the trial card is not', () {
    // Identifier-only: survives reformatting and gets carried by a rename.
    expect(
      sidebar.contains('sidebarShowsUpsell('),
      isTrue,
      reason:
          'the upsell must stay behind the height gate — a landscape phone '
          'cannot afford ~49 px of optional chrome',
    );

    final trial = sidebar.indexOf('TrialFooter(compact:');
    final upsell = sidebar.indexOf('WhiteLabelFooter(compact:');
    expect(trial, greaterThan(-1), reason: 'TrialFooter mount not found');
    expect(upsell, greaterThan(trial), reason: 'the cards swapped order');

    // The gate must apply to the upsell only. An expiring trial is
    // time-critical and, unlike the standing offer, has no second home.
    expect(
      slice(sidebar, trial, 'WhiteLabelFooter(').contains('sidebarShowsUpsell'),
      isFalse,
      reason: 'TrialFooter must not be suppressed on a short viewport',
    );
  });

  test('nothing is mounted below the white-label upsell', () {
    // The bottom gutter is the outer SafeArea's, so it lands below whatever
    // this Column's last child happens to be. A widget appended after the
    // upsell would paint inside the gesture bar.
    //
    // Unlike its siblings this one was ALREADY true before #124 (the upsell was
    // last then too) — it pins the invariant the fix newly depends on, rather
    // than the fix itself.
    final start = sidebar.indexOf('WhiteLabelFooter(compact:');
    expect(start, greaterThan(-1));

    // End at the `],` that closes the children list. Matched without leading
    // whitespace so a change in nesting depth can't silently move it, and
    // clamped so a missing one fails loudly here rather than throwing.
    final tailStart = sidebar.indexOf('\n', start) + 1;
    final tail = slice(sidebar, tailStart, '],');
    expect(
      sidebar.indexOf('],', tailStart),
      greaterThan(-1),
      reason: "the footer Column's closing `],` was not found",
    );

    final code = tail
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('//'))
        .toList();
    expect(
      code,
      isEmpty,
      reason:
          'Found a widget after WhiteLabelFooter in the sidebar Column. It '
          'would render inside the Android gesture bar / iPhone home '
          'indicator. Found:\n  ${code.join('\n  ')}',
    );
  });
}
