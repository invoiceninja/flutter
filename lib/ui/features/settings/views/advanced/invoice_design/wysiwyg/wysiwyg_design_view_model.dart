import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:admin/data/models/api/design_api_model.dart'
    show DesignTemplateApi;
import 'package:admin/data/models/domain/company_settings.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/models/domain/design_block_layout.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/design_repository.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_library.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_sizing.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/history/history_stack.dart';

/// Drives the WYSIWYG invoice designer screen.
///
/// Owns `template.blocks` and `template.documentSettings` via the underlying
/// [Design] draft — every mutation goes through [updateDraft] so the
/// `isDirty` flag, history tracking, and save pipeline inherited from
/// [GenericEditViewModel] all work without bespoke wiring.
///
/// Selection + property-panel mode are NOT persisted on the design — they
/// live on the VM and reset when the user opens a new design.
class WysiwygDesignViewModel extends GenericEditViewModel<Design> {
  WysiwygDesignViewModel({
    required this.repo,
    required this.companyId,
    Design? existing,
    Design? seed,
    String defaultName = '',
    this.companySettings,
    this.brandColors = const [],
    this.customFieldLabels = const {},
    super.sync,
    super.connectivity,
  }) : super(
         initialDraft: _seed(existing, seed, defaultName, companySettings),
         original: existing,
         companyId: companyId,
       );

  final DesignRepository repo;
  final String companyId;

  /// The company's settings: what a new design's page starts from, and what
  /// a design that carries no page settings of its own prints with.
  final CompanySettings? companySettings;

  /// The design as opened was arranged on the old free grid in a way that
  /// grid drew differently from how it prints, so this page shows it changed
  /// though nothing about its PDF has. Worth one sentence on open.
  late final bool openedWithFreeGridLayout =
      original != null && hasFreeGridOverlap(original!.template.blocks);

  /// The company's own colours, offered first by the colour picker.
  final List<String> brandColors;

  /// The names the company gave its custom fields, by slot (`client1`,
  /// `invoice2`, `product3`…). The variable picker shows them in place of
  /// "First Custom".
  final Map<String, String> customFieldLabels;

  /// The document types a new visual design applies to. All four: the design
  /// pickers hide a custom design from a type it does not list, and a builder
  /// that only ever wrote `invoice` made its designs unusable for quotes,
  /// credits and purchase orders.
  static const defaultEntities = <String>[
    'invoice',
    'quote',
    'credit',
    'purchase_order',
  ];

  /// Build the initial draft. For a new design it is [seed] (a starter layout,
  /// or a design being copied) or a blank one, given [defaultName] and — when
  /// it has none of its own — document settings seeded from the company, as
  /// React's `createDefaultDocumentSettings(companySettings)` does.
  ///
  /// The result is also the create baseline, so a starter the user has not
  /// touched is not "unsaved changes".
  static Design _seed(
    Design? existing,
    Design? seed,
    String defaultName,
    CompanySettings? companySettings,
  ) {
    if (existing != null) return existing;
    final base = seed?.copyWith(id: '') ?? _emptyDesign();
    return base.copyWith(
      name: base.name.isEmpty ? defaultName : base.name,
      entities: base.entities.isEmpty ? defaultEntities : base.entities,
      template:
          base.template.documentSettings != null || companySettings == null
          ? base.template
          : base.template.copyWith(
              documentSettings: _seededDocumentSettings(companySettings),
            ),
    );
  }

  static DocumentSettings _seededDocumentSettings(CompanySettings c) {
    return DocumentSettings(
      pageLayout: c.pageLayout ?? 'portrait',
      pageSize: c.pageSize ?? 'A4',
      globalFontSize: c.fontSize ?? 16,
      primaryFont: (c.primaryFont != null && c.primaryFont!.isNotEmpty)
          ? c.primaryFont!
          : 'Roboto',
      secondaryFont: (c.secondaryFont != null && c.secondaryFont!.isNotEmpty)
          ? c.secondaryFont!
          : 'Roboto',
      showPaidStamp: c.showPaidStamp ?? false,
      showShippingAddress: c.showShippingAddress ?? false,
      embedDocuments: c.embedDocuments ?? false,
      hideEmptyColumns: c.hideEmptyColumnsOnPdf ?? false,
      pageNumbering: c.pageNumbering ?? false,
      // Page margins / padding are design-only — not seeded from company
      // (React `createDefaultDocumentSettings` does the same).
    );
  }

  /// Selected block id; null when nothing is selected (right pane defaults
  /// to Document Settings — better empty-state than React's blank panel).
  String? _selectedBlockId;
  String? get selectedBlockId => _selectedBlockId;

