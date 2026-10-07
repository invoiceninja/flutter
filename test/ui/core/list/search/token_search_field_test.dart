import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_suggestion_menu.dart';
import 'package:admin/ui/core/list/search/filter_token.dart';
import 'package:admin/ui/core/list/search/filter_token_chip.dart';
import 'package:admin/ui/features/clients/client_filter_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../_localization_helper.dart';

/// Coverage for the pieces of the token search subsystem that fit a fast
/// unit-test loop: input parsing (`FilterInputParse.of`) and the chip
/// widget. Behavioral coverage of the FilterKey writes lives in
/// `test/ui/features/clients/client_filter_keys_test.dart`; the
/// repo / query-string path is in `client_repository_test.dart`.
///
/// The field itself — where its popup lands, what typing and the keys do —
/// is covered in `token_search_field_overlay_test.dart`, on the harness in
/// `_token_search_harness.dart`. It was left untested for a long time because
/// an open popup never settles under `pumpAndSettle`; the harness pumps
/// frame by frame instead.

void main() {
  group('FilterInputParse.of', () {
    // Second key is arbitrary filler for the parser tests (only `is` is
    // asserted). `VatFilterKey` is const + repo-free; `GroupFilterKey` is
    // now repo-backed (non-const) so it's no longer suitable here.
    final keys = <FilterKey>[const IsFilterKey(), const VatFilterKey()];

    test('no colon → key mode with the input as query', () {
      final parse = FilterInputParse.of('acme', keys);
      expect(parse.matchedKey, isNull);
      expect(parse.query, 'acme');
    });

    test('known prefix → value mode with the tail as query', () {
      final parse = FilterInputParse.of('is:arch', keys);
      expect(parse.matchedKey?.id, 'is');
      expect(parse.query, 'arch');
    });

    test('alias resolves to the same key (`state` → `is`)', () {
      final parse = FilterInputParse.of('state:active', keys);
      expect(parse.matchedKey?.id, 'is');
      expect(parse.query, 'active');
    });

    test('`status` is NOT an alias of the lifecycle key — it is reserved '
        'for the per-entity Status key, so here it falls to free text', () {
      // The lifecycle key dropped its old `status` alias to stop
      // duplicating / shadowing the per-entity Status filter. With no
      // Status key registered, `status:` is just free text.
      final parse = FilterInputParse.of('status:active', keys);
      expect(parse.matchedKey, isNull);
      expect(parse.query, 'status:active');
    });

    test('unmatched prefix falls back to free text', () {
      final parse = FilterInputParse.of('unknown:foo', keys);
      expect(parse.matchedKey, isNull);
      expect(
        parse.query,
        'unknown:foo',
        reason:
            'unrecognised prefix is left as-is so the user can search '
            'literally for it via the "Search for" row',
      );
    });
  });

  group('FilterTokenChip', () {
    Widget wrap(Widget child) => MaterialApp(
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      theme: buildInTheme(InTheme.light),
      home: Scaffold(body: child),
    );

    const sampleToken = FilterToken(
      keyId: 'is',
      displayKey: 'Status',
      rawValue: 'archived',
      displayValue: 'Archived',
    );

    testWidgets('renders the display value', (tester) async {
      await tester.pumpWidget(
        wrap(FilterTokenChip(token: sampleToken, onRemove: () {})),
      );
      expect(find.text('Archived'), findsOneWidget);
      // The label keeps its own case. It used to be lowercased, which is
      // wrong for any label that is not an English common noun.
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('status'), findsNothing);
    });

    testWidgets(
      'close icon fires onRemove; chip body is inert when onTap is null',
      (tester) async {
        var removed = 0;
        await tester.pumpWidget(
          wrap(FilterTokenChip(token: sampleToken, onRemove: () => removed++)),
        );

        // No onTap supplied → body tap does nothing (the historical
        // "inert chip" contract still holds for that case).
        await tester.tap(find.text('Archived'));
        await tester.pump();
        expect(removed, 0);

        // The × IconButton stays interactive regardless.
        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();
        expect(removed, 1);
      },
    );

    testWidgets('body tap fires onTap when supplied; × still fires onRemove', (
      tester,
    ) async {
      var tapped = 0;
      var removed = 0;
      Rect? anchor;
      await tester.pumpWidget(
        wrap(
          FilterTokenChip(
            token: sampleToken,
            onRemove: () => removed++,
            onTap: (r) {
              tapped++;
              anchor = r;
            },
          ),
        ),
      );

      // Body tap routes to onTap (the new "edit this chip" gesture).
      await tester.tap(find.text('Archived'));
      await tester.pump();
      expect(tapped, 1);
      expect(removed, 0, reason: 'body tap must not double-fire onRemove');
      // The reported bug: the dropdown anchored to the field's left edge
      // instead of the chip. onTap must hand back the tapped body's real
      // global rect, so the caller can anchor under the chip — the body
      // must enclose the value text it was tapped on.
      expect(anchor, isNotNull);
      expect(anchor!.width, greaterThan(0));
      final valueLeft = tester.getTopLeft(find.text('Archived')).dx;
      expect(
        anchor!.left,
        lessThanOrEqualTo(valueLeft),
        reason: 'chip body starts at/before its value text',
      );
      expect(
        anchor!.right,
        greaterThan(valueLeft),
        reason: 'rect must span the tapped chip body, not collapse to 0',
      );

      // The × button still routes to onRemove only.
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(removed, 1);
      expect(tapped, 1, reason: 'tapping × must not also fire onTap');
    });
  });
}
