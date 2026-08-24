import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/sync_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/connectivity_watcher.dart';
import 'package:admin/utils/formatting.dart';

/// State for an entity edit or create screen. Holds the in-progress draft in
/// memory, exposes dirty / saving flags, surfaces validation errors per-field,
/// and serializes the final save through a subclass-supplied [performSave].
///
/// Concrete subclasses (`ClientEditViewModel`, `ProductEditViewModel`, …)
/// supply:
///   * the empty-draft factory (passed as `initialDraft` when creating)
///   * the per-field setters (which call [updateDraft])
///   * [performSave] — runs the repo create/save call and returns the saved
///     entity (with tmp id for new rows) on success
///   * [draftIsNonEmpty] — used by the create-mode dirty check; defaults to
///     `true` so a brand-new screen is treated as dirty
abstract class GenericEditViewModel<T> extends ChangeNotifier {
  GenericEditViewModel({
    required T initialDraft,
    T? original,
    bool useCommaAsDecimalPlace = false,
    SyncRepository? sync,
    ConnectivityWatcher? connectivity,
    String? companyId,
    Duration onlineSaveTimeout = const Duration(seconds: 30),
  }) : _original = original,
       _draft = initialDraft,
       _useCommaAsDecimalPlace = useCommaAsDecimalPlace,
       _sync = sync,
       _connectivity = connectivity,
       _companyId = companyId,
       _onlineSaveTimeout = onlineSaveTimeout;

  final T? _original;
  T _draft;

  /// Optional sync + connectivity wiring. When both are set (production
  /// path), [save] awaits the just-enqueued outbox row so 422 / 5xx errors
  /// land inline on the still-open form instead of via the dead-row banner
  /// post-pop. Unit tests construct the VM without them and keep the
  /// legacy fire-and-forget behavior.
  final SyncRepository? _sync;
  final ConnectivityWatcher? _connectivity;
  final String? _companyId;
  final Duration _onlineSaveTimeout;

  /// Honors the company's `useCommaAsDecimalPlace` setting for [setDec].
  /// Without this, a user with that setting enabled typing `1,5` gets the
  /// comma stripped by [parseDecimal]'s regex and stored as `15` — a silent
  /// 10× corruption. Subclasses thread the company setting via `super`.
  final bool _useCommaAsDecimalPlace;

  T get draft => _draft;
  T? get original => _original;

  /// True when this VM is for a brand-new entity (no existing row).
  bool get isCreate => _original == null;

  /// Latches true the moment [performSave] succeeds, so a just-saved form
  /// is not "dirty" — otherwise the post-save navigation (`onSaved` →
  /// `context.go`/`context.pop`) trips the unsaved-changes guard and pops a
  /// spurious "Discard changes?" right after the user pressed Save. In
  /// create mode `_original` stays null (and `isCreate` must keep reflecting
  /// that), and in edit mode `_original` is never rebased, so neither side
  /// of [isDirty] would otherwise clear on save. Any later edit re-arms it
  /// via [updateDraft]. [reset] (the discard path) also latches it true, so a
  /// discarded create-mode draft reports clean instead of falling back to
  /// [draftIsNonEmpty] — otherwise the chained discard guards (sidebar →
  /// branch switch → route `onExit`) each see it as still-dirty and re-prompt.
  bool _savedClean = false;

  /// True when the user has actually changed something. The discard prompt
  /// uses this to decide whether to ask. For create mode, falls back to
  /// [draftIsNonEmpty] so an untouched empty screen doesn't ask to discard.
  /// A successful save clears it until the next edit.
  bool get isDirty {
    if (_savedClean) return false;
    final orig = _original;
    if (orig == null) return draftIsNonEmpty();
    return _draft != orig;
  }

  /// Override per entity. Default is `true` so subclasses that don't care
  /// always treat create-mode as dirty.
  @protected
  bool draftIsNonEmpty() => true;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  bool _lastSaveWasOptimistic = false;

