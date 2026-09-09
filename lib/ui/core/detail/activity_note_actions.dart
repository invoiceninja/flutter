/// The two "write a note onto this record's activity feed" flows — the single
/// implementation behind every Activity-tab button, every comments-only empty
/// state, every Comments card footer **and** every `⋯` menu arm, on all ten
/// entities that support notes.
///
/// Callers reach these through `EntityNoteActions`
/// (`activity_note_buttons.dart`), built once per detail screen so the
/// surfaces on one record cannot drift apart.
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
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/domain/phone/phone_candidates.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/dialogs/log_call_sheet.dart';
import 'package:admin/ui/core/sync/require_synced.dart';
import 'package:admin/ui/core/widgets/notify_async.dart';
import 'package:admin/ui/features/clients/widgets/detail/add_comment_dialog.dart';

final _log = Logger('ActivityNoteActions');

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
///
/// [clientId] / [vendorId] name the record's **party**, whose contacts seed the
/// form's Contact field and fill its picker. This is the one place that
/// resolution happens (invoiceninja/flutter#129): before it, only the Client
/// and Vendor screens passed a candidate list — they hold a resolved record
/// with `contacts` on it — while all eight document entities fell through to an
/// empty default at every one of their 15 call sites (two each, bar recurring
/// expense, which mounts no Activity tab and so has only its `⋯` arm). The
/// field was blank and the picker icon absent on every invoice, quote, credit,
/// recurring invoice, purchase order, payment, expense and recurring expense.
/// Nothing failed: the button rendered, the sheet opened, the note saved.
///
/// **Vendor wins over client, on vendor-facing records only** — expense,
/// recurring expense and purchase order.
///
/// `Invoice`, `Quote`, `Credit`, `RecurringInvoice` **and `Payment`** also
/// declare a `vendorId`, and it is not vestigial — `invoice_columns.dart` ships
/// a linked Vendor column for the billing docs, and React offers one too. It is
/// simply not the right party *here*: a call logged against an invoice is a
/// call to whoever owes it. Wiring it "for symmetry" would silently redirect
/// those five documents' contact lists.
///
/// `test/lint/call_note_wiring_test.dart` fails the build on a call site that
/// names neither, because every symptom of forgetting is silent.
Future<void> promptLogCallFor(
  BuildContext context, {
  required String companyId,
  required String entityId,
  required String subject,
  String? clientId,
  String? vendorId,
  required Future<void> Function(String text) submit,
}) async {
  if (!requireSynced(context, entityId)) return;

  final party = await _resolveParty(
    context,
    companyId: companyId,
    clientId: clientId,
    vendorId: vendorId,
  );
  if (!context.mounted) return;

  final note = await showLogCallSheet(
    context,
    companyId: companyId,
    subject: subject,
    partyName: party.name,
    candidates: party.contacts,
  );
  if (note == null || !context.mounted) return;
  await runMutationWithNotify(
    context,
    () => submit(note),
    successMsg: context.tr('logged_call'),
  );
}

/// The party's contacts plus its display name — the latter titles the contact
/// picker, which must not inherit the sheet's `subject` (`#0064` on a document,
/// so the picker headed itself "Call #0064").
typedef _Party = ({List<PhoneCandidate> contacts, String name});

const _Party _noParty = (contacts: <PhoneCandidate>[], name: '');

/// How long a party lookup may block the sheet when the record is not yet in
/// Drift.
///
/// The common path never spends it: a cached party is one local query. The miss
/// is a *configuration*, not merely a race, which is why this is a bounded wait
/// rather than a fire-and-forget hydrate — and it is reachable from both
/// layouts, though not for the reason it first appears:
///
///  * **Wide.** A billing doc's table hydrates its client from the Client
///    column *and* from every money column (`cellPartyMoney` →
///    `PartyCurrencyBuilder._ensure`), and `amount` / `balance` ship visible by
///    default — so the miss needs all of them hidden, or a genuinely zero row.
///    On the vendor-facing three the hydrating cell is `VendorNameLabel`.
///  * **Narrow.** The tile is *not* always safe: `expense_list_tile.dart`
///    mounts `VendorNameLabel` only when a vendor is set, and
///    `recurring_expense_list_tile.dart` only when the number is empty — so an
///    ordinary numbered recurring expense hydrates nothing at all on a phone.
///
/// `ensureLoaded` also negative-caches a 404, so "it'll be warm next time" is
/// not guaranteed either.
///
/// Two seconds is under the point at which a button reads as broken, and the
/// alternative on that path is a blank field. Never unbounded: `ensureLoaded`
/// awaits its fetch with no timeout of its own, and this tap has no spinner and
/// no cancel — `ActivityNoteButtons` latches the button for the duration, which
/// is the only feedback there is. (The two Drift reads either side are local
/// queries and carry no bound of their own.)
const Duration _kPartyHydrateBudget = Duration(seconds: 2);

