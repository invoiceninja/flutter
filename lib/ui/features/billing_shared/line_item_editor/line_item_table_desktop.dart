import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/billing/line_item_custom_fields.dart';
import 'package:admin/data/models/domain/billing/line_item_type.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_custom_fields.dart';
import 'package:admin/data/models/domain/custom_field_types.dart';
import 'package:admin/data/models/domain/product.dart';
import 'package:admin/data/models/domain/tax_rate.dart';
import 'package:admin/domain/date_placeholders.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/custom_field_input.dart';
import 'package:admin/ui/core/widgets/back_dismissible_menu_anchor.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/picker_dismissal.dart';
import 'package:admin/ui/core/widgets/scroll_edge_fades.dart';
import 'package:admin/ui/core/widgets/spell_check.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_column_config.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/product_stock_label.dart';
import 'package:admin/utils/formatting.dart';

// Cell-level layout constants. These are sub-token (smaller than
// `InSpacing.sm`) and apply only inside the items-table grid; outer
// spacing still flows through `InSpacing.md/lg(context)` per CLAUDE.md.
const double _kCellPadH = 8;
const double _kRowVerticalPad = 8;
const double _kHeaderVerticalPad = 10;
const double _kTrailingColWidth = 40;
const double _kDragColWidth = 24;

// Shared minimum content height for every line-item row. Keeps the drag
// handle, item / description / numeric / tax fields, and the line total on
// one centerline (the suffix-bearing cells would otherwise inflate to the
// 48 px `kMinInteractiveDimension`). A `minHeight` rather than a fixed
// height so a row can still grow to show an inline `errorText`.
const double _kRowContentHeight = 34;

// The Description cell grows with its text up to this many lines, then
// scrolls inside the cell. It must be multi-line for two reasons: a
// `maxLines: 1` field turns Return into "done", so there is no way to type a
// break; and Flutter gives every such field `singleLineFormatter`, which
// filters the WHOLE value on each edit — a multi-line product description
// lost every break at the first keystroke. It grows rather than collapsing
// on blur so row heights stay put while tabbing.
const int _kDescriptionMaxLines = 6;

/// Width of a custom-field column, by the field's type.
///
/// Fixed, where every built-in column but Item / Description is one flex
/// unit: a flex-1 column is ~40 px at the 700 px gate with three taxes and
/// two custom fields, ~4 characters of text, and a dropdown or a date cannot
/// fit at all. A fixed width keeps the value readable and lets the table say
/// it is wider than its pane by scrolling (see [_minTableWidth]) rather than
/// crushing every column. Sized to the content each type holds: a checkbox
/// (and room for a one-word header over it), a short value, an option and its
/// ▾, a formatted date (`05/Mar/2026` at its longest) beside its 28 px
/// calendar button, a few words.
double _customColumnWidth(ParsedCustomField field) => switch (field.type) {
  kFieldTypeSwitch => 80,
  kFieldTypeDropdown => 120,
  kFieldTypeDate => 136,
  kFieldTypeMultiLineText => 144,
  _ => 112,
};

/// The narrowest a flex unit may get before the table scrolls instead — about
/// what a company on three item taxes already gets on an iPad in landscape.
const double _kMinFlexUnitWidth = 48;

/// Dropdown-typed custom fields with more options than this get a
/// type-to-search cell instead of a menu (CLAUDE.md § Searchable pickers).
const int _kMaxMenuOptions = 20;

/// The width below which the table scrolls sideways, or 0 for "never".
///
/// Only a company with custom fields scrolls: their fixed-width columns are
/// what can starve the flex columns, and a table without them keeps the
/// layout it has always had at every width.
double _minTableWidth(BuildContext context, LineItemColumnConfig config) {
  if (config.customFields.isEmpty) return 0;
  // Item 3 + Description 3 + Unit Cost + Quantity + Line Total, then the
  // optional discount and tax columns — the flexes `_Row` lays out.
  final flexUnits = 9 + (config.showDiscount ? 1 : 0) + config.taxColumnCount;
  var width =
      InSpacing.lg(context) * 2 +
      _kDragColWidth +
      _kTrailingColWidth +
      flexUnits * _kMinFlexUnitWidth;
  for (final custom in config.customFields) {
    width += _customColumnWidth(custom.field);
  }
  return width;
}

/// Controller for [LineItemTableDesktop]. Hosted by the per-entity edit
/// layout so it can register [flushPending] as a `beforeSave` hook on
/// the VM — guarantees in-flight debounced cell edits land on the
/// draft before the save round-trips.
class LineItemTableDesktopController {
  void Function()? _flushHandler;

  // ignore: use_setters_to_change_properties
  void _attach(void Function() handler) {
    _flushHandler = handler;
  }

  void _detach(void Function() handler) {
    if (identical(_flushHandler, handler)) _flushHandler = null;
  }

  /// Flush every pending debounced cell edit synchronously. Safe to call
  /// when the table isn't mounted (becomes a no-op).
  void flushPending() => _flushHandler?.call();
}

/// Every build of a table row, counted in debug builds only.
/// `line_item_table_row_reuse_test` reads it to pin that an edit rebuilds the
/// row it changed and no other — see [_RowInputs].
@visibleForTesting
int debugLineItemRowBuilds = 0;

/// Inline-editable desktop line-item table. Each cell is its own editor
/// (product autocomplete, debounced text fields, tax dropdown). Drag
/// handles + per-row overflow menu cover reorder / clone / insert /
/// remove. A synthetic trailing blank row is rendered so the user can
/// start typing without first clicking Add — unless [allowNewRows] is
/// false, when it stays in `_rows` (rows pair with items by position) but
/// is never rendered or promoted.
class LineItemTableDesktop extends StatefulWidget {
  const LineItemTableDesktop({
    super.key,
    required this.companyId,
    required this.items,
    required this.onChanged,
    required this.newItemFactory,
    required this.config,
    this.currencyId,
    this.productConversionRate,
    this.controller,
    this.rowErrors,
    this.showStockQuantity = false,
    this.onCreateTaskFromLineItem,
    this.allowNewRows = true,
  });

  final String companyId;
  final List<LineItem> items;
  final ValueChanged<List<LineItem>> onChanged;
  final LineItem Function() newItemFactory;
  final LineItemColumnConfig config;

  /// Resolved display currency for line-item money (vendor currency for POs,
  /// client currency for client-billed docs). Null → company default. Threaded
  /// from [LineItemEditor] via `PartyCurrencyBuilder`.
  final String? currencyId;

  /// Company→client cross-currency rate applied to a filled product's unit
  /// price when `convert_products` is on and the client currency differs
  /// (null = no conversion). Computed by [LineItemEditor]; consumed via
  /// `lineItemFromProduct`.
  final Decimal? productConversionRate;
  final LineItemTableDesktopController? controller;

  /// Per-row server validation errors keyed by line-item index. Each
  /// inner map keys API field names (`cost`, `quantity`, `product_key`,
  /// `notes`) to localized error messages.
  final Map<int, Map<String, String>>? rowErrors;

  /// Invoice host only — show the bracketed in-stock count on product rows in
  /// the typeahead. ANDed with the company's `trackInventory` at the cell.
  final bool showStockQuantity;

  /// When set, each row's menu offers "Create Task" — schedule the work this
  /// line describes as a dated task (invoiceninja/flutter#88). Injected by the
  /// invoice / quote layouts so `billing_shared` stays free of task imports;
  /// null everywhere else, and the menu item simply doesn't render.
  final ValueChanged<LineItem>? onCreateTaskFromLineItem;

  /// False hides the trailing blank row and every row's "Insert Below" — see
  /// `LineItemEditor.allowNewRows`. The ghost row's `_RowState` still exists,
  /// because [_LineItemTableDesktopState._commitPending] pairs rows with items
  /// by position; it is just never rendered, committed or promoted.
  final bool allowNewRows;

  @override
  State<LineItemTableDesktop> createState() => _LineItemTableDesktopState();
}

class _LineItemTableDesktopState extends State<LineItemTableDesktop> {
  final List<_RowState> _rows = [];
  bool _suppressSync = false;

  /// The most recent list this table emitted, held until the parent's rebuild
  /// delivers it back as `widget.items`.
  ///
  /// `widget.onChanged` does not update the props within the frame, and a
  /// single gesture can emit more than once — a cell flush promotes the ghost
  /// row, and the very next statement adds a row on top of that. Reading
  /// `widget.items` in between sees the list as it was BEFORE the gesture
  /// started, which silently drops whatever the earlier emit produced: tab out
  /// of the ghost row inside the 250 ms debounce and the line you just typed
  /// was committed and then thrown away. Everything that reads "the current
  /// items" goes through [_items] instead.
  List<LineItem>? _emitted;

  /// The authoritative item list: what we last emitted while the parent has yet
  /// to catch up, else the props.
  List<LineItem> get _items => _emitted ?? widget.items;

  Formatter? _formatter;

  bool get _useComma => _formatter?.settings.useCommaAsDecimalPlace ?? false;