  /// True when the most recent successful `save()` returned because the
  /// online wait hit its timeout (server hasn't confirmed yet) rather than
  /// the dispatcher actually draining the row. The scaffold reads this to
  /// toast `"Saving in background…"` instead of `"Saved"` — without the
  /// distinction the user sees "Saved" then sees a dead-row banner a minute
  /// later when the row finally 422s. Reset on every save attempt.
  bool get lastSaveWasOptimistic => _lastSaveWasOptimistic;

  bool _disposed = false;

  /// Latches in [dispose] so the `save()` finally block (which can run
  /// after the screen unmounts — a 30 s `awaitRow` may still resolve
  /// while the user navigates away) doesn't call `notifyListeners()` on
  /// a disposed `ChangeNotifier`, which asserts in debug Flutter.
  bool get isDisposed => _disposed;

  /// Swallow notifications after disposal instead of asserting. Edit screens
  /// legitimately mutate the VM from post-frame callbacks and resolved futures
  /// that can outlive the route (e.g. an auto-seed scheduled on the frame the
  /// user closes the pane), and every such call site guarding itself is a rule
  /// that gets forgotten. `GenericListViewModel` and `GenericDetailViewModel`
  /// already do exactly this.
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  String? _submitError;

  /// The server's own words for why the save was rejected — network, 5xx, a
  /// permanent 4xx, **and** a 422's top-level message.
  ///
  /// It used to be nulled whenever [fieldErrors] was non-empty, on the theory
  /// that the per-field text said everything. It doesn't: a 422 can name keys
  /// no field on the form renders (`invitations.*.client_contact_id`,
  /// `location_id`, `tags.*`, `number`), and then the banner told the user to
  /// "fix the errors below" with nothing below and Discard as the only exit
  /// (invoiceninja/flutter#36). Always keep the message; the banner renders it
  /// alongside whatever field errors did map.
  String? get submitError => _submitError;

  int? _failedStatusCode;

  /// Wire status of the rejection currently on display, when it came from the
  /// server. Null for a client-side [validate] block or a clean form.
  int? get failedStatusCode => _failedStatusCode;

  /// True when the server refused because the record is soft-deleted
  /// (`ChecksEntityStatus::disallowUpdate()` — HTTP 400, *"Record is deleted
  /// and cannot be edited. Restore the record to enable editing"*). Retrying
  /// is futile; the failure surface offers **Restore** instead.
  ///
  /// Archived records never set this: the server's guard reads `is_deleted`
  /// only, so editing an archived record succeeds.
  bool get failedSaveIsRecordDeleted => _recordDeleted;
  bool _recordDeleted = false;

  Map<String, List<String>> _fieldErrors = const {};

  /// Map of `api_field_key` → list of error messages, populated when the
  /// server returns 422. Each [GenericEditField] (or any edit field) looks
  /// up its own key via [fieldErrorFor] to render an inline error.
  Map<String, List<String>> get fieldErrors => _fieldErrors;

  /// First error message for [apiKey], or null. The convention is to use
  /// the snake_case API field name (the same key the server returns).
  String? fieldErrorFor(String apiKey) {
    final list = _fieldErrors[apiKey];
    if (list == null || list.isEmpty) return null;
    return list.first;
  }

  bool _localValidationOnly = false;

  /// True when the current [fieldErrors] came from [validate] (a client-side
  /// block — no local write, no outbox row was ever created), rather than a
  /// server 422 / dead outbox row. The save-failed banner and the edit
  /// scaffold use this to drop the server-rejection framing and skip the
  /// dead-row lookup that only makes sense for a real sync failure.
  bool get localValidationOnly => _localValidationOnly;

