import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_edit_scaffold.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/save_failed_banner.dart';
import 'package:admin/ui/core/widgets/sync_first_banner.dart';

/// Outer scaffold for every entity edit / create screen.
///
/// Wraps [EntityEditScaffold] with the boilerplate every concrete edit
/// screen needs:
///
///   * VM lifecycle — sync construction for `create`, async fetch + ctor
///     for `edit`. The "Loading…" placeholder Scaffold while the existing
///     row is being read.
///   * Dead-outbox-row 422 recovery — on load, look up the newest `dead`
///     row for this entity and hydrate its `fieldErrorsJson` onto the VM
///     so the form opens pre-flagged. On a successful save, delete the
///     prior dead row so the Outbox screen does not keep showing the
///     stale failure. On a fresh 422, re-link to the new dead row so the
///     SaveFailedBanner's Discard targets the *fresh* failure.
///   * The SaveFailedBanner wired into `topBanner` (renders nothing when
///     `vm.fieldErrors` is empty, so always safe to pass).
///
/// Per-entity screens become ~30 lines: a single
/// `EntityEditScreenScaffold<T, VM>(...)` invocation with builders that
/// know how to construct the VM, fetch the existing row, render the form,
/// and navigate after save.
class EntityEditScreenScaffold<T, VM extends GenericEditViewModel<T>>
    extends StatefulWidget {
  const EntityEditScreenScaffold({
    super.key,
    required this.existingId,
    required this.entityTypeName,
    required this.fetchExisting,
    required this.buildVm,
    required this.titleBuilder,
    required this.titleWhileLoading,
    required this.bodyBuilder,
    required this.resetToEmpty,
    required this.onSaved,
    required this.entityIdOf,
    this.canSave,
    this.embedded = false,
    this.actionsBuilder,
    this.saveParamFor,
    this.onAfterSaveAction,
    this.onAfterSaveActionOnCreate,
  });

  /// Existing entity id when editing; null for create.
  final String? existingId;

  /// Outbox wire name for this entity (e.g. `'client'`, `'product'`).
  /// Used to scope the dead-row lookup.
  final String entityTypeName;

  /// Read the existing row once so the VM can be seeded. Called only when
  /// [existingId] is non-null. Reading once (not subscribing) matches the
  /// edit-screen semantics: the form snapshots the row, then owns the
  /// draft until save.
  final Future<T?> Function(
    BuildContext context,
    Services services,
    String companyId,
    String id,
  )
  fetchExisting;

  /// Construct the VM. `existing` is non-null when editing, null when
  /// creating.
  final VM Function(
    BuildContext context,
    Services services,
    String companyId,
    T? existing,
  )
  buildVm;

  /// AppBar title once the VM is ready.
  final String Function(BuildContext context, VM vm) titleBuilder;

  /// AppBar title while the existing row is being fetched.
  final String Function(BuildContext context) titleWhileLoading;

  final Widget Function(BuildContext context, VM vm) bodyBuilder;

  /// Called by the discard guard. Typically `(vm) => vm.resetToEmpty()`.
  final void Function(VM vm) resetToEmpty;

  /// Invoked after a successful save and after dead-row cleanup. Caller
  /// decides whether to pop or go to a detail route.
  final FutureOr<void> Function(BuildContext context, VM vm, T saved) onSaved;

  /// Optional Save-button gate. Defaults to `!vm.isSaving`.
  final bool Function(VM vm)? canSave;

  /// Read the entity id from a draft. Every entity has an `id` field but
  /// the generic [T] does not advertise that, so the caller supplies the
  /// accessor (typically `(c) => c.id`). Used to look up the dead outbox
  /// row that holds prior 422 errors.
  final String Function(T draft) entityIdOf;

  /// When `true`, the underlying [EntityEditScaffold] renders without
  /// its own `Scaffold` / `AppBar` — the host shell (typically
  /// `MasterDetailLayout` on wide desktop) owns the chrome.
  final bool embedded;

  /// Builds the right-aligned, overflow-aware header action cluster.
  /// Receives the live VM so the per-entity closure can read `vm.draft` /
  /// `vm.isCreate` (e.g. to apply `filterForEditScreen`). Returns an
  /// `EntityOverflowActionBar<A>` with the plain [saveButton] forwarded as
  /// its `leading:` child; wire each item's `onTap` to the type-erased
  /// sink. Null => no action bar.
  final Widget Function(
    BuildContext context,
    VM vm,
    void Function(Object action) onTap,
    Widget saveButton,
  )?
  actionsBuilder;

  /// Per-entity SAVE-PARAM classifier (typically `<E>Actions.saveParamFor`
  /// composed with the action-enum cast). Null => all actions after-save.
  final Map<String, String>? Function(Object action)? saveParamFor;

  /// Per-entity AFTER-SAVE dispatcher (typically
  /// `(ctx, saved, a) => InvoiceActions.dispatch(ctx, services,
  /// companyId, saved, a as InvoiceAction)`).
  final Future<void> Function(BuildContext context, T saved, Object action)?
  onAfterSaveAction;

  /// Per-entity CREATE-mode AFTER-SAVE dispatcher (typically
  /// `(ctx, saved, a) => dispatchAfterSaveOnCreate<E, EAction>(...)`). Forwarded
  /// to [EntityEditScaffold.onAfterSaveActionOnCreate]; see that field for the
  /// tmp-id-resolution + navigation-ownership contract. Null for entities with
  /// no navigating after-save actions.
  final Future<bool> Function(BuildContext context, T saved, Object action)?
  onAfterSaveActionOnCreate;

  @override
  State<EntityEditScreenScaffold<T, VM>> createState() =>
      _EntityEditScreenScaffoldState<T, VM>();
}

