import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The `entity:` each `addCommentHandlers` wiring sends to
/// `POST /api/v1/activities/notes` must be one the server accepts.
///
/// `StoreNoteRequest` validates it against a fixed `in:` list of PLURAL table
/// names, so a singular `'task'` — the spelling every other note-side surface
/// uses (`hostWireName`, `entityWireName`) — is a 422 on every note. The row
/// dead-letters minutes after the user saw "Added comment", and nothing in the
/// suite would notice: `mutation_handler_coverage_test` checks only that a
/// handler is wired, never what it sends.
///
/// Source: `invoiceninja/app/Http/Requests/Activity/StoreNoteRequest.php`,
/// `rules()` → `'entity' => 'required|bail|in:…'`.
const _storeNoteRequestEntities = {
  'invoices',
  'quotes',
  'credits',
  'recurring_invoices',
  'clients',
  'vendors',
  'payments',
  'projects',
  'tasks',
  'expenses',
  'recurring_expenses',
  'bank_transactions',
  'purchase_orders',
};

void main() {
  test(
    'every addCommentHandlers wiring names an entity the server accepts',
    () {
      final code = File('lib/app/services_entity_wiring.dart')
          .readAsLinesSync()
          .map((line) {
            final i = line.indexOf('//');
            return i == -1 ? line : line.substring(0, i);
          })
          .join('\n');
      // `[^)]*` stays inside the one call: the argument list holds no nested
      // parens (`reg.ctx.activitiesApi` is a plain getter chain).
      final entities = RegExp(
        r"addCommentHandlers<\w+>\([^)]*entity:\s*'([a-z_]+)'",
      ).allMatches(code).map((m) => m.group(1)!).toList();

      expect(
        entities,
        hasLength(12),
        reason:
            'expected the twelve comment-capable entities; found '
            '${entities.length}. If a call was reshaped so this scan no longer '
            'sees it, re-point the scan rather than changing the count.',
      );
      expect(
        entities.toSet(),
        hasLength(entities.length),
        reason: 'an entity is wired twice: $entities',
      );
      expect(
        entities.where((e) => !_storeNoteRequestEntities.contains(e)),
        isEmpty,
        reason:
            "StoreNoteRequest's `in:` list rejects these, so every note "
            'filed against them would 422 and dead-letter.',
      );
    },
  );
}
