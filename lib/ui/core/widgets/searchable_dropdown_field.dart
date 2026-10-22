import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/escape_observer.dart';
import 'package:admin/ui/core/widgets/picker_dismissal.dart';
import 'package:admin/utils/search_fold.dart';

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
    this.onCreateRequested,
    this.createLabelKey,
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
  /// for "Manage…" links that belong with the dropdown rather than below it —
  /// not for "+ New…": the popover unmounts when nothing matches, so a footer
  /// is unreachable for the one query create exists for. That is
  /// [onCreateRequested]. The builder fires once per popover render.
  final WidgetBuilder? footerBuilder;

  /// Optional glyph rendered before an option's label — a task status's colour
  /// dot, say. Also used as the field's `prefixIcon` for the committed item, so
  /// the collapsed and open states match. Null keeps the plain text row.
  final Widget Function(BuildContext, T)? optionLeadingBuilder;

  /// Opt-in inline create. When set, the popover carries a pinned "New …" /
  /// `Create "«query»"` row that calls this with the typed query (empty for an
  /// untouched field) and commits whatever it resolves to; null means
  /// cancelled. The caller owns the create UI, the permission gate (pass null
  /// to hide the row) and duplicate checks — see `docs/pickers.md`.
  ///
  /// It also keeps an empty [items] live rather than a disabled placeholder,
  /// since the create row is something to choose. Must handle an empty query:
  /// on touch a list of ≤ 6 items suppresses the keyboard, so the empty-query
  /// row is the only one reachable there.
  final Future<T?> Function(BuildContext context, String query)?
  onCreateRequested;

  /// Translation key for the create row when the query is empty
  /// (`new_vendor`, say). Defaults to `create`.
  final String? createLabelKey;

  @override
  State<SearchableDropdownField<T>> createState() =>
      _SearchableDropdownFieldState<T>();
}

/// What the internal `RawAutocomplete` actually carries.
///
/// The widget's public generic stays `T`; this wrapper exists so the option
/// list can hold something that is **not** a `T` — the synthetic "Create «x»"
/// row. That row is what keeps the list non-empty, and Flutter's
/// `RawAutocomplete` only mounts its options overlay while the list is
/// non-empty (`_canShowOptionsView`), which is why a create affordance living
/// purely in `optionsViewBuilder` is unreachable for a query that matches
/// nothing — the one case it exists for.
///
/// The create row is [_CreateOpt], opted into by
/// [SearchableDropdownField.onCreateRequested].
sealed class _Opt<T extends Object> {
  const _Opt();
}

/// A real option.
///
/// **`==` delegates to [item], which keeps this a faithful no-op.**
/// `RawAutocomplete._select` early-returns on `nextSelection == _selection`
/// (`autocomplete.dart`), and before this wrapper existed that comparison was
/// the caller's own `T` equality — freezed value equality, `String` equality,
/// or identity, as each of the ~124 call sites dictates. A wrapper with no `==`
/// is a fresh instance per build, so the early return would silently stop
/// firing everywhere.
///
/// Delegate to [item], **not** to `idOf(item)`. For `T = String` the two are
/// the same function — every such call site passes the identity projection — so
/// that is not the case to reason from. The difference shows on a freezed `T`
/// with an id-only projection (`Currency`, `Design`, `TaxRate`, `Country`),
/// where two instances can share an id and differ elsewhere: there `idOf` is
/// *coarser* and would early-return where `==` would not.
///
/// Note what this faithfully preserves rather than fixes: with two options
/// sharing a display label the SDK's `_selection` can hold A while `_committed`
/// holds B, and tapping A's row then hits the early return and does nothing.
/// Pre-existing; out of scope for a no-op refactor.
final class _ItemOpt<T extends Object> extends _Opt<T> {
  const _ItemOpt(this.item);

  final T item;

  @override
  bool operator ==(Object other) => other is _ItemOpt<T> && item == other.item;

  @override
  int get hashCode => item.hashCode;
}

/// The synthetic "Create «query»" row — always last, so the default highlight
/// stays on the best real match. Identity equality on purpose: it is a fresh
/// instance per options build, which is why it must never be routed through
/// `RawAutocomplete._select` (see [_SearchableDropdownFieldState._handleCreate]).
final class _CreateOpt<T extends Object> extends _Opt<T> {
  const _CreateOpt(this.query);

