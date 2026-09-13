import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import 'package:admin/domain/email_template_variables.dart';
import 'package:admin/ui/core/widgets/template_variables/template_variable_chip.dart';

// The super_editor seam for template-variable chips (invoiceninja/flutter#139)
// plus the linkify guard every markdown field needs. `MarkdownTextField` is the
// only caller; everything here is pure over super_editor's document model so it
// can be tested without pumping an editor.
//
// Two facts about the pinned super_editor shape all of it:
//  * A chip is an inline *placeholder* ([TemplateVariablePlaceholder]) — one
//    atomic character to the caret, selection and backspace — rendered through
//    `Stylesheet.inlineWidgetBuilders`. Inline widgets sit under an
//    `IgnorePointer`, so taps reach them only through a `ContentTapDelegate`
//    (editor) or a layout hit-test (reader): [hitTestTemplateVariableChip].
//  * The markdown serializer has no placeholder hook: a placeholder serializes
//    as a literal U+FFFC. So chips are created after deserializing
//    ([tokenizeTemplateVariables]) and turned back into their tokens before
//    every serialize ([detokenizeTemplateVariables]) — and the round trip must
//    be byte-identical, or an untouched field emits a spurious change.

/// A template-variable chip inside a super_editor document.
@immutable
class TemplateVariablePlaceholder {
  const TemplateVariablePlaceholder(this.token);

  /// The literal, `$` included.
  final String token;

  @override
  bool operator ==(Object other) =>
      other is TemplateVariablePlaceholder && other.token == token;

  @override
  int get hashCode => token.hashCode;

  @override
  String toString() => 'TemplateVariablePlaceholder($token)';
}

const int _objectReplacementCodeUnit = 0xFFFC;

/// Whether chips may live in [node]'s text: a paragraph that isn't a code
/// block, a list item, or a task. Tables and code stay raw text.
bool templateVariableNodeHoldsChips(DocumentNode node) {
  if (node is ParagraphNode) {
    return node.getMetadataValue('blockType') != codeAttribution;
  }
  return node is ListItemNode || node is TaskNode;
}

// ── Tokenize / detokenize ────────────────────────────────────────────────────

/// Replace every recognised `$token` in [document] with a chip. Returns
/// [document] itself when nothing changed.
MutableDocument tokenizeTemplateVariables(
  MutableDocument document,
  TemplateVariableScope scope,
) {
  var changed = false;
  final nodes = <DocumentNode>[];
  for (final node in document) {
    if (node is TextNode && templateVariableNodeHoldsChips(node)) {
      final text = tokenizeTemplateVariableText(node.text, scope);
      if (!identical(text, node.text)) {
        nodes.add(node.copyTextNodeWith(text: text));
        changed = true;
        continue;
      }
    }
    nodes.add(node);
  }
  return changed ? MutableDocument(nodes: nodes) : document;
}

/// [text] with each recognised, uniformly formatted `$token` replaced by a
/// [TemplateVariablePlaceholder]. Returns [text] itself when there is none.
///
/// **Uniform formatting only.** The server substitutes variables *before* it
/// parses the markdown, so `**$client**.name` is `$client` followed by the
/// literal `.name`. A token whose formatting changes part-way through can't
/// become one chip without changing what it means, so it stays text — as does
/// anything in inline code.
///
/// Attribution markers are remapped through an offset map (a token's range
/// collapses onto its chip), which [detokenizeTemplateVariableText] inverts
/// exactly.
AttributedText tokenizeTemplateVariableText(
  AttributedText text,
  TemplateVariableScope scope,
) {
  final plain = text.toPlainText();
  final matches = [
    for (final m in findTemplateVariables(plain))
      if (lookupTemplateVariable(m.token, scope) != null &&
          _isUniform(text, m.start, m.end))
        m,
  ];
  if (matches.isEmpty) return text;

  final chars = StringBuffer();
  final placeholders = <int, Object>{};
  var out = 0;
  var next = 0;
  var i = 0;
  while (i < plain.length) {
    if (next < matches.length && i == matches[next].start) {
      placeholders[out] = TemplateVariablePlaceholder(matches[next].token);
      out++;
      i = matches[next].end;
      next++;
      continue;
    }
    final existing = text.placeholders[i];
    if (existing != null) {
      placeholders[out] = existing;
    } else {
      chars.writeCharCode(plain.codeUnitAt(i));
    }
    out++;
    i++;
  }

  int remap(int offset) {
    var shift = 0;
    for (final m in matches) {
      if (offset >= m.end) {
        shift += m.end - m.start - 1;
      } else if (offset >= m.start) {
        return m.start - shift;
      } else {
        break;
      }
    }
    return offset - shift;
  }

  return AttributedText(
    chars.toString(),
    AttributedSpans(
      attributions: [
        for (final marker in text.spans.markers)
          marker.copyWith(offset: remap(marker.offset)),
      ],
    ),
    placeholders,
  );
}

