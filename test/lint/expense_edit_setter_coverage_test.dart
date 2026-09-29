import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every field setter an expense edit view model declares must be reachable
/// from that feature's screens.
///
/// invoiceninja/flutter#172 was a setter with no caller: `setDate` lived on
/// `ExpenseEditViewModel`, `emptyExpense()` seeded `date`, `toApiJson` wrote
/// it — and no widget ever called it, so the edit form had no Date field on
/// any platform. `setNumber` and `setAssignedUserId` were orphaned the same
/// way, on the recurring view model too. Nothing about a missing field looks
/// wrong on screen; it is just absent.
///
/// Scoped per feature on purpose. A repo-wide "every edit-VM setter has a
/// caller" scan was tried first and is useless: setter names collide across
/// view models (`setDate` is also the payment form's), so the expense gaps
/// matched someone else's call and vanished from the report.
///
/// A source scan rather than a widget test, for the reason
/// `expense_currency_seed_test.dart` gives: these sections need `Services`,
/// live Drift streams and a router to pump.
void main() {
  final vmSetter = RegExp(r'^\s+void (set[A-Z]\w*)\(', multiLine: true);

  Set<String> declaredSetters(String vmPath) => vmSetter
      .allMatches(File(vmPath).readAsStringSync())
      .map((m) => m.group(1)!)
      .toSet();

  /// Source with every `//` tail stripped. A comment that names a setter —
  /// "see `vm.setDate`" — is not a control, and counting it would hide exactly
  /// the orphan this test exists for. Same trade as
  /// `assigned_user_picker_wiring_test.dart`'s `codeOf`: a `//` inside a
  /// string literal is cut too, which can only under-count a caller.
  String codeOf(File f) => f
      .readAsStringSync()
      .split('\n')
      .map((l) {
        final i = l.indexOf('//');
        return i == -1 ? l : l.substring(0, i);
      })
      .join('\n');

  String featureUiSource(String featureDir) {
    final buf = StringBuffer();
    for (final sub in ['views', 'widgets']) {
      final dir = Directory('$featureDir/$sub');
      if (!dir.existsSync()) continue;
      for (final f
          in dir
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        buf.writeln(codeOf(f));
      }
    }
    return buf.toString();
  }

  bool isCalled(String source, String setter) =>
      RegExp('\\.$setter\\b').hasMatch(source);

  void checkFeature({
    required String vmPath,
    required String featureDir,
    required Map<String, String> allowUnwired,
  }) {
    final setters = declaredSetters(vmPath);
    expect(
      setters.length,
      greaterThan(10),
      reason:
          'only ${setters.length} setters parsed from $vmPath — the '
          'declaration shape changed and this scan went blind',
    );
    final ui = featureUiSource(featureDir);

    final orphaned = [
      for (final s in setters)
        if (!isCalled(ui, s) && !allowUnwired.containsKey(s)) s,
    ]..sort();
    expect(
      orphaned,
      isEmpty,
      reason:
          'these setters on $vmPath have no caller under $featureDir/views '
          'or /widgets, so the field they write has no control on screen '
          '(#172):\n  ${orphaned.join('\n  ')}',
    );

    final stale = [
      for (final s in allowUnwired.keys)
        if (isCalled(ui, s) || !setters.contains(s)) s,
    ]..sort();
    expect(
      stale,
      isEmpty,
      reason:
          'these allowlisted setters are now wired (or gone) — drop them '
          'from allowUnwired:\n  ${stale.join('\n  ')}',
    );
  }

  test('every ExpenseEditViewModel setter has a control', () {
    checkFeature(
      vmPath:
          'lib/ui/features/expenses/view_models/expense_edit_view_model.dart',
      featureDir: 'lib/ui/features/expenses',
      allowUnwired: const {},
    );
  });

  test('every RecurringExpenseEditViewModel setter has a control, or a '
      'reason it has none', () {
    checkFeature(
      vmPath:
          'lib/ui/features/recurring_expenses/view_models/'
          'recurring_expense_edit_view_model.dart',
      featureDir: 'lib/ui/features/recurring_expenses',
      allowUnwired: const {
        // `RecurringExpenseToExpenseFactory` stamps each generated expense
        // with `date = now()` and never reads the template's date, so a Date
        // field here would edit a value nothing uses.
        'setDate': 'server ignores the template date',
        // The recurring form has no Payment or Banking card yet (React's
        // has one). Known gap, outside #172 — remove each entry when its
        // field is surfaced.
        'setStatusId': 'no status control on the recurring form yet',
        'setPaymentDate': 'no Payment card on the recurring form yet',
        'setPaymentTypeId': 'no Payment card on the recurring form yet',
        'setTransactionReference': 'no Payment card on the recurring form yet',
        'setTransactionId': 'no Banking card on the recurring form yet',
        'setBankId': 'no Banking card on the recurring form yet',
      },
    );
  });
}
