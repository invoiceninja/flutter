import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/static/design_template_completions.dart';

/// Syntax-highlighting HTML editor for one custom-design template section
/// (body / header / footer / includes / product / task). Wraps `re_editor`
/// with a line-number gutter, an atom-one theme keyed to the active
/// brightness, and a custom autocomplete overlay covering:
///
/// - **Designs** ([isTemplate] = false): `$tokens` (`$client.name`,
///   `$invoice.balance`, …) trigger on typing `$`.
/// - **Templates** ([isTemplate] = true): `$tokens` work everywhere; Twig
///   (`{{ }}` / `{% %}`) completions activate only inside
///   `<ninja>...</ninja>` blocks per the Templates docs page.
///
/// Designs are raw HTML (with `$placeholder` / Twig fragments), so the
/// `xml` grammar is used — it covers HTML markup. This is a multi-line
/// code surface: Enter inserts a newline and it is deliberately **not**
/// wired to `FormSaveScope` (per CLAUDE.md Forms rule).
///
/// One-way seeding: the parent owns the string and feeds [initial] +
/// [seedRevision]. A bump of [seedRevision] (Start-from / Blank / Import
/// / Discard replacing the whole template) reseeds the controller;
/// ordinary keystrokes do not, so the cursor isn't yanked while typing.
class DesignCodeField extends StatefulWidget {
  const DesignCodeField({
    super.key,
    required this.initial,
    required this.seedRevision,
    required this.isTemplate,
    required this.onChanged,
    this.insertController,
    this.caretToNinjaOnSeed = false,
  });

  final String initial;
  final int seedRevision;

  /// Drives the autocomplete catalog: design mode (`$tokens` only) vs.
  /// template mode (Twig inside `<ninja>` blocks + `$tokens` anywhere).
  final bool isTemplate;

  final ValueChanged<String> onChanged;

  /// Optional hook the workspace uses to insert a `$variable` at the caret
  /// from the Variables pane. Assigned the controller once mounted.
  final ValueChanged<CodeLineEditingController>? insertController;

  /// On the next [seedRevision] bump, place the caret inside the first
  /// `<ninja>` block of [initial] instead of resetting to line 0 col 0.
  /// Used by the body section after `setIsTemplate(true)` seeds the
  /// blank Twig scaffold so the user can start typing inside `<ninja>`
  /// immediately.
  final bool caretToNinjaOnSeed;

  @override
  State<DesignCodeField> createState() => _DesignCodeFieldState();
}

class _DesignCodeFieldState extends State<DesignCodeField> {
  late final CodeLineEditingController _controller =
      CodeLineEditingController.fromText(widget.initial);

  late _DesignCompletionsBuilder _completions = _DesignCompletionsBuilder(
    isTemplate: widget.isTemplate,
    controller: _controller,
  );

  /// True while a programmatic reseed is assigning `_controller.text`.
  /// `re_editor` fires `onChanged` synchronously from that setter; echoing
  /// it back to `widget.onChanged` during `didUpdateWidget` would call the
  /// parent VM's `notifyListeners()` mid-build. The parent already owns the
  /// reseeded string (it bumped `seedRevision`), so the echo is redundant.
  bool _suppressOnChanged = false;

  @override
  void initState() {
    super.initState();
    widget.insertController?.call(_controller);
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
  }

