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
/// Ownership is the label, not the link table. Everything this feature writes
/// goes into one group per company, and the reconcile deletes any group member
/// it doesn't recognise — which is what lets it recover after `logout()` wipes
/// the link table, or after a pass dies half-way. Contacts outside the group are
/// never read, never written, never deleted.
///
/// See `docs/contacts-sync.md`.
class ContactsSyncService implements ContactsSyncEngine {
  ContactsSyncService({
    required DeviceContactsService device,
    required ClientRepository clients,
    required AppDatabase db,
    required Map<String, Country> Function() countries,
    required String Function() currentUserId,
    DateTime Function()? now,
  }) : _device = device,
       _clients = clients,
       _db = db,
       _countries = countries,
       _currentUserId = currentUserId,
       _now = now ?? DateTime.now;

  final DeviceContactsService _device;
  final ClientRepository _clients;
  final AppDatabase _db;

  /// Read lazily: the statics bundle can land after this service is built, and
  /// a country name missing from an early card would stick until the next edit.
  final Map<String, Country> Function() _countries;

  final String Function() _currentUserId;
  final DateTime Function() _now;

  /// The label a company's cards live under. Prefixed rather than bare so it
  /// can't be confused with (or collide with) a label the user made themselves.
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

    final companyName = (await _db.companiesDao.byId(companyId))?.name ?? '';
    final groupId = await _device.ensureGroup(labelFor(companyName));

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

    // Read the label's members *before* diffing, not after. Membership is what
    // tells us a link still points at a real card: without it, a contact the
    // user deleted by hand would be "updated" into the void, get a fresh hash
    // stamped on its link, and then read as unchanged on every subsequent pass
    // — gone from the device but never re-created.
    //
    // Null when there's no label to enumerate (a device with no contacts
    // account, see `DeviceContactsService.ensureGroup`). The link table is then
    // the only ownership record we have, so both this check and the heal below
    // are skipped.
    final memberIds = groupId == null
        ? null
        : (await _device.groupMemberIds(groupId)).toSet();

    final toCreate = <DeviceContactCard>[];
    final toUpdate = <DeviceContactUpdate>[];
    // Device ids we intend to keep — everything else in the label is ours to
    // reclaim.
    final keepDeviceIds = <String>{};
    var unchanged = 0;
    for (final entry in desired.entries) {
      final link = links[entry.key];
      final alive =
          link != null &&
          (memberIds == null || memberIds.contains(link.deviceContactId));
      if (!alive) {
        // No link at all, or one whose card is gone. Either way, create — the
        // upsert re-points the link row, since it is keyed by source id.
        toCreate.add(entry.value.card);
        continue;
      }
      keepDeviceIds.add(link.deviceContactId);
      if (link.hash == entry.value.hash) {
        unchanged++;
      } else {
        toUpdate.add(
          DeviceContactUpdate(
            deviceId: link.deviceContactId,
            card: entry.value.card,
          ),
        );
      }
    }

    // Links whose client or contact is gone (deleted, archived, or filtered out
    // by the scope).
    final staleSourceIds = [
      for (final sourceId in links.keys)
        if (!desired.containsKey(sourceId)) sourceId,
    ];
    final toDelete = <String>{
      for (final sourceId in staleSourceIds) links[sourceId]!.deviceContactId,
    };

    // Heal against the label. Anything in it we're not keeping is
    // ours-but-forgotten — a `logout()` wipe of the link table, or a pass that
    // died between the OS write and the Drift write. Without this those cards
    // would be stranded on the device forever, and the next run would create
    // duplicates alongside them.
    if (memberIds != null) {
      for (final memberId in memberIds) {
        if (!keepDeviceIds.contains(memberId)) toDelete.add(memberId);
      }
    }

    final total = toCreate.length + toUpdate.length + toDelete.length;
    onProgress?.call(0, total);
    var done = 0;
    var summary = ContactsSyncSummary(
      unchanged: unchanged,
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
    if (staleSourceIds.isNotEmpty) {
      await _db.deviceContactLinkDao.deleteBySourceIds(
        companyId: companyId,
        sourceIds: staleSourceIds,
      );
    }
    summary = summary.copyWith(deleted: toDelete.length);

    for (final chunk in _chunks(toCreate)) {
      if (isCancelled()) {
        return summary.copyWith(outcome: ContactsSyncOutcome.cancelled);
      }
      final ids = await _device.createContacts(chunk, groupId: groupId);
      // Persist the links immediately, chunk by chunk. Deferring to the end
      // would mean a mid-pass crash left real device contacts with no link row
      // — recoverable only via the group heal, and not at all without a label.
      await _db.deviceContactLinkDao.upsertAll([
        for (var i = 0; i < chunk.length && i < ids.length; i++)
          _link(
            companyId: companyId,
            sourceId: chunk[i].sourceId,
            deviceContactId: ids[i],
            hash: desired[chunk[i].sourceId]!.hash,
          ),
      ]);
      done += chunk.length;
      onProgress?.call(done, total);
    }
    summary = summary.copyWith(created: toCreate.length);

    for (final chunk in _chunks(toUpdate)) {
      if (isCancelled()) {
        return summary.copyWith(outcome: ContactsSyncOutcome.cancelled);
      }
      await _device.updateContacts(chunk);
      await _db.deviceContactLinkDao.upsertAll([
        for (final item in chunk)
          _link(
            companyId: companyId,
            sourceId: item.card.sourceId,
            deviceContactId: item.deviceId,
            hash: desired[item.card.sourceId]!.hash,
          ),
      ]);
      done += chunk.length;
      onProgress?.call(done, total);
    }
    summary = summary.copyWith(updated: toUpdate.length);

    _log.info(
      'contacts sync for $companyId: +${summary.created} ~${summary.updated} '
      '-${summary.deleted} =${summary.unchanged}'
      '${groupId == null ? ' (no label)' : ''}',
    );
    return summary;
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
  @override
  Future<void> removeAll({required String companyId}) async {
    if (!_device.canSync) return;
    try {
      final links = await _db.deviceContactLinkDao.byCompany(companyId);
      final ids = <String>{
        for (final link in links.values) link.deviceContactId,
      };

      final companyName = (await _db.companiesDao.byId(companyId))?.name ?? '';
      // Find-only: `ensureGroup` would *create* the label on a device that
      // never had one, seconds before deleting it again. A missing label just
      // means there's nothing of ours left to enumerate.
      final groupId = await _device.findGroup(labelFor(companyName));
      if (groupId != null) {
        ids.addAll(await _device.groupMemberIds(groupId));
      }

      for (final chunk in _chunks(ids.toList())) {
        await _device.deleteContacts(chunk);
      }
      // Members first, then the label — deleting a group does not delete its
      // contacts, and doing it the other way round strands every card.
      if (groupId != null) await _device.deleteGroup(groupId);
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
    required String hash,
  }) => DeviceContactLinksCompanion(
    companyId: Value(companyId),
    sourceId: Value(sourceId),
    deviceContactId: Value(deviceContactId),
    hash: Value(hash),
    updatedAt: Value(_now().millisecondsSinceEpoch),
  );

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
