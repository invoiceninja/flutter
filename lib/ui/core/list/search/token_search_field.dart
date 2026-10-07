import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/app/search_focus_registry.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/shortcuts/shortcut_catalog.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_result_scope.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/date_column_filter_key.dart';
import 'package:admin/ui/core/list/search/filter_chip_data.dart';
import 'package:admin/ui/core/list/search/filter_entry_sheet.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_menu_placement.dart';
import 'package:admin/ui/core/list/search/filter_suggestion_menu.dart'
    show FilterSuggestionMenu, kMenuRowInsetLeft, kFilterMenuMaxWidth;
import 'package:admin/ui/core/list/search/filter_token.dart';
import 'package:admin/ui/core/list/search/filter_token_chip.dart';
import 'package:admin/ui/core/list/search/segment_menu.dart';
import 'package:admin/ui/core/list/search/token_search_controller.dart';
import 'package:admin/ui/core/utils/platform_modifier.dart';
import 'package:admin/ui/core/widgets/key_cap.dart';
import 'package:admin/ui/core/widgets/picker_dismissal.dart';

/// Sentry-style token search field. Tokens (e.g. `is:active`,
/// `country:United States`) render as inline chips ahead of a `TextField`
/// for free-text search. Clicking the box opens an autocomplete menu listing
/// the available [FilterKey]s; typing `keyId:` enters value mode and the menu
/// flips to value suggestions.
///
/// `wide=false` collapses the widget to a tap-to-open summary that pushes
/// [FilterEntrySheet] as a full-screen route — the inline layout is
/// unusable on a 360-px phone screen with the keyboard up.
class TokenSearchField extends StatefulWidget {
  const TokenSearchField({
    required this.vm,
    required this.filterKeys,
    required this.wide,
    required this.hintKey,
    super.key,
  });

  final GenericListViewModel<dynamic> vm;
  final List<FilterKey> filterKeys;
  final bool wide;
  final String hintKey;

  @override
  State<TokenSearchField> createState() => _TokenSearchFieldState();
}

/// What [_TokenSearchFieldState._commit] did.
enum _Commit {
  /// Nothing to commit: the box is empty.
  none,

  /// A highlighted menu row ran.
  row,

  /// The typed `<key>:<value>` became a filter.
  applied,

  /// The typed text was committed as a search.
  searched,

  /// The typed value was refused; the input and the menu are kept.
  rejected,
}

class _TokenSearchFieldState extends State<TokenSearchField> {
  final OverlayPortalController _overlay = OverlayPortalController();

  /// The bordered search box. The suggestion menu is kept inside its
  /// horizontal extent, and chip / segment anchors are stored relative to it.
  final GlobalKey _fieldKey = GlobalKey();

  /// Key on the `OverlayPortal` wrapping the text input — the START of the
  /// token being typed, after the chips, which is what the menu hangs from.
  ///
  /// **The portal wraps the input, not the whole field, and that is the
  /// mechanism, not a detail.** `OverlayPortal.overlayChildLayoutBuilder` runs
  /// its builder during layout with the portal child's rect in the Overlay's
  /// coordinates — this frame's rect, which is the whole fix for "the popup
  /// appears too far over". The menu used to be positioned from a build-phase
  /// `localToGlobal`, i.e. from the PREVIOUS frame, so any open that coincided
  /// with a layout change (editing a chip, which removes one and writes text in
  /// the same frame) landed where the input used to be. The SDK guarantees the
  /// portal child's own rect and every ancestor's; it does not guarantee the
  /// child's interior, so the thing we measure has to BE the child. The search
  /// box is an ancestor and so is safe to read alongside it.
  ///
  /// A `GlobalKey` because the portal is a child of a `Wrap` whose earlier
  /// children (the chips) come and go; without it the portal's State — and the
  /// open menu with it — would be torn down whenever a chip is added.
  final GlobalKey _inputKey = GlobalKey();

  // Overlay visibility is intentionally decoupled from focus. It opens
  // only on explicit user gestures (a click anywhere in the box, the leading
  // button, ↓, OR the user typing into a focused field with non-empty text)
  // and closes only on explicit dismissal (Escape, outside-tap via TapRegion,
  // value pick, clear-filters). Tying it to focus directly produced two bugs
  // in tandem: focus loss raced clicks (the overlay would hide before the
  // row's onTap fired — on desktop a text field drops focus on ANY tap
  // outside itself, a menu row included), and focus gain re-opened the menu
  // when the framework re-routed focus back to the TextField after a
  // programmatic `unfocus()` in the dismiss path. The "typing opens" gesture
  // is safe against that: it's keyed on text change, not focus, so a focus
  // restoration without typing won't trip it.

  /// Shared `TapRegion.groupId` for the field and its overlay menu. Without
  /// this, the menu — mounted by `OverlayPortal` in the app-level Overlay —
  /// sits outside the field's TapRegion, so tapping a suggestion fires
  /// `onTapOutside` (which hides the overlay) before the row's detector can
  /// handle the tap. Sharing the group makes Flutter treat them as one
  /// logical region. Per-instance Object so two fields on the same screen
  /// don't cross-clobber.
  final Object _tapGroup = Object();

  /// The chip whose body opened the menu (a pinned value picker), as a rect
  /// relative to the search box. When set, the menu hangs under that chip
  /// instead of the input — the picker belongs to the chip being edited, and
  /// there is no typed text to put it under. Cleared whenever the pin clears.
  Rect? _chipAnchor;

  /// Where the menu was placed when it opened, relative to the search box:
  /// the token start (x) and the box's bottom (y).
  ///
  /// The menu does NOT simply follow the input. Typing never moves the token
  /// start, so there is nothing to chase — but ticking a row in a multi-select
  /// list widens that key's chip, which shoves the input right, and a menu
  /// that followed would slide out from under the pointer mid-click. So x is
  /// re-captured when the menu opens and when the applied chips change
  /// ([_heldChips]) and HELD while a multi-select list is open; y is held too
  /// while the pointer is the one driving, and follows the box otherwise.
  /// Everything is recomputed in the layout pass, so "re-captured" means this
  /// frame's geometry.
  double? _heldStartDx;
  double? _heldBottomDy;
  String? _heldChips;

  /// The side the menu opened on, pinned until it closes so a rising soft
  /// keyboard cannot flip it mid-aim. See `placeFilterMenu`.
  FilterMenuSide? _latchedSide;

  /// True from a tick made by tap or click in a multi-select list until the
  /// next key press: while it is set the open menu holds its y as well as its
  /// x, so a chip that wraps onto a new line cannot drop the list out from
  /// under the finger. Set where the tick is handled (`_onToggleValue`), which
  /// knows whether a key or a pointer made it.
  bool _pointerTicking = false;

