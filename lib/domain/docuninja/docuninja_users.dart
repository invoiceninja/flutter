/// DocuNinja users as React edits them (`pages/users`): the notification
/// choices and the permissions grid. docs/docuninja.md § Users.
library;

import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/domain/docuninja/docuninja_permissions.dart';

/// The document events a user can be emailed about, in React's order
/// (`constants/notifications.ts`), each with its label key.
const kDnNotificationTypes = <(String, String)>[
  ('document_created', 'document_created_notification'),
  ('document_sent', 'document_sent_notification'),
  ('document_viewed', 'document_viewed_notification'),
  ('document_signed', 'document_signed_notification'),
  ('document_completed', 'document_completed_notification'),
  ('document_rejected', 'document_rejected_notification'),
  ('document_voided', 'document_voided_notification'),
  ('document_expired', 'document_expired_notification'),
];

/// One choice: nothing, every document (`all`), or only the user's own
/// (`all_user`). The master choice also has `custom` (per type).
enum DnNotify { none, all, allUser, custom }

/// React's notification settings: a master choice and, when it is custom,
/// one per type.
class DnNotificationChoice {
  const DnNotificationChoice(
    this.master, [
    this.perType = const {},
    this.extra = const [],
  ]);

  /// React's `useNotifications` decode.
  factory DnNotificationChoice.decode(List<String> codes) {
    if (codes.contains('all')) return const DnNotificationChoice(DnNotify.all);
    if (codes.contains('all_user')) {
      return const DnNotificationChoice(DnNotify.allUser);
    }
    if (codes.isEmpty) return const DnNotificationChoice(DnNotify.none);
    final known = {
      for (final (type, _) in kDnNotificationTypes) ...[type, '${type}_user'],
    };
    return DnNotificationChoice(
      DnNotify.custom,
      {
        for (final (type, _) in kDnNotificationTypes)
          type: codes.contains('${type}_user')
              ? DnNotify.allUser
              : codes.contains(type)
              ? DnNotify.all
              : DnNotify.none,
      },
      // Codes for events this app does not list: kept, as React keeps
      // whatever it is given, so a save never drops them.
      [
        for (final c in codes)
          if (!known.contains(c)) c,
      ],
    );
  }

  final DnNotify master;
  final Map<String, DnNotify> perType;

  /// Custom codes the app does not know, sent back as they came.
  final List<String> extra;

  DnNotify of(String type) => perType[type] ?? DnNotify.none;

  /// Picking all, own or none clears the per-type choices (React).
  DnNotificationChoice withMaster(DnNotify m) => m == DnNotify.custom
      ? DnNotificationChoice(m, perType, extra)
      : DnNotificationChoice(m);

  /// Changing one type makes the master custom (React).
  DnNotificationChoice withType(String type, DnNotify value) =>
      DnNotificationChoice(DnNotify.custom, {...perType, type: value}, extra);

  /// React's payload.
  List<String> encode() => switch (master) {
    DnNotify.all => const ['all'],
    DnNotify.allUser => const ['all_user'],
    DnNotify.none => const [],
    DnNotify.custom => [
      for (final (type, _) in kDnNotificationTypes)
        if (of(type) == DnNotify.all)
          type
        else if (of(type) == DnNotify.allUser)
          '${type}_user',
      ...extra,
    ],
  };
}

/// The permissions grid's models, in React's rows, with their label keys.
/// React labels `blueprints` with a key its own bundle lacks; the app uses
/// `blueprint`.
const kDnPermissionModels = <(String, String)>[
  ('documents', 'documents'),
  ('templates', 'templates'),
  ('blueprints', 'blueprint'),
  ('clients', 'clients'),
];

/// The grid's columns, in React's order: create, view, edit, delete, and
/// requires approval (documents only).
const kDnPermissionColumns = <(DnAction, String)>[
  (DnAction.create, 'create'),
  (DnAction.view, 'view'),
  (DnAction.edit, 'edit'),
  (DnAction.delete, 'delete'),
  (DnAction.requiresApproval, 'requires_approval'),
];

/// Whether [model] has a [action] box (requires approval is documents-only).
bool dnPermissionApplies(String model, DnAction action) =>
    action != DnAction.requiresApproval || model == 'documents';

/// Whether [permissions] grants [action] on [model] globally.
bool dnHasPermission(
  List<DnPermission> permissions,
  String model,
  DnAction action,
) => permissions.any(
  (p) =>
      p.model == model &&
      p.permissionId == action.id &&
      p.permissionableId == null,
);

/// [permissions] with [action] on [model] turned [on] (a global grant).
List<DnPermission> dnSetPermission(
  List<DnPermission> permissions,
  String model,
  DnAction action, {
  required bool on,
}) {
  final rest = [
    for (final p in permissions)
      if (!(p.model == model &&
          p.permissionId == action.id &&
          p.permissionableId == null))
        p,
  ];
  return on
      ? [...rest, DnPermission(model: model, permissionId: action.id)]
      : rest;
}

/// React's "All" row: [action] on every model that has it.
List<DnPermission> dnSetPermissionForAll(
  List<DnPermission> permissions,
  DnAction action, {
  required bool on,
}) {
  var out = permissions;
  for (final (model, _) in kDnPermissionModels) {
    if (dnPermissionApplies(model, action)) {
      out = dnSetPermission(out, model, action, on: on);
    }
  }
  return out;
}
