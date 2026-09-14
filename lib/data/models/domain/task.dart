import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/task_api_model.dart';
import 'package:admin/data/models/domain/document.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/models/value/money.dart';
import 'package:admin/data/models/value/parsing.dart';
import 'package:admin/domain/tasks/task_schedule.dart';

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

    /// Creator. Read-only (server-assigned) and payload-backed — the `tasks`
    /// table has no `user_id` column — so the list column that renders it is
    /// display-only.
    @Default('') String userId,
    required List<TimeEntry> timeLog,

    /// The day the work is promised for (`tasks.due_date`, 2026-08-31).
    /// DATE-only on the wire, so it cannot carry a booked *time* — that still
    /// lives in a future `time_log` block. See `task_schedule.dart`.
    Date? dueDate,

    /// Allocated / budgeted time in SECONDS (`tasks.estimated_duration`),
    /// against which `workedDuration` is the actual. 0 means unset: the
    /// server distinguishes a stored `0` from `null` and we deliberately
    /// collapse them, because "estimated: zero" is not a thing a user means.
    @Default(0) int estimatedSeconds,
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
    userId: a.userId,
    // Sorted at the domain boundary, never inside `encodeLog`: the Drift
    // `is_running` column is written from this list's `.last` while `payload`
    // is written from `toApiJson`, so the two must see one order or a running
    // timer becomes unstoppable (`task_schedule.dart`).
    timeLog: sortTimeLog(TimeEntry.parseLog(a.timeLog)),
    dueDate: Date.tryParse(a.dueDate),
    estimatedSeconds: a.estimatedDuration ?? 0,
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

  /// Billable time **worked** by [now] — the quantity that drives the invoice
  /// line (`rate × hours`). Non-billable entries are excluded, matching
  /// admin-portal's "billable hours".
  /// **Use this ONLY for invoicing**; the UI displays [loggedDuration].
  ///
  /// Delegates to `workedDuration`, so a booking — a stopped entry that ends
  /// in the future — contributes **nothing**. Before that, converting a quote
  /// line into a dated task (invoiceninja/flutter#88) and then invoicing it
  /// billed the schedule: the hours were counted the moment they were booked,
  /// and again when the work was actually logged. That is the money half of
  /// invoiceninja/flutter#149's "allocated vs. worked", and it is why
  /// [loggedDuration] — which still totals every entry — must not be used
  /// for an invoice.
  /// Where this task sits relative to its own bookings at [now].
  ///
  /// Binds `due_date` and `estimated_duration` to the pure rules in
  /// `task_schedule.dart` in ONE place. Every UI surface asks the task, not the
  /// log — passing the log alone silently drops the anchor that tells a
  /// booking from a forward-looking timesheet entry, which is the whole point
  /// of the distinction.
  TaskScheduleState scheduleStateAt(DateTime now) => taskScheduleState(
    timeLog,
    now: now,
    dueDate: dueDate,
    estimatedSeconds: estimatedSeconds,
  );

  /// Time actually worked by [now] — every entry that isn't a booking.
  Duration workedTime([DateTime? now]) =>
      workedDuration(timeLog, now: now ?? DateTime.now(), dueDate: dueDate);

  /// Time booked and not yet worked — [workedTime]'s exact complement.
  Duration bookedTime([DateTime? now]) =>
      scheduledDuration(timeLog, now: now ?? DateTime.now(), dueDate: dueDate);

  /// How far past its booked start an unworked booking is, or null when this
  /// task isn't [TaskScheduleState.late].
  Duration? lateByAt(DateTime now) => lateBy(
    timeLog,
    now: now,
    dueDate: dueDate,
    estimatedSeconds: estimatedSeconds,
  );

  Duration billableDuration([DateTime? now]) => workedDuration(
    [
      for (final e in timeLog)
        if (e.billable) e,
    ],
    now: now ?? DateTime.now(),
    dueDate: dueDate,
  );

  /// Wall-clock time **worked**, billable or not — what every duration surface
  /// in the app displays.
  ///
  /// Delegates to [workedTime], so a booking contributes nothing. It used to
  /// total every entry, which meant the same booked task read `09:00` on a
  /// phone and `2:00` on a desktop, and an unstarted job showed
  /// `Duration 2:00 / Estimated 2:00` — "done". The billable/non-billable
  /// distinction this getter has always drawn against [billableDuration] is
  /// unchanged.
  Duration loggedDuration([DateTime? now]) => workedTime(now);
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
      // The server ignores this (it isn't fillable), but the Drift `payload`
      // column is written from this same map — so omitting it blanked the
      // list's created-by cell on every row with a pending edit. Guarded and
      // emitted exactly as Client and Product already do.
      if (userId.isNotEmpty) 'user_id': userId,
      'time_log': TimeEntry.encodeLog(timeLog),
      // Emitted unconditionally, both of them: `_domainToCompanion` stores
      // this map as the Drift `payload` and `_fromRow` reads the domain back
      // out of it, so an omitted key round-trips to "unset" and a local edit
      // would blank a value the user never touched. `''` is safe for the date
      // because Invoice Ninja runs `ConvertEmptyStringsToNull` globally, so
      // it reaches the `nullable` rule as null rather than failing `date:Y-m-d`.
      'due_date': dueDate?.toIso() ?? '',
      'estimated_duration': estimatedSeconds > 0 ? estimatedSeconds : null,
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