  @override
  void initState() {
    super.initState();
    _syncRows();
    final c = widget.controller;
    if (c != null) c._attach(_flushAll);
    // Prefer the sync cache so first-keystroke parsing already honors
    // the company's `useCommaAsDecimalPlace` setting. Fall back to the
    // async fetch if the cache hasn't been warmed yet (the post-frame
    // path also kicks the cache for next time).
    final services = context.read<Services>();
    _formatter = services.formatterIfReady(widget.companyId);
    if (_formatter == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        try {
          final fmt = await services.formatterFor(widget.companyId);
          if (!mounted) return;
          if (fmt != _formatter) setState(() => _formatter = fmt);
        } catch (_) {
          // Formatter read failed (statics not loaded yet) — keep default.
        }
      });
    }
  }

  /// A hot reload must rebuild every row with the new code, not hand back
  /// widgets — and closures — the old code built.
  @override
  void reassemble() {
    super.reassemble();
    for (final row in _rows) {
      row.built = null;
    }
  }

  @override
  void didUpdateWidget(LineItemTableDesktop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(_flushAll);
      widget.controller?._attach(_flushAll);
    }
    // Only re-point on an actual company switch — re-creating it on any other
    // rebuild is exactly the churn the cached stream exists to avoid.
    if (oldWidget.companyId != widget.companyId) {
      _companyStream = context.read<Services>().company.watchCompany(
        widget.companyId,
      );
    }
    if (_suppressSync) return;
    // The parent has delivered a list, so the in-frame override is spent —
    // clear it before the fast-path return, or a gesture that emitted and then
    // saw an identical-reference rebuild would keep reading a stale override.
    _emitted = null;
    // Fast-path: skip the full row-state reconciliation when the items
    // list reference is identical to the previous build (e.g. parent
    // rebuild from an unrelated keystroke). Saves N controller-touch
    // syncs on busy invoices.
    if (identical(widget.items, oldWidget.items)) return;
    _syncRows();
  }

  @override
  void dispose() {
    widget.controller?._detach(_flushAll);
    for (final row in _rows) {
      row.dispose();
    }
    _rows.clear();
    super.dispose();
  }

  /// Reconcile the local `_RowState` list to match `widget.items.length + 1`
  /// (the trailing slot is the synthetic ghost row). Called on every
  /// rebuild to keep controllers / focus nodes in sync with parent state.
  ///
  /// [override] is the list the caller has just emitted. `widget.onChanged`
  /// does NOT update `widget.items` within the frame (the parent rebuilds on
  /// the next one), so a post-emit sync that read the props would reconcile
  /// against the PREVIOUS list and reseed every row from stale data. Callers
  /// that mutate the list pass what they emitted; `build` / `didUpdateWidget`
  /// pass nothing and read the props, which are authoritative by then.
  void _syncRows([List<LineItem>? override]) {
    final items = override ?? widget.items;
    final desired = items.length + 1;
    while (_rows.length < desired) {
      _rows.add(_RowState());
    }
    while (_rows.length > desired) {
      _rows.removeLast().dispose();
    }
    for (var i = 0; i < items.length; i++) {
      _rows[i].syncFrom(items[i]);
    }
    // Trailing ghost row tracks a fresh empty item so its controllers
    // start blank.
    _rows.last.syncFrom(emptyLineItem());
  }

  /// Flush every row's debounced text onto the parent, and return the list
  /// that is now authoritative — which is NOT `widget.items`, since the parent
  /// rebuilds on the next frame. A caller that goes on to mutate the list must
  /// build from this return value or it silently discards the flush.
  List<LineItem> _flushAll() {
    // Iterate a SNAPSHOT: a row's flush commits through `onCellCommit`, which
    // can promote the ghost row and so append to `_rows` mid-loop.
    for (final row in List<_RowState>.of(_rows)) {
      row.flush();
    }
    return _commitPending();
  }

  /// Push every row's pending typed text onto the parent items list. The
  /// trailing ghost row is materialized only if it carries any
  /// user-meaningful content.
  /// Returns the list that is authoritative afterwards — the freshly committed
  /// one, or `widget.items` when nothing changed. See [_flushAll].
  List<LineItem> _commitPending() {
    final base = _items;
    // `_rows` always carries one entry per item plus the trailing ghost. If
    // that ever breaks, the bounded loop below silently DROPS the tail items
    // and re-emits `_rows.last` twice — a truncated billing document pushed
    // upward as authoritative. Fail loudly in debug; keep the bound as the
    // release-mode floor.
    assert(
      _rows.length == base.length + 1,
      '_rows (${_rows.length}) must be items (${base.length}) + 1 ghost',
    );
    final next = <LineItem>[];
    for (var i = 0; i < base.length && i < _rows.length; i++) {
      next.add(_rows[i].buildItem(base[i], useComma: _useComma));
    }
    // The host's factory, not `emptyLineItem()`: in the Tasks tab it makes an
    // hourly (`type_id` 2) row, and a ghost committed from here as `standard`
    // would leave the tab it was typed into. A table that takes no new rows
    // never commits its (unrendered) ghost, whatever it holds.
    if (widget.allowNewRows) {
      final ghost = _rows.last.buildItem(
        widget.newItemFactory(),
        useComma: _useComma,
      );
      if (!ghost.isBlank) next.add(ghost);
    }
    if (_listsEqual(next, base)) return base;
    _emitted = next;
    _suppressSync = true;
    widget.onChanged(next);
    _suppressSync = false;
    return next;
  }

  bool _listsEqual(List<LineItem> a, List<LineItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Apply a single-row mutation immediately (no debounce). Used by the
  /// product autocomplete (full-row replace), tax cell, overflow menu,
  /// drag reorder.
  void _applyRow(int index, LineItem next) {
    final base = _items;
    if (index < base.length) {
      final updated = List<LineItem>.from(base);
      updated[index] = next;
      _emit(updated);
    } else {
      // Promoting the ghost row — never in a table that takes no new rows.
      if (!widget.allowNewRows) return;
      final updated = List<LineItem>.from(base)..add(next);
      _emit(updated);
    }
  }

  void _emit(List<LineItem> next) {
    _emitted = next;
    _suppressSync = true;
    widget.onChanged(next);
    _suppressSync = false;
    // Force a sync so the just-promoted ghost row gets a fresh trailing
    // ghost without waiting for the parent to rebuild. Reconcile against
    // `next`, not the props — see [_syncRows].
    setState(() => _syncRows(next));
  }

  void _addBlankRow() {
    // From the FLUSHED list, not `widget.items`: the flush above commits the
    // ghost row the user just typed into, and `widget.onChanged` doesn't update
    // the props within the frame — so building from them discarded that row and
    // replaced it with a blank one (tab out of the last cell within the 250 ms
    // debounce and the line you just entered vanished).
    final next = List<LineItem>.from(_flushAll())..add(widget.newItemFactory());
    _emit(next);
    // Focus the new row's product cell after the frame settles.
    final newIndex = next.length - 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (newIndex < _rows.length) _rows[newIndex].focusProduct();
    });
  }

  void _remove(int index) {
    if (index >= _items.length) return;
    final next = List<LineItem>.from(_items)..removeAt(index);
    // Carry the positional `_RowState` with its line item — the same rule
    // `_move` documents below, and for a sharper reason here: `_syncRows`
    // refuses to reseed a FOCUSED field, so a caret parked in a row below the
    // mutation kept its old text while the data shifted under it, and
    // `_commitPending` (which pairs `_rows[i]` with `items[i]` positionally)
    // then wrote that text onto the wrong item — or, for a removal, promoted it
    // into the ghost slot and appended it as a duplicate line on Save.
    _rows.removeAt(index).dispose();
    _emit(next);
  }

  /// Hand this row to the host's "Create Task" flow.
  ///
  /// Reads the row's LIVE item, not `widget.items[index]`: text cells commit on
  /// a 250 ms debounce, so the props still hold pre-keystroke text — and the
  /// description the user just typed is the whole point of the seed. Flushing
  /// alone isn't enough either, because `widget.onChanged` doesn't update
  /// `widget.items` within the frame. (`_clone` below reads the stale props and
  /// has the same latent bug; don't copy it.)
  void _createTask(int index) {
    final handler = widget.onCreateTaskFromLineItem;
    if (handler == null || index >= _items.length) return;
    // Also pushes the pending edit onto the draft, so the document keeps it.
    final flushed = _flushAll();
    if (index >= flushed.length) return;
    handler(_rows[index].buildItem(flushed[index], useComma: _useComma));
  }

  void _clone(int index) {
    // Read the row's LIVE item like `_createTask` does, so a description the
    // user typed within the debounce window is cloned rather than the stale
    // props value. (This is the "same latent bug" `_createTask` warns about.)
    final next = List<LineItem>.from(_flushAll());
    if (index >= next.length) return;
    // A copy of a billed task / expense line is not that task or expense —
    // two lines claiming one task double-bills it. Drop the links and keep the
    // type, so an hourly copy stays hourly (admin-portal's
    // `InvoiceItemEntity.clone`). An expense line is `standard` + `expenseId`
    // (`expenseInvoiceLineItem`), so losing the link would turn its copy into
    // a product line and move it out of the Expenses tab it was cloned in;
    // type 6 keeps it there, and the server prints type 6 in the same product
    // table as its source. A task-linked row gets no such stamp: its type
    // decides the PDF table, and the copy must print where its source does.
    final source = next[index];
    next.insert(
      index + 1,
      source.copyWith(
        taskId: null,
        expenseId: null,
        typeId: (source.expenseId ?? '').isNotEmpty
            ? LineItemType.expense
            : source.typeId,
      ),
    );
    // See `_remove` for why the `_RowState` has to move too.
    _rows.insert(index + 1, _RowState());
    _emit(next);
  }

  void _insertBelow(int index) {
    final next = List<LineItem>.from(_flushAll());
    if (index >= next.length) return;
    next.insert(index + 1, widget.newItemFactory());
    // See `_remove` for why the `_RowState` has to move too.
    _rows.insert(index + 1, _RowState());
    _emit(next);
  }

  void _move(int from, int to) {
    final base = _items;
    if (from >= base.length) return;
    if (to < 0 || to >= base.length) return;
    if (from == to) return;
    final next = List<LineItem>.from(base);
    final row = next.removeAt(from);
    next.insert(to, row);
    // Keep the positional _RowState (key, controllers, autocomplete overlay)
    // bound to its line item across the reorder. Without this the ValueKey
    // and GlobalKey-bearing subtree stay fixed while the data shifts,
    // tripping ReorderableListView's _retakeInactiveElement assertion.
    final rowState = _rows.removeAt(from);
    _rows.insert(to, rowState);
    _emit(next);
  }

  void _onReorder(int oldIndex, int newIndex) {
    // Skip reorders dragging the synthetic trailing row itself.
    if (oldIndex >= _items.length) return;
    var adjusted = newIndex;
    // Drops past the last real row land on the last real position
    // rather than no-op'ing — the visible animation otherwise snaps
    // back, which feels broken.
    if (adjusted >= _items.length) {
      adjusted = _items.length - 1;
    }
    _move(oldIndex, adjusted);
  }

  /// Static, read-only snapshot of the row at [index], used as the drag
  /// proxy instead of the live editable subtree (which carries
  /// RawAutocomplete overlays/GlobalKeys that must not be duplicated). The
  /// column layout mirrors `_RowStateW.build` so the floating proxy lines
  /// up with the table underneath.
  Widget _dragSnapshot(BuildContext context, int index, InTheme tokens) {
    final item = (index >= 0 && index < _items.length) ? _items[index] : null;

    String dec(Decimal v) {
      if (v == Decimal.zero) return '';
      final raw = v.toString();
      return _useComma ? raw.replaceAll('.', ',') : raw;
    }

    String taxLabel(String name, Decimal rate) =>
        (item == null || name.isEmpty) ? '' : '$name ${dec(rate)}%';
    final tax = taxLabel(item?.taxName1 ?? '', item?.taxRate1 ?? Decimal.zero);
    final tax2 = taxLabel(item?.taxName2 ?? '', item?.taxRate2 ?? Decimal.zero);
    final tax3 = taxLabel(item?.taxName3 ?? '', item?.taxRate3 ?? Decimal.zero);

    final gross = item == null ? Decimal.zero : item.cost * item.quantity;
    final total = gross == Decimal.zero
        ? '—'
        : (_formatter?.money(
                gross,
                zeroIsNull: true,
                currencyId: widget.currencyId,
              ) ??
              gross.toString());

    Widget cell(
      String text, {
      int flex = 1,
      Alignment align = Alignment.centerLeft,
      int maxLines = 1,
    }) {
      return Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.only(right: _kCellPadH),
          child: Align(
            alignment: align,
            child: Text(
              text,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: tokens.ink, fontSize: 13),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: _kRowVerticalPad,
      ),
      color: tokens.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _kRowContentHeight),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.drag_indicator, color: tokens.ink3, size: 20),
            const SizedBox(width: _kDragColWidth - 20),
            cell(item?.productKey ?? '', flex: 3),
            // The proxy is forced to the dragged row's size, so a tall
            // description shows its lines rather than one centred line.
            cell(item?.notes ?? '', flex: 3, maxLines: _kDescriptionMaxLines),
            for (final custom in widget.config.customFields)
              SizedBox(
                width: _customColumnWidth(custom.field),
                child: Padding(
                  padding: const EdgeInsets.only(right: _kCellPadH),
                  child: Text(
                    item == null
                        ? ''
                        : displayCustomFieldValue(
                            type: custom.field.type,
                            value: lineItemCustomValue(item, custom.slot),
                            yes: context.tr('yes'),
                            no: context.tr('no'),
                            formatter: _formatter,
                          ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: tokens.ink, fontSize: 13),
                  ),
                ),
              ),
            cell(
              item == null ? '' : dec(item.cost),
              align: Alignment.centerRight,
            ),
            cell(
              item == null ? '' : dec(item.quantity),
              align: Alignment.centerRight,
            ),
            if (widget.config.showDiscount)
              cell(
                item == null ? '' : dec(item.discount),
                align: Alignment.centerRight,
              ),
            if (widget.config.taxColumnCount >= 1)
              cell(tax, align: Alignment.centerRight),
            if (widget.config.taxColumnCount >= 2)
              cell(tax2, align: Alignment.centerRight),
            if (widget.config.taxColumnCount >= 3)
              cell(tax3, align: Alignment.centerRight),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  total,
                  style: moneyTextStyle(color: tokens.ink, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: _kTrailingColWidth),
          ],
        ),
      ),
    );
  }

  /// Cached, not built in `build`: `watchCompany` returns a fresh stream per
  /// call, and this table rebuilds on every VM notification — so a per-build
  /// stream restarted the Drift query each time. Same fix as
  /// `InvoiceDesignPreviewPane`, which documents the trap.
  late Stream<Company?> _companyStream = context
      .read<Services>()
      .company
      .watchCompany(widget.companyId);

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final services = context.read<Services>();
    return StreamBuilder<Company?>(
      stream: _companyStream,
      builder: (context, snapshot) {
        final company = snapshot.data;
        // The ghost row stays in `_rows` either way — `_commitPending` pairs
        // rows with items by position — but a table that takes no new rows
        // doesn't render it.
        final itemCount = widget.allowNewRows ? _rows.length : _items.length;
        // Flat, title-less card matching the React / old-Flutter
        // references: hairline border, no header, no shadow.
        return Container(
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(InRadii.r3),
            border: Border.all(color: tokens.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _SidewaysScrollWhenNarrow(
                minWidth: _minTableWidth(context, widget.config),
                fadeColor: tokens.surface,
                child: Column(
                  children: [
                    _ColumnHeader(config: widget.config),
                    Divider(height: 1, color: tokens.border),
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: itemCount,
                      onReorderItem: _onReorder,
                      onReorderStart: (_) {
                        // Close any open product/tax dropdown before the drag
                        // so it doesn't float over the proxy. This is the
                        // normal supported focus-loss path (RawAutocomplete
                        // hides its overlay via its own lifecycle) — no
                        // re-entrant widget swap.
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      proxyDecorator: (child, index, animation) {
                        // Deliberately ignore `child` (the live, autocomplete-
                        // bearing row subtree). ReorderableListView would
                        // otherwise inflate it a second time into the drag
                        // overlay while it still exists in the list, duplicating
                        // RawAutocomplete's internal Overlay/GlobalKey and
                        // tripping `_retakeInactiveElement`. A self-contained
                        // static snapshot has no overlay/GlobalKey, so no
                        // duplication is possible. (The original row renders as
                        // a SizedBox while dragging — see Flutter
                        // reorderable_list.dart _ReorderableItem.build.)
                        return AnimatedBuilder(
                          animation: animation,
                          builder: (context, _) {
                            final t = Curves.easeInOut.transform(
                              animation.value,
                            );
                            return Material(
                              elevation: lerpDouble(0, 6, t)!,
                              color: tokens.surface,
                              shadowColor: Colors.black26,
                              borderRadius: BorderRadius.circular(InRadii.r2),
                              child: _dragSnapshot(context, index, tokens),
                            );
                          },
                        );
                      },
                      itemBuilder: (context, index) {
                        // `_items`, not the props: `_emit` reconciles `_rows`
                        // (which drives `itemCount`) against the list it just
                        // emitted, and the parent's rebuild lands a frame later.
                        // Reading the props here left the two disagreeing for
                        // that frame, so a just-promoted row rendered as the
                        // ghost — wrong `current`, suppressed row errors and an
                        // off-by-one `lastRealIndex`.
                        final items = _items;
                        final isGhost = index >= items.length;
                        final row = _rows[index];
                        final current = isGhost
                            ? widget.newItemFactory()
                            : items[index];
                        final errors = isGhost
                            ? null
                            : widget.rowErrors?[index];
                        // A row is rebuilt only when something it shows — or
                        // a value its callbacks below capture — has changed.
                        // Every VM notification rebuilds this table, and before
                        // this one keystroke's commit rebuilt all fifty rows of
                        // a fifty-line invoice to change one
                        // (docs/performance-tracking.md, the
                        // `screens.invoice_edit_typing` benchmark).
                        final inputs = _RowInputs(
                          index: index,
                          // The last RENDERED row: with no ghost row under it,
                          // the last item's own bottom border would double the
                          // divider below the list.
                          isLast: index == itemCount - 1,
                          isGhost: isGhost,
                          lastRealIndex: items.length - 1,
                          allowNewRows: widget.allowNewRows,
                          config: widget.config,
                          companyId: widget.companyId,
                          company: company,
                          showStockQuantity: widget.showStockQuantity,
                          useComma: _useComma,
                          formatter: _formatter,
                          currencyId: widget.currencyId,
                          currentItem: current,
                          errors: errors,
                          canCreateTask:
                              !isGhost &&
                              widget.onCreateTaskFromLineItem != null &&
                              (current.taskId ?? '').isEmpty,
                        );
                        final cached = row.built;
                        if (cached != null && cached.inputs == inputs) {
                          return cached.widget;
                        }
                        final built = _Row(
                          key: ValueKey(row.id),
                          index: index,
                          isLast: inputs.isLast,
                          isGhost: isGhost,
                          lastRealIndex: inputs.lastRealIndex,
                          allowNewRows: inputs.allowNewRows,
                          config: widget.config,
                          companyId: widget.companyId,
                          company: company,
                          showStockQuantity: widget.showStockQuantity,
                          useComma: _useComma,
                          formatter: _formatter,
                          currencyId: widget.currencyId,
                          row: row,
                          currentItem: current,
                          errors: errors,
                          services: services,
                          onCellCommit: (next) {
                            if (isGhost && next.isBlank) return;
                            _applyRow(index, next);
                          },
                          onProductSelected: (product) {
                            final base = isGhost
                                ? widget.newItemFactory()
                                : items[index];
                            final merged = (company?.fillProducts ?? false)
                                ? _mergeProductInto(
                                    base,
                                    product,
                                    company: company,
                                    conversionRate:
                                        widget.productConversionRate,
                                  )
                                : base.copyWith(productKey: product.productKey);
                            _applyRow(index, merged);
                            // Advance focus to the description cell so the
                            // user can immediately add notes after picking
                            // a product (otherwise focus stays in the
                            // autocomplete and the user has to Tab manually).
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) return;
                              if (index < _rows.length) {
                                _rows[index].notesFocus.requestFocus();
                              }
                            });
                          },
                          onCreateProduct: (query) async {
                            try {
                              final created = (await services.products.create(
                                companyId: widget.companyId,
                                draft: emptyProductWithKey(query),
                              )).entity;
                              if (!context.mounted) return;
                              final base = isGhost
                                  ? widget.newItemFactory()
                                  : items[index];
                              _applyRow(
                                index,
                                (company?.fillProducts ?? false)
                                    ? _mergeProductInto(
                                        base,
                                        created,
                                        company: company,
                                        conversionRate:
                                            widget.productConversionRate,
                                      )
                                    : base.copyWith(
                                        productKey: created.productKey,
                                      ),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              Notify.error(
                                context,
                                context.tr('could_not_save'),
                                error: e,
                              );
                            }
                          },
                          onMenuAction: (action) {
                            switch (action) {
                              case _RowAction.createTask:
                                _createTask(index);
                              case _RowAction.clone:
                                _clone(index);
                              case _RowAction.insertBelow:
                                _insertBelow(index);
                              case _RowAction.moveUp:
                                _move(index, index - 1);
                              case _RowAction.moveDown:
                                _move(index, index + 1);
                              case _RowAction.moveTop:
                                _move(index, 0);
                              case _RowAction.moveBottom:
                                _move(index, items.length - 1);
                              case _RowAction.remove:
                                _remove(index);
                            }
                          },
                          // A row that already IS a task can't be scheduled
                          // again. Deliberately NOT gated on `isBlank`: that
                          // reads the debounce-stale props and would hide the
                          // action from the row the user just typed into.
                          // `!isGhost` is belt-and-braces — the menu isn't
                          // rendered for the ghost row and its right-click is
                          // disabled — but `_createTask` would no-op on it, so
                          // keep the intent local rather than load-bearing at a
                          // distance.
                          canCreateTask: inputs.canCreateTask,
                          onTabFromLastCell: () {
                            if (isGhost) {
                              _addBlankRow();
                            } else if (index == items.length - 1 &&
                                items.last.isBlank == false) {
                              // Falling through into the ghost row — its
                              // first cell receives focus naturally. No-op.
                            }
                          },
                        );
                        row.built = _BuiltRow(inputs, built);
                        return built;
                      },
                    ),
                    Divider(height: 1, color: tokens.border),
                    // The redundant "+ Add item" button was removed — the
                    // synthetic trailing ghost row promotes itself on first
                    // keystroke, Tab from the last cell adds another row,
                    // and bulk adds go through the items-section FAB →
                    // line-item picker. `_addBlankRow` survives because
                    // it's still called by `onTabFromLastCell`. Where
                    // `allowNewRows` is false (the billing-doc Expenses tab)
                    // there is no ghost row, so the picker is the only way
                    // in.
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Merge a picked product into a row's line item. Delegates to the shared
/// [lineItemFromProduct] so the inline desktop path matches the picker and
/// React: unit price = the product's sale `price` (converted to the client's
/// currency when [conversionRate] is set), quantity per the company's
/// `enable_product_quantity` / `default_quantity` toggles.
LineItem _mergeProductInto(
  LineItem base,
  Product product, {
  required Company? company,
  required Decimal? conversionRate,
}) => lineItemFromProduct(
  product,
  base: base,
  enableProductQuantity: company?.enableProductQuantity ?? false,
  defaultQuantity: company?.defaultQuantity ?? false,
  conversionRate: conversionRate,
);

/// Lays [child] out at [minWidth] and scrolls it sideways when the pane is
/// narrower; otherwise hands it the pane's width untouched.
///
/// React's table does the same. The alternative — dropping to the phone card
/// list — would mean the cards/table gate (and the Items-tab button that
/// follows it, `lineItemEditorShowsWideTable`) learning about the company's
/// custom fields, and an iPad in landscape losing the table the moment one
/// custom field exists. The fades say there is more to the right, which is
/// where Line Total starts on a narrow pane.
class _SidewaysScrollWhenNarrow extends StatefulWidget {
  const _SidewaysScrollWhenNarrow({
    required this.minWidth,
    required this.fadeColor,
    required this.child,
  });

  final double minWidth;
  final Color fadeColor;
  final Widget child;

  @override
  State<_SidewaysScrollWhenNarrow> createState() =>
      _SidewaysScrollWhenNarrowState();
}

class _SidewaysScrollWhenNarrowState extends State<_SidewaysScrollWhenNarrow> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scrolls = constraints.maxWidth < widget.minWidth;
        // One shape whether or not it scrolls, so crossing the threshold — a
        // window resize, a custom field arriving with the company — never
        // re-parents [child] and tears down the rows' editors, focus and
        // pending debounced edits. Only the scroll extent changes.
        return Scrollbar(
          controller: _scroll,
          thumbVisibility: scrolls,
          // Draggable everywhere. On Android it isn't by default, and there a
          // swipe that starts on a text cell is claimed by the field's own
          // drag-to-select, which leaves the thumb as the way across.
          interactive: true,
          child: ScrollEdgeFades(
            color: widget.fadeColor,
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              physics: scrolls ? null : const NeverScrollableScrollPhysics(),
              child: SizedBox(
                width: scrolls ? widget.minWidth : constraints.maxWidth,
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({required this.config});
  final LineItemColumnConfig config;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: tokens.ink3,
      letterSpacing: 0.4,
    );
    // `labelKey` first: a task table reads Service / Rate / Hours, and a
    // company's Custom Label for THAT word is the one that applies.
    String label(String key) => context.tr(config.labelKey(key));
    Widget cell(
      String label, {
      int flex = 1,
      AlignmentGeometry align = Alignment.centerLeft,
    }) => Expanded(
      flex: flex,
      child: Align(
        alignment: align,
        // Left-aligned data cells inset their text by the field's
        // `contentPadding.horizontal` (`_kCellPadH`); match it so the
        // ITEM / DESCRIPTION headers sit directly over their columns.
        // Right-aligned columns are left as-is (the prominent LINE
        // TOTAL already flushes with its data; nudging it would
        // desync it from the other right-flushed labels).
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: align == Alignment.centerLeft ? _kCellPadH : 0,
          ),
          child: Text(label.toUpperCase(), style: style),
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: _kHeaderVerticalPad,
      ),
      child: Row(
        children: [
          const SizedBox(width: _kDragColWidth),
          // `context.tr` puts the company's Custom Labels first.
          cell(label('item'), flex: 3),
          cell(label('description'), flex: 3),
          // The company's own words, verbatim — not a translation key and not
          // a Custom Label. One line: a user label in a fixed column would
          // otherwise wrap over two or three, so the full text is a tooltip.
          for (final custom in config.customFields)
            SizedBox(
              key: ValueKey('custom_${custom.slot}'),
              width: _customColumnWidth(custom.field),
              child: Tooltip(
                message: custom.field.label,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: _kCellPadH,
                    end: _kCellPadH,
                  ),
                  child: Text(
                    custom.field.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: custom.field.type == kFieldTypeSwitch
                        ? TextAlign.center
                        : TextAlign.start,
                    style: style,
                  ),
                ),
              ),
            ),
          cell(label('unit_cost'), align: Alignment.centerRight),
          cell(label('quantity'), align: Alignment.centerRight),
          if (config.showDiscount)
            cell(label('discount'), align: Alignment.centerRight),
          // Slots 2 and 3 exist whenever the company enables 2 or 3 item tax
          // rates (Settings → Tax Settings). The mobile edit dialog has always
          // honoured all three; the desktop table rendered only the first, so a
          // multi-rate company could enter one tax on a phone and not on a
          // desktop — the same invoice totalling differently by viewport.
          for (var slot = 1; slot <= config.taxColumnCount; slot++)
            cell(
              config.taxColumnCount > 1
                  ? '${label('tax')} $slot'
                  : label('tax'),
              align: Alignment.centerRight,
            ),
          cell(label('line_total'), align: Alignment.centerRight),
          const SizedBox(width: _kTrailingColWidth),
        ],
      ),
    );
  }
}

/// The line item's tax name / rate for a 1-based slot. Keeps the three
/// flat `taxName1..3` / `taxRate1..3` fields addressable by index so the row
/// can render `config.taxColumnCount` cells in a loop.
String _taxNameOf(LineItem item, int slot) => switch (slot) {
  1 => item.taxName1,
  2 => item.taxName2,
  _ => item.taxName3,
};

Decimal _taxRateOf(LineItem item, int slot) => switch (slot) {
  1 => item.taxRate1,
  2 => item.taxRate2,
  _ => item.taxRate3,
};

/// What a [_Row] was built from, and the widget it was built as.
class _BuiltRow {
  _BuiltRow(this.inputs, this.widget);

  final _RowInputs inputs;
  final _Row widget;
}

/// Everything that can differ between two builds of one row: the row's own
/// props, and the values the table's callbacks capture when it builds the row
/// (`index`, `isGhost`, the item, the company). Equal inputs mean the earlier
/// widget is still right, closures included.
///
/// What is deliberately absent:
///
/// - **The closures themselves** — new each build, so comparing them would
///   never match. They read everything else through the State at call time
///   (`widget.*`, `_items`, `_rows`), which is always current.
/// - **`services`** — one instance for the app's life.
/// - **Theme, locale, media query** — a row depends on those through its
///   context, and an inherited change marks it dirty on its own, reused
///   widget or not.
/// - **The cells' own data** — the tax cell watches the tax rates itself, and
///   the text controllers live on [_RowState] and notify their fields.
///
/// A prop added to [_Row] — or a local a callback starts capturing — belongs
/// here too, or a row keeps showing the old value until something else about
/// it changes.
@immutable
class _RowInputs {
  const _RowInputs({
    required this.index,
    required this.isLast,
    required this.isGhost,
    required this.lastRealIndex,
    required this.allowNewRows,
    required this.config,
    required this.companyId,
    required this.company,
    required this.showStockQuantity,
    required this.useComma,
    required this.formatter,
    required this.currencyId,
    required this.currentItem,
    required this.errors,
    required this.canCreateTask,
  });

  final int index;
  final bool isLast;
  final bool isGhost;
  final int lastRealIndex;
  final bool allowNewRows;
  final LineItemColumnConfig config;
  final String companyId;
  final Company? company;
  final bool showStockQuantity;
  final bool useComma;
  final Formatter? formatter;
  final String? currencyId;
  final LineItem currentItem;
  final Map<String, String>? errors;
  final bool canCreateTask;

  @override
  bool operator ==(Object other) =>
      other is _RowInputs &&
      other.index == index &&
      other.isLast == isLast &&
      other.isGhost == isGhost &&
      other.lastRealIndex == lastRealIndex &&
      other.allowNewRows == allowNewRows &&
      other.config == config &&
      other.companyId == companyId &&
      // By identity: a new company row from Drift is a new object, and the
      // row reads several of its fields.
      identical(other.company, company) &&
      other.showStockQuantity == showStockQuantity &&
      other.useComma == useComma &&
      identical(other.formatter, formatter) &&
      other.currencyId == currencyId &&
      other.currentItem == currentItem &&
      mapEquals(other.errors, errors) &&
      other.canCreateTask == canCreateTask;

  @override
  int get hashCode => Object.hash(index, isGhost, currentItem);
}

/// Per-row mutable state. Survives parent rebuilds so cursor position
/// stays put while typing.
class _RowState {
  _RowState();

  /// The widget this row was last built as — handed back while its
  /// [_RowInputs] are unchanged (see the table's `itemBuilder`).
  _BuiltRow? built;

  final String id = UniqueKey().toString();
  final TextEditingController product = TextEditingController();
  final TextEditingController notes = TextEditingController();
  final TextEditingController cost = TextEditingController();
  final TextEditingController quantity = TextEditingController();
  final TextEditingController discount = TextEditingController();

  /// The text-typed custom-field cells, by slot - 1. All four exist whatever
  /// the company defines, so a field added mid-edit has one to bind to; an
  /// unbound one is never written back (see [buildItem]).
  final List<TextEditingController> custom = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> customFocus = List.generate(4, (_) => FocusNode());

  final FocusNode productFocus = FocusNode();
  final FocusNode notesFocus = FocusNode();
  final FocusNode costFocus = FocusNode();
  final FocusNode quantityFocus = FocusNode();
  final FocusNode discountFocus = FocusNode();

  Timer? _debounce;
  void Function()? _pendingFlush;

  // Track the values we last wrote *into* the controllers so external
  // syncs (e.g. autocomplete autofill) only rewrite when the parent value
  // genuinely changed — avoids stomping the user's cursor mid-type.
  String _seedProduct = '';
  String _seedNotes = '';
  String _seedCost = '';
  String _seedQty = '';
  String _seedDiscount = '';
  final List<String> _seedCustom = List.filled(4, '');

  /// Re-seed controllers when the parent's LineItem content changes
  /// (e.g. the user picked a product and we filled cost / notes).
  void syncFrom(LineItem item) {
    final product = item.productKey;
    if (product != _seedProduct && !productFocus.hasFocus) {
      this.product.text = product;
      _seedProduct = product;
    }
    final notes = item.notes;
    if (notes != _seedNotes && !notesFocus.hasFocus) {
      this.notes.text = notes;
      _seedNotes = notes;
    }
    final costText = _seedFor(item.cost);
    if (costText != _seedCost && !costFocus.hasFocus) {
      cost.text = costText;
      _seedCost = costText;
    }
    final qtyText = _seedFor(item.quantity);
    if (qtyText != _seedQty && !quantityFocus.hasFocus) {
      quantity.text = qtyText;
      _seedQty = qtyText;
    }
    final discText = _seedFor(item.discount);
    if (discText != _seedDiscount && !discountFocus.hasFocus) {
      discount.text = discText;
      _seedDiscount = discText;
    }
    for (var i = 0; i < 4; i++) {
      final value = lineItemCustomValue(item, i + 1);
      if (value == _seedCustom[i]) continue;
      if (!customFocus[i].hasFocus) {
        custom[i].text = value;
        _seedCustom[i] = value;
      } else if (custom[i].text == value) {
        // The focused cell's own commit landing. Advance the seed without
        // touching the text, or [buildItem] — which writes a custom value
        // only when its text differs from the seed — would read the user
        // clearing the cell back to the old seed as "no edit" and keep the
        // value they just deleted.
        _seedCustom[i] = value;
      }
    }
  }

  String _seedFor(Decimal d) => d == Decimal.zero ? '' : d.toString();

  /// Build a LineItem reflecting the current controller text. Used to
  /// commit the row on save / focus-out / explicit flush. The
  /// [useComma] flag honours the company's `use_comma_as_decimal_place`
  /// setting so EU users typing `1,50` produce 1.5 rather than 0.
  ///
  /// A custom value is written back only once its text differs from what was
  /// last seeded into it — i.e. the user typed in it. A switch / date /
  /// dropdown slot has no text cell, so its controller never diverges and the
  /// value it commits on its own can't be overwritten here by stale text; and
  /// no caller has to say which slots are text-typed. Untrimmed, unlike the
  /// product key: a stored value with a trailing space would otherwise never
  /// equal the item it came from, and every flush would re-dirty the document.
  LineItem buildItem(LineItem base, {bool useComma = false}) {
    var built = base.copyWith(
      productKey: product.text.trim(),
      notes: notes.text,
      cost:
          parseDecimal(cost.text, useCommaAsDecimalPlace: useComma) ??
          Decimal.zero,
      // An hourly row's Hours cell also takes a duration (`1:30`, `90m`); a
      // colon it can't read keeps the hours the row already had.
      quantity: base.typeId == LineItemType.task
          ? parseHoursInput(quantity.text, useCommaAsDecimalPlace: useComma) ??
                base.quantity
          : parseDecimal(quantity.text, useCommaAsDecimalPlace: useComma) ??
                Decimal.one,
      discount:
          parseDecimal(discount.text, useCommaAsDecimalPlace: useComma) ??
          Decimal.zero,
    );
    for (var i = 0; i < 4; i++) {
      final text = custom[i].text;
      if (text != _seedCustom[i]) {
        built = withLineItemCustomValue(built, i + 1, text);
      }
    }
    return built;
  }

  void scheduleCommit(VoidCallback commit) {
    _pendingFlush = commit;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _pendingFlush?.call();
      _pendingFlush = null;
    });
  }

  void flush() {
    _debounce?.cancel();
    final pending = _pendingFlush;
    _pendingFlush = null;
    pending?.call();
  }

  void focusProduct() {
    productFocus.requestFocus();
    product.selection = TextSelection(
      baseOffset: 0,
      extentOffset: product.text.length,
    );
  }

  void dispose() {
    _debounce?.cancel();
    product.dispose();
    notes.dispose();
    cost.dispose();
    quantity.dispose();
    discount.dispose();
    for (final c in custom) {
      c.dispose();
    }
    for (final f in customFocus) {
      f.dispose();
    }
    productFocus.dispose();
    notesFocus.dispose();
    costFocus.dispose();
    quantityFocus.dispose();
    discountFocus.dispose();
  }
}

