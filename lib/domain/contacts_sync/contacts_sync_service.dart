import 'package:drift/drift.dart' show Value;
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/value/country.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/services/device_contacts_service.dart';
import 'package:admin/domain/contacts_sync/contact_card_builder.dart';
import 'package:admin/domain/contacts_sync/contacts_sync_types.dart';

final _log = Logger('ContactsSyncService');

/// How many clients are read from Drift at a time, and how many address-book
/// writes go out in one batch. Small enough that cancellation is responsive and
/// a failure loses little, large enough that the plugin's batch path (which is
/// dramatically faster than per-contact calls) actually gets used.
const int kContactsSyncBatchSize = 100;

/// A client whose id is still a local placeholder hasn't been assigned a server
/// id yet. Syncing it would mint a card keyed to an id that is about to change,
/// so it's skipped and picked up on the next pass.
const String _tempIdPrefix = 'tmp_';

/// Reconciles Invoice Ninja client contacts into the device address book.
///
/// One-way (app to device) and **idempotent**: it computes the cards a company
/// should have, diffs them against what this install previously wrote, and
/// issues only the creates/updates/deletes needed. A second run right after a
/// first does nothing but read.
///
/// Ownership is the link table, never the label. A device contact is updated
/// or deleted only through a link row, and only once the device shows it is
/// still only ours (`ownsDeviceContact`): Android merges a card into the
/// user's own contact for the same person, and a write through the merged
/// contact reaches their copy too. The label groups the cards for display and
/// is a liveness hint — trusting its membership once deleted every contact on
/// the phone.
///
/// See `docs/contacts-sync.md`.
class ContactsSyncService implements ContactsSyncEngine {
  ContactsSyncService({
    required DeviceContactsService device,
    required ClientRepository clients,
    required AppDatabase db,
    required Map<String, Country> Function() countries,
    required String Function() currentUserId,
    required ContactsSyncGroupStore Function() groupStore,
    DateTime Function()? now,
  }) : _device = device,
       _clients = clients,
       _db = db,
       _countries = countries,
       _currentUserId = currentUserId,
       _groupStore = groupStore,
       _now = now ?? DateTime.now;

  final DeviceContactsService _device;
  final ClientRepository _clients;
  final AppDatabase _db;

  /// Read lazily: the statics bundle can land after this service is built, and
  /// a country name missing from an early card would stick until the next edit.
  final Map<String, Country> Function() _countries;

  final String Function() _currentUserId;

  /// Read through a getter, not held directly: the store is
  /// `ContactsSyncController`, which is constructed *around* this service, so a
  /// direct reference is a cycle. Same deferred-capture shape as `Services`'
  /// own `resync` runner.
  final ContactsSyncGroupStore Function() _groupStore;

  final DateTime Function() _now;

  /// The **display name** of the label a company's cards live under. Prefixed
  /// rather than bare so it can't be confused with a label the user made
  /// themselves.
  ///
  /// Deliberately *not* an identity: two companies can share a name, and every
  /// unnamed one shares the bare fallback below. Ownership keys on the company
  /// id via [ContactsSyncGroupStore] — see [_resolveGroupId].
  static String labelFor(String companyName) {
    final name = companyName.trim();
    return name.isEmpty ? 'Invoice Ninja' : 'Invoice Ninja — $name';
  }

