import 'dart:async';

import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_result_scope.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/filter_chip_data.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_suggestion_menu.dart';
import 'package:admin/ui/core/list/search/filter_token.dart';
import 'package:admin/ui/core/list/search/filter_token_chip.dart';
import 'package:admin/ui/core/list/search/segment_menu.dart';
import 'package:admin/ui/core/list/search/token_search_controller.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';

/// Narrow-mode editor for the token search field. Pushed as a full-screen
/// modal page from [TokenSearchField] on phone widths. Chips + input occupy
/// the top of the page; the suggestion list fills the rest. Done button +
/// system back close the page.
class FilterEntrySheet extends StatefulWidget {
  const FilterEntrySheet({
    required this.vm,
    required this.filterKeys,
    required this.hintKey,
    this.resultTile,
    this.onOpenRecord,
    super.key,
  });

  final GenericListViewModel<dynamic> vm;
  final List<FilterKey> filterKeys;
  final String hintKey;

  /// Renders one live-results row (the real per-entity list tile) — supplied
  /// by the list scaffold via [EntityListResultScope]. Null on lists without
  /// a tile builder (then the sheet shows no live results, only suggestions).
  final ResultTileBuilder? resultTile;

  /// Opens the tapped result's record. Paired with [resultTile].
  final OpenRecordCallback? onOpenRecord;

  @override
  State<FilterEntrySheet> createState() => _FilterEntrySheetState();
}

class _FilterEntrySheetState extends State<FilterEntrySheet> {
  late final TokenSearchController _controller;

  /// Last free-text value pushed to [widget.vm] via search-as-you-type.
  /// Tracked so a VM notify during the debounce window doesn't keep
  /// re-pushing (which would reset the debounce timer and stall the search).
  String _lastSyncedSearch = '';

  @override
  void initState() {
    super.initState();
    _controller = TokenSearchController(
      vm: widget.vm,
      filterKeys: widget.filterKeys,
      initialText: widget.vm.search,
    );
    _lastSyncedSearch = widget.vm.search;
    _controller.text.addListener(_onChange);
    _controller.text.addListener(_controller.disarmLastChip);
    widget.vm.addListener(_onChange);
    // Pin changes touch neither text nor vm — rebuild so the always-built
    // menu switches to value mode for a pinned checkbox key.
    _controller.pinRevision.addListener(_onChange);
    // Autofocus the input so the keyboard appears the moment the user
    // arrives — they tapped the summary specifically to edit.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.focus.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant FilterEntrySheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Mirror of `TokenSearchField.didUpdateWidget` — see that file for
    // the full rationale. The sheet can outlive a `customFields` change
    // in Settings; without this sync the controller would keep the
    // empty-label `CustomFieldFilterKey`s and the pill wouldn't render
    // after a custom value was picked.
    if (!identical(oldWidget.filterKeys, widget.filterKeys)) {
      _controller.filterKeys = widget.filterKeys;
    }
  }

  @override
  void dispose() {
    widget.vm.removeListener(_onChange);
    _controller.text.removeListener(_onChange);
    _controller.text.removeListener(_controller.disarmLastChip);
    _controller.pinRevision.removeListener(_onChange);
    _controller.dispose();
    super.dispose();
  }

  void _onChange() {
    _controller.invalidateParse();
    // Text typed into a pinned picker is that key's VALUE QUERY, exactly as
    // on wide. It used to drop the pin instead, which made a pinned list
    // un-narrowable (a tag past the first 50 could not be reached) and turned
    // a custom-field value into a free-text search. Only an explicit new
    // `<key>:` hands the menu to another key.
    if (_controller.pinnedValueKey != null &&
        _controller.typedPrefixKey() != null) {
      _controller.clearPinnedValueKey();
    }
    _syncLiveSearch();
    // External clear-all reset the search to empty — reflect it in the input.
    // Gated to FREE-TEXT only (not a `key:` prefix or pinned value picker):
    // tapping a key row writes e.g. `client:` and momentarily drops focus (the
    // TextField's onTapOutside), and without this guard the branch would wipe
    // that prefix before value mode could render. Also narrowed to the empty
    // case so it can't clobber an as-you-type query mid-debounce.
    if (widget.vm.search.isEmpty &&
        _controller.parseInput().matchedKey == null &&
        _controller.pinnedValueKey == null &&
        _controller.text.text.isNotEmpty &&
        !_controller.focus.hasFocus) {
      _controller.text.clear();
    }
    setState(() {});
  }

