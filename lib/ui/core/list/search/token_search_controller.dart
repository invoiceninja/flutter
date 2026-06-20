import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/filter_chip_data.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_lexer.dart';
import 'package:admin/ui/core/list/search/filter_suggestion_controller.dart';
import 'package:admin/ui/core/list/search/filter_suggestion_menu.dart';
import 'package:admin/ui/core/list/search/filter_token.dart';

/// Coordinates the shared state between the wide-mode [TokenSearchField] and
/// the narrow-mode [FilterEntrySheet]: text controller, focus, suggestion
/// selection. Owns the disposable objects; both widgets create one of these
/// in `initState` and forward `dispose` here.
///
/// Mode-specific behaviour (overlay management, modal navigation) stays in
/// the widgets — the controller only knows about VM state, the filter-key
/// list, and the inputs the user is typing.
class TokenSearchController {
  TokenSearchController({
    required this.vm,
    required List<FilterKey> filterKeys,
    required String initialText,
  }) : _filterKeys = filterKeys {
    text = TextEditingController(text: initialText);
  }

  final GenericListViewModel<dynamic> vm;

  /// The set of [FilterKey]s the search field exposes. Mutable because the
  /// host widget may receive a fresh list as upstream state loads (e.g. a
  /// `StreamBuilder<Company?>` first emits `null`, then a real Company —
  /// the second build supplies `CustomFieldFilterKey` instances with the
  /// configured labels populated, where the first build had blanks). Hosts
  /// sync via the [filterKeys] setter from `didUpdateWidget`.
  List<FilterKey> _filterKeys;
  List<FilterKey> get filterKeys => _filterKeys;
  set filterKeys(List<FilterKey> next) {
    if (identical(_filterKeys, next)) return;
    _filterKeys = next;
    // Without this the cached parse holds a reference to a stale key —
    // typing the same input afterwards would still match the old key set
    // (e.g. miss a newly-available custom column).
    invalidateParse();
  }

  late final TextEditingController text;
  final FocusNode focus = FocusNode();
  final FilterSuggestionController suggestions = FilterSuggestionController();

  /// Text-independent value-mode override. Set when the user taps a
  /// `checkboxMultiSelect` chip to edit it: the value picker must open
  /// WITHOUT writing a `<key>:` prefix into the visible input (that stray
  /// prefix next to the chips was the reported bug). While set, [parseInput]
  /// reports value mode for this key and treats any bare input text as that
  /// key's value query. The pin is dropped only by an explicit `:` (handled
  /// in the field's `_onTextChange`) or [clearPinnedValueKey] — not by plain
  /// typing.
  FilterKey? _pinnedValueKey;
  FilterKey? get pinnedValueKey => _pinnedValueKey;

  /// Bumped whenever the pin is set or cleared. Setting `_pinnedValueKey`
  /// changes neither `text` nor the VM, so without this the host's
  /// `Listenable.merge([vm, text])` would never rebuild and the menu would
  /// stay in key mode. The wide field merges this; the sheet listens to it.
  final ValueNotifier<int> pinRevision = ValueNotifier<int>(0);

  void pinValueKey(FilterKey key) {
    _pinnedValueKey = key;
    invalidateParse();
    focus.requestFocus();
    pinRevision.value++;
  }

  void clearPinnedValueKey() {
    if (_pinnedValueKey == null) return;
    _pinnedValueKey = null;
    invalidateParse();
    pinRevision.value++;
  }

  /// Cached parse of [text.value]. Recomputed lazily so each rebuild reuses
  /// the same `FilterInputParse` instead of re-tokenising on every
  /// dependent (`onKey`, `overlayChildBuilder`, etc.).
  String _parseText = '';
  FilterInputParse? _parse;
  FilterInputParse parseInput() {
    // A pinned value key owns the menu — the typed text (if any) is that
    // key's VALUE query, not a new key/free-text parse. `_onTextChange`
    // drops the pin only when a `:` is typed (an explicit new `key:`),
    // so here a pinned key + bare text always means "filter this key's
    // values by <text>". Computed fresh, never cached: the pin identity
    // isn't captured by the text-keyed cache below.
    if (_pinnedValueKey != null) {
      return FilterInputParse(matchedKey: _pinnedValueKey, query: text.text);
    }
    if (_parse == null || _parseText != text.text) {
      _parseText = text.text;
      _parse = FilterInputParse.of(_parseText, filterKeys);
    }
    return _parse!;
  }

