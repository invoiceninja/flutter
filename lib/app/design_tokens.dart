import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/color_hex.dart';

/// Bundled font families (declared in pubspec `fonts:`), referenced by name so
/// they load from our own assets instead of fetching from fonts.gstatic.com.
/// [kSansFontFamily] is the primary UI typeface; [kMonoFontFamily] is used for
/// tabular numerals (amounts, line-item quantities, column cells).
const String kSansFontFamily = 'Inter Tight';
const String kMonoFontFamily = 'JetBrains Mono';

/// Canonical text style for any standalone currency/amount display: the
/// bundled [kMonoFontFamily] (JetBrains Mono) plus tabular figures so digits
/// align across rows. Every money `Text` goes through this — pass the per-site
/// size/weight/color; never re-inline the family, or it silently drifts back
/// to the sans face. Money rendered inside prose/activity spans is the one
/// exception (it stays in the body font).
TextStyle moneyTextStyle({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? height,
  double? letterSpacing,
}) => TextStyle(
  fontFamily: kMonoFontFamily,
  fontFeatures: const [FontFeature.tabularFigures()],
  fontSize: fontSize,
  fontWeight: fontWeight,
  color: color,
  height: height,
  letterSpacing: letterSpacing,
);

/// Invoice Ninja v2 design tokens — the single source of truth for the
/// visual language. (Originally ported from `docs/design/v2/tokens.jsx`;
/// those JSX mockups were removed in the "Clean up" pass, so this file is
/// now authoritative on its own.)
///
/// Read tokens through `context.inTheme.<name>` — the [BuildContext]
/// extension below resolves to the brightness-appropriate variant
/// automatically.
class InTheme extends ThemeExtension<InTheme> {
  const InTheme({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.borderStrong,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.ink4,
    required this.accent,
    required this.accentInk,
    required this.accentSoft,
    required this.accentLime,
    required this.rail,
    required this.railInk,
    required this.railInk2,
    required this.paid,
    required this.paidSoft,
    required this.overdue,
    required this.overdueSoft,
    required this.draft,
    required this.draftSoft,
    required this.sent,
    required this.sentSoft,
    required this.partial,
    required this.partialSoft,
    required this.warning,
    required this.warningSoft,
    required this.shadow1,
    required this.shadow2,
  });

  /// Whether this palette is a light or dark variant. `buildInTheme` derives
  /// the `Brightness` for `ThemeData` from this field so the function stays a
  /// pure function of the tokens.
  final Brightness brightness;

  // Surfaces.
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color borderStrong;

  // Ink (four tones).
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color ink4;

  // Accent.
  final Color accent;
  final Color accentInk;
  final Color accentSoft;
  final Color accentLime;

  // Sidebar rail.
  final Color rail;
  final Color railInk;
  final Color railInk2;

  // Status pairs (the saturated tone + its soft background variant).
  final Color paid;
  final Color paidSoft;
  final Color overdue;
  final Color overdueSoft;
  final Color draft;
  final Color draftSoft;
  final Color sent;
  final Color sentSoft;
  final Color partial;
  final Color partialSoft;

  // Caution / low-stock semantic (amber). Distinct from the destructive
  // [overdue] red and the `sent` ochre so "low" reads as caution, not error.
  final Color warning;
  final Color warningSoft;

  // Elevation. Stored on the tokens because dark mode wants softer shadows.
  final List<BoxShadow> shadow1;
  final List<BoxShadow> shadow2;

  /// Foreground colour for content placed *on* the destructive [overdue]
  /// background (the FilledButton in Danger Zone, for example). The same
  /// `#FFFFFF` across every variant because both light and dark `overdue`
  /// resolve to a saturated red where white ink keeps WCAG-AA contrast.
  /// Implemented as a getter (not a field) so adding a new theme variant
  /// doesn't need to wire it through copyWith / lerp / every constant.
  Color get onOverdue => const Color(0xFFFFFFFF);

