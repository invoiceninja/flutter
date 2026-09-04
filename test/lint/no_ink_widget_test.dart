import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Opt-out marker — see the doc below.
const String _kAllowMarker = 'lint: allow-ink';

/// CI lint: no `Ink` / `Ink.image` in `lib/`. Paint a tappable surface with a
/// **local** `Material(color:, borderRadius:) > InkWell > Container(border-only)`
/// instead — the shape `sidebar_search_box.dart`, `sidebar_sync_button.dart`
/// and `company_switcher_button.dart` already use.
///
/// `Ink` registers an `InkDecoration` on the *nearest ancestor* `Material`, and
/// `_RenderInkFeatures.paint` draws every ink feature **before** its child
/// subtree. So any opaque widget between the `Ink` and that ancestor Material
/// paints over the decoration: the fill, the border and the tap ripple are all
/// drawn and then covered.
///
/// That is not hypothetical. `WhiteLabelFooter` was the only `Ink` in the app
/// and its ancestor Material was the Scaffold's / the Drawer's, because
/// `InSidebar` has none of its own — so `InSidebar`'s opaque
/// `AnimatedContainer(color: tokens.surface)` hid the card completely, and
/// "Purchase White Label" shipped for months as a bare line of text with no
/// card and no ripple (invoiceninja/flutter#124). Nothing catches this: it
/// analyzes clean, it throws nothing, and a widget test that pumps the widget
/// on its own — where the Scaffold's Material *is* directly above it — renders
/// it perfectly.
///
/// **House style, not a law of physics.** `Ink` is correct whenever you own the
/// nearest ancestor `Material` and nothing opaque sits between, and `Ink.image`
/// is the only sane way to ripple over an image fill (`Material.color` takes a
/// `Color`, not a `DecorationImage`). Put `// lint: allow-ink` on the line or
/// the line above it, with a reason. The default is a ban because the failure
/// mode is invisible in review and in tests.
///
/// **Scope note.** This catches the rarer half of the defect. The commoner half
/// is a bare `InkWell` under an opaque box — `trial_footer.dart`'s "Manage
/// Plan" link was one, fixed alongside #124 — which a text scan cannot see,
/// because whether it is a bug depends on what is above the widget at runtime.
void main() {
  test('lib/ does not use the Ink widget', () {
    // `\bInk\(` and `\bInk.image(`. `InkWell(` / `InkResponse(` don't match (a
    // paren must follow `Ink`), and neither does an identifier ending in `Ink`
    // such as `accentInk(` (no word boundary between `t` and `I`).
    final pattern = RegExp(r'\bInk(?:\.image)?\(');
    final offenders = <String>[];
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'lib/ should exist');

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart')) continue;
      if (entity.path.endsWith('.freezed.dart')) continue;

      final lines = entity.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (!pattern.hasMatch(lines[i])) continue;
        final line = lines[i].trim();
        // A line whose trimmed form starts with `//` cannot hold live code, so
        // prose about `Ink(` — including a comment explaining this very ban —
        // costs nothing.
        if (line.startsWith('//')) continue;
        if (line.contains(_kAllowMarker)) continue;
        if (i > 0 && lines[i - 1].contains(_kAllowMarker)) continue;
        offenders.add('${entity.path}:${i + 1}:  $line');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Use Material(color:, borderRadius:) > InkWell > Container(border '
          'only) instead of Ink: an ancestor Material paints ink features '
          'below its whole child subtree, so any opaque widget between the '
          'two hides the decoration AND the ripple, silently. If you own the '
          'nearest Material and nothing opaque is in between, opt out with '
          '`// $_kAllowMarker` plus a reason. Found:\n  '
          '${offenders.join('\n  ')}',
    );
  });
}
