import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

import 'package:admin/app/arrival_gate.dart';
import 'package:admin/app/localized_toast.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/shared_intake_files.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';
import 'package:admin/utils/document_upload_validation.dart';

/// Why the native side could not hand a shared file over as-is.
enum SharedFileIssue {
  /// Over the 25 MB document cap — the copy was abandoned.
  tooLarge,

  /// The sending app's file could not be read.
  unreadable,

  /// An image the server won't take that could not be converted to JPEG
  /// (an SVG, or HEIF on an Android older than 9).
  unsupported,
}

/// One file shared into the app from another one, as the native side
/// (`ShareReceiverActivity` / the iOS Share Extension) reports it: already
/// copied into the app's own `shared_intake/` folder, or not copied at all
/// when [issue] says why.
@immutable
class SharedFile {
  const SharedFile({required this.path, required this.name, this.issue});

  /// Decodes one entry of the `takeShares` channel reply. Null for an entry
  /// with no name — nothing the user could be told about.
  static SharedFile? fromChannel(Object? entry) {
    if (entry is! Map) return null;
    final name = entry['name'];
    if (name is! String || name.isEmpty) return null;
    final path = entry['path'];
    final issue = entry['issue'];
    return SharedFile(
      path: path is String ? path : '',
      name: name,
      issue: SharedFileIssue.values.where((i) => i.name == issue).firstOrNull,
    );
  }

  /// The app-owned copy; empty when nothing was copied.
  final String path;
  final String name;
  final SharedFileIssue? issue;
}

/// What to do with files shared into the app from another one
/// (invoiceninja/flutter#173): open New Expense with them attached.
///
/// The platform bridge (`AppShareIntake`) only transports; this decides. It
/// is shaped like `DeepLinkRouter`, its sibling, and for the same reasons:
/// it lives on `Services`, the router it navigates with only exists once
/// `MaterialApp.router` is built ([attach]), and a share that arrives before
/// then — or while the app is signed out, biometric-locked or still in
/// `/setup` — is held and replayed, not dropped ([ArrivalGate]).
///
/// The files are the app's own copies by the time they get here (the grant
/// on the original died with the native receiver), so every path out of this
/// class that does not hand them to the New Expense form deletes them.
class SharedFileIntake {
  SharedFileIntake({
    required ValueListenable<AuthSession?> session,
    required ValueListenable<ApiCredentials?> credentials,
    required ValueListenable<bool> requiresBiometricUnlock,
    required bool Function(AuthSession? session) isSetupRequired,
    required bool Function() canCreateExpense,
    required bool Function() expenseModuleOn,
    required bool Function() canAttachDocuments,
    required String? Function() currentCompanyId,
    required Future<bool> Function(BuildContext context) confirmLeave,
    required void Function(List<UploadSource> attachments) stageExpense,
    required Future<void> Function(Iterable<String> paths) deleteFiles,
    required Future<bool> Function(String path) ownsFile,
    required ToastController toasts,
    UploadSource Function(String path) sourceFor = fileUploadSource,
  }) : _gate = ArrivalGate(
         session: session,
         credentials: credentials,
         requiresBiometricUnlock: requiresBiometricUnlock,
         isSetupRequired: isSetupRequired,
       ),
       _canCreateExpense = canCreateExpense,
       _expenseModuleOn = expenseModuleOn,
       _canAttachDocuments = canAttachDocuments,
       _currentCompanyId = currentCompanyId,
       _confirmLeave = confirmLeave,
       _stageExpense = stageExpense,
       _deleteFiles = deleteFiles,
       _ownsFile = ownsFile,
       _toasts = toasts,
       _sourceFor = sourceFor;

  /// Where New Expense lives — full width, like every other create.
  static const kTarget = '/expenses/new?view=full';

  final ArrivalGate _gate;

  /// The dashboard's create gate: create route, module and `create_expense`.
  final bool Function() _canCreateExpense;

  /// Only to word a refusal: a company with Expenses switched off is told
  /// that, not that the user lacks a permission.
  final bool Function() _expenseModuleOn;

  /// False on a hosted plan without document attachments
  /// (`AuthSession.canAttachDocuments`). New Expense still opens, without the
  /// files and without its Documents card, and a toast says why.
  final bool Function() _canAttachDocuments;

  /// The active company, which a New Expense form must belong to before a
  /// share may join it ([registerAttachTarget]).
  final String? Function() _currentCompanyId;

  /// The app-wide unsaved-changes guard. Its Discard clears every dirty
  /// editor, so the edit route's own `onExit` prompt doesn't fire a second
  /// time — and it is what stops a share from silently replacing a dirty New
  /// Expense, which the generation-keyed `/new` route would otherwise do.
  final Future<bool> Function(BuildContext context) _confirmLeave;
  final void Function(List<UploadSource> attachments) _stageExpense;
  final Future<void> Function(Iterable<String> paths) _deleteFiles;

