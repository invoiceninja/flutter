import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **An action that changes a record is gated on `AuthSession.canEditRecord`,
/// never on `can('edit_<entity>')` alone.**
///
/// The server's rule (`EntityPolicy::edit`) has three arms — an admin, a
/// holder of `edit_<entity>`, **or the record's creator or assignee** — and a
/// user without `view_<entity>` is listed only records they created or are
/// assigned. So for the commonest restricted user ("may create tasks, nothing
/// else") the third arm is the only one that ever applies, and a gate written
/// as `me.can('edit_task')` hides Archive, Restore and Delete on every task
/// they can see.
///
/// That shipped once, on eleven entities at a time, and no test noticed:
/// every fixture is an admin, who passes any gate. Hence a scan of the source
/// rather than another fixture.
void main() {
  /// `(file, token)` pairs where a bare permission check is right, with why.
  const allowed = <String, String>{
    // Add To Invoice edits an invoice not yet chosen; whose it is cannot be
    // asked. Paired with `create_invoice` in each of the three.
    'task_actions.dart|edit_invoice': 'invoice is picked later',
    'project_actions.dart|edit_invoice': 'invoice is picked later',
    'expense_actions.dart|edit_invoice': 'invoice is picked later',
    // The local row carries no creator (`bank_transactions` has no `user_id`
    // column), so the creator arm is approximated with the create permission.
    'transaction_actions.dart|edit_bank_transaction': 'no creator on the row',
    // Bank accounts have no creator on the row either, and their other
    // writes are admin-only on the server.
    'bank_account_actions.dart|edit_bank_integration': 'no creator on the row',
  };

  test('no action file gates a record on the edit permission alone', () {
    final call = RegExp(r"\.can\(\s*'(edit_[a-z_]+)'\s*\)");
    final offenders = <String>[];
    final seen = <String>{};
    var scanned = 0;
    for (final f
        in Directory('lib/ui/features')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('_actions.dart'))) {
      scanned++;
      final name = f.uri.pathSegments.last;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        // A comment may quote the server's PHP.
        if (lines[i].trimLeft().startsWith('//')) continue;
        for (final m in call.allMatches(lines[i])) {
          final key = '$name|${m.group(1)}';
          seen.add(key);
          if (!allowed.containsKey(key)) {
            offenders.add('${f.path}:${i + 1}  can(\'${m.group(1)}\')');
          }
        }
      }
    }
    expect(scanned, greaterThan(12), reason: 'the glob stopped matching');
    expect(
      offenders,
      isEmpty,
      reason:
          'gate on `session.canEditRecord(entity, createdBy:, assignedTo:, '
          'recordId:)` — the creator and the assignee may edit too:\n'
          '  ${offenders.join('\n  ')}',
    );
    // An entry nothing uses any more is a rule nobody is checking.
    expect(
      allowed.keys.where((k) => !seen.contains(k)),
      isEmpty,
      reason: 'stale allowlist entries',
    );
  });

  test('every action file with a lifecycle gate uses canEditRecord', () {
    // The positive half: the files that used to hold the bare gate.
    for (final name in const [
      'client',
      'vendor',
      'project',
      'task',
      'expense',
      'recurring_expense',
      'product',
      'payment',
      'expense_category',
      'payment_link',
      'invoice',
      'quote',
      'credit',
      'recurring_invoice',
      'purchase_order',
    ]) {
      final file = Directory('lib/ui/features')
          .listSync(recursive: true)
          .whereType<File>()
          .firstWhere((f) => f.path.endsWith('/${name}_actions.dart'));
      expect(
        file.readAsStringSync(),
        contains('canEditRecord('),
        reason: '${file.path} no longer asks the record rule',
      );
    }
  });
}
