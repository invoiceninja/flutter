import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value, BooleanExpressionOperators;
import 'package:logging/logging.dart';

import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/billing_extra_filters.dart';
import 'package:admin/data/db/dao/payment_dao.dart';
import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/api/payment_api_model.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/tag_denormalization.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/repositories/document_bearing_repository.dart';
import 'package:admin/data/services/payments_api.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/data/models/value/parsing.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';

final _log = Logger('PaymentRepository');

/// Source of truth for Payment data. UI watches Drift via [watchPage] and
/// [watch]; network only writes. Every mutation goes through the outbox.
///
/// Mirrors `ExpenseRepository`: document-bearing, password-gated
/// delete/purge/documentDelete. Adds two payment-only flows — `refund`
/// (`POST /payments/refund`) and `apply` (`PUT /payments/{id}` with an
/// `invoices` allocations array) — enqueued as their own `MutationKind`
/// variants and dispatched via `customActions`.
class PaymentRepository extends BaseEntityRepository<Payment, PaymentApi>
    implements DocumentBearingRepository {
  PaymentRepository({
    required super.db,
    required this.api,
    super.uuid,
    super.now,
    super.onEnqueued,
    this.onRelatedEntitiesAffected,
    this.pageSize = 50,
  }) : super(
         entityType: EntityType.payment,
         requiresPasswordFor: const {
           MutationKind.delete,
           MutationKind.purge,
           MutationKind.documentDelete,
         },
       );

  final PaymentsApi api;
  final int pageSize;

  /// Fired after a payment mutation is applied, so the affected invoice(s) and
  /// client — which the server changed as a side effect (balance / paid_to_date
  /// / status_id) — are force-refetched into Drift instead of staying stale
  /// until a manual full resync (issue #7). Wired by DI; null in tests that
  /// don't exercise the side-effect refresh.
  final RelatedEntitiesRefresher? onRelatedEntitiesAffected;

  @override
  String get entityTypeName => 'payment';

  /// Watch the first [loadedPages] pages of payment rows. Filters and sort
  /// mirror what the list ViewModel exposes; the dedicated
  /// `hasUnappliedFundsOnly` flag matches the "Has unapplied funds" chip.
  Stream<List<Payment>> watchPage({
    required String companyId,
    int loadedPages = 1,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    Set<String> statusIds = const {},
    bool hasUnappliedFundsOnly = false,
    String sortField = PaymentFieldIds.date,
    bool sortAscending = false,
    String? clientId,
    Map<int, Set<String>> customFilters = const {},
    Map<String, Set<String>> extraFilters = const {},
    // Status-tab filter — see `list_status_tabs.dart`.
    String? badgeModeId,
  }) {
    assert(
      loadedPages >= 1,
      'loadedPages is 1-based; pass 1 for the first page',
    );
    final dateRange = parseDateRangeFilter(extraFilters);
    // Single-date comparators live in the `op:value` slot, not the range
    // slot — mirror them locally or the chip only narrows the server fetch.
    final dateCmp = parseComparableDateFilter(extraFilters, 'date');
    // Fold the `client_status` filter into `statusIds` — the DAO already
    // resolves numeric ('1'..'6') + virtual ('-1'/'-2') discriminators,
    // and `parsePaymentStatusFilter` maps the wire labels onto them.
    final mergedStatusIds = {
      ...statusIds,
      ...parsePaymentStatusFilter(extraFilters),
    };
    return db.paymentDao
        .watchPage(
          badgeModeId: badgeModeId,
          companyId: companyId,
          offset: 0,
          limit: pageSize * loadedPages,
          search: search,
          states: states,
          statusIds: mergedStatusIds,
          hasUnappliedFundsOnly: hasUnappliedFundsOnly,
          sortField: sortField,
          sortAscending: sortAscending,
          clientId: clientId,
          clientIds: parseClientIdFilter(extraFilters),
          customValues1: customFilters[1] ?? const {},
          customValues2: customFilters[2] ?? const {},
          customValues3: customFilters[3] ?? const {},
          customValues4: customFilters[4] ?? const {},
          dateOp: dateCmp.op,
          dateValue: dateCmp.value,
          dateStart: dateRange.start,
          dateEnd: dateRange.end,
        )
        .map((rows) {
          final items = rows.map(_fromRow);
          // `tag_ids` lives only in the payload — post-decode predicate.
          final tagIds = extraFilters['tag_ids'] ?? const <String>{};
          if (tagIds.isEmpty) return items.toList(growable: false);
          return items
              .where((p) => matchesTagIdFilter(p.tagIds, tagIds))
              .toList(growable: false);
        });
  }

  Stream<int> watchCount({required String companyId}) =>
      db.paymentDao.watchCount(companyId: companyId);

  /// Live count behind this entity's sidebar counter badge. [modeId] is one of
  /// the entity's `SidebarBadgeMode` ids; [currentUserId] is read only by the
  /// `assigned_to_me` mode.
  Stream<int> watchBadgeCount({
    required String companyId,
    String modeId = kBadgeModeTotal,
    String currentUserId = '',
  }) => db.paymentDao.watchBadgeCount(
    companyId: companyId,
    modeId: modeId,
    currentUserId: currentUserId,
  );

  Stream<List<Payment>> watchForClient({
    required String companyId,
    required String clientId,
  }) {
    if (clientId.isEmpty) {
      return Stream<List<Payment>>.value(const <Payment>[]);
    }
    return db.paymentDao
        .watchForClient(companyId: companyId, clientId: clientId)
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  Stream<List<Payment>> watchForInvoice({
    required String companyId,
    required String invoiceId,
  }) {
    if (invoiceId.isEmpty) {
      return Stream<List<Payment>>.value(const <Payment>[]);
    }
    return db.paymentDao
        .watchForInvoice(companyId: companyId, invoiceId: invoiceId)
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  @override
  Stream<Payment?> watchByRealId({
    required String companyId,
    required String id,
  }) => db.paymentDao
      .watchById(companyId: companyId, id: id)
      .map((row) => row == null ? null : _fromRow(row));

  /// Fetch one page from the server and upsert into Drift. Includes
  /// `client,invoices,paymentables` so the detail + refund screens have
  /// everything they need.
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
    extraFilters: extraFilters,
    ignoreCursor: ignoreCursor,
    excludeDeletedClients: true,
    staticFilters: const {'include': 'client,invoices,paymentables,documents'},
    listCall: api.list,
    itemsOf: (l) => l.data,
    idOf: (a) => a.id,
    toCompanion: (a) => _apiToCompanion(a, companyId),
    upsert: (byId) => db.paymentDao.upsertAllPreservingDirty(
      companyId: companyId,
      byId: byId,
    ),
  );

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
    const maxPages = 1000;
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

  /// Create a new payment offline. [sendEmail] threads through the
  /// outbox as a synthetic `_send_email` flag that [PaymentsApi.create]
  /// lifts to `?email_receipt=…` (always-appended on create).
  Future<SaveResult<Payment>> create({
    required String companyId,
    required Payment draft,
    required bool sendEmail,
    String? existingTempId,
  }) async {
    final tmpId = existingTempId ?? mintTempId();
    final stored = draft.copyWith(id: tmpId);
    final companion = _domainToCompanion(stored, companyId, isDirty: true);

    var rowId = 0;
    await db.transaction(() async {
      await db.paymentDao.upsert(companion);
      await dedupPendingMutations(
        companyId: companyId,
        entityId: tmpId,
        kind: MutationKind.create,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: tmpId,
        kind: MutationKind.create,
        payload: <String, dynamic>{
          ...stored.toApiJson(),
          kPaymentSendEmailKey: sendEmail,
        },
      );
    });
    return SaveResult(entity: stored, outboxRowId: rowId);
  }

  Future<SaveResult<Payment>> save({
    required String companyId,
    required Payment payment,
    required bool sendEmail,
  }) async {
    // If this entity's offline create already drained while the edit
    // form was open, id_remap now points the tmp id at the real row (the
    // tmp row was deleted). Saving under the stale tmp id would resurrect
    // it as a ghost duplicate — and deleting that ghost would delete the
    // real entity via the remap. Rebind to the real id first.
    final resolvedId = await resolveId(payment.id);
    if (resolvedId != payment.id) payment = payment.copyWith(id: resolvedId);

    final companion = _domainToCompanion(payment, companyId, isDirty: true);
    // Never re-send allocations on an update. The server's
    // PaymentRepository::applyPayment re-applies every `invoices`/`credits`
    // entry on PUT with no dedupe, so echoing an existing payment's
    // paymentables back double-applies it against the invoice (balance and
    // paid_to_date corrupted) — or 422s outright once the payment is fully
    // applied. Allocating funds is its own flow ([apply], a separate
    // `MutationKind.applyPayment` PUT). React's edit hook deletes both keys
    // before PUT for the same reason (useSave.ts).
    final updateJson = payment.toApiJson(preserveTempId: true)
      ..remove('invoices')
      ..remove('credits');
    var rowId = 0;
    await db.transaction(() async {
      await db.paymentDao.upsert(companion);
      await dedupPendingMutations(
        companyId: companyId,
        entityId: payment.id,
        kind: MutationKind.update,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: payment.id,
        kind: MutationKind.update,
        payload: <String, dynamic>{
          ...updateJson,
          kPaymentSendEmailKey: sendEmail,
        },
      );
    });
    return SaveResult(entity: payment, outboxRowId: rowId);
  }

  /// Refund a payment. Posts `POST /payments/refund` via the outbox.
  /// [invoices] entries shape: `{invoice_id, amount}` per row.
  Future<void> refund({
    required String companyId,
    required String paymentId,
    required String date,
    required List<Map<String, dynamic>> invoices,
    required bool sendEmail,
    required bool gatewayRefund,
  }) async {
    await enqueueMutation(
      companyId: companyId,
      entityId: paymentId,
      kind: MutationKind.refundPayment,
      payload: <String, dynamic>{
        'id': paymentId,
        'date': date,
        'invoices': invoices,
        'send_email': sendEmail,
        'gateway_refund': gatewayRefund,
      },
    );
  }

  /// Apply unapplied payment funds to one or more invoices. Hits
  /// `PUT /payments/{id}` with body `{invoices: [...]}`.
  Future<void> apply({
    required String companyId,
    required String paymentId,
    required List<Map<String, dynamic>> allocations,
  }) async {
    await enqueueMutation(
      companyId: companyId,
      entityId: paymentId,
      kind: MutationKind.applyPayment,
      payload: <String, dynamic>{'id': paymentId, 'invoices': allocations},
    );
  }

  /// Append a user comment to this payment's activity stream.
  Future<void> addComment({
    required String companyId,
    required String paymentId,
    required String text,
  }) async {
    await enqueueMutation(
      companyId: companyId,
      entityId: paymentId,
      kind: MutationKind.addComment,
      payload: {'entity_id': paymentId, 'notes': text.trim()},
    );
  }

  @override
  Future<void> uploadDocument({
    required String companyId,
    required String entityId,
    required UploadSource source,
  }) {
    return enqueueMutation(
      companyId: companyId,
      entityId: entityId,
      kind: MutationKind.documentUpload,
      payload: {'entity_id': entityId, ...source.toPayload()},
    );
  }

  @override
  Future<void> deleteDocument({
    required String companyId,
    required String entityId,
    required String documentId,
  }) {
    return enqueueMutation(
      companyId: companyId,
      entityId: entityId,
      kind: MutationKind.documentDelete,
      payload: {'entity_id': entityId, 'document_id': documentId},
    );
  }

  @override
  Future<void> setDocumentVisibility({
    required String companyId,
    required String entityId,
    required String documentId,
    required bool isPublic,
  }) {
    return enqueueMutation(
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

  @override
  Future<void> deleteLocalById({
    required String companyId,
    required String id,
  }) => db.paymentDao.deleteById(companyId: companyId, id: id);

  @override
  BaseEntityDao<dynamic, dynamic> get localDao => db.paymentDao;

  @override
  Future<void> applyCreateResponse({
    required String companyId,
    required String tempId,
    required PaymentApi serverResponse,
  }) async {
    await applyCreateResponseTemplate(
      companyId: companyId,
      tempId: tempId,
      realId: serverResponse.id,
      companion: _apiToCompanion(serverResponse, companyId),
      upsert: db.paymentDao.upsert,
      deleteById: (id) =>
          db.paymentDao.deleteById(companyId: companyId, id: id),
    );
    await _refreshRelatedFromResponse(companyId, serverResponse);
  }

  @override
  Future<void> applyUpdateResponse({
    required String companyId,
    required PaymentApi serverResponse,
  }) async {
    await db.paymentDao.upsert(_apiToCompanion(serverResponse, companyId));
    await _refreshRelatedFromResponse(companyId, serverResponse);
  }

  /// Force-refetch payments by id (e.g. the payment a bank-transaction match
  /// created/linked). See [refreshByIdsTemplate].
  /// Lazily hydrate a single payment into Drift on a cache miss — backs detail
  /// screens reached from the dashboard (whose rows live only in the dashboard
  /// cache, not the entity table). Deduped / negative-cached in the template.
  Future<void> ensureLoaded({required String companyId, required String id}) =>
      ensureLoadedTemplate(
        companyId: companyId,
        id: id,
        fetch: (id) async => (await api.get(id)).data,
        idOf: (a) => a.id,
        toCompanion: (a) => _apiToCompanion(a, companyId),
        upsert: (byId) => db.paymentDao.upsertAllPreservingDirty(
          companyId: companyId,
          byId: byId,
        ),
      );

  @override
  Future<void> refreshByIds({
    required String companyId,
    required Iterable<String> ids,
  }) async {
    await refreshByIdsTemplate<PaymentApi, PaymentsCompanion>(
      companyId: companyId,
      ids: ids,
      fetch: (id) async => (await api.get(id)).data,
      idOf: (a) => a.id,
      toCompanion: (a) => _apiToCompanion(a, companyId),
      upsert: (byId) => db.paymentDao.upsertAllPreservingDirty(
        companyId: companyId,
        byId: byId,
      ),
    );
  }

  @override
  Future<void> applyDeleteResponse({
    required String companyId,
    required String id,
  }) async {
    final existing = await db.paymentDao
        .watchById(companyId: companyId, id: id)
        .first;
    if (existing == null) return;
    await db.paymentDao.upsert(
      existing
          .toCompanion(true)
          .copyWith(isDeleted: const Value(true), isDirty: const Value(false)),
    );
    // Deleting/voiding a payment reverses its invoices'/credits' balance/status
    // server-side. No server response here, so source the affected ids from the
    // soft-deleted row (read above, before the write).
    final stored = _allocatedIdsFromStored(existing.paymentables);
    await _refreshRelated(
      companyId,
      invoiceIds: stored.invoiceIds,
      creditIds: stored.creditIds,
      clientId: existing.clientId,
    );
  }

  /// Fire [onRelatedEntitiesAffected] for the invoice(s), credit(s), and client
  /// carried by a payment [serverResponse]. `paymentables` are a default include
  /// (create / update / apply / refund responses all list them) and hold BOTH
  /// invoice and credit allocations (each row has `invoice_id` xor `credit_id`).
  Future<void> _refreshRelatedFromResponse(
    String companyId,
    PaymentApi serverResponse,
  ) {
    final paymentables = serverResponse.paymentables ?? const [];
    return _refreshRelated(
      companyId,
      invoiceIds: paymentables.map((p) => p.invoiceId),
      creditIds: paymentables.map((p) => p.creditId),
      clientId: serverResponse.clientId,
    );
  }

  Future<void> _refreshRelated(
    String companyId, {
    required Iterable<String> invoiceIds,
    Iterable<String> creditIds = const [],
    required String clientId,
  }) async {
    final cb = onRelatedEntitiesAffected;
    if (cb == null) return;
    final invIds = invoiceIds.where((id) => id.isNotEmpty).toSet();
    final credIds = creditIds.where((id) => id.isNotEmpty).toSet();
    final cliId = clientId.trim();
    if (invIds.isEmpty && credIds.isEmpty && cliId.isEmpty) return;
    try {
      await cb(companyId, {
        if (invIds.isNotEmpty) EntityType.invoice: invIds,
        if (credIds.isNotEmpty) EntityType.credit: credIds,
        if (cliId.isNotEmpty) EntityType.client: {cliId},
      });
    } catch (e) {
      _log.warning('onRelatedEntitiesAffected failed: $e');
    }
  }

  /// Invoice + credit ids from a payment row's stored `paymentables` JSON column
  /// (encoded by [_apiToCompanion]); used on delete/void where there is no server
  /// response to read.
  ({Set<String> invoiceIds, Set<String> creditIds}) _allocatedIdsFromStored(
    String? paymentablesJson,
  ) {
    const empty = (invoiceIds: <String>{}, creditIds: <String>{});
    if (paymentablesJson == null || paymentablesJson.isEmpty) return empty;
    try {
      final decoded = jsonDecode(paymentablesJson);
      if (decoded is! List) return empty;
      final rows = decoded.whereType<Map<String, dynamic>>();
      return (
        invoiceIds: {
          for (final m in rows)
            if ((m['invoice_id'] ?? '').toString().isNotEmpty)
              m['invoice_id'].toString(),
        },
        creditIds: {
          for (final m in rows)
            if ((m['credit_id'] ?? '').toString().isNotEmpty)
              m['credit_id'].toString(),
        },
      );
    } catch (e) {
      _log.warning('failed to decode stored paymentables: $e');
      return empty;
    }
  }

  Future<void> applyDocumentDeleted({
    required String companyId,
    required String entityId,
    required String documentId,
  }) async {
    final row = await db.paymentDao
        .watchById(companyId: companyId, id: entityId)
        .first;
    if (row == null) return;
    final current = decodeRawDocumentsColumn(row.documents);
    final next = current.where((d) => d.id != documentId).toList();
    if (next.length == current.length) return;
    await (db.update(db.payments)
          ..where((p) => p.companyId.equals(companyId) & p.id.equals(entityId)))
        .write(
          PaymentsCompanion(
            documents: Value(jsonEncode(next.map((d) => d.toJson()).toList())),
          ),
        );
  }

  Future<void> applyDocumentChanged({
    required String companyId,
    required String entityId,
    required DocumentApi document,
  }) async {
    final row = await db.paymentDao
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
    await (db.update(db.payments)
          ..where((p) => p.companyId.equals(companyId) & p.id.equals(entityId)))
        .write(
          PaymentsCompanion(
            documents: Value(jsonEncode(next.map((d) => d.toJson()).toList())),
          ),
        );
  }

  // -------------------- conversions --------------------

  PaymentsCompanion _apiToCompanion(PaymentApi a, String companyId) {
    return PaymentsCompanion.insert(
      id: a.id,
      companyId: companyId,
      number: Value(a.number),
      date: Value(a.date),
      amount: Value(_moneyString(a.amount)),
      applied: Value(_moneyString(a.applied)),
      refunded: Value(_moneyString(a.refunded)),
      exchangeRate: Value(_moneyString(a.exchangeRate)),
      statusId: Value(a.statusId),
      typeId: Value(a.typeId),
      clientId: Value(a.clientId),
      vendorId: Value(a.vendorId),
      projectId: Value(a.projectId),
      companyGatewayId: Value(a.companyGatewayId),
      gatewayTypeId: Value(a.gatewayTypeId),
      currencyId: Value(a.currencyId),
      exchangeCurrencyId: Value(a.exchangeCurrencyId),
      transactionReference: Value(a.transactionReference),
      isManual: Value(a.isManual),
      updatedAt: a.updatedAt,
      createdAt: Value(a.createdAt),
      archivedAt: a.archivedAt > 0 ? Value(a.archivedAt) : const Value(null),
      customValue1: Value(a.customValue1),
      customValue2: Value(a.customValue2),
      customValue3: Value(a.customValue3),
      customValue4: Value(a.customValue4),
      isDirty: const Value(false),
      isDeleted: Value(a.isDeleted),
      paymentables: a.paymentables == null
          ? const Value.absent()
          : Value(jsonEncode(a.paymentables!.map((p) => p.toJson()).toList())),
      invoices: a.invoices == null
          ? const Value.absent()
          : Value(jsonEncode(a.invoices!.map((i) => i.toJson()).toList())),
      credits: a.credits == null
          ? const Value.absent()
          : Value(jsonEncode(a.credits!.map((c) => c.toJson()).toList())),
      documents: a.documents == null
          ? const Value.absent()
          : Value(jsonEncode(a.documents!.map((d) => d.toJson()).toList())),
      payload: jsonEncode(a.toJson()),
    );
  }

  PaymentsCompanion _domainToCompanion(
    Payment p,
    String companyId, {
    required bool isDirty,
  }) {
    return PaymentsCompanion.insert(
      id: p.id,
      companyId: companyId,
      number: Value(p.number),
      date: Value(p.date?.toIso() ?? ''),
      amount: Value(p.amount.toString()),
      applied: Value(p.applied.toString()),
      refunded: Value(p.refunded.toString()),
      exchangeRate: Value(p.exchangeRate.toString()),
      statusId: Value(p.statusId),
      typeId: Value(p.typeId),
      clientId: Value(p.clientId),
      vendorId: Value(p.vendorId),
      projectId: Value(p.projectId),
      companyGatewayId: Value(p.companyGatewayId),
      gatewayTypeId: Value(p.gatewayTypeId),
      currencyId: Value(p.currencyId),
      exchangeCurrencyId: Value(p.exchangeCurrencyId),
      transactionReference: Value(p.transactionReference),
      isManual: Value(p.isManual),
      updatedAt: dateToEpochSeconds(p.updatedAt),
      createdAt: Value(dateToEpochSeconds(p.createdAt)),
      archivedAt: p.archivedAt == null
          ? const Value.absent()
          : Value(dateToEpochSeconds(p.archivedAt!)),
      customValue1: Value(p.customValue1),
      customValue2: Value(p.customValue2),
      customValue3: Value(p.customValue3),
      customValue4: Value(p.customValue4),
      isDirty: Value(isDirty),
      isDeleted: Value(p.isDeleted),
      paymentables: Value(
        jsonEncode(
          p.paymentables
              .map(
                (pa) => <String, dynamic>{
                  'id': pa.id,
                  'invoice_id': pa.invoiceId,
                  'credit_id': pa.creditId,
                  'amount': pa.amount.toString(),
                  'refunded': pa.refunded.toString(),
                  'created_at': pa.createdAt,
                  'updated_at': pa.updatedAt,
                  'archived_at': pa.archivedAt,
                },
              )
              .toList(),
        ),
      ),
      invoices: Value(
        jsonEncode(
          p.invoices
              .map(
                (i) => <String, dynamic>{
                  'id': i.id,
                  'number': i.number,
                  'amount': i.amount.toString(),
                  'balance': i.balance.toString(),
                  'paid_to_date': i.paidToDate.toString(),
                },
              )
              .toList(),
        ),
      ),
      credits: Value(
        jsonEncode(
          p.credits
              .map(
                (c) => <String, dynamic>{
                  'id': c.id,
                  'number': c.number,
                  'amount': c.amount.toString(),
                  'balance': c.balance.toString(),
                },
              )
              .toList(),
        ),
      ),
      documents: Value(
        jsonEncode(p.documents.map((d) => d.toApi().toJson()).toList()),
      ),
      payload: jsonEncode(p.toApiJson(preserveTempId: true)),
    );
  }

  Payment _fromRow(PaymentRow row) {
    final json = jsonDecode(row.payload) as Map<String, dynamic>;
    // Overlay the nested-array columns onto the payload so the domain
    // factory sees the freshest data without re-parsing payload-embedded
    // arrays that may have aged behind a server-include refresh.
    final paymentables = _decodeList(row.paymentables);
    final invoices = _decodeList(row.invoices);
    final credits = _decodeList(row.credits);
    if (paymentables != null) json['paymentables'] = paymentables;
    if (invoices != null) json['invoices'] = invoices;
    if (credits != null) json['credits'] = credits;
    final api = PaymentApi.fromJson(json);
    return Payment.fromApi(api).copyWith(
      isDirty: row.isDirty,
      isDeleted: row.isDeleted,
      archivedAt: epochSecondsToUtcOrNull(row.archivedAt ?? 0),
      // The local save path writes `payload` from `toApiJson`, which
      // deliberately omits the server-assigned timestamps — so a dirty row's
      // decoded `created_at` / `updated_at` fall back to the DTO default of 0
      // and `epochSecondsToUtc` (no zero guard) turns that into 1970. Read
      // them from the authoritative columns instead, exactly as
      // `TagRepository._fromRow` does.
      createdAt: epochSecondsToUtc(row.createdAt),
      updatedAt: epochSecondsToUtc(row.updatedAt),
      documents: decodeDocumentsColumn(row.documents),
    );
  }
}

List<dynamic>? _decodeList(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) return decoded;
  } catch (_) {}
  return null;
}

String _moneyString(Object raw) {
  if (raw is String) return raw;
  return raw.toString();
}