  /// Search-as-you-type: keep `vm.search` in sync with free-text input so the
  /// live results below update as the user types. `setSearch` already
  /// debounces (250 ms), so we just forward — but only on an actual text
  /// change (tracked via [_lastSyncedSearch]), never on an incidental VM
  /// notify, which would otherwise keep resetting the debounce timer.
  /// Skipped in `key:`/value mode and when the list exposes no result tile
  /// (no live-results section to feed).
  void _syncLiveSearch() {
    if (widget.resultTile == null) return;
    // Building a filter is not a search — and starting one withdraws the
    // search that was live, as on wide. `parseInput` is pin-aware.
    if (_controller.parseInput().matchedKey != null) {
      if (_lastSyncedSearch.isNotEmpty) {
        _lastSyncedSearch = '';
        widget.vm.setSearch('');
      }
      return;
    }
    final text = _controller.text.text.trim();
    if (text == _lastSyncedSearch) return;
    _lastSyncedSearch = text;
    widget.vm.setSearch(text);
  }

  Future<void> _onSelectValue(FilterKey key, FilterValueSuggestion value) {
    // The narrow-mode sheet is a dedicated batch-edit experience
    // (full-screen modal), so we STAY in value mode after a pick — the
    // user picks multiple values, then taps back to close. Unlike wide
    // mode, there's no overlay to dismiss; dismissal happens via the
    // AppBar's back button.
    return _controller.selectValue(
      key,
      value,
      context,
      beforeAwait: () {
        // What was typed to find the value is spent; leaving it filtered the
        // list for the next pick and had to be erased by hand.
        if (_controller.pinnedValueKey != null) _controller.text.clear();
        _controller.focus.requestFocus();
      },
    );
  }

  /// Checkbox half of the split action — toggle and stay in the sheet
  /// (the sheet is already a batch-edit surface; same as `_onSelectValue`
  /// but routed through the sticky toggle for symmetry with wide mode).
  Future<void> _onToggleValue(FilterKey key, FilterValueSuggestion value) {
    // A tick made from the keyboard's Search/Done brings the whole list back
    // for the next one. A TAP leaves the narrowed list alone — resetting it
    // there reshuffled the rows under the finger that was working down them.
    if (_controller.suggestions.committingByKeyboard) {
      _controller.resetValueQuery(key);
    }
    _controller.focus.requestFocus();
    return _controller.toggleValueSticky(key, value, context);
  }

  /// Row-label half — pick only this value, then close the sheet
  /// (pick-one-and-done, consistent with wide mode closing its overlay).
  void _onPickExclusive(FilterKey key, FilterValueSuggestion value) {
    // Not awaited: the write updates the VM synchronously and then reloads,
    // and holding the sheet open for that network round-trip made "Only" feel
    // like it had not registered.
    unawaited(_controller.selectValueExclusive(key, value, context));
    unawaited(Navigator.of(context).maybePop());
  }

  void _onCommitFreeText(String value) {
    _controller.commitFreeText(value);
    // Pop straight back to the list so the user sees the full filtered list.
    // Mirrors `_onPickExclusive`. Value/key taps deliberately stay (batch-edit).
    if (mounted) unawaited(Navigator.of(context).maybePop());
  }

  /// Soft-keyboard "Search"/"Done" submit. The on-screen action key arrives
  /// as a `TextInputAction` (→ `onSubmitted`), NOT a reliable hardware
  /// `KeyEvent`, so the `Focus(onKeyEvent:)` Enter path alone was flaky.
  /// Mirror that path here: the suggestion list is always visible in the
  /// sheet, so commit the highlighted row (row 0 is `Search for <query>` when
  /// the query is non-empty); fall back to a free-text search if the menu is
  /// empty. The `!mounted` guard keeps a synthetic-ENTER + onSubmitted
  /// double-fire harmless.
  void _onSubmit() {
    if (!mounted) return;
    // In results mode the suggestion menu isn't built (so its rows aren't
    // published) and the query is already applied live — just pop to the
    // filtered list, same as the back arrow.
    if (_showingResults) {
      _onCommitFreeText(_controller.text.text);
      return;
    }
    if (_controller.suggestions.commit(expecting: _controller.inputStamp)) {
      return;
    }
    // No row took it: commit what is typed. A `<key>:<value>` the key accepts
    // becomes a chip and the sheet stays open for the next one (batch edit);
    // a free-text term is searched and the sheet pops back to the list. This
    // path used to know only the second half, so `name:acme` + Search
    // searched for the literal text `name:acme`.
    final result = _controller.commitTyped(
      context,
      beforeApply: _controller.text.clear,
    );
    if (result == TypedCommit.searched && mounted) {
      unawaited(Navigator.of(context).maybePop());
    }
  }

