import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/custom_field_filter_key.dart';
import 'package:admin/ui/core/list/search/date_column_filter_key.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_suggestion_controller.dart';
import 'package:admin/ui/core/list/search/filter_token.dart';
import 'package:admin/ui/core/widgets/key_cap.dart';
import 'package:admin/ui/features/dashboard/widgets/filters/date_range_picker_button.dart';

/// Horizontal padding applied to every menu row's content (key / value /
/// operator / search-for). Exposed so the field's overlay positioning can
/// subtract it from the anchor's x to land the row text — not the painted
/// menu edge — under the typing column.
const double kMenuRowInsetLeft = 12.0;

/// Max width of the floating suggestion menu. Shared with the field's overlay
/// positioning (`token_search_field.dart`) so the placement clamp keeps the
/// painted menu inside the search box.
const double kFilterMenuMaxWidth = 420;

/// Height of one single-line menu row: 40 px for a pointer, the 44 px touch
/// floor on a touch platform, and scaled with the text so a large text size
/// grows the row instead of slicing its descenders (the value list hands this
/// to `ListView.itemExtent`, which clamps rather than grows).
double filterMenuRowExtent(BuildContext context) {
  final base = Env.isTouchPrimary ? 44.0 : 40.0;
  final scaled = MediaQuery.textScalerOf(context).scale(base);
  return scaled < base ? base : scaled;
}

/// Alphabetical sort comparator used by the key picker. Exposed so the
/// `_KeyList` builder uses one place and tests can pin the order without
/// pumping the whole menu widget.
int compareFilterKeysByLabel(FilterKey a, FilterKey b, BuildContext context) {
  return a
      .displayLabel(context)
      .toLowerCase()
      .compareTo(b.displayLabel(context).toLowerCase());
}

/// Keys eligible for the key-mode picker, in registry order: available, not
/// locked, and — for single-value keys — not already applied. An applied
/// single-value key has nothing more to add and is edited via its chip;
/// multi-value keys stay so the user can union more values. Exposed (like
/// [compareFilterKeysByLabel]) so the hide-applied rule is unit-testable
/// without pumping the whole menu.
List<FilterKey> availableKeyPickerKeys(
  List<FilterKey> keys,
  GenericListViewModel<dynamic> vm,
) {
  return keys
      .where(
        (k) =>
            k.isAvailable(vm) &&
            !vm.lockedFilterKeyIds.contains(k.id) &&
            !(k.singleValue && !k.isAtDefault(vm)),
      )
      .toList();
}

/// The key list for a typed [query]: keys whose label, id or an alias STARTS
/// with it lead, then the ones that merely contain it, each group A→Z. A flat
/// A→Z of every substring match put `Custom…` and `Last login` ahead of
/// `State` / `Status` for someone typing `st`. An empty [query] returns every
/// key A→Z. Exposed for the same reason as [compareFilterKeysByLabel].
List<FilterKey> rankFilterKeys(
  List<FilterKey> keys,
  String query,
  BuildContext context,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) {
    return [...keys]..sort((a, b) => compareFilterKeysByLabel(a, b, context));
  }
  final prefix = <FilterKey>[];
  final contains = <FilterKey>[];
  for (final k in keys) {
    // Match by id, alias, or localized display label so a user typing "stat"
    // finds `status` (alias of `is`).
    final label = k.displayLabel(context).toLowerCase();
    if (label.startsWith(q) ||
        k.id.startsWith(q) ||
        k.aliases.any((a) => a.startsWith(q))) {
      prefix.add(k);
    } else if (label.contains(q) ||
        k.id.contains(q) ||
        k.aliases.any((a) => a.contains(q))) {
      contains.add(k);
    }
  }
  prefix.sort((a, b) => compareFilterKeysByLabel(a, b, context));
  contains.sort((a, b) => compareFilterKeysByLabel(a, b, context));
  return [...prefix, ...contains];
}

/// Parsed view of the current input text.
///
///   ""               -> key mode, prefix=null, query=""
///   "acme"           -> key mode, prefix=null, query="acme"
///   "is:"            -> value mode, prefix=IsFilterKey, query=""
///   "is:arch"        -> value mode, prefix=IsFilterKey, query="arch"
///   "unmatched:foo"  -> key mode (the prefix doesn't match a known key —
///                       fall back to free-text mode so the user sees the
///                       "Search for 'unmatched:foo'" row).
class FilterInputParse {
  const FilterInputParse({this.matchedKey, required this.query});

  /// When non-null, the menu shows value suggestions for this key. When
  /// null, the menu shows the key picker (with [query] as the free-text
  /// filter / "Search for …" target).
  final FilterKey? matchedKey;
  final String query;

  /// [keys] is the set a typed prefix may resolve to — pass the controller's
  /// `typeableKeys`, not every registered key (a hidden or locked key must not
  /// be reachable by typing its id).
  static FilterInputParse of(String input, List<FilterKey> keys) {
    final colon = input.indexOf(':');
    if (colon == -1) return FilterInputParse(query: input);
    final prefix = input.substring(0, colon).trim().toLowerCase();
    final tail = input.substring(colon + 1);
    for (final k in keys) {
      if (k.id == prefix || k.aliases.contains(prefix)) {
        return FilterInputParse(matchedKey: k, query: tail);
      }
    }
    return FilterInputParse(query: input);
  }
}

/// Overlay menu attached to the token search field. Two modes:
///   * **Key mode** (`parse.matchedKey == null`): the filter picker —
///     suggested filters first, then the rest A→Z — plus a "Search for
///     `query`" row when [query] is non-empty so free-text submission is an
///     explicit choice.
///   * **Value mode** (`parse.matchedKey != null`): streams value
///     suggestions from the matched key.
///
/// Selection routes through the callbacks rather than mutating the VM
/// directly — keeps this widget free of side effects so it can be reused by
/// the wide-mode overlay and the narrow-mode full-screen sheet.
///
/// [controller] is the shared keyboard-navigation state: the menu publishes
/// each row's action so [TokenSearchField]'s arrow-key handler can drive
/// the highlight + commit Enter.
class FilterSuggestionMenu extends StatelessWidget {
  const FilterSuggestionMenu({
    required this.vm,
    required this.keys,
    required this.parse,
    required this.controller,
    required this.onSelectKey,
    required this.onSelectValue,
    required this.onToggleValue,
    required this.onPickExclusive,
    required this.onPickOp,
    required this.onCommitFreeText,
    required this.onDismiss,
    required this.onBack,
    this.stamp,
    this.maxHeight = 320,
    this.floating = true,
    super.key,
  });

  final GenericListViewModel<dynamic> vm;
  final List<FilterKey> keys;
  final FilterInputParse parse;
  final FilterSuggestionController controller;
  final ValueChanged<FilterKey> onSelectKey;
  final void Function(FilterKey key, FilterValueSuggestion value) onSelectValue;

  /// A multi-select ([FilterKey.checkboxMultiSelect]) row was clicked: tick or
  /// untick the value and keep the menu open.
  final void Function(FilterKey key, FilterValueSuggestion value) onToggleValue;

  /// Closes the surface hosting this menu, if it is dismissable at all.
  ///
  /// Called **before** a row awaits a pushed route (the two date pickers
  /// below). While the wide-mode overlay is showing, its
  /// `BackDismissibleOverlay` holds a `ChildBackButtonDispatcher`, and the
  /// `Router` consults child dispatchers *before* it pops any route — so a back
  /// press meant for the calendar would dismiss the menu underneath it and
  /// leave the calendar open. `token_search_field._onSelectValue` states the
  /// same "dismiss BEFORE the await" rule for its own network round-trip.
  ///
  /// **`required`, though nullable** — the same shape its two private children
  /// use. A third host that simply omitted it would be indistinguishable from
  /// the sheet's deliberate null, and would silently reintroduce the bug this
  /// exists for. Passing `null` has to be a decision someone typed.
  ///
  /// Null from the narrow-mode sheet, which is a route of its own and has no
  /// overlay to close.
  final VoidCallback? onDismiss;

