import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/domain/email_template_variables.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/picker_dismissal.dart';
import 'package:admin/ui/core/widgets/template_variables/template_variable_chip.dart';
import 'package:admin/ui/core/widgets/template_variables/template_variable_picker.dart';
import 'package:admin/ui/core/widgets/template_variables/template_variable_text_controller.dart';

/// Builds the owner's own `TextField` for edit mode, with the shell's composed
/// [decoration] and the tap-outside handler it must wire.
typedef TemplateVariableFieldBuilder =
    Widget Function(
      BuildContext context,
      InputDecoration decoration,
      TapRegionCallback onTapOutside,
    );

/// A single-line template field that shows its `$variables` as chips at rest
/// and as raw, tinted text while being edited (invoiceninja/flutter#139) —
/// the Templates & Reminders subject and the Send Email subject.
///
/// **Why two modes.** A chip `WidgetSpan` standing in for a 13-character token
/// breaks `EditableText`'s 1:1 text↔layout offset mapping, so a field can't
/// both hold chips and be edited as text. The rest view is therefore a
/// read-only `Text.rich` in an `InputDecorator` built exactly as `TextField`
/// builds its own; tapping a chip opens [showTemplateVariablePicker], tapping
/// the text swaps in the owner's untouched `TextField` with the caret at the
/// tapped character. The owner's field is used as-is, so Enter-to-save, the
/// error line, autocorrect and the suffix buttons all keep working.
///
/// **Blur** is focus leaving the whole shell (a `Focus` around it), not the
/// text field alone — Tabbing from the text into its own suffix button must
/// not swap the view and unmount the button that just took focus. On touch
/// an outside tap never unfocuses a field on its own, so the owner wires
/// the supplied tap-outside handler (`dismissPickerOnTapOutside`), or the
/// field would be stuck showing raw tokens.
///
/// **Default state.** With [defaultText] and an empty value, the rest view
/// shows the default template muted, with a caption. Chip edits and typing
/// work on a copy of it; the owner treats text equal to the default as "still
/// the default" and writes nothing, so looking is free and the first real edit
/// is what creates a custom template.
///
/// Edits made through a chip or the Insert button are programmatic, so they
/// don't fire the `TextField`'s `onChanged` — they are reported through
/// [onEdited] instead. Change and Remove offer an Undo toast.
class TemplateVariableFieldShell extends StatefulWidget {
  const TemplateVariableFieldShell({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.decoration,
    required this.onEdited,
    required this.fieldBuilder,
    this.enabled = true,
    this.interactive = true,
    this.values,
    this.defaultText,
    this.showDefaultCaption = true,
    this.showInsertButton = true,
    this.forSubject = true,
    this.style,
  });

  final TemplateVariableTextController controller;

  /// The owner's text field focus node — focused when edit mode begins.
  final FocusNode focusNode;

  /// The owner's decoration. The shell adds the Insert button to its suffix
  /// and the default-template caption to its helper line.
  final InputDecoration decoration;

  /// Reports text changed by a chip, the picker, or Undo.
  final ValueChanged<String> onEdited;

  final TemplateVariableFieldBuilder fieldBuilder;

  /// Visual enabled state (a disabled rest view renders dimmed and inert).
  final bool enabled;

  /// False for an inherited settings value at group/client scope: rendered
  /// normally but inert — no edit mode, no picker, and not focusable (an
  /// `IgnorePointer` around it doesn't stop Tab).
  final bool interactive;

  /// The document's values, per token (the Send Email probe).
  final ValueListenable<Map<String, TemplateVariableValue>>? values;

  /// The template the server uses when the field is empty.
  final String? defaultText;

  /// Whether the "showing the default" caption renders under the field. False
  /// where the host says it once for a group of fields — the Send Email
  /// composer captions its body and lets that cover the subject above it,
  /// rather than printing the same two wrapped lines twice on a phone.
  final bool showDefaultCaption;

  /// A suffix Insert button. The Send Email composer puts its own in the
  /// label row instead and calls [TemplateVariableFieldShellState.insertVariable].
  final bool showInsertButton;

  /// Hide variables whose value is HTML from the picker.
  final bool forSubject;

  /// The owner field's text style, so the rest view sets text identically.
  final TextStyle? style;

  @override
  State<TemplateVariableFieldShell> createState() =>
      TemplateVariableFieldShellState();
}

