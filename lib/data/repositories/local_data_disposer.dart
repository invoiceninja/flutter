import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';

final _log = Logger('LocalDataDisposer');

/// What ending a session does with this device's copy of the user's data.
/// `AuthRepository.logout` takes it as a REQUIRED argument: the old
/// `preserveLocalData = false` default meant a caller that never thought
/// about it destroyed every company's unsynced work.
enum LocalDataPolicy {
  /// Keep the database, the outbox and the on-disk tokens, and set the
  /// re-lock gate so the next `restore()` demands re-auth: an involuntary end
  /// — a 401, an idle timeout with unsynced work.
  keep,

  /// [keep] without the re-lock gate — for an end where nothing was unlocked
  /// (`restore()`'s own bounce, a Danger Zone fallback).
  keepUnlocked,

  /// Wipe everything. Only once the user has been shown the unsynced work
  /// this destroys (`confirmPendingOutboxIfAny(checkAllCompanies: true)`), or
  /// when there is none.
  destroy,
}

/// Why local data is being destroyed — logged with every wipe, so the
/// diagnostics log names the cause next to what went with it.
enum DisposalReason {
  /// A session ended with [LocalDataPolicy.destroy].
  sessionEnded,

  /// A different user, account or server is signing in on this device. The
  /// outgoing identity's rows could never be sent under the new token, and
  /// leaving them would show one user's data to another
  /// (`AuthRepository._wipeIfIdentityChanged`).
  identityChanged,

  /// The company was purged or deleted on the server, so its local rows —
  /// unsynced changes included — describe nothing (the Danger Zone).
  companyGoneOnServer,
}

/// The one owner of destroying local data: the whole database, or one
/// company's rows. The store is the only home of the user's unsynced work
/// (the outbox, `id_remap`, dirty and `tmp_` rows), so every wipe goes through
/// here, says why, and logs what it takes with it.
/// `test/lint/local_data_disposal_test.dart` fails the build on a wipe — or a
/// destructive outbox delete — anywhere this file and the sync engine don't
/// own.
class LocalDataDisposer {
  LocalDataDisposer(this._db);

  final AppDatabase _db;

  Future<void> wipeAll(DisposalReason reason) async {
    await _logWhatGoes(reason);
    await _db.wipe();
  }

  Future<void> wipeCompany(String companyId, DisposalReason reason) async {
    await _logWhatGoes(reason, companyId: companyId);
    await _db.wipeForCompany(companyId);
  }

  /// WARNING, so it reaches the diagnostics log: a wipe that took unsynced
  /// work is the first thing to look for when a user says their changes
  /// vanished. Best-effort — counting must never block the wipe.
  Future<void> _logWhatGoes(DisposalReason reason, {String? companyId}) async {
    try {
      final rows = await _db.select(_db.outbox).get();
      final byState = <String, int>{};
      for (final row in rows) {
        if (companyId != null && row.companyId != companyId) continue;
        byState[row.state] = (byState[row.state] ?? 0) + 1;
      }
      _log.warning(
        'Wiping local data (${reason.name})'
        '${companyId == null ? '' : ' for company $companyId'}; '
        'unsynced outbox rows going with it: '
        '${byState.isEmpty ? 'none' : byState}',
      );
    } catch (e) {
      _log.warning('Wiping local data (${reason.name}); counting failed: $e');
    }
  }
}
