import 'package:admin/domain/columns/column_cells.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/user_name_label.dart';

/// Factories for the columns every entity list shares.
///
/// Notes, the record-metadata block (created / archived / state / deleted /
/// documents / created-by / assigned-to) and simple flags have identical widget
/// anatomy across fifteen registries — only the accessor differs. They live here
/// once rather than as fifteen near-identical literals.
///
/// **Sortability rule**: a real Drift column is sortable and needs a matching
/// `_sortExpression` case in the entity's DAO; anything derived or payload-only
/// passes `sortable: false` and joins the `displayOnly` map in
/// `test/domain/columns/sortable_columns_test.dart`. The default on each factory
/// below is the answer that holds for most entities; callers override where
/// their table differs (e.g. `assigned_user_id` is a real column on invoices but
/// payload-only on tasks).
///
/// Deliberately NOT named `*_columns.dart`: `test/lint/layering_test.dart` keys
/// its "registry" predicate on that exact suffix, and this file is a helper, not
/// a registry. Like `column_cells.dart` it sits under `lib/domain/` while being
/// a UI helper — the same pre-existing misfiling, not a new one.

/// Free-text notes cell (`public_notes` / `private_notes`).
///
/// Display-only by default: on most tables the notes live in the `payload` JSON
/// blob with no column to order by. Clients and Vendors denormalize them and
/// pass `sortable: true`.
ColumnDefinition<T> colNotes<T>(
  String id,
  String Function(T entity) get, {
  required String labelKey,
  double width = 240,
  bool sortable = false,
}) => ColumnDefinition<T>(
  id: id,
  labelKey: labelKey,
  width: width,
  sortable: sortable,
  cellBuilder: (e, _) => cellText(get(e)),
  valueBuilder: (e) => cellNonZeroString(get(e)),
);

/// Record creation timestamp. `created_at` is a real column on every entity
/// table (`EntityTimestampColumns`), so this is sortable everywhere.
///
/// `labelKey: 'created'` matches what `client_columns.dart`,
/// `vendor_columns.dart` and `product_columns.dart` already ship; `created_at`
/// ("Date Created") also exists but renaming three live registries to match
/// React buys nothing.
ColumnDefinition<T> colCreatedAt<T>(
  String id,
  DateTime Function(T entity) get, {
  bool sortable = true,
}) => ColumnDefinition<T>(
  id: id,
  labelKey: 'created',
  width: 110,
  sortable: sortable,
  // Epoch 0 means "not set", not 1 Jan 1970. The Drift column is
  // `withDefault(const Constant(0))`, so a row written before it was
  // backfilled — or one whose server genuinely sent 0 — would otherwise paint
  // a nonsense date. Defence in depth: the real guarantee is the `createdAt`
  // overlay in each repository's `_fromRow`.
  cellBuilder: (e, ctx) {
    final at = get(e);
    return at.millisecondsSinceEpoch == 0 ? cellEmpty() : cellDate(at, ctx);
  },
  valueBuilder: (e) {
    final at = get(e);
    return at.millisecondsSinceEpoch == 0 ? null : at.toIso8601String();
  },
);

/// Server `updated_at`. Real column on every entity table, so sortable.
///
/// Epoch 0 is "never synced", not 1 Jan 1970 — a record created offline carries
/// 0 until the server echoes one back, and this is a DEFAULT column on almost
/// every list. `company_gateway_columns.dart` has guarded it this way all
/// along; the factory makes that uniform.
ColumnDefinition<T> colUpdatedAt<T>(
  String id,
  DateTime Function(T entity) get, {
  double width = 120,
  bool sortable = true,
}) => ColumnDefinition<T>(
  id: id,
  labelKey: 'last_updated',
  width: width,
  sortable: sortable,
  cellBuilder: (e, ctx) {
    final at = get(e);
    return at.millisecondsSinceEpoch == 0 ? cellEmpty() : cellDate(at, ctx);
  },
  valueBuilder: (e) {
    final at = get(e);
    return at.millisecondsSinceEpoch == 0 ? null : at.toIso8601String();
  },
);

