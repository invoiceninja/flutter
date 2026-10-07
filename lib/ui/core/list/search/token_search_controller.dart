import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/custom_field_filter_key.dart';
import 'package:admin/ui/core/list/search/filter_chip_data.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_lexer.dart';
import 'package:admin/ui/core/list/search/filter_suggestion_controller.dart';
import 'package:admin/ui/core/list/search/filter_suggestion_menu.dart';
import 'package:admin/ui/core/list/search/filter_token.dart';

/// What [TokenSearchController.pickKey] did with the key the user chose.
enum KeyPick {
  /// The key has one possible value and it was applied outright; there is
  /// no picker to show.
  applied,

  /// The key's value picker opened through the pin (nothing written into the
  /// box).
  pinned,

  /// The key's `<key>:` prefix was written into the box for a typed value.
  prefixed,
}

/// What [TokenSearchController.commitTyped] did with the text in the box.
enum TypedCommit {
  /// Nothing to commit — the box is empty.
  none,

  /// The text was a `<key>:<value>` the key refused (a half-typed
  /// `balance:>`, a date that is not a date, text that matches no row of a
  /// pick-only key). The host keeps the input and the menu so the user can
  /// finish it.
  rejected,

  /// A filter value was applied; the host clears the box.
  applied,

  /// The text was committed as a free-text search; the host keeps it.
  searched,
}

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

  /// The keys a TYPED or pasted `<prefix>:` may resolve to: what the picker
  /// would offer, i.e. available and not locked by an embedding parent.
  ///
  /// Matching against every registered key reached two kinds it must not. A
  /// key the picker hides — an unconfigured custom column, whose `tokensFrom`
  /// renders no chip — applied a filter nobody could see. And a **locked** key
  /// on an embedded list (`client:` on a client's own Invoices tab) added a
  /// second client next to the parent scope and emptied the list.
  ///
  /// Not the picker's own list: [availableKeyPickerKeys] also drops an applied
  /// single-value key (there is nothing more to add from the menu), but typing
  /// `name:` again is how that one is replaced.
  List<FilterKey> get typeableKeys => [
    for (final k in _filterKeys)
      if (k.isAvailable(vm) && !vm.lockedFilterKeyIds.contains(k.id)) k,
  ];

  late final TextEditingController text;
  final FocusNode focus = FocusNode();
  final FilterSuggestionController suggestions = FilterSuggestionController();

  /// Text-independent value-mode override. Set when a value picker must open
  /// WITHOUT writing a `<key>:` prefix into the visible input (that stray
  /// prefix next to the chips was a reported bug, and for a pick-only key it
  /// is a raw English id in every locale). While set, [parseInput] reports
  /// value mode for this key and treats any bare input text as that key's
  /// value query. The pin is dropped only by an explicit `<key>:` (handled in
  /// the host's text listener) or [clearPinnedValueKey] — not by plain typing.
  FilterKey? _pinnedValueKey;
  FilterKey? get pinnedValueKey => _pinnedValueKey;

  /// Bumped whenever the pin, the chip being edited or the armed chip
  /// changes. None of those touch `text` or the VM, so without this the
  /// host's `Listenable.merge([vm, text])` would never rebuild and the menu
  /// would stay in key mode. The wide field merges this; the sheet listens.
  final ValueNotifier<int> pinRevision = ValueNotifier<int>(0);

  /// True when [key]'s value picker opens through the pin rather than a typed
  /// `<key>:` prefix: every key whose values are PICKED (there is nothing to
  /// type, so the prefix is noise), plus custom fields, whose prefix would be
  /// the raw `custom1:` instead of the label the company configured.
  ///
  /// One predicate for both hosts. They used to carry a copy each and had
  /// already drifted — wide pinned custom fields, the sheet did not.
  bool opensViaPin(FilterKey key) =>
      !key.acceptsTypedValue || key is CustomFieldFilterKey;

  void pinValueKey(FilterKey key) {
    _pinnedValueKey = key;
    invalidateParse();
    focus.requestFocus();
    pinRevision.value++;
  }

  void clearPinnedValueKey() {
    if (_pinnedValueKey == null && _editing == null) return;
    _pinnedValueKey = null;
    _editing = null;
    invalidateParse();
    pinRevision.value++;
  }

  /// Drop whatever was typed to narrow [key]'s value list and show the whole
  /// list again, keeping that picker open — after a tick made from the
  /// keyboard, so the next value does not need the last one's query erased
  /// first. A typed `status:pa` becomes the pinned Status picker with an empty
  /// box.
  void resetValueQuery(FilterKey key) {
    if (text.text.isEmpty) return;
    if (!identical(_pinnedValueKey, key)) {
      _pinnedValueKey = key;
      invalidateParse();
      pinRevision.value++;
    }
    text.clear();
  }

  /// Empty the box as part of starting a filter, and withdraw the search
  /// that text was applying.
  ///
  /// The search is cleared HERE rather than left to a host's text listener,
  /// which only writes the search for a focused field — and a click on a menu
  /// row or a chip has already taken focus off the input by the time its
  /// handler runs (on desktop a text field unfocuses on any tap outside
  /// itself).
  void dropBoxText() {
    if (text.text.isNotEmpty) text.clear();
    vm.setSearch('');
  }

  /// The user picked [key] from the filter list. **One implementation for
  /// both hosts** — the wide field and the phone sheet each carried a copy of
  /// this, of [editChip] and of [pickOp], and they had drifted three times
  /// (custom fields pinned in one and not the other; `directApplyValue`
  /// honoured in one and not the other; the box text dropped in one and not
  /// the other). The hosts keep only what is theirs: anchors, the overlay,
  /// navigation.
  KeyPick pickKey(FilterKey key) {
    // A key with one possible value (Overdue) applies it outright — a
    // one-row picker is pure friction.
    final direct = key.directApplyValue;
    if (direct != null) {
      dropBoxText();
      unawaited(key.addValue(vm, direct));
      return KeyPick.applied;
    }
    // Pick-only keys and custom fields open their value picker via the pin —
    // NO `<id>:` prefix written into the input. Whatever was typed to FIND
    // the key (`sta` → Status) must not become the value query — it matches
    // no status and read as "No matches" — nor stay behind as the search it
    // was live-applying.
    if (opensViaPin(key)) {
      dropBoxText();
      pinValueKey(key);
      return KeyPick.pinned;
    }
    // Every other key gets its typed prefix so the user can type a value
    // (`name:`, `balance:>`).
    selectKey(key);
    return KeyPick.prefixed;
  }

  /// The user tapped [chip]'s body — open the editor for it. **The value
  /// stays applied**: the tap used to remove a multi-value key's chip first
  /// and then open the picker, so Escape (or a click away) deleted the
  /// filter. Only ✕ removes. Returns true when the picker opened through the
  /// pin, so a host that anchors its menu can hang it under the chip.
  bool editChip(ActiveFilterChip chip) {
    final key = chip.key;
    if (opensViaPin(key)) {
      // Whatever is in the box is not this key's value query.
      dropBoxText();
      pinValueKey(key);
      // A single-pick list edits THIS chip: the next pick replaces its value
      // (see [selectValue]). Multi-select and custom-field lists manage their
      // whole set with ticks instead, and an aggregate chip has no single
      // value to replace.
      if (!chip.aggregate &&
          !key.checkboxMultiSelect &&
          key is! CustomFieldFilterKey) {
        beginEdit(key, chip.rawValues.single);
      }
      return true;
    }
    final raw = chip.rawValues.single;
    if (!key.singleValue) beginEdit(key, raw);
    // Prefilled with whatever the key says is typeable for this value —
    // nothing, for one it declines (a rolling date, an opaque id).
    selectKey(key, initialValueText: key.editableValueText(raw));
    return false;
  }

  /// Operator picked before a value was typed. Write `<key>:<symbol>` to
  /// the input so the user can keep typing the value; the chip is
  /// committed on Enter (or when the user re-clicks an op row with the
  /// value present). The symbol form is what
  /// [ComparableFilterKey.parseWire] normalises back to the canonical
  /// wire `op:value`.
  void pickOp(FilterKey key, FilterOp op) {
    final next = '${typedPrefixOf(key)}:${filterOpSymbol(op)}';
    final selection = TextSelection.collapsed(offset: next.length);
    text.value = TextEditingValue(text: next, selection: selection);
    focus.requestFocus();
    // See [selectKey] for the macOS-echo rationale.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !focus.hasFocus) return;
      if (text.text != next) return;
      if (text.selection == selection) return;
      text.selection = selection;
    });
  }

  // ── Chip being edited ────────────────────────────────────────────────

  ({FilterKey key, String raw})? _editing;

  /// The applied value a chip tap opened for editing, if any. It STAYS applied
  /// until the user commits a replacement ([selectValue] / [commitTyped] swap
  /// it through [FilterKey.replaceValue]), so cancelling the edit changes
  /// nothing. The previous flow removed the value before opening the editor:
  /// a tap on a chip's body followed by Escape deleted the filter, which the
  /// chip's own contract ("the body opens the editor, only ✕ removes") forbids.
  String? editingValueOf(FilterKey key) =>
      identical(_editing?.key, key) ? _editing!.raw : null;

  void beginEdit(FilterKey key, String raw) {
    _editing = (key: key, raw: raw);
  }

  String? _takeEdit(FilterKey key) {
    final raw = editingValueOf(key);
    _editing = null;
    return raw;
  }

  // ── Armed chip (Backspace) ───────────────────────────────────────────

  bool _lastChipArmed = false;

  /// True after one Backspace on an empty input: the last chip is highlighted
  /// and the NEXT Backspace removes it. One press used to delete outright,
  /// which a user clearing their typed text with repeated taps overshot into.
  bool get lastChipArmed => _lastChipArmed;

  void disarmLastChip() {
    if (!_lastChipArmed) return;
    _lastChipArmed = false;
    pinRevision.value++;
  }

  /// Cached parse of [text.value]. Recomputed lazily so each rebuild reuses
  /// the same `FilterInputParse` instead of re-tokenising on every
  /// dependent (`onKey`, `overlayChildBuilder`, etc.).
  String _parseText = '';
  FilterInputParse? _parse;

  /// The current input as key + value query, **pin-aware**: a pinned key owns
  /// the menu, and any text is that key's value query. `matchedKey != null` is
  /// the one definition of "the user is building a filter" — every host
  /// decision that used to ask `text.contains(':')` asks this instead. That
  /// test was wrong in both directions: `INV:001` contains a colon and is a
  /// search, and text typed into a pinned picker contains none and is not.
  FilterInputParse parseInput() {
    // Computed fresh, never cached: the pin identity isn't captured by the
    // text-keyed cache below.
    if (_pinnedValueKey != null) {
      return FilterInputParse(matchedKey: _pinnedValueKey, query: text.text);
    }
    if (_parse == null || _parseText != text.text) {
      _parseText = text.text;
      _parse = FilterInputParse.of(_parseText, typeableKeys);
    }
    return _parse!;
  }

  /// The key an explicit `<prefix>:` in the text names, ignoring the pin —
  /// how a host notices the user typing a NEW key while a picker is pinned.
  FilterKey? typedPrefixKey() =>
      FilterInputParse.of(text.text, typeableKeys).matchedKey;

  /// Invalidate the cached parse. Call from text listeners when the input
  /// changes; the next [parseInput] re-tokenises.
  void invalidateParse() {
    _parse = null;
  }

  /// Identifies the input the menu's rows were built for — see
  /// [FilterSuggestionController.commit]. The pin is part of it: the same
  /// text means different rows under a different key.
  Object get inputStamp => '${_pinnedValueKey?.id ?? ''}\u0000${text.text}';

  bool _disposed = false;

  void dispose() {
    _disposed = true;
    text.dispose();
    focus.dispose();
    suggestions.dispose();
    pinRevision.dispose();
  }

  // ── Selection helpers ─────────────────────────────────────────────────

  /// User picked a typed-value key — switch the input into value mode by
  /// writing its `<key>:` prefix. Requests focus so the user can immediately
  /// type the value without an extra click; the menu row's GestureDetector tap
  /// doesn't preserve the TextField's focus on its own.
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
    final prefix = typedPrefixOf(key);
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
  /// When [key]'s chip is being edited ([editingValueOf]) the pick REPLACES
  /// that value instead of toggling: picking another value swaps it in, and
  /// picking the one already on the chip changes nothing.
  ///
  /// Also clears the search. Cross-key value matches surface values by typing
  /// free text (e.g. `act` → `Status  Active`), and the search-as-you-type
  /// pipe writes `vm.search = "act"` per keystroke; without this clear the
  /// chip and the stale search both filter the list and the user sees zero
  /// matches. Unconditional rather than guarded on `vm.search.isNotEmpty`:
  /// a term still inside its debounce is not `vm.search` yet, and `setSearch`
  /// is what withdraws it.
  Future<void> selectValue(
    FilterKey key,
    FilterValueSuggestion value,
    BuildContext context, {
    VoidCallback? beforeAwait,
  }) async {
    final isApplied = key
        .tokensFrom(vm, context)
        .any((t) => t.rawValue == value.rawValue);
    // Read before [beforeAwait]: the wide host's dismissal clears the edit.
    final editing = _takeEdit(key);
    beforeAwait?.call();
    vm.setSearch('');
    if (editing != null) {
      if (editing == value.rawValue) return;
      if (key.singleValue) {
        // One slot: the write is the replacement.
        await key.addValue(vm, value.rawValue);
      } else if (isApplied) {
        // Swapping onto a value that is already applied: the edited one goes.
        await key.removeValue(vm, editing);
      } else {
        await key.replaceValue(vm, editing, value.rawValue);
      }
      return;
    }
    if (isApplied) {
      await key.removeValue(vm, value.rawValue);
    } else {
      await key.addValue(vm, value.rawValue);
    }
  }

  /// Sticky toggle for a [FilterKey.checkboxMultiSelect] row. Same
  /// applied-check + add/remove as [selectValue] but deliberately takes
  /// **no** `beforeAwait` — the caller must NOT hide the menu, so it stays
  /// open while the user builds a multi-selection. The parent
  /// `ListenableBuilder` rebuilds the open menu with the updated checkbox
  /// state on the VM notify.
  Future<void> toggleValueSticky(
    FilterKey key,
    FilterValueSuggestion value,
    BuildContext context,
  ) async {
    final isApplied = key
        .tokensFrom(vm, context)
        .any((t) => t.rawValue == value.rawValue);
    vm.setSearch('');
    if (isApplied) {
      await key.removeValue(vm, value.rawValue);
    } else {
      await key.addValue(vm, value.rawValue);
    }
  }

  /// Exclusive select — the "Only" half of a multi-select row: replace the
  /// key's whole applied set with [value] and let the caller close the
  /// menu via [beforeAwait] (mirrors [selectValue]'s dismiss-before-await
  /// ordering — see that method for the flicker rationale).
  Future<void> selectValueExclusive(
    FilterKey key,
    FilterValueSuggestion value,
    BuildContext context, {
    VoidCallback? beforeAwait,
  }) async {
    _takeEdit(key);
    beforeAwait?.call();
    vm.setSearch('');
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

  /// Commit whatever is typed in the box — the Enter path once no menu row
  /// took the key. **One implementation for both hosts**: the sheet had none,
  /// so `name:acme` + Search there searched for the literal text `name:acme`.
  ///
  /// * `<key>:<value>` → the key normalizes the value
  ///   ([FilterKey.normalizeTypedValue]) and applies it, or the commit is
  ///   [TypedCommit.rejected]: a pick-only key never takes typed text
  ///   ([FilterKey.acceptsTypedValue]) and a typed key may refuse a
  ///   half-typed one.
  /// * anything else → a free-text search, applied immediately.
  ///
  /// [beforeApply] runs synchronously just before a filter value is written
  /// (the wide host clears the box and hides its menu there, so the menu
  /// doesn't re-render through the reload).
  TypedCommit commitTyped(BuildContext context, {VoidCallback? beforeApply}) {
    final input = text.text.trim();
    final parse = parseInput();
    final key = parse.matchedKey;
    if (key == null) {
      if (input.isEmpty) return TypedCommit.none;
      commitFreeText(input);
      return TypedCommit.searched;
    }
    final typed = parse.query.trim();
    // A bare `<key>:` (or an empty pinned query): nothing to commit, and not
    // a search either — keep the picker.
    if (typed.isEmpty) return TypedCommit.rejected;
    if (!key.acceptsTypedValue) return TypedCommit.rejected;
    final raw = key.normalizeTypedValue(vm, context, typed);
    if (raw == null) return TypedCommit.rejected;
    final editing = _takeEdit(key);
    beforeApply?.call();
    vm.setSearch('');
    if (editing != null && !key.singleValue) {
      unawaited(key.replaceValue(vm, editing, raw));
    } else {
      unawaited(key.addValue(vm, raw));
    }
    return TypedCommit.applied;
  }

  /// Remove [token] from the VM's applied filters.
  Future<void> removeToken(FilterToken token) async {
    final key = keyById(token.keyId);
    if (key == null) return;
    await key.removeValue(vm, token.rawValue);
  }

  /// How many values an aggregate chip names before it says `+N`. Three
  /// statuses used to render as one chip three labels wide, which is what
  /// pushed the input onto a second line in the first place.
  static const int kAggregateChipValues = 2;

  /// Applied chips across every key, in [filterKeys] order. Builds on
  /// [activeTokens] but collapses a `checkboxMultiSelect` key that has more
  /// than one applied value into a single aggregate chip — so picking 3
  /// statuses reads as one `Status Draft, Paid +1` chip, not three.
  /// Every other key keeps one chip per value. A key at its default
  /// contributes nothing at all — see [_isAtDefaultForChips].
  List<ActiveFilterChip> activeChips(BuildContext context) {
    final out = <ActiveFilterChip>[];
    for (final k in filterKeys) {
      if (_isAtDefaultForChips(k)) continue;
      final tokens = k.tokensFrom(vm, context).toList();
      if (tokens.isEmpty) continue;
      if (k.checkboxMultiSelect && tokens.length > 1) {
        final first = tokens.first;
        // Sort the member labels for a deterministic chip string (the
        // set-backed keys yield in unspecified order).
        final values = [for (final t in tokens) t.displayValue]..sort();
        final shown = values.take(kAggregateChipValues).join(', ');
        final hidden = values.length - kAggregateChipValues;
        out.add(
          ActiveFilterChip(
            key: k,
            token: FilterToken(
              keyId: first.keyId,
              displayKey: first.displayKey,
              rawValue: '',
              displayValue: hidden > 0 ? '$shown +$hidden' : shown,
              // The full list is one hover away when the chip abbreviates.
              valueTooltip: hidden > 0 ? values.join(', ') : null,
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

  /// Currently-applied tokens across every filter key **that is not at its
  /// default**, in [filterKeys] order — the same suppression [activeChips]
  /// applies, so Backspace can never reach a chip nobody can see. Recomputed
  /// on every read — cheap, since each key already memoises its own slice.
  List<FilterToken> activeTokens(BuildContext context) {
    final out = <FilterToken>[];
    for (final k in filterKeys) {
      if (_isAtDefaultForChips(k)) continue;
      out.addAll(k.tokensFrom(vm, context));
    }
    return out;
  }

  /// A key sitting at its default contributes no chip — which is what
  /// [FilterKey.isAtDefault]'s own doc has always promised ("the search field
  /// uses this to suppress noise on a fresh load"); until #126 nothing
  /// honoured it, and `isAtDefault` only gated the key picker.
  ///
  /// For every key but one this is a no-op: their `tokensFrom` projects a
  /// values set that their own `isAtDefault` reports empty, and the one
  /// differently-shaped key (`InvoiceOverdueFilterKey`) already early-returns
  /// on `isAtDefault` inside its own `tokensFrom`. It changes exactly one
  /// chip — `IsFilterKey`'s `State: Active`, whose `×` would otherwise reset
  /// the dimension to a value it already holds and appear to do nothing
  /// (invoiceninja/flutter#126). It also settles the mismatch
  /// `TokenSearchField` documents at its clear button: that chip rendered
  /// while `hasActiveFilters` reported none, so the button hid itself.
  ///
  /// Note the implication is one-way. `CustomFieldFilterKey` is the inverse
  /// case — `isAtDefault` false while `tokensFrom` is empty, because the
  /// company un-configured the column — and this guard is immune to it, but
  /// don't read `isAtDefault` as "has no chip" in the other direction.
  ///
  /// Applied in [activeChips] and [activeTokens] rather than in `tokensFrom`
  /// for two reasons. The value picker resolves its applied set — the check
  /// icon, and toggle-vs-add — from `tokensFrom` directly, so suppressing it
  /// there would un-tick Active on an active-only list. And [activeTokens]
  /// backs the Backspace-removes-the-last-chip path, which must not "remove"
  /// a chip nobody can see: it would announce a phantom removal to screen
  /// readers and swallow the key event.
  bool _isAtDefaultForChips(FilterKey key) => key.isAtDefault(vm);

  // ── Keyboard handling ─────────────────────────────────────────────────

  /// Shared arrow / Enter / backspace handling. Returns
  /// [KeyEventResult.handled] when the event was consumed, ignored
  /// otherwise. Mode-specific keys (Escape and Tab in wide mode, free-text
  /// commit fall-through) are layered on top by the widget.
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
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final repeat = event is KeyRepeatEvent;
    if (suggestionsActive) {
      // Arrows honour key-repeat: a held ↓ used to fall through to the text
      // field and walk the caret instead of the highlight.
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        suggestions.moveDown();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        suggestions.moveUp();
        return KeyEventResult.handled;
      }
      if (!repeat &&
          (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
        if (suggestions.commit(expecting: inputStamp)) {
          return KeyEventResult.handled;
        }
        // Fall through — caller may want to commit what is typed.
      }
    }
    // Everything below acts once per press. A repeating Backspace is the user
    // holding the key to clear their text, and it must stop at the chips.
    if (repeat) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.backspace && text.text.isEmpty) {
      // With a pinned (prefix-free) value picker open, Backspace means
      // "back to the filter list", not "delete the last chip" — there's no
      // `<key>:` string to edit any more.
      if (_pinnedValueKey != null) {
        clearPinnedValueKey();
        return KeyEventResult.handled;
      }
      // The last CHIP, not the last value: an aggregate chip stands for
      // several, and it is the chip that gets armed and highlighted. Removing
      // one value of `Status Draft, Paid +1` left the chip the user had just
      // been shown as "about to go" still sitting there.
      final chips = activeChips(context);
      if (chips.isNotEmpty) {
        // First press arms (highlights) the last chip, the second removes it.
        if (!_lastChipArmed) {
          _lastChipArmed = true;
          pinRevision.value++;
          return KeyEventResult.handled;
        }
        _lastChipArmed = false;
        final removed = chips.last;
        // Announce the removal so screen-reader users hear which chip
        // popped — the visual disappearance alone has no a11y signal.
        SemanticsService.sendAnnouncement(
          View.of(context),
          context.tr('filter_removed_announcement', {
            'filter':
                '${removed.token.displayKey} ${removed.token.displayValue}',
          }),
          Directionality.of(context),
        );
        unawaited(removeChip(removed, context));
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  // ── Paste ────────────────────────────────────────────────────────────

  /// Reads the clipboard and applies it through [applyPastedQuery]. Returns
  /// false when the paste should fall through to a native text paste.
  Future<bool> handlePaste(BuildContext context) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    // The host can be gone by the time the platform answers.
    if (_disposed || !context.mounted) return true;
    final input = data?.text;
    if (input == null) return false;
    final applied = applyPastedQuery(input, context);
    if (applied) focus.requestFocus();
    return applied;
  }

  /// Applies the `<key>:<value>` tokens of a pasted query and returns true,
  /// or returns false when nothing in [input] is a filter this list
  /// understands (the caller then pastes it as plain text).
  ///
  /// **A pasted value goes through the same gate as a typed one.** It used to
  /// go straight to `addValue`, so pasting `client:acme balance:abc` applied
  /// `client_id=acme` and `balance=gt:abc` — exactly what [commitTyped]
  /// refuses. A typed-value key normalizes it
  /// ([FilterKey.normalizeTypedValue]); a pick-only key takes it only when it
  /// names one of the key's own values exactly (`is:archived`,
  /// `status:paid`), resolved through the synchronous
  /// [FilterKey.quickValueSuggestions]. Whatever is refused is not dropped:
  /// it stays IN THE BOX with the leftover free text, where the user can see
  /// it and finish it. (Free text used to be applied to the list and the box
  /// cleared, so the list was searched by a term nobody could see.)
  ///
  /// Synchronous, and separate from [handlePaste], so it can be tested —
  /// `Clipboard.getData` never completes under a widget test.
  bool applyPastedQuery(String input, BuildContext context) {
    if (!input.contains(':')) return false;
    final lex = lexFilterInput(input, typeableKeys);
    if (lex.tokens.isEmpty) return false;
    final refused = <String>[];
    var applied = 0;
    for (final t in lex.tokens) {
      final key = keyById(t.keyId);
      if (key == null) continue;
      final raw = _resolvePastedValue(key, t.rawValue, context);
      if (raw == null) {
        refused.add('${typedPrefixOf(key)}:${t.rawValue}');
        continue;
      }
      applied++;
      // Each `addValue` updates the VM synchronously up to its reload, so
      // the tokens stack without awaiting one reload per token.
      unawaited(key.addValue(vm, raw));
    }
    if (applied == 0) return false;
    final rest = [
      ...refused,
      if (lex.freeText.isNotEmpty) lex.freeText,
    ].join(' ');
    text.value = TextEditingValue(
      text: rest,
      selection: TextSelection.collapsed(offset: rest.length),
    );
    // A refused token left in the box is a filter being built, not a search.
    vm.setSearch(refused.isEmpty ? lex.freeText : '');
    return true;
  }

  String? _resolvePastedValue(
    FilterKey key,
    String value,
    BuildContext context,
  ) {
    if (key.acceptsTypedValue) {
      return key.normalizeTypedValue(vm, context, value);
    }
    final wanted = value.trim().toLowerCase();
    for (final s in key.quickValueSuggestions(vm, context, value)) {
      if (s.rawValue.toLowerCase() == wanted ||
          s.displayLabel.toLowerCase() == wanted) {
        return s.rawValue;
      }
    }
    return null;
  }

  /// The prefix [selectKey] writes for [key] and the picker shows as its
  /// "what to type" hint: the first alias when there is one (`status`, not
  /// `is`), else the id.
  static String typedPrefixOf(FilterKey key) =>
      key.aliases.isNotEmpty ? key.aliases.first : key.id;
}