  /// Esc → dismiss any open autocomplete overlay. We mark the builder
  /// dismissed (so the next `build()` returns null) and jiggle the
  /// selection to force re_editor's `show()` to re-run synchronously.
  /// The builder's text-snapshot keeps the overlay closed until the
  /// user actually edits the buffer, so a normal trigger keystroke
  /// (e.g. typing `$`) can re-open it. Returns false to let the event
  /// keep propagating — re_editor's own Esc handler still cancels any
  /// active text selection.
  bool _onHardwareKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _completions.requestDismiss();
      _jiggleSelection();
    }
    return false;
  }

  /// Briefly move the caret one column then back so re_editor's value
  /// listener fires and re-evaluates the autocomplete. Two synchronous
  /// selection writes happen between paint frames, so no cursor flash.
  void _jiggleSelection() {
    final lines = _controller.codeLines;
    final s = _controller.selection;
    if (s.extentIndex >= lines.length) return;
    final lineLen = lines[s.extentIndex].text.length;
    final altOffset = s.extentOffset == 0
        ? (lineLen > 0 ? 1 : 0)
        : s.extentOffset - 1;
    if (altOffset == s.extentOffset) return;
    _controller.selection = CodeLineSelection.collapsed(
      index: s.extentIndex,
      offset: altOffset,
    );
    _controller.selection = s;
  }

  @override
  void didUpdateWidget(DesignCodeField old) {
    super.didUpdateWidget(old);
    // Whole-template replacement (Start-from / Blank / Import / Discard).
    // Reseed unconditionally on a seedRevision bump: even when the new text
    // coincidentally equals the current buffer, reassigning resets the
    // caret/scroll to the freshly-seeded template (and is otherwise a no-op).
    if (old.seedRevision != widget.seedRevision) {
      _suppressOnChanged = true;
      _controller.text = widget.initial;
      if (widget.caretToNinjaOnSeed) {
        _placeCaretInsideFirstNinja();
      }
      _suppressOnChanged = false;
    }
    if (old.isTemplate != widget.isTemplate) {
      _completions = _DesignCompletionsBuilder(
        isTemplate: widget.isTemplate,
        controller: _controller,
      );
    }
    if (!identical(old.insertController, widget.insertController)) {
      widget.insertController?.call(_controller);
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _controller.dispose();
    super.dispose();
  }

  /// After a fresh seed, drop the caret on the empty line inside the
  /// first `<ninja>...</ninja>` block — that's the spot the user wants
  /// to type Twig into. No-op if the seeded text has no `<ninja>`.
  void _placeCaretInsideFirstNinja() {
    final text = widget.initial;
    final idx = text.indexOf('<ninja>');
    if (idx < 0) return;
    // Step past `<ninja>` and the following newline (if any) so the
    // caret lands on the next line, ready for a Twig expression.
    var caretOffset = idx + '<ninja>'.length;
    if (caretOffset < text.length && text[caretOffset] == '\n') {
      caretOffset++;
    }
    final lineIndex = '\n'.allMatches(text.substring(0, caretOffset)).length;
    _controller.selection = CodeLineSelection.collapsed(
      index: lineIndex,
      offset: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(InRadii.r2),
        color: tokens.surface,
      ),
      clipBehavior: Clip.antiAlias,
      child: CodeAutocomplete(
        viewBuilder: (context, notifier, onSelected) {
          return _OverlayView(notifier: notifier, onSelected: onSelected);
        },
        promptsBuilder: _completions,
        child: CodeEditor(
          controller: _controller,
          wordWrap: false,
          onChanged: (_) {
            if (_suppressOnChanged) return;
            widget.onChanged(_controller.text);
          },
          padding: EdgeInsets.all(InSpacing.sm),
          style: CodeEditorStyle(
            fontSize: 12,
            fontFamily: kMonoFontFamily,
            codeTheme: CodeHighlightTheme(
              languages: {'xml': CodeHighlightThemeMode(mode: langXml)},
              theme: dark ? atomOneDarkTheme : atomOneLightTheme,
            ),
          ),
          indicatorBuilder:
              (context, editingController, chunkController, notifier) {
                return DefaultCodeLineNumber(
                  controller: editingController,
                  notifier: notifier,
                );
              },
        ),
      ),
    );
  }
}

// =============================================================================
// Prompts builder
// =============================================================================

enum _PromptKind {
  dollar,
  twigRoot,
  twigField,
  twigTag,
  twigFunction,
  twigFilter,
  elementId,
  snippet,
}

class _CompletionItem extends CodePrompt {
  _CompletionItem({
    required super.word,
    required this.kind,
    required this.label,
  });

  /// Visual category shown as the trailing dim label.
  final String label;
  final _PromptKind kind;

  /// Filtering is done in the builder, so always match — re_editor's
  /// own match-filter step is a no-op when we hand back a pre-filtered list.
  @override
  bool match(String input) => true;

  @override
  CodeAutocompleteResult get autocomplete =>
      CodeAutocompleteResult.fromWord(word);
}