  /// Leaves a value list for the filter picker — the value header's "‹" row.
  /// The only way back that does not need a hardware key: Backspace on an
  /// empty input also does it, but a soft keyboard sends no key event for
  /// that, so a picked key was a dead end on a phone.
  final VoidCallback onBack;

  /// "Only" on a multi-select row, and every commit that must REPLACE rather
  /// than toggle (a typed amount or date, a date window): select just this
  /// value and close.
  final void Function(FilterKey key, FilterValueSuggestion value)
  onPickExclusive;

  /// Fired when the user clicks an operator row with no value typed yet —
  /// the caller writes a key-prefixed symbol into the input (e.g.
  /// `balance:>`) so the user can keep typing the value. With a value
  /// typed, the click commits through [onPickExclusive] instead.
  final void Function(FilterKey key, FilterOp op) onPickOp;

  final ValueChanged<String> onCommitFreeText;

  /// Identifies the input these rows are built for; published with them so
  /// Enter can refuse rows that belong to the previous keystroke. See
  /// [FilterSuggestionController.commit].
  final Object? stamp;

  final double maxHeight;

  /// Whether the menu is a floating popup (wide mode) — gets the bordered,
  /// elevated, clipped chrome. `false` for the full-bleed narrow-mode
  /// [FilterEntrySheet] panel, which renders flat below a divider.
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final Widget body = parse.matchedKey == null
        ? _KeyList(
            vm: vm,
            keys: keys,
            query: parse.query.trim(),
            controller: controller,
            stamp: stamp,
            onSelectKey: onSelectKey,
            onSelectValue: onSelectValue,
            onCommitFreeText: onCommitFreeText,
          )
        : _ValueList(
            vm: vm,
            filterKey: parse.matchedKey!,
            query: parse.query,
            controller: controller,
            stamp: stamp,
            onSelectValue: onSelectValue,
            onToggleValue: onToggleValue,
            onPickExclusive: onPickExclusive,
            onPickOp: onPickOp,
            onDismiss: onDismiss,
            onBack: onBack,
          );
    // The key hints are a hardware-keyboard affordance: hidden on touch, and
    // in the sheet, whose rows fill the page.
    final showFooter = floating && !Env.isTouchPrimary;
    final child = ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxHeight,
        maxWidth: kFilterMenuMaxWidth,
      ),
      child: showFooter
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(child: body),
                const _KeyHintFooter(),
              ],
            )
          : body,
    );
    // Narrow mode (FilterEntrySheet) renders the menu full-bleed below a
    // divider — a flat list, no border/elevation/radius. Wide mode is a
    // floating popup that gets the bordered chrome (matches the company
    // picker / MenuTheme).
    if (!floating) {
      return Material(color: tokens.surface, child: child);
    }
    return Material(
      elevation: 4,
      color: tokens.surface,
      // The clip keeps row highlights inside the rounded corners.
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: tokens.border),
        borderRadius: BorderRadius.circular(InRadii.r2),
      ),
      child: child,
    );
  }
}

/// Schedule a row-publish on the next frame. Calling [publishRows]
/// synchronously during build is unsafe because it fires `notifyListeners`
/// which would re-trigger any widgets listening to the controller mid-build.
///
/// [keys] is a parallel list of stable per-row identifiers (e.g.
/// `'key:status'`, `'value:status:active'`) that lets the controller tell
/// "rows rebuilt with identical content" from "rows genuinely changed."
/// See [FilterSuggestionController.publishRows] for the full rationale.
void _scheduleRowPublish(
  FilterSuggestionController controller,
  List<VoidCallback> actions,
  List<Object> keys, {
  Object? stamp,
  int? preselect,
}) {
  SchedulerBinding.instance.addPostFrameCallback((_) {
    controller.publishRows(actions, keys, stamp: stamp, preselect: preselect);
  });
}

/// The slim `↑ ↓ navigate · ↵ select · Esc close` strip under the floating
/// menu. Same caps and the same three words as the command palette's footer.
class _KeyHintFooter extends StatelessWidget {
  const _KeyHintFooter();

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: tokens.border.withValues(alpha: 0.6)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        // `Wrap`, not `Row`: three runs fit 420 px in English but the caps
        // grow with the text scale and German / Spanish labels are longer.
        child: Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            KeyCapRow(
              keys: const ['↑', '↓'],
              label: context.tr('navigate'),
              dense: true,
              keyColor: tokens.ink3,
            ),
            KeyCapRow(
              keys: const ['↵'],
              label: context.tr('select'),
              dense: true,
              keyColor: tokens.ink3,
            ),
            KeyCapRow(
              keys: const ['Esc'],
              label: context.tr('close'),
              dense: true,
              keyColor: tokens.ink3,
            ),
          ],
        ),
      ),
    );
  }
}

/// Owns a list's [ScrollController] and keeps the keyboard highlight on
/// screen. Each row reveals itself when it becomes the highlighted one (see
/// [_Highlightable]) — but a lazily-built list has no row to do that for a
/// far jump: wrapping from the first row to the last, or any move in the
/// fixed-extent value list past its cache. Those are scrolled here, from the
/// index alone.
class _MenuScroll extends StatefulWidget {
  const _MenuScroll({
    required this.controller,
    required this.builder,
    this.itemExtent,
  });

  final FilterSuggestionController controller;

  /// When non-null every published row is exactly this tall and sits at
  /// `index * itemExtent`, so any keyboard move can be scrolled to without
  /// the row being built.
  final double? itemExtent;

  final Widget Function(ScrollController scroll) builder;

  @override
  State<_MenuScroll> createState() => _MenuScrollState();
}

class _MenuScrollState extends State<_MenuScroll> {
  final ScrollController _scroll = ScrollController();
  int _lastIndex = 0;

  @override
  void initState() {
    super.initState();
    _lastIndex = widget.controller.selectedIndex;
    widget.controller.addListener(_onSelection);
  }

