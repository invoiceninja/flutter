import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/spell_check_controller.dart';

/// How many suggestions a right-click offers — the same cap Flutter's own
/// mobile suggestions toolbar uses.
const int _kMaxSuggestions = 3;

/// Builds a line item's name or description field with the spell-check
/// configuration it should have (docs/spell-check.md).
///
/// Pass the configuration to `TextField.spellCheckConfiguration`, and
/// [spellCheckContextMenuBuilder] as the field's `contextMenuBuilder`.
///
/// The configuration arrives one frame after mount, on purpose.
/// `EditableText` checks only when its configuration changes or the user
/// types, never at mount, so a field that started with one would leave a
/// saved description unchecked until someone edited it.
class LineItemSpellCheck extends StatefulWidget {
  const LineItemSpellCheck({
    super.key,
    required this.builder,
    this.enabled = true,
  });

  final Widget Function(BuildContext context, SpellCheckConfiguration? config)
  builder;

  /// False hands the builder null (a custom-field cell). Fixed for the
  /// widget's life.
  final bool enabled;

  @override
  State<LineItemSpellCheck> createState() => _LineItemSpellCheckState();
}

class _LineItemSpellCheckState extends State<LineItemSpellCheck> {
  bool _armed = false;

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _armed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.builder(context, null);
    // Watched even while unarmed, so the switch rebuilds this from the start.
    final config = lineItemSpellCheck(context);
    return widget.builder(context, _armed ? config : null);
  }
}

/// The spell-check configuration the line-item fields use, or null (Flutter's
/// "off") where there is nothing to check with. Reach it through
/// [LineItemSpellCheck]; a field handed it directly from its first build
/// never checks its seeded text.
///
/// It watches [SpellCheckController], so the caller rebuilds when the Device
/// Settings switch flips. Without that provider (a widget test) it is off.
///
/// Never hand a field a bare `SpellCheckConfiguration()` instead: on a
/// platform with no service Flutter reports an error in debug and draws
/// nothing.
SpellCheckConfiguration? lineItemSpellCheck(BuildContext context) {
  final controller = context.watch<SpellCheckController?>();
  if (controller == null || !controller.value) return null;
  return platformSpellCheckConfiguration();
}

/// The runner-backed service macOS and Windows check with. One instance for
/// the app, because `EditableText` re-runs its check whenever the
/// configuration it is handed stops being `==` to the last one — and that
/// compares the service.
final NativeSpellCheckService desktopSpellCheckService =
    NativeSpellCheckService();

/// What this platform can check with, ignoring the preference.
///
/// - iOS / Android: Flutter's own `DefaultSpellCheckService`, inferred from a
///   configuration with no service — but only when the engine says the
///   platform has one, which is never the case under `flutter test`.
/// - macOS / Windows: [desktopSpellCheckService], until the runner has said
///   it can't (an older runner, or no checker for the language).
/// - Linux and web: nothing. Web draws the text itself, so the browser's own
///   underline can never show.
@visibleForTesting
SpellCheckConfiguration? platformSpellCheckConfiguration({
  NativeSpellCheckService? desktopService,
}) {
  if (kIsWeb) return null;
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.android:
      return WidgetsBinding
              .instance
              .platformDispatcher
              .nativeSpellCheckServiceDefined
          ? const SpellCheckConfiguration()
          : null;
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      final service = desktopService ?? desktopSpellCheckService;
      if (service.isUnavailable) return null;
      return SpellCheckConfiguration(spellCheckService: service);
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      return null;
  }
}

/// Whether this platform can underline at all — gates the Device Settings
/// switch, which would otherwise toggle nothing.
bool get platformSupportsSpellCheck {
  if (kIsWeb) return false;
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.android =>
      WidgetsBinding.instance.platformDispatcher.nativeSpellCheckServiceDefined,
    TargetPlatform.macOS || TargetPlatform.windows => true,
    TargetPlatform.linux || TargetPlatform.fuchsia => false,
  };
}

/// A [SpellCheckService] answered by the desktop runner over
/// `invoice_ninja/spell_check`: NSSpellChecker on macOS (spelling and
/// grammar), ISpellChecker on Windows (spelling).
///
/// The runner replies `[{start, end, suggestions}]` in UTF-16 code units,
/// which is what a Dart string indexes in.
class NativeSpellCheckService implements SpellCheckService {
  NativeSpellCheckService({
    MethodChannel channel = const MethodChannel('invoice_ninja/spell_check'),
  }) : _channel = channel;