  /// `SharedIntakeFiles.owns`: a share may only hand over the app's own copies.
  /// Anything else — a forged hand-off naming the app's private files — is
  /// refused as unreadable before it can be attached and uploaded.
  final Future<bool> Function(String path) _ownsFile;
  final ToastController _toasts;
  final UploadSource Function(String path) _sourceFor;
  final _log = Logger('SharedFileIntake');

  void Function(String location)? _go;
  BuildContext? Function()? _contextOf;

  /// The New Expense form open right now, if any ([registerAttachTarget]).
  _AttachTarget? _attachTarget;

  /// Files staged for a New Expense that hasn't mounted (and so registered)
  /// yet. A second share in that window is staged together with them rather
  /// than replacing them; the form's registration clears it.
  List<UploadSource> _unclaimedStage = const [];

  /// Serialises [receive]: two shares in quick succession must not interleave
  /// two unsaved-changes prompts.
  Future<void> _inFlight = Future.value();

  /// Bumped by [endSession], so a share queued behind another on [_inFlight]
  /// when the session ends — or one waiting on the unsaved-changes prompt — is
  /// dropped rather than replayed into the next account's.
  int _generation = 0;

  /// Shares waiting for [attach], the gate, or the first frame. A second share
  /// while waiting is appended: both were the user's.
  final _held = <SharedFile>[];

  /// The copies [_held] owns — what a wipe of the local data must spare. A file
  /// shared while signed out and followed by a sign-in as someone new triggers
  /// the identity-change wipe; that share belongs to the sign-in, not to the
  /// data being wiped.
  Set<String> get heldPaths => {
    for (final f in _held)
      if (f.path.isNotEmpty) f.path,
  };

  /// While a New Expense form is open it registers here, and a share joins
  /// it — no prompt, no lost draft — instead of replacing it: start an expense,
  /// go to Photos, share the receipt. Last registered wins; the returned
  /// callback unregisters (the view model calls it from `dispose`).
  ///
  /// [companyId] is the company the form saves into. A form left open in
  /// another branch survives a company switch — the create screen binds its
  /// company once, at mount — so a share joins it only while that company is
  /// still the active one; otherwise a fresh New Expense is staged, which
  /// re-keys the stale page. [attach] returns false when the form can't take
  /// files right now (its save is unconfirmed, or the record already exists),
  /// and the share then opens a New Expense of its own.
  VoidCallback registerAttachTarget(
    String companyId,
    bool Function(List<UploadSource> attachments) attach,
  ) {
    final target = _AttachTarget(companyId, attach);
    _attachTarget = target;
    _unclaimedStage = const [];
    return () {
      if (identical(_attachTarget, target)) _attachTarget = null;
    };
  }

  /// Wire navigation in once `MaterialApp.router` exists. [contextOf] supplies
  /// a `BuildContext` under the `MultiProvider` (the root navigator's), for the
  /// unsaved-changes prompt and the toasts' localization.
  void attach({
    required void Function(String location) go,
    required BuildContext? Function() contextOf,
  }) {
    _go = go;
    _contextOf = contextOf;
    _replayHeld();
  }

  /// Handle one share. Never throws — a problem is reported to the user, not
  /// to the caller.
  Future<void> receive(List<SharedFile> files) {
    if (files.isEmpty) return _inFlight;
    final generation = _generation;
    return _inFlight = _inFlight
        .then((_) {
          if (generation != _generation) return _deleteAll(files);
          return _receive(files, generation);
        })
        .catchError((Object e, StackTrace st) {
          _log.warning('shared files failed', e, st);
        });
  }

