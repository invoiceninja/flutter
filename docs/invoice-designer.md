# The visual invoice designer

Companion to CLAUDE.md § Visual invoice designer. The designer lives under
`lib/ui/features/settings/views/advanced/invoice_design/wysiwyg/`; this doc
carries what the server does with a block design, the probes that established
it, and the rules the client follows because of it.

A *visual* (block) design is a custom design whose `design` JSON carries a
`blocks` array. The canvas is only a picture of what the server will print, so
almost every rule here is a fact about the server's renderer
(`app/Services/Pdf/JsonDesignService.php`, `JsonToSectionsAdapter.php`,
`PdfService.php`), read at `invoiceninja@fd321ae8e1` (2026-09-08) and probed
against `demo.invoiceninja.com` on 2026-10-08 with
`POST /api/v1/preview?html=true` — the HTML the PDF is made from.

## How the server lays a block design out

- Blocks are sorted by `(gridPosition.y, gridPosition.x)`. Blocks with the
  **same integer `y`** form one row (`groupBlocksIntoRows`).
- A row of several blocks is `display:flex; flex-wrap:nowrap; gap:10px`. Each
  block's column gets `width: w/12`. Leftover space is absorbed by auto
  margins chosen by the block's `rowAlign` — `left` → `margin-right:auto`,
  `right` → `margin-left:auto`, `center` → both. **`x` is never a position.**
- A block alone in its row gets **no width from `w`** and its `rowAlign`
  margin has nothing to push against: the wrapper is full width. Where the
  content sits is the block's own `align` property.
- **`h` is never read.** Rows are 12px apart (`.json-block { margin-bottom }`)
  and as tall as their content.
- `body { zoom: 80% }`. The `@page` margin is `pageMargin* + pagePadding*` per
  side, in unzoomed px.
- `rowAlign` is derived client-side at save (`annotateBlocksAsApi`):
  `x == 0` → left, `x + w == 12` → right, otherwise center. `rowWidth`,
  `colStart` and `colSpan` are sent too and read by nothing.

## Probe results

Each was a `/api/v1/preview?html=true` request with a hand-built design.

| Question | Result |
|---|---|
| An HTML design sent with `"blocks": []` | Rendered by the **block** renderer: the Twig body is dropped and the page is empty. Without the key the Twig renders. |
| A table column `header` of `unit_cost` vs `$product.unit_cost_label` | `unit_cost` printed as typed; the token printed "Unit Cost". Same for an info block `title` (`bill_to` vs `$bill_to_label` → "Bill To:"). |
| A `tasks-table` block | Its container div is emitted with nothing in it. No table. |
| A `spacer` with no `properties`, or `properties: {}` | **HTTP 500** for the whole document. |
| A lone `total` at `x6 w6` vs `x0 w12` | Identical: wrapper carries only the margin, the inner table is `width: fit-content` and placed by the block's `align`. |
| A lone `text` at `x6 w6` | Full-width, left-aligned text. `w` and `x` changed nothing. |
| A row `[spacer w6 height:0px][text w6]` | Two `flex-col`s of 50% — the text starts at the half-way mark. |
| `pageSize: B5` (and `JIS-B5`), `pageLayout: landscape` | `@page { size: A4 portrait }` — an unknown size drops the orientation too. `A4` / `Letter` + `landscape` are honoured. |
| `globalFontSize: 22`, `primaryFont: Lato`, `secondaryFont: Merriweather` | `body { font-family: Lato, …; font-size: 22px }`. The secondary font appears nowhere. |
| QR `size: 200px` | The SVG is 150×150 regardless. |
| `entity_id: "-1"` vs a real invoice id | `-1` renders a real invoice of the company (the title read `Invoice_0025`); a real id renders that invoice with the request's design. |
| The four starters as saved (`blocksFromRows(rowsOf(…))`, Bold in `#2F7DC3`) | All HTTP 200. Bold: a `41.67% / 41.67%` first row, `border-top: 2px solid #2F7DC3`, the table header on `#2F7DC3` in white, and `$entity_label` printing **Invoice** — title case, which is why the sample's label is not upper case. |
| `showTitle` + `title` on each info block | Printed for `client-info` and `client-shipping-info` only. The company block and the details block print no title. |
| A field `prefix` / `suffix` | Printed for the company and client blocks; **ignored by the details block**. Stored trimmed (`TrimStrings`), so `Tel: ` prints `Tel:555…`. |
| A table region's `sides` with `left` **left out** vs `left: false` | Left out: `border-left: 2px solid …` — drawn. `false`: `border-left: none`. A side is on unless it is strictly `false`. |
| `$invoice.terms` / `$terms` / `$entity.terms` in a text block | `$invoice.terms` is not a variable: the shorter `$invoice` (the number) matched and it printed `0025.terms`. The other two resolve. |
| Details rows labelled `public_notes`, `$public_notes_label`, `$invoice.custom1_label` | The bare key printed as typed; the token printed "Public Notes"; the custom-field token printed the company's own name for that field (blank where it has none). |
| `$partial_label` / `$balance_due_label` in a totals block | "Partial Due" and "Balance Due". |

