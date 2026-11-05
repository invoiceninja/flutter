import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/create_already_landed_exception.dart';
import 'package:admin/data/repositories/document_bearing_repository.dart';
import 'package:admin/data/repositories/sync_repository.dart';
import 'package:admin/data/repositories/unconfirmed_prior_mutation_exception.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/connectivity_watcher.dart';
import 'package:admin/data/services/shared_intake_files.dart';
import 'package:admin/data/services/upload_source.dart';
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
    bool prefilled = false,
    List<UploadSource> initialDocuments = const [],
    this.discardDocumentFiles,
  }) : _documents = original == null ? [...initialDocuments] : [],
       _original = original,
       _draft = initialDraft,
       _createBaseline = initialDraft,
       _prefilled = prefilled,
       _useCommaAsDecimalPlace = useCommaAsDecimalPlace,
       _sync = sync,
       _connectivity = connectivity,
       _companyId = companyId,
       _onlineSaveTimeout = onlineSaveTimeout;

  final T? _original;
  T _draft;

  /// What an untouched create form holds: the initial draft, plus every
  /// default [seedCreateDefault] has applied since. A create-mode subclass
  /// can define "dirty" as "differs from this" ([createBaseline]) instead of
  /// listing the fields it thinks matter — a list that missed a field let a
  /// form holding only that field leave without the Discard prompt.
  T _createBaseline;

  /// True when the create form opened on a draft somebody else staged — a
  /// clone, a "New Invoice" from a client or a product — rather than the
  /// blank factory. Such a form carries content the user has not saved, so it
  /// is dirty from its first frame. Cleared by [reset].
  bool _prefilled;

  /// Defaults applied by [seedCreateDefault] that [reset] re-applies to the
  /// blank draft it rebases onto.
  final List<T Function(T)> _resetSeeds = [];

  /// See [_createBaseline].
  @protected
  T get createBaseline => _createBaseline;

  /// See [_prefilled].
  @protected
  bool get prefilled => _prefilled;

  /// Apply a default the create form learns after it opened (a settings
  /// cascade answer, say) to the draft AND to [createBaseline], so it lands
  /// in the form without reading as an edit: an untouched form stays clean,
  /// and a user edit made meanwhile is kept.
  ///
  /// No-op on an edit form, mid-save, or once the form was saved or
  /// discarded ([_savedClean]) — the draft is then the saved record, or a
  /// form on its way out. It never clears [_savedClean] itself.
  ///
  /// [rememberForReset]: re-apply [seed] when [reset] rebases the form onto a
  /// blank draft. Pass false for a default that depends on something the
  /// blank draft does not carry (the chosen client).
  ///
  /// Returns whether the seed was applied.
  @protected
  bool seedCreateDefault(T Function(T) seed, {bool rememberForReset = true}) {
    if (!isCreate || _isSaving || _savedClean) return false;
    _draft = seed(_draft);
    _createBaseline = seed(_createBaseline);
    if (rememberForReset) _resetSeeds.add(seed);
    notifyListeners();
    return true;
  }

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
    if (orig == null) return draftIsNonEmpty() || _documents.isNotEmpty;
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

  bool _lastSaveWasDiscarded = false;

  /// True when the most recent `save()` returned null because its outbox row
  /// was discarded (from the Outbox, or by a discarded parent's cascade) while
  /// the online wait was polling it: nothing was saved, and the draft is kept
  /// for the user to save again. It used to read as a success and pop the
  /// form on "Saved". Reset on every save attempt.
  bool get lastSaveWasDiscarded => _lastSaveWasDiscarded;

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
    // Left without saving: copies nothing queued belong to no record. Not
    // mid-save — the rows being written would name them; the boot sweep
    // collects anything that really was left behind.
    if (!_isSaving) _discardFiles(_documents);
    _documents.clear();
    super.dispose();
  }

  // ── Documents attached before the record exists ──────────────────────
  //
  // invoiceninja/flutter#173, docs/attaching-documents.md. Every
  // document-bearing entity's create form holds files the user picks before
  // Save; each Save queues exactly these as uploads of the record.

  /// The repository that takes this record's uploads, which turns the
  /// feature on. Null (the default): an entity that takes no documents.
  @protected
  PendingUploadsRepository? get documentUploadRepository => null;

  /// Hands a file's app-owned copy back once the form lets go of it
  /// (`SharedIntakeFiles.delete`, which ignores every path outside its own
  /// folder and every copy an outbox row still names — so a picked file, or
  /// one an earlier attempt queued, is never touched). Set by the edit
  /// scaffold; null in unit tests, which then keep every file.
  Future<void> Function(Iterable<String> paths)? discardDocumentFiles;

  /// Files attached to a new record before it exists — picked on the form,
  /// or (New Expense) shared into the app from another one.
  ///
  /// The list is the truth for every create attempt: each Save queues exactly
  /// these as uploads of the record (under its `tmp_` id — the outbox holds
  /// them behind the create and rewrites the id once it lands, so this works
  /// offline too), replacing whatever an earlier attempt left unsent
  /// (`BaseEntityRepository.replaceUnsentDocumentUploads`). The outbox rows
  /// can't be the truth: a rejected create's uploads die with it, and the
  /// save-failed banner's Discard deletes them with the record. Cleared only
  /// when a save succeeds. Create mode only — an existing record uploads from
  /// its detail screen's Documents tab.
  final List<UploadSource> _documents;

  /// What the save in flight queued, and under which `tmp_` id — so a file
  /// added while that save is still out ([save]) can follow it.
  List<UploadSource>? _attemptBatch;
  String? _attemptTempId;

  /// Whether an attempt on this form queued any upload. Until one has, a
  /// Save with no files leaves the outbox alone — nothing of this form's can
  /// be there to replace, and most creates carry no files.
  bool _documentsQueued = false;

  /// A copy, not a view: a caller may iterate it across awaits (New Expense's
  /// receipt read) while the user adds or removes a file.
  List<UploadSource> get documents => List.unmodifiable(_documents);

  /// Whether the form shows its Documents card (or tab): a new record of an
  /// entity that takes documents.
  bool get offersDocuments => documentUploadRepository != null && isCreate;

  /// Whether the form can take more files: [offersDocuments], and a create
  /// that isn't waiting on the user (unconfirmed — the card is locked) and
  /// hasn't already been made (every later Save is refused, so a file added
  /// then would be deleted on leave). A save in flight can: see [save].
  bool get acceptsDocuments =>
      offersDocuments &&
      !_disposed &&
      !_documentsHandedOver &&
      _unconfirmedRowId == null &&
      !_alreadyCreated;

  /// Latched when a save hands the files to the record: the form is on its
  /// way out (or running an after-save action), and a file added now would
  /// be neither queued nor kept. Cleared by [reset].
  bool _documentsHandedOver = false;

  /// Attach [sources]; false, with nothing attached, when the form can't take
  /// them ([acceptsDocuments]).
  bool addDocuments(Iterable<UploadSource> sources) {
    if (!acceptsDocuments) return false;
    if (sources.isEmpty) return true;
    final added = List<UploadSource>.of(sources);
    _documents.addAll(added);
    // Files are unsaved content, even on a form [reset] just marked clean.
    _savedClean = false;
    notifyListeners();
    onDocumentsAdded(added);
    return true;
  }

  void removeDocument(UploadSource source) {
    if (!_documents.remove(source)) return;
    onDocumentRemoved(source);
    _discardFiles([source]);
    notifyListeners();
  }

  /// Called after [addDocuments] attached [added] (New Expense reads a
  /// receipt from them).
  @protected
  void onDocumentsAdded(List<UploadSource> added) {}

  /// Called after [removeDocument] dropped [source].
  @protected
  void onDocumentRemoved(UploadSource source) {}

  void _discardFiles(Iterable<UploadSource> sources) {
    final paths = sources.map(SharedIntakeFiles.localPathOf).nonNulls.toList();
    if (paths.isEmpty) return;
    unawaited(discardDocumentFiles?.call(paths));
  }

  /// Queue this attempt's files behind the create [performSave] just queued
  /// (its `tmp_` id is [recoveryTempId] by now). [batch] was snapshotted
  /// before [performSave]'s first await: a dispose meanwhile (a sign-out, the
  /// `/new` route re-keyed) clears the list, and a file added meanwhile
  /// belongs to [save]'s follow-up, not to this batch.
  Future<void> _queueDocumentUploads({
    required List<UploadSource>? batch,
    required String? retryingTempId,
  }) async {
    final repo = documentUploadRepository;
    final companyId = _companyId ?? '';
    final tempId = _recoveryTempId;
    if (repo == null || tempId == null) return;
    if (batch != null) {
      // Recorded first: a file added while this save is out follows it
      // ([_settleDocuments]) even when the batch itself was empty.
      _attemptBatch = batch;
      _attemptTempId = tempId;
      if (batch.isEmpty && !_documentsQueued) return;
      if (batch.isNotEmpty) _documentsQueued = true;
      final replaced = await repo.replaceUnsentDocumentUploads(
        companyId: companyId,
        tempId: tempId,
        enqueue: () async {
          for (final source in batch) {
            await repo.uploadDocument(
              companyId: companyId,
              entityId: tempId,
              source: source,
            );
          }
        },
      );
      // A file removed from the form after an earlier attempt: its row named
      // it until now, so the ✕ couldn't hand it back then.
      final kept = batch.map(SharedIntakeFiles.localPathOf).nonNulls.toSet();
      final dropped = replaced.where((p) => !kept.contains(p)).toList();
      if (dropped.isNotEmpty) unawaited(discardDocumentFiles?.call(dropped));
    } else if (retryingTempId != null) {
      // An edit form re-sending a failed create holds no files of its own:
      // move the earlier attempt's uploads behind this create.
      await repo.requeueUnsentDocumentUploads(
        companyId: companyId,
        tempId: retryingTempId,
      );
    }
  }

  /// A save the server confirmed (or that went out optimistically) hands the
  /// files to the record for good; a rejected one keeps them on the form, to
  /// be queued again — the same list — by the next attempt.
  ///
  /// A file added while the save was out (up to the 30 s online wait) missed
  /// that attempt's batch. It follows the record when the attempt's create row
  /// stands — saved, or waiting on the user — and stays on the form for the
  /// next attempt otherwise.
  Future<void> _settleDocuments(T? saved) async {
    final repo = documentUploadRepository;
    final batch = _attemptBatch;
    final tempId = _attemptTempId;
    _attemptBatch = null;
    _attemptTempId = null;
    if (repo != null &&
        batch != null &&
        tempId != null &&
        (saved != null || _unconfirmedRowId != null)) {
      final arrived = [
        for (final source in _documents)
          if (!batch.contains(source)) source,
      ];
      if (arrived.isNotEmpty) _documentsQueued = true;
      for (final source in arrived) {
        await repo.uploadDocument(
          companyId: _companyId ?? '',
          entityId: tempId,
          source: source,
        );
      }
    }
    if (saved != null) {
      _documents.clear();
      _documentsHandedOver = true;
    }
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

  /// True when the save was refused because the record already exists on the
  /// server — an earlier attempt at its create landed ([kAlreadyCreatedError]).
  /// A create form must not offer a way to a second record: no Retry, no
  /// Discard (which would drop the temp id that makes every later Save be
  /// refused too). An edit form re-sending the create drops back to saving
  /// an update of the real record, so its Retry stays.
  bool get failedSaveAlreadyCreated => _alreadyCreated;
  bool _alreadyCreated = false;

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

  int? _failedAttemptRowId;

  /// `outbox.id` of the row a save made on THIS visit to the form queued and
  /// that then failed — a 422, a 5xx, a lost connection — or null. Unlike
  /// [deadOutboxRowId] it is never a row the form merely opened onto: the
  /// leave-page Discard (the unsaved-changes guard) abandons this row too,
  /// since the user is throwing away the edit it carries. Without it a 5xx'd
  /// save left `pending` went out after the user chose Discard. Cleared by a
  /// successful save, [clearFailedSync] and [reset] — the scaffold reads it
  /// before calling [reset].
  int? get failedAttemptRowId => _failedAttemptRowId;

  int? _unconfirmedRowId;
  bool _unconfirmedIsSave = false;
  String? _unconfirmedMessage;

  /// The `unconfirmed` outbox row this record's save is held on (see
  /// `OutboxState`), or null: a change that may already have reached the
  /// server, which nothing sends again until the user decides. Set by a
  /// [save] that came back [SyncRowOutcome.unconfirmed] or was refused with
  /// [UnconfirmedPriorMutationException], and by [applyUnconfirmed] when the
  /// form reopens onto one.
  int? get unconfirmedRowId => _unconfirmedRowId;

  /// Whether [unconfirmedRowId] is this record's own create / update — the
  /// banner offers Check / Resend / Discard for it — rather than another
  /// change to the record (an email, a payment) that the next save queues
  /// behind, which the banner points to on the Outbox screen.
  bool get unconfirmedIsSave => _unconfirmedIsSave;

  /// The technical reason the row's outcome is unknown (its `last_error`).
  String? get unconfirmedMessage => _unconfirmedMessage;

  void applyUnconfirmed({
    required int rowId,
    required bool isSave,
    String? message,
  }) {
    _unconfirmedRowId = rowId;
    _unconfirmedIsSave = isSave;
    _unconfirmedMessage = message;
    notifyListeners();
  }

  /// Drop the unconfirmed-row link alone — after a Resend put the row back in
  /// line. Unlike [clearFailedSync] it keeps [recoveryTempId]: the row still
  /// carries that temp id, and a later Save that minted a fresh one would
  /// queue a second create.
  void clearUnconfirmed() {
    if (_unconfirmedRowId == null) return;
    _clearUnconfirmedState();
    notifyListeners();
  }

  void _clearUnconfirmedState() {
    _unconfirmedRowId = null;
    _unconfirmedIsSave = false;
    _unconfirmedMessage = null;
  }

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

  bool _recreate = false;

  /// Whether [performSave] saves as a create: in create mode, or on an edit
  /// form of a record whose own create failed and never landed — linked by
  /// [applyFailedSync] with `recreate`. Saved as an update, that edit waited
  /// forever behind the failed create; as a create under the record's
  /// [recoveryTempId] it re-sends the record, and the failed attempt goes when
  /// it lands. [isCreate] is unchanged: titles, layout and actions stay those
  /// of an edit. Every `performSave` branches on this, never on [isCreate]
  /// (`test/lint/saves_as_create_wiring_test.dart`).
  bool get savesAsCreate => isCreate || (_recreate && _recoveryTempId != null);

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
  ///
  /// [recreate] — the dead row is the record's own failed `create`, and this
  /// form edits that record: its next Save re-sends the create
  /// ([savesAsCreate]).
  void applyFailedSync({
    required int rowId,
    required Map<String, List<String>> errors,
    String? entityId,
    String? message,
    int? statusCode,
    bool recreate = false,
  }) {
    _deadOutboxRowId = rowId;
    _fieldErrors = Map.unmodifiable(errors);
    if (message != null && message.isNotEmpty) _submitError = message;
    if (statusCode != null) {
      _failedStatusCode = statusCode;
      _recordDeleted = isRecordDeletedRejection(statusCode, _submitError);
    }
    _alreadyCreated = isAlreadyCreatedRejection(_submitError);
    if (entityId != null && entityId.startsWith('tmp_')) {
      _recoveryTempId = entityId;
      _recreate = recreate;
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
        _recoveryTempId == null &&
        !_recreate &&
        _unconfirmedRowId == null &&
        _failedAttemptRowId == null) {
      return;
    }
    _clearUnconfirmedState();
    _deadOutboxRowId = null;
    _failedAttemptRowId = null;
    _fieldErrors = const {};
    _localValidationOnly = false;
    _submitError = null;
    _failedStatusCode = null;
    _recordDeleted = false;
    _alreadyCreated = false;
    _recoveryTempId = null;
    _recreate = false;
    notifyListeners();
  }

  /// Latch the form clean the way a completed [save] does, for a change that
  /// went out another way — a banner Resend — so leaving the form doesn't ask
  /// to discard what was just sent. The next real edit re-arms it.
  void markSaved() {
    if (_savedClean) return;
    _savedClean = true;
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
  ///
  /// In create mode [emptyDraft] becomes the new [createBaseline], with the
  /// remembered [seedCreateDefault] defaults re-applied — a discarded form is
  /// a blank one, not a prefilled one.
  void reset({required T emptyDraft}) {
    // As in [dispose]: a save in flight is writing rows that name them.
    if (!_isSaving) _discardFiles(_documents);
    _documents.clear();
    // A fresh record from here: [_recoveryTempId] goes below.
    _documentsQueued = false;
    _documentsHandedOver = false;
    if (_original == null) {
      var baseline = emptyDraft;
      for (final seed in _resetSeeds) {
        baseline = seed(baseline);
      }
      _createBaseline = baseline;
      _prefilled = false;
    }
    _draft = _original ?? _createBaseline;
    _savedClean = true;
    _clearUnconfirmedState();
    _submitError = null;
    _fieldErrors = const {};
    _localValidationOnly = false;
    _alreadyCreated = false;
    _recoveryTempId = null;
    _recreate = false;
    _failedAttemptRowId = null;
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
  ///
  /// Deliberately NOT `@protected`, unlike its `set*` neighbours: a numeric
  /// `EntityEditField` needs it to decide whether the value it holds and the
  /// canonical text the VM hands back are the same NUMBER (see that widget's
  /// `numeric` flag). Reading it to compare is fine; parsing user input in a
  /// widget still isn't — that belongs in a `set*` on the VM.
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

  final List<void Function()> _flushHooks = [];

  /// Register a callback that commits an in-flight debounced edit onto the
  /// draft — a line-item cell, a notes editor. Run by [flushPendingEdits]
  /// and first thing in [save]. Unlike [addBeforeSaveHook], a flush hook must
  /// only COMMIT what the user typed, never reshape the draft: anything that
  /// reads the draft mid-edit (the line-item picker) runs them too.
  /// Returns the unregister closure — call it in `dispose`.
  VoidCallback addFlushHook(void Function() hook) {
    _flushHooks.add(hook);
    return () => _flushHooks.remove(hook);
  }

  /// Commit every debounced edit onto the draft now, so a reader of [draft]
  /// sees what is on screen. Opening the line-item picker within the 250 ms
  /// cell debounce otherwise rebuilt the list from the pre-keystroke draft
  /// and the edit was lost.
  void flushPendingEdits() {
    for (final hook in List.of(_flushHooks)) {
      hook();
    }
  }

  final List<void Function()> _beforeSaveHooks = [];

  /// Register a callback fired synchronously at the start of [save] before
  /// [performSave] runs, after the [addFlushHook] hooks. For work that
  /// prepares the draft for the wire and only makes sense on a save — e.g.
  /// stripping the line-item table's trailing blank rows, which run from the
  /// picker would drop a blank row the user left there on Cancel.
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
    T? saved;
    try {
      saved = await _save();
      // Still "saving" while the files settle: the panel stays locked and a
      // dispose leaves them be, so neither a ✕ nor a sign-out hands back a
      // copy this is about to queue.
      await _settleDocuments(saved);
    } finally {
      _isSaving = false;
      // The screen may have unmounted while we were awaiting the sync
      // result (30 s timeout) — guard the notification so we don't trip
      // ChangeNotifier's disposed assertion.
      if (!_disposed) notifyListeners();
    }
    return saved;
  }

  Future<T?> _save() async {
    flushPendingEdits();
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
    _alreadyCreated = false;
    _fieldErrors = const {};
    _localValidationOnly = false;
    _lastSaveWasOptimistic = false;
    _lastSaveWasDiscarded = false;
    _clearUnconfirmedState();
    // Note: `_deadOutboxRowId` deliberately survives `save()` entry — the
    // screen's `onSaved` callback reads it to delete the prior dead row
    // after a successful re-save. A save that fails resets it in the catch
    // blocks below: on a 422 so the late-arriving `onSaveRejected` hook can
    // pick up the *fresh* dead row id, and on any other failure so Discard
    // reaches the newer row rather than the stale one.
    notifyListeners();
    int? awaitedRowId;
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
      final createsHere = savesAsCreate && documentUploadRepository != null;
      // Captured before [performSave]: [rememberCreateTempId] overwrites it.
      final retryingTempId = _recoveryTempId;
      final batch = createsHere && isCreate
          ? List<UploadSource>.of(_documents)
          : null;
      final result = await performSave();
      awaitedRowId = result.outboxRowId;
      if (createsHere) {
        await _queueDocumentUploads(
          batch: batch,
          retryingTempId: retryingTempId,
        );
      }
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
            case SyncRowOutcome.discarded:
              // Nothing was saved. The form stays open, dirty, on its draft.
              // A dead row it opened onto went with this save's row, as in
              // the unconfirmed arm below.
              _lastSaveWasDiscarded = true;
              _deadOutboxRowId = null;
              return null;
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
            case SyncRowOutcome.unconfirmed:
              // Nothing will send it until the user decides, so waiting out
              // the timeout would only delay saying so. The form stays open
              // on the banner's Check / Resend / Discard.
              _unconfirmedRowId = outcome.unconfirmedRowId;
              _unconfirmedIsSave = const {
                'create',
                'update',
              }.contains(outcome.unconfirmedMutationKind);
              _unconfirmedMessage = outcome.message;
              // A dead row the form opened onto was replaced by this save
              // (`dedupPendingMutations` carries a failed update's action
              // into it and deletes it). Kept, the link sent Discard and
              // the post-save cleanup to a row that is gone.
              _deadOutboxRowId = null;
              return null;
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
      _recreate = false;
      _failedAttemptRowId = null;
      return result.entity;
    } on CreateAlreadyLandedException {
      // An earlier attempt at this record's create landed: another would make
      // it twice. A create form keeps its temp id, so every later Save is
      // refused the same way; an edit form re-sending the create drops back to
      // saving an update of the record, which now exists.
      _submitError = kAlreadyCreatedError;
      _alreadyCreated = true;
      _deadOutboxRowId = null;
      _recreate = false;
      return null;
    } on UnconfirmedPriorMutationException catch (e) {
      // The earlier create of this record may already have made it on the
      // server; nothing was queued this time.
      _unconfirmedRowId = e.rowId;
      _unconfirmedIsSave = true;
      _unconfirmedMessage = null;
      return null;
    } on ValidationException catch (e) {
      _fieldErrors = Map.unmodifiable(e.fieldErrors);
      // The prior dead-row link (if any) refers to the previous failure's
      // row; this fresh failure superseded it. Drop it so the screen's
      // discard / onSaveRejected hooks act on the new row instead.
      _deadOutboxRowId = null;
      _failedAttemptRowId = awaitedRowId ?? _failedAttemptRowId;
      _failedStatusCode = 422;
      // Keep the top-level message even when per-field errors exist. Rejected
      // keys often name no field this form renders, and nulling the message
      // there left the banner saying "fix the errors below" with nothing below
      // (invoiceninja/flutter#36).
      _submitError = e.message;
      return null;
    } catch (e) {
      // This visit's failed save, for the leave-page Discard. A throw before
      // anything was queued keeps the earlier attempt's row, still this
      // visit's.
      _failedAttemptRowId = awaitedRowId ?? _failedAttemptRowId;
      // Surface a clean error message: `ApiException` subclasses' default
      // `toString()` prefixes with the runtime type (e.g. "ServerException:
      // Connection lost"), which leaks implementation detail into the toast
      // and inline submit-error UI.
      _submitError = e is ApiException ? e.message : e.toString();
      _failedStatusCode = e is ServerException ? e.statusCode : null;
      // An awaited row reports the rejection as a plain ServerException, so
      // re-classify from the status and message, as a reopened form does.
      _recordDeleted =
          e is RecordDeletedException ||
          isRecordDeletedRejection(_failedStatusCode, _submitError);
      // The drain refused an awaited create whose record already exists.
      _alreadyCreated = isAlreadyCreatedRejection(_submitError);
      if (_alreadyCreated) {
        // Saved again, the form sends an update of the record that exists,
        // and links the refused row, which that save then supersedes. Left in
        // re-create mode, Retry was refused once more; unlinked, the refused
        // row stayed in the Outbox and the sign-out count, and came back as
        // this banner whenever the record was opened.
        _recreate = false;
        _deadOutboxRowId = awaitedRowId;
        return null;
      }
      // As in the 422 arm: this failure superseded the one the form opened
      // with. A 5xx or a lost connection leaves the NEW row pending, so a
      // cached link to the old dead row sent Discard there — and the write the
      // user had just discarded went out anyway. With no link, the screen's
      // discard falls back to the newest row for the record.
      _deadOutboxRowId = null;
      return null;
    } finally {
      // Defensively drop any pending save-query that performSave did not
      // consume (e.g. an after-save-only screen, or a non-billing entity):
      // it must never survive into a subsequent plain Save.
      // [save] clears `_isSaving` and notifies, once the attached files
      // have settled.
      _pendingSaveQuery = null;
    }
  }
}