bool _isUniform(AttributedText text, int start, int end) {
  if (text.getAllAttributionsAt(start).contains(codeAttribution)) return false;
  for (final marker in text.spans.markers) {
    final o = marker.offset;
    // A span that opens after the token's first character, or closes before
    // its last one (end markers are inclusive), splits it.
    if (marker.isStart && o > start && o < end) return false;
    if (marker.isEnd && o >= start && o < end - 1) return false;
  }
  return true;
}

/// A copy of [document] with every chip turned back into its token and any
/// stray U+FFFC dropped — what the markdown serializer must be handed.
/// Returns [document] itself when there is nothing to do.
Document detokenizeTemplateVariables(Document document) {
  if (!document.any(_needsDetokenize)) return document;
  return MutableDocument(
    nodes: [
      for (final node in document)
        if (node is TextNode && _needsDetokenize(node))
          node.copyTextNodeWith(text: detokenizeTemplateVariableText(node.text))
        else
          node,
    ],
  );
}

bool _needsDetokenize(DocumentNode node) =>
    node is TextNode &&
    (node.text
            .toPlainText(includePlaceholders: false)
            .codeUnits
            .contains(_objectReplacementCodeUnit) ||
        node.text.placeholders.values.any(
          (p) => p is TemplateVariablePlaceholder,
        ));

/// [text] with each chip widened back into its token. A literal U+FFFC that
/// isn't a placeholder — a chip copied to the clipboard and pasted back, since
/// super_editor copies placeholders as that character — means nothing to the
/// server and is dropped.
AttributedText detokenizeTemplateVariableText(AttributedText text) {
  var working = text;
  final plain = working.toPlainText();
  for (var i = plain.length - 1; i >= 0; i--) {
    if (plain.codeUnitAt(i) == _objectReplacementCodeUnit &&
        !working.placeholders.containsKey(i)) {
      working = working.removeRegion(startOffset: i, endOffset: i + 1);
    }
  }
  if (!working.placeholders.values.any(
    (p) => p is TemplateVariablePlaceholder,
  )) {
    return working;
  }

  final full = working.toPlainText();
  final newStart = List<int>.filled(full.length + 1, 0);
  final chars = StringBuffer();
  final placeholders = <int, Object>{};
  var out = 0;
  for (var i = 0; i < full.length; i++) {
    newStart[i] = out;
    final placeholder = working.placeholders[i];
    if (placeholder is TemplateVariablePlaceholder) {
      chars.write(placeholder.token);
      out += placeholder.token.length;
    } else if (placeholder != null) {
      placeholders[out] = placeholder;
      out += 1;
    } else {
      chars.writeCharCode(full.codeUnitAt(i));
      out += 1;
    }
  }
  newStart[full.length] = out;

  int widthAt(int i) {
    final placeholder = working.placeholders[i];
    return placeholder is TemplateVariablePlaceholder
        ? placeholder.token.length
        : 1;
  }

  return AttributedText(
    chars.toString(),
    AttributedSpans(
      attributions: [
        for (final marker in working.spans.markers)
          marker.copyWith(
            offset: marker.isStart
                ? newStart[marker.offset]
                : newStart[marker.offset] + widthAt(marker.offset) - 1,
          ),
      ],
    ),
    placeholders,
  );
}