## Rules that follow

### `blocks` is sent only when there are blocks

`PdfService::isJsonDesign` is `isset($design['blocks'])`, and `isset` is true
for an empty array. The client used to send `"blocks": []` with every design,
so every **HTML** design it saved or previewed took the block path and came
out blank. `DesignTemplateWire.toWireJson` (`design_api_model.dart`) omits the
key when the list is empty; `Design.toApiJson` — the save payload *and* the
preview request — goes through it. The local Drift payload still uses the
generated `toJson`, where the empty list is harmless.

A design saved before the fix keeps its stored `blocks: []` until it is saved
again. The builder also refuses to save an emptied canvas: that is the same
blank page reached from the other side.

### A block's `properties` are normalised on the way out

`wireBlockProperties` (`design_block_wire.dart`), applied by
`DesignBlock.toApi()`:

- `properties` is always present — every converter reads
  `$block['properties']` unguarded;
- a spacer always has a `height` (`kDefaultSpacerHeight` when cleared);
- a table column `header` or info `title` that is one of the bare
  localization keys this app used to seed (`item`, `unit_cost`, `bill_to`, …)
  becomes the label token the server translates. Anything else is the user's
  own text and is left alone.

New blocks are seeded with the tokens directly (`block_library.dart`). The
canvas resolves a header through `resolveTableHeaderLabel` /
`resolveBlockTitle`, which apply the same upgrade first — so a legacy design
shows the heading it will have once saved, and a preview already has it.
`kLabelTranslationMap`'s keys are the ones `HtmlEngine` passes to `ctrans`
(`$product.product_key_label` is "Product", `$product.item_label` is "Item").

### Fields this app does not model are carried, not dropped

The other client's builder writes `builderGridVersion`, `layout`, `customCss`,
a block's `region`, and pagination / repeating-header settings. `DesignTemplate`,
`DesignBlock` and `DocumentSettings` each hold an `extra` map of whatever the
JSON had that they have no field for. It rides the local payload under
`kDesignExtraKey` and is spread back to its own level by `toWireJson`. A known
field always wins over a leftover of the same name.

### A design with blocks opens in the builder, and only there

The Custom Designs list sent every custom design to the HTML editor. For a
block design that editor changes a body the server ignores, and it was the
only way back into a saved visual design. `_Row.isVisual`
(`custom_designs_body.dart`) routes on `template.blocks.isNotEmpty`; "Edit a
copy" of a visual design opens the builder too.

### A new visual design applies to all four document types

`OverridableDesignPicker` hides a custom design from a type its `entities` does
not list. The builder wrote `['invoice']` and had no control for it, so its
designs could never be chosen for quotes, credits or purchase orders.

### The Tasks block is not offered

`convertBlockToSection` has no `tasks-table` arm and `detectTableType` returns
`product` for every table, whose row filter keeps line-item types 1/4/5/6 —
so a task line (type 2) is printed by no block. `BlockSpec.printed` keeps the
block out of the palette and marks one already on a design. Flip it when the
server gains the renderer (`BACKEND.md`).

### Page sizes are the server's list

`kDesignerPageSizes` is `cssSizeFor`'s allow-list minus the poster sizes. A
stored value outside it keeps its own entry in the dropdown, labelled with what
it prints as, rather than the field quietly reading "A4".

## The editor

### Every key the workspace binds is guarded

The workspace's `Shortcuts` sit *between* the property panel's fields and
`DefaultTextEditingShortcuts` at the app root, so they are consulted first.
With plain `CallbackAction`s an arrow key typed in a field moved the selected
block and never reached the caret, and ⌘Z undid a canvas change instead of the
typing. All of them are `GuardedShortcutAction`s (disabled, so the key falls
through, while a text input has focus).

That guard is enough for a chord and not for a bare key, so there are two
intents:

| Keys | Intent | Acts when |
|---|---|---|
| ⌘Z, ⌘⇧Z / Ctrl+Y, ⌘D | `_Key` | focus is anywhere in the workspace, except a text field |
| arrows, Alt+↑/↓, Shift+←/→, Alt+Shift+←/→, Enter, Delete, Backspace, Esc | `_CanvasKey` | the workspace's **own** node has primary focus, and Preview is not showing |

A bare key is how every other control is worked. With the plain guard, Tab
onto a stepper and Enter was swallowed, the arrows were taken from a slider,
and **Backspace deleted the selected block**; in Preview, Delete removed a
block that was not on screen. `_CanvasKeyAction` is disabled — not a no-op —
outside its condition, so the key carries on to the control.

Plain Alt+←/→ is not bound: it is the app's Back / Forward
(`scaffold_with_nav.dart`) and this map is consulted first. Moving a block
along its row is Alt+Shift+←/→. `designer_workspace_keyboard_test.dart` fails
on each of these when the gate is removed.

Focus is held by a `FocusOwnerKeeper` over the workspace's own node —
`Focus(autofocus: true)` is applied once and never again. A press on the
canvas (a `Listener` around it in `DesignerWorkspace`) takes focus back from a
property field, and with it the canvas keys.

### Undo covers the whole template

`WysiwygDesignViewModel._apply` is the one place the template changes; it
snapshots the template (blocks **and** document settings) it replaces.

- Consecutive edits of one field of one block fold into one step
  (`_blockChangeKey`); selecting something else ends the run. The key names
  the *element* that changed (`columns[2].header`), not just the property:
  every column, field and totals-row edit rewrites its whole list, and keyed
  on `columns` alone one ⌘Z after deleting the wrong column took the two
  renames and three widths before it too. A change of length or order never
  folds into anything.
- A drag is `beginGesture()` … `endGesture()`: one step, and none at all when
  it changed nothing — the start is recorded on the first *real* change, so a
  press that moves nothing costs neither an undo step nor the redo stack.
- **A drag can lose its handle without ending.** A recognizer disposed
  mid-drag fires neither `onEnd` nor `onCancel` — press Esc while dragging and
  the handle unmounts. The gesture used to stay open: nothing after it was
  recorded, and the next drag replayed from the stale start, reverting
  everything done in between. So the handle ends its gesture in `dispose`,
  `beginGesture` always starts fresh, and `selectBlock`, `undo`, `redo` and
  the canvas's `dispose` end any that is open.
- **Whatever replaces the template bumps `templateEpoch`** — undo, redo,
  import, replace layout, discard. The panel's editors own text state seeded
  when a block is selected, and are keyed on `(block.id, templateEpoch)`:
  without it a field went on showing the undone text and the next keystroke
  wrote it back. `undo` / `redo` flush pending (debounced) edits first, so
  typing is undone rather than landing on top of the restored state.
- Undo keeps the selection when the block survives it.
- A delete — of a block or a row — also shows an Undo toast that restores
  that thing, rather than calling `undo()` on whatever happened last.

### Save keeps the builder open

`SettingsEntityEditScaffold(stayOpenAfterSave: true)`. The base edit view
model assumes a form closes on save, and three things had to be said again
for one that does not:

- **"Unsaved" is measured against the last save, not the design as opened.**
  The view model keeps the draft `performSave` sent (`_lastSaved`); `isDirty`
  compares with it once there is one, and Discard returns to it. Measured
  against the original, save-then-undo read as clean while the server held
  what the page no longer showed — and a Discard on a new design left a blank
  form still pointed at the saved record, which the next Save overwrote.
- **The second and later saves are updates to the first's id**, resolved
  through `id_remap` each time. While that id is still `tmp_` the save is
  sent as a create again with the same temp id (`existingTempId`) — an edit
  of a record whose create failed saves as a create (CLAUDE.md § Sync).
- **`savedDesignId` is null until the id is real**, so "Used for…" and "Use
  this design" never compare a `tmp_` id with the settings' real ones.

⌘S flushes pending edits and *then* asks whether there is anything to save:
inside the Content field's 300ms debounce it used to find nothing.

