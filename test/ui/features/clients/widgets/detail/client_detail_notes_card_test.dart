import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_notes_card.dart';

import '../../../../../_localization_helper.dart';

/// `public_notes` / `private_notes` are HTML on the wire — this app writes it,
/// the React client writes it, and the pre-v5 apps wrote it — so a read-only
/// card has to render the words rather than the markup. Before
/// invoiceninja/flutter#159 anything authored on the web painted raw `<p>`
/// tags at the user here.

Client _client({String privateNotes = '', String publicNotes = ''}) =>
    Client.fromApi(
      ClientApi(
        id: 'c1',
        name: 'Acme',
        privateNotes: privateNotes,
        publicNotes: publicNotes,
        updatedAt: 1,
      ),
    );

Future<void> _pump(WidgetTester tester, Client client) => tester.pumpWidget(
  MaterialApp(
    theme: buildInTheme(InTheme.light),
    localizationsDelegates: kTestLocalizationsDelegates,
    supportedLocales: kTestSupportedLocales,
    home: Scaffold(body: ClientDetailNotesCard(client: client)),
  ),
);

void main() {
  testWidgets('renders the words of an HTML note, not its tags', (
    tester,
  ) async {
    await _pump(
      tester,
      _client(publicNotes: '<p>Hi Bob</p><p>Thanks for the <b>quote</b>.</p>'),
    );

    expect(find.text('Hi Bob\n\nThanks for the quote.'), findsOneWidget);
    expect(find.textContaining('<p>'), findsNothing);
  });

  testWidgets('a note that renders as nothing opens no card', (tester) async {
    // `<p></p>` is what an HTML editor stores for an empty body; gating on the
    // raw string would reserve a card with nothing in it.
    await _pump(tester, _client(privateNotes: '<p></p>'));

    expect(find.byType(SizedBox), findsWidgets);
    expect(
      ClientDetailNotesCard.hasContent(_client(privateNotes: '<p></p>')),
      isFalse,
    );
    expect(
      ClientDetailNotesCard.hasContent(_client(privateNotes: '<p>x</p>')),
      isTrue,
    );
  });

  testWidgets('legacy plain text still renders its line breaks', (
    tester,
  ) async {
    await _pump(tester, _client(privateNotes: 'line one\nline two'));

    expect(find.text('line one\nline two'), findsOneWidget);
  });
}
