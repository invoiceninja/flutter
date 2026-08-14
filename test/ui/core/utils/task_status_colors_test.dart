import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/utils/task_status_colors.dart';

import '../../../_localization_helper.dart';

/// Stand-in for `context.tr` — returns the key itself unless overridden,
/// mirroring `Localization.lookup`'s missing-key behaviour.
String Function(String) _tr([Map<String, String> strings = const {}]) =>
    (key) => strings[key] ?? key;

/// Resolves [taskStatusColors] inside a real theme so the returned tokens are
/// the ones the app would paint.
Future<({Color fg, Color? bg})> _resolve(
  WidgetTester tester, {
  required String name,
  required String color,
  InTheme tokens = InTheme.light,
}) async {
  late ({Color fg, Color? bg}) result;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(tokens),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Builder(
        builder: (context) {
          result = taskStatusColors(context, name: name, color: color);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return result;
}

void main() {
  group('builtInTaskStatusKey', () {
    test('matches the English names the server stores', () {
      expect(builtInTaskStatusKey('Backlog', tr: _tr()), 'backlog');
      expect(builtInTaskStatusKey('Ready to do', tr: _tr()), 'ready_to_do');
      expect(builtInTaskStatusKey('In progress', tr: _tr()), 'in_progress');
      expect(builtInTaskStatusKey('Done', tr: _tr()), 'done');
    });

    test('ignores case and whitespace', () {
      expect(builtInTaskStatusKey('  IN PROGRESS ', tr: _tr()), 'in_progress');
      expect(builtInTaskStatusKey('In Progress', tr: _tr()), 'in_progress');
      expect(builtInTaskStatusKey('ready  TO  do', tr: _tr()), 'ready_to_do');
    });

    test('matches a name stored in the active locale', () {
      final tr = _tr({'in_progress': 'En curso', 'done': 'Hecho'});
      expect(builtInTaskStatusKey('En curso', tr: tr), 'in_progress');
      expect(builtInTaskStatusKey('hecho', tr: tr), 'done');
      // English still matches — the company's creation locale need not be
      // the viewer's.
      expect(builtInTaskStatusKey('Done', tr: tr), 'done');
    });

    test('returns null for a custom or empty name', () {
      expect(builtInTaskStatusKey('Blocked', tr: _tr()), isNull);
      expect(builtInTaskStatusKey('', tr: _tr()), isNull);
      expect(builtInTaskStatusKey('   ', tr: _tr()), isNull);
    });

    test('its hardcoded English names still match en.json', () {
      // The server names the four defaults from the same Transifex source this
      // bundle ships, so the matcher's English fallbacks have to track
      // `en.json`. `tr` echoes the key here so only the hardcoded English list
      // can produce a match — a drift can't hide behind the translated path.
      //
      // If this fails, Transifex reworded the key: ADD the new wording to the
      // matcher alongside the old one. Companies created before the change
      // keep the old name forever, so replacing it would strip their colours.
      final en =
          jsonDecode(File('assets/i18n/en.json').readAsStringSync())
              as Map<String, dynamic>;
      for (final key in const [
        'backlog',
        'ready_to_do',
        'in_progress',
        'done',
      ]) {
        expect(
          builtInTaskStatusKey(en[key] as String, tr: (k) => k),
          key,
          reason: 'en.json["$key"] = "${en[key]}" no longer matches',
        );
      }
    });
  });

  group('taskStatusColors', () {
    const tokens = InTheme.light;

    testWidgets('colors the built-ins the server leaves at #fff', (
      tester,
    ) async {
      expect(await _resolve(tester, name: 'Backlog', color: '#fff'), (
        fg: tokens.draft,
        bg: tokens.draftSoft,
      ));
      expect(await _resolve(tester, name: 'Ready to do', color: '#fff'), (
        fg: tokens.partial,
        bg: tokens.partialSoft,
      ));
      expect(await _resolve(tester, name: 'In progress', color: '#fff'), (
        fg: tokens.sent,
        bg: tokens.sentSoft,
      ));
      expect(await _resolve(tester, name: 'Done', color: '#fff'), (
        fg: tokens.paid,
        bg: tokens.paidSoft,
      ));
    });

    testWidgets('treats every unset spelling as colorless', (tester) async {
      for (final unset in const [
        '',
        '   ',
        '#fff',
        '#FFF',
        '#ffffff',
        'FFFFFF',
        '#FFFFFFFF', // opaque white in the 8-char form the parser accepts
      ]) {
        expect(
          await _resolve(tester, name: 'Done', color: unset),
          (fg: tokens.paid, bg: tokens.paidSoft),
          reason: 'color "$unset" should count as unset',
        );
      }
    });

    testWidgets('a user-picked color always wins', (tester) async {
      expect(await _resolve(tester, name: 'Done', color: '#EF4444'), (
        fg: const Color(0xFFEF4444),
        bg: null,
      ));
      // …including the grey this app seeds onto newly created statuses.
      expect(await _resolve(tester, name: 'In progress', color: '#9CA3AF'), (
        fg: const Color(0xFF9CA3AF),
        bg: null,
      ));
    });

    testWidgets('keeps the neutral for an unrecognized colorless status', (
      tester,
    ) async {
      expect(await _resolve(tester, name: 'Blocked', color: '#fff'), (
        fg: tokens.ink3,
        bg: null,
      ));
      // Unknown status (watch stream hasn't resolved) → name and color empty.
      expect(await _resolve(tester, name: '', color: ''), (
        fg: tokens.ink3,
        bg: null,
      ));
    });

    testWidgets('resolves the dark tokens under a dark theme', (tester) async {
      const dark = InTheme.dark;
      expect(
        await _resolve(
          tester,
          name: 'Backlog',
          color: '#fff',
          tokens: InTheme.dark,
        ),
        (fg: dark.draft, bg: dark.draftSoft),
      );
      expect(
        await _resolve(
          tester,
          name: 'Ready to do',
          color: '#fff',
          tokens: InTheme.dark,
        ),
        (fg: dark.partial, bg: dark.partialSoft),
      );
      expect(dark.draft, isNot(tokens.draft));
    });
  });
}