  /// The trimmed query; empty renders the plain "New …" row.
  final String query;
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
  List<_Opt<T>> _visibleOptions = const [];

  /// True while the options overlay is mounted; cleared on blur and on commit.
  bool _optionsVisible = false;

  /// True while [SearchableDropdownField.onCreateRequested] is in flight —
  /// the re-entrancy guard a double Enter / click would otherwise get past.
  bool _creating = false;

  /// Set across a create so the blur it causes doesn't snap the typed query
  /// away before a cancel can restore it.
  bool _suppressBlurSnap = false;

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
    // Cleared on focus *gain* as well as loss, and deliberately ABOVE the early
    // return below: `_reopenOptions`' toggle reads this flag, so a stale `true`
    // carried into a fresh focus would make the first tap close a popover that
    // isn't there. Don't tidy it under the `hasFocus` guard.
    _optionsVisible = false;
    // On blur, snap the visible text back to the committed item's name —
    // otherwise the user could leave half-typed garbage in the field that
    // doesn't reflect any committed id.
    if (_focusNode.hasFocus || _suppressBlurSnap) return;
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
  /// is a query at all — plus whether some item's name IS the query, which
  /// hides the create row. Materialised rather than lazy so the caller can ask
  /// whether it came back empty without re-iterating it.
  (List<T>, bool) _optionsFor(String text) {
    // While the field still shows the committed item's own name the user has
    // typed nothing, so there is no query — offer the whole list rather than
    // the one item they already have (invoiceninja/flutter#34).
    if (_isPristine(text)) return (_idleOptions(), false);
    final q = foldSearchText(text.trim());
    if (q.isEmpty) return (_idleOptions(), false);
    if (widget.onCreateRequested == null) {
      // Lazy: stops at [maxResults] matches, which is all a plain picker needs.
      final matches = widget.items
          .where((it) => foldSearchText(widget.displayString(it)).contains(q))
          .take(widget.maxResults)
          .toList(growable: false);
      return (matches, false);
    }
    // A creating picker must look at every item — an exact match anywhere
    // hides the create row, so it must also be SHOWN, or a name past the 50th
    // partial match would be neither listed nor creatable. Exact matches lead,
    // the rest keep their order. The names are folded once per `items` list
    // ([_foldedNames]), so a keystroke over a 5,000-row vendor list costs
    // string compares, not 5,000 folds.
    final folded = _foldedNames;
    final exact = <T>[];
    final partial = <T>[];
    for (var i = 0; i < widget.items.length; i++) {
      final name = folded[i];
      if (name == q) {
        exact.add(widget.items[i]);
      } else if (partial.length < widget.maxResults && name.contains(q)) {
        partial.add(widget.items[i]);
      }
    }
    return (
      [...exact, ...partial].take(widget.maxResults).toList(growable: false),
      exact.isNotEmpty,
    );
  }

  List<T>? _foldedFor;
  List<String> _folded = const [];

  /// Every item's display name, folded and trimmed — recomputed only when the
  /// parent hands over a different `items` list. Hosts rebuild per keystroke
  /// but pass the same list instance until their stream emits.
  List<String> get _foldedNames {
    if (!identical(_foldedFor, widget.items)) {
      _foldedFor = widget.items;
      _folded = [
        for (final it in widget.items)
          foldSearchText(widget.displayString(it)).trim(),
      ];
    }
    return _folded;
  }

  /// The single place `T` becomes `_Opt<T>`. Keeping it here is what lets
  /// [_optionsFor] and [_idleOptions] — and the hoist rules they encode — stay
  /// exactly as they were.
  List<_Opt<T>> _wrap(List<T> items, String text, {required bool hasExact}) => [
    for (final it in items) _ItemOpt<T>(it),
    if (_offersCreate(text, hasExact: hasExact))
      _CreateOpt<T>(_createQuery(text)),
  ];

  /// The query a create row built from [text] carries — empty while the field
  /// is untouched, so tapping a populated field offers "New Vendor" rather than
  /// "Create «the vendor it already holds»".
  String _createQuery(String text) => _isPristine(text) ? '' : text.trim();

