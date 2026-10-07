import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/expense_api_model.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/ui/core/detail/related_tab_counts.dart';
import 'package:admin/ui/features/vendors/view_models/vendor_spend_view_model.dart';

/// `VendorSpendViewModel` stands between "the expenses this device holds" and
/// a vendor's Total Expenses figure. The server keeps no such total, expenses
/// are paged in fifty at a time, and a sum of whatever happens to be cached is
/// a confidently wrong number in the most prominent card on the screen.

Expense _expense(
  String id, {
  String amount = '10.00',
  String currencyId = '1',
  String date = '2024-03-01',
}) => Expense.fromApi(
  ExpenseApi(
    id: id,
    vendorId: 'v1',
    amount: amount,
    currencyId: currencyId,
    date: date,
    updatedAt: 1,
  ),
);

class _Counts extends ChangeNotifier implements TabCounts {
  int? expenses;

  @override
  int? countFor(String tabId) => tabId == 'expenses' ? expenses : null;

  void set(int? value) {
    expenses = value;
    notifyListeners();
  }
}

/// A vendor's expenses as the local database would stream them, and a server
/// that hands over [serverRows] a page at a time.
class _World {
  /// Two to a page, so a three-expense vendor is two requests.
  static const int pageSize = 2;

  final counts = _Counts();
  final _local = <Expense>[];
  final _controllers = <String, StreamController<List<Expense>>>{};

  /// What the server holds for the vendor.
  List<Expense> serverRows = const [];
  final fetched = <(String, int)>[];
  bool offline = false;
  bool current = true;
  var notifications = 0;

  late final VendorSpendViewModel vm = VendorSpendViewModel(
    watch: (vendorId) {
      final c = _controllers[vendorId] = StreamController<List<Expense>>();
      c.add(List.of(_local));
      return c.stream;
    },
    fetchPage: (vendorId, page) async {
      fetched.add((vendorId, page));
      if (offline) throw StateError('offline');
      final rows = serverRows.skip((page - 1) * pageSize).take(pageSize);
      for (final r in rows) {
        if (!_local.any((e) => e.id == r.id)) _local.add(r);
      }
      _controllers[vendorId]?.add(List.of(_local));
      return rows.length >= pageSize;
    },
    pageSize: pageSize,
    counts: counts,
    countTabId: 'expenses',
    isCurrent: () => current,
    maxPages: 3,
    debounce: const Duration(milliseconds: 10),
  )..addListener(() => notifications++);

  void seed(List<Expense> rows) => _local.addAll(rows);

  /// The user changed the local set — archived one from the tab below.
  void removeLocal(String id) {
    _local.removeWhere((e) => e.id == id);
    _controllers.values.last.add(List.of(_local));
  }

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 60));

  String? total() => vm.valueFor(currencyId: '1')?.total.toStringAsFixed(2);

  void dispose() {
    vm.dispose();
    counts.dispose();
    for (final c in _controllers.values) {
      unawaited(c.close());
    }
  }
}