A starter layout is the *initial draft* (so an untouched one is not "unsaved
changes") and still enables Save (`hasUnsavedWork`). The default name is the
first of "Visual design", "Visual design 2"… that no design **of any state**
on this device uses (`DesignRepository.knownNames`): the server's
`unique:designs,name` counts archived and deleted designs too.

A design that exists is fetched again before it opens
(`DesignRepository.refreshByIds`, bounded, best effort): designs arrive in the
login bundle and a delta refresh re-sends only what changed, so a row can be
as old as the last full sync.

## The row model

`lib/data/models/domain/design_block_layout.dart` is the one copy of the
server's grouping rule; the canvas, the phone outline, the thumbnail and
`annotateBlocksAsApi` all go through it.

- `rowsOf(blocks)` — stable sort by `(y, x, index)`, a new row whenever `y`
  changes. It **never merges**: a design laid out on the old free grid opens
  as what it prints.
- `blocksFromRows(rows)` — `y` is the running sum of row spans and `h` the
  row's tallest stored `h`, so what is saved is valid for the server and
  non-overlapping for React's GridStack.
- `layoutRow(row, width)` — a port of the flex rule above. A row the user has
  not touched is drawn through it, exactly as it prints.

### Empty space is a gap cell

The flex rule cannot put a block in the middle of a row, or make a lone block
narrower than the page: `x` is ignored and leftover space goes to one auto
margin. So **a row the user edits always totals 12 columns**, and the space
that is not a block is a *gap cell* — a `spacer` block of height `0px`
(`newGapBlock`, `isGapBlock`). The probe row `[spacer w6][text w6]` is the
evidence that it prints as an empty column. A gap is not selected itself: it
is a drop target, and it grows or shrinks as the handle of the block beside
it is dragged; "Remove gaps" on the row's grip gives the columns back. `withBlockInRow` / `canJoinRow` take columns from gaps first, then from
the widest blocks down to their minimums, and refuse rather than squeeze a
block under its minimum.

The cost is blocks the user did not place by hand, visible as spacers in
React's builder.

### A design from the old grid says so once

`hasFreeGridOverlap` is true for two blocks at different `y` whose spans
overlap, side by side — the one arrangement the free grid drew differently
from the PDF. A design opened with it shows a single dismissible sentence
(`_FreeGridNote`). Nothing this builder saves has it.

## The canvas

`canvas/wysiwyg_canvas.dart`. `SingleChildScrollView` → `FittedBox(fitWidth)`
→ the sheet at true size (`DesignerPageMetrics`: A4 portrait is 794px; an
unknown size is A4 portrait, as on the server) → the content box at
`(width − insets) / 0.8`, shrunk by the body's 80% zoom → rows 12px apart. The
sheet is white with dark ink in either theme.

- **A block is drawn as it prints** — no card, no header (`BlockPreview`).
  The two things drawn that will not print are a placeholder where a block
  would render nothing (`blockRendersNothing`; without it the block could be
  neither seen nor clicked) and a note on a type the server cannot print.
- **Chrome lives in a layer above the page**, positioned with
  `CompositedTransformFollower`s: a `Stack` child outside its parent's bounds
  is not hit-testable, and the tab and handles sit outside the block. The tab
  takes the page's left margin when the block starts its row and the margin
  has room; otherwise it sits above the block's corner.
- **`resolveDrop` is pure** (`canvas/drop_resolver.dart`): the top and bottom
  band of a row, and the space between rows, mean "a new row here"; the
  middle means "into this row, beside this block" — and when the row has no
  room, a new row on the nearer side rather than nothing.
- A drag is `pointerDragAnchorStrategy` with a small chip (the old feedback
  was the tile, anchored wherever it was grabbed, so a block landed left of
  the pointer), `LongPressDraggable` on touch so the page still scrolls, and
  `EdgeDraggingAutoScroller` at the pane's edges.
- **Every move a drag can make is also in the block's menu** (`block_menu.dart`)
  — a drag is not available to a keyboard or a screen reader, and is awkward
  on a phone. The canvas tab, a right-click and the phone outline open the
  same menu.
- Keys: see § Every key the workspace binds is guarded. Plain arrows move
  the *selection* and never content, so they cannot fight scrolling.
- **Width handles are followers in the chrome layer too**, the size of their
  grip. Drawn inside the row they were clipped to the content box at a row's
  ends — a block alone in its row could not be resized — and as a strip the
  block's height they took taps meant for the block and let them fall to the
  background, which deselects.
- **An image is drawn by `DesignerImage`.** An upload is stored in the design
  as a `data:` URL, which `Image.network` cannot fetch outside a browser:
  every uploaded image drew as a broken-image box on the native apps. A
  `data:` source is decoded once into `Image.memory`. Only a source starting
  with `$` is run through `replaceVariables` (the rest was ~150 patterns
  over megabytes of base64 per rebuild), and the panel's address field stays
  empty for an upload.

### The layout follows the pane

The builder is laid out beside the app's sidebar (232px, 64 collapsed), so
the window's width says nothing about the room it has: on a 1280 window the
three-pane layout left the page at 55%, and an iPad in portrait got a toolbar
with no room for the name. `WysiwygDesignScreen` and `DesignerWorkspace` each
measure their own box with a `LayoutBuilder` and publish it as `DesignerPane`;
nothing in the designer reads `MediaQuery` for a width.

| Pane (`designerTierFor`) | Layout |
|---|---|
| ≥ 1280 `full` | palette · canvas · panel |
| 900–1279 `docked` | canvas · panel; palette behind "Add block" |
| 560–899 `canvas` | canvas; palette sheet; panel in a drawer |
| < 560 `outline` | the reorder outline |

At laptop widths it is the palette that gives way, so the page stays above
~80%. `designer_pane_layout_test.dart` pumps the workspace inside a
232px-inset navigator.

Two more things only that inset shows:

- **`showMenu` positions against the nearest navigator's overlay**, which
  starts at the pane's left edge, not the window's — every menu opened 232px
  right of its anchor. All of them go through `menuAnchor`
  (`designer_pane.dart`).
- **A menu's caller can be unmounted by its own first step.** Right-click
  selects the block, selection re-keys and re-parents its cell, and the
  `context.mounted` check after the menu then dropped the action. The canvas
  passes its own context, and nothing after the `await` needs the caller's
  (toasts and strings are captured first).

The invoice-details block's label/value gap is the label cell's right
padding, as on the server (`padding-right: labelValueGap`). It was a third
table column pinned to zero width, so the longest value printed flush against
its label ("Due DateDec 23, 2025").

## The property panel

320 wide, two tabs — **Block** and **Page** — at every width.

- `PropertyRow` is a name beside a control, and a name *above* it when the
  row is narrower than both need (`_kStackBelow`): an editor nested in a list
  row's card ran its stepper 28px past the edge.
  `property_panel_text_scale_test.dart` pumps every block's editor, every
  collapsed row opened, at 1.0× and 1.4× **with the app's own font** — under
  the test font's square glyphs the question means nothing.
- Colours are a button opening a picker (`showDesignerColorPicker`): the
  colours this design already uses, the company's, a swatch grid, and
  Default. A typed hex commits only when it is one.
- Margins are four numbers for four distances. The design stores a margin
  and a padding per side and the server adds them; the panel edits the sum
  and leaves the stored split alone where it can.
- A control the PDF ignores is not shown: QR size, secondary font, totals
  italic, block height, lock — and, by block, a **title** on the company and
  details blocks (only the client and ship-to blocks print one), a field's
  **prefix / suffix** on the details block, and a table's "Show borders"
  (read by neither renderer). `page_matches_pdf_test.dart`.
- **A table border side is stored `true` or `false`, never left out** — the
  server draws a side unless it is strictly `false`, and the renderer reads a
  missing one as on. A missing *region* is all four sides at 1px `#E5E7EB`.
- **A length never goes below zero.** `PxInput.minPx` defaults to 0; with no
  floor one press of "−" on an empty Padding wrote `-1px`.
- **A row is hidden by the server's own test** (`resolvesEmpty`): blank, or
  still holding a `$token` nothing replaced. `hideIfEmpty` left out is *on*.
- **A details row is labelled with a token**, the flat one where the page
  knows it (`$number_label`), else the variable's own (`$invoice.custom1_label`)
  — never this app's translation key, which prints verbatim. A custom
  field's label is the name the company gave it
  (`DesignerRenderScope.customFieldLabels`), as `makeCustomField` prints.
- Example values — under a field's name, and in the variable picker — are
  read from the document on the page (`DesignerRenderScope.sampleOf`), so
  they are the values the user is looking at. A value that document does not
  have is a dash; a token the page has no value for at all shows as typed.

## Start, check, finish

### Starting layouts

`templates.dart` → `showStarterGallery`. Blank plus four starters, each drawn
by `DesignPageThumbnail` — the canvas's own renderers, small — so what a card
promises is what opens. A starter is told apart by its picture, so each sets
some style on its blocks (`templates_test.dart` fails if two are the same
blocks in the same style); Bold takes the company's primary colour.
`starterGalleryColumns` avoids one card alone on the last line where it can
(it gives up a column) — at two columns an odd count still ends on one.
"Replace layout" in the builder's menu reuses the gallery and is one undo step.

### The page and the preview show the same document

`DesignerDocumentController` (`document_source.dart`) holds which document the
designer is filled in with: one of the company's five most recent invoices
(`InvoiceRepository.watchRecent`), newest by default, or the made-up sample.

- The page draws it through `designerDataFromInvoice`
  (`sample/real_document.dart`). A value the invoice does not have is empty,
  not the sample's — that is what prints, and what "hide if empty" reacts to.
  Line totals come from `computeLineTotal`, the rule the subtotal is built on.
  What is *due* follows `HtmlEngine` — a deposit that is asked for (and its
  date, and the label "Partial Due"), the amount on a draft, nothing once
  paid — and amounts are in the client's currency; a percentage line discount
  prints as `10%`. A client that is not on this device is fetched once.
- The preview sends its id as `entity_id` (`LiveDesignService.renderDesignPreview`),
  for the `invoice` document type only; any other type, the sample, or an
  unsynced (`tmp_`) invoice sends `-1`, and the header then says the server
  chose the document.
- It is a way of looking at the design, not part of it: nothing is saved and
  a different choice never dirties the design.
- With no invoice to offer, the picker and its bar render nothing.

### Suggestions

`designSuggestions` — no line-items table, no totals (which also loses the
paid stamp's anchor), two totals, a logo block with no company logo. A count
in the top bar; never an error, never in the way of a save. The two that
adding a block settles do so on a press.

### Putting a design to use

A saved design is not a used one: `*_design_id` in company settings decides
what documents use. The top bar says which (`_UsageButton`: "Not in use" /
"Used for Invoices +2"), and the first save of an unused design offers it on
the Saved toast (`savedActionBuilder`) — an offer, not a dialog, because a
save should not interrupt the work it saves.

`showUseDesignDialog` writes the same two things Invoice Design → General
does (`planUseDesign`): the settings, and for "also change existing documents"
the `_design_updates` directive `CompanySyncDispatcher` turns into
`POST /designs/set/default`. Its primary action is not focused and carries no
Enter hint — it changes what customers are sent. A design whose create has
not synced (`tmp_` id) cannot be put to use yet, and says so.

### Archived designs

`DesignDao.watchAll` is the pickers' list and leaves archived designs out, so
an archived design had nowhere to be found and nothing to restore it with.
Custom Designs has a "Show archived" switch (`_ArchivedDesigns`) listing
`watchArchived` with Restore. Turning it on runs `refreshAll(full: true)`
first: the login bundle never carries an archived design
(`Company::designs()` is a plain `hasMany` on a `SoftDeletes` model), and the
default delta sweep starts from the cursor that bundle left, so a design
archived before it is not in it either. A design has no local restore to
apply ahead of the server, so Restore says "restored" when the row has left
and, offline, that the change will sync.

## Deliberately not done

- **The builder is not a route.** It stays a pushed modal
  (`showWysiwygDesignScreen`), as `docs/architecture.md` § Navigation
  reserves for the design editor and `kNonRecordRouteEntityTypes` assumes. A
  refresh returns to the Custom Designs list, one tap from the saved design.
- **No draft autosave.** A design can embed megabytes of image data.
- **New blocks do not take the company colour.** A coloured header on one
  block of an otherwise neutral page is a worse default than a neutral one;
  the picker offers the company's colours first.
- Multi-select, copy/paste between designs, zoom beyond fit-to-width,
  repeating header/footer zones (the server reads no block `region`),
  in-place text editing, page-break guides (heights are approximate).

## Known gaps

- **`$bill_to_label` needs server 5.13.41.** It is the client block's default
  title (and what a legacy `bill_to` is upgraded to); `HtmlEngine` gained
  `$bill_to` in `01f8647eda` (2026-09-08), first tagged in v5.13.41. An older
  self-hosted server prints the token as typed.
- A design with a *partial* `documentSettings` map (nothing known writes
  one) has each missing key filled from this app's defaults on its first
  page-setting edit, where the server would have used the company's. One
  with **no** map falls back to the company's settings, not to the defaults.

- Flutter's text metrics are not Chrome's: heights on the canvas are close,
  not exact. The server preview is the truth.
- React's builder (unmerged at the time of writing) is GridStack with its
  own row height; it can re-flow a design saved here and forces portrait.
- An HTML design saved by an older build with `"blocks": []` prints blank
  until it is saved again.
- A billed-time (task) line is dropped by the server's products table, and
  there is no tasks table to add (`BACKEND.md`).