class _EntityEditScreenScaffoldState<T, VM extends GenericEditViewModel<T>>
    extends State<EntityEditScreenScaffold<T, VM>> {
  VM? _vm;
  bool _ready = false;
  bool _bootstrapped = false;
  bool _notFound = false;
  late final String _companyId;

  // Bootstrap runs in didChangeDependencies (not initState) so the
  // create-mode `buildVm` closure may legally read inherited widgets —
  // e.g. InvoiceEditScreen's `buildVm` calls `ctx.tr(...)`, which
  // registers a Localizations dependency and asserts if done in initState.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) return;
    _bootstrapped = true;
    final services = context.read<Services>();
    _companyId = services.auth.session.value!.currentCompanyId;
    if (widget.existingId == null) {
      setState(() {
        _vm = widget.buildVm(context, services, _companyId, null);
        _ready = true;
      });
    } else {
      _load(services, _companyId, widget.existingId!);
    }
  }

  Future<void> _load(
    Services services,
    String companyId,
    String existingId,
  ) async {
    final existing = await widget.fetchExisting(
      context,
      services,
      companyId,
      existingId,
    );
    if (!mounted) return;
    if (existing == null) {
      // The URL names a row that isn't in local Drift (restored deep link
      // after a DB reset, stale link, row deleted elsewhere). Building the
      // VM with null would silently open CREATE mode — a blank "New …" form
      // at an /edit URL whose save mints a duplicate record instead of
      // updating the one the user meant. Mirror SettingsEntityEditScaffold:
      // show not-found.
      setState(() {
        _notFound = true;
        _ready = true;
      });
      return;
    }
    final vm = widget.buildVm(context, services, companyId, existing);
    setState(() {
      _vm = vm;
      _ready = true;
    });
    await _hydrateFailedSync(services, companyId, existingId);
  }

  /// Replay a prior 422 onto the VM. Reads the newest dead outbox row for
  /// this entity (if any) and pushes its `field_errors_json` onto the VM
  /// so the form opens pre-flagged. No-op when nothing on disk or when
  /// the field-errors blob fails to decode.
  Future<void> _hydrateFailedSync(
    Services services,
    String companyId,
    String entityId,
  ) async {
    final row = await services.db.outboxDao.findDeadForEntity(
      companyId: companyId,
      entityType: widget.entityTypeName,
      entityId: entityId,
    );
    if (row == null || _vm == null || !mounted) return;
    final raw = row.fieldErrorsJson;
    if (raw == null || raw.isEmpty) return;
    Map<String, List<String>> errors;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      errors = decoded.map(
        (k, v) => MapEntry(
          k,
          (v as List).map((e) => e.toString()).toList(growable: false),
        ),
      );
    } catch (_) {
      return;
    }
    if (errors.isEmpty) return;
    // Pass the dead row's entityId so the VM can stash it as recoveryTempId
    // when it's a tmp_ id — the next Save then reuses that tmp id and
    // dedupPendingMutations replaces the prior dead/pending row instead of
    // creating a duplicate.
    _vm!.applyFailedSync(rowId: row.id, errors: errors, entityId: row.entityId);
  }

  /// Resolve the dead row id for the current entity. Prefers the VM's
  /// cached id; falls back to a dao lookup so the right row is targeted
  /// even when a 422 landed after the form opened but before the VM
  /// learned its id.
  Future<int?> _resolveDeadRowId(Services services, VM vm) async {
    final cached = vm.deadOutboxRowId;
    if (cached != null) return cached;
    final entityId = widget.existingId;
    if (entityId == null) return null;
    final row = await services.db.outboxDao.findDeadForEntity(
      companyId: _companyId,
      entityType: widget.entityTypeName,
      entityId: entityId,
    );
    return row?.id;
  }

  /// Delete a prior 422's `dead` outbox row after a successful re-save (its
  /// payload is now stale) and clear the VM's failed-sync link. Shared by the
  /// plain-Save `onSaved` path and the edit-mode after-save `onSaveCleanup`
  /// path so both consume the dead row.
  Future<void> _cleanupPriorDeadRow(Services services, VM vm) async {
    final priorDeadId = await _resolveDeadRowId(services, vm);
    if (priorDeadId != null) {
      await services.db.outboxDao.deleteRow(priorDeadId);
      vm.clearFailedSync();
    }
  }

  Future<void> _discardFailedSync(VM vm) async {
    final services = context.read<Services>();
    final rowId = await _resolveDeadRowId(services, vm);
    if (rowId == null) {
      vm.clearFailedSync();
      return;
    }
    final removedLocal = await services.sync.discardOutboxRow(rowId);
    vm.clearFailedSync();
    // A never-synced offline create just had its local record hard-deleted —
    // this screen now points at an entity that no longer exists. Leave it.
    // Embedded mode has no route of its own to pop.
    if (removedLocal && !widget.embedded && mounted && context.canPop()) {
      context.pop();
    }
  }

  @override
  void dispose() {
    _vm?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_notFound) {
      final body = EmptyState(
        icon: Icons.search_off_outlined,
        title: context.tr('not_found'),
      );
      if (widget.embedded) return body;
      return Scaffold(
        appBar: AppBar(title: Text(widget.titleWhileLoading(context))),
        body: body,
      );
    }
    if (!_ready || _vm == null) {
      // Embedded mode skips the Scaffold even on the loading state so
      // the parent shell's chrome doesn't briefly disappear before the
      // form renders.
      if (widget.embedded) {
        return const Center(child: CircularProgressIndicator());
      }
      return Scaffold(
        appBar: AppBar(title: Text(widget.titleWhileLoading(context))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final vm = _vm!;
    // Rebuild the whole scaffold when the VM notifies. `canSave` (below) and
    // `EntityEditScaffold`'s `PopScope.canPop` are both plain values read at
    // build time; this State has no other listener on the VM, so without this
    // they froze at their first-ready value. That left Save permanently
    // disabled on every screen whose `canSave` depends on `vm.isDirty`
    // (Expense Category and Payment Link could not be created OR edited at
    // all), and made the back-swipe / predictive-back discard guard dead code.
    // The sibling settings scaffolds already do exactly this.
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) => _scaffold(context, vm),
    );
  }

  Widget _scaffold(BuildContext context, VM vm) {
    final canSave = widget.canSave?.call(vm) ?? !vm.isSaving;
    return EntityEditScaffold<T>(
      vm: vm,
      canSave: canSave,
      embedded: widget.embedded,
      actionsBuilder: widget.actionsBuilder == null
          ? null
          : (ctx, onTap, saveButton) =>
                widget.actionsBuilder!(ctx, vm, onTap, saveButton),
      saveParamFor: widget.saveParamFor,
      onAfterSaveAction: widget.onAfterSaveAction,
      onAfterSaveActionOnCreate: widget.onAfterSaveActionOnCreate,
      titleBuilder: (ctx) => widget.titleBuilder(ctx, vm),
      bodyBuilder: (ctx) => widget.bodyBuilder(ctx, vm),
      topBanner: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Persistent "this record hasn't synced" strip when editing an
          // offline-created (`tmp_`) record — renders nothing otherwise.
          SyncFirstBanner(entityId: widget.existingId),
          SaveFailedBanner(vm: vm, onDiscard: () => _discardFailedSync(vm)),
        ],
      ),
      resetToEmpty: () => widget.resetToEmpty(vm),
      onSaveRejected: () async {
        // Fresh 422 landed — re-link to the new dead row so a subsequent
        // Discard tap targets *this* failure, not the prior cached id.
        final services = context.read<Services>();
        await _hydrateFailedSync(
          services,
          _companyId,
          widget.entityIdOf(vm.draft),
        );
      },
      onSaved: (ctx, saved) async {
        // A fresh save queued a new outbox row; the prior dead row's
        // payload is stale. Delete it so the Outbox screen doesn't keep
        // showing the failure indefinitely.
        await _cleanupPriorDeadRow(ctx.read<Services>(), vm);
        if (!ctx.mounted) return;
        await widget.onSaved(ctx, vm, saved);
      },
      // The edit-mode after-save action path bypasses onSaved (the action owns
      // navigation), so run the same dead-row cleanup there too.
      onSaveCleanup: () => _cleanupPriorDeadRow(context.read<Services>(), vm),
    );
  }
}
