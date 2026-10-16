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
import 'package:admin/ui/core/widgets/notify.dart';

/// What [TokenSearchController.pickKey] did with the key the user chose.
enum KeyPick {
  /// The key has one possible value and it was applied outright; there is
  /// no picker to show.
  applied,

  /// The key's value picker opened through the pin (nothing written into the
  /// box).
  pinned,
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

/// Sends a keyboard paste in the search box — ⌘V on Apple platforms, Ctrl+V
/// and Shift+Insert elsewhere — to [TokenSearchController.paste]. Hosts put it
/// in an `Actions` directly around the `TextField`: `EditableText` makes its
/// own paste overridable and looks the override up from there.
///
/// Always enabled. The default paste is disabled until the platform reports
/// pasteable text, which it may never do before the keystroke; this one reads
/// the clipboard itself and does nothing with an empty one.
class TokenSearchPasteAction extends ContextAction<PasteTextIntent> {
  TokenSearchPasteAction(this.onPaste);

  final VoidCallback onPaste;

  @override
  bool isEnabled(PasteTextIntent intent, [BuildContext? context]) => true;

  @override
  Object? invoke(PasteTextIntent intent, [BuildContext? context]) {
    onPaste();
    return null;
  }
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
    Future<String?> Function()? readClipboard,
  }) : _filterKeys = filterKeys,
       readClipboard = readClipboard ?? _readPlatformClipboard {
    text = TextEditingController(text: initialText);
    _lastText = initialText;
    _lastSyncedSearch = vm.search;
    text.addListener(_trackEdits);
  }

  final GenericListViewModel<dynamic> vm;

  /// Where [paste] reads the clipboard from. A seam because a widget test
  /// must never await `Clipboard.getData`: it never completes under the test
  /// binding's fake async, and the test hangs at 0% CPU.
  final Future<String?> Function() readClipboard;

  static Future<String?> _readPlatformClipboard() async =>
      (await Clipboard.getData(Clipboard.kTextPlain))?.text;

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
    _pinnedFromChip = false;
    invalidateParse();
    focus.requestFocus();
    pinRevision.value++;
  }

  void clearPinnedValueKey() {
    if (_pinnedValueKey == null && _editing == null) return;
    _pinnedValueKey = null;
    _pinnedFromChip = false;
    _editing = null;
    invalidateParse();
    pinRevision.value++;
  }

  bool _pinnedFromChip = false;

  /// True while the pinned picker belongs to an applied chip it is editing
  /// and hangs under it ([editChip] of a pick-only or custom-field key). The
  /// hosts show no [PendingKeyChip] then: the chip being edited already says
  /// what the list is for, and a second one in the box would repeat it.
  bool get pinnedFromChip => _pinnedFromChip;

  /// The key a filter is being built for, shown as a chip in front of the
  /// text ([PendingKeyChip]) — null when the box is not building one through
  /// the pin, or [pinnedFromChip].
  FilterKey? get pendingKey => _pinnedFromChip ? null : _pinnedValueKey;

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

  /// Empty the box, and withdraw the search that text was applying — unless
  /// the search is not in the box at all ([searchInChip]).
  ///
  /// The search is cleared HERE rather than left to a host's text listener,
  /// which only writes the search for a focused field — and a click on a menu
  /// row or a chip has already taken focus off the input by the time its
  /// handler runs (on desktop a text field unfocuses on any tap outside
  /// itself).
  void dropBoxText() {
    if (text.text.isNotEmpty) text.clear();
    withdrawBoxSearch();
  }

  // ── The search, in the box or in a chip ──────────────────────────────

  bool _searchInChip = false;

  /// True while the applied search is shown as a chip ([SearchTermChip])
  /// because the box is needed for something else: a filter being built, or
  /// text not yet committed.
  ///
  /// **The box owns the search by default, and on every mount.** Typing there
  /// is the live search, Enter keeps the text, and none of that changes. The
  /// search is set aside — "lifted" — only when a filter is started and the
  /// text in the box did not find it ([pickKey], [editChip]): `acme`, then
  /// State, used to drop `acme` on the floor, so a search and a filter could
  /// not be combined at all. While it is a chip, text typed into the box is a
  /// CANDIDATE: it is not applied live, and committing it (Enter, Tab, the
  /// "Search for" row) replaces the search and gives the box back. Tapping the
  /// chip puts the term back in the box ([unfoldSearch]); ✕ or Backspace
  /// removes it ([removeSearchChip]); a change of `vm.search` from outside the
  /// field puts the box back as it is on a mount ([syncExternalSearch]).
  bool get searchInChip => _searchInChip;

  /// The term [SearchTermChip] shows, or null when there is no search chip.
  String? get searchChipTerm =>
      _searchInChip && vm.search.isNotEmpty ? vm.search : null;

  /// The last value this controller wrote into `vm.search` — see
  /// [syncExternalSearch], which must tell its own writes from everyone
  /// else's.
  String? _requestedSearch;

  /// The `vm.search` the box already reflects.
  late String _lastSyncedSearch;

  /// Every write of `vm.search` from the field goes through here, so
  /// [syncExternalSearch] knows which changes it asked for.
  void writeSearch(String value, {bool immediate = false}) {
    _requestedSearch = value;
    vm.setSearch(value, immediate: immediate);
  }

  /// Withdraw the search the BOX was applying. A no-op while the search is a
  /// chip: the box is not applying it then, and a value picked or typed into
  /// a filter must not take the chip with it.
  void withdrawBoxSearch() {
    if (_searchInChip) return;
    writeSearch('');
  }

  /// Follow a change of `vm.search`. Hosts call this from their view-model
  /// listener.
  ///
  /// While the field has focus the box is the source of truth: `vm.search`
  /// trails it through the debounce, and copying a stale value back would
  /// resurrect a character the user just deleted. Unfocused, a change this
  /// controller asked for ([writeSearch]) is already shown; any other — a
  /// restored `nav_state`, a saved view, a deep link, Clear filters — puts
  /// the box back as it is on a mount: no search chip, no pin, the search as
  /// box text. An empty search also ends a search chip whatever the focus;
  /// a chip left standing for nothing would make the next typing a candidate
  /// that never applies.
  void syncExternalSearch({required bool focused}) {
    final current = vm.search;
    if (_searchInChip && current.isEmpty) {
      _searchInChip = false;
      pinRevision.value++;
    }
    if (focused) {
      _lastSyncedSearch = current;
      return;
    }
    if (current == _lastSyncedSearch) return;
    _lastSyncedSearch = current;
    if (current == _requestedSearch) return;
    _resetBoxTo(current);
  }

  /// The box as it is on a mount, showing [value].
  void _resetBoxTo(String value) {
    _searchInChip = false;
    _pinnedValueKey = null;
    _pinnedFromChip = false;
    _editing = null;
    invalidateParse();
    if (text.text != value) {
      text.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
    pinRevision.value++;
  }

  /// Clear filters: the box, the pin and the search chip go with them.
  void clearBox() => _resetBoxTo('');

  /// Make room in the box for a filter being started, deciding what the text
  /// in it was. **Text that found the key is dropped; any other text is the
  /// search, and is set aside as a chip.** "Found" means the list was ranked
  /// by that text and it names the key picked ([keyMatchesQuery]): `sta` for
  /// State was only ever how State was reached, and keeping it would leave a
  /// search nobody meant. A list opened on a search the list was already
  /// showing is not ranked by it ([searchSettled]), so picking from that one
  /// always lifts — the way to keep a search that happens to name a filter
  /// (`stat` for "Statler").
  ///
  /// Text that is not the search at all — a value query, a half-built
  /// `<key>:`, or a candidate beside a search chip — is simply cleared.
  void _setAsideBoxText(BuildContext context, {FilterKey? pickedKey}) {
    final typed = text.text;
    final free = typed.trim();
    if (_searchInChip || free.isEmpty || parseInput().matchedKey != null) {
      if (typed.isNotEmpty) text.clear();
      withdrawBoxSearch();
      return;
    }
    final foundIt =
        pickedKey != null &&
        !searchSettled &&
        keyMatchesQuery(pickedKey, free, context) != KeyQueryMatch.none;
    if (foundIt) {
      text.clear();
      writeSearch('');
      return;
    }
    // Set before the box is emptied, so the host's text listener sees a chip
    // and leaves the search alone.
    _searchInChip = true;
    writeSearch(free, immediate: true);
    text.clear();
    pinRevision.value++;
  }

  /// ✕ (or Backspace) on the search chip. Text typed beside it becomes the
  /// search — the box owns the search again, and box text is the search
  /// whenever there is no chip.
  void removeSearchChip() {
    if (!_searchInChip) return;
    _searchInChip = false;
    final candidate = parseInput().matchedKey == null ? text.text.trim() : '';
    writeSearch(candidate, immediate: true);
    pinRevision.value++;
  }

  /// A tap on the search chip: the term goes back into the box, where it is
  /// the search again and can be edited. A filter being built is abandoned;
  /// text typed beside the chip follows the term.
  void unfoldSearch() {
    final term = searchChipTerm;
    if (term == null) return;
    final candidate = parseInput().matchedKey == null ? text.text.trim() : '';
    _searchInChip = false;
    _pinnedValueKey = null;
    _pinnedFromChip = false;
    _editing = null;
    invalidateParse();
    final next = candidate.isEmpty ? term : '$term $candidate';
    writeSearch(next, immediate: true);
    text.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    focus.requestFocus();
    pinRevision.value++;
  }

  // ── Has the box been edited since the menu opened? ──────────────────

  String _lastText = '';
  bool _editedSinceOpen = false;

  /// Text changes, not every notification: the controller notifies for a
  /// caret moved or a selection made too, and neither is an edit — nor a
  /// reason to drop the armed chip, which ← itself would otherwise do.
  void _trackEdits() {
    if (text.text == _lastText) return;
    _lastText = text.text;
    _editedSinceOpen = true;
    disarmChip();
  }

  /// The menu was opened. [byTyping] when the keystroke that changed the
  /// text is what opened it — that text was typed, not settled.
  void markMenuOpened({bool byTyping = false}) {
    _editedSinceOpen = byTyping;
  }

  /// True when the box holds the search the list is already showing and the
  /// menu opened on it untouched: the key list then ignores the text
  /// ([FilterSuggestionMenu.rankByQuery]), and a key picked from it keeps the
  /// search ([_setAsideBoxText]). The first edit ranks it again.
  bool get searchSettled {
    if (_searchInChip || _editedSinceOpen) return false;
    final t = text.text.trim();
    return t.isNotEmpty &&
        t == vm.search.trim() &&
        parseInput().matchedKey == null;
  }

  /// The user picked [key] from the filter list. **One implementation for
  /// both hosts** — the wide field and the phone sheet each carried a copy of
  /// this, of [editChip] and of [pickOp], and they had drifted three times
  /// (custom fields pinned in one and not the other; `directApplyValue`
  /// honoured in one and not the other; the box text dropped in one and not
  /// the other). The hosts keep only what is theirs: anchors, the overlay,
  /// navigation.
  KeyPick pickKey(FilterKey key, BuildContext context) {
    // Whatever was typed to FIND the key (`sta` → Status) must not become the
    // value query — it matches no status and read as "No matches" — nor stay
    // behind as the search it was live-applying. Any other text is the
    // search, and is kept as a chip.
    _setAsideBoxText(context, pickedKey: key);
    // A key with one possible value (Overdue) applies it outright — a
    // one-row picker is pure friction.
    final direct = key.directApplyValue;
    if (direct != null) {
      unawaited(key.addValue(vm, direct));
      return KeyPick.applied;
    }
    // Every other key opens its value list through the pin, with NO `<id>:`
    // written into the box: the key shows as a chip in front of the text
    // instead ([pendingKey]). A typed-value key (`name`, `balance`) used to
    // get its prefix written in, which is the raw English id in every locale
    // and, for a custom field, the `custom1` its label exists to hide.
    pinValueKey(key);
    return KeyPick.pinned;
  }

  /// The user tapped [chip]'s body — open the editor for it. **The value
  /// stays applied**: the tap used to remove a multi-value key's chip first
  /// and then open the picker, so Escape (or a click away) deleted the
  /// filter. Only ✕ removes. Returns true when the picker opened through the
  /// pin, so a host that anchors its menu can hang it under the chip.
  bool editChip(ActiveFilterChip chip, BuildContext context) {
    final key = chip.key;
    // Whatever is in the box is not this key's value query; free text there
    // is the search, and is kept as a chip.
    _setAsideBoxText(context);
    pinValueKey(key);
    if (opensViaPin(key)) {
      _pinnedFromChip = true;
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
    // nothing, for one it declines (a rolling date, an opaque id) — and
    // selected, so typing replaces it and an arrow key refines it.
    final value = key.editableValueText(raw) ?? '';
    writeBoxText(
      value,
      selection: TextSelection(baseOffset: 0, extentOffset: value.length),
    );
    return false;
  }

  /// Operator picked before a value was typed. Write `<key>:<symbol>` to
  /// the input so the user can keep typing the value; the chip is
  /// committed on Enter (or when the user re-clicks an op row with the
  /// value present). The symbol form is what
  /// [ComparableFilterKey.parseWire] normalises back to the canonical
  /// wire `op:value`.
  ///
  /// Under the pin the box holds the value alone, so only the symbol is
  /// written; a `<key>:` the user typed keeps its prefix.
  void pickOp(FilterKey key, FilterOp op) {
    final symbol = filterOpSymbol(op);
    final next = identical(_pinnedValueKey, key)
        ? symbol
        : '${typedPrefixOf(key)}:$symbol';
    writeBoxText(next);
  }

  /// Write [next] into the box (caret at the end unless [selection] says
  /// otherwise) and focus it. macOS echoes a select-all selection back through
  /// the IME after a programmatic `text.value` write while focused,
  /// overriding the selection just set, so it is re-asserted on the next
  /// frame — guarded, so a user who has already typed or moved the caret is
  /// not fought.
  void writeBoxText(String next, {TextSelection? selection}) {
    final want = selection ?? TextSelection.collapsed(offset: next.length);
    text.value = TextEditingValue(text: next, selection: want);
    focus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !focus.hasFocus) return;
      if (text.text != next) return;
      if (text.selection == want) return;
      text.selection = want;
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

  /// Forget the chip being edited, keeping any pin.
  void clearEditing() {
    _editing = null;
  }

  String? _takeEdit(FilterKey key) {
    final raw = editingValueOf(key);
    _editing = null;
    return raw;
  }

  // ── Armed chip (Backspace, ←/→) ──────────────────────────────────────

  /// The [BoxChip.id] of the highlighted chip, or null.
  ///
  /// **A chip is armed, never focused.** One Backspace in the empty box arms
  /// the last chip and the next removes it (one press used to delete outright,
  /// which someone clearing their text overshot into); ← at the start of the
  /// box arms it too, and ←/→ walk the row ([handleChipKeys]). Real focus
  /// stays in the text field throughout: the moment it left, the list's bare
  /// keys came back on — `N` makes a record, ↑/↓ move the list selection, `G`
  /// arms the leader — because they stand down only while a text input has
  /// focus (`isTextInputFocused`). So the highlight is a value here, like the
  /// menu's, and the keys reach it through the field.
  ///
  /// An id rather than an index or the chip itself: [boxChips] builds fresh
  /// chips on every read, and the row changes under the highlight (a value
  /// ticked into an aggregate chip). An id that is no longer in the row reads
  /// as nothing armed.
  String? _armedChipId;

  bool isArmed(BoxChip chip) => _armedChipId == chip.id;

  /// The armed chip's id — for tests and hosts that scroll it into view.
  String? get armedChipId => _armedChipId;

  void disarmChip() {
    if (_armedChipId == null) return;
    _armedChipId = null;
    pinRevision.value++;
  }

  void _armChip(BoxChip chip, BuildContext context) {
    _armedChipId = chip.id;
    pinRevision.value++;
    // Focus does not move, so nothing else tells a screen reader which chip
    // the next key acts on.
    SemanticsService.sendAnnouncement(
      View.of(context),
      '${chipLabel(chip, context)}, ${context.tr('selected')}',
      Directionality.of(context),
    );
  }

  /// The chip keys while the field has focus: ←/→ into and along the chips,
  /// and Backspace / Delete / Enter / Space / Escape on the armed one. Hosts
  /// call this before anything else in their key handler, so an armed chip
  /// takes the keys it answers to. [onEdit] opens a chip's editor — the same
  /// thing a tap on its body does.
  ///
  /// ← enters the chips only with nothing else for it to do: a collapsed
  /// caret at the very start, no modifier (Shift+← selects, Alt+← and ⌘+←
  /// move by word and line), not mid-composition, and not while a filter is
  /// being built — Backspace leaves that first, and so does this. In
  /// right-to-left text the chips sit to the right, so it is →.
  KeyEventResult handleChipKeys(
    KeyEvent event, {
    required BuildContext context,
    required void Function(BoxChip chip) onEdit,
  }) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final toward = rtl
        ? LogicalKeyboardKey.arrowRight
        : LogicalKeyboardKey.arrowLeft;
    final away = rtl
        ? LogicalKeyboardKey.arrowLeft
        : LogicalKeyboardKey.arrowRight;
    final keyboard = HardwareKeyboard.instance;
    final modified =
        keyboard.isShiftPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed ||
        keyboard.isControlPressed;
    // The typing hot path: with nothing armed, only a plain ← press can start
    // anything here, and building the chips (every key's tokens) for each
    // keystroke is wasted work.
    if (_armedChipId == null &&
        (key != toward || modified || event is! KeyDownEvent)) {
      return KeyEventResult.ignored;
    }
    final chips = boxChips(context);
    final at = chips.indexWhere((c) => c.id == _armedChipId);

    if (at < 0) {
      if (_armedChipId != null) disarmChip();
      if (key != toward || modified || event is! KeyDownEvent) {
        return KeyEventResult.ignored;
      }
      if (chips.isEmpty || parseInput().matchedKey != null) {
        return KeyEventResult.ignored;
      }
      final value = text.value;
      final atStart =
          value.text.isEmpty ||
          (value.selection.isValid &&
              value.selection.isCollapsed &&
              value.selection.baseOffset == 0);
      final composing = value.composing.isValid && !value.composing.isCollapsed;
      if (!atStart || composing) return KeyEventResult.ignored;
      _armChip(chips.last, context);
      return KeyEventResult.handled;
    }

    final armed = chips[at];
    if ((key == toward || key == away) && !modified) {
      if (key == toward) {
        if (at > 0) _armChip(chips[at - 1], context);
      } else if (at < chips.length - 1) {
        _armChip(chips[at + 1], context);
      } else {
        // Past the last chip: back into the text.
        disarmChip();
      }
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      _removeArmed(armed, context);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      disarmChip();
      onEdit(armed);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      disarmChip();
      return KeyEventResult.handled;
    }
    // ↑/↓, Tab and the rest go on to the menu and the field.
    disarmChip();
    return KeyEventResult.ignored;
  }

  void _removeArmed(BoxChip chip, BuildContext context) {
    disarmChip();
    // Announce the removal so screen-reader users hear which chip popped —
    // the visual disappearance alone has no a11y signal.
    SemanticsService.sendAnnouncement(
      View.of(context),
      context.tr('filter_removed_announcement', {
        'filter': chipLabel(chip, context),
      }),
      Directionality.of(context),
    );
    unawaited(removeBoxChip(chip, context));
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

  /// A typed `<key>:` becomes the pin the moment its colon lands: `balance:`
  /// typed turns into the Balance key chip in front of an empty box, exactly
  /// as picking Balance from the menu does, and `status:pa` typed under a
  /// pinned Name picker hands the box to Status with `pa` as its query. One
  /// shape for a filter being built, however it was started — the typed
  /// prefix used to stay raw text, the English id in every locale. Only a
  /// colon after a key's id or alias counts: `Net:30` typed under a custom
  /// field is that field's value.
  ///
  /// Not while an input method is composing (Japanese and Chinese are
  /// bundled): rewriting text under an open composition breaks it. The
  /// rewrite happens once it is committed. The caret keeps its place in the
  /// value. Returns true when it rewrote the box — the host's text listener
  /// then returns at once, as the write notifies it again.
  bool adoptTypedPrefix() {
    final value = text.value;
    if (value.composing.isValid && !value.composing.isCollapsed) return false;
    final input = value.text;
    final colon = input.indexOf(':');
    if (colon < 0) return false;
    final key = typedPrefixKey();
    if (key == null) return false;
    final rest = input.substring(colon + 1);
    final caret = value.selection.isValid
        ? value.selection.extentOffset
        : input.length;
    _pinnedValueKey = key;
    _pinnedFromChip = false;
    _editing = null;
    invalidateParse();
    text.value = TextEditingValue(
      text: rest,
      selection: TextSelection.collapsed(
        offset: (caret - colon - 1).clamp(0, rest.length),
      ),
    );
    pinRevision.value++;
    return true;
  }

  /// Invalidate the cached parse. Call from text listeners when the input
  /// changes; the next [parseInput] re-tokenises.
  void invalidateParse() {
    _parse = null;
  }

  /// Identifies the input the menu's rows were built for — see
  /// [FilterSuggestionController.commit]. The pin is part of it: the same
  /// text means different rows under a different key.
  Object get inputStamp =>
      '${_pinnedValueKey?.id ?? ''}\u0000${searchSettled ? 's' : ''}'
      '\u0000${text.text}';

  bool _disposed = false;

  void dispose() {
    _disposed = true;
    text.removeListener(_trackEdits);
    text.dispose();
    focus.dispose();
    suggestions.dispose();
    pinRevision.dispose();
  }

  // ── Selection helpers ─────────────────────────────────────────────────

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
    withdrawBoxSearch();
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
    withdrawBoxSearch();
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
    withdrawBoxSearch();
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
  ///
  /// Beside a search chip the committed text is the new search, and the box
  /// owns it again.
  void commitFreeText(String value) {
    if (_searchInChip) {
      _searchInChip = false;
      pinRevision.value++;
    }
    writeSearch(value, immediate: true);
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
    withdrawBoxSearch();
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

  /// Every chip in the box: the applied filters, then the search when it is
  /// set aside ([searchInChip]). Last, beside the input, so the text slides
  /// into the chip and back out of it in the same place, and Backspace in the
  /// empty box reaches it first.
  List<BoxChip> boxChips(BuildContext context) {
    final term = searchChipTerm;
    return [...activeChips(context), if (term != null) SearchTermChip(term)];
  }

  /// Remove a whole chip. Non-aggregate → drop its single value (same as
  /// [removeToken]); aggregate → clear the key's whole set in one VM write
  /// via [FilterKey.clear].
  Future<void> removeChip(ActiveFilterChip chip, BuildContext context) {
    if (chip.aggregate) return chip.key.clear(vm, context);
    return chip.key.removeValue(vm, chip.rawValues.single);
  }

  /// [removeChip] for any chip in the box.
  Future<void> removeBoxChip(BoxChip chip, BuildContext context) async {
    switch (chip) {
      case ActiveFilterChip():
        await removeChip(chip, context);
      case SearchTermChip():
        removeSearchChip();
    }
  }

  /// What a screen reader hears for [chip].
  static String chipLabel(BoxChip chip, BuildContext context) => switch (chip) {
    ActiveFilterChip(:final token) =>
      '${token.displayKey} ${token.displayValue}',
    SearchTermChip(:final term) => '${context.tr('search_for')} "$term"',
  };

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
      final chips = boxChips(context);
      if (chips.isNotEmpty) {
        // First press arms (highlights) the last chip, the second removes it
        // — or whichever chip ← left armed ([handleChipKeys] takes that one
        // when the host calls it first).
        final armed = chips.where(isArmed).firstOrNull;
        if (armed == null) {
          _armChip(chips.last, context);
        } else {
          _removeArmed(armed, context);
        }
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  // ── Paste ────────────────────────────────────────────────────────────

  /// A paste into the box — **one path for ⌘/Ctrl+V and the context menu's
  /// Paste**. Only the right-click Paste used to understand a query;
  /// a keyboard paste dropped `status:paid client:acme` into the box as one
  /// Status query of `paid client:acme`, which matched nothing.
  ///
  /// Reads the clipboard, applies what it understands ([applyPastedQuery]),
  /// and pastes anything else as plain text where the caret is. It never
  /// hands back to the platform's own paste action: that would read the
  /// clipboard a second time.
  ///
  /// Not on the web, where ⌘/Ctrl+V and the context menu are the browser's and
  /// the text arrives as typing would.
  Future<void> paste(BuildContext context) async {
    final input = await readClipboard();
    // The host can be gone by the time the platform answers.
    if (_disposed || !context.mounted || input == null || input.isEmpty) {
      return;
    }
    if (!applyPastedQuery(input, context)) insertPlainText(input);
    focus.requestFocus();
  }

  /// Insert [pasted] at the caret, replacing any selection — what a paste
  /// into a single-line field does. Line breaks become spaces.
  void insertPlainText(String pasted) {
    final flat = pasted.replaceAll(RegExp(r'\r\n|\r|\n'), ' ');
    final value = text.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final next = value.text.replaceRange(selection.start, selection.end, flat);
    text.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: selection.start + flat.length),
    );
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
  /// [FilterKey.quickValueSuggestions].
  ///
  /// **What is not a filter lands where the caret is**, the way any paste
  /// does — joining the search already in the box (`acme` + a pasted
  /// `is:archived corp` searches `acme corp`), replacing a selection, or
  /// joining the candidate beside a search chip. It used to replace the whole
  /// box. A refused token is not dropped either: the box is left building it
  /// (refused values re-quoted when they hold a space), and a search the box
  /// owned is set aside as a chip first, unless the paste was over all of it.
  ///
  /// Synchronous, and separate from [paste], so it can be tested.
  bool applyPastedQuery(String input, BuildContext context) {
    if (!input.contains(':')) return false;
    final lex = lexFilterInput(input, typeableKeys);
    if (lex.tokens.isEmpty) return false;
    final accepted = <({FilterKey key, String raw})>[];
    final refused = <({FilterKey key, String value})>[];
    for (final t in lex.tokens) {
      final key = keyById(t.keyId);
      if (key == null) continue;
      final raw = _resolvePastedValue(key, t.rawValue, context);
      if (raw == null) {
        refused.add((key: key, value: t.rawValue));
      } else {
        accepted.add((key: key, raw: raw));
      }
    }
    if (accepted.isEmpty) return false;
    // Each `addValue` updates the VM synchronously up to its reload, so the
    // tokens stack without awaiting one reload per token.
    for (final a in accepted) {
      unawaited(a.key.addValue(vm, a.raw));
    }
    final free = lex.freeText;

    if (refused.isNotEmpty) {
      _leaveRefusedToFinish(refused, free, context);
      return true;
    }

    if (free.isNotEmpty) {
      _insertWithSpaces(free);
      if (!_searchInChip && parseInput().matchedKey == null) {
        writeSearch(text.text.trim(), immediate: true);
      }
    }
    return true;
  }

  /// A paste with filters the gate refused: the box is left building the
  /// FIRST — its key pinned, its value (as pasted, unquoted) in the box, the
  /// same shape picking the key and typing the value gives. The search the box
  /// owned (unless the paste was over all of it) and the paste's free text
  /// become the search, set aside as a chip.
  ///
  /// It used to write `<refused tokens> <free text>` into the box as text, and
  /// the typed-prefix rule then made the first key's value everything after
  /// its colon: `balance:bogus acme` was Balance `bogus acme`, the search lost
  /// inside a value that matched nothing. Only one filter can be built at a
  /// time, so any further refused ones are named in a toast instead.
  void _leaveRefusedToFinish(
    List<({FilterKey key, String value})> refused,
    String free,
    BuildContext context,
  ) {
    final selection = text.selection;
    final overAll =
        selection.isValid &&
        selection.start == 0 &&
        selection.end == text.text.length;
    final current = _searchInChip
        ? (searchChipTerm ?? '')
        : (parseInput().matchedKey != null || overAll ? '' : text.text.trim());
    final term = [current, free].where((t) => t.isNotEmpty).join(' ');
    // Before the box is written, so the host's text listener sees the chip
    // and the pin and leaves the search alone.
    if (term.isEmpty) {
      _searchInChip = false;
      writeSearch('');
    } else {
      _searchInChip = true;
      writeSearch(term, immediate: true);
    }
    final first = refused.first;
    _pinnedValueKey = first.key;
    _pinnedFromChip = false;
    _editing = null;
    invalidateParse();
    text.value = TextEditingValue(
      text: first.value,
      selection: TextSelection.collapsed(offset: first.value.length),
    );
    pinRevision.value++;
    final rest = refused.skip(1).toList();
    if (rest.isNotEmpty) {
      String shown(({FilterKey key, String value}) r) {
        final v = r.value.contains(RegExp(r'\s')) ? '"${r.value}"' : r.value;
        return '${typedPrefixOf(r.key)}:$v';
      }

      Notify.warning(
        context,
        context.tr('filters_not_applied', {
          'filters': rest.map(shown).join(', '),
        }),
      );
    }
  }

  /// [insertPlainText], with a space either side where the neighbouring text
  /// has none — the free text of a query joins words already in the box.
  void _insertWithSpaces(String insert) {
    final value = text.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final before = value.text.substring(0, selection.start);
    final after = value.text.substring(selection.end);
    final lead = before.isEmpty || before.endsWith(' ') ? '' : ' ';
    final trail = after.isEmpty || after.startsWith(' ') ? '' : ' ';
    final next = '$before$lead$insert$trail$after';
    text.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(
        offset: before.length + lead.length + insert.length,
      ),
    );
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

  /// The prefix the picker shows as a key's "what to type" hint, and a paste
  /// or a refused token is written back with: the first alias when there is
  /// one (`status`, not `is`), else the id.
  static String typedPrefixOf(FilterKey key) =>
      key.aliases.isNotEmpty ? key.aliases.first : key.id;
}
