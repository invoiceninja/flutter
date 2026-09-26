import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/data/db/app_database.dart';

final _log = Logger('UserSettingsRepository');

/// `entity_type` value used in the outbox row for user settings updates.
/// `EntityRegistry` routes rows with this wire name to the
/// `UserSettingsSyncDispatcher`.
const String kUserSettingsWireName = 'user_settings';

/// Read/write per-(user, company) settings (in particular: `table_columns`).
///
/// Format is intentionally identical to the old admin-portal's storage at
/// `userCompany.settings.table_columns` — same map key format
/// (`'$EntityType.<entity>'`) and same snake_case column-id values — so a
/// list customised in either app shows up in the other.
class UserSettingsRepository {
  UserSettingsRepository({
    required this.db,
    Uuid uuid = const Uuid(),
    DateTime Function()? now,
    this.onEnqueued,
  }) : _uuid = uuid,
       _now = now ?? DateTime.now;

  final AppDatabase db;
  final Uuid _uuid;
  final DateTime Function() _now;

  /// Fire-and-forget hook invoked after an outbox row is written. Wired by
  /// DI to `SyncRepository.drainOnce` so settings updates drain immediately
  /// when online. Same contract as [BaseEntityRepository.onEnqueued].
  final void Function(String companyId)? onEnqueued;

  /// Watch the column id list for [entityType] in [companyId]. Emits the
  /// stored list (possibly empty) — callers fall back to a default list when
  /// nothing has been customised yet.
  Stream<List<String>?> watchColumns({
    required String companyId,
    required EntityType entityType,
  }) {
    final key = _tableColumnsKey(entityType);
    return db.userSettingsDao.watch(companyId).map((row) {
      if (row == null) return null;
      return _extractColumns(row.tableColumnsJson, key);
    });
  }

  Future<List<String>?> getColumns({
    required String companyId,
    required EntityType entityType,
  }) async {
    final row = await db.userSettingsDao.get(companyId);
    if (row == null) return null;
    return _extractColumns(row.tableColumnsJson, _tableColumnsKey(entityType));
  }

  /// Persist the column list locally (so the UI reacts immediately) and
  /// enqueue an outbox row for the server PUT.
  ///
  /// If a pending (non-in-flight) outbox row already exists for this
  /// `(companyId, user_settings)` pair, replace its payload instead of
  /// queueing a second one — settings updates are idempotent and the
  /// outbox should not pile up duplicates while the user is rapidly
  /// toggling columns.
  ///
  /// The read of the stored columns is inside the write's transaction: two
  /// quick toggles read the same row outside it, and the second write lost
  /// the first's change. The drain is kicked after the commit.
  Future<void> setColumns({
    required String companyId,
    required EntityType entityType,
    required List<String> columns,
  }) async {
    final queued = await db.transaction(() async {
      final existing = await db.userSettingsDao.get(companyId);
      if (existing == null) {
        _log.warning(
          'setColumns called before settings hydrated for $companyId; '
          'skipping.',
        );
        return false;
      }

      final key = _tableColumnsKey(entityType);
      final tableColumns = _decodeTableColumns(existing.tableColumnsJson);
      // Idempotent: bail before any local write or outbox enqueue when the
      // column list is unchanged. Without this, applying a saved view (whose
      // snapshot captured the current columns) — or the column picker
      // re-selecting the same set — pushes a no-op `user_settings` PUT into
      // the outbox.
      if (_sameColumns(tableColumns[key], columns)) return false;
      tableColumns[key] = columns;
      await _writeAndEnqueue(companyId, existing, tableColumns);
      return true;
    });
    if (queued) onEnqueued?.call(companyId);
  }

  /// Restore the default column list (i.e. drop the entry from
  /// `table_columns` so the UI falls back to the registry default).
  Future<void> resetColumns({
    required String companyId,
    required EntityType entityType,
  }) async {
    final queued = await db.transaction(() async {
      final existing = await db.userSettingsDao.get(companyId);
      if (existing == null) return false;
      final tableColumns = _decodeTableColumns(existing.tableColumnsJson)
        ..remove(_tableColumnsKey(entityType));
      await _writeAndEnqueue(companyId, existing, tableColumns);
      return true;
    });
    if (queued) onEnqueued?.call(companyId);
  }

  /// Write [tableColumns] locally and queue (or collapse into) the PUT that
  /// carries them. Inside the caller's transaction.
  Future<void> _writeAndEnqueue(
    String companyId,
    UserSettingsRow existing,
    Map<String, List<String>> tableColumns,
  ) async {
    final nowMs = _now().millisecondsSinceEpoch;
    await db.userSettingsDao.writeTableColumns(
      companyId: companyId,
      tableColumnsJson: jsonEncode(tableColumns),
      now: nowMs,
    );
    await _enqueueOrCollapse(
      companyId: companyId,
      userId: existing.userId,
      body: _buildPutBody(
        userId: existing.userId,
        extraSettings: _decodeAny(existing.extraJson),
        tableColumns: tableColumns,
      ),
      nowMs: nowMs,
    );
  }

