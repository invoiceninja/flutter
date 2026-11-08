import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/billing/billing_contact.dart';
import 'package:admin/ui/features/billing_shared/contacts/billing_doc_contacts_section.dart';

import '../../../_localization_helper.dart';

BillingContact _contact(
  String id, {
  String firstName = 'Ada',
  String lastName = 'Lovelace',
  String email = 'ada@example.com',
  bool isPrimary = false,
}) => BillingContact(
  id: id,
  firstName: firstName,
  lastName: lastName,
  email: email,
  isPrimary: isPrimary,
);

Widget _host({
  required List<BillingContact> contacts,
  required Set<String> selected,
  required ValueChanged<Set<String>> onChanged,
  Map<String, bool?>? canSign,
  void Function(String, bool)? onCanSignChanged,
}) => MaterialApp(
  theme: buildInTheme(InTheme.light),
  localizationsDelegates: kTestLocalizationsDelegates,
  home: Scaffold(
    body: BillingDocContactsSection(
      contacts: contacts,
      selectedContactIds: selected,
      onChanged: onChanged,
      canSignByContactId: canSign,
      onCanSignChanged: onCanSignChanged,
    ),
  ),
);

void main() {
  // Contact ids are minted by the server. A contact with an empty id belongs
  // to a client that hasn't synced yet (created offline, or inline from a
  // billing-doc client picker). Toggling it would ship an invitation the
  // server can't resolve, failing `invitations.*.client_contact_id` and 422ing
  // the whole document save — so the row must be inert.
  group('unsynced contact rows', () {
    testWidgets('a blank-id row renders disabled and does not toggle', (
      tester,
    ) async {
      Set<String>? emitted;
      await tester.pumpWidget(
        _host(
          contacts: [_contact('', isPrimary: true)],
          selected: const {},
          onChanged: (next) => emitted = next,
        ),
      );

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.onChanged, isNull);

      await tester.tap(find.text('Ada Lovelace'));
      await tester.pump();
      expect(emitted, isNull);
    });

    testWidgets('a blank-id row explains itself via tooltip', (tester) async {
      await tester.pumpWidget(
        _host(contacts: [_contact('')], selected: const {}, onChanged: (_) {}),
      );

      expect(
        find.byTooltip('Available once this client syncs'),
        findsOneWidget,
      );
    });

    testWidgets('real-id rows still toggle', (tester) async {
      Set<String>? emitted;
      await tester.pumpWidget(
        _host(
          contacts: [_contact('c1')],
          selected: const {},
          onChanged: (next) => emitted = next,
        ),
      );

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.onChanged, isNotNull);

      await tester.tap(find.text('Ada Lovelace'));
      await tester.pump();
      expect(emitted, {'c1'});
    });

    testWidgets('a mixed list disables only the unsynced row', (tester) async {
      final emitted = <Set<String>>[];
      await tester.pumpWidget(
        _host(
          contacts: [
            _contact('c1', firstName: 'Real', lastName: 'Contact'),
            _contact('', firstName: 'Pending', lastName: 'Contact'),
          ],
          selected: const {'c1'},
          onChanged: emitted.add,
        ),
      );

      final boxes = tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
      expect(boxes, hasLength(2));
      expect(boxes[0].onChanged, isNotNull);
      expect(boxes[1].onChanged, isNull);

      // The unsynced row is visible, not hidden — hiding it would read as
      // data loss on a freshly created client.
      expect(find.text('Pending Contact'), findsOneWidget);

      await tester.tap(find.text('Pending Contact'));
      await tester.pump();
      expect(emitted, isEmpty);
    });
  });

  // DocuNinja's "Authorized to sign", as React's ClientSelector draws it.
  group('Authorized to sign', () {
    testWidgets('is absent while DocuNinja is off', (tester) async {
      await tester.pumpWidget(
        _host(contacts: [_contact('a')], selected: {'a'}, onChanged: (_) {}),
      );
      expect(find.text('Authorized to sign'), findsNothing);
    });

    testWidgets('toggles can_sign on an invited contact, not the invitation', (
      tester,
    ) async {
      final changes = <(String, bool)>[];
      Set<String>? invited;
      await tester.pumpWidget(
        _host(
          contacts: [_contact('a')],
          selected: {'a'},
          onChanged: (next) => invited = next,
          canSign: {'a': false},
          onCanSignChanged: (id, v) => changes.add((id, v)),
        ),
      );
      await tester.tap(find.text('Authorized to sign'));
      await tester.pump();
      expect(changes, [('a', true)]);
      expect(invited, isNull);
    });

    testWidgets('does nothing on a contact that is not invited', (
      tester,
    ) async {
      final changes = <(String, bool)>[];
      Set<String>? invited;
      await tester.pumpWidget(
        _host(
          contacts: [_contact('a')],
          selected: const {},
          onChanged: (next) => invited = next,
          canSign: const {},
          onCanSignChanged: (id, v) => changes.add((id, v)),
        ),
      );
      // Neither the dimmed label nor its checkbox may fall through to the
      // contact row, which would invite the contact.
      await tester.tap(find.text('Authorized to sign'));
      await tester.pump();
      await tester.tap(find.byType(Checkbox).last);
      await tester.pump();
      expect(changes, isEmpty);
      expect(invited, isNull);
    });

    testWidgets('an unread can_sign shows as a dash, not as false', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          contacts: [_contact('a')],
          selected: {'a'},
          onChanged: (_) {},
          canSign: {'a': null},
          onCanSignChanged: (_, _) {},
        ),
      );
      final boxes = tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
      expect(boxes.last.tristate, isTrue);
      expect(boxes.last.value, isNull);
    });
  });
}
