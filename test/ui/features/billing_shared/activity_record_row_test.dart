import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/activity.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/phone/call_note.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/ui/features/billing_shared/activity/activity_record_row.dart';
import 'package:admin/utils/formatting.dart';

import '../../../_localization_helper.dart';

Activity _activity({
  required int typeId,
  String notes = '',
  Map<String, ActivityRef> refs = const {},
  DateTime? createdAt,
}) => Activity(
  id: 'a1',
  activityTypeId: typeId,
  notes: notes,
  createdAt: createdAt ?? DateTime.utc(2026, 5, 18, 12),
  ip: '1.2.3.4',
  refs: refs,
);

Future<String> _render(
  WidgetTester tester,
  Activity a, {
  bool showIp = true,
  String? hostWireName,
  Formatter? formatter,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 420,
            child: ActivityRecordRow(
              activity: a,
              formatter: formatter,
              showIp: showIp,
              hostWireName: hostWireName,
            ),
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
    // `activity_141` is "User :user entered note: :notes" — the whole point of
    // the `isComment` bypass is that a note is not read as a sentence. Without
    // this the case above passes either way. (`_render` scrapes every
    // `RichText`, and a plain `Text` builds one too, so both the body and the
    // meta line are still caught.)
    expect(text, isNot(contains('entered note')));
  });

  testWidgets('a comment prints its body at regular weight, not strong', (
    tester,
  ) async {
    await _render(
      tester,
      _activity(
        typeId: 141,
        notes: 'Will pay Friday',
        refs: {'user': const ActivityRef(label: 'Jane Doe')},
      ),
    );
    final body = tester.widget<Text>(find.text('Will pay Friday'));
    expect(body.style?.fontWeight, isNot(FontWeight.w600));
  });

  testWidgets('a blank note falls back to the localized noun', (tester) async {
    // Only this client trims and gates on non-empty; a note written from React
    // or the API can arrive blank, and an empty row reads as broken.
    await _render(tester, _activity(typeId: 141, notes: '   '));
    expect(find.text('Comment'), findsOneWidget);
  });

  testWidgets('showIp: false drops the IP from a card row', (tester) async {
    final withIp = await _render(
      tester,
      _activity(typeId: 141, notes: 'Chasing'),
    );
    expect(withIp, contains('1.2.3.4'));
    final withoutIp = await _render(
      tester,
      _activity(typeId: 141, notes: 'Chasing'),
      showIp: false,
    );
    expect(withoutIp, isNot(contains('1.2.3.4')));
  });

  group('the record a note was filed against', () {
    // `ActivityController::note()` copies `client_id` off the parent, so a
    // comment typed on an invoice lands in that invoice's client's feed too —
    // and `Activity::harvestNoteEntities` ships the refs for exactly this.
    // A realistic note: `note()` stamps `client_id` alongside the document id,
    // so `harvestNoteEntities` ships BOTH refs. The first version of these
    // tests supplied only the invoice, which is exactly why it missed the
    // client name leaking onto every billing-doc comment.
    Activity onInvoice() => _activity(
      typeId: 141,
      notes: 'Will pay Friday',
      refs: {
        'user': const ActivityRef(label: 'Jane Doe'),
        'invoice': const ActivityRef(
          label: '0012',
          type: EntityType.invoice,
          id: 'inv1',
        ),
        'client': const ActivityRef(
          label: 'Acme Corp',
          type: EntityType.client,
          id: 'cli1',
        ),
      },
    );

    testWidgets('is named on another record\'s feed', (tester) async {
      final text = await _render(tester, onInvoice(), hostWireName: 'client');
      expect(text, contains('0012'));
    });

    testWidgets('is not repeated on its own', (tester) async {
      final text = await _render(tester, onInvoice(), hostWireName: 'invoice');
      expect(text, isNot(contains('0012')));
      // …and the client is not offered as a consolation label. It is already
      // in the header, and it is not the record the note was filed against.
      expect(text, isNot(contains('Acme Corp')));
    });

    testWidgets('prefers the document over the client on a client feed', (
      tester,
    ) async {
      final text = await _render(tester, onInvoice(), hostWireName: 'client');
      expect(text, contains('0012'));
      expect(text, isNot(contains('Acme Corp')));
    });

    testWidgets('a purchase order beats the expense ref note() poisons', (
      tester,
    ) async {
      // `note()`'s PurchaseOrder arm writes `expense_id = $entity->id`, and the
      // two tables have independent auto-increment ids — so the `expense`
      // relation often resolves to a real, unrelated expense. Ordering
      // `purchase_order` first is what keeps that off the row.
      final text = await _render(
        tester,
        _activity(
          typeId: 141,
          notes: 'Chasing',
          refs: {
            'user': const ActivityRef(label: 'Jane Doe'),
            'purchase_order': const ActivityRef(
              label: 'PO-7',
              type: EntityType.purchaseOrder,
              id: 'po1',
            ),
            'expense': const ActivityRef(
              label: 'EXP-999',
              type: EntityType.expense,
              id: 'exp1',
            ),
          },
        ),
        hostWireName: 'vendor',
      );
      expect(text, contains('PO-7'));
      expect(text, isNot(contains('EXP-999')));
    });
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

  group('a comment\'s timestamp', () {
    // `formatRelativeTime` bottoms out at `2w` / `3w`, and the exact stamp is a
    // `Tooltip` — long-press only on touch. "3w" is not an answer to "when did
    // they promise Friday?".
    Formatter dateFormatter() => Formatter(
      settings: CompanyFormatSettings.fallback,
      currencies: const {},
      countries: const {},
      dateFormats: const {},
    );

    testWidgets('stays relative under a day', (tester) async {
      final text = await _render(
        tester,
        _activity(
          typeId: 141,
          notes: 'Recent',
          createdAt: DateTime.now().toUtc().subtract(const Duration(hours: 3)),
        ),
        formatter: dateFormatter(),
      );
      expect(text, contains('h ago'));
    });

    testWidgets('becomes a date beyond one', (tester) async {
      final text = await _render(
        tester,
        _activity(
          typeId: 141,
          notes: 'Older',
          createdAt: DateTime.now().toUtc().subtract(const Duration(days: 12)),
        ),
        formatter: dateFormatter(),
      );
      expect(text, isNot(contains('ago')));
    });

    testWidgets('is the LOCAL calendar day, not the UTC one', (tester) async {
      // `Formatter.date` localizes only on its `showTime: true` branch, so
      // handing it the UTC instant printed the wrong day for anyone whose
      // evening crosses the boundary — and disagreed with this row's own
      // absolute tooltip, which does localize. Pick an instant that lands on a
      // different date in UTC than locally *whichever side* of UTC the machine
      // runs on, so this is meaningful on a developer laptop and on a UTC CI
      // box alike (on UTC the two agree and the assertion is trivially true).
      final at = DateTime.now().toUtc().subtract(const Duration(days: 12));
      final boundary = DateTime.utc(
        at.year,
        at.month,
        at.day,
        DateTime.now().timeZoneOffset.isNegative ? 2 : 22,
      );
      final text = await _render(
        tester,
        _activity(typeId: 141, notes: 'Older', createdAt: boundary),
        formatter: dateFormatter(),
      );
      final localDay = boundary.toLocal().day.toString().padLeft(2, '0');
      expect(text, contains(localDay));
    });

    testWidgets('a system row keeps relative time however old', (tester) async {
      final text = await _render(
        tester,
        _activity(
          typeId: 6,
          createdAt: DateTime.now().toUtc().subtract(const Duration(days: 12)),
        ),
        formatter: dateFormatter(),
      );
      expect(text, contains('ago'));
    });
  });
}
