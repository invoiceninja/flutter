import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_distinct_stream.dart';

import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/columns/ids/client_column_ids.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/data/db/dao/invoice_dao.dart';
import 'package:admin/data/db/dao/entity_query_helpers.dart';
import 'package:admin/data/db/tables/clients_table.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';

part 'client_dao.g.dart';

@DriftAccessor(tables: [Clients])
class ClientDao extends BaseEntityDao<$ClientsTable, ClientRow>
    with _$ClientDaoMixin {
  ClientDao(super.db);

  @override
  $ClientsTable get table => clients;
  @override
  GeneratedColumn<String> get idColumn => clients.id;
  @override
  GeneratedColumn<String> get companyIdColumn => clients.companyId;
  @override
  GeneratedColumn<bool> get isDeletedColumn => clients.isDeleted;
  @override
  GeneratedColumn<bool> get isDirtyColumn => clients.isDirty;

  @override
  GeneratedColumn<int>? get archivedAtColumn => clients.archivedAt;

  @override
  Expression<bool>? badgeModePredicate(
    String modeId, {
    required String companyId,
    required String currentUserId,
  }) => switch (modeId) {
    // Clients with at least one past-due invoice — who's actually late, which
    // is sharper than "who has a balance". Reuses the invoice list's own
    // overdue expression, so the two can't disagree. The `invoices` subquery
    // keeps the badge reactive to invoice changes, not just client ones.
    'overdue' => clients.id.isInQuery(_overdueInvoiceClientIds(companyId)),
    'outstanding' => clients.balance.cast<double>().isBiggerThanValue(0),
    kBadgeModeAssignedToMe => assignedToUserFilter(
      currentUserId,
      column: clients.assignedUserId,
    ),
    _ => null,
  };

  /// Client ids with at least one active, past-due invoice in [companyId].
  JoinedSelectStatement<HasResultSet, dynamic> _overdueInvoiceClientIds(
    String companyId,
  ) {
    final invoices = attachedDatabase.invoices;
    return selectOnly(invoices)
      ..addColumns([invoices.clientId])
      ..where(
        invoices.companyId.equals(companyId) &
            invoices.isDeleted.equals(false) &
            invoices.archivedAt.isNull() &
            invoiceOverdueFilter(invoices, Date.today().toIso()),
      );
  }

  Stream<List<ClientRow>> watchPage({
    required String companyId,
    required int offset,
    required int limit,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = ClientFieldIds.name,
    bool sortAscending = true,
    Set<String> customValues1 = const {},
    Set<String> customValues2 = const {},
    Set<String> customValues3 = const {},
    Set<String> customValues4 = const {},
    String? nameContains,
    double? balanceGt,
    double? balanceLt,
    Set<String> countryIds = const {},
    Set<String> industryIds = const {},
    Set<String> sizeIds = const {},
    Set<String> classifications = const {},
    Set<String> groupSettingsIds = const {},
    Set<String> assignedUserIds = const {},
    Set<String> idNumbers = const {},
    String? vatNumberContains,
    String? numberExact,
    int? updatedFrom,
    int? updatedTo,
    int? createdFrom,
    int? createdTo,
    String? badgeModeId,
  }) {
    final q = select(clients)..where((c) => c.companyId.equals(companyId));
    // Status-tab strip (#98): the SAME predicate the tab's count uses, so
    // the number above the list and the rows in it can't disagree. Applied
    // here (pre-LIMIT) rather than post-decode, so the Drift window stays
    // aligned with the page count.
    final badgeFilter = badgeModeListFilter(badgeModeId, companyId: companyId);
    if (badgeFilter != null) q.where((_) => badgeFilter);

    // State filter: OR'd group across the requested states. An empty set
    // means "no state restriction" — show every row regardless of
    // archived/deleted status. This mirrors the repo's `_stateFilters`,
    // which omits the `client_status` param in the same case.
    if (states.isNotEmpty) {
      q.where(
        (c) => entityStateFilter(
          states: states,
          archivedAt: c.archivedAt,
          isDeleted: c.isDeleted,
        ),
      );
    }

    if (search != null && search.isNotEmpty) {
      final pattern = '%$search%';
      q.where(
        (c) =>
            c.name.like(pattern) |
            c.number.like(pattern) |
            c.email.like(pattern) |
            c.idNumber.like(pattern) |
            c.customValue1.like(pattern) |
            c.customValue2.like(pattern) |
            c.customValue3.like(pattern) |
            c.customValue4.like(pattern),
      );
    }

    // Mirrors the server's `name=value` filter (SQL LIKE %value%) so the
    // local watch narrows in lockstep with what the server returns. Without
    // this, the locally cached clients from prior fetches bleed through
    // even when the chip is applied.
    if (nameContains != null && nameContains.isNotEmpty) {
      q.where((c) => c.name.like('%$nameContains%'));
    }

    // Numeric balance comparison. The balance column is stored as TEXT
    // (Decimal.toString()), so cast to REAL before comparing — same
    // pattern the sort ordering uses. Mirrors the server-side
    // `balance=value:gt` / `value:lt` filter.
    if (balanceGt != null || balanceLt != null) {
      const balanceReal = CustomExpression<double>('CAST(balance AS REAL)');
      if (balanceGt != null) {
        q.where((c) => balanceReal.isBiggerThanValue(balanceGt));
      }
      if (balanceLt != null) {
        q.where((c) => balanceReal.isSmallerThanValue(balanceLt));
      }
    }

    if (customValues1.isNotEmpty) {
      q.where((c) => c.customValue1.isIn(customValues1.toList()));
    }
    if (customValues2.isNotEmpty) {
      q.where((c) => c.customValue2.isIn(customValues2.toList()));
    }
    if (customValues3.isNotEmpty) {
      q.where((c) => c.customValue3.isIn(customValues3.toList()));
    }
    if (customValues4.isNotEmpty) {
      q.where((c) => c.customValue4.isIn(customValues4.toList()));
    }

    // Denormalized server-filter mirrors (v55). Each guards on a non-empty
    // selection and matches the payload id form with no decode — see
    // clients_table.dart / billing_extra_filters.dart.
    if (countryIds.isNotEmpty) {
      q.where((c) => c.countryId.isIn(countryIds.toList()));
    }
    if (industryIds.isNotEmpty) {
      q.where((c) => c.industryId.isIn(industryIds.toList()));
    }
    if (sizeIds.isNotEmpty) {
      q.where((c) => c.sizeId.isIn(sizeIds.toList()));
    }
    if (classifications.isNotEmpty) {
      q.where((c) => c.classification.isIn(classifications.toList()));
    }
    if (groupSettingsIds.isNotEmpty) {
      q.where((c) => c.groupSettingsId.isIn(groupSettingsIds.toList()));
    }
    if (assignedUserIds.isNotEmpty) {
      q.where((c) => c.assignedUserId.isIn(assignedUserIds.toList()));
    }
    // `id_number` is exact-match server-side (reverted from the briefly-LIKE
    // v5 PR). `IdNumberFilterKey` is a multi-value membership key, so mirror
    // it the same way as the other denormalized membership columns above —
    // exact equality to any selected value.
    if (idNumbers.isNotEmpty) {
      q.where((c) => c.idNumber.isIn(idNumbers.toList()));
    }
    // Server `vat_number` is substring LIKE — mirror with LIKE. `number` is
    // exact-match server-side, so mirror with an exact predicate (no LIKE).
    if (vatNumberContains != null && vatNumberContains.isNotEmpty) {
      q.where((c) => c.vatNumber.like('%$vatNumberContains%'));
    }
    if (numberExact != null && numberExact.isNotEmpty) {
      q.where((c) => c.number.equals(numberExact));
    }
    // `updated_at_range` / `created_at_range` — inclusive epoch-seconds
    // windows on the `updated_at` / `created_at` columns (the
    // `DateColumnFilterKey` between comparator).
    if (updatedFrom != null) {
      q.where((c) => c.updatedAt.isBiggerOrEqualValue(updatedFrom));
    }
    if (updatedTo != null) {
      q.where((c) => c.updatedAt.isSmallerOrEqualValue(updatedTo));
    }
    if (createdFrom != null) {
      q.where((c) => c.createdAt.isBiggerOrEqualValue(createdFrom));
    }
    if (createdTo != null) {
      q.where((c) => c.createdAt.isSmallerOrEqualValue(createdTo));
    }

    final mode = sortAscending ? OrderingMode.asc : OrderingMode.desc;
    q.orderBy([
      (c) =>
          OrderingTerm(expression: _sortExpression(c, sortField), mode: mode),
      // Always tiebreak on id so paginated reads are stable when the primary
      // sort has duplicates (common for balance=0 or empty number).
      (c) => OrderingTerm(expression: c.id, mode: mode),
    ]);
    q.limit(limit, offset: offset);
    return q.watch().distinctRows();
  }

  /// Wire-id → Drift ordering expression. Most ids map to a dedicated Drift
  /// column; the rest fall through to `json_extract(payload, '$.<id>')` so the
  /// table can be sorted by any column the user has shown — including fields
  /// we don't denormalize (address, contact name, …).
  ///
  /// Safety contract: [field] MUST be in [kClientColumnIds]. The asserts
  /// fail in debug builds (catches misuse during development); in release
  /// builds we degrade to sorting by `name` so a stray field id from a stale
  /// persisted filter can't crash the list.
  Expression _sortExpression(Clients c, String field) {
    assert(
      kClientColumnIds.contains(field),
      'ClientDao._sortExpression: unknown column id "$field". '
      'Validate against kClientColumnIds in the ViewModel before calling.',
    );
    if (!kClientColumnIds.contains(field)) {
      return c.name; // release-mode safety net for the assert above.
    }
    switch (field) {
      case ClientFieldIds.name:
        return c.name;
      case ClientFieldIds.number:
        return c.number;
      // Balance is stored as text (Decimal.toString()); sorting it as text
      // puts "9" after "1000". Cast to REAL so the ordering is numeric.
      case ClientFieldIds.balance:
        return const CustomExpression<double>('CAST(balance AS REAL)');
      case ClientFieldIds.updatedAt:
        return c.updatedAt;
      case ClientFieldIds.createdAt:
        return c.createdAt;
      case ClientFieldIds.archivedAt:
        return c.archivedAt;
      case ClientFieldIds.custom1:
        return c.customValue1;
      case ClientFieldIds.custom2:
        return c.customValue2;
      case ClientFieldIds.custom3:
        return c.customValue3;
      case ClientFieldIds.custom4:
        return c.customValue4;
    }
    // Monetary payload fields: cast to REAL so "9" < "1000".
    if (field == ClientFieldIds.paidToDate ||
        field == ClientFieldIds.creditBalance) {
      return CustomExpression<double>(
        "CAST(json_extract(payload, '\$.$field') AS REAL)",
      );
    }
    // Columns whose id is NOT a payload key. The generic fallback below
    // interpolates the column id straight into the JSON path, so these
    // resolved to NULL for every row — the primary ordering term became a
    // constant and the list collapsed into internal-id order (silently: the
    // header still showed its sort arrow).
    //   * contact_name / contact_phone are derived from the `contacts[]`
    //     array by the cell builders, which render `_primary()` (the
    //     `is_primary` contact, else the first). There is no denormalized
    //     column for them, so these sort on `contacts[0]` — an approximation
    //     that differs only for a multi-contact client whose primary isn't
    //     first, and the same one the server's `ClientFilters::sort` makes.
    //     `contact_email` is exact (see below).
    //   * last_login_at's payload key is `last_login`.
    switch (field) {
      case ClientFieldIds.contactName:
        return CustomExpression<String>(
          "LOWER(TRIM(COALESCE(json_extract(payload, '\$.contacts[0].first_name'), '') "
          "|| ' ' || COALESCE(json_extract(payload, '\$.contacts[0].last_name'), '')))",
        );
      case ClientFieldIds.contactEmail:
        // Exact: `clients.email` is denormalized with the SAME
        // primary-else-first rule the cell builder uses (`_primaryEmailOf`),
        // so this orders by precisely what the column displays — and it's an
        // indexed column rather than a JSON scan.
        return c.email.lower();
      case ClientFieldIds.contactPhone:
        return CustomExpression<String>(
          "COALESCE(json_extract(payload, '\$.contacts[0].phone'), '')",
        );
      case ClientFieldIds.lastLoginAt:
        return CustomExpression<int>(
          "COALESCE(json_extract(payload, '\$.last_login'), 0)",
        );
    }
    // Generic payload fallback. `LOWER(COALESCE(...))` matches every explicit
    // case above: without it SQLite's BINARY collation sorts "Zurich" before
    // "amsterdam" on City / State / Website / Notes, while the adjacent Name
    // column on the same screen sorts case-insensitively.
    return CustomExpression<String>(
      "LOWER(COALESCE(json_extract(payload, '\$.$field'), ''))",
    );
  }

  /// One page of full client rows for the contacts-sync reconcile.
  ///
  /// A [Future], not a [Stream], and paged rather than "all rows": a reconcile
  /// is a one-shot pass over potentially thousands of clients, each carrying a
  /// full JSON `payload`, so a watch stream would hold every decoded row in
  /// memory and re-run on every unrelated write. Callers loop on [offset] until
  /// a short page comes back.
  ///
  /// Active only — an archived client has stopped trading and shouldn't keep a
  /// card on the user's phone. Ordered by `id` so paging is stable even while
  /// rows are being written underneath it (`display_name` is not unique and a
  /// concurrent rename could skip or repeat a row).
  Future<List<ClientRow>> pageForContactSync({
    required String companyId,
    required int offset,
    required int limit,
    String? assignedUserId,
  }) {
    final q = select(clients)
      ..where(
        (c) =>
            c.companyId.equals(companyId) &
            c.isDeleted.equals(false) &
            c.archivedAt.isNull() &
            (assignedUserId == null || assignedUserId.isEmpty
                ? const Constant(true)
                : c.assignedUserId.equals(assignedUserId)),
      )
      ..orderBy([(c) => OrderingTerm(expression: c.id)])
      ..limit(limit, offset: offset);
    return q.get();
  }

  /// Stream `(id, name)` pairs for active clients in this company. Cheap
  /// alternative to `watchPage` for filter-key suggestions and chip name
  /// resolution — selects only the two columns needed and orders by name.
  Stream<List<({String id, String name})>> watchActiveNames({
    required String companyId,
  }) {
    final q = selectOnly(clients)
      ..addColumns([clients.id, clients.displayName, clients.name])
      ..where(
        clients.companyId.equals(companyId) &
            clients.isDeleted.equals(false) &
            clients.archivedAt.isNull(),
      )
      ..orderBy([OrderingTerm(expression: clients.displayName.lower())]);
    return q
        .map((row) {
          final display = row.read<String>(clients.displayName) ?? '';
          return (
            id: row.read<String>(clients.id) ?? '',
            name: display.isNotEmpty
                ? display
                : (row.read<String>(clients.name) ?? ''),
          );
        })
        .watch()
        .distinctRows();
  }

  /// Distinct non-empty values of `custom_value{columnIndex}` for the given
  /// company, ordered ascending. Drives the bottom-sheet option list for
  /// custom-field filtering.
  Stream<List<String>> watchDistinctCustomValues({
    required String companyId,
    required int columnIndex,
  }) {
    final column = switch (columnIndex) {
      1 => clients.customValue1,
      2 => clients.customValue2,
      3 => clients.customValue3,
      4 => clients.customValue4,
      _ => throw ArgumentError('columnIndex must be 1..4 (got $columnIndex)'),
    };
    final q = selectOnly(clients, distinct: true)
      ..addColumns([column])
      ..where(clients.companyId.equals(companyId) & column.equals('').not())
      ..orderBy([OrderingTerm(expression: column)]);
    return q.map((row) => row.read(column)!).watch().distinctRows();
  }
}