  /// Invalidate the cached parse. Call from text listeners when the input
  /// changes; the next [parseInput] re-tokenises.
  void invalidateParse() {
    _parse = null;
  }

  void dispose() {
    text.dispose();
    focus.dispose();
    suggestions.dispose();
    pinRevision.dispose();
  }

  // ── Selection helpers ─────────────────────────────────────────────────

  /// User picked a key from the menu — switch the input into value mode.
  /// Requests focus so the user can immediately type the value without an
  /// extra click; the menu row's GestureDetector tap doesn't preserve the
  /// TextField's focus on its own.
  ///
  /// Prefers the key's first alias over its canonical id when writing
  /// the prefix, so picking "Status" produces `status:` (user-friendly)
  /// rather than `is:` (Sentry-style canonical id). The parse in
  /// [FilterInputParse.of] still resolves either form back to the same
  /// key, so this is purely a presentation choice. Keys with no aliases
  /// fall back to the id unchanged.
  void selectKey(FilterKey key, {String? initialValueText}) {
    // A typed/picked key prefix owns the mode now — drop any pin so state
    // stays honest (text is non-empty here anyway, so the pin would be
    // ignored by `parseInput`).
    _pinnedValueKey = null;
    final prefix = key.aliases.isNotEmpty ? key.aliases.first : key.id;
    final next = initialValueText == null || initialValueText.isEmpty
        ? '$prefix:'
        : '$prefix:$initialValueText';
    // With an initial value, select it so the user can immediately retype
    // to replace, or arrow-key to deselect and refine. Without one, place
    // the caret after the colon to receive typed input.
    final selection = initialValueText == null || initialValueText.isEmpty
        ? TextSelection.collapsed(offset: next.length)
        : TextSelection(
            baseOffset: prefix.length + 1,
            extentOffset: next.length,
          );
    text.value = TextEditingValue(text: next, selection: selection);
    focus.requestFocus();
    // macOS echoes a select-all selection back through the IME after a
    // programmatic text.value write while focused, overriding the
    // selection we just set. Re-assert on the next frame, guarded so we
    // don't fight a user who has already typed or moved the caret.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!focus.hasFocus) return;
      if (text.text != next) return;
      if (text.selection == selection) return;
      text.selection = selection;
    });
  }

  /// Apply or unapply a value for [key]. Toggles based on whether the
  /// raw value is already in the live applied set. The optional
  /// [beforeAwait] callback fires synchronously before the addValue/
  /// removeValue future — wide mode uses it to clear the input and hide
  /// the overlay so the menu doesn't flicker through its post-click state
  /// during the network roundtrip.
  ///
  /// Also clears `vm.search` if non-empty. Cross-key value matches surface
  /// values by typing free text (e.g. `act` → `Status  Active`), and the
  /// search-as-you-type pipe writes `vm.search = "act"` per keystroke;
  /// without this clear the chip and the stale search both filter the
  /// list and the user sees zero matches. Other entry paths into
  /// `selectValue` go through the colon-pivot in `_onTextChange` first,
  /// which has already emptied `vm.search` — so this is a no-op there.
  Future<void> selectValue(
    FilterKey key,
    FilterValueSuggestion value,
    BuildContext context, {
    VoidCallback? beforeAwait,
  }) async {
    final isApplied = key
        .tokensFrom(vm, context)
        .any((t) => t.rawValue == value.rawValue);
    beforeAwait?.call();
    if (vm.search.isNotEmpty) {
      vm.setSearch('');
    }
    if (isApplied) {
      await key.removeValue(vm, value.rawValue);
    } else {
      await key.addValue(vm, value.rawValue);
    }
  }

  /// Sticky toggle for the [FilterKey.checkboxMultiSelect] split action's
  /// checkbox half. Same applied-check + add/remove as [selectValue] but
  /// deliberately takes **no** `beforeAwait` — the caller must NOT clear
  /// the input or hide the overlay, so the menu stays open while the user
  /// builds a multi-selection. The parent `ListenableBuilder` rebuilds the
  /// open menu with the updated checkbox state on the VM notify.
  Future<void> toggleValueSticky(
    FilterKey key,
    FilterValueSuggestion value,
    BuildContext context,
  ) async {
    final isApplied = key
        .tokensFrom(vm, context)
        .any((t) => t.rawValue == value.rawValue);
    if (vm.search.isNotEmpty) {
      vm.setSearch('');
    }
    if (isApplied) {
      await key.removeValue(vm, value.rawValue);
    } else {
      await key.addValue(vm, value.rawValue);
    }
  }

  /// Exclusive select for the split action's row-label half: replace the
  /// key's whole applied set with [value] and let the caller close the
  /// menu via [beforeAwait] (mirrors [selectValue]'s dismiss-before-await
  /// ordering — see that method for the flicker rationale).
  Future<void> selectValueExclusive(
    FilterKey key,
    FilterValueSuggestion value,
    BuildContext context, {
    VoidCallback? beforeAwait,
  }) async {
    beforeAwait?.call();
    if (vm.search.isNotEmpty) {
      vm.setSearch('');
    }
    await key.selectExclusive(vm, context, value.rawValue);
  }

  /// Commit the input as a free-text search query.
  ///
  /// With search-as-you-type (`TokenSearchField._onTextChange` keeps
  /// `vm.search` in sync per keystroke) this call is idempotent for the
  /// search side. It exists so the Enter handler on the "Search for X"
  /// row has a single dispatch point.
  ///
  /// We deliberately DON'T clear `text` here. The input IS the live
  /// query under search-as-you-type, and clearing would fire
  /// `_onTextChange` with empty text — which then pushes empty back into
  /// `vm.search` and wipes the filter the user just submitted.
  ///
  /// Applies immediately (`immediate: true`) rather than through the
  /// search-as-you-type debounce: this is an explicit "show me the results"
  /// commit, and the narrow-mode sheet (which has no live search at all)
  /// pops straight back to the list right after, so the term must already
  /// be applied by then.
  void commitFreeText(String value) {
    vm.setSearch(value, immediate: true);
  }

  /// Remove [token] from the VM's applied filters.
  Future<void> removeToken(FilterToken token) async {
    final key = keyById(token.keyId);
    if (key == null) return;
    await key.removeValue(vm, token.rawValue);
  }

  /// Applied chips across every key, in [filterKeys] order. Builds on
  /// [activeTokens] but collapses a `checkboxMultiSelect` key that has more
  /// than one applied value into a single aggregate chip — so picking 3
  /// statuses reads as one `status draft, paid, sent` chip, not three.
  /// Every other key keeps one chip per value (byte-for-byte today's
  /// behavior).
  List<ActiveFilterChip> activeChips(BuildContext context) {
    final out = <ActiveFilterChip>[];
    for (final k in filterKeys) {
      final tokens = k.tokensFrom(vm, context).toList();
      if (tokens.isEmpty) continue;
      if (k.checkboxMultiSelect && tokens.length > 1) {
        final first = tokens.first;
        // Sort the member labels for a deterministic chip string (the
        // set-backed keys yield in unspecified order).
        final values = [for (final t in tokens) t.displayValue]..sort();
        out.add(
          ActiveFilterChip(
            key: k,
            token: FilterToken(
              keyId: first.keyId,
              displayKey: first.displayKey,
              rawValue: '',
              displayValue: values.join(', '),
            ),
            rawValues: [for (final t in tokens) t.rawValue],
            aggregate: true,
          ),
        );
      } else {
        for (final t in tokens) {
          out.add(
            ActiveFilterChip(
              key: k,
              token: t,
              rawValues: [t.rawValue],
              aggregate: false,
            ),
          );
        }
      }
    }
    return out;
  }

  /// Remove a whole chip. Non-aggregate → drop its single value (same as
  /// [removeToken]); aggregate → clear the key's whole set in one VM write
  /// via [FilterKey.clear].
  Future<void> removeChip(ActiveFilterChip chip, BuildContext context) {
    if (chip.aggregate) return chip.key.clear(vm, context);
    return chip.key.removeValue(vm, chip.rawValues.single);
  }

  /// Look up a [FilterKey] by id. Returns null when the id isn't known —
  /// the caller is expected to no-op rather than throw, since stale
  /// VM-state could carry a key that has since been removed.
  FilterKey? keyById(String keyId) {
    for (final k in filterKeys) {
      if (k.id == keyId) return k;
    }
    return null;
  }

  /// Currently-applied tokens across every filter key, in [filterKeys]
  /// order. Recomputed on every read — cheap, since each key already
  /// memoises its own slice.
  List<FilterToken> activeTokens(BuildContext context) {
    final out = <FilterToken>[];
    for (final k in filterKeys) {
      out.addAll(k.tokensFrom(vm, context));
    }
    return out;
  }

  // ── Keyboard handling ─────────────────────────────────────────────────

  /// Shared arrow / Enter / backspace handling. Returns
  /// [KeyEventResult.handled] when the event was consumed, ignored
  /// otherwise. Mode-specific keys (Escape in wide mode, free-text commit
  /// fall-through) are layered on top by the widget.
  ///
  /// [suggestionsActive] controls whether arrow keys / Enter on a
  /// highlighted row are intercepted. Wide mode passes
  /// `overlayController.isShowing`; narrow mode passes `true` (the menu is
  /// always visible inside the sheet).
  KeyEventResult handleArrowEnterBackspace(
    KeyEvent event, {
    required bool suggestionsActive,
    required BuildContext context,
  }) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (suggestionsActive) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        suggestions.moveDown();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        suggestions.moveUp();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        if (suggestions.commit()) return KeyEventResult.handled;
        // Fall through — caller may want to commit free text.
      }
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace && text.text.isEmpty) {
      // With a pinned (prefix-free) value picker open, Backspace means
      // "back to the filter list", not "delete the last chip" — there's no
      // `<key>:` string to edit any more.
      if (_pinnedValueKey != null) {
        clearPinnedValueKey();
        return KeyEventResult.handled;
      }
      final tokens = activeTokens(context);
      if (tokens.isNotEmpty) {
        final removed = tokens.last;
        // Announce the removal so screen-reader users hear which chip
        // popped — the visual disappearance alone has no a11y signal.
        SemanticsService.sendAnnouncement(
          View.of(context),
          '${removed.displayKey} ${removed.displayValue} removed',
          Directionality.of(context),
        );
        unawaited(removeToken(removed));
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  // ── Paste ────────────────────────────────────────────────────────────

  /// Reads the clipboard and, when it parses as `<key>:<value>` tokens,
  /// applies them and returns true. Free text inside the paste is applied
  /// to the VM's search field. Returns false when the paste should fall
  /// through to a native text paste.
  Future<bool> handlePaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final input = data?.text;
    if (input == null || !input.contains(':')) return false;
    final lex = lexFilterInput(input, filterKeys);
    if (lex.tokens.isEmpty) return false;
    for (final t in lex.tokens) {
      final key = keyById(t.keyId);
      if (key != null) {
        await key.addValue(vm, t.rawValue);
      }
    }
    if (lex.freeText.isNotEmpty) vm.setSearch(lex.freeText);
    text.clear();
    focus.requestFocus();
    return true;
  }
}
