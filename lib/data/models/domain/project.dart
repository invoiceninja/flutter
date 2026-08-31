import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/project_api_model.dart';
import 'package:admin/data/models/domain/document.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/models/value/money.dart';
import 'package:admin/data/models/value/parsing.dart';

part 'project.freezed.dart';

/// Clean domain model the UI consumes. `Project.fromApi(...)` walks the
/// raw [ProjectApi] DTO. The `isDirty` flag is local-only — `fromApi`
/// defaults it to `false`, and `ProjectRepository._fromRow` overlays the
/// Drift row's value so unsaved edits survive app restart.
@freezed
abstract class Project with _$Project {
  const factory Project({
    required String id,
    required String userId,
    required String assignedUserId,
    required String clientId,
    required String number,
    required String name,
    required Decimal taskRate,
    required Date? dueDate,
    required String privateNotes,
    required String publicNotes,
    required double budgetedHours,

    /// Optional money budget, independent of `budgetedHours`. The server's
    /// project charts fall back to `budgetedHours × taskRate` when this is
    /// zero (`ProjectBurnUpService::budgetedAmount`).
    required Decimal budgetedAmount,
    required double currentHours,
    required String customValue1,
    required String customValue2,
    required String customValue3,
    required String customValue4,
    required String color,
    required DateTime updatedAt,
    required DateTime createdAt,
    required DateTime? archivedAt,
    required bool isDeleted,
    @Default(<Document>[]) List<Document> documents,
    // Attached tag ids (hashed); names/colors resolved from the tag cache.
    @Default(<String>[]) List<String> tagIds,
    @Default(false) bool isDirty,
  }) = _Project;

  factory Project.fromApi(ProjectApi a) => Project(
    id: a.id,
    userId: a.userId,
    assignedUserId: a.assignedUserId,
    clientId: a.clientId,
    number: a.number,
    name: a.name,
    taskRate: parseMoney(a.taskRate),
    dueDate: Date.tryParse(a.dueDate),
    privateNotes: a.privateNotes,
    publicNotes: a.publicNotes,
    budgetedHours: a.budgetedHours.toDouble(),
    budgetedAmount: parseMoney(a.budgetedAmount),
    currentHours: a.currentHours.toDouble(),
    customValue1: a.customValue1,
    customValue2: a.customValue2,
    customValue3: a.customValue3,
    customValue4: a.customValue4,
    color: a.color,
    updatedAt: epochSecondsToUtc(a.updatedAt),
    createdAt: epochSecondsToUtc(a.createdAt),
    archivedAt: epochSecondsToUtcOrNull(a.archivedAt),
    isDeleted: a.isDeleted,
    documents: mapDocuments(a.documents),
    tagIds: [
      for (final t in a.tags)
        if (t.id.isNotEmpty) t.id,
    ],
  );
}

/// Serialize back to the JSON shape the server expects. `preserveTempId`
/// lets the local Drift cache keep the temp id; outbound `POST /projects`
/// drops it so the server can assign the real one.
extension ProjectPayload on Project {
  Map<String, dynamic> toApiJson({bool preserveTempId = false}) {
    return <String, dynamic>{
      if (preserveTempId || !id.startsWith('tmp_')) 'id': id,
      'assigned_user_id': assignedUserId,
      // The server ignores this (it isn't fillable), but the Drift `payload`
      // column is written from this same map — so omitting it blanked the
      // list's created-by cell on every row with a pending edit. Guarded and
      // emitted exactly as Client and Product already do.
      if (userId.isNotEmpty) 'user_id': userId,
      'client_id': clientId,
      'number': number,
      'name': name,
      // Decimal → String so precision survives. Mirrors `Task.toApiJson`.
      'task_rate': taskRate.toString(),
      'due_date': dueDate?.toIso() ?? '',
      'private_notes': privateNotes,
      'public_notes': publicNotes,
      'budgeted_hours': budgetedHours,
      // Decimal → String so precision survives (see `task_rate` above).
      'budgeted_amount': budgetedAmount.toString(),
      'custom_value1': customValue1,
      'custom_value2': customValue2,
      'custom_value3': customValue3,
      'custom_value4': customValue4,
      'color': color,
      // Full-set replace (see `Task.toApiJson`).
      'tags': tagIds,
    };
  }
}