/// The tokens of every chip in [document], in order — the body's screen-reader
/// summary, since super_editor exposes no semantics of its own.
Iterable<String> templateVariableTokensIn(Document document) sync* {
  for (final node in document) {
    if (node is! TextNode) continue;
    for (final placeholder in node.text.placeholders.values) {
      if (placeholder is TemplateVariablePlaceholder) yield placeholder.token;
    }
  }
}

// ── Rendering and taps ───────────────────────────────────────────────────────

/// The inline-widget builder for chips. It must claim **every**
/// [TemplateVariablePlaceholder], known or not: super_editor adds nothing to
/// the span for an unclaimed placeholder, and the layout's offsets then drift
/// from the document's.
InlineWidgetBuilder templateVariableChipBuilder({
  required TemplateVariableScope scope,
  bool muted = false,
  bool editable = true,
}) {
  return (context, textStyle, placeholder) {
    if (placeholder is! TemplateVariablePlaceholder) return null;
    final display =
        describeTemplateVariable(context, placeholder.token, scope) ??
        TemplateVariableDisplay(
          token: placeholder.token,
          label: placeholder.token,
          monospace: true,
        );
    return TemplateVariableChip(
      display: display,
      muted: muted,
      editable: editable,
      fontSize: (textStyle.fontSize ?? 14) * 0.86,
    );
  };
}

/// A chip under a pointer: which node, which offset, which token.
@immutable
class TemplateVariableChipHit {
  const TemplateVariableChipHit({
    required this.nodeId,
    required this.offset,
    required this.token,
  });

  final String nodeId;
  final int offset;
  final String token;
}

/// The chip at [documentOffset] (document-layout coordinates), if any. The
/// nearest caret position lands on one side of a chip or the other, so both
/// neighbours are checked against the chip's own rect — widened a little
/// sideways and to the full line box vertically, so a chip is as easy to hit
/// as the line it sits in.
TemplateVariableChipHit? hitTestTemplateVariableChip(
  Document document,
  DocumentLayout layout,
  Offset documentOffset,
) {
  final position = layout.getDocumentPositionNearestToOffset(documentOffset);
  if (position == null) return null;
  final node = document.getNodeById(position.nodeId);
  final nodePosition = position.nodePosition;
  if (node is! TextNode || nodePosition is! TextNodePosition) return null;
  for (final i in [nodePosition.offset - 1, nodePosition.offset]) {
    final placeholder = node.text.placeholders[i];
    if (placeholder is! TemplateVariablePlaceholder) continue;
    final rect = layout.getRectForSelection(
      templateVariablePosition(node.id, i),
      templateVariablePosition(node.id, i + 1),
    );
    if (rect == null) continue;
    final target = Rect.fromLTRB(
      rect.left - 2,
      rect.top - 4,
      rect.right + 2,
      rect.bottom + 4,
    );
    if (target.contains(documentOffset)) {
      return TemplateVariableChipHit(
        nodeId: node.id,
        offset: i,
        token: placeholder.token,
      );
    }
  }
  return null;
}

/// Routes a tap on a chip in the live editor to [onChipTap] and stops
/// super_editor from also placing the caret there. SuperEditor disposes its
/// delegates whenever its `Editor` changes, so the factory must build a new
/// one on every call.
class TemplateVariableTapDelegate extends ContentTapDelegate {
  TemplateVariableTapDelegate({
    required this.document,
    required this.onChipTap,
  });

  final Document document;
  final ValueChanged<TemplateVariableChipHit> onChipTap;

