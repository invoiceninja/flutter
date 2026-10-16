import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/l10n/company_labels_scope.dart';
import 'package:admin/l10n/localization.dart';

import '../_localization_helper.dart';

/// The company's Custom Labels over the app's own strings
/// (invoiceninja/flutter#84): `Localization` looks them up first, and
/// `CompanyLabelsScope` carries them to every `context.tr` below it.
void main() {
  group('Localization with overrides', () {
    final base = Localization.forTesting(
      strings: const {'quote': 'Angebot', 'invoice': 'Rechnung'},
      fallback: const {'quote': 'Quote', 'invoice': 'Invoice', 'save': 'Save'},
      pending: const {'all_statuses': 'All statuses'},
    );

    test('an override comes before every bundle', () {
      final l = base.withOverrides(const {
        'quote': 'Estimate',
        'save': 'Keep',
        'all_statuses': 'Any status',
      });
      expect(l.lookup('quote'), 'Estimate', reason: 'over the locale');
      expect(l.lookup('save'), 'Keep', reason: 'over the English fallback');
      expect(l.lookup('all_statuses'), 'Any status', reason: 'over pending');
      expect(l.lookup('invoice'), 'Rechnung', reason: 'untouched');
    });

    test('a blank override falls through', () {
      final l = base.withOverrides(const {'quote': '  '});
      expect(l.lookup('quote'), 'Angebot');
    });

    test('placeholders are filled in an override too', () {
      final l = base.withOverrides(const {'greet': 'Hi :name'});
      expect(l.lookup('greet', {'name': 'Ada'}), 'Hi Ada');
    });

    test('lookupBundled and englishOf never see an override', () {
      final l = base.withOverrides(const {'quote': 'Estimate'});
      expect(l.lookupBundled('quote'), 'Angebot');
      expect(
        l.englishOf('quote'),
        'Quote',
        reason: 'settings search matches the English word',
      );
    });

    test('no overrides is the same instance', () {
      expect(identical(base.withOverrides(const {}), base), isTrue);
    });
  });

  group('CompanyLabelsScope', () {
    late ValueNotifier<Map<String, String>> labels;

    setUp(() => labels = ValueNotifier(const {'quote': 'Estimate'}));
    tearDown(() => labels.dispose());

    Future<void> pump(WidgetTester tester, Widget home) => tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        // Where the app installs it: around everything the builder returns,
        // so routes pushed later are below it too.
        builder: (context, child) =>
            CompanyLabelsScope(labels: labels, child: child!),
        home: home,
      ),
    );

    testWidgets('context.tr reads the labels; trBundled does not', (
      tester,
    ) async {
      await pump(
        tester,
        Builder(
          builder: (context) => Column(
            children: [
              Text(context.tr('quote')),
              Text('bundled ${context.trBundled('quote')}'),
            ],
          ),
        ),
      );
      expect(find.text('Estimate'), findsOneWidget);
      expect(find.text('bundled Quote'), findsOneWidget);
    });

    testWidgets('a changed label rebuilds what read it, a route included', (
      tester,
    ) async {
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => Text('dialog ${context.tr('quote')}'),
            ),
            child: Text(context.tr('quote')),
          ),
        ),
      );
      await tester.tap(find.text('Estimate'));
      await tester.pumpAndSettle();
      expect(find.text('dialog Estimate'), findsOneWidget);

      labels.value = const {'quote': 'Proposal'};
      await tester.pump();
      expect(find.text('dialog Proposal'), findsOneWidget);
      expect(find.text('Proposal'), findsOneWidget);

      labels.value = const {};
      await tester.pump();
      expect(find.text('dialog Quote'), findsOneWidget);
    });

    testWidgets('every string in a frame shares one overlaid instance', (
      tester,
    ) async {
      final seen = <Localization?>[];
      await pump(
        tester,
        Column(
          children: [
            for (var i = 0; i < 3; i++)
              Builder(
                builder: (context) {
                  seen.add(Localization.of(context));
                  return const SizedBox();
                },
              ),
          ],
        ),
      );
      expect(seen, hasLength(3));
      expect(
        identical(seen[0], seen[1]) && identical(seen[1], seen[2]),
        isTrue,
      );
    });
  });
}