  /// Server replied to our PUT with the canonical UserCompany shape — write
  /// it back so the local cache matches.
  Future<void> applyServerResponse({
    required String companyId,
    required Map<String, dynamic> response,
  }) async {
    final data = response['data'];
    if (data is! Map<String, dynamic>) return;
    final settings = data['settings'];
    if (settings is! Map<String, dynamic>) return;
    final user = data['user'];
    var userId = user is Map<String, dynamic>
        ? (user['id']?.toString() ?? '')
        : '';
    // The PUT /user response doesn't always echo the `user` block. `user_id`
    // is a required column, and `upsert` runs through `insertOnConflictUpdate`
    // which validates insert integrity even when the row already exists — an
    // absent userId throws InvalidDataException and parks the sync drain. Fall
    // back to the userId already persisted locally (written at login from
    // `data[N].user`); it's stable for the (user, company) pair.
    if (userId.isEmpty) {
      userId = (await db.userSettingsDao.get(companyId))?.userId ?? '';
    }
    if (userId.isEmpty) {
      _log.warning(
        'Skipping user_settings write for $companyId: no userId in server '
        'response and no local row to fall back to',
      );
      return;
    }
    final tableColumnsRaw = settings['table_columns'];
    final tableColumns = tableColumnsRaw is Map<String, dynamic>
        ? tableColumnsRaw
        : <String, dynamic>{};
    final extra = Map<String, dynamic>.from(settings)..remove('table_columns');
    final nowMs = _now().millisecondsSinceEpoch;
    await db.userSettingsDao.upsert(
      UserSettingsCompanion(
        companyId: Value(companyId),
        userId: Value(userId),
        tableColumnsJson: Value(jsonEncode(tableColumns)),
        extraJson: Value(jsonEncode(extra)),
        updatedAt: Value(nowMs),
      ),
    );
  }

  Future<void> _enqueueOrCollapse({
    required String companyId,
    required String userId,
    required Map<String, dynamic> body,
    required int nowMs,
  }) async {
    final existing = await db.outboxDao.findPending(
      companyId: companyId,
      entityType: kUserSettingsWireName,
    );
    if (existing != null &&
        await db.outboxDao.updatePayload(
          id: existing.id,
          payload: jsonEncode(body),
        )) {
      return;
    }
    await db.outboxDao.enqueue(
      OutboxCompanion.insert(
        companyId: companyId,
        entityType: kUserSettingsWireName,
        entityId: userId,
        mutationKind: MutationKind.update.wireName,
        payload: jsonEncode(body),
        idempotencyKey: _uuid.v4(),
        nextAttemptAt: nowMs,
        createdAt: nowMs,
      ),
    );
  }

  /// Build the PUT body that mirrors what the old admin-portal sends — a
  /// serialized UserEntity carrying `company_user.settings`. We omit the
  /// rest of UserEntity (email, first_name, …) because the new app doesn't
  /// model it; the server treats this as a partial update.
  Map<String, dynamic> _buildPutBody({
    required String userId,
    required Map<String, dynamic> extraSettings,
    required Map<String, List<String>> tableColumns,
  }) {
    final mergedSettings = <String, dynamic>{
      ...extraSettings,
      'table_columns': tableColumns,
    };
    return <String, dynamic>{
      'id': userId,
      'company_user': <String, dynamic>{'settings': mergedSettings},
    };
  }

  /// Old admin-portal uses `'$EntityType.client'` (the literal Dart enum
  /// toString) as the map key — must preserve that exactly.
  String _tableColumnsKey(EntityType entityType) =>
      'EntityType.${entityType.name}';

  /// Order-sensitive equality for two column-id lists. A missing stored
  /// list (`null`) only matches an empty incoming list.
  bool _sameColumns(List<String>? a, List<String> b) {
    final current = a ?? const <String>[];
    if (current.length != b.length) return false;
    for (var i = 0; i < b.length; i++) {
      if (current[i] != b[i]) return false;
    }
    return true;
  }

  Map<String, List<String>> _decodeTableColumns(String raw) {
    if (raw.isEmpty) return <String, List<String>>{};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return <String, List<String>>{};
    final out = <String, List<String>>{};
    for (final entry in decoded.entries) {
      final v = entry.value;
      if (v is List) {
        out[entry.key.toString()] = v.map((e) => e.toString()).toList();
      }
    }
    return out;
  }

  Map<String, dynamic> _decodeAny(String raw) {
    if (raw.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }

  List<String>? _extractColumns(String raw, String key) {
    final map = _decodeTableColumns(raw);
    return map[key];
  }
}
