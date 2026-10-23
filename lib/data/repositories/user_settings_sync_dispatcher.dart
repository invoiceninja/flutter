import 'dart:convert';

import 'package:logging/logging.dart';

import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/domain/sync/sync_dispatcher.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/services/user_settings_api.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';

final _log = Logger('UserSettingsSyncDispatcher');

/// Drains `user_settings` outbox rows by PUTting them to
/// `/api/v1/company_users/{userId}` and writing the canonical response back
/// into the local cache, and `user_preferences` rows by PUTting
/// `react_settings` to `/api/v1/company_users/{userId}/preferences`.
class UserSettingsSyncDispatcher implements SyncDispatcher {
  UserSettingsSyncDispatcher({required this.api, required this.repo});

  final UserSettingsApi api;
  final UserSettingsRepository repo;

  // No offline create-with-tmp-id flow → a discarded ghost create can
  // never route here. See SyncDispatcher.deleteLocalRecord.
  @override
  Future<void> deleteLocalRecord({
    required String companyId,
    required String id,
  }) async {}

  // user_settings is a single-row settings table with no `is_dirty` column;
  // its dirtiness is tracked by the outbox row's presence, not a flag, so
  // there is nothing to clear on discard.
  @override
  Future<void> clearLocalDirty({
    required String companyId,
    required String id,
  }) async {}

  @override
  Future<void> dispatch({
    required OutboxRow row,
    required MutationKind kind,
  }) async {
    // User settings only support `update`; the registry never produces other
    // kinds here. Ignore [kind] but assert in debug.
    assert(kind == MutationKind.update);
    if (row.entityType == kUserPreferencesWireName) {
      return _dispatchPreferences(row);
    }
    final body = jsonDecode(row.payload) as Map<String, dynamic>;
    final response = await api.update(
      userId: row.entityId,
      body: body,
      idempotencyKey: row.idempotencyKey,
    );
    if (response != null) {
      await repo.applyServerResponse(
        companyId: row.companyId,
        response: response,
      );
    }
  }

  /// The row holds only a patch; the server replaces the whole blob. So the
  /// body is the freshest local copy with the patch laid over it — the local
  /// copy already carries it, but a capture may have raced the patch's write.
  Future<void> _dispatchPreferences(OutboxRow row) async {
    final current = await repo.getReactSettings(row.companyId);
    if (current == null) {
      // Only reachable when the cache table was dropped after the patch was
      // queued. Sending the patch over nothing would wipe React's settings;
      // the change stays on this device until the user makes it again.
      _log.warning(
        'Dropping react_settings patch for ${row.companyId}: the blob is no '
        'longer known locally',
      );
      return;
    }
    await api.updatePreferences(
      userId: row.entityId,
      reactSettings: applyReactSettingsPatch(
        current,
        reactSettingsPatchOf(row.payload),
      ),
      idempotencyKey: row.idempotencyKey,
    );
  }
}
