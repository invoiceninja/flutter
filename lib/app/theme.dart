import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';

/// External URLs the login screen needs.
const String kSignupUrl = 'https://invoiceninja.com';
const String kStatusUrl = 'https://status.invoiceninja.com';

/// Builds the v2 design-system [ThemeData] for the given palette.
///
/// All variants share radii, spacing, and Inter Tight typography; the
/// colors come from the [InTheme] argument and are attached as a
/// `ThemeExtension` so widgets can read them via `context.inTheme.<name>`.
/// Brightness is derived from the tokens so this stays a pure function of
/// the palette — callers don't need to keep brightness in sync.
///
/// [accentOverride] swaps the palette's default `accent` (and re-derives
/// `accentSoft` / `accentInk` from it) so a per-(company, user) preference
/// can override the v2 blue without forking the whole palette. See
/// [AccentColorController].
ThemeData buildInTheme(InTheme baseTokens, {Color? accentOverride}) {
  final tokens = accentOverride == null
      ? baseTokens
      : baseTokens.copyWith(
          accent: accentOverride,
          accentSoft: _deriveAccentSoft(accentOverride, baseTokens),
          accentInk: _deriveAccentInk(accentOverride, baseTokens.brightness),
        );
  final brightness = tokens.brightness;

  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: tokens.accent,
    onPrimary: Colors.white,
    secondary: tokens.ink,
    onSecondary: tokens.surface,
    tertiary: tokens.accentLime,
    onTertiary: tokens.ink,
    error: tokens.overdue,
    onError: Colors.white,
    // Soft error surface — matches how the app renders every other error
    // banner (`SaveFailedBanner`: `overdueSoft` ground, `overdue` accent).
    // Left unset, `errorContainer` falls back to `error` itself, so the
    // settings load-failure banner painted as white-on-saturated-red.
    errorContainer: tokens.overdueSoft,
    onErrorContainer: tokens.overdue,
    surface: tokens.surface,
    onSurface: tokens.ink,
    // Unset, this falls back to `onSurface` — so every "muted subtitle" that
    // asks for `onSurfaceVariant` rendered at full title brightness and the
    // hierarchy silently collapsed (13 sites, worst on dark where `ink` is
    // near-white).
    onSurfaceVariant: tokens.ink2,
    // The container ramp all falls back to `surface` when unset, which makes
    // a raised card invisible: `_StarterCard` asks for `surfaceContainerHigh`
    // and got #0E0E0E on the #000000 dark-Carbon background.
    surfaceContainerLowest: tokens.bg,
    surfaceContainerLow: tokens.surface,
    surfaceContainer: tokens.surfaceAlt,
    surfaceContainerHigh: tokens.surfaceAlt,
    surfaceContainerHighest: tokens.surfaceAlt,
    outline: tokens.border,
    outlineVariant: tokens.borderStrong,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: tokens.bg,
    canvasColor: tokens.bg,
    dividerColor: tokens.border,
    extensions: [tokens],
  );

  // The v2 design system specifies Geist as the primary sans, with Inter
  // Tight as its declared fallback. Geist isn't bundled, so we use Inter
  // Tight — same geometric-humanist family — shipped as a bundled asset font
  // ([kSansFontFamily], see pubspec `fonts:`) so it loads from our own origin
  // instead of fetching from fonts.gstatic.com at runtime. The variable
  // font's `wght` axis is driven by each text style's `fontWeight`.
  final textTheme = base.textTheme.apply(
    fontFamily: kSansFontFamily,
    bodyColor: tokens.ink,
    displayColor: tokens.ink,
  );

  return base.copyWith(
    textTheme: textTheme,
    primaryTextTheme: textTheme,

    // Flat header app-wide: kill M3's "scrolled under" tint so an AppBar
    // never changes color when content scrolls beneath it. `surfaceTint`
    // transparent + zero scrolled-under/base elevation keeps the bar a
    // constant, flat color. `centerTitle: false` pins left-aligned titles
    // on every platform — without it macOS/iOS center the title whenever an
    // AppBar has fewer than 2 actions, so action-less screens (Reports,
    // Settings, Outbox) drifted out of line with the action-bearing list
    // screens. (Per-AppBar `style`/properties can still override.)
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: textTheme.bodyMedium?.copyWith(color: tokens.ink3),
      floatingLabelStyle: textTheme.bodySmall?.copyWith(color: tokens.ink2),
      // `ink3`, not `ink4`. A hint tells the user what the field expects, so
      // it's content — but `ink4` measures 2.00-2.32:1 against surface across
      // the six variants, below even the 3:1 non-text floor, and this one
      // line styles every placeholder in the app. `ink4` stays correct for
      // what it's used for elsewhere (disabled sidebar rows, muted cells, a
      // drag handle) where low contrast is the intent. `ink3` lands at
      // ~4.0-4.7:1.
      hintStyle: textTheme.bodyMedium?.copyWith(color: tokens.ink3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(InRadii.r2),
        borderSide: BorderSide(color: tokens.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(InRadii.r2),
        borderSide: BorderSide(color: tokens.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(InRadii.r2),
        borderSide: BorderSide(color: tokens.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(InRadii.r2),
        borderSide: BorderSide(color: tokens.overdue),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(InRadii.r2),
        borderSide: BorderSide(color: tokens.overdue, width: 1.5),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: tokens.accent,
        foregroundColor: Colors.white,
        // `Size.fromHeight(44)` is `Size(double.infinity, 44)` — full-width by
        // default. Fine for Column-stacked form buttons (login, settings);
        // crashes inside a `Row` (Row gives non-flex children unbounded
        // `maxWidth`, which the button then tries to enforce). When putting
        // a FilledButton in a Row, override per-call with e.g.
        // `style: FilledButton.styleFrom(minimumSize: const Size(64, 44))`.
        minimumSize: const Size.fromHeight(44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(InRadii.r2),
        ),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.ink,
        side: BorderSide(color: tokens.border),
        // See FilledButton note above — `Size.fromHeight(40)` is
        // `Size(double.infinity, 40)` and crashes inside a Row.
        minimumSize: const Size.fromHeight(40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(InRadii.r2),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: tokens.ink2,
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
    ),

    cardTheme: CardThemeData(
      color: tokens.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: tokens.border),
        borderRadius: BorderRadius.circular(InRadii.r3),
      ),
      margin: EdgeInsets.zero,
    ),

    // M3's default `SegmentedButton` silhouette is a `StadiumBorder` (pill).
    // The v2 design system uses rounded rectangles for every button family —
    // mirror the `InRadii.r2` corner used by `FilledButton` / `OutlinedButton`
    // above so all the button shapes line up. Per-widget `style` still wins
    // via Flutter's effectiveValue chain, so individual call sites can still
    // override (e.g. ThemeTile's per-segment minimumSize for uniform width).
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(InRadii.r2),
        ),
      ),
    ),

    // Snackbar styling lives in `lib/ui/core/widgets/notify.dart` — the
    // `Notify.success/error/warning/info` helpers render their own card and
    // pass `backgroundColor: transparent` so the shell here just controls
    // float + rounded shape for any direct `SnackBar` usage that bypasses
    // the helper.
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(InRadii.r2),
      ),
    ),

    // `MenuAnchor` / `SubmenuButton` drive the entity action menus (list-row
    // `⋮` and the detail-header "More" overflow) and the reports date-preset
    // picker. M3 defaults render a sharp-cornered surface — pin the v2
    // rounded-rect (`InRadii.r2`), the design system's surface/border, and a
    // popup-row-like padding so the fly-out matches the rest of the chrome.
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(tokens.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(2),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            side: BorderSide(color: tokens.border),
            borderRadius: BorderRadius.circular(InRadii.r2),
          ),
        ),
      ),
    ),
    // Applies to both `MenuItemButton` (leaf rows) and `SubmenuButton`
    // (the "Clone" parent) — `SubmenuButton` reads `MenuButtonTheme` too.
    menuButtonTheme: MenuButtonThemeData(
      style: MenuItemButton.styleFrom(
        foregroundColor: tokens.ink,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        minimumSize: const Size(0, 44),
      ),
    ),
  );
}

/// Blend an alpha-tinted version of [accent] over the palette's surface so
/// `accentSoft` (hover/selected backgrounds) tracks the override. The default
/// per-palette `accentSoft` values were chosen at ~15% saturation against
/// each surface — `Color.alphaBlend` reproduces that without a per-swatch
/// lookup table.
Color _deriveAccentSoft(Color accent, InTheme base) {
  final alpha = base.brightness == Brightness.light ? 0x26 : 0x33; // ~15% / 20%
  return Color.alphaBlend(accent.withAlpha(alpha), base.surface);
}

/// Lighten [accent] for dark backgrounds (the default dark palettes nudge
/// the accent up by ~25% lightness for active-state legibility); deepen it
/// for light backgrounds so the active-state ink reads as a saturated form
/// of the same hue.
Color _deriveAccentInk(Color accent, Brightness brightness) {
  final hsl = HSLColor.fromColor(accent);
  final adjusted = brightness == Brightness.dark
      ? hsl.withLightness((hsl.lightness + 0.18).clamp(0.0, 1.0))
      : hsl.withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0));
  return adjusted.toColor();
}