  /// Undo/redo over the whole template — blocks and document settings. Every
  /// change goes through [_apply], which snapshots the state it replaces;
  /// consecutive edits of one field fold into a single step, and a drag
  /// gesture ([beginGesture] … [endGesture]) is one step however many frames
  /// it took. Cleared on [resetToEmpty].
  final DesignerHistoryStack<DesignTemplate> _history = DesignerHistoryStack();
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  /// What the last change edited, when it was one that folds — see [_apply].
  String? _undoKey;
  bool _inGesture = false;
  bool _gestureRecorded = false;
  DesignTemplate? _gestureStart;

  /// Bumped whenever the template is replaced from outside the property
  /// panel — undo, redo, an import, a new layout, a discard. The panel keys
  /// its editors on it: they hold text of their own, seeded when a block is
  /// selected, and after an undo they went on showing the undone text — which
  /// the next keystroke then wrote back.
  int get templateEpoch => _templateEpoch;
  int _templateEpoch = 0;

  PropertyPanelMode get panelMode => _selectedBlockId == null
      ? PropertyPanelMode.document
      : PropertyPanelMode.block;

  /// Live blocks list (read-only — mutate via the methods below).
  List<DesignBlock> get blocks => draft.template.blocks;

  /// The page's settings. A design that stores none prints with the
  /// company's (the server lays a design's settings *over* them, key by
  /// key), so that is what this answers with — not built-in defaults. It
  /// used to: the Page tab then showed Roboto / A4 / 16px whatever was
  /// printing, and the first edit stored all eighteen defaults as overrides,
  /// so flipping a design's orientation also changed its font.
  DocumentSettings get documentSettings =>
      draft.template.documentSettings ?? _companyDocumentSettings;

  late final DocumentSettings _companyDocumentSettings = companySettings == null
      ? const DocumentSettings()
      : _seededDocumentSettings(companySettings!);

  DesignBlock? get selectedBlock {
    final id = _selectedBlockId;
    if (id == null) return null;
    for (final b in blocks) {
      if (b.id == id) return b;
    }
    return null;
  }

  @override
  bool draftIsNonEmpty() => draft != createBaseline;

  // ── Saving, in a form that stays open ─────────────────────────────
  //
  // The base view model is written for forms that close when they save:
  // "unsaved" means "differs from what was opened", Discard means "back to
  // what was opened", and it latches itself clean after a save without
  // looking at whether the draft is still the one it sent. The builder stays
  // open, so each of those needs the *last save* as its reference instead.

  /// The id the first save of a new design gave it — its temp id until the
  /// create lands, the server's after. From then on the form saves that
  /// record: sending the create a second time would make the design twice.
  String? _savedId;

  /// The draft the last successful save sent. Null until there is one.
  Design? _lastSaved;

  /// The draft the save in flight is sending.
  Design? _sending;

  /// Whether this design exists beyond the form — it was opened from the
  /// list, or has been saved at least once.
  bool get hasBeenSaved => original != null || _savedId != null;

  /// The id company settings would hold for this design: the record it was
  /// opened on, or the server's id for one made here. Null for a design never
  /// saved **and for one whose create has not landed** — a temp id equals
  /// nothing in anyone's settings, so comparing with it answered "not in
  /// use" for the whole session, even after the design was put to use.
  String? get savedDesignId {
    final id = _savedId ?? original?.id;
    return id == null || id.startsWith('tmp_') ? null : id;
  }

  /// The id to hand to something that resolves temp ids itself.
  String? get savedOrPendingDesignId => _savedId ?? original?.id;

  @override
  bool get isDirty => _lastSaved == null ? super.isDirty : draft != _lastSaved;

  /// Whether there is anything Save would send: an edit, or a new design that
  /// has never been saved — a starter is worth saving as it stands.
  bool get hasUnsavedWork => isDirty || (isCreate && _savedId == null);

  @override
  Future<Design?> save() async {
    final saved = await super.save();
    if (saved != null) {
      // What went out — not whatever the draft has become since: an edit
      // made while the save was in flight is still unsaved.
      _lastSaved = _sending ?? draft;
      if (isCreate) _savedId = await repo.resolveId(saved.id);
      if (!isDisposed) notifyListeners();
    }
    _sending = null;
    return saved;
  }

  /// Ask again whether the create has landed — after something that waited
  /// on the outbox (putting the design to use does).
  Future<void> refreshSavedId() async {
    final id = _savedId;
    if (id == null || !id.startsWith('tmp_')) return;
    final resolved = await repo.resolveId(id);
    if (resolved == id || isDisposed) return;
    _savedId = resolved;
    notifyListeners();
  }