Future<_Party> _resolveParty(
  BuildContext context, {
  required String companyId,
  required String? clientId,
  required String? vendorId,
}) async {
  final vendor = (vendorId ?? '').trim();
  final client = (clientId ?? '').trim();
  if (vendor.isEmpty && client.isEmpty) return _noParty;

  // Read AFTER the early return, and touch a repository only inside a branch a
  // caller opted into by passing an id: `PhoneActionsTestServices` is a stub
  // whose `noSuchMethod` throws, so an unconditional `services.clients` reds
  // every widget test built on it. `context.read` itself is safe — it hands
  // back the object without touching a member.
  final services = context.read<Services>();

  try {
    if (vendor.isNotEmpty) {
      // A vendor id that doesn't resolve yields NOTHING, never the client's
      // contacts: on an expense or purchase order whose vendor merely isn't
      // cached, falling through would file the wrong party's name into a note
      // that is append-only and permanent.
      final v = await _hydrate(
        watch: () => services.vendors.watch(companyId: companyId, id: vendor),
        ensureLoaded: () =>
            services.vendors.ensureLoaded(companyId: companyId, id: vendor),
      );
      return v == null
          ? _noParty
          : (contacts: vendorCallLogCandidates(v), name: v.name);
    }
    final c = await _hydrate(
      watch: () => services.clients.watch(companyId: companyId, id: client),
      ensureLoaded: () =>
          services.clients.ensureLoaded(companyId: companyId, id: client),
    );
    return c == null
        ? _noParty
        : (contacts: clientCallLogCandidates(c), name: c.displayName);
  } catch (e, s) {
    // A drift stream can complete `.first` with an error, and this whole
    // function runs inside a fire-and-forget `onLogCall` — so an escaping one
    // would swallow the tap entirely: no sheet, no toast, nothing. Degrade to
    // the pre-#129 rendering (blank field, no picker icon) instead; the field
    // is free text and the note still saves.
    //
    // Logged, not silent, and deliberately catching `Error` too: the
    // degradation is byte-for-byte the #129 symptom this file exists to
    // remove, so a genuine miswire here would otherwise reproduce the bug with
    // nothing to find. WARNING reaches the on-disk diagnostics log.
    _log.warning(
      'log-call party lookup failed; opening with no contacts',
      e,
      s,
    );
    return _noParty;
  }
}

/// One Drift read, then at most one bounded hydrate.
///
/// `watch().first` is the repo's one-shot read (`client_edit_screen.dart` does
/// the same, and so does `ensureLoadedTemplate` internally); it resolves `tmp_`
/// ids through `id_remap` and its controller cancels both inner subscriptions
/// on `.first`, so it cannot leak. **Not `peek`** — that is a first-frame seed
/// for a `StreamBuilder`'s `initialData` and nothing else, which
/// `test/lint/peek_is_seed_only_test.dart` enforces.
///
/// A `tmp_` party id cannot reach here anyway: `requireSynced` has already
/// gated the record, and a *synced* document cannot reference an unsynced
/// party — `save()` rebinds through `resolveId` first.
Future<T?> _hydrate<T>({
  required Stream<T?> Function() watch,
  required Future<void> Function() ensureLoaded,
}) async {
  final cached = await watch().first;
  if (cached != null) return cached;
  await ensureLoaded().timeout(_kPartyHydrateBudget, onTimeout: () {});
  return watch().first;
}
