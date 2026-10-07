# Rich text editing

Companion to CLAUDE.md § Rich text editing. `MarkdownTextField` is the shared WYSIWYG editor for the note-shaped fields. The main file carries one line per rule; this doc carries the evidence — what the stored value actually is and what converts in each direction, the read-only surfaces, the inbound-HTML fold, the sliver pointer gate, and the caret theming. Template-variable chips live in `docs/template-variables.md`.

## Inbound HTML is folded to markdown, never handed to the deserializer raw

**Inbound HTML is folded to markdown by `markdownFromLegacyHtml` (`lib/utils/legacy_html_markdown.dart`) — never handed to the deserializer raw, and never with a hand-rolled `replaceAll`.** HTML is a **permanent** inbound shape for these fields, not legacy Quill residue: the React client edits the very same `public_notes` / `terms` / `footer` with TinyMCE. Raw, it is destroyed two ways, both silent. A **block** tag makes `markdown`'s `HtmlBlockSyntax` treat the line as a raw HTML block *running to the next blank line*, and super_editor's block visitor drops raw text — so a `<ul>` deleted the list **and everything after it** (invoiceninja/flutter#107). An **inline** tag survives as literal text, because `InlineHtmlSyntax` isn't in `markdown`'s default set and super_editor's `defaultInlineHtmlSyntaxes` only ever see `md.Element`s (from `**bold**` / `[t](u)`), so `<strong>` is painted to the user verbatim. Either way the loss **persists**: `_seedDocument` baselines `_lastEmitted` on the round-tripped value, so the first keystroke writes the mangled document back. Three traps if you extend the converter: (1) the tag regex must require `<` to abut the name **and** attributes to carry `=value` — a permissive tail (`[^<>]*`) turns `'qty < table rate > 10'` and `'mail <form@x.com> now'` into tags and eats the text between the brackets; (2) merge line breaks *as they are emitted* (`_MarkdownWriter`), never with a `\n{3,}` sweep at the end — a sweep can't tell a run it created from a blank line the user typed, which super_editor preserves as an empty paragraph node; (3) it must stay **idempotent**, since its own output is what gets re-parsed on the next open. Entities are deliberately untouched — `markdown`'s `DecodeHtmlSyntax` resolves them downstream against the full WHATWG table.

## A read-only editor blocks pointers at the sliver, not around the host

**A read-only editor blocks pointers at the *sliver*, never around the scroll host.** `_EditorHost` nests a `CustomScrollView` so `SuperEditor`/`SuperReader` gets a viewport of its own, and an `IgnorePointer` wrapped around **that** switches the viewport off too: content past the box could not be scrolled into view by drag or by wheel, it was simply cut off — the other half of #107, and it applied to every unfocused field, plus disabled ones (`enabled: false`) and, via `OverridableField`'s own `IgnorePointer`, every inherited value at client/group scope. Use `SliverIgnorePointer` (a sliver-to-sliver proxy, so the sliver protocol survives) and pass `blockPointerWhenInactive: false` from `OverridableMarkdownField`, which goes inert via `readOnly` instead — the one mode that leaves the reader live. A tap still promotes to editing because `ScrollView` hit-tests opaquely, so its drag recognizer joins the arena first and rejects on a movement-free pointer up.

## The mobile caret is themed through `primaryColor`

**The mobile caret is themed through `Theme.of(context).primaryColor`, and the `DefaultCaretOverlayBuilder` sitting right next to it is desktop-only.** `CaretDocumentOverlay` returns an empty box on Android/iOS unless `displayOnAllPlatforms` is set, so the file's explicit caret override never reached a phone; there the caret comes from `AndroidHandlesDocumentLayer` / `IosHandlesDocumentLayer`, which — along with all three Android drag handles, the iOS handles, the iOS magnifier border, and `SuperReader`'s own handles — fall back to `Theme.of(context).primaryColor`. `buildInTheme` leaves `primaryColor` unset, and Flutter derives it as `isDark ? colorScheme.surface : colorScheme.primary`: in dark mode that is the markdown field's **own background**, so the caret was painted invisible on every dark palette while light mode looked perfect (invoiceninja/flutter#108). The editor sliver therefore carries a scoped `Theme(data: Theme.of(context).copyWith(primaryColor: t.accent))` — one seam, because the per-builder `caretColor` / `handleColor` params reach the caret but not the Android handles (those read the controls controller, whose `controlsColor` is `final`) and `SuperReader` consults no controls scope at all. `Theme` builds only `InheritedWidget`s and no `RenderObject`, which is the only reason it may sit inside the sliver host. The regression test must be **dark-themed** — every light-mode test passes either way.

## These fields are HTML on the wire, so the editor emits HTML

**The value is HTML in and HTML out; markdown is only how `MarkdownTextField` thinks.** `public_notes` / `private_notes` / `terms` / `footer` — and the settings templates behind the same widget — are HTML to every other participant, and this app was the only one writing something else. React edits all of them with `components/forms/MarkdownEditor.tsx`, which despite the name is TipTap (or legacy TinyMCE) and saves `editor.getHTML()`; every one of its read-only views injects the stored string with `dangerouslySetInnerHTML` into a `white-space: normal` container; the client portal renders `{!! html_entity_decode(e($public_notes)) !!}`; and the server sanitizes each field through `Purify::clean` on write (`app/Http/Requests/Request.php:212`), whose whitelist (`p div br hr strong em b i u s del code pre ul ol li a img h1-h6 table`) is an editor-output whitelist. Markdown is honoured only when a company sets `markdown_enabled`, which defaults to **false** (`CompanyFactory.php:50`) and is sniffed heuristically even then — so the `\n\n` this app used to send collapsed to one run-on line and `**bold**` printed its asterisks (invoiceninja/flutter#159). `htmlFromEditorDocument` (`lib/utils/editor_html.dart`) is the outbound half; `markdownFromLegacyHtml` is still the inbound one, and together they close the loop. Only `_valueFor` converts: the markdown still drives every *internal* comparison (`_lastSerialized`, `_defaultSerialized`, the chip-undo staleness guard), so opening a record — or saving one untouched — emits nothing and rewrites nothing. A legacy plain-text or markdown note becomes HTML on the user's first real edit and not before.

**The output must never contain a newline.** `HtmlEngine.php` runs `nl2br()` over these fields on the PDF path, so a `\n` between two block tags renders as an extra blank line on the invoice. The server gives React the same guarantee from the other side, by deleting every `\n` from a payload carrying `X-REACT` (`StoreInvoiceRequest.php:160-175`, duplicated across the invoice / quote / credit / PO / recurring / client requests). We don't send that header, so the guarantee has to hold here; `editor_html_test.dart` asserts it over every construct the editor can produce.

**It is a document walker, not `serializeDocumentToMarkdown` + `markdownToHtml`.** super_editor's markdown serializer escapes nothing (`document_to_markdown_serializer.dart:406-547`), so a paragraph whose plain text is `5 * 3 * 2`, `# 1 priority`, `- see below` or `a_b_c` serializes verbatim — and re-parsing that as markdown would promote the user's own words to emphasis, a heading or a list, then *persist* the result. Reading the document's node types and attributions directly means nothing in the text can become markup. It also keeps super_editor's private dialect (`¬underline¬`, `~strike~`, `:---:` alignment rows, `![a](u =100x50)` size notation) out of a value three other clients have to read. The inline writer mirrors `AttributedTextMarkdownSerializer` step for step — same visitor, same open/close ordering, link outside the style marks — plus a stack that closes and reopens tags around *partially* overlapping spans, which markdown tolerates as `**a*b**c*` and HTML does not.

**Byte-stability across the server is not the invariant; the fixed point is.** `Purify::clean` reparses with `DOMDocument` and re-serializes with `saveHTML`, so `<br>` and attribute order are the server's call. What must hold is that `htmlFromEditorDocument(deserialize(markdownFromLegacyHtml(v)))` is stable — otherwise every open-and-save churns the record. `editor_html_test.dart` pins that over ~23 stored shapes, including the ones that degrade **once** and then hold: a `<pre>` block flattens, because the fold has no rule for it and it is not reachable from this app's toolbar. A `<table>` flattens too if it gets this far — but in `MarkdownTextField` it no longer does: flattening turned out to be the *best* case of three, and a value containing a table is shown as its own HTML instead (§ A value the document cannot hold is shown as HTML source, below). The one place a table still reaches the fold is `htmlFromEditableValue`, i.e. the Custom gateway `text` field.

Closing that loop needed four fixes on the inbound side, each of which was a leak before: `<img>` now maps to `![alt](src)` (it used to fall through as an unmapped inline tag and be painted at the user as raw markup); `<blockquote>` keeps its `>` marker (a quote used to degrade to a plain paragraph on the next save); an *interior* `<p></p>` asks for four newlines, which is exactly one empty `ParagraphNode` to `_EmptyLinePreservingParagraphSyntax`, so a blank line somebody typed survives; and a link destination's entities are decoded, since nothing downstream decodes inside one and `?a=1&amp;b=2` would otherwise gain an `&amp;` every trip.

**An inline tag with no markdown equivalent is now dropped, keeping its text.** `<span style="color:red">`, `<font>` and `<mark>` used to be left in place as literal text. That round-tripped only by accident — the literal tag went back to the server and the browser re-parsed it — while the user stared at raw markup inside the editor the whole time. With an escaping writer it would be strictly worse: the tag would reach the web app as a visible `&lt;span …&gt;`. The span's own colour or size is the price; the words are what matter, and the tag pattern is conservative enough (a real tag name abutting `<`, attributes requiring `=value`) that prose is never eaten.

## A read-only render of a notes field goes through `plainTextFromHtml`

**Every read-only render of one of these fields — and every "is it empty" gate in front of one — goes through `plainTextFromHtml` (`lib/utils/notes_html.dart`).** They carry markup no matter who wrote it, so a `Text` widget handed the raw value prints tags; that was already happening for anything authored on the web, and making this app write HTML would have made it universal. The call sites are the client and vendor detail notes cards, the billing-doc overview's Notes / Terms block, the recurring-invoice and purchase-order detail strips, and the notes columns of the seven HTML-bearing registries (via `cellNotes` / `colNotes(html: true)`). `valueBuilder` strips too, because it is the copy-to-clipboard value — multi-line there, `singleLine: true` in a cell that has one line to spend. The emptiness gates matter as much as the rendering: `<p></p>` is what an HTML editor stores for an empty body, and gating on the raw string reserves a card with nothing in it — so `ClientDetailNotesCard.hasContent` and `VendorDetailNotesCard.hasContent` exist and both layouts call them (a card that hides itself still costs its caller a gap).

Expense, project, product, payment, task description and line-item description are **not** in this set: React edits those in a plain `<textarea>` and the portal `nl2br`s them, so they are plain text everywhere and must stay that way.

## A field with no editor converts at its seams, and which converter depends on where its value came from

**A field seeded from a stored value inverts the fold with `htmlFromEditableValue`; a field that is always typed from scratch uses `htmlFromPlainText`.** Three surfaces are HTML on the wire but have no editor behind them, and getting this pair wrong is silent and destructive. A Custom gateway's **`text`** config is *seeded*: it shows `markdownFromLegacyHtml`'s output so the user reads words instead of tags, which means whatever comes back is markdown, so the way out has to be the fold's inverse. (The **Send Email body** used to be the other seeded one; it is a `MarkdownTextField` now — invoiceninja/flutter#139 — so it owns both conversions itself.) Pairing the fold with `htmlFromPlainText` instead shipped for a day and degraded any formatted template that was merely customised and sent — `<strong>Bob</strong>` came back as `**Bob**`, a `<ul>` as `<p>- One<br>- Two</p>`, and an `<a href>` as a literal `[label](url)`, i.e. a dead link. `htmlFromEditableValue` folds *before* it parses, so it is total: markdown, HTML the user pasted, and plain text all normalise to the same canonical output, and `editor_html_test.dart`'s fixed-point corpus is what proves it. The **Send Email sheet** and the **client bulk-update note** are the other kind — they start empty and are typed — so `htmlFromPlainText` is right there, and it deliberately does not interpret markdown: a note reading `5 * 3 * 2` must stay `5 * 3 * 2`.

## Report cells are flattened at the parse, not at the widget

**A report's string cells are flattened by `plainTextFromHtml` in `report_preview_api_model.dart`, because five surfaces read the same string.** `public_notes` / `private_notes` are selectable report columns on every one of these entities (`app/Export/CSV/BaseExport.php`), and the server only strips tags for some of them — `InvoiceDecorator` strips `terms` / `footer` / `public_notes`, `ClientDecorator` strips both notes, `CreditDecorator` strips only `terms`, and `QuoteDecorator` / `PurchaseOrderDecorator` / `RecurringInvoiceDecorator` / `VendorDecorator` define no notes methods at all, so those arrive with their markup. Stripping at the single `ReportColumnType.string` construction covers the table cell, the narrow card list, the column filter (`filterText`), the sort (`sortKey`) and the group key that feeds the group rows, the drill-down crumb and the chart's axis labels — all of which derive from the same two strings. Doing it at `_CellText` instead would fix one of the five.

## Local list search matches the markup, and that is a known cost

**Searching an invoice / quote / credit / purchase-order / recurring-invoice list matches the *raw* notes value, tags included.** `payloadJsonLike` (`lib/data/db/dao/_payload_search.dart`) runs `lower(json_extract(payload,'$.public_notes')) LIKE '%needle%'`, so a search for `p`, `em`, `li` or `href` now matches every row that has a note. It was already true for anything authored on the web; storing HTML from here broadens it. It is a false-positive widening rather than lost results — the notes clause sits on top of number, PO number, custom values and client name — and the honest fixes are both disproportionate: a denormalized plain-text search column means a migration on a shipped database, and dropping notes from search costs a real capability (clients and vendors already don't search theirs). Left as is, deliberately.

## A typed break accumulates, a block boundary merges

`_MarkdownWriter` (`lib/utils/legacy_html_markdown.dart`) *requests* breaks rather than writing them,
and resolves the request when real text arrives. `requestBreak` takes the **larger** of two pending
requests, which is right for block tags: `</p><p>` asks twice for the one boundary it describes, and
summing would open an empty paragraph between every pair.

Consecutive `<br>`s are the opposite — each is a break the author typed — and taking the max collapsed
`a<br><br>b` to `a\nb`, byte-identical to what `a<br>b` folds to. The corpus in
`test/utils/editor_html_test.dart` pins `'<p>a<br>b</p>'` as a fixed point, i.e. one newline ↔ one
`<br>`, so the second break was simply gone by the next save.

That was not an edge case. **Every** Invoice Ninja default email body is
`'<p>$client<br><br>' . <message> . '</p><div>$view_button</div>'`
(`app/DataMapper/EmailTemplateDefaults.php`), and that string is exactly what
`OverridableMarkdownField(defaultValue: defaults.body)` feeds the editor. So changing one word in
Settings → Templates & Reminders dropped the blank line after the greeting from the saved template and
from every mail that company sent thereafter. The same loss hit the Send Email body, notes/terms/
footer pasted from an email, and the app's own output: two Shift+Enters produce `a\n\nb` in one
`ParagraphNode`, which `editor_html.dart` emits as `<p>a<br><br>b</p>`, and the next open deleted one.

`requestHardBreak` now counts consecutive `<br>`s in `_pendingBreaks`, separately from `_pending`, and
`writeText` flushes `max(_pending, _pendingBreaks)`. Two counters, not one, because a `<br>` that merely
decorates a boundary the block tags already asked for (`</p><br><p>`) must not push it a line wider —
which a naive "always sum" does, and which `'<P>one</P><BR>two'` in the fold's own test catches.
Capped at 4, the most the encoding distinguishes (1 = soft break, 2 = paragraph boundary, 4 = paragraph
plus one deliberately blank one).

Neither the fold's tests nor the fixed-point corpus had a `<br><br>` case. **Note the corpus asserts
`cycle(cycle(x)) == cycle(x)` — stability, not identity** — so adding the shape there would have passed
vacuously; the fix is pinned by explicit expectations in both files instead. Still open, same root
cause, lesser: Gmail's `<div><br></div>` blank line yields a plain paragraph break rather than an empty
paragraph, because `openParagraphIsEmpty` is tracked for `p` only.

## An empty marker construct must release the break hold

`holdBreaks()` suppresses break requests between a list/heading/blockquote marker and the text that
belongs to it — TinyMCE writes `<li><p>One</p></li>`, and honouring that `<p>` would strand the marker
on a line of its own, which CommonMark reads as an empty item plus an unrelated paragraph.

The **only** thing that cleared the flag was `writeText`, and only when the text had a non-whitespace
character. A construct containing no text had nothing to clear it, and since `requestBreak` is a no-op
while held, the suppression then ran to the **end of the document**: its own `</li>`, the `</ul>`, and
every later block's request was discarded, and the next real text was appended straight onto the
stranded marker.

```
<ul><li></li></ul><p>Next</p>              ->  '- Next'
<ul><li>One</li><li></li><li>Two</li></ul> ->  '- One\n- - Two'
<h2></h2><p>Next</p>                       ->  '## Next'
<blockquote></blockquote><p>Next</p>       ->  '> Next'
```

So a note whose list ended with a blank bullet had **the following paragraph turned into a bullet**, and
a blank bullet between two items made the next one **change nesting depth** — both persisted by the save
and both visible in the rendered PDF. `<li><p></p></li>` is what TinyMCE writes for an emptied item, and
`editor_html.dart` writes `<li></li>` for a `ListItemNode` with empty text, so the app produced its own
trigger.

`releaseBreaks()` now runs at all three closers. It is called **before** the closing `requestBreak` in
the heading and blockquote arms, not after: those arms request their break unconditionally, and while
the flag is still set that request is dropped too.

## A value the document cannot hold is shown as HTML source

**A value containing a table — or one the fold would delete text from — is shown as its own HTML,
verbatim, in a plain source box; any other field can be switched to its source from the formatting
toolbar, and back from the strip above the box (invoiceninja/flutter#174).**

The report was a three-column company footer, written in the web app, that "appears empty" in
Settings → Company Details → Defaults. The fold has no rule for a table and cannot have a faithful
one, and what it did instead depended on who typed the markup. `test/_html_table_fixtures.dart`
holds one of each:

| Stored shape | What the editor showed | What the first keystroke stored |
|---|---|---|
| TipTap / TinyMCE output | three stacked paragraphs | `<p>` per cell — the table is gone |
| Hand-written, cell text on its own indented line | one paragraph, then a code block | `<pre><code>` holding the rest |
| A cell tag `kHtmlTagPattern` refuses — `<td nowrap>`, `style=width:33%; text-align:left`, `style=“width: 33%”` | **nothing** | `''` plus whatever was typed |

The third row is the report. A refused tag is left as literal text at the start of its line;
`markdown` 7.3.1's `HtmlBlockSyntax` takes that line through the next blank one as a raw HTML block
(condition 6, and it can interrupt a paragraph); and super_editor's block visitor has a no-op
`visitText`, so the block is dropped. When every cell opens with such a tag, every line goes. It is
reachable from React without anyone doing anything odd: the source-code modal calls
`onValueChange(htmlCode)` with the textarea's string (`TipTapEditor.tsx:1146`) and the sync effect
then sets `currentValue` back to it, so pasted HTML is stored as typed until the user next edits in
the WYSIWYG. Opening and saving untouched was always safe — nothing is emitted until a real edit —
but an empty box invites the edit.

**Why not a table in the document.** super_editor has a `TableBlockNode` and a GFM table syntax, and
`editor_html.dart` can already write one. Neither carries a cell width, an alignment, a `colspan`, or
block content inside a cell (`<td><p>…</p><p>…</p></td>` is what TipTap writes), so the footer would
still be rewritten on the first edit — just into a prettier wrong thing. Every other client keeps
the markup: React has a table menu and that source view, and the old Flutter app bound all of these
fields to plain multi-line text boxes.

**Two detectors, permissive on purpose.** `hasTableMarkup` (`lib/utils/html_source.dart`) matches a
table-family tag on its **name alone**. `kHtmlTagPattern` is strict because it *rewrites* — matching
prose eats the user's words — but this one only *routes*: a false positive opens a field as source
with the value exactly as stored, a false negative hands a table to an editor that flattens it. So
`<td nowrap>` is caught here even though the fold refuses it. (`<` must still abut the name:
`qty < table rate > 10` is not a table.) `foldLeftRawHtmlBlock` (`legacy_html_markdown.dart`) is the
other half and is not a table check: it asks whether a line of the fold's *output* still opens with
a block-level tag, which is exactly the precondition for the deletion above —
`<p hidden>Gone</p><p>Kept</p>` trips it, and a "did the document come out blank?" check alone would
not, since "Kept" survives. It mirrors CommonMark condition 6 rather than "any `<`", because
`<john@x.com>` at the start of a line is not a block to the parser and must not flip a plain note
into source. `richEditorCannotHold` (`editor_html.dart`) combines them with two backstops — a blank
document from a value that has words in it, and a deserialize that throws (which used to take the
whole field down).

**It is not a formatting check.** `<span style="color:red">`, `text-align`, a font size: still
dropped on the first edit, still opening in the rich editor. Every one of those is a button on the
web app's toolbar, and showing each such note as raw tags to people who have never seen one was
judged worse than the loss. `<style>` / `<script>` blocks on their own are not caught either (the
fold drops the tag and keeps the CSS as a paragraph). The manual toggle is the way to the source for
all of these, and the choice lasts for the visit, not across visits — a value is not *forced* unless
one of the detectors says so.

**The source box holds the stored string, and so does the baseline.** In rich mode `_lastEmitted` is
baselined to the document's *canonical re-serialization* so that opening a record emits nothing.
For a table that is the flattened value, which means the `next != _lastEmitted` guard in
`didUpdateWidget` was true on every rebuild that bumped `externalValueKey` —
`OverridableMarkdownField` hashes the value into the key, so that is every emit. In HTML mode the
baseline is therefore the raw value, and a separate `_held` (the seed value until the first emit,
then the emitted one) is what rich → HTML shows, so a look at the source of an untouched field can
change nothing. `MarkdownFieldController.flush()` returns **null** from an untouched source box,
which is its documented contract and which every caller already falls back from; "Save as default"
on a document footer then hands company settings the stored string rather than a re-serialization.

**Line breaks are the one thing converted, and only on the way out.** The server runs `nl2br()` over
these fields on the PDF path (`HtmlEngine.php:823`) and deletes newlines only for a request carrying
`X-REACT` (`UpdateInvoiceRequest.php:191`), which this app does not send. A line break between two
tags — the first thing anyone does in a source box — would print as a blank line on the invoice, and
between two table rows as a blank line *above* the table, where the browser hoists the stray `<br>`.
`wireHtmlFromSource` decides by where the break sits: inside a tag it is one space; beside a
block-level tag or a `<br>` it is source formatting and is dropped (what the server does for React);
between words **or beside an inline tag** it becomes `<br>`, because that is what the PDF already
renders for it and what the rich path writes for the same value — collapsing it would join two lines
of an address the first time `Company\nStreet` was edited as source. Two consequences, both accepted:
source indented by hand comes back as one wrapped line on the next visit (React's source view shows
`getHTML()`, also one line), and the first edit of a value stored *with* breaks between tags (legacy
TinyMCE output) stops the PDF adding a blank line for each — which the rich editor already did to
such a value.

**Where the controls live, and why not in the label row.** Rich → HTML is a `</>` button at the end
of the formatting toolbar, under the web app's own name for it (`source_code`): a resting field
gains no chrome, and there are eight of them on the Defaults page. HTML → rich is a strip above the
box, shown whether or not the box is focused, because a field full of tags has to say why at rest.
While the value is forced the strip shows the reason instead of the button. Both sit **inside the
frame**: the billing notes tabs pass `showLabel: false, expand: true`, which takes the early return
at the top of the label-row code, and a label-row action there would put the `Expanded` frame into
a Column with no bounded height.

**What the mode has to keep its hands off.** The document, composer and editor are still built on
every seed — `dispose`, the chip summary and the way back all need them — but nothing may write to
them while they are hidden: `_onDocumentChange`, `_insertVariable`, the chip Undo closure (a toast
outlives the switch) and `_applyPendingCaret` all check the mode first. `_editing` follows focus in
HTML mode, since there is no reader to promote from; without that the blur block never ran, an
emptied box never got its default back, and a default that arrived mid-edit was never adopted. And
rich → HTML does **not** reseed: the toolbar is only up while a `SuperEditor` is mounted, and it is
still holding the composer a reseed would dispose.

**A consequence on the email surfaces.** A *customised* template that contains a table opens as
source in Templates & Reminders and in Send Email, without chips. That is the right trade — one
edited word there used to send the flattened table — and it is not the common case: none of the
server's default templates contains a table (`EmailTemplateDefaults.php`), and Send Email's default
body is the template's own body, not the wrapped email (`TemplateEngine.php:169`). "Insert variable"
there writes the raw `$token` at the caret.

**The source box is `readOnly`, never `enabled: false`.** A disabled `TextField` wraps itself in an
`IgnorePointer` and takes its own scrolling with it — #107 again, for a footer longer than the box.
Smart quotes, smart dashes, autocorrect, suggestions and spell check are all off, and the first is
load-bearing: iOS would turn `style="width: 33%"` into the curly-quoted shape in the table above.

**The box's text is not quite the source: embedded image data is shown as a placeholder.** The web
app's image button embeds an upload as a `data:` URI (TipTap's `allowBase64`), so a footer with a
logo in one cell is a single unbreakable word several hundred KB long. Measured under
`flutter test` with a 300 KB payload: **~2.1 s to mount the box and ~2.0 s per keystroke**, all of it
text layout — the emit itself (the wire rule plus the detectors) is 3 ms — and the markup the user
came to edit is somewhere under a wall of `AAAA…`. `elideDataPayloads` swaps each payload of 512+
characters for `[base64-data-1-300KB]` and `restoreDataPayloads` puts it back before anything leaves
the box; with that the same value shows 104 characters and a keystroke costs what any other does.
So `_htmlController.text` may only be compared with itself (`_lastHtmlText`, `_isPristine`);
everything that reads it for its *meaning* — the emitted value, the detectors — goes through
`_htmlSourceOf`. A deleted placeholder takes its image with it, a copied one brings it along, and a
number with no payload behind it (pasted from another field) is left as typed rather than guessed
at. The placeholder is plain ASCII on purpose: it has to render in the bundled mono face, and it
must not read as markup, a `$variable`, or Twig. An image the user pastes in *while* editing is not
elided until the next seed — rewriting the text under a live caret is the worse trade.

**Ligatures are off in the box.** JetBrains Mono draws `</` and `/>` as single glyphs (`calt`). In
a box whose whole content is tags that makes every closing tag look like a character nobody typed.

Pinned by `test/utils/html_source_test.dart` (the detectors, the wire rule and its fixed point, the
placeholders) and `test/ui/core/widgets/markdown_text_field_html_mode_test.dart` (verbatim seed with
no emission, the three blanking shapes, the key-bump and late-default cases, the toggle, `expand`,
read-only scrolling, an embedded image intact on the wire, the pending edit surviving teardown).
