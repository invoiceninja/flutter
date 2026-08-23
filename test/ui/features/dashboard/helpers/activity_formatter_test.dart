// Rendering rules for the shared `activity_<N>` templates.
//
// The load-bearing case is the user-lifecycle family (48-52). Their templates
// name two different people — ":user created user :user" — but the server
// persists only one: `ActivityRepository::save()` returns early for a `User`
// entity, and the `activities` table has no second user column, so
// `Activity::activity_string()` emits a single `user` object. The formatter's
// blanket token substitution therefore stamped the actor into both slots and
// produced "Alice created user Alice" — a sibling of the misattribution behind
// invoiceninja/flutter#45 / #47, and just as alarming to read in an audit log.
//
// Blanking the trailing token is not an available fix: German and Japanese put
// the second `:user` mid-string ("… がユーザー :user を作成しました。"), where a
// trim can't clean up after it. So the formatter swaps in an actor-only
// phrasing, and does it by *counting tokens* rather than hardcoding the swap —
// once the server moves the target into `:notes` the count drops to one and
// the translated template comes back with no change here.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/dashboard/dashboard_activity.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/dashboard/helpers/activity_formatter.dart';

import '../../../../_localization_helper.dart';

DashboardActivity _row(
  int typeId, {
  Map<String, dynamic> extra = const {},
  String notes = '',
}) => DashboardActivity.fromJson({
  'user': {'label': 'Alice Admin', 'hashed_id': 'u1'},
  'activity_type_id': typeId,
  'id': '1',
  'notes': notes,
  'created_at': 1787472002,
  ...extra,
});

void main() {
  /// Renders through a real `MaterialApp` so `context.tr` resolves against the
  /// bundled English strings, exactly as production does.
  Future<ActivityRender> render(
    WidgetTester tester,
    DashboardActivity a,
  ) async {
    late ActivityRender out;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Builder(
          builder: (context) {
            out = ActivityFormatter(context).format(a);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return out;
  }

  group('user-lifecycle activities (48-52)', () {
    testWidgets('name the actor once, never twice', (tester) async {
      for (final typeId in kUserLifecycleActivityTypes) {
        final r = await render(tester, _row(typeId));

        expect(
          'Alice Admin'.allMatches(r.title).length,
          1,
          reason:
              'activity_$typeId rendered "${r.title}" — the actor must not '
              'also fill the target slot',
        );
        // And the swap must not leave a raw token behind.
        expect(r.title, isNot(contains(':user')));
      }
    });

    testWidgets('read as a sentence about the actor', (tester) async {
      expect(
        (await render(tester, _row(48))).title,
        'Alice Admin created a user',
      );
      expect(
        (await render(tester, _row(51))).title,
        'Alice Admin deleted a user',
      );
    });

    test('every type has an actor-only string to fall back to', () {
      // The keys are reached through an interpolated lookup, so the
      // `no_unsubstituted_placeholders_test` scans can't see them — this is
      // the per-structure invariant that file's doc asks for.
      final l10n = bundledLocalization();
      for (final typeId in kUserLifecycleActivityTypes) {
        final key = 'activity_${typeId}_actor_only';
        final value = l10n.lookup(key);
        expect(value, isNot(key), reason: '$key resolves to nothing');
        expect(value, contains(':user'), reason: '$key must name the actor');
        // One token only — that is the whole point of the variant.
        expect(RegExp(':user').allMatches(value).length, 1, reason: key);
      }
    });

    test('the bundled templates really do carry the duplicate token', () {
      // Guards the guard: if Transifex ever ships a fixed template the
      // formatter silently stops swapping, and these tests would keep passing
      // for the wrong reason. This one fails loudly instead so the fallback
      // keys can be retired deliberately.
      final l10n = bundledLocalization();
      for (final typeId in kUserLifecycleActivityTypes) {
        expect(
          RegExp(':user').allMatches(l10n.lookup('activity_$typeId')).length,
          2,
          reason:
              'activity_$typeId no longer names the user twice — the server '
              'fix may have landed; see BACKEND.md',
        );
      }
    });

    testWidgets('a single-token template is used verbatim', (tester) async {
      // The self-healing path: a server that moves the target into `:notes`
      // ships a one-`:user` template, the count check stops matching, and the
      // translated string renders with both names.
      late ActivityRender out;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            _FixedTemplateDelegate({
              'activity_48': ':user created user :notes',
            }),
          ],
          supportedLocales: kTestSupportedLocales,
          home: Builder(
            builder: (context) {
              out = ActivityFormatter(
                context,
              ).format(_row(48, notes: 'Ivy Invited'));
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(out.title, 'Alice Admin created user Ivy Invited');
    });
  });

  group('untouched behaviour', () {
    testWidgets('type 10 picks online vs manual on the contact label', (
      tester,
    ) async {
      final online = await render(
        tester,
        _row(
          10,
          extra: {
            'contact': {'label': 'Bo Buyer', 'hashed_id': 'c1'},
            'invoice': {'label': '0025', 'hashed_id': 'i1'},
            'client': {'label': 'Acme', 'hashed_id': 'cl1'},
            'payment': {'label': '0009', 'hashed_id': 'p1'},
          },
        ),
      );
      expect(online.title, startsWith('Bo Buyer made payment'));

      final manual = await render(
        tester,
        _row(
          10,
          extra: {
            'invoice': {'label': '0025', 'hashed_id': 'i1'},
            'client': {'label': 'Acme', 'hashed_id': 'cl1'},
            'payment': {'label': '0009', 'hashed_id': 'p1'},
          },
        ),
      );
      expect(manual.title, startsWith('Alice Admin entered payment'));
    });

    testWidgets('type 54 with a contact swaps the actor for the contact', (
      tester,
    ) async {
      final r = await render(
        tester,
        _row(
          54,
          extra: {
            'contact': {'label': 'Bo Buyer', 'hashed_id': 'c1'},
            'invoice': {'label': '0025', 'hashed_id': 'i1'},
          },
        ),
      );

      expect(r.title, 'Bo Buyer paid invoice 0025');
    });

    testWidgets('an unknown type falls back to "Activity #N"', (tester) async {
      expect((await render(tester, _row(9999))).title, 'Activity #9999');
    });

    testWidgets('a row that names no object keeps the localized noun', (
      tester,
    ) async {
      // The #45 fallback: with no `invoice` label the token becomes the noun,
      // never a bare `:invoice` and never some other row's value.
      final r = await render(tester, _row(4));
      expect(r.title, 'Alice Admin created invoice Invoice');
    });
  });
}

/// Serves a caller-supplied template map instead of the bundled English, so a
/// hypothetical future server-side fix can be exercised today.
class _FixedTemplateDelegate extends LocalizationsDelegate<Localization> {
  const _FixedTemplateDelegate(this.strings);

  final Map<String, String> strings;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<Localization> load(Locale locale) =>
      SynchronousFuture(Localization.forTesting(strings: strings));

  @override
  bool shouldReload(LocalizationsDelegate<Localization> old) => false;
}