class TemplateVariableFieldShellState
    extends State<TemplateVariableFieldShell> {
  bool _editing = false;

  /// True between asking for edit mode and the text field taking focus: the
  /// rest view's focus node leaves the tree in that window, and a focus-loss
  /// report from it must not bounce the shell straight back to rest.
  bool _entering = false;

  final _restFocus = FocusNode(debugLabel: 'TemplateVariableFieldShell rest');
  final _paragraphKey = GlobalKey();

  /// Rendered-offset ↔ raw-offset table for the rest view (a chip renders as
  /// one placeholder character but stands for a whole token).
  List<_Segment> _segments = const [];

  TemplateVariableScope get _scope => widget.controller.scope;

  bool get _hasDefault => (widget.defaultText ?? '').isNotEmpty;

  /// The field is showing the default template: empty, or (while a seeded
  /// copy is being edited) still identical to it.
  bool get _showingDefault {
    final text = widget.controller.text;
    return _hasDefault && (text.isEmpty || text == widget.defaultText);
  }

  bool get _live => widget.enabled && widget.interactive;

  String _currentSource() => widget.controller.text.isEmpty && _hasDefault
      ? widget.defaultText!
      : widget.controller.text;

  Map<String, TemplateVariableValue> get _values =>
      widget.values?.value ?? const <String, TemplateVariableValue>{};

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFieldFocus);
  }

  @override
  void didUpdateWidget(TemplateVariableFieldShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFieldFocus);
      widget.focusNode.addListener(_onFieldFocus);
    }
    if (!_live && _editing) _editing = false;
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFieldFocus);
    _restFocus.dispose();
    super.dispose();
  }

  void _onFieldFocus() {
    if (widget.focusNode.hasFocus) _entering = false;
  }

  void _onShellFocusChange(bool hasFocus) {
    if (hasFocus || !_editing || _entering) return;
    setState(() => _editing = false);
  }

  void _enterEditing({int? caret}) {
    if (!_live) return;
    final controller = widget.controller;
    if (controller.text.isEmpty && _hasDefault) {
      // Edit a copy of the default. Not an edit yet: the owner writes nothing
      // until the text differs from it.
      final text = widget.defaultText!;
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(
          offset: (caret ?? text.length).clamp(0, text.length),
        ),
      );
    } else {
      final length = controller.text.length;
      controller.selection = TextSelection.collapsed(
        offset: (caret ?? length).clamp(0, length),
      );
    }
    if (_editing) {
      widget.focusNode.requestFocus();
      return;
    }
    _entering = true;
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.focusNode.requestFocus();
      // Whether or not focus arrives, the transition is over next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _entering = false);
    });
  }

  void _onRestTapUp(TapUpDetails details) {
    int? caret;
    final paragraph = _paragraphKey.currentContext?.findRenderObject();
    if (paragraph is RenderParagraph && paragraph.attached) {
      final local = paragraph.globalToLocal(details.globalPosition);
      caret = _rawOffsetFor(paragraph.getPositionForOffset(local).offset);
    }
    _enterEditing(caret: caret);
  }

  int _rawOffsetFor(int rendered) {
    for (final s in _segments) {
      final isLast = identical(s, _segments.last);
      if (rendered < s.renderedStart + s.renderedLength || isLast) {
        if (s.chip) {
          return rendered <= s.renderedStart
              ? s.rawStart
              : s.rawStart + s.rawLength;
        }
        return s.rawStart + (rendered - s.renderedStart).clamp(0, s.rawLength);
      }
    }
    return _currentSource().length;
  }

  /// Open the picker to change or remove the chip for [match] in [source].
  Future<void> _changeChip(TemplateVariableMatch match, String source) async {
    if (!_live) return;
    final pick = await showTemplateVariablePicker(
      context,
      scope: _scope,
      currentToken: match.token,
      forSubject: widget.forSubject,
      values: _values,
    );
    if (pick == null || !mounted) return;
    // The text may have changed while the picker was up; the chip must
    // still be where it was tapped.
    final now = _currentSource();
    if (now != source ||
        match.end > now.length ||
        now.substring(match.start, match.end) != match.token) {
      return;
    }
    final (text, caret) = switch (pick) {
      TemplateVariablePicked(:final token) => _replaced(now, match, token),
      TemplateVariableRemoved() => _removed(now, match),
    };
    _commit(
      text,
      caret,
      undoMessageKey: pick is TemplateVariableRemoved ? 'removed' : 'updated',
    );
  }

  /// Open the picker and insert its choice — at the caret while editing,
  /// appended otherwise. Public for hosts that place the button themselves.
  Future<void> insertVariable() async {
    if (!_live) return;
    final wasEditing = _editing && widget.focusNode.hasFocus;
    final source = _currentSource();
    final selection = widget.controller.selection;
    final pick = await showTemplateVariablePicker(
      context,
      scope: _scope,
      forSubject: widget.forSubject,
      values: _values,
    );
    if (pick is! TemplateVariablePicked || !mounted) return;
    if (_currentSource() != source) return;
    final atCaret =
        wasEditing && selection.isValid && selection.end <= source.length;
    final start = atCaret ? selection.start : source.length;
    final end = atCaret ? selection.end : source.length;
    final before = start > 0 ? source[start - 1] : '';
    final after = end < source.length ? source[end] : '';
    // Appending gets a space from the text before it; at the caret the
    // user put the caret exactly where they want the token.
    final lead = !atCaret && before.trim().isNotEmpty ? ' ' : '';
    final trail = _continuesToken(after) ? ' ' : '';
    final insert = '$lead${pick.token}$trail';
    final text = source.replaceRange(start, end, insert);
    final caret = start + insert.length;
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret),
    );
    widget.onEdited(text);
    if (wasEditing) _enterEditing(caret: caret);
  }

  /// Alt+↓: change the token at the caret, or insert one.
  void _pickAtCaret() {
    if (!_live) return;
    final text = _currentSource();
    final caret = widget.controller.selection.baseOffset;
    for (final m in findTemplateVariables(text)) {
      if (caret >= m.start &&
          caret <= m.end &&
          lookupTemplateVariable(m.token, _scope) != null) {
        _changeChip(m, text);
        return;
      }
    }
    insertVariable();
  }

  (String, int) _replaced(String s, TemplateVariableMatch m, String token) {
    final after = m.end < s.length ? s[m.end] : '';
    final insert = '$token${_continuesToken(after) ? ' ' : ''}';
    return (s.replaceRange(m.start, m.end, insert), m.start + insert.length);
  }

  (String, int) _removed(String s, TemplateVariableMatch m) {
    var start = m.start;
    // Don't leave a double space where the chip was.
    if (start > 0 &&
        s[start - 1] == ' ' &&
        (m.end >= s.length || s[m.end] == ' ')) {
      start--;
    }
    return (s.replaceRange(start, m.end, ''), start);
  }

  static bool _continuesToken(String char) =>
      char.isNotEmpty && RegExp(r'[A-Za-z0-9_]').hasMatch(char);

  void _commit(String text, int caret, {required String undoMessageKey}) {
    final previous = widget.controller.value;
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret),
    );
    widget.onEdited(text);
    Notify.info(
      context,
      context.tr(undoMessageKey),
      action: NotifyAction(context.tr('undo'), () {
        if (!mounted) return;
        widget.controller.value = previous;
        widget.onEdited(previous.text);
      }),
    );
  }

  InputDecoration _decoration(BuildContext context) {
    final base = widget.decoration;
    final insert = widget.showInsertButton && _live
        ? IconButton(
            icon: const Icon(Icons.add),
            tooltip: context.tr('insert_variable'),
            onPressed: insertVariable,
          )
        : null;
    final suffix = base.suffixIcon;
    return base.copyWith(
      suffixIcon: insert == null
          ? suffix
          : suffix == null
          ? insert
          : Row(mainAxisSize: MainAxisSize.min, children: [insert, suffix]),
      helperText: _showingDefault && widget.showDefaultCaption
          ? context.tr('default_template_caption')
          : base.helperText,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: _onShellFocusChange,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowDown, alt: true):
              _pickAtCaret,
        },
        child: ListenableBuilder(
          listenable: Listenable.merge([
            widget.controller,
            if (widget.values != null) widget.values!,
          ]),
          builder: (context, _) {
            final decoration = _decoration(context);
            if (_editing && _live) {
              return widget.fieldBuilder(
                context,
                decoration,
                dismissPickerOnTapOutside(widget.focusNode),
              );
            }
            return _restView(context, decoration);
          },
        ),
      ),
    );
  }

  Widget _restView(BuildContext context, InputDecoration decoration) {
    final theme = Theme.of(context);
    final t = context.inTheme;
    final showingDefault = _showingDefault;
    final source = _currentSource();
    final bodyLarge = theme.textTheme.bodyLarge ?? const TextStyle();
    var baseStyle = bodyLarge.merge(widget.style);
    if (!widget.enabled) {
      baseStyle = baseStyle.copyWith(
        color: bodyLarge.color?.withValues(alpha: 0.38),
      );
    } else if (showingDefault) {
      baseStyle = baseStyle.copyWith(color: t.ink2);
    }
    final (spans, spoken) = _buildSpans(context, source, muted: showingDefault);
    final effective = decoration
        .applyDefaults(InputDecorationTheme.of(context))
        .copyWith(
          enabled: widget.enabled,
          hintMaxLines: decoration.hintMaxLines ?? 1,
        );
    final view = InputDecorator(
      decoration: effective,
      baseStyle: baseStyle,
      isEmpty: source.isEmpty,
      child: Text.rich(
        TextSpan(children: spans),
        key: _paragraphKey,
        style: baseStyle,
      ),
    );
    if (!_live) return ExcludeFocus(child: view);
    return Semantics(
      container: true,
      textField: true,
      label: decoration.labelText,
      value: spoken,
      onTap: _enterEditing,
      child: Focus(
        focusNode: _restFocus,
        onFocusChange: (focused) {
          if (focused) _enterEditing();
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.text,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: _onRestTapUp,
            child: view,
          ),
        ),
      ),
    );
  }

  /// The rest view's spans, and what a screen reader should read for them
  /// (friendly labels in place of raw tokens).
  (List<InlineSpan>, String) _buildSpans(
    BuildContext context,
    String source, {
    required bool muted,
  }) {
    final spans = <InlineSpan>[];
    final segments = <_Segment>[];
    final spoken = StringBuffer();
    var cursor = 0;
    var rendered = 0;
    void plain(int end) {
      if (end <= cursor) return;
      final text = source.substring(cursor, end);
      spans.add(TextSpan(text: text));
      spoken.write(text);
      segments.add(_Segment(rendered, cursor, end - cursor, chip: false));
      rendered += end - cursor;
    }

    final values = _values;
    for (final m in findTemplateVariables(source)) {
      final display = describeTemplateVariable(
        context,
        m.token,
        _scope,
        value: values[m.token],
      );
      if (display == null) continue;
      plain(m.start);
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _ChipButton(
            display: display,
            muted: muted,
            enabled: _live,
            onTap: () => _changeChip(m, source),
          ),
        ),
      );
      spoken.write(display.label);
      segments.add(_Segment(rendered, m.start, m.end - m.start, chip: true));
      rendered += 1;
      cursor = m.end;
    }
    plain(source.length);
    _segments = segments;
    return (spans, spoken.toString());
  }
}

