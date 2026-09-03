/// The two "write a note onto this record's activity feed" flows — the single
/// implementation behind every Activity-tab button **and** every `⋯` menu arm,
/// on all ten entities that support notes.
///
/// Each caller supplies only [submit] — its own `repo.addComment(...)` — so the
/// `requireSynced` gate, the prompt and the success/error toast live in one
/// place. That matters beyond line count. Before this, five billing arms
/// awaited the repo bare (no success toast, no Retry) while the Activity tab on
/// the same screen toasted; three more used private helpers that skipped
/// `requireSynced` entirely, so a comment on a `tmp_` record burned an outbox
/// row against an id the server cannot resolve; and Vendor showed two visibly
/// different Add-comment dialogs depending on which entry point you used.
///
/// The `⋯` arms' local `tmpGate()` is exactly `() => !requireSynced(context,
/// id)`, so nothing is lost by routing them through here.
///
/// Both write the same `MutationKind.addComment` outbox row: a logged call is
/// an ordinary user note carrying a marker (see `call_note.dart`), which is why
/// the pending "Syncing…" row in the tab needs no special case.
library;

import 'package:flutter/widgets.dart';

import 'package:admin/domain/phone/phone_candidates.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/dialogs/log_call_sheet.dart';
import 'package:admin/ui/core/sync/require_synced.dart';
import 'package:admin/ui/core/widgets/notify_async.dart';
import 'package:admin/ui/features/clients/widgets/detail/add_comment_dialog.dart';

/// Opens the add-comment prompt for [entityId] and enqueues the text.
Future<void> promptAddCommentFor(
  BuildContext context, {
  required String entityId,
  required Future<void> Function(String text) submit,
}) async {
  // `tmp_` ids exist only in the outbox until the create round-trips, and
  // `StoreNoteRequest` validates `entity_id` with `Rule::exists` — so an
  // ungated note would burn its retries against a row the server can't see.
  if (!requireSynced(context, entityId)) return;
  final text = await showAddCommentDialog(context);
  if (text == null || text.isEmpty || !context.mounted) return;
  await runMutationWithNotify(
    context,
    () => submit(text),
    successMsg: context.tr('added_comment'),
  );
}

/// Opens the log-a-call form for [entityId] and enqueues the composed note.
Future<void> promptLogCallFor(
  BuildContext context, {
  required String companyId,
  required String entityId,
  required String subject,
  List<PhoneCandidate> candidates = const <PhoneCandidate>[],
  required Future<void> Function(String text) submit,
}) async {
  if (!requireSynced(context, entityId)) return;
  final note = await showLogCallSheet(
    context,
    companyId: companyId,
    subject: subject,
    candidates: candidates,
  );
  if (note == null || !context.mounted) return;
  await runMutationWithNotify(
    context,
    () => submit(note),
    successMsg: context.tr('logged_call'),
  );
}