  @override
  Future<SaveResult<Design>> performSave() async {
    _sending = draft;
    final savedId = _savedId;
    if (savedId != null) {
      final id = await repo.resolveId(savedId);
      if (!id.startsWith('tmp_')) {
        _savedId = id;
        return repo.save(
          companyId: companyId,
          design: draft.copyWith(id: id),
        );
      }
      // Its create has not landed: still queued, or rejected. An update
      // would wait behind it — for good, if it was rejected — so the record
      // goes out whole again under the same temp id, replacing the queued
      // create (and refused if that one has landed meanwhile).
      final result = await repo.create(
        companyId: companyId,
        draft: draft,
        existingTempId: savedId,
      );
      rememberCreateTempId(result.entity.id);
      return result;
    }
    if (savesAsCreate) {
      final result = await repo.create(
        companyId: companyId,
        draft: draft,
        existingTempId: recoveryTempId,
      );
      rememberCreateTempId(result.entity.id);
      return result;
    }
    return repo.save(companyId: companyId, design: draft);
  }

  // ── Selection ──────────────────────────────────────────────────────

  /// Bumped to ask the property panel to put the caret in the selected
  /// block's main text field — a second press on a block, or Enter. The
  /// panel listens; a block with no text field ignores it.
  final ValueNotifier<int> contentFocusRequest = ValueNotifier<int>(0);

  void requestContentFocus() => contentFocusRequest.value++;

  @override
  void dispose() {
    contentFocusRequest.dispose();
    super.dispose();
  }

  void selectBlock(String? id) {
    if (_selectedBlockId == id) return;
    // A drag cannot outlive the selection its handle belonged to.
    endGesture();
    _selectedBlockId = id;
    // Coming back to a field later starts a new undo step.
    _undoKey = null;
    notifyListeners();
  }

  // ── Rows ──────────────────────────────────────────────────────────

  /// The page as the server will print it: rows of blocks. Every edit below
  /// works on these and writes `gridPosition` back through [blocksFromRows].
  List<DesignRow> get rows => rowsOf(blocks);

  static String _newId(String type) => newBlockId(type);

  /// The narrowest a block may be dragged or squeezed to, in columns.
  static int minWidthOf(DesignBlock block) =>
      isGapBlock(block) ? 0 : sizeBoundsFor(block.type).minW;

  void _commitRows(List<DesignRow> rows, {String? coalesce}) =>
      _applyBlocks(blocksFromRows(rows), coalesce: coalesce);

  /// The width a block asks for when it joins a row of [neighbours] blocks.
  ///
  /// One that already shares a row keeps the width the user gave it. One with
  /// a row to itself — or fresh from the palette — is nominally as wide as
  /// its type's default, which for a table or a footer is the whole page:
  /// asking for that would squeeze every neighbour to its minimum. It asks
  /// for an equal share instead, or its default when that is narrower (a QR
  /// code does not need half a page).
  DesignBlock _asJoining(
    DesignBlock block, {
    required bool wasAlone,
    required int neighbours,
  }) {
    if (!wasAlone) return block;
    final share = (kDesignerGridCols ~/ (neighbours + 1)).clamp(
      1,
      kDesignerGridCols,
    );
    final preferred = blockSpecFor(block.type)?.defaultWidth ?? share;
    final w = preferred < share ? preferred : share;
    return block.copyWith(gridPosition: block.gridPosition.copyWith(w: w));
  }

  static int _solidCount(DesignRow row, {String? except}) =>
      row.where((b) => !isGapBlock(b) && b.id != except).length;

  // ── Adding ────────────────────────────────────────────────────────

  /// Add a block from the palette as a new row — below the row of the
  /// selected block, or at the end of the page.
  void addBlock(BlockSpec spec) {
    final current = rows;
    final selected = _selectedBlockId;
    final at = selected == null ? null : locateBlock(current, selected);
    insertRow(spec, at == null ? current.length : at.row + 1);
  }

  /// Add a block from the palette as a new row at [rowIndex].
  void insertRow(BlockSpec spec, int rowIndex) {
    final block = spec.newInstance(idPrefix: spec.type, x: 0, y: 0);
    _selectedBlockId = block.id;
    _commitRows(withNewRow(rows, rowIndex, block));
  }

  /// Add a block from the palette beside block [anchorId]. False — and
  /// nothing changes — when the row has no room for it.
  bool insertBeside(BlockSpec spec, String anchorId, {required bool before}) {
    final current = rows;
    final at = locateBlock(current, anchorId);
    if (at == null) return false;
    final block = _asJoining(
      spec.newInstance(idPrefix: spec.type, x: 0, y: 0),
      wasAlone: true,
      neighbours: _solidCount(current[at.row]),
    );
    final next = _withBlockBeside(current, block, anchorId, before: before);
    if (next == null) return false;
    _selectedBlockId = block.id;
    _commitRows(next);
    return true;
  }