enum _RowAction {
  createTask,
  clone,
  insertBelow,
  moveUp,
  moveDown,
  moveTop,
  moveBottom,
  remove,
}

class _Row extends StatefulWidget {
  const _Row({
    super.key,
    required this.index,
    required this.isLast,
    required this.isGhost,
    required this.lastRealIndex,
    required this.allowNewRows,
    required this.config,
    required this.companyId,
    required this.company,
    required this.showStockQuantity,
    required this.useComma,
    required this.formatter,
    required this.currencyId,
    required this.row,
    required this.currentItem,
    required this.errors,
    required this.services,
    required this.onCellCommit,
    required this.onProductSelected,
    required this.onCreateProduct,
    required this.onMenuAction,
    required this.onTabFromLastCell,
    required this.canCreateTask,
  });

  final int index;
  final bool isLast;
  final bool isGhost;
  final int lastRealIndex;

  /// False drops "Insert Below" from both row menus — see
  /// [LineItemTableDesktop.allowNewRows].
  final bool allowNewRows;
  final LineItemColumnConfig config;
  final String companyId;
  final Company? company;
  final bool showStockQuantity;
  final bool useComma;
  final Formatter? formatter;
  final String? currencyId;
  final _RowState row;
  final LineItem currentItem;
  final Map<String, String>? errors;
  final Services services;
  final ValueChanged<LineItem> onCellCommit;
  final ValueChanged<Product> onProductSelected;
  final Future<void> Function(String) onCreateProduct;
  final ValueChanged<_RowAction> onMenuAction;
  final VoidCallback onTabFromLastCell;

