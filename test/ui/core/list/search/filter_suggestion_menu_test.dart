import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_suggestion_menu.dart';
import 'package:admin/ui/core/list/search/filter_token.dart';
// Re-exports IsFilterKey + CustomFieldFilterKey alongside the client keys.
import 'package:admin/ui/features/clients/client_filter_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the alphabetical sort order the key dropdown uses. The full menu
/// pump (`FilterSuggestionMenu` + controller + vm) is heavier than the
/// file-level test policy in `token_search_field_test.dart` allows, so
/// the inline sort in `_KeyList.build` is delegated to the testable
/// top-level [compareFilterKeysByLabel] helper and unit-tested here.

class _StaticLabelKey extends FilterKey {
  const _StaticLabelKey(this._label);

  final String _label;

  @override
  String get id => _label.toLowerCase();

  @override
  String displayLabel(BuildContext context) => _label;

  @override
  FilterValueType get valueType => FilterValueType.string;

  @override
  bool isAtDefault(GenericListViewModel<dynamic> vm) => true;

  @override
  Iterable<FilterToken> tokensFrom(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
  ) => const [];

  @override
  Stream<List<FilterValueSuggestion>> watchValueSuggestions(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String query,
  ) => Stream.value(const []);

  @override
  Future<void> addValue(GenericListViewModel<dynamic> vm, String rawValue) =>
      Future.value();

  @override
  Future<void> removeValue(GenericListViewModel<dynamic> vm, String rawValue) =>
      Future.value();
}

/// Configurable fake for exercising [availableKeyPickerKeys] and the
/// [FilterKey.icon] default — `valueType` / `singleValue` / `applied` are the
/// only knobs those rules read; the `vm` argument is ignored.
class _ConfigurableKey extends FilterKey {
  const _ConfigurableKey(
    this._label, {
    this.valueType = FilterValueType.string,
    this.singleValue = false,
    this.applied = false,
  });

  final String _label;
  final bool applied;

  @override
  final FilterValueType valueType;

  @override
  final bool singleValue;

  @override
  String get id => _label.toLowerCase();

  @override
  String displayLabel(BuildContext context) => _label;

  @override
  bool isAtDefault(GenericListViewModel<dynamic> vm) => !applied;

  @override
  Iterable<FilterToken> tokensFrom(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
  ) => const [];

  @override
  Stream<List<FilterValueSuggestion>> watchValueSuggestions(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String query,
  ) => Stream.value(const []);

  @override
  Future<void> addValue(GenericListViewModel<dynamic> vm, String rawValue) =>
      Future.value();

  @override
  Future<void> removeValue(GenericListViewModel<dynamic> vm, String rawValue) =>
      Future.value();
}

/// Minimal VM stand-in: the picker rule only reads [lockedFilterKeyIds]; any
/// other access is a test bug, so it throws.
class _FakeVm implements GenericListViewModel<dynamic> {
  @override
  Set<String> get lockedFilterKeyIds => const {};

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected VM call: ${invocation.memberName}');
}

void main() {
  testWidgets(
    'compareFilterKeysByLabel sorts alphabetically (case-insensitive)',
    (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final keys = <FilterKey>[
        const _StaticLabelKey('Banana'),
        const _StaticLabelKey('apple'),
        const _StaticLabelKey('Cherry'),
      ];

      keys.sort((a, b) => compareFilterKeysByLabel(a, b, capturedContext));

      expect(keys.map((k) => k.displayLabel(capturedContext)).toList(), [
        'apple',
        'Banana',
        'Cherry',
      ], reason: 'Case-insensitive A→Z order regardless of registry order');
    },
  );

  test('FilterKey.icon defaults are derived from the value type', () {
    expect(const _ConfigurableKey('a').icon, Icons.short_text);
    expect(
      const _ConfigurableKey('a', valueType: FilterValueType.date).icon,
      Icons.event_outlined,
    );
    expect(
      const _ConfigurableKey('a', valueType: FilterValueType.enumeration).icon,
      Icons.adjust_outlined,
    );
  });

  test(
    'availableKeyPickerKeys hides applied single-value keys, keeps the rest',
    () {
      final vm = _FakeVm();
      final keys = <FilterKey>[
        // Applied single-value → hidden (edit it via its chip instead).
        const _ConfigurableKey('Name', singleValue: true, applied: true),
        // Unapplied single-value → shown.
        const _ConfigurableKey('Balance', singleValue: true),
        // Applied multi-value → shown (can union more values).
        const _ConfigurableKey('Country', applied: true),
        // Unapplied multi-value → shown.
        const _ConfigurableKey('Group'),
      ];

      final ids = availableKeyPickerKeys(keys, vm).map((k) => k.id).toList();

      expect(ids, [
        'balance',
        'country',
        'group',
      ], reason: 'Only the applied single-value key (Name) is dropped');
    },
  );

  test('semantic keys override the default icon', () {
    expect(const BalanceFilterKey().icon, Icons.attach_money);
    expect(const NameFilterKey().icon, Icons.badge_outlined);
    expect(const IsFilterKey().icon, Icons.toggle_on_outlined);
    expect(
      const CustomFieldFilterKey(columnIndex: 1, configuredLabel: 'x').icon,
      Icons.tune,
    );
  });
}
