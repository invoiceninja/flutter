import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart'
    show Value, BooleanExpressionOperators, Table, TableInfo, Variable;
import 'package:logging/logging.dart';

import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/domain/columns/ids/client_column_ids.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/billing_extra_filters.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/gateway_token.dart';
import 'package:admin/data/models/domain/location.dart';
import 'package:admin/data/services/clients_api.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/tag_denormalization.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/repositories/document_bearing_repository.dart';
import 'package:admin/data/models/value/parsing.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';

final _log = Logger('ClientRepository');

/// Source of truth for Client data. The UI watches Drift via [watchPage]
/// and [watch]; the network only writes. Every mutation goes through the
/// outbox.
///
/// Page size is fixed at [pageSize]. Subsequent pages are fetched only on
/// demand — list screens call [ensurePageLoaded] near the scroll edge.
class ClientRepository extends BaseEntityRepository<Client, ClientApi>
    implements DocumentBearingRepository {
  ClientRepository({
    required super.db,
    required this.api,
    super.uuid,
    super.now,
    super.onEnqueued,
    this.pageSize = 50,
  }) : super(
         entityType: EntityType.client,
         requiresPasswordFor: const {
           MutationKind.delete,
           MutationKind.purge,
           MutationKind.documentDelete,
           MutationKind.merge,
         },
       );

  final ClientsApi api;
  final int pageSize;

  @override
  String get entityTypeName => 'client';

  /// Watch the first [loadedPages] pages worth of rows (so an infinite-scroll
  /// list shows everything fetched so far). [loadedPages] is 1-based — 1
  /// means "show page 1," 2 means "show pages 1+2 contiguously," etc.
  Stream<List<Client>> watchPage({
    required String companyId,
    int loadedPages = 1,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = ClientFieldIds.name,
    bool sortAscending = true,
    Map<int, Set<String>> customFilters = const {},
    Map<String, Set<String>> extraFilters = const {},
    // Status-tab filter — see `list_status_tabs.dart`.
    String? badgeModeId,
  }) {
    assert(
      loadedPages >= 1,
      'loadedPages is 1-based; pass 1 for the first page',
    );
    // `name` is `singleValue: true` on its FilterKey, so there is at most
    // one entry — take the first. Membership-id keys (country, industry,
    // …) still need their own predicates; tracked as follow-ups.
    final nameValues = extraFilters['name'];
    final nameContains = (nameValues == null || nameValues.isEmpty)
        ? null
        : nameValues.first;
    final balance = _parseBalanceWire(extraFilters['balance']);
    // `DateColumnFilterKey` between windows: `updated`/`created` store a
    // closed `[start, end]` window in `updated_at_range` / `created_at_range`.
    final updated = parseUpdatedAtRangeFilter(extraFilters);
    final created = parseCreatedAtRangeFilter(extraFilters);
    // …and the SINGLE-date comparators (>, >=, <, <=, =), which live in the
    // bare `updated_at` / `created_at` slot as an `op:value` wire. Only the
    // range slot was read here, so a bare `updated:2026-06-01` (defaultOp
    // `gte`) narrowed the server fetch while the local watch applied nothing.
    // These columns are epoch seconds, so the comparator resolves to the same
    // from/to day bounds the range path already uses.
    final updatedCmp = _epochBoundsFor(
      parseComparableDateFilter(extraFilters, 'updated_at'),
    );
    final createdCmp = _epochBoundsFor(
      parseComparableDateFilter(extraFilters, 'created_at'),
    );
    return db.clientDao
        .watchPage(
          badgeModeId: badgeModeId,
          companyId: companyId,
          offset: 0,
          limit: pageSize * loadedPages,
          search: search,
          states: states,
          sortField: sortField,
          sortAscending: sortAscending,
          customValues1: customFilters[1] ?? const {},
          customValues2: customFilters[2] ?? const {},
          customValues3: customFilters[3] ?? const {},
          customValues4: customFilters[4] ?? const {},
          nameContains: nameContains,
          balanceGt: balance.gt,
          balanceLt: balance.lt,
          countryIds: parseCsvFilter(extraFilters, 'country_id'),
          industryIds: parseCsvFilter(extraFilters, 'industry_id'),
          sizeIds: parseCsvFilter(extraFilters, 'size_id'),
          classifications: parseCsvFilter(extraFilters, 'classification'),
          groupSettingsIds: parseCsvFilter(extraFilters, 'group_settings_id'),
          assignedUserIds: parseCsvFilter(extraFilters, 'assigned_user_ids'),
          idNumbers: parseCsvFilter(extraFilters, 'id_number'),
          vatNumberContains: parseSubstringFilter(extraFilters, 'vat_number'),
          numberExact: parseSubstringFilter(extraFilters, 'number'),
          updatedFrom: _isoDayStartEpoch(updated.start) ?? updatedCmp.from,
          updatedTo: _isoDayEndEpoch(updated.end) ?? updatedCmp.to,
          createdFrom: _isoDayStartEpoch(created.start) ?? createdCmp.from,
          createdTo: _isoDayEndEpoch(created.end) ?? createdCmp.to,
        )
        .map((rows) {
          final items = rows.map(_fromRow);
          // `tag_ids` lives only in the payload JSON — post-decode predicate
          // over the loaded page (the list VM strips it from the server fetch
          // and auto-chains page loads to converge).
          final tagIds = parseCsvFilter(extraFilters, 'tag_ids');
          if (tagIds.isEmpty) return items.toList(growable: false);
          return items
              .where((c) => matchesTagIdFilter(c.tagIds, tagIds))
              .toList(growable: false);
        });
  }

  /// Extracts the numeric (gt, lt) thresholds from a `BalanceFilterKey`
  /// wire for the **local** Drift query. The canonical wire is now the
  /// prefix form `op:value` (`gt:1000` / `lt:1000`); the legacy suffix
  /// form (`1000:gt`) is still decoded so persisted state from any prior
  /// app version still narrows correctly.
  ///
  /// Only `gt` / `lt` have a local Drift predicate. The extended
  /// operators `gte` / `lte` / `eq` (added with the segmented-chip work)
  /// filter **server-side only** — they fall through to `(null, null)`
  /// here, so the freshly-fetched server page is authoritative and the
  /// local watch applies no extra balance predicate. Returns
  /// `(null, null)` for missing, empty, or unparseable input too.
  ({double? gt, double? lt}) _parseBalanceWire(Set<String>? values) {
    final wire = (values == null || values.isEmpty) ? null : values.first;
    if (wire == null) return (gt: null, lt: null);
    double? parse(String s) => double.tryParse(s.trim());
    // Canonical prefix (primary).
    if (wire.startsWith('gt:')) return (gt: parse(wire.substring(3)), lt: null);
    if (wire.startsWith('lt:')) return (gt: null, lt: parse(wire.substring(3)));
    // Legacy suffix (self-heal: rewritten to canonical on next edit).
    if (wire.endsWith(':gt')) {
      return (gt: parse(wire.substring(0, wire.length - 3)), lt: null);
    }
    if (wire.endsWith(':lt')) {
      return (gt: null, lt: parse(wire.substring(0, wire.length - 3)));
    }
    return (gt: null, lt: null);
  }

  /// Distinct non-empty values populated by clients in `companyId` for the
  /// given custom column (1..4). Drives the bottom-sheet option list for
  /// custom-field filtering.
  Stream<List<String>> watchDistinctCustomValues({
    required String companyId,
    required int columnIndex,
  }) => db.clientDao.watchDistinctCustomValues(
    companyId: companyId,
    columnIndex: columnIndex,
  );

  /// Live non-deleted client count for [companyId]. Drives the sidebar
  /// badge; emits every time a client is added, archived, or deleted.
  Stream<int> watchCount({required String companyId}) =>
      db.clientDao.watchCount(companyId: companyId);

  /// Live count behind this entity's sidebar counter badge. [modeId] is one of
  /// the entity's `SidebarBadgeMode` ids; [currentUserId] is read only by the
  /// `assigned_to_me` mode.
  Stream<int> watchBadgeCount({
    required String companyId,
    String modeId = kBadgeModeTotal,
    String currentUserId = '',
  }) => db.clientDao.watchBadgeCount(
    companyId: companyId,
    modeId: modeId,
    currentUserId: currentUserId,
  );

  /// Cheap `(id, displayName)` stream for active clients — used by the
  /// shared `ClientFilterKey` (suggestion menu + chip display name) on
  /// every list screen that filters by client (invoices, quotes, credits,
  /// recurring invoices, payments, expenses, projects).
  Stream<List<({String id, String name})>> watchActiveNames({
    required String companyId,
  }) => db.clientDao.watchActiveNames(companyId: companyId);

  /// One page of clients for the contacts-sync reconcile, decoded to domain
  /// objects. See [ClientDao.pageForContactSync] for why this is paged and
  /// non-streaming. A page shorter than [limit] is the last one.
  Future<List<Client>> pageForContactSync({
    required String companyId,
    required int offset,
    required int limit,
    String? assignedUserId,
  }) async {
    final rows = await db.clientDao.pageForContactSync(
      companyId: companyId,
      offset: offset,
      limit: limit,
      assignedUserId: assignedUserId,
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Stream<Client?> watchByRealId({
    required String companyId,
    required String id,
  }) => db.clientDao
      .watchById(companyId: companyId, id: id)
      .map((row) => row == null ? null : _fromRow(row));

  /// Fetch one page from the server and upsert into Drift.
  ///
  /// Idempotent: calling for the same page repeatedly is safe (Drift upserts
  /// are by id). Advances the cursor only on a successful page that returned
  /// data.
  ///
  /// [states] drives the server-side `client_status` filter. Without it, the
  /// cursor only pulls `(updated_at, id)` slices and the local cache would
  /// be missing archived/deleted rows even when the user has toggled them on.
  ///
  /// [extraFilters] is an open-ended map of flat server query params
  /// (`country_id`, `group_settings_id`, …) populated from the token search
  /// field. Each value set is comma-joined.
  Future<bool> ensurePageLoaded({
    required String companyId,
    required int page,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    Map<String, Set<String>> extraFilters = const {},
    bool ignoreCursor = false,
  }) => ensurePageLoadedTemplate(
    companyId: companyId,
    page: page,
    pageSize: pageSize,
    search: search,
    states: states,
    extraFilters: _dateRangesForServer(extraFilters),
    ignoreCursor: ignoreCursor,
    // `?include=documents` makes the list response authoritative for the
    // `documents` array. Without it the server omits documents on list
    // calls — see `_apiToCompanion`'s `Value.absent()` guard — so docs
    // uploaded from another device would never appear locally.
    staticFilters: const {'include': 'documents'},
    listCall: api.list,
    itemsOf: (l) => l.data,
    idOf: (a) => a.id,
    toCompanion: (a) => _apiToCompanion(a, companyId),
    upsert: (byId) =>
        db.clientDao.upsertAllPreservingDirty(companyId: companyId, byId: byId),
  );

  /// Rewrite the `DateColumnFilterKey` between-window slots into the params
  /// the server actually honors before they hit the wire. The `created`/
  /// `updated` keys store a 3-part `<column>,<start>,<end>` window under
  /// `created_at_range` / `updated_at_range` — but the server has **no**
  /// handler by those names (`QueryFilters::apply()` silently skips unknown
  /// params), so the window would narrow only the local Drift cache and the
  /// list would return an incomplete (server-unfiltered) set. The honored
  /// params are `created_between` / `updated_between` with a 2-part
  /// `<start>,<end>` CSV (`QueryFilters::{created,updated}_between` →
  /// `whereBetween`). Strip the leading column token (keep the last two
  /// comma parts) and re-key. Single-date `created_at`/`updated_at` filters
  /// already work (prefix `gte:`), so only the window slots are remapped.
  ///
  /// Returns the input untouched (same instance) when neither window slot is
  /// present, so the common path allocates nothing. The local `watchPage`
  /// keeps reading the original `_at_range` keys — only the server fetch is
  /// rewritten here.
  static const Map<String, String> _dateRangeServerParams = {
    'created_at_range': 'created_between',
    'updated_at_range': 'updated_between',
  };

  Map<String, Set<String>> _dateRangesForServer(
    Map<String, Set<String>> extraFilters,
  ) {
    if (!extraFilters.keys.any(_dateRangeServerParams.containsKey)) {
      return extraFilters;
    }
    final out = <String, Set<String>>{};
    for (final entry in extraFilters.entries) {
      final serverKey = _dateRangeServerParams[entry.key];
      if (serverKey == null) {
        out[entry.key] = entry.value;
        continue;
      }
      final converted = <String>{};
      for (final wire in entry.value) {
        final parts = wire.split(',');
        if (parts.length < 2) continue;
        final start = parts[parts.length - 2].trim();
        final end = parts[parts.length - 1].trim();
        if (start.isEmpty || end.isEmpty) continue;
        converted.add('$start,$end');
      }
      if (converted.isNotEmpty) out[serverKey] = converted;
    }
    return out;
  }

  /// Lazily hydrate one client by id when a reference (e.g. an invoice's
  /// client) isn't in the prefetched page so a `*NameLabel` would show
  /// the raw id. See [ensureLoadedTemplate].
  Future<void> ensureLoaded({required String companyId, required String id}) =>
      ensureLoadedTemplate(
        companyId: companyId,
        id: id,
        fetch: (id) async => (await api.get(id)).data,
        idOf: (a) => a.id,
        toCompanion: (a) => _apiToCompanion(a, companyId),
        upsert: (byId) => db.clientDao.upsertAllPreservingDirty(
          companyId: companyId,
          byId: byId,
        ),
      );

  /// Force-refetches [ids] dirty-preserving (the non-cache-gated sibling of
  /// [ensureLoaded]) to converge a client's balance/paid_to_date after a mutation
  /// on another entity (payment, invoice, merge, …) changed it server-side.
  /// See [refreshByIdsTemplate] for the load-bearing per-id error swallow.
  @override
  Future<void> refreshByIds({
    required String companyId,
    required Iterable<String> ids,
  }) async {
    await refreshByIdsTemplate<ClientApi, ClientsCompanion>(
      companyId: companyId,
      ids: ids,
      fetch: (id) async => (await api.get(id)).data,
      idOf: (a) => a.id,
      toCompanion: (a) => _apiToCompanion(a, companyId),
      upsert: (byId) => db.clientDao.upsertAllPreservingDirty(
        companyId: companyId,
        byId: byId,
      ),
    );
  }

  /// After a client **merge**, the absorbed client's children were reassigned to
  /// the survivor server-side, but locally they still carry the old client_id in
  /// their `payload` JSON (a column-only rewrite wouldn't fix the domain, which
  /// reads client_id from the payload). Return their local ids grouped by type
  /// so the merge handler can force-refetch them — the refetch lands the new
  /// client_id. Read off the dedicated `client_id` COLUMN, still the old id here.
  Future<Map<EntityType, Set<String>>> childIdsForClient({
    required String companyId,
    required String clientId,
  }) async {
    final tables = <EntityType, TableInfo<Table, dynamic>>{
      EntityType.invoice: db.invoices,
      EntityType.quote: db.quotes,
      EntityType.credit: db.credits,
      EntityType.payment: db.payments,
      EntityType.expense: db.expenses,
      EntityType.task: db.tasks,
      EntityType.project: db.projects,
      EntityType.recurringInvoice: db.recurringInvoices,
      EntityType.recurringExpense: db.recurringExpenses,
    };
    final result = <EntityType, Set<String>>{};
    for (final entry in tables.entries) {
      final table = entry.value;
      final rows = await db
          .customSelect(
            'SELECT id FROM ${table.actualTableName} '
            'WHERE company_id = ?1 AND client_id = ?2',
            variables: [
              Variable<String>(companyId),
              Variable<String>(clientId),
            ],
            readsFrom: {table},
          )
          .get();
      final ids = rows
          .map((r) => r.read<String>('id'))
          .where((id) => id.isNotEmpty)
          .toSet();
      if (ids.isNotEmpty) result[entry.key] = ids;
    }
    return result;
  }

  /// Pull-to-refresh / foreground-resume entry point.
  ///
  /// **[full] resets the cursor; it does NOT shorten the walk.** Page 1 of a
  /// non-full pass does apply the cursor, but `hasMoreAfterPage` returns true
  /// for ANY cursor'd page (deliberately — concluding "end of list" from a
  /// short delta latched `hasMore = false` and capped every warm-session list
  /// at one page), and `shouldReadCursor` then drops the cursor for `page > 1`.
  /// So pages 2..N are plain offset pages of the whole list and the loop only
  /// stops on a short one: both `full: true` and `full: false` cost the same
  /// number of requests. Lists converge on id-keyed upserts plus this periodic
  /// full walk (see CLAUDE.md § Sync); do not read [full] as "cheap refresh".
  ///
  /// Filter-agnostic by design: we pull every state into the local cache so
  /// the UI's state filter can flip between active/archived/deleted without
  /// re-hitting the network. The local watch stream applies the user's
  /// current selection on top.
  Future<void> refreshAll({
    required String companyId,
    bool full = false,
  }) async {
    if (full) {
      await db.syncStateDao.reset(
        companyId: companyId,
        entityType: entityTypeName,
      );
    }
    var page = 1;
    var hasMore = true;
    const maxPages = 1000; // 50 rows × 1000 = 50 000 clients
    final allStates = EntityState.values.toSet();
    while (hasMore) {
      hasMore = await ensurePageLoaded(
        companyId: companyId,
        page: page,
        states: allStates,
        ignoreCursor: full && page == 1,
      );
      page++;
      if (page > maxPages) {
        _log.warning(
          'refreshAll hit the $maxPages page safety cap for company '
          '$companyId — cursor will resume on the next sync trigger.',
        );
        break;
      }
    }
  }

  /// Create a new client offline. Returns the client with its tmp id (so the
  /// UI can navigate to the detail screen immediately) plus the outbox row
  /// id (so `GenericEditViewModel.save()` can await the server's verdict).
  ///
  /// [existingTempId] — when re-saving after a transient/validation failure
  /// on a CREATE form, the VM threads the prior attempt's tmp id back in so
  /// `dedupPendingMutations` finds and deletes the now-stale pending row,
  /// preventing server-side duplicates. Without this, each retry mints a
  /// fresh tmp id and the prior pending row drains as a separate insert.
  Future<SaveResult<Client>> create({
    required String companyId,
    required Client draft,
    String? existingTempId,
  }) async {
    final tmpId = existingTempId ?? mintTempId();
    final stored = draft.copyWith(id: tmpId);
    final companion = _domainToCompanion(stored, companyId, isDirty: true);

    var rowId = 0;
    await db.transaction(() async {
      await db.clientDao.upsert(companion);
      await dedupPendingMutations(
        companyId: companyId,
        entityId: tmpId,
        kind: MutationKind.create,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: tmpId,
        kind: MutationKind.create,
        payload: stored.toApiJson(), // server allocates real id
      );
    });
    return SaveResult(entity: stored, outboxRowId: rowId);
  }

  /// Save an existing client. The local row updates instantly via the watch
  /// stream; the outbox handles the round-trip.
  /// [designDefaultUpdates] carries the Invoice Design "Update all records"
  /// directives (`[{design_id, entity}, …]`) for client scope. Each is enqueued
  /// as a `setDefaultDesign` row **inside the same transaction** as the settings
  /// `update`, so a process kill can't persist the settings change without the
  /// retro-apply. `settings_level` + `client_id` are stamped here.
  Future<SaveResult<Client>> save({
    required String companyId,
    required Client client,
    List<Map<String, dynamic>> designDefaultUpdates = const [],
  }) async {
    // If this entity's offline create already drained while the edit
    // form was open, id_remap now points the tmp id at the real row (the
    // tmp row was deleted). Saving under the stale tmp id would resurrect
    // it as a ghost duplicate — and deleting that ghost would delete the
    // real entity via the remap. Rebind to the real id first.
    final resolvedId = await resolveId(client.id);
    if (resolvedId != client.id) client = client.copyWith(id: resolvedId);

    final companion = _domainToCompanion(client, companyId, isDirty: true);
    var rowId = 0;
    await db.transaction(() async {
      await db.clientDao.upsert(companion);
      await dedupPendingMutations(
        companyId: companyId,
        entityId: client.id,
        kind: MutationKind.update,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: client.id,
        kind: MutationKind.update,
        payload: client.toApiJson(preserveTempId: true),
      );
      for (final u in designDefaultUpdates) {
        await enqueueMutation(
          companyId: companyId,
          entityId: client.id,
          kind: MutationKind.setDefaultDesign,
          payload: {
            'design_id': u['design_id'],
            'entity': u['entity'],
            'settings_level': 'client',
            'client_id': client.id,
          },
        );
      }
    });
    return SaveResult(entity: client, outboxRowId: rowId);
  }

  /// Mass-update one whitelisted column on [client] — the `bulk_update` bulk
  /// action, fired once per selected client by the list ViewModel. Mirrors
  /// [save]: optimistically writes the patched row to Drift (`is_dirty=true`)
  /// so the change shows immediately (online *and* offline), then enqueues a
  /// per-id `MutationKind.bulkUpdate` outbox row carrying `column` +
  /// `new_value`. We patch the full domain row (not just the Drift mirror
  /// column) because `_fromRow` reconstructs the client from the `payload`
  /// JSON — a column-only patch would leave the displayed value stale, and
  /// `public_notes` has no dedicated column at all.
  ///
  /// Unlike [save] this does NOT `dedupPendingMutations`: two bulk-updates on
  /// the same client may target *different* columns, so every queued row must
  /// drain. [column] is one of `Client::$bulk_update_columns` (validated
  /// server-side); see [_applyBulkColumn].
  Future<void> bulkUpdate({
    required String companyId,
    required Client client,
    required String column,
    required String newValue,
  }) async {
    final patched = _applyBulkColumn(client, column, newValue);
    await db.transaction(() async {
      await db.clientDao.upsert(
        _domainToCompanion(patched, companyId, isDirty: true),
      );
      await enqueueMutation(
        companyId: companyId,
        entityId: client.id,
        kind: MutationKind.bulkUpdate,
        payload: {'id': client.id, 'column': column, 'new_value': newValue},
      );
    });
  }

  /// Apply a `bulk_update` [column] (server wire name) to [c], returning the
  /// patched client. The eight columns mirror `Client::$bulk_update_columns`.
  Client _applyBulkColumn(Client c, String column, String newValue) {
    switch (column) {
      case 'public_notes':
        return c.copyWith(publicNotes: newValue);
      case 'industry_id':
        return c.copyWith(industryId: newValue);
      case 'size_id':
        return c.copyWith(sizeId: newValue);
      case 'country_id':
        return c.copyWith(countryId: newValue);
      case 'custom_value1':
        return c.copyWith(customValue1: newValue);
      case 'custom_value2':
        return c.copyWith(customValue2: newValue);
      case 'custom_value3':
        return c.copyWith(customValue3: newValue);
      case 'custom_value4':
        return c.copyWith(customValue4: newValue);
      default:
        throw ArgumentError('Unsupported bulk_update column: $column');
    }
  }

  /// Permanently destroy the client and every record that references it
  /// (invoices, payments, tasks, expenses, …). Irreversible. The outbox
  /// row carries `requiresPassword=true` so the sync engine prompts via
  /// `ConfirmPasswordSheet` before hitting `POST /clients/:id/purge`.
  /// Queue a document upload for this client. The local file at
  /// [localPath] survives until the dispatcher posts it — if the user
  /// moves or deletes the file before sync, the upload is skipped (the
  /// dispatcher warns and drops the row).
  @override
  Future<void> uploadDocument({
    required String companyId,
    required String entityId,
    required UploadSource source,
  }) async {
    await enqueueMutation(
      companyId: companyId,
      entityId: entityId,
      kind: MutationKind.documentUpload,
      payload: {'entity_id': entityId, ...source.toPayload()},
    );
  }

  /// Delete one document attached to a client. Password-gated (the
  /// server requires `X-API-PASSWORD-BASE64`; `requiresPasswordFor`
  /// returns true above).
  @override
  Future<void> deleteDocument({
    required String companyId,
    required String entityId,
    required String documentId,
  }) async {
    await enqueueMutation(
      companyId: companyId,
      entityId: entityId,
      kind: MutationKind.documentDelete,
      payload: {'entity_id': entityId, 'document_id': documentId},
    );
  }

  /// Flip a document's public/private flag.
  @override
  Future<void> setDocumentVisibility({
    required String companyId,
    required String entityId,
    required String documentId,
    required bool isPublic,
  }) async {
    await enqueueMutation(
      companyId: companyId,
      entityId: entityId,
      kind: MutationKind.documentVisibility,
      payload: {
        'entity_id': entityId,
        'document_id': documentId,
        'is_public': isPublic,
      },
    );
  }

  /// Append a user comment to this client's activity stream. Hits
  /// `/api/v1/activities/notes` via the outbox; the dispatcher's
  /// `customActions` map (registered in services.dart) calls the
  /// `ActivitiesApi`. The pending outbox row is what drives the optimistic
  /// "syncing…" entry in the Activity tab.
  Future<void> addComment({
    required String companyId,
    required String clientId,
    required String text,
  }) async {
    await enqueueMutation(
      companyId: companyId,
      entityId: clientId,
      kind: MutationKind.addComment,
      payload: {'entity_id': clientId, 'notes': text.trim()},
    );
  }

  /// Clears the Postmark bounce/spam suppression for [messageId] (an email
  /// event's `bounce_id`). Enqueues against the client so the Outbox screen
  /// groups it sensibly; the dispatcher's `customActions[reactivateEmail]`
  /// hits `POST /api/v1/reactivate_email/{messageId}`. No local entity update
  /// — the bounce indicator refreshes on the next client sync.
  Future<int> reactivateContactEmail({
    required String companyId,
    required String clientId,
    required String messageId,
  }) => enqueueMutation(
    companyId: companyId,
    entityId: clientId,
    kind: MutationKind.reactivateEmail,
    payload: {'message_id': messageId},
  );

  /// Merge [mergeFromId] (absorbed, deleted) into [mergeIntoId] (survivor).
  /// Password-gated (`requiresPasswordFor` ⇒ the outbox row carries the 412
  /// gate, same as delete/purge). The dispatcher's `customActions[merge]`
  /// handler hits `POST /clients/{into}/{from}/merge`, removes the absorbed
  /// client's local row, and upserts the surviving client from the response.
  Future<void> merge({
    required String companyId,
    required String mergeIntoId,
    required String mergeFromId,
  }) async {
    await enqueueMutation(
      companyId: companyId,
      entityId: mergeFromId,
      kind: MutationKind.merge,
      payload: {'merge_into_id': mergeIntoId, 'merge_from_id': mergeFromId},
    );
  }

  /// Client locations are a standalone `/api/v1/locations` resource. These
  /// enqueue `location*` outbox rows; the Client dispatcher's `customActions`
  /// call `LocationsApi` then refresh the parent client so the embedded
  /// `client.locations[]` reflects the change. `entityId` is the parent
  /// client id (create has no location id yet; update/delete carry the
  /// location id in the payload) so the Outbox screen groups them sensibly.
  Future<void> createLocation({
    required String companyId,
    required String clientId,
    required Map<String, dynamic> body,
  }) => enqueueMutation(
    companyId: companyId,
    entityId: clientId,
    kind: MutationKind.locationCreate,
    payload: {'client_id': clientId, 'body': body},
  );

  Future<void> updateLocation({
    required String companyId,
    required String clientId,
    required String locationId,
    required Map<String, dynamic> body,
  }) => enqueueMutation(
    companyId: companyId,
    entityId: clientId,
    kind: MutationKind.locationUpdate,
    payload: {'client_id': clientId, 'location_id': locationId, 'body': body},
  );

  Future<void> deleteLocation({
    required String companyId,
    required String clientId,
    required String locationId,
  }) => enqueueMutation(
    companyId: companyId,
    entityId: clientId,
    kind: MutationKind.locationDelete,
    payload: {'client_id': clientId, 'location_id': locationId},
  );

  /// Concrete handler for the `create` round-trip. See base class for
  /// the steps that run inside the transaction.
  @override
  Future<void> deleteLocalById({
    required String companyId,
    required String id,
  }) => db.clientDao.deleteById(companyId: companyId, id: id);

  @override
  BaseEntityDao<dynamic, dynamic> get localDao => db.clientDao;

  @override
  Future<void> applyCreateResponse({
    required String companyId,
    required String tempId,
    required ClientApi serverResponse,
  }) => applyCreateResponseTemplate(
    companyId: companyId,
    tempId: tempId,
    realId: serverResponse.id,
    companion: _apiToCompanion(serverResponse, companyId),
    upsert: db.clientDao.upsert,
    deleteById: (id) => db.clientDao.deleteById(companyId: companyId, id: id),
  );

  @override
  Future<void> applyUpdateResponse({
    required String companyId,
    required ClientApi serverResponse,
  }) async {
    await db.clientDao.upsert(_apiToCompanion(serverResponse, companyId));
  }

  @override
  Future<void> applyDeleteResponse({
    required String companyId,
    required String id,
  }) async {
    final existing = await db.clientDao
        .watchById(companyId: companyId, id: id)
        .first;
    if (existing == null) return;
    await db.clientDao.upsert(
      existing
          .toCompanion(true)
          .copyWith(isDeleted: const Value(true), isDirty: const Value(false)),
    );
  }

  @override
  Future<void> applyPurgeResponse({
    required String companyId,
    required String id,
  }) async {
    // Purge is irreversible server-side; remove the local row entirely so
    // the detail watcher emits null and every list query stops surfacing
    // it. `applyDeleteResponse` keeps the row around with is_deleted=true
    // because soft-delete is reversible via Restore — that doesn't apply
    // here.
    await db.clientDao.deleteById(companyId: companyId, id: id);
  }

  // Lifecycle filtering uses the shared `BaseEntityRepository.stateQueryParams`
  // (emits the `status` param). It used to override this to send
  // `client_status`, which silently no-op'd archived/deleted and collided
  // with the computed-status filters — see the base method's doc.

  // -------------------- conversions --------------------

  ClientsCompanion _apiToCompanion(ClientApi a, String companyId) {
    return ClientsCompanion.insert(
      id: a.id,
      companyId: companyId,
      name: a.name,
      number: a.number,
      email: _primaryEmailOf(a.contacts, (c) => c.isPrimary, (c) => c.email),
      displayName: a.displayName.isNotEmpty ? a.displayName : a.name,
      balance: a.balance.toString(),
      updatedAt: a.updatedAt,
      createdAt: Value(a.createdAt),
      archivedAt: a.archivedAt > 0 ? Value(a.archivedAt) : const Value(null),
      customValue1: Value(a.customValue1),
      customValue2: Value(a.customValue2),
      customValue3: Value(a.customValue3),
      customValue4: Value(a.customValue4),
      // Denormalized filter columns (v55). Stored in the payload's id form;
      // see clients_table.dart — no decode, mirrors the server filters.
      countryId: Value(a.countryId),
      industryId: Value(a.industryId),
      sizeId: Value(a.sizeId),
      classification: Value(a.classification),
      vatNumber: Value(a.vatNumber),
      groupSettingsId: Value(a.groupSettingsId),
      idNumber: Value(a.idNumber),
      assignedUserId: Value(a.assignedUserId),
      isDirty: const Value(false),
      isDeleted: Value(a.isDeleted),
      // The DTO's `documents` is nullable so we can distinguish JSON-omitted
      // (→ null, preserve local) from JSON-present-and-empty (→ `[]`,
      // authoritative — server says no docs). When the request didn't carry
      // `?include=documents`, the server omits the field; on update PUT and
      // create POST that's the norm, so `Value.absent()` here keeps the
      // local cache from being clobbered. On list refresh we explicitly
      // include documents, so an empty array correctly clears local state.
      documents: a.documents == null
          ? const Value.absent()
          : Value(jsonEncode(a.documents!.map((d) => d.toJson()).toList())),
      // Locations are always embedded on client responses (probe-verified:
      // not `?include=`-gated like documents), so always write the
      // authoritative array — no missing-key guard needed.
      locations: Value(jsonEncode(a.locations.map((l) => l.toJson()).toList())),
      payload: jsonEncode(a.toJson()),
    );
  }

  ClientsCompanion _domainToCompanion(
    Client c,
    String companyId, {
    required bool isDirty,
  }) {
    return ClientsCompanion.insert(
      id: c.id,
      companyId: companyId,
      name: c.name,
      number: c.number,
      email: _primaryEmailOf(c.contacts, (c) => c.isPrimary, (c) => c.email),
      displayName: c.displayName,
      balance: c.balance.toString(),
      updatedAt: dateToEpochSeconds(c.updatedAt),
      createdAt: Value(dateToEpochSeconds(c.createdAt)),
      archivedAt: c.archivedAt == null
          ? const Value.absent()
          : Value(dateToEpochSeconds(c.archivedAt!)),
      customValue1: Value(c.customValue1),
      customValue2: Value(c.customValue2),
      customValue3: Value(c.customValue3),
      customValue4: Value(c.customValue4),
      // Denormalized filter columns (v55) — keep in lockstep with
      // `_apiToCompanion` so a local edit-save round-trips filterable values.
      countryId: Value(c.countryId),
      industryId: Value(c.industryId),
      sizeId: Value(c.sizeId),
      classification: Value(c.classification),
      vatNumber: Value(c.vatNumber),
      groupSettingsId: Value(c.groupSettingsId),
      idNumber: Value(c.idNumber),
      assignedUserId: Value(c.assignedUserId),
      isDirty: Value(isDirty),
      isDeleted: Value(c.isDeleted),
      documents: Value(
        jsonEncode(c.documents.map((d) => d.toApi().toJson()).toList()),
      ),
      // Persist locations from the domain (loaded into `c` by `_fromRow`'s
      // overlay) so a local client edit-save round-trips them — `c.toApiJson`
      // deliberately omits locations from the outbound wire.
      locations: Value(
        jsonEncode(c.locations.map((l) => l.toApiJson()).toList()),
      ),
      // `gateway_tokens` are read-only and deliberately omitted from
      // `toApiJson` (kept off the outbound wire). Inject them into the stored
      // payload here so the "Payment Methods" card doesn't blank out after a
      // local edit-save until the next server sync re-embeds them.
      payload: jsonEncode(_payloadWithLocalContactMetadata(c)),
    );
  }

  /// Build the stored-payload JSON for a local edit-save, re-injecting the
  /// fields `toApiJson` deliberately drops from the outbound wire so the
  /// optimistic local copy round-trips them until the next server sync:
  ///  * `gateway_tokens` — read-only, keeps the "Payment Methods" card filled.
  ///  * per-contact `is_locked` / `last_login` — read-only server metadata
  ///    (`Contact.toApiJson` omits them); without this the contacts card's
  ///    "unsubscribed" warning icon + last-login would blank after an edit.
  Map<String, dynamic> _payloadWithLocalContactMetadata(Client c) {
    final json = c.toApiJson(preserveTempId: true);
    // `toApiJson` already serialized `contacts` in order; patch the two
    // read-only fields onto each entry in place (same index = same contact).
    final contactsJson = (json['contacts'] as List?)
        ?.cast<Map<String, dynamic>>();
    if (contactsJson != null) {
      for (var i = 0; i < contactsJson.length && i < c.contacts.length; i++) {
        final contact = c.contacts[i];
        contactsJson[i]['is_locked'] = contact.isLocked;
        final lastLogin = contact.lastLogin;
        if (lastLogin != null) {
          contactsJson[i]['last_login'] =
              lastLogin.millisecondsSinceEpoch ~/ 1000;
        }
      }
    }
    json['gateway_tokens'] = c.gatewayTokens.map((g) => g.toApiJson()).toList();
    return json;
  }

  /// Drop a document from the client's local `documents` JSON column.
  /// Called by the sync dispatcher after a successful `DELETE
  /// /api/v1/documents/{id}` round-trip — the server's response is empty,
  /// so we patch locally rather than refetching the whole client.
  Future<void> applyDocumentDeleted({
    required String companyId,
    required String entityId,
    required String documentId,
  }) async {
    final row = await db.clientDao
        .watchById(companyId: companyId, id: entityId)
        .first;
    if (row == null) return;
    final current = decodeRawDocumentsColumn(row.documents);
    final next = current.where((d) => d.id != documentId).toList();
    if (next.length == current.length) return; // not found; no-op
    await (db.update(db.clients)
          ..where((c) => c.companyId.equals(companyId) & c.id.equals(entityId)))
        .write(
          ClientsCompanion(
            documents: Value(jsonEncode(next.map((d) => d.toJson()).toList())),
          ),
        );
  }

  /// Replace (or insert) one document in the client's local `documents`
  /// JSON column. Called after `PUT /api/v1/documents/{id}` returns the
  /// updated document.
  Future<void> applyDocumentChanged({
    required String companyId,
    required String entityId,
    required DocumentApi document,
  }) async {
    final row = await db.clientDao
        .watchById(companyId: companyId, id: entityId)
        .first;
    if (row == null) return;
    final current = decodeRawDocumentsColumn(row.documents);
    final next = [
      for (final d in current)
        if (d.id == document.id) document else d,
    ];
    if (!current.any((d) => d.id == document.id)) {
      next.add(document);
    }
    await (db.update(db.clients)
          ..where((c) => c.companyId.equals(companyId) & c.id.equals(entityId)))
        .write(
          ClientsCompanion(
            documents: Value(jsonEncode(next.map((d) => d.toJson()).toList())),
          ),
        );
  }

  Client _fromRow(ClientRow row) {
    final json = jsonDecode(row.payload) as Map<String, dynamic>;
    final api = ClientApi.fromJson(json);
    // is_dirty is local-only (not in the API payload), so we layer it on
    // from the Drift row. Without this, an unsaved edit shows up as clean
    // after app restart. `documents` lives in its own column (the API
    // `toApiJson` deliberately omits it) — decode separately and overlay.
    return Client.fromApi(api).copyWith(
      isDirty: row.isDirty,
      isDeleted: row.isDeleted,
      archivedAt: epochSecondsToUtcOrNull(row.archivedAt ?? 0),
      documents: decodeDocumentsColumn(row.documents),
      // Same story as documents: `toApiJson` omits locations from the
      // payload JSON, so overlay them from their dedicated column.
      locations: decodeLocationsColumn(row.locations),
    );
  }
}

/// Inclusive day-window bounds (epoch seconds, UTC) for the `created_at` /
/// `updated_at` between filters. Those columns are stored as epoch seconds;
/// the filter value is an ISO `YYYY-MM-DD`, so the start is that day's
/// 00:00:00 and the end is 23:59:59 so the whole end day is included.
/// Translate a single-date comparator (`op:value`, ISO `YYYY-MM-DD`) into the
/// inclusive epoch-second `from`/`to` bounds the client DAO already applies to
/// `updated_at` / `created_at`. Reuses the day-window helpers below so the
/// comparator and the range slot agree on boundaries.
({int? from, int? to}) _epochBoundsFor(({String? op, String? value}) cmp) {
  final v = cmp.value;
  if (v == null || v.isEmpty) return (from: null, to: null);
  final start = _isoDayStartEpoch(v);
  final end = _isoDayEndEpoch(v);
  return switch (cmp.op) {
    'gt' => (from: end == null ? null : end + 1, to: null),
    'lt' => (from: null, to: start == null ? null : start - 1),
    'lte' => (from: null, to: end),
    'eq' => (from: start, to: end),
    _ => (from: start, to: null),
  };
}

int? _isoDayStartEpoch(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  final d = DateTime.tryParse(iso);
  if (d == null) return null;
  return DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 1000;
}

int? _isoDayEndEpoch(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  final d = DateTime.tryParse(iso);
  if (d == null) return null;
  return DateTime.utc(
        d.year,
        d.month,
        d.day,
        23,
        59,
        59,
      ).millisecondsSinceEpoch ~/
      1000;
}

/// Pick the primary contact's email, falling back to the first contact, then
/// empty string. Generic over both `ContactApi` and `Contact` so the API and
/// domain mappers share one walk.
String _primaryEmailOf<T>(
  List<T> contacts,
  bool Function(T) isPrimary,
  String Function(T) email,
) {
  if (contacts.isEmpty) return '';
  for (final c in contacts) {
    if (isPrimary(c)) return email(c);
  }
  return email(contacts.first);
}