/// Completion that inserts a snippet and places the caret at an
/// arbitrary offset inside the inserted text — used by the `<ninja>`
/// wrap completion. Extends [_CompletionItem] so the overlay row
/// rendering treats it the same as a normal prompt; only the
/// `autocomplete` getter differs (custom selection offset rather than
/// landing the cursor at end-of-word). Single-line only: re_editor
/// treats the result's selection offset as a column delta on the
/// current line, so multi-line snippets via `\n` would land the cursor
/// on the wrong line.
class _SnippetCompletion extends _CompletionItem {
  _SnippetCompletion({
    required super.word,
    required this.caretOffset,
    required super.label,
    required super.kind,
  });

  /// Where in [word] the caret lands after insertion (0..word.length).
  final int caretOffset;

  @override
  CodeAutocompleteResult get autocomplete => CodeAutocompleteResult(
    input: '',
    word: word,
    selection: TextSelection.collapsed(offset: caretOffset),
  );
}

class _DesignCompletionsBuilder implements CodeAutocompletePromptsBuilder {
  _DesignCompletionsBuilder({
    required this.isTemplate,
    required this.controller,
  });

  final bool isTemplate;
  final CodeLineEditingController controller;

  /// Suppress flag flipped by Esc. We snapshot the controller text at
  /// the same moment; while text matches the snapshot, `build()` keeps
  /// returning null (so the selection-jiggle that follows the Esc press
  /// doesn't re-open the overlay). The first actual edit clears the
  /// flag and normal completion resumes.
  bool _dismissed = false;
  String _dismissedAtText = '';

  void requestDismiss() {
    _dismissed = true;
    _dismissedAtText = controller.text;
  }

  @override
  CodeAutocompleteEditingValue? build(
    BuildContext context,
    CodeLine codeLine,
    CodeLineSelection selection,
  ) {
    if (_dismissed) {
      if (controller.text == _dismissedAtText) return null;
      _dismissed = false;
    }
    final lineText = codeLine.text;
    final col = selection.extentOffset;
    if (col < 0 || col > lineText.length) return null;
    final before = lineText.substring(0, col);

    // Element-ID completion inside `<elem id="…">` (both modes). Wins
    // over $token / Twig because the `id="…` context is more specific.
    final eid = _buildElementId(before);
    if (eid != null) return eid;

    // Template mode + caret outside <ninja>: offer the ninja-wrap snippet
    // when typing `<ni…`. Inside-ninja Twig completions are handled below.
    final inNinja = isTemplate && _isInNinja(selection);
    if (isTemplate && !inNinja) {
      final wrap = _buildNinjaWrapSnippet(before);
      if (wrap != null) return wrap;
    }

    // Twig completions (template mode, inside <ninja>, inside {{ }} / {% %}).
    if (inNinja) {
      final v = _buildTwig(before);
      if (v != null) return v;
    }

    // $-token completions — work in both modes.
    final v = _buildDollar(before);
    if (v != null) return v;

    return null;
  }

  // ---- element-id detection ------------------------------------------------

  CodeAutocompleteEditingValue? _buildElementId(String before) {
    final m = RegExp(r'''\bid\s*=\s*["']([\w-]*)$''').firstMatch(before);
    if (m == null) return null;
    final input = m.group(1) ?? '';
    final prompts = <CodePrompt>[];
    for (final id in kDocumentedElementIds) {
      if (input.isEmpty || id.toLowerCase().contains(input.toLowerCase())) {
        prompts.add(
          _CompletionItem(word: id, kind: _PromptKind.elementId, label: 'id'),
        );
      }
    }
    if (prompts.isEmpty) return null;
    _sortByPrefix(prompts, input);
    return CodeAutocompleteEditingValue(
      input: input,
      prompts: prompts,
      index: 0,
    );
  }

  // ---- <ninja> wrap snippet ------------------------------------------------

  CodeAutocompleteEditingValue? _buildNinjaWrapSnippet(String before) {
    final m = RegExp(r'<ni[a-z]*$').firstMatch(before);
    if (m == null) return null;
    const word = '<ninja></ninja>';
    // Caret between the open and close tags so the user types Twig
    // immediately. `<ninja>`.length == 7.
    return CodeAutocompleteEditingValue(
      input: m.group(0)!,
      prompts: [
        _SnippetCompletion(
          word: word,
          caretOffset: 7,
          label: 'wrap',
          kind: _PromptKind.snippet,
        ),
      ],
      index: 0,
    );
  }

