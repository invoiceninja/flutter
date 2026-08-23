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