  /// The value header's "‹": back to the filter picker. On a phone this is
  /// the only way — a soft keyboard sends no key event for Backspace on an
  /// empty input, so a picked key used to be a dead end.
  void _onBack() {
    _controller.clearPinnedValueKey();
    _controller.dropBoxText();
    _controller.focus.requestFocus();
  }

  /// Free-text input with live results available — the sheet shows matching
  /// records instead of the suggestion menu.
  bool get _showingResults {
    final parse = _controller.parseInput();
    return widget.resultTile != null &&
        widget.onOpenRecord != null &&
        _controller.pinnedValueKey == null &&
        parse.matchedKey == null &&
        parse.query.trim().isNotEmpty;
  }

  /// Comparator / value segment tap → the dedicated [SegmentMenu] in a
  /// bottom sheet. Commits straight through the key; never touches the
  /// search text controller.
  void _openSegmentSheet(ActiveFilterChip chip, SegmentKind kind) {
    final key = chip.key;
    if (key is! ComparableFilterKey) return;
    showModalBottomSheet<void>(
      context: context,
      // The value segment's field autofocuses, so the keyboard is up before the
      // sheet has settled: pad by the inset or it opens straight behind it.
      // `isScrollControlled` goes with it because the padding comes *out of*
      // the sheet's height ceiling: that ceiling is `9/16 × height` by default
      // and is never itself reduced by the keyboard, so on a short viewport
      // (landscape phone, split-screen) 9/16 minus the inset can collapse below
      // what the value field needs. Lifting the ceiling to full height gives
      // the padding room to come out of. Trade-off, keyboard aside: the
      // effective cap becomes `SegmentMenu`'s own 360 px rather than
      // `min(360, 9/16 × height)`, so a long field list grows on viewports
      // under ~640 px tall. Nothing changes on a portrait phone.
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SafeArea(
          child: SegmentMenu(
            vm: widget.vm,
            filterKey: key,
            kind: kind,
            currentWire: chip.rawValues.single,
            onClose: () => Navigator.of(sheetContext).pop(),
          ),
        ),
      ),
    );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    // The suggestion list is always visible inside the sheet, so
    // arrow keys + Enter always navigate it.
    return _controller.handleArrowEnterBackspace(
      event,
      suggestionsActive: true,
      context: context,
    );
  }

  /// The area below the input + divider. Free-text input with live results
  /// available → a results-focused view (real tiles + "Show all results");
  /// otherwise the filter-category / value suggestion menu.
  Widget _buildBody(BuildContext context) {
    return _showingResults ? _buildResults(context) : _buildSuggestionMenu();
  }

  Widget _buildSuggestionMenu() {
    return FilterSuggestionMenu(
      vm: widget.vm,
      keys: widget.filterKeys,
      parse: _controller.parseInput(),
      controller: _controller.suggestions,
      stamp: _controller.inputStamp,
      // This sheet IS a route, so back pops it and there is no overlay to
      // close first — see `FilterSuggestionMenu.onDismiss`.
      onDismiss: null,
      onBack: _onBack,
      // What a pick means is the controller's, shared with the wide field;
      // the sheet has no overlay to open or close around it.
      onSelectKey: _controller.pickKey,
      onSelectValue: _onSelectValue,
      onToggleValue: _onToggleValue,
      onPickExclusive: _onPickExclusive,
      onPickOp: _controller.pickOp,
      onCommitFreeText: _onCommitFreeText,
      maxHeight: double.infinity,
      // Full-bleed panel below the divider — flat, not a floating
      // popup, so skip the bordered/elevated chrome.
      floating: false,
    );
  }

  /// Live matching results for the typed query. Rows are the real per-entity
  /// list tiles ([widget.resultTile]); a whole-row tap opens that record. The
  /// search is already applied to the underlying list (as-you-type), so the
  /// AppBar back arrow returns to the full filtered list — no extra commit row.
  Widget _buildResults(BuildContext context) {
    final vm = widget.vm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Thin progress while a refetch is in flight — prior results stay
        // visible underneath, so there's no blank flash between keystrokes.
        SizedBox(
          height: 2,
          child: vm.isLoadingPage
              ? const LinearProgressIndicator(minHeight: 2)
              : null,
        ),
        Expanded(child: _buildResultsList(context)),
      ],
    );
  }

  Widget _buildResultsList(BuildContext context) {
    final vm = widget.vm;
    final items = vm.items;
    if (items.isEmpty) {
      // Full spinner only when there's nothing prior to show; otherwise the
      // thin top bar covers refetches without blanking results.
      if (vm.isLoadingPage) {
        return const Center(child: CircularProgressIndicator());
      }
      return EmptyState(
        icon: Icons.search_off,
        title: context.tr('no_records_found'),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      itemBuilder: (rowContext, index) {
        final item = items[index];
        // Reuse the real tile for visuals; IgnorePointer kills its own
        // InkWell + secondary buttons so the whole row maps to one action:
        // open the record (after popping the sheet).
        return Semantics(
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.of(context).maybePop();
              widget.onOpenRecord!(vm.idOf(item));
            },
            child: IgnorePointer(
              child: widget.resultTile!(rowContext, item, index),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final active = _controller.activeChips(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: context.tr('close'),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(context.tr('filters')),
        actions: [
          if (widget.vm.hasActiveFilters)
            TextButton(
              onPressed: () {
                widget.vm.clearAllFilters();
                _controller.text.clear();
              },
              child: Text(context.tr('clear_all')),
            ),
        ],
      ),
      body: Column(
        // Stretch so the input band + bordered box fill the width; otherwise
        // the box sizes to its (short) content and the Column centers it,
        // leaving big gaps on both sides.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: tokens.surface,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Container(
              // Fill the band width (the chips + input left-align inside) so
              // the box spans the sheet like the results below it.
              width: double.infinity,
              decoration: BoxDecoration(
                color: tokens.surfaceAlt,
                borderRadius: BorderRadius.circular(InRadii.r1),
                border: Border.all(color: tokens.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in active)
                    FilterTokenChip(
                      token: c.token,
                      armed:
                          identical(c, active.last) &&
                          _controller.lastChipArmed,
                      onRemove: () => _controller.removeChip(c, context),
                      // Narrow mode is a bottom sheet — no anchor math, so
                      // the reported rect is unused here.
                      onTap: (_) => _controller.editChip(c),
                      // Comparator / value segments open the same
                      // dedicated SegmentMenu as wide mode, hosted in a
                      // bottom sheet (no anchor math). Commits via
                      // changeOp / addValue — never writes search text.
                      onComparatorTap: c.key.supportedOps.isNotEmpty
                          ? (_) => _openSegmentSheet(c, SegmentKind.comparator)
                          : null,
                      onValueTap: c.key.supportedOps.isNotEmpty
                          ? (_) => _openSegmentSheet(c, SegmentKind.value)
                          : null,
                    ),
                  IntrinsicWidth(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 80),
                      child: Focus(
                        onKeyEvent: _handleKey,
                        child: TextField(
                          controller: _controller.text,
                          focusNode: _controller.focus,
                          // Soft keyboards deliver the action key as a
                          // TextInputAction, not a hardware KeyEvent — wire
                          // onSubmitted so "Done"/"Search" reliably commits
                          // (the `Focus(onKeyEvent:)` path catches only the
                          // hardware key, which IMEs emit inconsistently).
                          // Search queries are names and numbers, not prose — iOS
                          // autocorrecting "Acme" to "Acne" mid-search is the failure.
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _onSubmit(),
                          decoration: InputDecoration(
                            hintText: active.isEmpty
                                ? context.tr(widget.hintKey)
                                : null,
                            // See `token_search_field.dart` for why every
                            // state-specific border has to be overridden —
                            // the global `InputDecorationTheme` paints a
                            // rounded outline on the empty input otherwise.
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            filled: false,
                            isCollapsed: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }
}