  /// Whether this row can be scheduled as a task. False when the host wired no
  /// handler, and false for a row that already *is* a task.
  final bool canCreateTask;

  @override
  State<_Row> createState() => _RowStateW();
}

class _RowStateW extends State<_Row> {
  bool _hovered = false;

  // Re-expose widget fields as terse locals so the build body reads
  // without `widget.` prefix everywhere.
  int get index => widget.index;
  bool get isLast => widget.isLast;
  bool get isGhost => widget.isGhost;
  int get lastRealIndex => widget.lastRealIndex;
  bool get allowNewRows => widget.allowNewRows;
  LineItemColumnConfig get config => widget.config;
  String get companyId => widget.companyId;
  bool get useComma => widget.useComma;
  Formatter? get formatter => widget.formatter;
  String? get currencyId => widget.currencyId;
  _RowState get row => widget.row;
  LineItem get currentItem => widget.currentItem;
  Map<String, String>? get errors => widget.errors;
  Services get services => widget.services;
  ValueChanged<LineItem> get onCellCommit => widget.onCellCommit;
  ValueChanged<Product> get onProductSelected => widget.onProductSelected;
  Future<void> Function(String) get onCreateProduct => widget.onCreateProduct;
  ValueChanged<_RowAction> get onMenuAction => widget.onMenuAction;
  VoidCallback get onTabFromLastCell => widget.onTabFromLastCell;
  bool get canCreateTask => widget.canCreateTask;

