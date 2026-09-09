import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Opt-out markers. Each occurrence exempts exactly ONE host in its file — see
/// the counting note below.
const String _kAllowNoTapOutside = 'lint: allow-no-tap-outside';
const String _kAllowOpenDirection = 'lint: allow-options-open-direction';

/// The two invariants every `RawAutocomplete` options popover in this app has
/// to carry. Both fail **silently**, and neither is visible from inside the
/// widget that gets them wrong.
///
/// **1. The field must set `onTapOutside`.** `_canShowOptionsView` is
/// `hasFocus && options.isNotEmpty` (`widgets/autocomplete.dart`), so the
/// overlay closes only on a `_select`, on a `DismissIntent` (Escape — a
/// hardware keyboard) or on focus loss; and `_EditableTextTapOutsideAction`
/// (`widgets/editable_text.dart`) deliberately does *not* unfocus for a
/// `PointerDeviceKind.touch` event on android / iOS / fuchsia unless `kIsWeb`.
/// An options list that has anything in it therefore had **no dismissal path**
/// on a phone or tablet — it stayed up until the user picked something or left
/// the screen (invoiceninja/flutter#130). `dismissPickerOnTapOutside`
/// (`lib/ui/core/widgets/picker_dismissal.dart`) is the one hook; its dartdoc
/// carries the full argument, including why a tap on an option row can't trip
/// it. A picker shipped without it looks perfect on every desktop review.
///
/// **2. The popover must open into whichever side has more room.** Left at
/// `OptionsViewOpenDirection.down`, a picker low on the screen gets only the
/// space beneath it, floored at a ~48 px sliver. Four of the five hosts passed
/// `mostSpace`; the line-item tax cell did not, so the tax cell on the last row
/// of a long invoice was that picker — for the life of the file, with the rule
/// written down in CLAUDE.md and nothing checking it.
///
/// Both rules are **counts** per file, not scans of a window around
/// `fieldViewBuilder:`. That builder runs to ~85 lines in
/// `searchable_dropdown_field.dart`, and `line_item_table_desktop.dart`
/// legitimately holds two `RawAutocomplete`s — a count handles that without
/// tuning, and cannot be satisfied by accident. Opt-outs are counted the same
/// way rather than skipping the file, so a marker added for one host in a
/// two-host file can't quietly exempt the other.
///
/// Know the limits. This is an existence/count check: it proves the hook and
/// the direction are *present* in a file that builds a `RawAutocomplete`, not
/// that they sit on the right `TextField` — which is why
/// `line_item_table_desktop.dart`'s `_ProductCell` and `_TaxCell`, the two
/// hooks no widget test covers, are worth re-reading by hand if that file is
/// refactored. It also cannot see a file that correctly hoists one callback and
/// shares it across two fields (1 hook, 2 hosts would fail); nobody does that
/// today. And it says nothing about a hand-rolled `OverlayPortal` menu —
/// `token_search_field.dart` solves the same dismissal problem its own way,
/// with a shared `TapRegion.groupId`.
void main() {
  /// Every `.dart` file under `lib/`, as (path, raw source, source with `//`
  /// tails stripped). Stripping matters: the prose explaining these rules names
  /// every token they match, so an un-stripped scan fails on its own
  /// documentation. The raw text is kept only for counting opt-out markers,
  /// which live in comments by construction.
  late final List<(String, String, String)> sources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) {
        final raw = f.readAsStringSync();
        final stripped = raw
            .split('\n')
            .map((l) {
              final i = l.indexOf('//');
              return i == -1 ? l : l.substring(0, i);
            })
            .join('\n');
        return (f.path, raw, stripped);
      })
      .toList();

  int count(String src, String needle) => needle.allMatches(src).length;

  /// Hosts in [src]. Both spellings: `RawAutocomplete<Foo>(` and the
  /// type-inferred `RawAutocomplete(`. The second is legal — `T` is inferred
  /// from `optionsBuilder` — and `strict-raw-types` does not flag it, so a
  /// picker written that way would otherwise pass both rules with zero hooks.
  int hostsIn(String src) =>
      count(src, 'RawAutocomplete<') + count(src, 'RawAutocomplete(');

  test('every RawAutocomplete field dismisses on a tap outside', () {
    final offenders = <String>[];
    for (final (path, raw, src) in sources) {
      final hosts = hostsIn(src);
      if (hosts == 0) continue;
      final covered =
          count(src, 'dismissPickerOnTapOutside') +
          count(raw, _kAllowNoTapOutside);
      if (covered < hosts) {
        offenders.add('$path ($hosts host(s), $covered covered)');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Every RawAutocomplete field must pass '
          '`onTapOutside: dismissPickerOnTapOutside(focusNode)`. Without it the '
          'options popover has no dismissal path at all on native Android/iOS '
          'touch: the SDK closes it only on a pick, on Escape, or on focus '
          'loss, and it will not drop focus for a touch tap outside. Add the '
          'hook, or one `// $_kAllowNoTapOutside <reason>` per exempt host if '
          'it really does own dismissal some other way.',
    );
  });

  test('every RawAutocomplete popover opens into the roomier side', () {
    final offenders = <String>[];
    for (final (path, raw, src) in sources) {
      final hosts = hostsIn(src);
      if (hosts == 0) continue;
      // The VALUE, not the parameter name: counting the bare
      // `optionsViewOpenDirection` would let an explicit `.down` satisfy a rule
      // whose whole point is that `.down` is the bug.
      final covered =
          count(src, 'OptionsViewOpenDirection.mostSpace') +
          count(raw, _kAllowOpenDirection);
      if (covered < hosts) {
        offenders.add('$path ($hosts host(s), $covered covered)');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Every RawAutocomplete must pass `optionsViewOpenDirection: '
          'OptionsViewOpenDirection.mostSpace`. At the `.down` default a picker '
          'low on the screen gets only the space beneath it, floored at a '
          '~48 px sliver. Pin a different direction with one '
          '`// $_kAllowOpenDirection <reason>` per host.',
    );
  });

  /// Rule 1 counts a call site. This is the callee — without it, gutting the
  /// helper leaves all five call sites green while every popover goes
  /// undismissable again. Comment-stripped like the others, so a signature
  /// pasted into the helper's own dartdoc can't satisfy it.
  test('the shared hook actually drops focus', () {
    final src = File('lib/ui/core/widgets/picker_dismissal.dart')
        .readAsLinesSync()
        .map((l) {
          final i = l.indexOf('//');
          return i == -1 ? l : l.substring(0, i);
        })
        .join(' ');
    expect(
      RegExp(
        r'TapRegionCallback\s+dismissPickerOnTapOutside\(\s*FocusNode\s+(\w+),?\s*\)'
        r'\s*=>\s*\(_\)\s*=>\s*\1\.unfocus\(\)',
      ).hasMatch(src),
      isTrue,
      reason:
          'dismissPickerOnTapOutside must unfocus the node it is given — that '
          'is the only thing that hides a RawAutocomplete options overlay.',
    );
  });
}
