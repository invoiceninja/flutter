import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/templates_api.dart';
import 'package:admin/domain/email_template_variables.dart';
import 'package:admin/ui/features/billing_shared/email/template_variable_values_controller.dart';

/// Renders the probe subject the way the server does (`strtr`, longest key
/// first) — or fails with [error], or waits on [gate].
class _FakeTemplatesApi implements TemplatesApi {
  _FakeTemplatesApi(this.values);

  final Map<String, String> values;
  Object? error;
  Completer<void>? gate;
  final calls = <List<String>>[];

  @override
  Future<TemplatePreview> render({
    required String template,
    required String subject,
    required String body,
    String entity = '',
    String entityId = '',
  }) async {
    calls.add(findTemplateVariables(subject).map((m) => m.token).toList());
    if (gate != null) await gate!.future;
    final e = error;
    if (e != null) throw e;
    final keys = values.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final out = StringBuffer();
    var i = 0;
    outer:
    while (i < subject.length) {
      for (final key in keys) {
        if (subject.startsWith(key, i)) {
          out.write(values[key]);
          i += key.length;
          continue outer;
        }
      }
      out.write(subject[i]);
      i++;
    }
    return TemplatePreview(
      subject: out.toString(),
      body: body,
      wrapper: '',
      rawSubject: subject,
      rawBody: body,
    );
  }
}

Future<void> _settle() async {
  for (var i = 0; i < 3; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _FakeTemplatesApi api;
  late DateTime now;

  TemplateVariableValuesController build() => TemplateVariableValuesController(
    api: api,
    entity: 'invoice',
    entityId: 'Wpmbk5ezJn',
    scope: TemplateVariableScope.invoice,
    template: () => 'invoice',
    debounce: Duration.zero,
    clock: () => now,
  );

  setUp(() {
    api = _FakeTemplatesApi({r'$number': '0012', r'$company.name': 'Acme'});
    now = DateTime(2026, 9, 11, 12);
  });

  test('one probe on open covers the catalog and the subject', () async {
    final controller = build();
    addTearDown(controller.dispose);
    var notified = 0;
    controller.addListener(() => notified++);

    controller.start(const [r'$invoice.date']);
    await _settle();

    expect(api.calls, hasLength(1));
    expect(api.calls.single, containsAll([r'$number', r'$invoice.date']));
    expect(
      (controller.value[r'$number']! as TemplateVariableResolved).text,
      '0012',
    );
    expect(controller.value[r'$invoice.date'], isA<TemplateVariableUnknown>());
    expect(notified, 1);
  });

  test('later text probes only tokens nobody asked about', () async {
    final controller = build();
    addTearDown(controller.dispose);
    controller.start(const []);
    await _settle();

    controller.noteText(r'Invoice $number from $company.name');
    await _settle();
    expect(api.calls, hasLength(1), reason: 'both are catalogued');

    controller.noteText(r'Invoice $custom.thing');
    await _settle();
    expect(api.calls, hasLength(2));
    expect(api.calls.last, [r'$custom.thing']);
  });

  test('a permanent failure stops probing for the screen', () async {
    api.error = const ServerException(403);
    final controller = build();
    addTearDown(controller.dispose);
    controller.start(const []);
    await _settle();

    api.error = null;
    controller.noteText(r'Hi $custom.thing');
    await _settle();
    expect(api.calls, hasLength(1));
    expect(controller.value, isEmpty);
  });

  test('a transient failure retries on a later change, not before the '
      'window', () async {
    api.error = const NetworkException('offline');
    final controller = build();
    addTearDown(controller.dispose);
    controller.start(const []);
    await _settle();
    expect(api.calls, hasLength(1));

    api.error = null;
    controller.noteText(r'$number');
    await _settle();
    expect(api.calls, hasLength(1), reason: 'inside the 30 s window');

    now = now.add(const Duration(seconds: 31));
    controller.noteText(r'$number');
    await _settle();
    expect(api.calls, hasLength(2));
    expect(
      (controller.value[r'$number']! as TemplateVariableResolved).text,
      '0012',
    );
  });

  test('disposing mid-flight is safe', () async {
    api.gate = Completer<void>();
    final controller = build();
    var notified = 0;
    controller.addListener(() => notified++);
    controller.start(const []);
    await _settle();
    controller.dispose();
    api.gate!.complete();
    await _settle();
    expect(notified, 0);
  });
}
