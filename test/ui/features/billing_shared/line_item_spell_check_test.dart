import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/spell_check_controller.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/billing/line_item_custom_fields.dart';
import 'package:admin/ui/core/widgets/spell_check.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_column_config.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_edit_dialog.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_table_desktop.dart';

import '../shell/_shell_test_helpers.dart';

/// User feedback: "Spell check: underline incorrect grammar in the item name
/// & description." Both line-item editors — the wide table and the phone
/// dialog — hand those two fields the spell-check configuration, nothing
/// else, and on the desktop a right-click offers the fix (docs/spell-check.md).
LineItem _line({String productKey = 'Widgit', String notes = 'teh widget'}) =>
    emptyLineItem().copyWith(
      productKey: productKey,
      notes: notes,
      cost: Decimal.fromInt(10),
      customValue1: 'SN-1',
    );

class _Host extends StatefulWidget {
  const _Host({required this.initial, required this.onChanged});

  final List<LineItem> initial;
  final ValueChanged<List<LineItem>> onChanged;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late List<LineItem> _items = widget.initial;

  @override
  Widget build(BuildContext context) => LineItemTableDesktop(
    companyId: 'co1',
    items: _items,
    onChanged: (next) {
      widget.onChanged(next);
      setState(() => _items = next);
    },
    newItemFactory: emptyLineItem,
    config: LineItemColumnConfig(
      taxColumnCount: 0,
      customFields: lineItemCustomFields(const {
        'product1': 'Serial|single_line_text',
      }, task: false),
    ),
  );
}

void main() {
  const channel = MethodChannel('invoice_ninja/spell_check');
  late ShellFixture fixture;
  late List<List<LineItem>> emitted;

  setUp(() {
    // The runner: "teh" is misspelled wherever it appears.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final text = (call.arguments as Map)['text'] as String;
          final at = text.indexOf('teh');
          return [
            if (at >= 0)
              {
                'start': at,
                'end': at + 3,
                'suggestions': ['the', 'tech'],
              },
          ];
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  /// The root provider `main.dart` mounts, which `wrapWithShell` doesn't.
  Widget withSpellCheck(Widget child) =>
      ChangeNotifierProvider<SpellCheckController>.value(
        value: fixture.services.spellCheck,
        child: child,
      );

  Future<void> pumpTable(
    WidgetTester tester,
    List<LineItem> items, {
    bool spellCheckOn = true,
  }) async {
    emitted = <List<LineItem>>[];
    tester.view.physicalSize = const Size(1800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    fixture = await buildFixture(
      companies: [const FakeCompany(id: 'co1', name: 'Co')],
    );
    addTearDown(fixture.dispose);
    if (!spellCheckOn) {
      await tester.runAsync(() => fixture.services.spellCheck.set(false));
    }
    await tester.pumpWidget(
      withSpellCheck(
        wrapWithShell(
          fixture.services,
          _Host(initial: items, onChanged: emitted.add),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Finder field(String text) => find.byWidgetPredicate(
    (w) => w is TextField && w.controller?.text == text,
  );

  TextField textField(WidgetTester tester, String text) =>
      tester.widget<TextField>(field(text));

  group('wide table', () {
    testWidgets('the item name and description are checked, nothing else', (
      tester,
    ) async {
      await pumpTable(tester, [_line()]);

      expect(textField(tester, 'Widgit').spellCheckConfiguration, isNotNull);
      expect(
        textField(tester, 'teh widget').spellCheckConfiguration,
        isNotNull,
      );
      // A custom field may hold a serial number.
      expect(textField(tester, 'SN-1').spellCheckConfiguration, isNull);
      await teardown(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('turning the switch off takes the checking away', (
      tester,
    ) async {
      await pumpTable(tester, [_line()], spellCheckOn: false);

      expect(textField(tester, 'Widgit').spellCheckConfiguration, isNull);
      expect(textField(tester, 'teh widget').spellCheckConfiguration, isNull);
      await teardown(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('a right-click on a flagged word offers the fix', (
      tester,
    ) async {
      await pumpTable(tester, [_line()]);
      // The check runs at mount; let the mocked runner answer.
      await tester.pump();

      final state = tester.state<EditableTextState>(
        find.descendant(
          of: field('teh widget'),
          matching: find.byType(EditableText),
        ),
      );
      expect(state.spellCheckResults?.suggestionSpans, isNotEmpty);

      await tester.tap(field('teh widget'));
      await tester.pump();
      state.updateEditingValue(
        state.textEditingValue.copyWith(
          selection: const TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.pump();
      state.showToolbar();
      await tester.pump();

      expect(find.text('the'), findsOneWidget);
      expect(find.text('tech'), findsOneWidget);
      await tester.tap(find.text('the'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(emitted.last.single.notes, 'the widget');
      await teardown(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('no suggestions on a word that is not flagged', (tester) async {
      await pumpTable(tester, [_line()]);
      await tester.pump();

      final state = tester.state<EditableTextState>(
        find.descendant(
          of: field('teh widget'),
          matching: find.byType(EditableText),
        ),
      );
      state.updateEditingValue(
        state.textEditingValue.copyWith(
          selection: const TextSelection.collapsed(offset: 7),
        ),
      );
      await tester.pump();
      expect(spellCheckSuggestionItems(state), isEmpty);
      await teardown(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });

  group('phone dialog', () {
    testWidgets('the item name and description are checked', (tester) async {
      fixture = await buildFixture(
        companies: [const FakeCompany(id: 'co1', name: 'Co')],
      );
      addTearDown(fixture.dispose);
      await tester.pumpWidget(
        withSpellCheck(
          wrapWithShell(
            fixture.services,
            Builder(
              builder: (context) => TextButton(
                onPressed: () => showLineItemEditDialog(
                  context,
                  initial: _line(),
                  config: const LineItemColumnConfig(taxColumnCount: 0),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(textField(tester, 'Widgit').spellCheckConfiguration, isNotNull);
      expect(
        textField(tester, 'teh widget').spellCheckConfiguration,
        isNotNull,
      );
      await teardown(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  });
}