/// When the record was archived, or an em-dash while it is active. Real column
/// on every entity table.
ColumnDefinition<T> colArchivedAt<T>(
  String id,
  DateTime? Function(T entity) get, {
  bool sortable = true,
}) => ColumnDefinition<T>(
  id: id,
  labelKey: 'archived',
  width: 110,
  sortable: sortable,
  cellBuilder: (e, ctx) {
    final at = get(e);
    return at == null ? cellEmpty() : cellDate(at, ctx);
  },
  valueBuilder: (e) => get(e)?.toIso8601String(),
);

/// Active / Archived / Deleted, derived from the same two columns
/// `entityStateFilter` reads — so a row the state filter calls active can never
/// render here as archived.
///
/// Always `sortable: false`: the value is a `CASE` over two columns, not a
/// column, and the list already offers state as a filter and a status tab.
ColumnDefinition<T> colEntityState<T>(
  String id, {
  required DateTime? Function(T entity) archivedAt,
  required bool Function(T entity) isDeleted,
}) => ColumnDefinition<T>(
  id: id,
  labelKey: 'entity_state',
  width: 110,
  sortable: false,
  cellBuilder: (e, ctx) => cellText(
    ctx.tr(
      entityStateOf(
        archivedAt: archivedAt(e),
        isDeleted: isDeleted(e),
      ).labelKey,
    ),
  ),
  // `serverName`, not `.name`: `valueBuilder` is the canonical string, and
  // `serverName` is the token the `status=` query param uses. Identical for all
  // three values today; this keeps it honest if they ever diverge.
  valueBuilder: (e) => entityStateOf(
    archivedAt: archivedAt(e),
    isDeleted: isDeleted(e),
  ).serverName,
);

/// Localized Yes / No for a boolean field (`is_deleted`, `is_running`, …).
ColumnDefinition<T> colFlag<T>(
  String id,
  bool Function(T entity) get, {
  required String labelKey,
  double width = 110,
  bool sortable = true,
}) => ColumnDefinition<T>(
  id: id,
  labelKey: labelKey,
  width: width,
  sortable: sortable,
  cellBuilder: (e, ctx) => cellText(ctx.tr(get(e) ? 'yes' : 'no')),
  // Only the true rows are worth copying — otherwise an `is_deleted` column
  // paints a copy affordance over "No" on every row of a normal list.
  valueBuilder: (e) => get(e) ? 'true' : null,
);

/// Number of attached documents, or an em-dash for none.
///
/// Always `sortable: false`. The rows carry documents as a nullable JSON TEXT
/// column, and `json_array_length` raises "malformed JSON" on the `''` an older
/// row can hold — the throw would be synchronous inside `watchPage`, leaving the
/// watch subscription cancelled and every later search silently dead. A count
/// sort would need a denormalized integer column and a migration.
ColumnDefinition<T> colDocumentsCount<T>(
  String id,
  int Function(T entity) count,
) => ColumnDefinition<T>(
  id: id,
  labelKey: 'documents',
  width: 110,
  align: ColumnAlign.end,
  sortable: false,
  cellBuilder: (e, _) {
    final n = count(e);
    return n == 0 ? cellEmpty() : cellText('$n');
  },
  valueBuilder: (e) {
    final n = count(e);
    return n == 0 ? null : '$n';
  },
);

/// A user id resolved to a display name against the local roster
/// (`UserRepository.applyBundle`) — never the raw hashed id.
///
/// [labelKey] is `user` for the record's creator and `assigned_user` for its
/// assignee. **Never `created_by`**: that key is "Created by :name", and
/// `test/lint/no_unsubstituted_placeholders_test.dart` watches `labelKey:`, so
/// it would fail the build rather than leak the raw token. React labels its
/// created-by column `user` for the same reason.
///
/// Display-only by default — `user_id` is payload-only on every table, and
/// ordering by a hashed id is worthless anyway. Entities whose table has a real
/// `assigned_user_id` column pass `sortable: true`.
ColumnDefinition<T> colUserName<T>(
  String id,
  String Function(T entity) get, {
  required String labelKey,
  bool sortable = false,
}) => ColumnDefinition<T>(
  id: id,
  labelKey: labelKey,
  width: 160,
  sortable: sortable,
  cellBuilder: (e, _) {
    final userId = get(e);
    return userId.isEmpty ? cellEmpty() : UserNameLabel(userId: userId);
  },
  valueBuilder: (e) => cellNonZeroString(get(e)),
);
