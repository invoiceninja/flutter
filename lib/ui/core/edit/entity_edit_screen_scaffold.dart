import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/dialogs/confirm_action_dialog.dart';
import 'package:admin/ui/core/edit/entity_edit_scaffold.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/sync/unconfirmed_change_actions.dart';
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
///   * Dead-outbox-row recovery — on load, look up the newest `dead` row for
///     this entity and hydrate its `fieldErrorsJson` + `lastError` onto the VM
///     so the form opens pre-flagged with a stated reason. On a successful
///     save, delete the prior dead row so the Outbox screen does not keep
///     showing the stale failure. On a fresh rejection, re-link to the new
///     dead row so the SaveFailedBanner's Discard / Retry target the *fresh*
///     failure.
///   * The SaveFailedBanner wired into `topBanner` (renders nothing when the
///     VM holds no rejection, so always safe to pass).
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
    this.confirmSaveParam,
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

  /// Confirmation for a SAVE-PARAM action, forwarded to [EntityEditScaffold].
  /// See its doc for why this is a hook rather than `EntityActionItem.confirm`.
  final Future<bool> Function(BuildContext context, Object action)?
  confirmSaveParam;

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
    if (!mounted || _vm == null) return;
    await hydrateUnconfirmed(
      services,
      companyId: companyId,
      entityType: widget.entityTypeName,
      entityId: existingId,
      vm: _vm!,
    );
  }

  /// Replay a prior rejection onto the VM. Reads the newest dead outbox row
  /// for this entity (if any) and pushes its `field_errors_json` **and** its
  /// `last_error` / `last_status_code` onto the VM so the form opens
  /// pre-flagged with a stated reason.
  ///
  /// It used to bail whenever `field_errors_json` was absent, i.e. for every
  /// non-422 rejection — so a permanent 4xx (the record-deleted 400, say) died
  /// in the outbox while the reopened form looked perfectly clean and the only
  /// trace was a toast the user had already dismissed.
  Future<void> _hydrateFailedSync(
    Services services,
    String companyId,
    String entityId,
  ) async {
    if (await _linkFailedCreate(services, companyId, entityId)) return;
    final row = await services.db.outboxDao.findDeadSaveForEntity(
      companyId: companyId,
      entityType: widget.entityTypeName,
      entityId: entityId,
    );
    _applyFailedRow(row, recreate: false);
  }

  /// A record whose own create failed and never landed: link that create —
  /// its own rejection, not the one on the edits that died with it — and let
  /// an edit form re-send it (`GenericEditViewModel.savesAsCreate`). Saved as
  /// an update, the edit waited forever behind the failed create. Whether it
  /// linked one.
  Future<bool> _linkFailedCreate(
    Services services,
    String companyId,
    String entityId,
  ) async {
    if (!entityId.startsWith('tmp_')) return false;
    final newestCreate = await services.db.outboxDao.findNewestCreateForEntity(
      companyId: companyId,
      entityType: widget.entityTypeName,
      entityId: entityId,
    );
    if (newestCreate?.state != 'dead') return false;
    _applyFailedRow(newestCreate, recreate: widget.existingId != null);
    return true;
  }

  void _applyFailedRow(OutboxRow? row, {required bool recreate}) {
    if (row == null || _vm == null || !mounted) return;
    var errors = const <String, List<String>>{};
    final raw = row.fieldErrorsJson;
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        errors = decoded.map(
          (k, v) => MapEntry(
            k,
            (v as List).map((e) => e.toString()).toList(growable: false),
          ),
        );
      } catch (_) {
        // Undecodable blob — fall through on the message alone.
      }
    }
    final message = row.lastError;
    if (errors.isEmpty && (message == null || message.isEmpty)) return;
    // Pass the dead row's entityId so the VM can stash it as recoveryTempId
    // when it's a tmp_ id — the next Save then reuses that tmp id and
    // dedupPendingMutations replaces the prior dead/pending row instead of
    // creating a duplicate.
    _vm!.applyFailedSync(
      rowId: row.id,
      errors: errors,
      entityId: row.entityId,
      message: message,
      statusCode: row.lastStatusCode,
      recreate: recreate,
    );
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
    final row = await services.db.outboxDao.findDeadSaveForEntity(
      companyId: _companyId,
      entityType: widget.entityTypeName,
      entityId: entityId,
    );
    return row?.id;
  }

  /// The row a "Discard failed save" tap should abandon when the VM holds no
  /// link to one. Wider than [_resolveDeadRowId] — which stays dead-only
  /// because [_cleanupPriorDeadRow] must delete a SUPERSEDED row after a
  /// successful re-save and has no business touching one that is still queued.
  ///
  /// Discard is the other case: only a 422 kills the row, so a 5xx or a lost
  /// connection leaves the banner up over a `pending` row and the dead-only
  /// lookup found nothing — the tap cleared the banner and left the write to
  /// apply anyway. `findDiscardableForEntity` documents why `in_flight` and
  /// the non-save mutation kinds are excluded.
  Future<OutboxRow?> _findDiscardableRow(Services services, VM vm) async {
    // A create form has no record id: its rows are keyed on the temp id the
    // view model remembers from the attempt. Keyed on nothing, the lookup
    // never ran and a create the user discarded still went out.
    final entityId = widget.existingId ?? vm.recoveryTempId;
    if (entityId == null) return null;
    return services.db.outboxDao.findDiscardableForEntity(
      companyId: _companyId,
      entityType: widget.entityTypeName,
      entityId: entityId,
    );
  }

  /// Delete a prior 422's `dead` outbox row after a successful re-save (its
  /// payload is now stale) and clear the VM's failed-sync link. Shared by the
  /// plain-Save `onSaved` path and the edit-mode after-save `onSaveCleanup`
  /// path so both consume the dead row.
  ///
  /// Which rows a save supersedes is the repository's rule
  /// ([SyncRepository.supersedeDeadSave]) — a failed create that has not
  /// landed stays unless a newer create replaced it.
  Future<void> _cleanupPriorDeadRow(Services services, VM vm) async {
    final priorDeadId = await _resolveDeadRowId(services, vm);
    if (priorDeadId == null) return;
    await services.sync.supersedeDeadSave(priorDeadId);
    vm.clearFailedSync();
  }

  Future<void> _discardFailedSync(VM vm) async {
    final services = context.read<Services>();
    // A save held on an `unconfirmed` row discards THAT row — the newest
    // discardable one may be a later save queued behind it. It comes first:
    // it is what the banner shows, and a dead row cached when the form opened
    // may be stale (a later save replaced it) or simply not the one in view.
    final heldRowId = vm.unconfirmedIsSave ? vm.unconfirmedRowId : null;
    var rowId = heldRowId ?? vm.deadOutboxRowId;
    if (rowId == null) {
      final row = await _findDiscardableRow(services, vm);
      if (row != null &&
          row.state == 'unconfirmed' &&
          widget.existingId == null) {
        // A new record's create went `unconfirmed` out of the form's sight — a
        // background retry after the failure on screen — so it may have made
        // the record. Show that instead of dropping it unseen: the banner turns
        // to Check / Resend / Discard, and the form keeps its temp id, so a
        // Save is refused rather than making the record twice.
        vm.applyUnconfirmed(
          rowId: row.id,
          isSave: true,
          message: row.lastError,
        );
        return;
      }
      rowId = row?.id;
    }
    if (rowId == null) {
      vm.clearFailedSync();
      return;
    }
    // Read before it goes: where to leave for, if the record goes with it.
    final row = await services.db.outboxDao.byId(rowId);
    if (!mounted) return;
    // On a form opened on a record the server never saw, the failed save is
    // its create, and discarding that removes the record — with anything
    // queued that needs it, an invoice made for a new client say. More than
    // dropping a save, so it asks first, as the Outbox's Discard does.
    if (row != null &&
        widget.existingId != null &&
        services.confirmActions.value &&
        await services.sync.discardDeletesUnsyncedRecord(row)) {
      if (!mounted) return;
      final ok = await showConfirmActionDialog(
        context,
        title: context.tr('discard'),
        message: context.tr('discard_unsaved_record_body'),
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    final removedLocal = await services.sync.discardFailedSave(rowId);
    vm.clearFailedSync();
    // A never-synced record just went with its create (the ghost path): on a
    // form opened on it, or a create that may already have made it — whose
    // draft, saved again, could make it twice. Leave for its list, as a
    // resent create does, marked clean first so the route's exit guard
    // doesn't ask to discard what is already gone. Not `pop`: `/x/new` is a
    // sibling route in the entity shell, with nothing to pop, and
    // `/x/:id/edit` would pop onto the deleted record's detail. A create form
    // that dropped a create the server never saw keeps its draft; embedded
    // mode has no route of its own to leave.
    if (removedLocal &&
        row != null &&
        (widget.existingId != null || rowId == heldRowId) &&
        !widget.embedded &&
        mounted) {
      vm.markSaved();
      context.go(unconfirmedRowDestination(services, row));
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
      confirmSaveParam: widget.confirmSaveParam,
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
          // Builder so the retry closure resolves the `FormSaveScope` that
          // `EntityEditScaffold` installs *below* this method's context —
          // re-submitting through the scope reuses the one save path (unfocus
          // + flush hooks + dead-row relink) instead of forking a second one.
          Builder(
            builder: (bannerContext) => SaveFailedBanner(
              vm: vm,
              onDiscard: () => _discardFailedSync(vm),
              onRetry: () async =>
                  FormSaveScope.maybeOf(bannerContext)?.trySubmit(),
            ),
          ),
        ],
      ),
      resetToEmpty: () => widget.resetToEmpty(vm),
      onSaveRejected: () async {
        // Fresh 422 landed — re-link to the new dead row so a subsequent
        // Discard tap targets *this* failure, not the prior cached id. A new
        // record's draft has no id; its row is under the attempt's temp id.
        final services = context.read<Services>();
        final draftId = widget.entityIdOf(vm.draft);
        await _hydrateFailedSync(
          services,
          _companyId,
          draftId.isNotEmpty ? draftId : (vm.recoveryTempId ?? ''),
        );
      },
      onSaveFailed: () async {
        // The record's create can fail after the form opened: its edits then
        // die waiting on it, and saving another only queues one more that
        // can't go. From then on the form sends the create again, as one
        // opened after the create failed does.
        final existingId = widget.existingId;
        if (existingId == null || vm.savesAsCreate) return;
        await _linkFailedCreate(
          context.read<Services>(),
          _companyId,
          existingId,
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