  /// Whether [text] earns a create row. Not when an item's folded name is
  /// the query ([hasExact], from [_optionsFor]) — that row leads the list, and
  /// offering a second record with the same name is how duplicates get made.
  bool _offersCreate(String text, {required bool hasExact}) =>
      widget.onCreateRequested != null && !_creating && !hasExact;

  String _createRowLabel(BuildContext context, String query) => query.isEmpty
      ? context.tr(widget.createLabelKey ?? 'create')
      : '${context.tr('create')} "$query"';

  /// True when the parent still names [_committed] as its selection.
  ///
  /// False for the "add to a chip list" callers (`MultiEntityPicker`,
  /// `multi_product_picker`, the custom-labels screen): they keep
  /// `initialValue: null` forever and drop the picked item OUT of `items`, and
  /// `_committed` is never reset back to null (`didUpdateWidget` compares
  /// old-id vs new-id, both null) — so after an add it holds a value the parent
  /// has never agreed to, and the field text still shows that value's label.
  ///
  /// Two things read it, for the same underlying reason. [_idleOptions] won't
  /// hoist (or pre-highlight) a value the user has already added. And the ✕
  /// won't treat clearing as a *commit*: at those call sites `onChanged(null)`
  /// is explicitly discarded, so the ✕ means only "clear the leftover label",
  /// and dropping focus there would cost a tap and the keyboard on every
  /// subsequent add. It fails safe — a host that hasn't propagated its pick yet
  /// simply keeps focus, which is what the field did before either rule existed.
  bool get _parentOwnsCommitted {
    final committed = _committed;
    final initial = widget.initialValue;
    if (committed == null || initial == null) return false;
    return widget.idOf(initial) == widget.idOf(committed);
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
    // legacy rate. See [_parentOwnsCommitted] for the adder case this excludes.
    final parentAgrees = _parentOwnsCommitted;
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
    // A keyboard-less picker IS the dropdown button — `showCursor: false` and
    // `enableInteractiveSelection: false`, so there is no caret to place — and a
    // button you cannot un-press is the odd thing on a phone, where the field is
    // often the only part of the screen the popover doesn't cover. Toggle it
    // shut. A typable field keeps the tap for the caret. Benign if
    // `_optionsVisible` ever goes stale: one tap does nothing, the next reopens.
    if (_suppressKeyboard && _optionsVisible) {
      _focusNode.unfocus();
      return;
    }
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
    // A `switch`, not an `is` test, so a new `_Opt` subclass is a COMPILE
    // error here. The create row answers `false`, which is safe only because
    // `_onSubmitted` checks [_highlightIsCreateRow] first — otherwise Enter
    // would reach `onFieldSubmitted()` -> `_select(createOpt)`, the one call
    // `docs/pickers.md` says a create row must never go through.
    return switch (_visibleOptions[index]) {
      _ItemOpt<T>(:final item) => widget.idOf(item) == widget.idOf(committed),
      _CreateOpt<T>() => false,
    };
  }

  /// Whether Enter would land on the create row. Gated on [_optionsVisible]:
  /// Escape hides the overlay without touching focus or text, and a stale
  /// highlight must not turn the next Enter into a create the user dismissed.
  bool get _highlightIsCreateRow {
    if (!_optionsVisible) return false;
    final index = _highlight?.value ?? 0;
    if (index < 0 || index >= _visibleOptions.length) return false;
    return _visibleOptions[index] is _CreateOpt<T>;
  }

