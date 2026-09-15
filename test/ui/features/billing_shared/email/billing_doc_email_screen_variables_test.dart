import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/billing/invitation.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/contact.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/services/templates_api.dart';
import 'package:admin/ui/core/widgets/template_variables/template_variable_chip.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/email/billing_doc_email_screen.dart';
import 'package:admin/ui/features/clients/view_models/client_edit_view_model.dart'
    show emptyClient;
import 'package:admin/utils/legacy_html_markdown.dart';

import '../../../../_localization_helper.dart';

const _templateSubject = r'New invoice $number from $company.name';
const _templateBody =
    r'<p>$client</p><p>To view your invoice for $amount, click the link '
    r'below.</p><div>$view_button</div>';
const _values = {
  r'$number': '0012',
  r'$company.name': 'Acme Ltd',
  r'$client': 'Jane Doe',
  r'$amount': r'$1,250.00',
  r'$balance': r'$1,250.00',
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
  _FakeTemplatesApi({this.templateBody = _templateBody});

  /// The stored template body. HTML, as every Invoice Ninja client writes it.
  final String templateBody;

  final subjects = <String>[];

  bool get probed => subjects.any((s) => s.contains('[[in'));

  @override
  Future<TemplatePreview> render({
    required String template,
    required String subject,
    required String body,
    String entity = '',
    String entityId = '',
  }) async {
    subjects.add(subject);
    final rawSubject = subject.isEmpty ? _templateSubject : subject;
    final rawBody = body.isEmpty ? templateBody : body;
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
  List<String?>? sentBodies,
}) async {
  // A phone: the narrow layout, where the preview is a tab away.
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final api = _FakeTemplatesApi(templateBody: templateBody);
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

Finder get _bodyField =>
    find.byWidgetPredicate((w) => w is TextField && w.minLines == 4);

void main() {
  testWidgets('the subject seeds from the template, its chips carrying the '
      'document\'s values', (tester) async {
    final api = await _pump(tester);
    expect(api.probed, isTrue);
    expect(find.byType(TemplateVariableChip), findsNWidgets(2));
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

  testWidgets('the body starts empty; Customize loads the template without '
      'dirtying the form, Reset empties it again', (tester) async {
    await _pump(tester);
    expect(tester.widget<TextField>(_bodyField).controller!.text, isEmpty);

    await tester.tap(find.text('Customize'));
    await tester.pumpAndSettle();
    // The stored template is HTML — React's editor writes it, and so does this
    // app's Templates & Reminders screen — so a plain field has to be handed
    // the words, not the tags. It goes back out as HTML on send.
    expect(
      tester.widget<TextField>(_bodyField).controller!.text,
      markdownFromLegacyHtml(_templateBody),
    );
    expect(_canPop(tester), isTrue);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(_bodyField).controller!.text, isEmpty);
    expect(find.text('Customize'), findsOneWidget);
  });

  testWidgets('Customize then send hands the template back unchanged', (
    tester,
  ) async {
    // The body is a plain field over an HTML value, so the fold that makes it
    // readable and the converter that writes it back have to be inverses. They
    // weren't: bold came back as `**Bob**`, the list as `- One<br>- Two`, and
    // the link as literal `[this](url)` — a template degraded just by being
    // customised and sent.
    const rich =
        '<p>Hi <strong>Bob</strong></p>'
        '<ul><li>One</li><li>Two</li></ul>'
        '<p>See <a href="https://x.test">this</a></p>';
    final sent = <String?>[];
    await _pump(tester, templateBody: rich, sentBodies: sent);

    await tester.tap(find.text('Customize'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    // Let the "queued" toast's own timers run out; the controller outlives the
    // screen, which pops itself on send.
    await tester.pump(const Duration(seconds: 7));

    expect(sent.single, rich);
  });

  testWidgets('a body typed from scratch keeps its line breaks', (
    tester,
  ) async {
    // The other half of invoiceninja/flutter#159: the server renders a
    // non-`custom` template body through CommonMark and injects a custom one
    // raw, so a bare newline survives neither.
    final sent = <String?>[];
    await _pump(tester, sentBodies: sent);

    await tester.enterText(_bodyField, 'Hi Bob\nThanks.\n\nRegards');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 7));

    expect(sent.single, '<p>Hi Bob<br>Thanks.</p><p>Regards</p>');
    expect(sent.single, isNot(contains('\n')));
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
}
