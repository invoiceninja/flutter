import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/activity.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/phone/call_note.dart';
import 'package:admin/ui/features/billing_shared/activity/activity_record_row.dart';

import '../../../_localization_helper.dart';

Activity _activity({
  required int typeId,
  String notes = '',
  Map<String, ActivityRef> refs = const {},
}) => Activity(
  id: 'a1',
  activityTypeId: typeId,
  notes: notes,
  createdAt: DateTime.utc(2026, 5, 18, 12),
  ip: '1.2.3.4',
  refs: refs,
);

Future<String> _render(WidgetTester tester, Activity a) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 420,
            child: ActivityRecordRow(activity: a, formatter: null),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // The sentence renders via Text.rich → a RichText; concatenate every
  // RichText's plain text so we can assert on the resolved string.
  final buf = StringBuffer();
  for (final e in find.byType(RichText).evaluate()) {
    final rt = e.widget as RichText;
    buf.write(rt.text.toPlainText());
    buf.write('\n');
  }
  return buf.toString();
}

void main() {
  testWidgets('substitutes tokens from refs (activity_6)', (tester) async {
    final text = await _render(
      tester,
      _activity(
        typeId: 6,
        refs: {
          'user': const ActivityRef(label: 'Jane Doe'),
          'invoice': const ActivityRef(
            label: '0013',
            type: EntityType.invoice,
            id: 'inv1',
          ),
          'client': const ActivityRef(
            label: 'Acme Co',
            type: EntityType.client,
            id: 'cli1',
          ),
          'contact': const ActivityRef(
            label: 'Bob Roe',
            type: EntityType.client,
            id: 'con1',
          ),
        },
      ),
    );
    // en.json activity_6: ":user emailed invoice :invoice for :client to :contact"
    expect(text, contains('Jane Doe'));
    expect(text, contains('0013'));
    expect(text, contains('Acme Co'));
    expect(text, contains('Bob Roe'));
    expect(text, isNot(contains(':user')));
    expect(text, isNot(contains(':invoice')));
  });

  testWidgets('unknown activity type falls back to "Activity #N"', (
    tester,
  ) async {
    final text = await _render(tester, _activity(typeId: 99999));
    expect(text, contains('99999'));
    expect(text, isNot(contains('activity_unknown')));
  });

  testWidgets('comment (141) renders the note', (tester) async {
    final text = await _render(
      tester,
      _activity(
        typeId: 141,
        notes: 'Called the client',
        refs: {'user': const ActivityRef(label: 'Jane Doe')},
      ),
    );
    expect(text, contains('Jane Doe'));
    expect(text, contains('Called the client'));
  });

  testWidgets('type 10 picks online template when a contact is present', (
    tester,
  ) async {
    final text = await _render(
      tester,
      _activity(
        typeId: 10,
        refs: {
          'contact': const ActivityRef(
            label: 'Bob Roe',
            type: EntityType.client,
            id: 'c1',
          ),
          'payment': const ActivityRef(
            label: 'PMT-1',
            type: EntityType.payment,
            id: 'p1',
          ),
          'invoice': const ActivityRef(
            label: '0013',
            type: EntityType.invoice,
            id: 'i1',
          ),
          'client': const ActivityRef(
            label: 'Acme Co',
            type: EntityType.client,
            id: 'cl1',
          ),
        },
      ),
    );
    // activity_10_online: ":contact made payment :payment for invoice :invoice for :client"
    expect(text, contains('Bob Roe'));
    expect(text, contains('PMT-1'));
    expect(text, contains('made payment'));
  });

  group('a logged call (invoiceninja/flutter#120)', () {
    // Composed the way the sheet composes it: marker, `·`-joined header,
    // newline, summary. Nothing parses this back — the row only splits it.
    final call = _activity(
      typeId: 141,
      notes:
          '$kCallNoteMarker Outgoing · Jane Smith · 12 Minutes · '
          '3/Sep/2026 2:32 PM\nThey will pay Friday',
      refs: const {'user': ActivityRef(label: 'Hillel')},
    );

    testWidgets('gets the phone glyph, not the comment one', (tester) async {
      await _render(tester, call);
      final icons = tester
          .widgetList<Icon>(find.byType(Icon))
          .map((i) => i.icon)
          .toList();
      expect(icons, contains(Icons.phone_in_talk_outlined));
      expect(icons, isNot(contains(Icons.comment_outlined)));
    });

    testWidgets('a plain comment keeps the comment glyph', (tester) async {
      await _render(
        tester,
        _activity(typeId: 141, notes: 'Chasing this one up again'),
      );
      final icons = tester
          .widgetList<Icon>(find.byType(Icon))
          .map((i) => i.icon)
          .toList();
      expect(icons, contains(Icons.comment_outlined));
      expect(icons, isNot(contains(Icons.phone_in_talk_outlined)));
    });

    testWidgets('renders header and summary as two tiers, marker stripped', (
      tester,
    ) async {
      await _render(tester, call);
      // Asserted on the string, never on pixels: `flutter test` substitutes its
      // own font, so the marker glyph is invisible to a golden.
      expect(
        find.text('Outgoing · Jane Smith · 12 Minutes · 3/Sep/2026 2:32 PM'),
        findsOneWidget,
      );
      expect(find.text('They will pay Friday'), findsOneWidget);
      expect(find.textContaining(kCallNoteMarker), findsNothing);
    });

    testWidgets('keeps naming the actor the templated sentence would have', (
      tester,
    ) async {
      // The call branch bypasses `buildActivitySpans`, which is what supplies
      // "User :user entered note:" — drop the actor here and a logged call
      // becomes the one activity row that names nobody.
      await _render(tester, call);
      expect(find.textContaining('Hillel'), findsOneWidget);
    });

    testWidgets('a marked note with no newline renders as the summary', (
      tester,
    ) async {
      await _render(
        tester,
        _activity(typeId: 141, notes: '$kCallNoteMarker Rang, no answer'),
      );
      expect(find.text('Rang, no answer'), findsOneWidget);
    });
  });
}