  /// Push [companyId]'s client contacts to the device.
  ///
  /// Never throws — every failure comes back as a [ContactsSyncSummary], so
  /// every call site has one shape to handle.
  ///
  /// [refreshClients] decides whether to re-download clients first (see
  /// [ContactsSyncEngine.run]); [isFirstRun] then decides whether that download
  /// is a full re-pull or a cheap `updated_at` delta.
  @override
  Future<ContactsSyncSummary> run({
    required String companyId,
    required ContactsSyncScope scope,
    required bool isFirstRun,
    bool refreshClients = true,
    bool Function()? isCancelled,
    void Function(int done, int total)? onProgress,
  }) async {
    if (!_device.canSync) {
      return const ContactsSyncSummary(
        outcome: ContactsSyncOutcome.unsupported,
      );
    }
    if (companyId.isEmpty) {
      return const ContactsSyncSummary(outcome: ContactsSyncOutcome.noCompany);
    }
    // `limited` (iOS 18 "selected contacts") is deliberately not enough: we
    // could neither enumerate our own label nor trust a diff built from a
    // partial view, and the deletes that diff implies would be destructive.
    final permission = await _device.checkPermission();
    if (permission != DeviceContactsPermission.granted) {
      return const ContactsSyncSummary(
        outcome: ContactsSyncOutcome.permissionMissing,
      );
    }

    try {
      return await _reconcile(
        companyId: companyId,
        scope: scope,
        isFirstRun: isFirstRun,
        refreshClients: refreshClients,
        isCancelled: isCancelled ?? () => false,
        onProgress: onProgress,
      );
    } catch (e, st) {
      _log.warning('contacts sync failed for company $companyId', e, st);
      return ContactsSyncSummary.failed(e);
    }
  }

