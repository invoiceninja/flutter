import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:super_editor/super_editor.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/billing/invitation.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/contact.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/services/templates_api.dart';
import 'package:admin/ui/core/widgets/markdown_text_field.dart';
import 'package:admin/ui/core/widgets/template_variables/template_default_badge.dart';
import 'package:admin/ui/core/widgets/template_variables/template_variable_chip.dart';
import 'package:admin/ui/core/widgets/template_variables/template_variable_field_shell.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/email/billing_doc_email_screen.dart';
import 'package:admin/ui/features/billing_shared/email/labeled_field.dart';
import 'package:admin/ui/features/clients/view_models/client_edit_view_model.dart'
    show emptyClient;

import '../../../../_localization_helper.dart';

const _templateSubject = r'New invoice $number from $company.name';
const _reminderSubject = r'Reminder: invoice $number is due';

/// Each template has its own stored subject, which is the whole point of the
/// staleness tests — a cache of "what the server says this template is" that
/// survives a switch is indistinguishable from a fresh one otherwise.
String _subjectFor(String template) =>
    template == 'reminder1' ? _reminderSubject : _templateSubject;
const _templateBody =
    r'<p>$client</p><p>To view your invoice for $amount, click the link '
    r'below.</p><div>$view_button</div>';
const _values = {
  r'$number': '0012',
  r'$company.name': 'Acme Ltd',
  r'$client': 'Jane Doe',
  r'$amount': r'$1,250.00',
  r'$balance': r'$1,250.00',
  // The server answers this with the button's own caption, which is also its
  // label — the duplication the chip suppresses.
  r'$view_button': 'View Invoice',
};

/// PHP `strtr` over [_values]: longest key first, unknown tokens left alone.
String _strtr(String s) {
  final keys = _values.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  final out = StringBuffer();
  var i = 0;
  outer:
  while (i < s.length) {
    for (final key in keys) {
      if (s.startsWith(key, i)) {
        out.write(_values[key]);
        i += key.length;
        continue outer;
      }
    }
    out.write(s[i]);
    i++;
  }
  return out.toString();
}

/// Renders like `TemplateEngine`: an empty subject/body falls back to the
/// template's own, and the subject is substituted with plain `strtr`.
class _FakeTemplatesApi implements TemplatesApi {
  _FakeTemplatesApi({this.templateBody = _templateBody, this.responseDelay});

  /// The stored template body. HTML, as every Invoice Ninja client writes it.
  final String templateBody;

  /// Holds the response open, so a test can let the field change underneath an
  /// in-flight render — `PreviewController` only invalidates its token inside
  /// `_fire()`, so a plain reschedule leaves the old request live.
  final Duration? responseDelay;

  final subjects = <String>[];
  final bodies = <String>[];
  final templates = <String>[];

  bool get probed => subjects.any((s) => s.contains('[[in'));

  /// Renders that were not a variable probe — the ones the composer's own
  /// fields drove.
  Iterable<String> get realBodies => [
    for (var i = 0; i < subjects.length; i++)
      if (!subjects[i].contains('[[in')) bodies[i],
  ];

  @override
  Future<TemplatePreview> render({
    required String template,
    required String subject,
    required String body,
    String entity = '',
    String entityId = '',
  }) async {
    subjects.add(subject);
    bodies.add(body);
    templates.add(template);
    final rawSubject = subject.isEmpty ? _subjectFor(template) : subject;
    final rawBody = body.isEmpty ? templateBody : body;
    final delay = responseDelay;
    if (delay != null) await Future<void>.delayed(delay);
    return TemplatePreview(
      subject: _strtr(rawSubject),
      body: _strtr(rawBody),
      wrapper: '',
      rawSubject: rawSubject,
      rawBody: rawBody,
    );
  }
}

class _FakeClients implements ClientRepository {
  _FakeClients(this.client);

  final Client client;

  @override
  Future<void> ensureLoaded({
    required String companyId,
    required String id,
  }) async {}

