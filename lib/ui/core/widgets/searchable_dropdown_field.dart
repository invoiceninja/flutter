import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/escape_observer.dart';

/// Generic text-filter dropdown for long lists (countries, currencies,
/// industries, …). Replaces `DropdownButtonFormField` where scrolling through
/// every option is painful.
///
/// The caller owns the list and the projections — the widget has no knowledge
/// of `Services` or `statics`, so it stays reusable for any `T` (statics
/// values, gateway configs, freezed models, anything).
///
/// ## Opening a picker that already has a value
///
/// `RawAutocomplete` filters by the field's text, and the text of an untouched
/// picker IS the selected item's own name — so filtering by it would offer only
/// the value the user already has, and the only way out would be the ✕ (which
/// also clears the value). That was invoiceninja/flutter#34. Two rules fix it:
///
///  * [_isPristine] — while the text still equals the committed item's label the
///    user has typed nothing, so the query counts as empty and the whole list is
///    offered.
///  * [_reopenOptions] — `RawAutocomplete` recomputes only on a *text* change,
///    so a tap after a selection would reopen nothing; the `onTap` hook bounces
///    the text to force a recompute without changing what's on screen.
///
/// The committed item leads that list and carries a check, so it stays visible
/// in a 250-row list and the default highlight is the current value rather than
/// whatever happens to sort first.
///
/// Typical use:
///
/// ```dart
/// SearchableDropdownField<Country>(
///   label: context.tr('country'),
///   items: countries,                       // pre-sorted by caller
///   initialValue: countries.firstWhereOrNull((c) => c.id == current),
///   displayString: (c) => c.name,
///   idOf: (c) => c.id,
///   onChanged: (c) => vm.set(c?.id ?? ''),
/// );
/// ```
class SearchableDropdownField<T extends Object> extends StatefulWidget {
  const SearchableDropdownField({
    super.key,
    required this.label,
    required this.items,
    required this.initialValue,
    required this.displayString,
    required this.idOf,
    required this.onChanged,
    this.emptyHintKey,
    this.errorText,
    this.maxResults = 50,
    this.idleResults = 20,
    this.footerBuilder,
    this.optionLeadingBuilder,
  });

  /// Resolved (already-translated) field label.
  final String label;

  /// Source list. The caller is responsible for sorting.
  final List<T> items;

  /// Current selection (caller resolves id → item).
  final T? initialValue;

  /// Visible label for a given item.
  final String Function(T) displayString;

  /// Stable id used to detect external changes to [initialValue].
  final String Function(T) idOf;

  /// Fires with the new selection (or `null` when cleared).
  final ValueChanged<T?> onChanged;

  /// Localization key used as the placeholder label when [items] is empty
  /// (typically while statics is still loading). Defaults to `'loading'`.
  final String? emptyHintKey;

  /// Server-side validation error to surface beneath the field (e.g. a 422
  /// from `host.fieldErrors[apiKey]`). `null` hides the slot.
  final String? errorText;

  /// Maximum items shown while filtering.
  final int maxResults;

  /// Items shown when the field is focused with an empty query.
  final int idleResults;

  /// Optional widget pinned below the options list inside the popover. Use
  /// for "Manage…" or "+ New…" links that belong with the dropdown rather
  /// than below it. The builder fires once per popover render.
  final WidgetBuilder? footerBuilder;

  /// Optional glyph rendered before an option's label — a task status's colour
  /// dot, say. Also used as the field's `prefixIcon` for the committed item, so
  /// the collapsed and open states match. Null keeps the plain text row.
  final Widget Function(BuildContext, T)? optionLeadingBuilder;

  @override
  State<SearchableDropdownField<T>> createState() =>
      _SearchableDropdownFieldState<T>();
}