  Future<ContactsSyncSummary> _reconcile({
    required String companyId,
    required ContactsSyncScope scope,
    required bool isFirstRun,
    required bool refreshClients,
    required bool Function() isCancelled,
    void Function(int done, int total)? onProgress,
  }) async {
    if (refreshClients) {
      await _refreshClients(companyId: companyId, full: isFirstRun);
    }
    if (isCancelled()) {
      return const ContactsSyncSummary(outcome: ContactsSyncOutcome.cancelled);
    }

    final groupId = await _resolveGroupId(companyId, createIfMissing: true);

    final desiredResult = await _desiredCards(
      companyId: companyId,
      scope: scope,
      isCancelled: isCancelled,
    );
    final desired = desiredResult.cards;
    if (desired == null) {
      return ContactsSyncSummary(
        outcome: desiredResult.outcome ?? ContactsSyncOutcome.cancelled,
      );
    }

    final links = await _db.deviceContactLinkDao.byCompany(companyId);

    // The label's members are a liveness hint and nothing more: no card is
    // ever deleted because of what is, or isn't, in the label. flutter_contacts
    // before 2.3.0 answered an *empty* label with every contact on the phone,
    // and the heal pass that used to delete "members we don't recognise"
    // wiped the user's whole address book on a first sync. A linked card that
    // is a member is taken as present without asking the device again, which
    // keeps a repeat sync down to this one read.
    //
    // Null when there's no label to enumerate (a device with no contacts
    // account, see `DeviceContactsService.ensureGroup`); every link is then
    // taken as present.
    final memberIds = groupId == null
        ? null
        : (await _device.groupMemberIds(groupId)).toSet();
    bool isMember(DeviceContactLinkRow link) =>
        memberIds == null || memberIds.contains(link.deviceContactId);
    bool needsCheck(DeviceContactLinkRow link) =>
        !isMember(link) || desired[link.sourceId]?.hash != link.hash;

    // Ask the device about every link we are about to act on, or can't vouch
    // for:
    //
    //  * not in the label — the user deleted the card, or deleted the label
    //    (or this device only just gained its first contacts account, so
    //    `ensureGroup` minted an empty one), or Android merged the card into
    //    another contact and its id moved;
    //  * about to be updated or deleted — on Android both address the whole
    //    merged contact, so they wait for proof that it is only ours
    //    (`ownsDeviceContact`).
    final toCheck = <DeviceContactRef>[
      for (final link in links.values)
        if (needsCheck(link)) _ref(link),
    ];
    final states = toCheck.isEmpty
        ? const <String, DeviceContactState>{}
        : await _device.resolveContacts(toCheck);
    // Null: the device couldn't be read. Every link then counts as present —
    // re-creating them all would double the address book — and as not
    // provably ours, so nothing is updated or deleted this pass.
    final verified = states != null;

    final toCreate = <DeviceContactCard>[];
    final toUpdate = <DeviceContactUpdate>[];
    // The entry id to record for each updated card, by source id.
    final updateEntries = <String, String?>{};
    // Links whose card moved (merged into another contact) or whose entry id
    // was settled, re-written with the hash they already had.
    final relinks = <DeviceContactLinksCompanion>[];
    // Cards that outlived their label, put back in it.
    final readopt = <String>[];
    var unchanged = 0;
    var skippedMerged = 0;

    void relinkIfMoved(DeviceContactLinkRow link, DeviceContactState? state) {
      if (state == null) return;
      final recorded = _entryToRecord(link, state);
      if (state.contactId == link.deviceContactId &&
          recorded == link.rawContactId) {
        return;
      }
      relinks.add(
        _link(
          companyId: companyId,
          sourceId: link.sourceId,
          deviceContactId: state.contactId,
          rawContactId: recorded,
          hash: link.hash,
        ),
      );
    }

    for (final entry in desired.entries) {
      final link = links[entry.key];
      if (link == null) {
        toCreate.add(entry.value.card);
        continue;
      }
      final checked = needsCheck(link);
      final state = states?[link.deviceContactId];
      if (checked && verified && state == null) {
        // Gone from the device — the user deleted it by hand. Re-create; the
        // upsert re-points the link row, since it is keyed by source id.
        toCreate.add(entry.value.card);
        continue;
      }
      final owned =
          state != null &&
          ownsDeviceContact(
            recorded: link.rawContactId,
            entryIds: state.entryIds,
          );
      // Outlived its label — still a real card, just not in the group. Only a
      // card that is only ours goes back in: on a merged contact Android files
      // the membership under whichever entry shares the label's account, and
      // that may be the user's.
      if (!isMember(link) && owned && groupId != null) {
        readopt.add(state.contactId);
      }
      if (entry.value.hash == link.hash) {
        unchanged++;
        relinkIfMoved(link, state);
      } else if (owned) {
        toUpdate.add(
          DeviceContactUpdate(
            deviceId: state.contactId,
            card: entry.value.card,
          ),
        );
        updateEntries[entry.key] = _entryToRecord(link, state);
      } else {
        // Merged with a contact that isn't only ours (or unreadable): writing
        // through it would overwrite the user's own phones and emails. Leave
        // the card one edit behind; the hash stays old, so a later pass
        // updates it if the contacts are ever split apart again.
        if (state != null) skippedMerged++;
        relinkIfMoved(link, state);
      }
    }

    // Links whose client or contact is gone (deleted, archived, or filtered out
    // by the scope). A card is deleted only once the device has shown it is
    // only ours; a merged one stays, and so does its link row, so a later
    // pass can still remove it if the contacts are split apart again.
    final toDelete = <String>{};
    final droppedSourceIds = <String>[];
    for (final link in links.values) {
      if (desired.containsKey(link.sourceId) || states == null) continue;
      final state = states[link.deviceContactId];
      if (state == null) {
        droppedSourceIds.add(link.sourceId); // already gone from the device
      } else if (ownsDeviceContact(
        recorded: link.rawContactId,
        entryIds: state.entryIds,
      )) {
        toDelete.add(state.contactId);
        droppedSourceIds.add(link.sourceId);
      } else {
        skippedMerged++;
        relinkIfMoved(link, state);
      }
    }
    if (skippedMerged > 0) {
      _log.warning(
        'contacts sync for $companyId: $skippedMerged card(s) merged with '
        'another contact were left in place rather than writing through the '
        "user's own entry",
      );
    }

    final total = toCreate.length + toUpdate.length + toDelete.length;
    onProgress?.call(0, total);
    var done = 0;
    var summary = ContactsSyncSummary(
      unchanged: unchanged,
      skippedMerged: skippedMerged,
      labelled: groupId != null,
    );

    // Deletes first: they free up the address book before we add to it, and on
    // a scope change (all -> assigned to me) that's the bulk of the work.
    for (final chunk in _chunks(toDelete.toList())) {
      if (isCancelled()) {
        return summary.copyWith(outcome: ContactsSyncOutcome.cancelled);
      }
      await _device.deleteContacts(chunk);
      done += chunk.length;
      onProgress?.call(done, total);
    }
    if (droppedSourceIds.isNotEmpty) {
      await _db.deviceContactLinkDao.deleteBySourceIds(
        companyId: companyId,
        sourceIds: droppedSourceIds,
      );
    }
    summary = summary.copyWith(deleted: toDelete.length);

    await _db.deviceContactLinkDao.upsertAll(relinks);
    if (groupId != null && readopt.isNotEmpty) {
      await _device.addContactsToGroup(groupId: groupId, contactIds: readopt);
    }

    for (final chunk in _chunks(toCreate)) {
      if (isCancelled()) {
        return summary.copyWith(outcome: ContactsSyncOutcome.cancelled);
      }
      final created = await _device.createContacts(chunk, groupId: groupId);
      // Persist the links immediately, chunk by chunk. Deferring to the end
      // would mean a mid-pass crash left real device contacts with no link row
      // — and the link row is the only thing that lets a card be removed.
      await _db.deviceContactLinkDao.upsertAll([
        for (var i = 0; i < chunk.length && i < created.length; i++)
          _link(
            companyId: companyId,
            sourceId: chunk[i].sourceId,
            deviceContactId: created[i].contactId,
            rawContactId: entryIdToRecord(created[i].entryIds),
            hash: desired[chunk[i].sourceId]!.hash,
          ),
      ]);
      done += chunk.length;
      onProgress?.call(done, total);
    }
    summary = summary.copyWith(created: toCreate.length);

    var updated = 0;
    for (final chunk in _chunks(toUpdate)) {
      if (isCancelled()) {
        return summary.copyWith(
          outcome: ContactsSyncOutcome.cancelled,
          updated: updated,
        );
      }
      final written = await _device.updateContacts(chunk);
      updated += written.length;
      // Only what reached the device gets the new hash. A refused or skipped
      // card keeps its old one, so the next pass tries again rather than
      // treating it as up to date.
      await _db.deviceContactLinkDao.upsertAll([
        for (final item in chunk)
          if (written.contains(item.deviceId))
            _link(
              companyId: companyId,
              sourceId: item.card.sourceId,
              deviceContactId: item.deviceId,
              rawContactId: updateEntries[item.card.sourceId],
              hash: desired[item.card.sourceId]!.hash,
            ),
      ]);
      done += chunk.length;
      onProgress?.call(done, total);
    }
    summary = summary.copyWith(updated: updated);

    _log.info(
      'contacts sync for $companyId: +${summary.created} ~${summary.updated} '
      '-${summary.deleted} =${summary.unchanged} !${summary.skippedMerged}'
      '${groupId == null ? ' (no label)' : ''}',
    );
    return summary;
  }