void main() {
  group('vendorSpendOf', () {
    test('sums the vendor currency only, and dates from every expense', () {
      final spend = vendorSpendOf([
        _expense('a', amount: '100.00', date: '2024-01-05'),
        _expense('b', amount: '20.50', date: '2024-02-01'),
        // Another currency: not added as if it were dollars — but it is still
        // the most recent expense.
        _expense('c', amount: '999.00', currencyId: '3', date: '2024-06-30'),
      ], currencyId: '1');
      expect(spend.total, Decimal.parse('120.50'));
      expect(spend.lastExpense, const Date(2024, 6, 30));
    });

    test('no expenses is a real zero and no date', () {
      final spend = vendorSpendOf(const [], currencyId: '1');
      expect(spend.total, Decimal.zero);
      expect(spend.lastExpense, isNull);
    });

    test('an expense with no date does not decide the last one', () {
      final spend = vendorSpendOf([
        _expense('a', date: '2024-01-05'),
        _expense('b', date: ''),
      ], currencyId: '1');
      expect(spend.lastExpense, const Date(2024, 1, 5));
    });
  });

  group('VendorSpendViewModel', () {
    late _World w;
    setUp(() => w = _World());
    tearDown(() => w.dispose());

    test('not known until the local rows have arrived', () async {
      w.seed([_expense('a')]);
      w.vm.attach('v1');
      expect(w.total(), isNull);
      await w.settle();
      expect(w.total(), '10.00');
    });

    test('with no count from the server, the cached sum is shown and nothing '
        'is asked', () async {
      // Offline, or the count simply has not landed: the app shows what this
      // device holds, as it does everywhere else.
      w.seed([_expense('a'), _expense('b')]);
      w.vm.attach('v1');
      await w.settle();
      expect(w.total(), '20.00');
      expect(w.fetched, isEmpty);
    });

    test(
      'a count the device already meets is proof, and costs no request',
      () async {
        w.seed([_expense('a'), _expense('b')]);
        w.vm.attach('v1');
        await w.settle();
        w.counts.set(2);
        await w.settle();
        expect(w.total(), '20.00');
        expect(w.fetched, isEmpty);
      },
    );

    test('a count the device falls short of withholds the figure, fetches '
        'the rest, then shows the whole', () async {
      w.serverRows = [
        _expense('a'),
        _expense('b'),
        _expense('c', amount: '5.00'),
      ];
      w.seed([_expense('a')]);
      w.vm.attach('v1');
      await w.settle();
      expect(
        w.total(),
        '10.00',
        reason: 'the cached sum, until told otherwise',
      );

      final before = w.notifications;
      w.counts.set(3);
      // Known short the moment the count lands — and the card is told, so it
      // does not keep printing a sum it now knows is partial.
      expect(w.total(), isNull);
      expect(w.notifications, greaterThan(before));

      await w.settle();
      expect(w.fetched, [('v1', 1), ('v1', 2)]);
      expect(w.total(), '25.00');
    });

    test('an expense created offline is not held against the count', () async {
      // The server has never seen it, so its count does not include it; it is
      // still money spent, and is in the sum.
      w.seed([_expense('a'), _expense('tmp_1', amount: '7.00')]);
      w.vm.attach('v1');
      await w.settle();
      w.serverRows = [_expense('a'), _expense('b')];
      w.counts.set(2);
      expect(w.total(), isNull, reason: 'one server-held row of two');
      await w.settle();
      expect(w.total(), '27.00');
    });

    test('once complete, an expense archived from the tab below does not '
        'blank the figure or fetch again', () async {
      // The count was taken before the archive, so the device now holds one
      // fewer than it says. That is the user's own edit, not a gap.
      w.seed([_expense('a'), _expense('b')]);
      w.vm.attach('v1');
      await w.settle();
      w.counts.set(2);
      await w.settle();

      w.removeLocal('b');
      await w.settle();
      expect(w.total(), '10.00');
      expect(w.fetched, isEmpty);
    });

    test('a count that grows after the device was complete is a new '
        'question, and is asked', () async {
      // A refresh found an expense recorded elsewhere. "Complete" was only
      // ever complete against the count it was proven for.
      w.seed([_expense('a'), _expense('b')]);
      w.vm.attach('v1');
      await w.settle();
      w.counts.set(2);
      await w.settle();
      expect(w.total(), '20.00');

      w.serverRows = [
        _expense('a'),
        _expense('b'),
        _expense('c', amount: '5.00'),
      ];
      w.counts.set(3);
      expect(w.total(), isNull);
      await w.settle();
      expect(w.fetched, [('v1', 1), ('v1', 2)]);
      expect(w.total(), '25.00');
    });

    test(
      'too many expenses to fetch for: withheld, and nothing is asked',
      () async {
        // maxPages is 3 at two a page.
        w.seed([_expense('a')]);
        w.vm.attach('v1');
        await w.settle();
        w.counts.set(7);
        await w.settle();
        expect(w.total(), isNull);
        expect(w.fetched, isEmpty);
      },
    );

    test('a fetch that fails leaves the figure withheld, and is retried when '
        'the device is back online', () async {
      w.serverRows = [_expense('a'), _expense('b')];
      w.seed([_expense('a')]);
      w.offline = true;
      w.vm.attach('v1');
      await w.settle();
      w.counts.set(2);
      await w.settle();
      expect(w.fetched, [('v1', 1)]);
      expect(w.total(), isNull);

      // Nothing loops while it stays offline.
      await w.settle();
      expect(w.fetched, hasLength(1));

      w.offline = false;
      w.vm.retryIfUnanswered();
      await w.settle();
      expect(w.total(), '20.00');
    });

    test('a refresh asks again only while the figure is withheld', () async {
      w.serverRows = [_expense('a'), _expense('b')];
      w.seed([_expense('a')]);
      w.offline = true;
      w.vm.attach('v1');
      await w.settle();
      w.counts.set(2);
      await w.settle();
      expect(w.total(), isNull);

      w.offline = false;
      await w.vm.refresh();
      await w.settle();
      expect(w.total(), '20.00');
      final asked = w.fetched.length;

      await w.vm.refresh();
      await w.settle();
      expect(w.fetched, hasLength(asked), reason: 'complete: nothing to ask');
    });

    test(
      'a screen whose company is no longer the active one asks nothing',
      () async {
        w.serverRows = [_expense('a'), _expense('b')];
        w.seed([_expense('a')]);
        w.current = false;
        w.vm.attach('v1');
        await w.settle();
        w.counts.set(2);
        await w.settle();
        expect(w.fetched, isEmpty);
      },
    );

    test('an unsynced vendor is never fetched for', () async {
      w.vm.attach('tmp_v');
      await w.settle();
      w.counts.set(4);
      await w.settle();
      expect(w.fetched, isEmpty);
    });

    test(
      'the record syncing under an open screen starts over on its new id',
      () async {
        w.vm.attach('tmp_v');
        await w.settle();
        w.seed([_expense('a')]);
        w.vm.attach('v1');
        expect(w.total(), isNull, reason: 'the new id has not streamed yet');
        await w.settle();
        expect(w.total(), '10.00');
      },
    );

    test('stepping past a vendor fetches nothing for it', () async {
      // The debounce: disposed before it fires.
      final other = _World()
        ..serverRows = [_expense('a'), _expense('b')]
        ..seed([_expense('a')]);
      other.vm.attach('v1');
      await Future<void>.delayed(Duration.zero);
      other.counts.set(2);
      other.dispose();
      await other.settle();
      expect(other.fetched, isEmpty);
    });
  });
}
