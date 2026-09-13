import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/activity.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/phone/call_note.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/ui/core/list/entity_actions_popup_button.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/features/billing_shared/activity/activity_record_row.dart';
import 'package:admin/ui/features/billing_shared/activity/comment_row_menu.dart';
import 'package:admin/utils/formatting.dart';

import '../../../_localization_helper.dart';
import '../../../_responsive_helper.dart';
import '../shell/_shell_test_helpers.dart';

/// Every `TextSpan` in the rendered sentence, flattened.
List<TextSpan> _textSpans(WidgetTester tester) {
  final out = <TextSpan>[];
  for (final e in find.byType(RichText).evaluate()) {
    (e.widget as RichText).text.visitChildren((span) {
      if (span is TextSpan) out.add(span);
      return true;
    });
  }
  return out;
}

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

    testWidgets('the poisoned expense ref is dropped on the PO\'s own screen', (
      tester,
    ) async {
      // The sibling test above proves the ORDERING covers another record's
      // feed. It cannot cover the purchase order's own screen: there
      // `purchase_order` is skipped as the host, and the loop used to fall
      // straight through to the `expense` ref `note()` minted from that same
      // id — so every comment on every PO was labelled with an unrelated
      // expense's number, and `View Record` navigated to it.
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
        hostWireName: 'purchase_order',
      );
      expect(text, isNot(contains('EXP-999')));
      expect(text, isNot(contains('PO-7')));
    });

    testWidgets('a real expense ref still shows on an expense-less host', (
      tester,
    ) async {
      // The guard is scoped to the two hosts whose id `note()` aliases — it
      // must not blind every other screen to a genuine expense reference.
      final text = await _render(
        tester,
        _activity(
          typeId: 141,
          notes: 'Chasing',
          refs: {
            'user': const ActivityRef(label: 'Jane Doe'),
            'expense': const ActivityRef(
              label: 'EXP-42',
              type: EntityType.expense,
              id: 'exp1',
            ),
          },
        ),
        hostWireName: 'client',
      );
      expect(text, contains('EXP-42'));
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

  // ---------------------------------------------------------------------
  // The row's `⋯` menu — invoiceninja/flutter#123.
  //
  // The report was "seemingly no way to delete or edit a comment … doesn't
  // seem interactive". Edit and Delete are impossible: the API registers no
  // PUT/DELETE for an activity and `activities` has no soft-delete column
  // (BACKEND.md § F3d). So the row offers what it honestly can, and never
  // pretends otherwise.
  // ---------------------------------------------------------------------
  group('comment row menu', () {
    /// Captures `Clipboard.setData` payloads.
    ///
    /// Never `await Clipboard.getData()` in a widget test to read them back —
    /// it hangs forever under the fake-async zone with no timeout.
    List<String> spyClipboard(WidgetTester tester) {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      return copied;
    }

    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Actions'));
      await tester.pumpAndSettle();
    }

    testWidgets('a comment gets one, a system row does not', (tester) async {
      await _render(tester, _activity(typeId: 141, notes: 'Will pay Friday'));
      expect(find.byType(EntityActionsPopupButton<CommentRowAction>), findsOne);

      await _render(tester, _activity(typeId: 6));
      // Deliberately absent rather than empty: a templated sentence has
      // nothing to copy and nothing to delete, and reserving width for a dead
      // affordance is what flutter#111 decided against for the call button.
      expect(
        find.byType(EntityActionsPopupButton<CommentRowAction>),
        findsNothing,
      );
    });

    testWidgets('a comment with no text mounts no button', (tester) async {
      // `_CommentBody` prints a placeholder for one of these, but there is
      // nothing to copy and nothing to view — so the menu would be empty.
      await _render(tester, _activity(typeId: 141, notes: '   '));
      expect(
        find.byType(EntityActionsPopupButton<CommentRowAction>),
        findsNothing,
      );
    });

    testWidgets('Copy writes the note text', (tester) async {
      final copied = spyClipboard(tester);
      await _render(
        tester,
        _activity(typeId: 141, notes: '  Will pay Friday '),
      );
      await openMenu(tester);
      await tester.tap(find.widgetWithText(MenuItemButton, 'Copy'));
      await tester.pumpAndSettle();
      expect(copied, ['Will pay Friday']);
    });

    testWidgets('Copy strips a logged call marker', (tester) async {
      // The row displays the stripped form; copying the wire form would hand
      // the user a leading glyph they never typed.
      final copied = spyClipboard(tester);
      const note = '$kCallNoteMarker Outgoing \u00b7 Jane\nLeft a voicemail';
      await _render(tester, _activity(typeId: 141, notes: note));
      await openMenu(tester);
      await tester.tap(find.widgetWithText(MenuItemButton, 'Copy'));
      await tester.pumpAndSettle();
      expect(copied, hasLength(1));
      expect(copied.single, isNot(startsWith(kCallNoteMarker)));
      expect(copied.single, contains('Left a voicemail'));
    });

    testWidgets('View record appears only for a note filed elsewhere', (
      tester,
    ) async {
      // On a client's feed a note typed on an invoice carries that invoice's
      // ref. The meta line prints it as text — the note bypass strips the
      // linked sentence — so this menu item is the only way to reach it.
      await _render(
        tester,
        _activity(
          typeId: 141,
          notes: 'Chased this',
          refs: {
            'invoice': const ActivityRef(
              label: '0013',
              type: EntityType.invoice,
              id: 'inv1',
            ),
          },
        ),
        hostWireName: 'client',
      );
      await openMenu(tester);
      expect(find.widgetWithText(MenuItemButton, 'View Record'), findsOne);
    });

    testWidgets('View record is absent with no source ref', (tester) async {
      await _render(
        tester,
        _activity(typeId: 141, notes: 'Chased this'),
        hostWireName: 'client',
      );
      await openMenu(tester);
      expect(find.widgetWithText(MenuItemButton, 'View Record'), findsNothing);
    });

    testWidgets('View record is absent for a PO note on its own screen', (
      tester,
    ) async {
      // The navigation half of the same bug: the aliased `expense` ref would
      // have sent `goEntityRecord` to an unrelated expense.
      await _render(
        tester,
        _activity(
          typeId: 141,
          notes: 'Chased this',
          refs: {
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
        hostWireName: 'purchase_order',
      );
      await openMenu(tester);
      expect(find.widgetWithText(MenuItemButton, 'View Record'), findsNothing);
    });

    testWidgets('Delete is never offered on a synced note', (tester) async {
      // The server cannot remove it. Only a still-queued note can really be
      // deleted, and that is `PendingCommentRow`'s job.
      await _render(tester, _activity(typeId: 141, notes: 'Will pay Friday'));
      await openMenu(tester);
      expect(find.widgetWithText(MenuItemButton, 'Delete'), findsNothing);
      expect(find.widgetWithText(MenuItemButton, 'Copy'), findsOne);
    });

    testWidgets('the row survives the responsive sweep with a menu on it', (
      tester,
    ) async {
      // The button costs `actionButtonSize()` + a gap out of the row's width,
      // and the note body is what gives it back. Worth sweeping: the narrow
      // end is a phone at maximum text scale, where the meta line already
      // wraps.
      for (final width in kResponsiveWidths) {
        await pumpAt(
          tester,
          width,
          ActivityRecordRow(
            activity: _activity(
              typeId: 141,
              notes:
                  'Rang about the overdue balance and they promised '
                  'to pay on Friday once the PO clears finance.',
              refs: {
                'invoice': const ActivityRef(
                  label: '0013',
                  type: EntityType.invoice,
                  id: 'inv1',
                ),
              },
            ),
            formatter: null,
            hostWireName: 'client',
          ),
          textScale: kTextScaleMax,
        );
        expectNoOverflow(tester);
      }
    });

    testWidgets('the menu button is its own semantics node', (tester) async {
      // Regression guard: the comment row merges its text column for a screen
      // reader, and a merge stretched over the whole row would absorb the
      // button's tap action into the sentence — announced, unusable.
      final handle = tester.ensureSemantics();
      await _render(tester, _activity(typeId: 141, notes: 'Will pay Friday'));
      final node = tester.getSemantics(find.byTooltip('Actions'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(node.label, isNot(contains('Will pay Friday')));
      handle.dispose();
    });
  });

  group('the row opens the record it is about (invoiceninja/flutter#143)', () {
    // `activity_19` = ":user updated quote :quote" — the reported row, read on
    // a client's Activity tab.
    Activity quoteRow() => _activity(
      typeId: 19,
      refs: const {
        'user': ActivityRef(label: 'Hammy Havoc'),
        'quote': ActivityRef(label: '0092', type: EntityType.quote, id: 'q1'),
      },
    );

    testWidgets('on touch the sentence carries no recognizer, and the row '
        'carries the tap', (tester) async {
      // `flutter test` reports TargetPlatform.android, so this IS the touch
      // branch — the platform the issue was filed against.
      await _render(tester, quoteRow(), hostWireName: 'client');

      expect(
        _textSpans(tester).where((s) => s.recognizer != null),
        isEmpty,
        reason:
            'a span recognizer is only hit inside its ~17 dp glyph box, with '
            'no slop — unreachable by finger',
      );
      expect(
        _textSpans(tester).map((s) => s.text).join(),
        contains('0092'),
        reason: 'the number must still render, just not as a link',
      );
      expect(
        _textSpans(tester).where((s) => s.style?.color == InTheme.light.accent),
        isEmpty,
        reason:
            'accent without a recognizer is the worse half of the bug — a '
            'link the paint promises and the hit test refuses',
      );
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.byType(InkWell), findsOneWidget);

      // The ripple has to ride on a Material *inside* the row: the nearest
      // ancestor one sits above `ActivityListCard`'s opaque surface fill, so
      // ink registered there paints under the card and is invisible. Neither
      // the suite nor `no_ink_widget_test.dart` can see that from the outside
      // — its own doc says the scan cannot catch a bare `InkWell` under an
      // opaque box — so assert the local Material is present.
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(ActivityRecordRow),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.type, MaterialType.transparency);
    });

    testWidgets('on a pointer platform the inline links survive', (
      tester,
    ) async {
      // Reset inside the body, not from `addTearDown`: the binding asserts
      // every foundation debug var is unset before tear-downs run.
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final handle = tester.ensureSemantics();
      try {
        await _render(tester, quoteRow(), hostWireName: 'client');

        expect(
          _textSpans(tester).where((s) => s.recognizer != null),
          hasLength(1),
          reason: 'a mouse hits the glyph box every time; nothing is lost here',
        );
        expect(
          _textSpans(
            tester,
          ).where((s) => s.style?.color == InTheme.light.accent),
          hasLength(1),
          reason: 'the link keeps its accent where it can actually be clicked',
        );
        // The merge is conditional, and this is the branch that must skip it:
        // `SemanticsConfiguration` folds descendant actions into one, so
        // merging over a live recognizer would leave a screen reader a single
        // ambiguous tap for a row with two destinations. Drop the condition
        // and the link's own node goes with it.
        expect(
          find.semantics.byAction(SemanticsAction.tap),
          findsExactly(2),
          reason: 'the row button AND the link each keep an invocable node',
        );
        expect(
          find.byIcon(Icons.chevron_right),
          findsOneWidget,
          reason: 'the row is a target on every platform',
        );
      } finally {
        handle.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a row about the record on screen is inert', (tester) async {
      await _render(tester, quoteRow(), hostWireName: 'quote');
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('a comment keeps its menu and takes no row tap', (
      tester,
    ) async {
      await _render(
        tester,
        _activity(
          typeId: 141,
          notes: 'Chasing this one up',
          refs: const {
            'invoice': ActivityRef(
              label: '0012',
              type: EntityType.invoice,
              id: 'i1',
            ),
          },
        ),
        hostWireName: 'client',
      );
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.byType(CommentRowMenu), findsOneWidget);
    });

    testWidgets('the tappable row is a button a screen reader can invoke', (
      tester,
    ) async {
      // The assertion that would have caught this one: `ExcludeSemantics`
      // drops the whole subtree, and the tap action lives on `InkResponse`'s
      // own `Semantics(onTap:)` — which does not set `button` — so a wrapper
      // that declares the role without re-declaring the action leaves a node
      // TalkBack announces and cannot activate. The sibling assertion for the
      // `⋯` menu is a few tests above; `task_calendar_grid_mini_test.dart`
      // makes the same one for #137.
      final handle = tester.ensureSemantics();
      await _render(tester, quoteRow(), hostWireName: 'client');

      expect(
        find.semantics.byAction(SemanticsAction.tap),
        findsExactly(1),
        reason:
            'the other side of the merge condition: on touch there are no '
            'recognizers to absorb, so the row collapses to one stop',
      );

      final node = tester.getSemantics(find.byType(InkWell));
      final data = node.getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(
        data.hasAction(SemanticsAction.tap),
        isTrue,
        reason: 'announced but not invocable is the bug this guards',
      );
      expect(data.label, contains('0092'));
      expect(
        data.tooltip,
        isEmpty,
        reason:
            'with no company Formatter the absolute stamp is a raw ISO string '
            '— iOS appends a tooltip to the label, so it stays off',
      );
      handle.dispose();
    });

    testWidgets('the absolute timestamp survives the exclude once it can be '
        'formatted', (tester) async {
      // `ExcludeSemantics` drops the meta line's `Tooltip` along with
      // everything else, so the wrapper re-declares it — the same re-declare
      // the tap action needs, for the same reason.
      final handle = tester.ensureSemantics();
      await _render(
        tester,
        quoteRow(),
        hostWireName: 'client',
        formatter: Formatter(
          settings: CompanyFormatSettings.fallback,
          currencies: const {},
          countries: const {},
          dateFormats: const {},
        ),
      );
      expect(
        tester.getSemantics(find.byType(InkWell)).getSemanticsData().tooltip,
        isNotEmpty,
      );
      handle.dispose();
    });

    testWidgets('the chevron survives the responsive sweep at max text scale', (
      tester,
    ) async {
      // The row grew 20 px of trailing chrome; #112 / #136 / #140 are why this
      // repo sweeps rather than assuming a wrapping sentence absorbs it.
      for (final width in kResponsiveWidths) {
        await pumpAt(
          tester,
          width,
          ActivityRecordRow(
            activity: _activity(
              typeId: 10,
              refs: const {
                'user': ActivityRef(label: 'Hammy Havoc'),
                'payment': ActivityRef(
                  label: '0001',
                  type: EntityType.payment,
                  id: 'p1',
                ),
                'invoice': ActivityRef(
                  label: '0012',
                  type: EntityType.invoice,
                  id: 'i1',
                ),
                'client': ActivityRef(
                  label: 'A client with a rather long trading name Ltd',
                  type: EntityType.client,
                  id: 'c1',
                ),
              },
            ),
            formatter: null,
            hostWireName: 'client',
          ),
          textScale: kTextScaleMax,
        );
        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
        expectNoOverflow(tester);
      }
    });

    /// Pumps [activity] as a row inside a real router, so a tap can be
    /// followed to a location. Returns the router to assert on.
    Future<GoRouter> pumpRouted(WidgetTester tester, Activity activity) async {
      final fixture = await buildFixture(
        companies: [const FakeCompany(id: 'co1', name: 'Co')],
      );
      addTearDown(fixture.dispose);

      Widget dest(String name) => Scaffold(body: Text(name));
      final router = GoRouter(
        initialLocation: '/clients/c1',
        routes: [
          GoRoute(
            path: '/clients/:id',
            builder: (context, state) => Scaffold(
              body: Center(
                child: SizedBox(
                  width: 420,
                  child: ActivityRecordRow(
                    activity: activity,
                    formatter: null,
                    hostWireName: 'client',
                  ),
                ),
              ),
            ),
          ),
          GoRoute(path: '/quotes/:id', builder: (c, s) => dest('quote screen')),
          GoRoute(
            path: '/payments/:id',
            builder: (c, s) => dest('payment screen'),
          ),
          GoRoute(
            path: '/invoices/:id',
            builder: (c, s) => dest('invoice screen'),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        Provider<Services>.value(
          value: fixture.services,
          child: MaterialApp.router(
            theme: buildInTheme(InTheme.light),
            localizationsDelegates: kTestLocalizationsDelegates,
            supportedLocales: kTestSupportedLocales,
            routerConfig: router,
          ),
        ),
      );
      // Never `pumpAndSettle` — the fixture keeps timers pending.
      await tester.pump();
      return router;
    }

    testWidgets('a tap in the row\'s dead band opens the quote', (
      tester,
    ) async {
      // The reported gesture, and the geometry the whole fix is about: the
      // sentence is a ~17 dp line inside a 72 dp row, so most of the row is
      // dead space. Tapping the chevron — or the text — would prove only that
      // *something* is hittable; this lands in the empty band below the
      // badge, where pre-fix there was nothing at all.
      final router = await pumpRouted(tester, quoteRow());

      final row = tester.getRect(find.byType(ActivityRecordRow));
      expect(
        tester.getSize(find.byType(InkWell)).height,
        greaterThanOrEqualTo(kEntityListRowHeight - 1),
        reason: 'the whole band is the target, not just the text',
      );

      await tester.tapAt(row.bottomLeft + const Offset(24, -8));
      await tester.pump();
      await tester.pump();

      expect(find.text('quote screen'), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/quotes/q1',
      );
    });

    testWidgets('a refund row opens the payment it names, not the invoice it '
        'merely carries', (tester) async {
      // The end-to-end guard on `refTokens`. `activity_40` is ":user refunded
      // :adjustment of a :payment_amount payment :payment" — it never names an
      // invoice — but `RefundPayment::createActivity` stamps `invoice_id` on
      // the row anyway. Seeding `refTokens` from `a.refs.keys` instead of the
      // substitution loop passes every other test in this file and sends this
      // row to an invoice nobody mentioned.
      final router = await pumpRouted(
        tester,
        _activity(
          typeId: 40,
          refs: const {
            'user': ActivityRef(label: 'Hammy Havoc'),
            'payment': ActivityRef(
              label: '0001',
              type: EntityType.payment,
              id: 'p1',
            ),
            'invoice': ActivityRef(
              label: '0012',
              type: EntityType.invoice,
              id: 'i1',
            ),
          },
        ),
      );

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      await tester.pump();

      expect(find.text('payment screen'), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/payments/p1',
      );
    });
  });

  testWidgets('the chevron sits on the trailing edge in both directions', (
    tester,
  ) async {
    // `Icons.chevron_right` is `matchTextDirection: true`, so it must NOT be
    // hand-mirrored — but asserting that flag only tests Material. What has to
    // hold is the row's own geometry: the affordance follows the text
    // direction, whether that comes from the flag, a `Transform`, or a swap to
    // `chevron_left` by some later hand.
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Directionality(
            textDirection: direction,
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 420,
                  child: ActivityRecordRow(
                    activity: _activity(
                      typeId: 19,
                      refs: const {
                        'user': ActivityRef(label: 'Hammy Havoc'),
                        'quote': ActivityRef(
                          label: '0092',
                          type: EntityType.quote,
                          id: 'q1',
                        ),
                      },
                    ),
                    formatter: null,
                    hostWireName: 'client',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final row = tester.getRect(find.byType(ActivityRecordRow));
      final chevron = tester.getRect(find.byIcon(Icons.chevron_right));
      if (direction == TextDirection.ltr) {
        expect(chevron.center.dx, greaterThan(row.center.dx));
      } else {
        expect(
          chevron.center.dx,
          lessThan(row.center.dx),
          reason: 'in RTL the trailing edge is the left one',
        );
      }
    }
  });
}