  @override
  Widget build(BuildContext context) {
    assert(() {
      debugLineItemRowBuilds++;
      return true;
    }());
    final tokens = context.inTheme;

    void commitNow() {
      onCellCommit(row.buildItem(currentItem, useComma: useComma));
    }

    void scheduleCommit() {
      row.scheduleCommit(commitNow);
    }

    // A custom value set by a switch, date or dropdown cell commits at once,
    // on the row rebuilt from its live cells — the tax cell's pattern — so
    // text still inside the 250 ms debounce rides along rather than reverting.
    void commitCustom(int slot, String value) {
      onCellCommit(
        withLineItemCustomValue(
          row.buildItem(currentItem, useComma: useComma),
          slot,
          value,
        ),
      );
    }

    // One fixed-width column per configured custom field, keyed by slot so a
    // column arriving with the company row (a frame after the table) is
    // inserted rather than re-pairing its neighbours' state by position.
    //
    // On the trailing ghost row only the text cells are live, like its
    // other text cells: a tick on a switch there would promote a line holding
    // nothing but `no`, which `isBlank` counts as content, so it would survive
    // the save-time strip and print as an empty row.
    Widget customCell(LineItemCustomField custom) {
      final slot = custom.slot;
      final field = custom.field;
      final value = lineItemCustomValue(currentItem, slot);
      final Widget cell;
      switch (field.type) {
        case kFieldTypeSwitch:
          cell = _SwitchCell(
            label: field.label,
            value: isSwitchTruthy(value),
            onChanged: isGhost
                ? null
                : (on) {
                    if (on) return commitCustom(slot, kSwitchValueYes);
                    // Off is `no`, as React and admin-portal store it — except
                    // on a row with nothing else in it, where it clears the
                    // slot: `isBlank` counts any custom value as content, so a
                    // tick and untick on an inserted blank row would otherwise
                    // keep a line the save-time strip can't drop.
                    final rest = withLineItemCustomValue(
                      row.buildItem(currentItem, useComma: useComma),
                      slot,
                      '',
                    );
                    commitCustom(slot, rest.isBlank ? '' : kSwitchValueNo);
                  },
          );
        case kFieldTypeDate:
          cell = InDateField(
            dense: true,
            clearable: true,
            enabled: !isGhost,
            semanticLabel: field.label,
            formatter: formatter,
            value: customFieldDate(value),
            onChanged: (d) =>
                commitCustom(slot, d == null ? '' : customFieldIsoDate(d)),
          );
        case kFieldTypeDropdown:
          final options = customFieldDropdownItems(field, value);
          final onChanged = isGhost
              ? null
              : (String v) => commitCustom(slot, v);
          cell = field.options.length > _kMaxMenuOptions
              ? _ChoiceSearchCell(
                  label: field.label,
                  options: options,
                  value: value,
                  onChanged: onChanged,
                )
              : _ChoiceMenuCell(
                  label: field.label,
                  options: options,
                  value: value,
                  onChanged: onChanged,
                );
        default:
          // The cell's column is its header, so the hint carries the label
          // for an empty cell and the semantics carry it for a filled one.
          cell = MergeSemantics(
            child: Semantics(
              label: field.label,
              child: _TextCell(
                controller: row.custom[slot - 1],
                focusNode: row.customFocus[slot - 1],
                onChanged: scheduleCommit,
                hintText: field.label,
                maxLines: field.type == kFieldTypeMultiLineText ? 3 : 1,
              ),
            ),
          );
      }
      return SizedBox(
        key: ValueKey('custom_$slot'),
        width: _customColumnWidth(field),
        child: Padding(
          padding: const EdgeInsets.only(right: _kCellPadH),
          child: cell,
        ),
      );
    }

    Widget endTotalCell() {
      final cost =
          parseDecimal(row.cost.text, useCommaAsDecimalPlace: useComma) ??
          Decimal.zero;
      final qty = currentItem.typeId == LineItemType.task
          ? parseHoursInput(
                  row.quantity.text,
                  useCommaAsDecimalPlace: useComma,
                ) ??
                currentItem.quantity
          : parseDecimal(row.quantity.text, useCommaAsDecimalPlace: useComma) ??
                Decimal.one;
      final gross = cost * qty;
      // Display via the company Formatter when available so the line
      // total honors currency, thousands separator, and decimal place
      // count (per CLAUDE.md). Falls back to a raw `Decimal.toString`
      // before the formatter resolves.
      final display = gross == Decimal.zero
          ? '—'
          : (formatter?.money(
                  gross,
                  zeroIsNull: true,
                  currencyId: currencyId,
                ) ??
                gross.toString());
      return Expanded(
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(
            display,
            style: moneyTextStyle(color: tokens.ink, fontSize: 13),
          ),
        ),
      );
    }

    final body = FocusTraversalGroup(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: InSpacing.lg(context),
          vertical: _kRowVerticalPad,
        ),
        decoration: BoxDecoration(
          color: _hovered ? tokens.surfaceAlt : null,
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: tokens.border)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _kRowContentHeight),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              isGhost
                  ? const SizedBox(width: _kDragColWidth)
                  : MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: ReorderableDragStartListener(
                        index: index,
                        child: Semantics(
                          label: context.tr('reorder'),
                          child: Tooltip(
                            message: context.tr('reorder'),
                            child: Icon(
                              Icons.drag_indicator,
                              color: tokens.ink3,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(right: _kCellPadH),
                  child: _ProductCell(
                    companyId: companyId,
                    formatter: formatter,
                    showProductDetails:
                        widget.company?.showProductDetails ?? false,
                    showStock:
                        widget.showStockQuantity &&
                        (widget.company?.trackInventory ?? false),
                    controller: row.product,
                    focusNode: row.productFocus,
                    hintKey: isGhost
                        ? 'add_an_item'
                        : config.labelKey('product'),
                    onSelected: onProductSelected,
                    onCreateRequested: onCreateProduct,
                    onCommitText: scheduleCommit,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(right: _kCellPadH),
                  child: _TextCell(
                    controller: row.notes,
                    focusNode: row.notesFocus,
                    onChanged: scheduleCommit,
                    hintKey: 'description',
                    errorText: errors?['notes'],
                    maxLines: _kDescriptionMaxLines,
                    spellCheck: true,
                  ),
                ),
              ),
              for (final custom in config.customFields) customCell(custom),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: _kCellPadH),
                  child: _NumericCell(
                    controller: row.cost,
                    focusNode: row.costFocus,
                    onChanged: scheduleCommit,
                    errorText: errors?['cost'],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: _kCellPadH),
                  child: _NumericCell(
                    controller: row.quantity,
                    focusNode: row.quantityFocus,
                    onChanged: scheduleCommit,
                    errorText: errors?['quantity'],
                    // Quantity is the last typing cell when discount is
                    // hidden — tab forward then promotes the ghost.
                    onTabForward: !config.showDiscount && isGhost
                        ? onTabFromLastCell
                        : null,
                  ),
                ),
              ),
              if (config.showDiscount)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: _kCellPadH),
                    child: _NumericCell(
                      controller: row.discount,
                      focusNode: row.discountFocus,
                      onChanged: scheduleCommit,
                      errorText: errors?['discount'],
                      // Discount is the last typing cell when shown.
                      onTabForward: isGhost ? onTabFromLastCell : null,
                    ),
                  ),
                ),
              // One cell per enabled slot. Only slot 1 used to be rendered,
              // so a company on 2 or 3 item tax rates could not enter the
              // others at all on desktop while the mobile dialog offered them
              // — the same invoice totalling differently by viewport.
              //
              // Keyed on the `Expanded`, not the cell inside it: the `Row`
              // matches its own children, so a key one level down could not
              // keep a tax cell's state when a column is inserted before it.
              for (var slot = 1; slot <= config.taxColumnCount; slot++)
                Expanded(
                  key: ValueKey('tax_$slot'),
                  child: Padding(
                    padding: const EdgeInsets.only(right: _kCellPadH),
                    child: _TaxCell(
                      companyId: companyId,
                      services: services,
                      formatter: formatter,
                      initialName: _taxNameOf(currentItem, slot),
                      initialRate: _taxRateOf(currentItem, slot),
                      onSelected: (taxRate) {
                        final name = taxRate?.name ?? '';
                        final rate = taxRate == null
                            ? Decimal.zero
                            : Decimal.parse(taxRate.rate.toString());
                        final base = row.buildItem(
                          currentItem,
                          useComma: useComma,
                        );
                        onCellCommit(switch (slot) {
                          1 => base.copyWith(taxName1: name, taxRate1: rate),
                          2 => base.copyWith(taxName2: name, taxRate2: rate),
                          _ => base.copyWith(taxName3: name, taxRate3: rate),
                        });
                      },
                    ),
                  ),
                ),
              endTotalCell(),
              SizedBox(
                width: _kTrailingColWidth,
                child: isGhost
                    ? const SizedBox.shrink()
                    : AnimatedOpacity(
                        duration: const Duration(milliseconds: 120),
                        opacity: _hovered ? 1.0 : 0.0,
                        child: ExcludeFocus(
                          child: _RowMenu(
                            onSelected: onMenuAction,
                            canMoveUp: index > 0,
                            canMoveDown: index < lastRealIndex,
                            canCreateTask: canCreateTask,
                            allowNewRows: allowNewRows,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    final wrapped = isGhost ? Opacity(opacity: 0.55, child: body) : body;
    return MouseRegion(
      onEnter: (_) {
        if (!_hovered) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (_hovered) setState(() => _hovered = false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapDown: isGhost
            ? null
            : (details) => _showContextMenu(context, details.globalPosition),
        child: wrapped,
      ),
    );
  }

  /// Right-click context menu with the same actions as the per-row
  /// overflow menu. Anchored at the cursor position.
  Future<void> _showContextMenu(BuildContext ctx, Offset position) async {
    final overlay = Overlay.of(ctx).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final action = await showMenu<_RowAction>(
      context: ctx,
      position: RelativeRect.fromRect(
        Rect.fromPoints(position, position),
        Offset.zero & overlay.size,
      ),
      items: [
        if (canCreateTask) ...[
          PopupMenuItem(
            value: _RowAction.createTask,
            child: Text(ctx.tr('create_task')),
          ),
          const PopupMenuDivider(),
        ],
        PopupMenuItem(value: _RowAction.clone, child: Text(ctx.tr('clone'))),
        if (allowNewRows)
          PopupMenuItem(
            value: _RowAction.insertBelow,
            child: Text(ctx.tr('insert_below')),
          ),
        if (index > 0 || index < lastRealIndex) const PopupMenuDivider(),
        if (index > 0)
          PopupMenuItem(
            value: _RowAction.moveUp,
            child: Text(ctx.tr('move_up')),
          ),
        if (index < lastRealIndex)
          PopupMenuItem(
            value: _RowAction.moveDown,
            child: Text(ctx.tr('move_down')),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(value: _RowAction.remove, child: Text(ctx.tr('remove'))),
      ],
    );
    if (action != null) onMenuAction(action);
  }
}

/// Per-row overflow menu. Hides move actions that would be no-ops at
/// the row's current position so users don't see disabled-feeling
/// items.
class _RowMenu extends StatelessWidget {
  const _RowMenu({
    required this.onSelected,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.canCreateTask,
    required this.allowNewRows,
  });

  final ValueChanged<_RowAction> onSelected;
  final bool canMoveUp;
  final bool canMoveDown;
  final bool canCreateTask;

  /// False drops "Insert Below" — see [LineItemTableDesktop.allowNewRows].
  final bool allowNewRows;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return PopupMenuButton<_RowAction>(
      tooltip: context.tr('more'),
      icon: Icon(Icons.more_vert, size: 18, color: tokens.ink3),
      onSelected: onSelected,
      itemBuilder: (context) => [
        if (canCreateTask) ...[
          PopupMenuItem(
            value: _RowAction.createTask,
            child: Text(context.tr('create_task')),
          ),
          const PopupMenuDivider(),
        ],
        PopupMenuItem(
          value: _RowAction.clone,
          child: Text(context.tr('clone')),
        ),
        if (allowNewRows)
          PopupMenuItem(
            value: _RowAction.insertBelow,
            child: Text(context.tr('insert_below')),
          ),
        if (canMoveUp || canMoveDown) const PopupMenuDivider(),
        if (canMoveUp)
          PopupMenuItem(
            value: _RowAction.moveUp,
            child: Text(context.tr('move_up')),
          ),
        if (canMoveDown)
          PopupMenuItem(
            value: _RowAction.moveDown,
            child: Text(context.tr('move_down')),
          ),
        if (canMoveUp)
          PopupMenuItem(
            value: _RowAction.moveTop,
            child: Text(context.tr('move_top')),
          ),
        if (canMoveDown)
          PopupMenuItem(
            value: _RowAction.moveBottom,
            child: Text(context.tr('move_bottom')),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _RowAction.remove,
          child: Text(context.tr('remove')),
        ),
      ],
    );
  }
}

/// Inline cell: small bordered text field with no label, dense padding.
class _TextCell extends StatelessWidget {
  const _TextCell({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.hintKey,
    this.hintText,
    this.errorText,
    this.maxLines = 1,
    this.spellCheck = false,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onChanged;

  /// A translation key for the hint.
  final String? hintKey;

  /// A hint shown as given — a company's custom-field label, which is the
  /// user's own text and must not be looked up as a translation key.
  final String? hintText;
  final String? errorText;

  /// Above 1 the cell grows with its text up to this many lines (the
  /// description, or a multi-line custom field); the row is floored with
  /// `minHeight`, so it grows with it.
  final int maxLines;

  /// Underline spelling mistakes (docs/spell-check.md) — the description
  /// only; a custom field may hold anything.
  final bool spellCheck;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return LineItemSpellCheck(
      enabled: spellCheck,
      builder: (context, config) => TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: (_) => onChanged(),
        spellCheckConfiguration: config,
        contextMenuBuilder: spellCheckContextMenuBuilder,
        minLines: 1,
        maxLines: maxLines,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hintText ?? (hintKey == null ? null : context.tr(hintKey!)),
          errorText: errorText,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: _kCellPadH,
            vertical: _kCellPadH,
          ),
          // Resting cells have no border so the row dividers carry the
          // visual rhythm; a 2 px accent underline appears only on focus.
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: tokens.accent, width: 2),
          ),
        ),
      ),
    );
  }
}

