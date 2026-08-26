import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/product.dart';
import 'package:admin/data/models/domain/tax_rate.dart';
import 'package:admin/domain/date_placeholders.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
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

/// Inline-editable desktop line-item table. Each cell is its own editor
/// (product autocomplete, debounced text fields, tax dropdown). Drag
/// handles + per-row overflow menu cover reorder / clone / insert /
/// remove. A synthetic trailing blank row is always rendered so the
/// user can start typing without first clicking Add.
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
    final ghost = _rows.last.buildItem(emptyLineItem(), useComma: _useComma);
    if (!ghost.isBlank) next.add(ghost);
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
      // Promoting the ghost row.
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
    next.insert(index + 1, next[index]);
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
    }) {
      return Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.only(right: _kCellPadH),
          child: Align(
            alignment: align,
            child: Text(
              text,
              maxLines: 1,
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
            cell(item?.notes ?? '', flex: 3),
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
              Column(
                children: [
                  _ColumnHeader(config: widget.config),
                  Divider(height: 1, color: tokens.border),
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: _rows.length,
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
                          final t = Curves.easeInOut.transform(animation.value);
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
                      final errors = isGhost ? null : widget.rowErrors?[index];
                      return _Row(
                        key: ValueKey(row.id),
                        index: index,
                        isLast: index == _rows.length - 1,
                        isGhost: isGhost,
                        lastRealIndex: items.length - 1,
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
                                  conversionRate: widget.productConversionRate,
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
                        canCreateTask:
                            !isGhost &&
                            widget.onCreateTaskFromLineItem != null &&
                            (current.taskId ?? '').isEmpty,
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
                    },
                  ),
                  Divider(height: 1, color: tokens.border),
                  // The redundant "+ Add item" button was removed — the
                  // synthetic trailing ghost row promotes itself on first
                  // keystroke, Tab from the last cell adds another row,
                  // and bulk adds go through the items-section FAB →
                  // line-item picker. `_addBlankRow` survives because
                  // it's still called by `onTabFromLastCell`.
                ],
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
    String label(String key) => config.labels.resolve(context, key);
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
          // Headers resolve the company's Custom Labels before the bundled
          // string — see `LineItemColumnConfig.labels`.
          cell(label('item'), flex: 3),
          cell(label('description'), flex: 3),
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

/// Per-row mutable state. Survives parent rebuilds so cursor position
/// stays put while typing.
class _RowState {
  _RowState();

  final String id = UniqueKey().toString();
  final TextEditingController product = TextEditingController();
  final TextEditingController notes = TextEditingController();
  final TextEditingController cost = TextEditingController();
  final TextEditingController quantity = TextEditingController();
  final TextEditingController discount = TextEditingController();

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
  }

  String _seedFor(Decimal d) => d == Decimal.zero ? '' : d.toString();

  /// Build a LineItem reflecting the current controller text. Used to
  /// commit the row on save / focus-out / explicit flush. The
  /// [useComma] flag honours the company's `use_comma_as_decimal_place`
  /// setting so EU users typing `1,50` produce 1.5 rather than 0.
  LineItem buildItem(LineItem base, {bool useComma = false}) {
    return base.copyWith(
      productKey: product.text.trim(),
      notes: notes.text,
      cost:
          parseDecimal(cost.text, useCommaAsDecimalPlace: useComma) ??
          Decimal.zero,
      quantity:
          parseDecimal(quantity.text, useCommaAsDecimalPlace: useComma) ??
          Decimal.one,
      discount:
          parseDecimal(discount.text, useCommaAsDecimalPlace: useComma) ??
          Decimal.zero,
    );
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
  final ValueChanged<String> onCreateProduct;
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
  ValueChanged<String> get onCreateProduct => widget.onCreateProduct;
  ValueChanged<_RowAction> get onMenuAction => widget.onMenuAction;
  VoidCallback get onTabFromLastCell => widget.onTabFromLastCell;
  bool get canCreateTask => widget.canCreateTask;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;

    void commitNow() {
      onCellCommit(row.buildItem(currentItem, useComma: useComma));
    }

    void scheduleCommit() {
      row.scheduleCommit(commitNow);
    }

    Widget endTotalCell() {
      final cost =
          parseDecimal(row.cost.text, useCommaAsDecimalPlace: useComma) ??
          Decimal.zero;
      final qty =
          parseDecimal(row.quantity.text, useCommaAsDecimalPlace: useComma) ??
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
                    hintKey: isGhost ? 'add_an_item' : 'product',
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
                  ),
                ),
              ),
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
              for (var slot = 1; slot <= config.taxColumnCount; slot++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: _kCellPadH),
                    child: _TaxCell(
                      key: ValueKey('tax_$slot'),
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
  });

  final ValueChanged<_RowAction> onSelected;
  final bool canMoveUp;
  final bool canMoveDown;
  final bool canCreateTask;

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
    this.errorText,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onChanged;
  final String? hintKey;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: (_) => onChanged(),
      textAlignVertical: TextAlignVertical.center,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hintKey == null ? null : context.tr(hintKey!),
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
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
  final ValueChanged<String> onCreateRequested;
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
  bool _searching = false;
  bool _searchFailed = false;
  // Debounces the background catalog refresh fired from the local-first
  // (instant) path — without it a fast typist would hit the network once per
  // keystroke (the old 200 ms sleep that used to coalesce them is gone there).
  Timer? _bgRefreshTimer;
  final ScrollController _optionsScrollController = ScrollController();

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
  }

  @override
  void dispose() {
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
        } else if (opt is _ProductCreate) {
          widget.onCreateRequested(opt.label);
        }
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
            if (event.logicalKey != LogicalKeyboardKey.tab) {
              return KeyEventResult.ignored;
            }
            if (HardwareKeyboard.instance.isShiftPressed) {
              return KeyEventResult.ignored;
            }
            if (!_hasSelectableOptions) return KeyEventResult.ignored;
            // Accept the highlighted option (selection advances focus to the
            // notes cell). `handled` suppresses default traversal so it doesn't
            // race with that focus move.
            onFieldSubmitted();
            return KeyEventResult.handled;
          },
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: (_) => widget.onCommitText(),
            onSubmitted: (_) => onFieldSubmitted(),
            textAlignVertical: TextAlignVertical.center,
            style: const TextStyle(fontSize: 13),
            decoration: _decoration(context),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final tokens = context.inTheme;
        final highlightedIndex = AutocompleteHighlightedOption.of(context);
        _scrollHighlightedIntoView(highlightedIndex, options.length);
        return Align(
          alignment: Alignment.topLeft,
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
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.add,
                                        size: 16,
                                        color: tokens.accent,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${context.tr('create')} "${opt.label}"',
                                          style: TextStyle(
                                            color: tokens.accent,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
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
class _TaxCell extends StatefulWidget {
  const _TaxCell({
    super.key,
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
              onSubmitted: (_) => onFieldSubmitted(),
              textAlign: TextAlign.right,
              textAlignVertical: TextAlignVertical.center,
              readOnly: rates.isEmpty,
              style: const TextStyle(fontSize: 13),
              decoration: _decoration(context),
            );
          },
          optionsViewBuilder: (context, onSelected, options) => Align(
            alignment: Alignment.topLeft,
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
