import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/services/templates_api.dart';
import 'package:admin/ui/features/settings/views/advanced/templates_reminders/preview_controller.dart';

// `TemplatesApi` is a concrete class with only `render()`. We can't
// implement-with-noSuchMethod cheaply because its constructor wants an
// ApiClient — wrap with `implements` to swap behavior.
class _FakeTemplatesApi implements TemplatesApi {
  _FakeTemplatesApi({this.shouldThrow = false});

  int callCount = 0;
  bool shouldThrow;
  final List<String> templates = [];
  final List<(String, String)> entities = [];

  @override
  Future<TemplatePreview> render({
    required String template,
    required String subject,
    required String body,
    String entity = '',
    String entityId = '',
  }) async {
    callCount++;
    templates.add(template);
    entities.add((entity, entityId));
    if (shouldThrow) {
      throw const FormatException('boom');
    }
    return TemplatePreview(
      subject: subject,
      body: body,
      wrapper: '<html><body>$body</body></html>',
      rawSubject: subject,
      rawBody: body,
    );
  }
}

void main() {
  group('PreviewController', () {
    test('coalesces rapid scheduled calls into a single fetch', () async {
      final api = _FakeTemplatesApi();
      final controller = PreviewController(
        api: api,
        debounce: const Duration(milliseconds: 50),
      );
      addTearDown(controller.dispose);

      // Three rapid schedules within the debounce window — only the last
      // template id should be fired through the API.
      controller.schedule(template: 'invoice', subject: 'S1', body: 'B1');
      controller.schedule(template: 'quote', subject: 'S2', body: 'B2');
      controller.schedule(template: 'credit', subject: 'S3', body: 'B3');

      // Wait past the debounce window and the awaitable.
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(api.callCount, 1);
      expect(api.templates.single, 'credit');
      final state = controller.value as TemplatePreviewLoaded;
      expect(state.preview.subject, 'S3');
    });

    test('immediate: true bypasses the debounce', () async {
      final api = _FakeTemplatesApi();
      final controller = PreviewController(
        api: api,
        debounce: const Duration(seconds: 10),
      );
      addTearDown(controller.dispose);

      controller.schedule(
        template: 'invoice',
        subject: 'S',
        body: 'B',
        immediate: true,
      );
      // No need to wait past the debounce — immediate fires synchronously.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(api.callCount, 1);
    });

    test('transitions to error on a thrown render', () async {
      final api = _FakeTemplatesApi(shouldThrow: true);
      final controller = PreviewController(
        api: api,
        debounce: const Duration(milliseconds: 10),
      );
      addTearDown(controller.dispose);

      controller.schedule(template: 'invoice', subject: '', body: '');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.value, isA<TemplatePreviewError>());
      final state = controller.value as TemplatePreviewError;
      expect(state.message, contains('boom'));
    });

    test('refresh() re-fires the last scheduled request', () async {
      final api = _FakeTemplatesApi();
      final controller = PreviewController(
        api: api,
        debounce: const Duration(milliseconds: 10),
      );
      addTearDown(controller.dispose);

      controller.schedule(template: 'invoice', subject: 'S', body: 'B');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(api.callCount, 1);

      controller.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(api.callCount, 2);
    });

    test('forwards entity + entityId to the API, empty when omitted', () async {
      // The send-email composer binds the render to its own document; the
      // settings preview leaves it empty (invoiceninja/flutter#31).
      final api = _FakeTemplatesApi();
      final controller = PreviewController(
        api: api,
        debounce: const Duration(milliseconds: 10),
      );
      addTearDown(controller.dispose);

      controller.schedule(
        template: 'quote',
        subject: 'S',
        body: 'B',
        entity: 'quote',
        entityId: 'z3YaOpbxql',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(api.entities.single, ('quote', 'z3YaOpbxql'));

      controller.schedule(template: 'invoice', subject: 'S', body: 'B');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(api.entities.last, ('', ''));
    });

    test('render completing after dispose does not notify or throw', () async {
      // Repro for the diagnostics-log error "A PreviewController was used
      // after being disposed": the screen is closed (controller disposed)
      // while a render request is still in flight.
      final api = _CompleterFakeApi();
      final controller = PreviewController(
        api: api,
        debounce: const Duration(milliseconds: 1),
      );

      controller.schedule(
        template: 'invoice',
        subject: 'S',
        body: 'B',
        immediate: true,
      );
      await Future<void>.delayed(Duration.zero);

      // Tear the screen down mid-flight, then let the request resolve.
      // Without the disposed guard this resumes `_fire` past its await and
      // calls notifyListeners() on a disposed ChangeNotifier, which throws
      // a FlutterError that flutter_test surfaces as a test failure.
      controller.dispose();
      api.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // `_fire` bailed before mutating state — never reached
      // TemplatePreviewLoaded.
      expect(controller.value, isA<TemplatePreviewLoading>());
    });

    test('stale completions are dropped (token check)', () async {
      // Two schedules, first with immediate=true so it starts; second also
      // immediate=true. The first await returns before the second starts —
      // but the implementation increments the token on every fire, so the
      // first result must be dropped.
      final api = _SlowFakeApi();
      final controller = PreviewController(
        api: api,
        debounce: const Duration(milliseconds: 1),
      );
      addTearDown(controller.dispose);

      controller.schedule(
        template: 'invoice',
        subject: 'first',
        body: 'first',
        immediate: true,
      );
      controller.schedule(
        template: 'invoice',
        subject: 'second',
        body: 'second',
        immediate: true,
      );
      // Resolve the first slow request — its token is stale by now.
      api.completeAll();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final state = controller.value as TemplatePreviewLoaded;
      expect(state.preview.subject, 'second');
    });
  });
}

/// Fake that yields after a small delay so the stale-token check sees
/// two in-flight requests.
class _SlowFakeApi implements TemplatesApi {
  bool _completed = false;

  @override
  Future<TemplatePreview> render({
    required String template,
    required String subject,
    required String body,
    String entity = '',
    String entityId = '',
  }) async {
    if (!_completed) {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    return TemplatePreview(
      subject: subject,
      body: body,
      wrapper: '',
      rawSubject: subject,
      rawBody: body,
    );
  }

  void completeAll() {
    _completed = true;
  }
}

/// Fake whose `render` stays pending until [complete] is called — lets a
/// test dispose the controller while the request is still in flight.
class _CompleterFakeApi implements TemplatesApi {
  final _gate = Completer<void>();

  @override
  Future<TemplatePreview> render({
    required String template,
    required String subject,
    required String body,
    String entity = '',
    String entityId = '',
  }) async {
    await _gate.future;
    return TemplatePreview(
      subject: subject,
      body: body,
      wrapper: '',
      rawSubject: subject,
      rawBody: body,
    );
  }

  void complete() {
    if (!_gate.isCompleted) _gate.complete();
  }
}