class _NumericCell extends StatelessWidget {
  const _NumericCell({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.onTabForward,
    this.errorText,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onChanged;
  final VoidCallback? onTabForward;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: (_) => onChanged(),
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      textAlign: TextAlign.right,
      textAlignVertical: TextAlignVertical.center,
      style: moneyTextStyle(color: tokens.ink, fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        errorText: errorText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: _kCellPadH,
          vertical: _kCellPadH,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: tokens.accent, width: 2),
        ),
      ),
    );
    if (onTabForward == null) return field;
    return Focus(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey != LogicalKeyboardKey.tab) {
          return KeyEventResult.ignored;
        }
        if (HardwareKeyboard.instance.isShiftPressed) {
          return KeyEventResult.ignored;
        }
        // Last cell tab-forward — tell the host to add a new row.
        // Return `handled` so Flutter's default focus-traversal doesn't
        // also advance, which would race with the post-frame focus
        // request and produce a single-frame flicker.
        onTabForward?.call();
        return KeyEventResult.handled;
      },
      child: field,
    );
  }
}

/// Inline product picker. Server-side searched via
/// `services.products.watchPage(search:)`, debounced 200 ms. Includes a
/// "Create '`<query>`'" tile when the typed key matches no product.
class _ProductCell extends StatefulWidget {
  const _ProductCell({
    required this.companyId,
    required this.formatter,
    required this.showProductDetails,
    required this.showStock,
    required this.controller,
    required this.focusNode,
    required this.hintKey,
    required this.onSelected,
    required this.onCreateRequested,
    required this.onCommitText,
  });

  final String companyId;

  /// Renders the description's reserved date keywords through the company's
  /// date format; null until the statics bundle resolves.
  final Formatter? formatter;

  /// Company `show_product_details` — when false, the product description is
  /// hidden from the autocomplete option rows (only the product key shows).
  final bool showProductDetails;

  /// Resolved `company.trackInventory && docTypeIsInvoice` — show the
  /// bracketed in-stock count on each option row.
  final bool showStock;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintKey;
  final ValueChanged<Product> onSelected;

  /// Creates a product from the typed key and merges it into the row.
  /// Returns a future so the cell can hold its re-entrancy guard for the
  /// whole round trip — a void callback left `_creating` latched forever.
  final Future<void> Function(String) onCreateRequested;
  final VoidCallback onCommitText;

  @override
  State<_ProductCell> createState() => _ProductCellState();
}

class _ProductCellState extends State<_ProductCell> {
  // Fixed row height in the options popover — lets keyboard navigation scroll
  // the highlighted row into view with simple arithmetic (mirrors
  // `SearchableDropdownField._optionExtent`). Tall enough for the two-line
  // product row (key + first notes line).
  static const double _optionExtent = 48.0;

  // Bumped on every keystroke; an in-flight async `optionsBuilder` aborts as
  // soon as it sees a newer value (debounce + supersede guard).
  int _searchSeq = 0;
  // Length of the list the last `optionsBuilder` returned — gates Tab-to-select.
  int _lastOptionsCount = 0;

  /// The live highlight from the options overlay. Captured as the *notifier*
  /// rather than its value: `AutocompleteHighlightedOption` is an
  /// `InheritedNotifier`, so an index read during build lags a frame behind the
  /// arrow keys and a Tab/Enter in the same event batch acts on the wrong row.
  ValueNotifier<int>? _highlight;

  /// The options the popover last rendered — what is actually on screen, not
  /// whatever `optionsBuilder` returned (the SDK may discard a stale result).
  List<_ProductOption> _visibleOptions = const [];

  /// True while the options overlay is mounted.
  ///
  /// Load-bearing, and the reason is not obvious. Routing create away from
  /// `RawAutocomplete._select` also skips the guard *above* it:
  /// `_onFieldSubmitted` only selects `if (_optionsViewController.isShowing)`.
  /// Flutter's `DismissIntent` hides the overlay **without touching focus or
  /// text**, so nothing else here observes an Escape — and `_visibleOptions`,
  /// `_highlight` and `_lastOptionsCount` all survive it. Without this flag,
  /// Escape-then-Enter created a product the user had just dismissed.
  ///
  /// `_lastOptionsCount` is NOT a substitute: it comes from `optionsBuilder`'s
  /// return value, which the SDK may discard, and it is never reset on blur or
  /// dismissal — it answers "did a builder recently return rows", not "is the
  /// popover open".
  bool _optionsVisible = false;

  /// Guards the create round-trip against a second trigger.
  ///
  /// `_select` used to supply this for free — it latched the selection and
  /// called `hide()`, so a second Enter or click was a no-op. Routing around it
  /// removed both, and `onCreateProduct` awaits a network create, so a
  /// double-click or Enter key-repeat would otherwise POST twice and make two
  /// products. Mirrors `ClientPickerField._handleCreate`.
  bool _creating = false;

  /// Whether the keyboard cursor is sitting on the synthetic "Create «x»" row.
  ///
  /// Both key paths have to test this and route around
  /// `RawAutocomplete._select`, which early-returns on an unchanged selection
  /// *before* hiding the overlay — and `_ProductCreate` has no `operator ==`,
  /// so after a cancelled create the same instance is still the latched
  /// selection and the row is dead until the user edits the text.
  bool get _highlightIsCreateRow {
    if (!_optionsVisible || _creating || !_canCreateProducts) return false;
    final i = _highlight?.value ?? 0;
    if (i < 0 || i >= _visibleOptions.length) return false;
    return _visibleOptions[i] is _ProductCreate;
  }

  bool _searching = false;
  bool _searchFailed = false;
  // Debounces the background catalog refresh fired from the local-first
  // (instant) path — without it a fast typist would hit the network once per
  // keystroke (the old 200 ms sleep that used to coalesce them is gone there).
  Timer? _bgRefreshTimer;
  final ScrollController _optionsScrollController = ScrollController();

  /// Whether this user may create products at all. Read here rather than
  /// assumed: the inline create shipped with no permission check, so a
  /// view-only user was offered a row whose only possible outcome was a 403.
  bool _canCreateProducts = false;

  @override
  void initState() {
    super.initState();
    // Warm the local cache so the dropdown resolves instantly from local rows.
    // The dropdown opens on focus/tap (RawAutocomplete reruns `optionsBuilder`
    // on the cursor-selection change, and on a fresh cell `_lastFieldText` is
    // null so the empty-query build runs) as well as on the first keystroke —
    // this warm makes both paths return without a network round-trip.
    // Best-effort: failures fall back to whatever is cached.
    unawaited(
      context
          .read<Services>()
          .products
          .ensurePageLoaded(companyId: widget.companyId, page: 1)
          .catchError((_) => false),
    );
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _readPermission();
  }

  /// Blur closes the overlay, and nothing else tells us — the SDK hides it
  /// without calling back.
  void _onFocusChange() {
    if (!widget.focusNode.hasFocus) _optionsVisible = false;
  }

  @override
  void didUpdateWidget(_ProductCell old) {
    super.didUpdateWidget(old);
    // Permissions are per company-user, so a company switch has to re-evaluate
    // — mirrors `ClientPickerField._readPermission`.
    if (old.companyId != widget.companyId) _readPermission();
  }

  /// Admin/owner bypass and `create_all` expansion are handled inside `can`.
  void _readPermission() {
    _canCreateProducts =
        context.read<Services>().auth.session.value?.currentCompany?.can(
          'create_product',
        ) ??
        false;
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    _bgRefreshTimer?.cancel();
    _optionsScrollController.dispose();
    super.dispose();
  }

  /// One-shot snapshot of the local rows for [query], assembled into options.
  /// Shared by the instant (local-first) path and the post-fetch re-read.
  Future<List<_ProductOption>> _localProducts(
    Services services,
    String query,
  ) async {
    final rows = await services.products
        .watchPage(
          companyId: widget.companyId,
          search: query.isEmpty ? null : query,
          loadedPages: 1,
        )
        .first;
    final options = <_ProductOption>[
      for (final p in rows.take(20)) _ProductExisting(p),
    ];
    // Appended for EVERY user, not just those who may create — then rendered
    // as a muted "no records found" row, and inert, when they may not.
    //
    // `RawAutocomplete._canShowOptionsView` is `hasFocus && options.isNotEmpty`,
    // so an empty list means no overlay at all — and the search spinner and the
    // `couldnt_load_products` error both live *inside* `optionsViewBuilder`.
    // Gating the row out of the LIST (rather than out of the interaction) left
    // a user without `create_product` typing a name, losing the network, and
    // getting nothing whatsoever: no spinner, no error, no "no results".
    if (query.isNotEmpty &&
        !rows.any((p) => p.productKey.toLowerCase() == query.toLowerCase())) {
      options.add(_ProductCreate(query));
    }
    return options;
  }

  /// Best-effort server refresh fired from the instant path so a large
  /// catalog's extra matches land in Drift for the next keystroke. Debounced
  /// and never awaited — it must not gate the dropdown.
  void _scheduleBackgroundRefresh(Services services, String query) {
    _bgRefreshTimer?.cancel();
    _bgRefreshTimer = Timer(const Duration(milliseconds: 280), () {
      unawaited(
        services.products
            .ensurePageLoaded(
              companyId: widget.companyId,
              page: 1,
              search: query.isEmpty ? null : query,
            )
            .catchError((_) => false),
      );
    });
  }