  // ── Per-segment dropdown (comparator / value) ───────────────────────
  // A SECOND, dedicated overlay anchored to the tapped chip segment. It
  // commits straight through the key (changeOp / addValue) and never
  // touches the search text controller — fixing the "text appended to
  // the search box" bug of the shared value-mode overlay. Its own tap
  // group so its outside-tap dismissal is independent of the main menu.
  final OverlayPortalController _segmentOverlay = OverlayPortalController();
  final Object _segmentTapGroup = Object();
  final ValueNotifier<int> _segmentRev = ValueNotifier<int>(0);

  /// The tapped segment's rect, relative to the search box (see [_chipAnchor]).
  Rect? _segmentAnchor;
  FilterMenuSide? _segmentLatchedSide;
  ActiveFilterChip? _segmentChip;
  SegmentKind? _segmentKind;

  late final TokenSearchController _controller;

  /// Last `vm.search` value the field already reflects. Used by
  /// `_onVmChange` on the UNFOCUSED path to skip no-op re-syncs of a
  /// value we already wrote. On the FOCUSED path the controller wins
  /// unconditionally (see `_onVmChange` doc); this field still trails
  /// `vm.search` there so the next focus-loss starts from the right
  /// baseline.
  late String _lastSyncedSearch;

  /// Stashed in `initState` so `dispose` can release the claim without
  /// reading from a context that may already be detaching.
  SearchFocusRegistry? _searchFocus;

  @override
  void initState() {
    super.initState();
    _controller = TokenSearchController(
      vm: widget.vm,
      filterKeys: widget.filterKeys,
      initialText: widget.vm.search,
    );
    _lastSyncedSearch = widget.vm.search;
    _controller.text.addListener(_onTextChange);
    _controller.focus.addListener(_onFocusChange);
    widget.vm.addListener(_onVmChange);
    // The slot itself is claimed in [didChangeDependencies], not here — see the
    // TickerMode note there.
    _searchFocus = context.read<Services>().searchFocus;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `StatefulShellRoute.indexedStack` keeps every visited branch mounted, so
    // several `TokenSearchField`s are alive at once and an `initState`-only
    // registration leaves the registry pointing at whichever mounted *last*
    // — `/` then focuses an offstage branch's box, and because that box takes
    // focus it also latches `isTextInputFocused()` on for the whole app,
    // standing every `GuardedShortcutAction` down. go_router mutes the inactive
    // branches' `TickerMode`, so claim the slot whenever ours is the on-stage
    // one; reading it here is also what subscribes us to the offstage→onstage
    // flip. Same gate, same finding (#40), as `ShortcutHintScope`.
    //
    // …and give the claim up when we go offstage, so a screen with no list
    // (the dashboard) is not left with `/` aimed at the branch behind it.
    if (TickerMode.valuesOf(context).enabled) {
      _searchFocus?.current = _controller.focus;
    } else {
      _searchFocus?.release(_controller.focus);
    }
  }

  @override
  void didUpdateWidget(covariant TokenSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync the controller when the host hands us a fresh filter-key list.
    // For clients, `ClientTokenSearchField` wraps this in a
    // `StreamBuilder<Company?>` — the first build's keys carry empty
    // `configuredLabel`s for the custom columns; the second build (once
    // the Company stream emits) replaces them with the configured labels.
    // Without this sync, `_controller.activeTokens` consults the stale
    // empty-label key and `CustomFieldFilterKey.tokensFrom` short-circuits
    // on `configuredLabel.isEmpty` — so the pill never renders even
    // though the filter applies. List-identity is the right comparison:
    // `buildClientFilterKeys` constructs a fresh `List<FilterKey>` per
    // build, so identity mismatch == upstream gave us a new list.
    if (!identical(oldWidget.filterKeys, widget.filterKeys)) {
      _controller.filterKeys = widget.filterKeys;
    }
  }

  @override
  void dispose() {
    // Release rather than null: a record pane's embedded list mounts its field
    // over the main list's, and the main list must get the slot back when the
    // pane closes — see [SearchFocusRegistry].
    _searchFocus?.release(_controller.focus);
    widget.vm.removeListener(_onVmChange);
    _controller.text.removeListener(_onTextChange);
    _controller.focus.removeListener(_onFocusChange);
    _controller.dispose();
    _segmentRev.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    // Nothing else here — the menu is deliberately not driven by focus (see
    // the note above [_tapGroup]). The build listens to the node so the focus
    // ring repaints; it used to wait for the next keystroke.
    if (!_controller.focus.hasFocus) _controller.disarmLastChip();
  }

  void _onTextChange() {
    // Invalidate the parse cache so the next overlay rebuild re-tokenises.
    // No `setState` — the `ListenableBuilder` wrapping the build subtree
    // listens to `_controller.text` directly and rebuilds.
    _controller.invalidateParse();
    _controller.disarmLastChip();

    final text = _controller.text.text;

    // A pinned value key (state / status / client / custom field) keeps
    // ownership while the user types a bare value — the text becomes that
    // key's value query. Only an explicit new `<key>:` drops the pin and
    // reverts to typed-prefix parsing. A bare colon does not: `Net:30` is a
    // legitimate custom-field value.
    if (_controller.pinnedValueKey != null &&
        _controller.typedPrefixKey() != null) {
      _controller.clearPinnedValueKey();
      _chipAnchor = null;
    }

    final focused = _controller.focus.hasFocus;

    // Re-open the overlay when the user starts typing into a focused
    // field. Without this, a chip removal (or any path that leaves focus
    // on the field with the overlay hidden) traps the user typing into a
    // focused input with no dropdown.
    if (focused && text.isNotEmpty && !_overlay.isShowing) {
      _showOverlay();
    }

    // Everything below writes the search, and only the user's own typing may:
    // programmatic text writes on an unfocused field (`_onVmChange` syncing a
    // restored search in) must not echo back.
    if (!focused) return;

    // Building a filter — a matched `<key>:` prefix, or text typed into a
    // pinned picker — is not a search. Withdraw the search the moment that
    // starts: without it, picking "Name" after a live-search of `mar` leaves
    // `mar` filtering the list alongside the chip the user is about to add,
    // and text typed to narrow the Status list also searched the list behind
    // it. `setSearch('')` also cancels a term still inside its debounce.
    //
    // Keyed on the parse, not on `text.contains(':')`: `INV:001` has a colon
    // and IS a search.
    if (_controller.parseInput().matchedKey != null) {
      widget.vm.setSearch('');
      return;
    }

    // Emptying the box clears the search. This used to be skipped ("don't
    // push an empty string"), so backspacing a term away left the list
    // filtered by its last letter under a box that read as empty.
    if (text.isEmpty) {
      widget.vm.setSearch('');
      return;
    }

    // Bare text matching a known key id or alias (`name`, `status`,
    // `country`, …) is the user mid-typing a prefix, not a free-text query.
    // Without this, backspacing `name:` → `name` would search the list for
    // clients literally named "name". Enter or a tap away still commits it
    // (`_commitPendingFreeText`).
    if (_isKeyPrefix(text)) return;

    // Search-as-you-type. No `vm.search != text` pre-check: `vm.search` is
    // the APPLIED term, and re-asking for it is how a newer term still inside
    // the debounce gets withdrawn (type `b` after `a`, delete it at once).
    widget.vm.setSearch(text);
  }

