import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/date_column_filter_key.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_suggestion_controller.dart';
import 'package:admin/ui/core/list/search/filter_token.dart';
import 'package:admin/ui/features/dashboard/widgets/filters/date_range_picker_button.dart';

/// Horizontal padding applied to every menu row's content (key / value /
/// operator / search-for). Exposed so the field's overlay positioning can
/// subtract it from the cursor's x to land the row text — not the painted
/// menu edge — under the typing column.
const double kMenuRowInsetLeft = 12.0;

/// Max width of the floating suggestion menu. Shared with the field's overlay
/// positioning (`token_search_field.dart`) so the right-edge clamp keeps the
/// painted menu fully on-screen.
const double kFilterMenuMaxWidth = 420;

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
///   * **Key mode** (`parse.matchedKey == null`): renders a flat list of
///     every available [FilterKey], plus a "Search for `query`" row when
///     [query] is non-empty so free-text submission is an explicit choice.
///   * **Value mode** (`parse.matchedKey != null`): streams value
///     suggestions from the matched key.
///
/// Selection routes through the three callbacks rather than mutating the VM
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

  /// Checkbox half of the [FilterKey.checkboxMultiSelect] split action:
  /// toggle the value and keep the menu open.
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

  /// Row-label half of the split action: select only this value and close.
  final void Function(FilterKey key, FilterValueSuggestion value)
  onPickExclusive;

  /// Fired when the user clicks an operator row with no value typed yet —
  /// the caller writes a key-prefixed symbol into the input (e.g.
  /// `balance:>`) so the user can keep typing the value. With a value
  /// typed, the click commits through [onSelectValue] instead.
  final void Function(FilterKey key, FilterOp op) onPickOp;

  final ValueChanged<String> onCommitFreeText;
  final double maxHeight;

  /// Whether the menu is a floating popup (wide mode) — gets the bordered,
  /// elevated, clipped chrome. `false` for the full-bleed narrow-mode
  /// [FilterEntrySheet] panel, which renders flat below a divider.
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final child = ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxHeight,
        maxWidth: kFilterMenuMaxWidth,
      ),
      child: parse.matchedKey == null
          ? _KeyList(
              vm: vm,
              keys: keys,
              query: parse.query.trim(),
              controller: controller,
              onSelectKey: onSelectKey,
              onSelectValue: onSelectValue,
              onCommitFreeText: onCommitFreeText,
            )
          : _ValueList(
              vm: vm,
              filterKey: parse.matchedKey!,
              query: parse.query,
              controller: controller,
              onSelectValue: onSelectValue,
              onToggleValue: onToggleValue,
              onPickExclusive: onPickExclusive,
              onPickOp: onPickOp,
              onDismiss: onDismiss,
            ),
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
  List<Object> keys,
) {
  SchedulerBinding.instance.addPostFrameCallback((_) {
    controller.publishRows(actions, keys);
  });
}

class _KeyList extends StatelessWidget {
  const _KeyList({
    required this.vm,
    required this.keys,
    required this.query,
    required this.controller,
    required this.onSelectKey,
    required this.onSelectValue,
    required this.onCommitFreeText,
  });

  final GenericListViewModel<dynamic> vm;
  final List<FilterKey> keys;
  final String query;
  final FilterSuggestionController controller;
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
    final q = query.toLowerCase();
    final available = availableKeyPickerKeys(keys, vm);
    final filtered = q.isEmpty
        ? available
        : available.where((k) {
            // Match by id, alias, or localized display label so a user
            // typing "stat" finds `status` (alias of `is`).
            final label = k.displayLabel(context).toLowerCase();
            return k.id.contains(q) ||
                label.contains(q) ||
                k.aliases.any((a) => a.contains(q));
          }).toList();
    // Sort alphabetically by the user-visible (localized) label so the
    // dropdown reads like an A→Z list regardless of the registry order
    // in `client_filter_keys.dart`. See `compareFilterKeysByLabel`.
    filtered.sort((a, b) => compareFilterKeysByLabel(a, b, context));

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