  /// Keep the keyboard-highlighted option visible as the user arrows past the
  /// popover's visible window. Same arithmetic as
  /// `SearchableDropdownField._scrollHighlightedIntoView`, keyed off the fixed
  /// [_optionExtent].
  void _scrollHighlightedIntoView(int highlightedIndex, int optionCount) {
    if (highlightedIndex < 0 || highlightedIndex >= optionCount) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_optionsScrollController.hasClients) return;
      final position = _optionsScrollController.position;
      final target = highlightedIndex * _optionExtent;
      final viewport = position.viewportDimension;
      final current = position.pixels;
      double? newOffset;
      if (target < current) {
        newOffset = target;
      } else if (target + _optionExtent > current + viewport) {
        newOffset = target + _optionExtent - viewport;
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

  /// Whether the options popover currently has something to accept — gates
  /// Tab-to-select so that, with nothing to pick, Tab keeps doing normal
  /// cell-to-cell focus traversal.
  bool get _hasSelectableOptions =>
      widget.focusNode.hasFocus && _lastOptionsCount > 0;

  /// Fires the inline create when the keyboard cursor is on that row, and
  /// reports whether it did — so both key paths can return before reaching
  /// `RawAutocomplete._select`. Shared because Tab and Enter arrive by
  /// different routes (see the interceptor).
  bool _acceptedCreateRow() {
    if (!_highlightIsCreateRow) return false;
    _startCreate();
    return true;
  }

  /// The one way in to the inline create, from every path.
  ///
  /// Reads the name off the **live controller**, never the highlighted
  /// `_ProductCreate.label`: on a miss `optionsBuilder` debounces 200 ms and
  /// then awaits the server, so that label is the query as it stood when the
  /// builder last resolved. Typing `widge`, then `t`, then Enter inside that
  /// window used to create a product called `widge` while the field read
  /// `widget` — and silently, since `_applyRow` writes the created key back.
  /// `ClientPickerField` re-derives from the controller for the same reason.
  ///
  /// Closes the popover and drops focus first: that is what `_select` used to
  /// do, and it is half of the double-fire guard.
  void _startCreate() {
    if (_creating || !_canCreateProducts) return;
    final query = widget.controller.text.trim();
    if (query.isEmpty) return;
    _creating = true;
    _optionsVisible = false;
    widget.focusNode.unfocus();
    unawaited(
      widget.onCreateRequested(query).whenComplete(() {
        if (mounted) _creating = false;
      }),
    );
  }

  InputDecoration _decoration(BuildContext context) {
    final tokens = context.inTheme;
    return InputDecoration(
      hintText: context.tr(widget.hintKey),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: _kCellPadH,
        vertical: _kCellPadH,
      ),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: tokens.accent, width: 2),
      ),
      suffixIcon: ExcludeSemantics(
        child: Icon(Icons.arrow_drop_down, size: 18, color: tokens.ink3),
      ),
      // Without this the suffix icon imposes the 48 px
      // `kMinInteractiveDimension` and this cell rides taller than the
      // no-suffix cells, breaking the row's centerline.
      suffixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<_ProductOption>(
      textEditingController: widget.controller,
      focusNode: widget.focusNode,
      displayStringForOption: (opt) =>
          opt is _ProductExisting ? opt.product.productKey : opt.label,
      // Flip above the cell when there is more room there. Left at the `.down`
      // default, a row near the bottom of a long invoice gets only the space
      // beneath it, floored at a ~48 px sliver.
      optionsViewOpenDirection: OptionsViewOpenDirection.mostSpace,
      // Async builder: RawAutocomplete awaits this and sets its visible options
      // from the result (with its own call-id guard for out-of-order returns).
      // A synchronous builder can't work here because results arrive after the
      // keystroke — so a stale list would stick (e.g. clearing the field would
      // keep showing the previous search's narrow results).
      //
      // Local-first: the warmed Drift cache renders the dropdown instantly; the
      // network is only blocked on when the cache has nothing for the query.
      // Tradeoff: when the cache holds *some* matches but the server has *more*
      // for a typed query, the extras surface on the next keystroke (after the
      // debounced background refresh upserts them) — there's no supported way
      // to re-run this builder for unchanged text.
      optionsBuilder: (TextEditingValue value) async {
        // Capture before any await — the only BuildContext read in this async
        // builder. `Services` is a long-lived singleton, so this is stable.
        final services = context.read<Services>();
        final query = value.text.trim();
        // Supersede: a newer keystroke bumps `_searchSeq`, so this in-flight
        // build bails out. A bailed-out return is harmless — RawAutocomplete
        // discards it via its own call-id check.
        final seq = ++_searchSeq;

        // Instant snapshot from the warmed cache — no debounce, no network on
        // the critical path. This is what makes the dropdown appear instantly
        // on focus/tap (RawAutocomplete reruns this on the cursor-selection
        // change) and on each keystroke.
        List<_ProductOption> local;
        try {
          local = await _localProducts(services, query);
        } catch (_) {
          local = const <_ProductOption>[];
        }
        if (!mounted || seq != _searchSeq) return const <_ProductOption>[];

        // Route on a real product match, not `local.isNotEmpty`: a non-empty
        // query with zero matches yields only a `_ProductCreate` row — that
        // must still hit the server in case the catalog has the product.
        if (local.any((o) => o is _ProductExisting)) {
          if (_searching || _searchFailed) {
            setState(() {
              _searching = false;
              _searchFailed = false;
            });
          }
          _scheduleBackgroundRefresh(services, query);
          _lastOptionsCount = local.length;
          return local;
        }

        // Nothing cached for this query: fetch from the server (with a spinner)
        // so the full catalog is searched. Debounce so fast typing through a
        // miss doesn't fire a request per keystroke.
        setState(() {
          _searching = true;
          _searchFailed = false;
        });
        await Future<void>.delayed(const Duration(milliseconds: 200));
        if (!mounted || seq != _searchSeq) return const <_ProductOption>[];
        try {
          await services.products.ensurePageLoaded(
            companyId: widget.companyId,
            page: 1,
            search: query.isEmpty ? null : query,
          );
        } catch (_) {
          // ignore — fall back to the local snapshot
        }
        if (!mounted || seq != _searchSeq) return const <_ProductOption>[];
        final List<_ProductOption> afterFetch;
        try {
          // Re-read the local rows after the fetch has upserted (a builder
          // returns once — no live subscription).
          afterFetch = await _localProducts(services, query);
        } catch (_) {
          if (mounted && seq == _searchSeq) {
            setState(() {
              _searching = false;
              _searchFailed = true;
            });
          }
          return const <_ProductOption>[];
        }
        if (!mounted || seq != _searchSeq) return const <_ProductOption>[];
        setState(() {
          _searching = false;
          _searchFailed = false;
        });
        _lastOptionsCount = afterFetch.length;
        return afterFetch;
      },
      onSelected: (opt) {
        if (opt is _ProductExisting) {
          widget.onSelected(opt.product);
          return;
        }
        // Backstop only. The pointer path calls `_startCreate` from
        // `InkWell.onTap` and both key paths intercept below, because
        // `_select` early-returns on an unchanged selection. Handling it here
        // rather than dropping it matters: `_select` has already latched this
        // instance as its selection, so ignoring it would strand the row.
        _startCreate();
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        // Pure key interceptor (no tab stop of its own) so Tab can accept the
        // highlighted suggestion, same as Enter. Up/Down/Enter are left for
        // RawAutocomplete's own shortcuts (we return `ignored`).
        return Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            // Escape hides the overlay through `DismissIntent` without
            // touching focus or text, so this is the only place that can
            // observe it. Stay `ignored` — the SDK still needs the event.
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              _optionsVisible = false;
              return KeyEventResult.ignored;
            }
            if (event.logicalKey != LogicalKeyboardKey.tab) {
              return KeyEventResult.ignored;
            }
            if (HardwareKeyboard.instance.isShiftPressed) {
              return KeyEventResult.ignored;
            }
            if (!_hasSelectableOptions) return KeyEventResult.ignored;
            // Tab reaches `onFieldSubmitted` DIRECTLY, never through
            // `TextField.onSubmitted` — so it needs its own create
            // interception or it falls through to the dead `_select` path.
            if (_acceptedCreateRow()) return KeyEventResult.handled;
            // Accept the highlighted option (selection advances focus to the
            // notes cell). `handled` suppresses default traversal so it doesn't
            // race with that focus move.
            onFieldSubmitted();
            return KeyEventResult.handled;
          },
          child: LineItemSpellCheck(
            builder: (context, config) => TextField(
              controller: controller,
              focusNode: focusNode,
              // On native touch nothing else can close the popover — see
              // `picker_dismissal.dart`. On desktop this is the SDK default.
              onTapOutside: dismissPickerOnTapOutside(focusNode),
              onChanged: (_) => widget.onCommitText(),
              onSubmitted: (_) {
                if (_acceptedCreateRow()) return;
                onFieldSubmitted();
              },
              spellCheckConfiguration: config,
              contextMenuBuilder: spellCheckContextMenuBuilder,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(fontSize: 13),
              decoration: _decoration(context),
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final tokens = context.inTheme;
        final highlightedIndex = AutocompleteHighlightedOption.of(context);
        // Hold the notifier, not the index — see [_highlight].
        _highlight = context
            .dependOnInheritedWidgetOfExactType<AutocompleteHighlightedOption>()
            ?.notifier;
        _visibleOptions = options.toList(growable: false);
        _optionsVisible = true;
        _scrollHighlightedIntoView(highlightedIndex, options.length);
        // No `Align` of our own: `RawAutocomplete` already wraps this in
        // `ConstrainedBox(tight) -> Align`, and a bare `Align` shrink-wraps
        // only under an infinite constraint — so ours would fill the whole
        // bounding box and leave the SDK's alignment nothing to move.
        return BackDismissiblePickerOverlay(
          focusNode: widget.focusNode,
          child: Material(
            elevation: 4,
            color: tokens.surface,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: tokens.border),
              borderRadius: BorderRadius.circular(InRadii.r2),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280, maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searching) const LinearProgressIndicator(minHeight: 2),
                  if (_searchFailed)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: InSpacing.md(context),
                        vertical: InSpacing.sm,
                      ),
                      child: Text(
                        context.tr('couldnt_load_products'),
                        style: TextStyle(color: tokens.ink3, fontSize: 12),
                      ),
                    ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      controller: _optionsScrollController,
                      itemExtent: _optionExtent,
                      itemCount: options.length,
                      itemBuilder: (context, i) {
                        final opt = options.elementAt(i);
                        final isHighlighted = i == highlightedIndex;
                        if (opt is _ProductCreate) {
                          if (!_canCreateProducts) {
                            // Same row, no affordance: it exists only to keep the
                            // option list non-empty so the overlay — and with it
                            // the spinner / error above — can mount at all.
                            return Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: InSpacing.md(context),
                              ),
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  context.tr('no_records_found'),
                                  style: TextStyle(
                                    color: tokens.ink3,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            );
                          }
                          return Container(
                            color: isHighlighted ? tokens.accentSoft : null,
                            child: InkWell(
                              // Straight to the handler, never through
                              // `onSelected`: that is
                              // `RawAutocomplete._select`, which early-returns
                              // on an unchanged selection *before* hiding the
                              // overlay. `_ProductCreate` has no `operator ==`,
                              // so after one cancelled create the same instance
                              // is still latched and the tap was dead until the
                              // user edited the text.
                              onTap: _startCreate,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: InSpacing.md(context),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.add,
                                      size: 16,
                                      // `accentInk`, not `accent`: `accent`
                                      // is the same mid blue in BOTH
                                      // brightnesses and lands at ~3.2:1 on the
                                      // dark `accentSoft` highlight, under the
                                      // 4.5:1 floor. `accentInk` lightens for
                                      // dark themes and clears it either way.
                                      color: tokens.accentInk,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${context.tr('create')} "${opt.label}"',
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
                          );
                        }
                        final product = (opt as _ProductExisting).product;
                        return Container(
                          color: isHighlighted ? tokens.accentSoft : null,
                          child: InkWell(
                            onTap: () => onSelected(opt),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: InSpacing.md(context),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            product.productKey,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: tokens.ink,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        ProductStockLabel(
                                          quantity: product.inStockQuantity,
                                          show: widget.showStock,
                                        ),
                                      ],
                                    ),
                                    if (widget.showProductDetails &&
                                        product.notes.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          // The dates the keyword becomes, as
                                          // in the picker sheet and the
                                          // Products list
                                          // (invoiceninja/flutter#93).
                                          expandDatePlaceholders(
                                            product.notes,
                                            formatter: widget.formatter,
                                          ).split('\n').first,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: tokens.ink3,
                                            fontSize: 11,
                                          ),
                                        ),
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

sealed class _ProductOption {
  String get label;
}

class _ProductExisting implements _ProductOption {
  _ProductExisting(this.product);
  final Product product;
  @override
  String get label => product.productKey;
}

class _ProductCreate implements _ProductOption {
  _ProductCreate(this.label);
  @override
  final String label;
}

/// Inline tax dropdown — small list (rarely > 30 rates), so we materialize
/// the watch and feed an `Autocomplete<TaxRate>` for filterable picking.
/// A switch-typed custom field: a compact checkbox centred in its column.
///
/// The whole cell takes the tap, so the compact box (32 px, shrink-wrapped —
/// on touch the padded 48 px target would grow every row by 14 px) is not
/// the only thing to hit. Null [onChanged] disables it.
class _SwitchCell extends StatelessWidget {
  const _SwitchCell({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return Tooltip(
      message: label,
      // The checkbox's `semanticLabel` already names it.
      excludeFromSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // The checkbox carries the semantics, label and toggle action both.
        excludeFromSemantics: true,
        onTap: onChanged == null ? null : () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _kRowContentHeight),
          child: Center(
            child: Checkbox(
              value: value,
              onChanged: onChanged == null
                  ? null
                  : (v) => onChanged(v ?? false),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              semanticLabel: label,
            ),
          ),
        ),
      ),
    );
  }
}

