import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/task_api_model.dart';
import 'package:admin/data/models/domain/document.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/data/models/value/money.dart';
import 'package:admin/data/models/value/parsing.dart';

part 'task.freezed.dart';

/// Clean domain model the UI consumes. `Task.fromApi(...)` walks the raw
/// [TaskApi] DTO and parses the `time_log` wire string into typed
/// [TimeEntry]s. The `isDirty` flag is local-only — `fromApi` defaults it
/// to false, and `TaskRepository._fromRow` overlays the Drift row's value
/// so unsaved edits survive app restart.
@freezed
abstract class Task with _$Task {
  const factory Task({
    required String id,
    required String number,
    required String description,
    required Decimal rate,
    required String invoiceId,
    required String clientId,
    required String projectId,
    required String statusId,
    required int statusOrder,
    required String assignedUserId,
    required List<TimeEntry> timeLog,
    required String customValue1,
    required String customValue2,
    required String customValue3,
    required String customValue4,
    required DateTime updatedAt,
    required DateTime createdAt,
    required DateTime? archivedAt,
    required bool isDeleted,
    @Default(<Document>[]) List<Document> documents,
    // Attached tag ids (hashed). Names/colors are resolved from the tag
    // cache for rendering; `toApiJson` sends the full set (server `sync()`s).
    @Default(<String>[]) List<String> tagIds,
    // Set only when this task was converted from a calendar event — carries the
    // event link the server uses to dedupe (one task per user per event).
    TaskMeta? meta,
    @Default(false) bool isDirty,
  }) = _Task;

  factory Task.fromApi(TaskApi a) => Task(
    id: a.id,
    number: a.number,
    description: a.description,
    rate: parseMoney(a.rate),
    invoiceId: a.invoiceId,
    clientId: a.clientId,
    projectId: a.projectId,
    statusId: a.statusId,
    statusOrder: a.statusOrder ?? 0,
    assignedUserId: a.assignedUserId,
    timeLog: TimeEntry.parseLog(a.timeLog),
    customValue1: a.customValue1,
    customValue2: a.customValue2,
    customValue3: a.customValue3,
    customValue4: a.customValue4,
    updatedAt: epochSecondsToUtc(a.updatedAt),
    createdAt: epochSecondsToUtc(a.createdAt),
    archivedAt: epochSecondsToUtcOrNull(a.archivedAt),
    isDeleted: a.isDeleted,
    documents: mapDocuments(a.documents),
    tagIds: [
      for (final t in a.tags)
        if (t.id.isNotEmpty) t.id,
    ],
    meta: (a.meta?.calendarEventId.isNotEmpty ?? false)
        ? TaskMeta(calendarEventId: a.meta!.calendarEventId)
        : null,
  );
}

/// Domain mirror of the task `meta` block. Plain value type (no JSON) — the
/// API DTO [TaskMetaApi] owns the wire shape; `toApiJson` re-emits it.
@freezed
abstract class TaskMeta with _$TaskMeta {
  const factory TaskMeta({@Default('') String calendarEventId}) = _TaskMeta;
}

/// Derived state. None of these are persisted — they're computed from the
/// fields above. The UI surfaces all three (the kanban filters by
/// [isInvoiced]; the list tile renders [isRunning]; the times section
/// shows [loggedDuration]).
extension TaskDerived on Task {
  /// True when the task has been invoiced. Locked out for edits — the
  /// server treats invoiced tasks as immutable, and the edit form mirrors
  /// that with a read-only banner.
  bool get isInvoiced => invoiceId.isNotEmpty;

  /// True when the most recent time entry has no stop. Mirrors the server's
  /// `is_running` boolean; we compute it client-side for fresh edits
  /// (server flag is stale until the next save).
  bool get isRunning => timeLog.isNotEmpty && timeLog.last.isRunning;

  /// Billable elapsed time across the log, measured against [now] — the
  /// quantity that drives the invoice line (`rate × hours`). Non-billable
  /// entries are excluded, matching admin-portal's "billable hours".
  /// **Use this ONLY for invoicing**; the UI displays [loggedDuration].
  Duration billableDuration([DateTime? now]) {
    final n = now ?? DateTime.now();
    var total = Duration.zero;
    for (final e in timeLog) {
      if (!e.billable) continue;
      total += e.durationUpTo(n);
    }
    return total;
  }

  /// Total wall-clock elapsed time across EVERY entry (billable or not),
  /// measured against [now] — the duration shown everywhere in the UI
  /// (list, detail, kanban, editor). Matches admin-portal's
  /// `calculateDuration()` default. Use [billableDuration] for invoice
  /// quantities.
  Duration loggedDuration([DateTime? now]) {
    final n = now ?? DateTime.now();
    var total = Duration.zero;
    for (final e in timeLog) {
      total += e.durationUpTo(n);
    }
    return total;
  }
}

/// Serialize back to the JSON shape the server expects. `preserveTempId`
/// lets the local Drift cache keep the temp id; outbound `POST /tasks`
/// drops it so the server can assign the real one.
extension TaskPayload on Task {
  Map<String, dynamic> toApiJson({bool preserveTempId = false}) {
    return <String, dynamic>{
      if (preserveTempId || !id.startsWith('tmp_')) 'id': id,
      'number': number,
      'description': description,
      // Decimal → String so values like 35.07 don't lose precision in the
      // IEEE-754 round trip. Mirrors Product's `cost: cost.toString()`.
      'rate': rate.toString(),
      'invoice_id': invoiceId,
      'client_id': clientId,
      'project_id': projectId,
      'status_id': statusId,
      'status_order': statusOrder,
      'assigned_user_id': assignedUserId,
      'time_log': TimeEntry.encodeLog(timeLog),
      'custom_value1': customValue1,
      'custom_value2': customValue2,
      'custom_value3': customValue3,
      'custom_value4': customValue4,
      // Full-set replace: server `sync()`s the attached tags to exactly this
      // id set (empty clears). Bare ids — the server normalizes them.
      // Known bounded hazard (accepted): a Drift payload cached by an app
      // version PRE-dating the tags feature has no `tags` key, parses to [],
      // and an offline edit from it would clear tags set by other clients.
      // The window trends to zero — the server always emits `tags`
      // (TaskTransformer::transform, no include gate) and every fetch
      // rewrites non-dirty payloads — and a tri-state "absent vs empty"
      // encoding isn't worth the ripple through TaskApi/domain/copyWith.
      'tags': tagIds,
      // Only sent when converting a calendar event → task. The server dedupes
      // on this id (one task per user per event) and stores just it.
      if (meta != null && meta!.calendarEventId.isNotEmpty)
        'meta': <String, dynamic>{'calendar_event_id': meta!.calendarEventId},
    };
  }
}