  bool _isInNinja(CodeLineSelection selection) =>
      isCaretInNinja(controller, selection);

  // ---- $token detection ----------------------------------------------------

  CodeAutocompleteEditingValue? _buildDollar(String before) {
    final m = RegExp(r'\$[\w.]*$').firstMatch(before);
    if (m == null) return null;
    final input = m.group(0)!; // includes leading $
    final query = input.substring(1).toLowerCase(); // after $
    final prompts = <CodePrompt>[];
    for (final t in kDesignTokens) {
      if (query.isEmpty || t.token.toLowerCase().contains(query)) {
        prompts.add(
          _CompletionItem(
            word: t.token,
            kind: _PromptKind.dollar,
            label: t.categoryKey,
          ),
        );
      }
    }
    if (prompts.isEmpty) return null;
    _sortByPrefix(prompts, '\$$query');
    return CodeAutocompleteEditingValue(
      input: input,
      prompts: prompts,
      index: 0,
    );
  }

  // ---- Twig detection ------------------------------------------------------

  CodeAutocompleteEditingValue? _buildTwig(String before) {
    // Find an unclosed {{ or {% on the current line before the caret.
    final openExpr = before.lastIndexOf('{{');
    final closeExpr = before.lastIndexOf('}}');
    final openTag = before.lastIndexOf('{%');
    final closeTag = before.lastIndexOf('%}');
    final inExpr = openExpr > closeExpr && openExpr >= 0;
    final inTag = openTag > closeTag && openTag >= 0;
    if (!inExpr && !inTag) return null;

    // Pick the most recent opener.
    final isTagCtx = inTag && (!inExpr || openTag > openExpr);
    final openerIdx = isTagCtx ? openTag : openExpr;
    final inner = before.substring(openerIdx + 2);

    // After a pipe → filter completion.
    final pipe = RegExp(r'\|\s*(\w*)$').firstMatch(inner);
    if (pipe != null) {
      final input = pipe.group(1) ?? '';
      final prompts = <CodePrompt>[];
      for (final f in kTwigCatalog.filters) {
        if (input.isEmpty || f.toLowerCase().contains(input.toLowerCase())) {
          prompts.add(
            _CompletionItem(
              word: f,
              kind: _PromptKind.twigFilter,
              label: 'filter',
            ),
          );
        }
      }
      return _wrap(input, prompts);
    }

    // Identifier (possibly dotted) at the end.
    final identMatch = RegExp(r'([\w.]*)$').firstMatch(inner);
    final ident = identMatch?.group(1) ?? '';
    if (ident.contains('.')) {
      return _buildTwigDotted(ident);
    }

    // Bare identifier at start of expression/tag: roots + (in tag context)
    // tags + functions.
    final input = ident;
    final prompts = <CodePrompt>[];
    for (final root in kTwigCatalog.entityGraph.keys) {
      if (!isPublicTwigRoot(root)) {
        continue; // skip helper schemas (e.g. _po_vendor)
      }
      if (input.isEmpty || root.toLowerCase().contains(input.toLowerCase())) {
        prompts.add(
          _CompletionItem(
            word: root,
            kind: _PromptKind.twigRoot,
            label: 'variable',
          ),
        );
      }
    }
    if (isTagCtx) {
      for (final t in kTwigCatalog.tags) {
        if (input.isEmpty || t.toLowerCase().contains(input.toLowerCase())) {
          prompts.add(
            _CompletionItem(word: t, kind: _PromptKind.twigTag, label: 'tag'),
          );
        }
      }
    }
    for (final f in kTwigCatalog.functions) {
      if (input.isEmpty || f.toLowerCase().contains(input.toLowerCase())) {
        prompts.add(
          _CompletionItem(
            word: f,
            kind: _PromptKind.twigFunction,
            label: 'function',
          ),
        );
      }
    }
    // Twig literals — useful in both expression and tag contexts.
    for (final lit in kTwigLiterals) {
      if (input.isEmpty || lit.toLowerCase().contains(input.toLowerCase())) {
        prompts.add(
          _CompletionItem(
            word: lit,
            kind: _PromptKind.twigField,
            label: 'literal',
          ),
        );
      }
    }
    // Single-word operators (`and`, `or`, `not`, `in`, `is`, `defined`,
    // `empty`) — only meaningful inside `{% %}` tag context.
    if (isTagCtx) {
      for (final op in kTwigOperatorKeywords) {
        if (input.isEmpty || op.toLowerCase().contains(input.toLowerCase())) {
          prompts.add(
            _CompletionItem(
              word: op,
              kind: _PromptKind.twigField,
              label: 'operator',
            ),
          );
        }
      }
    }
    return _wrap(input, prompts);
  }