/// A dropdown-typed custom field, as a menu of its [options].
///
/// Not `SearchableDropdownField`, which the edit dialog uses: its ✕ + ▾
/// suffix alone is 72–96 px, its outlined field ~56 px tall — wider than the
/// column and taller than the row — and `RawAutocomplete` lays its popover
/// out at the field's width, a 120 px list. A menu sizes to its options,
/// raises no keyboard on a tablet and is one Tab stop. Styled like the tax
/// cell beside it: borderless, the label as the empty cell's hint, a ▾.
///
/// [options] leads with the blank (`customFieldDropdownItems`), which clears
/// the value. Null [onChanged] disables the cell.
class _ChoiceMenuCell extends StatelessWidget {
  const _ChoiceMenuCell({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<String> options;
  final String value;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final onChanged = this.onChanged;
    return BackDismissibleMenuAnchor(
      menuChildren: [
        for (final option in options)
          MenuItemButton(
            onPressed: onChanged == null ? null : () => onChanged(option),
            leadingIcon: SizedBox(
              width: 18,
              child: option == value && option.isNotEmpty
                  ? Icon(Icons.check, size: 16, color: tokens.ink)
                  : null,
            ),
            child: Text(
              option.isEmpty ? context.tr('none') : option,
              style: TextStyle(
                fontSize: 13,
                color: option.isEmpty ? tokens.ink3 : tokens.ink,
              ),
            ),
          ),
      ],
      builder: (context, controller, _) {
        final toggle = onChanged == null
            ? null
            : () => controller.isOpen ? controller.close() : controller.open();
        // One node — "Color, Blue, button" — rather than the label and value
        // here followed by the same value again from the Text below.
        return Semantics(
          button: true,
          enabled: toggle != null,
          label: label,
          value: value,
          onTap: toggle,
          excludeSemantics: true,
          // A local Material, or the InkWell's focus / hover / press ink paints
          // on the Scaffold's — under the table's opaque surface and the row's
          // hover fill, a Tab stop nobody can see (the `Ink` rule,
          // docs/sidebar-and-shell.md).
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: toggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: _kRowContentHeight,
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: _kCellPadH),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          value.isEmpty ? label : value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: value.isEmpty ? tokens.ink3 : tokens.ink,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, size: 18, color: tokens.ink3),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A dropdown-typed custom field with more options than a menu should list
/// (`_kMaxMenuOptions`): typed to filter, like the tax cell.
///
/// The rules `docs/pickers.md` records for `SearchableDropdownField`, applied
/// to a cell that can't be one (its suffix and height don't fit a row):
///  * the idle list leads with the stored value and ends with the blank, so
///    the default highlight — row 0, which Enter picks — keeps the value
///    rather than clearing it, and text equal to the value is not a query;
///  * a tap re-opens the whole list, by writing the text away and back —
///    `RawAutocomplete` recomputes options only on a text change;
///  * re-picking the value already held closes the list — `_select` returns
///    early on an unchanged selection, before it hides the overlay;
///  * leaving the cell keeps a typed option's exact name and puts anything
///    else back to the stored value.
class _ChoiceSearchCell extends StatefulWidget {
  const _ChoiceSearchCell({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<String> options;
  final String value;
  final ValueChanged<String>? onChanged;

  @override
  State<_ChoiceSearchCell> createState() => _ChoiceSearchCellState();
}

class _ChoiceSearchCellState extends State<_ChoiceSearchCell> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  final FocusNode _focusNode = FocusNode();

  /// `RawAutocomplete` clamps the old highlight onto a new list rather than
  /// resetting it, so a list recomputed after the user arrowed down would
  /// leave Enter on whatever row that index now holds. Held, not read once:
  /// see `SearchableDropdownField._highlight`.
  ValueNotifier<int>? _highlight;
  bool _resetHighlight = false;

  /// The text the options were last built for. `optionsBuilder` also runs on a
  /// caret move, and resetting the highlight then would undo the arrow keys.
  String? _optionsText;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_ChoiceSearchCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && widget.value != oldWidget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<String> _idle() => [
    if (widget.value.isNotEmpty) widget.value,
    for (final o in widget.options)
      if (o.isNotEmpty && o != widget.value) o,
    '',
  ];

  Iterable<String> _optionsFor(TextEditingValue text) {
    if (text.text != _optionsText) {
      _optionsText = text.text;
      _resetHighlight = true;
    }
    final q = text.text.trim().toLowerCase();
    if (q.isEmpty || text.text == widget.value) return _idle();
    return widget.options.where(
      (o) => o.isNotEmpty && o.toLowerCase().contains(q),
    );
  }

  void _commit(String option) {
    if (option == widget.value) {
      _controller.text = widget.value;
      _focusNode.unfocus();
      return;
    }
    widget.onChanged?.call(option);
  }

  void _reopen() {
    // A mid-edit tap places a caret in the user's own query; leave it be.
    if (_controller.text != widget.value) return;
    if (_controller.value.isComposingRangeValid) return;
    final text = _controller.text;
    // Writing an identical value notifies nobody, so an empty field needs a
    // non-empty sentinel or the bounce does nothing.
    _controller.value = TextEditingValue(text: text.isEmpty ? ' ' : '');
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection(baseOffset: 0, extentOffset: text.length),
    );
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) return;
    final typed = _controller.text.trim().toLowerCase();
    if (typed.isNotEmpty && typed != widget.value.toLowerCase()) {
      for (final o in widget.options) {
        if (o.toLowerCase() == typed) {
          _controller.text = o;
          widget.onChanged?.call(o);
          return;
        }
      }
    }
    if (_controller.text != widget.value) _controller.text = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final onChanged = widget.onChanged;
    return RawAutocomplete<String>(
      textEditingController: _controller,
      focusNode: _focusNode,
      displayStringForOption: (o) => o,
      optionsViewOpenDirection: OptionsViewOpenDirection.mostSpace,
      optionsBuilder: _optionsFor,
      onSelected: _commit,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: onChanged != null,
          // On native touch nothing else can close the popover — see
          // `picker_dismissal.dart`. On desktop this is the SDK default.
          onTapOutside: dismissPickerOnTapOutside(focusNode),
          onTap: _reopen,
          onSubmitted: (_) => onFieldSubmitted(),
          textAlignVertical: TextAlignVertical.center,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: widget.label,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: _kCellPadH,
              vertical: _kCellPadH,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: tokens.accent, width: 2),
            ),
            suffixIcon: ExcludeSemantics(
              child: Icon(Icons.arrow_drop_down, size: 18, color: tokens.ink3),
            ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 28,
              minHeight: 28,
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final highlighted = AutocompleteHighlightedOption.of(context);
        _highlight = context
            .dependOnInheritedWidgetOfExactType<AutocompleteHighlightedOption>()
            ?.notifier;
        if (_resetHighlight) {
          _resetHighlight = false;
          // Post-frame: writing the notifier mid-build would rebuild its
          // dependents mid-build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _highlight?.value = 0;
          });
        }
        return BackDismissiblePickerOverlay(
          focusNode: _focusNode,
          child: Material(
            elevation: 4,
            color: tokens.surface,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: tokens.border),
              borderRadius: BorderRadius.circular(InRadii.r2),
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final option = options.elementAt(i);
                  final isHighlighted = i == highlighted;
                  if (isHighlighted) {
                    // Keep the row the arrow keys moved to in view.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (context.mounted) {
                        Scrollable.ensureVisible(context, alignment: 0.5);
                      }
                    });
                  }
                  return Material(
                    color: isHighlighted
                        ? tokens.surfaceAlt
                        : Colors.transparent,
                    child: InkWell(
                      // Not `onSelected` for the value already held — see
                      // the class doc.
                      onTap: () => option == widget.value
                          ? _commit(option)
                          : onSelected(option),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: InSpacing.md(context),
                          vertical: 10,
                        ),
                        child: Text(
                          option.isEmpty ? context.tr('none') : option,
                          style: TextStyle(
                            color: option.isEmpty ? tokens.ink3 : tokens.ink,
                            fontSize: 13,
                            fontWeight:
                                option.isNotEmpty && option == widget.value
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TaxCell extends StatefulWidget {
  const _TaxCell({
    required this.companyId,
    required this.services,
    required this.formatter,
    required this.initialName,
    required this.initialRate,
    required this.onSelected,
  });

  final String companyId;
  final Services services;
  final Formatter? formatter;
  final String initialName;
  final Decimal initialRate;
  final ValueChanged<TaxRate?> onSelected;

  @override
  State<_TaxCell> createState() => _TaxCellState();
}

class _TaxCellState extends State<_TaxCell> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _displayFor(
        widget.initialName,
        widget.initialRate,
        widget.formatter,
      ),
    );
    _focusNode = FocusNode();
    _ratesStream = widget.services.taxRates.watchAll(
      companyId: widget.companyId,
    );
  }

  /// Cached, not rebuilt per frame. One of these exists per line-item row and
  /// the table rebuilds on every keystroke, so a stream opened in `build` tore
  /// down and restarted a Drift query per row per frame. Same fix as
  /// `_LineItemTableDesktopState._companyStream` above.
  late Stream<List<TaxRate>> _ratesStream;

  @override
  void didUpdateWidget(_TaxCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only on an actual company switch — re-creating it on any other rebuild is
    // the churn the cached stream exists to avoid.
    if (widget.companyId != oldWidget.companyId ||
        widget.services != oldWidget.services) {
      _ratesStream = widget.services.taxRates.watchAll(
        companyId: widget.companyId,
      );
    }
    if (!_focusNode.hasFocus &&
        (widget.initialName != oldWidget.initialName ||
            widget.initialRate != oldWidget.initialRate ||
            widget.formatter != oldWidget.formatter)) {
      _controller.text = _displayFor(
        widget.initialName,
        widget.initialRate,
        widget.formatter,
      );
    }
  }

  static String _displayFor(String name, Decimal rate, Formatter? formatter) {
    if (name.isEmpty) return '';
    final pct = formatter?.percent(rate.toDouble()) ?? '$rate%';
    return '$name $pct';
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  InputDecoration _decoration(BuildContext context) {
    final tokens = context.inTheme;
    return InputDecoration(
      hintText: context.tr('tax'),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: _kCellPadH,
        vertical: _kCellPadH,
      ),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: tokens.accent, width: 2),
      ),
      suffixIcon: ExcludeSemantics(
        child: Icon(Icons.arrow_drop_down, size: 18, color: tokens.ink3),
      ),
      // Without this the suffix icon imposes the 48 px
      // `kMinInteractiveDimension` and this cell rides taller than the
      // no-suffix cells, breaking the row's centerline.
      suffixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return StreamBuilder<List<TaxRate>>(
      stream: _ratesStream,
      builder: (context, snapshot) {
        final rates = snapshot.data ?? const <TaxRate>[];
        return RawAutocomplete<_TaxOption>(
          textEditingController: _controller,
          focusNode: _focusNode,
          displayStringForOption: (opt) => opt.display,
          // Flip above the field when there is more room there. Left at the
          // `.down` default — as this cell alone was — a tax cell on the last
          // row of a long invoice gets only the space beneath it, floored at a
          // ~48 px sliver. The other four pickers already pass this.
          optionsViewOpenDirection: OptionsViewOpenDirection.mostSpace,
          optionsBuilder: (value) {
            final q = value.text.trim().toLowerCase();
            final filtered = q.isEmpty
                ? rates
                : rates.where((r) => r.name.toLowerCase().contains(q));
            return [
              const _TaxOption.none(),
              for (final r in filtered) _TaxOption.rate(r),
            ];
          },
          onSelected: (opt) {
            widget.onSelected(opt.rate);
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              // On native touch nothing else can close the popover — see
              // `picker_dismissal.dart`. On desktop this is the SDK default.
              onTapOutside: dismissPickerOnTapOutside(focusNode),
              onSubmitted: (_) => onFieldSubmitted(),
              textAlign: TextAlign.right,
              textAlignVertical: TextAlignVertical.center,
              readOnly: rates.isEmpty,
              style: const TextStyle(fontSize: 13),
              decoration: _decoration(context),
            );
          },
          // No `Align` of our own: `RawAutocomplete` already wraps this in
          // `ConstrainedBox(tight) -> Align`, and a bare `Align` shrink-wraps
          // only under an infinite constraint — so ours would fill the whole
          // bounding box and leave the SDK's alignment nothing to move.
          optionsViewBuilder: (context, onSelected, options) =>
              BackDismissiblePickerOverlay(
                focusNode: _focusNode,
                child: Material(
                  elevation: 4,
                  color: tokens.surface,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: tokens.border),
                    borderRadius: BorderRadius.circular(InRadii.r2),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 240,
                      maxWidth: 280,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: options.length,
                      itemBuilder: (context, i) {
                        final opt = options.elementAt(i);
                        return InkWell(
                          onTap: () => onSelected(opt),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: InSpacing.md(context),
                              vertical: 10,
                            ),
                            child: Text(
                              opt.displayLocalized(widget.formatter).isEmpty
                                  ? context.tr('none')
                                  : opt.displayLocalized(widget.formatter),
                              style: TextStyle(color: tokens.ink, fontSize: 13),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
        );
      },
    );
  }
}

class _TaxOption {
  const _TaxOption.none() : rate = null;
  const _TaxOption.rate(TaxRate this.rate);
  final TaxRate? rate;
  String get display => rate == null ? '' : '${rate!.name} ${rate!.rate}%';

  /// Display formatted with the company's decimal separator. EU users
  /// see `19,0%` instead of `19.0%`.
  String displayLocalized(Formatter? formatter) {
    if (rate == null) return '';
    final pct = formatter?.percent(rate!.rate.toDouble()) ?? '${rate!.rate}%';
    return '${rate!.name} $pct';
  }
}
