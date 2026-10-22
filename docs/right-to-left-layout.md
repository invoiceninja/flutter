# What breaks when the app is drawn right-to-left

Companion to CLAUDE.md § Localization. CLAUDE.md keeps the one rule; this doc
carries which locales flip, what Flutter mirrors without help, and the debt
that shipped with them.

## Arabic, Persian and Hebrew lay out right-to-left, so new layout code says start / end

**Arabic, Persian and Hebrew lay out right-to-left, so new layout code says start / end (`EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`), never left / right.** The three arrived in Oct 2026 with the other languages the server's `LanguageSeeder` offers (the app shipped 11 locales before that; React and admin-portal ship all of them). `GlobalWidgetsLocalizations` sets `Directionality` from the locale, so the whole tree flips with no code: a `Row` lays its children out from the right, `ListTile` leading/trailing swap, `TextAlign.start` follows, and an icon declared `matchTextDirection: true` (`Icons.arrow_back`, `Icons.chevron_right`) mirrors itself — never mirror one by hand. `test/l10n/supported_locales_test.dart` pins that exactly these three resolve to `TextDirection.rtl`.

What does **not** flip is anything that names a physical side. At the time the locales landed, `lib/` held 18 `EdgeInsets.only(left:`, 21 `EdgeInsets.only(right:`, 95 `EdgeInsets.fromLTRB` (many symmetric, so harmless), 111 `Alignment.centerLeft` / `centerRight`, 10 `topLeft` / `topRight` and 39 `Positioned(` — against ~170 directional call sites already. In an RTL locale each asymmetric one renders mirrored wrong: an indent on the outer edge, a label hugging the far side of its cell, a badge on the wrong corner. None of it crashes, and the app had never been drawn RTL, so there is no catalogue of which screens are affected. admin-portal shipped the same three languages with the same kind of debt. Two known-good references: `ScrollEdgeFades` and `EntityListStatusTabs._edgeFade` use `PositionedDirectional` + `AlignmentDirectional`; `EntityDetailTabs._edgeFade` uses plain `Positioned` + `Alignment` and is wrong in RTL (`docs/pane-width-and-overflow.md`).

The way to find the rest is to look: `tools/capture_ux_review.sh` with the app language set to Arabic (Settings → User Details → Preferences → App Language), screen by screen. A `Directionality(textDirection: TextDirection.ltr)` wrapper is right only for content that is LTR in every language — a number field, an IBAN, a code block — never as a way to make a layout bug go away.