  /// Synchronous pre-save validation. Return `api_field_key -> messages` to
  /// block the save *before* any local write / outbox enqueue; the map feeds
  /// the same inline-error path ([fieldErrorFor]) as a server 422. Default:
  /// no client-side validation. Subclasses with required fields override
  /// this (e.g. billing docs require a client / vendor).
  @protected
  Map<String, List<String>> validate() => const {};

  /// Run [validate] and publish its result to [fieldErrors], without touching
  /// the draft, the local row or the outbox. Returns true when the form is
  /// clean.
  ///
  /// For a screen that opens a modal *on the user's behalf* before saving, so
  /// it can check the form first. User Details prompts for the account
  /// password before enqueuing (the server 412-gates every user mutation), and
  /// asking someone to authenticate in order to save a form that was never
  /// valid is the wrong order — that shipped briefly as the interaction of
  /// invoiceninja/flutter#64 and #66.
  ///
  /// [save] re-runs [validate] itself, so calling this first is belt-and-
  /// braces rather than a precondition; nothing downstream depends on it.
  bool validateAndPublish() {
    final errors = validate();
    _fieldErrors = Map.unmodifiable(errors);
    _localValidationOnly = errors.isNotEmpty;
    notifyListeners();
    return errors.isEmpty;
  }

  int? _deadOutboxRowId;

  /// `outbox.id` of the dead row whose 422 errors this VM is currently
  /// surfacing — set by [applyFailedSync] when the screen is reopened
  /// after a sync failure. Null otherwise. The "Discard failed save"
  /// affordance uses this to delete the right row from the outbox.
  int? get deadOutboxRowId => _deadOutboxRowId;

  String? _recoveryTempId;

  /// `tmp_<uuid>` from a prior CREATE attempt that didn't fully drain (422
  /// or transient error). Subclasses thread this into `repo.create(
  /// existingTempId: ...)` on the next `performSave` so the retry replaces
  /// the prior pending outbox row in-place — without it, each click of Save
  /// on a stuck CREATE form mints a fresh tmp id and the prior pending row
  /// (still under its old tmp id) eventually drains as a duplicate.
  ///
  /// Cleared after a successful save (`_savedClean = true`) and on [reset]
  /// — once the row is gone or the user explicitly discards, the next
  /// attempt is a clean start.
  String? get recoveryTempId => _recoveryTempId;

  /// Remember the tmp id from a CREATE attempt's [SaveResult] so subsequent
  /// retries can reuse it. Subclasses call this from their `performSave`
  /// override right after a `repo.create(...)` call.
  @protected
  void rememberCreateTempId(String? tmpId) {
    _recoveryTempId = tmpId;
  }

  /// Replay a prior sync failure on this screen. The Outbox screen's
  /// "Open" action and the edit form's `initState` use this to surface
  /// the server's 422 against the re-opened form, so the user can fix
  /// the flagged fields and re-save. Passing an empty [errors] map clears
  /// any previously-displayed errors.
  ///
  /// [entityId] — the dead outbox row's `entity_id`. When it's a `tmp_<uuid>`
  /// (the entity was created offline / via a timed-out online save and
  /// 422'd later), the VM stashes it as `recoveryTempId` so the user's
  /// next Save reuses that same tmp id. Without this, the retry mints a
  /// fresh tmp id and the (now-stale) dead row's eventual cleanup races
  /// with a second create attempt — duplicate-server-row risk.
  /// [message] / [statusCode] — the dead row's `last_error` / `last_status_code`.
  /// Supplying them lets the banner explain a rejection that carried **no**
  /// field errors at all (a permanent 4xx), which previously left the reopened
  /// form looking clean while the outbox row sat dead. Pass null to leave the
  /// current values alone (the fresh-failure path already set them in [save]).
  void applyFailedSync({
    required int rowId,
    required Map<String, List<String>> errors,
    String? entityId,
    String? message,
    int? statusCode,
  }) {
    _deadOutboxRowId = rowId;
    _fieldErrors = Map.unmodifiable(errors);
    if (message != null && message.isNotEmpty) _submitError = message;
    if (statusCode != null) {
      _failedStatusCode = statusCode;
      _recordDeleted = isRecordDeletedRejection(statusCode, _submitError);
    }
    if (entityId != null && entityId.startsWith('tmp_')) {
      _recoveryTempId = entityId;
    }
    notifyListeners();
  }

