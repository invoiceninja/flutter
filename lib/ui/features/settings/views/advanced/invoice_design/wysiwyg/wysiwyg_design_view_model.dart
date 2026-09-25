import 'dart:convert';

import 'package:admin/data/models/api/design_api_model.dart'
    show DesignTemplateApi;
import 'package:admin/data/models/domain/company_settings.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/models/domain/design_block_layout.dart'
    show kDesignerGridCols;
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/design_repository.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_library.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/grid/grid_model.dart';
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
    CompanySettings? companySettings,
    super.sync,
    super.connectivity,
  }) : super(
         initialDraft: _seed(existing, companySettings),
         original: existing,
         companyId: companyId,
       );

  final DesignRepository repo;
  final String companyId;

  /// Build the initial draft. For a brand-new design (no `existing`), seed
  /// `template.documentSettings` from the active company's settings —
  /// matching React's `createDefaultDocumentSettings(companySettings)`.
  /// Otherwise users get fixed defaults (portrait / A4 / Roboto / 16 px)
  /// that won't match what the React app would produce for the same
  /// company.
  static Design _seed(Design? existing, CompanySettings? companySettings) {
    if (existing != null) return existing;
    final draft = _emptyDesign();
    if (companySettings == null) return draft;
    return draft.copyWith(
      template: draft.template.copyWith(
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

  /// Undo/redo over structural mutations only — property-panel text edits
  /// don't snapshot (matches React `useBuilderHistory.ts`). Snapshot is
  /// taken BEFORE the mutation is applied so [undo] reverts to the prior
  /// state. Cleared on [resetToEmpty] so a discarded draft doesn't carry
  /// stale history forward.
  final DesignerHistoryStack _history = DesignerHistoryStack();
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  PropertyPanelMode get panelMode => _selectedBlockId == null
      ? PropertyPanelMode.document
      : PropertyPanelMode.block;

  /// Live blocks list (read-only — mutate via the methods below).
  List<DesignBlock> get blocks => draft.template.blocks;

  /// Current document settings, seeded on first access if the design didn't
  /// have one yet. Mirrors React's `createDefaultDocumentSettings` defaults.
  DocumentSettings get documentSettings =>
      draft.template.documentSettings ?? const DocumentSettings();

  DesignBlock? get selectedBlock {
    final id = _selectedBlockId;
    if (id == null) return null;
    for (final b in blocks) {
      if (b.id == id) return b;
    }
    return null;
  }

  @override
  bool draftIsNonEmpty() {
    final d = draft;
    return d.name.isNotEmpty ||
        d.template.blocks.isNotEmpty ||
        d.template.body.isNotEmpty;
  }

  @override
  Future<SaveResult<Design>> performSave() async {
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

  void selectBlock(String? id) {
    if (_selectedBlockId == id) return;
    _selectedBlockId = id;
    notifyListeners();
  }

  // ── Mutations on the blocks list ───────────────────────────────────

  /// Append a new block from a palette spec at the next free grid slot.
  /// Used by the palette's tap-to-add and as a fallback when a drop
  /// coordinate isn't available.
  void addBlock(BlockSpec spec) {
    final slot = findFirstEmptySlot(
      blocks,
      spec.defaultWidth,
      spec.defaultHeight,
    );
    addBlockAt(spec, slot.x, slot.y);
  }

  /// Append a new block at the given grid coords. Caller clamps to grid
  /// bounds; we run [pushCollisionsDown] to resolve any overlap with
  /// existing blocks (so the new block lands at least at the requested x,
  /// possibly shifted down if it would overlap something).
  void addBlockAt(BlockSpec spec, int x, int y) {
    final clampedX = x.clamp(0, kDesignerGridCols - spec.defaultWidth);
    final clampedY = y < 0 ? 0 : y;
    final next = spec.newInstance(
      idPrefix: spec.type,
      x: clampedX,
      y: clampedY,
    );
    final resolved = pushCollisionsDown([...blocks, next]);
    _history.record(blocks);
    _replaceBlocksAndSelect(resolved, next.id);
  }

  /// Replace a block in-place (used by the property panel + drag/resize).
  /// Property-panel edits go through here but **do NOT snapshot history**
  /// — matches React `useBuilderHistory.ts`, which only records structural
  /// mutations. Drag/resize-end callers should explicitly call
  /// [recordHistorySnapshot] if they want the gesture as one undoable step.
  void updateBlock(DesignBlock updated) {
    final next = [
      for (final b in blocks)
        if (b.id == updated.id) updated else b,
    ];
    _replaceBlocks(next);
  }

  void deleteBlock(String id) {
    _history.record(blocks);
    final next = blocks.where((b) => b.id != id).toList(growable: false);
    if (id == _selectedBlockId) {
      _replaceBlocksAndSelect(next, null);
    } else {
      _replaceBlocks(next);
    }
  }

  void duplicateBlock(String id) {
    final src = blocks.firstWhere(
      (b) => b.id == id,
      orElse: () => throw StateError(
        'duplicateBlock: no block with id "$id" in the canvas',
      ),
    );
    final slot = findFirstEmptySlot(
      blocks,
      src.gridPosition.w,
      src.gridPosition.h,
    );
    final clone = DesignBlock(
      id: newBlockId(src.type),
      type: src.type,
      gridPosition: GridPosition(
        x: slot.x,
        y: slot.y,
        w: src.gridPosition.w,
        h: src.gridPosition.h,
      ),
      properties: Map<String, dynamic>.from(src.properties),
    );
    _history.record(blocks);
    _replaceBlocksAndSelect([...blocks, clone], clone.id);
  }

  void moveBlock(String id, GridPosition next) {
    final repositioned = [
      for (final b in blocks)
        if (b.id == id) b.copyWith(gridPosition: next) else b,
    ];
    _history.record(blocks);
    _replaceBlocks(pushCollisionsDown(repositioned));
  }

  void toggleLock(String id) {
    final next = [
      for (final b in blocks)
        if (b.id == id) b.copyWith(locked: !b.locked) else b,
    ];
    _history.record(blocks);
    _replaceBlocks(next);
  }

  /// Resize-driven collision resolver. Caller decides when to run (canvas
  /// drag handles call this on `onPanEnd`).
  void fixOverlaps() {
    _history.record(blocks);
    _replaceBlocks(pushCollisionsDown(blocks));
  }

  /// Mobile reorder mode (Step 6): rearrange blocks into a single
  /// full-width vertical stack. Each block becomes `gridPosition.x = 0,
  /// w = 12`, with `y` set by row order × the block's existing height.
  /// Going back to desktop preserves the new vertical order (and the
  /// freeform x/w can be re-edited there).
  void reorderBlocks(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= blocks.length) return;
    if (newIndex == oldIndex) return;
    final reordered = List<DesignBlock>.of(blocks);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);

    // Lay them out top-to-bottom, full width, stacking by height.
    var y = 0;
    final stacked = <DesignBlock>[
      for (final b in reordered)
        b.copyWith(
          gridPosition: GridPosition(x: 0, y: y, w: 12, h: b.gridPosition.h),
        ),
      // y for next block accumulates inside the for-loop via the closure
    ];
    // Re-walk to set y values (Dart for-in inside list literal doesn't
    // let us mutate y between iterations easily).
    final laid = <DesignBlock>[];
    y = 0;
    for (final b in stacked) {
      final h = b.gridPosition.h;
      laid.add(
        b.copyWith(
          gridPosition: GridPosition(x: 0, y: y, w: 12, h: h),
        ),
      );
      y += h;
    }

    _history.record(blocks);
    _replaceBlocks(laid);
  }

  /// Explicit history checkpoint for callers that mutate via [updateBlock]
  /// in a fast loop (e.g. drag gestures via the canvas) and want the whole
  /// gesture to count as one undoable step. Call **before** the first
  /// `updateBlock` of the gesture.
  void recordHistorySnapshot() {
    _history.record(blocks);
  }

  // ── Undo / redo ───────────────────────────────────────────────────

  void undo() {
    final previous = _history.undo(blocks);
    if (previous == null) return;
    _selectedBlockId = null;
    updateDraft(
      draft.copyWith(template: draft.template.copyWith(blocks: previous)),
    );
  }

  void redo() {
    final next = _history.redo(blocks);
    if (next == null) return;
    _selectedBlockId = null;
    updateDraft(
      draft.copyWith(template: draft.template.copyWith(blocks: next)),
    );
  }

  // ── Document settings ─────────────────────────────────────────────

  void setDocumentSettings(DocumentSettings next) {
    updateDraft(
      draft.copyWith(template: draft.template.copyWith(documentSettings: next)),
    );
  }

  // ── Name / entities ───────────────────────────────────────────────

  void setName(String v) => updateDraft(draft.copyWith(name: v));

  void setEntities(List<String> v) => updateDraft(draft.copyWith(entities: v));

  /// Seed the draft from another design (e.g. duplicate a built-in).
  /// Keeps the WYSIWYG-specific selection / panel-mode cleared.
  void loadFrom(Design source) {
    _selectedBlockId = null;
    updateDraft(source.copyWith(id: '', name: source.name));
  }

  /// Phase 8k: replace the current draft's `blocks` + `documentSettings`
  /// from a JSON payload produced by [DesignPayload.toApiJson]. Mirrors
  /// React `InvoiceBuilder.tsx` Import JSON. Returns an i18n key on
  /// failure or `null` on success. Keeps the current id so Save still
  /// targets this draft.
  String? importFromJson(String raw) {
    final Object? parsed;
    try {
      parsed = jsonDecode(raw);
    } catch (_) {
      return 'invalid_json';
    }
    if (parsed is! Map) return 'invalid_json';
    final map = parsed.cast<String, dynamic>();
    try {
      // Accept both the full `Design.toApiJson()` envelope and a bare
      // template map (`{blocks, documentSettings, body, …}`).
      final designBlock = map['design'];
      final tmplSrc = designBlock is Map
          ? designBlock.cast<String, dynamic>()
          : map;
      final tmplApi = DesignTemplateApi.fromJson(tmplSrc);
      final template = DesignTemplate.fromApi(tmplApi);
      _selectedBlockId = null;
      _history.clear();
      updateDraft(draft.copyWith(template: template));
      return null;
    } catch (_) {
      return 'invalid_json';
    }
  }

  /// Clear the draft back to an empty design, optionally re-seeding the
  /// document settings from the active company. Used by the screen's
  /// unsaved-changes-guard discard flow.
  void resetToEmpty([CompanySettings? companySettings]) {
    _selectedBlockId = null;
    _history.clear();
    reset(emptyDraft: _seed(null, companySettings));
  }

  // ── helpers ───────────────────────────────────────────────────────

  /// Replace the blocks list, **preserving** the current selection. Used
  /// by [updateBlock] / [moveBlock] / [toggleLock] / [fixOverlaps] — the
  /// drag-time callers that depend on selection surviving across every
  /// frame's mutation (without that, the resize handles un-render mid-drag
  /// and the gesture dies).
  void _replaceBlocks(List<DesignBlock> next) {
    // updateDraft already calls notifyListeners; no second notify here.
    updateDraft(
      draft.copyWith(template: draft.template.copyWith(blocks: next)),
    );
  }

  /// Replace the blocks list AND set the selection to [newSelectionId]
  /// (pass null to deselect). Used by `addBlockAt` / `duplicateBlock` to
  /// auto-select the new block, and by `deleteBlock` when removing the
  /// currently-selected block.
  void _replaceBlocksAndSelect(List<DesignBlock> next, String? newSelectionId) {
    _selectedBlockId = newSelectionId;
    updateDraft(
      draft.copyWith(template: draft.template.copyWith(blocks: next)),
    );
  }
}

enum PropertyPanelMode { block, document }

Design _emptyDesign() => Design(
  id: '',
  name: '',
  isCustom: true,
  isActive: true,
  isTemplate: false,
  isFree: false,
  entities: const ['invoice'],
  template: const DesignTemplate(),
  updatedAt: DateTime(2000),
  createdAt: DateTime(2000),
  archivedAt: null,
  isDeleted: false,
);
