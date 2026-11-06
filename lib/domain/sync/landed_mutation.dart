import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:admin/domain/sync/mutation.dart';

/// An outbox row the server has confirmed — the moment `SyncRepository`
/// deletes it as delivered. Carried on `SyncRepository.landed` for the review
/// prompt, which counts finished work only once the server holds it, never
/// at enqueue time (docs/review-prompt.md).
@immutable
class LandedMutation {
  const LandedMutation({
    required this.entityType,
    required this.mutationKind,
    this.saveQueryKeys = const {},
    required this.rowCreatedAt,
    this.committedSettle = false,
  });

  /// Built from an outbox row's columns. [payload] is decoded only for a
  /// `create` / `update`, the two kinds whose save query (`__save_query`) can
  /// carry an action — a "mark paid" or "mark sent" on the edit screen.
  factory LandedMutation.fromRow({
    required String entityType,
    required String mutationKind,
    required String payload,
    required int createdAtMs,
    bool committedSettle = false,
  }) {
    var keys = const <String>{};
    if (mutationKind == MutationKind.create.wireName ||
        mutationKind == MutationKind.update.wireName) {
      try {
        final decoded = jsonDecode(payload);
        final query = decoded is Map ? decoded[kSaveQueryPayloadKey] : null;
        if (query is Map) keys = {for (final k in query.keys) '$k'};
      } on FormatException {
        // An unreadable payload carries no save query.
      }
    }
    return LandedMutation(
      entityType: entityType,
      mutationKind: mutationKind,
      saveQueryKeys: keys,
      rowCreatedAt: DateTime.fromMillisecondsSinceEpoch(
        createdAtMs,
        isUtc: true,
      ),
      committedSettle: committedSettle,
    );
  }

  /// The entity's wire name — `invoice`, `payment`, `recurring_invoice`.
  final String entityType;

  /// The [MutationKind.wireName] the row was queued under.
  final String mutationKind;

  /// The keys of the row's save query, if it had one.
  final Set<String> saveQueryKeys;

  /// When the row was queued. A payload collapsed into an older queued row
  /// keeps that row's time.
  final DateTime rowCreatedAt;

  /// The write reached the server but something after it failed (a
  /// client-too-old reply, a company switch mid-response) — still a success,
  /// but not a moment to ask anything in.
  final bool committedSettle;

  /// [mutationKind] as a [MutationKind]; null for a wire name this build
  /// doesn't know. Not `MutationKind.tryParse`, which answers only the core
  /// kinds (create, update, delete, …) and returns null for `email_entity`,
  /// `mark_paid` and every other action a win is made of.
  MutationKind? get kind {
    for (final k in MutationKind.values) {
      if (k.wireName == mutationKind) return k;
    }
    return null;
  }
}