    if (query.isNotEmpty) {
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
    }
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
    if (query.isNotEmpty && filtered.isNotEmpty) {
      rows.add(_SectionHeader(text: context.tr('filters_section')));
    }
    for (final k in filtered) {
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
    if (filtered.isEmpty && query.isEmpty) {
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

    _scheduleRowPublish(controller, actions, rowKeys);

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: rows,
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

/// Uppercase letter-spaced section divider, reused by the "Filter values"
/// and "Filters" headers in the key-mode picker.
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
    // See `_SearchForRow` for the GestureDetector rationale.
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _ValueList extends StatelessWidget {
  const _ValueList({
    required this.vm,
    required this.filterKey,
    required this.query,
    required this.controller,
    required this.onSelectValue,
    required this.onToggleValue,
    required this.onPickExclusive,
    required this.onPickOp,
    required this.onDismiss,
  });

  final GenericListViewModel<dynamic> vm;
  final FilterKey filterKey;
  final String query;
  final FilterSuggestionController controller;
  final void Function(FilterKey key, FilterValueSuggestion value) onSelectValue;
  final void Function(FilterKey key, FilterValueSuggestion value) onToggleValue;

  /// See [FilterSuggestionMenu.onDismiss] — forwarded to the date rows, which
  /// are the only ones that push a route.
  final VoidCallback? onDismiss;
  final void Function(FilterKey key, FilterValueSuggestion value)
  onPickExclusive;
  final void Function(FilterKey key, FilterOp op) onPickOp;

  @override
  Widget build(BuildContext context) {
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
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Text(
            filterKey.displayLabel(context),
            style: theme.textTheme.labelSmall?.copyWith(
              color: tokens.ink3,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Flexible(
          child: StreamBuilder<List<FilterValueSuggestion>>(
            stream: filterKey.watchValueSuggestions(vm, context, query),
            builder: (context, snapshot) {
              final values = snapshot.data ?? const <FilterValueSuggestion>[];
              if (values.isEmpty) {
                // Typed-value keys (name, balance, created, …) opt-in to
                // a key-specific hint via `hintForValueMode` — falls back
                // to the generic "No matches" copy for pick-list keys.
                // Keys that also declare `supportedOps` upgrade this slot
                // to an operator picker so the user can choose between
                // `> value` / `< value` instead of just typing-and-enter.
                if (filterKey.supportedOps.isNotEmpty) {
                  // Comparable DATE keys get the relative-preset +
                  // absolute-date value picker (with comparator rows
                  // below); numeric keys keep the plain operator picker.
                  if (filterKey.valueType == FilterValueType.date) {
                    return _DateValueRows(
                      vm: vm,
                      filterKey: filterKey,
                      query: query,
                      controller: controller,
                      onSelectValue: onSelectValue,
                      onPickExclusive: onPickExclusive,
                      onDismiss: onDismiss,
                    );
                  }
                  return _OperatorRows(
                    filterKey: filterKey,
                    query: query,
                    controller: controller,
                    onSelectValue: onSelectValue,
                    onPickOp: onPickOp,
                  );
                }
                _scheduleRowPublish(controller, const [], const <Object>[]);
                final hint =
                    filterKey.hintForValueMode(context) ??
                    context.tr('no_values_match');
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    hint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.ink3,
                    ),
                  ),
                );
              }
              // Non-checkbox keys: every value click funnels through
              // `onSelectValue` — the field (or the entry sheet) owns the
              // add/remove dispatch + dismiss decision; the ✓ icon shows
              // applied state. Checkbox keys ([FilterKey.checkboxMultiSelect])
              // split the row: tapping the checkbox toggles & stays open,
              // tapping the label picks-only & closes. Keyboard Enter on a
              // checkbox key uses the sticky toggle so arrow-keys + Enter
              // build a multi-selection without the menu closing.
              final isCheckbox = filterKey.checkboxMultiSelect;
              final actions = [
                for (final v in values)
                  isCheckbox
                      ? () => onToggleValue(filterKey, v)
                      : () => onSelectValue(filterKey, v),
              ];
              final keys = [for (final v in values) 'value:${v.rawValue}'];
              _scheduleRowPublish(controller, actions, keys);
              return ListView.builder(
                shrinkWrap: true,
                // `values` is the only unbounded list in this menu
                // (currencies / countries / statuses can run to
                // hundreds). A fixed `itemExtent` lets the ListView know
                // its scroll extent without laying out every row, so
                // `shrinkWrap` stays O(1) and only the visible window is
                // built. Rows are a single line (12px h-pad, 10px v-pad,
                // bodyMedium) ≈ 40px.
                itemExtent: 40,
                itemCount: values.length,
                itemBuilder: (context, i) {
                  final v = values[i];
                  final isApplied = applied.contains(v.rawValue);
                  final label = Text(
                    v.displayLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: tokens.ink,
                    ),
                  );
                  final Widget? secondary = v.secondaryLabel == null
                      ? null
                      : Text(
                          v.secondaryLabel!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tokens.ink3,
                          ),
                        );

                  // Leading slot: a checkbox in its OWN nested detector for
                  // checkbox keys, else the static ✓-icon. The checkbox
                  // detector is the innermost recognizer so it wins the tap
                  // arena (checkbox → sticky toggle); everything else on the
                  // row falls through to the whole-row detector below
                  // (pick-only & close / `onSelectValue`). One whole-row
                  // detector means the 12px padding + the checkbox↔label
                  // gap stay tappable — no dead zones.
                  final Widget leading = isCheckbox
                      ? GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onToggleValue(filterKey, v),
                          child: SizedBox(
                            width: 20,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _FilterCheckbox(checked: isApplied),
                            ),
                          ),
                        )
                      : SizedBox(
                          width: 20,
                          child: isApplied
                              ? Icon(
                                  Icons.check,
                                  size: 16,
                                  color: tokens.accent,
                                )
                              : null,
                        );

                  return _Highlightable(
                    controller: controller,
                    index: i,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        // See `_SearchForRow` for the rationale.
                        behavior: HitTestBehavior.opaque,
                        onTap: isCheckbox
                            ? () => onPickExclusive(filterKey, v)
                            : actions[i],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              // Fixed-width leading slot keeps row labels
                              // aligned regardless of which rows are applied.
                              leading,
                              if (isCheckbox)
                                const SizedBox(width: InSpacing.sm),
                              Expanded(child: label),
                              if (secondary != null) secondary,
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Renders the value menu for a typed-input key that exposes operators
/// (e.g. `BalanceFilterKey` with `[gt, lt]`). Each operator becomes a
/// row showing `<symbol> <value>` (or `<symbol> …` when the user hasn't
/// typed anything yet). Tapping a row commits the suffix wire format
/// `<value>:<op.name>` through `onSelectValue`, which the key parses
/// back via its own `addValue` path.
///
/// Empty-query state intentionally still publishes the row actions so
/// arrow-key navigation works once the user types — the actions just
/// no-op until a value is present.
class _OperatorRows extends StatelessWidget {
  const _OperatorRows({
    required this.filterKey,
    required this.query,
    required this.controller,
    required this.onSelectValue,
    required this.onPickOp,
  });

  final FilterKey filterKey;
  final String query;
  final FilterSuggestionController controller;
  final void Function(FilterKey key, FilterValueSuggestion value) onSelectValue;
  final void Function(FilterKey key, FilterOp op) onPickOp;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    // Strip a user-typed operator prefix (`>=1000`, `≤30`, `>1000`) so
    // the displayed value shows the bare value alone — the operator is
    // rendered in the leading slot instead.
    var value = query.trim();
    for (final prefix in const ['>=', '<=', '≥', '≤', '>', '<', '=']) {
      if (value.startsWith(prefix)) {
        value = value.substring(prefix.length).trim();
        break;
      }
    }
    final ops = filterKey.supportedOps;
    final comparable = filterKey is ComparableFilterKey
        ? filterKey as ComparableFilterKey
        : null;
    final actions = <VoidCallback>[
      for (final op in ops)
        () {
          if (value.isEmpty) {
            // Pick-op-first flow: write `<key>:<symbol>` to the input
            // so the user can type the value next. The actual commit
            // happens via Enter (or by re-clicking once a value is
            // present), routed back through `addValue`.
            onPickOp(filterKey, op);
            return;
          }
          onSelectValue(
            filterKey,
            FilterValueSuggestion(
              rawValue: comparable?.buildWire(value, op) ?? '$value:${op.name}',
              displayLabel:
                  '${filterOpPhrase(context, op, filterKey.valueType)} '
                  '$value',
            ),
          );
        },
    ];
    final keys = <Object>[for (final op in ops) 'op:${op.name}'];
    _scheduleRowPublish(controller, actions, keys);
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        for (var i = 0; i < ops.length; i++)
          _Highlightable(
            controller: controller,
            index: i,
            child: _OperatorRow(
              label: filterOpPhrase(context, ops[i], filterKey.valueType),
              value: value,
              onTap: actions[i],
              theme: theme,
              ink: tokens.ink,
              muted: tokens.ink3,
            ),
          ),
      ],
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

/// Two-step value picker for a comparable **date** key: the user picks
/// the **comparator first** (step 1: *is after / is on or after / …*,
/// the key's `defaultOp` pre-highlighted), **then the value** (step 2:
/// relative presets + "Absolute date →"). Step 2 carries a contextual
/// header (`<Field> · <phrase>`) and a leading "‹ Back" row that returns
/// to step 1. All commits emit the canonical wire `op:value`.
class _DateValueRows extends StatefulWidget {
  const _DateValueRows({
    required this.vm,
    required this.filterKey,
    required this.query,
    required this.controller,
    required this.onSelectValue,
    required this.onPickExclusive,
    required this.onDismiss,
  });

  final GenericListViewModel<dynamic> vm;
  final FilterKey filterKey;
  final String query;
  final FilterSuggestionController controller;
  final void Function(FilterKey key, FilterValueSuggestion value) onSelectValue;

  /// Replace-not-toggle commit (→ `controller.selectValueExclusive` →
  /// `key.selectExclusive`). Used for the `between` window so re-picking
  /// the *same* range re-applies it instead of clearing it (the
  /// applied-match toggle in `onSelectValue` would remove it).
  final void Function(FilterKey key, FilterValueSuggestion value)
  onPickExclusive;

  /// See [FilterSuggestionMenu.onDismiss]. Both rows below push a route and
  /// await it, so both must close the host surface first.
  final VoidCallback? onDismiss;

  @override
  State<_DateValueRows> createState() => _DateValueRowsState();
}

class _DateValueRowsState extends State<_DateValueRows> {
  FilterOp? _chosenOp;

  ComparableFilterKey get _key => widget.filterKey as ComparableFilterKey;

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
    final q = widget.query.trim();
    if (q.isNotEmpty) return _key.parseWire(q).$2;
    return _key.defaultOp;
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
      void pick() => setState(() => _chosenOp = op);
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
    _scheduleRowPublish(widget.controller, actions, rowKeys);
    // Pre-select the default op so Enter is a one-keystroke fast path.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.setSelectedIndex(defaultIndex);
    });
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        _MenuSectionLabel(
          text: context.tr('change_comparator'),
          theme: theme,
          muted: tokens.ink3,
        ),
        ...rows,
      ],
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

    // Back to the comparator step.
    addRow('‹  ${context.tr('change_comparator')}', 'back', () {
      setState(() => _chosenOp = null);
    });

    // `between` → dual-calendar window picker (no relative presets /
    // single absolute date — the value is a closed [start, end] range).
    if (op == FilterOp.between && widget.filterKey is DateColumnFilterKey) {
      final dateKey = widget.filterKey as DateColumnFilterKey;
      addRow('${context.tr('date_range')}  →', 'range', () async {
        final formatter = context.read<Services>().formatterIfReady(
          widget.vm.companyId,
        );
        widget.onDismiss?.call(); // before the await — see [onDismiss]
        final wire = await pickDateRangeWindow(
          context,
          column: dateKey.serverKey,
          formatter: formatter,
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
      _scheduleRowPublish(widget.controller, actions, rowKeys);
      final betweenHeader =
          '${widget.filterKey.displayLabel(context)} · '
          '${filterOpPhrase(context, op, widget.filterKey.valueType)}';
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: [
          _MenuSectionLabel(
            text: betweenHeader,
            theme: theme,
            muted: tokens.ink3,
          ),
          ...rows,
        ],
      );
    }

    for (final (token, labelKey) in kRelativeDatePresets) {
      addRow(context.tr(labelKey), 'rel:$token', () {
        widget.onSelectValue(
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
      widget.onSelectValue(
        widget.filterKey,
        FilterValueSuggestion(
          rawValue: _key.buildWire(iso, op),
          displayLabel: iso,
        ),
      );
    });

    _scheduleRowPublish(widget.controller, actions, rowKeys);
    final header =
        '${widget.filterKey.displayLabel(context)} · '
        '${filterOpPhrase(context, op, widget.filterKey.valueType)}';
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        _MenuSectionLabel(text: header, theme: theme, muted: tokens.ink3),
        ...rows,
      ],
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
/// [index], and updates that index on mouse enter so hover and keyboard
/// share a single highlight state. Listening only to the controller keeps
/// the row rebuild cheap (no full menu rebuild on highlight changes).
class _Highlightable extends StatelessWidget {
  const _Highlightable({
    required this.controller,
    required this.index,
    required this.child,
  });

  final FilterSuggestionController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return MouseRegion(
      // Hover drives the same `_selectedIndex` the keyboard arrow keys
      // do, so mouse + keyboard users see identical highlight feedback
      // and Enter commits whichever row was last interacted with.
      onEnter: (_) => controller.setSelectedIndex(index),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final selected = controller.selectedIndex == index;
          return Container(
            color: selected ? tokens.surfaceAlt : Colors.transparent,
            child: child,
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