  /// The device group that belongs to [companyId], resolved **by id**.
  ///
  /// The id this install last used is tried first, so the group survives a
  /// company rename and — the reason this exists — can never be confused with
  /// another company's. See [ContactsSyncGroupStore].
  ///
  /// Falling back to the name is only for installs that predate the stored id,
  /// and only when no other company already claims what the name finds:
  /// adopting a sibling's group is the exact collision being fixed. When the
  /// fallback is refused, [createIfMissing] mints a second group *under the
  /// same name* — companies that share a name get one label each, which is what
  /// the user's address book should show, rather than one of them carrying a
  /// suffix built from a raw company id.
  ///
  /// Returns null when the device can't have labels at all (no contacts
  /// account) or, with [createIfMissing] false, when there's nothing to find.
  Future<String?> _resolveGroupId(
    String companyId, {
    required bool createIfMissing,
  }) async {
    final store = _groupStore();
    final knownId = store.syncedGroupId(companyId);
    final companyName = (await _db.companiesDao.byId(companyId))?.name ?? '';
    final label = labelFor(companyName);

    final resolved = createIfMissing
        ? await _device.ensureGroup(label, knownId: knownId)
        : await _device.findGroup(label, knownId: knownId);
    if (resolved == null) {
      // Nothing to remember, and nothing to unremember: a null here means the
      // device has no labels (or, on the find-only path, that ours is gone).
      // Clearing the stored id on the latter would lose the link between a
      // company and a group that a later pass could still legitimately find.
      return null;
    }

    // The name lookup found someone else's group. Refuse it.
    if (resolved != knownId &&
        store.groupIsClaimedByOther(resolved, exceptCompanyId: companyId)) {
      _log.info(
        'the "$label" label belongs to another company — '
        '${createIfMissing ? 'creating a separate one' : 'skipping it'}',
      );
      if (!createIfMissing) return null;
      final fresh = await _device.createGroup(label);
      if (fresh != null) await store.setSyncedGroupId(companyId, fresh);
      return fresh;
    }

    if (resolved != knownId) await store.setSyncedGroupId(companyId, resolved);
    return resolved;
  }

