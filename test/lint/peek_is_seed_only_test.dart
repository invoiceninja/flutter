import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CI lint: `BaseEntityRepository.peek` is a **first-frame seed**, never a
/// source of truth.
///
/// It exists for exactly one problem: the master-detail pane re-keys its
/// subtree per `:id`, so every row click MOUNTS the detail widgets afresh, and
/// a fresh mount is the one event that makes `StreamBuilder` start at
/// `AsyncSnapshot.nothing()`. Without a seed, `ClientNameLabel` paints a raw
/// hashid and swaps to the name a frame later, on every click.
///
/// The moment anything *branches* on `peek` — `if (repo.peek(...) != null)`,
/// `peek(...) ?? fetch()`, rendering it after the watch has emitted — it stops
/// being a seed and becomes a second, unsynchronised copy of state that Drift
/// owns. CLAUDE.md is explicit that Drift is the only thing the UI reads from,
/// and a stale entry here would be invisible in every test.
///
/// So: every `.peek(` in `lib/` must be the value of an `initialData:`
/// argument, feeding a `StreamBuilder` / `WatchBuilder` whose stream is
/// `watch()` for the SAME `(companyId, id)`. Anything else needs a deliberate
/// entry in [_allowed] and a comment explaining why it is still only a seed.
void main() {
  /// `path: substring that must appear in the enclosing statement`. Kept tiny
  /// on purpose — each entry is a place the seed is stashed in a field before
  /// reaching `initialData:`, not a place it is branched on.
  const allowed = <String, String>{
    // Stashes the tier-1 party currency in `_seed`, which `build` hands to
    // `initialData:` further down the same class.
    'lib/ui/core/widgets/party_money_cell.dart': 'final seed =',
    // Same shape: stashes the company in `_seed`, which `build` hands to
    // `initialData:` on the StreamBuilder below.
    'lib/ui/features/billing_shared/billing_doc_overview.dart': '_seed =',
  };

  test('lib/ only uses repository peek() as a StreamBuilder seed', () {
    final pattern = RegExp(r'\.peek\(');
    final offenders = <String>[];
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'lib/ should exist');

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart')) continue;
      if (entity.path.endsWith('.freezed.dart')) continue;

      final content = entity.readAsStringSync();
      for (final match in pattern.allMatches(content)) {
        // The declaration itself lives on the base class.
        if (entity.path.endsWith('base_entity_repository.dart')) continue;

        final lineStart = content.lastIndexOf('\n', match.start) + 1;
        final lineEnd = content.indexOf('\n', match.end);
        final line = content
            .substring(lineStart, lineEnd == -1 ? content.length : lineEnd)
            .trim();

        // Scan the whole enclosing STATEMENT, not just the line: a wrapped
        // argument list puts `initialData:` several lines above the `.peek(`,
        // and requiring a particular formatting would make this lint fail on a
        // `dart format` reflow rather than on a real violation.
        final stmtStart = [
          content.lastIndexOf(';', match.start),
          content.lastIndexOf('{', match.start),
          content.lastIndexOf('}', match.start),
        ].reduce((a, b) => a > b ? a : b);
        final window = content.substring(
          stmtStart < 0 ? 0 : stmtStart,
          lineEnd == -1 ? content.length : lineEnd,
        );

        final exempt = allowed[entity.path];
        if (window.contains('initialData:') ||
            (exempt != null && window.contains(exempt))) {
          continue;
        }
        offenders.add('${entity.path}:  $line');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'peek() is a first-frame seed for `initialData:`, not a data source. '
          'Branching on it (or rendering it after the watch emits) makes it a '
          'second copy of state Drift owns, and a stale entry would be '
          'invisible in every test. Read the contract on '
          '`BaseEntityRepository._lastSeen`. Offenders:\n'
          '${offenders.join('\n')}',
    );
  });

  // The settings cascade has its own seed pair. `resolvedIfReady` is NOT a
  // general synchronous settings source — it exists so the invoice lock banner
  // can decide on frame 1 whether ~44px of chrome exists, and it is allowed to
  // be stale. Everything that ACTS on settings must keep awaiting
  // `SettingsRepository.resolved`, which is deliberately uncached.
  //
  // A file allowlist rather than a statement-shape rule: the shape check above
  // already had to be widened once so a `dart format` reflow couldn't break it,
  // and "which files may know about the seed" is the invariant that actually
  // matters here.
  test('the settings seed accessors stay confined to their files', () {
    const allowedBySymbol = <String, Set<String>>{
      'resolvedIfReady': {
        'lib/data/repositories/settings_repository.dart',
        'lib/domain/billing/invoice_lock.dart',
      },
      'peekInvoiceLockReason': {
        'lib/domain/billing/invoice_lock.dart',
        'lib/ui/features/invoices/widgets/detail/invoice_lock_banner.dart',
      },
    };

    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart')) continue;
      if (entity.path.endsWith('.freezed.dart')) continue;
      final content = entity.readAsStringSync();
      allowedBySymbol.forEach((symbol, allowedPaths) {
        // Match CALLS (and the declaration), not prose — other files may name
        // these in comments explaining why they don't use them.
        if (!content.contains('$symbol(')) return;
        if (allowedPaths.contains(entity.path)) return;
        offenders.add('${entity.path}: references $symbol');
      });
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'The settings seed may be stale and is corrected by the async '
          '`resolved()` on the next mount. Widening its reach turns a bounded '
          'rendering optimisation into an unbounded correctness surface — any '
          'new consumer needs its own answer to "what corrects this, and '
          'when?". Offenders:\n${offenders.join('\n')}',
    );
  });
}
