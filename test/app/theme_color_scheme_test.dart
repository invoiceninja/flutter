import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';

/// `ColorScheme` roles that widgets in `lib/ui` actually read must be wired
/// to real tokens.
///
/// Flutter fills an unspecified role from a *related* one rather than
/// failing — `onSurfaceVariant` falls back to `onSurface`, the whole
/// `surfaceContainer*` ramp falls back to `surface`, and `errorContainer`
/// falls back to `error`. Every one of those fallbacks is silently wrong
/// here, and two were visible bugs:
///
///  * `_StarterCard` (`settings_entity_list_scaffold.dart`) paints
///    `surfaceContainerHigh` — which resolved to `#0E0E0E` against the
///    `#000000` dark-Carbon page background, i.e. an invisible card.
///  * `_LoadErrorBanner` (`settings_page_scaffold.dart`) paints
///    `errorContainer` — which resolved to `error`, so the settings
///    load-failure banner was white-on-saturated-red instead of the soft
///    `overdueSoft` ground every other error banner in the app uses.
///
/// A dozen "muted subtitle" sites read `onSurfaceVariant` and were rendering
/// at full `onSurface` brightness, losing the hierarchy entirely.
void main() {
  const variants = <String, InTheme>{
    'lightSand': InTheme.lightSand,
    'lightMist': InTheme.lightMist,
    'lightPaper': InTheme.lightPaper,
    'darkEspresso': InTheme.darkEspresso,
    'darkMidnight': InTheme.darkMidnight,
    'darkCarbon': InTheme.darkCarbon,
  };

  variants.forEach((name, tokens) {
    group(name, () {
      final cs = buildInTheme(tokens).colorScheme;

      test('muted-text and error roles are distinct from their fallbacks', () {
        expect(
          cs.onSurfaceVariant,
          isNot(cs.onSurface),
          reason:
              'onSurfaceVariant fell back to onSurface — muted text would '
              'render at full title brightness',
        );
        expect(
          cs.errorContainer,
          isNot(cs.error),
          reason:
              'errorContainer fell back to error — banners would paint on '
              'saturated red instead of the soft ground',
        );
      });

      test('raised container surfaces are distinct from surface', () {
        for (final (role, value) in [
          ('surfaceContainer', cs.surfaceContainer),
          ('surfaceContainerHigh', cs.surfaceContainerHigh),
          ('surfaceContainerHighest', cs.surfaceContainerHighest),
        ]) {
          expect(
            value,
            isNot(cs.surface),
            reason:
                '$role fell back to surface — a raised card would be '
                'invisible against the page',
          );
        }
      });

      test('roles map to the intended design tokens', () {
        expect(cs.onSurfaceVariant, tokens.ink2);
        expect(cs.errorContainer, tokens.overdueSoft);
        expect(cs.onErrorContainer, tokens.overdue);
        expect(cs.surfaceContainerHigh, tokens.surfaceAlt);
      });
    });
  });
}
