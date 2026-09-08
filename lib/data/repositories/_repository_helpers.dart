import 'dart:convert';

import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/api/location_api_model.dart';
import 'package:admin/data/models/api/schedule_item_api_model.dart';
import 'package:admin/data/models/domain/document.dart';
import 'package:admin/data/models/domain/location.dart';
import 'package:admin/data/models/domain/schedule_item.dart';
import 'package:admin/domain/sync/mutation.dart';

/// `DateTime` → epoch seconds (Invoice Ninja's wire convention). Inverse of
/// `epochSecondsToUtc` in `models/value/parsing.dart`. Used by repository
/// `_apiToCompanion` builders when persisting timestamp columns.
int dateToEpochSeconds(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

/// Return shape for entity-repo `create` / `save`: the optimistically-written
/// domain entity plus the outbox row id that the sync engine will drain. The
/// id lets `GenericEditViewModel.save()` await a specific row when online,
/// flipping the form into a synchronous-feel UX (inline 422 / network errors
/// land on the open form instead of via the dead-row banner after pop).
class SaveResult<T> {
  const SaveResult({required this.entity, required this.outboxRowId});

  final T entity;
  final int outboxRowId;
}

/// Decode a Drift `documents` text column back into typed domain
/// [Document]s. Empty/malformed strings return `const <Document>[]` so the
/// repository's `_fromRow` can overlay a non-nullable list without
/// guarding the caller. Mirrors the lift in `models/value/parsing.dart`
/// `mapDocuments(...)` — this one starts from a JSON-encoded string, not
/// a `List<DocumentApi>?`.
List<Document> decodeDocumentsColumn(String? raw) {
  if (raw == null || raw.isEmpty) return const <Document>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((m) => Document.fromApi(DocumentApi.fromJson(m)))
          .toList(growable: false);
    }
  } catch (_) {}
  return const <Document>[];
}

/// Decode a Drift client `locations` text column back into typed domain
/// [Location]s. Empty/malformed → `const <Location>[]` so `_fromRow` can
/// overlay a non-nullable list without guarding the caller. Mirrors
/// [decodeDocumentsColumn]; the column is JSON-encoded `List<LocationApi>`.
List<Location> decodeLocationsColumn(String? raw) {
  if (raw == null || raw.isEmpty) return const <Location>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((m) => Location.fromApi(LocationApi.fromJson(m)))
          .toList(growable: false);
    }
  } catch (_) {}
  return const <Location>[];
}

/// Decode a Drift invoice `schedule` text column back into typed domain
/// [ScheduleItem]s. Empty/malformed → `const <ScheduleItem>[]`. Mirrors
/// [decodeLocationsColumn]; the column is JSON-encoded `List<ScheduleItemApi>`
/// (the invoice's read-only `schedule[]` projection).
List<ScheduleItem> decodeScheduleColumn(String? raw) {
  if (raw == null || raw.isEmpty) return const <ScheduleItem>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((m) => ScheduleItem.fromApi(ScheduleItemApi.fromJson(m)))
          .toList(growable: false);
    }
  } catch (_) {}
  return const <ScheduleItem>[];
}

/// Decode a Drift `documents` text column into the *API* DTO type, used
/// by document-mutation flows (add/delete/visibility) that need to rewrite
/// the wire-shape array before re-encoding it back into the column. The
/// growable return is deliberate — callers mutate the list.
List<DocumentApi> decodeRawDocumentsColumn(String? raw) {
  if (raw == null || raw.isEmpty) return const <DocumentApi>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(DocumentApi.fromJson)
          .toList(growable: true);
    }
  } catch (_) {}
  return <DocumentApi>[];
}

/// The server sometimes returns money as a number, sometimes as a string;
/// normalize to a string for stable storage in the Drift text column.
///
/// Shared by every repository's `_apiToCompanion`. It was previously copied
/// verbatim into eleven of them, each carrying a "Mirrors `_moneyString` in
/// `<some other repo>`" comment pointing at a different sibling.
String moneyString(Object raw) {
  if (raw is String) return raw;
  return raw.toString();
}

/// Map a billing-document clone `targetType` wire value onto its
/// [MutationKind]. Shared by the Invoice / Quote / Credit / RecurringInvoice
/// `cloneTo` enqueue paths, which each carried a byte-identical private copy.
MutationKind cloneKindFor(String targetType) {
  switch (targetType) {
    case 'invoice':
      return MutationKind.cloneToInvoice;
    case 'quote':
      return MutationKind.cloneToQuote;
    case 'credit':
      return MutationKind.cloneToCredit;
    case 'recurring_invoice':
      return MutationKind.cloneToRecurring;
    case 'purchase_order':
      return MutationKind.cloneToPurchaseOrder;
    default:
      throw ArgumentError(
        'Unknown clone target "$targetType" — must be one of '
        'invoice|quote|credit|recurring_invoice|purchase_order',
      );
  }
}