  // ───────────────────────── Light palettes ─────────────────────────
  //
  // Three light variants. They share brand accent + status colors + the dark
  // sidebar rail; they differ on surface family (warm beige / cool grey /
  // pure white) and the matching ink tones. `lightSand` is the original v2
  // light tokens — kept identical so existing builds look the same.

  /// Light · Sand — warm beige (v2 default; the original token set).
  static const InTheme lightSand = InTheme(
    brightness: Brightness.light,
    bg: Color(0xFFF6F4EF),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFFBF9F4),
    border: Color(0xFFE8E3D8),
    borderStrong: Color(0xFFD6CFBF),
    ink: Color(0xFF1A1814),
    ink2: Color(0xFF4A4540),
    ink3: Color(0xFF857F73),
    ink4: Color(0xFFB5AE9F),
    accent: Color(0xFF2F7DC3),
    accentInk: Color(0xFF0E4A78),
    accentSoft: Color(0xFFE3EDF7),
    accentLime: Color(0xFFA8E22F),
    rail: Color(0xFF15140F),
    railInk: Color(0xFFE8E5DC),
    railInk2: Color(0xFF8A8678),
    paid: Color(0xFF1F8A5B),
    paidSoft: Color(0xFFE3F3EA),
    overdue: Color(0xFFC0392B),
    overdueSoft: Color(0xFFF9E6E2),
    draft: Color(0xFF857F73),
    draftSoft: Color(0xFFEDEAE2),
    sent: Color(0xFFB07A1F),
    sentSoft: Color(0xFFF6EBD3),
    partial: Color(0xFF2A6FDB),
    partialSoft: Color(0xFFE2ECFB),
    warning: Color(0xFFB45309),
    warningSoft: Color(0xFFF6EBD3),
    shadow1: _lightShadow1,
    shadow2: _lightShadow2,
  );

  /// Light · Mist — cool blue-grey neutrals.
  static const InTheme lightMist = InTheme(
    brightness: Brightness.light,
    bg: Color(0xFFECEEF2),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF5F7FA),
    border: Color(0xFFDDE2EA),
    borderStrong: Color(0xFFBFC7D3),
    ink: Color(0xFF16171A),
    ink2: Color(0xFF444649),
    ink3: Color(0xFF7A7E85),
    ink4: Color(0xFFADB2BA),
    accent: Color(0xFF2F7DC3),
    accentInk: Color(0xFF0E4A78),
    accentSoft: Color(0xFFE3EDF7),
    accentLime: Color(0xFFA8E22F),
    rail: Color(0xFF15140F),
    railInk: Color(0xFFE8E5DC),
    railInk2: Color(0xFF8A8678),
    paid: Color(0xFF1F8A5B),
    paidSoft: Color(0xFFE3F3EA),
    overdue: Color(0xFFC0392B),
    overdueSoft: Color(0xFFF9E6E2),
    draft: Color(0xFF7A7E85),
    draftSoft: Color(0xFFE6E9EE),
    sent: Color(0xFFB07A1F),
    sentSoft: Color(0xFFF6EBD3),
    partial: Color(0xFF2A6FDB),
    partialSoft: Color(0xFFE2ECFB),
    warning: Color(0xFFB45309),
    warningSoft: Color(0xFFF6EBD3),
    shadow1: _lightShadow1,
    shadow2: _lightShadow2,
  );

  /// Light · Paper — crisp near-white, neutral ink.
  static const InTheme lightPaper = InTheme(
    brightness: Brightness.light,
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFFAFAF9),
    surfaceAlt: Color(0xFFF4F4F3),
    border: Color(0xFFE5E5E4),
    borderStrong: Color(0xFFCECDCB),
    ink: Color(0xFF18181A),
    ink2: Color(0xFF45454A),
    ink3: Color(0xFF7C7C82),
    ink4: Color(0xFFB3B3B9),
    accent: Color(0xFF2F7DC3),
    accentInk: Color(0xFF0E4A78),
    accentSoft: Color(0xFFE3EDF7),
    accentLime: Color(0xFFA8E22F),
    rail: Color(0xFF15140F),
    railInk: Color(0xFFE8E5DC),
    railInk2: Color(0xFF8A8678),
    paid: Color(0xFF1F8A5B),
    paidSoft: Color(0xFFE3F3EA),
    overdue: Color(0xFFC0392B),
    overdueSoft: Color(0xFFF9E6E2),
    draft: Color(0xFF7C7C82),
    draftSoft: Color(0xFFEDEDEB),
    sent: Color(0xFFB07A1F),
    sentSoft: Color(0xFFF6EBD3),
    partial: Color(0xFF2A6FDB),
    partialSoft: Color(0xFFE2ECFB),
    warning: Color(0xFFB45309),
    warningSoft: Color(0xFFF6EBD3),
    shadow1: _lightShadow1,
    shadow2: _lightShadow2,
  );

  // ───────────────────────── Dark palettes ─────────────────────────

  /// Dark · Espresso — warm deep brown. Anchored on `rail`
  /// (`#15140F`, already the design system's "deep ink").
  static const InTheme darkEspresso = InTheme(
    brightness: Brightness.dark,
    bg: Color(0xFF15140F),
    surface: Color(0xFF1F1E18),
    surfaceAlt: Color(0xFF28261F),
    border: Color(0xFF2E2B22),
    borderStrong: Color(0xFF3A362B),
    ink: Color(0xFFF6F4EF),
    ink2: Color(0xFFC8C2B5),
    ink3: Color(0xFF857F73), // perceptually mid — unchanged
    ink4: Color(0xFF5A554B),
    accent: Color(0xFF2F7DC3),
    accentInk: Color(0xFF7AB4E8), // lighter for dark active states
    accentSoft: Color(0xFF1B2C40),
    accentLime: Color(0xFFA8E22F),
    rail: Color(0xFF0A0907), // nudged darker so it differs from bg
    railInk: Color(0xFFE8E5DC),
    railInk2: Color(0xFF8A8678),
    paid: Color(0xFF1F8A5B),
    paidSoft: Color(0xFF1A3A2A),
    overdue: Color(0xFFE66055), // brighter for dark legibility
    overdueSoft: Color(0xFF3A1F1C),
    draft: Color(0xFFB5AE9F),
    draftSoft: Color(0xFF28261F),
    sent: Color(0xFFD49C42),
    sentSoft: Color(0xFF3A2D18),
    partial: Color(0xFF5994E8),
    partialSoft: Color(0xFF1B2A47),
    warning: Color(0xFFE0A33E),
    warningSoft: Color(0xFF332918),
    shadow1: _darkShadow1,
    shadow2: _darkShadow2,
  );

  /// Dark · Midnight — cool charcoal-navy.
  static const InTheme darkMidnight = InTheme(
    brightness: Brightness.dark,
    bg: Color(0xFF0F1115),
    surface: Color(0xFF181B21),
    surfaceAlt: Color(0xFF1F232B),
    border: Color(0xFF262A32),
    borderStrong: Color(0xFF34394A),
    ink: Color(0xFFECEEF2),
    ink2: Color(0xFFB7BCC8),
    ink3: Color(0xFF7A7E88),
    ink4: Color(0xFF4F535C),
    accent: Color(0xFF2F7DC3),
    accentInk: Color(0xFF7AB4E8),
    accentSoft: Color(0xFF18283F),
    accentLime: Color(0xFFA8E22F),
    rail: Color(0xFF060810),
    railInk: Color(0xFFE6E8ED),
    railInk2: Color(0xFF8388A0),
    paid: Color(0xFF1F8A5B),
    paidSoft: Color(0xFF18342A),
    overdue: Color(0xFFE66055),
    overdueSoft: Color(0xFF3A1F2A),
    draft: Color(0xFFADB2BA),
    draftSoft: Color(0xFF1F232B),
    sent: Color(0xFFD49C42),
    sentSoft: Color(0xFF332918),
    partial: Color(0xFF5994E8),
    partialSoft: Color(0xFF1B2A47),
    warning: Color(0xFFE0A33E),
    warningSoft: Color(0xFF332918),
    shadow1: _darkShadow1,
    shadow2: _darkShadow2,
  );

  /// Dark · Carbon — OLED-friendly neutral black (default).
  static const InTheme darkCarbon = InTheme(
    brightness: Brightness.dark,
    bg: Color(0xFF000000),
    surface: Color(0xFF0E0E0E),
    surfaceAlt: Color(0xFF161616),
    border: Color(0xFF1F1F1F),
    borderStrong: Color(0xFF2E2E2E),
    ink: Color(0xFFF2F2F2),
    ink2: Color(0xFFB8B8B8),
    ink3: Color(0xFF7D7D7D),
    ink4: Color(0xFF4E4E4E),
    accent: Color(0xFF2F7DC3),
    accentInk: Color(0xFF7AB4E8),
    accentSoft: Color(0xFF152538),
    accentLime: Color(0xFFA8E22F),
    rail: Color(0xFF000000),
    railInk: Color(0xFFE6E6E6),
    railInk2: Color(0xFF858585),
    paid: Color(0xFF1F8A5B),
    paidSoft: Color(0xFF153028),
    overdue: Color(0xFFE66055),
    overdueSoft: Color(0xFF2A1716),
    draft: Color(0xFFB8B8B8),
    draftSoft: Color(0xFF161616),
    sent: Color(0xFFD49C42),
    sentSoft: Color(0xFF2A2014),
    partial: Color(0xFF5994E8),
    partialSoft: Color(0xFF152038),
    warning: Color(0xFFE0A33E),
    warningSoft: Color(0xFF332918),
    shadow1: _darkShadow1,
    shadow2: _darkShadow2,
  );

  /// Back-compat aliases for the original two presets. New code should
  /// reference the named variants directly (or go through `LightVariant` /
  /// `DarkVariant`).
  static const InTheme light = lightSand;
  static const InTheme dark = darkCarbon;

  // Shadow lists are identical across same-brightness variants today, so
  // hoist them to avoid duplicating the constant literal six times.
  static const List<BoxShadow> _lightShadow1 = [
    BoxShadow(
      color: Color(0x0F14120C), // rgba(20,18,12,.06)
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
  ];
  static const List<BoxShadow> _lightShadow2 = [
    BoxShadow(
      color: Color(0x1414120C), // rgba(20,18,12,.08)
      offset: Offset(0, 4),
      blurRadius: 16,
    ),
    BoxShadow(
      color: Color(0x0A14120C), // rgba(20,18,12,.04)
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
  ];
  static const List<BoxShadow> _darkShadow1 = [
    BoxShadow(
      color: Color(0x4D000000), // rgba(0,0,0,.30)
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
  ];
  static const List<BoxShadow> _darkShadow2 = [
    BoxShadow(
      color: Color(0x66000000), // rgba(0,0,0,.40)
      offset: Offset(0, 4),
      blurRadius: 16,
    ),
    BoxShadow(
      color: Color(0x33000000), // rgba(0,0,0,.20)
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
  ];

  @override
  InTheme copyWith({
    Brightness? brightness,
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? borderStrong,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? ink4,
    Color? accent,
    Color? accentInk,
    Color? accentSoft,
    Color? accentLime,
    Color? rail,
    Color? railInk,
    Color? railInk2,
    Color? paid,
    Color? paidSoft,
    Color? overdue,
    Color? overdueSoft,
    Color? draft,
    Color? draftSoft,
    Color? sent,
    Color? sentSoft,
    Color? partial,
    Color? partialSoft,
    Color? warning,
    Color? warningSoft,
    List<BoxShadow>? shadow1,
    List<BoxShadow>? shadow2,
  }) {
    return InTheme(
      brightness: brightness ?? this.brightness,
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      ink4: ink4 ?? this.ink4,
      accent: accent ?? this.accent,
      accentInk: accentInk ?? this.accentInk,
      accentSoft: accentSoft ?? this.accentSoft,
      accentLime: accentLime ?? this.accentLime,
      rail: rail ?? this.rail,
      railInk: railInk ?? this.railInk,
      railInk2: railInk2 ?? this.railInk2,
      paid: paid ?? this.paid,
      paidSoft: paidSoft ?? this.paidSoft,
      overdue: overdue ?? this.overdue,
      overdueSoft: overdueSoft ?? this.overdueSoft,
      draft: draft ?? this.draft,
      draftSoft: draftSoft ?? this.draftSoft,
      sent: sent ?? this.sent,
      sentSoft: sentSoft ?? this.sentSoft,
      partial: partial ?? this.partial,
      partialSoft: partialSoft ?? this.partialSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      shadow1: shadow1 ?? this.shadow1,
      shadow2: shadow2 ?? this.shadow2,
    );
  }

  @override
  InTheme lerp(ThemeExtension<InTheme>? other, double t) {
    if (other is! InTheme) return this;
    return InTheme(
      // Brightness can't lerp — snap at the halfway point. In practice the
      // two sides of the transition share brightness (we only lerp within a
      // theme variant change), so this branch rarely matters.
      brightness: t < 0.5 ? brightness : other.brightness,
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      ink3: Color.lerp(ink3, other.ink3, t)!,
      ink4: Color.lerp(ink4, other.ink4, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentLime: Color.lerp(accentLime, other.accentLime, t)!,
      rail: Color.lerp(rail, other.rail, t)!,
      railInk: Color.lerp(railInk, other.railInk, t)!,
      railInk2: Color.lerp(railInk2, other.railInk2, t)!,
      paid: Color.lerp(paid, other.paid, t)!,
      paidSoft: Color.lerp(paidSoft, other.paidSoft, t)!,
      overdue: Color.lerp(overdue, other.overdue, t)!,
      overdueSoft: Color.lerp(overdueSoft, other.overdueSoft, t)!,
      draft: Color.lerp(draft, other.draft, t)!,
      draftSoft: Color.lerp(draftSoft, other.draftSoft, t)!,
      sent: Color.lerp(sent, other.sent, t)!,
      sentSoft: Color.lerp(sentSoft, other.sentSoft, t)!,
      partial: Color.lerp(partial, other.partial, t)!,
      partialSoft: Color.lerp(partialSoft, other.partialSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      // Shadows don't lerp cleanly when their list lengths match; we just
      // snap at the halfway point — the visual difference between light and
      // dark shadow alpha is subtle enough that this isn't noticeable.
      shadow1: t < 0.5 ? shadow1 : other.shadow1,
      shadow2: t < 0.5 ? shadow2 : other.shadow2,
    );
  }
}

/// Reads the brightness-appropriate tokens from the current [Theme].
extension InThemeContext on BuildContext {
  InTheme get inTheme => Theme.of(this).extension<InTheme>()!;
}

/// User-selectable light palette. Each value maps to a named [InTheme]
/// preset; the user's [CustomTheme] overrides (if any) layer on top via
/// [ThemeController.lightTokens]. Persisted to `nav_state.light_variant`.
enum LightVariant { sand, mist, paper }

/// User-selectable dark palette. See [LightVariant].
enum DarkVariant { espresso, midnight, carbon }

extension LightVariantTokens on LightVariant {
  InTheme get tokens => switch (this) {
    LightVariant.sand => InTheme.lightSand,
    LightVariant.mist => InTheme.lightMist,
    LightVariant.paper => InTheme.lightPaper,
  };
}

extension DarkVariantTokens on DarkVariant {
  InTheme get tokens => switch (this) {
    DarkVariant.espresso => InTheme.darkEspresso,
    DarkVariant.midnight => InTheme.darkMidnight,
    DarkVariant.carbon => InTheme.darkCarbon,
  };
}

/// The curated set of [InTheme] tokens a user can override on top of the
/// selected preset. Accent is intentionally **not** here — it stays the
/// existing per-user `accent_color` setting (applied through `buildInTheme`'s
/// `accentOverride:` so `accentSoft` / `accentInk` re-derive).
enum CustomToken { background, surface, ink, border }

/// First enum value in [values] whose `.name` equals [name], else null.
T? _byName<T extends Enum>(List<T> values, Object? name) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}

/// The user's per-brightness colour overrides. Each side holds a sparse map
/// of [CustomToken] → colour that layers on whatever preset is selected for
/// that side. Immutable app-config (not a freezed API/domain model);
/// persisted device-local as JSON in `nav_state.custom_theme_json`.
@immutable
class CustomTheme {
  const CustomTheme({
    this.lightOverrides = const {},
    this.darkOverrides = const {},
  });

  final Map<CustomToken, Color> lightOverrides;
  final Map<CustomToken, Color> darkOverrides;

  Map<CustomToken, Color> overridesFor(Brightness b) =>
      b == Brightness.dark ? darkOverrides : lightOverrides;

  /// [base] (the selected preset's tokens) with the [side] overrides applied.
  InTheme applyTo(InTheme base, Brightness side) {
    final ov = overridesFor(side);
    if (ov.isEmpty) return base;
    return base.copyWith(
      bg: ov[CustomToken.background],
      surface: ov[CustomToken.surface],
      ink: ov[CustomToken.ink],
      border: ov[CustomToken.border],
    );
  }

  CustomTheme copyWith({
    Map<CustomToken, Color>? lightOverrides,
    Map<CustomToken, Color>? darkOverrides,
  }) => CustomTheme(
    lightOverrides: lightOverrides ?? this.lightOverrides,
    darkOverrides: darkOverrides ?? this.darkOverrides,
  );

  /// Returns a copy with [token] on [side] set to [color].
  CustomTheme withOverride(Brightness side, CustomToken token, Color color) {
    final next = {...overridesFor(side), token: color};
    return side == Brightness.dark
        ? copyWith(darkOverrides: next)
        : copyWith(lightOverrides: next);
  }

  /// Returns a copy with [token] on [side] cleared (reverts to the preset).
  CustomTheme withoutOverride(Brightness side, CustomToken token) {
    final next = {...overridesFor(side)}..remove(token);
    return side == Brightness.dark
        ? copyWith(darkOverrides: next)
        : copyWith(lightOverrides: next);
  }

  static Map<String, dynamic> _encodeOverrides(Map<CustomToken, Color> ov) => {
    for (final e in ov.entries) e.key.name: formatHexColor(e.value),
  };

  static Map<CustomToken, Color> _decodeOverrides(Object? raw) {
    if (raw is! Map) return const {};
    final out = <CustomToken, Color>{};
    for (final e in raw.entries) {
      final token = _byName(CustomToken.values, e.key);
      final color = e.value is String ? parseHexColor(e.value as String) : null;
      if (token != null && color != null) out[token] = color;
    }
    return out;
  }

  /// Legacy blobs may carry `lightBase`/`darkBase`/an `accent` override key —
  /// [_decodeOverrides] silently drops unknown [CustomToken] names and the
  /// base keys are simply ignored, so old data degrades gracefully.
  String toJson() => jsonEncode({
    'light': _encodeOverrides(lightOverrides),
    'dark': _encodeOverrides(darkOverrides),
  });

  /// Tolerant decoder — a bad/legacy blob never breaks app start.
  factory CustomTheme.fromJson(String source) {
    try {
      final m = jsonDecode(source);
      if (m is! Map) return const CustomTheme();
      return CustomTheme(
        lightOverrides: _decodeOverrides(m['light']),
        darkOverrides: _decodeOverrides(m['dark']),
      );
    } catch (_) {
      return const CustomTheme();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is CustomTheme &&
      mapEquals(other.lightOverrides, lightOverrides) &&
      mapEquals(other.darkOverrides, darkOverrides);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(lightOverrides.entries.map((e) => e.key)),
    Object.hashAllUnordered(lightOverrides.values),
    Object.hashAllUnordered(darkOverrides.entries.map((e) => e.key)),
    Object.hashAllUnordered(darkOverrides.values),
  );
}

/// Default empty custom palette (no overrides — identical to the bare
/// presets).
const defaultCustomTheme = CustomTheme();

/// Brightness-independent dimensions — corner radii.
class InRadii {
  InRadii._();

  static const double r1 = 6;
  static const double r2 = 10;
  static const double r3 = 14;
  static const double r4 = 20;
}

/// Brightness-independent dimensions — interactive sizes.
class InSizes {
  InSizes._();

  /// Minimum interactive size on a touch pointer — the iOS HIG minimum, and
  /// already the app's button floor (`theme.dart`'s `Size.fromHeight(44)`, the
  /// "thumb-friendly" rows in `segment_menu.dart` / `filter_suggestion_menu.dart`).
  /// Material's Android figure is 48, but 44 keeps the sidebar's ~19 nav rows
  /// inside a phone viewport. Applied only when `Env.isTouchPrimary` — pointer
  /// platforms keep their denser metrics. See issue #11.
  static const double touchTarget = 44;
}

/// Brightness-independent dimensions — spacing scale.
///
/// `xs`, `sm`, `xl`, `xxl` are plain `static const` values for math
/// contexts (`kKanbanCardWidth`, gap calculations).
///
/// `md` and `lg` are **responsive** — they read [BuildContext] and
/// return different values above/below [Breakpoints.wide] (600 px):
///
/// | Token | narrow (<600) | wide (≥600) |
/// |-------|---------------|-------------|
/// | `md`  | 8 px          | 12 px       |
/// | `lg`  | 12 px         | 16 px       |
///
/// Wide values match the previous static constants, so desktop visuals
/// are unchanged. Narrow viewports breathe less — fewer wasted pixels
/// on phone-sized layouts. See **CLAUDE.md § Design system (v2)** for
/// the canonical card-padding rule.
///
/// Because `md` / `lg` now take a context they aren't compile-time
/// constants — drop `const` from any `EdgeInsets.all(InSpacing.lg(ctx))`
/// or `SizedBox(width: InSpacing.md(ctx))` literal that wraps them.
class InSpacing {
  InSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double xl = 24;
  static const double xxl = 32;

  /// Medium gap. 8 px narrow, 12 px wide.
  static double md(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 600 ? 12 : 8;

  /// Large gap. 12 px narrow, 16 px wide. The canonical card-interior
  /// padding (see CLAUDE.md § Design system v2).
  static double lg(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 600 ? 16 : 12;
}

/// Stable tint palette for initials avatars (clients, companies, contacts).
/// Brightness-independent — the same seed maps to the same colour in light
/// and dark mode so a given entity reads as the same identity across themes.
/// Pair with `avatarTintFor(seed)` in `lib/ui/core/widgets/avatar_tint.dart`.
class InAvatarPalette {
  InAvatarPalette._();

  static const List<Color> colors = <Color>[
    Color(0xFF1F8A5B), // jade
    Color(0xFF2A6FDB), // blue
    Color(0xFFB07A1F), // amber
    Color(0xFF7A3FB0), // purple
    Color(0xFFC0392B), // red
    Color(0xFF0E7C8C), // teal
    Color(0xFF3F8B2F), // forest
    Color(0xFFD04A7A), // magenta
  ];
}