  @override
  TapHandlingInstruction onTap(DocumentTapDetails details) {
    final hit = hitTestTemplateVariableChip(
      document,
      details.documentLayout,
      details.layoutOffset,
    );
    if (hit == null) return TapHandlingInstruction.continueHandling;
    onChipTap(hit);
    return TapHandlingInstruction.halt;
  }
}

// ── Editing ──────────────────────────────────────────────────────────────────

DocumentPosition templateVariablePosition(String nodeId, int offset) =>
    DocumentPosition(
      nodeId: nodeId,
      nodePosition: TextNodePosition(offset: offset),
    );

DocumentRange _range(String nodeId, int start, int end) => DocumentRange(
  start: templateVariablePosition(nodeId, start),
  end: templateVariablePosition(nodeId, end),
);

/// A chip as insertable text: the placeholder, carrying [attributions] (so a
/// chip inside a bold run stays bold), optionally with a space either side.
AttributedText templateVariableChipText(
  String token, {
  Set<Attribution> attributions = const {},
  bool leadingSpace = false,
  bool trailingSpace = false,
}) {
  final at = leadingSpace ? 1 : 0;
  return AttributedText(
    '${leadingSpace ? ' ' : ''}${trailingSpace ? ' ' : ''}',
    AttributedSpans(
      attributions: [
        for (final attribution in attributions) ...[
          SpanMarker(
            attribution: attribution,
            offset: at,
            markerType: SpanMarkerType.start,
          ),
          SpanMarker(
            attribution: attribution,
            offset: at,
            markerType: SpanMarkerType.end,
          ),
        ],
      ],
    ),
    {at: TemplateVariablePlaceholder(token)},
  );
}

/// Whether [char] would run on into a token placed before it (`$number` + `x`
/// reads `$numberx` to the server), so an inserted chip needs a space.
bool templateVariableContinuesToken(String char) =>
    char.isNotEmpty && RegExp(r'[A-Za-z0-9_]').hasMatch(char);

/// Where an appended chip goes: the end of the last text node that can hold
/// one, or null when the document ends in something else (a table, code).
DocumentPosition? templateVariableAppendPosition(Document document) {
  for (final node in document.toList().reversed) {
    if (node is TextNode && templateVariableNodeHoldsChips(node)) {
      return templateVariablePosition(node.id, node.text.length);
    }
  }
  return null;
}

/// Requests replacing the chip at [offset] of [node] with [token] — or
/// removing it when [token] is null — in one transaction. With [caretAfter]
/// the caret lands just past the result (editor mode); the single-node delete
/// never moves the selection itself.
List<EditRequest> replaceTemplateVariableChipRequests(
  TextNode node,
  int offset, {
  String? token,
  bool caretAfter = false,
}) {
  final attributions = node.text.getAllAttributionsAt(offset);
  final plain = node.text.toPlainText();
  final after = offset + 1 < plain.length ? plain[offset + 1] : '';
  final trailingSpace = token != null && templateVariableContinuesToken(after);
  final caret = offset + (token == null ? 0 : 1) + (trailingSpace ? 1 : 0);
  return [
    DeleteContentRequest(documentRange: _range(node.id, offset, offset + 1)),
    if (token != null)
      InsertAttributedTextRequest(
        templateVariablePosition(node.id, offset),
        templateVariableChipText(
          token,
          attributions: attributions,
          trailingSpace: trailingSpace,
        ),
      ),
    if (caretAfter)
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: templateVariablePosition(node.id, caret),
        ),
        SelectionChangeType.alteredContent,
        SelectionReason.userInteraction,
      ),
  ];
}

// ── Reactions ────────────────────────────────────────────────────────────────

/// Wire the reactions into a freshly created [editor]: the link scrub
/// directly after `LinkifyReaction` (every markdown field), and — for a
/// template field, when [scope] is given — the conversion reaction **last**.
void installTemplateVariableReactions(
  Editor editor, {
  TemplateVariableScope? scope,
}) {
  final pipeline = editor.reactionPipeline;
  final linkify = pipeline.indexWhere((r) => r is LinkifyReaction);
  pipeline.insert(
    linkify < 0 ? pipeline.length : linkify + 1,
    const TemplateVariableLinkScrubReaction(),
  );
  if (scope != null) pipeline.add(TemplateVariableConversionReaction(scope));
}

