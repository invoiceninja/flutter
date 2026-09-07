import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/list/standard_crud_bulk_actions.dart';

/// Guards the "never stack two modals in front of one bulk action" rule that
/// the Confirm-actions feature depends on (invoiceninja/flutter#49).
///
/// `EntityListScreenScaffold._onBulk` opens an "Are you sure?" dialog when
/// `BulkAction.confirm` is set, and separately opens `ConfirmPasswordSheet`
/// when `requiresPassword` is set. A password prompt already *is* a
/// confirmation, so an action carrying both makes the user clear two modals to
/// archive a handful of rows. Same reasoning keeps prep-dialog actions (email
/// compose, group picker) untagged.
///
/// This is a structural guard rather than a widget test on purpose: nothing in
/// the suite pumps `EntityListScreenScaffold`, so the `_onBulk` branch itself
/// is only reachable manually. Pinning the flags catches the regression that
/// actually matters.
void main() {
  group('standardCrudBulkActions flags', () {
    final actions = {
      for (final a in standardCrudBulkActions<Object>(
        isArchived: (_) => false,
        isDeleted: (_) => false,
        archive: (_) async {},
        restore: (_) async {},
        delete: (_) async {},
      ))
        a.id: a,
    };

    test('archive confirms and needs no password', () {
      expect(actions['archive']!.confirm, isTrue);
      expect(actions['archive']!.requiresPassword, isFalse);
    });

    test('delete relies on the password sheet, not a second dialog', () {
      expect(actions['delete']!.requiresPassword, isTrue);
      expect(
        actions['delete']!.confirm,
        isFalse,
        reason:
            'ConfirmPasswordSheet is already the confirmation for bulk delete',
      );
    });

    test('restore is the reversal and is not gated', () {
      expect(actions['restore']!.confirm, isFalse);
      expect(actions['restore']!.requiresPassword, isFalse);
    });
  });

  test('no BulkAction in lib/ sets both confirm and requiresPassword', () {
    // Scan each `BulkAction(...)` literal's argument list for the two flags.
    final ctor = RegExp(r'BulkAction<[^>]*>\(|BulkAction\(');
    final offenders = <String>[];
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'lib/ should exist');

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart')) continue;
      if (entity.path.endsWith('.freezed.dart')) continue;

      final content = entity.readAsStringSync();
      for (final match in ctor.allMatches(content)) {
        final args = _argumentList(content, match.end - 1);
        if (args == null) continue;
        if (RegExp(r'\bconfirm:\s*true\b').hasMatch(args) &&
            RegExp(r'\brequiresPassword:\s*true\b').hasMatch(args)) {
          final line =
              '\n'.allMatches(content.substring(0, match.start)).length + 1;
          offenders.add('${entity.path}:$line');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'A BulkAction with both confirm and requiresPassword makes the user '
          'clear an "Are you sure?" dialog AND a password sheet for one bulk '
          'op. Drop `confirm` — the password prompt is the confirmation. '
          'Found:\n  ${offenders.join('\n  ')}',
    );
  });

  group('coverage: the risky verbs are all gated', () {
    // `_onBulk` only prompts when `BulkAction.confirm` is set, and for a long
    // time the ONLY place in `lib/` that set it was `standardCrudBulkActions`'
    // archive. So multiselecting 40 invoices and hitting Auto Bill ran 40
    // gateway charges against 40 saved cards with no prompt at all, while the
    // single-record twin of every one of these verbs stopped and asked.
    // CLAUDE.md § Action confirmations names exactly these.
    const mustConfirm = {
      'mark_sent',
      'mark_paid',
      'auto_bill',
      'approve',
      'convert_to_invoice',
      'send_now',
    };

    Iterable<File> filesEndingIn(String dir, String suffix) => Directory(dir)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith(suffix));

    /// `(id, block)` for every `BulkAction<…>(…)` literal in [src].
    Iterable<({String id, String block})> bulkActionsIn(String src) sync* {
      for (final m in RegExp(r'BulkAction<[^>]+>\(').allMatches(src)) {
        final block = _argumentList(src, m.end - 1);
        if (block == null) continue;
        final id = RegExp(r"id: '([a-z_]+)'").firstMatch(block)?.group(1);
        if (id != null) yield (id: id, block: block);
      }
    }

    test('every risky bulk verb sets confirm: true', () {
      final missing = <String>[];
      for (final f in filesEndingIn(
        'lib/ui/features',
        '_list_view_model.dart',
      )) {
        for (final a in bulkActionsIn(f.readAsStringSync())) {
          if (mustConfirm.contains(a.id) && !_setsConfirmTrue(a.block)) {
            missing.add('${f.uri.pathSegments.last}: ${a.id}');
          }
        }
      }
      expect(
        missing,
        isEmpty,
        reason:
            'these fire immediately over a whole selection and are '
            'outward-facing or hard to reverse — tag them `confirm: true`',
      );
    });

    test('no confirm-tagged verb is also an onSelection action', () {
      // `_onBulk` captures `eligibleSelectedIds` BEFORE the confirm dialog and
      // re-reads `_vm.items` after it to resolve entities for an
      // `onSelection` handler. Its own comment records that this is "safe
      // today only because no `onSelection` action sets `confirm: true` — a
      // coincidence across two files, not an invariant". Tagging one re-opens
      // invoiceninja/flutter#89.
      // Scans `lib/ui` WHOLE, not just the per-entity list VMs. `archive` is
      // minted by the shared `standardCrudBulkActions` factory in
      // `lib/ui/core/list/` and is the one confirm-tagged verb no per-entity
      // file declares, so a features-only scan handed it a permanent free
      // pass: a screen adding `actionId: 'archive'` with an `onSelection:`
      // handler passed this test green while re-opening the exact bug it
      // cites. (`delete` and `purge` take the password sheet instead — see the
      // `confirm` / `requiresPassword` exclusivity test above.)
      final confirmIds = <String>{
        for (final f in filesEndingIn('lib/ui', '.dart'))
          for (final a in bulkActionsIn(f.readAsStringSync()))
            if (_setsConfirmTrue(a.block)) a.id,
      };
      expect(
        confirmIds,
        contains('archive'),
        reason:
            'the shared factory in lib/ui/core/list must be in scope — if '
            'archive is missing the scan has narrowed back to lib/ui/features '
            'and this test is vacuous for every verb the factory owns',
      );

      final clashes = <String>[];
      for (final f in filesEndingIn('lib/ui/features', '_list_screen.dart')) {
        final src = f.readAsStringSync();
        for (final m in RegExp(r'EntityListBulkAction\(').allMatches(src)) {
          final block = _argumentList(src, m.end - 1);
          if (block == null) continue;
          final id = RegExp(
            r"actionId: '([a-z_]+)'",
          ).firstMatch(block)?.group(1);
          if (id == null) continue;
          if (confirmIds.contains(id) && block.contains('onSelection:')) {
            clashes.add('${f.uri.pathSegments.last}: $id');
          }
        }
      }
      expect(clashes, isEmpty);
    });
  });
}

/// Whether [block] really passes `confirm: true` — as opposed to mentioning it
/// in a comment. A plain `contains` accepted `// confirm: true` and
/// `// TODO: confirm: true`, so commenting the flag out to silence a prompt
/// left both tests green while the guard was gone.
bool _setsConfirmTrue(String block) {
  for (final line in block.split('\n')) {
    final code = line.split('//').first;
    if (RegExp(r'\bconfirm:\s*true\b').hasMatch(code)) return true;
  }
  return false;
}

/// Returns the text between the `(` at [openParen] and its matching `)`, or
/// null when the parentheses don't balance (an unterminated literal).
String? _argumentList(String source, int openParen) {
  var depth = 0;
  for (var i = openParen; i < source.length; i++) {
    final c = source[i];
    if (c == '(') {
      depth++;
    } else if (c == ')') {
      depth--;
      if (depth == 0) return source.substring(openParen + 1, i);
    }
  }
  return null;
}