  /// Runs the caller's create UI for [query] and commits what it returns.
  ///
  /// Reached from the create row's `InkWell.onTap` and from the Enter
  /// interceptor — never via `onSelected` except as a backstop, because
  /// `RawAutocomplete._select` early-returns on an unchanged selection and the
  /// row would go dead after one cancelled create. [restoreText] overrides what
  /// a cancel puts back (the backstop path has already overwritten the field).
  Future<void> _handleCreate(String query, {String? restoreText}) async {
    final onCreate = widget.onCreateRequested;
    if (_creating || onCreate == null) return;
    final restore = restoreText ?? _controller.text;
    setState(() {
      _creating = true;
      _optionsVisible = false;
    });
    // Hand focus to the create UI: unfocusing collapses the popover so it
    // can't paint over a dialog barrier, and drops the soft keyboard before the
    // dialog's own field claims it.
    _suppressBlurSnap = true;
    _focusNode.unfocus();
    T? created;
    try {
      created = await onCreate(context, query);
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'searchable_dropdown_field',
          context: ErrorDescription('running an inline create'),
        ),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
      _suppressBlurSnap = false;
    }
    if (!mounted) return;
    if (created == null) {
      _controller.value = TextEditingValue(
        text: restore,
        selection: TextSelection.collapsed(offset: restore.length),
      );
      // A typed name is handed back for editing — after a cancelled dialog, a
      // refused name or a failed save alike, since the callback's null can't
      // tell them apart, and a typo is the likeliest fix in each. The plain
      // "New …" row has nothing to edit, so it refocuses nothing: that would
      // just reopen the popover over the form. Post-frame: the field is still
      // focus-excluded until the rebuild that clears `_creating` lands.
      if (query.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focusNode.requestFocus();
        });
      }
      return;
    }
    final committed = created;
    setState(() => _committed = committed);
    // Set the text as well: the blur snap was suppressed, so the field still
    // holds the query rather than the name the create UI settled on. Through a
    // different value first: `RawAutocomplete` recomputes its options only on
    // a text CHANGE, and an Enter-started create leaves the field holding this
    // exact string already — its cached options would still be the
    // `Create "«name»"` row, offered again for the record just created.
    final label = widget.displayString(committed);
    _controller.value = TextEditingValue(text: label.isEmpty ? ' ' : '');
    _controller.text = label;
    widget.onChanged(committed);
    // Deliberately not refocusing — create is terminal, and focus would
    // reopen the popover over the value just chosen.
  }

  void _onSubmitted(VoidCallback onFieldSubmitted) {
    // Enter, and Android's soft-keyboard "Done", mean "I'm finished" — so on
    // the value the field already holds they dismiss. Deliberately *not*
    // symmetric with a tap on that row, which is an explicit choice and does
    // re-commit: letting Done re-commit would let it silently re-add the last
    // item on a chip-adder.
    if (_highlightIsCreateRow) {
      unawaited(_handleCreate(_createQuery(_controller.text)));
      return; // never reaches `_select`
    }
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

    // No options — render a disabled placeholder rather than a live field that
    // opens onto nothing.
    //
    // This branch is 52 px against the live field's 48, so a picker whose list
    // arrives late does move 4 px once. That is **pre-existing and not caused
    // by `floatingLabelBehavior` below** — measured both ways, the number does
    // not move; an outline border gives a floated label zero height
    // (`input_decorator.dart`: `floatingLabelHeight = 0` for `isOutline`, so
    // `topHeight` is 0 either way). The difference comes from this branch
    // having no `suffixIcon`, where the live one is floored by a 44 px button.
    // An earlier version of this comment blamed the floating label for it and
    // built a "deliberate trade" on that; there is no trade.
    // A picker that can create stays live: its create row is something to pick.
    if (widget.items.isEmpty && widget.onCreateRequested == null) {
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
              // Without this the hint below is invisible, and this branch is
              // the ONLY place in the widget where that matters.
              // `_InputDecoratorState.labelShouldWithdraw` is
              // `widget._labelShouldWithdraw || floatingLabelBehavior ==
              // always`, where the first term is `!isEmpty || (isFocused &&
              // enabled)` — and a DISABLED, EMPTY field can be neither. So
              // `_hasInlineLabel` stays true, `showHint = isEmpty &&
              // !_hasInlineLabel` is false, and `input_decorator.dart` wraps
              // the hint in `AnimatedOpacity(opacity: 0)`; worse,
              // `RenderAnimatedOpacityMixin.visitChildrenForSemantics` drops
              // it at alpha 0, so it isn't announced either. The label simply
              // sits where the hint would have been, and the user gets an
              // outlined, un-tappable box with no ✕, no ▾ and no explanation —
              // which is what a company with no projects saw on the Tasks
              // filter bar (invoiceninja/flutter#134 follow-up). Floating the
              // label withdraws it and lets the hint paint.
              //
              // Testing this needs care, and the obvious two ways both LIE.
              // `decoration.hintText != null` asserts a property, not a pixel —
              // that is what let the invisible hint ship. And **`find.text`
              // cannot see it either**: the `Text` is in the tree in both
              // states, just wrapped in `AnimatedOpacity(opacity: 0)`, so a
              // finder-based test passes with this line reverted (checked by
              // experiment). Assert the computed opacity.
              floatingLabelBehavior: FloatingLabelBehavior.always,
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
          child: RawAutocomplete<_Opt<T>>(
            textEditingController: _controller,
            focusNode: _focusNode,
            // Read in TWO places, and the second is the one that matters for
            // the create row: `_select` writes the result into the field, and
            // `_onChangedField` compares it against the field text on every
            // keystroke — that comparison is the only thing that ever clears
            // the SDK's `_selection`, and a pinned `_selection` is exactly
            // CLAUDE.md's "the row goes permanently dead after one cancelled
            // create". So this must be total over `_Opt<T>`, cheap, and must
            // stop equalling the field text as soon as the query moves on: a
            // non-item row returns the query it was built from, never ''.
            displayStringForOption: (o) => switch (o) {
              _ItemOpt<T>(:final item) => widget.displayString(item),
              _CreateOpt<T>(:final query) => _createRowLabel(context, query),
            },
            // Flip above the field when there's more room there. Left at the
            // `.down` default, a picker low on a phone screen gets whatever
            // space is below it, floored at a 48px sliver — invisible while the
            // popover held one row, useless now that it holds the whole list.
            optionsViewOpenDirection: OptionsViewOpenDirection.mostSpace,
            optionsBuilder: (value) {
              // `_optionsFor` / `_idleOptions` stay in `T` — wrapping happens
              // here and nowhere else, so the hoist and its `parentAgrees`
              // guard are untouched.
              final (items, hasExact) = _optionsFor(value.text);
              final options = _wrap(items, value.text, hasExact: hasExact);
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
            onSelected: (opt) {
              final T item;
              switch (opt) {
                case _CreateOpt<T>(:final query):
                  // Backstop only — the tap and Enter paths call
                  // `_handleCreate` directly. `_select` has already written the
                  // row's label into the field, so a cancel restores the query
                  // — or, for the empty-query row, the committed value's name.
                  final committed = _committed;
                  unawaited(
                    _handleCreate(
                      query,
                      restoreText: query.isNotEmpty || committed == null
                          ? query
                          : widget.displayString(committed),
                    ),
                  );
                  return;
                case _ItemOpt<T>(item: final picked):
                  item = picked;
              }
              setState(() {
                _committed = item;
                _optionsVisible = false;
              });
              widget.onChanged(item);
            },
            fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
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
                // Locked while a create is in flight. A vendor's create
                // searches the server first, which can take seconds, and a
                // pick made in that window would be silently overwritten
                // when the create resolves.
                child: IgnorePointer(
                  ignoring: _creating,
                  child: ExcludeFocus(
                    excluding: _creating,
                    child: EscapeObserver(
                      // `DismissIntent` hides the overlay without touching
                      // focus, so nothing else would tell us it is gone.
                      onEscape: () => _optionsVisible = false,
                      child: TextField(
                        controller: textController,
                        focusNode: focusNode,
                        // On native touch nothing else can close the popover —
                        // see `picker_dismissal.dart`.
                        onTapOutside: dismissPickerOnTapOutside(focusNode),
                        onTap: _reopenOptions,
                        // Without this the toggle in `_reopenOptions` is
                        // intermittent. `TextField.onTap` arrives via
                        // `TextSelectionGestureDetectorBuilder.onUserTap`,
                        // which `_handleTapUp` calls only on the FIRST tap of a
                        // series (`text_selection.dart`) — so a second tap
                        // inside `kDoubleTapTimeout` at roughly the same spot
                        // is swallowed, and `enableInteractiveSelection: false`
                        // means the double-tap branch does nothing either: the
                        // tap is simply lost. Wait 300 ms and it works, which
                        // is the worst possible behaviour for a button.
                        //
                        // Gated on the same flag as the toggle, not `true`: on
                        // a typable picker the second tap of a series IS
                        // word-select, and `_reopenOptions`' select-all would
                        // fight it. Safe here precisely because a keyboard-less
                        // picker has no selection to steal.
                        onTapAlwaysCalled: _suppressKeyboard,
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
              // The create row is always last and is pinned below the list
              // rather than scrolled with it — as row 21 of a 280 px popover
              // nobody would find it. It stays in `options`, so the arrow keys
              // and Enter still reach it through the SDK's highlight.
              final createOpt = options.isNotEmpty
                  ? switch (options.last) {
                      final _CreateOpt<T> c => c,
                      _ItemOpt<T>() => null,
                    }
                  : null;
              final listCount = options.length - (createOpt == null ? 0 : 1);
              // Skip while resetting: this build still carries the old
              // highlight, so scrolling now would animate to the row the user
              // last arrowed to and then back to the top on the next build.
              // `listCount`, not `options.length`: the pinned create row has
              // nothing to scroll to.
              if (!resetting) {
                _scrollHighlightedIntoView(
                  highlightedIndex,
                  listCount,
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
                  // Exhaustive for the same reason as `_highlightIsCommitted`.
                  : _visibleOptions.indexWhere(
                      (o) => switch (o) {
                        _ItemOpt<T>(:final item) =>
                          widget.idOf(item) == committedId,
                        _CreateOpt<T>() => false,
                      },
                    );
              // No Align of our own: RawAutocomplete already wraps this in a
              // tightly-constrained Align that flips between topStart and
              // bottomStart. A bare Align here would expand to fill that box
              // (it only shrink-wraps under an infinite constraint), leaving
              // the SDK's alignment nothing to move — an upward popover would
              // detach and render at the top of the screen.
              return BackDismissiblePickerOverlay(
                focusNode: _focusNode,
                child: Material(
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
                            itemCount: listCount,
                            itemBuilder: (context, i) {
                              final opt = options.elementAt(i);
                              final item = switch (opt) {
                                _ItemOpt<T>(:final item) => item,
                                // Pinned below the list, never built here.
                                _CreateOpt<T>() => null,
                              };
                              if (item == null) return const SizedBox.shrink();
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
                                  color: isHighlighted
                                      ? tokens.accentSoft
                                      : null,
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
                                        : () => onSelected(opt),
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
                        if (createOpt != null) ...[
                          if (listCount > 0)
                            Divider(height: 1, color: tokens.border),
                          _CreateOptionRow(
                            label: _createRowLabel(context, createOpt.query),
                            extent: optionExtent,
                            highlighted: highlightedIndex == listCount,
                            onTap: () => _handleCreate(createOpt.query),
                          ),
                        ],
                        if (footer != null) ...[
                          Divider(height: 1, color: tokens.border),
                          footer,
                        ],
                      ],
                    ),
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

  /// Clear button (when there's something to clear) plus the dropdown toggle.
  ///
  /// Rebuilt from the controller rather than the enclosing build:
  /// `RawAutocomplete` does not `setState` when the text changes (it drives the
  /// overlay through an `OverlayPortalController` and passes the same field
  /// widget straight through), so a suffix chosen during the parent build goes
  /// stale as the user types.
  ///
  /// The arrow is what tells the user this is a picker at all — without it, a
  /// populated field offers only an ✕, and "delete the value, then choose" is a
  /// reasonable reading of that. It is also the only *visible* way to close the
  /// popover, which is why it is a button rather than a glyph; see its own
  /// comment below. The label is the state-neutral `options` rather than an
  /// open/close pair, because the glyph does not flip: making it do so would
  /// need `_optionsVisible` to become observable, and notifying from
  /// `optionsViewBuilder` fires mid-build into this very `ListenableBuilder`,
  /// which has already built this frame. Material's own `DropdownButton` keeps
  /// one glyph too.
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
        if (_creating) {
          return const Padding(
            padding: EdgeInsetsDirectional.only(end: InSpacing.sm * 1.5),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
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
                  // Both read BEFORE the mutation below: `_isPristine` reads
                  // the controller and `_parentOwnsCommitted` reads
                  // `_committed`.
                  final wasPristine = _isPristine(textController.text);
                  final wasSelection = _parentOwnsCommitted;
                  textController.clear();
                  setState(() {
                    _committed = null;
                    _optionsVisible = false;
                  });
                  widget.onChanged(null);
                  // Clearing an actual SELECTION is a commit — the same shape
                  // as tapping the committed row, which also closes and
                  // unfocuses. Without this the opposite happens: `clear()` is
                  // a text change, `_onChangedField` recomputes, the idle list
                  // comes back non-empty, the field still has focus, and the
                  // SDK OPENS the popover (invoiceninja/flutter#130). The
                  // `_optionsVisible` above is only our own bookkeeping — the
                  // SDK's OverlayPortalController never sees it. It also
                  // strands a stale `_options`: `optionsBuilder` ran inside
                  // `clear()`, BEFORE the setState above, so the list still
                  // holds the just-cleared item hoisted to row 0 and a
                  // soft-keyboard "Done" would re-select it.
                  //
                  // Two cases deliberately keep focus, because in neither is
                  // the ✕ a commit. A half-typed query: there it means "erase
                  // and let me retype", so the keyboard must stay and
                  // reopening the idle list is the right answer to an empty
                  // query. And a chip-adder ([_parentOwnsCommitted]), where
                  // `onChanged(null)` is discarded by the caller and the ✕
                  // only clears the leftover label of the last item added —
                  // unfocusing there costs a tap and the keyboard on every
                  // subsequent add, on the Activity filter sheet among others.
                  if (wasPristine && wasSelection) _focusNode.unfocus();
                },
              ),
            // A real toggle, not decoration. `_reopenOptions` gates its
            // close branch on `_suppressKeyboard`, so above six options the
            // field is typable and a tap on it — or on this glyph, which used
            // to be a bare `Icon` whose taps fell through to the field — could
            // only ever RE-open. On the Tasks filter bar that left the Client
            // and Project pickers with no tap-to-close at all, and cost the
            // Assigned User picker its own the moment a company hired a
            // seventh user: the one control that looks like a toggle wasn't
            // one (invoiceninja/flutter#134). An `IconButton` in the suffix
            // wins its own tap, so `TextField.onTap: _reopenOptions` does not
            // also run — the ✕ has worked that way in this Row since it
            // shipped.
            IconButton(
              tooltip: context.tr('options'),
              icon: Icon(Icons.arrow_drop_down, size: 20, color: tokens.ink3),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints.tightFor(
                width: buttonSize,
                height: buttonSize,
              ),
              // As on the ✕ beside it: `padded` (the iOS/Android default) would
              // inflate the layout box to kMinInteractiveDimension and ignore
              // the constraints above, stretching the dense field.
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                if (_optionsVisible) {
                  // The same lever as back and tap-outside, so all three
                  // dismissals leave identical state.
                  _focusNode.unfocus();
                  return;
                }
                // Order-insensitive, and it must stay that way: `requestFocus`
                // is applied in a microtask, so the synchronous text bounce
                // below may recompute the options while `hasFocus` is still
                // false. `RawAutocomplete` re-runs its visibility check on the
                // focus listener, so the overlay opens when focus lands. Don't
                // "fix" this into a post-frame callback.
                _focusNode.requestFocus();
                _reopenOptions();
              },
            ),
            const SizedBox(width: InSpacing.sm),
          ],
        );
      },
    );
  }
}

/// The pinned create row. Same look as `ClientPickerField`'s: `accentInk`, not
/// `accent` — `accent` is one mid blue in both brightnesses and lands at
/// ~3.2:1 on the dark `accentSoft` highlight, under the 4.5:1 floor.
class _CreateOptionRow extends StatelessWidget {
  const _CreateOptionRow({
    required this.label,
    required this.extent,
    required this.highlighted,
    required this.onTap,
  });

  final String label;
  final double extent;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Semantics(
      button: true,
      child: Container(
        color: highlighted ? tokens.accentSoft : null,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: extent),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: InSpacing.md(context),
                vertical: InSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(Icons.add, size: 16, color: tokens.accentInk),
                  const SizedBox(width: InSpacing.sm),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.accentInk,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