  /// Clear the dead-row link + the field errors. Called after the user
  /// either fixes the bad fields and saves again, or explicitly discards.
  ///
  /// Also clears `_recoveryTempId` — "Discard failed save" means the user
  /// wants to throw away the prior attempt entirely; the next Save should
  /// mint a fresh tmp id rather than re-use the discarded attempt's id
  /// (which would collide with the now-orphaned dead outbox row).
  void clearFailedSync() {
    if (_deadOutboxRowId == null &&
        _fieldErrors.isEmpty &&
        !_localValidationOnly &&
        _submitError == null &&
        _recoveryTempId == null) {
      return;
    }
    _deadOutboxRowId = null;
    _fieldErrors = const {};
    _localValidationOnly = false;
    _submitError = null;
    _failedStatusCode = null;
    _recordDeleted = false;
    _recoveryTempId = null;
    notifyListeners();
  }

  /// Replace the working draft and notify. Per-field setters in subclasses
  /// route through here.
  @protected
  void updateDraft(T next) {
    _draft = next;
    // A fresh edit after a save re-arms the dirty/guard machinery.
    _savedClean = false;
    notifyListeners();
  }

  /// Restore the draft to the loaded original (or [emptyDraft] in create
  /// mode) and clear all errors. Called by the unsaved-changes guard after
  /// the user picks Discard. Marks the VM clean (`_savedClean = true`) so a
  /// just-discarded draft reports `isDirty == false` in every mode — the next
  /// real edit re-arms it via [updateDraft]. Without this the chained discard
  /// guards re-prompt on a create-mode form whose [draftIsNonEmpty] stays true.
  void reset({required T emptyDraft}) {
    _draft = _original ?? emptyDraft;
    _savedClean = true;
    _submitError = null;
    _fieldErrors = const {};
    _localValidationOnly = false;
    _recoveryTempId = null;
    notifyListeners();
  }

  /// Concrete repo call — `repo.create` for new rows, `repo.save` for
  /// existing ones. Subclasses dispatch based on [isCreate]. Returns the
  /// saved entity *plus* the outbox row id that the sync engine will drain.
  /// The id lets [save] await that specific row when online so a 422 lands
  /// inline. Throws on synchronous failures (e.g. client-side guards inside
  /// the repo); 422 / 5xx are surfaced via the awaited outbox row, not by
  /// throwing here.
  @protected
  Future<SaveResult<T>> performSave();

  /// Optimistic save. Returns the saved entity on success, null on
  /// failure. The view uses the return value to decide whether to pop the
  /// route. On 422, [fieldErrors] is populated and the view should stay
  /// open so the user can fix the flagged fields.
  /// Collapse the entity's per-field setters from
  /// `void setX(T v) => updateDraft(draft.copyWith(x: v))` into one-liners
  /// via [setStr] / [setBool] / [setDec] / [setInt]. Each takes a function
  /// `(T, V) -> T` that applies the new value, plus the value itself.
  /// Mirrors freezed's `copyWith` shape without the per-VM boilerplate.
  ///
  /// Numeric inputs (`setDec`, `setInt`) accept the raw `String` from a
  /// text field; failing parse falls back to zero (matches the empty-for-
  /// blank convention in CLAUDE.md § Forms).
  @protected
  void setStr(T Function(T, String) write, String v) =>
      updateDraft(write(_draft, v));

  @protected
  void setBool(T Function(T, bool) write, bool v) =>
      updateDraft(write(_draft, v));