  /// True when [text] matches a typeable filter key's id or alias verbatim
  /// (case-insensitive). Used to suppress the live free-text commit when
  /// the user is mid-typing a key prefix.
  bool _isKeyPrefix(String text) {
    final lower = text.toLowerCase();
    for (final k in _controller.typeableKeys) {
      if (k.id == lower) return true;
      for (final a in k.aliases) {
        if (a == lower) return true;
      }
    }
    return false;
  }

  /// Commit the current input as a free-text search when it isn't a filter
  /// being built. `_onTextChange` live-commits most terms as they're typed,
  /// but suppresses the commit for a term that exactly matches a filter-key
  /// name (`_isKeyPrefix`, e.g. `name` / `status` / `balance`) in case the
  /// user is mid-typing a `name:` prefix. On an explicit "done" gesture —
  /// Enter or tapping away — that suppression must resolve to a search, not a
  /// silent no-op that leaves the list unfiltered.
  void _commitPendingFreeText() {
    final input = _controller.text.text.trim();
    if (input.isEmpty) return;
    if (_controller.parseInput().matchedKey != null) return;
    widget.vm.setSearch(input);
  }

  void _onVmChange() {
    // While the field has focus, the controller is the source of truth.
    // `vm.search` legitimately trails the controller during `setSearch`'s
    // 250 ms debounce — if a notify lands in that window with the STALE
    // `vm.search` value (e.g. a network reply for `john` arrives after
    // the user has backspaced to `joh`), syncing would resurrect a
    // character the user just deleted. External resets (Clear filters,
    // session restore, paste, chip commit) never happen on a focused
    // field, so it's safe to skip the sync here. Keep `_lastSyncedSearch`
    // aligned so the next focus-loss starts from the right baseline.
    if (_controller.focus.hasFocus) {
      _lastSyncedSearch = widget.vm.search;
      return;
    }
    // Unfocused path. Gate on `vm.search` *transitioning* — `_onVmChange`
    // fires on every notify including page loads / item refreshes, which
    // don't touch `vm.search`. Without this guard we'd write the same
    // value into the controller repeatedly and possibly trash the
    // selection.
    final current = widget.vm.search;
    if (current == _lastSyncedSearch) return;
    _lastSyncedSearch = current;
    if (_controller.text.text != current) {
      _controller.text.value = TextEditingValue(
        text: current,
        selection: TextSelection.collapsed(offset: current.length),
      );
    }
  }

  // ── Menu actions ─────────────────────────────────────────────────────

  Future<void> _onSelectValue(FilterKey key, FilterValueSuggestion value) {
    // Dismiss BEFORE the await. addValue/removeValue calls vm.setStates,
    // which fires notifyListeners synchronously and then awaits a page
    // refresh (a real network call). If we dismissed after the await,
    // the parent's ListenableBuilder would rebuild during the wait and
    // re-render the menu in its post-click state for the duration of
    // the network round-trip. Hiding first means the menu is already
    // gone when the await runs.
    //
    // We deliberately do NOT call `unfocus()` here. With the overlay no
    // longer tied to focus, an `unfocus()` would only cause Flutter's
    // FocusManager to re-route focus back to the TextField on the next
    // frame — which used to re-open the menu and produced the "popup
    // shown again" report.
    return _controller.selectValue(
      key,
      value,
      context,
      beforeAwait: () {
        _controller.text.clear();
        _hideOverlay();
      },
    );
  }

  /// A multi-select row — tick or untick the value and keep the menu open so
  /// the user can build a selection. Deliberately does NOT call
  /// `_hideOverlay`; the `ListenableBuilder` rebuilds the still-open menu with
  /// the new checkbox state when the VM notifies.
  Future<void> _onToggleValue(FilterKey key, FilterValueSuggestion value) {
    // A tick made with Enter clears what was typed to find the row (`pa` →
    // Paid), so the whole list is back for the next one. A tap or a click
    // leaves it: someone working down a narrowed list is ticking its matches,
    // and the list must not reshuffle under their finger.
    //
    // Asked of the commit itself, not of `movedByKeyboard` — that flag is true
    // for every fresh list until a mouse MOVES, so every touch tap read as a
    // key press.
    if (_controller.suggestions.committingByKeyboard) {
      _controller.resetValueQuery(key);
    } else {
      // …and from here the menu holds its height too. See [_pointerTicking].
      _pointerTicking = true;
    }
    // A mouse click on the row took focus off the input — on desktop a text
    // field unfocuses on any tap outside itself — which left the open menu
    // with no keyboard at all: arrows and Escape went nowhere.
    _controller.focus.requestFocus();
    return _controller.toggleValueSticky(key, value, context);
  }

  /// "Only", and every replace-not-toggle commit (a typed amount or date, a
  /// date window): select just this value and close, dismissing the overlay
  /// before the await (same ordering rationale as `_onSelectValue`).
  Future<void> _onPickExclusive(FilterKey key, FilterValueSuggestion value) {
    return _controller.selectValueExclusive(
      key,
      value,
      context,
      beforeAwait: () {
        _controller.text.clear();
        _hideOverlay();
      },
    );
  }

  /// User picked a filter dimension from the key-list. What that MEANS is
  /// [TokenSearchController.pickKey]'s, shared with the phone sheet; this only
  /// does the overlay's part.
  void _onSelectKey(FilterKey key) {
    switch (_controller.pickKey(key)) {
      case KeyPick.applied:
        _hideOverlay();
      case KeyPick.pinned:
        _showOverlay();
      case KeyPick.prefixed:
        // The prefix just written re-opens the menu through the text
        // listener if it was closed.
        break;
    }
  }

  /// The value header's "‹": leave the value list for the filter picker.
  void _onBack() {
    _controller.clearPinnedValueKey();
    _chipAnchor = null;
    _controller.dropBoxText();
    _controller.focus.requestFocus();
    _showOverlay();
  }

  /// User tapped a chip body — open the editor for it
  /// ([TokenSearchController.editChip]; the value stays applied). A picker
  /// that opened through the pin hangs under the tapped chip, not the input:
  /// it belongs to the chip, and there is no typed text to put it under.
  void _onChipTap(ActiveFilterChip chip, Rect anchorRect) {
    final anchor = _toFieldRelative(anchorRect);
    if (_controller.editChip(chip)) _chipAnchor = anchor;
    _showOverlay();
  }