  @override
  Stream<Client?> watch({required String companyId, required String id}) =>
      Stream.value(client);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeServices implements Services {
  _FakeServices({required this.templates, required this.clients});

  @override
  final TemplatesApi templates;

  @override
  final ClientRepository clients;

  @override
  final ToastController toasts = ToastController();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Future<_FakeTemplatesApi> _pump(
  WidgetTester tester, {
  bool withInvitation = true,
  String templateBody = _templateBody,
  Duration? responseDelay,
  List<String?>? sentBodies,
  List<String?>? sentSubjects,
}) async {
  // A phone: the narrow layout, where the preview is a tab away.
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final api = _FakeTemplatesApi(
    templateBody: templateBody,
    responseDelay: responseDelay,
  );
  final client = emptyClient().copyWith(
    id: 'cl1',
    contacts: [
      Contact(
        id: 'c1',
        firstName: 'Jane',
        lastName: 'Doe',
        email: 'jane@example.com',
        phone: '',
        isPrimary: true,
        sendEmail: true,
        updatedAt: DateTime.utc(2026, 1, 1, 12),
        isDeleted: false,
      ),
    ],
  );
  final services = _FakeServices(templates: api, clients: _FakeClients(client));
  addTearDown(services.toasts.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider<ToastController>.value(
      value: services.toasts,
      child: MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: BillingDocEmailScreen(
          services: services,
          companyId: 'co',
          type: BillingDocType.invoice,
          entityId: 'inv1',
          entityNumber: '0012',
          invitations: withInvitation
              ? const [Invitation(id: 'i1', clientContactId: 'c1')]
              : const [],
          isDirty: false,
          clientId: 'cl1',
          vendorId: '',
          isHosted: false,
          formatter: null,
          onSend: ({required template, subject, body, ccEmail}) async {
            sentBodies?.add(body);
            sentSubjects?.add(subject);
          },
          onSchedule:
              ({
                required template,
                required sendAt,
                subject,
                body,
                ccEmail,
              }) async {},
          onReactivate: (_) async => 0,
          pdfFetcher: ({designId, required deliveryNote}) async => Uint8List(0),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

/// The composer's own `PopScope` — `canPop` is false exactly when it's dirty.
bool _canPop(WidgetTester tester) => tester
    .widgetList<PopScope>(
      find.descendant(
        of: find.byType(BillingDocEmailScreen),
        matching: find.byWidgetPredicate((w) => w is PopScope),
      ),
    )
    .first
    .canPop;

/// The Body: a `MarkdownTextField`, so the value lives in a super_editor
/// document, not a controller — the parent's copy is what reaches the wire.
Finder get _bodyField => find.byType(MarkdownTextField);

/// Chips inside one field. The subject and the body both render them now, so
/// a bare `find.byType(TemplateVariableChip)` counts across both.
Finder _chipsIn(Finder field) =>
    find.descendant(of: field, matching: find.byType(TemplateVariableChip));

Finder get _subjectField => find.byType(TemplateVariableFieldShell);

/// super_editor runs its own IME, so `tester.enterText` (which wants an
/// `EditableText`) can't reach it — drive the editor directly.
void _typeInBody(WidgetTester tester, String character) {
  tester.widget<SuperEditor>(find.byType(SuperEditor)).editor.execute([
    InsertCharacterAtCaretRequest(character: character),
  ]);
}

void _deleteInBody(WidgetTester tester) {
  tester.widget<SuperEditor>(find.byType(SuperEditor)).editor.execute([
    const DeleteUpstreamCharacterRequest(),
  ]);
}

/// Put the Subject shell into text-edit mode and return its live `TextField`.
///
/// Tapping the shell's centre lands on a chip — `_templateSubject` puts one
/// mid-string — which opens the picker instead. The left edge is the literal
/// "New invoice " that precedes the first one.
Future<Finder> _editSubject(WidgetTester tester) async {
  final shell = find.byType(TemplateVariableFieldShell);
  await tester.tapAt(tester.getRect(shell).centerLeft + const Offset(8, 0));
  await tester.pumpAndSettle();
  final field = find.descendant(of: shell, matching: find.byType(TextField));
  expect(field, findsOneWidget, reason: 'the shell swapped in its TextField');
  return field;
}

Finder get _ccField => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == 'name@example.com',
);

/// The "Default" pill beside the Subject label — it lives in the
/// `LabeledField` row, outside the field, so descending into the shell misses
/// it.
Finder get _subjectBadge => find.descendant(
  of: find.ancestor(
    of: find.byType(TemplateVariableFieldShell),
    matching: find.byType(LabeledField),
  ),
  matching: find.byType(TemplateDefaultBadge),
);

/// Promote the body's reader to the live editor, with the caret where the tap
/// lands.
///
/// The tap must miss every chip — the reader hit-tests one first and swallows
/// the promote. In `_templateBody` the first and last blocks are a chip
/// standing alone, so the reliably empty spot is the right-hand end of the
/// first line; [tapBelowText] is for fixtures that open with prose instead.
/// (There is no `Scrollbar` in the editor host, so the right edge is safe.)
///
/// Frame by frame: a focused editor's caret blinks, so `pumpAndSettle` never
/// settles once it is up.
Future<void> _startEditingBody(
  WidgetTester tester, {
  bool tapBelowText = false,
}) async {
  final scroll = find.descendant(
    of: _bodyField,
    matching: find.byType(CustomScrollView),
  );
  await tester.ensureVisible(scroll);
  await tester.pump();
  final host = tester.getRect(scroll);
  await tester.tapAt(
    tapBelowText
        ? host.bottomLeft + const Offset(24, -8)
        : host.topRight + const Offset(-12, 14),
  );
  await tester.pump(); // `_enterEditing`'s post-frame callback
  await tester.pump(); // the editor mounts
  await tester.pump(); // and takes focus
}

void main() {
  testWidgets('the subject seeds from the template, its chips carrying the '
      'document\'s values', (tester) async {
    final api = await _pump(tester);
    expect(api.probed, isTrue);
    expect(_chipsIn(_subjectField), findsNWidgets(2));
    expect(find.text('0012'), findsOneWidget);
    expect(find.text('Acme Ltd'), findsOneWidget);
    expect(_canPop(tester), isTrue, reason: 'seeding is not an edit');
  });

  testWidgets('an unbound document is never probed', (tester) async {
    final api = await _pump(tester, withInvitation: false);
    expect(api.probed, isFalse);
    expect(find.text('Company Name'), findsOneWidget);
    expect(find.text('Acme Ltd'), findsNothing);
  });

  testWidgets('on a phone the rendered subject shows under the field', (
    tester,
  ) async {
    await _pump(tester);
    expect(
      find.textContaining('New invoice 0012 from Acme Ltd', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('the body shows the template muted, chips carrying the '
      "document's values, and Reset puts it back", (tester) async {
    await _pump(tester);

    // The default is on screen, not an empty box behind a "Customize" button:
    // it is what the server will actually send.
    expect(
      find.descendant(
        of: _bodyField,
        matching: find.byType(TemplateDefaultBadge),
      ),
      findsOneWidget,
    );
    // $client, $amount and $view_button, all three from `_templateBody`.
    expect(_chipsIn(_bodyField), findsNWidgets(3));
    // The whole point of the report: the body's chips carry values, like the
    // subject's. `$amount` appears in both fields' probes, so scope the find.
    expect(
      find.descendant(of: _bodyField, matching: find.text(r'$1,250.00')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _bodyField, matching: find.text('Jane Doe')),
      findsOneWidget,
    );
    // A value that repeats its own label shows the label alone — the probe
    // answers `$view_button` with the button's caption, which is also its
    // name, so the chip would otherwise read "View Invoice  View Invoice".
    expect(
      find.descendant(of: _bodyField, matching: find.text('View Invoice')),
      findsOneWidget,
    );
    expect(_canPop(tester), isTrue, reason: 'showing a default is not an edit');

    await _startEditingBody(tester);
    _typeInBody(tester, 'X');
    await tester.pump();
    // Synchronous, via `onEditing`: `canPop` is read during build and cannot
    // wait for the editor's debounce.
    expect(_canPop(tester), isFalse, reason: 'typing dirties the form at once');

    await tester.pump(const Duration(milliseconds: 200)); // the debounce
    await tester.pump();
    // The badge goes the moment it stops being the default — "muted text under
    // a Default badge that the server will not send" is its own failure mode.
    expect(
      find.descendant(
        of: _bodyField,
        matching: find.byType(TemplateDefaultBadge),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('reset_body')));
    await tester.pump();
    await tester.pump();
    expect(
      find.descendant(
        of: _bodyField,
        matching: find.byType(TemplateDefaultBadge),
      ),
      findsOneWidget,
    );
    // The badge alone proves nothing — it is a function of what the PARENT
    // holds, so it comes back whether or not the document was reseeded.
    expect(
      find.descendant(of: _bodyField, matching: find.textContaining('X')),
      findsNothing,
      reason: 'the edit is gone from the document, not just from the value',
    );
    expect(_chipsIn(_bodyField), findsNWidgets(3));
    expect(_canPop(tester), isTrue);
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('an untouched body sends null, so the server localises the '
      'template per client', (tester) async {
    final sent = <String?>[];
    await _pump(tester, sentBodies: sent);

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    // Let the "queued" toast's own timers run out; the controller outlives the
    // screen, which pops itself on send.
    await tester.pump(const Duration(seconds: 7));

    expect(
      sent.single,
      isNull,
      reason: 'an unedited body is the template, and the server owns that',
    );
  });

  testWidgets('an edited rich template goes back out as HTML, intact', (
    tester,
  ) async {
    // The composed pipeline — `markdownFromLegacyHtml` in, tokenize, edit,
    // detokenize, `htmlFromEditorDocument` out — is covered end to end
    // nowhere else: `editor_html_test.dart` has the fold without the chips and
    // `markdown_template_variables_test.dart` the chips without the fold. This
    // is what the old plain-field round-trip test guarded, and the shapes are
    // the ones that regressed: bold came back `**Bob**`, the list as
    // `- One<br>- Two`, and the link as a literal `[this](url)`.
    const rich =
        '<p>Hi <strong>Bob</strong></p>'
        '<ul><li>One</li><li>Two</li></ul>'
        '<p>See <a href="https://x.test">this</a></p>';
    final sent = <String?>[];
    await _pump(tester, templateBody: rich, sentBodies: sent);

    await _startEditingBody(tester, tapBelowText: true);
    _typeInBody(tester, '!');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 7));

    final body = sent.single;
    expect(body, isNotNull, reason: 'an edited body is an override');
    expect(body, contains('<strong>Bob</strong>'));
    expect(body, contains('<ul><li>One</li>'));
    expect(body, contains('href="https://x.test"'));
    expect(body, isNot(contains('\n')));
  });

  testWidgets('a rendered body never becomes the default — Reset restores the '
      'template, not the edit', (tester) async {
    // `raw_body` is the REQUEST echoed back (`TemplateEngine.php` assigns it
    // after `setTemplates()`), so a render that lands while the user is typing
    // carries the user's own text. Adopting that as the default made Reset
    // restore what it had just reset away.
    final api = await _pump(tester);
    await _startEditingBody(tester);
    _typeInBody(tester, 'X');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    // Let the preview round trip land with the echoed body.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    // Without this the test cannot tell "the guard works" from "no render ever
    // carried the user's text", which is what made it vacuous.
    expect(
      api.realBodies.last,
      contains('X'),
      reason: 'a render went out carrying the edit, and echoed it back',
    );

    await tester.tap(find.byKey(const Key('reset_body')));
    await tester.pump();
    await tester.pump();
    expect(
      find.descendant(of: _bodyField, matching: find.textContaining('X')),
      findsNothing,
      reason: 'Reset restored the template, not the echoed edit',
    );
    expect(_chipsIn(_bodyField), findsNWidgets(3));
    expect(_canPop(tester), isTrue, reason: 'Reset leaves a clean form');
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('changing a chip is an edit', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Company Name'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Balance'));
    await tester.pumpAndSettle();
    expect(_canPop(tester), isFalse);
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('Reset puts the template subject back', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Company Name'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Acme Ltd'), findsNothing);

    await tester.tap(find.byIcon(Icons.restart_alt));
    await tester.pumpAndSettle();
    expect(find.text('Acme Ltd'), findsOneWidget);
    expect(_canPop(tester), isTrue);
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('scheduling after an edit asks first — the server would drop '
      'the edit', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Company Name'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Balance'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule').last);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Scheduled emails are sent with the saved template'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsNothing);
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('a template switch drops the old template as the default, so an '
      'edit typed back is still an edit', (tester) async {
    // The cache of "what the server says this template is" cannot be refreshed
    // once the field is edited (every adopt path needs our own value empty),
    // so keeping it across a switch made `_editedSubject` compare against the
    // WRONG template: typing the old wording back read as "unedited" and sent
    // null, i.e. the new template's subject, while the user watched their own.
    final sentSubjects = <String?>[];
    final api = await _pump(tester, sentSubjects: sentSubjects);
    // The RAW template, tokens and all — that is what the field holds and what
    // `rawSubject` echoes; `preview.subject` is the substituted rendering.
    const original = _templateSubject;

    final subject = await _editSubject(tester);
    await tester.enterText(subject, 'Mine');
    await tester.pumpAndSettle();
    expect(_canPop(tester), isFalse);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('First Reminder').last);
    await tester.pumpAndSettle();
    expect(api.templates.last, 'reminder1');

    // Type the FIRST template's subject back. It is the second template's
    // subject that is the default now, so this is an override — and the stale
    // cache used to read it as "unedited" and send null, i.e. the reminder's
    // wording, while the user was looking at the invoice one.
    await tester.enterText(await _editSubject(tester), original);
    await tester.pumpAndSettle();
    expect(
      _canPop(tester),
      isFalse,
      reason: 'it is an override now, whatever it says',
    );
    expect(_subjectBadge, findsNothing);

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 7));
    expect(sentSubjects.single, original);
  });

  testWidgets('a render carrying the user\'s own text never becomes the '
      'default, even once they clear the field', (tester) async {
    // `PreviewController` only invalidates its token inside `_fire()`, so a
    // non-immediate reschedule leaves an in-flight request valid: the response
    // to "Hel" can land after the field is empty. Adopting it made the user's
    // own deleted draft the muted "Default".
    await _pump(tester, responseDelay: const Duration(milliseconds: 300));
    final subject = await _editSubject(tester);

    await tester.enterText(subject, 'Hel');
    // Past the 400 ms debounce, so the render is issued and in flight...
    await tester.pump(const Duration(milliseconds: 450));
    // ...then clear the field before its (delayed) response lands.
    await tester.enterText(subject, '');

    // Land the stale response, and stop short of the 400 ms debounce that
    // would issue a fresh render and heal the damage. The bug self-heals on
    // the next good render, so a `pumpAndSettle` here hides it entirely — and
    // it does NOT heal if that render errors.
    await tester.pump(const Duration(milliseconds: 320));

    // Ask the question through the *derived* state rather than the rendered
    // text: the field still has focus, so the shell is showing its editor, not
    // the muted default that would expose the poisoning directly. Typing the
    // draft back is an edit — unless the screen has adopted it as the
    // template, in which case it reads as "unedited" and would send null.
    await tester.enterText(subject, 'Hel');
    await tester.pump();
    expect(
      _canPop(tester),
      isFalse,
      reason: '"Hel" is the user\'s own text, never this template\'s default',
    );
    expect(_subjectBadge, findsNothing);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('clearing the default body and letting it come back leaves a '
      'clean form', (tester) async {
    // The edit round-trips, so `onChanged` never fires — only `onEditing`'s
    // false edge can un-dirty the form. Without it: a Reset button over an
    // untouched default, a discard prompt on every close, and a schedule
    // warning about edits that do not exist.
    await _pump(tester);
    await _startEditingBody(tester);
    _typeInBody(tester, 'X');
    await tester.pump();
    expect(_canPop(tester), isFalse);

    _deleteInBody(tester);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(_canPop(tester), isTrue, reason: 'nothing left to discard');
    expect(find.byKey(const Key('reset_body')), findsNothing);
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('a CC typo blocks Send even when the field was never blurred', (
    tester,
  ) async {
    // On touch an AppBar button takes no focus, so tapping Send never blurs
    // the CC field and the blur-time check never runs.
    final sent = <String?>[];
    await _pump(tester, sentBodies: sent);
    await tester.enterText(_ccField, 'bob@acme');
    await tester.pump();

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(sent, isEmpty, reason: 'nothing may be posted');
    expect(find.text('Email is invalid'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('a comma or space separated CC list is accepted, as the server '
      'parses it', (tester) async {
    // `SendEmailRequest::prepareForValidation` explodes on both, so validating
    // the field as one address disabled Send on a perfectly good entry.
    final sent = <String?>[];
    await _pump(tester, sentBodies: sent);
    await tester.enterText(_ccField, 'a@x.com, b@y.com c@z.com');
    await tester.pump();

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 7));
    expect(sent, hasLength(1));
    expect(find.text('Email is invalid'), findsNothing);
  });

  testWidgets('the subject keeps its Default badge when tapped and left '
      'untouched', (tester) async {
    // The shell adopts a copy of the default into the controller on tap, so a
    // badge keyed on "the field is empty" vanishes off a field that is still
    // showing the default — muted grey text with nothing to explain it.
    await _pump(tester);
    expect(_subjectBadge, findsOneWidget);

    await _editSubject(tester);
    await tester.tap(find.text('CC Email'));
    await tester.pumpAndSettle();

    expect(_subjectBadge, findsOneWidget);
    expect(find.byKey(const Key('reset_subject')), findsNothing);
    await tester.pump(const Duration(seconds: 30));
  });
}
