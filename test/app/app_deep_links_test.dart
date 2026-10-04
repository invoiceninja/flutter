import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/app_deep_links.dart';
import 'package:admin/app/deep_link_router.dart';

/// Android's half of deep links: the OS hands them to the engine-free
/// `DeepLinkReceiverActivity`, never to MainActivity (one that reaches
/// MainActivity can start a second one — docs/deep-links.md), and this bridge
/// pulls them over `invoice_ninja/deep_links` into the same [DeepLinkRouter].

class _RecordingRouter implements DeepLinkRouter {
  final opened = <Uri>[];

  @override
  Future<void> open(Uri uri) async => opened.add(uri);

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = AppDeepLinks.kChannel;

  late List<List<String>> queue;
  late int takes;

  setUp(() {
    queue = [];
    takes = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'takeLinks') return null;
      takes++;
      return queue.isEmpty ? <String>[] : queue.removeAt(0);
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  AppDeepLinks bridge(_RecordingRouter router, {VoidCallback? onShare}) {
    final b = AppDeepLinks(
      router,
      onShareHandoff: onShare,
      pullsLinks: true,
      subscribe: false,
    );
    addTearDown(b.dispose);
    return b;
  }

  test('pulls at start — the link that cold-started the app — and routes '
      'it', () async {
    queue.add(['https://invoicing.co/app/clients/c1?company=co1']);
    final router = _RecordingRouter();
    await bridge(router).pullLinks(); // joins the construction pull

    expect(router.opened, [
      Uri.parse('https://invoicing.co/app/clients/c1?company=co1'),
    ]);
  });

  test('the native linksAvailable ping pulls a link into a running app — the '
      'calendar return included', () async {
    final router = _RecordingRouter();
    final b = bridge(router);
    await b.pullLinks();

    queue.add(['invoiceninja://calendar_connection/complete?handoff=t']);
    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(const MethodCall('linksAvailable')),
      (_) {},
    );
    await b.pullLinks();

    expect(router.opened.single.host, 'calendar_connection');
  });

  test('a resume pulls too; an empty queue routes nothing', () async {
    final router = _RecordingRouter();
    final b = bridge(router);
    await b.pullLinks();
    b.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await b.pullLinks();
    expect(takes, greaterThanOrEqualTo(3));
    expect(router.opened, isEmpty);
  });

  test('the share hand-off link still means "files are waiting"', () async {
    queue.add(['invoiceninja://share']);
    final router = _RecordingRouter();
    var shares = 0;
    await bridge(router, onShare: () => shares++).pullLinks();
    expect(shares, 1);
    expect(router.opened, isEmpty);
  });

  test('off everywhere but Android — nothing is pulled', () async {
    final router = _RecordingRouter();
    final b = AppDeepLinks(router, pullsLinks: false, subscribe: false);
    addTearDown(b.dispose);
    await b.pullLinks();
    expect(takes, 0);
  });
}
