import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A cloned expense copies its source; a new one takes the company's Expense
/// Settings defaults (mark paid + default payment type, invoiceable, invoice
/// documents, tax by amount). Both reach the create screen through the one
/// staged-draft slot on `Services`, so the difference rides on a single flag,
/// and both ends of it are pinned here:
///
///  * every clone action stages with `isClone: true`, and
///  * both edit screens read it back through `takeCreateSeed` and skip
///    `seedCompanyDefaults` for a clone.
///
/// Dropping either end compiles, runs and looks right on screen — the cloned
/// expense just quietly comes up marked paid, or invoiceable, when its source
/// was neither. The view-model seeding and the `Services` round-trip have
/// their own tests; what is left is wiring, which a source scan sees and a
/// widget test would need `Services`, Drift and a router to reach.
void main() {
  /// Source with every `//` tail stripped, so prose naming a token can't
  /// satisfy a rule (same trade as `assigned_user_picker_wiring_test.dart`).
  String codeOf(String path) => File(path)
      .readAsStringSync()
      .split('\n')
      .map((l) {
        final i = l.indexOf('//');
        return i == -1 ? l : l.substring(0, i);
      })
      .join('\n');

  String dense(String s) => s.replaceAll(RegExp(r'\s+'), '');

  /// Every `goEntityCreateFullWidth(...)` call in [code], parens balanced.
  List<String> createCalls(String code) {
    const marker = 'goEntityCreateFullWidth(';
    final calls = <String>[];
    var from = 0;
    while (true) {
      final start = code.indexOf(marker, from);
      if (start == -1) break;
      var depth = 0;
      var end = start + marker.length - 1;
      for (; end < code.length; end++) {
        final ch = code[end];
        if (ch == '(') depth++;
        if (ch == ')' && --depth == 0) break;
      }
      calls.add(code.substring(start, end + 1));
      from = end + 1;
    }
    return calls;
  }

  bool targetsAnExpenseCreate(String call) =>
      call.contains("'/expenses'") || call.contains("'/recurring_expenses'");

  // A record's own action menu reaches an expense create route only to copy
  // that record — Clone, Clone to recurring / Clone to expense. Starting a
  // fresh expense is the list's "New", which stages nothing.
  for (final path in const [
    'lib/ui/features/expenses/widgets/expense_actions.dart',
    'lib/ui/features/recurring_expenses/widgets/recurring_expense_actions.dart',
  ]) {
    test('every expense create reached from ${path.split('/').last} is '
        'staged as a clone', () {
      final calls = createCalls(
        codeOf(path),
      ).where(targetsAnExpenseCreate).toList();
      expect(
        calls,
        hasLength(2),
        reason:
            '$path should stage exactly its two clone actions (Clone, and '
            'Clone to the other expense kind) — the call shape changed and '
            'this scan went blind',
      );
      for (final call in calls) {
        expect(
          dense(call).contains('isClone:true'),
          isTrue,
          reason:
              'this clone is staged without `isClone: true`, so the create '
              'screen would apply the company\'s new-expense defaults over '
              'the copied values:\n$call',
        );
      }
    });
  }

  for (final path in const [
    'lib/ui/features/expenses/views/expense_edit_screen.dart',
    'lib/ui/features/recurring_expenses/views/recurring_expense_edit_screen.dart',
  ]) {
    test('${path.split('/').last} reads the clone flag and skips the company '
        'defaults for a clone', () {
      final code = dense(codeOf(path));
      expect(
        code.contains('takeCreateSeed<'),
        isTrue,
        reason: '$path must read its seed through `takeCreateSeed`',
      );
      expect(
        code.contains('takeCreateDraft<'),
        isFalse,
        reason:
            '$path reads a seed through `takeCreateDraft`, which drops the '
            'clone flag',
      );
      expect(
        code.contains('seedCompanyDefaults('),
        isTrue,
        reason: '$path no longer seeds the company defaults at all',
      );
      expect(
        code.contains('existing==null&&!(seed?.isClone??false)'),
        isTrue,
        reason:
            '$path must gate `seedCompanyDefaults` on the seed not being a '
            'clone (`existing == null && !(seed?.isClone ?? false)`)',
      );
    });
  }
}