  /// Re-download clients so the reconcile reads a complete set.
  ///
  /// The local cache only holds page 1 per entity until the user browses, so
  /// reading straight from Drift would cover a fraction of the address book.
  /// Never throws: offline or a transient server blip leaves the stale cache in
  /// place, which still beats doing nothing — the diff is against what we last
  /// wrote, so at worst some cards stay one edit behind.
  Future<void> _refreshClients({
    required String companyId,
    required bool full,
  }) async {
    try {
      await _clients.refreshAll(companyId: companyId, full: full);
    } catch (e, st) {
      _log.info('contacts sync: client refresh failed, using cache', e, st);
    }
  }

  /// Every card [companyId] should have, keyed by `sourceId`.
  ///
  /// Returns a failure [outcome] instead of a map when the set can't be
  /// computed — cancelled part-way, or (see [ContactsSyncOutcome.noUser]) an
  /// "assigned to me" scope with no user to assign against.
  Future<({Map<String, _Desired>? cards, ContactsSyncOutcome? outcome})>
  _desiredCards({
    required String companyId,
    required ContactsSyncScope scope,
    required bool Function() isCancelled,
  }) async {
    final String? assignedUserId;
    if (scope == ContactsSyncScope.assignedToMe) {
      final userId = _currentUserId();
      // `ClientDao.pageForContactSync` treats a blank assignee as "no filter",
      // so passing one through here would silently widen "Assigned to me" into
      // "every client in the company" — the exact thing the scope picker is
      // for. Fail closed instead.
      if (userId.isEmpty) {
        _log.warning(
          'contacts sync: scope is assignedToMe but the session has no user '
          'id — refusing to fall back to every client',
        );
        return (cards: null, outcome: ContactsSyncOutcome.noUser);
      }
      assignedUserId = userId;
    } else {
      assignedUserId = null;
    }
    final countries = _countries();
    final desired = <String, _Desired>{};
    var offset = 0;
    while (true) {
      if (isCancelled()) {
        return (cards: null, outcome: ContactsSyncOutcome.cancelled);
      }
      final page = await _clients.pageForContactSync(
        companyId: companyId,
        offset: offset,
        limit: kContactsSyncBatchSize,
        assignedUserId: assignedUserId,
      );
      for (final client in page) {
        if (client.id.startsWith(_tempIdPrefix)) continue;
        for (final card in buildCards(client, countries: countries)) {
          desired[card.sourceId] = _Desired(card, cardHash(card));
        }
      }
      if (page.length < kContactsSyncBatchSize) break;
      offset += kContactsSyncBatchSize;
    }
    return (cards: desired, outcome: null);
  }