class _Segment {
  const _Segment(
    this.renderedStart,
    this.rawStart,
    this.rawLength, {
    required this.chip,
  });

  final int renderedStart;
  final int rawStart;
  final int rawLength;
  final bool chip;

  int get renderedLength => chip ? 1 : rawLength;
}

/// A rest-view chip as a button: the fill on a local `Material` so the ripple
/// shows (the `Ink`-ban idiom), a hit area a little taller than the chip on
/// touch, and one button node for screen readers.
class _ChipButton extends StatelessWidget {
  const _ChipButton({
    required this.display,
    required this.muted,
    required this.enabled,
    required this.onTap,
  });

  final TemplateVariableDisplay display;
  final bool muted;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return TemplateVariableChip(display: display, muted: muted);
    }
    final t = context.inTheme;
    final radius = BorderRadius.circular(InRadii.r1);
    final second =
        display.warning ??
        switch (display.value) {
          null => null,
          '' => context.tr('empty'),
          final value => value,
        };
    final label = [
      display.label,
      ?second,
      context.tr('change_variable'),
    ].join(', ');
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        // The padding around the chip is part of its hit area.
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: Env.isTouchPrimary ? 2 : 0),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Material(
              color: templateVariableChipFill(t, display),
              shape: RoundedRectangleBorder(borderRadius: radius),
              child: InkWell(
                onTap: onTap,
                borderRadius: radius,
                canRequestFocus: false,
                child: TemplateVariableChip(
                  display: display,
                  muted: muted,
                  editable: true,
                  showTooltip: true,
                  fill: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
