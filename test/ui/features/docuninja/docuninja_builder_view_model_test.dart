import 'dart:convert';

import 'package:admin/domain/docuninja/docuninja_embed.dart';
import 'package:admin/ui/features/docuninja/view_models/docuninja_builder_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

String _msg(String type, [Map<String, dynamic> payload = const {}]) =>
    jsonEncode({
      'v': kDnEmbedProtocolVersion,
      'type': type,
      'payload': payload,
    });

/// The app's half of the embedded builder, without a web view.
void main() {
  late List<String> scripts;
  late String? url;
  late int changed;
  late int closed;
  late List<Uri> opened;
  late List<Uri> inPlace;

  DocuNinjaBuilderViewModel vm({
    String? token = 'company-token',
    Duration timeout = const Duration(seconds: 20),
  }) => DocuNinjaBuilderViewModel(
    runJavaScript: (s) async => scripts.add(s),
    currentUrl: () async => url,
    token: () => token,
    onDocumentChanged: () => changed++,
    onClose: () => closed++,
    openExternal: opened.add,
    openInPlace: (u) async => inPlace.add(u),
    readyTimeout: timeout,
  );

  setUp(() {
    scripts = [];
    url = 'https://app.invoicing.co/#/docuninja/D1/builder?embed=1';
    changed = 0;
    closed = 0;
    opened = [];
    inPlace = [];
  });

  test(
    'every ready gets the token (a reload boots again), then loaded shows it',
    () async {
      final b = vm();
      await b.handle(_msg('ready'));
      await b.handle(_msg('ready'));
      expect(scripts, hasLength(2));
      expect(scripts.first, contains('company-token'));
      expect(b.phase, DnBuilderPhase.loading);
      await b.handle(_msg('loaded'));
      expect(b.phase, DnBuilderPhase.ready);
      b.dispose();
    },
  );

  test('a page on another origin is never handed the token', () async {
    url = 'https://evil.example/#/x';
    final b = vm();
    await b.handle(_msg('ready'));
    expect(scripts, isEmpty);
    expect(b.phase, DnBuilderPhase.unavailable);
    b.dispose();
  });

  test('another protocol version is not driven', () async {
    final b = vm();
    await b.handle(
      jsonEncode({'v': 99, 'type': 'ready', 'payload': <String, dynamic>{}}),
    );
    expect(scripts, isEmpty);
    expect(b.phase, DnBuilderPhase.unavailable);
    b.dispose();
  });

  test('a page that asked is an embed, however slow the builder is', () async {
    final b = vm(timeout: const Duration(milliseconds: 10))..start();
    await b.handle(_msg('ready'));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(b.phase, DnBuilderPhase.loading);
    b.dispose();
  });

  test('a page that never asks falls back to the browser', () async {
    final b = vm(timeout: const Duration(milliseconds: 10))..start();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(b.phase, DnBuilderPhase.unavailable);
    b.dispose();
  });

  test('unsaved work follows the page; a save clears it', () async {
    final b = vm();
    await b.handle(_msg('dirty', {'dirty': true}));
    expect(b.isDirty, isTrue);
    await b.handle(_msg('saved', {'documentId': 'D1'}));
    expect(b.isDirty, isFalse);
    expect(changed, 1);
    b.dispose();
  });

  test('a send refreshes the document; mapping signatories closes', () async {
    final b = vm();
    await b.handle(_msg('sent'));
    await b.handle(_msg('mapSignatoriesSent'));
    expect(changed, 2);
    expect(closed, 1);
    b.dispose();
  });

  test(
    'the web app opens in place; other web links outside; nothing else',
    () async {
      final b = vm();
      await b.handle(
        _msg('openExternal', {'url': 'https://app.invoicing.co/x'}),
      );
      await b.handle(
        _msg('openExternal', {'url': 'https://docuninja.co/help'}),
      );
      await b.handle(_msg('openExternal', {'url': 'javascript:alert(1)'}));
      await b.handle(_msg('openExternal', {'url': 'file:///etc/passwd'}));
      expect(inPlace, [Uri.parse('https://app.invoicing.co/x')]);
      expect(opened, [Uri.parse('https://docuninja.co/help')]);
      b.dispose();
    },
  );

  test('the sign page: loaded, then signed refreshes and closes', () async {
    final b = vm();
    await b.handle(_msg('ready'));
    await b.handle(_msg('loaded'));
    expect(b.phase, DnBuilderPhase.ready);
    await b.handle(_msg('signed', {'documentId': 'D1'}));
    expect(changed, 1);
    expect(closed, 1);
    b.dispose();
  });

  test('a page that cannot sign in offers the browser', () async {
    final b = vm();
    await b.handle(_msg('ready'));
    await b.handle(_msg('error', {'status': 401}));
    expect(b.phase, DnBuilderPhase.unavailable);
    b.dispose();
  });

  test('a reload starts clean: nothing on a new boot is unsaved', () async {
    final b = vm();
    await b.handle(_msg('dirty', {'dirty': true}));
    expect(b.isDirty, isTrue);
    await b.handle(_msg('ready'));
    expect(b.isDirty, isFalse);
    b.dispose();
  });
}
