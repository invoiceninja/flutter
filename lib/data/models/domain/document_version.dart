import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/document_version_api_model.dart';
import 'package:admin/data/models/value/money.dart';
import 'package:admin/data/models/value/parsing.dart';

part 'document_version.freezed.dart';

/// One saved version of a billing document — an `activities` row that produced
/// a `Backup`, as surfaced by
/// `GET /api/v1/<entity>/{id}?include=activities.history`.
///
/// There is no field-level data here and there never can be: the server stores
/// a rendered HTML document, not an entity snapshot. The only way to *see* a
/// version is `GET /api/v1/activities/download_entity/{activityId}`, which
/// returns it as a PDF. See `docs/document-version-history.md`.
///
/// Backups exist for invoices, quotes, credits, recurring invoices and
/// purchase orders only — no other entity type has them, clients included.
@freezed
abstract class DocumentVersion with _$DocumentVersion {
  const factory DocumentVersion({
    /// The activity that produced this version. Also the path segment for the
    /// PDF download, and the `?activity_id=` the PDF route reads.
    required String activityId,

    /// The document's total *after* this event, so a delta against the
    /// previous version is meaningful.
    required Decimal amount,

    /// Always UTC — built with [epochSecondsToUtc]. A local `DateTime` here
    /// renders an ISO string with no `Z`, which `Formatter.date(showTime:
    /// true)` then treats as UTC and localizes a second time.
    required DateTime createdAt,

    /// Server activity type, as a string (`'5'`). Drives the row's label via
    /// `kActivityTypeLabelKeys` and its tone via `kActivityTones`.
    @Default('') String activityTypeId,

    /// Acting user, when one is resolvable against the local roster.
    @Default('') String userId,

    /// Set instead of [userId] when a portal contact caused the change — an
    /// approval or rejection, which is the change users least expect.
    @Default('') String contactId,

    /// Server-initiated (a reminder, a scheduled send, auto-billing).
    @Default(false) bool isSystem,
  }) = _DocumentVersion;

  const DocumentVersion._();

  /// Null unless the row carries a real backup. The `history` object is
  /// serialized even when there is none, so `id.isNotEmpty` — not
  /// `history != null` — is the gate.
  static DocumentVersion? fromApi(DocumentVersionActivityApi a) {
    final h = a.history;
    if (h == null || h.id.isEmpty) return null;
    // `activity_id` is blank on the empty-relation shell; fall back to the
    // row's own id, which is the same value whenever both are populated.
    final id = h.activityId.isNotEmpty ? h.activityId : a.id;
    if (id.isEmpty) return null;
    return DocumentVersion(
      activityId: id,
      amount: parseMoney(h.amount),
      createdAt: epochSecondsToUtc(h.createdAt),
      activityTypeId: a.activityTypeId,
      userId: a.userId,
      contactId: a.contactId,
      isSystem: a.isSystem,
    );
  }
}

/// The result of one history fetch: the versions, newest first, plus whether
/// the server's window was full.
///
/// [truncated] is not cosmetic. `Invoice::activities()` (and each sibling) is
/// `->take(50)` with no pagination, so a long-lived document silently loses
/// its oldest versions — and the oldest row held has no honest predecessor to
/// compute a delta against.
class DocumentVersionPage {
  const DocumentVersionPage({required this.versions, required this.truncated});

  const DocumentVersionPage.empty() : versions = const [], truncated = false;

  final List<DocumentVersion> versions;
  final bool truncated;

  bool get isEmpty => versions.isEmpty;
}