  /// The company's decimal-comma setting, for subclasses that parse numeric
  /// input outside [setDec] (e.g. a setter that writes two fields, or one with
  /// a non-zero default). Pass it to [parseDecimal] — never `Decimal.tryParse`
  /// on raw input, which silently zeroes `"1,5"` for comma-locale users.
  @protected
  bool get useCommaAsDecimalPlace => _useCommaAsDecimalPlace;

  @protected
  void setDec(T Function(T, Decimal) write, String input) => updateDraft(
    write(
      _draft,
      parseDecimal(input, useCommaAsDecimalPlace: _useCommaAsDecimalPlace) ??
          Decimal.zero,
    ),
  );

  @protected
  void setInt(T Function(T, int) write, String input) =>
      updateDraft(write(_draft, int.tryParse(input.trim()) ?? 0));

  Map<String, String>? _pendingSaveQuery;

  /// Set by the edit scaffold immediately before triggering [save] for a
  /// SAVE-PARAM action (mark_sent / paid / cancel / …). The billing-doc
  /// `performSave` override reads it via [consumeSaveQuery] and threads it
  /// into the repo create/save call so the server performs the action as
  /// part of the same save request. Single-use: cleared by [consumeSaveQuery]
  /// and, defensively, at the end of every [save] so a later plain Enter/⌘S
  /// can never replay a stale action.
  void setPendingSaveQuery(Map<String, String>? q) => _pendingSaveQuery = q;

  /// Returns and clears the one-shot pending save-query. `performSave`
  /// overrides that support SAVE-PARAM actions call this and pass the result
  /// as the repo's `extraQuery`. Returns null when no action is pending
  /// (the normal Save / Enter path).
  @protected
  Map<String, String>? consumeSaveQuery() {
    final q = _pendingSaveQuery;
    _pendingSaveQuery = null;
    return q;
  }

  final List<void Function()> _beforeSaveHooks = [];

  /// Register a callback fired synchronously at the start of [save] before
  /// [performSave] runs. Used by inline-edit widgets (e.g. the desktop
  /// line-item table) to flush in-flight debounced text-field edits onto
  /// the draft so a Save click never loses the last few keystrokes.
  /// Returns the unregister closure — call it in `dispose`.
  VoidCallback addBeforeSaveHook(void Function() hook) {
    _beforeSaveHooks.add(hook);
    return () => _beforeSaveHooks.remove(hook);
  }

  final List<void Function()> _finalizeSaveHooks = [];

  /// Register a callback fired synchronously in [save] AFTER every
  /// [addBeforeSaveHook] hook has run. Use this for work that must observe the
  /// fully-flushed draft — e.g. billing totals stamping, which has to run after
  /// the line-item table flushes its debounced cell edits, not before (a
  /// before-save hook registered in a VM constructor would otherwise run ahead
  /// of flush hooks registered later in a child widget's initState).
  VoidCallback addFinalizeSaveHook(void Function() hook) {
    _finalizeSaveHooks.add(hook);
    return () => _finalizeSaveHooks.remove(hook);
  }