/// True when [link] over [linkedText] is linkify's false positive on a
/// variable: the loose URL matcher reads `$client.name` as a host (`.name`,
/// `.city`, `.date` are TLD-shaped) and links the whole space-delimited word,
/// trailing punctuation included, as `https://` + the word. Serialized, that
/// is `[$client.name,](https://$client.name,)`, and the server then replaces
/// the token in both halves — broken markup in the email.
bool isTemplateVariableAutoLink(LinkAttribution link, String linkedText) {
  if (findTemplateVariables(linkedText).isEmpty) return false;
  final url = link.plainTextUri.toLowerCase();
  final text = linkedText.toLowerCase();
  return url == 'https://$text' || url == 'http://$text' || url == text;
}

/// The link spans in [text] that [isTemplateVariableAutoLink] condemns.
List<AttributionSpan> templateVariableAutoLinkSpans(AttributedText text) {
  if (text.length == 0) return const [];
  final plain = text.toPlainText();
  return [
    for (final span in text.getAttributionSpansInRange(
      attributionFilter: (a) => a is LinkAttribution,
      range: SpanRange(0, text.length - 1),
    ))
      if (span.end < plain.length &&
          isTemplateVariableAutoLink(
            span.attribution as LinkAttribution,
            plain.substring(span.start, span.end + 1),
          ))
        span,
  ];
}

/// [document] with the variable auto-links removed — run on every seed, so
/// content saved while the bug was live is cleaned on the user's next real
/// edit (the baseline is taken after it, so opening a field emits nothing).
MutableDocument healTemplateVariableLinks(MutableDocument document) {
  var changed = false;
  final nodes = <DocumentNode>[];
  for (final node in document) {
    if (node is TextNode) {
      final spans = templateVariableAutoLinkSpans(node.text);
      if (spans.isNotEmpty) {
        final text = node.text.copy();
        for (final span in spans) {
          text.removeAttribution(
            span.attribution,
            SpanRange(span.start, span.end),
          );
        }
        nodes.add(node.copyTextNodeWith(text: text));
        changed = true;
        continue;
      }
    }
    nodes.add(node);
  }
  return changed ? MutableDocument(nodes: nodes) : document;
}

/// Undoes linkify's false positive the moment it happens — typed space,
/// Enter, or paste — on every markdown field, template or not: the server
/// substitutes variables in terms, notes and footers too. Installed directly
/// after `LinkifyReaction`; a `react`-phase request runs at once, so by the
/// time this runs the link it removes is already in the document.
class TemplateVariableLinkScrubReaction extends EditReaction {
  const TemplateVariableLinkScrubReaction();

  @override
  void react(
    EditContext editorContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
  ) {
    final nodeIds = <String>{
      for (final event in changeList)
        if (event is DocumentEdit && event.change is NodeDocumentChange)
          (event.change as NodeDocumentChange).nodeId,
    };
    if (nodeIds.isEmpty) return;
    final document = editorContext.document;
    final requests = <EditRequest>[];
    for (final id in nodeIds) {
      final node = document.getNodeById(id);
      if (node is! TextNode) continue;
      for (final span in templateVariableAutoLinkSpans(node.text)) {
        requests.add(
          RemoveTextAttributionsRequest(
            documentRange: _range(id, span.start, span.end + 1),
            attributions: {span.attribution},
          ),
        );
      }
    }
    if (requests.isNotEmpty) requestDispatcher.execute(requests);
  }
}

