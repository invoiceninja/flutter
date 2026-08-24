/// Which clients a contacts-sync pass covers.
///
/// The issue this feature came from ([invoiceninja/flutter#54]) asked for it
/// explicitly — *"can't just have any and every user syncing the entire list of
/// contacts"* — so a staff user on a shared account can push only their own
/// book rather than the whole company's.
enum ContactsSyncScope {
  /// Every active client in the company.
  all('all'),

  /// Only clients whose `assigned_user_id` is the signed-in user.
  assignedToMe('mine');

  const ContactsSyncScope(this.id);

  /// Stable id persisted in `nav_state.contacts_sync_json`. Never rename these
  /// — a stored preference would silently fall back to [all], which on a large
  /// account means an unexpected flood of cards.
  final String id;

  static ContactsSyncScope fromId(String? id) => switch (id) {
    'mine' => ContactsSyncScope.assignedToMe,
    _ => ContactsSyncScope.all,
  };
}

/// Why a pass did nothing, or that it ran. Drives what the settings card tells
/// the user; a silent no-op is the one outcome this feature can't afford.
enum ContactsSyncOutcome {
  ok,

  /// Not iOS/Android — the section shouldn't have been reachable at all.
  unsupported,

  /// The user hasn't granted full contacts access (including iOS 18's
  /// "selected contacts", which can't support a reconcile).
  permissionMissing,

  /// No signed-in company to read clients from.
  noCompany,

  /// Scope is "assigned to me" but the signed-in user has no id, so there is
  /// nothing to filter on. **Fails closed on purpose**: the alternative is
  /// syncing every client in the company, which is the precise outcome the
  /// scope picker exists to prevent (invoiceninja/flutter#54).
  noUser,

  /// Stopped at a chunk boundary — logout, or the user switched it off
  /// mid-pass. Whatever was written stays written and the next run continues.
  cancelled,

  /// The pass threw. Partial writes are safe: the link table records exactly
  /// what reached the device, so a re-run picks up where this left off.
  failed,
}

/// What one contacts-sync pass did. Every count is of *cards*, not clients.
class ContactsSyncSummary {
  const ContactsSyncSummary({
    this.outcome = ContactsSyncOutcome.ok,
    this.created = 0,
    this.updated = 0,
    this.deleted = 0,
    this.unchanged = 0,
    this.labelled = true,
    this.error,
  });

  const ContactsSyncSummary.failed(Object this.error)
    : outcome = ContactsSyncOutcome.failed,
      created = 0,
      updated = 0,
      deleted = 0,
      unchanged = 0,
      labelled = true;

  final ContactsSyncOutcome outcome;
  final int created;
  final int updated;
  final int deleted;

  /// Cards whose content hash matched, so nothing was written to the device.
  /// The number that should dominate on a repeat sync.
  final int unchanged;

  /// False when the device had no contacts account to hang a label on, so the
  /// cards were written without one (see `DeviceContactsService.ensureGroup`).
  final bool labelled;

  final Object? error;

  bool get didWrite => created > 0 || updated > 0 || deleted > 0;

  ContactsSyncSummary copyWith({
    ContactsSyncOutcome? outcome,
    int? created,
    int? updated,
    int? deleted,
    int? unchanged,
    bool? labelled,
  }) => ContactsSyncSummary(
    outcome: outcome ?? this.outcome,
    created: created ?? this.created,
    updated: updated ?? this.updated,
    deleted: deleted ?? this.deleted,
    unchanged: unchanged ?? this.unchanged,
    labelled: labelled ?? this.labelled,
    error: error,
  );
}

/// What [ContactsSyncController] drives.
///
/// A narrow interface rather than the concrete `ContactsSyncService` so the
/// controller — which is pure preference + single-flight bookkeeping — unit
/// tests against a fake instead of dragging in `ClientRepository`, the Drift
/// database and the platform seam. Mirrors the `ResyncRunner` seam on
/// `ResyncController`, widened to an interface because there are four calls.
abstract class ContactsSyncEngine {
  /// [refreshClients] decides whether the pass re-downloads clients before
  /// reading them. **The caller owns this**, because the answer depends on what
  /// just happened: the post-Sync hook runs immediately after a pass that
  /// already refreshed everything, and refreshing again there is a second full
  /// page-walk of the whole client list for nothing.
  Future<ContactsSyncSummary> run({
    required String companyId,
    required ContactsSyncScope scope,
    required bool isFirstRun,
    bool refreshClients,
    bool Function()? isCancelled,
    void Function(int done, int total)? onProgress,
  });

  Future<void> removeAll({required String companyId});

  /// How many cards a pass would write right now — the number the pre-flight
  /// dialog shows before the first run touches the address book.
  ///
  /// [refreshClients] must be **true** for that dialog. The local cache holds
  /// only page 1 per entity until the user browses, so counting straight off
  /// Drift on a fresh install reports ~50 for an account with thousands — and
  /// the whole point of the dialog is that the number is trustworthy.
  Future<int> previewCardCount({
    required String companyId,
    required ContactsSyncScope scope,
    bool refreshClients,
  });

  /// Companies this install has written cards for, including ones not opened
  /// this session. The logout cleanup must reach all of them.
  Future<List<String>> companiesWithSyncedContacts();
}