class _SearchableDropdownFieldState<T extends Object>
    extends State<SearchableDropdownField<T>> {
  /// Row height at 1.0 text scale on a pointer platform. Touch grows it to
  /// [InSizes.touchTarget]; both scale with the user's text size — see
  /// [_optionExtent].
  static const double _baseOptionExtent = 40.0;

  /// Above this many options a touch user still needs to type, so the soft
  /// keyboard stays. At or below it the picker behaves as a plain list.
  ///
  /// Deliberately below the "~10 items" figure the rest of the app uses for
  /// "short fixed enum": at 10 this straddles pickers that mean to be typed
  /// into — the import/export column mapper documents "staying type-to-search",
  /// and the design pickers sit close enough that one extra custom design would
  /// silently flip the behaviour. Six covers the case this exists for (a
  /// company's four task statuses) without reaching them.
  static const int _noKeyboardMaxItems = 6;

  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final ScrollController _optionsScrollController;
  T? _committed;

  /// The live highlight from the options overlay. Captured as the *notifier*
  /// rather than its value: `AutocompleteHighlightedOption` is an
  /// `InheritedNotifier`, so a build-captured index lags a frame behind the
  /// arrow keys and an Enter in the same event batch would act on the wrong
  /// row.
  ValueNotifier<int>? _highlight;

  /// The options currently rendered in the popover, so [_highlightIsCommitted]
  /// can map the highlight index back to an item.
  List<T> _visibleOptions = const [];

  /// True while the options overlay is mounted; cleared on blur and on commit.
  bool _optionsVisible = false;

  /// Set by [_reopenOptions] so the next popover render drops a carried-over
  /// highlight back to row 0. `_updateHighlight` only *clamps* the previous
  /// index (`autocomplete.dart`), so without this an earlier arrow-down would
  /// still be highlighted the next time the list opens — and row 0 being the
  /// committed item is what makes Enter safe.
  bool _resetHighlight = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue;
    _committed = initial;
    _controller = TextEditingController(
      text: initial == null ? '' : widget.displayString(initial),
    );
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
    _optionsScrollController = ScrollController();
  }

  @override
  void didUpdateWidget(SearchableDropdownField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Resync when the parent's [initialValue] changes (e.g. statics finished
    // loading async, or another part of the form reset the field). Skip while
    // focused — we'd be yanking the cursor mid-edit.
    final oldInitial = oldWidget.initialValue;
    final newInitial = widget.initialValue;
    final oldId = oldInitial == null ? null : oldWidget.idOf(oldInitial);
    final newId = newInitial == null ? null : widget.idOf(newInitial);
    if (oldId != newId && !_focusNode.hasFocus) {
      _committed = widget.initialValue;
      final expected = _committed == null
          ? ''
          : widget.displayString(_committed!);
      if (_controller.text != expected) {
        _controller.text = expected;
      }
    }
  }

  void _onFocusChange() {
    _optionsVisible = false;
    // On blur, snap the visible text back to the committed item's name —
    // otherwise the user could leave half-typed garbage in the field that
    // doesn't reflect any committed id.
    if (_focusNode.hasFocus) return;
    final expected = _committed == null
        ? ''
        : widget.displayString(_committed!);
    if (_controller.text != expected) {
      _controller.text = expected;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    _optionsScrollController.dispose();
    super.dispose();
  }

  /// True while [text] is still whatever the committed selection put there —
  /// i.e. the user has typed nothing, so there is no query to filter by.
  bool _isPristine(String text) {
    final committed = _committed;
    final raw = text.trim();
    if (committed == null) return raw.isEmpty;
    return raw == widget.displayString(committed).trim();
  }

  /// The options for [text], and the single place that decides whether there
  /// is a query at all. Materialised rather than lazy so the caller can ask
  /// whether it came back empty without re-iterating it.
  List<T> _optionsFor(String text) {
    // While the field still shows the committed item's own name the user has
    // typed nothing, so there is no query — offer the whole list rather than
    // the one item they already have (invoiceninja/flutter#34).
    if (_isPristine(text)) return _idleOptions();
    final q = text.trim().toLowerCase();
    if (q.isEmpty) return _idleOptions();
    return widget.items
        .where((it) => widget.displayString(it).toLowerCase().contains(q))
        .take(widget.maxResults)
        .toList(growable: false);
  }

  /// Options for an empty query. The committed item leads so it stays visible
  /// even in a 250-country list, and so the default highlight (row 0) is the
  /// CURRENT value — Enter, or Android's soft-keyboard "Done", then lands on
  /// what is already selected instead of whatever sorts first.
  List<T> _idleOptions() {
    final committed = _committed;
    if (committed == null) {
      return widget.items.take(widget.idleResults).toList(growable: false);
    }
    final id = widget.idOf(committed);
    final present = widget.items.any((it) => widget.idOf(it) == id);
    // Injecting an item that ISN'T in `items` is only right when the parent
    // still says it is the selection — that's `tax_rate_picker`'s synthetic
    // legacy rate. The "add to a chip list" pickers keep `initialValue: null`
    // forever and drop the added item OUT of `items`, and `_committed` is never
    // reset back to null (didUpdateWidget compares old-id vs new-id, both
    // null), so without this we would re-offer, and pre-highlight, a value the
    // user has already added.
    final initial = widget.initialValue;
    final parentAgrees = initial != null && widget.idOf(initial) == id;
    if (!present && !parentAgrees) {
      return widget.items.take(widget.idleResults).toList(growable: false);
    }
    return <T>[
      committed,
      ...widget.items.where((it) => widget.idOf(it) != id),
    ].take(widget.idleResults).toList(growable: false);
  }

  /// Reopen the options on a tap that isn't editing anything.
  ///
  /// `RawAutocomplete` recomputes its options only when the field TEXT changes
  /// (`_onChangedField`, autocomplete.dart), so tapping a field whose value was
  /// just picked reopens nothing at all. Bounce the value through a different
  /// string and back within the same frame: two synchronous writes, the newer
  /// one supersedes the older, and the visible text never changes. Select-all
  /// so typing replaces the value rather than appending to it.
  void _reopenOptions() {
    // A mid-edit tap is the user placing a caret in their own query, and a tap
    // mid-composition already has live options — leave both alone.
    if (!_isPristine(_controller.text)) return;
    if (_controller.value.isComposingRangeValid) return;
    final text = _controller.text;
    _resetHighlight = true;
    // A TextEditingController is a ValueNotifier: writing an identical value
    // notifies nobody, so an already-empty field needs a non-empty sentinel or
    // the reopen is a no-op (that's the state Escape leaves behind).
    _controller.value = TextEditingValue(text: text.isEmpty ? ' ' : '');
    _controller.value = TextEditingValue(
      text: text,
      // Select-all only where typing is possible. On a keyboard-less picker it
      // would be a highlight the user can't act on, over a field with no caret
      // to explain it — and it invites the selection toolbar.
      selection: _suppressKeyboard
          ? TextSelection.collapsed(offset: text.length)
          : TextSelection(baseOffset: 0, extentOffset: text.length),
    );
  }

  /// Row height, scaled with the user's text size. A fixed extent clips Inter
  /// Tight's descenders once UI text scale passes ~1.14 (Settings → Device
  /// Settings feeds an app-wide `textScaler`).
  double _optionExtent(BuildContext context) => MediaQuery.textScalerOf(
    context,
  ).scale(Env.isTouchPrimary ? InSizes.touchTarget : _baseOptionExtent);

  /// Whether the keyboard cursor is sitting on the already-committed row, in
  /// which case Enter should dismiss rather than "select" (see [_onSubmitted]).
  bool get _highlightIsCommitted {
    final committed = _committed;
    if (committed == null || !_optionsVisible) return false;
    final index = _highlight?.value ?? 0;
    if (index < 0 || index >= _visibleOptions.length) return false;
    return widget.idOf(_visibleOptions[index]) == widget.idOf(committed);
  }

  void _onSubmitted(VoidCallback onFieldSubmitted) {
    // Enter, and Android's soft-keyboard "Done", mean "I'm finished" — so on
    // the value the field already holds they dismiss. Deliberately *not*
    // symmetric with a tap on that row, which is an explicit choice and does
    // re-commit: letting Done re-commit would let it silently re-add the last
    // item on a chip-adder.
    if (_highlightIsCommitted) {
      _focusNode.unfocus();
      return;
    }
    onFieldSubmitted();
  }

  void _scrollHighlightedIntoView(
    int highlightedIndex,
    int optionCount,
    double optionExtent,
  ) {
    if (highlightedIndex < 0 || highlightedIndex >= optionCount) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_optionsScrollController.hasClients) return;
      final position = _optionsScrollController.position;
      final target = highlightedIndex * optionExtent;
      final viewport = position.viewportDimension;
      final current = position.pixels;
      double? newOffset;
      if (target < current) {
        newOffset = target;
      } else if (target + optionExtent > current + viewport) {
        newOffset = target + optionExtent - viewport;
      }
      if (newOffset != null) {
        _optionsScrollController.animateTo(
          newOffset.clamp(position.minScrollExtent, position.maxScrollExtent),
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(InRadii.r1),
      borderSide: BorderSide(color: tokens.border),
    );

    // Statics not loaded yet — render a disabled placeholder so layout
    // doesn't shift when the list arrives.
    if (widget.items.isEmpty) {
      // This branch unmounts `RawAutocomplete`, which disposes the highlight
      // notifier we borrowed — drop the reference so a post-frame callback
      // can't write to it. Our own `mounted` says nothing about its lifetime.
      _highlight = null;
      _optionsVisible = false;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: InSpacing.xs),
        // RawAutocomplete (below) provides no Material around its field,
        // unlike Flutter's Autocomplete — so this widget supplies its own
        // so hosts without a Material ancestor don't throw "No Material
        // widget found". Transparency = no visual change.
        child: Material(
          type: MaterialType.transparency,
          child: TextField(
            enabled: false,
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: context.tr(widget.emptyHintKey ?? 'loading'),
              errorText: widget.errorText,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: InSpacing.md(context),
                vertical: 14,
              ),
              border: border,
              disabledBorder: border,
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Size the options popover to the field's own width so it can't
        // overflow a narrow phone; cap at 360 on wide screens (the original
        // desktop max). The SDK anchors it to the field's leading edge, so
        // width <= field width never spills past the far edge.
        final fieldWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 360.0;
        final popoverWidth = math.min(fieldWidth, 360.0);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: InSpacing.xs),
          child: RawAutocomplete<T>(
            textEditingController: _controller,
            focusNode: _focusNode,
            displayStringForOption: widget.displayString,
            // Flip above the field when there's more room there. Left at the
            // `.down` default, a picker low on a phone screen gets whatever
            // space is below it, floored at a 48px sliver — invisible while the
            // popover held one row, useless now that it holds the whole list.
            optionsViewOpenDirection: OptionsViewOpenDirection.mostSpace,
            optionsBuilder: (value) {
              final options = _optionsFor(value.text);
              // An empty list unmounts the overlay, and `optionsViewBuilder`
              // then never runs again to say so — without this `_optionsVisible`
              // latches true, and a later Enter would take the "dismiss the
              // current value" path and blur, throwing away the query the user
              // is still typing.
              if (options.isEmpty) _optionsVisible = false;
              return options;
            },
            // setState so the field rebuilds: `_select` doesn't rebuild us, and
            // the leading glyph is read from `_committed` during the field
            // build — without this it lags a parent rebuild behind the text.
            onSelected: (item) {
              setState(() {
                _committed = item;
                _optionsVisible = false;
              });
              widget.onChanged(item);
            },
            fieldViewBuilder:
                (context, textController, focusNode, onFieldSubmitted) {
                  final committed = _committed;
                  final prefix = committed == null
                      ? null
                      : widget.optionLeadingBuilder?.call(context, committed);
                  // Own Material — RawAutocomplete (unlike Autocomplete) wraps
                  // its field in none, so a host without a Material ancestor
                  // throws "No Material widget found". Transparency = no visual
                  // change.
                  return Material(
                    type: MaterialType.transparency,
                    child: EscapeObserver(
                      // `DismissIntent` hides the overlay without touching
                      // focus, so nothing else would tell us it is gone.
                      onEscape: () => _optionsVisible = false,
                      child: TextField(
                        controller: textController,
                        focusNode: focusNode,
                        onTap: _reopenOptions,
                        onSubmitted: (_) => _onSubmitted(onFieldSubmitted),
                        // A short list on a touch device needs no typing, so keep
                        // the soft keyboard (which would cover the list) away.
                        // `TextInputType.none` rather than `readOnly` — readOnly
                        // also tears down the text input connection.
                        keyboardType: _suppressKeyboard
                            ? TextInputType.none
                            : null,
                        showCursor: _suppressKeyboard ? false : null,
                        // Nothing to select on a field that can't be typed into,
                        // and leaving it on lets a long-press raise the copy
                        // toolbar over what is really just a button.
                        enableInteractiveSelection: !_suppressKeyboard,
                        decoration: InputDecoration(
                          labelText: widget.label,
                          errorText: widget.errorText,
                          labelStyle: theme.textTheme.bodyMedium?.copyWith(
                            color: tokens.ink3,
                          ),
                          floatingLabelStyle: theme.textTheme.bodySmall
                              ?.copyWith(color: tokens.ink2),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: InSpacing.md(context),
                            vertical: 14,
                          ),
                          border: border,
                          enabledBorder: border,
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(InRadii.r1),
                            borderSide: BorderSide(
                              color: tokens.accent,
                              width: 1.5,
                            ),
                          ),
                          prefixIcon: prefix == null
                              ? null
                              : Padding(
                                  padding: EdgeInsetsDirectional.only(
                                    start: InSpacing.md(context),
                                    end: InSpacing.sm,
                                  ),
                                  child: prefix,
                                ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 0,
                            minHeight: 0,
                          ),
                          suffixIcon: _buildSuffix(
                            context,
                            tokens,
                            textController,
                          ),
                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 0,
                            minHeight: 0,
                          ),
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: tokens.ink,
                        ),
                      ),
                    ),
                  );
                },
            optionsViewBuilder: (context, onSelected, options) {
              final highlightedIndex = AutocompleteHighlightedOption.of(
                context,
              );
              // Hold the notifier, not the index: it is an `InheritedNotifier`,
              // so a value captured here is a frame behind the arrow keys, and
              // an Enter in the same event batch would act on the wrong row.
              _highlight = context
                  .dependOnInheritedWidgetOfExactType<
                    AutocompleteHighlightedOption
                  >()
                  ?.notifier;
              _visibleOptions = options.toList(growable: false);
              _optionsVisible = true;
              final resetting = _resetHighlight;
              if (resetting) {
                _resetHighlight = false;
                // Post-frame: writing to the notifier during build would
                // rebuild its dependents mid-build. Re-read `_highlight` there
                // rather than closing over it — RawAutocomplete owns it and can
                // be unmounted (disposing it) while this State survives.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _highlight?.value = 0;
                });
              }
              final optionExtent = _optionExtent(context);
              // Skip while resetting: this build still carries the old
              // highlight, so scrolling now would animate to the row the user
              // last arrowed to and then back to the top on the next build.
              if (!resetting) {
                _scrollHighlightedIntoView(
                  highlightedIndex,
                  options.length,
                  optionExtent,
                );
              }
              final footer = widget.footerBuilder?.call(context);
              final committed = _committed;
              final committedId = committed == null
                  ? null
                  : widget.idOf(committed);
              // By index, not by id: a caller can hand us duplicates (a custom
              // field defined as `Gold,Silver,Gold`), and marking every match
              // would show two "current" rows.
              final committedIndex = committedId == null
                  ? -1
                  : _visibleOptions.indexWhere(
                      (it) => widget.idOf(it) == committedId,
                    );
              // No Align of our own: RawAutocomplete already wraps this in a
              // tightly-constrained Align that flips between topStart and
              // bottomStart. A bare Align here would expand to fill that box
              // (it only shrink-wraps under an infinite constraint), leaving
              // the SDK's alignment nothing to move — an upward popover would
              // detach and render at the top of the screen.
              return Material(
                elevation: 4,
                // Bordered, not just elevated: in dark mode the popover's
                // surface is near-black against a near-black page, and
                // elevation alone leaves the (now full-length) list floating
                // with no visible edge.
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(InRadii.r2),
                  side: BorderSide(color: tokens.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 280,
                    maxWidth: popoverWidth,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          controller: _optionsScrollController,
                          itemExtent: optionExtent,
                          itemCount: options.length,
                          itemBuilder: (context, i) {
                            final item = options.elementAt(i);
                            final isHighlighted = i == highlightedIndex;
                            final label = widget.displayString(item);
                            final isCommitted = i == committedIndex;
                            final leading = widget.optionLeadingBuilder?.call(
                              context,
                              item,
                            );
                            return Semantics(
                              button: true,
                              inMutuallyExclusiveGroup: true,
                              selected: isCommitted,
                              child: Container(
                                color: isHighlighted ? tokens.accentSoft : null,
                                child: InkWell(
                                  // Re-picking the current value can't go
                                  // through `onSelected`: `_select` early-
                                  // returns on an unchanged selection *before*
                                  // hiding the overlay, so the tap would be
                                  // dead and the popover would stay open.
                                  // Notify and close here instead — several
                                  // callers treat a re-pick as a real command
                                  // (re-seed an allocation's auto-filled
                                  // amount, re-bind a stream, retry a change
                                  // their own handler vetoed, re-add an item
                                  // whose chip was deleted), and every handler
                                  // is idempotent for a same-value call.
                                  onTap: isCommitted
                                      ? () {
                                          _optionsVisible = false;
                                          widget.onChanged(item);
                                          _focusNode.unfocus();
                                        }
                                      : () => onSelected(item),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: InSpacing.md(context),
                                      vertical: InSpacing.sm,
                                    ),
                                    child: Row(
                                      children: [
                                        if (leading != null) ...[
                                          leading,
                                          const SizedBox(width: InSpacing.sm),
                                        ],
                                        Expanded(
                                          child: Text(
                                            label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(color: tokens.ink),
                                          ),
                                        ),
                                        // A blank option (the custom-field
                                        // "none" row) would show a bare tick.
                                        if (isCommitted && label.isNotEmpty)
                                          Icon(
                                            Icons.check,
                                            size: 16,
                                            color: tokens.accent,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (footer != null) ...[
                        Divider(height: 1, color: tokens.border),
                        footer,
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// True when this picker should behave as a plain list rather than a text
  /// field: a touch device with few enough options that typing buys nothing.
  bool get _suppressKeyboard =>
      Env.isTouchPrimary && widget.items.length <= _noKeyboardMaxItems;

  /// Clear button (when there's something to clear) plus the dropdown arrow.
  ///
  /// Rebuilt from the controller rather than the enclosing build:
  /// `RawAutocomplete` does not `setState` when the text changes (it drives the
  /// overlay through an `OverlayPortalController` and passes the same field
  /// widget straight through), so a suffix chosen during the parent build goes
  /// stale as the user types.
  ///
  /// The arrow is what tells the user this is a picker at all — without it, a
  /// populated field offers only an ✕, and "delete the value, then choose" is a
  /// reasonable reading of that.
  Widget _buildSuffix(
    BuildContext context,
    InTheme tokens,
    TextEditingController textController,
  ) {
    final touch = Env.isTouchPrimary;
    final buttonSize = touch ? InSizes.touchTarget : 32.0;
    return ListenableBuilder(
      listenable: textController,
      builder: (context, _) {
        // Text, not `_committed != null`: `T` can be `String`, and a picker
        // whose "unset" option is the empty string (dropdown custom fields)
        // has a non-null committed value with nothing to clear.
        final canClear = textController.text.isNotEmpty;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canClear)
              IconButton(
                tooltip: context.tr('clear'),
                icon: Icon(Icons.close, size: 16, color: tokens.ink3),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tightFor(
                  width: buttonSize,
                  height: buttonSize,
                ),
                // `padded` (the iOS/Android default) would inflate the layout
                // box to kMinInteractiveDimension and ignore the constraints
                // above, stretching the dense field.
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  textController.clear();
                  setState(() {
                    _committed = null;
                    _optionsVisible = false;
                  });
                  widget.onChanged(null);
                },
              ),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: InSpacing.sm),
              child: Icon(Icons.arrow_drop_down, size: 20, color: tokens.ink3),
            ),
          ],
        );
      },
    );
  }
}