  final MethodChannel _channel;

  /// Latched once the runner has no handler, or says it has no checker:
  /// [platformSpellCheckConfiguration] then stops handing the service out,
  /// rather than asking on every keystroke for the rest of the session.
  bool get isUnavailable => _unavailable;
  bool _unavailable = false;

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(
    Locale locale,
    String text,
  ) async {
    if (_unavailable) return null;
    if (text.trim().isEmpty) return const [];
    try {
      final raw = await _channel.invokeListMethod<Object?>('check', {
        'text': text,
        'language': locale.toLanguageTag(),
      });
      return parseSpellCheckSpans(raw ?? const [], text.length);
    } on MissingPluginException {
      _unavailable = true;
      return null;
    } on PlatformException catch (e) {
      if (e.code == 'unavailable') _unavailable = true;
      // Null tells `EditableText` the request came to nothing, so it keeps
      // whatever it showed before.
      return null;
    }
  }
}

/// The runner's reply as the sorted, non-overlapping spans `EditableText`
/// requires — it walks them in order and would print an overlapped stretch of
/// text twice. macOS reports a grammar phrase and a misspelling inside it as
/// two results; the one that starts first (the shorter on a tie) wins.
@visibleForTesting
List<SuggestionSpan> parseSpellCheckSpans(List<Object?> raw, int textLength) {
  final spans = <SuggestionSpan>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final start = entry['start'];
    final end = entry['end'];
    if (start is! int || end is! int) continue;
    if (start < 0 || end <= start || end > textLength) continue;
    final suggestions = entry['suggestions'];
    spans.add(
      SuggestionSpan(TextRange(start: start, end: end), [
        if (suggestions is List)
          for (final s in suggestions)
            if (s is String && s.isNotEmpty) s,
      ]),
    );
  }
  spans.sort((a, b) {
    final byStart = a.range.start.compareTo(b.range.start);
    return byStart != 0 ? byStart : a.range.end.compareTo(b.range.end);
  });
  final kept = <SuggestionSpan>[];
  for (final span in spans) {
    if (kept.isNotEmpty && span.range.start < kept.last.range.end) continue;
    kept.add(span);
  }
  return kept;
}

/// The field's context menu, led by the suggestions for the word under the
/// caret on macOS and Windows.
///
/// Flutter shows its suggestions toolbar only for a tap on iOS and Android,
/// so on the desktop an underline would otherwise have no fix. Everywhere
/// else — and on a word that isn't flagged — this is exactly the default
/// menu, so passing it costs a field nothing.
Widget spellCheckContextMenuBuilder(
  BuildContext context,
  EditableTextState editableTextState,
) {
  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors: editableTextState.contextMenuAnchors,
    buttonItems: [
      ...spellCheckSuggestionItems(editableTextState),
      ...editableTextState.contextMenuButtonItems,
    ],
  );
}

/// One button per suggestion for the flagged word under the caret — empty
/// off the desktop, with spell check off, or away from a flagged word.
@visibleForTesting
List<ContextMenuButtonItem> spellCheckSuggestionItems(
  EditableTextState editableTextState,
) {
  if (kIsWeb) return const [];
  if (defaultTargetPlatform != TargetPlatform.macOS &&
      defaultTargetPlatform != TargetPlatform.windows) {
    return const [];
  }
  if (!editableTextState.spellCheckEnabled ||
      editableTextState.widget.readOnly) {
    return const [];
  }
  final span = editableTextState.findSuggestionSpanAtCursorIndex(
    editableTextState.currentTextEditingValue.selection.baseOffset,
  );
  if (span == null) return const [];
  return [
    for (final suggestion in span.suggestions.take(_kMaxSuggestions))
      ContextMenuButtonItem(
        label: suggestion,
        onPressed: () {
          if (!editableTextState.mounted) return;
          // Through `userUpdateTextEditingValue`, so the field's `onChanged`
          // fires and the row's view model sees the correction.
          editableTextState.userUpdateTextEditingValue(
            editableTextState.textEditingValue.replaced(span.range, suggestion),
            SelectionChangedCause.toolbar,
          );
          editableTextState.hideToolbar();
        },
      ),
  ];
}