  /// Whether a block of [type] — or the block [movingId], which leaves its
  /// own place first — could be put beside block [anchorId].
  bool canPlaceBeside(String anchorId, {String? type, String? movingId}) {
    var current = rows;
    final target = locateBlock(current, anchorId);
    if (target == null) return false;
    final neighbours = _solidCount(current[target.row], except: movingId);
    DesignBlock? incoming;
    if (movingId != null) {
      if (movingId == anchorId) return false;
      final from = locateBlock(current, movingId);
      if (from == null) return false;
      incoming = _asJoining(
        current[from.row][from.index],
        wasAlone: _isAlone(current[from.row], movingId),
        neighbours: neighbours,
      );
      current = withoutBlock(current, movingId, newId: _newId);
    } else if (type != null) {
      final spec = blockSpecFor(type);
      if (spec != null) {
        incoming = _asJoining(
          spec.newInstance(idPrefix: type, x: 0, y: 0),
          wasAlone: true,
          neighbours: neighbours,
        );
      }
    }
    if (incoming == null) return false;
    final at = locateBlock(current, anchorId);
    if (at == null) return false;
    return canJoinRow(
      current[at.row],
      incoming,
      minWidthOf: minWidthOf,
      newId: _newId,
    );
  }

  List<DesignRow>? _withBlockBeside(
    List<DesignRow> current,
    DesignBlock block,
    String anchorId, {
    required bool before,
  }) {
    final at = locateBlock(current, anchorId);
    if (at == null) return null;
    final cells = explicitRow(current[at.row], _newId);
    final index = cells.indexWhere((c) => c.id == anchorId);
    if (index < 0) return null;
    // Work on the explicit row, so the index means the same thing to
    // [withBlockInRow], which makes it explicit again (a no-op by then).
    final staged = List<DesignRow>.of(current)..[at.row] = cells;
    return withBlockInRow(
      staged,
      at.row,
      before ? index : index + 1,
      block,
      minWidthOf: minWidthOf,
      newId: _newId,
    );
  }

  static bool _isAlone(DesignRow row, String id) =>
      !row.any((b) => b.id != id && !isGapBlock(b));

  // ── Changing a block ──────────────────────────────────────────────

  /// Replace a block in place — every property-panel edit. Undoable: edits
  /// to the same field of the same block fold into one step (typing a word
  /// is one undo, not one per letter).
  void updateBlock(DesignBlock updated) {
    DesignBlock? previous;
    for (final b in blocks) {
      if (b.id == updated.id) previous = b;
    }
    if (previous == null) return;
    _applyBlocks([
      for (final b in blocks)
        if (b.id == updated.id) updated else b,
    ], coalesce: _blockChangeKey(previous, updated));
  }

  /// Remove a block. In a row it shared, a gap takes its place so nothing
  /// else moves. Returns what [restoreDeleted] needs to put it back, or null
  /// when [id] is not on the page.
  DeletedBlock? deleteBlock(String id) {
    final current = rows;
    final at = locateBlock(current, id);
    if (at == null) return null;
    final before = draft.template;
    if (id == _selectedBlockId) _selectedBlockId = null;
    _commitRows(withoutBlock(current, id, newId: _newId));
    return DeletedBlock._(
      block: current[at.row][at.index],
      rowIndex: at.row,
      before: before,
      after: draft.template,
    );
  }

  /// Put a deleted block back — the Undo of a delete's toast. Exactly where
  /// it was when nothing has changed since; otherwise as a row of its own at
  /// the place its row had. No-op when it is on the page again.
  void restoreDeleted(DeletedBlock deleted) {
    final block = deleted.block;
    if (blocks.any((b) => b.id == block.id)) return;
    _selectedBlockId = block.id;
    _templateEpoch++;
    if (draft.template == deleted.after) {
      _apply(deleted.before);
      return;
    }
    final current = rows;
    _commitRows(
      withNewRow(current, deleted.rowIndex.clamp(0, current.length), block),
    );
  }

  /// Copy a block into a new row directly below, at the same place across
  /// the row and the same width.
  void duplicateBlock(String id) {
    final current = rows;
    final at = locateBlock(current, id);
    // Called with whatever is selected; nothing to copy is nothing to do.
    if (at == null) return;
    final src = current[at.row][at.index];
    final clone = src.copyWith(
      id: newBlockId(src.type),
      properties: Map<String, dynamic>.from(src.properties),
      locked: false,
    );
    final cells = explicitRow(current[at.row], _newId);
    final copyRow = packRow([
      for (final c in cells)
        if (c.id == id) clone else newGapBlock(c.gridPosition.w, _newId),
    ]);
    _selectedBlockId = clone.id;
    _commitRows(List<DesignRow>.of(current)..insert(at.row + 1, copyRow));
  }

  // ── Moving ────────────────────────────────────────────────────────

