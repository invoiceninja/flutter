import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/features/dashboard/view_models/async_section.dart';

/// `ListSectionState` is the one order every dashboard list surface renders in
/// — the wide `DashboardListCard`, `ActivityCard`, the mobile list cards — and
/// the one `DashboardViewModel.emptyPanels` hides by
/// (invoiceninja/flutter#161). "Empty" must mean exactly the state a card
/// renders as "No …", or a hidden panel would have had something to say.
void main() {
  test('nothing loaded yet is loading, not empty', () {
    expect(
      const AsyncSection<List<int>>.idle().listState,
      ListSectionState.loading,
    );
    expect(
      const AsyncSection<List<int>>.loading().listState,
      ListSectionState.loading,
    );
  });

  test('a failure with nothing cached is failed, not empty', () {
    expect(
      AsyncSection<List<int>>.error(Exception('offline')).listState,
      ListSectionState.failed,
    );
  });

  test('a loaded empty list is empty', () {
    expect(
      const AsyncSection<List<int>>.ready(<int>[]).listState,
      ListSectionState.empty,
    );
  });

  test('a failure over a cached empty list is still empty', () {
    // The cache already answered; the refresh failing doesn't make the panel
    // have something to show.
    expect(
      AsyncSection<List<int>>.error(
        Exception('offline'),
        data: const <int>[],
      ).listState,
      ListSectionState.empty,
    );
  });

  test('rows are rows, stale or not', () {
    expect(
      const AsyncSection<List<int>>.ready(<int>[1]).listState,
      ListSectionState.rows,
    );
    expect(
      AsyncSection<List<int>>.error(
        Exception('offline'),
        data: const <int>[1],
      ).listState,
      ListSectionState.rows,
    );
  });

  test('isLoadedEmpty agrees with the classifier', () {
    expect(isLoadedEmpty(null), isFalse);
    expect(isLoadedEmpty(const <int>[]), isTrue);
    expect(isLoadedEmpty(const <int>[1]), isFalse);
  });
}