  /// Walk a dotted Twig identifier (`invoice.client.location.addr`) and
  /// return field completions for the deepest resolved schema.
  CodeAutocompleteEditingValue? _buildTwigDotted(String ident) {
    final parts = ident.split('.');
    final input = parts.removeLast(); // partial last segment
    if (parts.isEmpty) return null;
    var schema = kTwigCatalog.entityGraph[parts.first];
    for (var i = 1; i < parts.length && schema != null; i++) {
      final next = parts[i];
      final nextKey = schema.objects[next] ?? schema.arrays[next];
      if (nextKey == null) return null;
      schema = kTwigCatalog.entityGraph[nextKey];
    }
    if (schema == null) return null;
    final prompts = <CodePrompt>[];
    void add(String word, _PromptKind kind, String label) {
      if (input.isEmpty || word.toLowerCase().contains(input.toLowerCase())) {
        prompts.add(_CompletionItem(word: word, kind: kind, label: label));
      }
    }

    for (final f in schema.fields) {
      // Surface the `_raw` / formatted convention via the kind label so
      // users can tell which to use for arithmetic vs display without
      // hunting through docs.
      add(f, _PromptKind.twigField, f.endsWith('_raw') ? 'raw' : 'field');
    }
    for (final obj in schema.objects.keys) {
      add(obj, _PromptKind.twigRoot, 'object');
    }
    for (final arr in schema.arrays.keys) {
      add(arr, _PromptKind.twigRoot, 'array');
    }
    return _wrap(input, prompts);
  }

  CodeAutocompleteEditingValue? _wrap(String input, List<CodePrompt> prompts) {
    if (prompts.isEmpty) return null;
    _sortByPrefix(prompts, input);
    return CodeAutocompleteEditingValue(
      input: input,
      prompts: prompts,
      index: 0,
    );
  }

  void _sortByPrefix(List<CodePrompt> prompts, String query) {
    if (query.isEmpty) return;
    final q = query.toLowerCase();
    prompts.sort((a, b) {
      final aw = a.word.toLowerCase();
      final bw = b.word.toLowerCase();
      final ap = aw.startsWith(q);
      final bp = bw.startsWith(q);
      if (ap != bp) return ap ? -1 : 1;
      return aw.compareTo(bw);
    });
  }
}

// =============================================================================
// Overlay view
// =============================================================================

const int _kMaxRows = 12;
const double _kRowHeight = 28;
const double _kFooterHeight = 22;
const double _kOverlayWidth = 320;

class _OverlayView extends StatelessWidget implements PreferredSizeWidget {
  const _OverlayView({required this.notifier, required this.onSelected});

  final ValueNotifier<CodeAutocompleteEditingValue> notifier;
  final ValueChanged<CodeAutocompleteResult> onSelected;