  @override
  void didUpdateWidget(covariant _MenuScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onSelection);
      widget.controller.addListener(_onSelection);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onSelection);
    _scroll.dispose();
    super.dispose();
  }

  void _onSelection() {
    final c = widget.controller;
    final index = c.selectedIndex;
    if (index == _lastIndex) return;
    _lastIndex = index;
    if (!c.movedByKeyboard) return;
    // After the frame: a fresh publish can land before the list has laid out
    // its new extent.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final position = _scroll.position;
      final extent = widget.itemExtent;
      if (extent != null) {
        final top = index * extent;
        final bottom = top + extent;
        if (top < position.pixels) {
          _scroll.jumpTo(top.clamp(0.0, position.maxScrollExtent));
        } else if (bottom > position.pixels + position.viewportDimension) {
          _scroll.jumpTo(
            (bottom - position.viewportDimension).clamp(
              0.0,
              position.maxScrollExtent,
            ),
          );
        }
        return;
      }
      if (index == 0) {
        _scroll.jumpTo(0);
      } else if (index == c.rowCount - 1) {
        _scroll.jumpTo(position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(_scroll);
}

class _KeyList extends StatelessWidget {
  const _KeyList({
    required this.vm,
    required this.keys,
    required this.query,
    required this.controller,
    required this.stamp,
    required this.onSelectKey,
    required this.onSelectValue,
    required this.onCommitFreeText,
  });

  final GenericListViewModel<dynamic> vm;
  final List<FilterKey> keys;
  final String query;
  final FilterSuggestionController controller;
  final Object? stamp;
  final ValueChanged<FilterKey> onSelectKey;
  final void Function(FilterKey key, FilterValueSuggestion value) onSelectValue;
  final ValueChanged<String> onCommitFreeText;

  /// Min query length for the cross-key value-match block. One letter
  /// matches too broadly (`a` against country names alone is dozens of
  /// rows) and the user is mid-typing anyway. Two letters narrows
  /// `act → Active`, `eur → EUR`, `ger → Germany` without flooding.
  static const int _kValueMatchMinQueryLen = 2;

  /// Total cap on cross-key value matches surfaced. The picker shows
  /// `Search for "…"` + this block + the filter keys section, so 6
  /// leaves room for keys below without scrolling the dropdown to fit.
  /// Per-key caps in `FilterKey.quickValueSuggestions` keep any one key
  /// from monopolising the budget.
  static const int _kValueMatchTotalCap = 6;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final available = availableKeyPickerKeys(keys, vm);

    // Cross-key value matches. So `act` surfaces a `Status: Active` row
    // and picking it sets `status:active` directly, without the user
    // having to first pick the Status key. Each contributing key caps
    // its own contribution inside `quickValueSuggestions`; we apply a
    // total cap on top across keys. Iterates keys in registry order
    // (Status first, statics after) so the most specific dimensions
    // surface ahead of the long-tail ones.
    final valueMatches = <_KeyedValue>[];
    if (query.trim().length >= _kValueMatchMinQueryLen) {
      for (final k in available) {
        if (valueMatches.length >= _kValueMatchTotalCap) break;
        for (final v in k.quickValueSuggestions(vm, context, query)) {
          if (valueMatches.length >= _kValueMatchTotalCap) break;
          valueMatches.add(_KeyedValue(k, v));
        }
      }
    }

    // Build the rows and the parallel action+rowKeys lists in display
    // order. The action list is what the field's keyboard handler
    // invokes on Enter; rowKeys lets the controller tell rebuilds with
    // identical content (highlight should survive) from genuine row
    // changes (highlight should reset). Named `rowKeys` rather than
    // `keys` to avoid shadowing this widget's `keys` field (the filter
    // key list).
    final rows = <Widget>[];
    final actions = <VoidCallback>[];
    final rowKeys = <Object>[];

    void addKeyRow(FilterKey k) {
      final idx = actions.length;
      actions.add(() => onSelectKey(k));
      rowKeys.add('key:${k.id}');
      rows.add(
        _Highlightable(
          controller: controller,
          index: idx,
          child: _KeyRow(filterKey: k, onTap: actions[idx]),
        ),
      );
    }

    if (query.isEmpty) {
      // First view. The few filters a list is usually narrowed by lead, in
      // the order the entity registers them; everything else follows A→Z.
      // The headers only appear when there are two groups to tell apart — a
      // settings list with State alone stays a bare row.
      final primary = [
        for (final k in available)
          if (k.isPrimary) k,
      ];
      final rest = rankFilterKeys(
        [
          for (final k in available)
            if (!k.isPrimary) k,
        ],
        '',
        context,
      );
      final sectioned = primary.isNotEmpty && rest.isNotEmpty;
      if (sectioned) {
        rows.add(_SectionHeader(text: context.tr('filters_suggested_section')));
      }
      primary.forEach(addKeyRow);
      if (sectioned) {
        rows.add(_SectionHeader(text: context.tr('filters_all_section')));
      }
      rest.forEach(addKeyRow);
      if (available.isEmpty) {
        rows.add(
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              context.tr('no_filters_available'),
              style: theme.textTheme.bodySmall?.copyWith(color: tokens.ink3),
            ),
          ),
        );
      }
    } else {
      final idx = actions.length;
      actions.add(() => onCommitFreeText(query));
      rowKeys.add('search_for');
      rows.add(
        _Highlightable(
          controller: controller,
          index: idx,
          child: _SearchForRow(query: query, onTap: actions[idx]),
        ),
      );
      if (valueMatches.isNotEmpty) {
        rows.add(_SectionHeader(text: context.tr('filter_values_section')));
        for (final pair in valueMatches) {
          final idx = actions.length;
          actions.add(() => onSelectValue(pair.key, pair.value));
          rowKeys.add('value:${pair.key.id}:${pair.value.rawValue}');
          rows.add(
            _Highlightable(
              controller: controller,
              index: idx,
              child: _ValueMatchRow(
                filterKey: pair.key,
                value: pair.value,
                onTap: actions[idx],
              ),
            ),
          );
        }
      }
      final ranked = rankFilterKeys(available, query, context);
      if (ranked.isNotEmpty) {
        rows.add(_SectionHeader(text: context.tr('filters_section')));
      }
      ranked.forEach(addKeyRow);
    }

    _scheduleRowPublish(controller, actions, rowKeys, stamp: stamp);

    return _MenuScroll(
      controller: controller,
      builder: (scroll) => ListView(
        controller: scroll,
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: rows,
      ),
    );
  }
}

/// `(FilterKey, FilterValueSuggestion)` tuple. Used internally by the
/// key-mode picker to fan out cross-key value matches while keeping a
/// pointer back to the originating key (needed for the `onSelectValue`
/// dispatch and the leading key-label rendering on each row).
class _KeyedValue {
  const _KeyedValue(this.key, this.value);
  final FilterKey key;
  final FilterValueSuggestion value;
}

/// Uppercase letter-spaced section divider, reused by the "Suggested",
/// "All filters", "Filter values" and "Filters" headers in the key-mode
/// picker.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: tokens.ink3,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// One row of the cross-key value-match block. Shows the originating
/// filter key's label in muted ink alongside the value's display label,
/// so a row reads `Status  Active` — picking it commits `status:active`.
/// Mirrors `_KeyRow`'s gesture / hover handling — see `_SearchForRow`
/// for the GestureDetector rationale.
class _ValueMatchRow extends StatelessWidget {
  const _ValueMatchRow({
    required this.filterKey,
    required this.value,
    required this.onTap,
  });

