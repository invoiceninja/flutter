import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/spell_check_controller.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/ui/core/widgets/spell_check.dart';

/// The spell-check seam (docs/spell-check.md): what each platform is handed,
/// and how the desktop runner's reply becomes the spans `EditableText` draws.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseSpellCheckSpans', () {
    test('maps the runner reply, suggestions included', () {
      final spans = parseSpellCheckSpans([
        {
          'start': 0,
          'end': 3,
          'suggestions': ['the', 'tech'],
        },
      ], 10);
      expect(spans, [
        const SuggestionSpan(TextRange(start: 0, end: 3), ['the', 'tech']),
      ]);
    });

    test('sorts, and drops a span overlapping one kept before it', () {
      // macOS reports a grammar phrase and a misspelling inside it as two
      // results; `EditableText` would print the overlapped text twice.
      final spans = parseSpellCheckSpans([
        {'start': 6, 'end': 9, 'suggestions': <String>[]},
        {'start': 0, 'end': 12, 'suggestions': <String>[]},
        {'start': 14, 'end': 18, 'suggestions': <String>[]},
      ], 20);
      expect(spans.map((s) => s.range).toList(), [
        const TextRange(start: 0, end: 12),
        const TextRange(start: 14, end: 18),
      ]);
    });

    test('drops a malformed or out-of-bounds entry', () {
      final spans = parseSpellCheckSpans([
        'nonsense',
        {'start': 2, 'end': 2},
        {'start': -1, 'end': 2},
        {'start': 0, 'end': 99},
        {'start': '0', 'end': 2},
        {
          'start': 0,
          'end': 2,
          'suggestions': [1, '', 'ok'],
        },
      ], 5);
      expect(spans, [
        const SuggestionSpan(TextRange(start: 0, end: 2), ['ok']),
      ]);
    });
  });

  group('NativeSpellCheckService', () {
    const channel = MethodChannel('test/spell_check');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('sends the text and the language tag', () async {
      MethodCall? seen;
      messenger.setMockMethodCallHandler(channel, (call) async {
        seen = call;
        return [
          {
            'start': 0,
            'end': 3,
            'suggestions': ['the'],
          },
        ];
      });
      final service = NativeSpellCheckService(channel: channel);

      final spans = await service.fetchSpellCheckSuggestions(
        const Locale('en', 'GB'),
        'teh cat',
      );

      expect(seen?.method, 'check');
      expect(seen?.arguments, {'text': 'teh cat', 'language': 'en-GB'});
      expect(spans, [
        const SuggestionSpan(TextRange(start: 0, end: 3), ['the']),
      ]);
    });

    test('blank text never reaches the runner', () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (_) async {
        calls++;
        return const [];
      });
      final service = NativeSpellCheckService(channel: channel);

      expect(
        await service.fetchSpellCheckSuggestions(const Locale('en'), '  '),
        isEmpty,
      );
      expect(calls, 0);
    });

    test('an older runner with no handler latches unavailable', () async {
      final service = NativeSpellCheckService(channel: channel);

      expect(
        await service.fetchSpellCheckSuggestions(const Locale('en'), 'teh'),
        isNull,
      );
      expect(service.isUnavailable, isTrue);
    });

    test('"unavailable" latches; any other failure does not', () async {
      var code = 'boom';
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: code);
      });
      final service = NativeSpellCheckService(channel: channel);

      expect(
        await service.fetchSpellCheckSuggestions(const Locale('en'), 'teh'),
        isNull,
      );
      expect(service.isUnavailable, isFalse);

      code = 'unavailable';
      await service.fetchSpellCheckSuggestions(const Locale('en'), 'teh');
      expect(service.isUnavailable, isTrue);
    });

    // Windows: a French-only machine has no en-US dictionary, but the app in
    // French must still get one — the latch is per language.
    test('"no_dictionary" latches that language only', () async {
      final asked = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        final language = (call.arguments as Map)['language'] as String;
        asked.add(language);
        if (language == 'en') throw PlatformException(code: 'no_dictionary');
        return const [];
      });
      final service = NativeSpellCheckService(channel: channel);

      expect(
        await service.fetchSpellCheckSuggestions(const Locale('en'), 'teh'),
        isNull,
      );
      expect(
        await service.fetchSpellCheckSuggestions(const Locale('en'), 'teh'),
        isNull,
      );
      expect(asked, ['en'], reason: 'not asked again for English');
      expect(service.isUnavailable, isFalse);

      expect(
        await service.fetchSpellCheckSuggestions(const Locale('fr'), 'le'),
        isEmpty,
      );
      expect(asked, ['en', 'fr']);
    });
  });

  group('platformSpellCheckConfiguration', () {
    testWidgets('desktop gets the runner service, one instance', (
      tester,
    ) async {
      for (final platform in [TargetPlatform.macOS, TargetPlatform.windows]) {
        debugDefaultTargetPlatformOverride = platform;
        final a = platformSpellCheckConfiguration();
        final b = platformSpellCheckConfiguration();
        expect(a?.spellCheckService, same(desktopSpellCheckService));
        // `EditableText` re-checks whenever the config stops being `==`.
        expect(a, b);
      }
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('desktop stops once the runner said it cannot', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      const channel = MethodChannel('test/unavailable');
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'unavailable');
      });
      final service = NativeSpellCheckService(channel: channel);
      expect(
        platformSpellCheckConfiguration(desktopService: service),
        isNotNull,
      );

      await service.fetchSpellCheckSuggestions(const Locale('en'), 'teh');

      expect(platformSpellCheckConfiguration(desktopService: service), isNull);
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('mobile only when the engine has a service', (tester) async {
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        debugDefaultTargetPlatformOverride = platform;
        tester.platformDispatcher.nativeSpellCheckServiceDefinedTestValue =
            false;
        expect(platformSpellCheckConfiguration(), isNull);
        expect(platformSupportsSpellCheck, isFalse);

        tester.platformDispatcher.nativeSpellCheckServiceDefinedTestValue =
            true;
        final config = platformSpellCheckConfiguration();
        expect(config, isNotNull);
        // No service: Flutter infers `DefaultSpellCheckService` itself.
        expect(config!.spellCheckService, isNull);
        expect(platformSupportsSpellCheck, isTrue);
      }
      tester.platformDispatcher.clearNativeSpellCheckServiceDefined();
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('nothing on Linux', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(platformSpellCheckConfiguration(), isNull);
      expect(platformSupportsSpellCheck, isFalse);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('lineItemSpellCheck', () {
    late AppDatabase db;
    late SpellCheckController controller;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      final prefs = DevicePrefsStore(db);
      await prefs.load();
      controller = SpellCheckController(prefs: prefs);
    });
    tearDown(() => db.close());

    Future<List<SpellCheckConfiguration?>> pump(
      WidgetTester tester, {
      required bool provided,
    }) async {
      final seen = <SpellCheckConfiguration?>[];
      final probe = Builder(
        builder: (context) {
          seen.add(lineItemSpellCheck(context));
          return const SizedBox.shrink();
        },
      );
      await tester.pumpWidget(
        provided
            ? ChangeNotifierProvider<SpellCheckController>.value(
                value: controller,
                child: probe,
              )
            : probe,
      );
      return seen;
    }

    testWidgets('follows the switch, rebuilding when it flips', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final seen = await pump(tester, provided: true);
      expect(seen.single, isNotNull);

      await tester.runAsync(() => controller.set(false));
      await tester.pump();
      expect(seen, hasLength(2));
      expect(seen.last, isNull);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('LineItemSpellCheck hands it over one frame after mount', (
      tester,
    ) async {
      // `EditableText` checks only when its configuration changes or the user
      // types, so a field holding one from its first build would never check
      // a saved description.
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final seen = <SpellCheckConfiguration?>[];
      await tester.pumpWidget(
        ChangeNotifierProvider<SpellCheckController>.value(
          value: controller,
          child: LineItemSpellCheck(
            builder: (context, config) {
              seen.add(config);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(seen.single, isNull);

      await tester.pump();
      expect(seen.last, isNotNull);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('a disabled LineItemSpellCheck never arms', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final seen = <SpellCheckConfiguration?>[];
      await tester.pumpWidget(
        ChangeNotifierProvider<SpellCheckController>.value(
          value: controller,
          child: LineItemSpellCheck(
            enabled: false,
            builder: (context, config) {
              seen.add(config);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();
      expect(seen, [null]);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('off without the provider', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final seen = await pump(tester, provided: false);
      expect(seen.single, isNull);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