/// Turns a `$token` typed or pasted into a template field into a chip.
///
/// Appended **last** to the reaction pipeline: every reaction's `react` gets
/// the same change list and a request issued in `react` runs at once, so a
/// reaction that shrank the text *before* `LinkifyReaction` would leave it
/// working from stale offsets.
///
/// For a single typed character it leaves a token alone while the user may
/// still be typing it — ending at the caret, or followed only by `.` (on the
/// way from `$client` to `$client.name`) — and never touches the IME's
/// composing region. A paste converts at once.
class TemplateVariableConversionReaction extends EditReaction {
  const TemplateVariableConversionReaction(this.scope);

  final TemplateVariableScope scope;

  @override
  void react(
    EditContext editorContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
  ) {
    // Node id → whether every insertion into it was a single typed character.
    final touched = <String, bool>{};
    for (final event in changeList) {
      if (event is! DocumentEdit) continue;
      final change = event.change;
      if (change is TextInsertionEvent) {
        // A chip we inserted ourselves.
        if (change.text.placeholders.values.any(
          (p) => p is TemplateVariablePlaceholder,
        )) {
          continue;
        }
        touched[change.nodeId] =
            (touched[change.nodeId] ?? true) && change.text.length == 1;
      } else if (change is NodeInsertedEvent) {
        touched[change.nodeId] = false;
      }
    }
    if (touched.isEmpty) return;

    final document = editorContext.document;
    final composer = editorContext.composer;
    final selection = composer.selection;
    final composing = composer.composingRegion.value;
    final requests = <EditRequest>[];
    DocumentSelection? newSelection;

    for (final entry in touched.entries) {
      final node = document.getNodeById(entry.key);
      if (node is! TextNode || !templateVariableNodeHoldsChips(node)) continue;
      final plain = node.text.toPlainText();
      final caret = _caretIn(selection, node.id);
      final composingRange = _rangeIn(composing, node.id);
      final typed = entry.value;
      final matches = [
        for (final m in findTemplateVariables(plain))
          if (lookupTemplateVariable(m.token, scope) != null &&
              _isUniform(node.text, m.start, m.end) &&
              !(typed && caret != null && _mayStillBeTyping(plain, m, caret)) &&
              !(composingRange != null &&
                  m.start < composingRange.$2 &&
                  m.end > composingRange.$1))
            m,
      ];
      if (matches.isEmpty) continue;
      for (final m in matches.reversed) {
        requests
          ..add(
            DeleteContentRequest(
              documentRange: _range(node.id, m.start, m.end),
            ),
          )
          ..add(
            InsertAttributedTextRequest(
              templateVariablePosition(node.id, m.start),
              templateVariableChipText(
                m.token,
                attributions: node.text.getAllAttributionsAt(m.start),
              ),
            ),
          );
      }
      if (caret != null) {
        var shift = 0;
        for (final m in matches) {
          if (m.end <= caret) shift += m.end - m.start - 1;
        }
        newSelection = DocumentSelection.collapsed(
          position: templateVariablePosition(node.id, caret - shift),
        );
      }
    }
    if (requests.isEmpty) return;
    requestDispatcher.execute([
      ...requests,
      if (newSelection != null)
        ChangeSelectionRequest(
          newSelection,
          SelectionChangeType.alteredContent,
          SelectionReason.contentChange,
        ),
    ]);
  }

  static bool _mayStillBeTyping(
    String plain,
    TemplateVariableMatch m,
    int caret,
  ) => caret == m.end || (caret == m.end + 1 && plain[m.end] == '.');

  static int? _caretIn(DocumentSelection? selection, String nodeId) {
    if (selection == null || !selection.isCollapsed) return null;
    final extent = selection.extent;
    final position = extent.nodePosition;
    if (extent.nodeId != nodeId || position is! TextNodePosition) return null;
    return position.offset;
  }

  static (int, int)? _rangeIn(DocumentRange? range, String nodeId) {
    if (range == null ||
        range.start.nodeId != nodeId ||
        range.end.nodeId != nodeId) {
      return null;
    }
    final start = range.start.nodePosition;
    final end = range.end.nodePosition;
    if (start is! TextNodePosition || end is! TextNodePosition) return null;
    return (start.offset, end.offset);
  }
}