  // ── Anchors ──────────────────────────────────────────────────────────

  /// A global rect reported by a chip / segment tap, re-expressed relative to
  /// the search box. Taps happen on a settled layout, so this read is exact;
  /// storing it box-relative lets the layout pass re-project it wherever the
  /// box is by then.
  Rect _toFieldRelative(Rect global) {
    final box = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return global;
    return global.shift(-box.localToGlobal(Offset.zero));
  }

  // ── Per-segment dropdown ─────────────────────────────────────────────

  /// Open the comparator/value dropdown anchored at the tapped segment.
  /// Hard-dismisses the main suggestion overlay + unfocuses so only one
  /// popup is ever live, and writes NOTHING into the search field.
  void _openSegment(ActiveFilterChip chip, SegmentKind kind, Rect anchor) {
    _hideOverlay();
    _controller.focus.unfocus();
    _segmentChip = chip;
    _segmentKind = kind;
    _segmentAnchor = _toFieldRelative(anchor);
    _segmentLatchedSide = null;
    _segmentRev.value++;
    if (!_segmentOverlay.isShowing) _segmentOverlay.show();
  }

  void _closeSegment() {
    if (_segmentOverlay.isShowing) _segmentOverlay.hide();
    _segmentChip = null;
    _segmentKind = null;
    _segmentAnchor = null;
    _segmentLatchedSide = null;
    _segmentRev.value++;
  }

  // ── Overlay show/hide ────────────────────────────────────────────────

  /// Show the dropdown. A fresh open re-captures its placement (see
  /// [_heldStartDx]); calling this on an already-open menu changes nothing.
  void _showOverlay() {
    if (_overlay.isShowing) return;
    _heldStartDx = null;
    _heldBottomDy = null;
    _heldChips = null;
    _latchedSide = null;
    _pointerTicking = false;
    _overlay.show();
  }

  /// Hide the dropdown and drop everything that belonged to that open: the
  /// chip anchor, the pin, the chip being edited, and text that was only ever
  /// a value query.
  void _hideOverlay() {
    if (_overlay.isShowing) _overlay.hide();
    _chipAnchor = null;
    _pointerTicking = false;
    _controller.disarmLastChip();
    // Text in the box that was a value query, not a search. Typed into a
    // pinned picker it never was anything else; behind a `<key>:` prefix it
    // goes when there is nothing after the colon, or when the list was a
    // multi-select — whose ticks are already applied, so the leftover `pa`
    // of `status:pa` is debris. A half-typed `name:ac` stays to be finished.
    final parse = _controller.parseInput();
    final key = parse.matchedKey;
    final debris =
        key != null &&
        (_controller.pinnedValueKey != null ||
            key.checkboxMultiSelect ||
            parse.query.trim().isEmpty);
    _controller.clearPinnedValueKey();
    if (debris && _controller.text.text.isNotEmpty) _controller.text.clear();
  }

  /// Put the caret in the box and open the menu — a click anywhere in the
  /// search box that no chip, button or the text itself claimed.
  void _focusInput() {
    _controller.focus.requestFocus();
    final length = _controller.text.text.length;
    _controller.text.selection = TextSelection.collapsed(offset: length);
    _showOverlay();
  }