  /// Move block [id] into a row of its own at [rowIndex] — an index into
  /// the rows as they are now (0 = above everything).
  void moveBlockToNewRow(String id, int rowIndex) {
    final current = rows;
    final from = locateBlock(current, id);
    if (from == null) return;
    final alone = _isAlone(current[from.row], id);
    if (alone && (rowIndex == from.row || rowIndex == from.row + 1)) return;
    final block = current[from.row][from.index];
    final without = withoutBlock(current, id, newId: _newId);
    // Its own row went with it: everything below moved up one.
    final target = alone && rowIndex > from.row ? rowIndex - 1 : rowIndex;
    _commitRows(withNewRow(without, target, block));
  }

  /// Move block [id] beside block [anchorId]. False when the row has no room.
  bool moveBlockBeside(String id, String anchorId, {required bool before}) {
    if (id == anchorId) return false;
    final current = rows;
    final from = locateBlock(current, id);
    if (from == null) return false;
    final target = locateBlock(current, anchorId);
    if (target == null) return false;
    final block = _asJoining(
      current[from.row][from.index],
      wasAlone: _isAlone(current[from.row], id),
      neighbours: _solidCount(current[target.row], except: id),
    );
    final next = _withBlockBeside(
      withoutBlock(current, id, newId: _newId),
      block,
      anchorId,
      before: before,
    );
    if (next == null) return false;
    _commitRows(next);
    return true;
  }

  /// Move row [from] so it ends up at index [to].
  void moveRow(int from, int to) {
    if (from == to) return;
    _commitRows(withRowMoved(rows, from, to));
  }

  /// Move block [id] up ([delta] −1) or down (+1). A block with a row to
  /// itself trades places with the neighbouring row; one that shares its row
  /// steps out into a row of its own on that side.
  void moveBlockVertically(String id, int delta) {
    final current = rows;
    final at = locateBlock(current, id);
    if (at == null || delta == 0) return;
    if (_isAlone(current[at.row], id)) {
      final to = at.row + delta.sign;
      if (to < 0 || to >= current.length) return;
      moveRow(at.row, to);
    } else {
      moveBlockToNewRow(id, delta < 0 ? at.row : at.row + 1);
    }
  }

  /// Move block [id] into the row above ([delta] −1) or below (+1), at its
  /// end. False when there is no such row or no room in it.
  bool joinNeighbourRow(String id, int delta) {
    final current = rows;
    final at = locateBlock(current, id);
    if (at == null) return false;
    final to = at.row + delta.sign;
    if (to < 0 || to >= current.length) return false;
    final anchor = current[to].lastWhere(
      (b) => !isGapBlock(b),
      orElse: () => current[to].last,
    );
    return moveBlockBeside(id, anchor.id, before: false);
  }

  /// Trade places with the cell to the left ([delta] −1) or right (+1) —
  /// another block, or empty space.
  void moveBlockWithinRow(String id, int delta) {
    final current = rows;
    final at = locateBlock(current, id);
    if (at == null) return;
    final cells = explicitRow(current[at.row], _newId);
    final i = cells.indexWhere((c) => c.id == id);
    final j = i + delta.sign;
    if (i < 0 || j < 0 || j >= cells.length) return;
    final swapped = List<DesignBlock>.of(cells);
    final tmp = swapped[i];
    swapped[i] = swapped[j];
    swapped[j] = tmp;
    _commitRows(List<DesignRow>.of(current)..[at.row] = packRow(swapped));
  }

  /// Put the one block of a row at its left, centre or right.
  void positionBlock(String id, RowPosition position) =>
      _commitRows(withBlockPositioned(rows, id, position, newId: _newId));

  // ── Widths ────────────────────────────────────────────────────────

  /// Move one edge of row [rowIndex] by [deltaCols] from where it was when
  /// the gesture began ([beginGesture]) — so the drag can be replayed from
  /// its start on every frame rather than accumulated. See
  /// [withBoundaryMoved] for how [boundary] is counted.
  void dragBoundary(int rowIndex, int boundary, int deltaCols) {
    final start = _gestureStart;
    if (start == null || !_inGesture) return;
    final startRows = rowsOf(start.blocks);
    final moved = deltaCols == 0
        ? startRows
        : withBoundaryMoved(
            startRows,
            rowIndex,
            boundary,
            deltaCols,
            minWidthOf: minWidthOf,
            newId: _newId,
          );
    if (identical(moved, startRows)) {
      // Nothing moved: back to *exactly* where the gesture began. Committing
      // the unchanged rows instead would re-sort and re-number them, which on
      // a design stored out of order is a change — a do-nothing undo step and
      // a design that reads as edited.
      _apply(start);
      return;
    }
    _commitRows(moved);
  }

