import 'package:admin/ui/core/list/generic_list_view_model.dart';

/// Archive / Restore / Delete bulk actions — the trio every CRUD-list entity
/// exposes on the multiselect AppBar. Concat with entity-specific actions:
///
/// ```dart
/// @override
/// Iterable<BulkAction<Invoice>> get bulkActions => [
///   ...standardCrudBulkActions(
///     isArchived: isArchived,
///     isDeleted: isDeleted,
///     archive: (id) => repo.archive(companyId: companyId, id: id),
///     restore: (id) => repo.restore(companyId: companyId, id: id),
///     delete: (id) => repo.delete(companyId: companyId, id: id),
///   ),
///   BulkAction<Invoice>(id: 'email', /* ... */),
/// ];
/// ```
///
/// Delete is flagged [BulkAction.requiresPassword] because the server
/// requires `X-API-PASSWORD-BASE64` for destructive ops — and that password
/// sheet *is* its confirmation, which is why only Archive carries
/// [BulkAction.confirm]. Restore is the reversal, so it isn't gated at all.
List<BulkAction<T>> standardCrudBulkActions<T>({
  required bool Function(T) isArchived,
  required bool Function(T) isDeleted,
  required Future<void> Function(String id) archive,
  required Future<void> Function(String id) restore,
  required Future<void> Function(String id) delete,
}) => [
  BulkAction<T>(
    id: 'archive',
    labelKey: 'archive',
    eligible: (t) => !isArchived(t) && !isDeleted(t),
    apply: archive,
    confirm: true,
  ),
  BulkAction<T>(
    id: 'restore',
    labelKey: 'restore',
    eligible: (t) => isArchived(t) || isDeleted(t),
    apply: restore,
  ),
  BulkAction<T>(
    id: 'delete',
    labelKey: 'delete',
    eligible: (t) => !isDeleted(t),
    apply: delete,
    requiresPassword: true,
  ),
];