  // ── Keyboard handling ────────────────────────────────────────────────

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // The keyboard has the menu again — see [_pointerTicking].
      _pointerTicking = false;
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.escape) {
        // Two stages, like every combobox: the first Escape closes the menu
        // and leaves the caret where it is, the second leaves the box. One
        // press used to do both, so each filter built from the keyboard cost
        // another `/` to get back in.
        if (_overlay.isShowing) {
          _hideOverlay();
        } else {
          _controller.focus.unfocus();
        }
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.tab && _overlay.isShowing) {
        // The menu is not a focus scope and its visibility is not tied to
        // focus, so a Tab that simply moved on left it open with nothing able
        // to close it from the keyboard. With something typed, Tab accepts
        // the highlighted row (autocomplete); otherwise — and for Shift+Tab —
        // it closes the menu and lets focus traverse.
        //
        // "Accepts" means something was actually committed. A typed value the
        // key refuses (`balance:abc`, text that matches no row of a pick-only
        // list) is not: Enter keeps that input so it can be finished, but a
        // Tab that did the same was simply swallowed — nothing committed,
        // nothing moved, on every press.
        final accept =
            !HardwareKeyboard.instance.isShiftPressed &&
            _controller.text.text.isNotEmpty;
        if (accept) {
          switch (_commit()) {
            case _Commit.row:
            case _Commit.applied:
            case _Commit.searched:
              return KeyEventResult.handled;
            case _Commit.none:
            case _Commit.rejected:
              break;
          }
        }
        _hideOverlay();
        return KeyEventResult.ignored;
      }
      if (key == LogicalKeyboardKey.arrowDown && !_overlay.isShowing) {
        // `/` focuses the box without opening anything; ↓ is how a keyboard
        // user reaches the filters from there.
        _showOverlay();
        return KeyEventResult.handled;
      }
    }
    final shared = _controller.handleArrowEnterBackspace(
      event,
      suggestionsActive: _overlay.isShowing,
      context: context,
    );
    if (shared == KeyEventResult.handled) return shared;
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
      return _commitEnter() ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  /// Commit on Enter (hardware) or the soft-keyboard "Search"/"Done" action
  /// (`onSubmitted`). Soft keyboards deliver the action key as a
  /// `TextInputAction`, not a hardware `KeyEvent`, so `_handleKey` alone
  /// missed it (flaky on tablets/iPad) — both entry points route here.
  /// Returns true when it acted.
  bool _commitEnter() => _commit() != _Commit.none;

  /// Commit what the box and the menu currently say, and report what
  /// happened — Enter and Tab want different things from a refusal.
  ///
  /// A highlighted row wins — provided the rows were published for the text
  /// that is in the box now (see [FilterSuggestionController.commit]).
  /// Otherwise the typed input commits: a `<key>:<value>` the key accepts, or
  /// a free-text search. Idempotent under a synthetic-ENTER + onSubmitted
  /// double-fire (`addValue` set-dedups, `setSearch` same-value no-ops,
  /// `_hideOverlay` no-ops).
  _Commit _commit() {
    if (_overlay.isShowing &&
        _controller.suggestions.commit(expecting: _controller.inputStamp)) {
      return _Commit.row;
    }
    final result = _controller.commitTyped(
      context,
      // Before the write, so the menu is already gone when the reload it
      // triggers rebuilds us (same ordering as `_onSelectValue`).
      beforeApply: () {
        _controller.text.clear();
        _hideOverlay();
      },
    );
    switch (result) {
      case TypedCommit.none:
        return _Commit.none;
      case TypedCommit.rejected:
        // Keep the input and the menu: the user sees what they typed and why
        // it did not commit, and can finish it.
        _showOverlay();
        return _Commit.rejected;
      case TypedCommit.applied:
        return _Commit.applied;
      case TypedCommit.searched:
        // We must NOT clear the input here: it IS the search, and clearing
        // it would clear the search with it.
        _hideOverlay();
        return _Commit.searched;
    }
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Rebuilds are driven by the listenable merge here rather than ad-hoc
    // `setState` calls in the change handlers. The text listener only
    // invalidates the parse cache; the VM listener only syncs the text
    // controller. Both notify the merge, which then rebuilds the subtree.
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.vm,
        _controller.text,
        _controller.pinRevision,
        _segmentRev,
        _controller.focus,
      ]),
      builder: (context, _) =>
          widget.wide ? _buildWide(context) : _buildNarrowSummary(context),
    );
  }

  /// The glyphs of the shortcut that focuses this box (`/` unless rebound), or
  /// null when it is unbound — for the hint cap in the empty box.
  List<String>? _focusSearchGlyphs(BuildContext context) {
    try {
      return context
          .read<Services>()
          .keyboardShortcuts
          .resolvedBinding(ShortcutActionIds.focusSearch)
          ?.displayGlyphs(platformModifierLabel());
    } catch (_) {
      // A host with no shortcut controller (a preview, a bare test tree):
      // the hint is decoration, never a reason to fail the field.
      return null;
    }
  }

  /// How far the soft keyboard reaches up into the Overlay hosting the menu.
  /// Measured against the Overlay's own bottom edge, not read off
  /// `MediaQuery.viewInsets` at this context: a `Scaffold` between here and
  /// the Overlay may or may not have consumed the inset already, and the
  /// Overlay is only shrunk by the ones ABOVE it.
  double _keyboardOverlap(BuildContext overlayContext) {
    final view = View.maybeOf(overlayContext);
    if (view == null) return 0;
    final data = MediaQueryData.fromView(view);
    final inset = data.viewInsets.bottom;
    if (inset <= 0) return 0;
    final box =
        Overlay.of(overlayContext).context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return 0;
    final overlayBottom = box.localToGlobal(Offset(0, box.size.height)).dy;
    return math.max(0, overlayBottom - (data.size.height - inset));
  }

  /// Positions the suggestion [menu]. Runs in the LAYOUT pass (see
  /// [_inputKey]), so every rect here belongs to this frame. Geometry only:
  /// no `setState`, no show/hide, no notifier — the cached anchor fields are
  /// plain writes.
  Widget _placeMenu(
    BuildContext overlayContext,
    OverlayChildLayoutInfo info,
    Widget menu,
    String chips,
  ) {
    final fieldBox = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    final inputBox = _inputKey.currentContext?.findRenderObject() as RenderBox?;
    if (fieldBox == null ||
        inputBox == null ||
        !fieldBox.hasSize ||
        !inputBox.hasSize) {
      return const SizedBox.shrink();
    }
    // The input's rect in the Overlay's coordinates — no global round-trip,
    // so the hosting Overlay's own origin (the sidebar's width on a wide
    // window) never enters into it.
    final inputRect = MatrixUtils.transformRect(
      info.childPaintTransform,
      Offset.zero & info.childSize,
    );
    final inputInField = inputBox.localToGlobal(
      Offset.zero,
      ancestor: fieldBox,
    );
    final fieldRect = (inputRect.topLeft - inputInField) & fieldBox.size;
    final direction = Directionality.of(overlayContext);
    final rtl = direction == TextDirection.rtl;

    final liveStart = rtl
        ? inputInField.dx + info.childSize.width
        : inputInField.dx;
    final liveBottom = fieldBox.size.height;
    final multiSelectOpen =
        _controller.parseInput().matchedKey?.checkboxMultiSelect ?? false;
    if (_heldStartDx == null || (!multiSelectOpen && chips != _heldChips)) {
      _heldStartDx = liveStart;
      _heldBottomDy = liveBottom;
    } else if (!multiSelectOpen || !_pointerTicking) {
      // x holds; y follows the box — unless a pointer is working a
      // multi-select list, where a chip that wraps onto a new line must not
      // drop the menu out from under the cursor.
      _heldBottomDy = liveBottom;
    }
    _heldChips = chips;

    // A chip anchor belongs to the pinned picker it opened. Backspace on an
    // empty input clears that pin from the controller, back to the filter
    // list — which then hangs from the input like any other open, not from
    // the chip it has nothing to do with any more.
    if (_controller.pinnedValueKey == null) _chipAnchor = null;
    final chip = _chipAnchor;
    final double anchorStart;
    final double anchorTop;
    final double anchorBottom;
    if (chip != null) {
      anchorStart = fieldRect.left + (rtl ? chip.right : chip.left);
      anchorTop = fieldRect.top + chip.top;
      anchorBottom = fieldRect.top + chip.bottom;
    } else {
      anchorStart = fieldRect.left + _heldStartDx!;
      anchorTop = fieldRect.top;
      anchorBottom = fieldRect.top + _heldBottomDy!;
    }

    final placement = placeFilterMenu(
      field: fieldRect,
      anchorStart: anchorStart,
      anchorTop: anchorTop,
      anchorBottom: anchorBottom,
      overlay: info.overlaySize,
      preferredWidth: kFilterMenuMaxWidth,
      bottomInset: _keyboardOverlap(overlayContext),
      textDirection: direction,
      latchedSide: _latchedSide,
      rowInset: kMenuRowInsetLeft,
    );
    _latchedSide = placement.side;

    return Positioned(
      left: placement.left,
      top: placement.top,
      bottom: placement.bottom,
      width: placement.width,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: placement.maxHeight),
        child: menu,
      ),
    );
  }

  Widget _buildWide(BuildContext context) {
    final tokens = context.inTheme;
    final active = _controller.activeChips(context);
    final focused = _controller.focus.hasFocus;
    // What "the applied chips changed" means to the menu's placement.
    final chips = [
      for (final c in active) '${c.key.id}=${c.rawValues.join(',')}',
    ].join('|');

    // Built once per build and handed to the layout callback, which only
    // positions it. The callback re-runs whenever the box moves (a resize, a
    // page scrolling under an embedded list); returning this same instance
    // means the menu itself is not rebuilt for that.
    //
    // Android back closes the menu instead of navigating off the list.
    // This is not a route and carries no back handling of its own, and
    // the wide field it belongs to is reachable on touch far more widely
    // than "desktop": every tablet gets it. Unhandled, back ran
    // `NavHistoryController.back()` — or `SystemNavigator.pop()` and left
    // the app.
    //
    // `onBack` closes AND unfocuses, deliberately not `onTapOutside`'s pair,
    // which also `_commitPendingFreeText()`s: back cancels, it does not
    // commit. `_hideOverlay` is load-bearing beyond `hide()` — it clears the
    // chip anchor, unpins the value key and drops a dangling `country:`
    // prefix.
    //
    // `BackDismissiblePickerOverlay` would be WRONG here: these overlays
    // are driven by an `OverlayPortalController` and visibility is
    // deliberately decoupled from focus (see the class doc), so
    // unfocusing would swallow the press and leave the menu on screen.
    // Hence the explicit `canDismiss` too — the mount window is the
    // portal's, and `isShowing` is the real predicate.
    final Widget menu = BackDismissibleOverlay(
      onBack: () {
        _hideOverlay();
        _controller.focus.unfocus();
      },
      canDismiss: () => _overlay.isShowing,
      child: TapRegion(
        groupId: _tapGroup,
        child: FilterSuggestionMenu(
          vm: widget.vm,
          keys: widget.filterKeys,
          parse: _controller.parseInput(),
          controller: _controller.suggestions,
          stamp: _controller.inputStamp,
          // A row that pushes a route (both date pickers) must close this
          // overlay first: the `BackDismissibleOverlay` above holds a
          // `ChildBackButtonDispatcher`, which the `Router` consults
          // BEFORE popping, so back would dismiss the menu under the
          // calendar and leave the calendar up.
          onDismiss: _hideOverlay,
          onBack: _onBack,
          onSelectKey: _onSelectKey,
          onSelectValue: _onSelectValue,
          onToggleValue: _onToggleValue,
          onPickExclusive: _onPickExclusive,
          onPickOp: _controller.pickOp,
          onCommitFreeText: (v) {
            _controller.commitFreeText(v);
            // Enter on the "Search for X" row signals "I'm done
            // picking; show me the results" — dismiss the dropdown
            // but keep focus + the typed text so the user can keep
            // editing the query.
            _hideOverlay();
            _controller.focus.requestFocus();
          },
        ),
      ),
    );

    final input = OverlayPortal.overlayChildLayoutBuilder(
      key: _inputKey,
      controller: _overlay,
      overlayChildBuilder: (overlayContext, info) =>
          _placeMenu(overlayContext, info, menu, chips),
      child: IntrinsicWidth(
        child: ConstrainedBox(
          // Sized so the input is visible-but-discoverable when
          // no chips are present. `IntrinsicWidth` keeps the
          // input from greedy-grabbing the row when chips are
          // wide enough to fill the available width on the
          // current run of the Wrap.
          constraints: const BoxConstraints(minWidth: 80),
          child: Focus(
            onKeyEvent: _handleKey,
            child: TextField(
              controller: _controller.text,
              focusNode: _controller.focus,
              // Soft keyboards (tablet/iPad in the wide layout)
              // send the action key as a TextInputAction, not a
              // hardware KeyEvent — wire onSubmitted so it
              // reliably commits, same as the `_handleKey` path.
              // Search queries are names and numbers, not prose — iOS
              // autocorrecting "Acme" to "Acne" mid-search is the failure.
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _commitEnter(),
              decoration: InputDecoration(
                hintText: active.isEmpty ? context.tr(widget.hintKey) : null,
                // All four state-specific borders must be
                // explicit; the global `InputDecorationTheme`
                // sets each to `OutlineInputBorder`, and
                // `border: InputBorder.none` alone leaves them
                // active — the user then sees a phantom
                // rounded box sitting where the empty input is.
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: false,
                isCollapsed: true,
                // 32 px on every platform. A pointer platform's compact
                // density already takes 8 off the decorator; touch has no
                // such adjustment, and at 8 + 8 the input alone was 40 px —
                // taller than the header row it sits in.
                contentPadding: EdgeInsets.symmetric(
                  vertical: Env.isTouchPrimary ? 4 : 8,
                ),
              ),
              onTap: _showOverlay,
              contextMenuBuilder: (context, editableState) {
                return AdaptiveTextSelectionToolbar.editable(
                  clipboardStatus: ClipboardStatus.pasteable,
                  onCopy: () => editableState.copySelection(
                    SelectionChangedCause.toolbar,
                  ),
                  onCut: () =>
                      editableState.cutSelection(SelectionChangedCause.toolbar),
                  onPaste: () async {
                    final handled = await _controller.handlePaste(context);
                    if (!handled && context.mounted) {
                      // Native paste fallback when the
                      // clipboard doesn't look like a
                      // `key:value` query — pasteText is
                      // fire-and-forget, the controller's
                      // change listener will sync state.
                      unawaited(
                        editableState.pasteText(SelectionChangedCause.toolbar),
                      );
                    }
                  },
                  onSelectAll: () =>
                      editableState.selectAll(SelectionChangedCause.toolbar),
                  anchors: editableState.contextMenuAnchors,
                  onLookUp: null,
                  onSearchWeb: null,
                  onShare: null,
                  onLiveTextInput: null,
                );
              },
            ),
          ),
        ),
      ),
    );

    // The shortcut that lands here, shown while the box is empty and idle.
    // A hardware-keyboard hint, so never on touch.
    // …and only on the box the shortcut would actually land in: a record
    // pane's embedded list claims the slot over the list behind it.
    final shortcut =
        !Env.isTouchPrimary &&
            !focused &&
            active.isEmpty &&
            _controller.text.text.isEmpty &&
            identical(_searchFocus?.current, _controller.focus)
        ? _focusSearchGlyphs(context)
        : null;

    final field = TapRegion(
      groupId: _tapGroup,
      onTapOutside: (_) {
        // The overlay shares this TapRegion group, so this only fires on a
        // genuine tap away (not when picking a suggestion). Commit any
        // pending key-name free-text term before dismissing so tapping away
        // filters the list, matching how every other term live-commits.
        _commitPendingFreeText();
        _hideOverlay();
        _controller.focus.unfocus();
      },
      child: Container(
        key: _fieldKey,
        clipBehavior: Clip.antiAlias,
        // One header row tall with nothing wrapped, on every platform — and
        // a floor: the box grows by a line each time its chips wrap, and the
        // header around it grows with it (`EntityListAppBar`).
        constraints: const BoxConstraints(minHeight: InSizes.headerRow),
        decoration: BoxDecoration(
          color: tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(InRadii.r1),
          // The focus ring thickens by SHADOW, not by border width. A wider
          // border grew the box by a pixel on every focus, which a header
          // that sizes to this box would pass on to the whole list below.
          border: Border.all(color: focused ? tokens.accent : tokens.border),
          boxShadow: focused
              ? [BoxShadow(color: tokens.accent, spreadRadius: 0.5)]
              : null,
        ),
        child: Stack(
          // Passthrough: the row is laid out exactly as it was without the
          // Stack around it.
          fit: StackFit.passthrough,
          children: [
            // Behind the row: any click in the box that no chip, button or
            // the text itself claims puts the caret in the input and opens
            // the menu. The input is only as wide as its text
            // (`IntrinsicWidth`), so most of an empty box used to be dead.
            // Not an ancestor detector — that would join the TextField's own
            // gesture arena and contest its selection drags.
            Positioned.fill(
              child: MouseRegion(
                cursor: SystemMouseCursors.text,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _focusInput,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              // Top-aligned: the chips wrap, and the box's own buttons stay
              // on the first line (each in a `_kBoxLine` slot) instead of
              // sliding down its middle as it grows.
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _boxButton(
                    tooltip: context.tr('add_filter'),
                    // A magnifier: this is the search box. It used to be the
                    // `tune` glyph, which says "settings" and left the box
                    // with no sign of what it is until the hint was read.
                    icon: Icons.search,
                    onPressed: () {
                      // Toggle: a second click dismisses the open menu rather
                      // than no-opping (the `OverlayPortal.show()` is guarded
                      // against double-shows). Standard dropdown affordance.
                      _controller.focus.requestFocus();
                      if (_overlay.isShowing) {
                        _hideOverlay();
                      } else {
                        _showOverlay();
                      }
                    },
                  ),
                  Expanded(
                    // Scrolls only when the header has reached its height
                    // ceiling (`EntityListAppBar.maxExtentFor`) — until then
                    // it is exactly as tall as its chips. Without it, lines
                    // past the ceiling were laid out anyway and painted over
                    // the list, out of reach of the pointer. `primary: false`
                    // so a phone's status-bar tap does not find this instead
                    // of the list.
                    //
                    // `deferToChild`: a scroll view is opaque to hits by
                    // default, which would swallow every click on the blank
                    // part of the box before it reached the detector behind
                    // this row — the one that focuses the input.
                    child: ScrollConfiguration(
                      // No scrollbar: the desktop one wraps the scroll view
                      // in an opaque `MouseRegion`, which blocks those same
                      // clicks however the scroll view itself hit-tests.
                      behavior: ScrollConfiguration.of(
                        context,
                      ).copyWith(scrollbars: false),
                      child: SingleChildScrollView(
                        primary: false,
                        hitTestBehavior: HitTestBehavior.deferToChild,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: _kBoxLine,
                          ),
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            // One line sits centred in the first-line slot.
                            // More have no spare height to distribute, so they
                            // simply stack from the top.
                            runAlignment: WrapAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              for (var i = 0; i < active.length; i++)
                                _chip(active[i], armed: i == active.length - 1),
                              input,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (shortcut != null && shortcut.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: _kBoxLine),
                      child: Align(
                        widthFactor: 1,
                        heightFactor: 1,
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(
                            start: 8,
                            end: 4,
                          ),
                          child: IgnorePointer(
                            child: KeyCapRow(
                              keys: shortcut,
                              dense: true,
                              keyColor: tokens.ink3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // `hasActiveFilters` treats `{active}` as "no state filter"
                  // (and ignores a changed sort — sort isn't a filter), so the
                  // clear button hides when the lifecycle default is the only
                  // thing applied, regardless of sort. Since #126 that agrees
                  // with the chips: a key at its default renders none, so there
                  // is nothing on screen for the missing button to contradict.
                  if (widget.vm.hasActiveFilters ||
                      _controller.text.text.isNotEmpty)
                    _boxButton(
                      tooltip: context.tr('clear_filters'),
                      // Distinct from the per-chip `Icons.close` so "clear all
                      // filters" doesn't look like "remove one chip".
                      icon: Icons.filter_alt_off_outlined,
                      onPressed: () {
                        _controller.text.clear();
                        widget.vm.clearAllFilters();
                        _hideOverlay();
                        _controller.focus.unfocus();
                      },
                    ),
                ],
              ),
            ),
            // A fetch in flight for what is typed or filtered. The list
            // itself only showed a spinner at its foot, off screen for any
            // list longer than the window.
            if (widget.vm.isLoadingPage &&
                (widget.vm.hasActiveFilters ||
                    _controller.text.text.isNotEmpty))
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              ),
          ],
        ),
      ),
    );

    // The segment overlay (comparator / value / field of one chip) is a
    // sibling of the main suggestion overlay — separate controller + tap
    // group. Only one is ever shown at a time (`_openSegment` hides the main
    // one first). Its portal wraps the whole box: the anchor is a chip
    // segment, stored relative to the box.
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _segmentOverlay,
      overlayChildBuilder: _buildSegmentOverlay,
      child: field,
    );
  }

  /// The height of one line INSIDE the box: [InSizes.headerRow] less the
  /// box's 4 px of padding and 1 px of border, above and below.
  static const double _kBoxLine = InSizes.headerRow - 10;

  /// One of the box's own icon buttons (the leading magnifier, clear-all), in
  /// a first-line slot so it stays level with the first line of chips.
  ///
  /// On a touch platform the theme pads a button's LAYOUT box to 48 px, which
  /// made the box — and the header around it — taller than the band with
  /// nothing in it; the old fixed-height header clamped that silently. So the
  /// button shrink-wraps, takes its height from the line and keeps a finger's
  /// width: the target is reclaimed on the axis that has room
  /// (`docs/touch-targets.md`).
  Widget _boxButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final touch = Env.isTouchPrimary;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kBoxLine),
      child: Align(
        widthFactor: 1,
        heightFactor: 1,
        child: IconButton(
          tooltip: tooltip,
          iconSize: 18,
          padding: touch ? EdgeInsets.zero : null,
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          // Unset on touch: `compact` would take 8 back off the constraints
          // below (CLAUDE.md § Design system, trap 2).
          visualDensity: touch ? null : VisualDensity.compact,
          constraints: touch
              ? const BoxConstraints.tightFor(width: 40, height: 34)
              : null,
          onPressed: onPressed,
          icon: Icon(icon, color: context.inTheme.ink3),
        ),
      ),
    );
  }

  Widget _chip(ActiveFilterChip c, {required bool armed}) {
    return FilterTokenChip(
      token: c.token,
      // The ✕ takes its height from the line here — see `compact`.
      compact: true,
      armed: armed && _controller.lastChipArmed,
      onRemove: () => _controller.removeChip(c, context),
      // Field-segment tap. MUST stay non-null for a
      // comparable chip — `_segmented` collapses to a
      // plain chip (losing the comparator/value editors)
      // if `onTap == null`. Four cases:
      //  • non-comparable → `_onChipTap`.
      //  • comparable window/between → value segment
      //    (the range picker); no field switch.
      //  • comparable, ≥2 same-type fields → field menu.
      //  • comparable, no alternative → value segment
      //    (fixes the stray-`balance:>400`-text bug).
      onTap: () {
        final k = c.key;
        if (k is! ComparableFilterKey) {
          return (Rect r) => _onChipTap(c, r);
        }
        final isWindow =
            k is DateColumnFilterKey && k.isWindowWire(c.rawValues.single);
        if (isWindow) {
          return (Rect r) => _openSegment(c, SegmentKind.value, r);
        }
        if (_fieldSwitchCandidates(k).length > 1) {
          return (Rect r) => _openSegment(c, SegmentKind.field, r);
        }
        return (Rect r) => _openSegment(c, SegmentKind.value, r);
      }(),
      // Comparator / value segments open a dedicated
      // dropdown anchored AT the segment (commits via
      // changeOp / addValue — never writes text into
      // the search field).
      onComparatorTap: c.key.supportedOps.isNotEmpty
          ? (r) => _openSegment(c, SegmentKind.comparator, r)
          : null,
      onValueTap: c.key.supportedOps.isNotEmpty
          ? (r) => _openSegment(c, SegmentKind.value, r)
          : null,
    );
  }

  /// Other comparable keys of the same [FilterValueType] this chip can
  /// switch its field to (includes [current], rendered check-marked).
  List<ComparableFilterKey> _fieldSwitchCandidates(
    ComparableFilterKey current,
  ) => widget.filterKeys
      .whereType<ComparableFilterKey>()
      .where(
        (k) => k.valueType == current.valueType && k.isAvailable(widget.vm),
      )
      .toList();

  /// Builds the per-segment dropdown, hung just below the tapped segment.
  /// Runs in the layout pass like [_placeMenu]; `info` describes the search
  /// box here, and [_segmentAnchor] is relative to it.
  Widget _buildSegmentOverlay(
    BuildContext overlayContext,
    OverlayChildLayoutInfo info,
  ) {
    final chip = _segmentChip;
    final kind = _segmentKind;
    final anchor = _segmentAnchor;
    if (chip == null || kind == null || anchor == null) {
      return const SizedBox.shrink();
    }
    final key = chip.key;
    if (key is! ComparableFilterKey) return const SizedBox.shrink();

    final fieldRect = MatrixUtils.transformRect(
      info.childPaintTransform,
      Offset.zero & info.childSize,
    );
    final direction = Directionality.of(overlayContext);
    final segment = anchor.shift(fieldRect.topLeft);
    final placement = placeFilterMenu(
      field: fieldRect,
      anchorStart: direction == TextDirection.rtl
          ? segment.right
          : segment.left,
      anchorTop: segment.top,
      anchorBottom: segment.bottom,
      overlay: info.overlaySize,
      preferredWidth: SegmentMenu.maxWidth,
      preferredMaxHeight: SegmentMenu.maxHeight,
      bottomInset: _keyboardOverlap(overlayContext),
      textDirection: direction,
      // A segment popup belongs to its chip, not to the box: it starts at the
      // segment's edge and only has to stay on screen.
      containInField: false,
      rowInset: 0,
      latchedSide: _segmentLatchedSide,
    );
    _segmentLatchedSide = placement.side;

    return Positioned(
      left: placement.left,
      top: placement.top,
      bottom: placement.bottom,
      width: placement.width,
      // Same reasoning as the main menu, and this one is worse: `_openSegment`
      // explicitly unfocuses before showing, so there is no IME to absorb the
      // press and the FIRST back navigated away. `_closeSegment` is what its
      // own Escape binding and tap-outside already do.
      child: BackDismissibleOverlay(
        onBack: _closeSegment,
        canDismiss: () => _segmentOverlay.isShowing,
        child: TapRegion(
          groupId: _segmentTapGroup,
          onTapOutside: (_) => _closeSegment(),
          child: Align(
            alignment: AlignmentDirectional.topStart,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: placement.maxHeight),
              child: SegmentMenu(
                vm: widget.vm,
                filterKey: key,
                kind: kind,
                currentWire: chip.rawValues.single,
                onClose: _closeSegment,
                fieldChoices: kind == SegmentKind.field
                    ? _fieldSwitchCandidates(key)
                    : const [],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNarrowSummary(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final active = _controller.activeChips(context);
    final search = widget.vm.search;
    final filtered = widget.vm.hasActiveFilters;

    final Widget content;
    if (active.isEmpty) {
      content = Text(
        search.isEmpty ? context.tr(widget.hintKey) : search,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: search.isEmpty ? tokens.ink3 : tokens.ink,
        ),
      );
    } else {
      // The first chip and a count of the rest — never a horizontal scroller,
      // which hides an active filter off the edge with nothing to say it is
      // there. The count is every other chip plus the search term.
      final more = active.length - 1 + (search.isEmpty ? 0 : 1);
      content = Row(
        children: [
          Flexible(child: FilterTokenChip.readOnly(token: active.first.token)),
          if (more > 0) ...[
            const SizedBox(width: 6),
            FilterTokenChip.readOnly(
              token: FilterToken(
                keyId: '',
                displayKey: '',
                rawValue: '',
                displayValue: '+$more',
              ),
            ),
          ],
        ],
      );
    }

    return InkWell(
      onTap: () => _openSheet(context),
      borderRadius: BorderRadius.circular(InRadii.r1),
      child: Container(
        // The same one-line height as the wide box, so it sits level with
        // the buttons beside it in a wide header (a phone in landscape gets
        // this row there).
        constraints: const BoxConstraints(minHeight: InSizes.headerRow),
        decoration: BoxDecoration(
          color: tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(InRadii.r1),
          border: Border.all(color: tokens.border),
        ),
        padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
        child: Row(
          children: [
            Icon(Icons.search, size: 18, color: tokens.ink3),
            const SizedBox(width: 8),
            Expanded(child: content),
            // Clearing used to take opening the sheet and finding "Clear
            // all". Width is the finger's axis here; the height is the row's.
            if (filtered)
              IconButton(
                tooltip: context.tr('clear_filters'),
                iconSize: 18,
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                constraints: const BoxConstraints.tightFor(
                  width: InSizes.touchTarget,
                  height: 38,
                ),
                onPressed: widget.vm.clearAllFilters,
                icon: Icon(Icons.filter_alt_off_outlined, color: tokens.ink3),
              )
            else
              SizedBox(
                width: InSizes.touchTarget,
                height: 38,
                child: Icon(Icons.tune, size: 18, color: tokens.ink3),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    // Read the scaffold-provided result scope BEFORE pushing — the pushed
    // route can't reach it through the element tree. Null on lists with no
    // tile builder (the sheet then simply shows no live-results section).
    final scope = EntityListResultScope.maybeOf(context);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => FilterEntrySheet(
          vm: widget.vm,
          filterKeys: widget.filterKeys,
          hintKey: widget.hintKey,
          resultTile: scope?.resultTile,
          onOpenRecord: scope?.onOpenRecord,
        ),
      ),
    );
  }
}