  /// Make block [id] one column wider ([delta] +1) or narrower (−1) — at its
  /// right edge, or its left one when the right has nothing left to give.
  void nudgeWidth(String id, int delta) {
    final current = rows;
    final at = locateBlock(current, id);
    if (at == null || delta == 0) return;
    final cells = explicitRow(current[at.row], _newId);
    final i = cells.indexWhere((c) => c.id == id);
    if (i < 0) return;
    final staged = List<DesignRow>.of(current)..[at.row] = cells;
    List<DesignRow> move(int boundary, int by) => withBoundaryMoved(
      staged,
      at.row,
      boundary,
      by,
      minWidthOf: minWidthOf,
      newId: _newId,
    );
    final before = cells[i].gridPosition.w;
    var next = move(i + 1, delta.sign);
    if (_widthOf(next[at.row], id) == before) next = move(i, -delta.sign);
    if (_widthOf(next[at.row], id) == before) return;
    _commitRows(next, coalesce: '$id|width');
  }

  static int _widthOf(DesignRow row, String id) {
    for (final b in row) {
      if (b.id == id) return b.gridPosition.w;
    }
    return -1;
  }

  /// Swap every block on the page for [layout] — a starter picked from the
  /// gallery. The page settings and the name are kept; one undo step.
  void replaceLayout(List<DesignBlock> layout) {
    _selectedBlockId = null;
    _templateEpoch++;
    _commitRows(rowsOf(layout));
  }

  // ── Whole rows ────────────────────────────────────────────────────

  /// Close up the empty space in row [rowIndex], sharing it between its
  /// blocks.
  void removeGaps(int rowIndex) =>
      _commitRows(withoutGaps(rows, rowIndex, newId: _newId));

  void duplicateRow(int rowIndex) {
    final current = rows;
    if (rowIndex < 0 || rowIndex >= current.length) return;
    final copy = [
      for (final b in current[rowIndex])
        b.copyWith(
          id: newBlockId(b.type),
          properties: Map<String, dynamic>.from(b.properties),
          locked: false,
        ),
    ];
    _commitRows(List<DesignRow>.of(current)..insert(rowIndex + 1, copy));
  }

  void deleteRow(int rowIndex) {
    final current = rows;
    if (rowIndex < 0 || rowIndex >= current.length) return;
    if (current[rowIndex].any((b) => b.id == _selectedBlockId)) {
      _selectedBlockId = null;
    }
    _commitRows(List<DesignRow>.of(current)..removeAt(rowIndex));
  }

  // ── Selection by direction ────────────────────────────────────────

  /// Select the block next to the selected one: [dx] steps along its row,
  /// [dy] to the row above or below (the block nearest across). With nothing
  /// selected, the first block.
  void selectNeighbour({int dx = 0, int dy = 0}) {
    final current = [
      for (final row in rows)
        [
          for (final b in row)
            if (!isGapBlock(b)) b,
        ],
    ].where((r) => r.isNotEmpty).toList();
    if (current.isEmpty) return;
    final selected = _selectedBlockId;
    final at = selected == null ? null : locateBlock(current, selected);
    if (at == null) {
      selectBlock(current.first.first.id);
      return;
    }
    if (dx != 0) {
      final i = at.index + dx.sign;
      if (i >= 0 && i < current[at.row].length) {
        selectBlock(current[at.row][i].id);
      }
      return;
    }
    final r = at.row + dy.sign;
    if (dy == 0 || r < 0 || r >= current.length) return;
    final from = current[at.row][at.index].gridPosition;
    final centre = from.x + from.w / 2;
    DesignBlock? best;
    var bestDistance = double.infinity;
    for (final b in current[r]) {
      final p = b.gridPosition;
      final d = (p.x + p.w / 2 - centre).abs();
      if (d < bestDistance) {
        best = b;
        bestDistance = d;
      }
    }
    if (best != null) selectBlock(best.id);
  }

  // ── Gestures ──────────────────────────────────────────────────────

  /// Start of a drag. The whole gesture is one undo step — taken when it
  /// first changes something, so a press that moves nothing costs neither an
  /// undo step nor the redo tail.
  ///
  /// Always starts afresh. A drag whose handle was unmounted mid-gesture
  /// never reports its end (a disposed recognizer fires neither `onEnd` nor
  /// `onCancel`); were its start kept, the next drag would replay from it and
  /// revert everything done in between.
  void beginGesture() {
    _gestureStart = draft.template;
    _gestureRecorded = false;
    _inGesture = true;
    _undoKey = null;
  }

  /// End of the drag [beginGesture] opened. One that ended where it began
  /// leaves no undo step behind. Safe to call when no drag is open.
  void endGesture() {
    if (!_inGesture) return;
    _inGesture = false;
    if (_gestureRecorded && draft.template == _gestureStart) {
      _history.discardLast();
    }
    _gestureRecorded = false;
    _gestureStart = null;
  }

  // ── Undo / redo ───────────────────────────────────────────────────

  void undo() {
    _settle();
    _restore(_history.undo(draft.template));
  }

  void redo() {
    _settle();
    _restore(_history.redo(draft.template));
  }

  /// Before stepping through history: close any drag, and commit what an
  /// editor is still holding in its debounce — otherwise it lands *after*
  /// the step, on top of the state just restored.
  void _settle() {
    endGesture();
    flushPendingEdits();
  }

