import 'package:flutter/foundation.dart';

import 'package:admin/domain/entity_type.dart';

/// A call the app has just handed to the platform dialer, held until the user
/// comes back so they can be offered a chance to log it
/// (invoiceninja/flutter#120).
///
/// A plain value, never a captured closure: it is held across an app-lifecycle
/// round trip, so anything it carried into the background would keep a widget
/// tree — and its `Services`, its route, its company — alive for the duration
/// of the call. [entityType] plus [entityId] is enough for `callNoteSink` to
/// find the repository again on the other side.
///
/// **Deliberately in memory only.** Persisting it (the `phone_actions_json`
/// blob would have taken it for free) buys back only the narrow case where
/// Android kills the app mid-call — iOS and ordinary Android backgrounding
/// both survive — and costs a stored record that has to be expired, scoped to a
/// company, and cleared on logout, or it offers to file a call against a record
/// in a workspace the user has since left. Manual logging stays available from
/// the record's actions menu and its Activity tab, so a lost prompt costs a
/// convenience, not the feature.
@immutable
class PendingCallLog {
  const PendingCallLog({
    required this.entityType,
    required this.entityId,
    required this.subject,
    required this.companyId,
    required this.contactLabel,
    required this.phone,
  });

  final EntityType entityType;
  final String entityId;

  /// What the log will be titled against — a party's display name, or a
  /// document's `#number`.
  final String subject;

  /// The company that owned the record when the call was placed. Compared
  /// against the active company before the offer is shown, so switching
  /// workspaces mid-call silently drops it rather than filing the note
  /// somewhere the user is no longer looking.
  final String companyId;

  final String contactLabel;
  final String phone;

  /// The line the toast shows: who was called, as far as the app knows.
  String get displayName {
    final who = contactLabel.trim();
    if (who.isNotEmpty) return who;
    final line = phone.trim();
    return line.isNotEmpty ? line : subject.trim();
  }
}
