import 'dart:async';

import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/docuninja/docuninja_api.dart';
import 'package:admin/ui/features/docuninja/view_models/docuninja_documents_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api implements DocuNinjaApi {
  final calls = <({int page, String search, String status})>[];
  Future<DnPage<DnDocument>> Function(int page, String search) answer =
      (page, _) async => _page(page, 2);

  @override
  Future<DnPage<DnDocument>> documents({
    int page = 1,
    int perPage = 20,
    String search = '',
    String status = '',
    String sort = 'id|desc',
  }) {
    calls.add((page: page, search: search, status: status));
    return answer(page, search);
  }

  final bulkCalls = <({String action, List<String> ids})>[];
  Object? bulkError;

  @override
  Future<void> bulk(String action, List<String> ids) async {
    bulkCalls.add((action: action, ids: ids));
    if (bulkError != null) throw bulkError!;
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

DnPage<DnDocument> _page(int page, int last, [String prefix = 'd']) => DnPage(
  items: [
    for (var i = 0; i < 2; i++) DnDocument.fromJson({'id': '$prefix$page-$i'}),
  ],
  currentPage: page,
  lastPage: last,
  total: last * 2,
);

void main() {
  test('loads a page at a time, newest first, without duplicates', () async {
    final api = _Api();
    final vm = DocuNinjaDocumentsViewModel(api: api);
    await vm.refresh();
    expect(vm.items.map((d) => d.id), ['d1-0', 'd1-1']);
    expect(vm.hasMore, isTrue);
    await vm.loadMore();
    expect(vm.items, hasLength(4));
    expect(vm.hasMore, isFalse);
    await vm.loadMore();
    expect(api.calls.map((c) => c.page), [1, 2]);
  });

  test('a refresh reloads the pages on screen, not just the first', () async {
    final api = _Api()..answer = (page, _) async => _page(page, 4);
    final vm = DocuNinjaDocumentsViewModel(api: api);
    await vm.refresh();
    await vm.loadMore();
    await vm.loadMore();
    expect(vm.items, hasLength(6));
    api.calls.clear();
    await vm.refresh();
    // The user three pages down stays three pages down.
    expect(api.calls.map((c) => c.page), [1, 2, 3]);
    expect(vm.items, hasLength(6));
    expect(vm.hasMore, isTrue);
    await vm.loadMore();
    expect(api.calls.last.page, 4);
    expect(vm.items, hasLength(8));
  });

  test('refreshes in a burst share one load', () async {
    final api = _Api();
    final vm = DocuNinjaDocumentsViewModel(api: api);
    await Future.wait([vm.refresh(), vm.refresh(), vm.refresh()]);
    expect(api.calls.map((c) => c.page), [1]);
  });

  test('retrying a failed deep refresh keeps the depth', () async {
    var failPage = 0;
    final api = _Api()
      ..answer = (page, _) async {
        if (page == failPage) throw StateError('boom');
        return _page(page, 4);
      };
    final vm = DocuNinjaDocumentsViewModel(api: api);
    await vm.refresh();
    await vm.loadMore();
    await vm.loadMore();
    failPage = 2;
    await vm.refresh();
    expect(vm.error, isNotNull);
    expect(vm.items, hasLength(6), reason: 'the rows on screen stay');
    failPage = 0;
    api.calls.clear();
    await vm.retry();
    expect(api.calls.map((c) => c.page), [1, 2, 3]);
    expect(vm.items, hasLength(6));
  });

  test('a refresh stops at the last page the server has now', () async {
    var last = 3;
    final api = _Api()..answer = (page, _) async => _page(page, last);
    final vm = DocuNinjaDocumentsViewModel(api: api);
    await vm.refresh();
    await vm.loadMore();
    await vm.loadMore();
    last = 1;
    api.calls.clear();
    await vm.refresh();
    expect(api.calls.map((c) => c.page), [1]);
    expect(vm.items, hasLength(2));
    expect(vm.hasMore, isFalse);
  });

  test('a search is debounced and drops an older answer', () async {
    final api = _Api();
    final slow = Completer<DnPage<DnDocument>>();
    api.answer = (page, search) =>
        search == 'old' ? slow.future : Future.value(_page(1, 1, search));
    final vm = DocuNinjaDocumentsViewModel(
      api: api,
      searchDelay: Duration.zero,
    );
    vm.setSearch('old');
    await Future<void>.delayed(Duration.zero);
    vm.setSearch('new');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    slow.complete(_page(1, 1, 'old'));
    await Future<void>.delayed(Duration.zero);
    expect(vm.items.first.id, startsWith('new'));
  });

  test('states and statuses are sent as React\'s one comma list', () async {
    final api = _Api();
    final vm = DocuNinjaDocumentsViewModel(api: api);
    await vm.refresh();
    expect(api.calls.last.status, 'active');
    expect(vm.activeFilterCount, 0);
    vm.setFilters(statuses: {'draft', 'sent'}, states: {'active', 'archived'});
    await Future<void>.delayed(Duration.zero);
    expect(api.calls.last.status.split(',').toSet(), {
      'active',
      'archived',
      'draft',
      'sent',
    });
    expect(vm.activeFilterCount, 2);
    // No state at all means active, never every state.
    vm.setFilters(statuses: const {}, states: const {});
    await Future<void>.delayed(Duration.zero);
    expect(vm.states, {'active'});
    expect(api.calls.last.status, 'active');
  });

  test('a search during a load-more does not stop paging', () async {
    final api = _Api();
    final vm = DocuNinjaDocumentsViewModel(
      api: api,
      searchDelay: Duration.zero,
    );
    await vm.refresh();
    final stalled = Completer<DnPage<DnDocument>>();
    api.answer = (page, _) =>
        page == 2 ? stalled.future : Future.value(_page(page, 3));
    unawaited(vm.loadMore());
    expect(vm.isLoadingMore, isTrue);
    vm.setSearch('acme');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    stalled.complete(_page(2, 3));
    await Future<void>.delayed(Duration.zero);
    expect(vm.isLoadingMore, isFalse);
    expect(api.calls.last.search, 'acme');
    await vm.loadMore();
    expect(api.calls.last.page, 2);
    expect(api.calls.last.search, 'acme');
  });

  test('offline is its own error; a failure is another', () async {
    final api = _Api()
      ..answer = (_, _) async => throw const NetworkException('x');
    final vm = DocuNinjaDocumentsViewModel(api: api);
    await vm.refresh();
    expect(vm.error, DnListError.offline);
    api.answer = (_, _) async => throw StateError('boom');
    await vm.refresh();
    expect(vm.error, DnListError.failed);
  });

  test('a failed next page can be retried, and paging resumes', () async {
    final api = _Api();
    final vm = DocuNinjaDocumentsViewModel(api: api);
    await vm.refresh();
    api.answer = (_, _) async => throw const NetworkException('x');
    await vm.loadMore();
    expect(vm.error, DnListError.offline);
    expect(vm.items, hasLength(2), reason: 'the rows on screen stay');
    api.answer = (page, _) async => _page(page, 2);
    await vm.retry();
    expect(vm.error, isNull);
    expect(vm.items, hasLength(4));
  });

  test('a failed new search drops the old search\'s rows', () async {
    final api = _Api();
    final vm = DocuNinjaDocumentsViewModel(
      api: api,
      searchDelay: Duration.zero,
    );
    await vm.refresh();
    expect(vm.items, isNotEmpty);
    api.answer = (_, _) async => throw StateError('boom');
    vm.setSearch('acme');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(vm.error, DnListError.failed);
    expect(vm.items, isEmpty, reason: 'they answer another search');
  });

  test('a failed refresh of the same query keeps its rows', () async {
    final api = _Api();
    final vm = DocuNinjaDocumentsViewModel(api: api);
    await vm.refresh();
    api.answer = (_, _) async => throw const NetworkException('x');
    await vm.refresh();
    expect(vm.error, DnListError.offline);
    expect(vm.items, hasLength(2));
  });

  test('no next page while a search waits out its debounce', () async {
    final api = _Api();
    final vm = DocuNinjaDocumentsViewModel(
      api: api,
      searchDelay: const Duration(milliseconds: 50),
    );
    await vm.refresh();
    vm.setSearch('acme');
    // The rows and the page count are still the old search's: a next page
    // now would be the new search's page 2 appended to them.
    await vm.loadMore();
    expect(api.calls.map((c) => c.page), [1]);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(api.calls.last.search, 'acme');
    expect(api.calls.last.page, 1);
  });

  group('selection', () {
    test('ticks rows, selects all visible, and clears', () async {
      final vm = DocuNinjaDocumentsViewModel(api: _Api());
      await vm.refresh();
      expect(vm.isSelecting, isFalse);
      vm.enterSelectionMode();
      expect(vm.isSelecting, isTrue);
      expect(vm.countSelected, 0);
      vm.toggleSelected(vm.items.first);
      expect(vm.isSelected(vm.items.first), isTrue);
      vm.toggleSelected(vm.items.first);
      expect(vm.countSelected, 0);
      expect(vm.isSelecting, isTrue, reason: 'unticking keeps the mode');
      vm.selectAllVisible();
      expect(vm.countSelected, 2);
      vm.clearSelection();
      expect(vm.isSelecting, isFalse);
      expect(vm.countSelected, 0);
      vm.dispose();
    });

    test('a row that leaves the list leaves the selection', () async {
      final api = _Api();
      final vm = DocuNinjaDocumentsViewModel(
        api: api,
        searchDelay: Duration.zero,
      );
      await vm.refresh();
      vm.selectAllVisible();
      api.answer = (page, _) async => _page(page, 1, 'x');
      await vm.refresh();
      expect(vm.countSelected, 0, reason: 'a bulk must not reach a row gone');
      vm.dispose();
    });

    test('a bulk action is one request, then a re-read', () async {
      final api = _Api();
      final vm = DocuNinjaDocumentsViewModel(api: api);
      await vm.refresh();
      vm.selectAllVisible();
      final ids = vm.selectedIdsWhere((d) => d.id.endsWith('0'));
      expect(ids, ['d1-0']);
      api.calls.clear();
      await vm.applyBulk('archive', ids);
      expect(api.bulkCalls.single.action, 'archive');
      expect(api.bulkCalls.single.ids, ['d1-0']);
      expect(vm.isSelecting, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(api.calls, isNotEmpty, reason: 'the rows are read again');
      vm.dispose();
    });

    test('a failed bulk keeps the selection and still re-reads', () async {
      final api = _Api()..bulkError = StateError('boom');
      final vm = DocuNinjaDocumentsViewModel(api: api);
      await vm.refresh();
      vm.selectAllVisible();
      api.calls.clear();
      await expectLater(
        vm.applyBulk('delete', vm.selectedIdsWhere((_) => true)),
        throwsStateError,
      );
      expect(vm.countSelected, 2, reason: 'a retry can go again');
      expect(vm.bulkInFlight, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(api.calls, isNotEmpty, reason: 'it may have landed');
      vm.dispose();
    });
  });
}