  Future<void> _receive(List<SharedFile> files, int generation) async {
    // Not yet able to act: no router, signed out / locked / in setup, or no
    // frame yet to put a prompt or a toast on.
    if (_go == null) {
      _held.addAll(files);
      return;
    }
    if (!_gate.isOpen) {
      _held.addAll(files);
      _gate.notifyWhenOpen(_replayHeld);
      return;
    }
    final context = _contextOf?.call();
    if (context == null) {
      _held.addAll(files);
      WidgetsBinding.instance.addPostFrameCallback((_) => _replayHeld());
      return;
    }

    if (!_canCreateExpense()) {
      final module = Localization.of(context)?.lookup('expenses');
      if (!_expenseModuleOn() && module != null) {
        _toast('module_disabled_notice', params: {'module': module});
      } else {
        _toast('not_allowed', kind: LocalizedToastKind.error);
      }
      await _deleteAll(files);
      return;
    }

    var attachments = const <UploadSource>[];
    if (_canAttachDocuments()) {
      attachments = await _validate(files);
      if (attachments.isEmpty) return;
    } else {
      // The receipt can't come along — say so, rather than let it vanish.
      _toast('requires_an_enterprise_plan');
      await _deleteAll(files);
    }

    if (generation != _generation) {
      await _deleteFiles(_pathsOf(attachments));
      return;
    }

    // A New Expense is already open, in this company, and can take them: the
    // files join it.
    final target = _attachTarget;
    if (target != null &&
        target.companyId == _currentCompanyId() &&
        (attachments.isEmpty || target.attach(attachments))) {
      _go?.call(kTarget);
      return;
    }
    // One is about to open with an earlier share's files: stage them together.
    if (_unclaimedStage.isNotEmpty) {
      _unclaimedStage = [..._unclaimedStage, ...attachments];
      _stageExpense(_unclaimedStage);
      _go?.call(kTarget);
      return;
    }

    if (!context.mounted) {
      await _deleteFiles(_pathsOf(attachments));
      return;
    }
    final leave = await _confirmLeave(context);
    // Re-checked after the prompt: a sign-out while it was up ends the session
    // this share was handled in.
    if (generation != _generation) {
      await _deleteFiles(_pathsOf(attachments));
      return;
    }
    if (!leave) {
      if (!_gate.isOpen) {
        // The prompt went because the app locked, not because the user said
        // no: hold the share for the unlock, as one that arrived then would be.
        _held.addAll([
          for (final s in attachments)
            if (SharedIntakeFiles.localPathOf(s) case final path?)
              SharedFile(path: path, name: s.fileName),
        ]);
        _gate.notifyWhenOpen(_replayHeld);
        return;
      }
      await _deleteFiles(_pathsOf(attachments));
      return;
    }
    _stageExpense(attachments);
    _unclaimedStage = attachments;
    _go?.call(kTarget);
  }

  /// The files the server will take, as upload sources. Rejects — reported by
  /// the native side or failing [validateDocumentSources] — are toasted with
  /// the same words every upload surface uses, and deleted.
  Future<List<UploadSource>> _validate(List<SharedFile> files) async {
    final candidates = <SharedFile>[];
    final reported = <SharedFile>[];
    for (final f in files) {
      if (f.issue != null || f.path.isEmpty) {
        reported.add(f);
      } else if (!await _ownsFile(f.path)) {
        // Not one of ours: refused, and not deleted — it isn't ours to delete
        // (and `SharedIntakeFiles.delete` would ignore it anyway).
        reported.add(
          SharedFile(path: '', name: f.name, issue: SharedFileIssue.unreadable),
        );
      } else {
        candidates.add(f);
      }
    }
    final batch = await validateDocumentSources([
      for (final f in candidates) _sourceFor(f.path),
    ]);
    final merged = DocumentUploadBatch(
      accepted: batch.accepted,
      rejected: batch.rejected,
      sawWrongType:
          batch.sawWrongType ||
          reported.any((f) => f.issue != SharedFileIssue.tooLarge),
      sawTooLarge:
          batch.sawTooLarge ||
          reported.any((f) => f.issue == SharedFileIssue.tooLarge),
    );
    for (final notice in merged.rejectNotices) {
      _toast(notice.key, params: notice.params);
    }
    await _deleteFiles([
      for (final f in reported)
        if (f.path.isNotEmpty) f.path,
      ..._pathsOf(batch.rejected),
    ]);
    return batch.accepted;
  }

  void _replayHeld() {
    if (_held.isEmpty) return;
    final files = List<SharedFile>.of(_held);
    _held.clear();
    unawaited(receive(files));
  }

  Iterable<String> _pathsOf(Iterable<UploadSource> sources) =>
      sources.map(SharedIntakeFiles.localPathOf).nonNulls;

  Future<void> _deleteAll(List<SharedFile> files) => _deleteFiles([
    for (final f in files)
      if (f.path.isNotEmpty) f.path,
  ]);

  void _toast(
    String key, {
    Map<String, String>? params,
    LocalizedToastKind kind = LocalizedToastKind.warning,
  }) => showLocalizedToast(
    toasts: _toasts,
    context: _contextOf?.call(),
    key: key,
    params: params,
    kind: kind,
    log: _log,
  );

  /// The session is ending (`onBeforeLogout` — which also runs, first, when a
  /// different identity signs in and the local data is wiped). Aborts any share
  /// being handled, including one waiting on the unsaved-changes prompt, but
  /// keeps the HELD ones: a file shared while signed out belongs to whoever
  /// signs in next, and the identity-change wipe spares it ([heldPaths]).
  void endSession() {
    _generation++;
    _unclaimedStage = const [];
    _attachTarget = null;
  }

  /// A deliberate sign-out finished (`onSessionReset`, which the
  /// identity-change wipe does not run): a receipt held for one account must
  /// not be attached to an expense in the next one's.
  void dropHeld() {
    final files = List<SharedFile>.of(_held);
    _held.clear();
    _gate.cancel();
    unawaited(_deleteAll(files));
  }

  void dispose() {
    _generation++;
    _held.clear();
    _gate.cancel();
  }
}

/// A New Expense form registered with [SharedFileIntake.registerAttachTarget].
class _AttachTarget {
  _AttachTarget(this.companyId, this.attach);

  final String companyId;
  final bool Function(List<UploadSource> attachments) attach;
}