  Future<T?> save() async {
    if (_isSaving) return null;
    for (final hook in List.of(_beforeSaveHooks)) {
      hook();
    }
    // Finalize hooks run after all before-save hooks so they see the
    // fully-flushed draft (e.g. totals stamped from the last cell keystroke).
    for (final hook in List.of(_finalizeSaveHooks)) {
      hook();
    }
    _isSaving = true;
    _submitError = null;
    _failedStatusCode = null;
    _recordDeleted = false;
    _fieldErrors = const {};
    _localValidationOnly = false;
    _lastSaveWasOptimistic = false;
    // Note: `_deadOutboxRowId` deliberately survives `save()` entry — the
    // screen's `onSaved` callback reads it to delete the prior dead row
    // after a successful re-save. If `performSave` itself throws a 422
    // synchronously, the catch block below resets it so the late-arriving
    // `onSaveRejected` hook can pick up the *fresh* dead row id.
    notifyListeners();
    try {
      // Client-side validation runs *inside* the try so the `finally` below
      // still fires on an early return — that's what clears _pendingSaveQuery
      // (a one-shot SAVE-PARAM action) and resets _isSaving. The before-save
      // hooks above have already flushed debounced edits onto the draft, so
      // validate() sees the final draft. Don't move this before the try.
      final localErrors = validate();
      if (localErrors.isNotEmpty) {
        _fieldErrors = Map.unmodifiable(localErrors);
        _localValidationOnly = true;
        return null;
      }
      final result = await performSave();
      // If the production wiring is in place AND the device is online, wait
      // for the just-enqueued row to settle so 422 / 5xx errors land on this
      // form instead of via the dead-row banner after pop. When wiring is
      // missing (unit tests) or the device is offline, fall through to the
      // legacy fire-and-forget behavior.
      final sync = _sync;
      final connectivity = _connectivity;
      final companyId = _companyId;
      if (sync != null && connectivity != null && companyId != null) {
        final online = await connectivity.isOnline;
        if (online) {
          final outcome = await sync.awaitRow(
            rowId: result.outboxRowId,
            companyId: companyId,
            timeout: _onlineSaveTimeout,
          );
          switch (outcome.outcome) {
            case SyncRowOutcome.success:
              break;
            case SyncRowOutcome.timeout:
              // Optimistic fallback — local Drift row is the user's draft,
              // outbox keeps trying in the background. Flag for the scaffold
              // so it can toast "Saving in background…" instead of "Saved".
              _lastSaveWasOptimistic = true;
              break;
            case SyncRowOutcome.validationFailed:
              throw ValidationException(
                outcome.message ?? '',
                outcome.fieldErrors,
              );
            case SyncRowOutcome.serverError:
              throw ServerException(
                outcome.statusCode ?? 0,
                outcome.message ?? 'Save failed',
              );
          }
        }
      }
      // Mark the form clean so the post-save navigation doesn't trip the
      // unsaved-changes guard. Re-armed by the next [updateDraft]. The
      // recovery tmp id is no longer needed: either we successfully drained
      // (the dispatcher will applyCreateResponse → remap to a real id), or
      // we hit timeout and the still-pending row carries the same tmp id
      // (background drain handles its own remap).
      _savedClean = true;
      _recoveryTempId = null;
      return result.entity;
    } on ValidationException catch (e) {
      _fieldErrors = Map.unmodifiable(e.fieldErrors);
      // The prior dead-row link (if any) refers to the previous failure's
      // row; this fresh failure superseded it. Drop it so the screen's
      // discard / onSaveRejected hooks act on the new row instead.
      _deadOutboxRowId = null;
      _failedStatusCode = 422;
      // Keep the top-level message even when per-field errors exist. Rejected
      // keys often name no field this form renders, and nulling the message
      // there left the banner saying "fix the errors below" with nothing below
      // (invoiceninja/flutter#36).
      _submitError = e.message;
      return null;
    } catch (e) {
      // Surface a clean error message: `ApiException` subclasses' default
      // `toString()` prefixes with the runtime type (e.g. "ServerException:
      // Connection lost"), which leaks implementation detail into the toast
      // and inline submit-error UI.
      _submitError = e is ApiException ? e.message : e.toString();
      _failedStatusCode = e is ServerException ? e.statusCode : null;
      _recordDeleted = e is RecordDeletedException;
      return null;
    } finally {
      // Defensively drop any pending save-query that performSave did not
      // consume (e.g. an after-save-only screen, or a non-billing entity):
      // it must never survive into a subsequent plain Save.
      _pendingSaveQuery = null;
      _isSaving = false;
      // The screen may have unmounted while we were awaiting the sync
      // result (30 s timeout) — guard the notification so we don't trip
      // ChangeNotifier's disposed assertion.
      if (!_disposed) notifyListeners();
    }
  }
}
