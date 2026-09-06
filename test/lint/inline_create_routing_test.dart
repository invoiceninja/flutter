import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Opt-out marker for the `Align` rule — see the doc below.
const String _kAllowAlignMarker = 'lint: allow-options-align';

/// The two `RawAutocomplete` invariants CLAUDE.md documents but nothing tested.
///
/// Both fail **silently**: the code analyzes clean, throws nothing, and renders
/// perfectly in the case a widget test is most likely to pump.
///
/// **1. An options popover must not wrap itself in an `Align`.**
/// `RawAutocomplete` already wraps `optionsViewBuilder`'s output in
/// `ConstrainedBox(tight) -> Align(topStart | bottomStart)`, and a bare `Align`
/// shrink-wraps only under an *infinite* constraint. So one of ours fills the
/// whole bounding box, leaves the SDK's alignment nothing to move, and strands
/// an upward-opening popover at the top of the screen. Invisible on a desktop
/// window with room below the field; obvious on a phone.
///
/// **2. An inline "Create «x»" row must not be routed through `onSelected`.**
/// That is `RawAutocomplete._select`, which early-returns on an *unchanged*
/// selection **before** hiding the overlay — and a create option is a fresh
/// instance per build with no `operator ==`, so after one **cancelled** create
/// the same instance is still the latched selection and the row is dead until
/// the user edits the text. The success path self-heals (the create changes the
/// field text, so options rebuild), which is exactly why this shipped: the only
/// broken path is the one nobody re-tests. The idiom is a direct call from
/// `InkWell.onTap`, plus key-path interceptors, with `onSelected` kept only as
/// a documented backstop.
///
/// Rule 2 is asserted structurally rather than behaviourally on purpose. The
/// desktop product cell's create handler is internal to its host, so no widget
/// test can drive its cancel path — the same reasoning as
/// `sidebar_footer_wiring_test.dart`, which scans source because the widget it
/// covers cannot be pumped.
///
/// Know its limits: it is an **existence** check over three named files. It
/// proves the direct-call idiom is present, not that the create row is the
/// thing using it, and it cannot notice a *new* inline-create picker shipped
/// without the routing. Rule 1, by contrast, scans all of `lib/`.
void main() {
  final libDir = Directory('lib');

  /// Every `.dart` file under `lib/`, as (path, source).
  List<(String, String)> sources() => libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) => (f.path, f.readAsStringSync()))
      .toList();

  test('no optionsViewBuilder wraps its popover in a bare Align', () {
    final offenders = <String>[];
    for (final (path, src) in sources()) {
      final lines = src.split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('optionsViewBuilder:')) continue;
        // Scan the handful of lines a `return Align(` would sit on — the
        // builder's own body, not the whole file.
        for (var j = i; j < lines.length && j < i + 12; j++) {
          final line = lines[j];
          // Both spellings: `return Align(` and the arrow form `=> Align(`.
          // Matching only the first left `_TaxCell` — the one remaining
          // offender in the tree — green, which is worse than no test.
          if (!RegExp(r'(return|=>)\s*Align\(').hasMatch(line)) continue;
          final prev = j > 0 ? lines[j - 1] : '';
          if (line.contains(_kAllowAlignMarker) ||
              prev.contains(_kAllowAlignMarker)) {
            break;
          }
          offenders.add('$path:${j + 1}');
          break;
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'An options popover must not Align itself — RawAutocomplete already '
          'wraps it in ConstrainedBox(tight) -> Align, and a bare Align fills '
          'that box instead of shrink-wrapping, so an upward-opening popover '
          'detaches to the top of the screen. Remove the Align, or add '
          '`// $_kAllowAlignMarker <reason>` if you really own the layout.',
    );
  });

  /// The two guards `RawAutocomplete._select` used to supply for free, and that
  /// routing around it silently removed.
  ///
  /// `_onFieldSubmitted` selects only `if (_optionsViewController.isShowing)`,
  /// and `_select` both early-returns on an unchanged selection and calls
  /// `hide()`. A picker that intercepts before them has to re-implement both,
  /// or Escape-then-Enter creates a record the user dismissed and a double
  /// Enter/click creates two.
  ///
  /// Structural, and deliberately so: the desktop product cell's create is
  /// internal to its host with no callback seam, and a widget test that drives
  /// it against real services hangs with no output — the fake-async zone never
  /// pumps a real Drift query's timers. That failure mode is documented in
  /// CLAUDE.md and was hit trying to write exactly that test.
  test('the product cell re-implements the two guards it routes around', () {
    const path =
        'lib/ui/features/billing_shared/line_item_editor/'
        'line_item_table_desktop.dart';
    final src = File(path).readAsStringSync().replaceAll('\n', ' ');

    expect(
      RegExp(
        r'bool get _highlightIsCreateRow\s*\{[^}]*_optionsVisible',
      ).hasMatch(src),
      isTrue,
      reason:
          'the create row must be unreachable once the overlay is hidden — '
          'DismissIntent hides it without touching focus or text, so nothing '
          'else observes an Escape.',
    );
    expect(
      RegExp(r'void _startCreate\(\)\s*\{\s*if \(_creating').hasMatch(src),
      isTrue,
      reason:
          'the create round trip needs a re-entrancy guard: _select used to '
          'supply one by latching the selection and hiding the overlay.',
    );
  });

  /// `SearchableDropdownField` wraps each option in `_ItemOpt<T>` so the list
  /// can also hold the synthetic create row. `RawAutocomplete._select`
  /// early-returns on `nextSelection == _selection`, and before the wrapper
  /// that comparison was the caller's own `T` equality — so a wrapper without
  /// `==` is a fresh instance per build and the early return silently stops
  /// firing for all ~124 call sites.
  ///
  /// Pinned structurally on purpose. The difference is **latent**: every
  /// keyboard path into `_select` is already intercepted (`_onSubmitted`
  /// dismisses on the committed row) and the committed row's tap deliberately
  /// bypasses `onSelected`, so no widget test can observe it — and the repo's
  /// own test type has no `==`, which would make such a test vacuous.
  test('_ItemOpt preserves T equality', () {
    final src = File(
      'lib/ui/core/widgets/searchable_dropdown_field.dart',
    ).readAsStringSync().replaceAll('\n', ' ');
    expect(
      RegExp(
        r'final class _ItemOpt<T extends Object>.*?'
        r'bool operator ==\(Object other\).*?'
        r'(other\.item == item|item == other\.item)',
      ).hasMatch(src),
      isTrue,
      reason:
          '_ItemOpt must delegate == to `item` (not to idOf, which is coarser '
          'for a freezed T with an id-only projection). Without it '
          'RawAutocomplete._select stops de-duplicating unchanged selections '
          'at every call site.',
    );
  });

  test(
    'every inline-create row fires its handler directly, not via onSelected',
    () {
      // The three pickers that append a synthetic create option. Each must call
      // its create handler from the row's own `onTap`.
      const expected = <String, String>{
        'lib/ui/core/widgets/client_picker_field.dart': '_handleCreate',
        'lib/ui/core/widgets/tag_picker_field.dart': '_handleCreate',
        'lib/ui/features/billing_shared/line_item_editor/line_item_table_desktop.dart':
            '_startCreate',
      };

      for (final entry in expected.entries) {
        final file = File(entry.key);
        expect(
          file.existsSync(),
          isTrue,
          reason:
              '${entry.key} is gone — this lint pins a rule about it, so '
              'update the map rather than letting the read throw.',
        );
        final src = file.readAsStringSync().replaceAll('\n', ' ');
        final handler = RegExp.escape(entry.value);
        // Both spellings: the closure `onTap: () => handler(...)` and the
        // tear-off `onTap: handler,`.
        final matched =
            RegExp(
              'onTap: \\(\\) =>\\s*(widget\\.)?$handler\\(',
            ).hasMatch(src) ||
            RegExp('onTap: (widget\\.)?$handler[,)]').hasMatch(src);
        expect(
          matched,
          isTrue,
          reason:
              '${entry.key} must call ${entry.value} straight from the create '
              "row's InkWell.onTap. Routing it through onSelected reaches "
              'RawAutocomplete._select, which early-returns on an unchanged '
              'selection — so the row goes dead after one cancelled create.',
        );
      }
    },
  );
}
