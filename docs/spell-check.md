# Spell check

Companion to CLAUDE.md § Forms. The rule lives there. This doc covers the platform matrix, the seam
in `lib/ui/core/widgets/spell_check.dart`, the two runner channels, and the Flutter behaviour that
decides what gets underlined and when.

User feedback asked for "Spell check: underline incorrect grammar in the item name & description."
A line item's **name** (`product_key`) and **description** (`notes`) are now checked in both
line-item editors: the wide table (`line_item_table_desktop.dart`) and the phone dialog
(`line_item_edit_dialog.dart`). Custom-field cells are not, because they hold serials and codes.
Device Settings → **Spell Check** switches it off (`DevicePrefKeys.spellCheck`, device scope,
default on). The switch is there because item names are often SKUs that every checker flags.

## Spell check goes through `LineItemSpellCheck` — a raw `SpellCheckConfiguration()` on a platform with no service throws in debug and draws nothing, and one held from the first build never checks the saved text

Flutter's `EditableText._inferSpellCheckConfiguration` turns a configuration with no service into
`DefaultSpellCheckService` only when `platformDispatcher.nativeSpellCheckServiceDefined` is true.
That is only the case on iOS and Android. Anywhere else, including every `flutter test` run, it
reports a `FlutterError` ("Spell check was enabled with spellCheckConfiguration, but the current
platform does not have a supported spell check service") and disables checking.
`lineItemSpellCheck(context)` returns null (Flutter's "off") in each of these cases:

- `SpellCheckController` is absent (a widget test) or switched off.
- The platform is Linux or web.
- iOS / Android, but the engine reports no service.
- macOS / Windows, but the runner has said it can't check (`NativeSpellCheckService.isUnavailable`,
  latched for the session on a `MissingPluginException` or the error code `unavailable`).

Fields don't call `lineItemSpellCheck` directly. They are built inside
`LineItemSpellCheck(builder: (context, config) => TextField(spellCheckConfiguration: config, …))`,
which hands the configuration over **one frame after mount**. `EditableText` runs a check only when
its configuration changes (`didUpdateWidget`) or the user types (`_formatAndSetValue`), never in
`initState`. A field holding the configuration from its first build would leave every saved
description un-underlined until someone edited it. This shipped in the first cut and was caught by
`line_item_spell_check_test.dart`, whose right-click test asserts results exist before any edit.

Pair it with `contextMenuBuilder: spellCheckContextMenuBuilder`. That is exactly the default menu,
except on macOS / Windows when the caret is on a flagged word, where up to three suggestions lead.
Flutter only shows its suggestions toolbar for a tap on iOS / Android, so without this an
underline on the desktop would have no fix.

| Platform | Service | Checks | Fix |
|---|---|---|---|
| iOS | Flutter's `DefaultSpellCheckService` (UITextChecker) | spelling | tap → Cupertino toolbar |
| Android | Flutter's `DefaultSpellCheckService` (SpellCheckerSession) | spelling | tap → Material toolbar |
| macOS | `NinjaSpellChecker` in `macos/Runner/MainFlutterWindow.swift` (NSSpellChecker) | spelling + grammar | right-click |
| Windows | `SpellChecker` in `windows/runner/spell_checker.cpp` (ISpellChecker, Windows 8+) | spelling | right-click |
| Linux, web | none | — | — |

Web draws the text itself, so the browser's own underline can never show. Linux would need
enchant / hunspell in the runner, which isn't worth it yet.

`super_editor_spellcheck` (in the super_editor monorepo) was ruled out. It needs super_editor
`^0.3.0-dev.38`, and the pin is `0.3.0-dev.10`. It is also a SuperEditor plugin, and these fields are
plain `TextField`s. Document notes / terms (SuperEditor) would need it after a super_editor bump.

## The runner channel is `invoice_ninja/spell_check`, and its offsets are UTF-16

`check {text, language}` replies `[{start, end, suggestions}]`. `language` is the field's locale as
a BCP-47 tag.

- **macOS:** maps the tag to the checker's own name (`en-GB` → `en_GB`, else the bare `en`) and
  passes it as the orthography. With no match it passes nothing, so the checker identifies the
  language itself. It uses the asynchronous `requestChecking`, the API built for off-main-thread
  checking, and does the rest (`guesses` included) back on the main queue.
- **Windows:** tries the tag, then the base language, then `en-US`. It replies `unavailable` when
  there is no factory or no dictionary at all. COM is apartment-threaded (`main.cpp`), so it checks
  synchronously on the platform thread.

`NSString`, ISpellChecker and a Dart string all index in UTF-16 code units, so offsets pass through
unconverted. `parseSpellCheckSpans` still drops anything out of bounds, sorts, and drops a span that
overlaps one kept before it. `EditableText` walks the spans in order and would print an overlapped
stretch twice. macOS does produce overlaps: a grammar phrase and a misspelling inside it are two
results.

A macOS grammar detail's `NSGrammarRange` is read as relative to its result's range (WebKit's
reading). If it fits only as absolute it is kept as given, and if it fits neither reading the whole
phrase is underlined. Grammar and spelling share one underline: Flutter's `SuggestionSpan` has no
kind.

## The service is one instance, or every rebuild re-checks

`EditableText.didUpdateWidget` re-infers the configuration, and runs a fresh check, whenever
`oldWidget.spellCheckConfiguration != widget.spellCheckConfiguration`.
`SpellCheckConfiguration.==` compares the service, and a line-item row rebuilds on every keystroke.
So `desktopSpellCheckService` is a top-level `final`, and the mobile configuration is
`const SpellCheckConfiguration()`. The same comparison is what makes the switch work: flipping it
turns null into a configuration or back, which re-runs or clears the check.

## What Flutter checks, and when

- **A check runs when the configuration arrives** (one frame after mount, through
  `LineItemSpellCheck`), **and on each user edit** (`_formatAndSetValue`). A programmatic controller
  write does not trigger one. A
  description filled in from a picked product (`line_item_table_desktop.dart`,
  `this.notes.text = notes`) stays un-underlined until the user types in it. That is accepted:
  catalog text is curated. Don't re-key the field to force a check, because that drops focus and
  the caret.
- **Unfocused fields keep their underlines,** so a 100-line invoice is checked at mount, two
  requests per row. The word under the caret is never underlined while typing (Flutter's
  `cursorInCurrentSpan`).
- **Mobile's `DefaultSpellCheckService` answers null to a request that overlaps one in flight.**
  The phone dialog's two fields mount together, so one initial result can be lost. The next
  keystroke recovers it.
- **The locale is the app's UI locale** (`Localizations.maybeLocaleOf`), not the client's
  language. A German description under an English UI is checked as English, except where macOS
  identifies the language itself.

Tests: `test/ui/core/widgets/spell_check_test.dart` (seam, parse, platform matrix, switch) and
`test/ui/features/billing_shared/line_item_spell_check_test.dart` (which fields, the switch, the
right-click fix).

Not done yet: "Learn spelling" / "Ignore" in the menu (NSSpellChecker `learnWord`, ISpellChecker
`Add`), the obvious next step for SKUs.