  final FilterKey filterKey;
  final FilterValueSuggestion value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: _RowFloor(
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: Icon(filterKey.icon, size: 18, color: tokens.ink3),
              ),
              const SizedBox(width: 6),
              Text(
                filterKey.displayLabel(context),
                style: theme.textTheme.bodyMedium?.copyWith(color: tokens.ink3),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value.displayLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.ink,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (value.secondaryLabel != null)
                Text(
                  value.secondaryLabel!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.ink3,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Standard row padding with the row-height floor ([filterMenuRowExtent]) —
/// a `ConstrainedBox(minHeight:)`, never a fixed height, so a row grows with
/// its text instead of clipping it.
class _RowFloor extends StatelessWidget {
  const _RowFloor({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: filterMenuRowExtent(context)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kMenuRowInsetLeft),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          heightFactor: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SearchForRow extends StatelessWidget {
  const _SearchForRow({required this.query, required this.onTap});

  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    // GestureDetector + MouseRegion instead of InkWell so the tap recognizer
    // doesn't lose the gesture arena to the surrounding ListView's scroll
    // recognizer on macOS (sub-pixel mouse motion between down and up was
    // canceling clicks even though the hover state worked). Keyboard Enter
    // routes through `FilterSuggestionController.commit()` directly and
    // never relied on this widget's recognizer.
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: _RowFloor(
          child: Row(
            children: [
              Icon(Icons.search, size: 16, color: tokens.ink3),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: tokens.ink,
                    ),
                    children: [
                      TextSpan(text: '${context.tr('search_for')} '),
                      TextSpan(
                        text: '"$query"',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                '↵',
                style: theme.textTheme.bodySmall?.copyWith(color: tokens.ink3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.filterKey, required this.onTap});

  final FilterKey filterKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    // What to type to reach this filter without the menu. A hardware-keyboard
    // hint, so not on touch — and not for a custom field, whose id
    // (`custom1`) is exactly what its configured label exists to hide.
    final typedHint = Env.isTouchPrimary || filterKey is CustomFieldFilterKey
        ? null
        : '${filterKey.aliases.isNotEmpty ? filterKey.aliases.first : filterKey.id}:';
    // See `_SearchForRow` for the GestureDetector rationale.
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: _RowFloor(
          child: Row(
            children: [
              // Leading icon replaces the old right-aligned type tag — the
              // same 20px leading slot the value rows use, so the label
              // columns line up.
              SizedBox(
                width: 20,
                child: Icon(filterKey.icon, size: 18, color: tokens.ink3),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  filterKey.displayLabel(context),
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.ink,
                  ),
                ),
              ),
              if (typedHint != null) ...[
                const SizedBox(width: 12),
                ExcludeSemantics(
                  child: Text(
                    typedHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.ink3,
                      fontFamily: kMonoFontFamily,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The value list's header: the key's name behind a "‹", tappable to return
/// to the filter picker.
class _ValueHeader extends StatelessWidget {
  const _ValueHeader({required this.label, required this.onBack});

  final String label;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: '${context.tr('back')}, $label',
      // The subtree is excluded, and the tap action lives in it — so it is
      // re-declared here, or a screen reader announces a button it cannot
      // press.
      onTap: onBack,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onBack,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: Env.isTouchPrimary ? 44 : 32,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 12, 4),
              child: Row(
                children: [
                  Icon(Icons.chevron_left, size: 18, color: tokens.ink3),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: tokens.ink3,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w600,
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

/// One emission of a key's value list, tagged with what it answers — see
/// [_ValueListState._suggestions].
typedef _Suggestions = ({
  FilterKey key,
  String query,
  List<FilterValueSuggestion> values,
});

/// The stamp published with rows that belong to an earlier query. It equals
/// no input stamp, so `FilterSuggestionController.commit(expecting:)` refuses
/// them and Enter commits what is actually typed instead.
class _StaleRows {
  const _StaleRows();
}

/// "Loading", shown only once a list has kept the user waiting. A list that
/// answers within a frame or two (every in-memory one) shows nothing at all
/// in between, rather than flashing the word.
class _LoadingHint extends StatefulWidget {
  const _LoadingHint();

  @override
  State<_LoadingHint> createState() => _LoadingHintState();
}

class _LoadingHintState extends State<_LoadingHint> {
  bool _show = false;
  late final Timer _timer = Timer(const Duration(milliseconds: 150), () {
    if (mounted) setState(() => _show = true);
  });

  @override
  void initState() {
    super.initState();
    _timer; // arm it
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        // Always laid out, so the menu does not change height when the word
        // appears.
        context.tr('loading'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: _show ? tokens.ink3 : Colors.transparent,
        ),
      ),
    );
  }
}

class _ValueList extends StatefulWidget {
  const _ValueList({
    required this.vm,
    required this.filterKey,
    required this.query,
    required this.controller,
    required this.stamp,
    required this.onSelectValue,
    required this.onToggleValue,
    required this.onPickExclusive,
    required this.onPickOp,
    required this.onDismiss,
    required this.onBack,
  });

  final GenericListViewModel<dynamic> vm;
  final FilterKey filterKey;
  final String query;
  final FilterSuggestionController controller;
  final Object? stamp;
  final void Function(FilterKey key, FilterValueSuggestion value) onSelectValue;
  final void Function(FilterKey key, FilterValueSuggestion value) onToggleValue;

  /// See [FilterSuggestionMenu.onDismiss] — forwarded to the date rows, which
  /// are the only ones that push a route.
  final VoidCallback? onDismiss;
  final VoidCallback onBack;
  final void Function(FilterKey key, FilterValueSuggestion value)
  onPickExclusive;
  final void Function(FilterKey key, FilterOp op) onPickOp;

  @override
  State<_ValueList> createState() => _ValueListState();
}

class _ValueListState extends State<_ValueList> {
  /// The suggestion stream for the current `(key, query)`, kept across
  /// rebuilds. Building it inline in `build` handed `StreamBuilder` a new
  /// stream on every rebuild of the menu — and the menu rebuilds on every VM
  /// notify — so an open `client:` list re-opened its Drift watch each time a
  /// page of the list behind it loaded.
  ///
  /// Last-only on purpose, and keyed on the key INSTANCE: `Stream.value` is
  /// single-subscription (a cache that handed an old one back would throw on
  /// the second listen), and keys are disposed and rebuilt when their inputs
  /// change (`EntityTokenSearchField._keysFor`).
  ///
  /// Each emission is tagged with the key and query it answers. When the
  /// stream is swapped, `StreamBuilder` keeps handing its builder the LAST
  /// stream's data until the new one emits — so for a frame (or, for a
  /// Drift-backed list, for as long as the query takes) the rows on screen
  /// belong to the previous query, or to the previous key altogether. The tag
  /// is how [build] tells; see the `fresh` / `mine` handling there.
  Stream<_Suggestions>? _stream;
  FilterKey? _streamKey;
  String? _streamQuery;

  Stream<_Suggestions> _suggestions(BuildContext context) {
    if (_stream == null ||
        !identical(_streamKey, widget.filterKey) ||
        _streamQuery != widget.query) {
      final key = widget.filterKey;
      final query = widget.query;
      _streamKey = key;
      _streamQuery = query;
      _stream = key
          .watchValueSuggestions(widget.vm, context, query)
          .map((values) => (key: key, query: query, values: values));
    }
    return _stream!;
  }

  /// The comparator picked in a date list's first step. Held HERE, not in
  /// `_DateValueRows`: typing a date swaps that widget for `_TypedDateRows`,
  /// and a choice kept in the swapped-out widget's State went with it — pick
  /// "is before", type the date, press Enter, and the filter applied was the
  /// default "is on or after". This State outlives the swap.
  FilterOp? _chosenOp;
  FilterKey? _chosenFor;

  FilterOp? get _chosen =>
      identical(_chosenFor, widget.filterKey) ? _chosenOp : null;

  void _choose(FilterOp? op) => setState(() {
    _chosenFor = widget.filterKey;
    _chosenOp = op;
  });

  @override
  Widget build(BuildContext context) {
    final filterKey = widget.filterKey;
    final vm = widget.vm;
    final query = widget.query;
    final controller = widget.controller;
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    // Snapshot of which raw values are currently applied for this key.
    // Drives the leading check icon and the toggle (vs. add) decision per
    // row. Computed once per build so we don't iterate tokens N times.
    final applied = <String>{
      for (final t in filterKey.tokensFrom(vm, context)) t.rawValue,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ValueHeader(
          label: filterKey.displayLabel(context),
          onBack: widget.onBack,
        ),
        Flexible(
          child: StreamBuilder<_Suggestions>(
            stream: _suggestions(context),
            builder: (context, snapshot) {
              final data = snapshot.data;
              // Rows left over from another KEY are not this list at all.
              final mine = data != null && identical(data.key, filterKey);
              final values = mine
                  ? data.values
                  : const <FilterValueSuggestion>[];
              // Rows for an earlier QUERY are this key's list a keystroke
              // ago. They stay on screen — blanking the list on every
              // keystroke would flicker — but they must not be what Enter
              // commits: publishing them under the current input's stamp let
              // `zeta` + Enter apply the first client of the idle list.
              final fresh = mine && data.query == query;
              final rowStamp = fresh ? widget.stamp : const _StaleRows();
              if (values.isEmpty) {
                // Typed-value keys (name, balance, created, …) opt-in to
                // a key-specific hint via `hintForValueMode` — falls back
                // to the generic "No matches" copy for pick-list keys.
                // Keys that also declare `supportedOps` upgrade this slot
                // to an operator picker so the user can choose between
                // `> value` / `< value` instead of just typing-and-enter.
                if (filterKey.supportedOps.isNotEmpty) {
                  if (filterKey is DateColumnFilterKey) {
                    // A date the user has TYPED commits from here in one
                    // step; anything else gets the comparator → preset
                    // picker. Typed dates used to be unreachable: Enter
                    // picked the comparator row, then the "back" row.
                    final typed = filterKey.parseTypedDate(
                      query,
                      activePattern: filterKey.activeDatePattern(vm, context),
                    );
                    if (typed != null) {
                      return _TypedDateRows(
                        vm: vm,
                        filterKey: filterKey,
                        typed: typed,
                        chosenOp: _chosen,
                        controller: controller,
                        stamp: widget.stamp,
                        onPickExclusive: widget.onPickExclusive,
                      );
                    }
                  }
                  // Comparable DATE keys get the relative-preset +
                  // absolute-date value picker (with comparator rows
                  // below); numeric keys keep the plain operator picker.
                  if (filterKey.valueType == FilterValueType.date) {
                    return _DateValueRows(
                      vm: vm,
                      filterKey: filterKey,
                      query: query,
                      // Something is typed and it is not a date: say so, and
                      // give Enter nothing to commit. It used to walk the
                      // highlight — a comparator, then "1 hour ago" — under
                      // text that read `date:banana`.
                      invalid: splitTypedOperator(query).value.isNotEmpty,
                      chosenOp: _chosen,
                      onChooseOp: _choose,
                      controller: controller,
                      stamp: widget.stamp,
                      onPickExclusive: widget.onPickExclusive,
                      onDismiss: widget.onDismiss,
                    );
                  }
                  return _OperatorRows(
                    vm: vm,
                    filterKey: filterKey,
                    query: query,
                    controller: controller,
                    stamp: widget.stamp,
                    onPickExclusive: widget.onPickExclusive,
                    onPickOp: widget.onPickOp,
                  );
                }
                _scheduleRowPublish(
                  controller,
                  const [],
                  const <Object>[],
                  stamp: widget.stamp,
                );
                // Nothing has answered THIS key and query yet (a Drift-backed
                // list): say so. "No matches" for as long as the query takes
                // read as "this client does not exist". A typed-value key has
                // no list to wait for — its hint shows at once.
                if (!fresh && !filterKey.acceptsTypedValue) {
                  return const _LoadingHint();
                }
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    filterKey.hintForValueMode(context) ??
                        context.tr('no_values_match'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.ink3,
                    ),
                  ),
                );
              }
              // Multi-select keys ([FilterKey.checkboxMultiSelect]): the
              // whole row ticks / unticks and the menu stays open; "Only" at
              // the row's end picks just that value and closes. Every other
              // key picks-and-closes through `onSelectValue`, with a ✓ on the
              // applied row. Enter follows the row: toggle for a checkbox
              // key, so arrows + Enter build a selection without the menu
              // closing.
              final isCheckbox = filterKey.checkboxMultiSelect;
              final actions = [
                for (final v in values)
                  isCheckbox
                      ? () => widget.onToggleValue(filterKey, v)
                      : () => widget.onSelectValue(filterKey, v),
              ];
              final keys = [for (final v in values) 'value:${v.rawValue}'];
              _scheduleRowPublish(controller, actions, keys, stamp: rowStamp);
              // The idle list of a long dimension is cut (see
              // [FilterKey.idleSuggestionCap]); say so in a trailing row
              // rather than passing 50 of 400 clients off as all of them.
              final cap = filterKey.idleSuggestionCap;
              final capped =
                  cap != null && query.trim().isEmpty && values.length >= cap;
              final extent = filterMenuRowExtent(context);
              return _MenuScroll(
                controller: controller,
                itemExtent: extent,
                builder: (scroll) => ListView.builder(
                  controller: scroll,
                  shrinkWrap: true,
                  // `values` is the only unbounded list in this menu
                  // (currencies / countries / statuses can run to
                  // hundreds). A fixed `itemExtent` lets the ListView know
                  // its scroll extent without laying out every row, so
                  // `shrinkWrap` stays O(1) and only the visible window is
                  // built.
                  itemExtent: extent,
                  itemCount: values.length + (capped ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == values.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: kMenuRowInsetLeft,
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            context.tr('filter_values_capped', {
                              'count': '$cap',
                            }),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: tokens.ink3,
                            ),
                          ),
                        ),
                      );
                    }
                    final v = values[i];
                    final isApplied = applied.contains(v.rawValue);
                    return _Highlightable(
                      controller: controller,
                      index: i,
                      checked: isCheckbox ? isApplied : null,
                      child: _ValueRow(
                        controller: controller,
                        index: i,
                        value: v,
                        isCheckbox: isCheckbox,
                        isApplied: isApplied,
                        onTap: actions[i],
                        onOnly: isCheckbox
                            ? () => widget.onPickExclusive(filterKey, v)
                            : null,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// One value row. A multi-select row leads with a checkbox and ends with
/// "Only"; a single-pick row leads with a ✓ when applied.
class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.controller,
    required this.index,
    required this.value,
    required this.isCheckbox,
    required this.isApplied,
    required this.onTap,
    required this.onOnly,
  });

  final FilterSuggestionController controller;
  final int index;
  final FilterValueSuggestion value;
  final bool isCheckbox;
  final bool isApplied;
  final VoidCallback onTap;

  /// "Only" — pick just this value and close. Null on a single-pick row.
  final VoidCallback? onOnly;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    // Fixed-width leading slot keeps row labels aligned regardless of which
    // rows are applied.
    final Widget leading = isCheckbox
        ? SizedBox(
            width: 20,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: _FilterCheckbox(checked: isApplied),
            ),
          )
        : SizedBox(
            width: 20,
            child: isApplied
                ? Icon(Icons.check, size: 16, color: tokens.accent)
                : null,
          );
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        // See `_SearchForRow` for the rationale. One whole-row detector means
        // the padding and the checkbox↔label gap stay tappable — no dead
        // zones, and no near-miss that does something other than the row.
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: kMenuRowInsetLeft),
          child: Row(
            children: [
              leading,
              if (isCheckbox) const SizedBox(width: InSpacing.sm),
              Expanded(
                child: Text(
                  value.displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.ink,
                  ),
                ),
              ),
              if (value.secondaryLabel != null)
                Text(
                  value.secondaryLabel!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.ink3,
                  ),
                ),
              if (onOnly != null)
                _OnlyButton(
                  controller: controller,
                  index: index,
                  onTap: onOnly!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The trailing "Only" on a multi-select row. Shown on the highlighted row
/// (hover or arrows) — and on every row on touch, where there is no hover to
/// reveal it. Its own detector sits inside the row's, so it wins the tap.
class _OnlyButton extends StatelessWidget {
  const _OnlyButton({
    required this.controller,
    required this.index,
    required this.onTap,
  });

  final FilterSuggestionController controller;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final label = context.tr('filter_only');
    final button = Semantics(
      button: true,
      label: label,
      onTap: onTap, // re-declared: the subtree that carries it is excluded
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          // Stretches to the row's full height and to the menu's edge, so on
          // touch it is a 44 px-tall target at least 44 px wide.
          padding: const EdgeInsetsDirectional.only(start: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: Env.isTouchPrimary ? 44 : 0),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              widthFactor: 1,
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: tokens.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (Env.isTouchPrimary) return button;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) => Visibility(
        visible: controller.selectedIndex == index,
        // Keep the slot: a row's label must not reflow as the highlight
        // moves over it.
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: child!,
      ),
      child: button,
    );
  }
}

/// The operator a comparable row list should pre-select: the one the user
/// typed (`<500`), else the key's default.
int _preselectedOp(List<FilterOp> ops, FilterOp? typed, FilterOp fallback) {
  final wanted = ops.indexOf(typed ?? fallback);
  return wanted < 0 ? 0 : wanted;
}

/// Renders the value menu for a typed-input key that exposes operators
/// (e.g. `BalanceFilterKey` with `[gt, lt]`). Each operator becomes a
/// row showing `<symbol> <value>` (or `<symbol> …` when the user hasn't
/// typed anything yet). Tapping a row commits the canonical wire through
/// [onPickExclusive] — replace, never toggle: re-entering the value that is
/// already applied must re-apply it, not clear it.
///
/// The row for the operator the user TYPED is the pre-selected one, so
/// `balance:<500` + Enter commits `< 500`. It used to commit row 0 (`>`)
/// whatever was typed.
class _OperatorRows extends StatelessWidget {
  const _OperatorRows({
    required this.vm,
    required this.filterKey,
    required this.query,
    required this.controller,
    required this.stamp,
    required this.onPickExclusive,
    required this.onPickOp,
  });

  final GenericListViewModel<dynamic> vm;
  final FilterKey filterKey;
  final String query;
  final FilterSuggestionController controller;
  final Object? stamp;
  final void Function(FilterKey key, FilterValueSuggestion value)
  onPickExclusive;
  final void Function(FilterKey key, FilterOp op) onPickOp;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    // Split a user-typed operator prefix (`>=1000`, `≤30`, `>1000`) from the
    // value — the operator is rendered in the leading slot instead.
    final typed = splitTypedOperator(query);
    final value = typed.value;
    final ops = filterKey.supportedOps;
    final comparable = filterKey as ComparableFilterKey;
    // The key's own normalizer decides whether what is typed is a value at
    // all (`balance:abc` is not) and what it canonically is (`1,5` → `1.5`
    // under a comma-decimal company).
    final normalized = value.isEmpty
        ? null
        : filterKey.normalizeTypedValue(vm, context, value);
    final canonical = normalized == null
        ? null
        : comparable.parseWire(normalized).$1;
    final invalid = value.isNotEmpty && canonical == null;

    final actions = <VoidCallback>[
      for (final op in ops)
        () {
          if (value.isEmpty) {
            // Pick-op-first flow: write `<key>:<symbol>` to the input
            // so the user can type the value next. The actual commit
            // happens via Enter (or by re-clicking once a value is
            // present).
            onPickOp(filterKey, op);
            return;
          }
          if (canonical == null) return; // not a value yet — keep typing
          onPickExclusive(
            filterKey,
            FilterValueSuggestion(
              rawValue: comparable.buildWire(canonical, op),
              displayLabel:
                  '${filterOpPhrase(context, op, filterKey.valueType)} '
                  '$canonical',
            ),
          );
        },
    ];
    // The typed operator is part of the row identity: typing one re-keys the
    // rows, which is what lets `preselect` move the highlight to it. Typing
    // the value's digits leaves the keys alone, so the highlight then stays
    // where the user (or that preselect) put it.
    final keys = <Object>[
      for (final op in ops) 'op:${op.name}|${typed.op?.name ?? ''}',
    ];
    // Nothing committable while the value is not a value: the rows are still
    // drawn (and say why, above), but an action that runs and does nothing
    // still counts as "committed" to Enter and Tab — which is how Tab got
    // swallowed on `balance:abc`.
    _scheduleRowPublish(
      controller,
      invalid ? const [] : actions,
      invalid ? const [] : keys,
      stamp: stamp,
      preselect: _preselectedOp(ops, typed.op, comparable.defaultOp),
    );
    return _MenuScroll(
      controller: controller,
      builder: (scroll) => ListView(
        controller: scroll,
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: [
          if (invalid || value.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
              child: Text(
                filterKey.hintForValueMode(context) ??
                    context.tr('enter_amount'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: invalid ? tokens.overdue : tokens.ink3,
                ),
              ),
            ),
          for (var i = 0; i < ops.length; i++)
            _Highlightable(
              controller: controller,
              index: i,
              child: _OperatorRow(
                label: filterOpPhrase(context, ops[i], filterKey.valueType),
                value: value,
                onTap: actions[i],
                theme: theme,
                ink: invalid ? tokens.ink3 : tokens.ink,
                muted: tokens.ink3,
              ),
            ),
        ],
      ),
    );
  }
}

class _OperatorRow extends StatelessWidget {
  const _OperatorRow({
    required this.label,
    required this.value,
    required this.onTap,
    required this.theme,
    required this.ink,
    required this.muted,
  });

  /// Comparator label — math symbol for numbers (`≥`), localized phrase
  /// for dates (*is on or after*).
  final String label;
  final String value;
  final VoidCallback onTap;
  final ThemeData theme;
  final Color ink;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    // See `_SearchForRow` for the GestureDetector rationale.
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: _RowFloor(
          child: Row(
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  // Placeholder `…` when no value typed yet — invites
                  // the user to type after picking the operator.
                  value.isEmpty ? '…' : value,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: value.isEmpty ? muted : ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One-step rows for a date the user has typed: one row per comparator, each
/// reading the way the chip will (`is on or after 14 May 2026`) so an
/// ambiguous `5/6` shows how it was understood before it is committed. The
/// comparator typed in front of the date — or the key's default — is the
/// pre-selected row, so Enter commits what was typed.
class _TypedDateRows extends StatelessWidget {
  const _TypedDateRows({
    required this.vm,
    required this.filterKey,
    required this.typed,
    required this.chosenOp,
    required this.controller,
    required this.stamp,
    required this.onPickExclusive,
  });

  final GenericListViewModel<dynamic> vm;
  final DateColumnFilterKey filterKey;
  final ({String value, FilterOp? op}) typed;

  /// The comparator picked in the preset list's first step before the user
  /// started typing, if any. A comparator typed in front of the date wins
  /// over it; it wins over the key's default.
  final FilterOp? chosenOp;
  final FilterSuggestionController controller;
  final Object? stamp;
  final void Function(FilterKey key, FilterValueSuggestion value)
  onPickExclusive;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final display = filterKey.chipValueLabel(vm, context, typed.value);

    // A window-only key (tasks' due date) has no single-date comparator on
    // the server: the one thing a typed date can mean there is that day.
    final ops = filterKey.windowOnly
        ? const [FilterOp.eq]
        : [
            for (final op in filterKey.supportedOps)
              if (op != FilterOp.between) op,
          ];
    final actions = <VoidCallback>[
      for (final op in ops)
        () => onPickExclusive(
          filterKey,
          FilterValueSuggestion(
            rawValue: filterKey.windowOnly
                ? filterKey.canonicalWindow(typed.value, typed.value)
                : filterKey.buildWire(typed.value, op),
            displayLabel: display,
          ),
        ),
    ];
    // What the user asked for, most explicit first: a comparator typed in
    // front of the date, the one picked from the list before typing, the
    // key's default. (`between` can be the picked one; a single typed date
    // has no row for it, so it falls through.)
    final wanted =
        typed.op ??
        (ops.contains(chosenOp) ? chosenOp : null) ??
        (filterKey.windowOnly ? FilterOp.eq : filterKey.defaultOp);
    final keys = <Object>[
      for (final op in ops) 'date:${op.name}|${wanted.name}',
    ];
    _scheduleRowPublish(
      controller,
      actions,
      keys,
      stamp: stamp,
      preselect: _preselectedOp(ops, wanted, wanted),
    );
    return _MenuScroll(
      controller: controller,
      builder: (scroll) => ListView(
        controller: scroll,
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: [
          for (var i = 0; i < ops.length; i++)
            _Highlightable(
              controller: controller,
              index: i,
              child: _OperatorRow(
                label: filterOpPhrase(context, ops[i], FilterValueType.date),
                value: display,
                onTap: actions[i],
                theme: theme,
                ink: tokens.ink,
                muted: tokens.ink3,
              ),
            ),
        ],
      ),
    );
  }
}

/// Two-step value picker for a comparable **date** key: the user picks
/// the **comparator first** (step 1: *is after / is on or after / …*,
/// the key's `defaultOp` pre-highlighted), **then the value** (step 2:
/// relative presets + "Absolute date →"). Step 2 carries a contextual
/// header (the comparator's phrase) and a leading "‹ Back" row that returns
/// to step 1. All commits emit the canonical wire `op:value`.
///
/// A key with a single comparator (a window-only date) has nothing to choose
/// in step 1 and opens straight on step 2.
class _DateValueRows extends StatefulWidget {
  const _DateValueRows({
    required this.vm,
    required this.filterKey,
    required this.query,
    required this.invalid,
    required this.chosenOp,
    required this.onChooseOp,
    required this.controller,
    required this.stamp,
    required this.onPickExclusive,
    required this.onDismiss,
  });

  final GenericListViewModel<dynamic> vm;
  final FilterKey filterKey;
  final String query;

  /// Something is typed after `<key>:` and it is not a date. The rows still
  /// work for a pointer, but Enter has nothing to commit and a line says why.
  final bool invalid;

  /// The comparator picked in step 1, or null while still on step 1. Owned by
  /// `_ValueListState`, which outlives this widget being swapped for the
  /// typed-date rows.
  final FilterOp? chosenOp;
  final ValueChanged<FilterOp?> onChooseOp;
  final FilterSuggestionController controller;
  final Object? stamp;

  /// Replace-not-toggle commit (→ `controller.selectValueExclusive` →
  /// `key.selectExclusive`). Every value here commits through it, so
  /// re-picking the value that is already applied re-applies it instead of
  /// clearing it (a toggling commit would remove it).
  final void Function(FilterKey key, FilterValueSuggestion value)
  onPickExclusive;

  /// See [FilterSuggestionMenu.onDismiss]. Both rows below push a route and
  /// await it, so both must close the host surface first.
  final VoidCallback? onDismiss;

  @override
  State<_DateValueRows> createState() => _DateValueRowsState();
}

class _DateValueRowsState extends State<_DateValueRows> {
  ComparableFilterKey get _key => widget.filterKey as ComparableFilterKey;

  bool get _singleOp => widget.filterKey.supportedOps.length == 1;

  /// The comparator step 2 is for. A key with one comparator has nothing to
  /// choose and is always on step 2.
  FilterOp? get _chosenOp =>
      widget.chosenOp ??
      (_singleOp ? widget.filterKey.supportedOps.single : null);

  /// What Enter may commit: nothing, while the typed text is not a date.
  void _publish(
    List<VoidCallback> actions,
    List<Object> rowKeys, {
    required int preselect,
  }) {
    _scheduleRowPublish(
      widget.controller,
      widget.invalid ? const [] : actions,
      widget.invalid ? const [] : rowKeys,
      stamp: widget.stamp,
      preselect: preselect,
    );
  }

  /// The line that says the typed text is not a date, above the rows.
  List<Widget> _invalidHint(BuildContext context) => [
    if (widget.invalid)
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
        child: Text(
          context.tr('filter_date_not_understood'),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.inTheme.overdue),
        ),
      ),
  ];

  /// Op to pre-highlight in step 1: the one already on the chip / typed,
  /// else the key's default.
  FilterOp get _effectiveOp {
    final dateKey = widget.filterKey is DateColumnFilterKey
        ? widget.filterKey as DateColumnFilterKey
        : null;
    final applied = widget.filterKey.tokensFrom(widget.vm, context).toList();
    if (applied.isNotEmpty) {
      final raw = applied.first.rawValue;
      if (dateKey != null && dateKey.isWindowWire(raw)) {
        return FilterOp.between;
      }
      return _key.parseWire(raw).$2;
    }
    final typed = splitTypedOperator(widget.query).op;
    return typed ?? _key.defaultOp;
  }

  @override
  Widget build(BuildContext context) {
    return _chosenOp == null ? _comparatorStep(context) : _valueStep(context);
  }

  // ── Step 1: pick the comparator ──────────────────────────────────────
  Widget _comparatorStep(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final ops = widget.filterKey.supportedOps;
    final defaultOp = _effectiveOp;

    final actions = <VoidCallback>[];
    final rowKeys = <Object>[];
    final rows = <Widget>[];
    var defaultIndex = 0;
    for (var i = 0; i < ops.length; i++) {
      final op = ops[i];
      if (op == defaultOp) defaultIndex = i;
      void pick() => widget.onChooseOp(op);
      actions.add(pick);
      rowKeys.add('op:${op.name}');
      rows.add(
        _Highlightable(
          controller: widget.controller,
          index: i,
          child: _MenuTextRow(
            label: filterOpPhrase(context, op, widget.filterKey.valueType),
            theme: theme,
            ink: tokens.ink,
            onTap: pick,
            selected: op == defaultOp,
          ),
        ),
      );
    }
    // Pre-select the default op so Enter is a one-keystroke fast path — as
    // part of the publish, which applies it only when these rows are NEW.
    // It used to be a post-frame `setSelectedIndex` on every build, and this
    // widget rebuilds on every VM notify: the highlight snapped back to the
    // default while the user was arrowing through the list.
    _publish(actions, rowKeys, preselect: defaultIndex);
    return _MenuScroll(
      controller: widget.controller,
      builder: (scroll) => ListView(
        controller: scroll,
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: [..._invalidHint(context), ...rows],
      ),
    );
  }

  // ── Step 2: pick the value (op already chosen) ───────────────────────
  Widget _valueStep(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final op = _chosenOp!;

    final actions = <VoidCallback>[];
    final rowKeys = <Object>[];
    final rows = <Widget>[];

    void addRow(String label, Object rowKey, VoidCallback onTap) {
      final i = actions.length;
      actions.add(onTap);
      rowKeys.add(rowKey);
      rows.add(
        _Highlightable(
          controller: widget.controller,
          index: i,
          child: _MenuTextRow(
            label: label,
            theme: theme,
            ink: tokens.ink,
            onTap: onTap,
          ),
        ),
      );
    }

    // Back to the comparator step — when there was one to come from.
    if (!_singleOp) {
      addRow('‹  ${context.tr('change_comparator')}', 'back', () {
        widget.onChooseOp(null);
      });
    }
    // The first row that is a VALUE, so Enter on a fresh step 2 picks one
    // instead of walking straight back to step 1.
    final firstValueRow = actions.length;

    final header = _MenuSectionLabel(
      text: filterOpPhrase(context, op, widget.filterKey.valueType),
      theme: theme,
      muted: tokens.ink3,
    );

    // `between` → dual-calendar window picker (no relative presets /
    // single absolute date — the value is a closed [start, end] range).
    if (op == FilterOp.between && widget.filterKey is DateColumnFilterKey) {
      final dateKey = widget.filterKey as DateColumnFilterKey;
      addRow('${context.tr('date_range')}  →', 'range', () async {
        final formatter = context.read<Services>().formatterIfReady(
          widget.vm.companyId,
        );
        // Seed from the applied window, so re-opening an existing range
        // starts on it rather than on today.
        final applied = [
          for (final t in dateKey.tokensFrom(widget.vm, context))
            if (dateKey.isWindowWire(t.rawValue)) t.rawValue,
        ];
        final seed = applied.isEmpty
            ? null
            : dateKey.parseWindow(applied.first);
        widget.onDismiss?.call(); // before the await — see [onDismiss]
        final wire = await pickDateRangeWindow(
          context,
          column: dateKey.serverKey,
          formatter: formatter,
          seed: seed,
        );
        if (wire == null) return;
        final (start, end) = dateKey.parseWindow(wire);
        // Replace-not-toggle: re-picking the same window re-applies it
        // (onSelectValue would treat an identical rawValue as "applied"
        // and clear it).
        widget.onPickExclusive(
          widget.filterKey,
          FilterValueSuggestion(rawValue: wire, displayLabel: '$start – $end'),
        );
      });
      _publish(actions, rowKeys, preselect: firstValueRow);
      return _MenuScroll(
        controller: widget.controller,
        builder: (scroll) => ListView(
          controller: scroll,
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          children: [header, ..._invalidHint(context), ...rows],
        ),
      );
    }

    for (final (token, labelKey) in kRelativeDatePresets) {
      addRow(context.tr(labelKey), 'rel:$token', () {
        widget.onPickExclusive(
          widget.filterKey,
          FilterValueSuggestion(
            rawValue: _key.buildWire(token, op),
            displayLabel: context.tr(labelKey),
          ),
        );
      });
    }

    addRow('${context.tr('absolute_date')}  →', 'abs', () async {
      widget.onDismiss?.call(); // before the await — see [onDismiss]
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: DateTime(2000),
        lastDate: DateTime(now.year + 5),
      );
      if (picked == null) return;
      final iso =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
      widget.onPickExclusive(
        widget.filterKey,
        FilterValueSuggestion(
          rawValue: _key.buildWire(iso, op),
          displayLabel: iso,
        ),
      );
    });

    _publish(actions, rowKeys, preselect: firstValueRow);
    return _MenuScroll(
      controller: widget.controller,
      builder: (scroll) => ListView(
        controller: scroll,
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: [header, ..._invalidHint(context), ...rows],
      ),
    );
  }
}

class _MenuSectionLabel extends StatelessWidget {
  const _MenuSectionLabel({
    required this.text,
    required this.theme,
    required this.muted,
  });

  final String text;
  final ThemeData theme;
  final Color muted;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
    child: Text(
      text,
      style: theme.textTheme.labelSmall?.copyWith(
        color: muted,
        letterSpacing: 0.6,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _MenuTextRow extends StatelessWidget {
  const _MenuTextRow({
    required this.label,
    required this.theme,
    required this.ink,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final ThemeData theme;
  final Color ink;
  final VoidCallback onTap;

  /// Leading ✓ + bold — marks the pre-highlighted default comparator.
  final bool selected;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      // See `_SearchForRow` for the GestureDetector rationale.
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        // ≥44 px row so the date value picker stays thumb-friendly in
        // the narrow-mode FilterEntrySheet.
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: selected ? Icon(Icons.check, size: 16, color: ink) : null,
            ),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: ink,
                  fontWeight: selected ? FontWeight.w600 : null,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Wraps a row in a tint when the controller's selected index equals
/// [index], and moves that index to the row as the pointer moves over it, so
/// hover and keyboard share a single highlight state. Listening only to the
/// controller keeps the row rebuild cheap (no full menu rebuild on highlight
/// changes).
///
/// **`onHover`, not `onEnter`.** `onEnter` also fires when a row APPEARS
/// under a pointer that is not moving — the menu opening beneath a cursor
/// parked below the search box. That row took the highlight, and Enter then
/// committed it instead of "Search for …": type a term, press Enter, get an
/// arbitrary filter. `onHover` needs the pointer to actually move.
///
/// When the highlight reaches this row by KEYBOARD it scrolls itself into
/// view; before, arrowing past the eighth row walked the highlight off the
/// bottom of the menu.
class _Highlightable extends StatefulWidget {
  const _Highlightable({
    required this.controller,
    required this.index,
    required this.child,
    this.checked,
  });

  final FilterSuggestionController controller;
  final int index;
  final Widget child;

  /// The tick state of a multi-select row, for a screen reader. Null for a
  /// row that is not a checkbox.
  final bool? checked;

  @override
  State<_Highlightable> createState() => _HighlightableState();
}

class _HighlightableState extends State<_Highlightable> {
  bool _wasSelected = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onController);
    _wasSelected = widget.controller.selectedIndex == widget.index;
  }

  @override
  void didUpdateWidget(covariant _Highlightable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onController);
      widget.controller.addListener(_onController);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    super.dispose();
  }

  void _onController() {
    final selected = widget.controller.selectedIndex == widget.index;
    final became = selected && !_wasSelected;
    _wasSelected = selected;
    if (!became || !widget.controller.movedByKeyboard) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final object = context.findRenderObject();
      // The NEAREST scrollable only — `Scrollable.ensureVisible` walks every
      // ancestor, and an embedded list's field sits inside the record page's
      // own scroll view.
      final position = Scrollable.maybeOf(context)?.position;
      if (object == null || position == null) return;
      // Both keep-visible policies: each scrolls only when the row is clipped
      // on its side, so a row already on screen does not move.
      position.ensureVisible(
        object,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
      position.ensureVisible(
        object,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return MouseRegion(
      onHover: (_) => widget.controller.setSelectedIndex(widget.index),
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          // Only a PUBLISHED row can be the highlighted one: a list that
          // publishes none (an invalid typed value) must not light up its
          // first row as though Enter would take it.
          final selected =
              widget.index < widget.controller.rowCount &&
              widget.controller.selectedIndex == widget.index;
          return Semantics(
            button: true,
            selected: selected,
            checked: widget.checked,
            child: Container(
              color: selected ? tokens.surfaceAlt : Colors.transparent,
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

/// Small rounded-square checkbox for the [FilterKey.checkboxMultiSelect]
/// value picker. Deliberately not [SelectionCheckbox] (32px circular,
/// list-row styled) — this is an 18px square that matches the design
/// system's rounded-rectangle rule and the compact 40px menu rows.
class _FilterCheckbox extends StatelessWidget {
  const _FilterCheckbox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: checked ? tokens.accent : tokens.surface,
        borderRadius: BorderRadius.circular(InRadii.r1),
        border: Border.all(
          color: checked ? tokens.accent : tokens.borderStrong,
          width: 1.5,
        ),
      ),
      child: checked
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : null,
    );
  }
}
