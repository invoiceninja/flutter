# When a billing-doc PDF preview re-renders

Companion to CLAUDE.md § Detail screens. The rule is there. This doc carries the mechanism behind it: the two revision seams on `BillingDocPdfView`, the render guard in `printing`, and what the user sees offline.

## A billing-doc PDF preview refetches when its document changes and keeps the last good render, marked stale, when that refresh fails

**A billing-doc PDF preview refetches when its document changes (`contentRevision`) and keeps the last good render, marked stale, when that refresh fails; a version switch (`revision`) still clears it.**

**The bug it fixes.** A user edited an invoice, added a line, and saved. The line-item list showed the new line, but the PDF beside it still showed the old invoice until the user backed out and reopened it. Here is why:

- `BillingDocPdfView` fetches once in `initState`.
- The wide record screen's `VersionedPdfPane` passed only `revision: activityId`, which is the selected history version. It is `null` for the live document and an edit doesn't change it.
- The editor is pushed over the record screen (`router.dart`, "the one page this Navigator pushes over another") and pops back to it, so the view's State survives the edit.
- The record screen did rebuild with the new row, and `_PdfPane` built a new fetcher around it. Nothing called that fetcher.

The five `/…/:id/pdf` route screens and the email screen's PDF tab had the same gap.

**There are two seams, because there are two kinds of change:**

| | `revision` | `contentRevision` |
|---|---|---|
| Means | a different document (a history version, the live one) | newer content of the same document |
| Fetch | at once | after `autoRefreshDebounce` (600 ms) |
| While loading | translucent scrim over the last good PDF | the last good PDF stays usable; a 2 px progress bar appears after 300 ms |
| On error | drops the PDF and shows `ErrorView` | keeps the PDF, shows "This preview doesn't include your latest changes" with Retry, and turns off Print and Share |

If both seams change in one rebuild, `revision` wins. Going back from a version to the live document changes both.

**Why an error drops the PDF on `revision` but keeps it on `contentRevision`.** A version whose backup file is missing returns 404 ("No backup exists"). If the view kept the old bytes, the live PDF would stay on screen under that version's title. Newer content is different: the PDF on screen is still this document, only older. The common way into this state is an edit made offline, because `live_preview` is a POST to the server. Before this fix, the offline user kept seeing the stale PDF with no warning. Clearing it for an error screen on every offline edit would make things worse.

**Recovery needs no trigger of its own.** When the outbox syncs, the server's echo changes the row again. That change is a new `contentRevision`, which refetches.

## The revision key is the whole freezed record

Every live caller passes the record itself:

- the edit screens pass `vm.draft`
- the record panes pass the watched row
- the `/pdf` routes pass the streamed row
- the email screen passes its streamed document

Two properties make this the right key:

- **A re-emit of an unchanged row doesn't refetch.** `BaseEntityRepository` returns the same decoded instance for an unchanged row, and freezed's `==` is deep otherwise: `DeepCollectionEquality` for lists and maps, value equality for `Date` and `Decimal`. The open re-check and a `/refresh` delta that rewrite an identical row therefore cost nothing (pinned by "the pane follows the record" in `test/ui/features/invoices/invoice_detail_screen_test.dart`).
- **A narrower key misses real changes.** A dirty row keeps its old `updatedAt` until the echo, so an `updatedAt` key would miss a second offline edit. A `toApiJson()` map compares by identity, so it would refetch on every rebuild.

The accepted cost is that a change which doesn't affect the PDF also refetches: private notes, a document upload, a client viewing the invoice (invitation dates arriving through a pushed `/refresh`). These refreshes are quiet and don't block the pane.

**What a save costs.** An online save waits for the server before the editor closes (`GenericEditViewModel.save`). Both the dirty write and the echo land while the editor still covers the pane, and the generation guard discards the first result. The user sees one refresh. Two visible refreshes happen only with an offline save, or one that hits the 30-second "Saving in background" timeout.

- The dirty render goes through `live_preview` of the local JSON. `storedPdfInvitationKey` is null while `isDirty`.
- The echo goes through `GET /api/v1/<entity>/<invitationKey>/download`. That is the server's own render: it carries the signature, any embedded documents and the e-invoice.
- That route renders on every call (`CreateRawPdf::handle`), so it is never stale after a save.

**A signed document goes back to the signed file.** Once DocuNinja signing completes, `CreateRawPdf` (`:107-125`) returns the stored signed PDF and skips rendering. Editing the document doesn't clear that state. So a signed invoice, quote or PO shows the edit while it is dirty, then the signed original after the echo. This is by design and matches React; it is not this bug coming back.

## The delivery note cannot show an unsynced edit

The delivery-note toggle fetches `GET /invoices/{id}/delivery_note`, which renders the server's saved copy, and `live_preview` has no delivery-note variant. While the record `isDirty` and the toggle is on, the view shows the stale notice without Retry, because retrying can't help, and keeps Print and Share off. The echo clears it. The input is `hasUnsyncedChanges` on `BillingDocPdfView`, which callers pass as the record's `isDirty`.

## PdfPreview gets a new build callback only with new bytes

`PdfPreview` re-renders (rasters) every page whenever its `build` callback changes identity. Its renderer skips a request that arrives while a render is running and never retries it (`docs/upstream-workarounds.md` #14).

The view used to pass `(_) => bytes` from `build()`, so a new callback was created on every frame. The scrim's own `setState` then queued a render of the old bytes just before the new bytes arrived, and on a slow device the new render was skipped. The pane showed the old invoice with the new bytes in memory: the same symptom as the original bug, by a different route.

`_build` is now created only where `_bytes` is assigned. The page images are replaced in place (`raster.dart`), so the scroll position survives a refresh, and an unrelated rebuild no longer resets the zoom.

**The slots around the preview come and go *after* it in the `Stack`**: the notice row, the progress bar and the scrim. `PdfPreview` stays child 0 and is never remounted. A notice placed *above* the preview would have resized it and forced every page to render again.