  /// Remove every card this install wrote for [companyId], plus its label.
  ///
  /// Backs both the "Remove synced contacts" button and the logout cleanup —
  /// `logout()` wipes the link table, so without this the user's address book
  /// would keep a former employer's whole client list.
  ///
  /// Only link rows say what is ours, and only [ownsDeviceContact] says a card
  /// is safe to delete: never the label's members (flutter_contacts before
  /// 2.3.0 reported an empty label as every contact on the phone, and this is
  /// the path that then deleted them all), and never a card merged into one of
  /// the user's own contacts, which on Android would go with it.
  @override
  Future<void> removeAll({required String companyId}) async {
    if (!_device.canSync) return;
    try {
      final links = await _db.deviceContactLinkDao.byCompany(companyId);
      final states = links.isEmpty
          ? const <String, DeviceContactState>{}
          : await _device.resolveContacts([
              for (final link in links.values) _ref(link),
            ]);
      if (states == null) {
        // Nothing can be proven ours, so nothing is deleted — and the link
        // rows stay, so a later Remove can still reach the cards. (On logout
        // the wipe that follows takes the rows anyway; stray cards are the
        // lesser loss.)
        _log.warning(
          'removing synced contacts for $companyId: the device could not be '
          'read, so nothing was deleted',
        );
        return;
      }
      final ids = <String>{};
      var leftMerged = 0;
      for (final link in links.values) {
        final state = states[link.deviceContactId];
        if (state == null) continue; // already gone
        if (ownsDeviceContact(
          recorded: link.rawContactId,
          entryIds: state.entryIds,
        )) {
          ids.add(state.contactId);
        } else {
          leftMerged++;
        }
      }
      if (leftMerged > 0) {
        _log.warning(
          'removing synced contacts for $companyId: $leftMerged card(s) merged '
          "with the user's own contacts were left in place",
        );
      }

      for (final chunk in _chunks(ids.toList())) {
        await _device.deleteContacts(chunk);
      }
      // Find-only: `ensureGroup` would *create* the label on a device that
      // never had one, seconds before deleting it again. Members first, then
      // the label — deleting a group does not delete its contacts.
      final groupId = await _resolveGroupId(companyId, createIfMissing: false);
      if (groupId != null) await _device.deleteGroup(groupId);
      await _groupStore().setSyncedGroupId(companyId, null);
      await _db.deviceContactLinkDao.deleteCompany(companyId);
    } catch (e, st) {
      // Called from logout, immediately before the database is wiped. Throwing
      // here would abort the sign-out itself.
      _log.warning('removing synced contacts failed for $companyId', e, st);
    }
  }

  /// Every company this install has written cards for — including ones the user
  /// hasn't opened this session, which the logout cleanup must still reach.
  @override
  Future<List<String>> companiesWithSyncedContacts() =>
      _db.deviceContactLinkDao.companiesWithLinks();

  /// How many cards [companyId] would produce right now. Drives the pre-flight
  /// dialog, so the user sees "this adds 2,431 contacts" before it happens.
  @override
  Future<int> previewCardCount({
    required String companyId,
    required ContactsSyncScope scope,
    bool refreshClients = false,
  }) async {
    if (refreshClients) {
      await _refreshClients(companyId: companyId, full: true);
    }
    final result = await _desiredCards(
      companyId: companyId,
      scope: scope,
      isCancelled: () => false,
    );
    return result.cards?.length ?? 0;
  }

  DeviceContactLinksCompanion _link({
    required String companyId,
    required String sourceId,
    required String deviceContactId,
    required String? rawContactId,
    required String hash,
  }) => DeviceContactLinksCompanion(
    companyId: Value(companyId),
    sourceId: Value(sourceId),
    deviceContactId: Value(deviceContactId),
    rawContactId: Value(rawContactId),
    hash: Value(hash),
    updatedAt: Value(_now().millisecondsSinceEpoch),
  );

  static DeviceContactRef _ref(DeviceContactLinkRow link) => DeviceContactRef(
    contactId: link.deviceContactId,
    rawContactId: link.rawContactId,
  );

  /// The entry id to keep on [link]'s row once the device has shown [state]:
  /// the recorded one, or — for a row from before schema v15 — whatever the
  /// device shows now (`entryIdToRecord`).
  static String? _entryToRecord(
    DeviceContactLinkRow link,
    DeviceContactState state,
  ) => link.rawContactId ?? entryIdToRecord(state.entryIds);

  static Iterable<List<T>> _chunks<T>(List<T> items) sync* {
    for (var i = 0; i < items.length; i += kContactsSyncBatchSize) {
      yield items.sublist(
        i,
        (i + kContactsSyncBatchSize).clamp(0, items.length),
      );
    }
  }
}

class _Desired {
  const _Desired(this.card, this.hash);

  final DeviceContactCard card;
  final String hash;
}