  @override
  Size get preferredSize {
    final rowCount = notifier.value.prompts.length.clamp(1, _kMaxRows);
    final extraForOverflow = notifier.value.prompts.length > _kMaxRows
        ? 24.0
        : 0;
    return Size(
      _kOverlayWidth,
      rowCount * _kRowHeight + extraForOverflow + _kFooterHeight + 8,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return ValueListenableBuilder<CodeAutocompleteEditingValue>(
      valueListenable: notifier,
      builder: (context, value, _) {
        final visible = value.prompts.take(_kMaxRows).toList();
        final overflow = value.prompts.length - visible.length;
        return Material(
          elevation: 8,
          color: tokens.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(InRadii.r2),
            side: BorderSide(color: tokens.border),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kOverlayWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < visible.length; i++)
                  _Row(
                    prompt: visible[i] as _CompletionItem,
                    input: value.input,
                    selected: i == value.index,
                    onTap: () =>
                        onSelected(value.copyWith(index: i).autocomplete),
                  ),
                if (overflow > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text(
                      '+$overflow more — keep typing',
                      style: TextStyle(
                        color: tokens.ink3,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                Container(
                  height: _kFooterHeight,
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: tokens.border)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '↑↓ navigate · ↵ insert · esc close',
                    style: TextStyle(color: tokens.ink3, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.prompt,
    required this.input,
    required this.selected,
    required this.onTap,
  });

  final _CompletionItem prompt;
  final String input;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final bg = selected ? tokens.accentSoft : Colors.transparent;
    final ink = tokens.ink;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: _kRowHeight,
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              child: Text(
                _glyphFor(prompt.kind),
                style: TextStyle(
                  color: _colorFor(prompt.kind, tokens),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFamily: kMonoFontFamily,
                ),
              ),
            ),
            Expanded(
              child: _HighlightedText(
                text: prompt.word,
                query: input,
                style: TextStyle(
                  fontFamily: kMonoFontFamily,
                  fontSize: 12,
                  color: ink,
                ),
              ),
            ),
            Text(
              prompt.label,
              style: TextStyle(color: tokens.ink3, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.query,
    required this.style,
  });

  final String text;
  final String query;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    // Strip a leading `$` from the query if present — design-token matches
    // are stored without highlighting the trigger char.
    final q = query.startsWith(r'$') ? query.substring(1) : query;
    if (q.isEmpty) {
      return Text(text, style: style, overflow: TextOverflow.ellipsis);
    }
    final lower = text.toLowerCase();
    final start = lower.indexOf(q.toLowerCase());
    if (start < 0) {
      return Text(text, style: style, overflow: TextOverflow.ellipsis);
    }
    final end = start + q.length;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          if (start > 0) TextSpan(text: text.substring(0, start)),
          TextSpan(
            text: text.substring(start, end),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (end < text.length) TextSpan(text: text.substring(end)),
        ],
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Leading visual marker per prompt kind. Only design `$tokens`, Twig
/// variable roots, element IDs, and snippets get a glyph — they're the
/// most identifiable trigger characters and worth a strong visual cue.
/// Tags / filters / functions lean on the trailing kind label
/// ("filter", "tag", "function") instead of dense glyphs that aren't
/// intuitive to non-developers.
String _glyphFor(_PromptKind k) => switch (k) {
  _PromptKind.dollar => r'$',
  _PromptKind.twigRoot => '{}',
  _PromptKind.elementId => '#',
  _PromptKind.snippet => '<>',
  _PromptKind.twigField || _PromptKind.twigTag => '',
  _PromptKind.twigFunction || _PromptKind.twigFilter => '',
};

/// True when [selection]'s caret sits inside an open `<ninja>...</ninja>`
/// block in [controller]. If [selection] is null, uses the controller's
/// current selection. Public so the side-pane click-insert path can
/// decide whether to wrap a Twig variable in `<ninja>` tags.
bool isCaretInNinja(
  CodeLineEditingController controller, [
  CodeLineSelection? selection,
]) {
  final sel = selection ?? controller.selection;
  final lines = controller.codeLines;
  var offset = 0;
  for (var i = 0; i < sel.extentIndex && i < lines.length; i++) {
    offset += lines[i].text.length + 1; // +1 for newline
  }
  offset += sel.extentOffset;
  final fullText = controller.text;
  if (offset > fullText.length) offset = fullText.length;
  if (offset < 0) return false;
  final before = fullText.substring(0, offset);
  final open = before.lastIndexOf('<ninja>');
  final close = before.lastIndexOf('</ninja>');
  return open > close;
}

Color _colorFor(_PromptKind k, InTheme t) => switch (k) {
  _PromptKind.dollar => t.accent,
  _PromptKind.twigRoot => t.accent,
  _PromptKind.elementId => t.accent,
  // Distinct from `twigFunction` (also paid-green) — `partial` orange
  // signals "wrap helper" cleanly without overloading function/filter.
  _PromptKind.snippet => t.partial,
  _PromptKind.twigField => t.ink2,
  _PromptKind.twigTag => t.overdue,
  _PromptKind.twigFunction => t.paid,
  _PromptKind.twigFilter => t.overdue,
};