  void _restore(DesignTemplate? template) {
    if (template == null) return;
    _undoKey = null;
    _templateEpoch++;
    // Keep the selection when its block survived: undoing a move must not
    // throw the property panel back to the page settings.
    final selected = _selectedBlockId;
    if (selected != null && !template.blocks.any((b) => b.id == selected)) {
      _selectedBlockId = null;
    }
    updateDraft(draft.copyWith(template: template));
  }

  // ── Document settings ─────────────────────────────────────────────

  void setDocumentSettings(DocumentSettings next) {
    final before = documentSettings.toApi().toJson();
    final after = next.toApi().toJson();
    final changed = [
      for (final key in after.keys)
        if ('${after[key]}' != '${before[key]}') key,
    ];
    _apply(
      draft.template.copyWith(documentSettings: next),
      coalesce: 'page|${changed.join(',')}',
    );
  }

  /// Extra CSS the server appends to the document (`design.customCss`). Not a
  /// field of this app's model — it lives among the template's carried
  /// fields — but the server honours it, so the page settings can edit it.
  String get customCss => (draft.template.extra['customCss'] as String?) ?? '';

  void setCustomCss(String css) {
    final extra = Map<String, dynamic>.from(draft.template.extra);
    if (css.trim().isEmpty) {
      extra.remove('customCss');
    } else {
      extra['customCss'] = css;
    }
    _apply(draft.template.copyWith(extra: extra), coalesce: 'page|customCss');
  }

  // ── Name / entities ───────────────────────────────────────────────

  void setName(String v) => updateDraft(draft.copyWith(name: v));

  void setEntities(List<String> v) => updateDraft(draft.copyWith(entities: v));

  /// Tick or untick a document type. The last one cannot be unticked — a
  /// design that applies to nothing is offered nowhere.
  void toggleEntity(String entity) {
    final current = draft.entities;
    if (current.contains(entity)) {
      if (current.length == 1) return;
      setEntities([
        for (final e in current)
          if (e != entity) e,
      ]);
    } else {
      // In the usual order — and keeping any type this control does not
      // offer that the design already carried.
      setEntities([
        for (final e in defaultEntities)
          if (e == entity || current.contains(e)) e,
        for (final e in current)
          if (!defaultEntities.contains(e)) e,
      ]);
    }
  }

  /// Seed the draft from another design (e.g. duplicate a built-in).
  /// Keeps the WYSIWYG-specific selection / panel-mode cleared.
  void loadFrom(Design source) {
    _selectedBlockId = null;
    _undoKey = null;
    updateDraft(source.copyWith(id: '', name: source.name));
  }

  /// Phase 8k: replace the current draft's `blocks` + `documentSettings`
  /// from a JSON payload produced by [DesignPayload.toApiJson]. Mirrors
  /// React `InvoiceBuilder.tsx` Import JSON. Returns an i18n key on
  /// failure or `null` on success. Keeps the current id so Save still
  /// targets this draft. One undo step, like any other change.
  String? importFromJson(String raw) {
    final template = designTemplateFromJson(raw);
    if (template == null) return 'invalid_json';
    _selectedBlockId = null;
    _templateEpoch++;
    _apply(template);
    return null;
  }

  /// Throw away what has not been saved — the unsaved-changes guard's
  /// Discard. Back to the last save when there has been one; otherwise to
  /// the design as opened, or for a new design to a blank one (optionally
  /// re-seeding its page settings from the company's).
  ///
  /// Not always "to empty", though the name is older than that: the route can
  /// outlive a Discard (leaving by the sidebar keeps it mounted), and going
  /// back to what was *opened* after a save showed a design the server no
  /// longer had — and for a new design left a blank form still pointed at the
  /// saved record, which its next Save overwrote.
  void resetToEmpty([CompanySettings? companySettings]) {
    _selectedBlockId = null;
    _undoKey = null;
    _inGesture = false;
    _gestureRecorded = false;
    _gestureStart = null;
    _history.clear();
    _templateEpoch++;
    final saved = _lastSaved;
    reset(
      emptyDraft: _seed(
        null,
        null,
        '',
        companySettings ?? this.companySettings,
      ),
    );
    if (saved != null) updateDraft(saved);
  }

  // ── helpers ───────────────────────────────────────────────────────

  void _applyBlocks(List<DesignBlock> next, {String? coalesce}) =>
      _apply(draft.template.copyWith(blocks: next), coalesce: coalesce);

