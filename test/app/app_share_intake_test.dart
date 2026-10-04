import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/app_share_intake.dart';
import 'package:admin/app/entity_links.dart';
import 'package:admin/app/shared_file_intake.dart';

/// The platform half of sharing files into the app (invoiceninja/flutter#173):
/// it only pulls the native queue and hands it on — at start, on the native
/// ping, and on every resume.

class _RecordingIntake implements SharedFileIntake {
  final received = <List<SharedFile>>[];

  @override
  Future<void> receive(List<SharedFile> files) async => received.add(files);

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = AppShareIntake.kChannel;

  late List<List<Map<String, Object?>>> queue;
  late int takes;

  setUp(() {
    queue = [];
    takes = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'takeShares') return null;
      takes++;
      return queue.isEmpty ? <Object?>[] : queue.removeAt(0);
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<void> nativeCalls(String method) async {
    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(MethodCall(method)),
      (_) {},
    );
  }

  test('pulls once at start — the share that cold-started the app', () async {
    queue.add([
      {'path': '/x/a.pdf', 'name': 'a.pdf', 'issue': null},
    ]);
    final intake = _RecordingIntake();
    final bridge = AppShareIntake(intake, enabled: true);
    addTearDown(bridge.dispose);
    await bridge.pull(); // joins the construction pull's chain

    expect(intake.received, hasLength(1));
    expect(intake.received.single.single.name, 'a.pdf');
  });

  test('an empty queue hands nothing on', () async {
    final intake = _RecordingIntake();
    final bridge = AppShareIntake(intake, enabled: true);
    addTearDown(bridge.dispose);
    await bridge.pull();
    expect(takes, 2);
    expect(intake.received, isEmpty);
  });

  test(
    'the native sharesAvailable ping pulls a share into a running app',
    () async {
      final intake = _RecordingIntake();
      final bridge = AppShareIntake(intake, enabled: true);
      addTearDown(bridge.dispose);
      await bridge.pull();

      queue.add([
        {'path': '/x/b.jpg', 'name': 'b.jpg'},
      ]);
      await nativeCalls('sharesAvailable');
      await bridge.pull();

      expect(intake.received.single.single.name, 'b.jpg');
    },
  );

  test('every resume pulls — the iOS fallback when the extension could not '
      'open the app', () async {
    final intake = _RecordingIntake();
    final bridge = AppShareIntake(intake, enabled: true);
    addTearDown(bridge.dispose);
    await bridge.pull();

    queue.add([
      {'path': '/x/c.pdf', 'name': 'c.pdf'},
    ]);
    bridge.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await bridge.pull();

    expect(intake.received.single.single.name, 'c.pdf');
  });

  test(
    'a host with no native half (MissingPluginException) is a no-op',
    () async {
      messenger.setMockMethodCallHandler(channel, null);
      final intake = _RecordingIntake();
      final bridge = AppShareIntake(intake, enabled: true);
      addTearDown(bridge.dispose);
      await bridge.pull();
      expect(intake.received, isEmpty);
    },
  );

  test('disabled (web, desktop) never touches the channel', () async {
    final bridge = AppShareIntake(_RecordingIntake(), enabled: false);
    addTearDown(bridge.dispose);
    await bridge.pull();
    expect(takes, 0);
  });

  group('the Share Extension hand-off link', () {
    test('is recognised, in any case', () {
      expect(isShareHandoffLink(Uri.parse('invoiceninja://share')), isTrue);
      expect(isShareHandoffLink(Uri.parse('InvoiceNinja://SHARE')), isTrue);
    });

    test('is nothing else', () {
      expect(
        isShareHandoffLink(Uri.parse('invoiceninja://app/clients/abc')),
        isFalse,
      );
      expect(isShareHandoffLink(Uri.parse('https://share/app/x')), isFalse);
    });
  });
}