  /// The one place the template changes. Snapshots the state being replaced
  /// so it can be undone, except mid-gesture (the gesture already did) and
  /// when [coalesce] names the same thing the previous change edited — a
  /// change with no [coalesce] always gets its own step. The selection is
  /// whatever the caller set before calling.
  void _apply(DesignTemplate next, {String? coalesce}) {
    if (next == draft.template) {
      notifyListeners();
      return;
    }
    if (_inGesture) {
      // The gesture's one step, taken on its first real change.
      if (!_gestureRecorded) {
        _history.record(_gestureStart ?? draft.template);
        _gestureRecorded = true;
      }
    } else {
      if (coalesce == null || coalesce != _undoKey) {
        _history.record(draft.template);
      }
      _undoKey = coalesce;
    }
    updateDraft(draft.copyWith(template: next));
  }

  /// Names what differs between two versions of one block, so repeated edits
  /// of the same thing fold into one undo step — and edits of different
  /// things do not.
  ///
  /// "The same thing" goes one level into a list: a table's columns, an info
  /// block's fields and a totals block's rows are each stored as one list,
  /// and keying on the property alone made renaming two headers, setting
  /// three widths and deleting a column a single undo step. An element's own
  /// field is named (`columns[2].header`); a list that changed length or
  /// order is structural and never folds with anything.
  String _blockChangeKey(DesignBlock before, DesignBlock after) {
    final parts = <String>[after.id];
    if (before.gridPosition != after.gridPosition) parts.add('position');
    if (before.locked != after.locked) parts.add('locked');
    final keys = {...before.properties.keys, ...after.properties.keys};
    for (final key in keys) {
      final a = before.properties[key];
      final b = after.properties[key];
      if (_sameValue(a, b)) continue;
      parts.add('$key${_changedWithin(a, b)}');
    }
    return parts.join('|');
  }

  int _structuralEdits = 0;

  /// Where inside a list (or map) property the change is — `[2].header`,
  /// `.color` — or a suffix unique to this edit when it is not one element's
  /// field that changed.
  String _changedWithin(Object? a, Object? b) {
    if (a is Map && b is Map) {
      final changed = [
        for (final k in {...a.keys, ...b.keys})
          if (!_sameValue(a[k], b[k])) k,
      ];
      return changed.length == 1 ? '.${changed.single}' : '';
    }
    if (a is! List || b is! List) return '';
    if (a.length != b.length) return '#${_structuralEdits++}';
    final at = [
      for (var i = 0; i < a.length; i++)
        if (!_sameValue(a[i], b[i])) i,
    ];
    if (at.length != 1) return '#${_structuralEdits++}';
    final i = at.single;
    return '[$i]${_changedWithin(a[i], b[i])}';
  }

  static bool _sameValue(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is String || a is num || a is bool || a == null) return a == b;
    return jsonEncode(a) == jsonEncode(b);
  }
}

enum PropertyPanelMode { block, document }

/// What [WysiwygDesignViewModel.deleteBlock] removed, for
/// [WysiwygDesignViewModel.restoreDeleted].
class DeletedBlock {
  const DeletedBlock._({
    required this.block,
    required this.rowIndex,
    required this.before,
    required this.after,
  });

  final DesignBlock block;
  final int rowIndex;
  final DesignTemplate before;
  final DesignTemplate after;
}

Design _emptyDesign() => Design(
  id: '',
  name: '',
  isCustom: true,
  isActive: true,
  isTemplate: false,
  isFree: false,
  entities: WysiwygDesignViewModel.defaultEntities,
  template: const DesignTemplate(),
  updatedAt: DateTime(2000),
  createdAt: DateTime(2000),
  archivedAt: null,
  isDeleted: false,
);

/// The template in a pasted design — the full `Design.toApiJson()` envelope
/// or a bare template map (`{blocks, documentSettings, body, …}`) — or null
/// when [raw] is not one.
///
/// "A design" means it has at least one of a template's sections: any JSON
/// object parses to a template of nothing, and importing `{"name": "x"}`
/// used to wipe the page, say "Imported", and park `name` among the fields
/// sent back to the server. A block with no id, or one that repeats, is
/// given a fresh one: two blocks that cannot be told apart cannot be
/// selected, moved or deleted apart.
DesignTemplate? designTemplateFromJson(String raw) {
  final Object? parsed;
  try {
    parsed = jsonDecode(raw);
  } catch (_) {
    return null;
  }
  if (parsed is! Map) return null;
  final map = parsed.cast<String, dynamic>();
  try {
    final inner = map['design'];
    final source = inner is Map ? inner.cast<String, dynamic>() : map;
    const sections = ['blocks', 'body', 'header', 'footer', 'includes'];
    if (!sections.any(source.containsKey)) return null;
    final template = DesignTemplate.fromApi(DesignTemplateApi.fromJson(source));
    final seen = <String>{};
    return template.copyWith(
      blocks: [
        for (final b in template.blocks)
          b.id.isEmpty || !seen.add(b.id)
              ? b.copyWith(id: newBlockId(b.type))
              : b,
      ],
    );
  } catch (_) {
    return null;
  }
}
